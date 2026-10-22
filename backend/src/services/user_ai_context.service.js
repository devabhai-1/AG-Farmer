/**
 * Per-user AI chat + context — Realtime Database is the source of truth.
 * Always dual-written under uid AND email when both are known.
 *
 * ISOLATION (never break):
 * - Chat thread is only chat_{sessionId} or main. Never a course_* thread.
 * - Course thread is only course_{cropId}. Never a chat thread.
 * - Window lives under users/{THIS uid}/ai (and that user's email mirror).
 * - Never load another uid/email/IP guest box into GPT.
 * - Never seed GPT or a thread from client `history`.
 * - Deleted chats move to training/deleted_chats. That box is never read
 *   back into a user thread, a session list, or GPT.
 *
 * Normal chat (named sessions):
 *   …/ai/sessions/{sessionId}              ← name, threadId, updatedAt
 *   …/ai/threads/chat_{sessionId}/messages
 *   …/ai/threads/chat_{sessionId}/window
 *   …/ai/threads/main/…                    ← legacy / default session
 *
 * Fasal course (one thread per crop — afim, lasun, …):
 *   …/ai/threads/course_{cropId}/
 *     meta
 *     days/{YYYY-MM-DD}/messages/{id}       ← full season history
 *     days/{YYYY-MM-DD}/digest
 *     months/{YYYY-MM}/summary
 *     window                                ← very large packed context
 *
 * Paths: users/{uid}/ai  AND  email_users/{emailKey}/ai
 * Index: indexes/email/{emailKey} → { uid }
 */
import { isFirebaseReady, rootRef } from '../config/firebase.js';
import { stripAccountSecrets } from './ai_privacy.js';
import { UserService } from './user.service.js';
import { hashIp } from '../middleware/client_ip.js';
import { emailKey } from '../utils/email_key.js';
import { randomBytes } from 'crypto';

const lanes = new Map();

/**
 * How many back-and-forth chats the model remembers.
 * One chat = the farmer's message plus the answer.
 * Default / ₹299 → 5, ₹599 → 10, ₹2650 → 30, ₹13500 → 300.
 */
export function contextMemoryForPlan(planId) {
  const p = String(planId || 'free')
    .toLowerCase()
    .trim()
    .replace(/[\s_-]+/g, '');
  let chats = 5;
  if (p === 'all' || p === 'allcrops') chats = 10;
  if (p === 'super' || p === 'superpro' || p === 'superpremium') chats = 30;
  if (p === 'distributor' || p === 'distributorpro' || p === 'dealer') chats = 300;
  const turns = chats * 2;
  return { chats, turns, chars: turns * 2400 };
}

/** AG Live spoken turns keep a 100k-token working window. */
const LIVE_CONTEXT_TOKENS = 100000;
const LIVE_KEEP_TURNS = 500;
const LIVE_KEEP_CHARS = 320000;

export function liveContextBudget() {
  return { tokens: LIVE_CONTEXT_TOKENS, turns: LIVE_KEEP_TURNS, chars: LIVE_KEEP_CHARS };
}

/** Normal chat sessions */
const MAIN_MAX_STORE = 600;
const MAIN_MAX_TURNS = 10;
const MAIN_MAX_CHARS = 24000;

/** Course: full season — huge context window for THIS crop only. */
const COURSE_KEEP_DAYS = 400;
const COURSE_RECENT_TURNS = 400;
const COURSE_RECENT_CHARS = 280000;
const COURSE_DAY_DIGESTS = 240;
const COURSE_MONTH_SUMMARIES = 24;
const COURSE_SUMMARY_CHARS = 48000;

function dayKey(d = new Date()) {
  return d.toISOString().slice(0, 10);
}

function safeId(raw, max = 48) {
  return String(raw || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_-]/g, '_')
    .replace(/_+/g, '_')
    .slice(0, max);
}

function threadIdFor({ mode = 'chat', cropId = null, sessionId = null } = {}) {
  const m = String(mode || 'chat').toLowerCase();
  if (m === 'course' || m === 'fasal') {
    const crop = safeId(cropId, 48);
    if (!crop || crop === 'all') return null;
    return `course_${crop}`;
  }
  const sid = safeId(sessionId, 40);
  if (!sid) return null;
  if (sid === 'main') return 'main';
  return `chat_${sid}`;
}

function isCourseThread(threadId) {
  return String(threadId || '').startsWith('course_');
}

function sessionIdFromThread(threadId) {
  const t = String(threadId || '');
  if (!t) return '';
  if (t.startsWith('chat_')) return t.slice(5);
  if (t === 'main') return 'main';
  if (t.startsWith('course_')) return t;
  return t;
}

function defaultChatName(chatName, sessionId) {
  const n = String(chatName || '').trim();
  if (n) return n.slice(0, 80);
  const sid = sessionIdFromThread(sessionId) || 'main';
  if (sid === 'main') return 'General Chat';
  return `Chat ${sid.slice(0, 12)}`;
}

const WEAK_TITLE = /^(h+i+|hello+|hey+|helo+|namaste|namaskar|good\s*(morning|evening|afternoon|night)|yo|sup|नमस्ते|नमस्कार|हेलो|हाय|हाए|राम\s*राम|प्रणाम|नई चैट|new chat|general chat)[\s!.,।🙏]*$/i;

function isWeakTitle(name) {
  return WEAK_TITLE.test(String(name || '').trim());
}

function clipTopicWords(text, maxWords) {
  const words = String(text || '')
    .replace(/[*#_`]/g, '')
    .replace(/\s+/g, ' ')
    .trim()
    .split(' ')
    .filter(Boolean);
  if (!words.length) return '';
  const kept = words.slice(0, maxWords).join(' ');
  return words.length > maxWords ? `${kept}…` : kept;
}

function stripLeadGreeting(text) {
  return String(text || '')
    .replace(
      /^(h+i+|hello+|hey+|helo+|namaste|namaskar|नमस्ते|नमस्कार|हेलो|हाय|हाए|राम\s*राम|प्रणाम)[,!\s.।🙏]+/i,
      '',
    )
    .trim();
}

const TOPIC_CROPS = [
  [/अफीम|अफ़ीम|afim|opium|poppy|पोस्त/i, 'अफीम'],
  [/लहसुन|lahsun|garlic/i, 'लहसुन'],
  [/प्याज|onion|pyaaz|pyaj/i, 'प्याज'],
  [/गेहूँ|गेहूं|gehun|wheat/i, 'गेहूँ'],
  [/धान|चावल|paddy|rice|dhan/i, 'धान'],
  [/मक्का|makka|maize|corn/i, 'मक्का'],
  [/कपास|cotton|kapas/i, 'कपास'],
  [/सरसों|mustard|sarson/i, 'सरसों'],
  [/चना|chana|gram/i, 'चना'],
  [/टमाटर|tomato|tamatar/i, 'टमाटर'],
  [/मिर्च|mirch|chilli|chili/i, 'मिर्च'],
  [/आलू|potato|aalu|aloo/i, 'आलू'],
  [/गन्ना|sugarcane|ganna/i, 'गन्ना'],
  [/सोयाबीन|soy/i, 'सोयाबीन'],
  [/मूंगफली|groundnut|moongphali/i, 'मूंगफली'],
  [/जीरा|jeera|cumin/i, 'जीरा'],
  [/धनिया|coriander|dhaniya/i, 'धनिया'],
  [/हल्दी|turmeric|haldi/i, 'हल्दी'],
  [/अदरक|ginger|adrak/i, 'अदरक'],
];

const TOPIC_ISSUES = [
  [/पील|yellow|peel/i, 'पीलापन'],
  [/कीट|कीड़ा|कीडा|pest|keet|insect/i, 'कीट'],
  [/रोग|बीमारी|bimari|disease/i, 'रोग'],
  [/खाद|fertili[sz]er|khad|यूरिया|urea|\bdap\b/i, 'खाद'],
  [/सिंचाई|सिंच|पानी|irrigation|sinchai|water/i, 'सिंचाई'],
  [/बुवाई|बुआई|sowing|buwai|बोना|बीज बो/i, 'बुवाई'],
  [/बीज|seed|beej/i, 'बीज'],
  [/खरपतवार|weed/i, 'खरपतवार'],
  [/कटाई|harvest|katai/i, 'कटाई'],
  [/धब्ब|spot|daag|दाग/i, 'धब्बे'],
  [/सड़|rot|galn|गलन/i, 'सड़ना'],
  [/सूख|wilt|sukha|dry/i, 'सूखना'],
  [/मंडी|भाव|bhav|price|rate/i, 'मंडी भाव'],
  [/दवा|spray|दवाई|छिड़काव/i, 'दवा'],
];

function firstTopicHit(text, table) {
  const blob = String(text || '');
  for (const [re, label] of table) {
    if (re.test(blob)) return label;
  }
  return '';
}

/** One short topic line for history. Never the raw opening word like "hello". */
function topicLine(messages) {
  const rows = (messages || []).filter((m) => {
    if (!m) return false;
    const id = String(m.id || '');
    if (id.startsWith('welcome_') || id.startsWith('summary_')) return false;
    return true;
  });
  const users = rows
    .filter((m) => m.role === 'user')
    .map((m) => String(m.text || '').trim())
    .filter(Boolean);
  const real = users
    .map(stripLeadGreeting)
    .find((t) => t && !isWeakTitle(t) && t.length > 1);
  if (!real) {
    if (rows.some((m) => m.imageUrl || m.mediaPath || m.imagePath)) {
      return 'फसल की फोटो';
    }
    if (users.length) return 'सामान्य बातचीत';
    return '';
  }
  const asked = users.map(stripLeadGreeting).filter(Boolean).join('\n');
  const crop = firstTopicHit(real, TOPIC_CROPS) || firstTopicHit(asked, TOPIC_CROPS);
  const issue = firstTopicHit(real, TOPIC_ISSUES) || firstTopicHit(asked, TOPIC_ISSUES);
  if (crop && issue) return `${crop} · ${issue}`;
  if (crop) return crop;
  if (issue) return issue;
  const sentence = real.split(/[.?!।\n]/).map((s) => s.trim()).find((s) => s.length > 1) || real;
  return clipTopicWords(sentence, 7);
}

async function lockedSessionName(bases, sid) {
  for (const base of bases || []) {
    try {
      const snap = await rootRef(`${base}/sessions/${sid}`).get();
      const row = snap.val();
      if (row?.custom === true) {
        const n = String(row.name || '').trim();
        if (n) return n;
      }
    } catch {
      /* try the next copy */
    }
  }
  return '';
}

function clipText(t, max = 4000) {
  const s = String(t || '').trim();
  if (s.length <= max) return s;
  return `${s.slice(0, max)}…`;
}

function lastCount(list, n) {
  const rows = list || [];
  const keep = Number(n) || 0;
  if (keep <= 0) return [];
  return rows.slice(-keep);
}

function turnsFromMessages(messages, maxTurns) {
  return lastCount(
    (messages || []).filter((m) => m && (m.role === 'user' || m.role === 'assistant') && m.text),
    maxTurns,
  )
    .map((m) => ({
      role: m.role === 'assistant' ? 'assistant' : 'user',
      text: clipText(m.text, 2200),
    }));
}

function estimateChars(turns, extra = '') {
  let n = String(extra || '').length;
  for (const t of turns || []) n += String(t.text || '').length + 8;
  return n;
}

const mem = {
  control: new Map(),
  emailIndex: new Map(),
};

export function threadMatchesMode(mode, threadId) {
  const t = String(threadId || '');
  const m = String(mode || 'chat').toLowerCase();
  if (m === 'course' || m === 'fasal') return t.startsWith('course_');
  return t === 'main' || t.startsWith('chat_');
}

export const UserAiContextService = {
  emailKey,
  threadIdFor,
  isCourseThread,
  threadMatchesMode,

  /**
   * One farmer + one thread at a time.
   * Other farmers run together. Their windows never share this lock.
   */
  withLane(key, fn) {
    const id = String(key || 'none');
    const prev = lanes.get(id) || Promise.resolve();
    const run = prev.catch(() => {}).then(fn);
    const tracked = run.finally(() => {
      if (lanes.get(id) === tracked) lanes.delete(id);
    });
    lanes.set(id, tracked);
    return run;
  },

  ownerPath({ uid, email, ip }) {
    if (uid) return { kind: 'user', id: String(uid), base: `users/${uid}/ai` };
    if (email) {
      const ek = emailKey(email);
      return { kind: 'email', id: ek, base: `email_users/${ek}/ai` };
    }
    const ipHash = hashIp(ip || '0.0.0.0');
    return { kind: 'guest', id: ipHash, base: `guests/${ipHash}/ai` };
  },

  /** All AI bases that must stay in sync for this farmer (uid + email). */
  ownerBases({ uid, email, ip }) {
    const bases = [];
    const seen = new Set();
    const push = (b) => {
      if (!b || seen.has(b)) return;
      seen.add(b);
      bases.push(b);
    };
    if (uid) push(`users/${uid}/ai`);
    if (email) push(`email_users/${emailKey(email)}/ai`);
    if (!bases.length && ip) push(`guests/${hashIp(ip)}/ai`);
    return bases;
  },

  async writeToBases(bases, relativePath, data, { merge = false } = {}) {
    if (!isFirebaseReady() || !bases.length) return;
    await Promise.all(
      bases.map(async (base) => {
        const ref = rootRef(`${base}/${relativePath}`);
        if (merge) await ref.update(data);
        else await ref.set(data);
      }),
    );
  },

  rtdbReady() {
    return isFirebaseReady();
  },

  async linkEmailToUid(email, uid) {
    const ek = emailKey(email);
    if (!ek || !uid) return;
    mem.emailIndex.set(ek, uid);
    if (!isFirebaseReady()) return;
    try {
      await rootRef(`indexes/email/${ek}`).set({
        uid,
        email: String(email).trim().toLowerCase(),
        updatedAt: Date.now(),
      });
      await rootRef(`users/${uid}/ai/control`).update({
        email: String(email).trim().toLowerCase(),
        uid,
        updatedAt: Date.now(),
      });
    } catch (e) {
      console.warn('[ai-context] email index skip:', e.message);
    }
  },

  async resolveUidByEmail(email) {
    const ek = emailKey(email);
    if (!ek) return null;
    if (isFirebaseReady()) {
      try {
        const snap = await rootRef(`indexes/email/${ek}`).get();
        const uid = snap.val()?.uid || null;
        if (uid) {
          mem.emailIndex.set(ek, uid);
          return uid;
        }
        mem.emailIndex.delete(ek);
        return null;
      } catch {
        /* fall through to memory */
      }
    }
    if (mem.emailIndex.has(ek)) return mem.emailIndex.get(ek);
    return null;
  },

  async getControl({ uid, email, ip }) {
    const owner = this.ownerPath({ uid, email, ip });
    const isCourseDefaults = false;
    const defaults = {
      email: email ? String(email).trim().toLowerCase() : null,
      uid: uid || null,
      planId: 'free',
      planTier: 'free',
      dailyChatLimit: 50,
      dailyImageLimit: 10,
      contextMaxTurns: MAIN_MAX_TURNS,
      contextMaxChars: MAIN_MAX_CHARS,
      courseRecentTurns: COURSE_RECENT_TURNS,
      courseRecentChars: COURSE_RECENT_CHARS,
      courseKeepDays: COURSE_KEEP_DAYS,
      courseDayDigests: COURSE_DAY_DIGESTS,
      courseMonthSummaries: COURSE_MONTH_SUMMARIES,
      blocked: false,
      blockReason: null,
      updatedAt: Date.now(),
    };
    void isCourseDefaults;

    // Always prefer RTDB when ready — invalidate stale in-memory control after wipe
    if (isFirebaseReady()) {
      try {
        const snap = await rootRef(`${owner.base}/control`).get();
        if (snap.exists()) {
          const v = { ...defaults, ...snap.val() };
          mem.control.set(owner.base, v);
          return v;
        }
        mem.control.delete(owner.base);
      } catch (e) {
        console.warn('[ai-context] control read skip:', e.message);
      }
    } else if (mem.control.has(owner.base)) {
      return { ...defaults, ...mem.control.get(owner.base) };
    }
    return defaults;
  },

  async setControl({ uid, email, ip }, patch = {}) {
    const owner = this.ownerPath({ uid, email, ip });
    const prev = await this.getControl({ uid, email, ip });
    const next = {
      ...prev,
      ...patch,
      email: email ? String(email).trim().toLowerCase() : prev.email,
      uid: uid || prev.uid,
      updatedAt: Date.now(),
    };
    mem.control.set(owner.base, next);
    if (isFirebaseReady()) {
      try {
        await rootRef(`${owner.base}/control`).update(next);
      } catch (e) {
        console.warn('[ai-context] control write skip:', e.message);
      }
    }
    if (email && uid) await this.linkEmailToUid(email, uid);
    return next;
  },

  /**
   * Build model context window from RTDB.
   * Course threads: season + month summaries + day digests + recent turns (huge pack).
   * Chat threads: named session window.
   */
  async memoryForUid(uid) {
    const planId = await UserService.effectivePlanId(uid);
    return { planId, ...contextMemoryForPlan(planId) };
  },

  async getWindow({ uid, email, ip, mode, cropId, sessionId = null, voice = false }) {
    const owner = this.ownerPath({ uid, email, ip });
    const threadId = threadIdFor({ mode, cropId, sessionId });
    const empty = {
      owner,
      threadId: threadId || '',
      sessionId: sessionIdFromThread(threadId) || '',
      control: {},
      summary: '',
      history: [],
      course: isCourseThread(threadId),
      blocked: false,
      storage: 'none',
    };
    // Guests share CGNAT IPs — never load a guest/IP window into GPT.
    if (!uid && !String(email || '').trim()) return empty;
    if (!threadId) return empty;
    const control = await this.getControl({ uid, email, ip });
    const course = isCourseThread(threadId);

    let windowData = {
      summary: '',
      seasonSummary: '',
      monthSummaries: [],
      dayDigests: [],
      turns: [],
      updatedAt: 0,
    };

    if (isFirebaseReady()) {
      try {
        const snap = await rootRef(
          `${owner.base}/threads/${threadId}/window`,
        ).get();
        if (snap.exists()) windowData = { ...windowData, ...snap.val() };
        // Fallback: if uid path empty, try email mirror
        if (!snap.exists() && email && owner.kind === 'user') {
          const ek = emailKey(email);
          const alt = await rootRef(
            `email_users/${ek}/ai/threads/${threadId}/window`,
          ).get();
          if (alt.exists()) windowData = { ...windowData, ...alt.val() };
        }
      } catch (e) {
        console.warn('[ai-context] window read skip:', e.message);
      }
    }

    const planMemory = course ? null : await this.memoryForUid(uid);
    const live = voice === true;
    const maxTurns = course
      ? control.courseRecentTurns || COURSE_RECENT_TURNS
      : live
        ? LIVE_KEEP_TURNS
        : planMemory.turns;
    const maxChars = course
      ? control.courseRecentChars || COURSE_RECENT_CHARS
      : live
        ? LIVE_KEEP_CHARS
        : planMemory.chars;

    let history = Array.isArray(windowData.turns)
      ? lastCount(windowData.turns, maxTurns)
      : [];

    // Pack long-term memory into system-facing summary for course
    let summaryParts = [];
    if (course) {
      if (windowData.seasonSummary) {
        summaryParts.push(`सीजन सार: ${clipText(windowData.seasonSummary, 6000)}`);
      }
      const months = Array.isArray(windowData.monthSummaries)
        ? windowData.monthSummaries.slice(-COURSE_MONTH_SUMMARIES)
        : [];
      for (const m of months) {
        if (m?.month && m?.text) {
          summaryParts.push(`${m.month}: ${clipText(m.text, 1600)}`);
        }
      }
      const digests = Array.isArray(windowData.dayDigests)
        ? windowData.dayDigests.slice(-COURSE_DAY_DIGESTS)
        : [];
      if (digests.length) {
        summaryParts.push(
          `रोजाना नोट्स:\n${digests
            .map((d) => `${d.day}: ${clipText(d.text, 320)}`)
            .join('\n')}`,
        );
      }
    } else if (windowData.summary) {
      summaryParts.push(windowData.summary);
    }

    const summary = summaryParts
      .join('\n\n')
      .slice(0, course ? COURSE_SUMMARY_CHARS : live ? 12000 : 4000);

    if (estimateChars(history, summary) > maxChars && history.length) {
      const room = Math.max(160, Math.floor((maxChars - summary.length) / history.length) - 8);
      history = history.map((t) => ({ ...t, text: clipText(t.text, room) }));
    }

    return {
      owner,
      threadId,
      sessionId: sessionIdFromThread(threadId),
      control,
      summary,
      history,
      course,
      blocked: Boolean(control.blocked),
      storage: isFirebaseReady() ? 'rtdb' : 'memory',
    };
  },

  /**
   * Persist turns to Realtime Database (primary).
   * Dual-writes under users/{uid}/ai AND email_users/{email}/ai.
   * Course → days/{date}/messages; Chat session → messages/{id}
   */
  /** Long course memory is the short GPT day summary, not raw chat clips. */
  async applyCourseDaySummary({ bases, threadId, day, text }) {
    const clean = clipText(text, 280);
    if (!clean || !bases?.length || !threadId || !day) return;
    const now = Date.now();
    const month = String(day).slice(0, 7);
    let windowData = {
      turns: [],
      dayDigests: [],
      monthSummaries: [],
      seasonSummary: '',
      summary: '',
    };
    try {
      const snap = await rootRef(`${bases[0]}/threads/${threadId}/window`).get();
      if (snap.exists()) windowData = { ...windowData, ...snap.val() };
    } catch (_) {}

    let dayDigests = Array.isArray(windowData.dayDigests)
      ? windowData.dayDigests.filter((d) => d?.day && d?.text)
      : [];
    const entry = { day, text: clean, updatedAt: now };
    const idx = dayDigests.findIndex((d) => d.day === day);
    if (idx >= 0) dayDigests[idx] = entry;
    else dayDigests.push(entry);
    dayDigests = dayDigests
      .sort((a, b) => String(a.day).localeCompare(String(b.day)))
      .slice(-COURSE_DAY_DIGESTS);

    const monthMap = {};
    for (const d of dayDigests) {
      const mo = String(d.day).slice(0, 7);
      if (!monthMap[mo]) monthMap[mo] = [];
      monthMap[mo].push(d);
    }
    const monthSummaries = Object.keys(monthMap)
      .sort()
      .slice(-COURSE_MONTH_SUMMARIES)
      .map((mo) => ({
        month: mo,
        text: monthMap[mo]
          .map((x) => `${String(x.day).slice(8)}: ${clipText(x.text, 220)}`)
          .join(' · ')
          .slice(0, 2000),
        updatedAt: now,
      }));
    const seasonSummary = monthSummaries
      .map((m) => `${m.month}: ${clipText(m.text, 400)}`)
      .join('\n')
      .slice(0, 6000);
    const monthEntry = monthSummaries.find((m) => m.month === month);

    await this.writeToBases(
      bases,
      `threads/${threadId}/days/${day}/digest`,
      entry,
    );
    if (monthEntry) {
      await this.writeToBases(
        bases,
        `threads/${threadId}/months/${month}/summary`,
        monthEntry,
      );
    }
    await this.writeToBases(bases, `threads/${threadId}/window`, {
      ...windowData,
      dayDigests,
      monthSummaries,
      seasonSummary,
      summary: seasonSummary,
      updatedAt: now,
    });
  },

  async appendTurn({
    uid,
    email,
    ip,
    mode = 'chat',
    cropId = null,
    sessionId = null,
    chatName = null,
    userText,
    assistantText,
    label = 'AG Farmer',
    imageUrl = null,
    imageLat = null,
    imageLon = null,
    clientHistory = [],
    voice = false,
  }) {
    if (!uid && !email) {
      console.warn('[ai-context] skip persist — login/email required for RTDB chat');
      return { ok: false, skipped: 'no_owner' };
    }
    const threadId = threadIdFor({ mode, cropId, sessionId });
    if (!threadId) {
      return { ok: false, skipped: 'no_thread' };
    }

    const owner = this.ownerPath({ uid, email, ip });
    const bases = this.ownerBases({ uid, email, ip });
    const sid = sessionIdFromThread(threadId);
    const course = isCourseThread(threadId);
    const control = await this.getControl({ uid, email, ip });
    const now = Date.now();
    const stamp = `${now}_${randomBytes(4).toString('hex')}`;
    const day = dayKey(new Date(now));
    let name = course
      ? `Course ${cropId || ''}`.trim()
      : defaultChatName(chatName, sid);

    const userMsg = {
      id: `u_${stamp}`,
      role: 'user',
      text: clipText(userText, 4000),
      createdAt: new Date(now).toISOString(),
      ts: now,
      day,
    };
    if (imageUrl && String(imageUrl).startsWith('http')) {
      userMsg.imageUrl = imageUrl;
      userMsg.imagePath = imageUrl;
      userMsg.mediaPath = imageUrl;
      userMsg.mediaType = 'image';
      const la = Number(imageLat);
      const lo = Number(imageLon);
      if (
        Number.isFinite(la) &&
        Number.isFinite(lo) &&
        Math.abs(la) + Math.abs(lo) > 0.0001
      ) {
        userMsg.lat = Math.round(la * 1e6) / 1e6;
        userMsg.lon = Math.round(lo * 1e6) / 1e6;
      }
    }
    const botMsg = {
      id: `a_${stamp}`,
      role: 'assistant',
      text: clipText(assistantText, 8000),
      createdAt: new Date(now + 1).toISOString(),
      ts: now + 1,
      label,
      day,
    };

    // Load existing window / recent for packing
    let prevWindow = { turns: [], dayDigests: [], monthSummaries: [], seasonSummary: '', summary: '' };
    if (isFirebaseReady()) {
      try {
        const snap = await rootRef(
          `${owner.base}/threads/${threadId}/window`,
        ).get();
        if (snap.exists()) prevWindow = { ...prevWindow, ...snap.val() };
      } catch (_) {}
    }

    let recent = Array.isArray(prevWindow.turns) ? [...prevWindow.turns] : [];
    recent.push(
      { role: 'user', text: userMsg.text },
      { role: 'assistant', text: botMsg.text },
    );
    const planMemory = course ? null : await this.memoryForUid(uid);
    const keepTurns = course
      ? control.courseRecentTurns || COURSE_RECENT_TURNS
      : voice
        ? LIVE_KEEP_TURNS
        : planMemory.turns;
    recent = lastCount(recent, keepTurns);
    if (!course) {
      const locked = await lockedSessionName(bases, sid);
      if (locked) name = locked;
      else {
        const topic = topicLine([...recent, userMsg]);
        if (topic) name = topic;
        else if (isWeakTitle(name)) name = 'सामान्य बातचीत';
      }
    }

    if (course) {
      // Past-day memory stays the GPT day summary. Today's live turns stay in `turns`.
      prevWindow = {
        ...prevWindow,
        turns: recent,
        updatedAt: now,
      };
    } else {
      let summary = String(prevWindow.summary || '');
      if (recent.length > 24) {
        summary = recent
          .slice(0, -16)
          .slice(-20)
          .map((m) => `${m.role === 'user' ? 'किसान' : 'AG'}: ${clipText(m.text, 160)}`)
          .join(' | ')
          .slice(0, 4000);
      }
      prevWindow = {
        ...prevWindow,
        turns: recent,
        summary,
        updatedAt: now,
      };
    }

    if (!isFirebaseReady()) {
      console.warn(
        '[ai-context] RTDB offline — chat NOT durable. Add serviceAccountKey.json',
      );
      return {
        threadId,
        sessionId: sid,
        history: recent,
        summary: prevWindow.summary || prevWindow.seasonSummary || '',
        storage: 'memory',
        durable: false,
      };
    }

    const meta = {
      mode: course ? 'course' : 'chat',
      cropId: cropId || null,
      sessionId: sid,
      name,
      label,
      email: email ? String(email).trim().toLowerCase() : null,
      uid: uid || null,
      updatedAt: now,
      storage: 'rtdb',
      courseKeepDays: course ? COURSE_KEEP_DAYS : null,
      contextMaxTurns: course ? COURSE_RECENT_TURNS : MAIN_MAX_TURNS,
    };

    const sessionMeta = {
      id: sid,
      threadId,
      name,
      ...(course ? {} : { topic: name }),
      mode: course ? 'course' : 'chat',
      cropId: cropId || null,
      email: email ? String(email).trim().toLowerCase() : null,
      uid: uid || null,
      updatedAt: now,
      lastMessageAt: now,
    };

    try {
      await this.writeToBases(bases, `threads/${threadId}/meta`, meta, {
        merge: true,
      });
      await this.writeToBases(bases, `sessions/${sid}`, sessionMeta, {
        merge: true,
      });

      if (course) {
        await this.writeToBases(
          bases,
          `threads/${threadId}/days/${day}/messages/${userMsg.id}`,
          userMsg,
        );
        await this.writeToBases(
          bases,
          `threads/${threadId}/days/${day}/messages/${botMsg.id}`,
          botMsg,
        );
      } else {
        await this.writeToBases(
          bases,
          `threads/${threadId}/messages/${userMsg.id}`,
          userMsg,
        );
        await this.writeToBases(
          bases,
          `threads/${threadId}/messages/${botMsg.id}`,
          botMsg,
        );
        void MAIN_MAX_STORE;
      }

      await this.writeToBases(bases, `threads/${threadId}/window`, prevWindow);
    } catch (e) {
      console.error('[ai-context] RTDB append failed:', e.message);
      return {
        threadId,
        sessionId: sid,
        history: recent,
        summary: prevWindow.summary || '',
        storage: 'error',
        durable: false,
      };
    }

    if (email && uid) await this.linkEmailToUid(email, uid);

    return {
      threadId,
      sessionId: sid,
      name,
      history: recent,
      summary: prevWindow.seasonSummary || prevWindow.summary || '',
      storage: 'rtdb',
      durable: true,
      day: course ? day : null,
    };
  },

  /** Sync full message list from app → RTDB (login required). Dual-writes email+uid. */
  async syncThreadMessages({
    uid,
    email,
    ip,
    mode = 'chat',
    cropId = null,
    sessionId = null,
    chatName = null,
    messages = [],
  }) {
    if (!uid && !email) {
      return { ok: false, error: 'login_required', storage: 'none' };
    }
    if (!isFirebaseReady()) {
      return { ok: false, error: 'rtdb_offline', storage: 'none' };
    }

    let resolvedUid = uid;
    if (!resolvedUid && email) {
      resolvedUid = await this.resolveUidByEmail(email);
    }
    const bases = this.ownerBases({ uid: resolvedUid, email, ip });
    const threadId = threadIdFor({ mode, cropId, sessionId });
    if (!threadId) {
      return { ok: false, error: 'no_thread', storage: 'none' };
    }
    const sid = sessionIdFromThread(threadId);
    const course = isCourseThread(threadId);
    const now = Date.now();

    const cleaned = (messages || [])
      .map((m, i) => {
        const rawUrl = String(m.imageUrl || m.imagePath || m.mediaPath || '');
        const imageUrl = rawUrl.startsWith('http') ? rawUrl : '';
        const text = String(m.text || '').trim();
        if ((!text && !imageUrl) || String(m.id || '').startsWith('welcome_')) return null;
        const ts =
          Date.parse(m.createdAt || '') || now - (messages.length - i) * 1000;
        return {
          id: String(m.id || `m_${ts}`),
          role: m.role === 'assistant' || m.role === 'bot' ? 'assistant' : 'user',
          text: clipText(text || (imageUrl ? 'फोटो' : ''), 4000),
          createdAt: m.createdAt || new Date(ts).toISOString(),
          ts,
          day: dayKey(new Date(ts)),
          dosageHighlight: m.dosageHighlight || null,
          cropTag: m.cropTag || cropId || null,
          ...(imageUrl
            ? {
                imageUrl,
                imagePath: imageUrl,
                mediaPath: imageUrl,
                mediaType: 'image',
              }
            : {}),
        };
      })
      .filter(Boolean);

    // An empty payload must not zero msgCount or hide the course.
    if (!cleaned.length) {
      return { ok: true, skipped: true, threadId, sessionId: sid, count: 0 };
    }

    const locked = course ? '' : await lockedSessionName(bases, sid);
    const topic = course || locked ? '' : topicLine(cleaned);
    const name = course
      ? `Course ${cropId || ''}`.trim()
      : locked || topic || (isWeakTitle(chatName) ? 'सामान्य बातचीत' : defaultChatName(chatName, sid));

    try {
      await this.writeToBases(
        bases,
        `threads/${threadId}/meta`,
        {
          mode: course ? 'course' : 'chat',
          cropId: cropId || null,
          sessionId: sid,
          name,
          email: email ? String(email).trim().toLowerCase() : null,
          uid: resolvedUid || null,
          msgCount: cleaned.length,
          updatedAt: now,
          storage: 'rtdb',
        },
        { merge: true },
      );
      await this.writeToBases(
        bases,
        `sessions/${sid}`,
        {
          id: sid,
          threadId,
          name,
          topic: locked || topic || null,
          ...(locked ? { custom: true } : {}),
          mode: course ? 'course' : 'chat',
          cropId: cropId || null,
          email: email ? String(email).trim().toLowerCase() : null,
          uid: resolvedUid || null,
          msgCount: cleaned.length,
          updatedAt: now,
          lastMessageAt: now,
        },
        { merge: true },
      );

      if (course) {
        // Group by day for full season course
        const byDay = {};
        for (const m of cleaned) {
          if (!byDay[m.day]) byDay[m.day] = [];
          byDay[m.day].push(m);
        }
        const days = Object.keys(byDay).sort().slice(-COURSE_KEEP_DAYS);
        const dayDigests = [];
        for (const d of days) {
          const list = byDay[d];
          const updates = {};
          for (const m of list) updates[m.id] = m;
          for (const base of bases) {
            await rootRef(`${base}/threads/${threadId}/days/${d}/messages`).update(
              updates,
            );
          }
          const official = list.find(
            (m) =>
              String(m.id || '').startsWith('summary_') ||
              m.kind === 'daily_summary',
          );
          if (!official?.text) continue;
          let brief = String(official.text);
          const splitAt = brief.indexOf('\n');
          if (brief.startsWith('आज का सारांश') && splitAt > 0) {
            brief = brief.slice(splitAt + 1);
          }
          const digest = {
            day: d,
            text: clipText(brief, 280),
            updatedAt: now,
          };
          await this.writeToBases(
            bases,
            `threads/${threadId}/days/${d}/digest`,
            digest,
          );
          dayDigests.push(digest);
        }

        // Month summaries
        const monthMap = {};
        for (const d of dayDigests) {
          const mo = d.day.slice(0, 7);
          if (!monthMap[mo]) monthMap[mo] = [];
          monthMap[mo].push(d);
        }
        const monthSummaries = [];
        for (const [mo, digs] of Object.entries(monthMap)) {
          const text = digs
            .map((x) => `${x.day.slice(8)}: ${clipText(x.text, 140)}`)
            .join(' · ')
            .slice(0, 4000);
          monthSummaries.push({ month: mo, text, updatedAt: now });
          await this.writeToBases(
            bases,
            `threads/${threadId}/months/${mo}/summary`,
            { month: mo, text, updatedAt: now },
          );
        }

        const seasonSummary = monthSummaries
          .slice(-COURSE_MONTH_SUMMARIES)
          .map((m) => `${m.month}: ${clipText(m.text, 500)}`)
          .join('\n')
          .slice(0, 8000);

        const turns = turnsFromMessages(
          cleaned.filter((m) => !String(m.id || '').startsWith('summary_')),
          COURSE_RECENT_TURNS,
        );
        await this.writeToBases(bases, `threads/${threadId}/window`, {
          turns,
          dayDigests: dayDigests.slice(-COURSE_DAY_DIGESTS),
          monthSummaries: monthSummaries.slice(-COURSE_MONTH_SUMMARIES),
          seasonSummary,
          summary: seasonSummary,
          updatedAt: now,
        });
      } else {
        const planMemory = await this.memoryForUid(resolvedUid);
        const slice = cleaned.slice(-MAIN_MAX_STORE);
        const updates = {};
        for (const m of slice) updates[m.id] = m;
        for (const base of bases) {
          await rootRef(`${base}/threads/${threadId}/messages`).update(updates);
        }
        await this.writeToBases(bases, `threads/${threadId}/window`, {
          turns: turnsFromMessages(slice, planMemory.turns),
          summary: '',
          updatedAt: now,
        });
      }

      if (email && resolvedUid) await this.linkEmailToUid(email, resolvedUid);

      return {
        ok: true,
        storage: 'rtdb',
        threadId,
        sessionId: sid,
        name,
        count: cleaned.length,
        course,
      };
    } catch (e) {
      console.error('[ai-context] sync failed:', e.message);
      return { ok: false, error: 'sync_failed', storage: 'rtdb' };
    }
  },

  /** Restore messages from RTDB for UI. */
  async restoreThreadMessages({
    uid,
    email,
    ip,
    mode = 'chat',
    cropId = null,
    sessionId = null,
    limit = 400,
  }) {
    if (!uid && !email) return { messages: [], storage: 'none' };
    if (!isFirebaseReady()) return { messages: [], storage: 'rtdb_offline' };

    let resolvedUid = uid;
    if (!resolvedUid && email) {
      resolvedUid = await this.resolveUidByEmail(email);
    }
    const owner = this.ownerPath({ uid: resolvedUid, email, ip });
    const threadId = threadIdFor({ mode, cropId, sessionId });
    const course = isCourseThread(threadId);
    const base = `${owner.base}/threads/${threadId}`;

    try {
      const out = [];
      if (course) {
        let daysSnap = await rootRef(`${base}/days`).get();
        let days = daysSnap.val() || {};
        if (!Object.keys(days).length && email && owner.kind === 'user') {
          const ek = emailKey(email);
          daysSnap = await rootRef(
            `email_users/${ek}/ai/threads/${threadId}/days`,
          ).get();
          days = daysSnap.val() || {};
        }
        const dayKeys = Object.keys(days).sort().slice(-COURSE_KEEP_DAYS);
        for (const d of dayKeys) {
          const msgs = days[d]?.messages || {};
          for (const m of Object.values(msgs)) {
            if (m?.text) out.push(m);
          }
        }
      } else {
        let snap = await rootRef(`${base}/messages`).get();
        let msgs = snap.val() || {};
        if (!Object.keys(msgs).length && email && owner.kind === 'user') {
          const ek = emailKey(email);
          snap = await rootRef(
            `email_users/${ek}/ai/threads/${threadId}/messages`,
          ).get();
          msgs = snap.val() || {};
        }
        for (const m of Object.values(msgs)) {
          if (m?.text) out.push(m);
        }
      }

      out.sort((a, b) => (a.ts || 0) - (b.ts || 0));
      return {
        messages: out.slice(-limit),
        storage: 'rtdb',
        threadId,
        sessionId: sessionIdFromThread(threadId),
        source: 'user_ai',
      };
    } catch (e) {
      console.warn('[ai-context] restore skip:', e.message);
      return { messages: [], storage: 'error' };
    }
  },

  /** List named chat sessions (and course threads) for this email/uid. */
  async listSessions({ uid, email, ip, mode = null }) {
    if (!uid && !email) return { sessions: [] };
    if (!isFirebaseReady()) return { sessions: [], storage: 'rtdb_offline' };

    let resolvedUid = uid;
    if (!resolvedUid && email) {
      resolvedUid = await this.resolveUidByEmail(email);
    }
    const owner = this.ownerPath({ uid: resolvedUid, email, ip });

    try {
      let snap = await rootRef(`${owner.base}/sessions`).get();
      let raw = snap.val() || {};
      if (!Object.keys(raw).length && email && owner.kind === 'user') {
        const ek = emailKey(email);
        snap = await rootRef(`email_users/${ek}/ai/sessions`).get();
        raw = snap.val() || {};
      }

      let sessions = Object.values(raw).filter((s) => s && s.id);
      if (mode === 'chat') {
        sessions = sessions.filter((s) => s.mode !== 'course');
      } else if (mode === 'course') {
        sessions = sessions.filter((s) => s.mode === 'course' || String(s.threadId || s.id || '').startsWith('course_'));
      }
      sessions = sessions.filter((s) => {
        if (s.mode === 'course' || String(s.threadId || s.id || '').startsWith('course_')) {
          return Boolean(s.cropId || String(s.id || '').startsWith('course_'));
        }
        const n = Number(s.msgCount);
        if (Number.isFinite(n)) return n > 0;
        const name = String(s.name || '').trim();
        return name && name !== 'नई चैट' && name !== 'New chat' && name !== 'General Chat';
      });
      sessions.sort(
        (a, b) => (b.lastMessageAt || b.updatedAt || 0) - (a.lastMessageAt || a.updatedAt || 0),
      );
      if (mode !== 'course') {
        const bases = this.ownerBases({ uid: resolvedUid, email, ip });
        await Promise.all(
          sessions.slice(0, 40).map(async (s) => {
            if (
              s.mode === 'course' ||
              String(s.threadId || s.id || '').startsWith('course_')
            ) {
              return;
            }
            if (s.custom === true && String(s.name || '').trim()) {
              s.topic = String(s.name).trim();
              return;
            }
            const saved = String(s.topic || '').trim();
            if (saved && !isWeakTitle(saved)) {
              s.name = saved;
              return;
            }
            const threadId =
              s.threadId || threadIdFor({ mode: 'chat', sessionId: s.id });
            if (!threadId) return;
            try {
              const snap = await rootRef(
                `${owner.base}/threads/${threadId}/messages`,
              ).get();
              let rows = Object.values(snap.val() || {});
              if (!rows.length) {
                const win = await rootRef(
                  `${owner.base}/threads/${threadId}/window`,
                ).get();
                const turns = win.val()?.turns;
                rows = Array.isArray(turns) ? turns : [];
              }
              const topic = topicLine(rows);
              if (!topic) return;
              s.name = topic;
              s.topic = topic;
              await this.writeToBases(
                bases,
                `sessions/${s.id}`,
                { name: topic, topic },
                { merge: true },
              );
            } catch {
              /* keep the old title if this thread cannot be read */
            }
          }),
        );
      }
      if (mode === 'course') {
        try {
          const threads = await rootRef(`${owner.base}/threads`).get();
          const known = new Set(
            sessions.map((s) => String(s.threadId || s.id || '')),
          );
          for (const [id, row] of Object.entries(threads.val() || {})) {
            if (!id.startsWith('course_') || known.has(id)) continue;
            const cropId = row?.meta?.cropId || id.slice(7);
            if (!cropId) continue;
            sessions.push({
              id,
              threadId: id,
              mode: 'course',
              cropId,
              name: row?.meta?.name || cropId,
              msgCount: row?.meta?.msgCount || 1,
              updatedAt: row?.meta?.updatedAt || 0,
            });
          }
        } catch {
          /* session list is enough */
        }
      }
      return { sessions, storage: 'rtdb' };
    } catch (e) {
      console.warn('[ai-context] list sessions skip:', e.message);
      return { sessions: [], storage: 'error' };
    }
  },

  /** Create / rename a normal chat session under this email. */
  async upsertSession({
    uid,
    email,
    ip,
    sessionId = null,
    chatName = null,
  }) {
    if (!uid && !email) {
      return { ok: false, error: 'login_required' };
    }
    const now = Date.now();
    const sid = safeId(sessionId) || `s_${now}`;
    const threadId = threadIdFor({ mode: 'chat', sessionId: sid });
    const given = String(chatName || '').trim().slice(0, 40);
    const custom = given.length > 0;
    const name = custom ? given : defaultChatName(chatName, sid);
    const resolvedUid = uid || (email ? await this.resolveUidByEmail(email) : null);
    const bases = this.ownerBases({ uid: resolvedUid, email, ip });

    if (!isFirebaseReady()) {
      return { ok: false, error: 'rtdb_offline', sessionId: sid, threadId, name };
    }

    const sessionMeta = {
      id: sid,
      threadId,
      name,
      topic: name,
      ...(custom ? { custom: true } : {}),
      mode: 'chat',
      cropId: null,
      email: email ? String(email).trim().toLowerCase() : null,
      uid: resolvedUid || null,
      updatedAt: now,
    };

    await this.writeToBases(bases, `sessions/${sid}`, sessionMeta, {
      merge: true,
    });
    await this.writeToBases(
      bases,
      `threads/${threadId}/meta`,
      {
        mode: 'chat',
        sessionId: sid,
        name,
        email: sessionMeta.email,
        uid: resolvedUid || null,
        updatedAt: now,
        storage: 'rtdb',
      },
      { merge: true },
    );
    if (email && resolvedUid) await this.linkEmailToUid(email, resolvedUid);

    return { ok: true, sessionId: sid, threadId, name, storage: 'rtdb' };
  },

  /** Delete one normal chat. Never a course thread, never another farmer. */
  async deleteSession({ uid, email, ip, sessionId = null }) {
    if (!uid && !email) return { ok: false, error: 'login_required' };
    const sid = safeId(sessionId, 40);
    if (!sid || sid.startsWith('course')) {
      return { ok: false, error: 'not_chat' };
    }
    const resolvedUid = uid || (email ? await this.resolveUidByEmail(email) : null);
    const bases = this.ownerBases({ uid: resolvedUid, email, ip });
    if (!bases.length) return { ok: false, error: 'login_required' };
    if (!isFirebaseReady()) return { ok: false, error: 'rtdb_offline' };

    let threadId = threadIdFor({ mode: 'chat', sessionId: sid });
    try {
      const snap = await rootRef(`${bases[0]}/sessions/${sid}`).get();
      const row = snap.val();
      const stored = String(row?.threadId || '');
      if (
        row?.mode === 'course' ||
        stored.startsWith('course_') ||
        sid.startsWith('course_')
      ) {
        return { ok: false, error: 'not_chat' };
      }
      if (stored && (stored === 'main' || stored.startsWith('chat_'))) {
        threadId = stored;
      }
    } catch {
      /* still remove the chat path */
    }
    if (!threadId || isCourseThread(threadId)) {
      return { ok: false, error: 'not_chat' };
    }

    const kept = await this.archiveDeletedChat(bases[0], threadId, sid);
    if (kept === false) {
      return { ok: false, error: 'archive_failed' };
    }

    await Promise.all(
      bases.map(async (base) => {
        await rootRef(`${base}/sessions/${sid}`).remove();
        await rootRef(`${base}/threads/${threadId}`).remove();
      }),
    );
    return { ok: true, sessionId: sid, threadId };
  },

  /**
   * Copy one deleted chat into the training box, then the caller removes it
   * from the farmer's own chat. Returns false only when a real chat could
   * not be saved. An empty chat returns true so it can still be removed.
   */
  async archiveDeletedChat(base, threadId, sid) {
    let rows = [];
    let title = '';
    try {
      const [msgSnap, winSnap, sesSnap] = await Promise.all([
        rootRef(`${base}/threads/${threadId}/messages`).get(),
        rootRef(`${base}/threads/${threadId}/window`).get(),
        rootRef(`${base}/sessions/${sid}`).get(),
      ]);
      rows = Object.values(msgSnap.val() || {});
      if (!rows.length) {
        const turns = winSnap.val()?.turns;
        rows = Array.isArray(turns) ? turns : [];
      }
      title = String(sesSnap.val()?.name || sesSnap.val()?.topic || '').trim();
    } catch (e) {
      console.warn('[ai-context] training read skip:', e.message);
      return false;
    }

    const messages = rows
      .map((m) => {
        const text = stripAccountSecrets(m?.text || '');
        if (!text) return null;
        const role = m?.role === 'assistant' || m?.role === 'bot' ? 'assistant' : 'user';
        return {
          role,
          text: clipText(text, 4000),
          ts: Number(m?.ts) || Date.parse(m?.createdAt || '') || 0,
        };
      })
      .filter(Boolean)
      .sort((a, b) => a.ts - b.ts)
      .slice(-400);

    if (!messages.length) return true;

    const id = `d_${Date.now()}_${randomBytes(4).toString('hex')}`;
    try {
      await rootRef(`training/deleted_chats/${id}`).set({
        id,
        purpose: 'train',
        hidden: true,
        name: stripAccountSecrets(title).slice(0, 80),
        messages,
        deletedAt: Date.now(),
      });
      return true;
    } catch (e) {
      console.warn('[ai-context] training save skip:', e.message);
      return false;
    }
  },

  async mergeIntoUid({ uid, email, ip }) {
    if (!uid) return;
    if (email) await this.linkEmailToUid(email, uid);
    if (!isFirebaseReady()) return;

    const sources = [];
    if (email) sources.push(`email_users/${emailKey(email)}/ai`);
    if (ip) sources.push(`guests/${hashIp(ip)}/ai`);

    for (const srcBase of sources) {
      try {
        const snap = await rootRef(`${srcBase}/threads`).get();
        const threads = snap.val() || {};
        for (const [tid, tdata] of Object.entries(threads)) {
          const dest = `users/${uid}/ai/threads/${tid}`;
          const existing = await rootRef(`${dest}/window`).get();
          if (!existing.exists() && tdata?.window) {
            await rootRef(`${dest}/window`).set(tdata.window);
            await rootRef(`${dest}/meta`).update({
              ...(tdata.meta || {}),
              mergedFrom: srcBase,
              updatedAt: Date.now(),
            });
          }
        }
      } catch (e) {
        console.warn('[ai-context] merge skip:', e.message);
      }
    }

    await this.setControl(
      { uid, email },
      { uid, email: email ? String(email).trim().toLowerCase() : null },
    );
  },

  async getQuota({ uid, email, ip }, day = dayKey()) {
    const owner = this.ownerPath({ uid, email, ip });
    if (!isFirebaseReady()) return { chat: 0, image: 0, day };
    try {
      const snap = await rootRef(`${owner.base}/quota/control`).get();
      if (snap.exists()) return snap.val();
      const daySnap = await rootRef(`${owner.base}/quota/${day}`).get();
      return daySnap.exists() ? daySnap.val() : { chat: 0, image: 0, day };
    } catch {
      return { chat: 0, image: 0, day };
    }
  },

  /**
   * Full per-account usage + caps. No phone / email / secrets.
   * users/{uid}/ai/quota/{day}
   * users/{uid}/ai/quota/control
   * users/{uid}/ai/quota/life
   */
  async writeQuotaSnapshot({ uid, email, ip }, snapshot = {}) {
    const bases = this.ownerBases({ uid, email, ip });
    if (!isFirebaseReady() || !bases.length) return;
    const day = snapshot.day || dayKey();
    const now = Date.now();
    const dayRow = {
      day,
      planId: snapshot.planId || 'free',
      chat: Number(snapshot.chat || 0),
      image: Number(snapshot.image || 0),
      deep: Number(snapshot.deep || 0),
      strong: Number(snapshot.strong || 0),
      voice: Number(snapshot.voice || 0),
      voiceMini: Number(snapshot.voiceMini || 0),
      videoUsed: Number(snapshot.videoUsed || 0),
      guestChat: Number(snapshot.guestChat || 0),
      guestLive: Number(snapshot.guestLive || 0),
      updatedAt: now,
    };
    const control = {
      day,
      planId: snapshot.planId || 'free',
      guest: snapshot.guest === true,
      chatUsed: dayRow.chat,
      chatCap: snapshot.chatCap ?? 0,
      imageUsed: dayRow.image,
      imageCap: snapshot.imageCap ?? 0,
      deepUsed: dayRow.deep,
      deepCap: snapshot.deepCap ?? 0,
      strongUsed: dayRow.strong,
      strongCap: snapshot.strongCap ?? 0,
      voiceUsed: dayRow.voice,
      voiceCap: snapshot.voiceCap ?? 0,
      liveMiniUsed: dayRow.voiceMini,
      liveMiniCap: snapshot.liveMiniCap ?? 0,
      liveMiniPer: snapshot.liveMiniPer || 'day',
      videoUsed: dayRow.videoUsed,
      videoCap: snapshot.videoCap ?? 0,
      guestChatUsed: dayRow.guestChat,
      guestChatCap: snapshot.guestChatCap ?? 0,
      guestLiveUsed: dayRow.guestLive,
      guestLiveCap: snapshot.guestLiveCap ?? 0,
      updatedAt: now,
    };
    const life = {
      voice: Number(snapshot.voiceLife || 0),
      bankChat: Number(snapshot.bankChat || 0),
      bankStrong: Number(snapshot.bankStrong || 0),
      guestChat: dayRow.guestChat,
      guestLive: dayRow.guestLive,
      updatedAt: now,
    };
    try {
      await Promise.all(
        bases.flatMap((base) => [
          rootRef(`${base}/quota/${day}`).set(dayRow),
          rootRef(`${base}/quota/control`).set(control),
          rootRef(`${base}/quota/life`).set(life),
        ]),
      );
    } catch (e) {
      console.warn('[ai-context] quota skip:', e.message);
    }
    return control;
  },

  async bumpQuota({ uid, email, ip }, kind = 'chat') {
    const day = dayKey();
    const prev = await this.getQuota({ uid, email, ip }, day);
    return this.writeQuotaSnapshot(
      { uid, email, ip },
      {
        day,
        planId: prev.planId || 'free',
        chat: Number(prev.chatUsed ?? prev.chat ?? 0) + (kind === 'chat' ? 1 : 0),
        image: Number(prev.imageUsed ?? prev.image ?? 0) + (kind === 'image' ? 1 : 0),
        deep: Number(prev.deepUsed ?? prev.deep ?? 0) + (kind === 'deep' ? 1 : 0),
        strong: Number(prev.strongUsed ?? prev.strong ?? 0),
        voice: Number(prev.voiceUsed ?? prev.voice ?? 0),
        voiceMini: Number(prev.liveMiniUsed ?? prev.voiceMini ?? 0),
        videoUsed: Number(prev.videoUsed ?? 0),
        guestChat: Number(prev.guestChatUsed ?? prev.guestChat ?? 0),
        guestLive: Number(prev.guestLiveUsed ?? prev.guestLive ?? 0),
      },
    );
  },

  /**
   * Admin only: list this user's chat sessions and course threads separately.
   * Never merges chat_* with course_*.
   */
  async adminListThreads({ uid, email }) {
    if (!uid && !email) {
      throw Object.assign(new Error('uid or email required'), { status: 400 });
    }
    if (!isFirebaseReady()) {
      return { chats: [], courses: [], storage: 'rtdb_offline' };
    }
    let resolvedUid = uid;
    if (!resolvedUid && email) {
      resolvedUid = await this.resolveUidByEmail(email);
    }
    const [chatPack, coursePack] = await Promise.all([
      this.listSessions({ uid: resolvedUid, email, mode: 'chat' }),
      this.listSessions({ uid: resolvedUid, email, mode: 'course' }),
    ]);

    const chats = [];
    const courses = [];
    const seenChat = new Set();
    const seenCourse = new Set();

    for (const s of chatPack.sessions || []) {
      if (s.mode === 'course' || String(s.threadId || s.id || '').startsWith('course_')) {
        continue;
      }
      const sid = String(s.id || sessionIdFromThread(s.threadId) || '').trim();
      if (!sid || seenChat.has(sid)) continue;
      seenChat.add(sid);
      chats.push({
        kind: 'chat',
        id: sid,
        sessionId: sid,
        threadId: s.threadId || threadIdFor({ mode: 'chat', sessionId: sid }),
        name: String(s.topic || s.name || sid).trim() || sid,
        msgCount: Number(s.msgCount) || 0,
        updatedAt: s.lastMessageAt || s.updatedAt || 0,
      });
    }

    for (const s of coursePack.sessions || []) {
      const tid = String(s.threadId || s.id || '');
      if (!tid.startsWith('course_') && s.mode !== 'course') continue;
      const cropId = String(s.cropId || tid.replace(/^course_/, '') || '').trim();
      if (!cropId || seenCourse.has(cropId)) continue;
      seenCourse.add(cropId);
      courses.push({
        kind: 'course',
        id: `course_${cropId}`,
        cropId,
        threadId: `course_${cropId}`,
        name: String(s.name || cropId).trim() || cropId,
        msgCount: Number(s.msgCount) || 0,
        updatedAt: s.lastMessageAt || s.updatedAt || 0,
      });
    }

    // Scan threads node for anything sessions missed (isolation: bucket by prefix only).
    const owner = this.ownerPath({ uid: resolvedUid, email });
    try {
      const paths = [owner.base];
      const ek = emailKey(email);
      if (ek && owner.kind === 'user') paths.push(`email_users/${ek}/ai`);
      for (const base of paths) {
        const snap = await rootRef(`${base}/threads`).get();
        for (const [tid, row] of Object.entries(snap.val() || {})) {
          if (tid.startsWith('course_')) {
            const cropId = String(row?.meta?.cropId || tid.slice(7) || '').trim();
            if (!cropId || seenCourse.has(cropId)) continue;
            seenCourse.add(cropId);
            courses.push({
              kind: 'course',
              id: `course_${cropId}`,
              cropId,
              threadId: `course_${cropId}`,
              name: String(row?.meta?.name || cropId).trim() || cropId,
              msgCount: Number(row?.meta?.msgCount) || 0,
              updatedAt: row?.meta?.updatedAt || 0,
            });
            continue;
          }
          if (tid === 'main' || tid.startsWith('chat_')) {
            const sid = sessionIdFromThread(tid);
            if (!sid || seenChat.has(sid)) continue;
            seenChat.add(sid);
            chats.push({
              kind: 'chat',
              id: sid,
              sessionId: sid,
              threadId: tid,
              name: String(row?.meta?.name || row?.meta?.topic || sid).trim() || sid,
              msgCount: Number(row?.meta?.msgCount) || 0,
              updatedAt: row?.meta?.updatedAt || 0,
            });
          }
        }
      }
    } catch (e) {
      console.warn('[ai-context] admin thread scan skip:', e.message);
    }

    chats.sort((a, b) => (b.updatedAt || 0) - (a.updatedAt || 0));
    courses.sort((a, b) => (b.updatedAt || 0) - (a.updatedAt || 0));
    return {
      uid: resolvedUid || null,
      email: emailKey(email) || null,
      chats,
      courses,
      storage: 'rtdb',
    };
  },

  /**
   * Admin only: read one thread. mode must be chat XOR course.
   * Chat → sessionId only. Course → cropId only. Never both mixed.
   */
  async adminReadThread({ uid, email, mode, sessionId = null, cropId = null, limit = 200 }) {
    if (!uid && !email) {
      throw Object.assign(new Error('uid or email required'), { status: 400 });
    }
    const m = String(mode || '').toLowerCase();
    if (m === 'course' || m === 'fasal') {
      let crop = String(cropId || '').trim();
      if (crop.startsWith('course_')) crop = crop.slice(7);
      if (!crop || crop === 'all') {
        throw Object.assign(new Error('cropId required for course'), { status: 400 });
      }
      const cap = Math.max(1, Math.min(2000, Number(limit) || 400));
      const pack = await this.restoreThreadMessages({
        uid,
        email,
        mode: 'course',
        cropId: crop,
        sessionId: null,
        limit: cap,
      });
      return {
        mode: 'course',
        cropId: crop,
        threadId: pack.threadId || `course_${crop}`,
        sessionId: null,
        messages: (pack.messages || []).map((row) => ({
          id: row.id || null,
          role: row.role === 'assistant' || row.role === 'bot' ? 'assistant' : 'user',
          text: stripAccountSecrets(row.text || ''),
          ts: row.ts || null,
          createdAt: row.createdAt || null,
        })),
        storage: pack.storage,
      };
    }
    if (m !== 'chat') {
      throw Object.assign(new Error('mode must be chat or course'), { status: 400 });
    }
    let sid = String(sessionId || '').trim();
    if (sid.startsWith('chat_')) sid = sid.slice(5);
    if (!sid) {
      throw Object.assign(new Error('sessionId required for chat'), { status: 400 });
    }
    const cap = Math.max(1, Math.min(400, Number(limit) || 200));
    const pack = await this.restoreThreadMessages({
      uid,
      email,
      mode: 'chat',
      cropId: null,
      sessionId: sid,
      limit: cap,
    });
    return {
      mode: 'chat',
      sessionId: sid,
      cropId: null,
      threadId: pack.threadId || threadIdFor({ mode: 'chat', sessionId: sid }),
      messages: (pack.messages || []).map((row) => ({
        id: row.id || null,
        role: row.role === 'assistant' || row.role === 'bot' ? 'assistant' : 'user',
        text: stripAccountSecrets(row.text || ''),
        ts: row.ts || null,
        createdAt: row.createdAt || null,
      })),
      storage: pack.storage,
    };
  },

  /** Admin: zero today's usage counters (caps stay from plan). */
  async adminResetDayQuota({ uid, email }) {
    if (!uid && !email) throw Object.assign(new Error('uid or email required'), { status: 400 });
    const day = dayKey();
    const prev = await this.getQuota({ uid, email }, day);
    await this.writeQuotaSnapshot(
      { uid, email },
      {
        day,
        planId: prev.planId || 'free',
        chat: 0,
        image: 0,
        deep: 0,
        strong: 0,
        voice: 0,
        voiceMini: 0,
        videoUsed: 0,
        guestChat: 0,
        guestLive: 0,
      },
    );
    return this.getQuota({ uid, email }, day);
  },

  async adminGetUser({ uid, email }) {
    let resolvedUid = uid;
    if (!resolvedUid && email) {
      resolvedUid = await this.resolveUidByEmail(email);
    }
    const control = await this.getControl({ uid: resolvedUid, email });
    const window = await this.getWindow({
      uid: resolvedUid,
      email,
      mode: 'chat',
    });
    const quota = await this.getQuota({ uid: resolvedUid, email });
    let place = '';
    let lat = null;
    let lon = null;
    if (isFirebaseReady() && resolvedUid) {
      try {
        const ek = emailKey(email || control.email);
        const [locSnap, emailLocSnap] = await Promise.all([
          rootRef(`users/${resolvedUid}/location`).get(),
          ek
            ? rootRef(`email_users/${ek}/location`).get()
            : Promise.resolve({ val: () => null }),
        ]);
        const candidates = [locSnap.val(), emailLocSnap.val()].filter(Boolean);
        let best = null;
        let bestScore = -1;
        for (const loc of candidates) {
          const p = String(loc.place || '').trim();
          const la = Number(loc.lat);
          const lo = Number(loc.lon);
          const hasCoords =
            Number.isFinite(la) &&
            Number.isFinite(lo) &&
            Math.abs(la) + Math.abs(lo) > 0.0001;
          if (!p && !hasCoords) continue;
          let score = 0;
          if (p) score += 4;
          if (hasCoords) score += 2;
          if (loc.precise !== false) score += 1;
          if (score > bestScore) {
            bestScore = score;
            best = { place: p, lat: hasCoords ? la : null, lon: hasCoords ? lo : null };
          }
        }
        if (best) {
          place = best.place;
          lat = best.lat;
          lon = best.lon;
        }
      } catch (_) {
        /* ignore */
      }
    }
    return {
      uid: resolvedUid,
      email: emailKey(email) || control.email,
      control,
      threadId: window.threadId,
      historyTurns: window.history.length,
      summaryChars: String(window.summary || '').length,
      storage: window.storage,
      quota,
      place,
      lat,
      lon,
      rtdbReady: isFirebaseReady(),
    };
  },
};
