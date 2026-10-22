/**
 * Never leak internal infra (DB, Firebase, keys, vendors, stack) to the app.
 * Snake_case error codes stay for Flutter mapping (e.g. bad_credentials).
 */

const SAFE_CODES = new Set([
  'invalid_email',
  'weak_password',
  'accept_policy',
  'invalid_phone',
  'email_in_use',
  'bad_credentials',
  'account_not_found',
  'email_auth_disabled',
  'email_send_failed',
  'login_required',
  'file_too_large',
  'service_unavailable',
  'too_many_attempts_blocked_24h',
  'rate_limit_exceeded',
]);

const INTERNAL_RE =
  /firebase|realtime\s*database|serviceaccount|mongodb|postgres|sql|firestore|\.env|api[_\s-]?key|secret|stack|traceback|googleapis|ai\.studio|prepayment|billing|openai|gemini|gpt-|claude|anthropic|twilio|smtp|localhost|192\.168|serviceAccount|bucket|projectId|ECONNREFUSED|ENOENT|admin\.sdk/i;

const GENERIC = {
  hi: 'कुछ गलत हो गया। थोड़ी देर बाद फिर कोशिश करें।',
  en: 'Something went wrong. Please try again shortly.',
};

const UNAVAILABLE = {
  hi: 'सेवा अभी उपलब्ध नहीं है। थोड़ी देर बाद कोशिश करें।',
  en: 'Service is temporarily unavailable. Please try again shortly.',
};

export function toPublicErrorMessage(errOrMsg, { lang = 'hi' } = {}) {
  const raw = typeof errOrMsg === 'string' ? errOrMsg : errOrMsg?.message || '';
  const msg = String(raw || '').trim();
  if (!msg) return GENERIC[lang] || GENERIC.en;

  // Known app codes — keep for client switch/case
  if (msg === 'service_unavailable' || msg === 'firebase_auth_unavailable') {
    return UNAVAILABLE[lang] || UNAVAILABLE.en;
  }
  if (SAFE_CODES.has(msg) || /^[a-z][a-z0-9_.]{1,64}$/.test(msg)) {
    return msg;
  }

  // Short user-facing validation (no infra words)
  if (
    !INTERNAL_RE.test(msg) &&
    msg.length < 120 &&
    !msg.includes('\n') &&
    !/at\s+\S+\s+\(/.test(msg)
  ) {
    // Soften common auth phrases
    if (/unauthorized/i.test(msg)) return lang === 'hi' ? 'लॉगिन जरूरी है।' : 'Login required.';
    if (/not found/i.test(msg) && /user|crop|file|track/i.test(msg)) {
      return lang === 'hi' ? 'डेटा नहीं मिला।' : 'Not found.';
    }
    return msg;
  }

  if (/offline|not ready|not configured|timeout|network|503|502|504/i.test(msg)) {
    return UNAVAILABLE[lang] || UNAVAILABLE.en;
  }

  return GENERIC[lang] || GENERIC.en;
}

export function publicServiceUnavailable(lang = 'hi') {
  return UNAVAILABLE[lang] || UNAVAILABLE.en;
}
