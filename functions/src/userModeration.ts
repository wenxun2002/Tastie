import {getAuth} from "firebase-admin/auth";
import type {DocumentData} from "firebase-admin/firestore";
import {getFirestore} from "firebase-admin/firestore";
import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";

const db = getFirestore();

const USERS_COLLECTION = "users";
const RECIPES_COLLECTION = "recipes";
const FIRESTORE_TRIGGER_OPTS = {region: "asia-southeast1"};
const BANNED_AUTHOR_NICKNAME = "Banned User";
const BATCH_LIMIT = 500;

/**
 * Reads a user's moderation status (`active` / `banned`).
 * @param {DocumentData} data Firestore user document fields.
 * @return {string} Normalized status string.
 */
function normalizeUserStatus(data: DocumentData): string {
  return (data["status"] ?? "active").toString().toLowerCase();
}

/**
 * Loads the current user profile used for moderation side effects.
 * @param {string} uid Firebase Auth UID.
 * @return {Promise<DocumentData | null>} Live user fields, or null if missing.
 */
async function readLiveUser(uid: string): Promise<DocumentData | null> {
  const snap = await db.collection(USERS_COLLECTION).doc(uid).get();
  if (!snap.exists) {
    return null;
  }
  return snap.data() ?? {};
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
 * Re-checks live status immediately before every batch commit so a rapid
 * admin toggle aborts stale fan-out instead of overwriting the newer state.
 * @param {string} uid Recipe owner UID.
 * @param {string} nickname Author nickname to write.
 * @param {string} avatar Author avatar URL to write.
 * @param {string} requiredStatus Status that must still be live to continue.
 * @return {Promise<{updated: number, aborted: boolean}>} Progress + abort flag.
 */
async function updateRecipesAuthor(
  uid: string,
  nickname: string,
  avatar: string,
  requiredStatus: string,
): Promise<{updated: number; aborted: boolean}> {
  const snap = await db
    .collection(RECIPES_COLLECTION)
    .where("userId", "==", uid)
    .get();

  if (snap.empty) {
    return {updated: 0, aborted: false};
  }

  let updated = 0;
  let batch = db.batch();
  let batchCount = 0;

  /**
   * Commits the current batch only if live status still matches.
   * @return {Promise<boolean>} False when the fan-out must abort.
   */
  async function commitBatchIfCurrent(): Promise<boolean> {
    if (batchCount === 0) {
      return true;
    }
    const liveUser = await readLiveUser(uid);
    const liveStatus = normalizeUserStatus(liveUser ?? {});
    if (liveStatus !== requiredStatus) {
      logger.warn("Aborting recipe author batch; status changed", {
        uid,
        requiredStatus,
        liveStatus,
        updatedSoFar: updated - batchCount,
      });
      return false;
    }
    await batch.commit();
    batch = db.batch();
    batchCount = 0;
    return true;
  }

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
      const committed = await commitBatchIfCurrent();
      if (!committed) {
        return {updated: updated - batchCount, aborted: true};
      }
    }
  }

  if (batchCount > 0) {
    const committed = await commitBatchIfCurrent();
    if (!committed) {
      return {updated: updated - batchCount, aborted: true};
    }
  }

  return {updated, aborted: false};
}

/**
 * Converges Auth + recipe authors to the *live* user status.
 *
 * Triggers capture before/after from a specific write, but rapid admin toggles
 * can run concurrently. Always re-reading status (and reconciling at the end)
 * prevents a stale ban/restore event from leaving Auth disabled or authors
 * anonymized after the user was restored (or the reverse).
 *
 * Retries a few times when a newer toggle wins mid-fan-out so this invocation
 * still converges mixed recipe authors to the latest status.
 * @param {string} uid Firebase Auth UID.
 * @return {Promise<void>} Resolves when convergence finishes.
 */
async function syncModerationToLiveStatus(uid: string): Promise<void> {
  const maxAttempts = 3;

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    const liveUser = await readLiveUser(uid);
    if (!liveUser) {
      logger.warn("Moderation sync skipped; user doc missing", {uid});
      return;
    }

    const intendedStatus = normalizeUserStatus(liveUser);
    await setAuthDisabled(uid, intendedStatus === "banned");

    // A newer toggle may have landed while Auth was updating.
    const afterAuthUser = await readLiveUser(uid);
    if (!afterAuthUser) {
      return;
    }
    const statusForRecipes = normalizeUserStatus(afterAuthUser);
    if (statusForRecipes !== intendedStatus) {
      await setAuthDisabled(uid, statusForRecipes === "banned");
    }

    const nickname = statusForRecipes === "banned" ?
      BANNED_AUTHOR_NICKNAME :
      resolveAuthorNickname(afterAuthUser);
    const avatar = statusForRecipes === "banned" ?
      "" :
      resolveAuthorAvatar(afterAuthUser);

    const {updated, aborted} = await updateRecipesAuthor(
      uid,
      nickname,
      avatar,
      statusForRecipes,
    );

    // Always reconcile Auth to whatever is live now — even stale invocations
    // must leave Auth aligned with the latest users/{uid}.status.
    const finalUser = await readLiveUser(uid);
    const finalStatus = normalizeUserStatus(finalUser ?? {});
    await setAuthDisabled(uid, finalStatus === "banned");

    if (!aborted && finalStatus === statusForRecipes) {
      logger.info(
        finalStatus === "banned" ? "User banned" : "User restored",
        {uid, recipeCount: updated, nickname, attempt},
      );
      return;
    }

    logger.info("Moderation sync retrying after newer status won", {
      uid,
      statusForRecipes,
      finalStatus,
      recipeCount: updated,
      aborted,
      attempt,
    });
  }

  logger.warn("Moderation sync exhausted retries", {uid, maxAttempts});
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

    // Ban, or restore from banned → active. Other transitions are ignored.
    if (
      nextStatus === "banned" ||
      (nextStatus === "active" && previousStatus === "banned")
    ) {
      await syncModerationToLiveStatus(uid);
    }
  },
);
