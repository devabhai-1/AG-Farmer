import crypto from 'crypto';
import path from 'path';
import { fileURLToPath } from 'url';
import { env } from '../config/env.js';
import { auth, isFirebaseReady, rootRef } from '../config/firebase.js';
import { signAppToken } from './jwt.service.js';
import {
  maskEmail,
  sendPasswordResetLinkEmail,
  shortResetUrl,
} from './mail.service.js';
import { consumeResetOob, createResetCode } from './reset_link.service.js';
import { sendAccountWelcome } from '../mail/index.js';
import { FirebaseIdentity } from './firebase_identity.service.js';
import { RtdbWrite } from './rtdb_write.service.js';
import { UserAiContextService } from './user_ai_context.service.js';
import { emailKey, normalizeEmail } from '../utils/email_key.js';
import { jsonCache } from '../utils/json_cache.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const dataDir = path.resolve(__dirname, '../../data');
const accountsFile = path.join(dataDir, 'accounts.json');
const accounts = jsonCache(accountsFile, { byEmail: {}, byUid: {} });

function readStoreLocal() {
  const raw = accounts.read();
  if (!raw.byEmail || typeof raw.byEmail !== 'object') raw.byEmail = {};
  if (!raw.byUid || typeof raw.byUid !== 'object') raw.byUid = {};
  return raw;
}

function writeStoreLocal(store) {
  accounts.write(store, { now: true });
}

/** Never mirror password hashes to RTDB. */
function publicAccountMirror(row) {
  if (!row || typeof row !== 'object') return null;
  const { passwordSalt: _s, passwordHash: _h, ...safe } = row;
  return { ...safe, updatedAt: Date.now() };
}

async function writeStore(store, touch = {}) {
  writeStoreLocal(store);
  if (!isFirebaseReady()) return;
  try {
    const uid = touch.uid;
    const ek = touch.emailKey;
    const ops = [];
    if (uid && store.byUid?.[uid]) {
      const safe = publicAccountMirror(store.byUid[uid]);
      if (safe) ops.push(rootRef(`accounts/${uid}`).set(safe));
    }
    if (ek && store.byEmail?.[ek]) {
      const row = store.byEmail[ek];
      ops.push(
        rootRef(`indexes/email/${ek}`).set({
          uid: row.uid,
          email: row.email || ek,
          provider: row.provider || 'email',
          updatedAt: Date.now(),
        }),
      );
    }
    ops.push(
      rootRef('auth/meta').update({
        accountCount: Object.keys(store.byUid || {}).length,
        updatedAt: Date.now(),
      }),
    );
    await Promise.all(ops);
  } catch (e) {
    console.warn('[email-auth] RTDB accounts write skipped:', e.message);
  }
}

async function readStore() {
  const local = readStoreLocal();

  // Normalize legacy raw-email keys → shared emailKey
  let dirty = false;
  for (const [k, row] of Object.entries(local.byEmail)) {
    const em = normalizeEmail(row?.email || k);
    if (!em.includes('@')) continue;
    const canon = emailKey(em);
    if (k !== canon) {
      if (!local.byEmail[canon]) local.byEmail[canon] = { ...row, email: em };
      delete local.byEmail[k];
      dirty = true;
    }
  }
  if (dirty) writeStoreLocal(local);

  if (!isFirebaseReady()) return local;
  try {
    const snap = await rootRef('auth/meta').get();
    if (snap.exists()) return local;
    const legacy = await rootRef('auth/accounts').get();
    if (legacy.exists() && legacy.val()) {
      const remote = legacy.val();
      const merged = {
        byEmail: { ...(local.byEmail || {}), ...(remote.byEmail || {}) },
        byUid: { ...(local.byUid || {}), ...(remote.byUid || {}) },
      };
      writeStoreLocal(merged);
      await rootRef('auth/meta').update({
        accountCount: Object.keys(merged.byUid || {}).length,
        migratedLegacy: true,
        updatedAt: Date.now(),
      });
      await rootRef('auth/accounts').remove().catch(() => {});
      return merged;
    }
  } catch (e) {
    console.warn('[email-auth] RTDB accounts read skipped:', e.message);
  }
  return local;
}

function scryptHex(password, salt) {
  return new Promise((resolve, reject) => {
    crypto.scrypt(password, salt, 64, (err, buf) => {
      if (err) reject(err);
      else resolve(buf.toString('hex'));
    });
  });
}

async function hashPassword(password, salt = crypto.randomBytes(16).toString('hex')) {
  const hash = await scryptHex(password, salt);
  return { salt, hash };
}

async function verifyPassword(password, salt, hash) {
  if (!password || !salt || !hash) return false;
  const check = await scryptHex(password, salt);
  const a = Buffer.from(check);
  const b = Buffer.from(String(hash));
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

function newUid(prefix = 'u') {
  return `${prefix}_${crypto.randomBytes(12).toString('hex')}`;
}

/** Legacy in-memory OTP (unused when Firebase reset is active) */
const resetStore = new Map();

function randomOtp() {
  return String(crypto.randomInt(100000, 999999));
}

function randomTempPassword() {
  return `Tmp_${crypto.randomBytes(12).toString('base64url')}!a1`;
}

/** Google sign-in becomes a real Firebase Auth user, then the profile is stored in RTDB. */
async function ensureFirebaseGoogleUser({ email, name, googleSub }) {
  if (!isFirebaseReady()) return null;
  const a = auth();
  let user;
  try {
    user = await a.getUserByEmail(email);
  } catch (e) {
    if (e.code !== 'auth/user-not-found') throw e;
    user = await a.createUser({
      email,
      emailVerified: true,
      displayName: name || undefined,
    });
  }
  if (user.disabled) {
    throw Object.assign(new Error('account_pending_deletion'), { status: 403 });
  }

  if (googleSub) {
    try {
      await a.updateUser(user.uid, {
        emailVerified: true,
        displayName: user.displayName || name || undefined,
        providerToLink: {
          providerId: 'google.com',
          uid: String(googleSub),
          email,
          displayName: name || undefined,
        },
      });
    } catch (e) {
      const msg = `${e.code || ''} ${e.message || ''}`;
      if (!/already|FEDERATED_USER_ID_ALREADY_LINKED/i.test(msg)) {
        console.warn('[google] provider link skip:', e.message);
      }
    }
  }
  return user.uid;
}

async function saveProfile(uid, profile, { idToken = null, ip = null } = {}) {
  const now = Date.now();
  const merged = {
    ...profile,
    uid,
    updatedAt: now,
    createdAt: profile.createdAt || now,
  };

  // Always try Realtime Database (Admin SDK or Auth REST)
  try {
    return await RtdbWrite.saveUserProfile({
      uid,
      email: profile.email,
      name: profile.name,
      phone: profile.phone,
      address: profile.address,
      age: profile.age,
      acceptedPolicy: profile.acceptedPolicy,
      provider: profile.provider || 'email',
      plan: profile.plan || 'free',
      firebaseUid: profile.firebaseUid || uid,
      ip,
      idToken,
      createdAt: profile.accountCreatedAt || profile.createdAt || now,
      extra: {
        profileComplete: profile.profileComplete !== false,
      },
    });
  } catch (e) {
    console.error('[email-auth] RTDB profile REQUIRED but failed:', e.message);
    // Still return local profile so JWT login works — but flag for client
    return { ...merged, rtdbSaved: false, rtdbError: String(e.message || e) };
  }
}

function normalizeIndianMobile(phone) {
  const digits = String(phone || '').replace(/\D/g, '');
  const norm =
    digits.length === 12 && digits.startsWith('91')
      ? digits.slice(2)
      : digits.length === 11 && digits.startsWith('0')
        ? digits.slice(1)
        : digits;
  return norm.length === 10 ? norm : '';
}

function sessionPayload(account, profile) {
  const token = signAppToken({
    uid: account.uid,
    email: account.email,
    provider: account.provider || 'email',
  });
  return {
    token,
    tokenType: 'Bearer',
    expiresInSec: env.jwtExpiresSec,
    uid: account.uid,
    email: account.email,
    // Never fall back to local accounts.json ghost fields
    name: profile?.name || '',
    phone: profile?.phone || '',
    profile,
    authMode: 'backend_email',
    needsProfileCompletion: profile?.profileComplete === false,
  };
}

export const EmailAuthService = {
  async register({
    name,
    email,
    password,
    phone = '',
    address = '',
    age,
    acceptedPolicy,
    ip = null,
  }) {
    const em = normalizeEmail(email);
    if (!em || !em.includes('@')) {
      throw Object.assign(new Error('invalid_email'), { status: 400 });
    }
    if (!name || String(name).trim().length < 2) {
      throw Object.assign(new Error('Name required'), { status: 400 });
    }
    if (!password || String(password).length < 6) {
      throw Object.assign(new Error('weak_password'), { status: 400 });
    }
    if (!acceptedPolicy) {
      throw Object.assign(new Error('accept_policy'), { status: 400 });
    }
    if (age != null && (Number(age) < 18 || Number(age) > 100)) {
      throw Object.assign(new Error('Age must be 18+'), { status: 400 });
    }
    const phoneNorm = normalizeIndianMobile(phone);
    if (!phoneNorm) {
      throw Object.assign(new Error('invalid_phone'), { status: 400 });
    }

    const store = await readStore();
    const key = emailKey(em);
    const existingLocal = store.byEmail[key] ? store.byUid[store.byEmail[key].uid] : null;

    // One email, one account. An existing or 30-day pending row blocks a second signup.
    if (existingLocal || store.byEmail[key]) {
      const code = existingLocal?.pendingDeletion || store.byEmail[key]?.pendingDeletion
        ? 'account_pending_deletion'
        : 'email_in_use';
      throw Object.assign(new Error(code), { status: code === 'email_in_use' ? 409 : 403 });
    }

    let firebaseUid = null;
    let idToken = null;
    const firebaseReady = isFirebaseReady();

    try {
      const fb = await FirebaseIdentity.signUp({
        email: em,
        password: String(password),
        displayName: String(name).trim(),
      });
      firebaseUid = fb.localId;
      idToken = fb.idToken || null;
    } catch (e) {
      if (e.message === 'email_in_use' || e.message === 'account_pending_deletion') {
        throw Object.assign(new Error(e.message), {
          status: e.message === 'email_in_use' ? 409 : 403,
        });
      } else if (firebaseReady) {
        console.error('[register] Firebase Auth failed:', e.message);
        throw Object.assign(new Error('service_unavailable'), { status: 503 });
      } else {
        console.warn('[register] Firebase Auth skipped:', e.message);
      }
    }

    if (firebaseReady && !firebaseUid) {
      throw Object.assign(new Error('service_unavailable'), { status: 503 });
    }

    const uid = firebaseUid || existingLocal?.uid || newUid('u');
    const createdAt = existingLocal?.createdAt || Date.now();
    const { salt, hash } = await hashPassword(password);
    const account = {
      uid,
      firebaseUid: firebaseUid || existingLocal?.firebaseUid || null,
      email: em,
      name: String(name).trim(),
      phone: phoneNorm,
      address: String(address || '').trim(),
      age: age != null ? Number(age) : null,
      provider: 'email',
      passwordSalt: salt,
      passwordHash: hash,
      createdAt,
    };
    // Drop any stale local uid rows for this email
    if (existingLocal && existingLocal.uid !== uid) {
      delete store.byUid[existingLocal.uid];
    }
    store.byEmail[key] = {
      uid,
      email: em,
      passwordSalt: salt,
      passwordHash: hash,
      provider: 'email',
      firebaseUid: account.firebaseUid,
    };
    store.byUid[uid] = account;
    await writeStore(store, { uid, emailKey: key });

    const profile = await saveProfile(
      uid,
      {
        name: account.name,
        email: em,
        phone: account.phone,
        address: account.address,
        age: account.age,
        acceptedPolicy: true,
        provider: 'email',
        profileComplete: true,
        plan: 'free',
        firebaseUid: account.firebaseUid,
        accountCreatedAt: createdAt,
        createdAt,
      },
      { idToken, ip },
    );

    if (idToken || isFirebaseReady()) {
      await UserAiContextService.linkEmailToUid(em, uid).catch(() => {});
    }

    sendAccountWelcome({ to: em, name: account.name }).catch((err) => {
      console.error('[mail] welcome', err?.message || 'welcome');
    });

    const session = sessionPayload(account, profile);
    return {
      ...session,
      rtdbSaved: profile?.rtdbSaved !== false && !profile?.rtdbError,
      profilePath: `${env.rtdbRoot}/users/${uid}/profile`,
      emailProfilePath: `${env.rtdbRoot}/email_users/${key}/profile`,
    };
  },

  async login({ email, password, ip = null }) {
    const em = normalizeEmail(email);
    if (!em || !password) {
      throw Object.assign(new Error('bad_credentials'), { status: 401 });
    }

    const store = await readStore();
    const key = emailKey(em);
    let row = store.byEmail[key];
    if (row?.pendingDeletion) {
      throw Object.assign(new Error('account_pending_deletion'), { status: 403 });
    }

    // Prefer Firebase Auth (source of truth after password resets)
    let firebaseUid = null;
    let firebaseOk = false;
    let idToken = null;
    try {
      const fb = await FirebaseIdentity.signIn({ email: em, password: String(password) });
      firebaseUid = fb.localId;
      idToken = fb.idToken || null;
      firebaseOk = true;
    } catch (fbErr) {
      const code = String(fbErr?.message || '');
      if (code === 'account_pending_deletion') {
        throw Object.assign(new Error('account_pending_deletion'), { status: 403 });
      }
      const wrongPassword = code === 'bad_credentials' || code === 'invalid_email';
      if (wrongPassword) {
        throw Object.assign(new Error('bad_credentials'), { status: 401 });
      }
      if (code === 'too_many_requests') {
        throw Object.assign(new Error('rate_limit_exceeded'), { status: 429 });
      }
      const localOk =
        row?.passwordHash &&
        (await verifyPassword(password, row.passwordSalt, row.passwordHash));
      if (localOk) {
        console.warn('[login] Firebase Auth skipped, using local account');
        firebaseUid = row.firebaseUid || null;
      } else if (code === 'account_not_found') {
        throw Object.assign(new Error('bad_credentials'), { status: 401 });
      } else {
        throw Object.assign(new Error('service_unavailable'), { status: 503 });
      }
    }

    // Ensure local profile row exists (same email → same data)
    if (!row) {
      const uid = firebaseUid || newUid('u');
      const account = {
        uid,
        firebaseUid,
        email: em,
        name: '',
        phone: '',
        provider: 'email',
        createdAt: Date.now(),
      };
      store.byEmail[key] = { uid, email: em, provider: 'email', firebaseUid };
      store.byUid[uid] = account;
      try {
        await writeStore(store, { uid, emailKey: key });
      } catch {
        console.warn('[login] account save skipped');
      }
      row = store.byEmail[key];
    } else if (firebaseUid && !row.firebaseUid) {
      row.firebaseUid = firebaseUid;
      const account = store.byUid[row.uid];
      if (account) {
        account.firebaseUid = firebaseUid;
        store.byUid[row.uid] = account;
      }
      store.byEmail[key] = row;
      try {
        await writeStore(store, { uid: row.uid, emailKey: key });
      } catch {
        console.warn('[login] account save skipped');
      }
    }

    if (row && firebaseOk) {
      const same =
        row.passwordHash &&
        (await verifyPassword(password, row.passwordSalt, row.passwordHash));
      if (!same) {
        const { salt, hash } = await hashPassword(password);
        row.passwordSalt = salt;
        row.passwordHash = hash;
        const account = store.byUid[row.uid];
        if (account) {
          account.passwordSalt = salt;
          account.passwordHash = hash;
          store.byUid[row.uid] = account;
        }
        store.byEmail[key] = row;
        try {
          await writeStore(store, { uid: row.uid, emailKey: key });
        } catch {
          console.warn('[login] account save skipped');
        }
      }
    }

    const account = store.byUid[row.uid] || {
      uid: row.uid,
      email: em,
      name: '',
      phone: '',
      provider: 'email',
    };

    // Profile from RTDB only — local accounts.json is credentials, not display SoT
    const { UserService } = await import('./user.service.js');
    let fromDb = null;
    try {
      fromDb = await UserService.get(account.uid);
    } catch {
      console.warn('[login] profile read skipped');
    }
    let profile = {
      uid: account.uid,
      name: fromDb?.name || account.name || '',
      email: em,
      phone: fromDb?.phone || account.phone || '',
      address: fromDb?.address || account.address || '',
      age: fromDb?.age ?? account.age ?? null,
      provider: 'email',
      plan: fromDb?.plan || 'free',
      acceptedPolicy: true,
      profileComplete: true,
      firebaseUid: account.firebaseUid || firebaseUid,
      accountCreatedAt: account.createdAt || Date.now(),
      createdAt: account.createdAt || Date.now(),
      selectedCropIds: fromDb?.selectedCropIds || [],
      subscription: fromDb?.subscription || null,
    };

    if (isFirebaseReady() && !fromDb) {
      profile = await saveProfile(account.uid, profile, { idToken, ip });
      profile = { ...profile, profileComplete: true };
    }

    return {
      ...sessionPayload(account, profile),
      rtdbSaved: isFirebaseReady(),
    };
  },

  async loginWithGoogle({ idToken, name, phone, age, acceptedPolicy }) {
    if (!idToken) throw Object.assign(new Error('Google token required'), { status: 400 });

    let info;
    try {
      const res = await fetch(
        `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`,
        { signal: AbortSignal.timeout(8000) },
      );
      info = await res.json();
      if (!res.ok || !info.email) {
        throw Object.assign(new Error('bad_credentials'), { status: 401 });
      }
    } catch (e) {
      if (e?.status) throw e;
      throw Object.assign(new Error('service_unavailable'), { status: 503 });
    }
    if (env.googleClientId && info.aud && info.aud !== env.googleClientId) {
      // Android client ids from this Firebase project (feradox) are valid too.
      const aud = String(info.aud);
      const sameProject =
        aud.startsWith('621096737592-') && aud.endsWith('.apps.googleusercontent.com');
      if (!sameProject) {
        throw Object.assign(new Error('bad_credentials'), { status: 401 });
      }
    }

    const em = normalizeEmail(info.email);
    const store = await readStore();
    const key = emailKey(em);
    let account = store.byUid[store.byEmail[key]?.uid];
    if (account?.pendingDeletion || store.byEmail[key]?.pendingDeletion) {
      throw Object.assign(new Error('account_pending_deletion'), { status: 403 });
    }

    // Prefer RTDB profile over local ghosts after wipe
    let rtdbProfile = null;
    if (isFirebaseReady() && account?.uid) {
      try {
        const snap = await rootRef(`users/${account.uid}/profile`).get();
        if (snap.exists()) rtdbProfile = snap.val() || {};
      } catch (_) {}
    }

    const formName = name != null && String(name).trim() ? String(name).trim() : '';
    const formPhone = normalizeIndianMobile(phone);
    const alreadyHadPhone = Boolean(
      normalizeIndianMobile(account?.phone) || normalizeIndianMobile(rtdbProfile?.phone),
    );
    const googleName = info.name || '';

    let firebaseUid = null;
    try {
      firebaseUid = await ensureFirebaseGoogleUser({
        email: em,
        name: formName || googleName,
        googleSub: info.sub,
      });
    } catch (e) {
      if (e.message === 'account_pending_deletion') throw e;
      console.error('[google] Firebase Auth failed:', e.message);
      throw Object.assign(new Error('firebase_auth_unavailable'), { status: 503 });
    }

    const isNewAccount = !account;
    if (!account) {
      const uid =
        firebaseUid ||
        `g_${String(info.sub || '').replace(/[^a-zA-Z0-9]/g, '').slice(0, 28) || newUid('g').slice(2)}`;
      account = {
        uid,
        firebaseUid,
        email: em,
        name: formName || googleName || '',
        phone: formPhone,
        age: age != null ? Number(age) : null,
        provider: 'google',
        googleSub: info.sub,
        createdAt: Date.now(),
      };
      store.byEmail[key] = {
        uid,
        email: em,
        provider: 'google',
        googleSub: info.sub,
      };
      store.byUid[uid] = account;
      await writeStore(store, { uid, emailKey: key });
    } else {
      const nextName =
        formName ||
        account.name ||
        (rtdbProfile?.name || '') ||
        googleName ||
        '';
      const nextPhone =
        formPhone ||
        normalizeIndianMobile(account.phone) ||
        normalizeIndianMobile(rtdbProfile?.phone) ||
        '';
      account = {
        ...account,
        firebaseUid: firebaseUid || account.firebaseUid || null,
        name: nextName,
        phone: nextPhone,
        age: age != null ? Number(age) : account.age ?? rtdbProfile?.age ?? null,
        provider: 'google',
        googleSub: info.sub,
      };
      store.byUid[account.uid] = account;
      await writeStore(store, {
        uid: account.uid,
        emailKey: key,
      });
    }

    const phoneNow = normalizeIndianMobile(account.phone);
    const ageNow = account.age != null ? Number(account.age) : null;
    const policyNow = Boolean(acceptedPolicy) || rtdbProfile?.acceptedPolicy === true;
    const complete = Boolean(phoneNow) && (alreadyHadPhone || (policyNow && ageNow >= 18));

    const profile = await saveProfile(account.uid, {
      name: account.name,
      email: em,
      phone: phoneNow,
      age: account.age,
      acceptedPolicy: policyNow,
      provider: 'google',
      firebaseUid: account.firebaseUid || account.uid,
      profileComplete: complete,
      plan: 'free',
    });

    if (isNewAccount) {
      sendAccountWelcome({ to: em, name: account.name }).catch((err) => {
        console.error('[mail] welcome', err?.message || 'welcome');
      });
    }

    console.info(
      `[google] auth+rtdb uid=${account.uid} firebaseUid=${account.firebaseUid || account.uid}`,
    );

    return {
      ...sessionPayload(account, { ...profile, profileComplete: complete }),
      authMode: 'firebase',
      firebaseUid: account.firebaseUid || account.uid,
    };
  },

  async completeProfile(uid, { phone, age, acceptedPolicy, name }) {
    if (!uid) throw Object.assign(new Error('Unauthorized'), { status: 401 });
    if (!acceptedPolicy) throw Object.assign(new Error('accept_policy'), { status: 400 });
    const phoneNorm = normalizeIndianMobile(phone);
    if (!phoneNorm) {
      throw Object.assign(new Error('invalid_phone'), { status: 400 });
    }
    if (age == null || Number(age) < 18) {
      throw Object.assign(new Error('Age must be 18+'), { status: 400 });
    }

    const store = await readStore();
    let account = store.byUid[uid];
    // After local wipe, recreate cache row from JWT identity
    if (!account) {
      account = {
        uid,
        email: '',
        name: name ? String(name).trim() : '',
        phone: '',
        provider: 'google',
        createdAt: Date.now(),
      };
    }

    account.phone = phoneNorm;
    account.age = Number(age);
    if (name) account.name = String(name).trim();
    store.byUid[uid] = account;
    const ek = account.email ? emailKey(account.email) : null;
    if (ek) {
      store.byEmail[ek] = {
        ...(store.byEmail[ek] || {}),
        uid,
        email: account.email,
        provider: account.provider || 'google',
      };
    }
    await writeStore(store, { uid, emailKey: ek });

    const profile = await saveProfile(uid, {
      name: account.name,
      email: account.email,
      phone: account.phone,
      age: account.age,
      acceptedPolicy: true,
      provider: account.provider || 'google',
      profileComplete: true,
    });

    return sessionPayload(account, profile);
  },

  async forgotPassword({ email }) {
    const em = normalizeEmail(email);
    if (!em || !em.includes('@')) {
      throw Object.assign(new Error('invalid_email'), { status: 400 });
    }
    if (!isFirebaseReady()) {
      throw Object.assign(new Error('email_auth_disabled'), { status: 503 });
    }

    const store = await readStore();
    const row = store.byEmail[emailKey(em)];
    const account = row ? store.byUid[row.uid] : null;
    if (account?.pendingDeletion || row?.pendingDeletion) {
      throw Object.assign(new Error('account_pending_deletion'), { status: 403 });
    }

    const a = auth();
    let fbUser = null;
    try {
      fbUser = await a.getUserByEmail(em);
    } catch (e) {
      if (e.code !== 'auth/user-not-found') {
        console.error('[forgot] lookup failed:', e.code || e.message);
        throw Object.assign(new Error('email_send_failed'), { status: 502 });
      }
    }

    if (!fbUser && !account) {
      throw Object.assign(new Error('account_not_found'), { status: 404 });
    }
    if (fbUser?.disabled) {
      throw Object.assign(new Error('account_pending_deletion'), { status: 403 });
    }

    if (!fbUser) {
      try {
        fbUser = await a.createUser({
          email: em,
          password: randomTempPassword(),
          displayName: account.name || undefined,
        });
      } catch (e) {
        if (e.code === 'auth/email-already-exists') {
          fbUser = await a.getUserByEmail(em);
        } else {
          console.error('[forgot] create user failed:', e.code || e.message);
          throw Object.assign(new Error('email_send_failed'), { status: 502 });
        }
      }
    }

    let link;
    try {
      link = await a.generatePasswordResetLink(em, {
        url: 'https://api.ag-farmer.com/api/reset-password',
        handleCodeInApp: false,
      });
    } catch (e) {
      console.error('[forgot] link failed:', e.code || e.message);
      throw Object.assign(new Error('email_send_failed'), { status: 502 });
    }
    const oobCode = new URL(link).searchParams.get('oobCode') || '';
    if (!oobCode) {
      throw Object.assign(new Error('email_send_failed'), { status: 502 });
    }
    try {
      await sendPasswordResetLinkEmail({
        to: em,
        name: account?.name || fbUser?.displayName || '',
        link: shortResetUrl(createResetCode(oobCode)),
      });
    } catch (e) {
      console.error('[forgot] mail failed:', e.message);
      throw Object.assign(new Error('email_send_failed'), { status: 502 });
    }
    console.log('[forgot] reset mail queued for', maskEmail(em));
    return {
      sent: true,
      channel: 'ag_farmer_email',
      emailMasked: maskEmail(em),
      mode: 'reset_link',
    };
  },

  async confirmReset({ oobCode, newPassword }) {
    const code = String(oobCode || '').trim();
    const password = String(newPassword || '');
    if (code.length < 8) {
      throw Object.assign(new Error('reset_link_expired'), { status: 400 });
    }
    if (password.length < 6) {
      throw Object.assign(new Error('weak_password'), { status: 400 });
    }
    const email = await FirebaseIdentity.confirmPasswordReset({
      oobCode: code,
      newPassword: password,
    });
    consumeResetOob(code);
    const em = normalizeEmail(email);
    if (em) {
      const store = await readStore();
      const key = emailKey(em);
      const row = store.byEmail[key];
      const account = row ? store.byUid[row.uid] : null;
      if (account && row) {
        const { salt, hash } = await hashPassword(password);
        account.passwordSalt = salt;
        account.passwordHash = hash;
        row.passwordSalt = salt;
        row.passwordHash = hash;
        store.byUid[account.uid] = account;
        store.byEmail[key] = row;
        try {
          await writeStore(store, { uid: account.uid, emailKey: key });
        } catch {
          console.warn('[forgot] local password save skipped');
        }
      }
    }
    return { updated: true, emailMasked: em ? maskEmail(em) : '' };
  },

  async resetPassword({ email, code, newPassword }) {
    if (code && newPassword && String(code).length > 20) {
      return this.confirmReset({ oobCode: code, newPassword });
    }
    throw Object.assign(new Error('reset_link_expired'), { status: 400 });
  },
};
