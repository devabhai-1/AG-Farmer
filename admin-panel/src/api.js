export const API = import.meta.env.DEV ? '/api' : import.meta.env.VITE_API_URL || 'https://api.ag-farmer.com/api';
export const ENV_KEY = import.meta.env.VITE_ADMIN_KEY || '';

export const PLAN_ORDER = ['free', 'advanced', 'all', 'super', 'distributor'];

export const PLAN_NAMES = {
  free: 'Free',
  advanced: '₹299 लहसुन',
  all: '₹599 अफीम',
  super: '₹2650 सुपर',
  distributor: '₹13500 डिस्ट्रीब्यूटर',
};

export const CROPS = [
  ['all', 'सभी फसल'],
  ['afim', 'अफीम'],
  ['lasun', 'लहसुन'],
  ['wheat', 'गेहूँ'],
  ['rice', 'धान'],
  ['maize', 'मक्का'],
  ['cotton', 'कपास'],
  ['mustard', 'सरसों'],
  ['soybean', 'सोयाबीन'],
  ['groundnut', 'मूंगफली'],
  ['onion', 'प्याज'],
  ['potato', 'आलू'],
  ['tomato', 'टमाटर'],
  ['chilli', 'मिर्च'],
];

export function cropLabel(id) {
  return CROPS.find((row) => row[0] === id)?.[1] || id;
}

export async function call(api, key, action, extra = {}) {
  const res = await fetch(api, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ action, adminKey: key, ...extra }),
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok || body.ok === false) {
    throw new Error(body.message || 'एडमिन की गलत है या सर्वर नहीं मिला');
  }
  return body;
}
