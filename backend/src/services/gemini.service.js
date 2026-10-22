import { env } from '../config/env.js';
import { adviceClassRule, contextAxisRule, cropSpecialty, farmerPrivacyRule, identityRules, medicineApiInject, medicineDistributorPromptRule, normalizeAnswerLayout, stripAccountSecrets, tenAariRule, topicPointsRule } from './ai_privacy.js';
import { recordUpstreamFailure } from '../middleware/metrics.js';

/** AG High — farming advice (server Gemini family). */
function systemPrompt({ lang, cropId, mode, contextSummary, hasImage = false, farmContext = '', farmerName = '', threadId = '', sessionId = '' }) {
  const hi = lang === 'hi';
  const cropLine = cropId
    ? hi
      ? `यूज़र की सक्रिय फसल: ${cropId}. सिर्फ इसी फसल पर जवाब दो।`
      : `Active crop: ${cropId}. Answer only for this crop.`
    : hi
      ? 'कोई फसल चुनी न हो तो भी अफीम और लहसुन ही मानो।'
      : 'If no crop is selected, still answer for opium poppy and garlic.';

  const modeLine =
    mode === 'course'
      ? hi
        ? 'फसल कोर्स मोड — किसान ने जो पूछा उसी का चरणबद्ध, सटीक खेत-जवाब। तय FAQ/लिस्ट मत ठोकना।'
        : 'Course mode — answer exactly what they asked, stepwise and precise. Do not dump a fixed FAQ.'
      : hi
        ? 'चैट मोड — किसान ने जो पूछा उसी का सटीक, पूरा खेत-जवाब। फोटो हो तो जो दिखे वही। तय FAQ/लिस्ट मत ठोकना।'
        : 'Chat mode — answer exactly what they asked. If there is a photo, name only what is visible. Do not dump a fixed FAQ.';

  const deep = mode === 'deep';
  const memoryCap = mode === 'course' || mode === 'chat' ? 32000 : deep ? 800 : 500;
  const memory =
    contextSummary && String(contextSummary).trim()
      ? hi
        ? `पिछली बातचीत का सार (सिर्फ इसी किसान का): ${stripAccountSecrets(contextSummary).slice(0, memoryCap)}`
        : `Prior chat summary (this farmer only): ${stripAccountSecrets(contextSummary).slice(0, memoryCap)}`
      : '';

  return [
    hi
      ? 'तुम AG High हो — AG Farmer का उच्च स्तर का कृषि वैज्ञानिक। राय हल्की टिप नहीं, खेत पर चलने लायक सटीक सलाह हो।'
      : 'You are AG High — AG Farmer high-class agri-scientist. Advice is precise field practice, not a light tip.',
    identityRules({ label: 'AG High', lang }),
    farmerPrivacyRule(lang, farmerName),
    contextAxisRule(lang, { mode, threadId, sessionId, cropId }),
    cropSpecialty(lang),
    cropLine,
    modeLine,
    memory,
    hi
      ? 'बीमारी या कीड़े पर दवा का नाम, मात्रा और कैसे दें — पूरा लिखो। विशेषज्ञ वाली लाइन मत लिखना।'
      : 'For a disease or pest, write the medicine name, dose, and how to use it in full. Do not add an expert line.',
    hasImage
      ? hi
        ? 'यह असली खेत की फोटो है। जो साफ दिखे उसी की पहचान करो और उसी समस्या का इलाज लिखो। जो फोटो में न हो उसे मत गढ़ो।'
        : 'This is a real field photo. Name only what is clearly visible, and give treatment for that visible problem. Do not invent what is not in the photo.'
      : '',
    farmContext
      ? hi
        ? `किसान की ऐप अकाउंट लोकेशन और लाइव मौसम: ${String(farmContext).slice(0, 700)} सिंचाई, छिड़काव, बोआई, तापमान, बारिश या मौसम वाली बीमारी हो तभी इसे इस्तेमाल करो। बिना जरूरत जगह या मौसम मत लिखना। GPS नंबर मत लिखना।`
        : `Farmer account location and live weather: ${String(farmContext).slice(0, 700)} Use it only for irrigation, spray, sowing, temperature, rain, or weather-linked disease. Do not mention place or weather if not needed. Do not write GPS numbers.`
      : '',
    adviceClassRule(lang),
    medicineDistributorPromptRule(lang),
    tenAariRule(lang),
    topicPointsRule(lang),
    hi
      ? 'बीमारी, कीड़ा, खाद या दवा पर जितने मिलते-जुलते टॉपिक सही बनें उतने नंबर करो। चार की गिनती जरूरी नहीं। सादा सवाल बिना नंबर के लिखो। quickReplies हमेशा खाली रखो।'
      : 'For disease, pest, fertilizer, or medicine, number as many related topics as fit. A count of four is not required. A plain question has no numbers. quickReplies must be empty.',
    'Return ONLY valid JSON: text (string; plain sentences, or numbered points only when the question needs several facts), dosageHighlight (string|null), quickReplies (empty array).',
  ]
    .filter(Boolean)
    .join('\n');
}

function parseModelJson(content) {
  const raw = String(content || '').trim();
  try {
    return JSON.parse(raw);
  } catch (_) {
    const m = raw.match(/\{[\s\S]*\}/);
    if (m) {
      try {
        return JSON.parse(m[0]);
      } catch (_) {}
    }
  }
  return {
    text: raw || 'Sorry, I could not generate a reply.',
    dosageHighlight: null,
    quickReplies: [],
  };
}

export const GeminiService = {
  isConfigured() {
    const k = env.geminiApiKey;
    return Boolean(k && k.length > 20);
  },

  async chatComplete({
    message,
    lang = 'hi',
    cropId = null,
    mode = 'chat',
    history = [],
    model: modelOverride = null,
    images = null,
    imageBase64 = null,
    contextSummary = '',
    farmContext = '',
    farmerName = '',
    threadId = '',
    sessionId = '',
  }) {
    if (!this.isConfigured()) {
      throw Object.assign(new Error('gemini_not_configured'), { status: 503 });
    }

    const contents = [];
    // Same idea as OpenAI: chat is not stuck on a tiny 10-turn window.
    const histCap = mode === 'deep' ? 24 : mode === 'course' ? 400 : 200;
    const hist = Array.isArray(history) ? history.slice(-histCap) : [];
    for (const h of hist) {
      const text = stripAccountSecrets(h.text || h.content || '');
      if (!text) continue;
      const role =
        h.role === 'assistant' || h.role === 'bot' || h.role === 'model'
          ? 'model'
          : 'user';
      contents.push({ role, parts: [{ text }] });
    }

    const farmerText = String(message || '').trim();
    const userParts = [{ text: farmerText }];
    const imgList = [];
    if (imageBase64) imgList.push(imageBase64);
    if (Array.isArray(images)) imgList.push(...images);
    for (const raw of imgList.slice(0, 3)) {
      const s = String(raw || '');
      const m = s.match(/^data:(image\/[a-zA-Z0-9.+-]+);base64,(.+)$/);
      const mime = m ? m[1] : 'image/jpeg';
      const data = m ? m[2] : s.replace(/^data:.*,/, '');
      if (data.length < 40) continue;
      userParts.push({ inlineData: { mimeType: mime, data } });
    }
    const hasImage = userParts.length > 1;
    contents.push({ role: 'user', parts: userParts });

    // Safe fallback: when the quota service does not pass an explicit model,
    // default to the LOW-cost model (never the advanced one) so an unset env
    // var can never hand a free/low-tier user the strong model.
    const model =
      modelOverride ||
      env.geminiChatLowModel ||
      env.geminiModel ||
      'gemini-3.1-flash-lite';
    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent` +
      `?key=${encodeURIComponent(env.geminiApiKey)}`;

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), env.geminiTimeoutMs);

    let res;
    try {
      res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          systemInstruction: {
            parts: [{ text: `${systemPrompt({ lang, cropId, mode, contextSummary, hasImage, farmContext, farmerName, threadId, sessionId })}\n${medicineApiInject(lang)}` }],
          },
          contents,
          safetySettings: [
            { category: 'HARM_CATEGORY_HARASSMENT', threshold: 'BLOCK_ONLY_HIGH' },
            { category: 'HARM_CATEGORY_HATE_SPEECH', threshold: 'BLOCK_ONLY_HIGH' },
            { category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold: 'BLOCK_ONLY_HIGH' },
            { category: 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold: 'BLOCK_NONE' },
          ],
          generationConfig: {
            temperature: 0.35,
            maxOutputTokens: mode === 'deep' ? 2048 : 1024,
            responseMimeType: 'application/json',
            thinkingConfig: {
              thinkingBudget: mode === 'deep' ? 256 : 0,
            },
          },
        }),
        signal: controller.signal,
      });
    } catch (e) {
      clearTimeout(timer);
      if (e.name === 'AbortError') {
        recordUpstreamFailure('gemini', 'timeout');
        throw Object.assign(new Error('gemini_timeout'), { status: 504 });
      }
      recordUpstreamFailure('gemini', 'network');
      throw Object.assign(new Error('gemini_network'), { status: 502 });
    }
    clearTimeout(timer);

    const body = await res.json().catch(() => ({}));
    if (!res.ok) {
      const msg =
        body?.error?.message || body?.error?.status || `gemini_http_${res.status}`;
      recordUpstreamFailure('gemini', `http_${res.status}`);
      console.error('[gemini]', res.status, msg);
      throw Object.assign(new Error(msg), {
        status: res.status >= 500 ? 502 : 400,
      });
    }

    const content =
      body?.candidates?.[0]?.content?.parts?.map((p) => p.text || '').join('') ||
      '';
    const parsed = parseModelJson(content);
    const dosage =
      parsed.dosageHighlight == null || parsed.dosageHighlight === ''
        ? null
        : String(parsed.dosageHighlight);
    const text = normalizeAnswerLayout(String(parsed.text || parsed.reply || '').trim());
    const quickReplies = [];

    return {
      reply: text,
      text,
      dosageHighlight: dosage,
      quickReplies,
      meta: {
        source: 'gemini',
        model,
        label: 'AG High',
        cropId,
        mode,
      },
    };
  },
};
