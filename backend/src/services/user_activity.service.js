/**
 * Every app action is stored under the logged-in user's email + uid.
 * RTDB (Admin SDK) is source of truth. Local memory is only a fallback.
 *
 *   indexes/email/{emailKey} → { uid, email }
 *   users/{uid}/activities/{YYYY-MM-DD}/{id}
 *   users/{uid}/activity_last
 *   users/{uid}/state
 *   email_users/{emailKey}/activities/{YYYY-MM-DD}/{id}
 *   email_users/{emailKey}/activity_last
 *   email_users/{emailKey}/state
 */
import { isFirebaseReady, rootRef } from '../config/firebase.js';
import { hashIp } from '../middleware/client_ip.js';

const SKIP = new Set([
  'health',
  'config',
  'firebase.config',
  'actions',
  'catalog.all',
  'catalog.plans',
  'catalog.crops',
  'catalog.crop',
  'jankari.list',
  'jankari.search',
  'jankari.meta',
  'announcement.list',
  'ai.quota',
  'quota',
  'activity.log',
  'analytics.page',
  'presence.ping',
  'voice.transcribe',
]);

const SECRET = /password|otp|token|secret|idtoken|adminkey|imagebase64|audiobase64|^images$|history|authorization/i;
const KEEP_DAYS = 180;

import { emailKey as sharedEmailKey } from '../utils/email_key.js';

export function emailKey(email) {
  return sharedEmailKey(email);
}

function dayKey(d = new Date()) {
  return d.toISOString().slice(0, 10);
}

function clip(v, max = 500) {
  const s = typeof v === 'string' ? v : JSON.stringify(v ?? '');
  if (s.length <= max) return s;
  return `${s.slice(0, max)}…`;
}

function num(v) {
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

function pickDetail(data = {}, result = null) {
  const extra = data.detail && typeof data.detail === 'object' ? data.detail : {};
  const src = { ...data, ...extra };
  const out = {};
  const textKeys = ['message', 'text', 'query'];
  for (const k of textKeys) {
    if (typeof src[k] === 'string' && src[k].trim()) {
      out.sent = clip(src[k].trim(), 2000);
      break;
    }
  }
  for (const k of [
    'mode',
    'cropId',
    'sessionId',
    'chatName',
    'provider',
    'planId',
    'type',
    'name',
    'phone',
    'lang',
    'place',
    'screen',
    'filename',
  ]) {
    if (src[k] == null || SECRET.test(k)) continue;
    out[k] = typeof src[k] === 'string' ? clip(src[k], 180) : src[k];
  }
  if (src.hasImage === true || src.imageBase64) out.hasImage = true;
  if (src.deepResearch === true) out.deepResearch = true;
  const lat = num(src.lat ?? src.latitude);
  const lon = num(src.lon ?? src.longitude);
  if (lat != null && lon != null) {
    out.lat = lat;
    out.lon = lon;
  }
  if (Array.isArray(src.selectedCropIds)) {
    out.selectedCropIds = src.selectedCropIds.map((id) => String(id)).slice(0, 40);
  }
  const weather = result?.weather;
  if (weather && typeof weather === 'object') {
    if (weather.place) out.place = clip(weather.place, 120);
    const wlat = num(weather.lat);
    const wlon = num(weather.lon);
    if (wlat != null && wlon != null) {
      out.lat = wlat;
      out.lon = wlon;
    }
    if (weather.precise === false) out.precise = false;
    else if (wlat != null && wlon != null) out.precise = true;
  }
  const imageUrl = result?.meta?.imageUrl;
  if (typeof imageUrl === 'string' && imageUrl.startsWith('http')) {
    out.imageUrl = imageUrl;
    out.hasImage = true;
  }
  if (typeof result?.text === 'string' && result.text.trim()) {
    out.reply = clip(result.text.trim(), 500);
  }
  return out;
}

export const UserActivityService = {
  emailKey,

  skip(action) {
    return SKIP.has(String(action || ''));
  },

  async writeLive({
    uid = null,
    email = null,
    ip = null,
    installId = null,
    firstInstallAt = null,
    installCount = 1,
    screen = null,
  }) {
    const now = Date.now();
    const live = {
      ip: ip || null,
      at: now,
      screen: screen ? String(screen).slice(0, 40) : null,
      installId: installId ? String(installId).slice(0, 80) : null,
      firstInstallAt: Number(firstInstallAt) || null,
      installCount: Math.max(1, Number(installCount) || 1),
      email: email ? String(email).trim().toLowerCase() : null,
      uid: uid || null,
    };
    if (!isFirebaseReady()) return { ok: false };
    try {
      if (uid) {
        const prev = (await rootRef(`users/${uid}/presence/live`).get()).val() || {};
        if (live.installId && prev.installId && prev.installId !== live.installId) {
          live.installCount = Math.max(live.installCount, Number(prev.installCount) || 1) + 1;
          live.reinstallAt = now;
        } else if (prev.installCount) {
          live.installCount = Math.max(live.installCount, Number(prev.installCount) || 1);
        }
        await rootRef(`users/${uid}/presence/live`).set(live);
        await rootRef(`users/${uid}/state`).update({
          lastActivity: now,
          lastIp: ip || null,
        });
      } else if (ip) {
        await rootRef(`guests/${hashIp(ip)}/presence/live`).set(live);
      }
      return { ok: true };
    } catch (e) {
      console.warn('[activity] live skip:', e.message);
      return { ok: false };
    }
  },

  async linkEmail(email, uid) {
    const em = String(email || '').trim().toLowerCase();
    const ek = emailKey(em);
    if (!ek || !uid || !isFirebaseReady()) return;
    try {
      await rootRef(`indexes/email/${ek}`).update({
        uid,
        email: em,
        updatedAt: Date.now(),
      });
    } catch (e) {
      console.warn('[activity] email index skip:', e.message);
    }
  },

  /**
   * Current prefs snapshot — language, theme, crops, AI, last screen.
   */
  async saveState({ uid, email, patch = {} }) {
    const em = String(email || '').trim().toLowerCase();
    const ek = emailKey(em);
    if (!uid && !ek) return { ok: false };
    const next = {
      ...patch,
      email: em || patch.email || null,
      uid: uid || patch.uid || null,
      updatedAt: Date.now(),
    };
    if (!isFirebaseReady()) return { ok: false, storage: 'offline' };

    const ops = [];
    if (uid) ops.push(rootRef(`users/${uid}/state`).update(next));
    if (ek) ops.push(rootRef(`email_users/${ek}/state`).update(next));
    try {
      await Promise.all(ops);
      if (em && uid) await this.linkEmail(em, uid);
      return { ok: true, storage: 'rtdb' };
    } catch (e) {
      console.warn('[activity] state skip:', e.message);
      return { ok: false, error: e.message };
    }
  },

  /**
   * One row per small activity, keyed by email + uid.
   */
  async record({
    uid = null,
    email = null,
    ip = null,
    action,
    type = null,
    data = {},
    result = null,
    ok = true,
    error = null,
  }) {
    const act = String(type || action || '').trim();
    if (!act || this.skip(act)) return { skipped: true };

    const em = String(email || '').trim().toLowerCase();
    const ek = emailKey(em);
    if (!uid && !ek) return { skipped: true, reason: 'no_user' };

    const now = Date.now();
    const day = dayKey(new Date(now));
    const id = `a_${now}_${Math.random().toString(36).slice(2, 8)}`;
    const row = {
      id,
      action: act,
      email: em || null,
      uid: uid || null,
      ipHash: ip ? hashIp(ip) : null,
      ip: ip || null,
      ok: Boolean(ok),
      error: error ? clip(error, 180) : null,
      detail: pickDetail(data, result),
      day,
      ts: now,
      at: new Date(now).toISOString(),
    };

    if (!isFirebaseReady()) {
      console.warn('[activity] RTDB offline — activity not durable', act);
      return { ok: false, storage: 'offline', id };
    }

    const ops = [];
    if (uid) {
      ops.push(rootRef(`users/${uid}/activities/${day}/${id}`).set(row));
      ops.push(
        rootRef(`users/${uid}/activity_last`).set({
          action: act,
          email: em || null,
          ts: now,
          day,
        }),
      );
    }
    if (ek) {
      ops.push(rootRef(`email_users/${ek}/activities/${day}/${id}`).set(row));
      ops.push(
        rootRef(`email_users/${ek}/activity_last`).set({
          action: act,
          uid: uid || null,
          ts: now,
          day,
        }),
      );
    }

    try {
      await Promise.all(ops);
      await this._touchDaily({ uid, ek, em, row });
      if (em && uid) await this.linkEmail(em, uid);
      this._pruneOld(uid, ek, day).catch(() => {});
      return { ok: true, storage: 'rtdb', id, day };
    } catch (e) {
      console.warn('[activity] write skip:', e.message);
      return { ok: false, error: e.message };
    }
  },

  async _touchDaily({ uid, ek, em, row }) {
    const bases = [];
    if (uid) bases.push(`users/${uid}`);
    if (ek) bases.push(`email_users/${ek}`);
    const place = row.detail?.place || null;
    const lat = row.detail?.lat ?? null;
    const lon = row.detail?.lon ?? null;
    const login = /^auth\.(login|google|register|otp\.verify)$/.test(row.action);
    for (const base of bases) {
      const dayRef = rootRef(`${base}/presence/${row.day}`);
      const prev = (await dayRef.get()).val() || {};
      const keepPlace = row.detail?.precise !== false;
      await dayRef.update({
        day: row.day,
        email: em || prev.email || null,
        uid: row.uid || prev.uid || null,
        firstAt: prev.firstAt || row.at,
        lastAt: row.at,
        lastAction: row.action,
        hits: (Number(prev.hits) || 0) + 1,
        ...(keepPlace && place ? { place } : {}),
        ...(keepPlace && lat != null ? { lat, lon } : {}),
      });
      if (lat != null && lon != null && row.detail?.precise !== false) {
        await rootRef(`${base}/location`).set({
          lat,
          lon,
          place,
          precise: true,
          at: row.at,
          ts: row.ts,
        });
      }
      if (login && row.ok) {
        await rootRef(`${base}/last_login`).set({
          at: row.at,
          ts: row.ts,
          action: row.action,
          email: em || null,
          uid: row.uid || null,
          ipHash: row.ipHash,
          ip: row.ip || null,
          place,
          lat,
          lon,
        });
      }
    }
  },

  async _pruneOld(uid, ek, today) {
    if (!isFirebaseReady()) return;
    const cutoff = Date.now() - KEEP_DAYS * 86400000;
    const cutoffDay = dayKey(new Date(cutoff));
    const bases = [];
    if (uid) bases.push(`users/${uid}/activities`);
    if (ek) bases.push(`email_users/${ek}/activities`);
    for (const base of bases) {
      try {
        const snap = await rootRef(base).limitToFirst(8).get();
        const days = Object.keys(snap.val() || {});
        for (const d of days) {
          if (d < cutoffDay && d !== today) {
            await rootRef(`${base}/${d}`).remove();
          }
        }
      } catch (_) {}
    }
  },
};
