import { rootRef, isFirebaseReady } from '../config/firebase.js';
import { emailKey } from './user_activity.service.js';

export const TrackService = {
  async list(uid) {
    if (!isFirebaseReady()) return {};
    const snap = await rootRef(`users/${uid}/tracks`).get();
    return snap.val() || {};
  },

  async save(uid, trackId, track, { email = null } = {}) {
    if (!isFirebaseReady()) {
      throw Object.assign(new Error('service_unavailable'), { status: 503 });
    }
    const em = String(email || track?.email || '').trim().toLowerCase();
    const row = {
      ...track,
      uid,
      email: em || null,
      updatedAt: Date.now(),
    };
    await rootRef(`users/${uid}/tracks/${trackId}`).set(row);
    const ek = emailKey(em);
    if (ek) {
      await rootRef(`email_users/${ek}/tracks/${trackId}`).set(row);
    }
    const snap = await rootRef(`users/${uid}/tracks/${trackId}`).get();
    return snap.val();
  },

  async saveLog(uid, trackId, dateKey, log, { email = null } = {}) {
    if (!isFirebaseReady()) {
      throw Object.assign(new Error('service_unavailable'), { status: 503 });
    }
    const em = String(email || log?.email || '').trim().toLowerCase();
    const row = {
      ...log,
      dateKey,
      uid,
      email: em || null,
      updatedAt: Date.now(),
    };
    await rootRef(`users/${uid}/tracks/${trackId}/logs/${dateKey}`).set(row);
    const ek = emailKey(em);
    if (ek) {
      await rootRef(`email_users/${ek}/tracks/${trackId}/logs/${dateKey}`).set(row);
    }
    const snap = await rootRef(`users/${uid}/tracks/${trackId}/logs/${dateKey}`).get();
    return snap.val();
  },

  async remove(uid, trackId) {
    if (!isFirebaseReady()) {
      throw Object.assign(new Error('service_unavailable'), { status: 503 });
    }
    await rootRef(`users/${uid}/tracks/${trackId}`).remove();
    return { deleted: true, trackId };
  },
};
