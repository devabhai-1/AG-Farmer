import crypto from 'crypto';
import { env } from '../config/env.js';

function b64urlJson(obj) {
  return Buffer.from(JSON.stringify(obj)).toString('base64url');
}

export function signAppToken(payload, expiresInSec = env.jwtExpiresSec) {
  const header = { alg: 'HS256', typ: 'JWT' };
  const now = Math.floor(Date.now() / 1000);
  const body = { ...payload, iat: now, exp: now + expiresInSec };
  const h = b64urlJson(header);
  const p = b64urlJson(body);
  const sig = crypto
    .createHmac('sha256', env.jwtSecret)
    .update(`${h}.${p}`)
    .digest('base64url');
  return `${h}.${p}.${sig}`;
}

export function verifyAppToken(token) {
  if (!token || typeof token !== 'string') return null;
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  const [h, p, sig] = parts;
  const expected = crypto
    .createHmac('sha256', env.jwtSecret)
    .update(`${h}.${p}`)
    .digest('base64url');
  const a = Buffer.from(sig);
  const b = Buffer.from(expected);
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) return null;
  try {
    const body = JSON.parse(Buffer.from(p, 'base64url').toString('utf8'));
    if (!body?.uid || !body.exp || body.exp < Math.floor(Date.now() / 1000)) return null;
    return body;
  } catch {
    return null;
  }
}
