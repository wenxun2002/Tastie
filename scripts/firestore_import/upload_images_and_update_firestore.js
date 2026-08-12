import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';
import admin from 'firebase-admin';

const args = new Set(process.argv.slice(2));
const dryRun = args.has('--dry-run');
const emulatorOnly = args.has('--emulator-only');

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, '..', '..');
const assetsImagesDir = path.join(repoRoot, 'assets', 'images');

const serviceAccountPath =
  process.env.GOOGLE_APPLICATION_CREDENTIALS ||
  path.join(__dirname, 'serviceAccountKey.json');

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function isObject(v) {
  return v !== null && typeof v === 'object' && !Array.isArray(v);
}

/**
 * Firestore sentinel / value types must not be walked as plain maps.
 * `Object.entries(Timestamp)` yields `_seconds`/`_nanoseconds`; writing that
 * plain object back via `set(..., {merge:false})` stores a **map** instead of
 * a timestamp, which drops recipes from `orderBy('createdAt')` / range queries.
 */
function isFirestoreValueType(v) {
  if (v == null || typeof v !== 'object') return false;
  if (typeof Buffer !== 'undefined' && Buffer.isBuffer(v)) return true;
  // Prefer instanceof when admin is initialized; also match by constructor
  // name so unit-style checks work before initAdmin().
  try {
    const fs = admin.firestore;
    if (v instanceof fs.Timestamp) return true;
    if (v instanceof fs.GeoPoint) return true;
    if (v instanceof fs.DocumentReference) return true;
    if (typeof fs.Blob === 'function' && v instanceof fs.Blob) return true;
  } catch {
    // admin not ready
  }
  const name = v.constructor?.name;
  return (
    name === 'Timestamp' ||
    name === 'GeoPoint' ||
    name === 'DocumentReference' ||
    name === 'Blob'
  );
}

function initAdmin() {
  if (!fs.existsSync(serviceAccountPath)) {
    throw new Error(
      `Missing service account file.\n` +
        `Set GOOGLE_APPLICATION_CREDENTIALS or put serviceAccountKey.json at:\n` +
        serviceAccountPath,
    );
  }

  const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
  const projectId =
    process.env.FIREBASE_PROJECT_ID || serviceAccount.project_id || 'tastie-1701f';

  if (emulatorOnly) {
    if (!process.env.FIRESTORE_EMULATOR_HOST) {
      console.warn(
        '[warn] FIRESTORE_EMULATOR_HOST is not set. Set it to 127.0.0.1:8080 so writes hit the emulator.',
      );
    }
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId,
    });
    const db = admin.firestore();
    db.settings({ ignoreUndefinedProperties: true });
    return { db, bucket: null };
  }

  const storageBucket =
    process.env.FIREBASE_STORAGE_BUCKET || `${projectId}.firebasestorage.app`;

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId,
    storageBucket,
  });

  const db = admin.firestore();
  const bucket = admin.storage().bucket();

  db.settings({ ignoreUndefinedProperties: true });

  return { db, bucket };
}

function collectAssetImagePathsFromValue(value, set) {
  if (typeof value === 'string') {
    if (value.startsWith('assets/images/')) {
      set.add(value);
    }
  } else if (Array.isArray(value)) {
    for (const item of value) {
      collectAssetImagePathsFromValue(item, set);
    }
  } else if (isObject(value)) {
    for (const v of Object.values(value)) {
      collectAssetImagePathsFromValue(v, set);
    }
  }
}

function replaceAssetPaths(value, mapping) {
  if (typeof value === 'string') {
    return mapping[value] ?? value;
  }
  if (Array.isArray(value)) {
    return value.map((v) => replaceAssetPaths(v, mapping));
  }
  // Do not recurse into Timestamp / GeoPoint / DocumentReference / Blob / Buffer.
  if (isFirestoreValueType(value)) {
    return value;
  }
  if (isObject(value)) {
    const out = {};
    for (const [k, v] of Object.entries(value)) {
      out[k] = replaceAssetPaths(v, mapping);
    }
    return out;
  }
  return value;
}

function hasChanges(before, after) {
  return JSON.stringify(after) !== JSON.stringify(before);
}

function emulatorPublicUrl(assetPath) {
  const storagePath = assetPath.replace(/^assets\//, 'images/');
  const encoded = encodeURIComponent(storagePath);
  return `https://emulator.local/v0/b/emulator/o/${encoded}?alt=media`;
}

function assertLocalAssetExists(assetPath) {
  const relative = assetPath.replace(/^assets[\\/]/, 'assets/');
  const localPath = path.join(repoRoot, relative);
  if (!fs.existsSync(localPath)) {
    throw new Error(`Local asset not found for image: ${assetPath}\nExpected at: ${localPath}`);
  }
}

async function ensureUploaded(bucket, assetPath) {
  const relative = assetPath.replace(/^assets[\\/]/, 'assets/');
  const localPath = path.join(repoRoot, relative);
  if (!fs.existsSync(localPath)) {
    throw new Error(`Local asset not found for image: ${assetPath}\nExpected at: ${localPath}`);
  }

  const storagePath = assetPath.replace(/^assets\//, 'images/');
  const file = bucket.file(storagePath);
  const [exists] = await file.exists();

  if (!exists && !dryRun) {
    await bucket.upload(localPath, {
      destination: storagePath,
      public: true,
      metadata: {
        cacheControl: 'public,max-age=31536000',
      },
    });
    console.log(`[upload] ${assetPath} -> gs://${bucket.name}/${storagePath}`);
  } else {
    console.log(
      `[skip-upload] ${assetPath} -> gs://${bucket.name}/${storagePath} (exists=${exists}, dryRun=${dryRun})`,
    );
  }

  const encoded = encodeURIComponent(storagePath);
  const publicUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encoded}?alt=media`;
  return { storagePath, publicUrl };
}

function resolveModeLabel() {
  if (dryRun && emulatorOnly) {
    return 'DRY RUN + EMULATOR ONLY (fake URLs, no Firestore write)';
  }
  if (dryRun) {
    return 'DRY RUN (no upload, no write)';
  }
  if (emulatorOnly) {
    return 'EMULATOR ONLY (skip Storage, fake URLs + update Firestore)';
  }
  return 'MIGRATE (upload + update Firestore)';
}

async function buildAssetPathMapping(assetPaths, bucket) {
  const mapping = {};
  for (const assetPath of assetPaths) {
    if (emulatorOnly) {
      assertLocalAssetExists(assetPath);
      const publicUrl = emulatorPublicUrl(assetPath);
      console.log(`[emulator-only] ${assetPath} -> ${publicUrl}`);
      mapping[assetPath] = publicUrl;
      continue;
    }

    const { publicUrl } = await ensureUploaded(bucket, assetPath);
    mapping[assetPath] = publicUrl;
  }
  return mapping;
}

async function main() {
  if (args.has('--self-test')) {
    // Regression: Timestamp must survive replaceAssetPaths (not become a plain map).
    const { Timestamp, GeoPoint } = admin.firestore;
    const createdAt = new Timestamp(1_700_000_000, 123_000_000);
    const loc = new GeoPoint(1.23, 4.56);
    const mapping = {
      'assets/images/soup.jpg': 'https://cdn.example/soup.jpg',
    };
    const before = {
      title: 'Soup',
      createdAt,
      loc,
      imageUrls: ['assets/images/soup.jpg'],
      author: { nickname: 'A', avatar: '' },
      tags: ['Comfort'],
    };
    const after = replaceAssetPaths(before, mapping);
    if (!(after.createdAt instanceof Timestamp)) {
      throw new Error('self-test failed: createdAt lost Timestamp type');
    }
    if (!(after.loc instanceof GeoPoint)) {
      throw new Error('self-test failed: GeoPoint lost type');
    }
    if (after.createdAt.seconds !== createdAt.seconds) {
      throw new Error('self-test failed: Timestamp seconds changed');
    }
    if (after.imageUrls[0] !== mapping['assets/images/soup.jpg']) {
      throw new Error('self-test failed: asset path not replaced');
    }
    if (after.title !== 'Soup' || after.author.nickname !== 'A') {
      throw new Error('self-test failed: unrelated fields mutated');
    }
    console.log('self-test OK: Timestamp/GeoPoint preserved; asset paths rewritten');
    return;
  }

  console.log(`Repo root: ${repoRoot}`);
  console.log(`Assets images dir: ${assetsImagesDir}`);
  console.log(`Mode: ${resolveModeLabel()}`);

  assert(fs.existsSync(assetsImagesDir), `Directory not found: ${assetsImagesDir}`);

  const { db, bucket } = initAdmin();

  const collections = ['recipes'];
  const allDocs = [];
  const assetPaths = new Set();

  for (const col of collections) {
    const snap = await db.collection(col).get();
    console.log(`[scan] ${col}: ${snap.size} documents`);
    snap.forEach((doc) => {
      const data = doc.data();
      allDocs.push({ col, ref: doc.ref, data });
      collectAssetImagePathsFromValue(data, assetPaths);
    });
  }

  console.log(`Found ${assetPaths.size} unique asset image paths in Firestore.`);
  if (assetPaths.size === 0) {
    console.log('Nothing to migrate. Exiting.');
    return;
  }

  const mapping = await buildAssetPathMapping(assetPaths, bucket);

  let updatedCount = 0;
  for (const { col, ref, data } of allDocs) {
    const newData = replaceAssetPaths(data, mapping);
    const changed = hasChanges(data, newData);
    if (!changed) continue;

    console.log(`[update] ${col}/${ref.id}`);
    if (dryRun) {
      updatedCount += 1;
      continue;
    }

    const updated = await db.runTransaction(async (txn) => {
      const latestSnap = await txn.get(ref);
      if (!latestSnap.exists) return false;

      const latestData = latestSnap.data();
      const latestNewData = replaceAssetPaths(latestData, mapping);
      if (!hasChanges(latestData, latestNewData)) return false;

      // Preserve Firestore value types (Timestamp, etc.) via replaceAssetPaths.
      // Full-document set keeps nested array/map path rewrites exact while the
      // transaction protects against writes that land after the initial scan.
      txn.set(ref, latestNewData, { merge: false });
      return true;
    });
    if (updated) updatedCount += 1;
  }

  console.log(
    `Done. Docs scanned: ${allDocs.length}, docs updated: ${updatedCount}, images referenced: ${assetPaths.size}`,
  );
}

main().catch((err) => {
  console.error('Image migration failed.');
  console.error(err?.stack || err);
  process.exit(1);
});

