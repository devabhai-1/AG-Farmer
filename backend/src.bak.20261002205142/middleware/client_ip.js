import crypto from 'crypto';
import { env } from '../config/env.js';

/** Normalize Express remote address / proxy headers to a clean IPv4/IPv6 string. */
export function extractClientIp(req) {
  const xf = req.headers['x-forwarded-for'];
  let raw = '';
  if (typeof xf === 'string' && xf.trim()) {
    raw = xf.split(',')[0].trim();
  } else if (Array.isArray(xf) && xf[0]) {
    raw = String(xf[0]).trim();
  } else if (req.headers['x-real-ip']) {
    raw = String(req.headers['x-real-ip']).trim();
  } else {
    raw = req.socket?.remoteAddress || req.ip || '';
  }
  return normalizeIp(raw);
}

export function normalizeIp(ip) {
  let s = String(ip || '').trim();
  if (!s) return 'unknown';
  if (s.startsWith('::ffff:')) s = s.slice(7);
  if (s === '::1') s = '127.0.0.1';
  return s;
}

export function hashIp(ip) {
  const pepper = env.ipPepper || env.jwtSecret || 'ag-farmer-ip';
  return crypto.createHash('sha256').update(`${pepper}|${normalizeIp(ip)}`).digest('hex');
}

/** e.g. 192.168.1.36 → 192.168.1.* */
export function maskIp(ip) {
  const s = normalizeIp(ip);
  if (s.includes('.')) {
    const p = s.split('.');
    if (p.length === 4) return `${p[0]}.${p[1]}.${p[2]}.*`;
  }
  if (s.includes(':')) {
    const p = s.split(':');
    return `${p.slice(0, 3).join(':')}:*`;
  }
  return s;
}

export function clientIpMiddleware(req, _res, next) {
  req.clientIp = extractClientIp(req);
  req.clientIpHash = hashIp(req.clientIp);
  req.clientIpMasked = maskIp(req.clientIp);
  next();
}
