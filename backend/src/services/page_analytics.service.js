import { isFirebaseReady, rootRef } from '../config/firebase.js';
import { hashIp } from '../middleware/client_ip.js';

function dayKey(d = new Date()) {
  return d.toISOString().slice(0, 10);
}

function slug(raw, fallback = 'unknown') {
  const s = String(raw || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_-]+/g, '_')
    .replace(/_+/g, '_')
    .replace(/^_|_$/g, '')
    .slice(0, 40);
  return s || fallback;
}

function whoKey({ uid, ip }) {
  const u = String(uid || '').trim();
  if (/^[A-Za-z0-9_-]{6,128}$/.test(u)) return `u_${u}`;
  if (u) return `u_${slug(u, 'user')}`;
  return `g_${hashIp(ip || '0.0.0.0').slice(0, 24)}`;
}

async function inc(path) {
  if (!isFirebaseReady()) return;
  await rootRef(path).transaction((cur) => (Number(cur) || 0) + 1);
}

async function patch(path, data) {
  if (!isFirebaseReady()) return;
  await rootRef(path).update(data);
}

export const PageAnalyticsService = {
  async hit({ page, extra = null, uid = null, ip = null }) {
    const pageId = slug(page);
    if (pageId === 'unknown') return { ok: false };
    const who = whoKey({ uid, ip });
    const day = dayKey();
    const now = Date.now();
    const extraId = extra ? slug(extra, '') : '';

    const jobs = [
      inc(`analytics/pages/${pageId}/visits`),
      inc(`analytics/pages/${pageId}/byUser/${who}`),
      inc(`analytics/daily/${day}/pages/${pageId}/visits`),
      inc(`analytics/daily/${day}/pages/${pageId}/byUser/${who}`),
      inc('analytics/summary/totalVisits'),
      inc(`analytics/daily/${day}/totalVisits`),
      patch(`analytics/pages/${pageId}/meta`, { lastAt: now, lastWho: who, page: pageId }),
      patch('analytics/summary', { lastAt: now, lastPage: pageId, lastWho: who }),
    ];

    if (extraId) {
      jobs.push(inc(`analytics/pages/${pageId}/extras/${extraId}`));
      jobs.push(inc(`analytics/daily/${day}/pages/${pageId}/extras/${extraId}`));
    }

    if (uid) {
      jobs.push(inc(`users/${uid}/analytics/pages/${pageId}/visits`));
      jobs.push(
        patch(`users/${uid}/analytics/pages/${pageId}`, {
          lastAt: now,
          page: pageId,
          ...(extraId ? { lastExtra: extraId } : {}),
        }),
      );
      jobs.push(inc(`users/${uid}/analytics/summary/totalVisits`));
      jobs.push(
        patch(`users/${uid}/analytics/summary`, {
          lastPage: pageId,
          lastAt: now,
          ...(extraId ? { lastExtra: extraId } : {}),
        }),
      );
    }

    await Promise.all(jobs.map((p) => p.catch(() => {})));
    return { ok: true, page: pageId, who, day };
  },

  /** Local admin only — page totals, never per-user AI threads. */
  async adminSnapshot() {
    if (!isFirebaseReady()) return { pages: {}, summary: {}, daily: {} };
    const [pagesSnap, summarySnap, dailySnap] = await Promise.all([
      rootRef('analytics/pages').get(),
      rootRef('analytics/summary').get(),
      rootRef('analytics/daily').get(),
    ]);
    const raw = pagesSnap.val() || {};
    const pages = {};
    for (const [id, row] of Object.entries(raw)) {
      if (!row || typeof row !== 'object') continue;
      pages[id] = {
        visits: Number(row.visits) || 0,
        extras: row.extras && typeof row.extras === 'object' ? row.extras : {},
        lastAt: row.meta?.lastAt || null,
        page: row.meta?.page || id,
      };
    }
    const dailyRaw = dailySnap.val() || {};
    const daily = {};
    for (const [day, row] of Object.entries(dailyRaw)) {
      daily[day] = { totalVisits: Number(row?.totalVisits) || 0 };
    }
    return {
      pages,
      summary: summarySnap.val() || {},
      daily,
    };
  },
};
