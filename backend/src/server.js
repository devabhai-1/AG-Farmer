import { createApp } from './app.js';
import { env } from './config/env.js';
import { startMailDesk } from './mail/index.js';
import { startCourseDailySummary } from './services/course_daily_summary.service.js';
import { startAccountPurge } from './services/user.service.js';
import { startBillingSync } from './services/razorpay.service.js';
import { readQuota, flushQuotaNow } from './utils/quota_store.js';
import { flushJsonCaches } from './utils/json_cache.js';
import { hydrateSystemToRtdb } from './services/system_hydrate.service.js';

readQuota();

const app = createApp();
// Production sits behind Caddy on the same machine; bind loopback so the
// Node port is never reachable directly (no proxy bypass, no spoofed
// X-Forwarded-For). Set HOST=0.0.0.0 explicitly for LAN/dev use.
const host = process.env.HOST || (env.nodeEnv === 'production' ? '127.0.0.1' : '0.0.0.0');

const server = app.listen({ port: env.port, host, backlog: 16384 }, () => {
  console.log(`AG Farmer backend [${env.nodeEnv}] on ${host}:${env.port}`);
  console.log(`API: ${env.publicApiUrl}`);
  console.log(`Try: POST ${env.publicApiUrl}  { "action": "health" }`);
  startMailDesk();
  startCourseDailySummary();
  startBillingSync();
  startAccountPurge();
  hydrateSystemToRtdb().catch((err) => {
    console.warn('[rtdb-system] hydrate skip', err?.message || 'hydrate');
  });
  // pm2 wait_ready: mark online only once the port is accepting connections.
  if (typeof process.send === 'function') process.send('ready');
});
server.keepAliveTimeout = 65000;
server.headersTimeout = 70000;
server.requestTimeout = 130000;

let closing = false;
function shutdown(code = 0, reason = 'signal') {
  if (closing) return;
  closing = true;
  console.log(`[process] shutting down (${reason})`);
  try {
    flushQuotaNow();
    flushJsonCaches();
  } catch (err) {
    console.error('[process] flush failed', err?.message || 'flush');
  }
  // Stop accepting new connections, let in-flight requests finish, then exit.
  // pm2 sends SIGINT and waits (kill_timeout) before SIGKILL, so finishing
  // open chat/voice requests here avoids half-written answers on deploy.
  server.close(() => process.exit(code));
  if (typeof server.closeIdleConnections === 'function') server.closeIdleConnections();
  setTimeout(() => {
    if (typeof server.closeAllConnections === 'function') server.closeAllConnections();
    process.exit(code);
  }, 10000).unref();
}

process.on('SIGTERM', () => shutdown(0, 'SIGTERM'));
process.on('SIGINT', () => shutdown(0, 'SIGINT'));
process.on('unhandledRejection', (err) => {
  console.error('[process] rejection', err?.message || 'rejected');
});
process.on('uncaughtException', (err) => {
  console.error('[process] crash', err?.message || 'crash');
  shutdown(1, 'uncaughtException');
});
