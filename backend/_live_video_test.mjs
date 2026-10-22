// End-to-end Gemini Live VIDEO test, mirrors the app's exact protocol.
// Run on the server inside /opt/ag-farmer-backend with --experimental-websocket.
import fs from 'node:fs';
import { execSync } from 'node:child_process';
import { env } from './src/config/env.js';

const API = 'http://127.0.0.1:5055/api';
const EMAIL = process.env.QA_EMAIL;
const PASS = process.env.QA_PASS;
const MODE = process.env.PROMPT_MODE || 'realtimeText'; // realtimeText | clientContent
const FRAME_PX = Number(process.env.FRAME_PX || 320);
const FRAME_Q = Number(process.env.FRAME_Q || 40);
const IMG = process.env.IMG || 'data/jankari_images/afim_doda.jpg';

const t0 = Date.now();
const log = (...a) => console.log(`[${String(Date.now() - t0).padStart(6)}ms]`, ...a);

async function api(body, token) {
  const res = await fetch(API, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: JSON.stringify(body),
  });
  const j = await res.json();
  if (!j.ok) throw new Error(`${body.action}: ${j.error}`);
  return j;
}

function jpegFrame() {
  // ffmpeg quality: 2 (best) .. 31 (worst). Map app quality (0-100) roughly.
  const q = Math.max(2, Math.min(31, Math.round(31 - (FRAME_Q / 100) * 29)));
  const out = `/tmp/frame_${FRAME_PX}.jpg`;
  execSync(`ffmpeg -y -loglevel error -i ${IMG} -vf "scale='min(${FRAME_PX},iw)':-2" -q:v ${q} ${out}`);
  const buf = fs.readFileSync(out);
  log(`frame ${FRAME_PX}px q${FRAME_Q} → ${buf.length} bytes`);
  return buf;
}

async function speechPcm16k(text) {
  const res = await fetch('https://api.openai.com/v1/audio/speech', {
    method: 'POST',
    headers: { Authorization: `Bearer ${env.openaiApiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ model: 'tts-1', voice: 'alloy', input: text, response_format: 'mp3' }),
  });
  if (!res.ok) throw new Error(`tts ${res.status}`);
  fs.writeFileSync('/tmp/q.mp3', Buffer.from(await res.arrayBuffer()));
  execSync('ffmpeg -y -loglevel error -i /tmp/q.mp3 -ac 1 -ar 16000 -f s16le /tmp/q.pcm');
  const pcm = fs.readFileSync('/tmp/q.pcm');
  log(`question pcm ${pcm.length} bytes (${(pcm.length / 32000).toFixed(1)}s)`);
  return pcm;
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function main() {
  const login = await api({ action: 'auth.login', email: EMAIL, password: PASS });
  const token = login.token;
  log('login ok plan=', login.profile?.plan);

  const DIRECT = process.env.DIRECT === '1';
  const SEND_FRAMES = process.env.FRAMES !== '0';
  let sess;
  if (DIRECT) {
    // No quota use: same model/voice/instructions shape as the server builds.
    sess = {
      model: env.geminiLiveModel || 'gemini-3.8-live',
      voice: env.geminiLiveVoice || 'Kore',
      instructions:
        'AG Live. afim. साफ और धीमी हिन्दी बोलो। किसान का पूरा वाक्य सुनो, फिर 1 या 2 छोटे वाक्य। खुद को दोहराओ मत। दवा हो तो पहले नाम और मात्रा, आखिरी वाक्य: अब एक बार जाइए और विशेषज्ञ से पूछ लें। शुरू करो: राम-राम किसान भाई। मॉडल का नाम मत लो।',
    };
  } else {
    sess = await api(
      { action: 'voice.realtime.session', mode: 'video', lang: 'hi', isHi: true, planId: 'super', cropId: 'afim' },
      token,
    );
    log('session ok model=', sess.model, 'voice=', sess.voice, 'videoSeconds=', sess.videoSeconds);
  }
  const TURN_COVERAGE = process.env.TURN_COVERAGE ?? 'TURN_INCLUDES_AUDIO_ACTIVITY_AND_ALL_VIDEO';
  const ACTIVITY = process.env.ACTIVITY ?? 'NO_INTERRUPTION';
  const url = DIRECT
    ? new URL('wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent')
    : new URL(sess.wsUrl);
  if (DIRECT) url.searchParams.set('key', env.geminiApiKey);
  else url.searchParams.set('access_token', sess.clientSecret);
  log(`variant direct=${DIRECT} turnCoverage=${TURN_COVERAGE} activity=${ACTIVITY} prompt=${MODE}`);
  const ws = new WebSocket(url);

  const stats = { audioBytes: 0, firstAudioMs: null, turns: 0, out: '', in: '', errors: [] };
  let setupReady = false;
  let phase = 'setup';
  let phaseStart = Date.now();

  const send = (obj) => ws.send(JSON.stringify(obj));

  ws.addEventListener('open', () => {
    log('ws open');
    send({
      setup: (!DIRECT && sess.liveSetup) ? (log('using server liveSetup'), sess.liveSetup) : {
        model: `models/${sess.model}`,
        generationConfig: {
          responseModalities: ['AUDIO'],
          maxOutputTokens: Number(process.env.MAXTOK || 180),
          speechConfig: { voiceConfig: { prebuiltVoiceConfig: { voiceName: sess.voice } } },
        },
        contextWindowCompression: { triggerTokens: 2000, slidingWindow: { targetTokens: 800 } },
        systemInstruction: { parts: [{ text: sess.instructions }] },
        realtimeInputConfig: {
          ...(ACTIVITY !== 'none' ? { activityHandling: ACTIVITY } : {}),
          ...(TURN_COVERAGE !== 'none' ? { turnCoverage: TURN_COVERAGE } : {}),
          automaticActivityDetection: process.env.VAD === 'manual' ? { disabled: true } : { silenceDurationMs: 1100, prefixPaddingMs: 400, endOfSpeechSensitivity: 'END_SENSITIVITY_LOW' },
        },
        inputAudioTranscription: {},
        outputAudioTranscription: {},
      },
    });
  });

  ws.addEventListener('error', (e) => log('ws error', e.message || e));
  ws.addEventListener('close', (e) => log('ws close', e.code, e.reason));

  ws.addEventListener('message', async (ev) => {
    const text = typeof ev.data === 'string' ? ev.data : Buffer.from(await ev.data.arrayBuffer()).toString('utf8');
    let msg;
    try { msg = JSON.parse(text); } catch { return; }
    if (msg.setupComplete) { setupReady = true; log('setupComplete'); return; }
    if (msg.error) { stats.errors.push(msg.error); log('ERROR msg', JSON.stringify(msg.error).slice(0, 300)); return; }
    const sc = msg.serverContent;
    if (!sc) { log('other', Object.keys(msg).join(',')); return; }
    if (sc.interrupted) log('interrupted');
    const parts = sc.modelTurn?.parts || [];
    for (const p of parts) {
      if (p.inlineData?.data) {
        const n = Buffer.from(p.inlineData.data, 'base64').length;
        stats.audioBytes += n;
        if (stats.firstAudioMs == null) { stats.firstAudioMs = Date.now() - phaseStart; log(`first audio after ${stats.firstAudioMs}ms (${phase})`); }
      }
      if (p.text) log('text part', p.text.slice(0, 120));
    }
    if (sc.inputTranscription?.text) stats.in += sc.inputTranscription.text;
    if (sc.outputTranscription?.text) stats.out += sc.outputTranscription.text;
    if (sc.turnComplete) {
      stats.turns += 1;
      log(`turnComplete #${stats.turns} audio=${stats.audioBytes}B (~${(stats.audioBytes / 48000).toFixed(1)}s)`);
      log('  user said :', stats.in.trim().slice(0, 200));
      log('  model said:', stats.out.trim().slice(0, 300));
      stats.in = ''; stats.out = ''; stats.audioBytes = 0; stats.firstAudioMs = null;
    }
  });

  // wait for setup
  for (let i = 0; i < 120 && !setupReady; i++) await sleep(100);
  if (!setupReady) { log('FAIL: no setupComplete in 12s'); ws.close(); return; }

  const frame = jpegFrame();
  const b64 = frame.toString('base64');
  const sendFrame = () => { if (SEND_FRAMES) send({ realtimeInput: { video: { mimeType: 'image/jpeg', data: b64 } } }); };
  phase = 'greeting'; phaseStart = Date.now();
  // 2 frames 1s apart like the app, then the greeting prompt.
  sendFrame();
  await sleep(1000);
  sendFrame();
  if (MODE === 'clientContent') {
    send({ clientContent: { turns: [{ role: 'user', parts: [{ text: 'Look at the plant in the camera. First say exactly: राम-राम किसान भाई. Then one short Hindi treatment.' }] }], turnComplete: true } });
    log('sent clientContent prompt');
  } else {
    send({ realtimeInput: { text: 'Look at the plant in the camera. First say exactly: राम-राम किसान भाई. Then one short Hindi treatment.' } });
    log('sent realtimeInput.text prompt');
  }

  // keep frames flowing at 1fps while waiting for the greeting (max 25s)
  const t1 = Date.now();
  let gotTurn = stats.turns;
  while (Date.now() - t1 < 25000 && stats.turns === gotTurn) {
    await sleep(1000);
    sendFrame();
  }
  if (stats.turns === gotTurn) log('FAIL: greeting never answered in 25s');

  // user asks a question by voice
  const pcm = await speechPcm16k('इस पौधे की पत्तियाँ पीली पड़ रही हैं और मुरझा रही हैं, क्या करें?');
  phase = 'question'; phaseStart = Date.now();
  gotTurn = stats.turns;
  const chunk = 3200; // 100ms @16k mono s16
  const silence = Buffer.alloc(chunk); if (process.env.VAD === 'manual') { send({ realtimeInput: { activityStart: {} } }); log('activityStart'); }
  for (let i = 0; i < 3; i++) { send({ realtimeInput: { audio: { mimeType: 'audio/pcm;rate=16000', data: silence.toString('base64') } } }); await sleep(100); }
  for (let off = 0; off < pcm.length; off += chunk) {
    send({ realtimeInput: { audio: { mimeType: 'audio/pcm;rate=16000', data: pcm.subarray(off, off + chunk).toString('base64') } } });
    if ((off / chunk) % 10 === 0) sendFrame();
    await sleep(100);
  }
  log('question audio sent; trailing silence'); if (process.env.VAD === 'manual') { send({ realtimeInput: { activityEnd: {} } }); log('activityEnd'); }
  for (let i = 0; i < 20; i++) { send({ realtimeInput: { audio: { mimeType: 'audio/pcm;rate=16000', data: silence.toString('base64') } } }); await sleep(100); }

  const t2 = Date.now();
  while (Date.now() - t2 < 25000 && stats.turns === gotTurn) {
    await sleep(1000);
    sendFrame();
  }
  if (stats.turns === gotTurn) log('FAIL: question never answered in 25s');
  log('errors:', stats.errors.length);
  ws.close();
}

main().catch((e) => { log('FATAL', e.message); process.exit(1); });
