import { env } from '../config/env.js';
import { identityRules, medicineApiInject, medicineDistributorPromptRule } from './ai_privacy.js';

/** AG Expert — deeper, precise farming advice. */
function systemPrompt({ lang, cropId, mode, contextSummary, hasImage = false }) {
  const hi = lang === 'hi';
  const cropLine = cropId
    ? hi
      ? `यूज़र की सक्रिय फसल: ${cropId}. सिर्फ इसी फसल के गहरे संदर्भ में जवाब दो।`
      : `Active crop focus: ${cropId}. Give deep crop-specific advice only.`
    : hi
      ? 'भारतीय खेती पर एक्सपर्ट स्तर की सलाह दो।'
      : 'Give expert-level Indian farming advice.';

  const modeLine =
    mode === 'course'
      ? hi
        ? 'फसल कोर्स मोड — चरणबद्ध, सही मात्रा व समय के साथ एक्सपर्ट गाइड।'
        : 'Course mode — stepwise expert guide with correct dose and timing.'
      : hi
        ? 'AG Expert मोड — प्रीमियम, सटीक खेती सलाह।'
        : 'AG Expert mode — premium precise farming advice.';

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
      ? 'तुम AG Expert हो — AG Farmer का प्रीमियम कृषि वैज्ञानिक AI। बेहतर, गहरी और भरोसेमंद सलाह दो।'
      : 'You are AG Expert — AG Farmer premium agri-scientist AI. Give better, deeper, trustworthy advice.',
    identityRules({ label: 'AG Expert', lang }),
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
    hasImage
      ? hi
        ? 'यह असली खेत की फोटो है। जो साफ दिखे उसी की पहचान करो और उस समस्या की दवा का नाम लिखो। जो फोटो में न हो उसे मत गढ़ो।'
        : 'This is a real field photo. Name only what is clearly visible, and name the medicine for that visible problem. Do not invent a disease that is not in the photo.'
      : hi
        ? 'नाप बीघा और लीटर पंप में दो। जो समस्या पूछी है उसी की दवा बताओ।'
        : 'Use bigha and litre-pump units. Name the medicine for the problem they asked.',
    medicineDistributorPromptRule(lang),
    hi
      ? 'quickReplies हमेशा खाली array रखो। अतिरिक्त सुझाव chip मत दो।'
      : 'quickReplies must always be an empty array. Do not add suggestion chips.',
    'Return ONLY valid JSON: text (string, markdown ok), dosageHighlight (string|null), quickReplies (empty array).',
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

export const OpenAiService = {
  isConfigured() {
    return Boolean(env.openaiApiKey && env.openaiApiKey.startsWith('sk-'));
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
      const err = new Error('openai_not_configured');
      err.status = 503;
      throw err;
    }

    const hasImage =
      (imageBase64 && String(imageBase64).length > 40) ||
      (Array.isArray(images) &&
        images.some((item) => String(item || '').length > 40));

    const messages = [
      {
        role: 'system',
        content: systemPrompt({ lang, cropId, mode, contextSummary, hasImage }),
      },
    ];

    const histCap = mode === 'deep' ? 12 : mode === 'course' ? 16 : 8;
    const hist = Array.isArray(history) ? history.slice(-histCap) : [];
    for (const h of hist) {
      const role = h.role === 'assistant' || h.role === 'bot' ? 'assistant' : 'user';
      const text = String(h.text || h.content || '').trim();
      if (!text) continue;
      messages.push({ role, content: text });
    }

    messages.push({ role: 'system', content: medicineApiInject(lang) });

    const contentParts = [{ type: 'text', text: String(message || '').trim() }];
    const imgList = [];
    if (imageBase64) imgList.push(imageBase64);
    if (Array.isArray(images)) imgList.push(...images);
    for (const raw of imgList.slice(0, 3)) {
      const s = String(raw || '');
      if (s.length < 40) continue;
      const url = s.startsWith('data:')
        ? s
        : `data:image/jpeg;base64,${s}`;
      contentParts.push({ type: 'image_url', image_url: { url } });
    }

    messages.push({
      role: 'user',
      content: contentParts.length > 1 ? contentParts : String(message || '').trim(),
    });

    const model =
      modelOverride ||
      env.openaiChatLowModel ||
      env.openaiModel ||
      'gpt-5-nano';
    const reasoningFamily = /^gpt-(5|6)/.test(model);
    const reasoningEffort = /gpt-6-luna|gpt-5\.4-mini|gpt-5\.6-luna/.test(model)
      ? 'none'
      : /gpt-6-(sol|astra)|gpt-5\.6-(sol|terra)/.test(model)
        ? 'low'
        : 'minimal';

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), env.openaiTimeoutMs);

    let res;
    try {
      res = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${env.openaiApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model,
          ...(reasoningFamily
            ? { reasoning_effort: reasoningEffort }
            : { temperature: 0.3 }),
          max_completion_tokens: mode === 'deep' ? 500 : 280,
          response_format: { type: 'json_object' },
          messages,
        }),
        signal: controller.signal,
      });
    } catch (e) {
      clearTimeout(timer);
      if (e.name === 'AbortError') {
        throw Object.assign(new Error('openai_timeout'), { status: 504 });
      }
      throw Object.assign(new Error('openai_network'), { status: 502 });
    }
    clearTimeout(timer);

    const body = await res.json().catch(() => ({}));
    if (!res.ok) {
      const msg = body?.error?.message || `openai_http_${res.status}`;
      console.error('[openai]', res.status, msg);
      throw Object.assign(new Error(msg), { status: res.status >= 500 ? 502 : 400 });
    }

    const content = body?.choices?.[0]?.message?.content || '';
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
        source: 'openai',
        model,
        label: 'AG Expert',
        cropId,
        mode,
      },
    };
  },
};
