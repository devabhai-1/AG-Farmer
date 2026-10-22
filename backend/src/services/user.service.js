import path from 'path';
import { fileURLToPath } from 'url';
import { auth, rootRef, isFirebaseReady } from '../config/firebase.js';
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

function mobileDigits(phone) {
  const digits = String(phone || '').replace(/\D/g, '');
  if (digits.length === 12 && digits.startsWith('91')) return digits.slice(2);
  if (digits.length === 11 && digits.startsWith('0')) return digits.slice(1);
  return digits.length === 10 ? digits : '';
}

function activeSubscription(sub) {
  if (!sub || typeof sub !== 'object') return null;
  const status = String(sub.status || '').toLowerCase();
  if (status === 'cleared' || status === 'expired' || status === 'cancelled') return null;
  if (sub.active === false) return null;
  const id = String(sub.planId || sub.plan || sub.id || '');
  if (!id || id === 'free') return null;
  if (sub.expiresAt) {
    const t = typeof sub.expiresAt === 'number' ? sub.expiresAt : Date.parse(sub.expiresAt);
    if (Number.isFinite(t) && t < Date.now()) return null;
  }
  return sub;
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
        const rawSub = subscription.exists() ? subscription.val() : p.subscription || null;
        const liveSub = activeSubscription(rawSub);
        const planId = liveSub
          ? String(liveSub.planId || liveSub.plan || liveSub.id)
          : 'free';

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
          plan: planId,
          acceptedPolicy: p.acceptedPolicy !== false,
          profileComplete:
            p.profileComplete === false
              ? false
              : mobileDigits(p.phone || acct?.phone).length === 10,
          subscription: liveSub,
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

  /**
   * Paid access comes only from an active subscription written by payment.
   * A missing user, a lookup error, or a client-sent plan name is free.
   */
  async effectivePlanId(uid) {
    if (!uid) return 'free';
    try {
      const user = await this.get(uid);
      const sub = user?.subscription;
      if (!sub || typeof sub !== 'object') return 'free';
      const id = String(sub.planId || sub.plan || sub.id || '').trim();
      if (!id || id.toLowerCase() === 'free') return 'free';
      return id;
    } catch (e) {
      console.warn('[plan] resolve failed:', e.message);
      return 'free';
    }
  },

  async update(uid, patch, { email = null } = {}) {
    const now = Date.now();
    const safe = { ...patch };
    for (const key of [
      'plan',
      'planId',
      'subscription',
      'expiresAt',
      'autoRenew',
      'razorpaySubscriptionId',
    ]) {
      delete safe[key];
    }
    const next = { ...safe, updatedAt: now };

    if (isFirebaseReady()) {
      const current = await this.get(uid);
      const em = String(email || current?.email || '').trim().toLowerCase();
      const ek = emailKey(em);

      const statePatch = {};
      for (const k of ['language', 'theme', 'aiProvider', 'selectedCropIds']) {
        if (safe[k] !== undefined) statePatch[k] = safe[k];
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
    const now = Date.now();
    const planId = subscription.planId || 'free';
    const clean = {};
    for (const [key, value] of Object.entries(subscription)) {
      if (value !== null && value !== undefined) clean[key] = value;
    }
    await Promise.all([
      rootRef(`users/${uid}/subscription`).set({
        ...clean,
        updatedAt: now,
      }),
      rootRef(`users/${uid}/profile`).update({
        plan: planId,
        updatedAt: now,
      }),
      rootRef(`users/${uid}/state`).update({
        plan: planId,
        planId,
        lastActivity: now,
      }),
    ]);
    return this.get(uid);
  },

  async list(limit = 50) {
    const cap = Math.max(1, Math.min(200, Number(limit) || 50));
    const store = accounts.read();
    const fromFile = Object.entries(store.byUid || {});
    const out = {};

    const putSlim = (uid, extra = {}) => {
      if (!uid || out[uid]) return;
      const a = store.byUid?.[uid] || {};
      out[uid] = {
        uid,
        email: extra.email || a.email || '',
        name: extra.name || '',
        plan: extra.plan || 'free',
        lastActivity: extra.lastActivity || null,
        provider: extra.provider || a.provider || 'email',
        subscription: extra.subscription || null,
      };
    };

    if (isFirebaseReady()) {
      let extraUids = [];
      try {
        const idx = await rootRef('indexes/email').limitToFirst(cap).get();
        extraUids = Object.values(idx.val() || {})
          .map((row) => row?.uid)
          .filter(Boolean);
      } catch {
        extraUids = [];
      }
      const uids = [...new Set([...fromFile.map(([uid]) => uid), ...extraUids])].slice(0, cap);
      await Promise.all(
        uids.map(async (uid) => {
          try {
            const [profile, subscription, state] = await Promise.all([
              rootRef(`users/${uid}/profile`).get(),
              rootRef(`users/${uid}/subscription`).get(),
              rootRef(`users/${uid}/state`).get(),
            ]);
            const p = profile.val() || {};
            const st = state.val() || {};
            const rawSub = subscription.val() || p.subscription || null;
            const liveSub = activeSubscription(rawSub);
            putSlim(uid, {
              email: p.email,
              name: p.name || '',
              plan: liveSub
                ? String(liveSub.planId || liveSub.plan || liveSub.id)
                : String(p.plan || st.plan || 'free'),
              lastActivity: st.lastActivity || null,
              provider: p.provider,
              subscription: liveSub,
            });
          } catch {
            putSlim(uid);
          }
        }),
      );
      return out;
    }

    fromFile.slice(0, cap).forEach(([uid]) => putSlim(uid));
    return out;
  },

  /**
   * Mark the account for deletion. Data stays in Firebase for 30 days,
   * then purgeDue removes it. The email stays taken until that purge.
   */
  async scheduleDelete(uid) {
    const now = Date.now();
    const purgeAt = now + 30 * 24 * 60 * 60 * 1000;
    const store = accounts.read();
    const row = store.byUid?.[uid] || null;
    const email = row?.email || null;
    if (row) {
      row.pendingDeletion = true;
      row.deletionRequestedAt = now;
      row.purgeAt = purgeAt;
      store.byUid[uid] = row;
      const ek = emailKey(email);
      if (ek && store.byEmail?.[ek]) {
        store.byEmail[ek].pendingDeletion = true;
        store.byEmail[ek].purgeAt = purgeAt;
      }
      accounts.write(store, { now: true });
    }

    if (isFirebaseReady()) {
      await rootRef(`users/${uid}/profile`)
        .update({
          accountStatus: 'pending_deletion',
          deletionRequestedAt: now,
          purgeAt,
        })
        .catch((e) => console.warn('[account-delete] profile mark skip', e.message));
      await rootRef(`system/pending_deletions/${uid}`)
        .set({
          uid,
          email: email || null,
          requestedAt: now,
          purgeAt,
        })
        .catch((e) => console.warn('[account-delete] queue skip', e.message));
      try {
        const a = auth();
        const fbUid = row?.firebaseUid || uid;
        try {
          await a.updateUser(fbUid, { disabled: true });
        } catch (e) {
          if (!email) throw e;
          const found = await a.getUserByEmail(email);
          await a.updateUser(found.uid, { disabled: true });
        }
      } catch (e) {
        console.warn('[account-delete] auth disable skip', e.message);
      }
    }

    return { scheduled: true, retainDays: 30, purgeAt, uid };
  },

  /** Delete accounts whose 30-day hold has ended. */
  async purgeDue() {
    const now = Date.now();
    const due = new Set();
    const store = accounts.read();
    for (const [uid, row] of Object.entries(store.byUid || {})) {
      if (row?.pendingDeletion && Number(row.purgeAt || 0) <= now) due.add(uid);
    }
    if (isFirebaseReady()) {
      try {
        const snap = await rootRef('system/pending_deletions').get();
        for (const [uid, row] of Object.entries(snap.val() || {})) {
          if (Number(row?.purgeAt || 0) <= now) due.add(uid);
        }
      } catch (e) {
        console.warn('[account-purge] queue read skip', e.message);
      }
    }

    let purged = 0;
    for (const uid of due) {
      const row = store.byUid?.[uid];
      const email = row?.email || null;
      const fbUid = row?.firebaseUid || uid;
      await this.remove(uid);
      if (isFirebaseReady()) {
        try {
          await auth().deleteUser(fbUid);
        } catch (e) {
          if (email) {
            try {
              const found = await auth().getUserByEmail(email);
              await auth().deleteUser(found.uid);
            } catch {
              /* auth user already gone */
            }
          }
        }
        await rootRef(`system/pending_deletions/${uid}`).remove().catch(() => {});
      }
      purged += 1;
    }
    if (purged) console.log(`[account-purge] removed ${purged}`);
    return { purged };
  },

  async remove(uid) {
    if (isFirebaseReady()) {
      try {
        const current = await this.get(uid);
        // Chat, course threads, and course enrollment stay on Firebase.
        const keep = new Set(['ai', 'courses']);
        const userSnap = await rootRef(`users/${uid}`).get();
        const userKeys = Object.keys(userSnap.val() || {}).filter((k) => !keep.has(k));
        await Promise.all(userKeys.map((k) => rootRef(`users/${uid}/${k}`).remove()));
        const ek = emailKey(current?.email);
        if (ek) {
          const emailSnap = await rootRef(`email_users/${ek}`).get();
          const emailKeys = Object.keys(emailSnap.val() || {}).filter((k) => k !== 'ai');
          await Promise.all(
            emailKeys.map((k) => rootRef(`email_users/${ek}/${k}`).remove()),
          );
        }
        await rootRef(`accounts/${uid}`).remove().catch(() => {});
        if (ek) await rootRef(`indexes/email/${ek}`).remove().catch(() => {});
      } catch (e) {
        console.warn('[account-delete] profile wipe skipped', e.message);
      }
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

let purgeTimer = null;
export function startAccountPurge() {
  if (purgeTimer) return;
  const run = () => {
    UserService.purgeDue().catch((e) => {
      console.warn('[account-purge] run skip', e.message);
    });
  };
  purgeTimer = setInterval(run, 60 * 60 * 1000);
  purgeTimer.unref();
  setTimeout(run, 20000).unref();
  console.log('[account-purge] scheduler on — 30 day hold');
}
