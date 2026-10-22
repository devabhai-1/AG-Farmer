/**
 * Realtime Database writer:
 * 1) Admin SDK when serviceAccountKey.json is present
 * 2) Else REST + user idToken (Firebase Auth) — needs rules that allow auth.uid writes
 */
import { env } from '../config/env.js';
import { isFirebaseReady, rootRef } from '../config/firebase.js';
import { maskIp, normalizeIp } from '../middleware/client_ip.js';

function dbBase() {
  const url = String(env.databaseURL || '').replace(/\/$/, '');
  return url;
}

function emailKey(email) {
  // RTDB keys cannot contain . # $ [ ]
  return String(email || '')
    .trim()
    .toLowerCase()
    .replace(/@/g, '_at_')
    .replace(/\./g, '_dot_')
    .replace(/[^a-z0-9_]/g, '_');
}

async function restPut(path, data, idToken) {
  const base = dbBase();
  if (!base) throw new Error('database_url_missing');
  const url = `${base}/${path}.json?auth=${encodeURIComponent(idToken)}`;
  const res = await fetch(url, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
  const text = await res.text();
  let json = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = { raw: text };
  }
  if (!res.ok) {
    const msg = json?.error || text || `rtdb_http_${res.status}`;
    throw Object.assign(new Error(String(msg)), { status: res.status, body: json });
  }
  return json;
}

async function restPatch(path, data, idToken) {
  const base = dbBase();
  const url = `${base}/${path}.json?auth=${encodeURIComponent(idToken)}`;
  const res = await fetch(url, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
  const text = await res.text();
  let json = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = { raw: text };
  }
  if (!res.ok) {
    const msg = json?.error || text || `rtdb_http_${res.status}`;
    throw Object.assign(new Error(String(msg)), { status: res.status, body: json });
  }
  return json;
}

async function adminSet(path, data) {
  await rootRef(path).set(data);
  return data;
}

async function adminUpdate(path, data) {
  await rootRef(path).update(data);
  return data;
}

export const RtdbWrite = {
  emailKey,

  async set(path, data, { idToken = null } = {}) {
    if (isFirebaseReady()) return adminSet(path, data);
    if (!idToken) throw new Error('rtdb_needs_id_token_or_service_account');
    // path is relative to ag_farmer root via rootRef — REST needs full ag_farmer/...
    const full = `${env.rtdbRoot}/${path}`.replace(/\/+/g, '/');
    return restPut(full, data, idToken);
  },

  async update(path, data, { idToken = null } = {}) {
    if (isFirebaseReady()) return adminUpdate(path, data);
    if (!idToken) throw new Error('rtdb_needs_id_token_or_service_account');
    const full = `${env.rtdbRoot}/${path}`.replace(/\/+/g, '/');
    return restPatch(full, data, idToken);
  },

  /**
   * Full user profile under:
   *   users/{uid}/profile
   *   email_users/{emailKey}/profile   (mail ke andar profile)
   *   indexes/email/{emailKey}
   */
  async saveUserProfile({
    uid,
    email,
    name,
    phone,
    address,
    age,
    acceptedPolicy,
    provider = 'email',
    plan = 'free',
    firebaseUid = null,
    ip = null,
    extra = {},
    idToken = null,
    createdAt = null,
  }) {
    const now = Date.now();
    const em = String(email || '').trim().toLowerCase();
    const ek = emailKey(em);
    const ipNorm = ip ? normalizeIp(ip) : null;

    const profile = {
      uid,
      firebaseUid: firebaseUid || uid,
      email: em,
      name: String(name || '').trim(),
      phone: String(phone || '').trim(),
      address: String(address || '').trim(),
      age: age != null ? Number(age) : null,
      acceptedPolicy: Boolean(acceptedPolicy),
      provider,
      plan,
      planId: plan,
      profileComplete: true,
      ip: ipNorm,
      ipMasked: ipNorm ? maskIp(ipNorm) : null,
      accountCreatedAt: createdAt || now,
      createdAt: createdAt || now,
      updatedAt: now,
      ...extra,
    };

    const writes = [
      this.set(`users/${uid}/profile`, profile, { idToken }),
      this.set(`email_users/${ek}/profile`, profile, { idToken }),
      this.set(
        `indexes/email/${ek}`,
        { uid, email: em, provider, updatedAt: now },
        { idToken },
      ),
      this.set(
        `users/${uid}/ai/control`,
        {
          uid,
          email: em,
          planId: plan,
          planTier: plan,
          blocked: false,
          updatedAt: now,
        },
        { idToken },
      ),
    ];

    const results = await Promise.allSettled(writes);
    const failed = results.filter((r) => r.status === 'rejected');
    if (failed.length) {
      const err = failed[0].reason;
      console.error('[rtdb] profile save failed:', err?.message || err);
      throw err;
    }

    console.info(`[rtdb] profile saved uid=${uid} email=${em} via=${isFirebaseReady() ? 'admin' : 'rest'}`);
    return profile;
  },
};
