import { IpChatService } from './ip_chat.service.js';
import { OpenAiService } from './openai.service.js';
import { GeminiService } from './gemini.service.js';
import { AiQuotaService } from './ai_quota.service.js';
import { publicErrorText, sanitizePublicText, ensureLocalDistributorNote, safeFarmerName, stripAccountSecrets } from './ai_privacy.js';
import { UserAiContextService, threadMatchesMode } from './user_ai_context.service.js';
import { UserService } from './user.service.js';
import { planRank, requiredRankForCrop } from './access.service.js';
import { takeCourseChat } from './course_trial.service.js';
import { StorageService } from './storage.service.js';
import { env } from '../config/env.js';
import { WeatherService } from './weather.service.js';
import { ChatLimitsService } from './chat_limits.service.js';
import { parseGeo } from '../utils/geo.js';
import { acquireModelSlot } from './model_lane.js';

/** Server subscription only. The plan name in the request is ignored. */
async function resolveEffectivePlanId(uid) {
  return UserService.effectivePlanId(uid);
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

function lastImagePayload(imageBase64, images) {
  if (imageBase64 && String(imageBase64).length > 40) return imageBase64;
  if (!Array.isArray(images)) return null;
  for (let i = images.length - 1; i >= 0; i -= 1) {
    if (String(images[i] || '').length > 40) return images[i];
  }
  return null;
}

async function storeChatPhoto({ uid, imageBase64, images, mode, lat, lon }) {
  const raw = lastImagePayload(imageBase64, images);
  if (!uid || !raw) return null;
  try {
    const saved = await StorageService.uploadDirect({
      uid,
      base64: raw,
      kind: 'chat',
      filename: mode === 'course' ? 'course.jpg' : 'chat.jpg',
      contentType: 'image/jpeg',
      lat,
      lon,
    });
    ImageGeoService.record({
      uid,
      url: saved.publicUrl,
      objectPath: saved.objectPath,
      lat: saved.lat ?? lat,
      lon: saved.lon ?? lon,
      mode,
      kind: mode === 'course' ? 'course' : 'chat',
    }).catch((e) => console.warn('[chat] image geo skip:', e.message));
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
  const dosage =
    out.dosageHighlight == null
      ? null
      : sanitizePublicText(String(out.dosageHighlight), { label, lang });
  let text = sanitizePublicText(out.text || out.reply || '', { label, lang });
  text = ensureLocalDistributorNote(text, {
    lang,
    dosageHighlight: dosage,
  });
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
  async reply(input) {
    if (!input?._inLane && (input?.uid || input?.email)) {
      const thread =
        UserAiContextService.threadIdFor({
          mode: input.mode,
          cropId: input.cropId,
          sessionId: input.sessionId,
        }) || 'none';
      const key = `${input.uid || String(input.email).trim().toLowerCase()}|${thread}`;
      return UserAiContextService.withLane(key, () =>
        this.reply({ ...input, _inLane: true }),
      );
    }
    return this._reply(input || {});
  },

  async _reply({
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
    voice = false,
    lat = null,
    lon = null,
    place = null,
  }) {
    const voiceTurn = voice === true;
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
      voice: voiceTurn,
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

    // Only this farmer + this thread. Never client history (it can mix chats).
    const isolated =
      Boolean(resolvedUid || String(email || '').trim()) &&
      ctx.threadId &&
      threadMatchesMode(mode, ctx.threadId);
    const serverHistory = isolated && Array.isArray(ctx.history) ? ctx.history : [];
    const contextSummary = isolated ? stripAccountSecrets(ctx.summary || '') : '';
    let courseFreeMini = false;
    let courseVoiceOpen = false;

    if (mode === 'course') {
      if (!resolvedUid) {
        const msg = lang === 'hi'
          ? 'कोर्स के लिए लॉगिन करें।'
          : 'Log in to use a course.';
        return {
          reply: msg,
          text: msg,
          dosageHighlight: null,
          quickReplies: [],
          meta: {
            source: 'plan',
            label: 'AG Farmer',
            blocked: true,
            reason: 'login',
            planId: 'free',
          },
        };
      }
      const planId = await resolveEffectivePlanId(resolvedUid);
      const need = await requiredRankForCrop(cropId);
      if (!voiceTurn && planRank(planId) < need) {
        let trial = { ok: false, left: 0 };
        try {
          trial = await takeCourseChat(resolvedUid);
        } catch (_) {
          trial = { ok: false, left: 0 };
        }
        if (!trial.ok) {
          const msg = lang === 'hi'
            ? 'फ्री प्लान की 25 चैट पूरी हो गईं। आगे की चैट के लिए प्रीमियम प्लान लें।'
            : 'The 25 free-plan chats are used. Take a premium plan for more chats.';
          return {
            reply: msg,
            text: msg,
            dosageHighlight: null,
            quickReplies: [],
            meta: {
              source: 'plan',
              label: 'AG Farmer',
              blocked: true,
              reason: 'plan',
              planId,
            },
          };
        }
        courseFreeMini = true;
      }
    }

    const effectivePlanId = await resolveEffectivePlanId(resolvedUid);
    if (mode === 'course' && voiceTurn && resolvedUid) {
      const gate = AiQuotaService.consumeCourseVoice({
        ip,
        uid: resolvedUid,
        email,
        planId: effectivePlanId,
      });
      if (gate.blocked) {
        const msg =
          lang === 'hi'
            ? 'आज की कोर्स आवाज़ पूरी हो गई। कल फिर बोल सकते हो।'
            : 'Today’s course voice is used up. You can speak again tomorrow.';
        return {
          reply: msg,
          text: msg,
          dosageHighlight: null,
          quickReplies: [],
          meta: {
            source: 'plan',
            label: 'AG Farmer',
            blocked: false,
            reason: 'course_voice',
            planId: effectivePlanId,
          },
        };
      }
      courseVoiceOpen = true;
    }
    const wantDeep =
      !voiceTurn &&
      (deepResearch === true || deepResearch === 'true' || mode === 'deep');
    const afimAsk = /अफीम|अफ़ीम|afim|opium|poppy|पोस्त|papaver/i.test(text);
    const label = imageMode || afimAsk || forced !== 'gemini' ? 'AG Expert' : 'AG High';
    const kind = wantDeep ? 'deep' : imageMode ? 'image' : 'chat';
    const family = imageMode || afimAsk ? 'openai' : forced;
    const guestVoice =
      voiceTurn && !resolvedUid && !String(email || '').trim();
    let liveModel = null;
    let resolved;
    if (courseFreeMini || courseVoiceOpen) {
      const mini = env.openaiChatAdvancedModel || 'gpt-5-mini';
      liveModel = mini;
      resolved = {
        blocked: false,
        model: mini,
        tier: 'strong',
        highPlan: false,
        planId: effectivePlanId,
        status: {},
      };
    } else if (guestVoice) {
      const live = AiQuotaService.consumeLiveMini({
        ip,
        uid: null,
        email: null,
        planId: 'free',
      });
      if (live.blocked) {
        const msg =
          lang === 'hi'
            ? 'बिना लॉगिन AG Live की 2 चैट हो चुकी हैं। आगे के लिए लॉगिन करें।'
            : '2 AG Live chats are done without login. Log in to keep talking.';
        return {
          reply: msg,
          text: msg,
          dosageHighlight: null,
          quickReplies: [],
          meta: {
            source: forced,
            label,
            blocked: true,
            reason: 'login',
            planId: 'free',
          },
        };
      }
      liveModel = live.model;
      resolved = {
        blocked: false,
        model: live.model,
        tier: live.tier,
        highPlan: false,
        planId: 'free',
        status: {},
      };
    } else {
      resolved = AiQuotaService.consumeAndResolveModel({
        ip,
        uid: resolvedUid,
        email,
        kind,
        family,
        planId: effectivePlanId,
      });
    }

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
              ? 'फ्री प्लान की चैट पूरी हो गई। आगे के लिए प्रीमियम प्लान लें।'
              : 'The free-plan chat limit is used. Take a premium plan to continue.'
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

    let address = '';
    let farmerName = '';
    if (resolvedUid) {
      try {
        const profile = await UserService.get(resolvedUid);
        farmerName = safeFarmerName(profile?.name);
        address = String(profile?.address || '').trim();
      } catch (_) {}
    }
    if (voiceTurn && !guestVoice && !courseFreeMini) {
      const live = AiQuotaService.consumeLiveMini({
        ip,
        uid: resolvedUid,
        email,
        planId: effectivePlanId,
      });
      liveModel = live.model;
    }
    const farmContext =
      resolvedUid || String(email || '').trim()
        ? stripAccountSecrets(
            await WeatherService.farmBrief({
              uid: resolvedUid,
              email,
              ip,
              lang,
              address,
              lat,
              lon,
              place,
            }),
          )
        : '';

    const shotCap = Math.max(
      1,
      Math.min(12, Number(ChatLimitsService.quotaFor(effectivePlanId).videoShots) || 1),
    );
    const shotList = [];
    if (Array.isArray(images)) {
      for (const item of images) {
        if (String(item || '').length > 40) shotList.push(item);
      }
    }
    if (imageBase64 && String(imageBase64).length > 40) shotList.push(imageBase64);
    const videoShots = shotList.slice(-shotCap);

    const payload = {
      message:
        text || (lang === 'hi' ? 'इस फोटो की जाँच करें' : 'Analyze this photo'),
      lang,
      cropId,
      mode: wantDeep ? 'deep' : mode,
      history: (serverHistory || [])
        .map((h) => ({
          role: h.role,
          text: stripAccountSecrets(h.text || h.content || ''),
        }))
        .filter((h) => h.text),
      model: liveModel || resolved.model,
      images: videoShots,
      imageBase64: videoShots.length ? videoShots[videoShots.length - 1] : imageBase64,
      videoShots: shotCap,
      contextSummary,
      voice: voiceTurn,
      farmContext,
      farmerName,
      threadId: ctx.threadId || '',
      sessionId: ctx.sessionId || sessionId || '',
    };

    const run = async () => {
      if (!voiceTurn && !imageMode && forced === 'gemini' && !afimAsk) {
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

    const photoGeo =
      parseGeo(lat, lon) || (resolvedUid ? await ImageGeoService.savedFix(resolvedUid) : null);
    if (photoGeo && resolvedUid) {
      WeatherService.rememberFix({
        uid: resolvedUid,
        email,
        lat: photoGeo.lat,
        lon: photoGeo.lon,
      }).catch(() => {});
    }

    const imageUrl =
      imageMode && resolvedUid
        ? await storeChatPhoto({
            uid: resolvedUid,
            imageBase64,
            images: videoShots,
            mode,
            lat: photoGeo?.lat,
            lon: photoGeo?.lon,
          })
        : null;

    let releaseSlot = null;
    try {
      releaseSlot = await acquireModelSlot();
    } catch {
      const busy =
        lang === 'hi'
          ? 'अभी बहुत लोग पूछ रहे हैं। कुछ सेकंड बाद फिर पूछें।'
          : 'A lot of people are asking right now. Ask again in a few seconds.';
      return {
        reply: busy,
        text: busy,
        dosageHighlight: null,
        quickReplies: [],
        meta: {
          source: forced,
          label,
          blocked: true,
          reason: 'busy',
          planId: effectivePlanId,
          threadId: ctx.threadId,
        },
      };
    }
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
        imageLat: photoGeo?.lat,
        imageLon: photoGeo?.lon,
        clientHistory: serverHistory,
        voice: voiceTurn,
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
          imageLat: photoGeo?.lat,
          imageLon: photoGeo?.lon,
          clientHistory: serverHistory,
          voice: voiceTurn,
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
    } finally {
      if (releaseSlot) releaseSlot();
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
    // Course history can be saved and read on the free trial. New chats are limited in ask().
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

  async deleteSession({ uid, email, ip, sessionId = null }) {
    return UserAiContextService.deleteSession({
      uid,
      email,
      ip,
      sessionId,
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
    const effectivePlanId = await resolveEffectivePlanId(uid);
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

  async adminResetDayQuota({ uid, email }) {
    return UserAiContextService.adminResetDayQuota({ uid, email });
  },

  async adminListThreads({ uid, email }) {
    return UserAiContextService.adminListThreads({ uid, email });
  },

  async adminReadThread(args) {
    return UserAiContextService.adminReadThread(args);
  },
};
