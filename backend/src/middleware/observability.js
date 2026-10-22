import crypto from 'crypto';
import { env } from '../config/env.js';
import { recordRequest, markSlow } from './metrics.js';

// Requests slower than this are logged as warnings so we can see degrading
// upstreams (OpenAI / Gemini / Firebase) before users complain.
const SLOW_MS = 5000;

// Reverse-proxy / uptime probes: counted in metrics but never written to the
// access log (one line every 10s would bury real traffic).
const PROBE_PATHS = new Set(['/healthz', '/readyz']);

function newRequestId() {
  // 16 hex chars: short enough to read in logs, unique enough per process.
  return crypto.randomBytes(8).toString('hex');
}

/**
 * Attach a request id, no-store cache headers for API responses, and emit one
 * structured JSON access-log line per request in production.
 *
 * Log fields: ts, id, method, path, action, status, ms, ip (masked), uid.
 * Never logs request bodies, tokens, or raw IPs.
 */
export function observabilityMiddleware(req, res, next) {
  const started = process.hrtime.bigint();
  const incoming = String(req.get('x-request-id') || '').trim();
  const id = /^[A-Za-z0-9_-]{8,64}$/.test(incoming) ? incoming : newRequestId();
  req.requestId = id;
  res.setHeader('X-Request-Id', id);

  // API responses carry per-user data; never let a proxy or CDN cache them.
  if (String(req.path || '').startsWith('/api')) {
    res.setHeader('Cache-Control', 'no-store');
  }

  const done = () => {
    res.removeListener('finish', done);
    res.removeListener('close', done);
    const ms = Number(process.hrtime.bigint() - started) / 1e6;
    const action = String(req.body?.action || req.query?.action || '').slice(0, 64);
    const status = res.statusCode;
    const reqPath = String(req.path || '');
    const probe = PROBE_PATHS.has(reqPath);
    if (!probe) recordRequest({ action, status, ms, path: reqPath });
    if (probe && ms < SLOW_MS) return;
    const line = {
      ts: new Date().toISOString(),
      id,
      method: req.method,
      path: req.path,
      action: action || undefined,
      status,
      ms: Math.round(ms),
      ip: req.clientIpMasked || undefined,
      uid: req.authUid || undefined,
    };
    if (ms >= SLOW_MS) {
      markSlow();
      console.warn('[slow]', JSON.stringify(line));
    } else if (env.nodeEnv === 'production' && !reqPath.startsWith('/media/')) {
      console.log('[req]', JSON.stringify(line));
    }
  };
  res.on('finish', done);
  res.on('close', done);
  next();
}
