import { createHash } from 'crypto';
import { env } from '../config/env.js';
import { adviceClassRule, cropSpecialty, farmerPrivacyRule, identityRules, medicineApiInject, medicineDistributorPromptRule } from './ai_privacy.js';
import { planAllowsAdvanced } from './ai_quota.service.js';
import { UserService } from './user.service.js';

function farmingInstructions({ lang, cropId }) {
  const hi = lang === 'hi';
  const crop = cropId
    ? hi
      ? `सक्रिय फसल: ${cropId}. इसी फसल पर ध्यान दें।`
      : `Active crop: ${cropId}. Stay focused on this crop.`
    : hi
      ? 'कोई फसल चुनी न हो तो भी अफीम और लहसुन ही मानो।'
      : 'If no crop is selected, still answer for opium poppy and garlic.';

  return [
    hi
      ? 'तुम AG Live हो — AG Farmer का लाइव आवाज़ कृषि वैज्ञानिक। जवाब बोलने योग्य हो, पर हल्की टिप नहीं — उच्च स्तर की सटीक राय दो।'
      : 'You are AG Live — AG Farmer live voice agri-scientist. Speak clearly, and give high-class precise advice, not a light tip.',
    identityRules({ label: 'AG Live', lang }),
    farmerPrivacyRule(lang),
    cropSpecialty(lang),
    crop,
    hi
      ? 'भाषा: सरल हिन्दी (किसान बोली)। दवा/खाद नाम अंग्रेज़ी में भी बोलो।'
      : 'Language: simple Hindi/English farmers understand. Say product names clearly.',
    'Prefer India units: 10 aari, 15 litre pump. Never invent an unapproved pesticide dose.',
    adviceClassRule(lang),
    medicineDistributorPromptRule(lang),
    medicineApiInject(lang),
    'Speak the full high-class answer. Do not stop after one light tip, and do not turn it into a long story.',
  ]
    .filter(Boolean)
    .join('\n');
}

function safetyId({ uid, email, ip }) {
  const raw = `${uid || ''}|${email || ''}|${ip || 'anon'}`;
  return createHash('sha256').update(raw).digest('hex').slice(0, 48);
}

async function resolvePlanId(uid) {
  return UserService.effectivePlanId(uid);
}

/**
 * Mint short-lived Realtime client secret for browser/mobile WebRTC.
 * Never returns the long-lived OPENAI_API_KEY.
 * High plans only (₹299+) — free/local cannot start AG Live.
 */
export const OpenAiRealtimeService = {
  isConfigured() {
    return Boolean(env.openaiApiKey && env.openaiApiKey.startsWith('sk-'));
  },

  async createClientSecret({
    lang = 'hi',
    cropId = null,
    uid = null,
    email = null,
    ip = null,
    planId = null,
  } = {}) {
    if (!this.isConfigured()) {
      const err = new Error('openai_not_configured');
      err.status = 503;
      throw err;
    }

    const effectivePlan = await resolvePlanId(uid);
    if (!planAllowsAdvanced(effectivePlan)) {
      const err = new Error('plan_required_for_live');
      err.status = 403;
      err.planId = effectivePlan;
      throw err;
    }

    const model = env.openaiRealtimeModel || 'gpt-realtime';
    const voice = env.openaiRealtimeVoice || 'alloy';
    const instructions = farmingInstructions({ lang, cropId });
    const headers = {
      Authorization: `Bearer ${env.openaiApiKey}`,
      'Content-Type': 'application/json',
      'OpenAI-Safety-Identifier': safetyId({ uid, email, ip }),
    };

    // GA path: /v1/realtime/client_secrets
    let res = await fetch('https://api.openai.com/v1/realtime/client_secrets', {
      method: 'POST',
      headers,
      body: JSON.stringify({
        session: {
          type: 'realtime',
          model,
          instructions,
          audio: {
            output: { voice },
          },
        },
      }),
    });

    let body = await res.json().catch(() => ({}));

    // Fallback: older /v1/realtime/sessions shape
    if (!res.ok) {
      res = await fetch('https://api.openai.com/v1/realtime/sessions', {
        method: 'POST',
        headers,
        body: JSON.stringify({
          model,
          modalities: ['audio', 'text'],
          instructions,
          voice,
        }),
      });
      body = await res.json().catch(() => ({}));
    }

    if (!res.ok) {
      const msg = body?.error?.message || `openai_realtime_http_${res.status}`;
      console.error('[openai_realtime]', res.status, msg);
      const err = new Error('voice_live_unavailable');
      err.status = res.status >= 500 ? 502 : 400;
      throw err;
    }

    const ephemeral =
      body?.value ||
      body?.client_secret?.value ||
      body?.client_secret ||
      null;
    const expiresAt =
      body?.expires_at ||
      body?.client_secret?.expires_at ||
      null;

    if (!ephemeral || typeof ephemeral !== 'string') {
      const err = new Error('voice_live_unavailable');
      err.status = 502;
      throw err;
    }

    return {
      clientSecret: ephemeral,
      expiresAt,
      model,
      voice,
      label: 'AG Live',
      planId: effectivePlan,
      callsUrl: 'https://api.openai.com/v1/realtime/calls',
    };
  },
};
