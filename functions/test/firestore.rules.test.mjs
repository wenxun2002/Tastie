import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {fileURLToPath} from "node:url";
import {dirname, resolve} from "node:path";
import test from "node:test";

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  deleteDoc,
  doc,
  getDoc,
  increment,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
} from "firebase/firestore";

const __dirname = dirname(fileURLToPath(import.meta.url));
const rules = readFileSync(resolve(__dirname, "../../firestore.rules"), "utf8");

async function createTestEnvironment() {
  return initializeTestEnvironment({
    projectId: `demo-tastie-rules-${Date.now()}`,
    firestore: {rules},
  });
}

async function seedRecipe(testEnv, id = "recipe-1") {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), `recipes/${id}`), {
      userId: "author",
      authorUid: "author",
      status: "active",
      title: "Soup",
      likeCount: 0,
      favCount: 0,
      commentCount: 0,
    });
  });
}

test("only admins can change recipe moderation status", async () => {
  const testEnv = await createTestEnvironment();
  try {
    await seedRecipe(testEnv);

    const userDb = testEnv.authenticatedContext("user").firestore();
    await assertFails(
      updateDoc(doc(userDb, "recipes/recipe-1"), {status: "banned"}),
    );

    const adminDb = testEnv
      .authenticatedContext("admin", {admin: true})
      .firestore();
    await assertSucceeds(
      updateDoc(doc(adminDb, "recipes/recipe-1"), {status: "banned"}),
    );
  } finally {
    await testEnv.cleanup();
  }
});

test("recipe creates must belong to the caller and start with zero counters", async () => {
  const testEnv = await createTestEnvironment();
  try {
    const authorDb = testEnv.authenticatedContext("author").firestore();
    const validRecipe = {
      userId: "author",
      authorUid: "author",
      status: "active",
      title: "Soup",
      likeCount: 0,
      favCount: 0,
      commentCount: 0,
    };

    await assertFails(
      setDoc(doc(authorDb, "recipes/fake-popular"), {
        ...validRecipe,
        likeCount: 1000,
      }),
    );
    await assertFails(
      setDoc(doc(authorDb, "recipes/stolen-author"), {
        ...validRecipe,
        userId: "other-user",
      }),
    );
    await assertSucceeds(setDoc(doc(authorDb, "recipes/valid"), validRecipe));
  } finally {
    await testEnv.cleanup();
  }
});

test("likes must be paired with the matching counter delta", async () => {
  const testEnv = await createTestEnvironment();
  try {
    await seedRecipe(testEnv);

    const userDb = testEnv.authenticatedContext("user").firestore();
    await assertFails(
      updateDoc(doc(userDb, "recipes/recipe-1"), {likeCount: 1000}),
    );
    await assertFails(
      setDoc(doc(userDb, "users/user/likes/recipe-1"), {
        recipeId: "recipe-1",
        createdAt: serverTimestamp(),
      }),
    );

    await assertSucceeds(
      runTransaction(userDb, async (transaction) => {
        transaction.set(doc(userDb, "users/user/likes/recipe-1"), {
          recipeId: "recipe-1",
          createdAt: serverTimestamp(),
        });
        transaction.update(doc(userDb, "recipes/recipe-1"), {
          likeCount: increment(1),
        });
      }),
    );

    await assertSucceeds(
      runTransaction(userDb, async (transaction) => {
        transaction.delete(doc(userDb, "users/user/likes/recipe-1"));
        transaction.update(doc(userDb, "recipes/recipe-1"), {
          likeCount: increment(-1),
        });
      }),
    );
  } finally {
    await testEnv.cleanup();
  }
});

test("reports are private to admins", async () => {
  const testEnv = await createTestEnvironment();
  try {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "reports/report-1"), {
        reportedBy: "reporter",
        reason: "Spam",
        description: "private details",
      });
    });

    const reporterDb = testEnv.authenticatedContext("reporter").firestore();
    await assertSucceeds(
      setDoc(doc(reporterDb, "reports/report-2"), {
        reportedBy: "reporter",
        reason: "Spam",
        description: "more private details",
      }),
    );
    await assertFails(getDoc(doc(reporterDb, "reports/report-1")));

    const adminDb = testEnv
      .authenticatedContext("admin", {admin: true})
      .firestore();
    const report = await assertSucceeds(getDoc(doc(adminDb, "reports/report-1")));
    assert.equal(report.exists(), true);
  } finally {
    await testEnv.cleanup();
  }
});
