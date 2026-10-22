import path from 'path';
import { fileURLToPath } from 'url';
import { hashIp, maskIp, normalizeIp } from '../middleware/client_ip.js';
import { isFirebaseReady, rootRef } from '../config/firebase.js';
import { emailKey } from '../utils/email_key.js';
import { jsonCache } from '../utils/json_cache.js';
import { rtdbPush } from './rtdb_system.js';
import { stripAccountSecrets } from './ai_privacy.js';

const storeFile = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../data/ip_chats.json');
const chats = jsonCache(storeFile, { byIp: {}, byEmail: {}, byUid: {} });
const MAX_MESSAGES = 200;
const MAX_IPS_PER_EMAIL = 12;

function readStore() {
  const store = chats.read();
  if (!store.byIp) store.byIp = {};
  if (!store.byEmail) store.byEmail = {};
  if (!store.byUid) store.byUid = {};
  return store;
}

function writeStore(store) {
  chats.write(store);
  rtdbPush('system/ip_chats/meta', {
    ips: Object.keys(store.byIp || {}).length,
    emails: Object.keys(store.byEmail || {}).length,
    uids: Object.keys(store.byUid || {}).length,
    updatedAt: Date.now(),
  });
}

function normalizeMessage(m) {
  if (!m || typeof m !== 'object') return null;
  const id = String(m.id || `m_${Date.now()}`);
  const text = String(m.text || '').trim();
  if (!text) return null;
  const role = m.role === 'assistant' || m.role === 'bot' ? 'assistant' : 'user';
  return {
    id,
    text,
    role,
    createdAt: m.createdAt || new Date().toISOString(),
    dosageHighlight: m.dosageHighlight || null,
    quickReplies: Array.isArray(m.quickReplies) ? m.quickReplies.slice(0, 8) : [],
    cropTag: m.cropTag || null,
  };
}

function mergeMessages(existing = [], incoming = []) {
  const map = new Map();
  for (const m of [...existing, ...incoming]) {
    const n = normalizeMessage(m);
    if (!n) continue;
    // skip pure welcome seeds for storage noise? keep them if id doesn't start with welcome_
    if (String(n.id).startsWith('welcome_')) continue;
    map.set(n.id, n);
  }
  return [...map.values()]
    .sort((a, b) => String(a.createdAt).localeCompare(String(b.createdAt)))
    .slice(-MAX_MESSAGES);
}

function touchIpBucket(store, ip, ipHash) {
  const key = ipHash || hashIp(ip);
  if (!store.byIp) store.byIp = {};
  if (!store.byEmail) store.byEmail = {};
  if (!store.byUid) store.byUid = {};
  if (!store.byIp[key]) {
    store.byIp[key] = {
      ipHash: key,
      ip: normalizeIp(ip),
      ipMasked: maskIp(ip),
      visitorId: `v_${key.slice(0, 20)}`,
      createdAt: new Date().toISOString(),
      lastSeenAt: new Date().toISOString(),
      emails: {},
      uids: {},
      linkedUid: null,
      linkedEmail: null,
      messages: [],
    };
  } else {
    const b = store.byIp[key];
    b.lastSeenAt = new Date().toISOString();
    b.ip = normalizeIp(ip);
    b.ipMasked = maskIp(ip);
    if (!b.emails || typeof b.emails !== 'object') b.emails = {};
    if (!b.uids || typeof b.uids !== 'object') b.uids = {};
    if (!Array.isArray(b.messages)) b.messages = [];
  }
  return store.byIp[key];
}

async function mirrorRtdb(path, value) {
  if (!isFirebaseReady()) return;
  try {
    await rootRef(path).update({ ...value, updatedAt: Date.now() });
  } catch (e) {
    console.warn('[ip_chats] RTDB mirror skipped:', e.message);
  }
}

export const IpChatService = {
  /** Record which email/uid used this IP (login / register / google). */
  async bindIdentity({ ip, email, uid }) {
    const store = readStore();
    const ipHash = hashIp(ip);
    const bucket = touchIpBucket(store, ip, ipHash);
    const em = emailKey(email);
    const now = new Date().toISOString();

    if (uid) {
      bucket.uids[uid] = { email: em || null, lastSeenAt: now };
      bucket.linkedUid = uid;
      if (!store.byUid[uid]) {
        store.byUid[uid] = { uid, email: em || null, messages: [], lastIpHash: ipHash };
      } else {
        store.byUid[uid].lastIpHash = ipHash;
        if (em) store.byUid[uid].email = em;
      }
      // Do NOT merge IP guest messages into logged-in user — that resurrects
      // wiped chats on the same LAN. Logged-in chats live in RTDB only.
    }

    if (em) {
      bucket.emails[em] = {
        uid: uid || bucket.emails[em]?.uid || null,
        lastSeenAt: now,
        count: (bucket.emails[em]?.count || 0) + 1,
      };
      bucket.linkedEmail = em;

      if (!store.byEmail[em]) {
        store.byEmail[em] = { email: em, uid: uid || null, ips: {} };
      }
      if (uid) store.byEmail[em].uid = uid;
      store.byEmail[em].ips[ipHash] = {
        ipMasked: maskIp(ip),
        lastSeenAt: now,
        count: (store.byEmail[em].ips[ipHash]?.count || 0) + 1,
      };
      // keep only recent IPs
      const ipEntries = Object.entries(store.byEmail[em].ips).sort(
        (a, b) => String(b[1].lastSeenAt).localeCompare(String(a[1].lastSeenAt)),
      );
      store.byEmail[em].ips = Object.fromEntries(ipEntries.slice(0, MAX_IPS_PER_EMAIL));
    }

    writeStore(store);
    await mirrorRtdb(`ip_index/${ipHash}`, {
      ipMasked: maskIp(ip),
      linkedUid: bucket.linkedUid,
      linkedEmail: bucket.linkedEmail,
      lastSeenAt: now,
    });
    if (em) {
      await mirrorRtdb(`email_ips/${em.replace(/[.#$\[\]]/g, '_')}`, {
        lastIpHash: ipHash,
        uid: uid || null,
        lastSeenAt: now,
      });
    }

    return {
      ipHash,
      ipMasked: maskIp(ip),
      linkedUid: bucket.linkedUid,
      linkedEmail: bucket.linkedEmail,
      messageCount: bucket.messages.length,
    };
  },

  /** Save chat messages for this IP (+ logged-in user if any). */
  async syncMessages({ ip, messages, uid = null, email = null }) {
    const store = readStore();
    const ipHash = hashIp(ip);
    const bucket = touchIpBucket(store, ip, ipHash);
    const incoming = (messages || []).map(normalizeMessage).filter(Boolean);

    bucket.messages = mergeMessages(bucket.messages, incoming);

    const em = emailKey(email);
    if (uid) {
      bucket.linkedUid = uid;
      if (em) bucket.linkedEmail = em;
      if (!store.byUid[uid]) {
        store.byUid[uid] = { uid, email: em || null, messages: [], lastIpHash: ipHash };
      }
      store.byUid[uid].lastIpHash = ipHash;
      if (em) store.byUid[uid].email = em;
      store.byUid[uid].messages = mergeMessages(store.byUid[uid].messages, incoming);
    }

    if (em) {
      if (!store.byEmail[em]) store.byEmail[em] = { email: em, uid: uid || null, ips: {} };
      store.byEmail[em].ips[ipHash] = {
        ipMasked: maskIp(ip),
        lastSeenAt: new Date().toISOString(),
        count: (store.byEmail[em].ips[ipHash]?.count || 0) + 1,
      };
      if (uid) store.byEmail[em].uid = uid;
    }

    writeStore(store);
    return {
      saved: incoming.length,
      total: bucket.messages.length,
      ipMasked: maskIp(ip),
      visitorId: bucket.visitorId,
    };
  },

  /**
   * Restore chat after reinstall / new browser:
   * 1) messages on this IP (anonymous)
   * 2) if IP linked to a user, that user's messages too
   */
  async restore({ ip, uid = null, email = null }) {
    const store = readStore();
    const ipHash = hashIp(ip);
    const bucket = touchIpBucket(store, ip, ipHash);
    writeStore(store); // persist touch

    let messages = [...(bucket.messages || [])];
    let source = 'anonymous';
    let linkedEmail = bucket.linkedEmail || null;
    let linkedUid = bucket.linkedUid || null;

    const em = emailKey(email);
    const effectiveUid = uid || linkedUid;

    if (effectiveUid && store.byUid[effectiveUid]?.messages?.length) {
      messages = mergeMessages(messages, store.byUid[effectiveUid].messages);
      source = uid ? 'user' : 'ip_linked_user';
      linkedEmail = store.byUid[effectiveUid].email || linkedEmail;
      linkedUid = effectiveUid;
    } else if (em && store.byEmail[em]?.uid) {
      const u = store.byEmail[em].uid;
      if (store.byUid[u]?.messages?.length) {
        messages = mergeMessages(messages, store.byUid[u].messages);
        source = 'email';
        linkedUid = u;
        linkedEmail = em;
      }
    }

    // Also: if this IP has known emails, surface the most recent email for UX (masked)
    const emailHits = Object.entries(bucket.emails || {}).sort(
      (a, b) => String(b[1].lastSeenAt || '').localeCompare(String(a[1].lastSeenAt || '')),
    );
    const lastEmail = emailHits[0]?.[0] || linkedEmail;

    return {
      visitorId: bucket.visitorId,
      ipMasked: maskIp(ip),
      source,
      linkedUid,
      linkedEmail: lastEmail
        ? lastEmail.replace(/(.{2}).+(@.+)/, '$1***$2')
        : null,
      linkedEmailRaw: null, // never send raw to client unless logged in
      messageCount: messages.length,
      messages,
    };
  },

  /** Save mosum / weather place against this IP (guest or any visitor). */
  async saveLocation({ ip, lat, lon, place = '', precise = false }) {
    const la = Number(lat);
    const lo = Number(lon);
    const normalized = normalizeIp(ip);
    if (!normalized || normalized === 'unknown') return null;
    if (!Number.isFinite(la) || !Number.isFinite(lo)) return null;
    if (Math.abs(la) + Math.abs(lo) < 0.0001) return null;
    const store = readStore();
    const ipHash = hashIp(ip);
    const bucket = touchIpBucket(store, ip, ipHash);
    const payload = {
      lat: la,
      lon: lo,
      place: String(place || '').trim(),
      precise: precise === true,
      at: new Date().toISOString(),
      ts: Date.now(),
    };
    bucket.location = payload;
    writeStore(store);
    if (isFirebaseReady()) {
      try {
        await rootRef(`guests/${ipHash}/location`).set({
          ...payload,
          ipMasked: maskIp(ip),
          updatedAt: Date.now(),
        });
      } catch (e) {
        console.warn('[ip_chats] guest location RTDB skipped:', e.message);
      }
    }
    return payload;
  },

  readLocation(ip) {
    if (!ip) return null;
    const store = readStore();
    const bucket = store.byIp?.[hashIp(ip)];
    const loc = bucket?.location;
    if (!loc || typeof loc !== 'object') return null;
    const lat = Number(loc.lat);
    const lon = Number(loc.lon);
    if (!Number.isFinite(lat) || !Number.isFinite(lon)) return null;
    return {
      lat,
      lon,
      place: String(loc.place || '').trim(),
      precise: loc.precise === true,
      at: loc.at || null,
      ts: loc.ts || null,
    };
  },

  /** Admin / debug: which emails used which IPs */
  async lookupByEmail(email) {
    const store = readStore();
    const em = emailKey(email);
    const row = store.byEmail[em];
    if (!row) return { email: em, ips: [] };
    return {
      email: em,
      uid: row.uid,
      ips: Object.entries(row.ips || {}).map(([hash, meta]) => ({
        ipHash: hash,
        ...meta,
      })),
    };
  },

  /** Local admin list — IPs and links, never chat text / AI threads. */
  adminIndex() {
    const store = readStore();
    const byUid = {};
    const guests = [];
    for (const [hash, b] of Object.entries(store.byIp || {})) {
      if (!b || typeof b !== 'object') continue;
      const loc = b.location && typeof b.location === 'object' ? b.location : null;
      const slim = {
        ipHash: hash,
        ip: b.ip || '',
        ipMasked: b.ipMasked || '',
        lastSeenAt: b.lastSeenAt || '',
        createdAt: b.createdAt || '',
        linkedUid: b.linkedUid || null,
        linkedEmail: b.linkedEmail || null,
        visitorId: b.visitorId || '',
        place: String(loc?.place || '').trim(),
        lat: Number.isFinite(Number(loc?.lat)) ? Number(loc.lat) : null,
        lon: Number.isFinite(Number(loc?.lon)) ? Number(loc.lon) : null,
        locationAt: loc?.ts || loc?.at || null,
        msgCount: Array.isArray(b.messages) ? b.messages.length : 0,
      };
      const uid = b.linkedUid;
      if (uid) {
        if (!byUid[uid]) {
          byUid[uid] = { uid, ip: slim.ip, lastSeenAt: slim.lastSeenAt, ips: [] };
        }
        byUid[uid].ips.push(slim);
        if (String(slim.lastSeenAt || '') > String(byUid[uid].lastSeenAt || '')) {
          byUid[uid].lastSeenAt = slim.lastSeenAt;
          byUid[uid].ip = slim.ip;
        }
      } else {
        guests.push(slim);
      }
    }
    guests.sort((a, b) => String(b.lastSeenAt || '').localeCompare(String(a.lastSeenAt || '')));
    return { byUid, guests };
  },

  async lookupByIp(ip) {
    const store = readStore();
    const ipHash = hashIp(ip);
    const bucket = store.byIp[ipHash];
    if (!bucket) return { ipMasked: maskIp(ip), emails: [], uids: [] };
    return {
      ipMasked: bucket.ipMasked,
      visitorId: bucket.visitorId,
      linkedUid: bucket.linkedUid,
      linkedEmail: bucket.linkedEmail,
      emails: Object.keys(bucket.emails || {}),
      uids: Object.keys(bucket.uids || {}),
      messageCount: (bucket.messages || []).length,
      lastSeenAt: bucket.lastSeenAt,
    };
  },

  /**
   * Admin only: guest chat for one IP bucket.
   * Never merges logged-in user RTDB threads — IP guest box only.
   */
  adminGuestChat({ ip = null, ipHash = null, limit = 300 } = {}) {
    const store = readStore();
    let key = String(ipHash || '').trim();
    if (!key && ip) key = hashIp(normalizeIp(ip));
    if (!key) {
      throw Object.assign(new Error('ip or ipHash required'), { status: 400 });
    }
    const bucket = store.byIp?.[key];
    if (!bucket) {
      return {
        kind: 'guest',
        ipHash: key,
        ip: '',
        visitorId: '',
        place: '',
        chats: [],
        courses: [],
        messages: [],
        msgCount: 0,
      };
    }
    const cap = Math.max(1, Math.min(500, Number(limit) || 300));
    const raw = Array.isArray(bucket.messages) ? bucket.messages : [];
    const messages = raw
      .filter((m) => m && String(m.text || '').trim())
      .sort((a, b) => String(a.createdAt || '').localeCompare(String(b.createdAt || '')))
      .slice(-cap)
      .map((m) => ({
        id: m.id || null,
        role: m.role === 'assistant' || m.role === 'bot' ? 'assistant' : 'user',
        text: stripAccountSecrets(m.text || ''),
        ts: m.createdAt ? Date.parse(m.createdAt) || null : null,
        createdAt: m.createdAt || null,
      }));
    const loc = bucket.location && typeof bucket.location === 'object' ? bucket.location : null;
    const msgCount = messages.length;
    const chats =
      msgCount > 0
        ? [
            {
              kind: 'guest',
              id: 'guest_ip',
              sessionId: 'guest_ip',
              threadId: `guest_${key}`,
              name: 'गेस्ट चैट',
              msgCount,
              updatedAt: bucket.lastSeenAt ? Date.parse(bucket.lastSeenAt) || 0 : 0,
            },
          ]
        : [];
    return {
      kind: 'guest',
      ipHash: key,
      ip: bucket.ip || '',
      ipMasked: bucket.ipMasked || maskIp(bucket.ip),
      visitorId: bucket.visitorId || '',
      place: String(loc?.place || '').trim(),
      lat: Number.isFinite(Number(loc?.lat)) ? Number(loc.lat) : null,
      lon: Number.isFinite(Number(loc?.lon)) ? Number(loc.lon) : null,
      lastSeenAt: bucket.lastSeenAt || null,
      chats,
      courses: [],
      messages,
      msgCount,
      storage: 'ip_chats',
    };
  },
};
