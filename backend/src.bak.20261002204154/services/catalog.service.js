import { rootRef, isFirebaseReady } from '../config/firebase.js';
import { plans as seedPlans } from '../../seed/plans.js';
import { crops as seedCrops } from '../../seed/crops.js';

const CATALOG_MS = 30000;
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

  async setPlans(plans) {
    await rootRef('catalog/plans').set(plans);
    catalogCache.plans.at = 0;
    return plans;
  },

  async setCrops(crops) {
    await rootRef('catalog/crops').set(crops);
    catalogCache.crops.at = 0;
    return crops;
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
    const [plans, crops, adminUnlock] = await Promise.all([
      this.getPlans(),
      this.getCrops(),
      this.getAdminUnlock(),
    ]);
    return { plans, crops, adminUnlock };
  },
};
