import { env } from '../config/env.js';

const ID_TOOLKIT = 'https://identitytoolkit.googleapis.com/v1';

function apiKey() {
  return env.firebase.apiKey;
}

async function post(path, body) {
  const res = await fetch(`${ID_TOOLKIT}/${path}?key=${encodeURIComponent(apiKey())}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(12000),
  });
  const json = await res.json().catch(() => ({}));
  return { ok: res.ok, status: res.status, json };
}

function mapFirebaseError(json) {
  const msg = String(json?.error?.message || '');
  if (msg.includes('EMAIL_EXISTS')) return 'email_in_use';
  if (msg.includes('EMAIL_NOT_FOUND')) return 'account_not_found';
  if (msg.includes('INVALID_PASSWORD') || msg.includes('INVALID_LOGIN_CREDENTIALS')) {
    return 'bad_credentials';
  }
  if (msg.includes('INVALID_EMAIL')) return 'invalid_email';
  if (msg.includes('WEAK_PASSWORD')) return 'weak_password';
  if (msg.includes('TOO_MANY_ATTEMPTS')) return 'too_many_requests';
  if (msg.includes('EXPIRED_OOB_CODE') || msg.includes('INVALID_OOB_CODE')) return 'reset_link_expired';
  if (msg.includes('OPERATION_NOT_ALLOWED')) return 'email_auth_disabled';
  if (msg.includes('USER_DISABLED')) return 'account_pending_deletion';
  return msg || 'firebase_auth_error';
}

/**
 * Firebase Identity Toolkit helpers — password reset emails are sent by Firebase
 * (no SMTP needed). Email/Password provider must be enabled in Firebase Console.
 */
export const FirebaseIdentity = {
  async signUp({ email, password, displayName }) {
    const { ok, json } = await post('accounts:signUp', {
      email,
      password,
      displayName: displayName || undefined,
      returnSecureToken: true,
    });
    if (!ok) {
      const code = mapFirebaseError(json);
      throw Object.assign(new Error(code), { status: code === 'email_in_use' ? 409 : 400, firebase: json });
    }
    return {
      localId: json.localId,
      email: json.email,
      idToken: json.idToken,
    };
  },

  async signIn({ email, password }) {
    const { ok, json } = await post('accounts:signInWithPassword', {
      email,
      password,
      returnSecureToken: true,
    });
    if (!ok) {
      const code = mapFirebaseError(json);
      throw Object.assign(new Error(code), {
        status: code === 'account_pending_deletion' ? 403 : 401,
        firebase: json,
      });
    }
    return {
      localId: json.localId,
      email: json.email,
      idToken: json.idToken,
    };
  },

  /** Firebase emails a password-reset link to the user (built-in templates). */
  async sendPasswordResetEmail(email) {
    const { ok, json } = await post('accounts:sendOobCode', {
      requestType: 'PASSWORD_RESET',
      email,
    });
    if (!ok) {
      const code = mapFirebaseError(json);
      throw Object.assign(new Error(code), {
        status: code === 'account_not_found' ? 404 : 400,
        firebase: json,
      });
    }
    return { sent: true, email: json.email || email };
  },

  /** Apply the code from our own reset page and set the new password. */
  async confirmPasswordReset({ oobCode, newPassword }) {
    const { ok, json } = await post('accounts:resetPassword', {
      oobCode,
      newPassword,
    });
    if (!ok) {
      const code = mapFirebaseError(json);
      throw Object.assign(new Error(code === 'firebase_auth_error' ? 'reset_link_expired' : code), {
        status: 400,
      });
    }
    return json.email || '';
  },

  /** Ensure Firebase Auth user exists so reset emails work (for older local accounts). */
  async ensureUser({ email, password, displayName }) {
    try {
      return await this.signUp({ email, password, displayName });
    } catch (e) {
      if (e.message === 'email_in_use') {
        return { localId: null, email, alreadyExists: true };
      }
      throw e;
    }
  },
};
