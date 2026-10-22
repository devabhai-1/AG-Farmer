import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { isFirebaseReady } from '../config/firebase.js';
import { env } from '../config/env.js';
import { rtdbGet, rtdbSet } from './rtdb_system.js';
import { ChatLimitsService } from './chat_limits.service.js';
import { CatalogService } from './catalog.service.js';
import { JankariService } from './jankari.service.js';
import { readQuota } from '../utils/quota_store.js';
import { plans as seedPlans } from '../../seed/plans.js';
import { crops as seedCrops } from '../../seed/crops.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const dataDir = path.resolve(__dirname, '../../data');

function listNames(dir) {
  try {
    if (!fs.existsSync(dir)) return [];
    return fs.readdirSync(dir).filter((n) => !n.startsWith('.')).slice(0, 400);
  } catch {
    return [];
  }
}

function publicRuntimeConfig() {
  return {
    updatedAt: Date.now(),
    nodeEnv: env.nodeEnv,
    publicApiUrl: env.publicApiUrl,
    rtdbRoot: env.rtdbRoot,
    liveLimitsOff: env.liveLimitsOff === true,
    aiProvider: env.aiProvider,
    models: {
      openaiChatAdvanced: env.openaiChatAdvancedModel,
      openaiChatLow: env.openaiChatLowModel,
      openaiChatDeep: env.openaiChatDeepModel,
      geminiChatAdvanced: env.geminiChatAdvancedModel,
      geminiChatLow: env.geminiChatLowModel,
      ttsModel: env.ttsModel,
      ttsVoice: env.ttsVoice,
    },
    secretsInEnvOnly: true,
    accountsLocalOnly: true,
  };
}

async function seedIfEmpty(path, local) {
  const remote = await rtdbGet(path);
  if (remote) return remote;
  await rtdbSet(path, local);
  return local;
}

export async function hydrateSystemToRtdb() {
  if (!isFirebaseReady()) {
    console.warn('[rtdb-system] Firebase not ready — file store stays local');
    return { ok: false };
  }

  const limits = ChatLimitsService.get();
  const remoteLimits = await rtdbGet('system/chat_limits');
  if (remoteLimits && typeof remoteLimits === 'object') {
    ChatLimitsService.save(remoteLimits);
  } else {
    await rtdbSet('system/chat_limits', { ...limits, updatedAt: Date.now() });
  }

  const creditsFile = path.join(dataDir, 'credits.json');
  let credits = { wallets: {}, tokens: {} };
  try {
    credits = JSON.parse(fs.readFileSync(creditsFile, 'utf8'));
  } catch {
    /* empty */
  }
  const remoteCredits = await rtdbGet('system/credits');
  if (!remoteCredits) {
    await rtdbSet('system/credits', { ...credits, updatedAt: Date.now() });
  }
  const wallets = remoteCredits?.wallets || credits.wallets || {};
  for (const [uid, row] of Object.entries(wallets)) {
    if (!uid || !row) continue;
    await rtdbSet(`users/${uid}/credits`, {
      voice: Number(row.voice) || 0,
      video: Number(row.video) || 0,
      updatedAt: Date.now(),
    });
  }

  const lockFile = path.join(dataDir, 'login_lockouts.json');
  let lockouts = {};
  try {
    lockouts = JSON.parse(fs.readFileSync(lockFile, 'utf8'));
  } catch {
    lockouts = {};
  }
  await seedIfEmpty('system/lockouts', { ...lockouts, updatedAt: Date.now() });

  const quota = readQuota();
  await rtdbSet('system/quota/meta', {
    guests: quota.guests || {},
    voiceLife: quota.voiceLife || {},
    bank: quota.bank || {},
    months: quota.months || {},
    updatedAt: Date.now(),
  });

  const plans = await CatalogService.getPlans();
  if (!plans || !Object.keys(plans).length) {
    await CatalogService.setPlans(seedPlans);
  }
  const crops = await CatalogService.getCrops();
  if (!crops || !Object.keys(crops).length) {
    await CatalogService.setCrops(seedCrops);
  }

  await rtdbSet('system/public_config', publicRuntimeConfig());

  const images = listNames(path.join(dataDir, 'jankari_images'));
  const tts = listNames(path.join(dataDir, 'tts_cache'));
  await rtdbSet('system/media', {
    jankariImages: images.length,
    ttsCache: tts.length,
    jankariImageFiles: images.slice(0, 80),
    ttsFiles: tts.slice(0, 80),
    updatedAt: Date.now(),
  });

  try {
    await JankariService.syncAllToRtdb();
  } catch (err) {
    console.warn('[rtdb-system] jankari seed skip', err?.message || 'jankari');
  }

  console.log('[rtdb-system] server data mirrored under ag_farmer/system');
  return { ok: true };
}
