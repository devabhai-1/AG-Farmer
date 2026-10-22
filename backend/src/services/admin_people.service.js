import { isFirebaseReady, rootRef } from '../config/firebase.js';
import { UserService } from './user.service.js';
import { IpChatService } from './ip_chat.service.js';
import { emailKey } from '../utils/email_key.js';

const ONLINE_MS = 3 * 60 * 1000;
const INSTALLED_MS = 7 * 24 * 60 * 60 * 1000;
const OFFLINE_MS = 30 * 24 * 60 * 60 * 1000;

function tsOf(value) {
  if (value == null) return 0;
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  const n = Date.parse(value);
  return Number.isFinite(n) ? n : 0;
}

/** Same saved fix the Home weather card uses (users + email_users /location). */
function pickWeatherLocation(...candidates) {
  let best = null;
  let bestScore = -1;
  for (const loc of candidates) {
    if (!loc || typeof loc !== 'object') continue;
    const place = String(loc.place || '').trim();
    const lat = Number(loc.lat);
    const lon = Number(loc.lon);
    const hasCoords =
      Number.isFinite(lat) &&
      Number.isFinite(lon) &&
      Math.abs(lat) + Math.abs(lon) > 0.0001;
    if (!place && !hasCoords) continue;
    let score = 0;
    if (place) score += 4;
    if (hasCoords) score += 2;
    if (loc.precise !== false) score += 1;
    const at = tsOf(loc.ts || loc.at);
    if (score > bestScore || (score === bestScore && at > tsOf(best?.ts || best?.at))) {
      bestScore = score;
      best = {
        place,
        lat: hasCoords ? lat : null,
        lon: hasCoords ? lon : null,
        locationAt: loc.ts || loc.at || null,
        ts: loc.ts,
        at: loc.at,
      };
    }
  }
  return best;
}

export function peopleStatus(lastSeen) {
  const t = tsOf(lastSeen);
  if (!t) return 'unknown';
  const ago = Date.now() - t;
  if (ago < ONLINE_MS) return 'online';
  if (ago < INSTALLED_MS) return 'installed';
  if (ago < OFFLINE_MS) return 'offline';
  return 'uninstalled';
}

/** Google / crawler ranges that show up as fake "guests". */
export function isBotIp(ip) {
  const s = String(ip || '').trim();
  if (!s) return false;
  return /^(66\.102\.|66\.249\.|74\.125\.|108\.177\.|192\.178\.|142\.250\.|172\.217\.|216\.239\.)/.test(
    s,
  );
}

/** Count chat sessions vs course threads — never mix. */
function countAiActivity(sessionsVal, threadsVal) {
  let chatCount = 0;
  let courseCount = 0;
  let chatMsgs = 0;
  let courseMsgs = 0;
  const seenCourse = new Set();
  const seenChat = new Set();

  for (const s of Object.values(sessionsVal || {})) {
    if (!s || typeof s !== 'object') continue;
    const tid = String(s.threadId || s.id || '');
    const n = Math.max(0, Number(s.msgCount) || 0);
    if (s.mode === 'course' || tid.startsWith('course_')) {
      const crop = String(s.cropId || tid.replace(/^course_/, '') || '').trim();
      if (!crop || seenCourse.has(crop)) continue;
      seenCourse.add(crop);
      courseCount += 1;
      courseMsgs += n;
      continue;
    }
    const sid = String(s.id || '').trim();
    if (!sid || seenChat.has(sid)) continue;
    seenChat.add(sid);
    chatCount += 1;
    chatMsgs += n;
  }

  for (const [tid, row] of Object.entries(threadsVal || {})) {
    if (tid.startsWith('course_')) {
      const crop = String(row?.meta?.cropId || tid.slice(7) || '').trim();
      if (!crop || seenCourse.has(crop)) continue;
      seenCourse.add(crop);
      courseCount += 1;
      courseMsgs += Math.max(0, Number(row?.meta?.msgCount) || 0);
      continue;
    }
    if (tid === 'main' || tid.startsWith('chat_')) {
      const sid = tid === 'main' ? 'main' : tid.slice(5);
      if (!sid || seenChat.has(sid)) continue;
      seenChat.add(sid);
      chatCount += 1;
      chatMsgs += Math.max(0, Number(row?.meta?.msgCount) || 0);
    }
  }

  return {
    chatCount,
    courseCount,
    chatMsgs,
    courseMsgs,
    msgCount: chatMsgs + courseMsgs,
  };
}

export const AdminPeopleService = {
  async list({ limit = 150, hideBots = true } = {}) {
    const cap = Math.max(1, Math.min(200, Number(limit) || 150));
    const users = await UserService.list(cap);
    const ipIndex = IpChatService.adminIndex();
    const people = [];
    const skipBots = hideBots !== false;

    const uids = Object.keys(users);
    const extras = await Promise.all(
      uids.map(async (uid) => {
        if (!isFirebaseReady()) {
          return {
            uid,
            live: null,
            login: null,
            location: null,
            emailLocation: null,
            ai: { chatCount: 0, courseCount: 0, chatMsgs: 0, courseMsgs: 0, msgCount: 0 },
          };
        }
        try {
          const email = String(users[uid]?.email || '').trim();
          const ek = emailKey(email);
          const [liveSnap, loginSnap, locSnap, emailLocSnap, sessSnap, thrSnap] =
            await Promise.all([
              rootRef(`users/${uid}/presence/live`).get(),
              rootRef(`users/${uid}/last_login`).get(),
              rootRef(`users/${uid}/location`).get(),
              ek
                ? rootRef(`email_users/${ek}/location`).get()
                : Promise.resolve({ val: () => null }),
              rootRef(`users/${uid}/ai/sessions`).get(),
              rootRef(`users/${uid}/ai/threads`).get(),
            ]);
          let sessions = sessSnap.val() || {};
          let threads = thrSnap.val() || {};
          if (!Object.keys(sessions).length && !Object.keys(threads).length && ek) {
            const [es, et] = await Promise.all([
              rootRef(`email_users/${ek}/ai/sessions`).get(),
              rootRef(`email_users/${ek}/ai/threads`).get(),
            ]);
            sessions = es.val() || {};
            threads = et.val() || {};
          }
          return {
            uid,
            live: liveSnap.val(),
            login: loginSnap.val(),
            location: locSnap.val(),
            emailLocation: emailLocSnap.val(),
            ai: countAiActivity(sessions, threads),
          };
        } catch {
          return {
            uid,
            live: null,
            login: null,
            location: null,
            emailLocation: null,
            ai: { chatCount: 0, courseCount: 0, chatMsgs: 0, courseMsgs: 0, msgCount: 0 },
          };
        }
      }),
    );
    const extraMap = Object.fromEntries(extras.map((row) => [row.uid, row]));

    for (const [uid, u] of Object.entries(users)) {
      const extra = extraMap[uid] || {};
      const live = extra.live || {};
      const login = extra.login || {};
      const ai = extra.ai || {
        chatCount: 0,
        courseCount: 0,
        chatMsgs: 0,
        courseMsgs: 0,
        msgCount: 0,
      };
      // Home "मौसम" card place — same RTDB location node.
      const weatherLoc = pickWeatherLocation(extra.location, extra.emailLocation);
      const ipRow = ipIndex.byUid[uid] || {};
      const lastSeen = Math.max(
        tsOf(live.at),
        tsOf(u.lastActivity),
        tsOf(login.ts),
        tsOf(ipRow.lastSeenAt),
      );
      people.push({
        kind: 'user',
        uid,
        email: u.email || live.email || login.email || '',
        name: u.name || '',
        plan: u.plan || 'free',
        provider: u.provider || '',
        ip: live.ip || login.ip || ipRow.ip || '',
        ips: ipRow.ips || [],
        place: weatherLoc?.place || '',
        lat: weatherLoc?.lat ?? null,
        lon: weatherLoc?.lon ?? null,
        locationAt: weatherLoc?.locationAt || null,
        chatCount: ai.chatCount,
        courseCount: ai.courseCount,
        chatMsgs: ai.chatMsgs,
        courseMsgs: ai.courseMsgs,
        msgCount: ai.msgCount,
        lastSeen,
        lastLogin: tsOf(login.ts) || null,
        lastLoginAction: login.action || null,
        screen: live.screen || null,
        installId: live.installId || null,
        firstInstallAt: live.firstInstallAt || null,
        installCount: Number(live.installCount) || 0,
        reinstall: Number(live.installCount) > 1,
        status: peopleStatus(lastSeen),
      });
    }

    let guestRows = ipIndex.guests || [];
    if (skipBots) guestRows = guestRows.filter((g) => !isBotIp(g.ip));
    for (const g of guestRows.slice(0, cap)) {
      const lastSeen = tsOf(g.lastSeenAt);
      const msgCount = Number(g.msgCount) || 0;
      people.push({
        kind: 'guest',
        uid: '',
        email: g.linkedEmail || '',
        name: 'गेस्ट',
        plan: 'guest',
        provider: '',
        ip: g.ip || '',
        ips: g.ip ? [{ ip: g.ip, lastSeenAt: g.lastSeenAt }] : [],
        place: g.place || '',
        lat: g.lat ?? null,
        lon: g.lon ?? null,
        locationAt: g.locationAt || null,
        lastSeen,
        lastLogin: null,
        visitorId: g.visitorId || '',
        ipHash: g.ipHash || '',
        chatCount: msgCount > 0 ? 1 : 0,
        courseCount: 0,
        chatMsgs: msgCount,
        courseMsgs: 0,
        msgCount,
        screen: null,
        installId: null,
        reinstall: false,
        bot: isBotIp(g.ip),
        status: peopleStatus(lastSeen),
      });
    }

    people.sort((a, b) => (b.lastSeen || 0) - (a.lastSeen || 0));
    return {
      people,
      counts: {
        users: people.filter((p) => p.kind === 'user').length,
        guests: people.filter((p) => p.kind === 'guest').length,
        online: people.filter((p) => p.status === 'online').length,
      },
    };
  },
};
