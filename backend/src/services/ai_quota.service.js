import { hashIp, normalizeIp } from '../middleware/client_ip.js';
import { readQuota, markQuota } from '../utils/quota_store.js';
import { env } from '../config/env.js';
import { ChatLimitsService } from './chat_limits.service.js';
import { CreditService, hasDailyVideo } from './credit.service.js';
import { UserAiContextService } from './user_ai_context.service.js';

function dayKey(d = new Date()) {
  return d.toISOString().slice(0, 10); // UTC YYYY-MM-DD
}

function monthKey(d = new Date()) {
  return d.toISOString().slice(0, 7);
}

function readStore() {
  return readQuota();
}

function writeStore() {
  markQuota();
}

function writeStoreFor(who) {
  markQuota();
  pushQuotaRtdb(who);
}

function pushQuotaRtdb({ ip, uid, email, planId = null }) {
  try {
    const store = readStore();
    const guest = isGuestUser(uid, email);
    const q = guest ? null : planQuotas(planId);
    const key = bucketKey({ ip, uid, email });
    const day = dayKey();
    const c = guest ? {} : getCounters(getDayBucket(store, day), key);
    const g = guest ? guestRecord(store, ip) : {};
    const life = guest ? { voice: 0 } : voiceLifeRecord(store, key);
    const bank = guest ? {} : store.bank?.[key] || {};
    const voicePerLife = q?.voicePer === 'life';
    UserAiContextService.writeQuotaSnapshot(
      { uid, email, ip },
      {
        day,
        planId: guest ? 'free' : planId || 'free',
        guest,
        chat: guest ? Number(g.chat) || 0 : Number(c.chat) || 0,
        image: Number(c.image) || 0,
        deep: Number(c.deep) || 0,
        strong: Number(c.strong) || 0,
        voice: Number(voicePerLife ? life.voice : c.voice) || 0,
        voiceMini: guest ? Number(g.live) || 0 : Number(c.voiceMini) || 0,
        videoUsed: Number(c.videoUsed) || 0,
        guestChat: Number(g.chat) || 0,
        guestLive: Number(g.live) || 0,
        chatCap: guest ? guestLimit() : q.totalChat,
        imageCap: q?.image ?? 0,
        deepCap: q?.deep ?? 0,
        strongCap: q?.strongChat ?? 0,
        voiceCap: q?.voice ?? 0,
        liveMiniCap: guest ? guestLiveLimit() : q?.liveMiniPer === 'none' ? 0 : q?.liveMini ?? 0,
        liveMiniPer: guest ? 'life' : q?.liveMiniPer || 'day',
        videoCap: q?.video ?? 0,
        guestChatCap: guestLimit(),
        guestLiveCap: guestLiveLimit(),
        voiceLife: Number(life.voice) || 0,
        bankChat: Number(bank.chat) || 0,
        bankStrong: Number(bank.strong) || 0,
      },
    ).catch(() => {});
  } catch (_) {}
}

function bucketKey({ ip, uid, email }) {
  if (uid) return `u:${uid}`;
  if (email) return `e:${String(email).trim().toLowerCase()}`;
  return `ip:${hashIp(ip || '0.0.0.0')}`;
}

function getMonthBucket(store, month) {
  if (!store.months) store.months = {};
  if (!store.months[month]) store.months[month] = {};
  const keys = Object.keys(store.months).sort();
  while (keys.length > 3) {
    delete store.months[keys.shift()];
  }
  return store.months[month];
}

function getDayBucket(store, day) {
  if (!store.days[day]) store.days[day] = {};
    // prune old days after unused allowance has been folded into the bank
    const keys = Object.keys(store.days).sort();
    while (keys.length > 40) {
      delete store.days[keys.shift()];
    }
  return store.days[day];
}

function getCounters(dayMap, key) {
  if (!dayMap[key]) {
    dayMap[key] = { chat: 0, image: 0, deep: 0, strong: 0, ip: null };
  }
  if (dayMap[key].deep == null) dayMap[key].deep = 0;
  if (dayMap[key].strong == null) dayMap[key].strong = 0;
  if (dayMap[key].voice == null) dayMap[key].voice = 0;
  if (dayMap[key].videoUsed == null) dayMap[key].videoUsed = 0;
  if (dayMap[key].voiceMini == null) dayMap[key].voiceMini = 0;
  if (dayMap[key].courseVoice == null) dayMap[key].courseVoice = 0;
  return dayMap[key];
}

function voiceLifeRecord(store, key) {
  if (!store.voiceLife) store.voiceLife = {};
  if (!store.voiceLife[key]) store.voiceLife[key] = { voice: 0 };
  return store.voiceLife[key];
}

function normalizePlanId(planId) {
  return String(planId || 'free')
    .toLowerCase()
    .trim()
    .replace(/[\s_-]+/g, '');
}

/**
 * High / paid crop plans only → advanced models.
 * free + local (chat-only) → always low-cost models.
 * Plan keys: advanced (₹299), all/allCrops (₹599), super/superPro,
 * distributor (₹13500 Distributor Pro).
 */
export function planAllowsAdvanced(planId) {
  const p = normalizePlanId(planId);
  return (
    p === 'advanced' ||
    p === 'all' ||
    p === 'allcrops' ||
    p === 'super' ||
    p === 'superpro' ||
    p === 'superpremium' ||
    p === 'distributor' ||
    p === 'distributorpro' ||
    p === 'dealer'
  );
}

/**
 * Caps sized so a full month on either family costs at most half the plan price.
 * strongChat = first N chats/day on the better model.
 * totalChat = hard stop for the day (strong + cheap).
 * deep / deepPer = deep research cap, separate from chat.
 */
export function planQuotas(planId) {
  return ChatLimitsService.quotaFor(planId);
}

function guestLimit() {
  return ChatLimitsService.get().guestChatLimit;
}

function guestLiveLimit() {
  return ChatLimitsService.get().guestLiveLimit || 2;
}

function bankDays() {
  return ChatLimitsService.get().bankDays;
}

function guestRecord(store, ip) {
  if (!store.guests) store.guests = {};
  const key = bucketKey({ ip, uid: null, email: null });
  if (!store.guests[key]) store.guests[key] = { chat: 0, live: 0 };
  if (store.guests[key].live == null) store.guests[key].live = 0;
  return store.guests[key];
}

function isGuestUser(uid, email) {
  return !uid && !String(email || '').trim();
}

function addDays(iso, n) {
  const d = new Date(`${iso}T00:00:00.000Z`);
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}

/** Fold unused paid-plan chat and strong-model allowance into a carry bank. Deep research is never banked. Free does not roll over. */
function accrue(store, key, planId) {
  if (!store.days) store.days = {};
  if (!store.bank) store.bank = {};
  if (!store.bank[key]) {
    store.bank[key] = { chat: 0, strong: 0, settledDay: null };
  }
  const bank = store.bank[key];
  const q = planQuotas(planId);
  const today = dayKey();
  const yesterday = addDays(today, -1);
  const rolls = q.rollsOver === true;

  if (!rolls) {
    bank.chat = 0;
    bank.strong = 0;
    bank.settledDay = yesterday;
    return { bank, q, rolls };
  }

  if (!bank.settledDay) {
    bank.settledDay = yesterday;
    return { bank, q, rolls };
  }

  if (bank.settledDay < yesterday) {
    let cursor = addDays(bank.settledDay, 1);
    const earliest = addDays(yesterday, -(bankDays() - 1));
    if (cursor < earliest) cursor = earliest;
    while (cursor <= yesterday) {
      const used = store.days[cursor]?.[key] || {};
      bank.chat = Math.max(0, bank.chat + q.totalChat - (Number(used.chat) || 0));
      bank.strong = Math.max(0, bank.strong + q.strongChat - (Number(used.strong) || 0));
      cursor = addDays(cursor, 1);
    }
    const capDays = bankDays();
    bank.chat = Math.min(bank.chat, q.totalChat * capDays);
    bank.strong = Math.min(bank.strong, q.strongChat * capDays);
    bank.settledDay = yesterday;
  }
  return { bank, q, rolls };
}

/**
 * Paid High plans: daily advanced quota then low.
 * Free / local / guests: always low-cost models (same AG High / AG Expert family).
 */
export const AiQuotaService = {
  status({ ip, uid, email, planId = null }) {
    if (isGuestUser(uid, email)) {
      const store = readStore();
      const g = guestRecord(store, ip);
      writeStoreFor({ ip, uid, email, planId });
      return {
        day: dayKey(),
        planId: 'free',
        highPlan: false,
        guest: true,
        rollsOver: false,
        chatUsed: g.chat,
        totalChatLimit: guestLimit(),
        chatLeft: Math.max(0, guestLimit() - g.chat),
        deepLimit: 0,
        deepLeft: 0,
        chatTier: 'low',
      };
    }
    const store = readStore();
    const day = dayKey();
    const key = bucketKey({ ip, uid, email });
    const { bank, q, rolls } = accrue(store, key, planId);
    const dayMap = getDayBucket(store, day);
    const c = getCounters(dayMap, key);
    writeStoreFor({ ip, uid, email, planId });
    const highPlan = rolls;
    const deepMap =
      q.deepPer === 'month'
        ? getCounters(getMonthBucket(store, monthKey()), key)
        : c;
    const strongUsed = Number(c.strong) || 0;
    const chatGrant = q.totalChat + (rolls ? bank.chat : 0);
    const strongGrant = q.strongChat + (rolls ? bank.strong : 0);
    return {
      day,
      planId: planId || 'free',
      highPlan,
      rollsOver: rolls,
      chatUsed: c.chat,
      imageUsed: c.image,
      deepUsed: deepMap.deep,
      deepPer: q.deepPer,
      strongChatLimit: q.strongChat,
      totalChatLimit: q.totalChat,
      chatBank: rolls ? bank.chat : 0,
      strongBank: rolls ? bank.strong : 0,
      chatLeft: Math.max(0, chatGrant - c.chat),
      strongChatLeft: Math.max(0, strongGrant - strongUsed),
      deepLimit: q.deep,
      deepLeft: Math.max(0, q.deep - deepMap.deep),
      chatTier: strongGrant - strongUsed > 0 ? 'strong' : 'low',
    };
  },

  /**
   * Resolve which concrete model id to use, then bump the right counter.
   * kind: 'chat' | 'image'
   * family: 'gemini' | 'openai'  (AG High / AG Expert)
   * planId: subscription plan — only High plans get advanced models
   */
  /**
   * kind: 'chat' | 'image' | 'deep'
   * family: 'gemini' | 'openai'
   * Free: always the cheap chat model, deep research closed.
   * ₹299+: first N chats/day on the stronger model, then the cheap model.
   * Deep research uses its own daily cap and its own model.
   */
  consumeAndResolveModel({
    ip,
    uid,
    email,
    kind = 'chat',
    family = 'openai',
    planId = null,
  }) {
    const store = readStore();
    if (isGuestUser(uid, email)) {
      const g = guestRecord(store, ip);
      if (kind === 'deep' || g.chat >= guestLimit()) {
        writeStoreFor({ ip, uid, email, planId });
        return {
          blocked: true,
          reason: 'login',
          tier: 'low',
          model: null,
          highPlan: false,
          planId: 'free',
          status: this.status({ ip, uid, email, planId }),
        };
      }
      g.chat += 1;
      writeStoreFor({ ip, uid, email, planId });
      return {
        blocked: false,
        tier: 'low',
        model: this.modelFor({
          family: kind === 'image' ? 'openai' : family,
          kind: kind === 'image' ? 'image' : 'chat',
          tier: 'low',
        }),
        highPlan: false,
        planId: 'free',
        status: this.status({ ip, uid, email, planId }),
      };
    }
    const day = dayKey();
    const key = bucketKey({ ip, uid, email });
    const { bank, q, rolls } = accrue(store, key, planId);
    const dayMap = getDayBucket(store, day);
    const c = getCounters(dayMap, key);
    c.ip = normalizeIp(ip || '') || c.ip;

    const highPlan = rolls;
    const isDeep = kind === 'deep';
    const isImage = kind === 'image';
    const strongUsed = Number(c.strong) || 0;
    const chatGrant = q.totalChat + (rolls ? bank.chat : 0);
    const strongGrant = q.strongChat + (rolls ? bank.strong : 0);

    if (isDeep) {
      const deepMap =
        q.deepPer === 'month'
          ? getCounters(getMonthBucket(store, monthKey()), key)
          : c;
      if (deepMap.deep >= q.deep) {
        return {
          blocked: true,
          reason: q.deep <= 0 ? 'plan' : q.deepPer === 'month' ? 'month' : 'daily',
          tier: 'deep',
          model: null,
          highPlan,
          planId: planId || 'free',
          status: this.status({ ip, uid, email, planId }),
        };
      }
      deepMap.deep += 1;
      writeStoreFor({ ip, uid, email, planId });
      return {
        blocked: false,
        tier: 'deep',
        model: this.modelFor({ family, kind: 'deep', tier: 'deep' }),
        highPlan,
        planId: planId || 'free',
        status: this.status({ ip, uid, email, planId }),
      };
    }

    if (isImage) {
      const imageCap = Number(q.image) || 0;
      if (imageCap > 0 && (Number(c.image) || 0) >= imageCap) {
        return {
          blocked: true,
          reason: 'image',
          tier: 'low',
          model: null,
          highPlan: false,
          planId: planId || 'free',
          status: this.status({ ip, uid, email, planId }),
        };
      }
      if (c.chat >= chatGrant) {
        return {
          blocked: true,
          reason: 'chat',
          tier: 'low',
          model: null,
          highPlan,
          planId: planId || 'free',
          status: this.status({ ip, uid, email, planId }),
        };
      }
      c.chat += 1;
      c.image = (Number(c.image) || 0) + 1;
      const freePlan = normalizePlanId(planId) === 'free' || normalizePlanId(planId) === 'local' || !planId;
      const imageMini = freePlan && (Number(c.image) || 0) <= (Number(q.strongChat) || 0);
      if (imageMini) c.strong = (Number(c.strong) || 0) + 1;
      writeStoreFor({ ip, uid, email, planId });
      const mini = env.openaiChatAdvancedModel || 'gpt-5-mini';
      const nano = env.openaiChatLowModel || 'gpt-5-nano';
      return {
        blocked: false,
        tier: freePlan ? (imageMini ? 'strong' : 'low') : 'strong',
        model: freePlan
          ? (imageMini ? mini : nano)
          : this.modelFor({
              family: 'openai',
              kind: 'image',
              tier: 'strong',
            }),
        highPlan,
        planId: planId || 'free',
        status: this.status({ ip, uid, email, planId }),
      };
    }

    if (c.chat >= chatGrant) {
      writeStoreFor({ ip, uid, email, planId });
      return {
        blocked: true,
        reason: 'chat',
        tier: 'low',
        model: null,
        highPlan,
        planId: planId || 'free',
        status: this.status({ ip, uid, email, planId }),
      };
    }

    const tier = strongUsed < strongGrant ? 'strong' : 'low';
    c.chat += 1;
    if (tier === 'strong') c.strong += 1;
    writeStoreFor({ ip, uid, email, planId });

    return {
      blocked: false,
      tier,
      model: this.modelFor({
        family,
        kind: 'chat',
        tier,
      }),
      highPlan,
      planId: planId || 'free',
      status: this.status({ ip, uid, email, planId }),
    };
  },

  /**
   * Course mic only. Separate from normal chat, a bit above that day's chat cap.
   * One spoken course answer = one use. Resets with the UTC day.
   */
  consumeCourseVoice({ ip, uid, email, planId = null }) {
    const store = readStore();
    const q = planQuotas(planId);
    const cap = Math.max(0, Number(q.courseVoice) || 0);
    const key = bucketKey({ ip, uid, email });
    const usedMap = getCounters(getDayBucket(store, dayKey()), key);
    const used = Number(usedMap.courseVoice) || 0;
    if (cap <= 0 || used >= cap) {
      return { blocked: true, used, cap };
    }
    usedMap.courseVoice = used + 1;
    writeStoreFor({ ip, uid, email, planId });
    return { blocked: false, used: used + 1, cap };
  },

  /**
   * Voice and video answers always use gpt-5-mini.
   * Speaking is the app's own voice, not a Google live model.
   */
  consumeLiveMini({ ip, uid, email, planId = null }) {
    const mini = env.openaiChatAdvancedModel || 'gpt-5-mini';
    const store = readStore();
    if (isGuestUser(uid, email)) {
      const g = guestRecord(store, ip);
      if (g.live >= guestLiveLimit()) {
        writeStoreFor({ ip, uid, email, planId });
        return { blocked: true, reason: 'login', tier: 'strong', model: null };
      }
      g.live += 1;
      writeStoreFor({ ip, uid, email, planId });
      return { blocked: false, tier: 'strong', model: mini };
    }
    const q = planQuotas(planId);
    const key = bucketKey({ ip, uid, email });
    const bucket =
      q.liveMiniPer === 'month'
        ? getMonthBucket(store, monthKey())
        : getDayBucket(store, dayKey());
    const c = getCounters(bucket, key);
    c.voiceMini = (Number(c.voiceMini) || 0) + 1;
    writeStoreFor({ ip, uid, email, planId });
    return { blocked: false, tier: 'strong', model: mini };
  },

  /**
   * One AG Live open = one voice use.
   * Free is 5 lifetime, then upgrade. Paid plans reset every day.
   */
  consumeVoice({ ip, uid, email, planId = null }) {
    if (isGuestUser(uid, email)) {
      return { blocked: true, reason: 'login_required' };
    }
    const store = readStore();
    const key = bucketKey({ ip, uid, email });
    const q = planQuotas(planId);
    const life = q.voicePer === 'life';
    const usedMap = life ? voiceLifeRecord(store, key) : getCounters(getDayBucket(store, dayKey()), key);
    const used = Number(usedMap.voice) || 0;
    if (used < q.voice) {
      usedMap.voice = used + 1;
      writeStoreFor({ ip, uid, email, planId });
      return { blocked: false, source: 'plan' };
    }
    if (uid && CreditService.take(uid, 'voice')) {
      return { blocked: false, source: 'credit' };
    }
    const p = normalizePlanId(planId);
    const freeLike = p === 'free' || p === 'local' || p === '';
    return { blocked: true, reason: freeLike ? 'voice_upgrade' : 'voice_credit' };
  },

  refundVoice({ ip, uid, email, planId = null, source = 'plan' }) {
    if (source === 'credit') {
      if (uid) CreditService.giveBack(uid, 'voice');
      return;
    }
    if (isGuestUser(uid, email)) return;
    const store = readStore();
    const key = bucketKey({ ip, uid, email });
    const q = planQuotas(planId);
    const usedMap =
      q.voicePer === 'life'
        ? voiceLifeRecord(store, key)
        : getCounters(getDayBucket(store, dayKey()), key);
    usedMap.voice = Math.max(0, (Number(usedMap.voice) || 0) - 1);
    writeStoreFor({ ip, uid, email, planId });
  },

  consumeVideo({ ip, uid, email, planId = null }) {
    const em = String(email || '').trim().toLowerCase();
    if (!em) {
      return { blocked: true, reason: 'login_required', seconds: 0 };
    }
    if (!hasDailyVideo(planId)) {
      return { blocked: true, reason: 'voice_upgrade', seconds: 0 };
    }
    const store = readStore();
    const key = `e:${em}`;
    const q = planQuotas(planId);
    const paid = planAllowsAdvanced(planId);
    if (q.videoPer === 'none') {
      const usedMap = getCounters(getDayBucket(store, dayKey()), key);
      const used = (Number(usedMap.videoUsed) || 0) + 1;
      usedMap.videoUsed = used;
      writeStoreFor({ ip, uid, email: em, planId });
      return { blocked: false, source: 'plan', seconds: 120, used, cap: null };
    }
    const cap = Math.max(0, Number(q.video) || (paid ? 2 : 2));
    if (cap <= 0) {
      return { blocked: true, reason: paid ? 'voice_credit' : 'voice_upgrade', seconds: 0 };
    }
    const usedMap = getCounters(getDayBucket(store, dayKey()), key);
    const used = Number(usedMap.videoUsed) || 0;
    if (used < cap) {
      usedMap.videoUsed = used + 1;
      writeStoreFor({ ip, uid, email: em, planId });
      return { blocked: false, source: 'plan', seconds: 120, used: used + 1, cap };
    }
    if (uid && CreditService.take(uid, 'video')) {
      return { blocked: false, source: 'credit', seconds: 120, used, cap };
    }
    return {
      blocked: true,
      reason: paid ? 'voice_credit' : 'voice_upgrade',
      seconds: 0,
      used,
      cap,
    };
  },

  refundVideo({ uid, ip, email, planId = null, source = 'plan' }) {
    if (source === 'credit') {
      if (uid) CreditService.giveBack(uid, 'video');
      return;
    }
    const em = String(email || '').trim().toLowerCase();
    if (!em || !hasDailyVideo(planId)) return;
    const store = readStore();
    const key = `e:${em}`;
    const usedMap = getCounters(getDayBucket(store, dayKey()), key);
    usedMap.videoUsed = Math.max(0, (Number(usedMap.videoUsed) || 0) - 1);
    writeStoreFor({ ip, uid, email: em, planId });
  },

  modelFor({ family, kind, tier }) {
    const f = family === 'gemini' ? 'gemini' : 'openai';
    if (tier === 'deep' || kind === 'deep') {
      return f === 'gemini' ? env.geminiChatDeepModel : env.openaiChatDeepModel;
    }
    const strong = tier === 'strong' || tier === 'advanced';
    if (f === 'gemini') {
      if (kind === 'image') {
        return strong ? env.geminiImageAdvancedModel : env.geminiImageLowModel;
      }
      return strong ? env.geminiChatAdvancedModel : env.geminiChatLowModel;
    }
    if (kind === 'image') {
      return strong ? env.openaiImageAdvancedModel : env.openaiImageLowModel;
    }
    return strong ? env.openaiChatAdvancedModel : env.openaiChatLowModel;
  },
};
