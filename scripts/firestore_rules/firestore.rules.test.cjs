const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  increment,
  serverTimestamp,
  setDoc,
  updateDoc,
} = require('firebase/firestore');

const projectId = 'demo-tastie-rules';
let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: '127.0.0.1',
      port: 8080,
      rules: fs.readFileSync(path.join(__dirname, '..', '..', 'firestore.rules'), 'utf8'),
    },
  });
});

test.after(async () => {
  await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
});

function authedDb(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

function adminDb() {
  return testEnv.unauthenticatedContext().firestore();
}

async function seed(pathSegments, data) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), ...pathSegments), data);
  });
}

async function seedAdminUser(uid = 'admin') {
  await seed(['users', uid], {
    uid,
    email: `${uid}@example.test`,
    displayName: 'Admin',
    photoURL: null,
    providerIds: ['password'],
    role: 'admin',
  });
}

async function seedRecipe(id = 'recipe1', overrides = {}) {
  await seed(['recipes', id], {
    userId: 'owner',
    authorUid: 'owner',
    title: 'Soup',
    status: 'active',
    likeCount: 0,
    favCount: 0,
    commentCount: 0,
    createdAt: new Date('2026-01-01T00:00:00.000Z'),
    ...overrides,
  });
}

test('users cannot grant themselves admin role on profile create or update', async () => {
  const alice = authedDb('alice');
  const aliceRef = doc(alice, 'users/alice');

  await assertFails(setDoc(aliceRef, {
    uid: 'alice',
    email: 'alice@example.test',
    displayName: 'Alice',
    photoURL: null,
    providerIds: ['password'],
    role: 'admin',
    createdAt: serverTimestamp(),
    lastLoginAt: serverTimestamp(),
  }));

  await assertSucceeds(setDoc(aliceRef, {
    uid: 'alice',
    email: 'alice@example.test',
    displayName: 'Alice',
    photoURL: null,
    providerIds: ['password'],
    createdAt: serverTimestamp(),
    lastLoginAt: serverTimestamp(),
  }));

  await assertFails(updateDoc(aliceRef, {role: 'admin'}));
  await assertFails(setDoc(doc(alice, 'system_configs/weather_rules'), {enabled: false}));
});

test('existing admin profiles still authorize admin-only system config writes', async () => {
  await seedAdminUser('admin');

  await assertSucceeds(setDoc(
    doc(authedDb('admin'), 'system_configs/weather_rules'),
    {enabled: true},
  ));
});

test('only admins can change recipe moderation status', async () => {
  await seedAdminUser('admin');
  await seedRecipe('recipe1');

  await assertFails(updateDoc(doc(authedDb('attacker'), 'recipes/recipe1'), {
    status: 'banned',
  }));

  await assertSucceeds(updateDoc(doc(authedDb('admin'), 'recipes/recipe1'), {
    status: 'banned',
  }));

  await assertFails(updateDoc(doc(authedDb('owner'), 'recipes/recipe1'), {
    status: 'active',
  }));
});

test('engagement counters only accept single-step numeric increments', async () => {
  await seedRecipe('recipe1');
  const recipeRef = doc(authedDb('viewer'), 'recipes/recipe1');

  await assertSucceeds(updateDoc(recipeRef, {likeCount: increment(1)}));
  await assertSucceeds(updateDoc(recipeRef, {favCount: increment(1)}));

  await assertFails(updateDoc(recipeRef, {likeCount: 999}));
  await assertFails(updateDoc(recipeRef, {favCount: -1}));
  await assertFails(updateDoc(recipeRef, {likeCount: 'poisoned'}));
  await assertFails(updateDoc(recipeRef, {
    likeCount: increment(1),
    favCount: increment(1),
  }));
});

test('client-created recipes cannot start banned or with inflated counters', async () => {
  const owner = authedDb('owner');
  const validRecipe = {
    userId: 'owner',
    authorUid: 'owner',
    title: 'Soup',
    status: 'active',
    likeCount: 0,
    favCount: 0,
    commentCount: 0,
    createdAt: serverTimestamp(),
  };

  await assertSucceeds(setDoc(doc(owner, 'recipes/valid'), validRecipe));
  await assertFails(setDoc(doc(owner, 'recipes/banned'), {
    ...validRecipe,
    status: 'banned',
  }));
  await assertFails(setDoc(doc(owner, 'recipes/inflated'), {
    ...validRecipe,
    likeCount: 1000,
  }));
});
