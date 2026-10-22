import { normalizeIp } from './client_ip.js';

// Configuration
const WINDOW_MS = 60 * 1000; // 1 minute sliding window
const MAX_REQUESTS_PER_WINDOW = 240;
const MAX_IN_FLIGHT = 80;
const MAX_GLOBAL = 20000;
const MAX_CHAT = 2000;
const MAX_UPLOAD = 150;
const MAX_USERS_PER_SECOND = 2000;
const ACTIVE_MS = 10 * 60 * 1000;
const QUEUE_MAX = 4000;
const QUEUE_WAIT_MS = 2000;

const CHAT_HEAVY = new Set(['chat', 'voice.realtime.session']);
const UPLOAD_HEAVY = new Set([
  'storage.upload',
  'storage.upload-url',
  'storage.uploadUrl',
]);

const AUTH_PASS = new Set([
  'auth.login',
  'auth.register',
  'auth.google',
  'auth.otp.send',
  'auth.otp.verify',
  'auth.password.forgot',
  'auth.password.reset',
  'auth.profile.complete',
  'auth.phone.lookup',
  'auth.verify',
]);

const TIGHT_PER_MINUTE = {
  'auth.login': 40,
  'auth.register': 20,
  'auth.google': 40,
  'auth.otp.send': 15,
  'auth.otp.verify': 20,
  'auth.password.forgot': 12,
  'auth.password.reset': 12,
  'auth.phone.lookup': 30,
  chat: 40,
  'voice.realtime.session': 20,
  'storage.upload': 20,
  'credit.redeem': 10,
  'credit.create': 10,
};

// In-memory bucket: Map<ip, { count: number, resetAt: number }>
const ipBuckets = new Map();
const actionBuckets = new Map();
const inFlight = new Map();
let globalOpen = 0;
let chatOpen = 0;
let uploadOpen = 0;
let tokens = MAX_USERS_PER_SECOND;
let lastRefill = Date.now();
const activeUsers = new Map();
const waitQueue = [];
let drainTimer = null;

function refillTokens() {
  const now = Date.now();
  const add = ((now - lastRefill) * MAX_USERS_PER_SECOND) / 1000;
  if (add <= 0) return;
  tokens = Math.min(MAX_USERS_PER_SECOND, tokens + add);
  lastRefill = now;
}

function isActive(ip) {
  const seen = activeUsers.get(ip);
  return Boolean(seen && Date.now() - seen < ACTIVE_MS);
}

function markActive(ip) {
  activeUsers.set(ip, Date.now());
}

// Periodic garbage collection to ensure memory never leaks
setInterval(() => {
  const now = Date.now();
  for (const [ip, bucket] of ipBuckets.entries()) {
    if (bucket.resetAt <= now) ipBuckets.delete(ip);
  }
  for (const [key, bucket] of actionBuckets.entries()) {
    if (bucket.resetAt <= now) actionBuckets.delete(key);
  }
  for (const [ip, seen] of activeUsers.entries()) {
    if (now - seen > ACTIVE_MS) activeUsers.delete(ip);
  }
}, 5 * 60 * 1000).unref(); // unref so it won't hold the process open

function hit(map, key, limit) {
  const now = Date.now();
  let bucket = map.get(key);
  if (!bucket || bucket.resetAt <= now) {
    bucket = { count: 1, resetAt: now + WINDOW_MS };
    map.set(key, bucket);
    return { ok: true, retryAfterSec: 0 };
  }
  bucket.count += 1;
  if (bucket.count > limit) {
    return {
      ok: false,
      retryAfterSec: Math.max(1, Math.ceil((bucket.resetAt - now) / 1000)),
    };
  }
  return { ok: true, retryAfterSec: 0 };
}

function tooMany(res, retryAfterSec) {
  res.setHeader('Retry-After', String(retryAfterSec));
  return res.status(429).json({
    ok: false,
    error: 'rate_limit_exceeded',
    message: 'Too many requests. Please slow down. / बहुत अधिक अनुरोध। कृपया थोड़ी देर प्रतीक्षा करें।',
    retryAfter: retryAfterSec,
  });
}

function busy(res) {
  res.setHeader('Retry-After', '2');
  return res.status(503).json({
    ok: false,
    error: 'service_unavailable',
    message: 'सर्वर अभी व्यस्त है। कुछ सेकंड बाद फिर कोशिश करें।',
    retryAfter: 2,
  });
}

function scheduleDrain() {
  if (drainTimer) return;
  drainTimer = setTimeout(drainQueue, 20);
  drainTimer.unref();
}

function drainQueue() {
  drainTimer = null;
  refillTokens();
  while (waitQueue.length && tokens >= 1) {
    const item = waitQueue.shift();
    clearTimeout(item.timer);
    if (item.done || item.res.writableEnded || item.res.headersSent) continue;
    item.done = true;
    tokens -= 1;
    markActive(item.ip);
    protect(item.req, item.res, item.next, item.ip);
  }
  if (waitQueue.length) scheduleDrain();
}

function enqueue(req, res, next, ip) {
  if (waitQueue.length >= QUEUE_MAX) return busy(res);
  const item = { req, res, next, ip, done: false, timer: null };
  item.timer = setTimeout(() => {
    if (item.done) return;
    item.done = true;
    const index = waitQueue.indexOf(item);
    if (index >= 0) waitQueue.splice(index, 1);
    if (!res.headersSent) busy(res);
  }, QUEUE_WAIT_MS);
  item.timer.unref();
  res.on('close', () => {
    if (item.done) return;
    item.done = true;
    clearTimeout(item.timer);
    const index = waitQueue.indexOf(item);
    if (index >= 0) waitQueue.splice(index, 1);
  });
  waitQueue.push(item);
  scheduleDrain();
  return undefined;
}

function protect(req, res, next, clientIp, { critical = false } = {}) {
  const general = hit(ipBuckets, clientIp, MAX_REQUESTS_PER_WINDOW);
  if (!general.ok) {
    console.warn('[ddos-protection] rate limit');
    return tooMany(res, general.retryAfterSec);
  }

  const action = String(req.body?.action || req.query?.action || '').trim();
  const tight = TIGHT_PER_MINUTE[action] || (action.startsWith('admin.') ? 30 : 0);
  if (tight) {
    const scoped = hit(actionBuckets, `${clientIp}|${action}`, tight);
    if (!scoped.ok) {
      console.warn('[ddos-protection] action limit');
      return tooMany(res, scoped.retryAfterSec);
    }
  }

  const open = (inFlight.get(clientIp) || 0) + 1;
  if (!critical && (open > MAX_IN_FLIGHT || globalOpen >= MAX_GLOBAL)) {
    return busy(res);
  }
  const chatHeavy = CHAT_HEAVY.has(action);
  const uploadHeavy = UPLOAD_HEAVY.has(action);
  if (chatHeavy && chatOpen >= MAX_CHAT) return busy(res);
  if (uploadHeavy && uploadOpen >= MAX_UPLOAD) return busy(res);
  inFlight.set(clientIp, open);
  globalOpen += 1;
  if (chatHeavy) chatOpen += 1;
  if (uploadHeavy) uploadOpen += 1;
  let released = false;
  const release = () => {
    if (released) return;
    released = true;
    const left = (inFlight.get(clientIp) || 1) - 1;
    if (left <= 0) inFlight.delete(clientIp);
    else inFlight.set(clientIp, left);
    globalOpen = Math.max(0, globalOpen - 1);
    if (chatHeavy) chatOpen = Math.max(0, chatOpen - 1);
    if (uploadHeavy) uploadOpen = Math.max(0, uploadOpen - 1);
  };
  res.on('finish', release);
  res.on('close', release);

  return next();
}

export function ddosProtectionMiddleware(req, res, next) {
  if (String(req.path || '').startsWith('/media/')) return next();
  const clientIp = normalizeIp(req.clientIp || req.socket?.remoteAddress || 'unknown');
  const action = String(req.body?.action || req.query?.action || '').trim();
  const loopback = clientIp === '127.0.0.1' || clientIp === 'localhost' || clientIp === '::1';
  const authPass = AUTH_PASS.has(action);
  if (loopback || authPass || isActive(clientIp)) {
    if (!loopback) markActive(clientIp);
    return protect(req, res, next, clientIp, { critical: authPass });
  }
  refillTokens();
  if (tokens >= 1) {
    tokens -= 1;
    markActive(clientIp);
    return protect(req, res, next, clientIp);
  }
  return enqueue(req, res, next, clientIp);
}
