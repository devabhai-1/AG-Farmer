import { premiumLetter } from './layout.js';

const APP_URL = 'https://play.google.com/store/apps/details?id=com.agfarmer.app';
const RESET_PAGE = 'https://api.ag-farmer.com/api/reset-password';

export function shortResetUrl(code) {
  return `https://api.ag-farmer.com/api/r/${code}`;
}

export function resetPageForCode(oobCode) {
  const url = new URL(RESET_PAGE);
  url.searchParams.set('oobCode', oobCode);
  return url.toString();
}

function hello(name) {
  const clean = String(name || '').trim();
  return clean ? `Hello ${clean},` : 'Hello,';
}

export function welcomeLetter({ name }) {
  const caption = 'Congratulations. Your AG Farmer account is ready.';
  const paragraphs = [
    'Congratulations. Your account has been created.',
    'The crop chat, the season course, and your farm notes are open. Start with the crop you grow, and AG Farmer will stay with the work.',
    'We are glad you are here.',
  ];
  return {
    from: 'AG Farmer <account@ag-farmer.com>',
    subject: 'Congratulations — your AG Farmer account is ready',
    text: [
      caption,
      '',
      hello(name),
      '',
      ...paragraphs,
      '',
      APP_URL,
      '',
      'AG Farmer',
      'account@ag-farmer.com',
    ].join('\n'),
    html: premiumLetter({
      caption,
      eyebrow: 'Account',
      greeting: hello(name),
      paragraphs,
      buttonLabel: 'Open AG Farmer',
      buttonHref: APP_URL,
      fromAddress: 'account@ag-farmer.com',
      note: 'This note was sent because an AG Farmer account was created for this address.',
    }),
  };
}

export function reminderLetter({ name, pauseUrl }) {
  const caption = 'A short note from AG Farmer. Your field is still in our care.';
  const paragraphs = [
    'It has been a few days. This is a quiet reminder to look in on your crop.',
    'Your chat, your course, and your notes are still in the app. Open AG Farmer when you have a moment and tell us how the field is today.',
  ];
  const note = pauseUrl
    ? `You receive this note every few days. To pause these reminders, open ${pauseUrl}`
    : 'You receive this note every few days because you have an AG Farmer account.';
  return {
    from: 'AG Farmer <contact@ag-farmer.com>',
    subject: 'A note for your farm',
    text: [
      caption,
      '',
      hello(name),
      '',
      ...paragraphs,
      '',
      APP_URL,
      '',
      note,
      '',
      'AG Farmer',
      'contact@ag-farmer.com',
    ].join('\n'),
    html: premiumLetter({
      caption,
      eyebrow: 'From the farm desk',
      greeting: hello(name),
      paragraphs,
      buttonLabel: 'Continue in the app',
      buttonHref: APP_URL,
      fromAddress: 'contact@ag-farmer.com',
      note: 'You receive this note every few days because you have an AG Farmer account.',
      quietLabel: 'Pause these reminders',
      quietHref: pauseUrl || '',
    }),
  };
}

// Locked inbox pattern, 18 Oct 2026. From help@, this subject, this copy.
export function resetLetter({ name, link }) {
  const caption = 'Reset your AG Farmer password. This link expires in one hour.';
  const who = String(name || '').trim();
  const paragraphs = [
    'We received a request to reset the password for your AG Farmer account.',
    'Use the button below. Enter a new password, then confirm it. The link expires in one hour.',
    'If you did not ask for this, you can ignore the message. Your password will stay the same.',
  ];
  return {
    from: 'AG Farmer <help@ag-farmer.com>',
    subject: 'Reset your AG Farmer password',
    text: [
      caption,
      '',
      hello(who),
      '',
      ...paragraphs,
      '',
      link,
      '',
      'AG Farmer',
      'help@ag-farmer.com',
    ].join('\n'),
    html: premiumLetter({
      caption,
      eyebrow: 'Password reset',
      greeting: hello(who),
      paragraphs,
      buttonLabel: 'Set a new password',
      buttonHref: link,
      fromAddress: 'help@ag-farmer.com',
    }),
  };
}
