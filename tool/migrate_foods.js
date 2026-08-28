#!/usr/bin/env node
/**
 * One-time migration: single_male -> foods
 *
 * Throwaway. Never imported from lib/. Run it once, verify, then forget it.
 *
 * The old `single_male` collection is left completely untouched, so a bad run
 * costs nothing but a re-run.
 *
 * Usage:
 *   node tool/migrate_foods.js            # dry run, writes nothing
 *   node tool/migrate_foods.js --commit   # actually writes
 *
 * Needs a service account key. Firebase console -> Project settings ->
 * Service accounts -> Generate new private key. Save it OUTSIDE the repo, then
 * point .env at it (see .env.example):
 *
 *   GOOGLE_APPLICATION_CREDENTIALS=C:\path\to\serviceAccountKey.json
 *   FIREBASE_PROJECT_ID=diet-app-a908a
 *
 * This script reads .env itself, so nothing has to be exported by hand.
 *
 * The Admin SDK bypasses security rules, which is why this can write to
 * `foods` even though the deployed rules make it read-only to clients.
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const COMMIT = process.argv.includes('--commit');
const BATCH_SIZE = 400; // Firestore's hard limit is 500

/**
 * Minimal .env loader. Avoids a dotenv dependency for what is one file of
 * KEY=VALUE lines. Existing environment variables win, so an explicit export
 * can still override .env.
 */
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

    // Strip matching surrounding quotes, if any.
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

if (!KEY_PATH) {
  console.error('GOOGLE_APPLICATION_CREDENTIALS is not set. Copy .env.example to .env.');
  process.exit(1);
}
if (!fs.existsSync(KEY_PATH)) {
  console.error(`Service account key not found at:
  ${KEY_PATH}`);
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(require(KEY_PATH)),
  projectId: PROJECT_ID,
});
const db = admin.firestore();

/**
 * Arabic normalization for search: strip diacritics and tatweel, then unify
 * the letter forms people actually vary when typing.
 */
function normalizeArabic(s) {
  return s
    .replace(/[ً-ْـ]/g, '') // harakat + tatweel
    .replace(/[أإآ]/g, 'ا') // أ إ آ -> ا
    .replace(/ة/g, 'ه') // ة -> ه
    .replace(/ى/g, 'ي'); // ى -> ي
}

/** Search tokens: whole words plus prefixes, raw and Arabic-normalized. */
function buildSearchTokens(name) {
  const tokens = new Set();
  const forms = [name.toLowerCase().trim(), normalizeArabic(name.toLowerCase().trim())];

  for (const form of forms) {
    for (const word of form.split(/\s+/).filter(Boolean)) {
      tokens.add(word);
      for (let i = 2; i <= Math.min(word.length, 8); i++) {
        tokens.add(word.slice(0, i));
      }
    }
  }
  return [...tokens];
}

const num = (v) => {
  const n = typeof v === 'number' ? v : parseFloat(String(v ?? '0'));
  return Number.isFinite(n) ? n : 0;
};

async function main() {
  console.log(COMMIT ? '=== COMMIT MODE — will write ===' : '=== DRY RUN — writes nothing ===\n');

  const snap = await db.collection('single_male').get();
  console.log(`Read ${snap.size} docs from single_male\n`);

  if (snap.empty) {
    console.log('Nothing to migrate. Is the collection name right?');
    return;
  }

  const rows = [];
  const skipped = [];

  for (const doc of snap.docs) {
    const d = doc.data();
    const name = (d.name ?? '').toString().trim();

    if (!name) {
      skipped.push({ id: doc.id, why: 'no name' });
      continue;
    }

    // The old key names are the singular forms: `fat`, `carp`, `note`.
    const protein = num(d.protein);
    const carbs = num(d.carp);
    const fat = num(d.fat);

    rows.push({
      id: doc.id, // preserve ids so nothing has to be re-linked
      data: {
        name,
        nameNormalized: normalizeArabic(name.toLowerCase()),
        category: (d.category ?? '').toString() || null,
        active: true,
        per100: { protein, carbs, fat },
        kcalPer100: protein * 4 + carbs * 4 + fat * 9, // denormalized, sort only
        micros: null,
        imageUrl: null,
        pricePer100: d.price != null ? num(d.price) : null,
        note: (d.note ?? '').toString() || null,
        searchTokens: buildSearchTokens(name),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
    });
  }

  console.log(`Prepared ${rows.length} foods, skipped ${skipped.length}\n`);
  console.log('Sample of the first 5:');
  for (const r of rows.slice(0, 5)) {
    const p = r.data.per100;
    console.log(
      `  ${r.id}  ${r.data.name}  ` +
        `P${p.protein} C${p.carbs} F${p.fat} = ${r.data.kcalPer100.toFixed(0)} kcal/100g  ` +
        `[${r.data.searchTokens.slice(0, 4).join(', ')}...]`
    );
  }

  if (skipped.length) {
    console.log('\nSkipped:');
    for (const s of skipped) console.log(`  ${s.id}: ${s.why}`);
  }

  // Anything with zero macros across the board is worth eyeballing before it
  // becomes a catalog entry the user builds meals from.
  const suspicious = rows.filter(
    (r) => r.data.per100.protein === 0 && r.data.per100.carbs === 0 && r.data.per100.fat === 0
  );
  if (suspicious.length) {
    console.log(`\nWARNING: ${suspicious.length} entries have all-zero macros:`);
    for (const s of suspicious) console.log(`  ${s.id}: ${s.data.name}`);
  }

  if (!COMMIT) {
    console.log('\nDry run complete. Re-run with --commit to write.');
    return;
  }

  let written = 0;
  for (let i = 0; i < rows.length; i += BATCH_SIZE) {
    const batch = db.batch();
    for (const r of rows.slice(i, i + BATCH_SIZE)) {
      batch.set(db.collection('foods').doc(r.id), r.data);
    }
    await batch.commit();
    written += Math.min(BATCH_SIZE, rows.length - i);
    console.log(`  wrote ${written}/${rows.length}`);
  }

  console.log(`\nDone. ${written} foods written. single_male left untouched.`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
