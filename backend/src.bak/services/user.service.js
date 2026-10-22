import path from 'path';
import { fileURLToPath } from 'url';
import { rootRef, isFirebaseReady } from '../config/firebase.js';
import { UserActivityService, emailKey } from './user_activity.service.js';
import { jsonCache } from '../utils/json_cache.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const accountsFile = path.resolve(__dirname, '../../data/accounts.json');
const accounts = jsonCache(accountsFile, { byEmail: {}, byUid: {} });

function readAccount(uid) {
  try {
    const store = accounts.read();
    const a = store.byUid?.[uid];
    if (!a) return null;
    return {
      uid,
      name: a.name || '',
      email: a.email || '',
      phone: a.phone || '',
      address: a.address || '',
      age: a.age ?? null,
      provider: a.provider || 'email',
      profileComplete: a.provider === 'google'
        ? Boolean(a.phone && a.age >= 18)
        : true,
      plan: 'free',
      acceptedPolicy: true,
    };
  } catch {
    return null;
  }
}

function patchAccountFile(uid, patch) {
  const store = accounts.read();
  const a = store.byUid?.[uid];
  if (!a) return null;
  Object.assign(a, {
    name: patch.name ?? a.name,
    phone: patch.phone ?? a.phone,
    address: patch.address ?? a.address,
    age: patch.age ?? a.age,
    language: patch.language ?? a.language,
    theme: patch.theme ?? a.theme,
  });
  store.byUid[uid] = a;
  accounts.write(store, { now: true });
  return readAccount(uid);
}

export const UserService = {
  /** Auth credentials may live in accounts.json — display profile is RTDB-only. */
  async get(uid) {
    const acct = readAccount(uid);
    const email = acct?.email || null;

    if (isFirebaseReady()) {
      try {
        const [profile, subscription, state] = await Promise.all([
          rootRef(`users/${uid}/profile`).get(),
          rootRef(`users/${uid}/subscription`).get(),
          rootRef(`users/${uid}/state`).get(),
        ]);
        const p = profile.exists() ? profile.val() || {} : {};
        const st = state.exists() ? state.val() || {} : {};

        // RTDB empty after wipe → empty profile (do NOT fall back to accounts.json)
        if (!profile.exists() && !state.exists() && !subscription.exists()) {
          return {
            uid,
            email: acct?.email || email,
            name: acct?.name || '',
            phone: acct?.phone || '',
            address: acct?.address || '',
            age: acct?.age ?? null,
            provider: acct?.provider || 'email',
            plan: 'free',
            selectedCropIds: [],
            subscription: null,
            profileComplete: Boolean(acct),
            storage: 'rtdb',
            rtdbEmpty: true,
          };
        }

        return {
          uid,
          email: p.email || email,
          name: p.name || '',
          phone: p.phone || '',
          address: p.address || '',
          age: p.age ?? null,
          provider: p.provider || acct?.provider || 'email',
          plan: p.plan || 'free',
          acceptedPolicy: p.acceptedPolicy !== false,
          profileComplete: p.profileComplete !== false || Boolean(acct),
          subscription: subscription.val() || p.subscription || null,
          language: st.language || p.language || null,
          theme: st.theme || p.theme || null,
          aiProvider: st.aiProvider || p.aiProvider || null,
          selectedCropIds: st.selectedCropIds || p.selectedCropIds || [],
          lastActivity: st.lastActivity || null,
          storage: 'rtdb',
        };
      } catch (e) {
        console.warn('[user] RTDB get failed:', e.message);
      }
    }

    // No Admin SDK / RTDB offline — never show ghost name/phone from local JSON
    return {
      uid,
      email,
      name: '',
      phone: '',
      address: '',
      age: null,
      provider: acct?.provider || 'email',
      plan: 'free',
      selectedCropIds: [],
      subscription: null,
      profileComplete: false,
      storage: 'rtdb_offline',
      rtdbEmpty: true,
    };
  },

  async update(uid, patch, { email = null } = {}) {
    const now = Date.now();
    const next = { ...patch, updatedAt: now };

    if (isFirebaseReady()) {
      const current = await this.get(uid);
      const em = String(email || current?.email || '').trim().toLowerCase();
      const ek = emailKey(em);

      const statePatch = {};
      for (const k of [
        'language',
        'theme',
        'aiProvider',
        'selectedCropIds',
        'plan',
      ]) {
        if (patch[k] !== undefined) statePatch[k] = patch[k];
      }
      if (patch.subscription !== undefined) {
        statePatch.planId =
          patch.subscription?.planId || patch.plan || statePatch.planId;
      }

      const ops = [
        rootRef(`users/${uid}/profile`).update({
          uid,
          email: em || current?.email || null,
          ...next,
        }),
      ];
      if (Object.keys(statePatch).length) {
        ops.push(
          UserActivityService.saveState({
            uid,
            email: em,
            patch: { ...statePatch, lastActivity: now },
          }),
        );
      }
      if (patch.subscription) {
        ops.push(
          rootRef(`users/${uid}/subscription`).set({
            ...patch.subscription,
            updatedAt: now,
          }),
        );
      }
      if (ek) {
        ops.push(
          rootRef(`email_users/${ek}/profile`).update({
            uid,
            email: em,
            ...next,
          }),
        );
      }
      await Promise.all(ops);
      if (em) await UserActivityService.linkEmail(em, uid);
      return this.get(uid);
    }

    // Offline / Admin SDK down → do NOT write profile ghosts to accounts.json
    throw Object.assign(new Error('service_unavailable'), { status: 503 });
  },

  async setSubscription(uid, subscription) {
    if (!isFirebaseReady()) {
      throw Object.assign(new Error('service_unavailable'), { status: 503 });
    }
    await rootRef(`users/${uid}/subscription`).set({
      ...subscription,
      updatedAt: Date.now(),
    });
    return this.get(uid);
  },

  async list(limit = 50) {
    if (!isFirebaseReady()) return {};
    const snap = await rootRef('users').limitToFirst(limit).get();
    return snap.val() || {};
  },

  async remove(uid) {
    if (isFirebaseReady()) {
      try {
        const current = await this.get(uid);
        await rootRef(`users/${uid}`).remove();
        const ek = emailKey(current?.email);
        if (ek) await rootRef(`email_users/${ek}`).remove();
        await rootRef(`accounts/${uid}`).remove().catch(() => {});
        if (ek) await rootRef(`indexes/email/${ek}`).remove().catch(() => {});
      } catch (_) {}
    }
    const store = accounts.read();
    if (store.byUid?.[uid]) {
      const a = store.byUid?.[uid];
      if (a?.email) {
        const ek = emailKey(a.email);
        delete store.byEmail[ek];
        // legacy raw-email key
        delete store.byEmail[String(a.email).toLowerCase()];
      }
      delete store.byUid[uid];
      accounts.write(store, { now: true });
    }
    return { deleted: true, uid };
  },
};
