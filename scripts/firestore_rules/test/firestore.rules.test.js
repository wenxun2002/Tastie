const assert = require('assert');
const {after, before, beforeEach, describe, it} = require('node:test');
const fs = require('fs');
const path = require('path');

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  increment,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
} = require('firebase/firestore');

const projectId = 'demo-tastie-rules';

describe('firestore.rules', {timeout: 30000}, () => {

  let testEnv;

  before(async () => {
    testEnv = await initializeTestEnvironment({
      projectId,
      firestore: {
        rules: fs.readFileSync(
          path.join(__dirname, '..', '..', '..', 'firestore.rules'),
          'utf8',
        ),
      },
    });
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
  });

  after(async () => {
    await testEnv.cleanup();
  });

  function authedDb(uid, claims = {}) {
    return testEnv.authenticatedContext(uid, claims).firestore();
  }

  async function seedRecipe(id = 'recipe1', overrides = {}) {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'recipes', id), {
        userId: 'owner',
        authorUid: 'owner',
        author: {
          nickname: 'Owner',
          avatar: '',
        },
        imageUrls: [],
        title: 'Tomato Soup',
        content: 'A simple soup.',
        tags: ['soup'],
        ingredients: [],
        procedures: [],
        nutrition: {
          calories: 120,
          protein: 3,
          carbs: 16,
          fat: 5,
        },
        likeCount: 0,
        favCount: 0,
        commentCount: 0,
        status: 'active',
        createdAt: 1,
        ...overrides,
      });
    });
  }

  async function seedEngagementDoc(collection, uid, recipeId) {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), 'users', uid, collection, recipeId),
        {
          recipeId,
          createdAt: 1,
        },
      );
    });
  }

  it('blocks client status changes unless the caller has an admin claim', async () => {
    await seedRecipe();

    await assertFails(
      updateDoc(doc(authedDb('stranger'), 'recipes', 'recipe1'), {
        status: 'banned',
      }),
    );
    await assertFails(
      updateDoc(doc(authedDb('owner'), 'recipes', 'recipe1'), {
        status: 'banned',
      }),
    );
    await assertSucceeds(
      updateDoc(doc(authedDb('admin', {admin: true}), 'recipes', 'recipe1'), {
        status: 'banned',
      }),
    );
  });

  it('lets owners edit recipe content but not aggregate counters', async () => {
    await seedRecipe();

    await assertSucceeds(
      updateDoc(doc(authedDb('owner'), 'recipes', 'recipe1'), {
        title: 'Updated Tomato Soup',
      }),
    );
    await assertFails(
      updateDoc(doc(authedDb('owner'), 'recipes', 'recipe1'), {
        likeCount: 1000,
      }),
    );
  });

  it('rejects forged engagement counter writes', async () => {
    await seedRecipe();
    const db = authedDb('fan');

    await assertFails(
      updateDoc(doc(db, 'recipes', 'recipe1'), {
        likeCount: 999999,
      }),
    );
    await assertFails(
      updateDoc(doc(db, 'recipes', 'recipe1'), {
        favCount: 999999,
      }),
    );
    await assertFails(
      updateDoc(doc(db, 'recipes', 'recipe1'), {
        likeCount: increment(1),
      }),
    );
  });

  it('allows a like only when the like doc is created atomically', async () => {
    await seedRecipe();
    const db = authedDb('fan');
    const recipeRef = doc(db, 'recipes', 'recipe1');
    const likeRef = doc(db, 'users', 'fan', 'likes', 'recipe1');

    await assertSucceeds(
      runTransaction(db, async (txn) => {
        const recipeSnap = await txn.get(recipeRef);
        const likeSnap = await txn.get(likeRef);
        assert.equal(recipeSnap.exists(), true);
        assert.equal(likeSnap.exists(), false);

        txn.set(likeRef, {
          recipeId: 'recipe1',
          createdAt: serverTimestamp(),
        });
        txn.update(recipeRef, {
          likeCount: increment(1),
        });
      }),
    );
  });

  it('allows an unlike only when the like doc is deleted atomically', async () => {
    await seedRecipe('recipe1', {likeCount: 1});
    await seedEngagementDoc('likes', 'fan', 'recipe1');
    const db = authedDb('fan');
    const recipeRef = doc(db, 'recipes', 'recipe1');
    const likeRef = doc(db, 'users', 'fan', 'likes', 'recipe1');

    await assertSucceeds(
      runTransaction(db, async (txn) => {
        const recipeSnap = await txn.get(recipeRef);
        const likeSnap = await txn.get(likeRef);
        assert.equal(recipeSnap.exists(), true);
        assert.equal(likeSnap.exists(), true);

        txn.delete(likeRef);
        txn.update(recipeRef, {
          likeCount: increment(-1),
        });
      }),
    );
  });

  it('allows a favorite only when the collection doc is created atomically', async () => {
    await seedRecipe();
    const db = authedDb('fan');
    const recipeRef = doc(db, 'recipes', 'recipe1');
    const collectionRef = doc(db, 'users', 'fan', 'collections', 'recipe1');

    await assertSucceeds(
      runTransaction(db, async (txn) => {
        const recipeSnap = await txn.get(recipeRef);
        const collectionSnap = await txn.get(collectionRef);
        assert.equal(recipeSnap.exists(), true);
        assert.equal(collectionSnap.exists(), false);

        txn.set(collectionRef, {
          recipeId: 'recipe1',
          createdAt: serverTimestamp(),
        });
        txn.update(recipeRef, {
          favCount: increment(1),
        });
      }),
    );
  });

  it('allows an unfavorite only when the collection doc is deleted atomically', async () => {
    await seedRecipe('recipe1', {favCount: 1});
    await seedEngagementDoc('collections', 'fan', 'recipe1');
    const db = authedDb('fan');
    const recipeRef = doc(db, 'recipes', 'recipe1');
    const collectionRef = doc(db, 'users', 'fan', 'collections', 'recipe1');

    await assertSucceeds(
      runTransaction(db, async (txn) => {
        const recipeSnap = await txn.get(recipeRef);
        const collectionSnap = await txn.get(collectionRef);
        assert.equal(recipeSnap.exists(), true);
        assert.equal(collectionSnap.exists(), true);

        txn.delete(collectionRef);
        txn.update(recipeRef, {
          favCount: increment(-1),
        });
      }),
    );
  });

  it('does not let engagement counters go negative', async () => {
    await seedRecipe();
    await seedEngagementDoc('likes', 'fan', 'recipe1');
    const db = authedDb('fan');
    const recipeRef = doc(db, 'recipes', 'recipe1');
    const likeRef = doc(db, 'users', 'fan', 'likes', 'recipe1');

    await assertFails(
      runTransaction(db, async (txn) => {
        await txn.get(recipeRef);
        await txn.get(likeRef);

        txn.delete(likeRef);
        txn.update(recipeRef, {
          likeCount: increment(-1),
        });
      }),
    );
  });
});
