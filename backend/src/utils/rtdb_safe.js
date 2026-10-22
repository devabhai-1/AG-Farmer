/**
 * RTDB write sanitizer.
 *
 * Firebase Realtime Database rejects a write when:
 *  - a key contains any of  . # $ [ ] /  (or is empty / control chars)
 *  - a value is `undefined`
 * and it DELETES a path when the value is `null`.
 *
 * Any client-supplied object that is spread straight into `.set()` / `.update()`
 * is therefore both a write-integrity hazard (one bad key fails the whole op)
 * and a tampering vector (unexpected keys land in the tree). Run it through
 * `sanitizeForRtdb` first.
 */

const ILLEGAL_KEY = /[.#$/\[\]]/;
const MAX_DEPTH = 24;

function isPlainObject(v) {
  return v != null && typeof v === 'object' && !Array.isArray(v);
}

/**
 * Deep-copy a value keeping only RTDB-writable data:
 *  - drops `null` / `undefined` entries (so `set()` never nulls a sibling)
 *  - drops object keys containing illegal RTDB characters
 *  - preserves arrays (RTDB stores them as 0..n keyed objects), sanitizing items
 *  - caps recursion depth to avoid pathological/cyclic payloads
 *
 * @returns the sanitized value, or `undefined` when nothing writable remains.
 */
export function sanitizeForRtdb(value, depth = 0) {
  if (value === null || value === undefined) return undefined;

  if (Array.isArray(value)) {
    if (depth >= MAX_DEPTH) return undefined;
    const arr = [];
    for (const item of value) {
      const clean = sanitizeForRtdb(item, depth + 1);
      // RTDB arrays cannot contain holes/undefined — collapse them.
      if (clean !== undefined) arr.push(clean);
    }
    return arr;
  }

  if (isPlainObject(value)) {
    if (depth >= MAX_DEPTH) return undefined;
    const out = {};
    let kept = 0;
    for (const [key, raw] of Object.entries(value)) {
      const k = String(key);
      if (!k || ILLEGAL_KEY.test(k)) continue;
      const clean = sanitizeForRtdb(raw, depth + 1);
      if (clean === undefined) continue;
      out[k] = clean;
      kept += 1;
    }
    return kept ? out : undefined;
  }

  // Primitive (string / number / boolean). Reject non-finite numbers (RTDB rejects NaN/Infinity).
  if (typeof value === 'number' && !Number.isFinite(value)) return undefined;
  return value;
}

/**
 * Convenience for the common "merge a client object into a server-built row"
 * pattern. `base` keys (server-trusted) always win and are never dropped;
 * `client` is sanitized first so it can never inject illegal keys or null out
 * a trusted field. Keys listed in `block` are removed from the client object.
 */
export function mergeSafe(base, client, { block = [] } = {}) {
  const cleanClient = sanitizeForRtdb(client) || {};
  if (block.length) {
    for (const k of block) delete cleanClient[k];
  }
  return { ...cleanClient, ...base };
}
