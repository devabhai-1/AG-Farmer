import crypto from 'crypto';
import path from 'path';
import { fileURLToPath } from 'url';
import { env } from '../config/env.js';
import { emailKey, normalizeEmail } from '../utils/email_key.js';
import { jsonCache } from '../utils/json_cache.js';
import { reminderLetter, resetLetter, welcomeLetter } from './letters.js';
import { deliverMail, maskEmail } from './transport.js';

const DAY = 24 * 60 * 60 * 1000;
const IST_OFFSET_MS = (5 * 60 + 30) * 60 * 1000;
const dataDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../data');
const stateFile = path.join(dataDir, 'mail_desk.json');
const accountsFile = path.join(dataDir, 'accounts.json');

const stateCache = jsonCache(stateFile, { welcomeAt: {}, nextAt: {}, quiet: {} });
const accountsCache = jsonCache(accountsFile, { byEmail: {}, byUid: {} });

let timer = null;
let ticking = false;

function state() {
  const row = stateCache.read();
  row.welcomeAt = row.welcomeAt || {};
  row.nextAt = row.nextAt || {};
  row.quiet = row.quiet || {};
  return row;
}

function gapMs() {
  return 3 * DAY + crypto.randomInt(0, DAY);
}

function signQuiet(id) {
  return crypto.createHmac('sha256', env.jwtSecret).update(`mail-quiet:${id}`).digest('base64url');
}

export function pauseUrlFor(email) {
  const id = emailKey(email);
  return `https://api.ag-farmer.com/api/mail/quiet?id=${encodeURIComponent(id)}&t=${signQuiet(id)}`;
}

export function pauseReminders(id, token) {
  const key = String(id || '');
  const given = String(token || '');
  if (!/^[a-z0-9_]{3,180}$/.test(key) || !given) return false;
  const expected = signQuiet(key);
  const a = Buffer.from(given);
  const b = Buffer.from(expected);
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) return false;
  const row = state();
  row.quiet[key] = Date.now();
  stateCache.write(row, { now: true });
  console.log('[mail] reminders paused');
  return true;
}

async function sendLetter(letter, to) {
  const sent = await deliverMail({
    from: letter.from,
    replyTo: letter.from,
    to,
    subject: letter.subject,
    text: letter.text,
    html: letter.html,
  });
  console.log(`[mail] ${letter.from} -> ${maskEmail(to)} via ${sent.provider}`);
  return sent;
}

export async function sendAccountWelcome({ to, name }) {
  const em = normalizeEmail(to);
  if (!em || !em.includes('@')) return { sent: false };
  const key = emailKey(em);
  const row = state();
  if (row.welcomeAt[key]) return { sent: false, reason: 'already' };
  await sendLetter(welcomeLetter({ name }), em);
  row.welcomeAt[key] = Date.now();
  if (!row.nextAt[key]) row.nextAt[key] = Date.now() + gapMs();
  stateCache.write(row, { now: true });
  return { sent: true };
}

export async function sendPasswordResetLinkEmail({ to, name, link }) {
  const letter = resetLetter({ name, link });
  const sent = await sendLetter(letter, to);
  return { provider: sent.provider, ref: sent.ref };
}

function istHour(now = Date.now()) {
  return new Date(now + IST_OFFSET_MS).getUTCHours();
}

function listAccounts() {
  const store = accountsCache.read() || {};
  const byUid = store.byUid || {};
  const rows = [];
  for (const account of Object.values(byUid)) {
    if (!account || account.pendingDeletion) continue;
    const em = normalizeEmail(account.email);
    if (!em || !em.includes('@')) continue;
    rows.push({
      email: em,
      name: account.name || '',
      createdAt: Number(account.createdAt) || 0,
    });
  }
  return rows;
}

async function tick() {
  if (ticking) return;
  ticking = true;
  try {
    const now = Date.now();
    const row = state();
    let changed = false;
    const hour = istHour(now);
    const officeHours = hour >= 10 && hour < 18;

    for (const account of listAccounts()) {
      const key = emailKey(account.email);
      if (!row.welcomeAt[key] && account.createdAt && now - account.createdAt < 2 * 60 * 60 * 1000) {
        try {
          await sendLetter(welcomeLetter({ name: account.name }), account.email);
          row.welcomeAt[key] = now;
          if (!row.nextAt[key]) row.nextAt[key] = now + gapMs();
          changed = true;
        } catch (err) {
          console.error('[mail] welcome retry failed', maskEmail(account.email), err?.message || 'send');
        }
      }
      if (!row.nextAt[key]) {
        const created = account.createdAt || now;
        row.nextAt[key] = now - created < 3 * DAY ? created + gapMs() : now + crypto.randomInt(0, 2 * DAY);
        changed = true;
      }
    }
    if (changed) stateCache.write(row);

    if (!officeHours) return;

    let sent = 0;
    for (const account of listAccounts()) {
      if (sent >= 8) break;
      const key = emailKey(account.email);
      if (row.quiet[key]) continue;
      if (!row.nextAt[key] || row.nextAt[key] > now) continue;
      try {
        await sendLetter(
          reminderLetter({ name: account.name, pauseUrl: pauseUrlFor(account.email) }),
          account.email,
        );
        row.nextAt[key] = now + gapMs();
        sent += 1;
        stateCache.write(row, { now: true });
      } catch (err) {
        row.nextAt[key] = now + 12 * 60 * 60 * 1000;
        stateCache.write(row, { now: true });
        console.error('[mail] reminder failed', maskEmail(account.email), err?.message || 'send');
      }
    }
  } finally {
    ticking = false;
  }
}

export function startMailDesk() {
  if (timer) return;
  timer = setInterval(() => {
    tick().catch((err) => console.error('[mail] tick', err?.message || 'tick'));
  }, 15 * 60 * 1000);
  timer.unref();
  console.log('[mail] desk on — welcome from account@, notes from contact@ every 3 to 4 days');
}
