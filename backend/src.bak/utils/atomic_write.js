import fs from 'fs';
import path from 'path';

/** Write JSON by temp file + rename so a crash cannot leave a half file. */
export function writeJsonAtomic(file, data) {
  const dir = path.dirname(file);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  const tmp = `${file}.${process.pid}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(data, null, 2), 'utf8');
  try {
    fs.renameSync(tmp, file);
  } catch (err) {
    if (err?.code !== 'EEXIST' && err?.code !== 'EPERM') throw err;
    fs.rmSync(file, { force: true });
    fs.renameSync(tmp, file);
  }
}
