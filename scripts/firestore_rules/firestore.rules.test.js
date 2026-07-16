const fs = require('fs');
const path = require('path');

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} = require('firebase/firestore');

const projectId = 'demo-tastie-rules';

let testEnv;

function rulesPath() {
  return path.join(__dirname, '..', '..', 'firestore.rules');
}

function authedDb(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

function unauthenticatedDb() {
  return testEnv.unauthenticatedContext().firestore();
}

async function seedDoc(documentPath, data) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), documentPath), data);
  });
}

function baseRecipe(overrides = {}) {
  return {
    userId: 'alice',
    authorUid: 'alice',
    author: {nickname: 'Alice', avatar: ''},
    imageUrls: [],
    title: 'Soup',
    content: 'Warm soup',
    tags: ['soup'],
    ingredients: [],
    procedures: [],
    likeCount: 0,
    favCount: 0,
    commentCount: 0,
    clicked: 0,
    click_metrics: {
      weather_promoted: 0,
      weather_notpromoted: 0,
      normal_browse: 0,
      search: 0,
      total: 0,
    },
    status: 'active',
    createdAt: new Date('2026-01-01T00:00:00Z'),
    ...overrides,
  };
}

describe('firestore.rules', () => {
  before(async () => {
    testEnv = await initializeTestEnvironment({
      projectId,
      firestore: {
        rules: fs.readFileSync(rulesPath(), 'utf8'),
        host: '127.0.0.1',
        port: 8080,
      },
    });
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
  });

  after(async () => {
    await testEnv.cleanup();
  });

  it('rejects self-service admin role writes on user profiles', async () => {
    const alice = authedDb('alice');
    const aliceRef = doc(alice, 'users/alice');

    await assertFails(setDoc(aliceRef, {
      uid: 'alice',
      email: 'alice@example.com',
      role: 'admin',
      lastLoginAt: serverTimestamp(),
      createdAt: serverTimestamp(),
    }));

    await assertSucceeds(setDoc(aliceRef, {
      uid: 'alice',
      email: 'alice@example.com',
      displayName: null,
      photoURL: null,
      providerIds: ['google.com'],
      lastLoginAt: serverTimestamp(),
      createdAt: serverTimestamp(),
    }));

    await assertFails(updateDoc(aliceRef, {role: 'admin'}));
  });

  it('keeps user PII private except to the user and admins', async () => {
    await seedDoc('users/alice', {
      uid: 'alice',
      email: 'alice@example.com',
      role: 'user',
    });
    await seedDoc('users/admin', {
      uid: 'admin',
      email: 'admin@example.com',
      role: 'admin',
    });

    await assertFails(getDoc(doc(unauthenticatedDb(), 'users/alice')));
    await assertFails(getDoc(doc(authedDb('bob'), 'users/alice')));
    await assertSucceeds(getDoc(doc(authedDb('alice'), 'users/alice')));
    await assertSucceeds(getDoc(doc(authedDb('admin'), 'users/alice')));
  });

  it('allows only admins to change user moderation status', async () => {
    await seedDoc('users/admin', {uid: 'admin', role: 'admin'});
    await seedDoc('users/alice', {
      uid: 'alice',
      email: 'alice@example.com',
      status: 'active',
    });

    await assertFails(updateDoc(doc(authedDb('alice'), 'users/alice'), {
      status: 'banned',
    }));
    await assertFails(updateDoc(doc(authedDb('bob'), 'users/alice'), {
      status: 'banned',
    }));
    await assertSucceeds(updateDoc(doc(authedDb('admin'), 'users/alice'), {
      status: 'banned',
    }));
    await assertSucceeds(updateDoc(doc(authedDb('admin'), 'users/alice'), {
      status: 'active',
    }));
  });

  it('allows only admins to change recipe moderation status', async () => {
    await seedDoc('users/admin', {uid: 'admin', role: 'admin'});
    await seedDoc('recipes/r1', baseRecipe());

    await assertFails(updateDoc(doc(authedDb('alice'), 'recipes/r1'), {
      status: 'banned',
    }));
    await assertFails(updateDoc(doc(authedDb('bob'), 'recipes/r1'), {
      status: 'banned',
    }));
    await assertSucceeds(updateDoc(doc(authedDb('admin'), 'recipes/r1'), {
      status: 'banned',
    }));
  });

  it('prevents recipe owners from reassigning ownership or counters', async () => {
    await seedDoc('users/alice', {
      uid: 'alice',
      status: 'active',
    });
    await seedDoc('recipes/r1', baseRecipe());
    const recipeRef = doc(authedDb('alice'), 'recipes/r1');

    await assertSucceeds(updateDoc(recipeRef, {title: 'Tomato soup'}));
    await assertFails(updateDoc(recipeRef, {userId: 'bob'}));
    await assertFails(updateDoc(recipeRef, {authorUid: 'bob'}));
    await assertFails(updateDoc(recipeRef, {likeCount: 999}));
    await assertFails(updateDoc(recipeRef, {clicked: 999}));
  });

  it('requires like count changes to be coupled with the like document', async () => {
    await seedDoc('users/alice', {
      uid: 'alice',
      status: 'active',
    });
    await seedDoc('recipes/r1', baseRecipe());
    const alice = authedDb('alice');
    const recipeRef = doc(alice, 'recipes/r1');
    const likeRef = doc(alice, 'users/alice/likes/r1');

    await assertFails(updateDoc(recipeRef, {likeCount: 1}));
    await assertFails(setDoc(likeRef, {
      recipeId: 'r1',
      createdAt: serverTimestamp(),
    }));

    const likeBatch = writeBatch(alice);
    likeBatch.set(likeRef, {recipeId: 'r1', createdAt: serverTimestamp()});
    likeBatch.update(recipeRef, {likeCount: 1});
    await assertSucceeds(likeBatch.commit());

    await assertFails(updateDoc(recipeRef, {likeCount: 2}));

    const unlikeBatch = writeBatch(alice);
    unlikeBatch.delete(likeRef);
    unlikeBatch.update(recipeRef, {likeCount: 0});
    await assertSucceeds(unlikeBatch.commit());
  });

  it('requires favorite count changes to be coupled with the collection document', async () => {
    await seedDoc('users/alice', {
      uid: 'alice',
      status: 'active',
    });
    await seedDoc('recipes/r1', baseRecipe());
    const alice = authedDb('alice');
    const recipeRef = doc(alice, 'recipes/r1');
    const collectionRef = doc(alice, 'users/alice/collections/r1');

    await assertFails(updateDoc(recipeRef, {favCount: 1}));

    const favoriteBatch = writeBatch(alice);
    favoriteBatch.set(collectionRef, {
      recipeId: 'r1',
      createdAt: serverTimestamp(),
    });
    favoriteBatch.update(recipeRef, {favCount: 1});
    await assertSucceeds(favoriteBatch.commit());

    const unfavoriteBatch = writeBatch(alice);
    unfavoriteBatch.delete(collectionRef);
    unfavoriteBatch.update(recipeRef, {favCount: 0});
    await assertSucceeds(unfavoriteBatch.commit());
  });

  it('allows only admins to change report status', async () => {
    await seedDoc('users/admin', {uid: 'admin', role: 'admin'});
    await seedDoc('reports/r1', {
      recipeId: 'r1',
      reportedBy: 'alice',
      status: 'pending',
    });

    await assertFails(updateDoc(doc(authedDb('alice'), 'reports/r1'), {
      status: 'solved',
    }));
    await assertFails(updateDoc(doc(authedDb('admin'), 'reports/r1'), {
      reason: 'spam',
    }));
    await assertSucceeds(updateDoc(doc(authedDb('admin'), 'reports/r1'), {
      status: 'solved',
    }));
    await assertSucceeds(updateDoc(doc(authedDb('admin'), 'reports/r1'), {
      status: 'pending',
    }));
  });

  it('blocks writes from banned users with still-valid auth tokens', async () => {
    await seedDoc('users/alice', {
      uid: 'alice',
      displayName: 'Alice',
      status: 'banned',
    });
    await seedDoc('recipes/r1', baseRecipe());

    const alice = authedDb('alice');
    const recipeRef = doc(alice, 'recipes/r1');

    await assertFails(updateDoc(recipeRef, {title: 'Changed after ban'}));
    await assertFails(deleteDoc(recipeRef));
    await assertFails(updateDoc(doc(alice, 'users/alice'), {
      displayName: 'Changed after ban',
    }));
    await assertFails(setDoc(doc(alice, 'reports/banned-report'), {
      recipeId: 'r1',
      reportedBy: 'alice',
      status: 'pending',
    }));
    await assertFails(setDoc(doc(alice, 'recipe_click_events/banned-click'), {
      recipeId: 'r1',
      userId: 'alice',
      clickSource: 'normal_browse',
    }));

    const likeBatch = writeBatch(alice);
    likeBatch.set(doc(alice, 'users/alice/likes/r1'), {
      recipeId: 'r1',
      createdAt: serverTimestamp(),
    });
    likeBatch.update(recipeRef, {likeCount: 1});
    await assertFails(likeBatch.commit());
  });

  it('removes admin privileges as soon as the admin is banned', async () => {
    await seedDoc('users/admin', {
      uid: 'admin',
      role: 'admin',
      status: 'banned',
    });
    await seedDoc('users/alice', {
      uid: 'alice',
      status: 'active',
    });
    await seedDoc('recipes/r1', baseRecipe());
    await seedDoc('reports/r1', {
      recipeId: 'r1',
      reportedBy: 'alice',
      status: 'pending',
    });

    const bannedAdmin = authedDb('admin');
    await assertFails(updateDoc(doc(bannedAdmin, 'users/alice'), {
      status: 'banned',
    }));
    await assertFails(updateDoc(doc(bannedAdmin, 'recipes/r1'), {
      status: 'banned',
    }));
    await assertFails(updateDoc(doc(bannedAdmin, 'reports/r1'), {
      status: 'solved',
    }));
  });
});
