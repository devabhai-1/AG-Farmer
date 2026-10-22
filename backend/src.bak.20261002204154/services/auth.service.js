import { auth, isFirebaseReady, rootRef } from '../config/firebase.js';
import { env } from '../config/env.js';

function normalizePhone(raw) {
  if (!raw) return null;
  let p = String(raw).trim().replace(/[\s\-()]/g, '');
  if (p.startsWith('00')) p = `+${p.slice(2)}`;
  if (/^\d{10}$/.test(p)) p = `${env.defaultCountryCode}${p}`;
  if (!p.startsWith('+')) p = `${env.defaultCountryCode}${p.replace(/^\+/, '')}`;
  if (!/^\+[1-9]\d{7,14}$/.test(p)) return null;
  return p;
}

export const AuthPhoneService = {
  normalizePhone,

  /** After Flutter phone OTP — verify ID token and sync RTDB profile */
  async verifyIdToken(idToken) {
    if (!isFirebaseReady()) throw new Error('service_unavailable');
    if (!idToken) throw new Error('idToken required');

    const decoded = await auth().verifyIdToken(idToken, true);
    const user = await auth().getUser(decoded.uid);

    const phone = user.phoneNumber || null;
    if (env.phoneAuthEnabled && !phone && !user.email) {
      // allow other providers, but prefer phone for this app
    }

    const profile = await this.ensureUserProfile(user);
    return {
      uid: user.uid,
      phone: user.phoneNumber || null,
      email: user.email || null,
      name: user.displayName || profile?.name || '',
      providers: user.providerData.map((p) => p.providerId),
      profile,
      tokenClaims: {
        authTime: decoded.auth_time,
        exp: decoded.exp,
      },
    };
  },

  async lookupByPhone(phoneRaw) {
    if (!isFirebaseReady()) throw new Error('service_unavailable');
    const phone = normalizePhone(phoneRaw);
    if (!phone) throw new Error('Invalid phone. Use +91XXXXXXXXXX');

    try {
      const user = await auth().getUserByPhoneNumber(phone);
      return {
        exists: true,
        uid: user.uid,
        phone: user.phoneNumber,
        name: user.displayName || '',
        disabled: user.disabled,
      };
    } catch (err) {
      if (err.code === 'auth/user-not-found') {
        return { exists: false, phone };
      }
      throw err;
    }
  },

  /** Create Auth user by phone if missing (Admin). OTP still happens on client. */
  async ensurePhoneUser(phoneRaw, { name = '' } = {}) {
    if (!isFirebaseReady()) throw new Error('service_unavailable');
    if (!env.phoneAuthEnabled) throw new Error('Phone auth disabled in .env');

    const phone = normalizePhone(phoneRaw);
    if (!phone) throw new Error('Invalid phone. Use +91XXXXXXXXXX');

    let user;
    try {
      user = await auth().getUserByPhoneNumber(phone);
    } catch (err) {
      if (err.code !== 'auth/user-not-found') throw err;
      user = await auth().createUser({
        phoneNumber: phone,
        displayName: name || undefined,
      });
    }

    if (name && user.displayName !== name) {
      user = await auth().updateUser(user.uid, { displayName: name });
    }

    const profile = await this.ensureUserProfile(user);
    const customToken = await auth().createCustomToken(user.uid, { phone });

    return {
      uid: user.uid,
      phone: user.phoneNumber,
      name: user.displayName || '',
      profile,
      customToken,
    };
  },

  async ensureUserProfile(user) {
    const ref = rootRef(`users/${user.uid}`);
    const snap = await ref.get();
    const now = Date.now();
    const phone = user.phoneNumber || '';

    if (snap.exists()) {
      const current = snap.val() || {};
      const patch = {
        updatedAt: now,
        phone: phone || current.phone || '',
        email: user.email || current.email || '',
        name: user.displayName || current.name || '',
        provider: phone ? 'phone' : current.provider || 'email',
      };
      await ref.update(patch);
      return { ...(typeof current === 'object' ? current : {}), ...patch, uid: user.uid };
    }

    const created = {
      uid: user.uid,
      name: user.displayName || '',
      email: user.email || '',
      phone,
      provider: phone ? 'phone' : 'email',
      profileComplete: Boolean(phone && user.displayName),
      plan: 'free',
      createdAt: now,
      updatedAt: now,
    };
    await ref.set(created);
    return created;
  },

  async revokeSessions(uid) {
    if (!isFirebaseReady()) throw new Error('service_unavailable');
    await auth().revokeRefreshTokens(uid);
    return { uid, revoked: true };
  },
};
