import express from 'express';
import cors from 'cors';
import morgan from 'morgan';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { pauseReminders, quietPage } from './mail/index.js';
import { lookupResetCode, resetLinkState } from './services/reset_link.service.js';
import { env } from './config/env.js';
import { initFirebase } from './config/firebase.js';
import routes from './routes/index.js';
import { fail } from './middleware/response.js';
import { clientIpMiddleware } from './middleware/client_ip.js';
import { ddosProtectionMiddleware } from './middleware/ddos_protection.js';
import { observabilityMiddleware } from './middleware/observability.js';
import { isFirebaseReady } from './config/firebase.js';
import { RazorpayService } from './services/razorpay.service.js';
import { TTS_CACHE_DIR } from './services/tts.service.js';

export function createApp() {
  initFirebase();

  const app = express();
  app.disable('x-powered-by');
  app.set('trust proxy', 1);
  app.use((_req, res, next) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Referrer-Policy', 'no-referrer');
    res.setHeader('X-Frame-Options', 'DENY');
    next();
  });
  app.post(
    '/api/razorpay/webhook',
    express.raw({ type: '*/*', limit: '1mb' }),
    async (req, res) => {
      try {
        const result = await RazorpayService.handleWebhook(
          req.body,
          req.get('x-razorpay-signature') || '',
        );
        res.json({ ok: true, ...result });
      } catch (err) {
        res.status(err.status || 400).json({ ok: false });
      }
    },
  );
  // The API is a single POST endpoint consumed by the mobile app; browsers
  // only need preflight for the website. Keep CORS open on origin but tight
  // on methods/headers so a stray verb or header cannot reach the handlers.
  app.use(
    cors({
      origin: true,
      methods: ['GET', 'POST', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization', 'X-Request-Id', 'x-admin-key'],
      exposedHeaders: ['X-Request-Id', 'Retry-After'],
      maxAge: 86400,
    }),
  );
  app.use(express.json({ limit: '8mb' }));
  // Shape guard: the gateway only accepts a JSON object with a well-formed
  // action name. Arrays, scalars and junk action strings are rejected here so
  // they never reach the limiter buckets or the dispatcher.
  app.use('/api', (req, res, next) => {
    if (req.method === 'POST') {
      const body = req.body;
      if (body == null || typeof body !== 'object' || Array.isArray(body)) {
        return fail(res, 400, 'bad_request', { lang: 'hi' });
      }
      const action = body.action;
      if (action != null && (typeof action !== 'string' || !/^[a-z][a-zA-Z0-9_.-]{0,63}$/.test(action))) {
        return fail(res, 400, 'bad_request', { lang: 'hi' });
      }
    }
    return next();
  });
  app.use((req, res, next) => {
    res.setTimeout(120000, () => {
      if (!res.headersSent) fail(res, 503, 'service_unavailable', { lang: 'hi' });
    });
    next();
  });
  if (env.nodeEnv !== 'production') app.use(morgan('dev'));
  app.use(clientIpMiddleware);
  app.use(observabilityMiddleware);

  // Liveness / readiness for the reverse proxy and uptime monitors. These sit
  // BEFORE rate limiting so a probe can never be throttled, and they expose
  // no internal details.
  app.get('/healthz', (_req, res) => {
    res.setHeader('Cache-Control', 'no-store');
    res.json({ ok: true });
  });
  app.get('/readyz', (_req, res) => {
    res.setHeader('Cache-Control', 'no-store');
    const ready = isFirebaseReady();
    res.status(ready ? 200 : 503).json({ ok: ready });
  });

  app.use(ddosProtectionMiddleware);

  // Public root — no project ids, paths, or internal examples
  app.get('/', (_req, res) => {
    res.json({
      ok: true,
      name: 'AG Farmer',
      status: 'online',
    });
  });

  const resetPage = path.resolve(
    path.dirname(fileURLToPath(import.meta.url)),
    '../public/reset-password.html',
  );
  const sendResetPage = (_req, res) => {
    res.setHeader('Cache-Control', 'no-store');
    res.sendFile(resetPage);
  };
  app.get(['/reset-password', '/reset-password/', '/api/reset-password', '/api/reset-password/'], sendResetPage);
  const mailLogo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), 'mail/logo.png');
  app.get(['/mail-logo.png', '/api/mail-logo.png'], (_req, res) => {
    res.setHeader('Cache-Control', 'public, max-age=86400');
    res.type('png').sendFile(mailLogo);
  });
  app.get(['/mail/quiet', '/api/mail/quiet'], (req, res) => {
    const ok = pauseReminders(String(req.query.id || ''), String(req.query.t || ''));
    res.setHeader('Cache-Control', 'no-store');
    res.type('html').send(quietPage(ok));
  });
  app.get(/^\/api\/r\/([23456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjklmnpqrstuvwxyz]{8})\/?$/, (req, res) => {
    const state = resetLinkState(req.params[0]);
    const oob = state === 'ok' ? lookupResetCode(req.params[0]) : '';
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Referrer-Policy', 'no-referrer');
    if (state !== 'ok' || !oob) {
      const html = fs.readFileSync(resetPage, 'utf8').replace(
        '</head>',
        `<script>window.__RESET_STATE=${JSON.stringify(state === 'used' ? 'used' : 'bad')};</script></head>`,
      );
      res.type('html').send(html);
      return;
    }
    const html = fs.readFileSync(resetPage, 'utf8').replace(
      '</head>',
      `<script>window.__RESET_OOB=${JSON.stringify(oob)};window.__RESET_STATE="ok";</script></head>`,
    );
    res.type('html').send(html);
  });

  const dataDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../data/jankari_images');
  app.use('/media/jankari', express.static(dataDir, {
    maxAge: '7d',
    fallthrough: false,
  }));
  // Cached article audio; file names are content hashes so they can be
  // cached forever by the app and any proxy.
  app.use('/media/tts', express.static(TTS_CACHE_DIR, {
    maxAge: '30d',
    immutable: true,
    fallthrough: false,
    setHeaders: (res, filePath) => {
      res.setHeader('Content-Type', String(filePath).endsWith('.wav') ? 'audio/wav' : 'audio/mpeg');
    },
  }));

  app.use('/api', routes);

  // Unknown path: clean JSON instead of the Express HTML 404 page.
  app.use((req, res) => {
    fail(res, 404, 'not_found', { lang: 'hi' });
  });

  app.use((err, req, res, _next) => {
    if (res.headersSent) return;
    const parseFail = err?.type === 'entity.parse.failed' || err instanceof SyntaxError;
    if (parseFail) {
      return fail(res, 400, 'bad_request', { lang: 'hi' });
    }
    if (err?.type === 'entity.too.large') {
      return fail(res, 413, 'file_too_large', { lang: 'hi' });
    }
    // Log with the request id so a user-reported id can be matched to this line.
    console.error('[error]', req?.requestId || '-', err?.message || 'server');
    return fail(res, err.status || 500, 'service_unavailable', { lang: 'hi' });
  });

  return app;
}
   