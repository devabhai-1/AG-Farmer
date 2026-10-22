import nodemailer from 'nodemailer';
import { env } from '../config/env.js';

let transporter;

function getTransporter() {
  if (transporter) return transporter;
  if (!env.smtpUser || !env.smtpPass) return null;

  transporter = nodemailer.createTransport({
    host: env.smtpHost,
    port: env.smtpPort,
    secure: env.smtpSecure,
    auth: {
      user: env.smtpUser,
      pass: env.smtpPass,
    },
  });
  return transporter;
}

export function isMailConfigured() {
  return Boolean(env.smtpUser && env.smtpPass);
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

/**
 * Send password-reset OTP to the user's email inbox.
 */
export async function sendPasswordResetOtpEmail({ to, otp, name }) {
  const minutes = Math.max(1, Math.round(env.otpTtlSec / 60));
  const subject = 'AG Farmer — Password Reset OTP';
  const text = [
    `Hello${name ? ` ${name}` : ''},`,
    '',
    `Your AG Farmer password reset OTP is: ${otp}`,
    `Valid for ${minutes} minutes. Do not share this code.`,
    '',
    'If you did not request this, ignore this email.',
    '',
    '— AG Farmer',
  ].join('\n');

  const html = `
    <div style="font-family:Arial,sans-serif;max-width:480px;margin:0 auto;padding:24px;color:#1a2e1a">
      <h2 style="color:#1b5e20;margin:0 0 12px">AG Farmer</h2>
      <p>Hello${name ? ` ${escapeHtml(name)}` : ''},</p>
      <p>Your password reset OTP is:</p>
      <p style="font-size:28px;letter-spacing:6px;font-weight:700;color:#1b5e20;margin:16px 0">${otp}</p>
      <p style="color:#555">Valid for <strong>${minutes} minutes</strong>. Do not share this code.</p>
      <p style="color:#777;font-size:13px">If you did not request this, you can ignore this email.</p>
    </div>
  `;

  const tx = getTransporter();
  if (!tx) {
    console.log(`[password-reset-email] SMTP not configured — OTP for ${to}: ${otp}`);
    return { provider: 'log', ref: 'console' };
  }

  const info = await tx.sendMail({
    from: env.smtpFrom || env.smtpUser,
    to,
    subject,
    text,
    html,
  });

  console.log(`[password-reset-email] sent to ${to} id=${info.messageId}`);
  return { provider: 'smtp', ref: info.messageId || 'sent' };
}

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
