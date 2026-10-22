/** One-shot: set crop minPlans for new pricing (99 chat / 299 lasun / 599 afim). */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { crops } from './crops.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

for (const [id, crop] of Object.entries(crops)) {
  if (id === 'afim') {
    crop.minPlan = 'all';
  } else {
    // ₹299 Lasun Special unlocks every course crop except Afim
    crop.minPlan = 'advanced';
  }
}

const out = `/** Auto-updated crop catalog — minPlan: advanced (₹299) or all (afim ₹599) */\nexport const crops = ${JSON.stringify(crops, null, 2)};\n`;
fs.writeFileSync(path.join(__dirname, 'crops.js'), out, 'utf8');
console.log('Updated', Object.keys(crops).length, 'crops. afim=', crops.afim.minPlan, 'lasun=', crops.lasun.minPlan);
