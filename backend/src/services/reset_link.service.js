import crypto from 'crypto';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const file = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../data/reset_codes.json');
const ALPHABET = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
const CODE_RE = /^[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{8}$/;
const TTL_MS = 60 * 60 * 1000;

function readAll() {
  try {
    const raw = JSON.parse(fs.readFileSync(file, 'utf8'));
    return raw && typeof raw === 'object' && !Array.isArray(raw) ? raw : {};
  } catch {
    return {};
  }
}

function writeAll(map) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const tmp = `${file}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(map));
  fs.renameSync(tmp, file);
}

function prune(map, now) {
  for (const [key, row] of Object.entries(map)) {
    if (!row || !row.exp || row.exp < now) delete map[key];
  }
}

function readKey(code) {
  const key = String(code || '').trim().toUpperCase();
  if (!CODE_RE.test(key)) return '';
  return key;
}

export function createResetCode(oobCode) {
  const oob = String(oobCode || '').trim();
  if (oob.length < 8) {
    throw Object.assign(new Error('email_send_failed'), { status: 502 });
  }
  const now = Date.now();
  const map = readAll();
  prune(map, now);
  let code = '';
  for (let attempt = 0; attempt < 6; attempt += 1) {
    const bytes = crypto.randomBytes(8);
    code = [...bytes].map((b) => ALPHABET[b % ALPHABET.length]).join('');
    if (!map[code]) break;
  }
  map[code] = { oob, exp: now + TTL_MS };
  writeAll(map);
  return code;
}

export function lookupResetCode(code) {
  const key = readKey(code);
  if (!key) return '';
  const now = Date.now();
  const map = readAll();
  prune(map, now);
  const row = map[key];
  writeAll(map);
  if (!row || row.used || row.exp < now || !row.oob) return '';
  return String(row.oob);
}

/** ok = can set a password, used = already spent, bad = missing or old. */
export function resetLinkState(code) {
  const key = readKey(code);
  if (!key) return 'bad';
  const now = Date.now();
  const map = readAll();
  prune(map, now);
  const row = map[key];
  writeAll(map);
  if (!row || row.exp < now) return 'bad';
  if (row.used || !row.oob) return 'used';
  return 'ok';
}

export function consumeResetOob(oobCode) {
  const oob = String(oobCode || '').trim();
  if (!oob) return;
  const now = Date.now();
  const map = readAll();
  prune(map, now);
  let changed = false;
  for (const row of Object.values(map)) {
    if (row && row.oob === oob) {
      row.used = true;
      row.oob = '';
      changed = true;
    }
  }
  if (changed) writeAll(map);
}
