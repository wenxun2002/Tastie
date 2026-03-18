import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';
import admin from 'firebase-admin';

const args = new Set(process.argv.slice(2));
const dryRun = args.has('--dry-run');

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const serviceAccountPath =
  process.env.GOOGLE_APPLICATION_CREDENTIALS ||
  path.join(__dirname, 'serviceAccountKey.json');

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
    process.env.FIREBASE_PROJECT_ID || serviceAccount.project_id || undefined;

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId,
  });

  const db = admin.firestore();
  db.settings({ ignoreUndefinedProperties: true });
  return db;
}

function parseAuthTime(s) {
  if (!s) return null;
  const d = new Date(s);
  return Number.isNaN(d.getTime()) ? null : d;
}

async function listAllAuthUsers() {
  const out = [];
  let nextPageToken = undefined;
  do {
    const res = await admin.auth().listUsers(1000, nextPageToken);
    out.push(...res.users);
    nextPageToken = res.pageToken;
  } while (nextPageToken);
  return out;
}

async function main() {
  console.log(`Mode: ${dryRun ? 'DRY RUN (no writes)' : 'SYNC (write to Firestore)'}`);
  initAdmin();

  const users = await listAllAuthUsers();
  console.log(`Auth users: ${users.length}`);

  const db = admin.firestore();
  const col = db.collection('users');

  const batchSize = 400;
  let processed = 0;

  for (let i = 0; i < users.length; i += batchSize) {
    const chunk = users.slice(i, i + batchSize);

    if (!dryRun) {
      const batch = db.batch();

      for (const u of chunk) {
        const ref = col.doc(u.uid);
        const snap = await ref.get();
        const exists = snap.exists;
        const data = exists ? (snap.data() || {}) : {};
        const hasStatus = typeof data.status === 'string' && data.status.trim().length > 0;
        const hasCreatedAt = data.createdAt != null;

        const authCreatedAt = parseAuthTime(u.metadata?.creationTime);
        const authLastLoginAt = parseAuthTime(u.metadata?.lastSignInTime);

        const payload = {
          uid: u.uid,
          email: u.email || '',
          displayName: u.displayName || '',
          photoURL: u.photoURL || '',
          providerIds: (u.providerData || []).map((p) => p.providerId).filter(Boolean),
          disabled: !!u.disabled,
          authCreatedAt: authCreatedAt ? admin.firestore.Timestamp.fromDate(authCreatedAt) : null,
          authLastLoginAt: authLastLoginAt ? admin.firestore.Timestamp.fromDate(authLastLoginAt) : null,
          lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        if (!exists || !hasCreatedAt) {
          payload.createdAt = authCreatedAt
            ? admin.firestore.Timestamp.fromDate(authCreatedAt)
            : admin.firestore.FieldValue.serverTimestamp();
        }

        if (!exists || !hasStatus) {
          payload.status = 'active';
        }

        batch.set(ref, payload, { merge: true });
      }

      await batch.commit();
    }

    processed += chunk.length;
    console.log(`[users] ${dryRun ? 'checked' : 'synced'} ${processed}/${users.length}`);
  }

  console.log('Done.');
}

main().catch((err) => {
  console.error('Sync failed.');
  console.error(err?.stack || err);
  process.exit(1);
});

