/**
 * Per-user AI chat + context — Realtime Database is the source of truth.
 * Always dual-written under uid AND email when both are known.
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
import { hashIp } from '../middleware/client_ip.js';
import { emailKey } from '../utils/email_key.js';

/** Normal chat sessions */
const MAIN_MAX_STORE = 600;
const MAIN_MAX_TURNS = 60;
const MAIN_MAX_CHARS = 36000;

/** Course: full season — huge context window for the model */
const COURSE_KEEP_DAYS = 200;
const COURSE_RECENT_TURNS = 160;
const COURSE_RECENT_CHARS = 120000;
const COURSE_DAY_DIGESTS = 120;
const COURSE_MONTH_SUMMARIES = 12;
const COURSE_SUMMARY_CHARS = 24000;

function dayKey(d = new Date()) {
  return d.toISOString().slice(0, 10);
}

function monthKey(d = new Date()) {
  return d.toISOString().slice(0, 7);
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
  if ((m === 'course' || m === 'fasal') && cropId) {
    return `course_${safeId(cropId, 48)}`;
  }
  const sid = safeId(sessionId, 40);
  if (sid && sid !== 'main') return `chat_${sid}`;
  return 'main';
}

function isCourseThread(threadId) {
  return String(threadId || '').startsWith('course_');
}

function sessionIdFromThread(threadId) {
  const t = String(threadId || '');
  if (t.startsWith('chat_')) return t.slice(5);
  if (t === 'main') return 'main';
  if (t.startsWith('course_')) return t;
  return t || 'main';
}

function defaultChatName(chatName, sessionId) {
  const n = String(chatName || '').trim();
  if (n) return n.slice(0, 80);
  const sid = sessionIdFromThread(sessionId) || 'main';
  if (sid === 'main') return 'General Chat';
  return `Chat ${sid.slice(0, 12)}`;
}

function clipText(t, max = 4000) {
  const s = String(t || '').trim();
  if (s.length <= max) return s;
  return `${s.slice(0, max)}…`;
}

function turnsFromMessages(messages, maxTurns) {
  return (messages || [])
    .filter((m) => m && (m.role === 'user' || m.role === 'assistant') && m.text)
    .slice(-maxTurns)
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

function buildDigestLine(messages) {
  return (messages || [])
    .slice(-8)
    .map(
      (m) =>
        `${m.role === 'user' ? 'किसान' : 'AG'}: ${clipText(m.text, 140)}`,
    )
    .join(' | ')
    .slice(0, 900);
}

const mem = {
  control: new Map(),
  emailIndex: new Map(),
};

export const UserAiContextService = {
  emailKey,
  threadIdFor,
  isCourseThread,

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
  async getWindow({ uid, email, ip, mode, cropId, sessionId = null }) {
    const owner = this.ownerPath({ uid, email, ip });
    const threadId = threadIdFor({ mode, cropId, sessionId });
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

    const maxTurns = course
      ? control.courseRecentTurns || COURSE_RECENT_TURNS
      : control.contextMaxTurns || MAIN_MAX_TURNS;
    const maxChars = course
      ? control.courseRecentChars || COURSE_RECENT_CHARS
      : control.contextMaxChars || MAIN_MAX_CHARS;

    let history = Array.isArray(windowData.turns)
      ? windowData.turns.slice(-maxTurns)
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
      .slice(0, course ? COURSE_SUMMARY_CHARS : 4000);

    while (history.length > 8 && estimateChars(history, summary) > maxChars) {
      history = history.slice(2);
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
    clientHistory = [],
  }) {
    if (!uid && !email) {
      console.warn('[ai-context] skip persist — login/email required for RTDB chat');
    }

    const owner = this.ownerPath({ uid, email, ip });
    const bases = this.ownerBases({ uid, email, ip });
    const threadId = threadIdFor({ mode, cropId, sessionId });
    const sid = sessionIdFromThread(threadId);
    const course = isCourseThread(threadId);
    const control = await this.getControl({ uid, email, ip });
    const now = Date.now();
    const day = dayKey(new Date(now));
    const month = monthKey(new Date(now));
    const name = course
      ? `Course ${cropId || ''}`.trim()
      : defaultChatName(chatName, sid);

    const userMsg = {
      id: `u_${now}`,
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
    }
    const botMsg = {
      id: `a_${now + 1}`,
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
    if (!recent.length && Array.isArray(clientHistory) && clientHistory.length) {
      recent = turnsFromMessages(clientHistory, course ? COURSE_RECENT_TURNS : MAIN_MAX_TURNS);
    }
    recent.push(
      { role: 'user', text: userMsg.text },
      { role: 'assistant', text: botMsg.text },
    );
    const keepTurns = course
      ? control.courseRecentTurns || COURSE_RECENT_TURNS
      : control.contextMaxTurns || MAIN_MAX_TURNS;
    recent = recent.slice(-keepTurns);

    // Day digest (course): refresh today's digest from recent same-day turns
    let dayDigests = Array.isArray(prevWindow.dayDigests)
      ? [...prevWindow.dayDigests]
      : [];
    if (course) {
      const todayLine = buildDigestLine([
        { role: 'user', text: userMsg.text },
        { role: 'assistant', text: botMsg.text },
      ]);
      const idx = dayDigests.findIndex((d) => d.day === day);
      const entry = {
        day,
        text:
          idx >= 0
            ? clipText(`${dayDigests[idx].text} | ${todayLine}`, 1200)
            : todayLine,
        updatedAt: now,
      };
      if (idx >= 0) dayDigests[idx] = entry;
      else dayDigests.push(entry);
      dayDigests = dayDigests.slice(-(control.courseKeepDays || COURSE_KEEP_DAYS));

      // Month rollup from digests of this month
      let monthSummaries = Array.isArray(prevWindow.monthSummaries)
        ? [...prevWindow.monthSummaries]
        : [];
      const monthDigests = dayDigests.filter((d) => String(d.day).startsWith(month));
      const monthText = monthDigests
        .map((d) => `${d.day.slice(8)}: ${clipText(d.text, 180)}`)
        .join(' · ')
        .slice(0, 4000);
      const mi = monthSummaries.findIndex((m) => m.month === month);
      const mEntry = { month, text: monthText, updatedAt: now };
      if (mi >= 0) monthSummaries[mi] = mEntry;
      else monthSummaries.push(mEntry);
      monthSummaries = monthSummaries.slice(-COURSE_MONTH_SUMMARIES);

      // Season summary = latest months compressed
      const seasonSummary = monthSummaries
        .map((m) => `${m.month}: ${clipText(m.text, 500)}`)
        .join('\n')
        .slice(0, 8000);

      prevWindow = {
        ...prevWindow,
        turns: recent,
        dayDigests,
        monthSummaries,
        seasonSummary,
        summary: seasonSummary,
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
        await this.writeToBases(
          bases,
          `threads/${threadId}/days/${day}/digest`,
          {
            day,
            text: dayDigests[dayDigests.length - 1]?.text || '',
            updatedAt: now,
          },
        );
        await this.writeToBases(
          bases,
          `threads/${threadId}/months/${month}/summary`,
          {
            month,
            text:
              prevWindow.monthSummaries?.find((m) => m.month === month)?.text ||
              '',
            updatedAt: now,
          },
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
    const sid = sessionIdFromThread(threadId);
    const course = isCourseThread(threadId);
    const now = Date.now();
    const name = course
      ? `Course ${cropId || ''}`.trim()
      : defaultChatName(chatName, sid);

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
          const digest = {
            day: d,
            text: buildDigestLine(list),
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

        const turns = turnsFromMessages(cleaned, COURSE_RECENT_TURNS);
        await this.writeToBases(bases, `threads/${threadId}/window`, {
          turns,
          dayDigests: dayDigests.slice(-COURSE_DAY_DIGESTS),
          monthSummaries: monthSummaries.slice(-COURSE_MONTH_SUMMARIES),
          seasonSummary,
          summary: seasonSummary,
          updatedAt: now,
        });
      } else {
        const slice = cleaned.slice(-MAIN_MAX_STORE);
        const updates = {};
        for (const m of slice) updates[m.id] = m;
        for (const base of bases) {
          await rootRef(`${base}/threads/${threadId}/messages`).update(updates);
        }
        await this.writeToBases(bases, `threads/${threadId}/window`, {
          turns: turnsFromMessages(slice, MAIN_MAX_TURNS),
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
        sessions = sessions.filter((s) => s.mode === 'course');
      }
      sessions = sessions.filter((s) => {
        const n = Number(s.msgCount);
        if (Number.isFinite(n)) return n > 0;
        const name = String(s.name || '').trim();
        return name && name !== 'नई चैट' && name !== 'New chat' && name !== 'General Chat';
      });
      sessions.sort(
        (a, b) => (b.lastMessageAt || b.updatedAt || 0) - (a.lastMessageAt || a.updatedAt || 0),
      );
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
    const name = defaultChatName(chatName, sid);
    const resolvedUid = uid || (email ? await this.resolveUidByEmail(email) : null);
    const bases = this.ownerBases({ uid: resolvedUid, email, ip });

    if (!isFirebaseReady()) {
      return { ok: false, error: 'rtdb_offline', sessionId: sid, threadId, name };
    }

    const sessionMeta = {
      id: sid,
      threadId,
      name,
      mode: 'chat',
      cropId: null,
      email: email ? String(email).trim().toLowerCase() : null,
      uid: resolvedUid || null,
      updatedAt: now,
      lastMessageAt: now,
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
      const snap = await rootRef(`${owner.base}/quota/${day}`).get();
      return snap.exists() ? snap.val() : { chat: 0, image: 0, day };
    } catch {
      return { chat: 0, image: 0, day };
    }
  },

  async bumpQuota({ uid, email, ip }, kind = 'chat') {
    const owner = this.ownerPath({ uid, email, ip });
    const day = dayKey();
    const prev = await this.getQuota({ uid, email, ip }, day);
    const next = {
      day,
      chat: Number(prev.chat || 0) + (kind === 'chat' ? 1 : 0),
      image: Number(prev.image || 0) + (kind === 'image' ? 1 : 0),
      updatedAt: Date.now(),
    };
    if (isFirebaseReady()) {
      try {
        await rootRef(`${owner.base}/quota/${day}`).set(next);
      } catch (e) {
        console.warn('[ai-context] quota skip:', e.message);
      }
    }
    return next;
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
    return {
      uid: resolvedUid,
      email: emailKey(email) || control.email,
      control,
      threadId: window.threadId,
      historyTurns: window.history.length,
      summaryChars: String(window.summary || '').length,
      storage: window.storage,
      quota,
      rtdbReady: isFirebaseReady(),
    };
  },
};
