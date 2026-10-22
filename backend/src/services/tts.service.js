import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { spawnSync } from 'child_process';
import { fileURLToPath } from 'url';
import { env } from '../config/env.js';
import { JankariService } from './jankari.service.js';
import { recordUpstreamFailure } from '../middleware/metrics.js';

/**
 * Neural text-to-speech for Fasal Jankari articles.
 *
 * - Audio is generated once per (model, voice, lang, text) and cached as an
 *   mp3 under data/tts_cache; every later listener gets the same file, so the
 *   cost is paid once per article, never per user.
 * - Only server-side article text is ever synthesised (the client sends a
 *   post id, not free text), so the endpoint cannot be used as a general TTS.
 */

const __dirname = path.dirname(fileURLToPath(import.meta.url));
export const TTS_CACHE_DIR = path.resolve(__dirname, '../../data/tts_cache');
const MAX_CHARS = 4000; // OpenAI speech input limit is 4096
const SPEAK_CHARS = 850; // A chat reply this long starts speaking in a few seconds
const TIMEOUT_MS = 60000;

const inFlight = new Map();

function ensureDir() {
  if (!fs.existsSync(TTS_CACHE_DIR)) fs.mkdirSync(TTS_CACHE_DIR, { recursive: true });
}
// express.static needs the folder to exist before the first request.
try {
  ensureDir();
} catch (err) {
  console.warn('[tts] cache dir not writable:', err?.message || 'mkdir');
}

function cleanForSpeech(raw) {
  return String(raw || '')
    .replace(/!\[[^\]]*\]\([^)]*\)/g, ' ')
    .replace(/\[([^\]]*)\]\([^)]*\)/g, '$1')
    .replace(/https?:\/\/\S+/g, ' ')
    .replace(/[*_`#~>]+/g, ' ')
    .replace(/[🙏🔊✅❌⚠️•·]+/g, ' ')
    .replace(/\s*\n\s*/g, ' । ')
    .replace(/(\s*।\s*){2,}/g, ' । ')
    .replace(/\s{2,}/g, ' ')
    .trim();
}

function instructionsFor(lang) {
  return lang === 'en'
    ? 'You are a warm, friendly Indian agricultural expert explaining to farmers. Speak clearly at a calm, moderate pace with natural pauses; Indian English accent; pronounce crop names (Afim, Lasun) the Indian way.'
    : 'आप एक अनुभवी, स्नेही कृषि विशेषज्ञ हैं जो किसानों को समझा रही हैं। स्वाभाविक, साफ़ हिंदी में, आराम से और मध्यम गति से बोलें; वाक्यों के बीच हल्का ठहराव रखें; संख्याएँ और तारीखें साफ़ बोलें।';
}

function mediaOrigin() {
  return String(env.publicApiUrl || '').replace(/\/api\/?$/, '');
}

async function openaiSpeech({ text, lang, model, voice }) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  const body = {
    model,
    voice,
    input: text,
    response_format: 'mp3',
    speed: 1.0,
  };
  if (model.includes('4o')) body.instructions = instructionsFor(lang);
  let res;
  try {
    res = await fetch('https://api.openai.com/v1/audio/speech', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${env.openaiApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
      signal: controller.signal,
    });
  } catch (e) {
    clearTimeout(timer);
    recordUpstreamFailure('openai_tts', e.name === 'AbortError' ? 'timeout' : 'network');
    throw Object.assign(new Error('tts_unavailable'), { status: 502 });
  }
  clearTimeout(timer);
  if (!res.ok) {
    const detail = await res.text().catch(() => '');
    recordUpstreamFailure('openai_tts', `http_${res.status}`);
    console.error('[tts]', model, res.status, detail.slice(0, 160));
    throw Object.assign(new Error('tts_unavailable'), { status: 502, retryable: res.status >= 500 || res.status === 404 || res.status === 400 });
  }
  return Buffer.from(await res.arrayBuffer());
}

async function synthesize({ text, lang, model, voice }) {
  if (!env.openaiApiKey) throw Object.assign(new Error('tts_unavailable'), { status: 503 });
  const primary = model || env.ttsModel;
  const useVoice = voice || env.ttsVoice;
  try {
    return {
      buf: await openaiSpeech({ text, lang, model: primary, voice: useVoice }),
      model: primary,
      voice: useVoice,
    };
  } catch (err) {
    if (primary !== 'tts-1' && err.retryable) {
      return {
        buf: await openaiSpeech({ text, lang, model: 'tts-1', voice: useVoice }),
        model: 'tts-1',
        voice: useVoice,
      };
    }
    throw err;
  }
}

async function findPost(postId, cropId) {
  const id = String(postId || '').trim();
  if (!id) return null;
  const scoped = cropId ? await JankariService.postsFor(cropId) : [];
  let post = scoped.find((p) => String(p?.id) === id);
  if (!post) {
    const all = await JankariService.posts();
    post = all.find((p) => String(p?.id) === id);
  }
  return post || null;
}

async function cachedSpeech(text, lang, tag, pick = {}) {
  const l = lang === 'en' ? 'en' : 'hi';
  const model = pick.model || env.ttsModel;
  const voice = pick.voice || env.ttsVoice;
  const key = crypto
    .createHash('sha256')
    .update(`${model}|${voice}|${l}|${text}`)
    .digest('hex')
    .slice(0, 40);
  ensureDir();
  const file = path.join(TTS_CACHE_DIR, `${key}.mp3`);
  const url = `${mediaOrigin()}/media/tts/${key}.mp3`;

  if (fs.existsSync(file) && fs.statSync(file).size > 1000) {
    return { url, cached: true, chars: text.length };
  }

  if (!inFlight.has(key)) {
    inFlight.set(
      key,
      (async () => {
        const started = Date.now();
        const made = await synthesize({
          text,
          lang: l,
          model,
          voice,
        });
        if (!made.buf || made.buf.length < 1000) {
          throw Object.assign(new Error('tts_unavailable'), { status: 502 });
        }
        const tmp = `${file}.${process.pid}.tmp`;
        fs.writeFileSync(tmp, made.buf);
        fs.renameSync(tmp, file);
        console.log(
          `[tts] ${tag} ${l} ${made.model}/${made.voice} ${text.length}ch → ${Math.round(made.buf.length / 1024)}KB in ${Date.now() - started}ms`,
        );
      })().finally(() => inFlight.delete(key)),
    );
  }
  await inFlight.get(key);
  return { url, cached: false, chars: text.length };
}

export const TtsService = {
  /** Audio for one Jankari article. Returns a cacheable public mp3 URL. */
  async article({ postId, cropId, lang }) {
    const l = lang === 'en' ? 'en' : 'hi';
    const post = await findPost(postId, cropId);
    if (!post) throw Object.assign(new Error('not_found'), { status: 404 });
    const title = l === 'en' ? post.titleEn || post.titleHi : post.titleHi || post.titleEn;
    const body = l === 'en' ? post.bodyEn || post.bodyHi : post.bodyHi || post.bodyEn;
    let text = cleanForSpeech(`${title || ''}। ${body || ''}`);
    if (!text) throw Object.assign(new Error('not_found'), { status: 404 });
    if (text.length > MAX_CHARS) text = `${text.slice(0, MAX_CHARS - 1)}…`;
    const audio = await cachedSpeech(text, l, post.id);
    return { ...audio, postId: post.id };
  },

  /**
   * Speak a chat reply in the same neural voice as Jankari.
   * The chat model writes the words; this only reads them aloud.
   */
  async speak({ text, lang }) {
    const l = lang === 'en' ? 'en' : 'hi';
    let clean = cleanForSpeech(text);
    if (!clean) throw Object.assign(new Error('empty_text'), { status: 400 });
    if (clean.length > SPEAK_CHARS) {
      const slice = clean.slice(0, SPEAK_CHARS);
      let end = -1;
      for (const stop of ['।', '.', '?', '!', '\n']) {
        end = Math.max(end, slice.lastIndexOf(stop));
      }
      clean = (end >= 280 ? slice.slice(0, end + 1) : slice).trim();
    }
    // Live chat must start speaking quickly and stay cheap.
    // tts-1 is OpenAI, no Google, about 1/4 the wait of gpt-4o-mini-tts.
    return cachedSpeech(clean, l, 'chat', { model: 'tts-1', voice: 'nova' });
  },

  /** Test-only: Chatterbox sidecar on 127.0.0.1:5066. Does not replace Jankari TTS. */
  async chatterboxTest({ text, lang }) {
    const l = lang === 'en' ? 'en' : 'hi';
    let clean = cleanForSpeech(text);
    if (!clean) {
      clean =
        l === 'en'
          ? 'Ram-ram farmer. This is the Chatterbox test voice for ten aari.'
          : 'राम-राम किसान भाई। यह चैटरबॉक्स टेस्ट आवाज़ है। दस आरी खेत की बात है।';
    }
    if (clean.length > 400) clean = `${clean.slice(0, 399)}…`;
    let res;
    try {
      res = await fetch('http://127.0.0.1:5066/speak', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: clean, lang: l }),
        signal: AbortSignal.timeout(180000),
      });
    } catch (err) {
      throw Object.assign(new Error('chatterbox_offline'), { status: 503 });
    }
    if (!res.ok) {
      throw Object.assign(new Error('chatterbox_failed'), { status: 502 });
    }
    const wav = Buffer.from(await res.arrayBuffer());
    ensureDir();
    const wavFile = path.join(TTS_CACHE_DIR, 'chatterbox_test.wav');
    const mp3File = path.join(TTS_CACHE_DIR, 'chatterbox_test.mp3');
    fs.writeFileSync(wavFile, wav);
    const conv = spawnSync(
      'ffmpeg',
      ['-y', '-i', wavFile, '-codec:a', 'libmp3lame', '-q:a', '4', mp3File],
      { stdio: 'ignore' },
    );
    const useMp3 = conv.status === 0 && fs.existsSync(mp3File);
    const outFile = useMp3 ? mp3File : wavFile;
    const outBuf = fs.readFileSync(outFile);
    const ext = useMp3 ? 'mp3' : 'wav';
    return {
      url: `${mediaOrigin()}/media/tts/chatterbox_test.${ext}`,
      audioBase64: outBuf.toString('base64'),
      mime: useMp3 ? 'audio/mpeg' : 'audio/wav',
      cached: false,
      model: 'chatterbox-multilingual',
      chars: clean.length,
    };
  },
};
