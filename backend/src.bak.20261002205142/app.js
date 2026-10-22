import express from 'express';
import cors from 'cors';
import morgan from 'morgan';
import path from 'path';
import { fileURLToPath } from 'url';
import { env } from './config/env.js';
import { initFirebase } from './config/firebase.js';
import routes from './routes/index.js';
import { fail } from './middleware/response.js';
import { clientIpMiddleware } from './middleware/client_ip.js';
import { ddosProtectionMiddleware } from './middleware/ddos_protection.js';
import { RazorpayService } from './services/razorpay.service.js';

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
  app.use(cors());
  app.use(express.json({ limit: '8mb' }));
  app.use((req, res, next) => {
    res.setTimeout(120000, () => {
      if (!res.headersSent) fail(res, 503, 'service_unavailable', { lang: 'hi' });
    });
    next();
  });
  if (env.nodeEnv !== 'production') app.use(morgan('dev'));
  app.use(clientIpMiddleware);
  app.use(ddosProtectionMiddleware);

  // Public root — no project ids, paths, or internal examples
  app.get('/', (_req, res) => {
    res.json({
      ok: true,
      name: 'AG Farmer',
      status: 'online',
    });
  });

  const dataDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../data/jankari_images');
  app.use('/media/jankari', express.static(dataDir, {
    maxAge: '7d',
    fallthrough: false,
  }));

  app.use('/api', routes);

  app.use((err, _req, res, _next) => {
    const parseFail = err?.type === 'entity.parse.failed' || err instanceof SyntaxError;
    if (parseFail) {
      return fail(res, 400, 'bad_request', { lang: 'hi' });
    }
    if (err?.type === 'entity.too.large') {
      return fail(res, 413, 'file_too_large', { lang: 'hi' });
    }
    console.error('[error]', err?.message || 'server');
    return fail(res, err.status || 500, 'service_unavailable', { lang: 'hi' });
  });

  return app;
}
   