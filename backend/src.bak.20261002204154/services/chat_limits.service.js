import { jsonCache } from '../utils/json_cache.js';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const file = path.resolve(__dirname, '../../data/chat_limits.json');

export const defaultChatLimits = {
  guestChatLimit: 5,
  bankDays: 30,
  plans: {
    free: {
      label: 'Free',
      totalChat: 40,
      strongChat: 0,
      deep: 0,
      deepPer: 'day',
      rollsOver: false,
      voice: 5,
      voicePer: 'life',
      image: 5,
    },
    advanced: {
      label: '₹299',
      totalChat: 52,
      strongChat: 2,
      deep: 4,
      deepPer: 'month',
      rollsOver: true,
      voice: 10,
      voicePer: 'day',
      image: 12,
    },
    all: {
      label: '₹599',
      totalChat: 83,
      strongChat: 3,
      deep: 1,
      deepPer: 'day',
      rollsOver: true,
      voice: 15,
      voicePer: 'day',
    },
    super: {
      label: '₹2650',
      totalChat: 165,
      strongChat: 15,
      deep: 4,
      deepPer: 'day',
      rollsOver: true,
      voice: 25,
      voicePer: 'day',
      image: 20,
      video: 1,
    },
    distributor: {
      label: '₹13500',
      totalChat: 1650,
      strongChat: 150,
      deep: 40,
      deepPer: 'day',
      rollsOver: true,
      voice: 250,
      voicePer: 'day',
      image: 200,
      video: 10,
    },
  },
};

function clampInt(value, min, max, fallback) {
  const n = Number(value);
  if (!Number.isFinite(n)) return fallback;
  return Math.max(min, Math.min(max, Math.round(n)));
}

function sanitize(raw) {
  const src = raw && typeof raw === 'object' ? raw : {};
  const plansIn = src.plans && typeof src.plans === 'object' ? src.plans : {};
  const plans = {};
  for (const id of Object.keys(defaultChatLimits.plans)) {
    const base = defaultChatLimits.plans[id];
    const row = plansIn[id] && typeof plansIn[id] === 'object' ? plansIn[id] : {};
    const totalChat = clampInt(row.totalChat, 0, 5000, base.totalChat);
    let strongChat = clampInt(row.strongChat, 0, 5000, base.strongChat);
    if (strongChat > totalChat) strongChat = totalChat;
    const deepPer = row.deepPer === 'month' ? 'month' : row.deepPer === 'day' ? 'day' : base.deepPer;
    const voicePer = id === 'free' ? 'life' : row.voicePer === 'life' ? 'life' : 'day';
    plans[id] = {
      label: base.label,
      totalChat,
      strongChat,
      deep: clampInt(row.deep, 0, 500, base.deep),
      deepPer,
      rollsOver: id === 'free' ? false : row.rollsOver !== false,
      voice: clampInt(row.voice, 0, 5000, base.voice),
      voicePer,
      image: clampInt(row.image, 0, 5000, base.image ?? 0),
      video: clampInt(row.video, 0, 100, base.video ?? 0),
    };
  }
  return {
    guestChatLimit: clampInt(src.guestChatLimit, 0, 100, defaultChatLimits.guestChatLimit),
    bankDays: clampInt(src.bankDays, 1, 90, defaultChatLimits.bankDays),
    plans,
  };
}

function planKey(planId) {
  const p = String(planId || 'free')
    .toLowerCase()
    .trim()
    .replace(/[\s_-]+/g, '');
  if (p === 'distributor' || p === 'distributorpro' || p === 'dealer') return 'distributor';
  if (p === 'super' || p === 'superpro' || p === 'superpremium') return 'super';
  if (p === 'all' || p === 'allcrops') return 'all';
  if (p === 'advanced') return 'advanced';
  return 'free';
}

const limitsCache = jsonCache(file, defaultChatLimits);

export const ChatLimitsService = {
  get() {
    try {
      return sanitize(limitsCache.read());
    } catch {
      return sanitize(defaultChatLimits);
    }
  },

  save(input) {
    const next = sanitize({ ...this.get(), ...input, plans: { ...this.get().plans, ...(input?.plans || {}) } });
    limitsCache.write(next, { now: true });
    return next;
  },

  quotaFor(planId) {
    const row = this.get().plans[planKey(planId)];
    return {
      strongChat: row.strongChat,
      totalChat: row.totalChat,
      deep: row.deep,
      deepPer: row.deepPer,
      rollsOver: row.rollsOver,
      voice: row.voice,
      voicePer: row.voicePer,
      image: row.image || 0,
      video: row.video || 0,
    };
  },
};
