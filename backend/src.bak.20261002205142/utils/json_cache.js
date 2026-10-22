import fs from 'fs';
import path from 'path';
import { writeJsonAtomic } from './atomic_write.js';

const slots = new Map();
let timer = null;
const FLUSH_MS = 800;

function ensureFile(file, fallback) {
  const dir = path.dirname(file);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  if (!fs.existsSync(file)) writeJsonAtomic(file, fallback);
}

/** One shared copy of a JSON file. Reads stay in memory. Writes hit disk together. */
export function jsonCache(file, fallback) {
  const key = path.resolve(file);
  let slot = slots.get(key);
  if (!slot) {
    ensureFile(key, fallback);
    let data = fallback;
    try {
      data = JSON.parse(fs.readFileSync(key, 'utf8'));
    } catch {
      data = fallback;
    }
    slot = { file: key, data, dirty: false };
    slots.set(key, slot);
  }
  return {
    read() {
      return slot.data;
    },
    write(next, { now = false } = {}) {
      if (next != null && next !== slot.data) slot.data = next;
      if (now) {
        writeJsonAtomic(slot.file, slot.data);
        slot.dirty = false;
        return;
      }
      slot.dirty = true;
      if (!timer) {
        timer = setTimeout(() => {
          timer = null;
          flushJsonCaches();
        }, FLUSH_MS);
        timer.unref();
      }
    },
  };
}

export function flushJsonCaches() {
  if (timer) {
    clearTimeout(timer);
    timer = null;
  }
  for (const slot of slots.values()) {
    if (!slot.dirty) continue;
    try {
      writeJsonAtomic(slot.file, slot.data);
      slot.dirty = false;
    } catch (err) {
      console.error('[store] flush failed', err?.message || 'write');
    }
  }
}
