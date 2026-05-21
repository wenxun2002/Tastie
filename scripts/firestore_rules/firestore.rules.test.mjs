import {readFileSync} from "node:fs";
import path from "node:path";
import test from "node:test";
import {fileURLToPath} from "node:url";

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  addDoc,
  collection,
  doc,
  getDoc,
  increment,
  serverTimestamp,
  setDoc,
  updateDoc,
} from "firebase/firestore";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const projectId = "demo-tastie-rules";

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: readFileSync(
        path.resolve(__dirname, "../../firestore.rules"),
        "utf8",
      ),
    },
  });
});

test.after(async () => {
  await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
});

function authedDb(uid, claims = {}) {
  return testEnv.authenticatedContext(uid, claims).firestore();
}

function anonDb() {
  return testEnv.unauthenticatedContext().firestore();
}

async function seedDoc(refPath, data) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), refPath), data);
  });
}

function recipeData(overrides = {}) {
  return {
    userId: "owner",
    authorUid: "owner",
    author: {
      nickname: "Owner",
      avatar: "",
    },
    imageUrls: [],
    title: "Soup",
    content: "A simple soup.",
    tags: ["quick"],
    ingredients: [],
    procedures: [],
    likeCount: 0,
    favCount: 0,
    commentCount: 0,
    status: "active",
    createdAt: serverTimestamp(),
    ...overrides,
  };
}

async function seedRecipe(overrides = {}) {
  await seedDoc("recipes/r1", recipeData(overrides));
}

test("recipe creation must use caller ownership, active status, and zero counters", async () => {
  const ownerDb = authedDb("owner");

  await assertSucceeds(
    setDoc(doc(ownerDb, "recipes/good"), recipeData()),
  );
  await assertFails(
    setDoc(doc(ownerDb, "recipes/wrong-owner"), recipeData({userId: "other"})),
  );
  await assertFails(
    setDoc(doc(ownerDb, "recipes/inflated"), recipeData({likeCount: 99})),
  );
  await assertFails(
    setDoc(doc(ownerDb, "recipes/pre-banned"), recipeData({status: "banned"})),
  );
});

test("authors cannot transfer ownership, change moderation status, or tamper counters", async () => {
  await seedRecipe();
  const ownerDb = authedDb("owner");

  await assertSucceeds(
    updateDoc(doc(ownerDb, "recipes/r1"), {title: "Updated soup"}),
  );
  await assertFails(
    updateDoc(doc(ownerDb, "recipes/r1"), {userId: "victim"}),
  );
  await assertFails(
    updateDoc(doc(ownerDb, "recipes/r1"), {authorUid: "victim"}),
  );
  await assertFails(
    updateDoc(doc(ownerDb, "recipes/r1"), {status: "banned"}),
  );
  await assertFails(
    updateDoc(doc(ownerDb, "recipes/r1"), {likeCount: 50}),
  );
});

test("moderation status updates require an admin custom claim", async () => {
  await seedRecipe();

  await assertFails(
    updateDoc(doc(authedDb("attacker"), "recipes/r1"), {status: "banned"}),
  );
  await assertSucceeds(
    updateDoc(doc(authedDb("admin", {admin: true}), "recipes/r1"), {
      status: "banned",
    }),
  );
  await assertFails(
    updateDoc(doc(authedDb("attacker"), "recipes/r1"), {status: "active"}),
  );
  await assertSucceeds(
    updateDoc(doc(authedDb("admin", {admin: true}), "recipes/r1"), {
      status: "active",
    }),
  );
});

test("engagement counter updates are limited to non-negative one-step changes", async () => {
  await seedRecipe();
  const userDb = authedDb("user");

  await assertSucceeds(
    updateDoc(doc(userDb, "recipes/r1"), {likeCount: increment(1)}),
  );
  await assertSucceeds(
    updateDoc(doc(userDb, "recipes/r1"), {likeCount: increment(-1)}),
  );
  await assertFails(
    updateDoc(doc(userDb, "recipes/r1"), {likeCount: 10}),
  );
  await assertFails(
    updateDoc(doc(userDb, "recipes/r1"), {favCount: increment(-1)}),
  );
});

test("user profile documents are readable only by the user or admins", async () => {
  await seedDoc("users/alice", {
    uid: "alice",
    email: "alice@example.com",
    displayName: "Alice",
  });

  await assertFails(getDoc(doc(anonDb(), "users/alice")));
  await assertFails(getDoc(doc(authedDb("bob"), "users/alice")));
  await assertSucceeds(getDoc(doc(authedDb("alice"), "users/alice")));
  await assertSucceeds(
    getDoc(doc(authedDb("admin", {admin: true}), "users/alice")),
  );
});

test("reports cannot be read by regular users and cannot impersonate reporters", async () => {
  await seedDoc("reports/report1", {
    recipeId: "r1",
    recipeTitle: "Soup",
    authorUsername: "Owner",
    reportedBy: "reporter",
    reason: "Spam",
    description: "Bad content",
    timestamp: serverTimestamp(),
  });

  await assertFails(getDoc(doc(authedDb("reporter"), "reports/report1")));
  await assertSucceeds(
    getDoc(doc(authedDb("admin", {admin: true}), "reports/report1")),
  );

  await assertSucceeds(
    addDoc(collection(authedDb("reporter"), "reports"), {
      recipeId: "r1",
      recipeTitle: "Soup",
      authorUsername: "Owner",
      reportedBy: "reporter",
      reason: "Spam",
      description: "Bad content",
      timestamp: serverTimestamp(),
    }),
  );
  await assertFails(
    addDoc(collection(authedDb("reporter"), "reports"), {
      recipeId: "r1",
      recipeTitle: "Soup",
      authorUsername: "Owner",
      reportedBy: "someone-else",
      reason: "Spam",
      description: "Bad content",
      timestamp: serverTimestamp(),
    }),
  );
});
