/**
 * Every day at 12:00 noon Asia/Kolkata, append one Hindi summary as the
 * last course-chat message for that morning's work, and push a notification
 * when the phone has registered an FCM token.
 *
 * Idempotent: days/{YYYY-MM-DD}/messages/summary_{day} is written once.
 */
import admin from 'firebase-admin';
import { isFirebaseReady, rootRef } from '../config/firebase.js';
import { env } from '../config/env.js';
import { emailKey } from '../utils/email_key.js';
import { crops } from '../../seed/crops.js';
import { stripAccountSecrets } from './ai_privacy.js';
import { UserAiContextService } from './user_ai_context.service.js';
import { CourseAheadService } from './course_ahead.service.js';

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

function statusBody(cropName, lang, tasks) {
  const en = lang === 'en';
  const name = cropName || (en ? 'crop' : 'फसल');
  const ask = en
    ? `How is your ${name} today? Tell us how the field is.`
    : `आज आपकी ${name} कैसी है? खेत का हाल बताएँ।`;
  const titles = (tasks || []).map((t) => t.title).filter(Boolean).slice(0, 3);
  if (!titles.length) return ask;
  const work = en ? 'Today' : 'आज का काम';
  return `${ask}\n${work}: ${titles.join(' · ')}`;
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

function transcriptForSummary(items) {
  const lines = [];
  for (const m of items) {
    const said = mainLine(stripAccountSecrets(m.text), 160);
    if (!said || said === 'फोटो') continue;
    lines.push(`${m.role === 'user' ? 'किसान' : 'सलाह'}: ${said}`);
  }
  return lines.slice(-16).join('\n').slice(0, 3500);
}

function shortFallback(cropName, items) {
  const line = transcriptForSummary(items).split('\n').slice(0, 2).join(' ');
  return clip(`${cropName}: ${line}`, 180);
}

async function gptDaySummary(cropName, items) {
  const transcript = transcriptForSummary(items);
  if (!transcript) return '';
  const key = env.openaiApiKey || '';
  if (!key.startsWith('sk-')) return shortFallback(cropName, items);
  const model = env.openaiChatAdvancedModel || 'gpt-5-mini';
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), Math.min(env.openaiTimeoutMs || 60000, 25000));
  try {
    const res = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${key}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model,
        reasoning_effort: 'minimal',
        max_completion_tokens: 180,
        messages: [
          {
            role: 'system',
            content:
              'तुम AG Farmer हो। फसल कोर्स के एक दिन का सार बहुत कम शब्दों में लिखो। हिंदी में 2 छोटी पंक्तियाँ, कुल 40 शब्द से कम। पहली पंक्ति: किसान ने क्या पूछा। दूसरी: जो असली सलाह दी (नाम और 10 आरी मात्रा अगर हो)। नंबर वाली लंबी सूची मत लिखो। मॉडल या कंपनी का नाम मत लो। मोबाइल या ईमेल मत लिखो।',
          },
          {
            role: 'user',
            content: `फसल: ${cropName}\n${transcript}`,
          },
        ],
      }),
      signal: controller.signal,
    });
    const body = await res.json().catch(() => ({}));
    const text = clip(stripAccountSecrets(body?.choices?.[0]?.message?.content || ''), 220);
    if (!res.ok || text.length < 8) return shortFallback(cropName, items);
    return text;
  } catch {
    return shortFallback(cropName, items);
  } finally {
    clearTimeout(timer);
  }
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
        type: 'course_status',
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
  let sent = 0;

  for (const [threadId, thread] of Object.entries(threads)) {
    if (!String(threadId).startsWith('course_') || !thread) continue;
    const existing = thread?.days?.[day]?.messages?.[`summary_${day}`];
    if (existing) continue;

    const work = collectTodayWork(thread, day);
    const meta = thread.meta || {};
    const cropId = String(meta.cropId || threadId.replace(/^course_/, ''));
    const label = cropLabel(threadId, meta);
    const brief = await gptDaySummary(label, work);
    if (!brief) continue;
    const text = `आज का सारांश — ${label}\n${brief}`;

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
    try {
      await UserAiContextService.applyCourseDaySummary({
        bases,
        threadId,
        day,
        text: brief,
      });
    } catch {
      console.warn('[course-summary] context update skipped');
    }
    sent += 1;
  }

  return sent;
}

async function deliverStatusReminders(uid, user, day) {
  const courses = user?.courses || {};
  const already = { ...(user?.course_notify || {}) };
  const token = user?.fcmToken || user?.notify?.token || '';
  const lang = user?.language === 'en' || user?.profile?.language === 'en' ? 'en' : 'hi';
  let sent = 0;
  let dropToken = false;

  for (const [cropId, row] of Object.entries(courses)) {
    if (!row || row.endedAt) continue;
    if (already[cropId] === day) continue;
    const name = String(
      lang === 'en'
        ? (row.nameEn || row.nameHi || cropId)
        : (row.nameHi || row.nameEn || cropId),
    ).trim() || (lang === 'en' ? 'crop' : 'फसल');
    let tasks = [];
    try {
      const plan = await CourseAheadService.ensure({
        uid,
        cropId,
        name,
        lang,
        day,
      });
      if (plan.ready === true) {
        tasks = (plan.items || []).filter((item) => item.day === day);
        await CourseAheadService.postUpdate({
          uid,
          email: user.email || user.profile?.email || '',
          cropId,
          name,
          day,
          items: plan.items,
          lang,
        });
      }
    } catch {
      console.warn('[course-ahead] plan skipped');
    }
    const pushed = await pushSummary({
      token,
      title: name,
      body: statusBody(name, lang, tasks),
      cropId,
      day,
    });
    if (pushed === 'drop') dropToken = true;
    if (pushed === true) {
      already[cropId] = day;
      await rootRef(`users/${uid}/course_notify/${cropId}`).set(day);
      sent += 1;
    }
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
        sent += await deliverStatusReminders(uid, user, day);
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
