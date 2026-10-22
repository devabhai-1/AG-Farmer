import os from 'os';

/**
 * In-process metrics: request counters, latency percentiles, per-action
 * stats and upstream failure counts. Zero dependencies, bounded memory.
 *
 * - snapshot()        → used by the admin.metrics action
 * - a `[stats]` line is logged every minute so pm2 logs show rps / p95 / 5xx
 *   without any external tooling.
 */

const STARTED_AT = Date.now();
const RESERVOIR_MAX = 4096;
const ACTION_MAX = 200;

const totals = {
  requests: 0,
  status2xx: 0,
  status4xx: 0,
  status5xx: 0,
  rateLimited: 0,
  busy: 0,
  slow: 0,
};

// Latency reservoir: fixed-size ring so percentiles stay O(1) in memory.
const latency = new Float64Array(RESERVOIR_MAX);
let latencyCount = 0;

// Per-action rolling counters: Map<action, {n, err, ms, max}>
const actions = new Map();

// Upstream (OpenAI / Gemini / Firebase / Razorpay) failures per minute window.
const upstream = new Map();

// Last-minute window for the periodic stats line.
let minute = freshMinute();

function freshMinute() {
  return { requests: 0, s4xx: 0, s5xx: 0, rl: 0, busy: 0, ms: [] };
}

function percentile(sorted, p) {
  if (!sorted.length) return 0;
  const idx = Math.min(sorted.length - 1, Math.max(0, Math.ceil((p / 100) * sorted.length) - 1));
  return Math.round(sorted[idx]);
}

export function recordRequest({ action, status, ms, path }) {
  totals.requests += 1;
  if (status >= 500) totals.status5xx += 1;
  else if (status >= 400) totals.status4xx += 1;
  else totals.status2xx += 1;
  if (status === 429) totals.rateLimited += 1;
  if (status === 503) totals.busy += 1;

  latency[latencyCount % RESERVOIR_MAX] = ms;
  latencyCount += 1;

  minute.requests += 1;
  if (status >= 500) minute.s5xx += 1;
  else if (status >= 400) minute.s4xx += 1;
  if (status === 429) minute.rl += 1;
  if (status === 503) minute.busy += 1;
  if (minute.ms.length < RESERVOIR_MAX) minute.ms.push(ms);

  const key = action || path || '-';
  let row = actions.get(key);
  if (!row) {
    if (actions.size >= ACTION_MAX) return;
    row = { n: 0, err: 0, ms: 0, max: 0 };
    actions.set(key, row);
  }
  row.n += 1;
  if (status >= 500) row.err += 1;
  row.ms += ms;
  if (ms > row.max) row.max = ms;
}

export function markSlow() {
  totals.slow += 1;
}

/** Call from services when a third-party call fails (name: 'openai' | 'gemini' | 'firebase' | 'razorpay'). */
export function recordUpstreamFailure(name, code = 'error') {
  const key = `${name}:${code}`.slice(0, 64);
  upstream.set(key, (upstream.get(key) || 0) + 1);
  if (upstream.size > 100) {
    const first = upstream.keys().next().value;
    upstream.delete(first);
  }
}

export function snapshot({ ddos } = {}) {
  const n = Math.min(latencyCount, RESERVOIR_MAX);
  const sorted = Array.from(latency.subarray(0, n)).sort((a, b) => a - b);
  const mem = process.memoryUsage();
  const load = os.loadavg();
  const topActions = Array.from(actions.entries())
    .sort((a, b) => b[1].n - a[1].n)
    .slice(0, 25)
    .map(([name, r]) => ({
      action: name,
      count: r.n,
      errors: r.err,
      avgMs: r.n ? Math.round(r.ms / r.n) : 0,
      maxMs: Math.round(r.max),
    }));
  return {
    uptimeSec: Math.round((Date.now() - STARTED_AT) / 1000),
    node: process.version,
    pid: process.pid,
    totals: { ...totals },
    latencyMs: {
      samples: n,
      p50: percentile(sorted, 50),
      p90: percentile(sorted, 90),
      p95: percentile(sorted, 95),
      p99: percentile(sorted, 99),
      max: n ? Math.round(sorted[n - 1]) : 0,
    },
    actions: topActions,
    upstreamFailures: Object.fromEntries(upstream),
    process: {
      rssMb: Math.round(mem.rss / 1048576),
      heapUsedMb: Math.round(mem.heapUsed / 1048576),
      heapTotalMb: Math.round(mem.heapTotal / 1048576),
      externalMb: Math.round(mem.external / 1048576),
    },
    host: {
      load1: Number(load[0].toFixed(2)),
      load5: Number(load[1].toFixed(2)),
      cpus: os.cpus().length,
      freeMemMb: Math.round(os.freemem() / 1048576),
      totalMemMb: Math.round(os.totalmem() / 1048576),
    },
    limiter: ddos || undefined,
  };
}

function flushMinute() {
  const m = minute;
  minute = freshMinute();
  if (!m.requests) return;
  const sorted = m.ms.sort((a, b) => a - b);
  const mem = process.memoryUsage();
  console.log(
    '[stats]',
    JSON.stringify({
      ts: new Date().toISOString(),
      rpm: m.requests,
      p50: percentile(sorted, 50),
      p95: percentile(sorted, 95),
      p99: percentile(sorted, 99),
      s4xx: m.s4xx,
      s5xx: m.s5xx,
      rl: m.rl,
      busy: m.busy,
      rssMb: Math.round(mem.rss / 1048576),
      heapMb: Math.round(mem.heapUsed / 1048576),
    }),
  );
}

setInterval(flushMinute, 60 * 1000).unref();
