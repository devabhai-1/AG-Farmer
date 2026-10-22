import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { maskIp } from '../middleware/client_ip.js';
import { writeJsonAtomic } from '../utils/atomic_write.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const logsFile = path.resolve(__dirname, '../../data/logs.json');
const KEEP_MS = 10 * 24 * 60 * 60 * 1000;
const MAX_ENTRIES = 1500;

const recent = new Map();

function clip(value, max) {
  return String(value || '')
    .replace(/[\r\n\t]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, max);
}

function readStore() {
  try {
    const raw = JSON.parse(fs.readFileSync(logsFile, 'utf8'));
    const entries = Array.isArray(raw?.entries) ? raw.entries : [];
    return { entries };
  } catch {
    return { entries: [] };
  }
}

function prune(entries, now) {
  const cutoff = now - KEEP_MS;
  return entries
    .filter((row) => Number(row?.ts) >= cutoff)
    .slice(-MAX_ENTRIES);
}

/**
 * Login and layout problems only. Kept 10 days in data/logs.json.
 * Passwords, tokens, and full emails are never stored.
 */
export function recordProblem({
  kind = 'login',
  code = '',
  message = '',
  screen = '',
  uid = null,
  ip = null,
} = {}) {
  const safeKind = kind === 'layout' ? 'layout' : 'login';
  const safeCode = clip(code, 80) || 'unknown';
  const safeMessage = clip(message, 240);
  const safeScreen = clip(screen, 40);
  const now = Date.now();
  const dedupe = `${safeKind}|${safeCode}|${safeScreen}|${clip(uid, 40)}`;
  const last = recent.get(dedupe) || 0;
  if (now - last < 60 * 1000) return { ok: true, stored: false };
  recent.set(dedupe, now);

  const store = readStore();
  const entries = prune(store.entries, now);
  entries.push({
    ts: now,
    at: new Date(now).toISOString(),
    kind: safeKind,
    code: safeCode,
    message: safeMessage,
    screen: safeScreen || undefined,
    uid: clip(uid, 80) || undefined,
    ip: ip ? maskIp(ip) : undefined,
  });
  try {
    writeJsonAtomic(logsFile, {
      keepDays: 10,
      updatedAt: now,
      entries: prune(entries, now),
    });
  } catch (err) {
    console.warn('[client-log] write skipped:', err.message);
    return { ok: true, stored: false };
  }
  return { ok: true, stored: true };
}
