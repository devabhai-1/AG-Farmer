// Locked inbox pattern, 18 Oct 2026. Remote logo only. Do not switch this to a cid: image.
const LOGO_URL = 'https://api.ag-farmer.com/api/mail-logo.png';

export function escapeHtml(value) {
  return String(value || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function paragraph(line) {
  return `<p style="margin:0 0 16px;font-family:Arial,Helvetica,sans-serif;font-size:16px;line-height:1.6;color:#3d4d5c;">${escapeHtml(line)}</p>`;
}

function buttonRow(label, href) {
  const safeHref = escapeHtml(href);
  const safeLabel = escapeHtml(label || 'Open AG Farmer');
  return `
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" align="center" style="margin:6px auto 18px;">
      <tr>
        <td align="center" bgcolor="#073a5c" style="background-color:#073a5c;border-radius:999px;">
          <a href="${safeHref}" style="display:inline-block;padding:14px 28px;font-family:Arial,Helvetica,sans-serif;font-size:15px;line-height:1.2;font-weight:bold;color:#f6e7c1;text-decoration:none;">${safeLabel}</a>
        </td>
      </tr>
    </table>`;
}

/**
 * The navy card that Gmail placed in the inbox on 17 Oct.
 * The logo stays a normal image link, not a file inside the mail.
 */
export function premiumLetter({
  caption,
  eyebrow,
  greeting,
  paragraphs,
  buttonLabel,
  buttonHref,
  fromAddress,
  note,
  quietLabel,
  quietHref,
}) {
  const body = (paragraphs || []).map(paragraph).join('');
  const button = buttonHref ? buttonRow(buttonLabel, buttonHref) : '';
  const quiet = quietHref
    ? `<p style="margin:0 0 8px;font-family:Arial,Helvetica,sans-serif;font-size:13px;line-height:1.5;"><a href="${escapeHtml(quietHref)}" style="color:#073a5c;text-decoration:underline;">${escapeHtml(quietLabel || 'Pause these reminders')}</a></p>`
    : '';
  const noteHtml = note
    ? `<p style="margin:0 0 20px;font-family:Arial,Helvetica,sans-serif;font-size:13px;line-height:1.55;color:#7a6a58;">${escapeHtml(note)}</p>`
    : '';
  const brow = eyebrow
    ? `<p style="margin:8px 0 0;font-family:Arial,Helvetica,sans-serif;font-size:12px;line-height:1.4;letter-spacing:1.2px;text-transform:uppercase;color:#e6d3a3;">${escapeHtml(eyebrow)}</p>`
    : '';

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta name="color-scheme" content="light">
  <meta name="supported-color-schemes" content="light">
  <title>${escapeHtml(caption || 'AG Farmer')}</title>
</head>
<body style="margin:0;padding:0;background-color:#f4f0e8;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#f4f0e8" style="background-color:#f4f0e8;">
    <tr>
      <td align="center" style="padding:24px 12px;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#ffffff" style="max-width:560px;width:100%;background-color:#ffffff;border:1px solid #e6dfd2;">
          <tr>
            <td height="4" bgcolor="#c4a46a" style="height:4px;font-size:0;line-height:0;background-color:#c4a46a;">&nbsp;</td>
          </tr>
          <tr>
            <td align="center" bgcolor="#073a5c" style="background-color:#073a5c;padding:28px 24px 24px;">
              <img src="${LOGO_URL}" width="88" height="88" alt="" style="display:block;margin:0 auto;width:88px;height:88px;border:0;outline:none;text-decoration:none;">
              <p style="margin:14px 0 0;font-family:Arial,Helvetica,sans-serif;font-size:22px;line-height:1.2;font-weight:bold;color:#ffffff;">AG Farmer</p>
              ${brow}
            </td>
          </tr>
          <tr>
            <td style="padding:28px 24px 8px;">
              <p style="margin:0 0 16px;font-family:Arial,Helvetica,sans-serif;font-size:18px;line-height:1.4;color:#16324a;">${escapeHtml(greeting || 'Hello,')}</p>
              ${body}
              ${button}
              ${noteHtml}
              ${quiet}
            </td>
          </tr>
          <tr>
            <td align="center" style="padding:16px 24px 22px;border-top:1px solid #efe8dc;font-family:Arial,Helvetica,sans-serif;">
              <p style="margin:0;font-size:13px;line-height:1.4;font-weight:bold;color:#16324a;">AG Farmer</p>
              <p style="margin:4px 0 0;font-size:12px;line-height:1.4;color:#7a6a58;">${escapeHtml(fromAddress || '')}</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

export function quietPage(ok) {
  const title = ok ? 'Notes paused' : 'Link not valid';
  const line = ok
    ? 'Reminder notes from contact@ag-farmer.com are paused for this address. Your account and password mail are unchanged.'
    : 'This link is incomplete. Open the latest note from AG Farmer and use the pause link there.';
  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${title}</title></head><body style="margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;background:#f4f0e8;font-family:Arial,Helvetica,sans-serif;color:#16324a"><div style="max-width:420px;margin:24px;background:#fff;border-radius:18px;padding:28px;border:1px solid #e6dfd2;text-align:center"><img src="${LOGO_URL}" alt="AG Farmer" width="72" height="72"><h1 style="font-size:26px;margin:14px 0 8px">${title}</h1><p style="color:#5c6b78;line-height:1.5">${line}</p></div></body></html>`;
}
