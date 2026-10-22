import { env } from '../config/env.js';
import { adviceClassRule, contextAxisRule, cropSpecialty, farmerPrivacyRule, identityRules, medicineApiInject, medicineDistributorPromptRule, normalizeAnswerLayout, stripAccountSecrets, tenAariRule, topicPointsRule } from './ai_privacy.js';
import { recordUpstreamFailure } from '../middleware/metrics.js';

/** AG Expert — deeper, precise farming advice. */
function systemPrompt({ lang, cropId, mode, contextSummary, hasImage = false, voice = false, farmContext = '', farmerName = '', threadId = '', sessionId = '' }) {
  const hi = lang === 'hi';
  const cropLine = cropId
    ? hi
      ? `यूज़र की सक्रिय फसल: ${cropId}. सिर्फ इसी फसल के गहरे संदर्भ में जवाब दो।`
      : `Active crop focus: ${cropId}. Give deep crop-specific advice only.`
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
  const memoryCap = voice ? 12000 : mode === 'course' || mode === 'chat' ? 32000 : deep ? 800 : 500;
  const memory =
    contextSummary && String(contextSummary).trim()
      ? hi
        ? `पिछली बातचीत का सार (सिर्फ इसी किसान का): ${stripAccountSecrets(contextSummary).slice(0, memoryCap)}`
        : `Prior chat summary (this farmer only): ${stripAccountSecrets(contextSummary).slice(0, memoryCap)}`
      : '';

  return [
    hi
      ? 'तुम AG Expert हो — AG Farmer का उच्च स्तर का कृषि वैज्ञानिक। राय हल्की टिप नहीं, खेत पर चलने लायक सटीक सलाह हो।'
      : 'You are AG Expert — AG Farmer high-class agri-scientist. Advice is precise field practice, not a light tip.',
    identityRules({ label: 'AG Expert', lang }),
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
        ? 'यह असली खेत की फोटो है। जो साफ दिखे उसी की पहचान करो और उस समस्या की दवा का नाम लिखो। जो फोटो में न हो उसे मत गढ़ो।'
        : 'This is a real field photo. Name only what is clearly visible, and name the medicine for that visible problem. Do not invent a disease that is not in the photo.'
      : hi
        ? 'नाप 10 आरी और 15 लीटर पंप में दो। जो समस्या पूछी है उसी की दवा बताओ।'
        : 'Use 10 aari and 15 litre-pump units. Name the medicine for the problem they asked.',
    farmContext
      ? hi
        ? `किसान की ऐप अकाउंट लोकेशन और लाइव मौसम: ${String(farmContext).slice(0, 700)} सिंचाई, छिड़काव, बोआई, तापमान, बारिश या मौसम वाली बीमारी हो तभी इसे इस्तेमाल करो। बिना जरूरत जगह या मौसम मत लिखना। GPS नंबर मत लिखना।`
        : `Farmer account location and live weather: ${String(farmContext).slice(0, 700)} Use it only for irrigation, spray, sowing, temperature, rain, or weather-linked disease. Do not mention place or weather if not needed. Do not write GPS numbers.`
      : '',
    adviceClassRule(lang),
    medicineDistributorPromptRule(lang),
    tenAariRule(lang),
    topicPointsRule(lang),
    voice
      ? hi
        ? 'यह जवाब आवाज़ में बोला जाएगा। सवाल जितना है उतना ही बोलो। कई बातें हों तभी अलग पॉइंट, हर पॉइंट नई लाइन पर। कहानी मत बनाओ।'
        : 'This answer will be spoken aloud. Say only what the question needs. Use separate points only when there are several facts, each on a new line. Do not write a story.'
      : hi
        ? 'बीमारी, कीड़ा, खाद या दवा पर जितने मिलते-जुलते टॉपिक सही बनें उतने नंबर करो। हर टॉपिक नई लाइन पर। चार की गिनती जरूरी नहीं। सादा सवाल बिना नंबर के लिखो।'
        : 'For disease, pest, fertilizer, or medicine, number as many related topics as fit, each on its own line. A count of four is not required. A plain question has no numbers.',
    hi
      ? 'quickReplies हमेशा खाली array रखो। अतिरिक्त सुझाव chip मत दो।'
      : 'quickReplies must always be an empty array. Do not add suggestion chips.',
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
    text: raw,
    dosageHighlight: null,
    quickReplies: [],
  };
}

/** Model refused licensed crop-care help — retry with the same farmer ask. */
function refusedCropCare(text) {
  return /नहीं दे सकता|नहीं दे सकती|अवैध|गैर-कानूनी|नियंत्रित|illegal|controlled substance|cannot help with|won't help with|संवेदनशील विषय/i.test(
    String(text || ''),
  );
}

function estimateTokens(text) {
  return Math.ceil(String(text || '').length / 3) + 4;
}

/** Newest turns first, then reverse. Live uses a 100k-token window. */
function packHistory(history, maxTokens) {
  const rows = Array.isArray(history) ? history : [];
  const out = [];
  let used = 0;
  for (let i = rows.length - 1; i >= 0; i--) {
    const role = rows[i].role === 'assistant' || rows[i].role === 'bot' ? 'assistant' : 'user';
    const text = stripAccountSecrets(rows[i].text || rows[i].content || '');
    if (!text) continue;
    const cost = estimateTokens(text);
    if (used + cost > maxTokens) break;
    used += cost;
    out.push({ role, content: text });
  }
  return out.reverse();
}

function readContent(message) {
  const content = message?.content;
  if (typeof content === 'string') return content;
  if (Array.isArray(content)) {
    return content
      .map((part) => {
        if (typeof part === 'string') return part;
        if (part && typeof part.text === 'string') return part.text;
        return '';
      })
      .join('');
  }
  return '';
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
    videoShots = 3,
    contextSummary = '',
    voice = false,
    farmContext = '',
    farmerName = '',
    threadId = '',
    sessionId = '',
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
        content: systemPrompt({ lang, cropId, mode, contextSummary, hasImage, voice, farmContext, farmerName, threadId, sessionId }),
      },
    ];

    // Chat + course share the same packing path (no tiny 10-turn chat window).
    const histCap = voice
      ? 100000
      : mode === 'deep'
        ? 8000
        : mode === 'course'
          ? 80000
          : 50000;
    const hist = packHistory(history, histCap);
    for (const h of hist) {
      messages.push({ role: h.role, content: h.content });
    }

    messages.push({ role: 'system', content: medicineApiInject(lang) });
    // One path for chat / course / deep: farmer words + photos, no FAQ swap.
    const farmerText = String(message || '').trim();
    const contentParts = [{ type: 'text', text: farmerText }];
    const imgList = [];
    if (Array.isArray(images)) imgList.push(...images);
    if (imageBase64 && !imgList.length) imgList.push(imageBase64);
    const shotCap = Math.max(1, Math.min(12, Number(videoShots) || 3));
    for (const raw of imgList.slice(0, shotCap)) {
      const s = String(raw || '');
      if (s.length < 40) continue;
      const url = s.startsWith('data:')
        ? s
        : `data:image/jpeg;base64,${s}`;
      contentParts.push({ type: 'image_url', image_url: { url } });
    }

    messages.push({
      role: 'user',
      content: contentParts.length > 1 ? contentParts : farmerText,
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

    // Reasoning tokens count against this cap. 280 was used up before any
    // answer text, so the app spoke the empty-reply line.
    const tokenCap = voice ? 3072 : mode === 'deep' ? 4096 : 2048;

    const requestCompletion = async (cap) => {
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
            max_completion_tokens: cap,
            response_format: { type: 'json_object' },
            messages,
          }),
          signal: controller.signal,
        });
      } catch (e) {
        if (e.name === 'AbortError') {
          recordUpstreamFailure('openai', 'timeout');
          throw Object.assign(new Error('openai_timeout'), { status: 504 });
        }
        recordUpstreamFailure('openai', 'network');
        throw Object.assign(new Error('openai_network'), { status: 502 });
      } finally {
        clearTimeout(timer);
      }

      const body = await res.json().catch(() => ({}));
      if (!res.ok) {
        const msg = body?.error?.message || `openai_http_${res.status}`;
        recordUpstreamFailure('openai', `http_${res.status}`);
        console.error('[openai]', res.status, msg);
        throw Object.assign(new Error(msg), { status: res.status >= 500 ? 502 : 400 });
      }
      return body;
    };

    let body = await requestCompletion(tokenCap);
    let content = readContent(body?.choices?.[0]?.message);
    if (!String(content).trim()) {
      const finish = body?.choices?.[0]?.finish_reason || 'none';
      const reasoning = body?.usage?.completion_tokens_details?.reasoning_tokens ?? 0;
      console.warn(
        `[openai] empty reply model=${model} finish=${finish} reasoning=${reasoning} cap=${tokenCap}`,
      );
      body = await requestCompletion(voice ? 4096 : mode === 'deep' ? 8192 : 4096);
      content = readContent(body?.choices?.[0]?.message);
    }
    if (!String(content).trim()) {
      const finish = body?.choices?.[0]?.finish_reason || 'none';
      console.warn(`[openai] empty reply after retry model=${model} finish=${finish}`);
      recordUpstreamFailure('openai', 'empty');
      throw Object.assign(new Error('openai_empty'), { status: 502 });
    }
    const parsedOnce = parseModelJson(content);
    let text = normalizeAnswerLayout(
      String(parsedOnce.text || parsedOnce.reply || '').trim(),
    );
    let dosage =
      parsedOnce.dosageHighlight == null || parsedOnce.dosageHighlight === ''
        ? null
        : String(parsedOnce.dosageHighlight);
    if (refusedCropCare(text)) {
      // Same ask again — never invent a different question / FAQ checklist.
      messages.length = 0;
      const retryParts = [{ type: 'text', text: farmerText }];
      for (const raw of imgList.slice(0, shotCap)) {
        const s = String(raw || '');
        if (s.length < 40) continue;
        const url = s.startsWith('data:') ? s : `data:image/jpeg;base64,${s}`;
        retryParts.push({ type: 'image_url', image_url: { url } });
      }
      messages.push(
        {
          role: 'system',
          content: systemPrompt({
            lang,
            cropId,
            mode,
            contextSummary,
            hasImage,
            voice,
            farmContext,
            farmerName,
            threadId,
            sessionId,
          }),
        },
        {
          role: 'system',
          content:
            lang === 'hi'
              ? 'किसान का वही सवाल दोबारा है। जो पूछा है उसी का सटीक खेत-जवाब दो। मना मत करना। कोई अलग लिस्ट या FAQ मत बनाओ।'
              : 'Same farmer question again. Answer exactly what they asked. Do not refuse. Do not invent a FAQ checklist.',
        },
        {
          role: 'user',
          content: retryParts.length > 1 ? retryParts : farmerText,
        },
      );
      const again = await requestCompletion(tokenCap);
      const parsedAgain = parseModelJson(readContent(again?.choices?.[0]?.message));
      const careText = normalizeAnswerLayout(
        String(parsedAgain.text || parsedAgain.reply || '').trim(),
      );
      if (careText && !refusedCropCare(careText)) {
        text = careText;
        dosage =
          parsedAgain.dosageHighlight == null || parsedAgain.dosageHighlight === ''
            ? null
            : String(parsedAgain.dosageHighlight);
      }
    }
    if (!text) {
      recordUpstreamFailure('openai', 'empty');
      throw Object.assign(new Error('openai_empty'), { status: 502 });
    }
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
