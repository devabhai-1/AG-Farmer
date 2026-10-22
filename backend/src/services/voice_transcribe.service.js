import { env } from '../config/env.js';
import { recordUpstreamFailure } from '../middleware/metrics.js';

const MAX_BYTES = 1_500_000;
const TIMEOUT_MS = 45000;

/**
 * Turns a short mic recording into text.
 * The phone records with the plain microphone, not the system speech
 * recognizer, so Android does not play its start/stop beep.
 */
export async function transcribeSpeech({ audioBase64, lang }) {
  if (!env.openaiApiKey) {
    throw Object.assign(new Error('transcribe_unavailable'), { status: 503 });
  }
  const clean = String(audioBase64 || '').replace(/^data:[^;]+;base64,/, '');
  const buf = Buffer.from(clean, 'base64');
  if (buf.length < 800) return { text: '' };
  if (buf.length > MAX_BYTES) {
    throw Object.assign(new Error('too_large'), { status: 413 });
  }

  const language = lang === 'en' ? 'en' : 'hi';
  try {
    return { text: await openaiTranscribe(buf, 'gpt-4o-mini-transcribe', language) };
  } catch (err) {
    if (!err.retryable) throw err;
    return { text: await openaiTranscribe(buf, 'whisper-1', language) };
  }
}

async function openaiTranscribe(buf, model, language) {
  const wav = buf.length > 12 && buf.slice(0, 4).toString() === 'RIFF';
  const form = new FormData();
  form.append(
    'file',
    new Blob([buf], { type: wav ? 'audio/wav' : 'audio/mp4' }),
    wav ? 'speech.wav' : 'speech.m4a',
  );
  form.append('model', model);
  form.append('language', language);
  form.append(
    'prompt',
    language === 'hi'
      ? 'किसान हिन्दी या गाँव की बोली में खेती की बात बोल रहा है। शब्द जस के तस लिखो, अनुमान से मत बदलो। फसल, बीमारी, कीड़ा, दवा, स्प्रे, 10 आरी, 15 लीटर पंप, खाद, पानी, सिंचाई, अफीम, लहसुन, प्याज, गेहूँ, खाखरिया, थ्रिप्स, उकठा, पीलापन।'
      : 'A farmer is speaking. Write the words exactly. Do not guess a different sentence. Crop, disease, pest, spray, dose, irrigation.',
  );

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  let res;
  try {
    res = await fetch('https://api.openai.com/v1/audio/transcriptions', {
      method: 'POST',
      headers: { Authorization: `Bearer ${env.openaiApiKey}` },
      body: form,
      signal: controller.signal,
    });
  } catch (e) {
    clearTimeout(timer);
    recordUpstreamFailure('openai_transcribe', e.name === 'AbortError' ? 'timeout' : 'network');
    throw Object.assign(new Error('transcribe_unavailable'), { status: 502 });
  }
  clearTimeout(timer);

  if (!res.ok) {
    recordUpstreamFailure('openai_transcribe', `http_${res.status}`);
    const retryable = res.status === 400 || res.status === 404;
    throw Object.assign(new Error('transcribe_unavailable'), { status: 502, retryable });
  }
  const json = await res.json().catch(() => ({}));
  return String(json.text || '').trim();
}
