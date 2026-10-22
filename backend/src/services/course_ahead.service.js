/**
 * Rolling 15-day care schedule for an active course.
 * Irrigation, medicine, pests, nutrients, manure, disease, and small checks.
 * No invented doses. Opium never gets lancing or latex tasks.
 */
import { isFirebaseReady, rootRef } from '../config/firebase.js';
import { env } from '../config/env.js';
import { emailKey } from '../utils/email_key.js';
import { stripAccountSecrets } from './ai_privacy.js';

const IST_OFFSET_MS = (5 * 60 + 30) * 60 * 1000;

function todayIst() {
  return new Date(Date.now() + IST_OFFSET_MS).toISOString().slice(0, 10);
}

const KINDS = ['sinchai', 'dawai', 'keet', 'poshak', 'khad', 'bimari', 'dekhbhal'];
const BANNED = /चीरा|latex|lancing|lance|opium milk|दूध निकाल/i;
const MIN_ANALYZED_DAYS = 4;

function cropKey(raw) {
  return String(raw || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_-]/g, '_')
    .replace(/_+/g, '_')
    .slice(0, 48);
}

function addDays(day, n) {
  const [y, m, d] = String(day || '').split('-').map((x) => Number(x));
  if (!y || !m || !d) return '';
  const dt = new Date(Date.UTC(y, m - 1, d + n));
  return dt.toISOString().slice(0, 10);
}

function windowDays(from) {
  return Array.from({ length: 15 }, (_, i) => addDays(from, i));
}

function isOpium(cropId) {
  return /^(afim|afeem|opium)$/.test(String(cropId || ''));
}

function clip(text, max) {
  const s = String(text || '').replace(/\s+/g, ' ').trim();
  if (s.length <= max) return s;
  return `${s.slice(0, max)}…`;
}

function cleanItems(raw, from) {
  const allowed = new Set(windowDays(from));
  const items = [];
  const list = Array.isArray(raw) ? raw : [];
  for (const row of list) {
    const day = String(row?.day || '').slice(0, 10);
    const kind = String(row?.kind || '');
    const title = clip(stripAccountSecrets(row?.title), 80);
    const detail = clip(stripAccountSecrets(row?.detail), 180);
    if (!allowed.has(day) || !KINDS.includes(kind) || title.length < 2) continue;
    if (BANNED.test(title) || BANNED.test(detail)) continue;
    items.push({ day, kind, title, detail });
    if (items.length >= 45) break;
  }
  const covered = new Set(items.map((i) => i.day));
  if (covered.size < 12) return [];
  return items;
}

function analyzedDayKeys(days) {
  const keys = [];
  for (const [day, bucket] of Object.entries(days || {})) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(day) || !bucket) continue;
    const msgs = Object.values(bucket.messages || {});
    const analyzed = bucket.dailySummarySent === true || msgs.some((m) => {
      const id = String(m?.id || '');
      return id.startsWith('summary_') || m?.kind === 'daily_summary';
    });
    if (analyzed) keys.push(day);
  }
  return keys.sort();
}

function analysisNotes(days, keys) {
  const lines = [];
  for (const day of keys.slice(-5)) {
    const msgs = Object.values(days[day]?.messages || {});
    for (const m of msgs) {
      const id = String(m?.id || '');
      if (!id.startsWith('summary_') && m?.kind !== 'daily_summary') continue;
      const said = clip(stripAccountSecrets(m?.text), 240);
      if (said) lines.push(`${day}: ${said}`);
    }
  }
  return lines.join('\n').slice(0, 2200);
}

function notReady(from, analyzedDays) {
  return {
    from,
    items: [],
    ready: false,
    analyzedDays,
    need: MIN_ANALYZED_DAYS,
  };
}

async function gptPlan({ name, cropId, from, lang, notes }) {
  const key = env.openaiApiKey || '';
  if (!key.startsWith('sk-') || !notes) return null;
  const days = windowDays(from);
  const opium = isOpium(cropId)
    ? 'अफ़ीम में चीरा, दूध, latex या lancing कभी मत लिखो। सिर्फ बोवाई, पानी, खाद, पोषक तत्व, बीमारी, कीट और देखभाल।'
    : '';
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 12000);
  try {
    const res = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${key}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: env.openaiChatAdvancedModel || 'gpt-5-mini',
        reasoning_effort: 'minimal',
        max_completion_tokens: 1400,
        messages: [
          {
            role: 'system',
            content:
              `तुम AG Farmer हो। अगले 15 दिन का खेत शेड्यूल सिर्फ JSON array में दो। हर दिन 2 काम। kind सिर्फ: sinchai, dawai, keet, poshak, khad, bimari, dekhbhal। title छोटा। detail एक छोटी पंक्ति। नई दवाई की मात्रा मत गढ़ो। दवाई वाले काम में लिखो कि अंतिम राय के लिए एक बार स्थानीय सलाहकार से पूछना जरूरी है। मात्रा सिर्फ तभी जब किसान की पुरानी बात में वही हो। ${opium} मॉडल का नाम मत लो।`,
          },
          {
            role: 'user',
            content: `फसल: ${name}\nतारीखें: ${days.join(', ')}\nभाषा: ${lang === 'en' ? 'English' : 'Hindi'}\nपुरानी बात:\n${notes}`,
          },
        ],
      }),
      signal: controller.signal,
    });
    const body = await res.json().catch(() => ({}));
    const text = String(body?.choices?.[0]?.message?.content || '');
    const start = text.indexOf('[');
    const end = text.lastIndexOf(']');
    if (!res.ok || start < 0 || end <= start) return null;
    return JSON.parse(text.slice(start, end + 1));
  } catch {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

async function loadDays(uid, cropId, seeded) {
  if (seeded?.days) return seeded.days;
  if (!uid || !isFirebaseReady()) return {};
  const snap = await rootRef(`users/${uid}/ai/threads/course_${cropId}/days`)
    .orderByKey()
    .limitToLast(20)
    .get();
  return snap.exists() ? (snap.val() || {}) : {};
}

export const CourseAheadService = {
  async ensure({ uid, cropId, name, lang = 'hi', day, thread }) {
    const id = cropKey(cropId);
    const from = day || todayIst();
    const useLang = lang === 'en' ? 'en' : 'hi';
    if (!uid || !id || !isFirebaseReady()) return notReady(from, 0);
    const days = await loadDays(uid, id, thread);
    const analyzed = analyzedDayKeys(days);
    if (analyzed.length < MIN_ANALYZED_DAYS) return notReady(from, analyzed.length);
    const cached = await rootRef(`users/${uid}/course_ahead/${id}`).get();
    const prev = cached.val();
    if (
      prev &&
      prev.ready === true &&
      prev.from === from &&
      Number(prev.analyzedDays) >= MIN_ANALYZED_DAYS &&
      Array.isArray(prev.items) &&
      prev.items.length
    ) {
      return {
        from,
        items: prev.items,
        ready: true,
        analyzedDays: Number(prev.analyzedDays),
        need: MIN_ANALYZED_DAYS,
      };
    }
    const notes = analysisNotes(days, analyzed);
    const drafted = notes
      ? await gptPlan({
        name: name || id,
        cropId: id,
        from,
        lang: useLang,
        notes,
      })
      : null;
    const items = cleanItems(drafted, from);
    if (!items.length) return notReady(from, analyzed.length);
    await rootRef(`users/${uid}/course_ahead/${id}`).set({
      from,
      cropId: id,
      ready: true,
      analyzedDays: analyzed.length,
      need: MIN_ANALYZED_DAYS,
      builtAt: Date.now(),
      items,
    });
    return {
      from,
      items,
      ready: true,
      analyzedDays: analyzed.length,
      need: MIN_ANALYZED_DAYS,
    };
  },

  async getOrBuild({ uid, cropId, lang }) {
    const id = cropKey(cropId);
    if (!uid || !id) {
      throw Object.assign(new Error('crop_required'), { status: 400 });
    }
    if (!isFirebaseReady()) {
      throw Object.assign(new Error('service_unavailable'), { status: 503 });
    }
    const course = await rootRef(`users/${uid}/courses/${id}`).get();
    const row = course.val();
    if (!row || row.endedAt) {
      return { from: todayIst(), days: 15, items: [], ready: false, analyzedDays: 0, need: MIN_ANALYZED_DAYS };
    }
    const name = lang === 'en'
      ? (row.nameEn || row.nameHi || id)
      : (row.nameHi || row.nameEn || id);
    const plan = await this.ensure({
      uid,
      cropId: id,
      name,
      lang,
      day: todayIst(),
    });
    return {
      from: plan.from,
      days: 15,
      items: plan.items,
      ready: plan.ready === true,
      analyzedDays: plan.analyzedDays || 0,
      need: plan.need || MIN_ANALYZED_DAYS,
    };
  },

  async postUpdate({ uid, email, cropId, name, day, items, lang }) {
    const id = cropKey(cropId);
    if (!uid || !id || !isFirebaseReady() || !items?.length) return;
    const msgId = `ahead_${day}`;
    const path = `users/${uid}/ai/threads/course_${id}/days/${day}/messages/${msgId}`;
    const existing = await rootRef(path).get();
    if (existing.exists()) return;
    const hi = lang !== 'en';
    const today = (items || []).filter((i) => i.day === day);
    const nextDay = addDays(day, 1);
    const tomorrow = (items || []).filter((i) => i.day === nextDay);
    const line = (rows) => rows.map((r) => r.title).filter(Boolean).slice(0, 4).join(' · ');
    const todayLine = line(today);
    const nextLine = line(tomorrow);
    const text = hi
      ? `आगे 15 दिन — ${name}\nआज: ${todayLine || 'खेत का हाल देखें'}\nकल: ${nextLine || 'उसी देखभाल को आगे रखें'}\nपूरा शेड्यूल कैलेंडर में «आगे क्या करना है» पर है। सिंचाई, दवाई, कीट, पोषक तत्व, खाद, बीमारी और छोटे काम उसी सूची में हैं।`
      : `Next 15 days — ${name}\nToday: ${todayLine || 'Check the field'}\nTomorrow: ${nextLine || 'Keep the same care going'}\nThe full schedule is in the calendar under To do. Irrigation, medicine, insects, nutrients, manure, disease, and small jobs are in that list.`;
    const now = Date.now();
    const message = {
      id: msgId,
      role: 'assistant',
      text: clip(text, 700),
      createdAt: new Date(now).toISOString(),
      ts: now,
      day,
      cropTag: id,
      kind: 'ahead_plan',
      label: hi ? 'आगे 15 दिन' : 'Next 15 days',
    };
    await rootRef(path).set(message);
    const ek = email ? emailKey(email) : '';
    if (ek) {
      await rootRef(
        `email_users/${ek}/ai/threads/course_${id}/days/${day}/messages/${msgId}`,
      ).set(message);
    }
  },
};
