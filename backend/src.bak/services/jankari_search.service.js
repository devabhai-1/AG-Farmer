import Sanscript from '@indic-transliteration/sanscript';
import { JankariService } from './jankari.service.js';

/**
 * Title-only search. Roman Hinglish is turned into Devanagari with
 * @indic-transliteration/sanscript (the barakhadi / Indian-script library).
 * A short phonetic step still catches spellings the library leaves unfinished,
 * and only the post title is searched.
 */

const CONS = {
  क: 'k', ख: 'K', ग: 'g', घ: 'G', ङ: 'n',
  च: 'c', छ: 'C', ज: 'j', झ: 'J', ञ: 'n',
  ट: 't', ठ: 'T', ड: 'd', ढ: 'D', ण: 'n',
  त: 't', थ: 'T', द: 'd', ध: 'D', न: 'n',
  प: 'p', फ: 'P', ब: 'b', भ: 'B', म: 'm',
  य: 'y', र: 'r', ल: 'l', व: 'v', श: 'S',
  ष: 'S', स: 's', ह: 'h', ळ: 'l',
  क़: 'k', ख़: 'K', ग़: 'g', ज़: 'z', फ़: 'P',
  ड़: 'r', ढ़: 'D',
};

const LATIN_MULTI = [
  ['ksh', 'X'], ['chh', 'C'], ['kh', 'K'], ['gh', 'G'], ['gy', 'Y'],
  ['jh', 'J'], ['th', 'T'], ['dh', 'D'], ['ph', 'P'], ['bh', 'B'],
  ['sh', 'S'], ['ch', 'c'], ['ng', 'n'],
];

const STOP = new Set([
  'ka', 'ki', 'ke', 'ko', 'se', 'me', 'mei', 'mein', 'main', 'mai',
  'pe', 'par', 'per', 'hi', 'to', 'na', 'ne', 'hai', 'hain', 'ho',
  'hoga', 'hogi', 'kaun', 'kya', 'kab', 'kaha', 'kahan', 'kaise',
  'wali', 'wala', 'wale', 'vali', 'vala', 'vale', 'aur', 'ya', 'bhi',
  'tak', 'ye', 'yeh', 'wo', 'woh', 'us', 'is', 'jo', 'so', 'or',
  'and', 'the', 'of', 'in', 'on', 'for', 'ek', 'hum', 'tum', 'aap',
  'karo', 'karna', 'kare', 'kara', 'dena', 'dijiye', 'batao', 'bata',
  'dikhao', 'search', 'post', 'time', 'taim', 'taime', 'samay', 'waqt',
  'kitni', 'kitna', 'kitne',
]);

const SOFT = {
  K: 'k', G: 'g', C: 'c', J: 'j', T: 't', D: 'd', P: 'p', B: 'b', S: 's',
};

function foldNukta(text) {
  return String(text)
    .replace(/फ़/g, 'फ')
    .replace(/ज़/g, 'ज')
    .replace(/ड़/g, 'ड')
    .replace(/ढ़/g, 'ढ')
    .replace(/क़/g, 'क')
    .replace(/ख़/g, 'ख')
    .replace(/ग़/g, 'ग');
}

function squeeze(code) {
  const raw = String(code);
  const folded = raw.replace(/(.)\1+/g, '$1');
  return folded.length >= 2 ? folded : raw;
}

function skeletonDevanagari(word) {
  const chars = [...foldNukta(word)];
  let out = '';
  for (let i = 0; i < chars.length; i += 1) {
    const ch = chars[i];
    if (ch === '़' || ch === '्') continue;
    if (ch === 'ं' || ch === 'ँ') {
      if (!out.endsWith('n')) out += 'n';
      continue;
    }
    if (!CONS[ch]) continue;
    const next = chars[i + 1];
    const third = chars[i + 2];
    if (next === '्' && CONS[third]) {
      if (ch === 'क' && third === 'ष') out += 'X';
      else if (ch === 'ज' && third === 'ञ') out += 'Y';
      else out += CONS[ch] + CONS[third];
      i += 2;
      continue;
    }
    out += CONS[ch];
  }
  return squeeze(out);
}

function skeletonLatin(word) {
  const raw = String(word).toLowerCase().replace(/[^a-z0-9]/g, '');
  let out = '';
  let i = 0;
  while (i < raw.length) {
    const ch = raw[i];
    if (ch >= '0' && ch <= '9') {
      out += ch;
      i += 1;
      continue;
    }
    let jumped = 0;
    for (const [latin, code] of LATIN_MULTI) {
      if (raw.startsWith(latin, i)) {
        out += code;
        jumped = latin.length;
        break;
      }
    }
    if (jumped) {
      i += jumped;
      continue;
    }
    if ('aeiou'.includes(ch)) {
      i += 1;
      continue;
    }
    if (ch === 'y') {
      const prevIsVowel = i > 0 && 'aeiou'.includes(raw[i - 1]);
      const nextIsVowelOrEnd = i + 1 >= raw.length || 'aeiou'.includes(raw[i + 1]);
      if (prevIsVowel && nextIsVowelOrEnd) {
        i += 1;
        continue;
      }
    }
    if (ch === 'w') out += 'v';
    else if (ch === 'f') out += 'P';
    else if (ch === 'q') out += 'k';
    else if (ch === 'x') out += 'ks';
    else if (ch === 'c') out += 'k';
    else out += ch;
    i += 1;
  }
  return squeeze(out);
}

function hindiTitleCodes(title) {
  const out = [];
  for (const part of foldNukta(title).split(/[^\u0900-\u097F]+/)) {
    const code = skeletonDevanagari(part);
    if (code.length >= 2) out.push(code);
  }
  return out;
}

function barakhadiForms(word) {
  const forms = new Set();
  const variants = [word, word.replace(/w/g, 'v'), word.replace(/v/g, 'w')];
  for (const variant of variants) {
    if (!/[a-z]/i.test(variant)) continue;
    for (const scheme of ['itrans', 'hk']) {
      try {
        const dev = foldNukta(Sanscript.t(variant, scheme, 'devanagari', { syncope: true }));
        if (/[\u0900-\u097F]/.test(dev)) forms.add(dev);
      } catch (_) {
        /* skip a scheme the library cannot read */
      }
    }
  }
  return [...forms];
}

function tokensOf(query) {
  return String(query || '')
    .trim()
    .split(/\s+/)
    .map((part) => part.trim())
    .filter((part) => {
      if (part.length < 2) return false;
      if (STOP.has(part.toLowerCase())) return false;
      if (/^\d+$/.test(part)) return true;
      if (/[\u0900-\u097F]/.test(part)) return skeletonDevanagari(part).length >= 2;
      if (/^[a-z]+$/i.test(part) && part.length >= 3) return true;
      return skeletonLatin(part).replace(/[0-9]/g, '').length >= 2;
    });
}

function englishWord(title, token) {
  const escaped = token.toLowerCase().replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return new RegExp(`(?:^|[^a-z0-9])${escaped}(?:[^a-z0-9]|$)`, 'i').test(title);
}

function soften(code) {
  return squeeze([...String(code)].map((ch) => SOFT[ch] || ch).join(''));
}

function codeOf(token) {
  const raw = /[\u0900-\u097F]/.test(token)
    ? skeletonDevanagari(token)
    : skeletonLatin(token).replace(/[0-9]/g, '');
  return squeeze(raw);
}

function runsEqual(a, b) {
  const left = a.replace(/(.)\1+/g, '$1');
  const right = b.replace(/(.)\1+/g, '$1');
  return left === right && left.length >= 1 && a.length >= 2 && b.length >= 2;
}

function damerau(a, b) {
  const n = a.length;
  const m = b.length;
  if (Math.abs(n - m) > 1) return 9;
  const dp = Array.from({ length: n + 1 }, () => new Array(m + 1).fill(0));
  for (let i = 0; i <= n; i += 1) dp[i][0] = i;
  for (let j = 0; j <= m; j += 1) dp[0][j] = j;
  for (let i = 1; i <= n; i += 1) {
    let rowBest = dp[i][0];
    for (let j = 1; j <= m; j += 1) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      let next = Math.min(dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + cost);
      if (i > 1 && j > 1 && a[i - 1] === b[j - 2] && a[i - 2] === b[j - 1]) {
        next = Math.min(next, dp[i - 2][j - 2] + 1);
      }
      dp[i][j] = next;
      if (next < rowBest) rowBest = next;
    }
    if (rowBest > 1) return 9;
  }
  return dp[n][m];
}

function englishWords(title) {
  return String(title || '').toLowerCase().split(/[^a-z0-9]+/).filter((word) => word.length >= 4);
}

function sameSound(a, b) {
  return (a === 'b' && b === 'v') || (a === 'v' && b === 'b');
}

function typoRank(query, target) {
  if (query === target || query.length < 2 || target.length < 2) return 9;
  if (Math.abs(query.length - target.length) > 1) return 9;
  if (damerau(query, target) !== 1) return 9;
  if (query.length === target.length) {
    let diffs = 0;
    let sound = true;
    for (let i = 0; i < query.length; i += 1) {
      if (query[i] === target[i]) continue;
      diffs += 1;
      if (!sameSound(query[i], target[i])) sound = false;
    }
    if (diffs === 1 && sound) return 0;
    for (let i = 0; i < query.length - 1; i += 1) {
      const swapped = query.slice(0, i) + query[i + 1] + query[i] + query.slice(i + 2);
      if (swapped === target) return 0;
    }
    return 2;
  }
  const longer = query.length > target.length ? query : target;
  const shorter = query.length > target.length ? target : query;
  for (let i = 0; i < longer.length; i += 1) {
    if (longer.slice(0, i) + longer.slice(i + 1) !== shorter) continue;
    return shorter.includes(longer[i]) ? 0 : 1;
  }
  return 3;
}

function collectFuzzy(soft, universe) {
  let best = 9;
  const buckets = new Map();
  for (const word of universe) {
    if (word.length < 2) continue;
    const folded = soften(word);
    const rank = typoRank(soft, folded);
    if (rank > 2) continue;
    if (rank < best) {
      best = rank;
      buckets.clear();
    }
    if (rank === best) {
      if (!buckets.has(folded)) buckets.set(folded, new Set());
      buckets.get(folded).add(word);
    }
  }
  const cap = soft.length < 3 ? 1 : 2;
  if (!buckets.size || buckets.size > cap) return new Set();
  const codes = new Set();
  for (const set of buckets.values()) {
    for (const word of set) codes.add(word);
  }
  return codes;
}

function dropOneExact(token, universe) {
  if (token.length < 5 || token.length > 18 || /[\u0900-\u097F]/.test(token)) return new Set();
  const found = new Map();
  const chars = [...token];
  for (let i = 0; i < chars.length; i += 1) {
    const cut = chars.slice(0, i).concat(chars.slice(i + 1)).join('');
    const soft = soften(codeOf(cut));
    if (soft.length < 3) continue;
    for (const word of universe) {
      const folded = soften(word);
      if (folded !== soft && !runsEqual(folded, soft)) continue;
      if (!found.has(folded)) found.set(folded, new Set());
      found.get(folded).add(word);
    }
  }
  if (found.size !== 1) return new Set();
  return [...found.values()][0];
}

function resolveToken(token, universe, englishUniverse) {
  const low = token.toLowerCase();
  const code = codeOf(token);
  const soft = soften(code);
  const exact = new Set();
  if (soft.length >= 2) {
    for (const word of universe) {
      const folded = soften(word);
      const tail = folded.startsWith(soft) ? folded.slice(soft.length) : null;
      const prefixOk = tail === '' || (soft.length >= 3 && tail) || (soft.length === 2 && tail === 'y');
      if (folded === soft || runsEqual(folded, soft) || (tail != null && prefixOk)) exact.add(word);
    }
  }
  const englishExact = englishUniverse.filter((word) => word === low);
  if (exact.size || englishExact.length) {
    return { kind: 'exact', codes: exact, english: new Set(englishExact) };
  }
  let fuzzy = soft.length >= 2 ? collectFuzzy(soft, universe) : new Set();
  if (!fuzzy.size) fuzzy = dropOneExact(low, universe);
  const englishFuzzy = new Set();
  if (!fuzzy.size && low.length >= 4 && /^[a-z]+$/.test(low)) {
    const near = englishUniverse.filter((word) => Math.abs(word.length - low.length) <= 1 && damerau(low, word) === 1);
    const distinct = new Set(near);
    if (distinct.size >= 1 && distinct.size <= 2) {
      for (const word of distinct) englishFuzzy.add(word);
    }
  }
  if (fuzzy.size || englishFuzzy.size) {
    return { kind: 'fuzzy', codes: fuzzy, english: englishFuzzy };
  }
  return { kind: 'none', codes: new Set(), english: new Set() };
}

function tokenHitsTitle(entry, token, resolved) {
  const low = token.toLowerCase();
  if (entry.titleHi.includes(foldNukta(token)) || englishWord(entry.titleEn, low)) return 8;
  if (entry.forms.get(low)?.some((form) => entry.titleHi.includes(form))) return 7;
  if (/^\d+$/.test(token) && (entry.titleHi.includes(token) || entry.titleEn.includes(token))) return 6;
  const plan = resolved.get(low);
  if (!plan || plan.kind === 'none') return 0;
  const codeHit = entry.codes.some((word) => plan.codes.has(word));
  const englishHit = englishWords(entry.titleEn).some((word) => plan.english.has(word));
  if (!codeHit && !englishHit) return 0;
  return plan.kind === 'exact' ? 5 : 3;
}

function indexed(posts) {
  const formCache = new Map();
  return posts.map((post) => {
    const titleHi = foldNukta(post.titleHi || '');
    const titleEn = String(post.titleEn || '').toLowerCase();
    return {
      post,
      titleHi,
      titleEn,
      codes: hindiTitleCodes(titleHi),
      forms: formCache,
    };
  });
}

function formsFor(cache, token) {
  const key = token.toLowerCase();
  if (!cache.has(key)) cache.set(key, barakhadiForms(key));
  return cache.get(key);
}

export function matchPosts(posts, query, limit = 80) {
  const tokens = tokensOf(query);
  if (!tokens.length || !Array.isArray(posts) || !posts.length) {
    return { posts: [], suggestions: [] };
  }
  const rows = indexed(posts);
  const cache = rows[0]?.forms || new Map();
  for (const token of tokens) formsFor(cache, token);
  const universe = new Set();
  const englishUniverse = new Set();
  for (const entry of rows) {
    for (const code of entry.codes) universe.add(code);
    for (const word of englishWords(entry.titleEn)) englishUniverse.add(word);
  }
  const resolved = new Map();
  for (const token of tokens) {
    resolved.set(token.toLowerCase(), resolveToken(token, universe, [...englishUniverse]));
  }
  const strict = [];
  const loose = [];
  for (const entry of rows) {
    const hits = tokens.map((token) => tokenHitsTitle(entry, token, resolved));
    const score = hits.reduce((sum, hit) => sum + hit, 0);
    if (!score || (hits[0] <= 0 && !hits.every((hit) => hit > 0))) continue;
    const row = { post: entry.post, score };
    if (hits.every((hit) => hit > 0)) strict.push(row);
    else if (hits[0] > 0) loose.push(row);
  }
  let ranked = strict;
  if (strict.length < 8) {
    const seen = new Set(strict.map((row) => row.post.id));
    ranked = [
      ...strict.map((row) => ({ ...row, score: row.score + 10 })),
      ...loose.filter((row) => !seen.has(row.post.id)),
    ];
  }
  ranked.sort((a, b) => b.score - a.score || String(a.post.id).localeCompare(String(b.post.id)));
  const top = ranked.slice(0, limit).map((row) => row.post);
  return {
    posts: top,
    suggestions: top.slice(0, 8).map((post) => ({
      id: post.id,
      titleHi: post.titleHi,
      titleEn: post.titleEn,
    })),
  };
}

export const JankariSearchService = {
  async search({ q, cropId, limit } = {}) {
    const query = String(q || '').trim().slice(0, 80);
    const id = String(cropId || 'all').trim();
    const posts = await JankariService.postsFor(id);
    const cap = Math.min(80, Math.max(1, Number(limit) || 80));
    const found = matchPosts(posts, query, cap);
    return { q: query, cropId: id || 'all', count: found.posts.length, ...found };
  },
};
