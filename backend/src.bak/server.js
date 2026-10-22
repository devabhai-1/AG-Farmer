import { createApp } from './app.js';
import { env } from './config/env.js';
import { startCourseDailySummary } from './services/course_daily_summary.service.js';
import { readQuota, flushQuotaNow } from './utils/quota_store.js';
import { flushJsonCaches } from './utils/json_cache.js';

readQuota();

const app = createApp();
const host = process.env.HOST || '0.0.0.0';

const server = app.listen({ port: env.port, host, backlog: 16384 }, () => {
  console.log(`AG Farmer backend [${env.nodeEnv}] on ${host}:${env.port}`);
  console.log(`API: ${env.publicApiUrl}`);
  console.log(`Try: POST ${env.publicApiUrl}  { "action": "health" }`);
  startCourseDailySummary();
});
server.keepAliveTimeout = 65000;
server.headersTimeout = 70000;
server.requestTimeout = 130000;

let closing = false;
function shutdown(code = 0) {
  if (closing) return;
  closing = true;
  try {
    flushQuotaNow();
    flushJsonCaches();
  } catch (err) {
    console.error('[process] flush failed', err?.message || 'flush');
  }
  server.close(() => process.exit(code));
  setTimeout(() => process.exit(code), 8000).unref();
}

process.on('SIGTERM', () => shutdown(0));
process.on('SIGINT', () => shutdown(0));
process.on('unhandledRejection', (err) => {
  console.error('[process] rejection', err?.message || 'rejected');
});
process.on('uncaughtException', (err) => {
  console.error('[process] crash', err?.message || 'crash');
  shutdown(1);
});
