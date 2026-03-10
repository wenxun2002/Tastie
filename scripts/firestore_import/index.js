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

function assertNumber(v, name) {
  assert(typeof v === 'number' && Number.isFinite(v), `${name} must be number`);
}

function assertInt(v, name) {
  assertNumber(v, name);
  assert(Number.isInteger(v), `${name} must be integer`);
}

function assertStringArray(v, name) {
  assert(Array.isArray(v), `${name} must be array`);
  for (let i = 0; i < v.length; i++) {
    assertString(v[i], `${name}[${i}]`);
  }
}

function validateIndexCard(item, idx) {
  assert(isObject(item), `index_list[${idx}] must be object`);
  assertInt(item.id, `index_list[${idx}].id`);
  assertInt(item.uid, `index_list[${idx}].uid`);
  assertString(item.cover, `index_list[${idx}].cover`);
  assertString(item.content, `index_list[${idx}].content`);
  assertString(item.avatar, `index_list[${idx}].avatar`);
  assertString(item.nickname, `index_list[${idx}].nickname`);
  assertInt(item.fav, `index_list[${idx}].fav`);
  assertInt(item.like, `index_list[${idx}].like`);
  if (item.comment !== undefined) assertInt(item.comment, `index_list[${idx}].comment`);
  assertStringArray(item.tags, `index_list[${idx}].tags`);
}

function validateTag(item, idx) {
  assert(isObject(item), `tag_list[${idx}] must be object`);
  assertInt(item.id, `tag_list[${idx}].id`);
  assertString(item.label, `tag_list[${idx}].label`);
  if (item.defaultEnabled !== undefined) assertBool(item.defaultEnabled, `tag_list[${idx}].defaultEnabled`);
}

function validateCardDetail(item, idx) {
  assert(isObject(item), `card_detail_list[${idx}] must be object`);
  assertInt(item.id, `card_detail_list[${idx}].id`);
  assertInt(item.uid, `card_detail_list[${idx}].uid`);
  assertString(item.title, `card_detail_list[${idx}].title`);
  assertString(item.content, `card_detail_list[${idx}].content`);

  assert(isObject(item.author), `card_detail_list[${idx}].author must be object`);
  assertString(item.author.nickname, `card_detail_list[${idx}].author.nickname`);
  assertString(item.author.avatar, `card_detail_list[${idx}].author.avatar`);

  assertStringArray(item.tags, `card_detail_list[${idx}].tags`);
  assertStringArray(item.images, `card_detail_list[${idx}].images`);

  assert(Array.isArray(item.ingredients), `card_detail_list[${idx}].ingredients must be array`);
  for (let j = 0; j < item.ingredients.length; j++) {
    const ing = item.ingredients[j];
    assert(isObject(ing), `card_detail_list[${idx}].ingredients[${j}] must be object`);
    assertString(ing.name, `card_detail_list[${idx}].ingredients[${j}].name`);
    assertNumber(ing.amount, `card_detail_list[${idx}].ingredients[${j}].amount`);
    assertString(ing.unit, `card_detail_list[${idx}].ingredients[${j}].unit`);
  }

  assert(Array.isArray(item.procedures), `card_detail_list[${idx}].procedures must be array`);
  for (let j = 0; j < item.procedures.length; j++) {
    assertString(item.procedures[j], `card_detail_list[${idx}].procedures[${j}]`);
  }

  if (item.nutrition !== undefined && item.nutrition !== null) {
    assert(isObject(item.nutrition), `card_detail_list[${idx}].nutrition must be object`);
    assertInt(item.nutrition.calories, `card_detail_list[${idx}].nutrition.calories`);
    assertNumber(item.nutrition.fat, `card_detail_list[${idx}].nutrition.fat`);
    assertNumber(item.nutrition.carbs, `card_detail_list[${idx}].nutrition.carbs`);
    assertNumber(item.nutrition.fiber, `card_detail_list[${idx}].nutrition.fiber`);
    assertNumber(item.nutrition.sugar, `card_detail_list[${idx}].nutrition.sugar`);
    assertNumber(item.nutrition.protein, `card_detail_list[${idx}].nutrition.protein`);
  }

  assertInt(item.fav, `card_detail_list[${idx}].fav`);
  assertInt(item.like, `card_detail_list[${idx}].like`);
  if (item.commentCount !== undefined) assertInt(item.commentCount, `card_detail_list[${idx}].commentCount`);
  assertString(item.date, `card_detail_list[${idx}].date`);
  assertString(item.address, `card_detail_list[${idx}].address`);
}

function normalizeIndexCard(item) {
  return {
    ...item,
    comment: item.comment ?? 0
  };
}

function normalizeTag(item) {
  return {
    ...item,
    defaultEnabled: item.defaultEnabled ?? false
  };
}

function normalizeCardDetail(item) {
  return {
    ...item,
    commentCount: item.commentCount ?? 0
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

  const indexListPath = path.join(assetsMockDir, 'index_list.json');
  const tagListPath = path.join(assetsMockDir, 'tag_list.json');
  const cardDetailListPath = path.join(assetsMockDir, 'card_detail_list.json');

  if (!fs.existsSync(assetsMockDir)) {
    throw new Error(
      `assets/mock directory not found.\n` +
        `You deleted local mock JSON already, so this import script has no source data.\n` +
        `If you want to re-import into the new Firebase project, provide JSON sources again\n` +
        `(or we can copy data from your old Firestore to the new one).`,
    );
  }

  const indexList = readJson(indexListPath);
  const tagList = readJson(tagListPath);
  const cardDetailList = readJson(cardDetailListPath);

  assert(Array.isArray(indexList), 'index_list.json must be an array');
  assert(Array.isArray(tagList), 'tag_list.json must be an array');
  assert(Array.isArray(cardDetailList), 'card_detail_list.json must be an array');

  for (let i = 0; i < indexList.length; i++) validateIndexCard(indexList[i], i);
  for (let i = 0; i < tagList.length; i++) validateTag(tagList[i], i);
  for (let i = 0; i < cardDetailList.length; i++) validateCardDetail(cardDetailList[i], i);

  // normalize optional fields for consistent Firestore documents
  const indexCards = indexList.map(normalizeIndexCard);
  const tags = tagList.map(normalizeTag);
  const cardDetails = cardDetailList.map(normalizeCardDetail);

  if (dryRun) {
    console.log('Validation OK.');
    console.log(`index_cards: ${indexCards.length}, tags: ${tags.length}, card_details: ${cardDetails.length}`);
    return;
  }

  const db = initAdmin();
  db.settings({ ignoreUndefinedProperties: true });

  await batchSetAll(db, 'index_cards', indexCards, (x) => String(x.id));
  await batchSetAll(db, 'tags', tags, (x) => String(x.id));
  await batchSetAll(db, 'card_details', cardDetails, (x) => String(x.id));

  console.log('Import complete.');
}

main().catch((err) => {
  console.error('Import failed.');
  console.error(err?.stack || err);
  process.exit(1);
});

