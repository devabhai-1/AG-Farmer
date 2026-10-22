/**
 * Every day at 12:00 noon Asia/Kolkata, append one Hindi summary as the
 * last course-chat message for that morning's work, and push a notification
 * when the phone has registered an FCM token.
 *
 * Idempotent: days/{YYYY-MM-DD}/messages/summary_{day} is written once.
 */
import admin from 'firebase-admin';
import { isFirebaseReady, rootRef } from '../config/firebase.js';
import { emailKey } from '../utils/email_key.js';
import { crops } from '../../seed/crops.js';

const IST_OFFSET_MS = (5 * 60 + 30) * 60 * 1000;

let timer = null;
let ticking = false;
let finishedDay = '';

export function istParts(now = new Date()) {
  const shifted = new Date(now.getTime() + IST_OFFSET_MS);
  return {
    day: shifted.toISOString().slice(0, 10),
    hour: shifted.getUTCHours(),
    minute: shifted.getUTCMinutes(),
  };
}

function clip(text, max) {
  const s = String(text || '').replace(/\s+/g, ' ').trim();
  if (s.length <= max) return s;
  return `${s.slice(0, max)}…`;
}

function cropLabel(threadId, meta) {
  const cropId = String(meta?.cropId || threadId || '').replace(/^course_/, '');
  const known = crops[cropId];
  if (known?.nameHi) return known.nameHi;
  const raw = String(meta?.name || '').replace(/^Course\s+/i, '').trim();
  return raw || cropId || 'कोर्स';
}

function messageTime(m) {
  const ts = Number(m?.ts);
  if (Number.isFinite(ts) && ts > 0) return ts;
  const parsed = Date.parse(m?.createdAt || '');
  return Number.isFinite(parsed) ? parsed : 0;
}

function istDayOf(ms) {
  if (!ms) return '';
  return new Date(ms + IST_OFFSET_MS).toISOString().slice(0, 10);
}

function isSummary(m) {
  const id = String(m?.id || '');
  return id.startsWith('summary_') || m?.kind === 'daily_summary';
}

function collectTodayWork(thread, day) {
  const days = thread?.days || {};
  const items = [];
  for (const bucket of Object.values(days)) {
    const msgs = bucket?.messages || {};
    for (const m of Object.values(msgs)) {
      if (!m || isSummary(m)) continue;
      const role = m.role === 'assistant' || m.role === 'bot' ? 'assistant' : 'user';
      const when = messageTime(m);
      const onDay = istDayOf(when) || String(m.day || '');
      if (onDay !== day) continue;
      items.push({ ...m, role, ts: when });
    }
  }
  items.sort((a, b) => (a.ts || 0) - (b.ts || 0));
  return items;
}

function mainLine(text, max = 160) {
  const s = clip(text, 500);
  if (!s || s === 'फोटो') return '';
  const sentence = s.split(/(?<=[।.!?])\s/)[0] || s;
  return clip(sentence, max);
}

function buildSummary(cropName, items) {
  const pairs = [];
  let open = null;
  const flush = () => {
    if (!open) return;
    if (open.input || open.output) pairs.push(open);
    open = null;
  };
  for (const m of items) {
    const hasPhoto = Boolean(m.imageUrl || m.imagePath || m.mediaType === 'image');
    if (m.role === 'user') {
      flush();
      const said = mainLine(m.text, 120);
      const input = said
        ? (hasPhoto ? `${said} · फोटो` : said)
        : (hasPhoto ? 'फोटो भेजी' : '');
      open = { input, output: '' };
      continue;
    }
    if (!open || open.output) continue;
    open.output = mainLine(m.text, 180);
  }
  flush();
  const kept = pairs.filter((p) => p.input || p.output).slice(0, 5);
  if (!kept.length) return '';
  const blocks = kept.map((p, i) => {
    const lines = [`${i + 1}.`];
    if (p.input) lines.push(`इनपुट: ${p.input}`);
    lines.push(`आउटपुट: ${p.output || 'जवाब नहीं आया'}`);
    return lines.join('\n');
  });
  return [`आज का सारांश — ${cropName}`, ...blocks].join('\n\n').slice(0, 1800);
}

async function writeSummary(bases, threadId, day, message) {
  const id = message.id;
  await Promise.all(
    bases.map(async (base) => {
      await rootRef(
        `${base}/threads/${threadId}/days/${day}/messages/${id}`,
      ).set(message);
      await rootRef(
        `${base}/threads/${threadId}/days/${day}/dailySummarySent`,
      ).set(true);
    }),
  );
}

async function pushSummary({ token, title, body, cropId, day }) {
  if (!token) return false;
  try {
    await admin.messaging().send({
      token: String(token),
      notification: { title, body: clip(body, 180) },
      data: {
        type: 'course_summary',
        cropId: String(cropId || ''),
        day: String(day),
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'ag_course_summary',
          sound: 'default',
        },
      },
    });
    return true;
  } catch (err) {
    const code = String(err?.code || err?.message || '');
    if (
      code.includes('registration-token-not-registered') ||
      code.includes('invalid-registration-token')
    ) {
      return 'drop';
    }
    console.warn('[course-summary] push failed');
    return false;
  }
}

async function deliverForUser(uid, user, day) {
  const threads = user?.ai?.threads || {};
  const token = user?.fcmToken || user?.notify?.token || '';
  let sent = 0;
  let dropToken = false;

  for (const [threadId, thread] of Object.entries(threads)) {
    if (!String(threadId).startsWith('course_') || !thread) continue;
    const existing = thread?.days?.[day]?.messages?.[`summary_${day}`];
    if (existing) continue;

    const work = collectTodayWork(thread, day);
    const meta = thread.meta || {};
    const cropId = String(meta.cropId || threadId.replace(/^course_/, ''));
    const label = cropLabel(threadId, meta);
    const text = buildSummary(label, work);
    if (!text) continue;

    const now = Date.now();
    const message = {
      id: `summary_${day}`,
      role: 'assistant',
      text,
      createdAt: new Date(now).toISOString(),
      ts: now,
      day,
      cropTag: cropId,
      kind: 'daily_summary',
      label: 'आज का सारांश',
    };

    const bases = [`users/${uid}/ai`];
    const email = meta.email || user.email || user.profile?.email || '';
    const ek = email ? emailKey(email) : '';
    if (ek) bases.push(`email_users/${ek}/ai`);

    await writeSummary(bases, threadId, day, message);
    sent += 1;

    const pushed = await pushSummary({
      token,
      title: `आज का सारांश — ${label}`,
      body: text,
      cropId,
      day,
    });
    if (pushed === 'drop') dropToken = true;
  }

  if (dropToken) {
    try {
      await rootRef(`users/${uid}/fcmToken`).remove();
    } catch {
      /* ignore */
    }
  }
  return sent;
}

export async function runCourseDailySummaries(day) {
  if (!isFirebaseReady()) return { ok: false, sent: 0 };
  let sent = 0;
  let cursor = '';
  const pageSize = 15;
  for (;;) {
    let query = rootRef('users').orderByKey().limitToFirst(pageSize);
    if (cursor) {
      query = rootRef('users').orderByKey().startAfter(cursor).limitToFirst(pageSize);
    }
    const snap = await query.get();
    if (!snap.exists()) break;
    const page = snap.val() || {};
    const uids = Object.keys(page);
    if (!uids.length) break;
    for (const uid of uids) {
      const user = page[uid];
      if (!user) continue;
      try {
        sent += await deliverForUser(uid, user, day);
      } catch {
        console.warn('[course-summary] user skipped');
      }
      await new Promise((resolve) => setImmediate(resolve));
    }
    cursor = uids[uids.length - 1];
    if (uids.length < pageSize) break;
  }
  console.log(`[course-summary] ${day} sent=${sent}`);
  return { ok: true, sent, day };
}

async function claimDay(day) {
  const ref = rootRef(`system/course_daily_summary/${day}`);
  const tx = await ref.transaction((cur) => {
    if (cur && cur.done) return;
    if (
      cur &&
      cur.startedAt &&
      !cur.error &&
      Date.now() - Number(cur.startedAt) < 10 * 60 * 1000
    ) {
      return;
    }
    return { done: false, startedAt: Date.now() };
  });
  return Boolean(tx.committed);
}

async function tick() {
  if (ticking || !isFirebaseReady()) return;
  const { day, hour } = istParts();
  if (hour < 12 || finishedDay === day) return;
  ticking = true;
  try {
    const claimed = await claimDay(day);
    if (!claimed) {
      const done = await rootRef(`system/course_daily_summary/${day}/done`).get();
      if (done.val() === true) finishedDay = day;
      return;
    }
    await runCourseDailySummaries(day);
    await rootRef(`system/course_daily_summary/${day}`).update({
      done: true,
      finishedAt: Date.now(),
    });
    finishedDay = day;
  } catch (err) {
    console.warn('[course-summary] run failed');
    try {
      await rootRef(`system/course_daily_summary/${day}`).update({
        error: clip(err?.message || 'failed', 160),
        startedAt: 0,
      });
    } catch {
      /* ignore */
    }
  } finally {
    ticking = false;
  }
}

export function startCourseDailySummary() {
  if (timer) return;
  timer = setInterval(() => {
    tick().catch(() => {});
  }, 30000);
  setTimeout(() => {
    tick().catch(() => {});
  }, 8000);
  console.log('[course-summary] scheduler on — 12:00 Asia/Kolkata');
}

export async function saveFcmToken({ uid, email, token }) {
  if (!uid || !isFirebaseReady()) return { ok: false, error: 'not_ready' };
  const clean = String(token || '').trim();
  if (clean.length < 20 || clean.length > 4096) {
    return { ok: false, error: 'bad_token' };
  }
  await rootRef(`users/${uid}/fcmToken`).set(clean);
  const ek = email ? emailKey(email) : '';
  if (ek) await rootRef(`email_users/${ek}/fcmToken`).set(clean);
  return { ok: true };
}
