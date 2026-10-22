import crypto from 'crypto';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { isFirebaseReady, rootRef } from '../config/firebase.js';
import { writeJsonAtomic } from '../utils/atomic_write.js';

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

function contentHash(posts) {
  const hash = crypto.createHash('sha1');
  for (const post of posts) {
    hash.update(String(post?.id || ''));
    hash.update('\n');
    hash.update(String(post?.titleHi || ''));
    hash.update('\n');
    hash.update(String(post?.bodyHi || ''));
    hash.update('\n');
    hash.update(String(post?.titleEn || ''));
    hash.update('\n');
    hash.update(String(post?.bodyEn || ''));
    hash.update('\n');
    hash.update(JSON.stringify(post?.images || []));
    hash.update('\n');
  }
  return hash.digest('hex').slice(0, 12);
}

const fileCache = new Map();

function loadFresh(filePath, fallbackCropId) {
  if (!fs.existsSync(filePath)) {
    fileCache.delete(filePath);
    return { version: 0, cropId: fallbackCropId, posts: [], hash: contentHash([]) };
  }
  const stat = fs.statSync(filePath);
  const hit = fileCache.get(filePath);
  if (hit && hit.mtimeMs === stat.mtimeMs && hit.size === stat.size) return hit.pack;
  const pack = loadFile(filePath);
  pack.cropId = pack.cropId || fallbackCropId;
  pack.hash = contentHash(pack.posts);
  fileCache.set(filePath, { mtimeMs: stat.mtimeMs, size: stat.size, pack });
  return pack;
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
  const meta = metaSnap.val() || {};
  return { version: Number(meta.version) || 0, posts, hash: String(meta.hash || '') };
}

const syncing = { afim: null, lasun: null };

function syncRemote(cropId, pack) {
  if (syncing[cropId]) return syncing[cropId];
  syncing[cropId] = (async () => {
    try {
      const remote = await readRemote(cropId);
      const hash = pack.hash || contentHash(pack.posts);
      if (remote && remote.hash === hash && remote.posts.length === pack.posts.length) {
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
        hash: pack.hash || contentHash(pack.posts),
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
  return loadFresh(path.join(cropsDir, `${cropId}.json`), cropId);
}

function loadCropPosts(cropId) {
  return loadCropPack(cropId).posts;
}

function basePacks() {
  const afim = loadFresh(afimPath, 'afim');
  const lasun = loadFresh(lasunPath, 'lasun');
  const other = loadFresh(cropsPath, 'crops');
  if (isFirebaseReady()) {
    syncRemote('afim', afim);
    if (lasun.posts.length) syncRemote('lasun', lasun);
    if (other.posts.length) syncRemote('crops', other);
  }
  return { afim, lasun, other };
}

function stampOf(pack, cropId) {
  const hash = pack.hash || contentHash(pack.posts || []);
  return `${cropId}:v${Number(pack.version) || 0}:n${(pack.posts || []).length}:h${hash}`;
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
      return {
        posts: pack.posts,
        stamp: stampOf(pack, id),
        count: pack.posts.length,
        version: pack.version,
      };
    }
    const pack = loadCropPack(id);
    if (pack.posts.length) {
      return {
        posts: pack.posts,
        stamp: stampOf(pack, id),
        count: pack.posts.length,
        version: pack.version,
      };
    }
    const base = basePacks();
    const posts = base.other.posts.filter((post) => post.cropId === id);
    return {
      posts,
      stamp: stampOf({ version: base.other.version, posts }, id),
      count: posts.length,
      version: base.other.version,
    };
  },

  async syncAllToRtdb() {
    const base = basePacks();
    const jobs = [syncRemote('afim', base.afim)];
    if (base.lasun.posts.length) jobs.push(syncRemote('lasun', base.lasun));
    if (base.other.posts.length) jobs.push(syncRemote('crops', base.other));
    if (fs.existsSync(cropsDir)) {
      for (const name of fs.readdirSync(cropsDir)) {
        if (!name.endsWith('.json')) continue;
        const cropId = name.slice(0, -5);
        const pack = loadCropPack(cropId);
        if (pack.posts.length) jobs.push(syncRemote(cropId, pack));
      }
    }
    await Promise.all(jobs);
    return { ok: true, crops: jobs.length };
  },

  /** Admin: crop packs summary. */
  async adminMeta() {
    const base = basePacks();
    const crops = [
      { cropId: 'afim', count: base.afim.posts.length, version: base.afim.version },
      { cropId: 'lasun', count: base.lasun.posts.length, version: base.lasun.version },
      { cropId: 'crops', count: base.other.posts.length, version: base.other.version },
    ];
    if (fs.existsSync(cropsDir)) {
      for (const name of fs.readdirSync(cropsDir)) {
        if (!name.endsWith('.json')) continue;
        const cropId = name.slice(0, -5);
        if (cropId === 'afim' || cropId === 'lasun') continue;
        const pack = loadCropPack(cropId);
        crops.push({ cropId, count: pack.posts.length, version: pack.version });
      }
    }
    return { crops };
  },

  /**
   * Admin: replace one crop file posts (afim / lasun / crops / jankari_crops/{id}).
   * Keeps payload bounded — titles + bodies only per post fields already present.
   */
  async adminSave(cropId, { posts, version } = {}) {
    const id = String(cropId || '').trim();
    if (!id || !/^[a-z0-9_]{2,32}$/i.test(id)) {
      throw Object.assign(new Error('cropId required'), { status: 400 });
    }
    if (!Array.isArray(posts)) {
      throw Object.assign(new Error('posts required'), { status: 400 });
    }
    if (posts.length > 400) {
      throw Object.assign(new Error('too many posts'), { status: 400 });
    }
    const clean = posts
      .filter((p) => p && typeof p === 'object')
      .map((p) => {
        const row = { ...p };
        row.id = String(row.id || '').trim().slice(0, 80);
        if (!row.id) return null;
        for (const k of ['titleHi', 'titleEn', 'bodyHi', 'bodyEn']) {
          if (row[k] != null) row[k] = String(row[k]).slice(0, 12000);
        }
        return row;
      })
      .filter(Boolean);
    const pack = {
      version: Math.max(1, Number(version) || 1),
      cropId: id === 'crops' ? 'crops' : id,
      posts: clean,
    };
    pack.hash = contentHash(pack.posts);
    let target = path.join(cropsDir, `${id}.json`);
    if (id === 'afim') target = afimPath;
    else if (id === 'lasun') target = lasunPath;
    else if (id === 'crops') target = cropsPath;
    else if (!fs.existsSync(cropsDir)) fs.mkdirSync(cropsDir, { recursive: true });
    const size = Buffer.byteLength(JSON.stringify(pack), 'utf8');
    if (size > 2.5 * 1024 * 1024) {
      throw Object.assign(new Error('pack too large'), { status: 400 });
    }
    writeJsonAtomic(target, pack);
    fileCache.delete(target);
    if (isFirebaseReady()) {
      await syncRemote(id === 'crops' ? 'crops' : id, {
        ...pack,
        hash: pack.hash,
      });
    }
    return { cropId: id, count: pack.posts.length, version: pack.version, stamp: stampOf(pack, id) };
  },
};
