import { env } from '../config/env.js';
import { AiQuotaService } from './ai_quota.service.js';
import { UserService } from './user.service.js';

const WS_URL =
  'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContentConstrained';

function isSuperLivePlan(planId) {
  const p = String(planId || '')
    .toLowerCase()
    .replace(/[\s_-]+/g, '');
  return (
    p === 'super' ||
    p === 'superpro' ||
    p === 'superpremium' ||
    p === 'distributor' ||
    p === 'distributorpro' ||
    p === 'dealer'
  );
}

function clip(text, n = 40) {
  const t = String(text || '').replace(/\s+/g, ' ').trim();
  if (t.length <= n) return t;
  return `${t.slice(0, n - 1)}…`;
}

function memoryLines(recent, clipLen = 40) {
  const rows = (Array.isArray(recent) ? recent : [])
    .filter((m) => m && (m.role === 'user' || m.role === 'assistant') && m.text)
    .slice(-5)
    .map((m) => `${m.role === 'user' ? 'K' : 'A'}: ${clip(m.text, clipLen)}`);
  if (!rows.length) return '';
  return rows.join('\n');
}

function farmingInstructions({ lang, cropId, recent, superLive, video = false }) {
  const crop = cropId ? ` ${cropId}.` : '';
  const memory = memoryLines(recent, superLive ? 80 : 40);
  const hi = lang === 'hi';
  const line = hi
    ? `AG Live.${crop} साफ और धीमी हिन्दी बोलो। किसान का पूरा वाक्य सुनो, फिर 1 या 2 छोटे वाक्य। खुद को दोहराओ मत और बीच में मत रuko। दवा हो तो पहले नाम और मात्रा, आखिरी वाक्य: अब एक बार जाइए और विशेषज्ञ से पूछ लें। शुरू करो: राम-राम किसान भाई। मॉडल का नाम मत लो।`
    : `AG Live.${crop} Speak clear, slow Hindi or English. Hear the full sentence, then 1 or 2 short sentences. Do not repeat yourself. If medicine, name it and the dose first. Last sentence: now go once and ask an expert. Start: राम-राम किसान भाई. Never name the model.`;
  return [line, memory].filter(Boolean).join('\n');
}

async function resolvePlanId({ uid, planId }) {
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
      console.warn('[gemini_live] plan resolve skip:', e.message);
    }
  }
  return planId || 'free';
}

/**
 * Short-lived Gemini Live token for the phone. The long-lived API key stays here.
 * AG Live is Gemini voice only (gemini-3.8-live). High plans only.
 */
export const GeminiLiveService = {
  isConfigured() {
    return Boolean(env.geminiApiKey && String(env.geminiApiKey).length > 10);
  },

  async createClientSecret({
    lang = 'hi',
    cropId = null,
    uid = null,
    email = null,
    ip = null,
    planId = null,
    recent = null,
    mode = 'voice',
  } = {}) {
    if (!this.isConfigured()) {
      const err = new Error('gemini_not_configured');
      err.status = 503;
      throw err;
    }

    const effectivePlan = await resolvePlanId({ uid, planId });
    const video = mode === 'video';
    const voiceGate = video
      ? AiQuotaService.consumeVideo({ ip, uid, email, planId: effectivePlan })
      : AiQuotaService.consumeVoice({ ip, uid, email, planId: effectivePlan });
    if (voiceGate.blocked) {
      const err = new Error(voiceGate.reason || 'voice_upgrade');
      err.status = 403;
      err.planId = effectivePlan;
      throw err;
    }
    const refund = () => {
      const args = { ip, uid, email, planId: effectivePlan, source: voiceGate.source };
      if (video) AiQuotaService.refundVideo(args);
      else AiQuotaService.refundVoice(args);
    };

    const model = env.geminiLiveModel || 'gemini-3.8-live';
    const voice = env.geminiLiveVoice || 'Kore';
    const superLive = isSuperLivePlan(effectivePlan);
    const instructions = farmingInstructions({
      lang,
      cropId,
      recent,
      superLive,
      video,
    });
    const maxOutputTokens = video ? 160 : 180;
    const expireTime = new Date(Date.now() + (video ? 10 : 30) * 60 * 1000).toISOString();
    const newSessionExpireTime = new Date(Date.now() + (video ? 5 : 2) * 60 * 1000).toISOString();

    let res;
    try {
      res = await fetch(
      'https://generativelanguage.googleapis.com/v1beta/auth_tokens',
      {
        method: 'POST',
        headers: {
          'x-goog-api-key': env.geminiApiKey,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          uses: 1,
          expireTime,
          newSessionExpireTime,
          bidiGenerateContentSetup: {
            model: `models/${model}`,
            generationConfig: {
              responseModalities: ['AUDIO'],
              maxOutputTokens,
              speechConfig: {
                voiceConfig: {
                  prebuiltVoiceConfig: { voiceName: voice },
                },
              },
            },
            systemInstruction: {
              parts: [{ text: instructions }],
            },
            realtimeInputConfig: {
              activityHandling: 'NO_INTERRUPTION',
              automaticActivityDetection: {
                silenceDurationMs: 1100,
                prefixPaddingMs: 400,
                endOfSpeechSensitivity: 'END_SENSITIVITY_LOW',
              },
            },
            inputAudioTranscription: {},
            outputAudioTranscription: {},
            contextWindowCompression: superLive
              ? { triggerTokens: 2000, slidingWindow: { targetTokens: 800 } }
              : { triggerTokens: 1200, slidingWindow: { targetTokens: 500 } },
          },
        }),
      },
    );
    } catch (e) {
      refund();
      throw e;
    }

    const body = await res.json().catch(() => ({}));
    if (!res.ok) {
      refund();
      const msg = body?.error?.message || `gemini_live_http_${res.status}`;
      console.error('[gemini_live]', res.status, msg);
      const err = new Error('voice_live_unavailable');
      err.status = res.status >= 500 ? 502 : 400;
      throw err;
    }

    const ephemeral = body?.name || body?.token || null;
    if (!ephemeral || typeof ephemeral !== 'string') {
      refund();
      console.error('[gemini_live] token missing');
      const err = new Error('voice_live_unavailable');
      err.status = 502;
      throw err;
    }

    return {
      provider: 'gemini',
      clientSecret: ephemeral,
      expiresAt: expireTime,
      model,
      voice,
      instructions,
      label: 'AG Live',
      liveQuality: superLive ? 'super' : 'short',
      mode: video ? 'video' : 'voice',
      videoSeconds: video ? voiceGate.seconds || 120 : 0,
      planId: effectivePlan,
      wsUrl: WS_URL,
    };
  },
};
