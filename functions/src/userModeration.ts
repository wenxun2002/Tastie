import {getAuth} from "firebase-admin/auth";
import type {DocumentData} from "firebase-admin/firestore";
import {getFirestore} from "firebase-admin/firestore";
import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";

const USERS_COLLECTION = "users";
const RECIPES_COLLECTION = "recipes";
const FIRESTORE_TRIGGER_OPTS = {region: "asia-southeast1"};
const BANNED_AUTHOR_NICKNAME = "Banned User";
const BATCH_LIMIT = 500;

/**
 * Resolves the Firestore client lazily after Firebase Admin initialization.
 * @return {FirebaseFirestore.Firestore} Firestore client.
 */
function firestore() {
  return getFirestore();
}

/**
 * Reads a user's moderation status (`active` / `banned`).
 * @param {DocumentData} data Firestore user document fields.
 * @return {string} Normalized status string.
 */
function normalizeUserStatus(data: DocumentData): string {
  return (data["status"] ?? "active").toString().toLowerCase();
}

/**
 * Resolves the display name shown on restored recipe author fields.
 * @param {DocumentData} userData Firestore user document fields.
 * @return {string} Nickname for recipe author restoration.
 */
function resolveAuthorNickname(userData: DocumentData): string {
  const displayName = (userData["displayName"] ?? "").toString().trim();
  return displayName.length === 0 ? "User" : displayName;
}

/**
 * Resolves avatar URL for restored recipe author fields.
 * @param {DocumentData} userData Firestore user document fields.
 * @return {string} Avatar URL or empty string.
 */
function resolveAuthorAvatar(userData: DocumentData): string {
  return (userData["photoURL"] ?? "").toString();
}

/**
 * Enables or disables Firebase Auth for the given UID.
 * @param {string} uid Firebase Auth UID.
 * @param {boolean} disabled Whether the account should be disabled.
 * @return {Promise<void>} Resolves when Auth is updated or logs a warning.
 */
async function setAuthDisabled(uid: string, disabled: boolean): Promise<void> {
  try {
    await getAuth().updateUser(uid, {disabled});
  } catch (error) {
    logger.warn("Failed to update Auth disabled state", {
      uid,
      disabled,
      error: String(error),
    });
  }
}

/**
 * Updates all recipes owned by [uid] with the given author nickname/avatar.
 * @param {string} uid Recipe owner UID.
 * @param {string} nickname Author nickname to write.
 * @param {string} avatar Author avatar URL to write.
 * @return {Promise<number>} Number of recipe documents updated.
 */
async function updateRecipesAuthor(
  uid: string,
  nickname: string,
  avatar: string,
): Promise<number> {
  const db = firestore();
  const snap = await db
    .collection(RECIPES_COLLECTION)
    .where("userId", "==", uid)
    .get();

  if (snap.empty) {
    return 0;
  }

  let updated = 0;
  let batch = db.batch();
  let batchCount = 0;

  for (const doc of snap.docs) {
    batch.update(doc.ref, {
      author: {
        nickname,
        avatar,
      },
    });
    updated += 1;
    batchCount += 1;

    if (batchCount >= BATCH_LIMIT) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }

  return updated;
}

/**
 * On ban/restore: sync Auth and anonymize or restore recipe authors.
 */
export const moderateUserOnStatusChange = onDocumentUpdated(
  {
    ...FIRESTORE_TRIGGER_OPTS,
    document: `${USERS_COLLECTION}/{userId}`,
  },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) {
      return;
    }

    const previousStatus = normalizeUserStatus(before);
    const nextStatus = normalizeUserStatus(after);
    if (previousStatus === nextStatus) {
      return;
    }

    const uid = event.params.userId;

    if (nextStatus === "banned") {
      await setAuthDisabled(uid, true);
      const recipeCount = await updateRecipesAuthor(
        uid,
        BANNED_AUTHOR_NICKNAME,
        "",
      );
      logger.info("User banned", {uid, recipeCount});
      return;
    }

    if (nextStatus === "active" && previousStatus === "banned") {
      await setAuthDisabled(uid, false);
      const nickname = resolveAuthorNickname(after);
      const avatar = resolveAuthorAvatar(after);
      const recipeCount = await updateRecipesAuthor(uid, nickname, avatar);
      logger.info("User restored", {uid, recipeCount, nickname});
    }
  },
);
