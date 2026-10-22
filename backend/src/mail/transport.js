import crypto from 'crypto';
import dnsCb from 'dns';
import dns from 'dns/promises';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import nodemailer from 'nodemailer';
import { env } from '../config/env.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const keyPath = path.resolve(here, '../../data/dkim_private.pem');
const MAIL_NAME = 'mail.ag-farmer.com';

async function outboundFamily(host) {
  try {
    const rows = await dns.resolve6(host);
    if (rows && rows.length) return 6;
  } catch {
    /* This host has no IPv6 mail server. Use IPv4. */
  }
  return 4;
}

function lookupFamily(family) {
  return (hostname, _options, callback) => {
    dnsCb.lookup(hostname, { family }, (err, address, fam) => {
      if (err) callback(err);
      else callback(null, address, fam);
    });
  };
}

function envelopeFrom(from) {
  const raw = String(from || '').trim();
  const angled = raw.match(/<([^>]+)>/);
  return (angled ? angled[1] : raw).trim();
}

let dkim;
function dkimSettings() {
  if (dkim !== undefined) return dkim;
  try {
    const privateKey = fs.readFileSync(keyPath, 'utf8');
    dkim = privateKey.includes('PRIVATE KEY')
      ? { domainName: 'ag-farmer.com', keySelector: 'agf', privateKey }
      : null;
  } catch {
    dkim = null;
  }
  return dkim;
}

function signed(options) {
  const sign = dkimSettings();
  if (sign) options.dkim = sign;
  return options;
}

let authed;

function authedTransport() {
  if (authed) return authed;
  if (!env.smtpUser || !env.smtpPass) return null;
  authed = nodemailer.createTransport(signed({
    host: env.smtpHost,
    port: env.smtpPort,
    secure: env.smtpSecure,
    auth: { user: env.smtpUser, pass: env.smtpPass },
  }));
  return authed;
}

export function isMailConfigured() {
  return Boolean(env.smtpUser && env.smtpPass);
}

async function directTransport(to) {
  const domain = String(to || '').split('@')[1] || '';
  const rows = domain ? await dns.resolveMx(domain) : [];
  rows.sort((a, b) => a.priority - b.priority);
  const host = rows[0] && rows[0].exchange;
  if (!host) {
    const err = new Error('email_send_failed');
    err.status = 502;
    throw err;
  }
  const family = await outboundFamily(host);
  const helo = family === 6 ? MAIL_NAME : 'vmi3461293.contaboserver.net';
  return nodemailer.createTransport(signed({
    host,
    port: 25,
    secure: false,
    name: helo,
    lookup: lookupFamily(family),
    tls: { servername: host },
    connectionTimeout: 20000,
    greetingTimeout: 20000,
    socketTimeout: 30000,
  }));
}

export function maskEmail(email) {
  const em = String(email || '');
  const at = em.indexOf('@');
  if (at < 1) return '***';
  const user = em.slice(0, at);
  const domain = em.slice(at);
  const keep = Math.min(2, user.length);
  return `${user.slice(0, keep)}***${domain}`;
}

export async function deliverMail({ from, replyTo, to, subject, text, html }) {
  let tx = authedTransport();
  let provider = 'smtp';
  if (!tx) {
    tx = await directTransport(to);
    provider = 'server';
  }
  const sender = envelopeFrom(from);
  const info = await tx.sendMail({
    from,
    replyTo: replyTo || sender,
    to,
    subject,
    text,
    html,
    envelope: { from: sender, to },
    messageId: `<${crypto.randomBytes(16).toString('hex')}@ag-farmer.com>`,
  });
  return { provider, ref: info.messageId || 'sent' };
}
