const {after, before, beforeEach, describe, it} = require('node:test');
const fs = require('node:fs');
const path = require('node:path');

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  deleteDoc,
  doc,
  getDoc,
  increment,
  serverTimestamp,
  setDoc,
  setLogLevel,
  updateDoc,
  writeBatch,
} = require('firebase/firestore');

setLogLevel('error');

let testEnv;

function dbFor(uid, claims = {}) {
  return testEnv.authenticatedContext(uid, claims).firestore();
}

function recipeData(userId = 'alice') {
  return {
    userId,
    authorUid: userId,
    author: {
      nickname: userId,
      avatar: '',
    },
    imageUrls: [],
    title: 'Tomato soup',
    content: 'A quick soup.',
    tags: [],
    ingredients: [],
    procedures: [],
    likeCount: 0,
    favCount: 0,
    commentCount: 0,
    status: 'active',
    createdAt: serverTimestamp(),
  };
}

async function seedDoc(documentPath, data) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), documentPath), data);
  });
}

async function commitLike(db, recipeId) {
  const batch = writeBatch(db);
  batch.set(doc(db, `users/alice/likes/${recipeId}`), {
    recipeId,
    createdAt: serverTimestamp(),
  });
  batch.update(doc(db, `recipes/${recipeId}`), {
    likeCount: increment(1),
  });
  await batch.commit();
}

async function commitUnlike(db, recipeId) {
  const batch = writeBatch(db);
  batch.delete(doc(db, `users/alice/likes/${recipeId}`));
  batch.update(doc(db, `recipes/${recipeId}`), {
    likeCount: increment(-1),
  });
  await batch.commit();
}

async function commitFavorite(db, recipeId) {
  const batch = writeBatch(db);
  batch.set(doc(db, `users/alice/collections/${recipeId}`), {
    recipeId,
    createdAt: serverTimestamp(),
  });
  batch.update(doc(db, `recipes/${recipeId}`), {
    favCount: increment(1),
  });
  await batch.commit();
}

async function commitUnfavorite(db, recipeId) {
  const batch = writeBatch(db);
  batch.delete(doc(db, `users/alice/collections/${recipeId}`));
  batch.update(doc(db, `recipes/${recipeId}`), {
    favCount: increment(-1),
  });
  await batch.commit();
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: `tastie-rules-${Date.now()}`,
    firestore: {
      rules: fs.readFileSync(
        path.join(__dirname, '../../../firestore.rules'),
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

describe('recipe rules', () => {
  it('requires new recipes to be owned by the caller with zeroed counters', async () => {
    const alice = dbFor('alice');

    await assertSucceeds(setDoc(doc(alice, 'recipes/good'), recipeData()));
    await assertFails(setDoc(doc(alice, 'recipes/bad-owner'), recipeData('bob')));
    await assertFails(
      setDoc(doc(alice, 'recipes/bad-like-count'), {
        ...recipeData(),
        likeCount: 10,
      }),
    );
    await assertFails(
      setDoc(doc(alice, 'recipes/bad-status'), {
        ...recipeData(),
        status: 'banned',
      }),
    );
  });

  it('prevents authors from reassigning ownership or moderation status', async () => {
    await seedDoc('recipes/r1', recipeData());
    const alice = dbFor('alice');

    await assertSucceeds(updateDoc(doc(alice, 'recipes/r1'), {title: 'Soup'}));
    await assertFails(updateDoc(doc(alice, 'recipes/r1'), {userId: 'bob'}));
    await assertFails(updateDoc(doc(alice, 'recipes/r1'), {authorUid: 'bob'}));
    await assertFails(updateDoc(doc(alice, 'recipes/r1'), {status: 'banned'}));
  });

  it('allows only admins to update moderation status', async () => {
    await seedDoc('recipes/r1', recipeData());
    const alice = dbFor('alice');
    const admin = dbFor('admin-user', {admin: true});

    await assertFails(updateDoc(doc(alice, 'recipes/r1'), {status: 'banned'}));
    await assertSucceeds(updateDoc(doc(admin, 'recipes/r1'), {status: 'banned'}));
  });
});

describe('engagement rules', () => {
  it('requires like markers and likeCount to change atomically', async () => {
    await seedDoc('recipes/r1', recipeData());
    const alice = dbFor('alice');
    const recipeRef = doc(alice, 'recipes/r1');
    const likeRef = doc(alice, 'users/alice/likes/r1');

    await assertFails(updateDoc(recipeRef, {likeCount: 1}));
    await assertFails(
      setDoc(likeRef, {
        recipeId: 'r1',
        createdAt: serverTimestamp(),
      }),
    );

    await assertSucceeds(commitLike(alice, 'r1'));
    await assertFails(updateDoc(recipeRef, {likeCount: 2}));
    await assertFails(deleteDoc(likeRef));
    await assertSucceeds(commitUnlike(alice, 'r1'));
    await assertFails(updateDoc(recipeRef, {likeCount: -1}));
  });

  it('requires collection markers and favCount to change atomically', async () => {
    await seedDoc('recipes/r1', recipeData());
    const alice = dbFor('alice');
    const recipeRef = doc(alice, 'recipes/r1');
    const collectionRef = doc(alice, 'users/alice/collections/r1');

    await assertFails(updateDoc(recipeRef, {favCount: 1}));
    await assertFails(
      setDoc(collectionRef, {
        recipeId: 'r1',
        createdAt: serverTimestamp(),
      }),
    );

    await assertSucceeds(commitFavorite(alice, 'r1'));
    await assertFails(updateDoc(recipeRef, {favCount: 2}));
    await assertFails(deleteDoc(collectionRef));
    await assertSucceeds(commitUnfavorite(alice, 'r1'));
    await assertFails(updateDoc(recipeRef, {favCount: -1}));
  });
});

describe('report rules', () => {
  it('only lets users create their own reports', async () => {
    const alice = dbFor('alice');

    await assertSucceeds(
      setDoc(doc(alice, 'reports/own-report'), {
        recipeId: 'r1',
        recipeTitle: 'Tomato soup',
        authorUsername: 'chef',
        reportedBy: 'alice',
        reason: 'Spam',
        description: 'Looks automated.',
        timestamp: serverTimestamp(),
      }),
    );
    await assertFails(
      setDoc(doc(alice, 'reports/forged-report'), {
        recipeId: 'r1',
        recipeTitle: 'Tomato soup',
        authorUsername: 'chef',
        reportedBy: 'bob',
        reason: 'Spam',
        description: 'Looks automated.',
        timestamp: serverTimestamp(),
      }),
    );
  });

  it('restricts report reads to admins', async () => {
    await seedDoc('reports/r1', {
      recipeId: 'r1',
      recipeTitle: 'Tomato soup',
      authorUsername: 'chef',
      reportedBy: 'alice',
      reason: 'Spam',
      description: 'Looks automated.',
      timestamp: serverTimestamp(),
    });

    const alice = dbFor('alice');
    const admin = dbFor('admin-user', {admin: true});

    await assertFails(getDoc(doc(alice, 'reports/r1')));
    await assertSucceeds(getDoc(doc(admin, 'reports/r1')));
  });
});
