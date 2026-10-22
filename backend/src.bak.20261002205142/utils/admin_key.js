import crypto from 'crypto';
import { env } from '../config/env.js';

/** Compare admin keys without leaking the key through response time. */
export function adminKeyMatches(given) {
  const expected = String(env.adminApiKey || '');
  const got = String(given || '');
  if (!expected || !got) return false;
  const a = crypto.createHash('sha256').update(expected).digest();
  const b = crypto.createHash('sha256').update(got).digest();
  return crypto.timingSafeEqual(a, b);
}
