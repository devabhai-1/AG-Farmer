import dotenv from 'dotenv';
import path from 'path';
import crypto from 'crypto';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.resolve(__dirname, '../../.env') });

function required(name) {
  const v = process.env[name];
  if (!v || !String(v).trim()) {
    throw new Error(`[env] Missing required ${name} in backend/.env`);
  }
  return String(v).trim();
}

function optional(name, fallback = '') {
  const v = process.env[name];
  return v && String(v).trim() ? String(v).trim() : fallback;
}

export const env = {
  port: Number(optional('PORT', '5055')),
  nodeEnv: optional('NODE_ENV', 'development'),
  publicApiUrl: optional('PUBLIC_API_URL', 'http://localhost:5055/api'),

  // Firebase web / client config (ag-farmer1 only)
  firebase: {
    apiKey: required('FIREBASE_API_KEY'),
    authDomain: required('FIREBASE_AUTH_DOMAIN'),
    databaseURL: required('FIREBASE_DATABASE_URL'),
    projectId: required('FIREBASE_PROJECT_ID'),
    storageBucket: required('FIREBASE_STORAGE_BUCKET'),
    messagingSenderId: required('FIREBASE_MESSAGING_SENDER_ID'),
    appId: required('FIREBASE_APP_ID'),
    androidApiKey: optional('FIREBASE_ANDROID_API_KEY', ''),
    androidAppId: optional('FIREBASE_ANDROID_APP_ID', ''),
  },

  // Shorthand (backward compatible names used in services)
  get databaseURL() {
    return this.firebase.databaseURL;
  },
  get storageBucket() {
    return this.firebase.storageBucket;
  },
  get projectId() {
    return this.firebase.projectId;
  },

  credentialsPath: optional('GOOGLE_APPLICATION_CREDENTIALS', './serviceAccountKey.json'),

  // App session JWT (backend OTP) — never ship this secret to the app
  jwtSecret: optional('JWT_SECRET', cryptoRandomFallback()),
  jwtExpiresSec: Number(optional('JWT_EXPIRES_SEC', '2592000')), // 30 days

  // Phone OTP (backend-owned SMS)
  phoneAuthEnabled: optional('FIREBASE_AUTH_PHONE_ENABLED', 'true') === 'true',
  defaultCountryCode: optional('FIREBASE_AUTH_DEFAULT_COUNTRY', '+91'),
  otpTtlSec: Number(optional('OTP_TTL_SEC', '300')),
  otpResendSec: Number(optional('OTP_RESEND_SEC', '45')),
  smsProvider: optional('SMS_PROVIDER', 'log'), // log | msg91 | twilio
  msg91AuthKey: optional('MSG91_AUTH_KEY', ''),
  msg91Sender: optional('MSG91_SENDER', 'AGFMRR'),
  twilioAccountSid: optional('TWILIO_ACCOUNT_SID', ''),
  twilioAuthToken: optional('TWILIO_AUTH_TOKEN', ''),
  twilioFrom: optional('TWILIO_FROM', ''),

  // Password-reset OTP email (SMTP)
  smtpHost: optional('SMTP_HOST', 'smtp.gmail.com'),
  smtpPort: Number(optional('SMTP_PORT', '587')),
  smtpSecure: optional('SMTP_SECURE', 'false') === 'true',
  smtpUser: optional('SMTP_USER', ''),
  smtpPass: optional('SMTP_PASS', ''),
  smtpFrom: optional('SMTP_FROM', ''),

  // Paths — AG Farmer only
  rtdbRoot: optional('RTDB_ROOT', 'ag_farmer'),
  storageFolders: {
    chatImages: optional('STORAGE_CHAT_IMAGES', 'ag_farmer/chat_images'),
    cropLogs: optional('STORAGE_CROP_LOGS', 'ag_farmer/crop_logs'),
    profiles: optional('STORAGE_PROFILES', 'ag_farmer/profiles'),
  },

  adminApiKey: optional('ADMIN_API_KEY', ''),

  // IP visitor / chat restore pepper (hash IPs at rest)
  ipPepper: optional('IP_PEPPER', optional('JWT_SECRET', 'ag-farmer-ip')),

  // OpenAI — server only (AG Expert family)
  openaiApiKey: optional('OPENAI_API_KEY', ''),
  openaiModel: optional('OPENAI_MODEL', 'gpt-5-nano'),
  openaiChatAdvancedModel: optional('OPENAI_CHAT_ADVANCED_MODEL', 'gpt-5-mini'),
  openaiChatLowModel: optional('OPENAI_CHAT_LOW_MODEL', 'gpt-5-nano'),
  openaiChatDeepModel: optional('OPENAI_CHAT_DEEP_MODEL', 'gpt-4o'),
  openaiImageAdvancedModel: optional('OPENAI_IMAGE_ADVANCED_MODEL', 'gpt-5.4-mini'),
  openaiImageLowModel: optional('OPENAI_IMAGE_LOW_MODEL', 'gpt-6-luna'),
  openaiTimeoutMs: Number(optional('OPENAI_TIMEOUT_MS', '60000')),
  openaiRealtimeModel: optional('OPENAI_REALTIME_MODEL', 'gpt-realtime'),
  openaiRealtimeVoice: optional('OPENAI_REALTIME_VOICE', 'alloy'),

  // Neural TTS for Jankari "बोलें" (server-side, cached per article)
  ttsModel: optional('TTS_MODEL', 'gpt-4o-mini-tts'),
  ttsVoice: optional('TTS_VOICE', 'coral'),

  // Google Gemini — server only (AG High family)
  geminiApiKey: optional('GEMINI_API_KEY', ''),
  geminiModel: optional('GEMINI_MODEL', 'gemini-3.1-flash-lite'),
  geminiChatAdvancedModel: optional(
    'GEMINI_CHAT_ADVANCED_MODEL',
    'gemini-3.6-flash',
  ),
  geminiChatLowModel: optional(
    'GEMINI_CHAT_LOW_MODEL',
    'gemini-3.1-flash-lite',
  ),
  geminiChatDeepModel: optional('GEMINI_CHAT_DEEP_MODEL', 'gemini-3.1-pro-preview'),
  geminiImageAdvancedModel: optional(
    'GEMINI_IMAGE_ADVANCED_MODEL',
    'gemini-3.6-flash',
  ),
  geminiImageLowModel: optional(
    'GEMINI_IMAGE_LOW_MODEL',
    'gemini-3.1-flash-lite',
  ),
  geminiTimeoutMs: Number(optional('GEMINI_TIMEOUT_MS', '60000')),
  geminiLiveModel: optional('GEMINI_LIVE_MODEL', ''),
  geminiLiveVoice: optional('GEMINI_LIVE_VOICE', ''),
  // 1 = no daily voice/video cap, so a live test is not cut off.
  // Set LIVE_LIMITS_OFF=0 to turn the plan caps back on.
  liveLimitsOff: optional('LIVE_LIMITS_OFF', '1') !== '0',

  // Daily free advanced usage (then auto-switch to low-cost models)
  dailyChatAdvancedLimit: Number(optional('DAILY_CHAT_ADVANCED_LIMIT', '50')),
  dailyImageAdvancedLimit: Number(optional('DAILY_IMAGE_ADVANCED_LIMIT', '10')),

  // Which AI to try first when client omits provider: gemini | openai
  aiProvider: optional('AI_PROVIDER', 'openai').toLowerCase(),

  // Google Sign-In (OAuth web client id — not a Firebase API secret)
  googleClientId: optional(
    'GOOGLE_CLIENT_ID',
    '621096737592-abjvope8i0jgc0gdg7201a48sb5ltkn1.apps.googleusercontent.com',
  ),

  // Razorpay — server only. The app receives Key Id at checkout, never the secret.
  razorpayKeyId: optional('RAZORPAY_KEY_ID', ''),
  razorpayKeySecret: optional('RAZORPAY_KEY_SECRET', ''),
  razorpayWebhookSecret: optional('RAZORPAY_WEBHOOK_SECRET', ''),
};

function cryptoRandomFallback() {
  // Dev-only fallback — set JWT_SECRET in production .env
  return crypto.randomBytes(32).toString('hex');
}
