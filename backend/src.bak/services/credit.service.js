import crypto from 'crypto';
import path from 'path';
import { fileURLToPath } from 'url';
import { UserService } from './user.service.js';
import { jsonCache } from '../utils/json_cache.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const file = path.resolve(__dirname, '../../data/credits.json');
const credits = jsonCache(file, { wallets: {}, tokens: {} });

function read() {
  const parsed = credits.read();
  if (!parsed.wallets) parsed.wallets = {};
  if (!parsed.tokens) parsed.tokens = {};
  return parsed;
}

function write(store) {
  credits.write(store, { now: true });
}

function walletOf(store, uid) {
  const key = String(uid || '').trim();
  if (!key) return { voice: 0, video: 0 };
  if (!store.wallets[key]) store.wallets[key] = { voice: 0, video: 0 };
  const row = store.wallets[key];
  row.voice = Math.max(0, Number(row.voice) || 0);
  row.video = Math.max(0, Number(row.video) || 0);
  return row;
}

function makeCode() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const bytes = crypto.randomBytes(8);
  let out = 'AG';
  for (let i = 0; i < 8; i += 1) out += alphabet[bytes[i] % alphabet.length];
  return out;
}

function cleanCount(value) {
  const n = Math.round(Number(value) || 0);
  if (!Number.isFinite(n) || n < 0) return 0;
  return Math.min(100, n);
}

export async function planOfUser(uid) {
  try {
    const user = await UserService.get(uid);
    const sub = user?.subscription;
    if (sub && typeof sub === 'object') {
      if (sub.active === false) return 'free';
      if (sub.expiresAt) {
        const t = typeof sub.expiresAt === 'number' ? sub.expiresAt : Date.parse(sub.expiresAt);
        if (Number.isFinite(t) && t < Date.now()) return 'free';
      }
      const id = sub.planId || sub.plan || sub.id;
      if (id) return String(id);
    }
    if (user?.plan && user.plan !== 'free') return String(user.plan);
  } catch (_) {}
  return 'free';
}

export function isDistributorPlan(planId) {
  const p = String(planId || '').toLowerCase().replace(/[\s_-]+/g, '');
  return p === 'distributor' || p === 'distributorpro' || p === 'dealer';
}

export function hasDailyVideo(planId) {
  const p = String(planId || '').toLowerCase().replace(/[\s_-]+/g, '');
  return (
    p === 'super' ||
    p === 'superpro' ||
    p === 'superpremium' ||
    isDistributorPlan(p)
  );
}

export const CreditService = {
  wallet(uid) {
    const store = read();
    const row = walletOf(store, uid);
    return { voice: row.voice, video: row.video };
  },

  add(uid, { voice = 0, video = 0 } = {}) {
    const store = read();
    const row = walletOf(store, uid);
    row.voice += cleanCount(voice);
    row.video += cleanCount(video);
    write(store);
    return { voice: row.voice, video: row.video };
  },

  take(uid, kind) {
    if (kind !== 'voice' && kind !== 'video') return false;
    const store = read();
    const row = walletOf(store, uid);
    if (row[kind] < 1) return false;
    row[kind] -= 1;
    write(store);
    return true;
  },

  giveBack(uid, kind) {
    if (!uid || (kind !== 'voice' && kind !== 'video')) return;
    const store = read();
    const row = walletOf(store, uid);
    row[kind] += 1;
    write(store);
  },

  createToken({ voice = 0, video = 0, by = null } = {}) {
    const voiceN = cleanCount(voice);
    const videoN = cleanCount(video);
    if (voiceN + videoN < 1) {
      const err = new Error('credit_empty');
      err.status = 400;
      throw err;
    }
    const store = read();
    let code = makeCode();
    while (store.tokens[code]) code = makeCode();
    store.tokens[code] = {
      voice: voiceN,
      video: videoN,
      by: by || 'admin',
      createdAt: new Date().toISOString(),
      usedBy: null,
      usedAt: null,
    };
    const keys = Object.keys(store.tokens);
    if (keys.length > 400) {
      const old = keys
        .filter((key) => store.tokens[key].usedBy)
        .slice(0, keys.length - 300);
      for (const key of old) delete store.tokens[key];
    }
    write(store);
    return { code, voice: voiceN, video: videoN };
  },

  redeem(uid, rawCode) {
    const code = String(rawCode || '').trim().toUpperCase().replace(/\s+/g, '');
    if (!code) {
      const err = new Error('credit_invalid');
      err.status = 400;
      throw err;
    }
    const store = read();
    const token = store.tokens[code];
    if (!token) {
      const err = new Error('credit_invalid');
      err.status = 400;
      throw err;
    }
    if (token.usedBy) {
      const err = new Error('credit_used');
      err.status = 400;
      throw err;
    }
    token.usedBy = String(uid);
    token.usedAt = new Date().toISOString();
    const row = walletOf(store, uid);
    row.voice += Number(token.voice) || 0;
    row.video += Number(token.video) || 0;
    write(store);
    return { wallet: { voice: row.voice, video: row.video }, voice: token.voice, video: token.video };
  },

  list() {
    const store = read();
    return Object.entries(store.tokens)
      .map(([code, row]) => ({
        code,
        voice: row.voice,
        video: row.video,
        used: Boolean(row.usedBy),
        createdAt: row.createdAt,
      }))
      .reverse()
      .slice(0, 20);
  },
};
