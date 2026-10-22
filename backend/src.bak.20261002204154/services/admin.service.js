import { rootRef, isFirebaseReady } from '../config/firebase.js';

export const AdminService = {
  async getUnlock(uid) {
    if (!isFirebaseReady()) return { unlocked: false };
    const snap = await rootRef(`admin_unlocks/${uid}`).get();
    return snap.val();
  },

  async grantUnlock(uid, { amount = 2999, note = '' } = {}) {
    if (!isFirebaseReady()) {
      throw Object.assign(new Error('service_unavailable'), { status: 503 });
    }
    const payload = {
      unlocked: true,
      amount,
      note,
      paidAt: Date.now(),
      grantedBy: 'backend',
    };
    await rootRef(`admin_unlocks/${uid}`).set(payload);
    return payload;
  },

  async revokeUnlock(uid) {
    if (!isFirebaseReady()) {
      throw Object.assign(new Error('service_unavailable'), { status: 503 });
    }
    await rootRef(`admin_unlocks/${uid}`).set({
      unlocked: false,
      revokedAt: Date.now(),
    });
    return { unlocked: false };
  },
};
