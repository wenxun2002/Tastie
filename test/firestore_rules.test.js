const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  deleteDoc,
  doc,
  increment,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
} = require('firebase/firestore');

let testEnv;

function rulesPath() {
  return path.resolve(__dirname, '..', 'firestore.rules');
}

function recipePayload(userId, overrides = {}) {
  return {
    userId,
    authorUid: userId,
    author: {
      nickname: 'Recipe Owner',
      avatar: '',
    },
    imageUrls: [],
    title: 'Test recipe',
    content: 'Recipe content',
    tags: ['quick'],
    ingredients: [{name: 'Salt', amount: 1, unit: 'g'}],
    procedures: ['Mix ingredients.'],
    nutrition: {
      calories: 10,
      protein: 1,
      carbs: 1,
      fat: 1,
    },
    likeCount: 0,
    favCount: 0,
    commentCount: 0,
    status: 'active',
    createdAt: serverTimestamp(),
    ...overrides,
  };
}

async function seedRecipe(recipeId, userId = 'owner', overrides = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'recipes', recipeId),
      recipePayload(userId, overrides),
    );
  });
}

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-tastie-firestore-rules',
    firestore: {
      rules: fs.readFileSync(rulesPath(), 'utf8'),
    },
  });
});

test.after(async () => {
  await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
});

test('recipe create rejects corrupted aggregate counters', async () => {
  const db = testEnv.authenticatedContext('alice').firestore();

  await assertSucceeds(
    setDoc(doc(db, 'recipes', 'valid'), recipePayload('alice')),
  );

  await assertFails(
    setDoc(
      doc(db, 'recipes', 'bad-like-count'),
      recipePayload('alice', {likeCount: 'boom'}),
    ),
  );

  await assertFails(
    setDoc(
      doc(db, 'recipes', 'preloaded-likes'),
      recipePayload('alice', {likeCount: 1}),
    ),
  );

  await assertFails(
    setDoc(
      doc(db, 'recipes', 'wrong-owner'),
      recipePayload('mallory'),
    ),
  );
});

test('recipe counter updates require matching user engagement writes', async () => {
  await seedRecipe('pasta');
  const bobDb = testEnv.authenticatedContext('bob').firestore();
  const recipeRef = doc(bobDb, 'recipes', 'pasta');
  const likeRef = doc(bobDb, 'users', 'bob', 'likes', 'pasta');

  await assertFails(updateDoc(recipeRef, {likeCount: 'boom'}));
  await assertFails(updateDoc(recipeRef, {likeCount: increment(1)}));
  await assertFails(
    setDoc(likeRef, {
      recipeId: 'pasta',
      createdAt: serverTimestamp(),
    }),
  );

  await assertSucceeds(
    runTransaction(bobDb, async (transaction) => {
      const recipeSnap = await transaction.get(recipeRef);
      assert.equal(recipeSnap.exists(), true);
      transaction.set(likeRef, {
        recipeId: 'pasta',
        createdAt: serverTimestamp(),
      });
      transaction.update(recipeRef, {likeCount: increment(1)});
    }),
  );

  await assertFails(updateDoc(recipeRef, {likeCount: increment(1)}));
  await assertFails(deleteDoc(likeRef));

  await assertSucceeds(
    runTransaction(bobDb, async (transaction) => {
      const recipeSnap = await transaction.get(recipeRef);
      assert.equal(recipeSnap.exists(), true);
      transaction.delete(likeRef);
      transaction.update(recipeRef, {likeCount: increment(-1)});
    }),
  );
});

test('favorite counter updates require matching collection writes', async () => {
  await seedRecipe('soup');
  const bobDb = testEnv.authenticatedContext('bob').firestore();
  const recipeRef = doc(bobDb, 'recipes', 'soup');
  const collectionRef = doc(bobDb, 'users', 'bob', 'collections', 'soup');

  await assertFails(updateDoc(recipeRef, {favCount: 100}));
  await assertFails(
    setDoc(collectionRef, {
      recipeId: 'soup',
      createdAt: serverTimestamp(),
    }),
  );

  await assertSucceeds(
    runTransaction(bobDb, async (transaction) => {
      const recipeSnap = await transaction.get(recipeRef);
      assert.equal(recipeSnap.exists(), true);
      transaction.set(collectionRef, {
        recipeId: 'soup',
        createdAt: serverTimestamp(),
      });
      transaction.update(recipeRef, {favCount: increment(1)});
    }),
  );

  await assertFails(deleteDoc(collectionRef));

  await assertSucceeds(
    runTransaction(bobDb, async (transaction) => {
      const recipeSnap = await transaction.get(recipeRef);
      assert.equal(recipeSnap.exists(), true);
      transaction.delete(collectionRef);
      transaction.update(recipeRef, {favCount: increment(-1)});
    }),
  );
});

test('moderation status is admin-only and cannot be changed by owners', async () => {
  await seedRecipe('cake', 'owner');
  const ownerDb = testEnv.authenticatedContext('owner').firestore();
  const bobDb = testEnv.authenticatedContext('bob').firestore();
  const adminDb = testEnv.authenticatedContext('moderator', {admin: true}).firestore();

  await assertSucceeds(
    updateDoc(doc(ownerDb, 'recipes', 'cake'), {title: 'Updated cake'}),
  );
  await assertFails(updateDoc(doc(bobDb, 'recipes', 'cake'), {status: 'banned'}));

  await assertSucceeds(
    updateDoc(doc(adminDb, 'recipes', 'cake'), {status: 'banned'}),
  );
  await assertFails(updateDoc(doc(ownerDb, 'recipes', 'cake'), {status: 'active'}));
});
