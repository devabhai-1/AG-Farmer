import crypto from 'crypto';
import { rootRef, isFirebaseReady } from '../config/firebase.js';

function makeLiveToken() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const bytes = crypto.randomBytes(8);
  let code = '';
  for (let i = 0; i < 8; i += 1) code += alphabet[bytes[i] % alphabet.length];
  return `AGRO-LIVE-${code}`;
}

export const SupportService = {
  async list(status) {
    if (!isFirebaseReady()) return {};
    const snap = await rootRef('support_requests').get();
    const all = snap.val() || {};
    if (!status) return all;
    return Object.fromEntries(
      Object.entries(all).filter(([, v]) => v?.status === status),
    );
  },

  async listByUid(uid) {
    const all = await this.list();
    return Object.fromEntries(
      Object.entries(all).filter(([, v]) => v?.uid === uid),
    );
  },

  async create(payload) {
    if (!isFirebaseReady()) {
      throw Object.assign(new Error('service_unavailable'), { status: 503 });
    }
    const ref = rootRef('support_requests').push();
    const id = ref.key;
    const row = {
      ...payload,
      id,
      uid: payload.uid || null,
      token: makeLiveToken(),
      userEmail: String(payload.userEmail || payload.email || '').toLowerCase() || null,
      status: payload.status || 'pending',
      createdAt: payload.createdAt || new Date().toISOString(),
      updatedAt: Date.now(),
    };
    await ref.set(row);
    if (row.uid) {
      await rootRef(`users/${row.uid}/support/${id}`).set(row);
    }
    return row;
  },

  async get(id) {
    if (!isFirebaseReady()) return null;
    const snap = await rootRef(`support_requests/${id}`).get();
    return snap.val();
  },

  async updateStatus(id, { status, adminNote }) {
    if (!isFirebaseReady()) {
      throw Object.assign(new Error('service_unavailable'), { status: 503 });
    }
    const patch = { status, updatedAt: Date.now() };
    if (adminNote !== undefined) patch.adminNote = adminNote;
    await rootRef(`support_requests/${id}`).update(patch);
    return this.get(id);
  },
};
