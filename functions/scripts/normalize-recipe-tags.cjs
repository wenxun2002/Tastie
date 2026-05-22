/**
 * Normalize recipe `tags` to canonical casing (Comfort, Cooling, …).
 *
 * Dry run (default):
 *   node scripts/normalize-recipe-tags.cjs
 *
 * Apply to Firestore:
 *   node scripts/normalize-recipe-tags.cjs --apply
 */
const { readFileSync } = require('fs');
const { join } = require('path');
const auth = require('firebase-tools/lib/auth');
const { Client } = require('firebase-tools/lib/apiv2');
const api = require('firebase-tools/lib/api');
const { convertInputToValue } = require('firebase-tools/lib/mcp/tools/firestore/converter');
const { firestoreDocumentToJson } = require('firebase-tools/lib/mcp/tools/firestore/converter');

const PROJECT_ID = 'tastie-0314x';
const CANONICAL = JSON.parse(
  readFileSync(join(__dirname, 'tag-canonical.json'), 'utf8'),
);
const BY_LOWER = Object.fromEntries(
  CANONICAL.map((label) => [label.toLowerCase(), label]),
);

function setupCliAuth() {
  const account = auth.getGlobalDefaultAccount();
  if (!account?.tokens?.refresh_token) {
    throw new Error('Firebase CLI not logged in. Run: firebase login');
  }
  auth.setRefreshToken(account.tokens.refresh_token);
}

function normalizeTagList(tags) {
  if (!Array.isArray(tags)) return { normalized: [], changed: false };
  const seen = new Set();
  const normalized = [];
  let changed = false;

  for (const raw of tags) {
    const trimmed = String(raw).trim();
    if (!trimmed) continue;
    const canonical = BY_LOWER[trimmed.toLowerCase()] ?? trimmed;
    if (canonical !== trimmed) changed = true;
    if (!seen.has(canonical)) {
      seen.add(canonical);
      normalized.push(canonical);
    } else if (raw !== canonical) {
      changed = true;
    }
  }

  if (tags.length !== normalized.length) changed = true;
  if (!changed && tags.some((t, i) => String(t) !== normalized[i])) {
    changed = true;
  }
  return { normalized, changed };
}

async function fetchAllRecipes(client) {
  const url = `projects/${PROJECT_ID}/databases/(default)/documents:runQuery`;
  const res = await client.post(url, {
    structuredQuery: {
      from: [{ collectionId: 'recipes', allDescendants: false }],
      limit: 500,
    },
  });
  const documents = [];
  for (const row of res.body) {
    if (row.document) documents.push(row.document);
  }
  return documents.map(firestoreDocumentToJson);
}

async function patchTags(client, docPath, normalizedTags) {
  const basePath = `projects/${PROJECT_ID}/databases/(default)/documents`;
  const url = `${basePath}/${docPath}?updateMask.fieldPaths=tags`;
  await client.patch(url, {
    fields: {
      tags: convertInputToValue(normalizedTags),
    },
  });
}

async function main() {
  const apply = process.argv.includes('--apply');
  setupCliAuth();

  const client = new Client({
    auth: true,
    apiVersion: 'v1',
    urlPrefix: api.firestoreOrigin(),
  });

  console.log(`\n=== Normalize recipe tags (${PROJECT_ID}) ===`);
  console.log(`Mode: ${apply ? 'APPLY' : 'DRY RUN (pass --apply to write)'}\n`);

  const docs = await fetchAllRecipes(client);
  const pending = [];

  for (const doc of docs) {
    const docPath = doc.__path__;
    if (!docPath) continue;
    const raw = doc.tags;
    if (raw == null) continue;
    const tags = Array.isArray(raw) ? raw.map(String) : [String(raw)];
    const { normalized, changed } = normalizeTagList(tags);
    if (!changed) continue;
    pending.push({
      id: docPath.split('/').pop(),
      docPath,
      before: tags,
      after: normalized,
    });
  }

  if (pending.length === 0) {
    console.log('No documents need tag normalization.');
    return;
  }

  console.log(`Documents to update: ${pending.length}\n`);
  for (const p of pending) {
    console.log(`  ${p.id}`);
    console.log(`    before: ${JSON.stringify(p.before)}`);
    console.log(`    after:  ${JSON.stringify(p.after)}`);
  }

  if (!apply) {
    console.log('\nDry run complete. Re-run with --apply to update Firestore.\n');
    return;
  }

  console.log('\nApplying patches...');
  let ok = 0;
  for (const p of pending) {
    await patchTags(client, p.docPath, p.after);
    ok++;
    console.log(`  updated ${p.id}`);
  }
  console.log(`\nDone. Updated ${ok} document(s).\n`);
}

main().catch((e) => {
  console.error(e.message || e);
  process.exit(1);
});
