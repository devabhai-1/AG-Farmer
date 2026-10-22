import { toPublicErrorMessage } from '../services/public_errors.js';

const SAFE_HTTP200 = new Set([
  'invalid_email',
  'weak_password',
  'accept_policy',
  'invalid_phone',
  'email_in_use',
  'account_pending_deletion',
  'bad_credentials',
  'account_not_found',
  'email_auth_disabled',
  'email_send_failed',
  'reset_link_expired',
  'login_required',
  'file_too_large',
  'otp_expired',
  'invalid_otp',
  'no_phone_on_account',
]);

export function ok(res, data = {}, status = 200) {
  return res.status(status).json({ ok: true, ...data });
}

export function fail(res, status, message, extra = {}) {
  const safe = toPublicErrorMessage(message, {
    lang: extra.lang === 'en' ? 'en' : 'hi',
  });
  const { lang: _lang, ...rest } = extra;
  // Expected app/business codes (email_in_use, bad_credentials, …) stay
  // HTTP 200 so browsers don't log "Failed to load resource: 409".
  // Clients already treat { ok: false } as an error.
  // Transport-level statuses keep their real code so proxies, monitors and
  // the app's retry logic can tell them apart from business errors.
  const keepReal = status === 404 || status === 405 || status === 413 || status === 429;
  const httpStatus =
    !keepReal &&
    typeof status === 'number' &&
    status >= 400 &&
    status < 500 &&
    typeof safe === 'string' &&
    (SAFE_HTTP200.has(safe) || /^[a-z][a-z0-9_.]{1,64}$/.test(safe))
      ? 200
      : status;
  return res.status(httpStatus).json({
    ok: false,
    error: safe,
    ...rest,
  });
}

export function asyncHandler(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
}
