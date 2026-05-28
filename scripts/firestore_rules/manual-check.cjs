const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, updateDoc, writeBatch } = require('firebase/firestore');

const projectId = 'demo-tastie-rules';

function rulesPath() {
  return path.join(__dirname, '..', '..', 'firestore.rules');
}

async function seedData(testEnv) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();

    await setDoc(doc(db, 'users/admin'), { uid: 'admin', role: 'admin' });
    await setDoc(doc(db, 'users/alice'), {
      uid: 'alice',
      role: 'user',
      email: 'alice@example.com',
      displayName: 'Alice',
      photoURL: null,
      providerIds: ['password'],
      createdAt: new Date(),
      lastLoginAt: new Date(),
    });
    await setDoc(doc(db, 'users/bob'), {
      uid: 'bob',
      role: 'user',
      email: 'bob@example.com',
      displayName: 'Bob',
      photoURL: null,
      providerIds: ['password'],
      createdAt: new Date(),
      lastLoginAt: new Date(),
    });

    await setDoc(doc(db, 'recipes/r1'), {
      userId: 'alice',
      authorUid: 'alice',
      author: { nickname: 'Alice', avatar: '' },
      imageUrls: [],
      title: 'Soup',
      content: 'Warm soup',
      tags: ['soup'],
      ingredients: [],
      procedures: [],
      nutrition: {},
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
      createdAt: new Date(),
    });
  });
}

async function run() {
  let testEnv;

  try {
    testEnv = await initializeTestEnvironment({
      projectId,
      firestore: {
        rules: fs.readFileSync(rulesPath(), 'utf8'),
        host: '127.0.0.1',
        port: 8080,
      },
    });

    await testEnv.clearFirestore();
    await seedData(testEnv);

    const dbAs = (uid) => testEnv.authenticatedContext(uid).firestore();
    const alice = dbAs('alice');
    const bob = dbAs('bob');
    const admin = dbAs('admin');

    // 1) Owner content update succeeds.
    await assertSucceeds(updateDoc(doc(alice, 'recipes/r1'), { title: 'Tomato soup' }));

    // 2) Owner cannot update protected fields.
    await assertFails(updateDoc(doc(alice, 'recipes/r1'), { status: 'banned' }));
    await assertFails(updateDoc(doc(alice, 'recipes/r1'), { userId: 'bob' }));
    await assertFails(updateDoc(doc(alice, 'recipes/r1'), { likeCount: 999 }));

    // 3) Only admin can moderate recipe status.
    await assertFails(updateDoc(doc(bob, 'recipes/r1'), { status: 'banned' }));
    await assertSucceeds(updateDoc(doc(admin, 'recipes/r1'), { status: 'banned' }));
    await assertSucceeds(updateDoc(doc(admin, 'recipes/r1'), { status: 'active' }));

    // 4) Profile read boundaries.
    await assertFails(getDoc(doc(bob, 'users/alice')));
    await assertSucceeds(getDoc(doc(admin, 'users/alice')));

    // 5) Likes must be coupled with recipe counter update.
    await assertFails(updateDoc(doc(alice, 'recipes/r1'), { likeCount: 1 }));
    const likeBatch = writeBatch(alice);
    likeBatch.set(doc(alice, 'users/alice/likes/r1'), {
      recipeId: 'r1',
      createdAt: new Date(),
    });
    likeBatch.update(doc(alice, 'recipes/r1'), { likeCount: 1 });
    await assertSucceeds(likeBatch.commit());

    console.log('manual checks passed');
  } catch (err) {
    console.error('manual checks failed');
    console.error(err);
    process.exitCode = 1;
  } finally {
    if (testEnv) {
      await testEnv.cleanup();
    }
  }
}

run();
