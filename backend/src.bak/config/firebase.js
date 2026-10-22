import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import admin from 'firebase-admin';
import { env } from './env.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function resolveCredentialsPath() {
  const fromEnv = env.credentialsPath;
  if (path.isAbsolute(fromEnv)) return fromEnv;
  return path.resolve(__dirname, '../../', fromEnv);
}

let ready = false;

export function initFirebase() {
  if (admin.apps.length) return admin;

  const keyPath = resolveCredentialsPath();

  try {
    if (fs.existsSync(keyPath)) {
      const serviceAccount = JSON.parse(fs.readFileSync(keyPath, 'utf8'));
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        databaseURL: env.databaseURL,
        storageBucket: env.storageBucket,
        projectId: env.projectId,
      });
      ready = true;
      console.log(
        `[firebase] ready → project=${env.projectId} rtdb=/${env.rtdbRoot} bucket=${env.storageBucket}`,
      );
      // Do not copy agro_gpt back into ag_farmer. A cleared tree must stay empty.
    } else {
      console.warn(
        `[firebase] ${path.basename(keyPath)} missing — download from Firebase Console (ag-farmer1) and place at backend/serviceAccountKey.json`,
      );
    }
  } catch (err) {
    ready = false;
    console.warn('[firebase] init failed:', err.message);
  }

  return admin;
}

export function isFirebaseReady() {
  return ready && admin.apps.length > 0;
}

export function db() {
  if (!isFirebaseReady()) {
    throw new Error('Firebase not ready. Add backend/serviceAccountKey.json for ag-farmer1');
  }
  return admin.database();
}

export function auth() {
  if (!isFirebaseReady()) {
    throw new Error('Firebase Auth not ready. Add backend/serviceAccountKey.json for ag-farmer1');
  }
  return admin.auth();
}

export function bucket() {
  if (!isFirebaseReady()) {
    throw new Error('Firebase Storage not ready. Add backend/serviceAccountKey.json for ag-farmer1');
  }
  return admin.storage().bucket(env.storageBucket);
}

export function rootRef(subPath = '') {
  const full = subPath ? `${env.rtdbRoot}/${subPath}` : env.rtdbRoot;
  return db().ref(full);
}

/** Public config for app — NEVER expose Firebase client keys / DB / storage / project id */
export function publicAuthConfig() {
  return {
    mode: 'backend_otp',
  };
}
