import { jsonCache } from '../utils/json_cache.js';
import path from 'path';
import { fileURLToPath } from 'url';
import { rtdbPush } from './rtdb_system.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const file = path.resolve(__dirname, '../../data/chat_limits.json');

export const defaultChatLimits = {
  guestChatLimit: 5,
  guestLiveLimit: 2,
  bankDays: 30,
  plans: {
    free: {
      label: 'Free',
      totalChat: 20,
      strongChat: 8,
      deep: 0,
      deepPer: 'day',
      rollsOver: false,
      voice: 14,
      voicePer: 'life',
      image: 14,
      liveMini: 8,
      liveMiniPer: 'day',
      courseVoice: 25,
      video: 10,
      videoPer: 'day',
      videoShots: 3,
    },
    advanced: {
      label: '₹299',
      totalChat: 104,
      strongChat: 4,
      deep: 8,
      deepPer: 'month',
      rollsOver: true,
      voice: 20,
      voicePer: 'day',
      image: 24,
      liveMini: 20,
      liveMiniPer: 'day',
      courseVoice: 130,
      video: 45,
      videoPer: 'day',
      videoShots: 4,
    },
    all: {
      label: '₹599',
      totalChat: 166,
      strongChat: 6,
      deep: 2,
      deepPer: 'day',
      rollsOver: true,
      voice: 30,
      voicePer: 'day',
      image: 15,
      liveMini: 60,
      liveMiniPer: 'day',
      courseVoice: 200,
      video: 70,
      videoPer: 'day',
      videoShots: 6,
    },
    super: {
      label: '₹2650',
      totalChat: 330,
      strongChat: 30,
      deep: 8,
      deepPer: 'day',
      rollsOver: true,
      voice: 50,
      voicePer: 'day',
      image: 40,
      video: 140,
      videoPer: 'day',
      liveMini: 0,
      liveMiniPer: 'none',
      courseVoice: 400,
      videoShots: 8,
    },
    distributor: {
      label: '₹13500',
      totalChat: 3300,
      strongChat: 300,
      deep: 80,
      deepPer: 'day',
      rollsOver: true,
      voice: 500,
      voicePer: 'day',
      image: 400,
      video: 0,
      videoPer: 'none',
      liveMini: 0,
      liveMiniPer: 'none',
      courseVoice: 4000,
      videoShots: 10,
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
    const liveMiniPer =
      row.liveMiniPer === 'none' || row.liveMiniPer === 'month' || row.liveMiniPer === 'day'
        ? row.liveMiniPer
        : base.liveMiniPer || 'day';
    const videoPer =
      row.videoPer === 'none' || row.videoPer === 'day'
        ? row.videoPer
        : base.videoPer === 'none'
          ? 'none'
          : 'day';
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
      video: videoPer === 'none' ? 0 : clampInt(row.video, 0, 5000, base.video ?? 0),
      videoPer,
      courseVoice: clampInt(row.courseVoice, 0, 5000, base.courseVoice ?? base.totalChat),
      liveMini: clampInt(row.liveMini, 0, 100000, base.liveMini ?? 0),
      liveMiniPer,
      videoShots: clampInt(row.videoShots, 1, 12, base.videoShots ?? 1),
    };
  }
  return {
    guestChatLimit: clampInt(src.guestChatLimit, 0, 100, defaultChatLimits.guestChatLimit),
    guestLiveLimit: clampInt(src.guestLiveLimit, 0, 20, defaultChatLimits.guestLiveLimit ?? 2),
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
    rtdbPush('system/chat_limits', { ...next, updatedAt: Date.now() });
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
      video: row.videoPer === 'none' ? 0 : row.video || 0,
      videoPer: row.videoPer || 'day',
      courseVoice: row.courseVoice || row.totalChat || 0,
      liveMini: row.liveMini || 0,
      liveMiniPer: row.liveMiniPer || 'day',
      videoShots: row.videoShots || 1,
    };
  },
};
