import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { writeJsonAtomic } from '../utils/atomic_write.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const file = path.resolve(__dirname, '../../data/screens.json');

const ALLOWED = new Set([
  'login',
  'register',
  'forgot',
  'google',
  'jankariLogin',
  'course',
  'courseChat',
  'chat',
  'live',
  'video',
  'profile',
  'payment',
]);

function sanitize(raw) {
  const out = {};
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return out;
  for (const key of ALLOWED) {
    const block = raw[key];
    if (block && typeof block === 'object' && !Array.isArray(block)) {
      const copy = { ...block };
      delete copy.blocks;
      out[key] = copy;
    }
  }
  return out;
}

export function getScreens() {
  try {
    return sanitize(JSON.parse(fs.readFileSync(file, 'utf8')));
  } catch {
    return {};
  }
}

export function saveScreens(input) {
  const clean = sanitize(input);
  const size = Buffer.byteLength(JSON.stringify(clean), 'utf8');
  if (size > 80 * 1024) {
    throw Object.assign(new Error('bad_request'), { status: 400 });
  }
  writeJsonAtomic(file, clean);
  return clean;
}
