import { Router } from 'express';
import { asyncHandler, ok, fail } from '../middleware/response.js';
import { CatalogService } from '../services/catalog.service.js';
import { UserService } from '../services/user.service.js';
import { SupportService } from '../services/support.service.js';
import { AdminService } from '../services/admin.service.js';
import { TrackService } from '../services/track.service.js';
import { ChatService } from '../services/chat.service.js';
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
import { AiQuotaService } from '../services/ai_quota.service.js';
import { WeatherService } from '../services/weather.service.js';
import { CreditService, isDistributorPlan, planOfUser } from '../services/credit.service.js';
import { UserActivityService } from '../services/user_activity.service.js';
import { istParts, saveFcmToken } from '../services/course_daily_summary.service.js';
import { adminKeyMatches } from '../utils/admin_key.js';
import { mergeSafe } from '../utils/rtdb_safe.js';
import { JankariService } from '../services/jankari.service.js';
import { JankariSearchService } from '../services/jankari_search.service.js';
import { AnnouncementService } from '../services/announcement.service.js';
import { RazorpayService } from '../services/razorpay.service.js';
import { assertCropAccess, assertPaidPlan } from '../services/access.service.js';
import { snapshot as metricsSnapshot } from '../middleware/metrics.js';
import { TtsService } from '../services/tts.service.js';
import { transcribeSpeech } from '../services/voice_transcribe.service.js';
import { limiterSnapshot } from '../middleware/ddos_protection.js';
import { PageAnalyticsService } from '../services/page_analytics.service.js';
import { rtdbGet } from '../services/rtdb_system.js';
import { AdminPeopleService } from '../services/admin_people.service.js';
import { recordProblem } from '../services/client_logs.service.js';
import { getScreens, saveScreens } from '../services/screen_pack.service.js';
import { CourseEnrollmentService } from '../services/course_enrollment.service.js';
import { CourseAheadService } from '../services/course_ahead.service.js';
import { assertOpen, getControls, setControls } from '../services/controls.service.js';
import { assertAppBuild, getAppRelease, setAppRelease } from '../services/app_release.service.js';
import { LoginSecurityService } from '../services/login_security.service.js';
import { IpBlockService } from '../services/ip_block.service.js';

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
    assertAppBuild(req, action);
    const user = await resolveUser(req);
    if (user?.uid) req.authUid = String(user.uid);
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
      if (String(action).startsWith('auth.')) {
        try {
          recordProblem({
            kind: 'login',
            code,
            message: code,
            screen: action,
            uid: user?.uid || null,
            ip: req.clientIp,
          });
        } catch {
          /* log file must not block the login response */
        }
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
  'screen.pack',
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
  if (!String(action || '').startsWith('admin.')) {
    if (IpBlockService.isBlocked(ctx.req?.clientIp)) {
      throw Object.assign(new Error('ip_blocked'), { status: 403 });
    }
    assertOpen(action, data);
  }

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
        features: getControls(),
        release: getAppRelease(),
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
          'jankari.tts',
          'announcement.list',
          'chat',
          'chat.sync',
          'chat.restore',
          'notify.token',
          'chat.sessions',
          'chat.sessions.list',
          'chat.sessions.create',
          'chat.sessions.delete',
          'activity.log',
          'analytics.page',
          'client.log',
          'screen.pack',
          'billing.checkout.create',
          'billing.checkout.verify',
          'support.create',
          'support.mine',
          'video.start',
          'tracks.list',
          'tracks.save',
          'tracks.log',
          'tracks.delete',
          'report.create',
          'presence.ping',
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
      ChatService.bindIp({
        ip: ctx.req.clientIp,
        uid: result.uid,
        email: result.email,
      }).catch(() => console.warn('[register] chat link skipped'));
      return result;
    }

    case 'auth.login': {
      const result = await EmailAuthService.login({
        email: data.email,
        password: data.password,
        ip: ctx.req.clientIp,
      });
      ChatService.bindIp({
        ip: ctx.req.clientIp,
        uid: result.uid,
        email: result.email,
      }).catch(() => console.warn('[login] chat link skipped'));
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
      ChatService.bindIp({
        ip: ctx.req.clientIp,
        uid: result.uid,
        email: result.email,
      }).catch(() => console.warn('[google] chat link skipped'));
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

    case 'auth.password.confirm':
      return EmailAuthService.confirmReset({
        oobCode: data.oobCode || data.code,
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
      if (!String(data.objectPath).includes(`/${user.uid}/`)) {
        throw Object.assign(new Error('Not allowed to read this file'), { status: 403 });
      }
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

    // Fasal Jankari is open without login. Courses, tracks and chat
    // keep their own gates (assertCropAccess).
    case 'jankari.list': {
      const cropId = data.cropId || data.id || 'afim';
      return JankariService.list(cropId);
    }

    case 'jankari.meta': {
      const cropId = data.cropId || data.id || 'all';
      return JankariService.meta(cropId);
    }

    case 'jankari.tts': {
      const controls = getControls();
      if (controls.jankariVoice !== 'openai' || !controls.openaiSpeech) {
        return { voice: 'device' };
      }
      return TtsService.article({
        postId: data.postId || data.id,
        cropId: data.cropId,
        lang: data.lang === 'en' || data.isHi === false ? 'en' : 'hi',
      });
    }

    case 'voice.speak': {
      requireUser(user);
      if (!getControls().openaiSpeech) {
        throw Object.assign(new Error('voice_closed'), { status: 403 });
      }
      return TtsService.speak({
        text: data.text,
        lang: data.lang === 'en' || data.isHi === false ? 'en' : 'hi',
      });
    }

    case 'tts.chatterbox.test': {
      if (!getControls().chatterbox) {
        throw Object.assign(new Error('voice_closed'), { status: 403 });
      }
      return TtsService.chatterboxTest({
        text: data.text,
        lang: data.lang === 'en' || data.isHi === false ? 'en' : 'hi',
      });
    }

    case 'voice.transcribe': {
      requireUser(user);
      return transcribeSpeech({
        audioBase64: data.audioBase64 || data.audio,
        lang: data.lang === 'en' || data.isHi === false ? 'en' : 'hi',
      });
    }

    case 'jankari.search': {
      const cropId = data.cropId || data.id || 'all';
      return JankariSearchService.search({
        q: data.q || data.query || data.text,
        cropId,
        limit: data.limit,
      });
    }

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
    case 'chat': {
      const message = String(data.message || data.text || data.query || '').slice(0, 4000);
      const images = Array.isArray(data.images) ? data.images.slice(0, 6) : null;
      const imageBase64 = data.imageBase64 || data.image || null;
      const hasImage = Boolean(
        data.hasImage || imageBase64 || (images && images.length),
      );
      if (!message.trim() && !hasImage) {
        throw Object.assign(new Error('bad_request'), { status: 400 });
      }
      return ChatService.reply({
        message,
        lang: data.lang || (data.isHi === false ? 'en' : 'hi'),
        cropId: data.cropId || null,
        planId: null,
        mode: data.mode === 'course' ? 'course' : 'chat',
        history: [],
        uid: user?.uid || null,
        email: user?.email || null,
        ip: ctx.req.clientIp,
        provider: data.provider || data.aiProvider || data.model || null,
        images,
        imageBase64,
        sessionId: data.sessionId || data.chatId || null,
        chatName: data.chatName || data.sessionName || null,
        deepResearch: data.deepResearch === true || data.deep === true,
        voice: data.voice === true,
        lat: data.lat ?? data.latitude ?? null,
        lon: data.lon ?? data.lng ?? data.longitude ?? null,
        place: data.place || data.location || null,
        hasImage,
      });
    }

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
      throw Object.assign(new Error('voice_live_unavailable'), { status: 410 });

    case 'ai.quota':
    case 'quota':
      return ChatService.quotaStatus({
        ip: ctx.req.clientIp,
        uid: user?.uid || null,
        email: user?.email || null,
        planId: data.planId || null,
      });

    case 'chat.sync': {
      requireUser(user);
      const all = Array.isArray(data.messages) ? data.messages : [];
      const courseMode = data.mode === 'course' || data.mode === 'fasal';
      const msgs = courseMode ? all.slice(-2000) : all.slice(-80);
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
      requireUser(user);
      return ChatService.restore({
        ip: ctx.req.clientIp,
        uid: user?.uid || null,
        email: user?.email || null,
        mode: data.mode || 'chat',
        cropId: data.cropId || null,
        sessionId: data.sessionId || data.chatId || null,
        limit: Math.min(
          data.mode === 'course' || data.mode === 'fasal' ? 2000 : 200,
          Math.max(1, Number(data.limit) || 80),
        ),
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

    case 'chat.sessions.delete': {
      requireUser(user);
      return ChatService.deleteSession({
        uid: user.uid,
        email: user.email,
        ip: ctx.req.clientIp,
        sessionId: data.sessionId || data.chatId || null,
      });
    }

    case 'presence.ping': {
      const uid = user?.uid || null;
      const email = user?.email || data.email || null;
      await IpChatService.bindIdentity({
        ip: ctx.req.clientIp,
        email: uid ? email : null,
        uid,
      });
      await UserActivityService.writeLive({
        uid,
        email: uid ? email : null,
        ip: ctx.req.clientIp,
        installId: data.installId,
        firstInstallAt: data.firstInstallAt,
        installCount: data.installCount,
        screen: data.screen || data.page,
      });
      return { ok: true };
    }

    case 'analytics.page':
      return PageAnalyticsService.hit({
        page: data.page || data.screen || data.name,
        extra: data.extra || data.cropId || data.crop || null,
        uid: user?.uid || null,
        ip: ctx.req.clientIp,
      });

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
        const state = { ...data.state };
        for (const key of [
          'plan',
          'planId',
          'subscription',
          'expiresAt',
          'autoRenew',
          'razorpaySubscriptionId',
        ]) {
          delete state[key];
        }
        await UserActivityService.saveState({
          uid: user.uid,
          email: user.email,
          patch: state,
        });
      }
      return { activity: saved };
    }

    case 'client.log':
      return recordProblem({
        kind: data.kind === 'layout' ? 'layout' : 'login',
        code: String(data.code || '').slice(0, 80),
        message: String(data.message || '').slice(0, 500),
        screen: data.screen || data.page,
        uid: user?.uid || null,
        ip: ctx.req.clientIp,
      });

    case 'screen.pack':
      return { screens: getScreens() };

    case 'admin.screens.set': {
      requireAdmin(isAdmin);
      const saved = saveScreens(data.screens);
      return { screens: saved };
    }

    case 'ip.lookup.self':
      requireAdmin(isAdmin);
      return IpChatService.lookupByIp(ctx.req.clientIp);

    case 'ip.lookup.email': {
      requireAdmin(isAdmin);
      return IpChatService.lookupByEmail(data.email);
    }

    // ── Users ──
    case 'users.me':
      requireUser(user);
      return { user: await RazorpayService.syncAccess(user.uid) };

    case 'users.me.delete': {
      requireUser(user);
      return UserService.scheduleDelete(user.uid);
    }

    case 'users.me.update': {
      requireUser(user);
      // Client may edit only these. plan/subscription/email/profileComplete/
      // provider are server-derived and must never be written from the client.
      const allowed = [
        'name',
        'phone',
        'address',
        'age',
        'language',
        'theme',
        'aiProvider',
        'selectedCropIds',
      ];
      const patch = {};
      for (const k of allowed) {
        if (data[k] !== undefined) patch[k] = data[k];
      }
      return { user: await UserService.update(user.uid, patch, { email: user.email }) };
    }

    case 'billing.subscription.create': {
      requireUser(user);
      return RazorpayService.createSubscription({
        uid: user.uid,
        email: user.email,
        planId: data.planId || data.plan,
      });
    }

    case 'billing.subscription.verify': {
      requireUser(user);
      return RazorpayService.verifySubscription({
        uid: user.uid,
        subscriptionId: data.subscriptionId,
        paymentId: data.paymentId,
        signature: data.signature,
      });
    }

    case 'billing.subscription.cancel': {
      requireUser(user);
      return RazorpayService.cancelSubscription({ uid: user.uid });
    }

    case 'billing.checkout.create': {
      requireUser(user);
      return RazorpayService.createCheckout({
        uid: user.uid,
        email: user.email,
        planId: data.planId || data.plan,
        cycle: data.cycle,
      });
    }

    case 'billing.checkout.verify': {
      requireUser(user);
      return RazorpayService.verifyCheckout({
        uid: user.uid,
        subscriptionId: data.subscriptionId,
        orderId: data.orderId,
        paymentId: data.paymentId,
        signature: data.signature,
      });
    }

    case 'support.create': {
      requireUser(user);
      const planId = await assertPaidPlan(user.uid);
      const profile = await UserService.get(user.uid);
      const row = await SupportService.create({
        uid: user.uid,
        userName: profile.name || '',
        userPhone: profile.phone || '',
        userEmail: user.email || profile.email || '',
        email: user.email || profile.email || '',
        planId,
        message: String(data.message || 'Live support request').slice(0, 500),
        status: 'pending',
      });
      return { request: row };
    }

    case 'support.mine': {
      requireUser(user);
      return { requests: await SupportService.listByUid(user.uid) };
    }

    case 'video.start': {
      requireUser(user);
      const planId = await UserService.effectivePlanId(user.uid);
      const profile = await UserService.get(user.uid);
      const email = user.email || profile.email || '';
      const gate = AiQuotaService.consumeVideo({
        ip: ctx.req?.clientIp,
        uid: user.uid,
        email,
        planId,
      });
      if (gate.blocked) {
        throw Object.assign(new Error(gate.reason || 'voice_upgrade'), { status: 403 });
      }
      return { video: gate };
    }

    case 'admin.unlock.self':
    case 'admin.unlock.me':
      throw Object.assign(new Error('gone'), { status: 410 });

    case 'tracks.delete':
      requireUser(user);
      if (!data.trackId) throw new Error('trackId required');
      return TrackService.remove(user.uid, data.trackId);

    case 'report.create': {
      // Login is optional. Play requires any user to flag AI output
      // without leaving the app, including before an account exists.
      const report =
        data.report && typeof data.report === 'object' && !Array.isArray(data.report)
          ? data.report
          : {};
      const clip = (value, max) =>
        String(value ?? '')
          .replace(/\s+/g, ' ')
          .trim()
          .slice(0, max);
      const reason = clip(report.reason, 200);
      if (!reason) {
        throw Object.assign(new Error('reason required'), { status: 400 });
      }
      const ref = rootRef('ai_reports').push();
      const row = {
        id: ref.key,
        uid: user?.uid || null,
        email: user?.email || null,
        createdAt: Date.now(),
        messageId: clip(report.messageId, 80),
        messageSnippet: clip(report.messageSnippet, 240),
        reason,
        source: clip(report.source, 24),
        app: clip(report.app, 24) || 'ag_live',
        reportedAt: clip(report.reportedAt, 40),
      };
      await ref.set(row);
      if (user?.uid) {
        await rootRef(`users/${user.uid}/reports/${ref.key}`).set(row);
      }
      return { report: row };
    }

    case 'courses.list':
      requireUser(user);
      return { courses: await CourseEnrollmentService.list(user.uid) };

    case 'courses.save':
      requireUser(user);
      return { course: await CourseEnrollmentService.save(user.uid, data) };

    case 'courses.ahead': {
      requireUser(user);
      return CourseAheadService.getOrBuild({
        uid: user.uid,
        cropId: data.cropId,
        lang: data.lang === 'en' ? 'en' : 'hi',
      });
    }

    case 'courses.seen':
      requireUser(user);
      return CourseEnrollmentService.markSeen(user.uid, data.cropId, istParts().day);

    case 'courses.remove':
      requireUser(user);
      return CourseEnrollmentService.remove(user.uid, data.cropId);

    case 'tracks.list':
      requireUser(user);
      return { tracks: await TrackService.list(user.uid) };

    case 'tracks.save':
      requireUser(user);
      if (!data.trackId) throw new Error('trackId required');
      await assertCropAccess({
        uid: user.uid,
        cropId: data.track?.cropId || data.cropId,
      });
      return {
        track: await TrackService.save(user.uid, data.trackId, data.track || data, {
          email: user.email,
        }),
      };

    case 'tracks.log':
      requireUser(user);
      if (!data.trackId || !data.dateKey) throw new Error('trackId and dateKey required');
      {
        let cropId = data.log?.cropId || data.cropId || data.track?.cropId;
        if (!cropId) {
          const saved = await rootRef(`users/${user.uid}/tracks/${data.trackId}`).get();
          cropId = saved.val()?.cropId;
        }
        await assertCropAccess({ uid: user.uid, cropId });
      }
      return {
        log: await TrackService.saveLog(user.uid, data.trackId, data.dateKey, data.log || data, {
          email: user.email,
        }),
      };

    // ── Admin ──
    case 'chat.limits':
      return { limits: ChatLimitsService.get() };

    case 'weather.search': {
      const query = String(data.query || data.q || data.name || '').trim().slice(0, 80);
      if (query.length < 2) return { places: [] };
      return { places: await WeatherService.search(query) };
    }

    case 'weather.forecast':
      return {
        weather: await WeatherService.forecast({
          lat: data.lat,
          lon: data.lon,
          ip: ctx.req?.clientIp,
          place: String(data.place || '').slice(0, 80),
          approximate: data.approximate === true,
          uid: user?.uid || null,
          email: user?.email || null,
        }),
      };

    case 'admin.metrics':
      requireAdmin(isAdmin);
      return { metrics: metricsSnapshot({ ddos: limiterSnapshot() }) };

    case 'admin.chat.limits.get':
      requireAdmin(isAdmin);
      return { limits: ChatLimitsService.get() };

    case 'admin.chat.limits.set':
      requireAdmin(isAdmin);
      return { limits: ChatLimitsService.save(data.limits || data) };

    case 'admin.users':
      requireAdmin(isAdmin);
      return { users: await UserService.list(Number(data.limit) || 50) };

    case 'admin.people.list':
      requireAdmin(isAdmin);
      return AdminPeopleService.list({
        limit: data.limit,
        hideBots: data.hideBots !== false,
      });

    case 'admin.controls.get':
      requireAdmin(isAdmin);
      return { controls: getControls(), release: getAppRelease() };

    case 'admin.controls.set':
      requireAdmin(isAdmin);
      return { controls: setControls(data.controls || data) };

    case 'admin.release.get':
      requireAdmin(isAdmin);
      return { release: getAppRelease() };

    case 'admin.release.set':
      requireAdmin(isAdmin);
      return { release: setAppRelease(data.release || data) };

    case 'admin.lockouts.list':
      requireAdmin(isAdmin);
      return { lockouts: LoginSecurityService.listLockouts() };

    case 'admin.lockouts.clear':
      requireAdmin(isAdmin);
      LoginSecurityService.clearLockout({ ip: data.ip, email: data.email });
      return { ok: true, lockouts: LoginSecurityService.listLockouts() };

    case 'admin.blocks.list':
      requireAdmin(isAdmin);
      return { blocks: IpBlockService.list() };

    case 'admin.blocks.add':
      requireAdmin(isAdmin);
      return { block: IpBlockService.block({ ip: data.ip, note: data.note }) };

    case 'admin.blocks.remove':
      requireAdmin(isAdmin);
      return IpBlockService.unblock({ ip: data.ip, ipHash: data.ipHash });

    case 'admin.reports.list': {
      requireAdmin(isAdmin);
      if (!isFirebaseReady()) return { reports: [] };
      const lim = Math.max(1, Math.min(100, Number(data.limit) || 40));
      const snap = await rootRef('ai_reports').limitToLast(lim).get();
      const val = snap.val() || {};
      const reports = Object.values(val)
        .filter((r) => r && typeof r === 'object')
        .sort((a, b) => (b.createdAt || 0) - (a.createdAt || 0));
      return { reports };
    }

    case 'admin.jankari.meta':
      requireAdmin(isAdmin);
      return JankariService.adminMeta();

    case 'admin.jankari.get':
      requireAdmin(isAdmin);
      return JankariService.list(data.cropId || 'afim');

    case 'admin.jankari.set':
      requireAdmin(isAdmin);
      return {
        saved: await JankariService.adminSave(data.cropId, {
          posts: data.posts,
          version: data.version,
        }),
      };

    case 'admin.screens.get':
      requireAdmin(isAdmin);
      return { screens: getScreens() };

    case 'admin.quota.reset':
      requireAdmin(isAdmin);
      return {
        quota: await ChatService.adminResetDayQuota({
          uid: data.uid,
          email: data.email,
        }),
      };

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

    case 'admin.ai.threads':
    case 'admin.ai.threads.list':
      requireAdmin(isAdmin);
      if (!data.uid && !data.email) throw new Error('uid or email required');
      return ChatService.adminListThreads({
        uid: data.uid || null,
        email: data.email || null,
      });

    case 'admin.ai.thread':
    case 'admin.ai.thread.get':
      requireAdmin(isAdmin);
      if (!data.uid && !data.email) throw new Error('uid or email required');
      return ChatService.adminReadThread({
        uid: data.uid || null,
        email: data.email || null,
        mode: data.mode,
        sessionId: data.sessionId || data.chatId || null,
        cropId: data.cropId || null,
        limit: data.limit,
      });

    case 'admin.ai.guest':
    case 'admin.ai.guest.get':
      requireAdmin(isAdmin);
      if (!data.ip && !data.ipHash) throw new Error('ip or ipHash required');
      return IpChatService.adminGuestChat({
        ip: data.ip || null,
        ipHash: data.ipHash || null,
        limit: data.limit,
      });

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

    case 'admin.catalog.get':
      requireAdmin(isAdmin);
      return CatalogService.getAdminCatalog();

    case 'admin.catalog.plans.set':
      requireAdmin(isAdmin);
      return { plans: await CatalogService.setPlans(data.plans || data) };

    case 'admin.catalog.crops.set':
      requireAdmin(isAdmin);
      return { crops: await CatalogService.setCrops(data.crops || data) };

    case 'admin.catalog.unlock.set':
      requireAdmin(isAdmin);
      return { adminUnlock: await CatalogService.setAdminUnlock(data.unlock || data) };

    case 'admin.system.get':
      requireAdmin(isAdmin);
      return {
        config: await rtdbGet('system/public_config'),
        media: await rtdbGet('system/media'),
      };

    case 'admin.analytics.get':
      requireAdmin(isAdmin);
      return { analytics: await PageAnalyticsService.adminSnapshot() };

    default:
      throw Object.assign(new Error('bad_request'), { status: 400 });
  }
}

export default router;
