import crypto from 'crypto';
import { env } from '../config/env.js';
import { isFirebaseReady, rootRef } from '../config/firebase.js';
import { AuthPhoneService } from './auth.service.js';
import { signAppToken } from './jwt.service.js';

/** In-memory OTP store (single server). Key = phone E.164 */
const otpStore = new Map();

function randomOtp() {
  return String(crypto.randomInt(100000, 999999));
}

function requestIdFor(phone) {
  return crypto.createHash('sha256').update(`otp:${phone}:${Date.now()}`).digest('hex').slice(0, 24);
}

async function sendSms(phone, otp) {
  const provider = env.smsProvider;
  const text = `AG Farmer OTP: ${otp}. Valid ${env.otpTtlSec / 60} min. Do not share.`;

  if (provider === 'msg91' && env.msg91AuthKey) {
    const url = new URL('https://control.msg91.com/api/v5/flow/');
    // Simple SMS API fallback
    const qs = new URLSearchParams({
      authkey: env.msg91AuthKey,
      mobiles: phone.replace('+', ''),
      message: text,
      sender: env.msg91Sender,
      route: '4',
    });
    const res = await fetch(`https://api.msg91.com/api/sendhttp.php?${qs}`);
    const body = await res.text();
    if (!res.ok) throw new Error(`SMS failed: ${body}`);
    return { provider: 'msg91', ref: body };
  }

  if (provider === 'twilio' && env.twilioAccountSid && env.twilioAuthToken) {
    const from = env.twilioFrom;
    const authHeader = Buffer.from(`${env.twilioAccountSid}:${env.twilioAuthToken}`).toString('base64');
    const res = await fetch(
      `https://api.twilio.com/2010-04-01/Accounts/${env.twilioAccountSid}/Messages.json`,
      {
        method: 'POST',
        headers: {
          Authorization: `Basic ${authHeader}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({ To: phone, From: from, Body: text }),
      },
    );
    const json = await res.json();
    if (!res.ok) throw new Error(json.message || 'Twilio SMS failed');
    return { provider: 'twilio', ref: json.sid };
  }

  // Default: log only (wire MSG91/Twilio in .env for real SMS)
  console.log(`[otp] ${phone} → ${otp}`);
  return { provider: 'log', ref: 'console' };
}

function phoneUid(phone) {
  return `p_${crypto.createHash('sha256').update(phone).digest('hex').slice(0, 28)}`;
}

export const OtpAuthService = {
  async send({ phone: phoneRaw }) {
    if (!env.phoneAuthEnabled) throw Object.assign(new Error('Phone auth disabled'), { status: 403 });
    const phone = AuthPhoneService.normalizePhone(phoneRaw);
    if (!phone) throw Object.assign(new Error('Invalid phone. Use 10-digit or +91…'), { status: 400 });

    const prev = otpStore.get(phone);
    const now = Date.now();
    if (prev?.sentAt && now - prev.sentAt < env.otpResendSec * 1000) {
      const wait = Math.ceil((env.otpResendSec * 1000 - (now - prev.sentAt)) / 1000);
      throw Object.assign(new Error(`Wait ${wait}s before resend`), { status: 429 });
    }

    const otp = randomOtp();
    const requestId = requestIdFor(phone);
    const expiresAt = now + env.otpTtlSec * 1000;
    const hash = crypto.createHash('sha256').update(`${otp}:${phone}:${env.jwtSecret}`).digest('hex');

    otpStore.set(phone, {
      hash,
      requestId,
      expiresAt,
      sentAt: now,
      attempts: 0,
    });

    const sms = await sendSms(phone, otp);

    const out = {
      ok: true,
      requestId,
      phone,
      expiresInSec: env.otpTtlSec,
      channel: 'sms',
      smsProvider: sms.provider,
    };
    // When SMS is not wired (log mode), return OTP so app/debug can show it
    if (sms.provider === 'log') {
      out.debugOtp = otp;
    }
    return out;
  },

  async verify({ phone: phoneRaw, otp, requestId, name = '' }) {
    if (!env.phoneAuthEnabled) throw Object.assign(new Error('Phone auth disabled'), { status: 403 });
    const phone = AuthPhoneService.normalizePhone(phoneRaw);
    if (!phone) throw Object.assign(new Error('Invalid phone'), { status: 400 });
    const code = String(otp || '').trim();
    if (!/^\d{6}$/.test(code)) throw Object.assign(new Error('OTP must be 6 digits'), { status: 400 });

    const row = otpStore.get(phone);
    if (!row) throw Object.assign(new Error('OTP expired or not sent'), { status: 400 });
    if (requestId && row.requestId !== requestId) {
      throw Object.assign(new Error('Invalid OTP session'), { status: 400 });
    }
    if (Date.now() > row.expiresAt) {
      otpStore.delete(phone);
      throw Object.assign(new Error('OTP expired'), { status: 400 });
    }
    if (row.attempts >= 5) {
      otpStore.delete(phone);
      throw Object.assign(new Error('Too many attempts'), { status: 429 });
    }

    const hash = crypto.createHash('sha256').update(`${code}:${phone}:${env.jwtSecret}`).digest('hex');
    row.attempts += 1;
    if (hash !== row.hash) {
      otpStore.set(phone, row);
      throw Object.assign(new Error('Invalid OTP'), { status: 401 });
    }
    otpStore.delete(phone);

    let uid;
    let displayName = name || '';
    let profile = null;

    if (isFirebaseReady()) {
      const ensured = await AuthPhoneService.ensurePhoneUser(phone, { name: displayName });
      uid = ensured.uid;
      displayName = ensured.name || displayName;
      profile = ensured.profile;
    } else {
      uid = phoneUid(phone);
      displayName = displayName || 'किसान साथी';
      profile = {
        uid,
        name: displayName,
        phone,
        email: '',
        provider: 'phone',
        profileComplete: Boolean(displayName),
      };
      // Best-effort RTDB when admin later available
      try {
        if (isFirebaseReady()) {
          await rootRef(`users/${uid}`).set({ ...profile, createdAt: Date.now(), updatedAt: Date.now() });
        }
      } catch (_) {}
    }

    const token = signAppToken({
      uid,
      phone,
      provider: 'phone',
    });

    return {
      token,
      tokenType: 'Bearer',
      expiresInSec: env.jwtExpiresSec,
      uid,
      phone,
      name: displayName || profile?.name || '',
      profile,
      authMode: 'backend_otp',
    };
  },
};
