/**
 * Audit Firestore recipes vs Hot & Humid Explore rules.
 * Uses Firebase CLI login (same as `firebase projects:list`).
 * Run: node scripts/audit-explore-recipes.cjs
 */
const auth = require('firebase-tools/lib/auth');
const { Client } = require('firebase-tools/lib/apiv2');
const api = require('firebase-tools/lib/api');
const { firestoreDocumentToJson } = require('firebase-tools/lib/mcp/tools/firestore/converter');

const PROJECT_ID = 'tastie-0314x';

const HOT_HUMID = {
  promoted: ['Cooling', 'Hydrating', 'Light'],
  neutral: ['Comfort'],
  suppressed: ['Energy', 'Warming'],
};
const POLICY_TAGS = [
  ...HOT_HUMID.promoted,
  ...HOT_HUMID.neutral,
  ...HOT_HUMID.suppressed,
];
const CANONICAL = new Set(POLICY_TAGS);

function setupCliAuth() {
  const account = auth.getGlobalDefaultAccount();
  if (!account?.tokens?.refresh_token) {
    throw new Error(
      'Firebase CLI not logged in. Run: firebase login',
    );
  }
  auth.setRefreshToken(account.tokens.refresh_token);
}

function isPublicVisible(data) {
  const s = data.status?.toString?.().toLowerCase?.();
  return s !== 'banned';
}

function hasCreatedAt(data) {
  return data.createdAt != null;
}

function normalizeTags(data) {
  const raw = data.tags;
  if (raw == null) return [];
  if (!Array.isArray(raw)) return [String(raw)];
  return raw.map((t) => String(t));
}

function intersectsPolicy(tags) {
  return tags.some((t) => CANONICAL.has(t));
}

function caseMismatchTags(tags) {
  return tags.filter((t) => {
    if (CANONICAL.has(t)) return false;
    const lower = t.toLowerCase();
    return POLICY_TAGS.some((p) => p.toLowerCase() === lower);
  });
}

async function fetchAllRecipes() {
  const client = new Client({
    auth: true,
    apiVersion: 'v1',
    urlPrefix: api.firestoreOrigin(),
  });
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

async function main() {
  setupCliAuth();
  console.log(`\n=== Explore recipe audit (project: ${PROJECT_ID}) ===\n`);

  const docs = await fetchAllRecipes();
  const rows = [];

  for (const doc of docs) {
    const data = doc;
    const id = (doc.__path__ ?? '').split('/').pop() || '(unknown)';
    const tags = normalizeTags(data);
    const hasTagsField = data.tags != null;
    const hasNonEmptyTags = tags.length > 0;
    const visible = isPublicVisible(data);
    const createdAt = hasCreatedAt(data);
    const policyMatch = hasNonEmptyTags && intersectsPolicy(tags);
    const hotHumidEligible = visible && createdAt && policyMatch;
    const caseBad = hasNonEmptyTags ? caseMismatchTags(tags) : [];

    rows.push({
      id,
      title: (data.title ?? '').toString().slice(0, 50),
      hasTagsField,
      hasNonEmptyTags,
      tags,
      status: data.status ?? '(missing)',
      visible,
      createdAt,
      policyMatch,
      hotHumidEligible,
      caseBad,
      likeCount: data.likeCount ?? data.like ?? '(missing)',
    });
  }

  const total = rows.length;
  const withTagsField = rows.filter((r) => r.hasTagsField).length;
  const withNonEmptyTags = rows.filter((r) => r.hasNonEmptyTags).length;
  const hotHumidEligible = rows.filter((r) => r.hotHumidEligible).length;
  const banned = rows.filter((r) => !r.visible).length;
  const noCreatedAt = rows.filter(
    (r) => r.hasNonEmptyTags && !r.createdAt,
  ).length;
  const tagsNoPolicy = rows.filter(
    (r) => r.hasNonEmptyTags && !r.policyMatch,
  ).length;
  const caseMismatch = rows.filter((r) => r.caseBad.length > 0);
  const emptyTagsField = rows.filter(
    (r) => r.hasTagsField && !r.hasNonEmptyTags,
  );

  console.log('--- Counts ---');
  console.log(`Total recipes in collection:      ${total}`);
  console.log(`Has tags field:                   ${withTagsField}`);
  console.log(`Non-empty tags array:             ${withNonEmptyTags}`);
  console.log(`Hot&Humid feed-eligible:          ${hotHumidEligible}`);
  console.log(`  (= not banned + has createdAt + tag in policy set)`);
  console.log(`Banned (status=banned):           ${banned}`);
  console.log(`Non-empty tags, no createdAt:     ${noCreatedAt}`);
  console.log(`Non-empty tags, no policy match:  ${tagsNoPolicy}`);
  console.log(`tags field but empty []:          ${emptyTagsField.length}`);
  console.log(`Case-only mismatch documents:     ${caseMismatch.length}`);

  const gap = withNonEmptyTags - hotHumidEligible;
  console.log(
    `\nGap (non-empty tags − eligible):  ${gap}  (your 47−41 = 6)`,
  );

  if (caseMismatch.length) {
    console.log('\n--- Case mismatch (would fail arrayContainsAny) ---');
    for (const r of caseMismatch) {
      console.log(
        `  ${r.id} | tags=${JSON.stringify(r.tags)} | wrong casing=${JSON.stringify(r.caseBad)}`,
      );
    }
  }

  const excluded = rows.filter(
    (r) => r.hasNonEmptyTags && !r.hotHumidEligible,
  );
  if (excluded.length) {
    console.log('\n--- Has tags but NOT Hot&Humid eligible ---');
    for (const r of excluded) {
      const reasons = [];
      if (!r.visible) reasons.push('banned');
      if (!r.createdAt) reasons.push('no createdAt');
      if (!r.policyMatch) reasons.push('tag not in Hot&Humid policy');
      console.log(
        `  ${r.id} | "${r.title}" | tags=${JSON.stringify(r.tags)} | status=${r.status} | [${reasons.join(', ')}]`,
      );
    }
  }

  const tagFreq = new Map();
  for (const r of rows) {
    for (const t of r.tags) {
      tagFreq.set(t, (tagFreq.get(t) ?? 0) + 1);
    }
  }
  console.log('\n--- Every tag string in Firestore (count) ---');
  [...tagFreq.entries()]
    .sort((a, b) => b[1] - a[1])
    .forEach(([t, n]) => {
      let note = CANONICAL.has(t) ? 'policy OK' : 'NOT in policy';
      if (
        !CANONICAL.has(t) &&
        POLICY_TAGS.some((p) => p.toLowerCase() === t.toLowerCase())
      ) {
        note = 'CASE MISMATCH (fix to canonical spelling)';
      }
      console.log(`  ${JSON.stringify(t)}: ${n} — ${note}`);
    });

  console.log('\n--- Canonical Hot&Humid policy tags ---');
  console.log(`  ${POLICY_TAGS.join(', ')}\n`);
}

main().catch((e) => {
  console.error(e.message || e);
  process.exit(1);
});
