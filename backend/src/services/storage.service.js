import { randomUUID } from 'crypto';
import { bucket, isFirebaseReady } from '../config/firebase.js';
import { env } from '../config/env.js';
import { parseGeo } from '../utils/geo.js';

const FOLDER_MAP = {
  chat: () => env.storageFolders.chatImages,
  crop_log: () => env.storageFolders.cropLogs,
  profile: () => env.storageFolders.profiles,
};

function safeExt(filename = '', contentType = '') {
  const fromName = pathExt(filename);
  if (fromName) return fromName;
  if (contentType.includes('png')) return 'png';
  if (contentType.includes('webp')) return 'webp';
  if (contentType.includes('jpeg') || contentType.includes('jpg')) return 'jpg';
  return 'bin';
}

function pathExt(name) {
  const i = String(name).lastIndexOf('.');
  if (i < 0) return '';
  return String(name)
    .slice(i + 1)
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '')
    .slice(0, 8);
}

export const StorageService = {
  folders: FOLDER_MAP,

  /** Create a signed write URL so the app can upload directly to Storage */
  async createUploadUrl({
    uid,
    kind = 'chat',
    filename = 'upload.jpg',
    contentType = 'image/jpeg',
    expiresMinutes = 15,
  }) {
    if (!isFirebaseReady()) throw new Error('Firebase Storage not ready');
    if (!uid) throw new Error('uid required');

    const folderFn = FOLDER_MAP[kind] || FOLDER_MAP.chat;
    const folder = folderFn();
    const ext = safeExt(filename, contentType);
    const objectPath = `${folder}/${uid}/${Date.now()}_${randomUUID().slice(0, 8)}.${ext}`;

    const file = bucket().file(objectPath);
    const expires = Date.now() + Math.max(1, expiresMinutes) * 60 * 1000;

    const [uploadUrl] = await file.getSignedUrl({
      version: 'v4',
      action: 'write',
      expires,
      contentType,
    });

    const publicUrl = `https://firebasestorage.googleapis.com/v0/b/${env.storageBucket}/o/${encodeURIComponent(objectPath)}?alt=media`;

    return {
      objectPath,
      uploadUrl,
      contentType,
      expiresAt: new Date(expires).toISOString(),
      publicUrl,
      bucket: env.storageBucket,
    };
  },

  /**
   * Direct server-side upload with base64 payload.
   * Saves to Firebase Storage and generates a persistent download URL with token.
   */
  async uploadDirect({
    uid,
    base64,
    kind = 'chat',
    filename = 'upload.jpg',
    contentType = 'image/jpeg',
    lat = null,
    lon = null,
  }) {
    if (!isFirebaseReady()) throw new Error('Firebase Storage not ready');
    if (!uid) throw new Error('uid required');
    if (!base64) throw new Error('base64 required');

    const folderFn = FOLDER_MAP[kind] || FOLDER_MAP.chat;
    const folder = folderFn();
    const ext = safeExt(filename, contentType);
    const objectPath = `${folder}/${uid}/${Date.now()}_${randomUUID().slice(0, 8)}.${ext}`;
    const cleanBase64 = String(base64).replace(/^data:[^;]+;base64,/, '');
    const buf = Buffer.from(cleanBase64, 'base64');
    const geo = parseGeo(lat, lon);
    const downloadToken = randomUUID();

    const file = bucket().file(objectPath);
    await file.save(buf, {
      contentType,
      metadata: {
        metadata: {
          firebaseStorageDownloadTokens: downloadToken,
          uid: String(uid),
          ...(geo ? { lat: String(geo.lat), lon: String(geo.lon) } : {}),
        },
      },
    });

    const publicUrl = `https://firebasestorage.googleapis.com/v0/b/${env.storageBucket}/o/${encodeURIComponent(objectPath)}?alt=media&token=${downloadToken}`;

    return {
      objectPath,
      publicUrl,
      downloadToken,
      size: buf.length,
      contentType,
      bucket: env.storageBucket,
      lat: geo?.lat ?? null,
      lon: geo?.lon ?? null,
    };
  },

  /** Signed read URL for private files */
  async createDownloadUrl(objectPath, expiresMinutes = 60) {
    if (!isFirebaseReady()) throw new Error('Firebase Storage not ready');
    if (!objectPath) throw new Error('objectPath required');

    const file = bucket().file(objectPath);
    const [exists] = await file.exists();
    if (!exists) throw Object.assign(new Error('File not found'), { status: 404 });

    const expires = Date.now() + Math.max(1, expiresMinutes) * 60 * 1000;
    const [downloadUrl] = await file.getSignedUrl({
      version: 'v4',
      action: 'read',
      expires,
    });

    return {
      objectPath,
      downloadUrl,
      expiresAt: new Date(expires).toISOString(),
    };
  },

  async deleteObject(objectPath) {
    if (!isFirebaseReady()) throw new Error('Firebase Storage not ready');
    if (!objectPath) throw new Error('objectPath required');
    await bucket().file(objectPath).delete({ ignoreNotFound: true });
    return { deleted: true, objectPath };
  },

  async listUserFiles(uid, kind = 'chat', max = 50) {
    if (!isFirebaseReady()) throw new Error('Firebase Storage not ready');
    if (!uid) throw new Error('uid required');
    const folderFn = FOLDER_MAP[kind] || FOLDER_MAP.chat;
    const prefix = `${folderFn()}/${uid}/`;
    const [files] = await bucket().getFiles({ prefix, maxResults: max });
    return files.map((f) => {
      const extra = f.metadata?.metadata || {};
      const geo = parseGeo(extra.lat, extra.lon);
      return {
        objectPath: f.name,
        size: Number(f.metadata?.size || 0),
        contentType: f.metadata?.contentType || null,
        updated: f.metadata?.updated || null,
        lat: geo?.lat ?? null,
        lon: geo?.lon ?? null,
      };
    });
  },
};
