import { IpChatService } from './ip_chat.service.js';
import { OpenAiService } from './openai.service.js';
import { GeminiService } from './gemini.service.js';
import { AiQuotaService } from './ai_quota.service.js';
import { publicErrorText, sanitizePublicText } from './ai_privacy.js';
import { UserAiContextService } from './user_ai_context.service.js';
import { UserService } from './user.service.js';
import { StorageService } from './storage.service.js';
import { env } from '../config/env.js';

/** Prefer RTDB subscription; ignore expired / inactive plans. */
async function resolveEffectivePlanId({ uid, planId }) {
  if (uid) {
    try {
      const u = await UserService.get(uid);
      const sub = u?.subscription;
      if (sub && typeof sub === 'object') {
        if (sub.active === false) return 'free';
        if (sub.expiresAt) {
          const t =
            typeof sub.expiresAt === 'number'
              ? sub.expiresAt
              : Date.parse(sub.expiresAt);
          if (Number.isFinite(t) && t < Date.now()) return 'free';
        }
        const fromSub = sub.planId || sub.plan || sub.id;
        if (fromSub) return String(fromSub);
      }
      if (u?.plan && u.plan !== 'free') return String(u.plan);
    } catch (e) {
      console.warn('[chat] plan resolve skip:', e.message);
    }
  }
  return planId || 'free';
}

function normalizeProvider(raw) {
  const p = String(raw || '').toLowerCase().trim();
  if (
    p === 'gemini' ||
    p === 'google' ||
    p === 'high' ||
    p === 'ag-high' ||
    p === 'aghigh'
  ) {
    return 'gemini';
  }
  if (
    p === 'openai' ||
    p === 'gpt' ||
    p === 'chatgpt' ||
    p === 'expert' ||
    p === 'ag-expert' ||
    p === 'agexpert'
  ) {
    return 'openai';
  }
  return null;
}

async function storeChatPhoto({ uid, imageBase64, mode }) {
  if (!uid || !imageBase64 || String(imageBase64).length < 40) return null;
  try {
    const saved = await StorageService.uploadDirect({
      uid,
      base64: imageBase64,
      kind: 'chat',
      filename: mode === 'course' ? 'course.jpg' : 'chat.jpg',
      contentType: 'image/jpeg',
    });
    return saved.publicUrl || null;
  } catch (e) {
    console.error('[chat] image store failed:', e.message);
    return null;
  }
}

function hasImagePayload(images, imageBase64, hasImage) {
  if (hasImage === true) return true;
  if (imageBase64 && String(imageBase64).length > 40) return true;
  if (Array.isArray(images) && images.length > 0) return true;
  return false;
}

function scrubOutput(out, { label, lang }) {
  if (!out) return out;
  const text = sanitizePublicText(out.text || out.reply || '', { label, lang });
  const dosage =
    out.dosageHighlight == null
      ? null
      : sanitizePublicText(String(out.dosageHighlight), { label, lang });
  const quickReplies = Array.isArray(out.quickReplies)
    ? out.quickReplies
        .map((q) => sanitizePublicText(String(q), { label, lang }))
        .filter(Boolean)
        .slice(0, 4)
    : [];
  return {
    ...out,
    text,
    reply: text,
    dosageHighlight: dosage && dosage.length ? dosage : null,
    quickReplies,
  };
}

/**
 * AG High  → Gemini models (advanced then low by daily quota)
 * AG Expert → OpenAI models (advanced then low by daily quota)
 */
export const ChatService = {
  async reply({
    message,
    lang = 'hi',
    cropId = null,
    planId = null,
    mode = 'chat',
    history = [],
    uid = null,
    email = null,
    ip = null,
    provider = null,
    images = null,
    imageBase64 = null,
    hasImage = false,
    sessionId = null,
    chatName = null,
    deepResearch = false,
  }) {
    const text = String(message || '').trim();
    const imageMode = hasImagePayload(images, imageBase64, hasImage);
    if (!text && !imageMode) {
      return {
        reply:
          lang === 'hi'
            ? 'कृपया अपना सवाल लिखें।'
            : 'Please type your question.',
        text:
          lang === 'hi'
            ? 'कृपया अपना सवाल लिखें।'
            : 'Please type your question.',
        dosageHighlight: null,
        quickReplies: [],
        meta: { source: 'validation' },
      };
    }

    const forced =
      normalizeProvider(provider) ||
      (env.aiProvider === 'openai' ? 'openai' : 'gemini');

    // Resolve uid from email index when only email is known (per-user isolation)
    let resolvedUid = uid;
    if (!resolvedUid && email) {
      resolvedUid = await UserAiContextService.resolveUidByEmail(email);
    }

    const ctx = await UserAiContextService.getWindow({
      uid: resolvedUid,
      email,
      ip,
      mode,
      cropId,
      sessionId,
    });

    if (ctx.blocked) {
      const msg =
        lang === 'hi'
          ? 'आपका AI एक्सेस अभी बंद है। सपोर्ट से संपर्क करें।'
          : 'Your AI access is paused. Please contact support.';
      return {
        reply: msg,
        text: msg,
        dosageHighlight: null,
        quickReplies: [],
        meta: { source: 'blocked', label: 'AG Farmer', error: true },
      };
    }

    // Prefer durable per-user window; fall back to client history
    const serverHistory =
      ctx.history?.length > 0
        ? ctx.history
        : Array.isArray(history)
          ? history
          : [];

    const wantDeep = deepResearch === true || deepResearch === 'true' || mode === 'deep';
    const label = imageMode || forced !== 'gemini' ? 'AG Expert' : 'AG High';
    const kind = wantDeep ? 'deep' : imageMode ? 'image' : 'chat';
    const family = imageMode ? 'openai' : forced;
    const effectivePlanId = await resolveEffectivePlanId({
      uid: resolvedUid,
      planId,
    });
    const resolved = AiQuotaService.consumeAndResolveModel({
      ip,
      uid: resolvedUid,
      email,
      kind,
      family,
      planId: effectivePlanId,
    });

    if (resolved.blocked) {
      const msg =
        resolved.reason === 'login'
          ? lang === 'hi'
            ? `बिना लॉगिन ${resolved.status?.totalChatLimit ?? 5} चैट हो चुकी हैं। आगे बात करने के लिए लॉगिन करें।`
            : `${resolved.status?.totalChatLimit ?? 5} chats are done without login. Log in to keep chatting.`
          : resolved.reason === 'image'
          ? lang === 'hi'
            ? 'आज की फोटो जाँच पूरी हो गई। आगे के लिए प्लान अपग्रेड करें।'
            : 'Today’s photo checks are used up. Upgrade your plan to continue.'
          : resolved.reason === 'chat'
          ? resolved.highPlan
            ? lang === 'hi'
              ? 'चैट बैलेंस खत्म हो गया। कल की नई चैट जुड़ जाएगी।'
              : 'Chat balance is used up. Tomorrow’s new chats will be added.'
            : lang === 'hi'
              ? `आज की ${resolved.status?.totalChatLimit ?? 40} चैट पूरी हो गईं। कल फिर ${resolved.status?.totalChatLimit ?? 40} मिलेंगी।`
              : `Today’s ${resolved.status?.totalChatLimit ?? 40} chats are used up. Tomorrow you get ${resolved.status?.totalChatLimit ?? 40} again.`
          : resolved.reason === 'plan'
            ? lang === 'hi'
              ? 'डीप रिसर्च ₹299 और उससे बड़े प्लान पर है। अभी सामान्य चैट में पूछें।'
              : 'Deep research starts on the ₹299 plan and above. Ask in normal chat for now.'
            : resolved.reason === 'month'
              ? lang === 'hi'
                ? 'इस महीने की डीप रिसर्च पूरी हो गई। अभी सामान्य चैट में पूछें।'
                : 'This month’s deep research is used up. Ask in normal chat for now.'
              : lang === 'hi'
                ? 'आज की डीप रिसर्च पूरी हो गई। कल फिर खुल जाएगी। अभी सामान्य चैट में पूछें।'
                : 'Today’s deep research is used up. It opens again tomorrow. Ask in normal chat for now.';
      return {
        reply: msg,
        text: msg,
        dosageHighlight: null,
        quickReplies: [],
        meta: {
          source: forced,
          label,
          deepResearch: wantDeep,
          blocked: true,
          reason: resolved.reason || 'chat',
          planId: effectivePlanId,
          quota: resolved.status,
        },
      };
    }

    // Mirror quota onto per-user RTDB path (10k-scale control)
    UserAiContextService.bumpQuota(
      { uid: resolvedUid, email, ip },
      kind,
    ).catch(() => {});

    const payload = {
      message:
        text || (lang === 'hi' ? 'इस फोटो की जाँच करें' : 'Analyze this photo'),
      lang,
      cropId,
      mode: wantDeep ? 'deep' : mode,
      history: serverHistory,
      model: resolved.model,
      images,
      imageBase64,
      contextSummary: ctx.summary || '',
    };

    const run = async () => {
      if (!imageMode && forced === 'gemini') {
        if (!GeminiService.isConfigured()) {
          throw Object.assign(new Error('gemini_not_configured'), {
            status: 503,
          });
        }
        return GeminiService.chatComplete(payload);
      }
      if (!OpenAiService.isConfigured()) {
        throw Object.assign(new Error('openai_not_configured'), {
          status: 503,
        });
      }
      return OpenAiService.chatComplete(payload);
    };

    const imageUrl =
      imageMode && resolvedUid
        ? await storeChatPhoto({
            uid: resolvedUid,
            imageBase64,
            mode,
          })
        : null;

    try {
      const out = scrubOutput(await run(), { label, lang });
      console.info(
        `[chat] ${label} ok plan=${effectivePlanId} tier=${resolved.tier} model=${resolved.model} user=${resolvedUid || email || 'guest'}`,
      );

      // Persist isolated context window for this email/uid (+ named session)
      UserAiContextService.appendTurn({
        uid: resolvedUid,
        email,
        ip,
        mode,
        cropId,
        sessionId,
        chatName,
        userText: payload.message,
        assistantText: out.text,
        label,
        imageUrl,
        clientHistory: serverHistory,
      }).catch((e) => console.warn('[chat] context save skip:', e.message));

      return {
        ...out,
        meta: {
          source: imageMode ? 'openai' : forced,
          label,
          tier: resolved.tier,
          planId: effectivePlanId,
          highPlan: resolved.highPlan,
          kind,
          deepResearch: wantDeep,
          quota: resolved.status,
          threadId: ctx.threadId,
          sessionId: ctx.sessionId,
          imageUrl,
        },
      };
    } catch (e) {
      console.error(`[chat] ${label} failed:`, e.message);
      const friendly = publicErrorText({ label, lang });
      if (imageUrl) {
        UserAiContextService.appendTurn({
          uid: resolvedUid,
          email,
          ip,
          mode,
          cropId,
          sessionId,
          chatName,
          userText: payload.message,
          assistantText: friendly,
          label,
          imageUrl,
          clientHistory: serverHistory,
        }).catch((err) => console.warn('[chat] photo save skip:', err.message));
      }
      return {
        reply: friendly,
        text: friendly,
        dosageHighlight: null,
        quickReplies: [],
        meta: {
          source: forced,
          label,
          error: true,
          tier: resolved.tier,
          planId: effectivePlanId,
          highPlan: resolved.highPlan,
          kind,
          quota: resolved.status,
          threadId: ctx.threadId,
          imageUrl,
        },
      };
    }
  },

  async sync({
    ip,
    messages,
    uid,
    email,
    mode = 'chat',
    cropId = null,
    sessionId = null,
    chatName = null,
  }) {
    // Logged-in / email users → Realtime Database only (no local JSON source of truth)
    if (uid || email) {
      await UserAiContextService.mergeIntoUid({ uid, email, ip });
      const saved = await UserAiContextService.syncThreadMessages({
        uid,
        email,
        ip,
        mode,
        cropId,
        sessionId,
        chatName,
        messages,
      });
      return {
        ...saved,
        ipMirrored: false,
        note: saved.ok
          ? 'stored_in_rtdb'
          : saved.error || 'rtdb_required',
      };
    }
    // Anonymous guests: short-lived IP bucket only (not durable across devices)
    return IpChatService.syncMessages({ ip, messages, uid, email });
  },

  async restore({
    ip,
    uid,
    email,
    mode = 'chat',
    cropId = null,
    sessionId = null,
    limit = 400,
  }) {
    if (uid || email) {
      const fromDb = await UserAiContextService.restoreThreadMessages({
        uid,
        email,
        ip,
        mode,
        cropId,
        sessionId,
        limit,
      });
      return {
        messages: fromDb.messages || [],
        source: fromDb.source || 'user_ai',
        storage: fromDb.storage,
        threadId: fromDb.threadId,
        sessionId: fromDb.sessionId,
      };
    }
    return IpChatService.restore({ ip, uid, email });
  },

  async listSessions({ uid, email, ip, mode = 'chat' }) {
    return UserAiContextService.listSessions({ uid, email, ip, mode });
  },

  async createSession({ uid, email, ip, sessionId = null, chatName = null }) {
    return UserAiContextService.upsertSession({
      uid,
      email,
      ip,
      sessionId,
      chatName,
    });
  },

  async bindIp({ ip, uid, email }) {
    if (uid || email) {
      await UserAiContextService.mergeIntoUid({ uid, email, ip });
      if (email && uid) {
        await UserAiContextService.setControl(
          { uid, email },
          { email: String(email).trim().toLowerCase(), uid },
        );
      }
    }
    return IpChatService.bindIdentity({ ip, email, uid });
  },

  async quotaStatus({ ip, uid, email, planId = null }) {
    const effectivePlanId = await resolveEffectivePlanId({ uid, planId });
    return AiQuotaService.status({
      ip,
      uid,
      email,
      planId: effectivePlanId,
    });
  },

  /** Admin: per-user AI control */
  async adminUserContext({ uid, email }) {
    return UserAiContextService.adminGetUser({ uid, email });
  },

  async adminSetControl({ uid, email, patch }) {
    return UserAiContextService.setControl({ uid, email }, patch || {});
  },
};
