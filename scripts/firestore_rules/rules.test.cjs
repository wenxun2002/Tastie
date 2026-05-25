const fs = require('node:fs');
const path = require('node:path');
const { after, before, beforeEach, describe, it } = require('node:test');

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
} = require('firebase/firestore');

const projectId = 'demo-tastie-rules';

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync(
        path.join(__dirname, '..', '..', 'firestore.rules'),
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

function authedDb(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

async function seedFirestore(callback) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await callback(context.firestore());
  });
}

describe('user profile rules', () => {
  it('allow users to maintain only their own auth-derived profile fields', async () => {
    const db = authedDb('alice');

    await assertSucceeds(setDoc(doc(db, 'users/alice'), {
      uid: 'alice',
      email: 'alice@example.com',
      displayName: 'Alice',
      photoURL: null,
      providerIds: ['google.com'],
      createdAt: new Date(),
      lastLoginAt: new Date(),
    }));

    await assertSucceeds(updateDoc(doc(db, 'users/alice'), {
      displayName: 'Alice Example',
      lastLoginAt: new Date(),
    }));
  });

  it('block self-service role escalation on create and update', async () => {
    const db = authedDb('alice');

    await assertFails(setDoc(doc(db, 'users/alice'), {
      uid: 'alice',
      email: 'alice@example.com',
      role: 'admin',
    }));

    await seedFirestore(async (adminDb) => {
      await setDoc(doc(adminDb, 'users/alice'), {
        uid: 'alice',
        email: 'alice@example.com',
      });
    });

    await assertFails(updateDoc(doc(db, 'users/alice'), {
      role: 'admin',
    }));
  });
});

describe('recipe moderation rules', () => {
  beforeEach(async () => {
    await seedFirestore(async (db) => {
      await setDoc(doc(db, 'users/admin'), {
        uid: 'admin',
        role: 'admin',
      });
      await setDoc(doc(db, 'recipes/recipe-1'), {
        userId: 'alice',
        title: 'Soup',
        status: 'active',
        likeCount: 0,
        favCount: 0,
      });
    });
  });

  it('block non-admin users from banning or unbanning recipes', async () => {
    await assertFails(updateDoc(doc(authedDb('mallory'), 'recipes/recipe-1'), {
      status: 'banned',
    }));

    await assertFails(updateDoc(doc(authedDb('alice'), 'recipes/recipe-1'), {
      status: 'banned',
    }));

    await seedFirestore(async (db) => {
      await updateDoc(doc(db, 'recipes/recipe-1'), {
        status: 'banned',
      });
    });

    await assertFails(updateDoc(doc(authedDb('alice'), 'recipes/recipe-1'), {
      status: 'active',
    }));
  });

  it('allow admins to update only valid moderation status values', async () => {
    const adminDb = authedDb('admin');

    await assertSucceeds(updateDoc(doc(adminDb, 'recipes/recipe-1'), {
      status: 'banned',
    }));

    const updated = await getDoc(doc(adminDb, 'recipes/recipe-1'));
    if (updated.data().status !== 'banned') {
      throw new Error('expected admin status update to persist');
    }

    await assertFails(updateDoc(doc(adminDb, 'recipes/recipe-1'), {
      status: 'deleted',
    }));
  });

  it('preserve existing recipe author edits and engagement counter updates', async () => {
    await assertSucceeds(updateDoc(doc(authedDb('alice'), 'recipes/recipe-1'), {
      title: 'Updated Soup',
    }));

    await assertSucceeds(updateDoc(doc(authedDb('mallory'), 'recipes/recipe-1'), {
      likeCount: 1,
    }));
  });
});
