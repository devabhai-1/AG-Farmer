import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { writeJsonAtomic } from '../utils/atomic_write.js';

const file = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '../../data/controls.json',
);

/**
 * Every switch is read from disk on each call.
 * Missing keys use these defaults, so a partial file cannot turn the app off.
 * Paid or unused doors stay false until the file turns them on.
 */
const defaults = {
  jankariVoice: 'device',
  openaiSpeech: false,
  chatterbox: false,
  geminiLive: false,
  transcribe: false,
  chat: true,
  course: true,
  image: true,
  voiceCall: true,
  videoCall: true,
  deep: true,
  jankari: true,
  weather: true,
  billing: true,
  storage: true,
  tracks: true,
  support: true,
  announcements: true,
  googleLogin: true,
  otp: true,
  credits: true,
  reports: true,
  notify: true,
};

const ONE = {
  'auth.google': 'googleLogin',
  'auth.otp.send': 'otp',
  'auth.otp.verify': 'otp',
  'auth.phone.lookup': 'otp',
  'jankari.list': 'jankari',
  'jankari.meta': 'jankari',
  'jankari.search': 'jankari',
  'jankari.tts': 'jankari',
  'announcement.list': 'announcements',
  'voice.speak': 'openaiSpeech',
  'tts.chatterbox.test': 'chatterbox',
  'voice.transcribe': 'transcribe',
  'voice.realtime.session': 'geminiLive',
  'video.start': 'videoCall',
  'weather.search': 'weather',
  'weather.forecast': 'weather',
  'billing.subscription.create': 'billing',
  'billing.subscription.verify': 'billing',
  'billing.subscription.cancel': 'billing',
  'billing.checkout.create': 'billing',
  'billing.checkout.verify': 'billing',
  'storage.upload': 'storage',
  'storage.upload-url': 'storage',
  'storage.uploadUrl': 'storage',
  'storage.download': 'storage',
  'storage.download-url': 'storage',
  'storage.downloadUrl': 'storage',
  'storage.list': 'storage',
  'storage.my-files': 'storage',
  'storage.delete': 'storage',
  'tracks.list': 'tracks',
  'tracks.save': 'tracks',
  'tracks.log': 'tracks',
  'tracks.delete': 'tracks',
  'support.create': 'support',
  'support.mine': 'support',
  'credit.status': 'credits',
  'credit.redeem': 'credits',
  'credit.create': 'credits',
  'report.create': 'reports',
  'notify.token': 'notify',
};

function hasImage(data) {
  return Boolean(
    data?.hasImage ||
      data?.imageBase64 ||
      data?.image ||
      (Array.isArray(data?.images) && data.images.length),
  );
}

function flagsFor(action, data) {
  if (
    action === 'chat.sync' ||
    action === 'chat.restore' ||
    action === 'chat.sessions' ||
    action === 'chat.sessions.list' ||
    action === 'chat.sessions.create' ||
    action === 'chat.sessions.delete'
  ) {
    return [data?.mode === 'course' ? 'course' : 'chat'];
  }
  if (action === 'chat') {
    const flags = [data?.mode === 'course' ? 'course' : 'chat'];
    const voice = data?.voice === true;
    const image = hasImage(data);
    if (voice && image) flags.push('videoCall');
    else if (voice) flags.push('voiceCall');
    if (image) flags.push('image');
    if (data?.deepResearch === true || data?.deep === true) flags.push('deep');
    return flags;
  }
  const one = ONE[action];
  return one ? [one] : [];
}

export function getControls() {
  let raw = {};
  try {
    raw = JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch {
    raw = {};
  }
  const out = {
    jankariVoice: raw?.jankariVoice === 'openai' ? 'openai' : 'device',
  };
  for (const key of Object.keys(defaults)) {
    if (key === 'jankariVoice') continue;
    out[key] = typeof raw?.[key] === 'boolean' ? raw[key] : defaults[key];
  }
  return out;
}

/** Refuse the action when its backend switch is off. Login and the shell stay open. */
export function assertOpen(action, data) {
  const controls = getControls();
  for (const flag of flagsFor(action, data || {})) {
    if (controls[flag] === false) {
      throw Object.assign(new Error('feature_closed'), {
        status: 403,
        feature: flag,
      });
    }
  }
}

/** Admin panel: merge boolean / jankariVoice switches onto disk. */
export function setControls(patch = {}) {
  const current = getControls();
  const next = { ...current };
  if (patch && typeof patch === 'object') {
    if (patch.jankariVoice === 'openai' || patch.jankariVoice === 'device') {
      next.jankariVoice = patch.jankariVoice;
    }
    for (const key of Object.keys(defaults)) {
      if (key === 'jankariVoice') continue;
      if (typeof patch[key] === 'boolean') next[key] = patch[key];
    }
  }
  writeJsonAtomic(file, next);
  return getControls();
}

export function controlFlagKeys() {
  return Object.keys(defaults).filter((k) => k !== 'jankariVoice');
}
