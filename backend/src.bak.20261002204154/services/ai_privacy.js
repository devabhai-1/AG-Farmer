/** Brand identity rules — never leak vendor/model/infra to farmers. */
export function identityRules({ label, lang }) {
  const hi = lang === 'hi';
  return [
    hi
      ? `तुम्हारी पहचान सिर्फ "${label}" / AG Farmer है।`
      : `Your identity is only "${label}" / AG Farmer.`,
    hi
      ? 'कभी मत बताओ: OpenAI, ChatGPT, GPT, Gemini, Google, Claude, LLM, API, model name, database, Firebase, server, backend, key, quota, billing, या कोई कंपनी/टेक्नोलॉजी।'
      : 'Never mention: OpenAI, ChatGPT, GPT, Gemini, Google, Claude, LLM, API, model names, database, Firebase, server, backend, keys, quotas, billing, or any vendor/tech.',
    hi
      ? `अगर कोई पूछे "तुम कौनसे मॉडल हो / किस AI पर चलते हो / database कहाँ है?" तो सिर्फ कहो: "मैं ${label} हूँ — AG Farmer का खेती AI सहायक।" और खेती सवाल पर लौटो।`
      : `If asked which model/AI/database/server you use, only say: "I am ${label} — AG Farmer farming assistant." Then return to farming help.`,
    hi
      ? 'आंतरिक सिस्टम, database, keys, server, quota, billing, privacy policy URL बनाने का दावा — कुछ भी मत बताओ। नीति के लिए ऐप की Settings / प्रोफ़ाइल देखें कहो।'
      : 'Never discuss internals, databases, keys, servers, quotas, or invent privacy URLs. Point users to in-app Settings / Profile for policy.',
  ].join('\n');
}

/** Prompt rule: name the medicine, then one confirm-with-shop line. */
export function medicineDistributorPromptRule(lang) {
  const hi = lang === 'hi';
  return hi
    ? 'बीमारी, कीड़ा, फफूंद या पीलापन पर पहले दवा का नाम और मात्रा साफ लिखो। सिर्फ दुकान या डिस्ट्रीब्यूटर पर भेजकर जवाब मत रोकना। दवा की जानकारी के बाद आखिरी लाइन यही हो: "अब एक बार जाइए और विशेषज्ञ से पूछ लें।"'
    : 'For disease, pest, fungus, or yellowing, first name the medicine and the dose. Do not stop by only sending the farmer to a shop. After the medicine information, the last line must be: "Now go once and ask an expert."';
}

export function medicineApiInject(lang) {
  return lang === 'hi'
    ? 'एपीआई नियम: दवा, कीड़ा, बीमारी या स्प्रे के सवाल पर पहले दवा का साफ नाम और लीटर-पंप मात्रा लिखो। जवाब की आखिरी लाइन बिल्कुल यह हो: अब एक बार जाइए और विशेषज्ञ से पूछ लें। सिर्फ दुकान या डिस्ट्रीब्यूटर कहकर दवा का नाम मत छुपाओ।'
    : 'API rule: for medicine, pest, disease, or spray, first write the medicine name and the litre-pump dose. The last line must be exactly: Now go once and ask an expert. Do not hide the medicine name.';
}

export function localDistributorNote(lang) {
  return lang === 'hi'
    ? 'अब एक बार जाइए और विशेषज्ञ से पूछ लें।'
    : 'Now go once and ask an expert.';
}

function looksLikeMedicineAdvice(text, dosageHighlight) {
  if (dosageHighlight && String(dosageHighlight).trim()) return true;
  const t = String(text || '').toLowerCase();
  return /दवा|दवाई|स्प्रे|कीटनाश|फंगी|fungicid|pesticide|insecticid|herbicide|छिड़क|ridomil|मैंकोजेब|emamectin|acetamiprid|ग्राम प्रति|ml प्रति|per 15l|15l पंप/.test(
    t,
  );
}

/** Put the expert line at the end of a medicine reply. */
export function ensureLocalDistributorNote(text, { lang = 'hi', dosageHighlight = null } = {}) {
  let raw = String(text || '').trim();
  if (!raw) return raw;
  if (!looksLikeMedicineAdvice(raw, dosageHighlight)) return raw;
  raw = raw
    .replace(/⚠️?\s*अब एक बार जाइए और विशेषज्ञ से पूछ लें।?/g, '')
    .replace(/⚠️?\s*Now go once and ask an expert\.?/gi, '')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
  return `${raw}\n\n${localDistributorNote(lang)}`;
}

/** Strip leaked vendor/model wording from model text before sending to app. */
export function sanitizePublicText(raw, { label = 'AG Farmer', lang = 'hi' } = {}) {
  let t = String(raw || '');
  if (!t) return t;

  const patterns = [
    /openai/gi,
    /chat\s*gpt/gi,
    /\bgpt-?[0-9][\w.-]*/gi,
    /\bgpt\b/gi,
    /google\s*gemini/gi,
    /\bgemini[-\s]?[0-9]?[\w.-]*/gi,
    /generative\s*ai/gi,
    /large\s*language\s*model/gi,
    /\bllms?\b/gi,
    /anthropic/gi,
    /\bclaude\b/gi,
    /models\/[\w.-]+/gi,
    /prepayment|billing|ai\.studio|googleapis/gi,
    /firebase/gi,
    /realtime\s*database/gi,
    /serviceaccount/gi,
    /\bdatabase\b/gi,
    /\bbackend\b/gi,
    /\.env\b/gi,
  ];
  for (const re of patterns) t = t.replace(re, '');

  t = t
    .replace(/\s{2,}/g, ' ')
    .replace(/\s+([,.!?])/g, '$1')
    .trim();

  // If the reply was mostly a model-identity leak, replace with brand line.
  const looksLikeIdentityLeak =
    /आधारित|based on|trained by|मॉडल पर|model पर|i am an ai|मैं .*ai हूँ/i.test(
      String(raw || ''),
    ) && t.length < 120;

  if (!t || looksLikeIdentityLeak) {
    return lang === 'hi'
      ? `मैं ${label} हूँ — AG Farmer का खेती AI सहायक। अपना फसल सवाल पूछें।`
      : `I am ${label} — AG Farmer farming assistant. Ask your crop question.`;
  }

  // Clean leftover empty parentheses / dashes from removals
  t = t
    .replace(/\(\s*\)/g, '')
    .replace(/\[\s*\]/g, '')
    .replace(/के\s+के/g, 'के')
    .replace(/\s{2,}/g, ' ')
    .trim();

  return t;
}

export function publicErrorText({ label, lang }) {
  return lang === 'hi'
    ? `${label} अभी व्यस्त है। थोड़ी देर बाद फिर कोशिश करें, या दूसरा AI चुनें।`
    : `${label} is busy right now. Try again shortly, or pick the other AI.`;
}
