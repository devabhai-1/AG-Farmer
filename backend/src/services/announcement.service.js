import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { isFirebaseReady, rootRef } from '../config/firebase.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const filePath = path.resolve(__dirname, '../../data/announcements.json');
const MAX = 80;

function readFile() {
  try {
    const raw = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    return Array.isArray(raw.posts) ? raw.posts : [];
  } catch {
    return [];
  }
}

function sortNewest(posts) {
  return [...posts].sort((a, b) => (b.createdAt || 0) - (a.createdAt || 0));
}

function clean(text, max) {
  return String(text || '').replace(/\r/g, '').trim().slice(0, max);
}

function publicPost(post) {
  return {
    id: post.id,
    cropId: post.cropId || 'all',
    titleHi: post.titleHi || '',
    bodyHi: post.bodyHi || '',
    active: post.active !== false,
    createdAt: post.createdAt || 0,
  };
}

async function readRemote() {
  if (!isFirebaseReady()) return null;
  const snap = await rootRef('announcements').get();
  if (!snap.exists()) return null;
  const val = snap.val() || {};
  return sortNewest(Object.values(val).filter((post) => post && post.id));
}

async function writeAll(posts) {
  const next = sortNewest(posts).slice(0, MAX);
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, JSON.stringify({ posts: next }, null, 2));
  if (!isFirebaseReady()) return next;
  const map = {};
  for (const post of next) {
    if (post?.id) map[post.id] = post;
  }
  await rootRef('announcements').set(map);
  return next;
}

async function load() {
  const remote = await readRemote();
  if (remote) return remote;
  return sortNewest(readFile());
}

export const AnnouncementService = {
  async list() {
    const posts = (await load()).map(publicPost);
    return { posts };
  },

  async create({ cropId, titleHi, bodyHi }) {
    const title = clean(titleHi, 90);
    const body = clean(bodyHi, 700);
    if (!title || !body) {
      throw Object.assign(new Error('शीर्षक और संदेश दोनों लिखो'), { status: 400 });
    }
    const crop = String(cropId || 'all')
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9_]/g, '') || 'all';
    const posts = await load();
    const post = {
      id: `ann_${Date.now().toString(36)}`,
      cropId: crop,
      titleHi: title,
      bodyHi: body,
      active: true,
      createdAt: Date.now(),
    };
    const next = await writeAll([post, ...posts]);
    return { post: publicPost(post), posts: next.map(publicPost) };
  },

  async setActive(id, active) {
    const key = String(id || '').trim();
    const posts = await load();
    const index = posts.findIndex((post) => post.id === key);
    if (index < 0) {
      throw Object.assign(new Error('घोषणा नहीं मिली'), { status: 404 });
    }
    posts[index] = { ...posts[index], active: Boolean(active) };
    const next = await writeAll(posts);
    return { posts: next.map(publicPost) };
  },
};
