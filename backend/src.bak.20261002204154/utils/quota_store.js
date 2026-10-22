import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { writeJsonAtomic } from './atomic_write.js';

const dataDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../data');
const legacyFile = path.join(dataDir, 'ai_quota.json');
const partDir = path.join(dataDir, 'quota_parts');
const dayDir = path.join(partDir, 'days');
const metaFile = path.join(partDir, 'meta.json');

const mem = { days: {}, months: {}, bank: {}, guests: {}, voiceLife: {} };
let loaded = false;
let dirty = false;
let timer = null;
let legacyTimer = null;
const dirtyDays = new Set();

function todayKey() {
  return new Date().toISOString().slice(0, 10);
}

function readJson(file, fallback) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch {
    return fallback;
  }
}

function load() {
  if (loaded) return;
  loaded = true;
  if (!fs.existsSync(dataDir)) fs.mkdirSync(dataDir, { recursive: true });
  if (fs.existsSync(metaFile)) {
    const meta = readJson(metaFile, {});
    mem.months = meta.months || {};
    mem.bank = meta.bank || {};
    mem.guests = meta.guests || {};
    mem.voiceLife = meta.voiceLife || {};
    if (fs.existsSync(dayDir)) {
      for (const name of fs.readdirSync(dayDir)) {
        if (!name.endsWith('.json')) continue;
        const day = name.slice(0, -5);
        mem.days[day] = readJson(path.join(dayDir, name), {});
      }
    }
    return;
  }
  if (fs.existsSync(legacyFile)) {
    const raw = readJson(legacyFile, {});
    mem.days = raw.days && typeof raw.days === 'object' ? raw.days : {};
    mem.months = raw.months || {};
    mem.bank = raw.bank || {};
    mem.guests = raw.guests || {};
    mem.voiceLife = raw.voiceLife || {};
  }
  for (const day of Object.keys(mem.days)) dirtyDays.add(day);
  dirty = true;
  flushQuotaNow();
}

export function readQuota() {
  load();
  return mem;
}

export function markQuota() {
  load();
  dirty = true;
  dirtyDays.add(todayKey());
  if (!timer) {
    timer = setTimeout(() => {
      timer = null;
      flushQuotaNow();
    }, 1000);
    timer.unref();
  }
  if (!legacyTimer) {
    legacyTimer = setTimeout(() => {
      legacyTimer = null;
      try {
        writeJsonAtomic(legacyFile, mem);
      } catch (err) {
        console.error('[quota] backup failed', err?.message || 'write');
      }
    }, 30000);
    legacyTimer.unref();
  }
}

export function flushQuotaNow() {
  if (timer) {
    clearTimeout(timer);
    timer = null;
  }
  if (!loaded || !dirty) return;
  if (!fs.existsSync(dayDir)) fs.mkdirSync(dayDir, { recursive: true });
  const daysToWrite = [...dirtyDays];
  dirtyDays.clear();
  try {
    writeJsonAtomic(metaFile, {
      months: mem.months || {},
      bank: mem.bank || {},
      guests: mem.guests || {},
      voiceLife: mem.voiceLife || {},
    });
    for (const day of daysToWrite) {
      const file = path.join(dayDir, `${day}.json`);
      if (!mem.days[day]) {
        if (fs.existsSync(file)) fs.rmSync(file, { force: true });
        continue;
      }
      writeJsonAtomic(file, mem.days[day]);
    }
    for (const name of fs.readdirSync(dayDir)) {
      const day = name.slice(0, -5);
      if (!mem.days[day]) fs.rmSync(path.join(dayDir, name), { force: true });
    }
    dirty = false;
  } catch (err) {
    dirty = true;
    for (const day of daysToWrite) dirtyDays.add(day);
    console.error('[quota] flush failed', err?.message || 'write');
  }
}
