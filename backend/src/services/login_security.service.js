import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { isFirebaseReady, rootRef } from '../config/firebase.js';
import { maskIp, normalizeIp } from '../middleware/client_ip.js';
import { emailKey } from '../utils/email_key.js';
import { writeJsonAtomic } from '../utils/atomic_write.js';
import { rtdbPush } from './rtdb_system.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const dataDir = path.resolve(__dirname, '../../data');
const lockoutsFile = path.join(dataDir, 'login_lockouts.json');

// Configuration
const MAX_FAILED_ATTEMPTS = 5;
const ATTEMPT_WINDOW_MS = 15 * 60 * 1000; // 15 minutes window
const LOCKOUT_DURATION_MS = 24 * 60 * 60 * 1000; // 24 hours lockout

// In-memory cache for 0ms response time
// Map<key, { count: number, firstAttemptAt: number, lockUntil: number }>
const attemptStore = new Map();

function ensureStoreFile() {
  if (!fs.existsSync(dataDir)) {
    fs.mkdirSync(dataDir, { recursive: true });
  }
  if (!fs.existsSync(lockoutsFile)) {
    writeJsonAtomic(lockoutsFile, {});
  }
}

function loadPersistedLockouts() {
  try {
    ensureStoreFile();
    const raw = JSON.parse(fs.readFileSync(lockoutsFile, 'utf8'));
    const now = Date.now();
    for (const [key, data] of Object.entries(raw)) {
      if (data?.lockUntil && data.lockUntil > now) {
        attemptStore.set(key, {
          count: data.count || MAX_FAILED_ATTEMPTS,
          firstAttemptAt: data.firstAttemptAt || now,
          lockUntil: data.lockUntil,
        });
      }
    }
  } catch (err) {
    console.warn('[login-security] Failed to load lockouts:', err.message);
  }
}

function persistActiveLockouts() {
  try {
    ensureStoreFile();
    const now = Date.now();
    const active = {};
    for (const [key, data] of attemptStore.entries()) {
      if (data.lockUntil && data.lockUntil > now) {
        active[key] = data;
      }
    }
    writeJsonAtomic(lockoutsFile, active);
    rtdbPush('system/lockouts', { ...active, updatedAt: Date.now() });
  } catch (err) {
    console.warn('[login-security] Failed to persist lockouts:', err.message);
  }
}

// Initial load on startup
loadPersistedLockouts();

export const LoginSecurityService = {
  MAX_FAILED_ATTEMPTS,
  LOCKOUT_DURATION_MS,

  /**
   * Check if an IP or email is currently locked out for 24 hours.
   */
  isBlocked({ ip = null, email = null } = {}) {
    const now = Date.now();
    const keysToCheck = [];

    if (ip) {
      const normIp = normalizeIp(ip);
      if (normIp && normIp !== 'unknown') {
        keysToCheck.push(`ip_${normIp}`);
      }
    }

    if (email) {
      const ek = emailKey(email);
      if (ek) {
        keysToCheck.push(`email_${ek}`);
      }
    }

    for (const key of keysToCheck) {
      const record = attemptStore.get(key);
      if (record && record.lockUntil && record.lockUntil > now) {
        const remainingMs = record.lockUntil - now;
        const remainingHours = Math.max(1, Math.ceil(remainingMs / (60 * 60 * 1000)));
        return {
          blocked: true,
          remainingMs,
          remainingHours,
          reason: key.startsWith('ip_') ? 'ip_blocked' : 'account_blocked',
        };
      }
    }

    return { blocked: false, remainingMs: 0, remainingHours: 0 };
  },

  /**
   * Record a failed login attempt. If attempts exceed MAX_FAILED_ATTEMPTS within
   * ATTEMPT_WINDOW_MS, locks the IP and account for 24 hours.
   */
  async recordFailedAttempt({ ip = null, email = null, userAgent = '' } = {}) {
    const now = Date.now();
    const keysToUpdate = [];

    if (ip) {
      const normIp = normalizeIp(ip);
      if (normIp && normIp !== 'unknown') {
        keysToUpdate.push(`ip_${normIp}`);
      }
    }

    if (email) {
      const ek = emailKey(email);
      if (ek) {
        keysToUpdate.push(`email_${ek}`);
      }
    }

    let isNowLocked = false;
    let lockUntil = 0;

    for (const key of keysToUpdate) {
      let record = attemptStore.get(key);

      if (!record || now - record.firstAttemptAt > ATTEMPT_WINDOW_MS) {
        record = { count: 1, firstAttemptAt: now, lockUntil: 0 };
      } else {
        record.count += 1;
      }

      if (record.count >= MAX_FAILED_ATTEMPTS) {
        record.lockUntil = now + LOCKOUT_DURATION_MS;
        isNowLocked = true;
        lockUntil = record.lockUntil;
      }

      attemptStore.set(key, record);
    }

    if (isNowLocked) {
      console.warn(
        `[login-security] 24h LOCKOUT triggered! IP=${ip} Email=${email} UA=${userAgent.slice(0, 50)}`,
      );
      persistActiveLockouts();

      // Mirror lockout alert to RTDB non-blockingly
      if (isFirebaseReady()) {
        const alertId = `lockout_${now}_${Math.random().toString(36).slice(2, 6)}`;
        rootRef(`security/lockouts/${alertId}`)
          .set({
            ip: ip ? normalizeIp(ip) : null,
            ipMasked: ip ? maskIp(ip) : null,
            email: email || null,
            userAgent: userAgent ? userAgent.slice(0, 200) : null,
            lockUntil,
            createdAt: now,
            at: new Date(now).toISOString(),
          })
          .catch(() => {});
      }
    }

    return {
      locked: isNowLocked,
      lockUntil,
      remainingHours: isNowLocked ? 24 : 0,
    };
  },

  /**
   * Reset failed attempt count and record successful login audit in RTDB.
   */
  async recordSuccessfulLogin({
    uid,
    email = null,
    ip = null,
    userAgent = '',
    provider = 'email',
  } = {}) {
    // 1. Reset failed attempts for this IP and email
    if (ip) {
      const normIp = normalizeIp(ip);
      attemptStore.delete(`ip_${normIp}`);
    }
    if (email) {
      const ek = emailKey(email);
      attemptStore.delete(`email_${ek}`);
    }
    persistActiveLockouts();

    // 2. Audit record in Firebase RTDB (Non-blocking async)
    const now = Date.now();
    const normIp = ip ? normalizeIp(ip) : 'unknown';
    const masked = maskIp(normIp);
    const uaClean = String(userAgent || '').slice(0, 200);

    const loginAudit = {
      ip: normIp,
      maskedIp: masked,
      userAgent: uaClean,
      provider,
      timestamp: now,
      at: new Date(now).toISOString(),
    };

    if (isFirebaseReady() && uid) {
      try {
        const ops = [];

        // Save last login snapshot under user security
        ops.push(rootRef(`users/${uid}/security/lastLogin`).set(loginAudit));

        // Update profile fields
        ops.push(
          rootRef(`users/${uid}/profile`).update({
            lastLoginAt: now,
            lastLoginIp: normIp,
            lastLoginProvider: provider,
            updatedAt: now,
          }),
        );

        // Keep last 15 logins history
        const historyId = `l_${now}_${Math.random().toString(36).slice(2, 6)}`;
        ops.push(rootRef(`users/${uid}/security/history/${historyId}`).set(loginAudit));

        // If email known, mirror under email_users
        if (email) {
          const ek = emailKey(email);
          if (ek) {
            ops.push(rootRef(`email_users/${ek}/security/lastLogin`).set(loginAudit));
            ops.push(
              rootRef(`email_users/${ek}/profile`).update({
                lastLoginAt: now,
                lastLoginIp: normIp,
                lastLoginProvider: provider,
                updatedAt: now,
              }),
            );
          }
        }

        Promise.allSettled(ops).catch(() => {});
      } catch (err) {
        console.warn('[login-security] Audit write skipped:', err.message);
      }
    }

    return loginAudit;
  },

  /**
   * Reset lockout manually (e.g. for testing or admin unblock).
   */
  clearLockout({ ip = null, email = null } = {}) {
    if (ip) {
      attemptStore.delete(`ip_${normalizeIp(ip)}`);
    }
    if (email) {
      attemptStore.delete(`email_${emailKey(email)}`);
    }
    persistActiveLockouts();
  },

  /** Active 24h lockouts for admin panel. */
  listLockouts() {
    const now = Date.now();
    const rows = [];
    for (const [key, data] of attemptStore.entries()) {
      if (!data?.lockUntil || data.lockUntil <= now) continue;
      const kind = key.startsWith('ip_') ? 'ip' : key.startsWith('email_') ? 'email' : 'other';
      const value = key.replace(/^(ip_|email_)/, '');
      rows.push({
        key,
        kind,
        value,
        ip: kind === 'ip' ? value : null,
        email: kind === 'email' ? value : null,
        count: Number(data.count) || 0,
        lockUntil: data.lockUntil,
        remainingMs: Math.max(0, data.lockUntil - now),
      });
    }
    rows.sort((a, b) => (b.lockUntil || 0) - (a.lockUntil || 0));
    return rows;
  },
};
