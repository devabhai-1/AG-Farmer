import { isFirebaseReady, rootRef } from '../config/firebase.js';
import { sanitizeForRtdb } from '../utils/rtdb_safe.js';

export async function rtdbGet(path) {
  if (!isFirebaseReady()) return null;
  try {
    const snap = await rootRef(path).get();
    return snap.exists() ? snap.val() : null;
  } catch (err) {
    console.warn('[rtdb-system] get skip', path, err?.message || 'get');
    return null;
  }
}

export async function rtdbSet(path, data) {
  if (!isFirebaseReady()) return false;
  try {
    const clean = sanitizeForRtdb(data);
    if (clean === undefined) return false;
    await rootRef(path).set(clean);
    return true;
  } catch (err) {
    console.warn('[rtdb-system] set skip', path, err?.message || 'set');
    return false;
  }
}

export function rtdbPush(path, data) {
  rtdbSet(path, data).catch(() => {});
}
