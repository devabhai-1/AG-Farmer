import { rootRef } from '../config/firebase.js';

const FREE_CHATS = 25;

function readRow(val) {
  const row = val && typeof val === 'object' ? val : {};
  return {
    startedAt: Number(row.startedAt) || 0,
    used: Number(row.used) || 0,
  };
}

/**
 * Free course: 25 chats in total, on gpt-5-mini. No day limit.
 * Paid plans do not call this.
 */
export async function takeCourseChat(uid) {
  const ref = rootRef(`users/${uid}/courseTrial`);
  const result = await ref.transaction((cur) => {
    const now = Date.now();
    const row = readRow(cur);
    if (row.used >= FREE_CHATS) return;
    return {
      startedAt: row.startedAt || now,
      used: row.used + 1,
      updatedAt: now,
    };
  });
  const saved = readRow(result.snapshot?.val());
  if (!result.committed) {
    return { ok: false, used: saved.used, left: Math.max(0, FREE_CHATS - saved.used) };
  }
  return {
    ok: true,
    used: saved.used,
    left: Math.max(0, FREE_CHATS - saved.used),
    startedAt: saved.startedAt,
  };
}
