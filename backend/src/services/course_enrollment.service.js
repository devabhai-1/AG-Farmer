import { rootRef, isFirebaseReady } from '../config/firebase.js';

function cropKey(raw) {
  return String(raw || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_-]/g, '_')
    .replace(/_+/g, '_')
    .slice(0, 48);
}

function rowOf(cropId, data) {
  const started = Date.parse(data?.startedAt) || Date.now();
  const ended = data?.endedAt ? Date.parse(data.endedAt) : null;
  return {
    cropId,
    nameEn: String(data?.nameEn || cropId).slice(0, 80),
    nameHi: String(data?.nameHi || data?.nameEn || cropId).slice(0, 80),
    emoji: String(data?.emoji || '🌾').slice(0, 8),
    startedAt: new Date(started).toISOString(),
    endedAt: ended && Number.isFinite(ended) ? new Date(ended).toISOString() : null,
    pendingAdminClose: data?.pendingAdminClose === true,
    updatedAt: Date.now(),
  };
}

/** Course enrollment lives on the account, not on the phone. */
export const CourseEnrollmentService = {
  async list(uid) {
    if (!uid || !isFirebaseReady()) return {};
    const snap = await rootRef(`users/${uid}/courses`).get();
    return snap.val() || {};
  },

  async save(uid, data) {
    if (!uid || !isFirebaseReady()) {
      throw Object.assign(new Error('service_unavailable'), { status: 503 });
    }
    const cropId = cropKey(data?.cropId);
    if (!cropId) throw Object.assign(new Error('crop_required'), { status: 400 });
    const row = rowOf(cropId, data);
    await rootRef(`users/${uid}/courses/${cropId}`).set(row);
    return row;
  },

  async markSeen(uid, cropIdRaw, day) {
    if (!uid || !isFirebaseReady()) {
      throw Object.assign(new Error('service_unavailable'), { status: 503 });
    }
    const cropId = cropKey(cropIdRaw);
    if (!cropId) throw Object.assign(new Error('crop_required'), { status: 400 });
    const seenDay = String(day || '').slice(0, 10);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(seenDay)) {
      throw Object.assign(new Error('bad_day'), { status: 400 });
    }
    await rootRef(`users/${uid}/course_seen/${cropId}`).set(seenDay);
    return { ok: true, cropId, day: seenDay };
  },

  async remove(uid, cropIdRaw) {
    if (!uid || !isFirebaseReady()) {
      throw Object.assign(new Error('service_unavailable'), { status: 503 });
    }
    const cropId = cropKey(cropIdRaw);
    if (!cropId) throw Object.assign(new Error('crop_required'), { status: 400 });
    await rootRef(`users/${uid}/courses/${cropId}`).remove();
    return { deleted: true, cropId };
  },
};
