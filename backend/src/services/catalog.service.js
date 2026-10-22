import { rootRef, isFirebaseReady } from '../config/firebase.js';
import { plans as seedPlans } from '../../seed/plans.js';
import { crops as seedCrops } from '../../seed/crops.js';

const CATALOG_MS = 2000;
const catalogCache = {
  plans: { at: 0, value: null },
  crops: { at: 0, value: null },
  unlock: { at: 0, value: null },
};

function fresh(slot) {
  return slot.value != null && Date.now() - slot.at < CATALOG_MS;
}

function remember(slot, value) {
  slot.at = Date.now();
  slot.value = value;
  return value;
}

function bumpCatalog() {
  catalogCache.plans.at = 0;
  catalogCache.crops.at = 0;
  catalogCache.unlock.at = 0;
  if (!isFirebaseReady()) return;
  rootRef('catalog/updatedAt').set(Date.now()).catch(() => {});
}

export function planMrpInr(plan) {
  const id = String(plan?.id || '')
    .toLowerCase()
    .replace(/[\s_-]+/g, '');
  const key =
    id === 'allcrops' ? 'all' : id === 'superpro' || id === 'superpremium' ? 'super' : id;
  const fixed = seedPlans[key]?.priceInr;
  if (fixed != null && Number.isFinite(Number(fixed))) return Math.round(Number(fixed));
  return Math.max(0, Math.round(Number(plan?.priceInr) || 0));
}

/** What Razorpay charges. saleInr is a cut under the fixed MRP. */
export function planChargeInr(plan) {
  const mrp = planMrpInr(plan);
  const sale = Math.max(0, Math.round(Number(plan?.saleInr) || 0));
  if (sale > 0 && sale < mrp) return sale;
  return mrp;
}

function publicPlans(raw) {
  const src = raw && typeof raw === 'object' ? raw : {};
  const out = {};
  for (const [k, v] of Object.entries(src)) {
    if (!v || typeof v !== 'object') continue;
    const id = String(v.id || k).toLowerCase();
    if (id === 'local' || Number(v.priceInr) === 99) continue;
    if (v.active === false) continue;
    out[k] = v;
  }
  return out;
}

export const CatalogService = {
  async getPlans() {
    if (fresh(catalogCache.plans)) return catalogCache.plans.value;
    if (!isFirebaseReady()) return remember(catalogCache.plans, publicPlans(seedPlans));
    const snap = await rootRef('catalog/plans').get();
    return remember(catalogCache.plans, publicPlans(snap.val() || seedPlans));
  },

  async getCrops() {
    if (fresh(catalogCache.crops)) return catalogCache.crops.value;
    if (!isFirebaseReady()) return remember(catalogCache.crops, seedCrops);
    const snap = await rootRef('catalog/crops').get();
    return remember(catalogCache.crops, snap.val() || seedCrops);
  },

  async getCrop(id) {
    const crops = await this.getCrops();
    return crops?.[id] || null;
  },

  /** Full catalog for local admin — includes inactive / retired plans. */
  async getAdminCatalog() {
    const { adminUnlock } = await import('../../seed/plans.js');
    if (!isFirebaseReady()) {
      return { plans: seedPlans, crops: seedCrops, adminUnlock };
    }
    const [plansSnap, cropsSnap, unlockSnap] = await Promise.all([
      rootRef('catalog/plans').get(),
      rootRef('catalog/crops').get(),
      rootRef('catalog/adminUnlock').get(),
    ]);
    return {
      plans: plansSnap.val() || seedPlans,
      crops: cropsSnap.val() || seedCrops,
      adminUnlock: unlockSnap.val() || adminUnlock,
    };
  },

  async setAdminUnlock(unlock) {
    const { adminUnlock } = await import('../../seed/plans.js');
    const next = {
      ...adminUnlock,
      ...(unlock && typeof unlock === 'object' ? unlock : {}),
      priceInr: Math.max(0, Math.round(Number(unlock?.priceInr) || adminUnlock.priceInr)),
    };
    if (isFirebaseReady()) {
      await rootRef('catalog/adminUnlock').set(next);
      bumpCatalog();
    }
    return next;
  },

  async setPlans(plans) {
    const current = (await this.getAdminCatalog()).plans || {};
    const incoming = plans && typeof plans === 'object' && !Array.isArray(plans) ? plans : {};
    const next = { ...current };
    for (const [id, row] of Object.entries(incoming)) {
      if (!row || typeof row !== 'object') continue;
      const seed = seedPlans[id] || {};
      const mrp = planMrpInr({ id: seed.id || row.id || id, priceInr: seed.priceInr ?? row.priceInr });
      const saleRaw = row.saleInr;
      let sale =
        saleRaw === undefined || saleRaw === null || saleRaw === ''
          ? Math.round(Number(current[id]?.saleInr) || 0)
          : Math.round(Number(saleRaw) || 0);
      if (sale < 0 || sale >= mrp) sale = 0;
      next[id] = {
        ...current[id],
        ...row,
        id: seed.id || row.id || id,
        priceInr: mrp,
        saleInr: sale,
      };
    }
    await rootRef('catalog/plans').set(next);
    bumpCatalog();
    return next;
  },

  async setCrops(crops) {
    const current = (await this.getAdminCatalog()).crops || {};
    const incoming = crops && typeof crops === 'object' && !Array.isArray(crops) ? crops : {};
    const next = { ...current, ...incoming };
    await rootRef('catalog/crops').set(next);
    bumpCatalog();
    return next;
  },

  async getAdminUnlock() {
    if (fresh(catalogCache.unlock)) return catalogCache.unlock.value;
    if (!isFirebaseReady()) {
      const { adminUnlock } = await import('../../seed/plans.js');
      return remember(catalogCache.unlock, adminUnlock);
    }
    const snap = await rootRef('catalog/adminUnlock').get();
    if (snap.exists()) return remember(catalogCache.unlock, snap.val());
    const { adminUnlock } = await import('../../seed/plans.js');
    return remember(catalogCache.unlock, adminUnlock);
  },

  async getAll() {
    const [plans, crops] = await Promise.all([this.getPlans(), this.getCrops()]);
    let updatedAt = 1;
    if (isFirebaseReady()) {
      try {
        const snap = await rootRef('catalog/updatedAt').get();
        if (snap.exists()) updatedAt = Number(snap.val()) || 1;
      } catch {
        /* keep 1 */
      }
    }
    return { plans, crops, updatedAt };
  },
};
