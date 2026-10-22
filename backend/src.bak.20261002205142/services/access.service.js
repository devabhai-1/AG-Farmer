import { UserService } from './user.service.js';
import { CatalogService } from './catalog.service.js';

const RANK = {
  free: 0,
  local: 0,
  advanced: 2,
  all: 3,
  allcrops: 3,
  super: 4,
  superpro: 4,
  superpremium: 4,
  distributor: 5,
  distributorpro: 5,
  dealer: 5,
};

function planKey(planId) {
  return String(planId || 'free')
    .toLowerCase()
    .trim()
    .replace(/[\s_-]+/g, '');
}

export function planRank(planId) {
  return RANK[planKey(planId)] ?? 0;
}

function deny(code, status = 403) {
  const err = new Error(code);
  err.status = status;
  throw err;
}

/** Lowest paid rank that may use this crop. Unknown and custom names need ₹299. Afim needs ₹599. */
export async function requiredRankForCrop(cropId) {
  const id = String(cropId || '').trim().toLowerCase();
  if (!id || id === 'all') return 2;
  if (id === 'afim' || id.startsWith('afim')) return 3;
  if (id.startsWith('custom_')) return 2;
  const crop = await CatalogService.getCrop(id);
  const min = planKey(crop?.minPlan || 'advanced');
  if (min === 'free' || min === 'local') return 2;
  return RANK[min] ?? 2;
}

/**
 * Course, track, knowledge and live-crop calls are allowed only from the
 * subscription stored on the server. The plan name in the request is ignored.
 */
export async function assertCropAccess({ uid, cropId }) {
  if (!uid) deny('login_required', 401);
  const plan = await UserService.effectivePlanId(uid);
  const need = await requiredRankForCrop(cropId);
  if (planRank(plan) < need) {
    const err = new Error('plan_required');
    err.status = 403;
    err.planId = plan;
    throw err;
  }
  return plan;
}
