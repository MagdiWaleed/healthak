/**
 * One-off fix: `foods.category` was carried verbatim from the legacy
 * `single_male` collection by migrate_foods.js, which never translated or
 * corrected it. The legacy data used English macro-type tags with the same
 * typos CLAUDE.md already documents for other fields -- `carp` (a
 * misspelling of `carbs`) and `protien` -- so the catalog's category filter
 * chips render "protein" / "protien" / "carp" instead of Arabic.
 *
 * This corrects `category` in place to the three Arabic macro labels the
 * rest of the new UI already uses (بروتين / كارب / دهون). Values already in
 * Arabic, or not recognized, are left untouched and reported for manual
 * review -- this script never invents a category.
 *
 * Dry run by default; --commit writes.
 *
 *   node tool/normalize_food_categories.js
 *   node tool/normalize_food_categories.js --commit
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const COMMIT = process.argv.includes('--commit');

/** Same minimal .env loader as migrate_foods.js -- see that file's comment. */
function loadDotEnv() {
  const file = path.join(__dirname, '..', '.env');
  if (!fs.existsSync(file)) return;
  const text = fs.readFileSync(file, 'utf8');
  for (const raw of text.split('\n')) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const eq = line.indexOf('=');
    if (eq === -1) continue;
    const key = line.slice(0, eq).trim();
    let value = line.slice(eq + 1).trim();
    const q = value[0];
    if (value.length > 1 && q === value[value.length - 1] && (q === '"' || q === "'")) {
      value = value.slice(1, -1);
    }
    if (!(key in process.env)) process.env[key] = value;
  }
}
loadDotEnv();

const KEY_PATH = process.env.GOOGLE_APPLICATION_CREDENTIALS;
const PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'diet-app-a908a';

if (!KEY_PATH || !fs.existsSync(KEY_PATH)) {
  console.error('GOOGLE_APPLICATION_CREDENTIALS is not set or the key file is missing.');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(require(KEY_PATH)),
  projectId: PROJECT_ID,
});
const db = admin.firestore();

// Known raw values -> the Arabic label the catalog screen should show.
// Matched case-insensitively after trimming.
const MAP = {
  protein: 'بروتين',
  protien: 'بروتين', // legacy typo
  carbs: 'كارب',
  carp: 'كارب', // legacy typo -- see CLAUDE.md's naming table
  carbohydrate: 'كارب',
  fat: 'دهون',
  fats: 'دهون',
};

(async () => {
  const snapshot = await db.collection('foods').get();
  const toWrite = [];
  const skipped = [];

  for (const doc of snapshot.docs) {
    const raw = doc.data().category;
    if (raw === null || raw === undefined || raw === '') continue;

    const key = String(raw).trim().toLowerCase();
    const mapped = MAP[key];

    if (mapped) {
      if (raw !== mapped) toWrite.push({ id: doc.id, name: doc.data().name, from: raw, to: mapped });
    } else {
      skipped.push({ id: doc.id, name: doc.data().name, category: raw });
    }
  }

  console.log(`${toWrite.length} to update, ${skipped.length} unrecognized (left unchanged):\n`);
  for (const r of toWrite) {
    console.log(`  ${r.name.padEnd(20)} "${r.from}" -> "${r.to}"`);
  }
  if (skipped.length) {
    console.log('\nUnrecognized category values (not touched):');
    for (const r of skipped) {
      console.log(`  ${r.name.padEnd(20)} "${r.category}"`);
    }
  }

  if (!COMMIT) {
    console.log('\nDry run only. Re-run with --commit to write.');
    process.exit(0);
  }

  const batch = db.batch();
  for (const r of toWrite) {
    batch.update(db.collection('foods').doc(r.id), { category: r.to });
  }
  await batch.commit();
  console.log(`\nCommitted ${toWrite.length} update(s).`);
  process.exit(0);
})();
