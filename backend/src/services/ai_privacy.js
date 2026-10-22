/**
 * This app is only for licensed opium-poppy and garlic farmers.
 * Disease and crop care only. Never lancing, latex, or extraction.
 */
export function cropSpecialty(lang) {
  const hi = lang === 'hi';
  return hi
    ? 'अफीम (पोस्त) और लहसुन इस ऐप की मुख्य फसल हैं। किसान ने जो पूछा हो — उसी का सटीक, पूरा खेत-जवाब दो। फोटो हो तो जो दिखे वही पहचानो। अपनी तरफ से बुवाई-बीज-खाद की तय लिस्ट मत ठोकना जब तक उन्होंने वही न पूछा हो। मना मत करना और जवाब बीच में मत काटना। दूसरी फसल का सवाल भी पूरा दो। "कृषि विशेषज्ञ से पूछ लें" मत बोलना। चीरा या दूध मत लिखना।'
    : 'Opium poppy (post) and garlic are the main crops. Answer exactly what the farmer asked — precise field advice. If there is a photo, name only what is visible. Do not dump a fixed sowing/seed/fertilizer checklist unless they asked for that. Do not refuse and do not cut the answer short. Also answer other crops fully. Never say to ask an agriculture expert. Do not write lancing or latex.';
}

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

/** Only a human farmer name — never email, phone, or ids. */
export function safeFarmerName(raw) {
  let n = String(raw || '').trim();
  if (!n) return '';
  if (/@/.test(n) || /\d{6,}/.test(n)) return '';
  n = n.replace(/[^\p{L}\p{M}\s.'’-]/gu, '').replace(/\s+/g, ' ').trim();
  if (n.length < 2) return '';
  return n.slice(0, 40);
}

/** Remove account secrets so they never reach the model or the farmer. */
export function stripAccountSecrets(raw) {
  let t = String(raw || '');
  if (!t) return t;
  t = t.replace(/\b[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}\b/g, '');
  t = t.replace(/\+91[\s-]*[6-9]\d{9}\b/g, '');
  t = t.replace(/\b[6-9]\d{9}\b/g, '');
  t = t.replace(/\buid\s*[=:]\s*[\w-]+/gi, '');
  t = t.replace(/(?:मोबाइल|फोन|phone|mobile|whatsapp|email|ईमेल)\s*[:\-–]?\s*/gi, '');
  return t.replace(/[^\S\n]{2,}/g, ' ').replace(/\n{3,}/g, '\n\n').trim();
}

/** GPT may use name + location + chat/course memory. Nothing else personal. */
export function farmerPrivacyRule(lang, farmerName = '') {
  const hi = lang === 'hi';
  const name = safeFarmerName(farmerName);
  return [
    name
      ? hi
        ? `किसान का नाम: ${name}। जरूरत हो तो नाम से बोलो।`
        : `Farmer name: ${name}. Use the name when it helps.`
      : '',
    hi
      ? 'तुम्हें सिर्फ ये निजी बातें मिल सकती हैं: किसान का नाम, खेत की जगह/मौसम, और नीचे दिया गया एक ही संदर्भ अक्ष। मोबाइल नंबर, ईमेल, यूज़र आईडी या और खाता जानकारी न तो माँगो, न लिखो, न मानो कि तुम्हारे पास है।'
      : 'You may only use: the farmer name, farm place/weather, and the one context axis below. Never ask for, write, or assume you have a mobile number, email, user id, or other account details.',
  ]
    .filter(Boolean)
    .join('\n');
}

/** One chat session XOR one crop course. Never mix users or threads. */
export function contextAxisRule(lang, { mode, threadId, sessionId, cropId } = {}) {
  const hi = lang === 'hi';
  const course = String(mode || '') === 'course';
  if (course) {
    const axis = String(cropId || threadId || 'course').slice(0, 48);
    return hi
      ? `संदर्भ अक्ष: सिर्फ इसी फसल कोर्स (${axis})। दूसरी चैट, दूसरा कोर्स, या दूसरे किसान की कोई बात न याद करो, न मिलाओ, न मानो।`
      : `Context axis: only this crop course (${axis}). Do not recall, mix, or assume any other chat, course, or farmer.`;
  }
  const axis = String(sessionId || threadId || 'chat').slice(0, 48);
  return hi
    ? `संदर्भ अक्ष: सिर्फ इसी चैट (${axis})। दूसरी चैट, कोई कोर्स, या दूसरे किसान की कोई बात न याद करो, न मिलाओ, न मानो।`
    : `Context axis: only this chat (${axis}). Do not recall, mix, or assume any other chat, course, or farmer.`;
}

export function useStoreCaption(lang) {
  return lang === 'hi'
    ? 'यह एक बार डिस्ट्रीब्यूटर या खाद-बीज भंडार से पूछकर ही उपयोग करें।'
    : 'Use this only after asking your distributor or a fertilizer-seed store.';
}

export function tenAariRule(lang) {
  const hi = lang === 'hi';
  return hi
    ? 'मात्रा तभी लिखो जब सवाल मात्रा, खाद, बीज, पानी, दवा या स्प्रे का हो। नाप सिर्फ 10 आरी। स्प्रे हो तो 10 आरी की कुल मात्रा और 15 लीटर पंप की मात्रा दोनों लिखो। मात्रा वाला सवाल न हो तो "10 आरी के हिसाब से" शीर्षक मत लगाओ और मात्रा मत गढ़ो। दवाई बताओ तो सिर्फ उसी दवाई के अपने तत्व लिखो। एक खाद-तत्व पूछा हो तो बाकी तत्वों की लंबी लिस्ट मत लगाओ। बीघा, एकड़ या हेक्टेयर मत लिखो। किसान दूसरी नाप पूछे तो पहले 10 आरी बताओ, फिर उसी से हिसाब लगाकर लिखो।'
    : 'Write a dose only when they ask about quantity, fertilizer, seed, water, medicine, or spray. Use only 10 aari. For spray, give the 10 aari total and the 15 litre pump dose. If the question is not about a dose, do not add a "For 10 aari" heading and do not invent a dose. When you name a medicine, list only that medicine’s own ingredients. If they asked one fertilizer nutrient, do not dump a long element list. Do not write doses per bigha, acre, or hectare. If they ask another area, first give 10 aari, then scale from that.';
}

export function topicPointsRule(lang) {
  const hi = lang === 'hi';
  return hi
    ? 'बीमारी, कीड़ा, धब्बा, पीलापन, सड़न, खाद, दवा या स्प्रे का संदेश हो तो जवाब उतने नंबर वाले टॉपिक में दो जितने उस सवाल से सच में जुड़ते हों। संख्या चार पर मत टिकाओ — दो भी हो सकते हैं, छह भी, जितने सही बनें। हर टॉपिक नई लाइन पर हो, बोल्ड शीर्षक हो और उसमें असली बात हो। जो बात लगे उसे अलग टॉपिक बनाओ, जैसे समझ, कौन सी दवाई बेहतर है, उस दवाई के तत्व, मात्रा और कैसे डालें, फायदा और नुकसान, और और क्या लगेगा। जो टॉपिक सवाल से न जुड़ता हो उसे मत लिखो। दवाई का नाम देवनागरी में और कोष्ठक में अंग्रेज़ी। चीरा या दूध मत लिखना। "विशेषज्ञ से पूछ लें" मत लिखना। हाँ, ना, एक नाम या एक समय जैसा सादा सवाल हो और दवा न बतानी हो तो टॉपिक मत लगाओ, सीधा वाक्य लिखो। एक ही सूची दो बार मत दो। आखिरी कैप्शन मत लिखना।'
    : 'If the message is about disease, pest, spots, yellowing, rot, fertilizer, medicine, or spray, answer in as many numbered topics as truly fit that question. Do not lock the count at four — two is fine, six is fine, however many are right. Each topic is its own line, with a bold title and a real fact. Split what belongs apart, such as the explanation, which medicine is better, that medicine’s ingredients, the dose and how to apply it, benefit and harm, and what else is needed. Skip a topic that does not fit the question. Write the medicine name in the local language, then English in brackets. Do not write lancing or latex. Do not say to ask an expert. For a plain yes, no, one name, or one time, with no medicine, do not use topics; write a direct sentence. Do not repeat the same list twice. Do not write the last caption.';
}

/** Every reply is high-class agronomy, not a light tip. */
export function adviceClassRule(lang) {
  const hi = lang === 'hi';
  return hi
    ? 'राय हमेशा उच्च स्तर की हो, हल्की या सामान्य टिप नहीं। जो दवा, खाद, पोषक तत्व, समय या तरीका बताओ वह खेत पर चलने लायक सटीक हो: सही नाम, 10 आरी की असली मात्रा, कब डालना है और कैसे डालना है। "थोड़ा खाद दो" या "पानी देते रहो" जैसी हल्की बात मत लिखो।'
    : 'Every reply must be high-class agronomy, not a light tip. Any medicine, fertilizer, nutrient, timing, or method must be precise enough to use in the field: the real name, the real 10 aari dose, when to apply it, and how. Do not write vague lines like "add some fertilizer" or "keep watering".';
}

/** Prompt rule: name the medicine, then benefits and harms. */
export function medicineDistributorPromptRule(lang) {
  const hi = lang === 'hi';
  return hi
    ? 'दवा, खाद, स्प्रे या पोषक तत्व तभी लिखो जब सवाल बीमारी, कीड़ा, फफूंद, पीलापन, खाद, दवा, स्प्रे या पोषण का हो। नाम देवनागरी में, फिर कोष्ठक में अंग्रेज़ी। ऐसी राय पर जितने मिलते-जुलते टॉपिक सही बनें उतने लिखो — समझ, बेहतर दवाई, उसके तत्व, मात्रा, फायदा-नुकसान, और क्या लगेगा। चार की गिनती जरूरी नहीं। तत्व सिर्फ उसी चुनी दवाई के लिखो। हल्की सामान्य बात मत लिखो। अनुमान मत गढ़ो। "कृषि विशेषज्ञ से पूछ लें" मत लिखो।'
    : 'Write a medicine, fertilizer, spray, or nutrient only when they asked about disease, pest, fungus, yellowing, fertilizer, medicine, spray, or nutrition. Write the name in the local language, then English in brackets. For that advice write as many related topics as fit — the explanation, the better medicine, its ingredients, the dose, benefit and harm, and what else is needed. A count of four is not required. Ingredients are only for the medicine you chose. Do not write a light generic line. Do not invent. Do not write "ask an agriculture expert".';
}

/** Force each GPT point onto its own line so the app can show 1, 2, 3. */
export function normalizeAnswerLayout(text) {
  let t = String(text || '');
  t = t.replace(/\\n/g, '\n').replace(/<br\s*\/?>/gi, '\n');
  t = t.replace(/[ \t]*(\*\*[^*]{1,40}\*\*)/g, '\n$1');
  t = t.replace(/(^|[ \t।])(\d{1,2}[.)])\s+(?=\S)/gm, '\n$2 ');
  t = t.replace(/(^|[ \t।])([-*•–])\s+(?=\S)/gm, '\n$2 ');
  t = t.replace(/\n{3,}/g, '\n\n').replace(/^\n+/, '').trim();
  return t;
}

export function medicineApiInject(lang) {
  return lang === 'hi'
    ? 'एपीआई नियम: बीमारी, कीड़ा, खाद या दवा के संदेश पर जितने मिलते-जुलते टॉपिक सही बनें उतने दो — समझ, बेहतर दवाई, उसके तत्व, मात्रा, फायदा-नुकसान, और क्या लगेगा। चार की गिनती जरूरी नहीं। जो टॉपिक न जुड़ता हो उसे छोड़ो। स्प्रे हो तो 15 लीटर पंप भी। सादा सवाल हो तो सीधा वाक्य। "विशेषज्ञ से पूछ लें" मत लिखो।'
    : 'API rule: a disease, pest, fertilizer, or medicine message gets as many related topics as fit — what it is, the better medicine, its ingredients, the dose, benefit and harm, and what else is needed. A count of four is not required. Skip a topic that does not fit. For spray, also give the 15 litre pump dose. A plain question stays one sentence. Do not write "ask an expert".';
}

export function localDistributorNote(lang) {
  return useStoreCaption(lang);
}

function looksLikeMedicineAdvice(text, dosageHighlight) {
  if (dosageHighlight && String(dosageHighlight).trim()) return true;
  const t = String(text || '').toLowerCase();
  return /दवा|दवाई|खाद|पोषक|यूरिया|डीएपी|dap|urea|स्प्रे|रोग|कीड़|कीटनाश|फंगी|fungicid|pesticide|insecticid|herbicide|छिड़क|मात्रा|ग्राम|मिली|बीघा|पंप|ridomil|मैंकोजेब|emamectin|acetamiprid/.test(
    t,
  ) || /आरी|aari/.test(t);
}

/** Last caption: ask distributor or fertilizer-seed store before use. */
export function ensureLocalDistributorNote(text, { lang = 'hi', dosageHighlight = null } = {}) {
  let raw = String(text || '').trim();
  if (!raw) return raw;
  raw = raw
    .replace(/⚠️?\s*अब एक बार जाइए और विशेषज्ञ से पूछ लें।?/g, '')
    .replace(/⚠️?\s*Now go once and ask an expert\.?/gi, '')
    .replace(/कृषि विशेषज्ञ से पूछ(?:ें|लें)।?/g, '')
    .replace(/यह एक बार डिस्ट्रीब्यूटर या खाद-बीज भंडार से पूछकर ही उपयोग करें।?/g, '')
    .replace(/Use this only after asking your distributor or a fertilizer-seed store\.?/gi, '')
    .replace(/\*\*उपयोग से पहले\*\*/g, '')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
  if (!looksLikeMedicineAdvice(raw, dosageHighlight)) return raw;
  return `${raw}\n\n**उपयोग से पहले**\n${useStoreCaption(lang)}`;
}

/** Strip leaked vendor/model wording from model text before sending to app. */
export function sanitizePublicText(raw, { label = 'AG Farmer', lang = 'hi' } = {}) {
  let t = stripAccountSecrets(raw);
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
    .replace(/[^\S\n]{2,}/g, ' ')
    .replace(/[^\S\n]+([,.!?])/g, '$1')
    .replace(/\n{3,}/g, '\n\n')
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
    .replace(/[^\S\n]{2,}/g, ' ')
    .trim();

  return t;
}

export function publicErrorText({ label, lang }) {
  return lang === 'hi'
    ? `${label} अभी व्यस्त है। थोड़ी देर बाद फिर कोशिश करें, या दूसरा AI चुनें।`
    : `${label} is busy right now. Try again shortly, or pick the other AI.`;
}
