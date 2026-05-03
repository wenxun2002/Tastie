import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';
import admin from 'firebase-admin';

const args = new Set(process.argv.slice(2));
const dryRun = args.has('--dry-run');

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const repoRoot = path.resolve(__dirname, '..', '..');
const assetsMockDir = path.join(repoRoot, 'assets', 'mock');
const serviceAccountPath =
  process.env.GOOGLE_APPLICATION_CREDENTIALS ||
  path.join(__dirname, 'serviceAccountKey.json');

function readJson(filePath) {
  const raw = fs.readFileSync(filePath, 'utf8');
  return JSON.parse(raw);
}

function isObject(v) {
  return v !== null && typeof v === 'object' && !Array.isArray(v);
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function assertString(v, name) {
  assert(typeof v === 'string', `${name} must be string`);
}

function assertBool(v, name) {
  assert(typeof v === 'boolean', `${name} must be boolean`);
}

function assertInt(v, name) {
  assert(typeof v === 'number' && Number.isFinite(v), `${name} must be number`);
  assert(Number.isInteger(v), `${name} must be integer`);
}

function assertStringArray(v, name) {
  assert(Array.isArray(v), `${name} must be array`);
  for (let i = 0; i < v.length; i++) {
    assertString(v[i], `${name}[${i}]`);
  }
}

function validateTag(item, idx) {
  assert(isObject(item), `tag_list[${idx}] must be object`);
  assertInt(item.id, `tag_list[${idx}].id`);
  assertString(item.label, `tag_list[${idx}].label`);
  if (item.defaultEnabled !== undefined) assertBool(item.defaultEnabled, `tag_list[${idx}].defaultEnabled`);
}

function normalizeTag(item) {
  return {
    ...item,
    defaultEnabled: item.defaultEnabled ?? false,
  };
}

function initAdmin() {
  if (!fs.existsSync(serviceAccountPath)) {
    throw new Error(
      `Missing service account file.\n` +
        `Set GOOGLE_APPLICATION_CREDENTIALS or put serviceAccountKey.json at:\n` +
        `${path.join(__dirname, 'serviceAccountKey.json')}`,
    );
  }
  const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
  const projectId =
    process.env.FIREBASE_PROJECT_ID || serviceAccount.project_id || 'tastie-0314x';
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId,
  });
  return admin.firestore();
}

async function batchSetAll(db, collectionPath, items, docIdSelector) {
  const batchSize = 450; // keep under 500 ops
  let written = 0;
  for (let i = 0; i < items.length; i += batchSize) {
    const chunk = items.slice(i, i + batchSize);
    if (!dryRun) {
      const batch = db.batch();
      for (const item of chunk) {
        const docId = docIdSelector(item);
        const ref = db.collection(collectionPath).doc(docId);
        batch.set(ref, item, { merge: false });
      }
      await batch.commit();
    }
    written += chunk.length;
    console.log(`[${collectionPath}] ${dryRun ? 'validated' : 'written'} ${written}/${items.length}`);
  }
}

async function main() {
  console.log(`Assets dir: ${assetsMockDir}`);
  console.log(`Mode: ${dryRun ? 'DRY RUN (validate only)' : 'IMPORT (write to Firestore)'}`);

  const tagListPath = path.join(assetsMockDir, 'tag_list.json');

  if (!fs.existsSync(assetsMockDir)) {
    throw new Error(
      `assets/mock directory not found.\n` +
        `You deleted local mock JSON already, so this import script has no source data.\n` +
        `If you want to re-import into the new Firebase project, provide JSON sources again\n` +
        `(or we can copy data from your old Firestore to the new one).`,
    );
  }

  const tagList = readJson(tagListPath);

  assert(Array.isArray(tagList), 'tag_list.json must be an array');

  for (let i = 0; i < tagList.length; i++) validateTag(tagList[i], i);

  const tags = tagList.map(normalizeTag);

  if (dryRun) {
    console.log('Validation OK.');
    console.log(`tags: ${tags.length}`);
    return;
  }

  const db = initAdmin();
  db.settings({ ignoreUndefinedProperties: true });

  await batchSetAll(db, 'tags', tags, (x) => String(x.id));

  console.log('Import complete.');
}

main().catch((err) => {
  console.error('Import failed.');
  console.error(err?.stack || err);
  process.exit(1);
});
