import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { hashIp, maskIp, normalizeIp } from '../middleware/client_ip.js';
import { writeJsonAtomic } from '../utils/atomic_write.js';

const file = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '../../data/ip_blocks.json',
);

function readStore() {
  try {
    const raw = JSON.parse(fs.readFileSync(file, 'utf8'));
    if (raw && typeof raw === 'object' && !Array.isArray(raw)) return raw;
  } catch {
    /* empty */
  }
  return { byHash: {} };
}

function writeStore(store) {
  writeJsonAtomic(file, store);
}

export const IpBlockService = {
  list() {
    const store = readStore();
    return Object.values(store.byHash || {})
      .filter(Boolean)
      .sort((a, b) => (b.at || 0) - (a.at || 0));
  },

  isBlocked(ip) {
    const normalized = normalizeIp(ip);
    if (!normalized || normalized === 'unknown') return false;
    const store = readStore();
    const row = store.byHash?.[hashIp(normalized)];
    return Boolean(row?.blocked);
  },

  block({ ip, note = '' } = {}) {
    const normalized = normalizeIp(ip);
    if (!normalized || normalized === 'unknown') {
      throw Object.assign(new Error('ip required'), { status: 400 });
    }
    const store = readStore();
    if (!store.byHash) store.byHash = {};
    const key = hashIp(normalized);
    store.byHash[key] = {
      ipHash: key,
      ip: normalized,
      ipMasked: maskIp(normalized),
      blocked: true,
      note: String(note || '').trim().slice(0, 120),
      at: Date.now(),
    };
    writeStore(store);
    return store.byHash[key];
  },

  unblock({ ip, ipHash } = {}) {
    const store = readStore();
    if (!store.byHash) store.byHash = {};
    let key = String(ipHash || '').trim();
    if (!key && ip) key = hashIp(normalizeIp(ip));
    if (!key || !store.byHash[key]) return { ok: false };
    delete store.byHash[key];
    writeStore(store);
    return { ok: true };
  },
};
