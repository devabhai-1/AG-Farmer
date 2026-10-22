import { rootRef, isFirebaseReady } from '../config/firebase.js';
import { parseGeo } from '../utils/geo.js';

/** Photo + lat/lng live only under that user's box. Never email/IP boxes. */
export const ImageGeoService = {
  async savedFix(uid) {
    if (!uid || !isFirebaseReady()) return null;
    try {
      const val = (await rootRef(`users/${uid}/location`).get()).val();
      if (!val || val.precise === false) return null;
      return parseGeo(val.lat, val.lon);
    } catch {
      return null;
    }
  },

  async record({ uid, url, objectPath, lat, lon, mode = 'chat', kind = 'chat' }) {
    if (!uid || !isFirebaseReady()) return null;
    const geo = parseGeo(lat, lon);
    const ref = rootRef(`users/${uid}/media/images`).push();
    const row = {
      id: ref.key,
      url: url || null,
      objectPath: objectPath || null,
      mode: String(mode || 'chat'),
      kind: String(kind || 'chat'),
      createdAt: new Date().toISOString(),
      ts: Date.now(),
      ...(geo || {}),
    };
    await ref.set(row);
    return row;
  },
};
