import crypto from 'crypto';
import { env } from '../config/env.js';
import { rootRef, isFirebaseReady } from '../config/firebase.js';
import { CatalogService, planChargeInr, planMrpInr } from './catalog.service.js';
import { UserService } from './user.service.js';

const TESTER_EMAIL = 'devdhaker7073@gmail.com';
const CYCLE_MS = 30 * 24 * 60 * 60 * 1000;
const OPEN_MS = 20 * 60 * 1000;
const ACTIVE = new Set(['active', 'authenticated', 'pending']);
const STOPPED = new Set(['cancelled', 'completed']);
const DEAD = new Set(['halted', 'expired']);
const syncCache = new Map();

function fail(code, status = 400) {
  throw Object.assign(new Error(code), { status });
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function authHeader() {
  const token = Buffer.from(`${env.razorpayKeyId}:${env.razorpayKeySecret}`).toString('base64');
  return `Basic ${token}`;
}

async function razorpay(path, { method = 'GET', body } = {}) {
  if (!env.razorpayKeyId || !env.razorpayKeySecret) fail('payment_not_configured', 503);
  const res = await fetch(`https://api.razorpay.com/v1${path}`, {
    method,
    headers: {
      Authorization: authHeader(),
      'Content-Type': 'application/json',
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    const desc = json?.error?.description || res.status;
    console.error('[pay] api', method, path, desc);
    const err = new Error('payment_failed');
    err.status = 502;
    err.detail = String(desc);
    throw err;
  }
  return json;
}

function isTester(email) {
  return String(email || '').trim().toLowerCase() === TESTER_EMAIL;
}

async function testerAccount(uid, email) {
  if (isTester(email)) return true;
  const user = await UserService.get(uid);
  return isTester(user?.email);
}

async function grantTester({ uid, plan, spec }) {
  const user = await UserService.setSubscription(uid, {
    planId: String(plan.id),
    status: 'active',
    active: true,
    autoRenew: false,
    cycle: spec.cycle,
    cycleDays: spec.days,
    expiresAt: Date.now() + spec.days * 24 * 60 * 60 * 1000,
    provider: 'tester',
  });
  return { alreadyPaid: true, user };
}

function findPlan(plans, planId) {
  const want = String(planId || '').toLowerCase();
  for (const row of Object.values(plans || {})) {
    if (!row || typeof row !== 'object') continue;
    if (String(row.id || '').toLowerCase() === want) return row;
  }
  return null;
}

function signaturesMatch(expected, actual) {
  const a = Buffer.from(String(expected));
  const b = Buffer.from(String(actual));
  if (a.length !== b.length || a.length === 0) return false;
  return crypto.timingSafeEqual(a, b);
}

function quote(baseRupees, cycle) {
  const base = Math.round(Number(baseRupees));
  if (!base || base <= 0) fail('plan_not_found', 404);
  if (cycle === 'four_month') {
    return { cycle, days: 120, autopay: false, amount: Math.round((base * 4 * 90) / 100) };
  }
  if (cycle === 'yearly') {
    return { cycle, days: 365, autopay: false, amount: Math.round((base * 12 * 75) / 100) };
  }
  if (cycle === 'monthly' || cycle == null || cycle === '') {
    return { cycle: 'monthly', days: 30, autopay: true, amount: base };
  }
  fail('plan_not_found', 404);
}

function cycleEndMs(subscription) {
  const endSec = Number(subscription?.current_end || subscription?.end_at || 0);
  if (Number.isFinite(endSec) && endSec > 0) return endSec * 1000;
  const startSec = Number(subscription?.current_start || subscription?.start_at || 0);
  if (Number.isFinite(startSec) && startSec > 0) return startSec * 1000 + CYCLE_MS;
  const chargeSec = Number(subscription?.charge_at || 0);
  if (Number.isFinite(chargeSec) && chargeSec * 1000 > Date.now() + 60 * 1000) {
    return chargeSec * 1000;
  }
  return Date.now() + CYCLE_MS;
}

async function savedCheckout(subId) {
  if (!isFirebaseReady()) return null;
  const snap = await rootRef(`payments/subscriptions/${subId}`).get();
  return snap.val() || null;
}

async function ensureBillingPlan(plan, amountPaise) {
  const amount = Math.round(Number(amountPaise));
  const planId = `${plan.id}_monthly`;
  if (isFirebaseReady()) {
    const snap = await rootRef(`payments/razorpay_plans/${planId}`).get();
    const saved = snap.val();
    if (saved?.razorpayPlanId && Number(saved.amount) === amount && saved.interval === 30) {
      return saved.razorpayPlanId;
    }
  }

  const created = await razorpay('/plans', {
    method: 'POST',
    body: {
      period: 'daily',
      interval: 30,
      item: {
        name: `AG Farmer ${plan.nameEn || planId}`.slice(0, 80),
        amount,
        currency: 'INR',
        description: '30 day autopay',
      },
      notes: { app: 'ag_farmer', planId },
    },
  });
  if (!created?.id) fail('payment_failed', 502);

  if (isFirebaseReady()) {
    await rootRef(`payments/razorpay_plans/${planId}`).set({
      razorpayPlanId: created.id,
      amount,
      interval: 30,
      planId,
      updatedAt: Date.now(),
    });
  }
  return created.id;
}

async function cancelRemote(subscriptionId) {
  const id = String(subscriptionId || '');
  if (!id.startsWith('sub_')) return;
  try {
    await razorpay(`/subscriptions/${encodeURIComponent(id)}/cancel`, {
      method: 'POST',
      body: { cancel_at_cycle_end: 0 },
    });
  } catch (err) {
    console.warn('[pay] cancel skip', err.detail || err.message);
  }
}

async function loadSubscription(subId) {
  let subscription = null;
  for (let attempt = 0; attempt < 6; attempt += 1) {
    subscription = await razorpay(`/subscriptions/${encodeURIComponent(subId)}`);
    const status = String(subscription?.status || '');
    if (ACTIVE.has(status) || STOPPED.has(status) || DEAD.has(status)) return subscription;
    if (attempt < 5) await sleep(700);
  }
  return subscription;
}

async function loadOrder(oid) {
  try {
    return await razorpay(`/orders/${encodeURIComponent(oid)}`);
  } catch (err) {
    console.warn('[pay] order', err.detail || err.message);
    return null;
  }
}

async function paidInvoice(subId) {
  try {
    const data = await razorpay(
      `/invoices?subscription_id=${encodeURIComponent(subId)}&count=10`,
    );
    const items = Array.isArray(data?.items) ? data.items : [];
    return (
      items.find((inv) => {
        const status = String(inv?.status || '');
        return (status === 'paid' || status === 'partially_paid') && inv?.payment_id;
      }) || null
    );
  } catch (err) {
    console.warn('[pay] invoices', err.detail || err.message);
    return null;
  }
}

function checkoutBody(subscriptionId, plan, spec) {
  return {
    checkout: {
      keyId: env.razorpayKeyId,
      subscriptionId,
      orderId: '',
      planId: String(plan.id),
      cycle: spec.cycle,
      autopay: true,
      amount: spec.amount * 100,
      currency: 'INR',
      description: `${plan.nameEn || plan.id} · monthly autopay`,
      name: 'AG Farmer',
    },
  };
}

async function grantAccess({ uid, subscription, paymentId, planId }) {
  const subId = String(subscription.id);
  const current = await UserService.get(uid);
  const previous = current?.subscription?.razorpaySubscriptionId;
  if (previous && previous !== subId) await cancelRemote(previous);

  const expiresAt = cycleEndMs(subscription);
  const user = await UserService.setSubscription(uid, {
    planId,
    status: 'active',
    active: true,
    autoRenew: true,
    cycle: 'monthly',
    cycleDays: 30,
    expiresAt,
    provider: 'razorpay',
    razorpaySubscriptionId: subId,
    paymentId: String(paymentId),
  });

  if (isFirebaseReady()) {
    await rootRef(`payments/subscriptions/${subId}`).update({
      status: subscription.status || 'active',
      paymentId: String(paymentId),
      planId,
      uid: String(uid),
      expiresAt,
      paidAt: Date.now(),
    });
    await rootRef(`payments/open_by_user/${uid}`).remove();
  }
  syncCache.set(uid, Date.now());
  return user;
}

// Grant access for a one-time order (four_month / yearly). Used by both
// billing.checkout.verify (client-driven) and the webhook (server reconcile).
async function grantOrderAccess({ uid, planId, order, paymentId }) {
  const spec = quote(
    planChargeInr(await findPlan(await CatalogService.getPlans(), planId)),
    order?.notes?.cycle,
  );
  const current = await UserService.get(uid);
  if (current?.subscription?.razorpaySubscriptionId) {
    await cancelRemote(current.subscription.razorpaySubscriptionId);
  }
  const expiresAt = Date.now() + spec.days * 24 * 60 * 60 * 1000;
  const user = await UserService.setSubscription(uid, {
    planId,
    status: 'active',
    active: true,
    autoRenew: false,
    cycle: spec.cycle,
    cycleDays: spec.days,
    expiresAt,
    provider: 'razorpay',
    razorpaySubscriptionId: null,
    paymentId: String(paymentId),
    orderId: String(order.id),
  });
  if (isFirebaseReady()) {
    await rootRef(`payments/orders/${order.id}`).update({
      status: 'paid',
      paymentId: String(paymentId),
      uid: String(uid),
      planId,
      expiresAt,
      paidAt: Date.now(),
    });
    await rootRef(`payments/open_by_user/${uid}`).remove();
  }
  syncCache.set(uid, Date.now());
  return user;
}

// Webhook reconcile for one-time orders. Fetches the order + payment, checks
// capture + amount, then grants. Idempotent: skips if already paid.
async function reconcileOrder({ oid, payment }) {
  let saved = null;
  if (isFirebaseReady()) {
    const snap = await rootRef(`payments/orders/${oid}`).get();
    saved = snap.val();
  }
  const order = await loadOrder(oid);
  if (!order) return { ignored: true };
  const uid = String(order?.notes?.uid || saved?.uid || '');
  const planId = String(order?.notes?.planId || saved?.planId || '');
  if (!uid || !planId) return { ignored: true };

  const paymentId = String(payment?.id || saved?.paymentId || '');
  if (!paymentId) return { ignored: true };
  if (saved?.status === 'paid' && saved?.paymentId === paymentId) {
    return { ok: true };
  }

  const paid = payment?.status
    ? payment
    : await razorpay(`/payments/${encodeURIComponent(paymentId)}`).catch(() => null);
  if (!paid) return { ignored: true };
  if (String(paid.order_id || '') !== oid) return { ignored: true };
  if (paid.status !== 'captured' && paid.status !== 'authorized') return { ignored: true };

  const spec = quote(
    planChargeInr(await findPlan(await CatalogService.getPlans(), planId)),
    order?.notes?.cycle || saved?.cycle,
  );
  if (Number(order.amount) !== spec.amount * 100) return { ignored: true };
  if (Number(paid.amount) !== spec.amount * 100) return { ignored: true };

  await grantOrderAccess({ uid, planId, order, paymentId });
  return { ok: true };
}

async function keepPaidDays(uid, subscription, planId, expiresAt) {
  return UserService.setSubscription(uid, {
    planId,
    status: 'active',
    active: true,
    autoRenew: false,
    cycleDays: 30,
    expiresAt,
    provider: 'razorpay',
    razorpaySubscriptionId: null,
  });
}

async function clearAccess(uid, expiresAt) {
  return UserService.setSubscription(uid, {
    planId: 'free',
    status: 'cleared',
    active: false,
    autoRenew: false,
    expiresAt: expiresAt || Date.now(),
    provider: 'razorpay',
    razorpaySubscriptionId: null,
  });
}

export const RazorpayService = {
  async createSubscription({ uid, planId, email }) {
    const plans = await CatalogService.getPlans();
    const plan = findPlan(plans, planId);
    if (
      plan &&
      planMrpInr(plan) > 0 &&
      plan.active !== false &&
      (await testerAccount(uid, email))
    ) {
      return grantTester({ uid, plan, spec: quote(planChargeInr(plan), 'monthly') });
    }
    const price = planChargeInr(plan);
    if (!plan || planMrpInr(plan) <= 0 || plan.active === false) fail('plan_not_found', 404);
    const spec = quote(price, 'monthly');

    if (isFirebaseReady()) {
      const openSnap = await rootRef(`payments/open_by_user/${uid}`).get();
      const open = openSnap.val();
      const fresh = open?.subscriptionId
        && String(open.planId) === String(plan.id)
        && open.cycle === 'monthly'
        && Number(open.amount) === spec.amount * 100
        && Date.now() - Number(open.createdAt || 0) < OPEN_MS;
      if (fresh) {
        try {
          const existing = await razorpay(
            `/subscriptions/${encodeURIComponent(open.subscriptionId)}`,
          );
          const status = String(existing?.status || '');
          if (status === 'created') return checkoutBody(existing.id, plan, spec);
          if (ACTIVE.has(status)) {
            const invoice = await paidInvoice(existing.id);
            if (invoice?.payment_id) {
              const user = await grantAccess({
                uid,
                subscription: existing,
                paymentId: invoice.payment_id,
                planId: String(plan.id),
              });
              return { user, alreadyPaid: true };
            }
          }
        } catch (err) {
          console.warn('[pay] reuse skip', err.detail || err.message);
        }
      }
    }

    const razorpayPlanId = await ensureBillingPlan(plan, spec.amount * 100);
    const subscription = await razorpay('/subscriptions', {
      method: 'POST',
      body: {
        plan_id: razorpayPlanId,
        total_count: 120,
        quantity: 1,
        customer_notify: false,
        notes: {
          uid: String(uid),
          planId: String(plan.id),
          cycle: 'monthly',
          app: 'ag_farmer',
        },
      },
    });
    if (!subscription?.id) fail('payment_failed', 502);

    if (isFirebaseReady()) {
      const row = {
        subscriptionId: subscription.id,
        uid: String(uid),
        planId: String(plan.id),
        cycle: 'monthly',
        amount: spec.amount * 100,
        status: subscription.status || 'created',
        createdAt: Date.now(),
      };
      await rootRef(`payments/subscriptions/${subscription.id}`).set(row);
      await rootRef(`payments/open_by_user/${uid}`).set(row);
    }

    return checkoutBody(subscription.id, plan, spec);
  },

  async createCheckout({ uid, planId, cycle, email }) {
    const plans = await CatalogService.getPlans();
    const plan = findPlan(plans, planId);
    const price = planChargeInr(plan);
    if (!plan || planMrpInr(plan) <= 0 || plan.active === false) fail('plan_not_found', 404);
    const spec = quote(price, cycle || 'monthly');
    if (await testerAccount(uid, email)) return grantTester({ uid, plan, spec });
    if (spec.autopay) return this.createSubscription({ uid, planId: plan.id, email });
    return this.createOrder({ uid, plan, spec });
  },

  async createOrder({ uid, plan, spec }) {
    const amount = spec.amount * 100;
    const order = await razorpay('/orders', {
      method: 'POST',
      body: {
        amount,
        currency: 'INR',
        receipt: `ag${Date.now()}`.slice(0, 40),
        notes: {
          uid: String(uid),
          planId: String(plan.id),
          cycle: spec.cycle,
          app: 'ag_farmer',
        },
      },
    });
    if (!order?.id) fail('payment_failed', 502);
    if (isFirebaseReady()) {
      await rootRef(`payments/orders/${order.id}`).set({
        orderId: order.id,
        uid: String(uid),
        planId: String(plan.id),
        cycle: spec.cycle,
        days: spec.days,
        amount,
        status: order.status || 'created',
        createdAt: Date.now(),
      });
    }
    return {
      checkout: {
        keyId: env.razorpayKeyId,
        subscriptionId: '',
        orderId: order.id,
        planId: String(plan.id),
        cycle: spec.cycle,
        autopay: false,
        amount,
        currency: 'INR',
        description: `${plan.nameEn || plan.id} · ${spec.cycle === 'yearly' ? '1 year' : '4 months'}`,
        name: 'AG Farmer',
      },
    };
  },

  async verifyCheckout({ uid, subscriptionId, orderId, paymentId, signature }) {
    if (orderId) {
      return this.verifyOrder({ uid, orderId, paymentId, signature });
    }
    return this.verifySubscription({ uid, subscriptionId, paymentId, signature });
  },

  async verifyOrder({ uid, orderId, paymentId, signature }) {
    if (!env.razorpayKeySecret) fail('payment_not_configured', 503);
    const oid = String(orderId || '');
    const payment = String(paymentId || '');
    const sig = String(signature || '');
    if (!oid || !payment || !sig) fail('payment_failed');

    let saved = null;
    if (isFirebaseReady()) {
      const snap = await rootRef(`payments/orders/${oid}`).get();
      saved = snap.val();
    }
    if (saved?.paymentId === payment && String(saved.uid) === String(uid)) {
      const user = await UserService.get(uid);
      if (user?.plan && user.plan !== 'free') return { user };
    }

    const expected = crypto
      .createHmac('sha256', env.razorpayKeySecret)
      .update(`${payment}|${oid}`)
      .digest('hex');
    if (!signaturesMatch(expected, sig)) fail('payment_failed');

    const order = await razorpay(`/orders/${encodeURIComponent(oid)}`);
    const paid = await razorpay(`/payments/${encodeURIComponent(payment)}`);
    if (String(paid.order_id || '') !== oid) fail('payment_failed');
    if (paid.status !== 'captured' && paid.status !== 'authorized') fail('payment_failed');

    const noteUid = String(order?.notes?.uid || saved?.uid || '');
    if (noteUid !== String(uid)) fail('payment_failed');
    const planId = String(order?.notes?.planId || saved?.planId || '');
    const spec = quote(
      planChargeInr(await findPlan(await CatalogService.getPlans(), planId)),
      order?.notes?.cycle || saved?.cycle,
    );
    if (!planId || Number(order.amount) !== spec.amount * 100) fail('payment_failed');
    if (Number(paid.amount) !== spec.amount * 100) fail('payment_failed');

    const user = await grantOrderAccess({ uid, planId, order, paymentId: payment });
    return { user };
  },

  async verifySubscription({ uid, subscriptionId, paymentId, signature }) {
    if (!env.razorpayKeySecret) fail('payment_not_configured', 503);
    const subId = String(subscriptionId || '');
    const payment = String(paymentId || '');
    const sig = String(signature || '');
    if (!subId || !payment || !sig) fail('payment_failed');

    const saved = await savedCheckout(subId);
    if (saved?.paymentId === payment && String(saved.uid) === String(uid)) {
      const user = await UserService.get(uid);
      if (user?.plan && user.plan !== 'free') return { user };
    }

    const expected = crypto
      .createHmac('sha256', env.razorpayKeySecret)
      .update(`${payment}|${subId}`)
      .digest('hex');
    if (!signaturesMatch(expected, sig)) fail('payment_failed');

    const subscription = await loadSubscription(subId);
    const noteUid = String(subscription?.notes?.uid || saved?.uid || '');
    if (noteUid !== String(uid)) fail('payment_failed');
    const status = String(subscription?.status || '');
    if (DEAD.has(status) || STOPPED.has(status)) fail('payment_failed');

    const paid = await razorpay(`/payments/${encodeURIComponent(payment)}`);
    if (String(paid.subscription_id || '') !== subId) fail('payment_failed');
    if (paid.status !== 'captured' && paid.status !== 'authorized') fail('payment_failed');

    const planId = String(subscription?.notes?.planId || saved?.planId || '');
    if (!planId) fail('payment_failed');

    const user = await grantAccess({
      uid,
      subscription,
      paymentId: payment,
      planId,
    });
    return { user };
  },

  async cancelSubscription({ uid }) {
    const current = await UserService.get(uid);
    const subId = current?.subscription?.razorpaySubscriptionId;
    if (subId) await cancelRemote(subId);
    const expiresAt = Number(current?.subscription?.expiresAt || 0);
    const planId = String(current?.subscription?.planId || current?.plan || 'free');
    syncCache.set(uid, Date.now());
    if (planId && planId !== 'free' && expiresAt > Date.now()) {
      const user = await keepPaidDays(uid, null, planId, expiresAt);
      return { user };
    }
    const user = await clearAccess(uid, Date.now());
    return { user };
  },

  async syncAccess(uid) {
    const user = await UserService.get(uid);
    const subId = user?.subscription?.razorpaySubscriptionId;
    if (!subId || !env.razorpayKeyId) return user;
    const last = syncCache.get(uid) || 0;
    if (Date.now() - last < 60 * 1000) return user;

    try {
      const subscription = await razorpay(`/subscriptions/${encodeURIComponent(subId)}`);
      syncCache.set(uid, Date.now());
      const planId = String(subscription?.notes?.planId || user.subscription.planId || '');
      const remoteEnd = Number(subscription?.current_end || 0) > 0
        ? Number(subscription.current_end) * 1000
        : 0;
      const localEnd = Number(user.subscription?.expiresAt || 0);
      const expiresAt = remoteEnd || localEnd;
      const status = String(subscription.status || '');

      if (DEAD.has(status) || (expiresAt && expiresAt <= Date.now() && !ACTIVE.has(status))) {
        return clearAccess(uid, expiresAt || Date.now());
      }
      if (STOPPED.has(status)) {
        if (expiresAt > Date.now()) {
          if (user.subscription?.autoRenew === false && user.subscription?.expiresAt === expiresAt) {
            return user;
          }
          return keepPaidDays(uid, subscription, planId, expiresAt);
        }
        return clearAccess(uid, expiresAt || Date.now());
      }
      if (ACTIVE.has(status) && expiresAt > Date.now()) {
        if (user.subscription?.expiresAt !== expiresAt || user.plan !== planId || user.subscription?.autoRenew === false) {
          return UserService.setSubscription(uid, {
            planId,
            status: 'active',
            active: true,
            autoRenew: true,
            cycleDays: 30,
            expiresAt,
            provider: 'razorpay',
            razorpaySubscriptionId: subId,
            paymentId: user.subscription?.paymentId || null,
          });
        }
        return user;
      }
      return user;
    } catch (err) {
      console.warn('[pay] sync skip', err.detail || err.message);
      return user;
    }
  },

  async handleWebhook(rawBody, signature) {
    if (!env.razorpayWebhookSecret) fail('payment_not_configured', 503);
    const body = Buffer.isBuffer(rawBody) ? rawBody : Buffer.from(String(rawBody || ''));
    const expected = crypto
      .createHmac('sha256', env.razorpayWebhookSecret)
      .update(body)
      .digest('hex');
    if (!signaturesMatch(expected, signature)) fail('payment_failed', 401);

    let event;
    try {
      event = JSON.parse(body.toString('utf8'));
    } catch (_) {
      fail('payment_failed');
    }

    const name = String(event?.event || '');
    const subscription = event?.payload?.subscription?.entity;
    const payment = event?.payload?.payment?.entity;
    const order = event?.payload?.order?.entity;
    const subId = String(subscription?.id || payment?.subscription_id || '');

    // One-time orders (four_month / yearly). Reconcile even if the client
    // dropped before calling billing.checkout.verify. Signature is already
    // verified on the raw body above, so grant from the fetched order.
    if (!subId.startsWith('sub_')) {
      const oid = String(order?.id || payment?.order_id || '');
      if (!oid.startsWith('order_')) return { ignored: true };
      const handled = await reconcileOrder({ oid, payment });
      return handled || { ignored: true };
    }

    const saved = await savedCheckout(subId);
    const uid = String(subscription?.notes?.uid || saved?.uid || '');
    const planId = String(subscription?.notes?.planId || saved?.planId || '');
    if (!uid || !planId) return { ignored: true };

    if (
      name === 'subscription.charged'
      || name === 'subscription.activated'
      || name === 'subscription.authenticated'
      || name === 'payment.captured'
    ) {
      const paymentId = String(payment?.id || saved?.paymentId || '');
      if (!paymentId) return { ignored: true };
      if (payment && payment.status && payment.status !== 'captured' && payment.status !== 'authorized') {
        return { ignored: true };
      }
      const live = subscription?.id ? subscription : await loadSubscription(subId);
      await grantAccess({ uid, subscription: live, paymentId, planId });
      return { ok: true };
    }

    if (name === 'subscription.halted' || name === 'subscription.pending') {
      if (name === 'subscription.halted') {
        await clearAccess(uid, Date.now());
      }
      return { ok: true };
    }

    if (name === 'subscription.cancelled' || name === 'subscription.completed') {
      const expiresAt = cycleEndMs(subscription);
      if (expiresAt > Date.now()) await keepPaidDays(uid, subscription, planId, expiresAt);
      else await clearAccess(uid, expiresAt);
      return { ok: true };
    }

    return { ignored: true };
  },
};

export function startBillingSync() {
  const tick = async () => {
    if (!isFirebaseReady() || !env.razorpayKeyId || !env.razorpayKeySecret) return;
    try {
      const snap = await rootRef('payments/subscriptions').limitToLast(40).get();
      const all = snap.val() || {};
      const uids = new Set();
      for (const row of Object.values(all)) {
        if (!row?.uid || !row?.subscriptionId) continue;
        if (row.status === 'created') continue;
        uids.add(String(row.uid));
      }
      for (const uid of uids) {
        syncCache.delete(uid);
        await RazorpayService.syncAccess(uid);
      }
    } catch (err) {
      console.warn('[pay] sweep', err.detail || err.message);
    }
  };
  setTimeout(tick, 20000).unref();
  setInterval(tick, 15 * 60 * 1000).unref();
}
