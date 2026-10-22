import { Router } from 'express';
import { asyncHandler, ok, fail } from '../middleware/response.js';
import { CatalogService } from '../services/catalog.service.js';
import { UserService } from '../services/user.service.js';
import { SupportService } from '../services/support.service.js';
import { AdminService } from '../services/admin.service.js';
import { TrackService } from '../services/track.service.js';
import { ChatService } from '../services/chat.service.js';
import { GeminiLiveService } from '../services/gemini_live.service.js';
import { IpChatService } from '../services/ip_chat.service.js';
import { AuthPhoneService } from '../services/auth.service.js';
import { OtpAuthService } from '../services/otp.service.js';
import { EmailAuthService } from '../services/email_auth.service.js';
import { verifyAppToken } from '../services/jwt.service.js';
import { StorageService } from '../services/storage.service.js';
import { env } from '../config/env.js';
import { initFirebase, isFirebaseReady, publicAuthConfig, rootRef } from '../config/firebase.js';
import { toPublicErrorMessage } from '../services/public_errors.js';
import { ChatLimitsService } from '../services/chat_limits.service.js';
import { WeatherService } from '../services/weather.service.js';
import { CreditService, isDistributorPlan, planOfUser } from '../services/credit.service.js';
import { UserActivityService } from '../services/user_activity.service.js';
import { saveFcmToken } from '../services/course_daily_summary.service.js';
import { adminKeyMatches } from '../utils/admin_key.js';
import { JankariService } from '../services/jankari.service.js';
import { JankariSearchService } from '../services/jankari_search.service.js';
import { AnnouncementService } from '../services/announcement.service.js';

const router = Router();

/**
 * SINGLE API ADDRESS — everything goes through POST /api
 * Body: { "action": "...", ...payload }
 * Optional: Authorization: Bearer <appJwt from auth.otp.verify>
 * Optional admin: header x-admin-key OR body.adminKey
 */
router.post(
  '/',
  asyncHandler(async (req, res) => {
    const action = String(req.body?.action || '').trim();
    if (!action) {
      return fail(res, 400, 'action required. Example: { "action": "health" }');
    }

    const data = req.body || {};
    const user = await resolveUser(req);
    const isAdmin = checkAdmin(req, data);

    try {
      const result = await dispatch(action, data, { user, isAdmin, req });
      UserActivityService.record({
        uid: user?.uid || result?.uid || null,
        email: user?.email || result?.email || data.email || null,
        ip: req.clientIp,
        action,
        data,
        result,
        ok: true,
      }).catch(() => {});
      return ok(res, { action, ...wrap(result) });
    } catch (err) {
      const status = err.status || (err.message?.includes('Unauthorized') ? 401 : 400);
      const lang = data.lang === 'en' || data.isHi === false ? 'en' : 'hi';
      const code = String(err.message || '');
      if (
        status >= 400 &&
        status < 500 &&
        (/^[a-z][a-z0-9_.]{1,64}$/.test(code) || code === 'email_in_use')
      ) {
        console.warn(`[api] ${action}: ${code}`);
      } else {
        console.error(`[api] ${action} failed:`, err.message);
      }
      UserActivityService.record({
        uid: user?.uid || null,
        email: user?.email || data.email || null,
        ip: req.clientIp,
        action,
        data,
        ok: false,
        error: code || 'failed',
      }).catch(() => {});
      return fail(res, status, toPublicErrorMessage(err, { lang }), { lang });
    }
  }),
);

/** Same gateway also accepts GET /api?action=health for quick checks */
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const action = String(req.query.action || 'health').trim();
    if (!GET_ACTIONS.has(action)) {
      return fail(res, 405, 'method_not_allowed', { lang: 'hi' });
    }
    try {
      const result = await dispatch(action, { ...req.query }, { user: null, isAdmin: false, req });
      return ok(res, { action, ...wrap(result) });
    } catch (err) {
      console.error(`[api] ${action} failed:`, err.message);
      return fail(res, err.status || 400, toPublicErrorMessage(err), { lang: 'hi' });
    }
  }),
);

function wrap(result) {
  if (result == null) return { data: null };
  if (typeof result !== 'object' || Array.isArray(result)) return { data: result };
  return result;
}

function checkAdmin(req, data) {
  const key = req.header('x-admin-key') || data.adminKey;
  return adminKeyMatches(key);
}

const GET_ACTIONS = new Set([
  'health',
  'config',
  'firebase.config',
  'actions',
  'catalog.all',
  'catalog.plans',
  'catalog.crops',
  'catalog.crop',
  'jankari.list',
  'jankari.search',
  'jankari.meta',
  'announcement.list',
  'weather.search',
  'weather.forecast',
  'chat.limits',
]);

async function resolveUser(req) {
  const header = req.header('authorization') || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : req.body?.idToken || null;
  if (!token) return null;

  // Prefer backend JWT (OTP login)
  const appUser = verifyAppToken(token);
  if (appUser?.uid) {
    return {
      uid: appUser.uid,
      email: appUser.email || null,
      phone_number: appUser.phone || null,
      provider: appUser.provider || 'phone',
    };
  }

  // Legacy Firebase ID token (if still sent)
  try {
    const admin = initFirebase();
    if (!admin.apps.length) return null;
    return await admin.auth().verifyIdToken(token);
  } catch {
    return null;
  }
}

function requireUser(user) {
  if (!user?.uid) {
    const e = new Error('Login required — send Authorization: Bearer <token>');
    e.status = 401;
    throw e;
  }
  return user;
}

function requireAdmin(isAdmin) {
  if (!isAdmin) {
    const e = new Error('Unauthorized admin');
    e.status = 401;
    throw e;
  }
}

async function dispatch(action, data, ctx) {
  const { user, isAdmin } = ctx;

  switch (action) {
    // ── Core ──
    case 'health': {
      // Public health — no vendor/model/DB names. Admin gets richer status.
      const base = {
        service: 'AG Farmer',
        ok: true,
        ready: isFirebaseReady(),
        time: new Date().toISOString(),
        quota: ChatService.quotaStatus({
          ip: ctx.req.clientIp,
          uid: user?.uid || null,
          email: user?.email || null,
        }),
      };
      if (isAdmin) {
        return {
          ...base,
          rtdb: { root: env.rtdbRoot, ready: isFirebaseReady() },
          ai: {
            expertReady: Boolean(env.openaiApiKey),
            highReady: Boolean(env.geminiApiKey),
            default: env.aiProvider === 'gemini' ? 'AG High' : 'AG Expert',
          },
          models: {
            agHigh: {
              chatAdvanced: env.geminiChatAdvancedModel,
              chatLow: env.geminiChatLowModel,
              imageAdvanced: env.geminiImageAdvancedModel,
              imageLow: env.geminiImageLowModel,
            },
            agExpert: {
              chatAdvanced: env.openaiChatAdvancedModel,
              chatLow: env.openaiChatLowModel,
              imageAdvanced: env.openaiImageAdvancedModel,
              imageLow: env.openaiImageLowModel,
            },
          },
        };
      }
      return base;
    }

    case 'config':
    case 'firebase.config':
      return {
        authMode: 'backend_email',
        auth: {
          ...publicAuthConfig(),
          googleClientId: env.googleClientId,
        },
        phoneAuth: {
          enabled: false,
          defaultCountry: env.defaultCountryCode,
        },
        apiUrl: env.publicApiUrl,
      };

    case 'actions':
      return {
        actions: [
          'health',
          'config',
          'auth.register',
          'auth.login',
          'auth.google',
          'auth.profile.complete',
          'auth.password.forgot',
          'auth.password.reset',
          'auth.otp.send',
          'auth.otp.verify',
          'auth.phone.lookup',
          'auth.verify',
          'auth.revoke',
          'storage.upload',
          'storage.download',
          'storage.list',
          'storage.delete',
          'catalog.all',
          'catalog.plans',
          'catalog.crops',
          'catalog.crop',
          'jankari.list',
          'jankari.search',
          'jankari.meta',
          'announcement.list',
          'chat',
          'chat.sync',
          'chat.restore',
          'notify.token',
          'chat.sessions',
          'chat.sessions.list',
          'chat.sessions.create',
          'activity.log',
          'ai.quota',
          'quota',
          'ip.lookup.email',
          'ip.lookup.self',
          'users.me',
          'users.me.update',
          'users.me.delete',
          'support.create',
          'support.mine',
          'tracks.list',
          'tracks.save',
          'tracks.log',
          'tracks.delete',
          'report.create',
          'admin.unlock.me',
          'admin.unlock.self',
          'admin.users',
          'admin.subscription',
          'admin.ai.user',
          'admin.ai.control',
          'admin.support.list',
          'admin.support.update',
          'admin.unlock.get',
          'admin.unlock.grant',
          'admin.unlock.revoke',
          'admin.catalog.plans.set',
          'admin.catalog.crops.set',
          'admin.phone.ensure',
          'admin.chat.limits.get',
          'admin.chat.limits.set',
          'chat.limits',
          'weather.forecast',
          'weather.search',
        ],
      };

    // ── Auth: email / Google (preferred) + optional OTP ──
    case 'auth.register': {
      const result = await EmailAuthService.register({
        name: data.name,
        email: data.email,
        password: data.password,
        phone: data.phone,
        address: data.address,
        age: data.age,
        acceptedPolicy: data.acceptedPolicy,
        ip: ctx.req.clientIp,
      });
      try {
        await ChatService.bindIp({
          ip: ctx.req.clientIp,
          uid: result.uid,
          email: result.email,
        });
      } catch {
        console.warn('[register] chat link skipped');
      }
      return result;
    }

    case 'auth.login': {
      const result = await EmailAuthService.login({
        email: data.email,
        password: data.password,
        ip: ctx.req.clientIp,
      });
      try {
        await ChatService.bindIp({
          ip: ctx.req.clientIp,
          uid: result.uid,
          email: result.email,
        });
        await ChatService.sync({
          ip: ctx.req.clientIp,
          messages: [],
          uid: result.uid,
          email: result.email,
        });
      } catch {
        console.warn('[login] chat link skipped');
      }
      return result;
    }

    case 'auth.google': {
      const result = await EmailAuthService.loginWithGoogle({
        idToken: data.idToken || data.googleIdToken,
        name: data.name,
        phone: data.phone,
        age: data.age,
        acceptedPolicy: data.acceptedPolicy,
      });
      try {
        await ChatService.bindIp({
          ip: ctx.req.clientIp,
          uid: result.uid,
          email: result.email,
        });
      } catch {
        console.warn('[google] chat link skipped');
      }
      return result;
    }

    case 'auth.profile.complete':
      requireUser(user);
      return EmailAuthService.completeProfile(user.uid, {
        phone: data.phone,
        age: data.age,
        acceptedPolicy: data.acceptedPolicy,
        name: data.name,
      });

    case 'auth.password.forgot':
      return EmailAuthService.forgotPassword({ email: data.email });

    case 'auth.password.reset':
      return EmailAuthService.resetPassword({
        email: data.email,
        code: data.code || data.otp,
        newPassword: data.newPassword || data.password,
      });

    case 'auth.otp.send':
      return OtpAuthService.send({ phone: data.phone });

    case 'auth.otp.verify': {
      const result = await OtpAuthService.verify({
        phone: data.phone,
        otp: data.otp || data.smsCode || data.code,
        requestId: data.requestId || data.verificationId,
        name: data.name || '',
      });
      try {
        await ChatService.bindIp({
          ip: ctx.req.clientIp,
          uid: result.uid,
          email: result.email || null,
        });
      } catch {
        console.warn('[otp] chat link skipped');
      }
      return result;
    }

    case 'auth.phone.lookup':
      return AuthPhoneService.lookupByPhone(data.phone);

    case 'auth.verify': {
      const idToken = data.idToken || ctx.req.header('authorization')?.replace(/^Bearer\s+/i, '');
      if (!idToken) throw Object.assign(new Error('idToken required'), { status: 400 });
      return AuthPhoneService.verifyIdToken(idToken);
    }

    case 'auth.revoke':
      requireUser(user);
      return AuthPhoneService.revokeSessions(user.uid);

    case 'admin.phone.ensure':
      requireAdmin(isAdmin);
      return AuthPhoneService.ensurePhoneUser(data.phone, { name: data.name || '' });

    // ── Storage (backend manages Firebase Storage) ──
    case 'storage.upload':
    case 'storage.upload-url':
    case 'storage.uploadUrl':
      requireUser(user);
      return StorageService.createUploadUrl({
        uid: user.uid,
        kind: data.kind || 'chat',
        filename: data.filename || 'upload.jpg',
        contentType: data.contentType || 'image/jpeg',
        expiresMinutes: data.expiresMinutes,
      });

    case 'storage.download':
    case 'storage.download-url':
    case 'storage.downloadUrl':
      requireUser(user);
      if (!data.objectPath) throw new Error('objectPath required');
      return StorageService.createDownloadUrl(data.objectPath, data.expiresMinutes);

    case 'storage.list':
    case 'storage.my-files':
      requireUser(user);
      return {
        files: await StorageService.listUserFiles(user.uid, data.kind || 'chat', Number(data.limit) || 50),
      };

    case 'storage.delete': {
      requireUser(user);
      if (!data.objectPath) throw new Error('objectPath required');
      if (!String(data.objectPath).includes(`/${user.uid}/`)) {
        throw Object.assign(new Error('Not allowed to delete this file'), { status: 403 });
      }
      return StorageService.deleteObject(data.objectPath);
    }

    // ── Catalog ──
    case 'catalog.all':
      return CatalogService.getAll();

    case 'catalog.plans':
      return { plans: await CatalogService.getPlans() };

    case 'catalog.crops':
      return { crops: await CatalogService.getCrops() };

    case 'catalog.crop': {
      const crop = await CatalogService.getCrop(data.id || data.cropId);
      if (!crop) throw Object.assign(new Error('Crop not found'), { status: 404 });
      return { crop };
    }

    case 'jankari.list':
      return JankariService.list(data.cropId || data.id || 'afim');

    case 'jankari.meta':
      return JankariService.meta(data.cropId || data.id || 'all');

    case 'jankari.search':
      return JankariSearchService.search({
        q: data.q || data.query || data.text,
        cropId: data.cropId || data.id || 'all',
        limit: data.limit,
      });

    case 'announcement.list':
      return AnnouncementService.list();

    case 'admin.announcement.create':
      requireAdmin(isAdmin);
      return AnnouncementService.create({
        cropId: data.cropId,
        titleHi: data.titleHi || data.title,
        bodyHi: data.bodyHi || data.body,
      });

    case 'admin.announcement.set':
      requireAdmin(isAdmin);
      return AnnouncementService.setActive(data.id, data.active !== false);

    // ── Chat ──
    case 'chat':
      return ChatService.reply({
        message: data.message || data.text || data.query,
        lang: data.lang || (data.isHi === false ? 'en' : 'hi'),
        cropId: data.cropId || null,
        planId: data.planId || null,
        mode: data.mode === 'course' ? 'course' : 'chat',
        history: Array.isArray(data.history) ? data.history : [],
        uid: user?.uid || null,
        email: user?.email || null,
        ip: ctx.req.clientIp,
        provider: data.provider || data.aiProvider || data.model || null,
        images: data.images || null,
        imageBase64: data.imageBase64 || data.image || null,
        sessionId: data.sessionId || data.chatId || null,
        chatName: data.chatName || data.sessionName || null,
        deepResearch: data.deepResearch === true || data.deep === true,
        hasImage: Boolean(
          data.hasImage ||
            data.imageBase64 ||
            data.image ||
            (Array.isArray(data.images) && data.images.length),
        ),
      });

    case 'credit.status': {
      requireUser(user);
      return { wallet: CreditService.wallet(user.uid) };
    }

    case 'credit.redeem': {
      requireUser(user);
      return CreditService.redeem(user.uid, data.code || data.token);
    }

    case 'credit.create': {
      const voiceN = Number(data.voice) || 0;
      const videoN = Number(data.video) || 0;
      if (!isAdmin) {
        requireUser(user);
        const plan = await planOfUser(user.uid);
        if (!isDistributorPlan(plan)) {
          const err = new Error('voice_upgrade');
          err.status = 403;
          throw err;
        }
      }
      return CreditService.createToken({
        voice: voiceN,
        video: videoN,
        by: isAdmin ? 'admin' : user.uid,
      });
    }

    case 'admin.credit.list':
      requireAdmin(isAdmin);
      return { tokens: CreditService.list() };

    case 'voice.realtime.session':
      return GeminiLiveService.createClientSecret({
        lang: data.lang || (data.isHi === false ? 'en' : 'hi'),
        cropId: data.cropId || null,
        uid: user?.uid || null,
        email: user?.email || null,
        ip: ctx.req.clientIp,
        planId: data.planId || null,
        recent: Array.isArray(data.recent) ? data.recent : [],
        mode: data.mode === 'video' ? 'video' : 'voice',
      });

    case 'ai.quota':
    case 'quota':
      return ChatService.quotaStatus({
        ip: ctx.req.clientIp,
        uid: user?.uid || null,
        email: user?.email || null,
        planId: data.planId || null,
      });

    case 'chat.sync': {
      const msgs = Array.isArray(data.messages) ? data.messages : [];
      return ChatService.sync({
        ip: ctx.req.clientIp,
        messages: msgs,
        uid: user?.uid || null,
        email: user?.email || null,
        mode: data.mode || 'chat',
        cropId: data.cropId || null,
        sessionId: data.sessionId || data.chatId || null,
        chatName: data.chatName || data.sessionName || null,
      });
    }

    case 'notify.token': {
      requireUser(user);
      return saveFcmToken({
        uid: user.uid,
        email: user.email,
        token: data.token,
      });
    }

    case 'chat.restore':
      return ChatService.restore({
        ip: ctx.req.clientIp,
        uid: user?.uid || null,
        email: user?.email || null,
        mode: data.mode || 'chat',
        cropId: data.cropId || null,
        sessionId: data.sessionId || data.chatId || null,
        limit: Number(data.limit) || 400,
      });

    case 'chat.sessions':
    case 'chat.sessions.list': {
      requireUser(user);
      return ChatService.listSessions({
        uid: user.uid,
        email: user.email,
        ip: ctx.req.clientIp,
        mode: data.mode || 'chat',
      });
    }

    case 'chat.sessions.create': {
      requireUser(user);
      return ChatService.createSession({
        uid: user.uid,
        email: user.email,
        ip: ctx.req.clientIp,
        sessionId: data.sessionId || data.chatId || null,
        chatName: data.chatName || data.name || data.sessionName || null,
      });
    }

    case 'activity.log': {
      requireUser(user);
      const saved = await UserActivityService.record({
        uid: user.uid,
        email: user.email,
        ip: ctx.req.clientIp,
        action: data.type || data.kind || 'client',
        type: data.type || data.kind || 'client',
        data: data.detail && typeof data.detail === 'object' ? data.detail : data,
        ok: true,
      });
      if (data.state && typeof data.state === 'object') {
        await UserActivityService.saveState({
          uid: user.uid,
          email: user.email,
          patch: data.state,
        });
      }
      return { activity: saved };
    }

    case 'ip.lookup.self':
      return IpChatService.lookupByIp(ctx.req.clientIp);

    case 'ip.lookup.email': {
      requireAdmin(isAdmin);
      return IpChatService.lookupByEmail(data.email);
    }

    // ── Users ──
    case 'users.me':
      requireUser(user);
      return { user: await UserService.get(user.uid) };

    case 'users.me.delete': {
      requireUser(user);
      return UserService.remove(user.uid);
    }

    case 'users.me.update': {
      requireUser(user);
      const allowed = [
        'name',
        'phone',
        'address',
        'age',
        'language',
        'theme',
        'aiProvider',
        'selectedCropIds',
        'provider',
        'profileComplete',
        'plan',
        'subscription',
      ];
      const patch = {};
      for (const k of allowed) {
        if (data[k] !== undefined) patch[k] = data[k];
      }
      return { user: await UserService.update(user.uid, patch, { email: user.email }) };
    }

    case 'support.create': {
      requireUser(user);
      const row = await SupportService.create({
        uid: user.uid,
        userName: data.userName || '',
        userPhone: data.userPhone || '',
        userEmail: user.email || data.userEmail || '',
        email: user.email || data.userEmail || '',
        planId: data.planId || 'free',
        token: data.token,
        message: data.message || 'Live support request',
        status: 'pending',
      });
      return { request: row };
    }

    case 'support.mine': {
      requireUser(user);
      return { requests: await SupportService.listByUid(user.uid) };
    }

    case 'admin.unlock.self': {
      requireUser(user);
      const unlock = await AdminService.grantUnlock(user.uid, {
        amount: data.amount,
        note: data.note || 'self_pay',
      });
      return { unlock };
    }

    case 'admin.unlock.me': {
      requireUser(user);
      return { unlock: await AdminService.getUnlock(user.uid) };
    }

    case 'tracks.delete':
      requireUser(user);
      if (!data.trackId) throw new Error('trackId required');
      return TrackService.remove(user.uid, data.trackId);

    case 'report.create': {
      requireUser(user);
      const ref = rootRef('ai_reports').push();
      const row = {
        id: ref.key,
        uid: user.uid,
        email: user.email || null,
        ...data.report,
        createdAt: Date.now(),
      };
      await ref.set(row);
      if (user.uid) {
        await rootRef(`users/${user.uid}/reports/${ref.key}`).set(row);
      }
      return { report: row };
    }

    // ── Tracks ──
    case 'tracks.list':
      requireUser(user);
      return { tracks: await TrackService.list(user.uid) };

    case 'tracks.save':
      requireUser(user);
      if (!data.trackId) throw new Error('trackId required');
      return {
        track: await TrackService.save(user.uid, data.trackId, data.track || data, {
          email: user.email,
        }),
      };

    case 'tracks.log':
      requireUser(user);
      if (!data.trackId || !data.dateKey) throw new Error('trackId and dateKey required');
      return {
        log: await TrackService.saveLog(user.uid, data.trackId, data.dateKey, data.log || data, {
          email: user.email,
        }),
      };

    // ── Admin ──
    case 'chat.limits':
      return { limits: ChatLimitsService.get() };

    case 'weather.search':
      return {
        places: await WeatherService.search(data.query || data.q || data.name),
      };

    case 'weather.forecast':
      return {
        weather: await WeatherService.forecast({
          lat: data.lat,
          lon: data.lon,
          ip: ctx.req?.clientIp,
          place: data.place,
          approximate: data.approximate === true,
          uid: ctx.user?.uid || null,
          email: ctx.user?.email || data.email || null,
        }),
      };

    case 'admin.chat.limits.get':
      requireAdmin(isAdmin);
      return { limits: ChatLimitsService.get() };

    case 'admin.chat.limits.set':
      requireAdmin(isAdmin);
      return { limits: ChatLimitsService.save(data.limits || data) };

    case 'admin.users':
      requireAdmin(isAdmin);
      return { users: await UserService.list(Number(data.limit) || 50) };

    case 'admin.subscription':
      requireAdmin(isAdmin);
      if (!data.uid || !data.planId) throw new Error('uid and planId required');
      return {
        user: await UserService.setSubscription(data.uid, {
          planId: data.planId,
          status: data.status || 'active',
          expiresAt: data.expiresAt || null,
        }),
      };

    case 'admin.ai.user':
      requireAdmin(isAdmin);
      return {
        user: await ChatService.adminUserContext({
          uid: data.uid,
          email: data.email,
        }),
      };

    case 'admin.ai.control':
      requireAdmin(isAdmin);
      if (!data.uid && !data.email) throw new Error('uid or email required');
      return {
        control: await ChatService.adminSetControl({
          uid: data.uid,
          email: data.email,
          patch: data.patch || data.control || {},
        }),
      };

    case 'admin.support.list':
      requireAdmin(isAdmin);
      return { requests: await SupportService.list(data.status) };

    case 'admin.support.update':
      requireAdmin(isAdmin);
      if (!data.id || !data.status) throw new Error('id and status required');
      return {
        request: await SupportService.updateStatus(data.id, {
          status: data.status,
          adminNote: data.adminNote,
        }),
      };

    case 'admin.unlock.get':
      requireAdmin(isAdmin);
      return { unlock: await AdminService.getUnlock(data.uid) };

    case 'admin.unlock.grant':
      requireAdmin(isAdmin);
      return { unlock: await AdminService.grantUnlock(data.uid, data) };

    case 'admin.unlock.revoke':
      requireAdmin(isAdmin);
      return { unlock: await AdminService.revokeUnlock(data.uid) };

    case 'admin.catalog.plans.set':
      requireAdmin(isAdmin);
      return { plans: await CatalogService.setPlans(data.plans || data) };

    case 'admin.catalog.crops.set':
      requireAdmin(isAdmin);
      return { crops: await CatalogService.setCrops(data.crops || data) };

    default:
      throw Object.assign(
        new Error(`Unknown action "${action}". Use action:"actions" to list all.`),
        { status: 400 },
      );
  }
}

export default router;
