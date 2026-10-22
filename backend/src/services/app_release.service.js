import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { writeJsonAtomic } from '../utils/atomic_write.js';

const file = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '../../data/app_release.json',
);

const STORE = 'https://play.google.com/store/apps/details?id=com.agfarmer.app';

/** Read on every call. minBuild 0 means every installed build may run. */
export function getAppRelease() {
  let raw = {};
  try {
    raw = JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch {
    raw = {};
  }
  const minBuild = Number(raw.minBuild);
  const storeUrl = typeof raw.storeUrl === 'string' ? raw.storeUrl.trim() : '';
  return {
    minBuild: Number.isFinite(minBuild) && minBuild > 0 ? Math.floor(minBuild) : 0,
    storeUrl: storeUrl.startsWith('https://') ? storeUrl : STORE,
  };
}

/** Admin: set Play force-update floor. minBuild 0 = off. */
export function setAppRelease(input = {}) {
  const cur = getAppRelease();
  let minBuild = cur.minBuild;
  if (input.minBuild !== undefined && input.minBuild !== null && input.minBuild !== '') {
    const n = Number(input.minBuild);
    minBuild = Number.isFinite(n) && n > 0 ? Math.floor(n) : 0;
  }
  let storeUrl = cur.storeUrl;
  if (typeof input.storeUrl === 'string' && input.storeUrl.trim()) {
    const u = input.storeUrl.trim();
    if (u.startsWith('https://')) storeUrl = u.slice(0, 300);
  }
  const next = { minBuild, storeUrl };
  writeJsonAtomic(file, next);
  return getAppRelease();
}

/**
 * A build that names itself and is older than the Play Store line is refused.
 * Calls with no build header stay open: the website and the admin panel
 * do not send one. config and health stay open so the update page can load.
 */
export function assertAppBuild(req, action) {
  if (action === 'config' || action === 'health' || action === 'firebase.config') return;
  const { minBuild } = getAppRelease();
  if (!minBuild) return;
  const header = req.get('x-app-build');
  if (header == null || String(header).trim() === '') return;
  const build = Number(header);
  if (!Number.isFinite(build) || build < minBuild) {
    const err = new Error('update_required');
    err.status = 426;
    throw err;
  }
}
