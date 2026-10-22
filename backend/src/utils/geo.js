/** Valid map point only. 0,0 and junk numbers are dropped. */
export function parseGeo(lat, lon) {
  const la = Number(lat);
  const lo = Number(lon);
  if (!Number.isFinite(la) || !Number.isFinite(lo)) return null;
  if (la < -90 || la > 90 || lo < -180 || lo > 180) return null;
  if (Math.abs(la) < 0.0001 && Math.abs(lo) < 0.0001) return null;
  return {
    lat: Math.round(la * 1e6) / 1e6,
    lon: Math.round(lo * 1e6) / 1e6,
  };
}
