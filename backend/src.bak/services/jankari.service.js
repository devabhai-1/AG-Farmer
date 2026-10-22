import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { isFirebaseReady, rootRef } from '../config/firebase.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const afimPath = path.resolve(__dirname, '../../data/afim_jankari.json');
const lasunPath = path.resolve(__dirname, '../../data/lasun_jankari.json');
const cropsPath = path.resolve(__dirname, '../../data/crops_jankari.json');
const cropsDir = path.resolve(__dirname, '../../data/jankari_crops');

function loadFile(filePath) {
  const raw = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  const posts = Array.isArray(raw.posts) ? raw.posts : [];
  return { version: Number(raw.version) || 1, cropId: raw.cropId || 'afim', posts };
}

function sortPosts(posts) {
  return [...posts].sort((a, b) => String(a.id).localeCompare(String(b.id)));
}

async function readRemote(cropId) {
  const [postsSnap, metaSnap] = await Promise.all([
    rootRef(`jankari/${cropId}/posts`).get(),
    rootRef(`jankari/${cropId}/meta`).get(),
  ]);
  if (!postsSnap.exists()) return null;
  const val = postsSnap.val() || {};
  const posts = sortPosts(Object.values(val));
  return { version: Number(metaSnap.val()?.version) || 0, posts };
}

const syncing = { afim: null, lasun: null };
const cropCache = new Map();

function syncRemote(cropId, pack) {
  if (syncing[cropId]) return syncing[cropId];
  syncing[cropId] = (async () => {
    try {
      const remote = await readRemote(cropId);
      if (remote && remote.version === pack.version && remote.posts.length === pack.posts.length) {
        return;
      }
      const map = {};
      for (const post of pack.posts) {
        if (post?.id) map[post.id] = post;
      }
      const ids = Object.keys(map);
      const chunk = 40;
      for (let i = 0; i < ids.length; i += chunk) {
        const part = {};
        for (const id of ids.slice(i, i + chunk)) part[id] = map[id];
        await rootRef(`jankari/${cropId}/posts`).update(part);
      }
      await rootRef(`jankari/${cropId}/meta`).set({
        version: pack.version,
        cropId,
        count: pack.posts.length,
        updatedAt: Date.now(),
      });
    } catch (err) {
      console.error('[jankari] rtdb sync failed:', err && err.message ? err.message : err);
    } finally {
      syncing[cropId] = null;
    }
  })();
  return syncing[cropId];
}

function loadCropPack(cropId) {
  if (cropCache.has(cropId)) return cropCache.get(cropId);
  const filePath = path.join(cropsDir, `${cropId}.json`);
  if (!fs.existsSync(filePath)) {
    const empty = { version: 0, posts: [] };
    cropCache.set(cropId, empty);
    return empty;
  }
  const pack = loadFile(filePath);
  cropCache.set(cropId, pack);
  return pack;
}

function loadCropPosts(cropId) {
  return loadCropPack(cropId).posts;
}

function basePacks() {
  const afim = loadFile(afimPath);
  const lasun = fs.existsSync(lasunPath) ? loadFile(lasunPath) : { version: 0, posts: [] };
  const other = fs.existsSync(cropsPath) ? loadFile(cropsPath) : { version: 0, posts: [] };
  if (isFirebaseReady()) {
    syncRemote('afim', afim);
    if (lasun.posts.length) syncRemote('lasun', lasun);
    if (other.posts.length) syncRemote('crops', other);
  }
  return { afim, lasun, other };
}

function stampOf(pack, cropId) {
  return `${cropId}:v${Number(pack.version) || 0}:n${pack.posts.length}`;
}

export const JankariService = {
  /** Afim, garlic, and a short copy of every other crop. */
  async posts() {
    const base = basePacks();
    return [...base.afim.posts, ...base.lasun.posts, ...base.other.posts];
  },

  async meta(cropId) {
    const id = String(cropId || 'all').trim();
    if (id && id !== 'all') {
      if (id === 'afim' || id === 'lasun') {
        const base = basePacks();
        const pack = id === 'afim' ? base.afim : base.lasun;
        return { stamp: stampOf(pack, id), count: pack.posts.length, cropId: id };
      }
      const pack = loadCropPack(id);
      if (pack.posts.length) {
        return { stamp: stampOf(pack, id), count: pack.posts.length, cropId: id };
      }
      const base = basePacks();
      const posts = base.other.posts.filter((post) => post.cropId === id);
      return {
        stamp: stampOf({ version: base.other.version, posts }, id),
        count: posts.length,
        cropId: id,
      };
    }
    const base = basePacks();
    return {
      stamp: [
        stampOf(base.afim, 'afim'),
        stampOf(base.lasun, 'lasun'),
        stampOf(base.other, 'crops'),
      ].join('|'),
      afim: base.afim.version,
      lasun: base.lasun.version,
      crops: base.other.version,
      count: base.afim.posts.length + base.lasun.posts.length + base.other.posts.length,
    };
  },

  async postsFor(cropId) {
    const id = String(cropId || 'all').trim();
    if (!id || id === 'all') return this.posts();
    if (id === 'afim' || id === 'lasun') {
      const base = basePacks();
      if (id === 'afim') return base.afim.posts;
      return base.lasun.posts;
    }
    const full = loadCropPosts(id);
    if (full.length) return full;
    const base = basePacks();
    return base.other.posts.filter((post) => post.cropId === id);
  },

  async list(cropId) {
    const id = String(cropId || 'afim').trim();
    if (!id || id === 'all') {
      const meta = await this.meta();
      return { posts: await this.posts(), stamp: meta.stamp, count: meta.count };
    }
    if (id === 'afim' || id === 'lasun') {
      const base = basePacks();
      const pack = id === 'afim' ? base.afim : base.lasun;
      return { posts: pack.posts, stamp: stampOf(pack, id), count: pack.posts.length };
    }
    const pack = loadCropPack(id);
    if (pack.posts.length) {
      return { posts: pack.posts, stamp: stampOf(pack, id), count: pack.posts.length };
    }
    const base = basePacks();
    const posts = base.other.posts.filter((post) => post.cropId === id);
    return { posts, stamp: stampOf({ version: base.other.version, posts }, id), count: posts.length };
  },
};
