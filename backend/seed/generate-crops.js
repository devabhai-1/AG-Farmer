import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const dartPath = path.resolve(__dirname, '../../app/ag_farmer/lib/data/crop_catalog.dart');
const outPath = path.resolve(__dirname, 'crops.js');

const dart = fs.readFileSync(dartPath, 'utf8');
const re =
  /CropItem\(\s*id:\s*'([^']+)',\s*nameEn:\s*'([^']*)',\s*nameHi:\s*'([^']*)',\s*emoji:\s*'([^']*)',\s*minPlan:\s*(\w+),\s*priority:\s*(\d+)(?:,\s*hasLiveAnalysis:\s*(true|false))?/g;

const planMap = {
  local: 'local',
  advanced: 'advanced',
  all: 'all',
  superPro: 'super',
};

const crops = {};
let m;
while ((m = re.exec(dart))) {
  crops[m[1]] = {
    id: m[1],
    nameEn: m[2],
    nameHi: m[3],
    emoji: m[4],
    minPlan: planMap[m[5]] || m[5],
    priority: Number(m[6]),
    hasLiveAnalysis: m[7] === 'true',
    active: true,
  };
}

const js =
  '/** Auto-mapped from Flutter crop_catalog.dart — run: node seed/generate-crops.js */\n' +
  'export const crops = ' +
  JSON.stringify(crops, null, 2) +
  ';\n';

fs.writeFileSync(outPath, js, 'utf8');
console.log(`Wrote ${Object.keys(crops).length} crops → seed/crops.js`);
console.log('afim:', crops.afim);
