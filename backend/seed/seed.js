/**
 * Seed catalog into Firebase RTDB: ag_farmer/catalog/*
 * Run: npm run seed  (needs serviceAccountKey.json)
 */
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';
import { plans, adminUnlock } from './plans.js';
import { crops } from './crops.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.resolve(__dirname, '../.env') });

async function main() {
  const { initFirebase, rootRef } = await import('../src/config/firebase.js');
  initFirebase();

  console.log('Seeding plans...');
  await rootRef('catalog/plans').set(plans);

  console.log(`Seeding ${Object.keys(crops).length} crops...`);
  await rootRef('catalog/crops').set(crops);

  await rootRef('catalog/adminUnlock').set(adminUnlock);

  await rootRef('catalog/meta').set({
    seededAt: Date.now(),
    version: 1,
  });

  console.log('Done. Paths:');
  console.log('  ag_farmer/catalog/plans');
  console.log('  ag_farmer/catalog/crops');
  process.exit(0);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
