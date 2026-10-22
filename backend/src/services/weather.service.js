import { isFirebaseReady, rootRef } from '../config/firebase.js';
import { emailKey } from '../utils/email_key.js';
import { parseGeo } from '../utils/geo.js';
import { IpChatService } from './ip_chat.service.js';

const CODE = {
  0: ['सूरज', 'Sun', '☀️'],
  1: ['सूरज', 'Sun', '☀️'],
  2: ['आधा बादल', 'Half cloud', '⛅'],
  3: ['बादल', 'Cloud', '☁️'],
  45: ['कोहरा', 'Fog', '🌫️'],
  48: ['कोहरा', 'Fog', '🌫️'],
  51: ['बारिश', 'Rain', '🌧️'],
  53: ['बारिश', 'Rain', '🌧️'],
  55: ['बारिश', 'Rain', '🌧️'],
  61: ['बारिश', 'Rain', '🌧️'],
  63: ['बारिश', 'Rain', '🌧️'],
  65: ['बारिश', 'Rain', '🌧️'],
  71: ['बारिश', 'Rain', '🌧️'],
  73: ['बारिश', 'Rain', '🌧️'],
  75: ['बारिश', 'Rain', '🌧️'],
  80: ['बारिश', 'Rain', '🌧️'],
  81: ['बारिश', 'Rain', '🌧️'],
  82: ['बारिश', 'Rain', '🌧️'],
  95: ['बिजली के साथ बादल', 'Lightning cloud', '⛈️'],
  96: ['बिजली के साथ बादल', 'Lightning cloud', '⛈️'],
  99: ['बिजली के साथ बादल', 'Lightning cloud', '⛈️'],
};

const weatherCache = new Map();
const WEATHER_MS = 8 * 60 * 1000;
const WEATHER_MAX = 4000;

function weatherGet(key) {
  const row = weatherCache.get(key);
  if (!row) return null;
  if (Date.now() - row.at > WEATHER_MS) {
    weatherCache.delete(key);
    return null;
  }
  return row.value;
}

function weatherSet(key, value) {
  if (weatherCache.size >= WEATHER_MAX) {
    const first = weatherCache.keys().next().value;
    weatherCache.delete(first);
  }
  weatherCache.set(key, { at: Date.now(), value });
  return value;
}

function describe(code) {
  return CODE[Number(code)] || ['मौसम', 'Weather', '🌡️'];
}

async function getJson(url) {
  const res = await fetch(url, {
    headers: { Accept: 'application/json', 'User-Agent': 'AGFarmer/1.0' },
    signal: AbortSignal.timeout(10000),
  });
  if (!res.ok) throw new Error(`weather_http_${res.status}`);
  return res.json();
}

function isPublicIp(ip) {
  const s = String(ip || '');
  if (!s || s === 'unknown' || s === '127.0.0.1' || s === '::1') return false;
  if (s.startsWith('10.') || s.startsWith('192.168.') || s.startsWith('169.254.')) return false;
  const m = s.match(/^172\.(\d+)\./);
  if (m && Number(m[1]) >= 16 && Number(m[1]) <= 31) return false;
  return true;
}

function asPlace(parts) {
  return parts.map((part) => String(part || '').trim()).filter(Boolean).join(', ');
}

async function readSavedLocation(uid, email) {
  if (!isFirebaseReady()) return null;
  const paths = [];
  if (uid) paths.push(`users/${uid}/location`);
  const ek = emailKey(email);
  if (ek) paths.push(`email_users/${ek}/location`);
  for (const path of paths) {
    try {
      const val = (await rootRef(path).get()).val();
      const lat = Number(val?.lat);
      const lon = Number(val?.lon);
      if (!Number.isFinite(lat) || !Number.isFinite(lon)) continue;
      if (val.precise === false) continue;
      return { lat, lon, place: String(val.place || '').trim() };
    } catch (_) {}
  }
  return null;
}

async function savePreciseLocation(uid, email, row) {
  if (!isFirebaseReady()) return;
  let prevPlace = '';
  if (uid) {
    try {
      const prev = (await rootRef(`users/${uid}/location`).get()).val();
      prevPlace = String(prev?.place || '').trim();
    } catch {
      /* keep empty */
    }
  }
  const payload = {
    lat: row.lat,
    lon: row.lon,
    place: String(row.place || prevPlace || '').trim(),
    precise: true,
    at: new Date().toISOString(),
    ts: Date.now(),
  };
  const ops = [];
  if (uid) ops.push(rootRef(`users/${uid}/location`).set(payload));
  const ek = emailKey(email);
  if (ek) ops.push(rootRef(`email_users/${ek}/location`).set(payload));
  if (ops.length) await Promise.all(ops).catch(() => {});
}

async function locateByIp(ip) {
  if (!isPublicIp(ip)) return null;
  const cached = weatherGet(`ip:${ip}`);
  if (cached) return cached;
  const safeIp = encodeURIComponent(ip);
  const tries = [
    async () => {
      const body = await getJson(`https://ipwho.is/${safeIp}`);
      if (!body?.success || !Number.isFinite(Number(body.latitude))) return null;
      return {
        lat: Number(body.latitude),
        lon: Number(body.longitude),
        place: asPlace([body.city, body.region]),
      };
    },
    async () => {
      const body = await getJson(
        `http://ip-api.com/json/${safeIp}?fields=status,city,regionName,lat,lon`,
      );
      if (body?.status !== 'success' || !Number.isFinite(Number(body.lat))) return null;
      return {
        lat: Number(body.lat),
        lon: Number(body.lon),
        place: asPlace([body.city, body.regionName]),
      };
    },
  ];
  for (const attempt of tries) {
    try {
      const hit = await attempt();
      if (hit) return weatherSet(`ip:${ip}`, hit);
    } catch (_) {}
  }
  return null;
}

function uniqueParts(parts) {
  const out = [];
  for (const part of parts) {
    const text = String(part || '').trim();
    if (!text || out.some((row) => row.toLowerCase() === text.toLowerCase())) continue;
    out.push(text);
  }
  return out;
}

async function placeName(lat, lon) {
  try {
    const url =
      `https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${lat}&lon=${lon}&zoom=16&addressdetails=1&accept-language=hi`;
    const body = await getJson(url);
    const address = body.address || {};
    const village =
      address.village ||
      address.hamlet ||
      address.suburb ||
      address.neighbourhood ||
      address.locality ||
      address.town;
    const area =
      address.county ||
      address.city_district ||
      address.state_district ||
      address.city;
    const parts = uniqueParts([village, area, address.state]);
    if (parts.length) return parts.join(', ');
    if (body.display_name) {
      return uniqueParts(String(body.display_name).split(',')).slice(0, 3).join(', ');
    }
  } catch (_) {}

  const url =
    `https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${lat}&longitude=${lon}&localityLanguage=hi`;
  const body = await getJson(url);
  const admin = Array.isArray(body.localityInfo?.administrative)
    ? body.localityInfo.administrative
    : [];
  const specific = admin
    .filter((row) => row?.name && Number(row.order) >= 6)
    .sort((a, b) => Number(b.order) - Number(a.order))
    .slice(0, 2)
    .map((row) => row.name);
  return uniqueParts([
    ...specific,
    body.locality,
    body.city,
    body.principalSubdivision,
  ]).slice(0, 3).join(', ');
}

function placeLabel(row) {
  return uniqueParts([
    row.name,
    row.admin4,
    row.admin3,
    row.admin2,
    row.admin1,
  ]).slice(0, 4).join(', ');
}

function nextRain(hourly) {
  const now = Date.now() - 30 * 60 * 1000;
  const times = hourly?.time || [];
  const pops = hourly?.precipitation_probability || [];
  const rains = hourly?.precipitation || [];
  let maxPop = 0;
  let next = null;
  for (let i = 0; i < times.length; i += 1) {
    const at = new Date(times[i]).getTime();
    if (!Number.isFinite(at) || at < now) continue;
    if (at > Date.now() + 36 * 60 * 60 * 1000) break;
    const probability = Number(pops[i] || 0);
    const mm = Number(rains[i] || 0);
    if (probability > maxPop) maxPop = probability;
    if (!next && (probability >= 40 || mm >= 0.4)) {
      next = { time: times[i], probability, mm };
    }
  }
  return { next, maxPop };
}

/** Guest (and any visitor): keep mosum place on the IP bucket for admin. */
async function rememberIpWeather(ip, uid, { lat, lon, place, precise }) {
  // Logged-in users already have users/{uid}/location; still stamp guest IPs.
  if (uid) return;
  if (!ip) return;
  try {
    await IpChatService.saveLocation({ ip, lat, lon, place, precise });
  } catch (_) {
    /* ignore */
  }
}

export class WeatherService {
  static async rememberFix({ uid, email, lat, lon, place = '' }) {
    const geo = parseGeo(lat, lon);
    if (!geo || !uid) return null;
    await savePreciseLocation(uid, email, { ...geo, place });
    return geo;
  }

  static async search(query) {
    const name = String(query || '').trim();
    if (name.length < 2) return [];
    const cached = weatherGet(`s:${name.toLowerCase()}`);
    if (cached) return cached;
    async function lookup(countryCode) {
      const url = new URL('https://geocoding-api.open-meteo.com/v1/search');
      url.searchParams.set('name', name);
      url.searchParams.set('count', '6');
      url.searchParams.set('language', 'hi');
      url.searchParams.set('format', 'json');
      if (countryCode) url.searchParams.set('countryCode', countryCode);
      const body = await getJson(url);
      return Array.isArray(body.results) ? body.results : [];
    }
    let rows = await lookup('IN');
    if (!rows.length) rows = await lookup('');
    return weatherSet(
      `s:${name.toLowerCase()}`,
      rows
      .filter((row) => Number.isFinite(row.latitude) && Number.isFinite(row.longitude))
      .slice(0, 6)
      .map((row) => ({
        label: placeLabel(row),
        lat: row.latitude,
        lon: row.longitude,
      })),
    );
  }

  static async forecast({ lat, lon, ip, place: requestedPlace, approximate = false, uid, email }) {
    const incomingLat = Number(lat);
    const incomingLon = Number(lon);
    const incomingPrecise = Number.isFinite(incomingLat) && Number.isFinite(incomingLon) && !approximate;
    let latitude = incomingLat;
    let longitude = incomingLon;
    let place = String(requestedPlace || '').trim();
    let precise = incomingPrecise;
    if (!incomingPrecise) {
      const saved = await readSavedLocation(uid, email);
      if (saved) {
        latitude = saved.lat;
        longitude = saved.lon;
        place = saved.place || place;
        precise = true;
      } else {
        const guestSaved = !uid ? IpChatService.readLocation(ip) : null;
        if (guestSaved) {
          latitude = guestSaved.lat;
          longitude = guestSaved.lon;
          place = guestSaved.place || place;
          precise = guestSaved.precise === true;
        } else if (!Number.isFinite(incomingLat) || !Number.isFinite(incomingLon)) {
          const located = await locateByIp(ip);
          if (!located) throw new Error('location_required');
          latitude = located.lat;
          longitude = located.lon;
          place = located.place || place;
          precise = false;
        } else {
          precise = false;
        }
      }
    }
    const cacheKey = `${precise ? 'f' : 'fa'}:${latitude.toFixed(2)}:${longitude.toFixed(2)}`;
    const cached = weatherGet(cacheKey);
    if (cached) {
      if (incomingPrecise) {
        await savePreciseLocation(uid, email, {
          lat: latitude,
          lon: longitude,
          place: cached.place || place,
        });
      }
      await rememberIpWeather(ip, uid, {
        lat: latitude,
        lon: longitude,
        place: cached.place || place,
        precise,
      });
      return cached;
    }
    if (!place) {
      place = await placeName(latitude, longitude).catch(() => '');
    }

    const url = new URL('https://api.open-meteo.com/v1/forecast');
    url.searchParams.set('latitude', String(latitude));
    url.searchParams.set('longitude', String(longitude));
    url.searchParams.set(
      'current',
      'temperature_2m,relative_humidity_2m,weather_code,precipitation,wind_speed_10m',
    );
    url.searchParams.set(
      'hourly',
      'precipitation_probability,precipitation,temperature_2m,weather_code',
    );
    url.searchParams.set(
      'daily',
      'precipitation_probability_max,precipitation_sum,temperature_2m_max,temperature_2m_min,weather_code',
    );
    url.searchParams.set('forecast_days', '12');
    url.searchParams.set('timezone', 'auto');

    const body = await getJson(url);
    const current = body.current || {};
    const [conditionHi, conditionEn, icon] = describe(current.weather_code);
    const rain = nextRain(body.hourly);
    const hours = [];
    const times = body.hourly?.time || [];
    const now = Date.now() - 30 * 60 * 1000;
    for (let i = 0; i < times.length && hours.length < 8; i += 1) {
      const at = new Date(times[i]).getTime();
      if (at < now) continue;
      const [hHi, hEn, hIcon] = describe(body.hourly.weather_code?.[i]);
      hours.push({
        time: times[i],
        temp: body.hourly.temperature_2m?.[i] ?? null,
        probability: body.hourly.precipitation_probability?.[i] ?? 0,
        conditionHi: hHi,
        conditionEn: hEn,
        icon: hIcon,
      });
    }
    const days = (body.daily?.time || []).slice(0, 12).map((date, i) => {
      const code = body.daily.weather_code?.[i];
      const [dHi, dEn, dIcon] = describe(code);
      const probability = body.daily.precipitation_probability_max?.[i] ?? 0;
      const rainMm = body.daily.precipitation_sum?.[i] ?? 0;
      const storm = [63, 65, 82, 95, 96, 99].includes(Number(code));
      const dayHours = [];
      for (let h = 0; h < times.length; h += 1) {
        if (!String(times[h]).startsWith(date)) continue;
        const [hHi, hEn, hIcon] = describe(body.hourly.weather_code?.[h]);
        dayHours.push({
          time: times[h],
          temp: body.hourly.temperature_2m?.[h] ?? null,
          probability: body.hourly.precipitation_probability?.[h] ?? 0,
          mm: body.hourly.precipitation?.[h] ?? 0,
          conditionHi: hHi,
          conditionEn: hEn,
          icon: hIcon,
        });
      }
      return {
        date,
        probability,
        rainMm,
        tempMax: body.daily.temperature_2m_max?.[i] ?? null,
        tempMin: body.daily.temperature_2m_min?.[i] ?? null,
        conditionHi: dHi,
        conditionEn: dEn,
        icon: dIcon,
        bad: probability >= 50 || rainMm >= 2 || storm,
        hours: dayHours,
      };
    });

    const forecast = weatherSet(cacheKey, {
      place: place || 'आपका क्षेत्र',
      lat: latitude,
      lon: longitude,
      temp: current.temperature_2m ?? null,
      humidity: current.relative_humidity_2m ?? null,
      wind: current.wind_speed_10m ?? null,
      rainNow: current.precipitation ?? 0,
      conditionHi,
      conditionEn,
      icon,
      precise,
      nextRain: rain.next,
      maxPop: rain.maxPop,
      hours,
      days,
    });
    if (incomingPrecise) {
      await savePreciseLocation(uid, email, {
        lat: latitude,
        lon: longitude,
        place: forecast.place,
      });
    }
    await rememberIpWeather(ip, uid, {
      lat: latitude,
      lon: longitude,
      place: forecast.place,
      precise,
    });
    return forecast;
  }

  /** Compact place + weather for GPT. Empty if nothing can be resolved. */
  static async farmBrief({
    uid,
    email,
    ip,
    lang = 'hi',
    address = '',
    lat,
    lon,
    place,
  }) {
    try {
      let useLat = Number(lat);
      let useLon = Number(lon);
      let usePlace = String(place || '').trim();
      if (!Number.isFinite(useLat) || !Number.isFinite(useLon)) {
        const saved = await readSavedLocation(uid, email);
        if (saved) {
          useLat = saved.lat;
          useLon = saved.lon;
          usePlace = saved.place || usePlace;
        }
      }
      if ((!Number.isFinite(useLat) || !Number.isFinite(useLon)) && String(address || '').trim()) {
        const hits = await WeatherService.search(address);
        if (hits[0]) {
          useLat = hits[0].lat;
          useLon = hits[0].lon;
          usePlace = hits[0].label || String(address).trim();
        }
      }
      const wx = await WeatherService.forecast({
        lat: useLat,
        lon: useLon,
        ip,
        place: usePlace,
        uid,
        email,
      });
      return formatFarmBrief(wx, lang);
    } catch (_) {
      return '';
    }
  }
}

function formatFarmBrief(wx, lang) {
  if (!wx || typeof wx !== 'object') return '';
  const hi = lang === 'hi';
  const temp = wx.temp == null ? '' : `${Math.round(Number(wx.temp))}°C`;
  const hum = wx.humidity == null ? '' : `${Math.round(Number(wx.humidity))}%`;
  const wind = wx.wind == null ? '' : `${Math.round(Number(wx.wind))} km/h`;
  const days = (Array.isArray(wx.days) ? wx.days : [])
    .slice(0, 3)
    .map((d) => {
      const name = String(d.date || '').slice(5);
      const cond = hi ? d.conditionHi : d.conditionEn;
      const max = d.tempMax == null ? '' : `${Math.round(Number(d.tempMax))}`;
      const min = d.tempMin == null ? '' : `${Math.round(Number(d.tempMin))}`;
      return hi
        ? `${name} ${cond} ${max}/${min}° बारिश ${d.probability || 0}%`
        : `${name} ${cond} ${max}/${min}° rain ${d.probability || 0}%`;
    })
    .filter(Boolean)
    .join('; ');
  const rain = wx.nextRain
    ? hi
      ? ` अगली बारिश संभावना ${wx.nextRain.probability}%.`
      : ` Next rain chance ${wx.nextRain.probability}%.`
    : '';
  const nowBits = [
    hi ? wx.conditionHi : wx.conditionEn,
    temp ? (hi ? `तापमान ${temp}` : `temp ${temp}`) : '',
    hum ? (hi ? `नमी ${hum}` : `humidity ${hum}`) : '',
    wind ? (hi ? `हवा ${wind}` : `wind ${wind}`) : '',
  ].filter(Boolean);
  const place = String(wx.place || '').trim() || (hi ? 'आपका क्षेत्र' : 'your area');
  if (hi) {
    return `जगह ${place}। अभी ${nowBits.join(', ')}.${rain}${days ? ` अगले 3 दिन: ${days}` : ''}`;
  }
  return `Place ${place}. Now ${nowBits.join(', ')}.${rain}${days ? ` Next 3 days: ${days}` : ''}`;
}
