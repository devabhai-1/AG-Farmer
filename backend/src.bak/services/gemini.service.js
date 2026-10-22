import { env } from '../config/env.js';
import { identityRules, medicineApiInject, medicineDistributorPromptRule } from './ai_privacy.js';

/** AG High — farming advice (server Gemini family). */
function systemPrompt({ lang, cropId, mode, contextSummary }) {
  const hi = lang === 'hi';
  const cropLine = cropId
    ? hi
      ? `यूज़र की सक्रिय फसल: ${cropId}. सिर्फ इसी फसल पर जवाब दो।`
      : `Active crop: ${cropId}. Answer only for this crop.`
    : hi
      ? 'सामान्य भारतीय खेती सलाह।'
      : 'General Indian farming advice.';

  const modeLine =
    mode === 'course'
      ? hi
        ? 'फसल कोर्स मोड — अगला प्रैक्टिकल स्टेप बताओ।'
        : 'Course mode — give the next practical step.'
      : hi
        ? 'AG High मोड — तेज़, साफ़ खेती सलाह।'
        : 'AG High mode — clear farming advice.';

  const deep = mode === 'deep';
  const memoryCap = mode === 'course' ? 1200 : deep ? 800 : 500;
  const memory =
    contextSummary && String(contextSummary).trim()
      ? hi
        ? `पिछली बातचीत का सार (सिर्फ इसी किसान का): ${String(contextSummary).slice(0, memoryCap)}`
        : `Prior chat summary (this farmer only): ${String(contextSummary).slice(0, memoryCap)}`
      : '';

  return [
    hi
      ? 'तुम AG High हो — AG Farmer का तेज़ कृषि AI। साफ़ व काम की सलाह दो।'
      : 'You are AG High — AG Farmer agri AI. Give clear actionable advice.',
    identityRules({ label: 'AG High', lang }),
    cropLine,
    modeLine,
    memory,
    hi
      ? 'चैट: बीमारी या कीड़े पर पहले दवा का नाम, मात्रा और कैसे दें — यह लिखो। आखिरी लाइन अलग से यही हो: अब एक बार जाइए और विशेषज्ञ से पूछ लें। शुरुआत में सिर्फ दुकान या विशेषज्ञ मत लिखना।'
      : 'Chat: for a disease or pest, first write the medicine name, dose, and how to use it. The last line must be: Now go once and ask an expert. Do not start by only sending them to a shop.',
    deep
      ? hi
        ? 'डीप रिसर्च: अधिकतम 140 शब्द। वजह, सटीक मात्रा, 1 सावधानी। लंबा परिचय मत लिखो।'
        : 'Deep research: max 140 words. Cause, exact dose, one caution. No long intro.'
      : mode === 'course'
        ? hi
          ? 'कोर्स: अधिकतम 90 शब्द। सिर्फ अगला काम और मात्रा।'
          : 'Course: max 90 words. Next step and dose only.'
        : hi
          ? 'सामान्य चैट: अधिकतम 70 शब्द। पहले सीधा जवाब, फिर 1 मात्रा अगर ज़रूरी हो। छोटा और साफ़।'
          : 'Normal chat: max 70 words. Direct answer first, then one dose if needed. Short and clear.',
    medicineDistributorPromptRule(lang),
    hi
      ? 'नाप बीघा और लीटर पंप में दो। जो समस्या पूछी है उसी की दवा बताओ। quickReplies हमेशा खाली रखो।'
      : 'Use bigha and litre-pump units. Name the medicine for the problem they asked. quickReplies must be empty.',
    'Return ONLY valid JSON: text (string), dosageHighlight (string|null), quickReplies (empty array).',
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
  }) {
    if (!this.isConfigured()) {
      throw Object.assign(new Error('gemini_not_configured'), { status: 503 });
    }

    const contents = [];
    const histCap = mode === 'deep' ? 12 : mode === 'course' ? 16 : 8;
    const hist = Array.isArray(history) ? history.slice(-histCap) : [];
    for (const h of hist) {
      const text = String(h.text || h.content || '').trim();
      if (!text) continue;
      const role =
        h.role === 'assistant' || h.role === 'bot' || h.role === 'model'
          ? 'model'
          : 'user';
      contents.push({ role, parts: [{ text }] });
    }

    const userParts = [{ text: String(message || '').trim() }];
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
    contents.push({ role: 'user', parts: userParts });

    const model =
      modelOverride ||
      env.geminiChatAdvancedModel ||
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
            parts: [{ text: `${systemPrompt({ lang, cropId, mode, contextSummary })}\n${medicineApiInject(lang)}` }],
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
        throw Object.assign(new Error('gemini_timeout'), { status: 504 });
      }
      throw Object.assign(new Error('gemini_network'), { status: 502 });
    }
    clearTimeout(timer);

    const body = await res.json().catch(() => ({}));
    if (!res.ok) {
      const msg =
        body?.error?.message || body?.error?.status || `gemini_http_${res.status}`;
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
    const text = String(parsed.text || parsed.reply || '').trim();
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
