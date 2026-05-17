const assert = require('assert');
const fs = require('fs');
const path = require('path');

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  increment,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
} = require('firebase/firestore');

const PROJECT_ID = 'demo-tastie-rules';

function recipeData(overrides = {}) {
  return {
    userId: 'alice',
    authorUid: 'alice',
    author: {
      nickname: 'Alice',
      avatar: '',
    },
    imageUrls: [],
    title: 'Soup',
    content: 'A simple soup',
    tags: ['dinner'],
    ingredients: [],
    procedures: [],
    likeCount: 0,
    favCount: 0,
    commentCount: 0,
    status: 'active',
    createdAt: serverTimestamp(),
    ...overrides,
  };
}

function reportData(overrides = {}) {
  return {
    recipeId: 'recipe1',
    recipeTitle: 'Soup',
    authorUsername: 'Alice',
    reportedBy: 'bob',
    reason: 'Spam',
    description: 'Looks suspicious',
    timestamp: serverTimestamp(),
    ...overrides,
  };
}

async function seedData(testEnv) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'recipes/recipe1'), recipeData());
    await setDoc(doc(db, 'users/alice'), {
      uid: 'alice',
      email: 'alice@example.com',
      displayName: 'Alice',
      providerIds: ['google.com'],
      lastLoginAt: serverTimestamp(),
    });
    await setDoc(doc(db, 'reports/report1'), reportData({reportedBy: 'alice'}));
  });
}

async function likeRecipe(db, recipeId) {
  const recipeRef = doc(db, 'recipes', recipeId);
  const likeRef = doc(db, 'users/bob/likes', recipeId);

  await runTransaction(db, async (txn) => {
    await txn.get(recipeRef);
    await txn.get(likeRef);
    txn.set(likeRef, {
      recipeId,
      createdAt: serverTimestamp(),
    });
    txn.update(recipeRef, {
      likeCount: increment(1),
    });
  });
}

async function unlikeRecipe(db, recipeId) {
  const recipeRef = doc(db, 'recipes', recipeId);
  const likeRef = doc(db, 'users/bob/likes', recipeId);

  await runTransaction(db, async (txn) => {
    await txn.get(recipeRef);
    await txn.get(likeRef);
    txn.delete(likeRef);
    txn.update(recipeRef, {
      likeCount: increment(-1),
    });
  });
}

async function saveRecipe(db, recipeId) {
  const recipeRef = doc(db, 'recipes', recipeId);
  const collectionRef = doc(db, 'users/bob/collections', recipeId);

  await runTransaction(db, async (txn) => {
    await txn.get(recipeRef);
    await txn.get(collectionRef);
    txn.set(collectionRef, {
      recipeId,
      createdAt: serverTimestamp(),
    });
    txn.update(recipeRef, {
      favCount: increment(1),
    });
  });
}

async function run() {
  const rules = fs.readFileSync(
    path.join(__dirname, '..', '..', 'firestore.rules'),
    'utf8',
  );
  const testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {rules},
  });

  try {
    await testEnv.clearFirestore();
    await seedData(testEnv);

    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    const bobDb = testEnv.authenticatedContext('bob').firestore();
    const adminDb = testEnv
      .authenticatedContext('admin', {admin: true})
      .firestore();

    await assertSucceeds(getDoc(doc(bobDb, 'recipes/recipe1')));

    await assertFails(getDoc(doc(bobDb, 'users/alice')));
    await assertSucceeds(getDoc(doc(aliceDb, 'users/alice')));

    await assertFails(getDoc(doc(bobDb, 'reports/report1')));
    await assertSucceeds(getDoc(doc(adminDb, 'reports/report1')));
    await assertFails(
      setDoc(
        doc(bobDb, 'reports/badReporter'),
        reportData({reportedBy: 'alice'}),
      ),
    );
    await assertSucceeds(
      setDoc(doc(bobDb, 'reports/ownReporter'), reportData()),
    );

    await assertFails(updateDoc(doc(bobDb, 'recipes/recipe1'), {
      status: 'banned',
    }));
    await assertSucceeds(updateDoc(doc(adminDb, 'recipes/recipe1'), {
      status: 'banned',
    }));
    await assertSucceeds(updateDoc(doc(adminDb, 'recipes/recipe1'), {
      status: 'active',
    }));

    await assertFails(updateDoc(doc(aliceDb, 'recipes/recipe1'), {
      userId: 'bob',
    }));
    await assertFails(updateDoc(doc(aliceDb, 'recipes/recipe1'), {
      status: 'banned',
    }));
    await assertSucceeds(updateDoc(doc(aliceDb, 'recipes/recipe1'), {
      title: 'Soup v2',
    }));

    await assertFails(updateDoc(doc(bobDb, 'recipes/recipe1'), {
      likeCount: 999,
    }));
    await assertFails(updateDoc(doc(bobDb, 'recipes/recipe1'), {
      favCount: 999,
    }));
    await assertFails(setDoc(doc(bobDb, 'users/bob/likes/recipe1'), {
      recipeId: 'recipe1',
      createdAt: serverTimestamp(),
    }));

    await assertSucceeds(likeRecipe(bobDb, 'recipe1'));
    await assertFails(likeRecipe(bobDb, 'recipe1'));
    await assertSucceeds(unlikeRecipe(bobDb, 'recipe1'));
    await assertSucceeds(saveRecipe(bobDb, 'recipe1'));

    const snap = await getDoc(doc(bobDb, 'recipes/recipe1'));
    assert.strictEqual(snap.data().likeCount, 0);
    assert.strictEqual(snap.data().favCount, 1);
  } finally {
    await testEnv.cleanup();
  }
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});
