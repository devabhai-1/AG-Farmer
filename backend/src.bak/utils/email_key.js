/**
 * Shared RTDB-safe email key — MUST match across auth, users, activity, AI.
 */
export function normalizeEmail(email) {
  return String(email || '').trim().toLowerCase();
}

export function emailKey(email) {
  return normalizeEmail(email)
    .replace(/@/g, '_at_')
    .replace(/\./g, '_dot_')
    .replace(/[^a-z0-9_]/g, '_');
}
