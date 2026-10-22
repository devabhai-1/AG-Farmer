import { fail } from './response.js';
import { adminKeyMatches } from '../utils/admin_key.js';

/** Temporary admin gate — later replace with Firebase custom claims. */
export function requireAdminKey(req, res, next) {
  const key = req.header('x-admin-key') || req.query.adminKey;
  if (!adminKeyMatches(key)) {
    return fail(res, 401, 'Unauthorized admin');
  }
  return next();
}

/**
 * Verify session token from Authorization: Bearer <token>
 * Supports both Backend App JWT (perpetual session) and Firebase ID token.
 */
export async function optionalAuth(req, _res, next) {
  const header = req.header('authorization') || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  req.user = null;

  if (!token) return next();

  // 1. Try Backend App Token first (fast local HMAC check, no network roundtrip)
  try {
    const { verifyAppToken } = await import('../services/jwt.service.js');
    const appUser = verifyAppToken(token);
    if (appUser?.uid) {
      req.user = {
        uid: appUser.uid,
        email: appUser.email || null,
        phone_number: appUser.phone || null,
        provider: appUser.provider || 'email',
      };
      return next();
    }
  } catch {
    // continue to Firebase check
  }

  // 2. Fallback to Firebase ID token (if client passed Firebase Auth token)
  try {
    const admin = (await import('../config/firebase.js')).initFirebase();
    if (!admin.apps.length) return next();
    req.user = await admin.auth().verifyIdToken(token);
  } catch {
    // leave req.user null
  }
  return next();
}

export async function requireAuth(req, res, next) {
  await optionalAuth(req, res, () => {
    if (!req.user) return fail(res, 401, 'Login required');
    return next();
  });
}
