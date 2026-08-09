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
 * Returns true when Admin Auth reports the UID does not exist.
 * @param {unknown} error Auth error from firebase-admin.
 * @return {boolean} Whether the error is auth/user-not-found.
 */
function isAuthUserNotFound(error: unknown): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    (error as {code?: string}).code === "auth/user-not-found"
  );
}

/**
 * Enables or disables Firebase Auth for the given UID.
 *
 * Must not swallow transient failures: the Firestore trigger otherwise
 * completes successfully, so Auth stays permanently out of sync with
 * `users/{uid}.status` (banned user still minting tokens, or restored
 * user stuck `disabled`).
 *
 * @param {string} uid Firebase Auth UID.
 * @param {boolean} disabled Whether the account should be disabled.
 * @return {Promise<void>} Resolves when Auth is updated.
 */
async function setAuthDisabled(uid: string, disabled: boolean): Promise<void> {
  const maxAttempts = 3;
  let lastError: unknown;

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      await getAuth().updateUser(uid, {disabled});
      if (disabled) {
        // Best-effort: shrink the stale-token window after a successful ban.
        try {
          await getAuth().revokeRefreshTokens(uid);
        } catch (revokeError) {
          logger.warn("Failed to revoke refresh tokens after disable", {
            uid,
            error: String(revokeError),
          });
        }
      }
      return;
    } catch (error) {
      lastError = error;
      if (isAuthUserNotFound(error)) {
        // Orphaned profile with no Auth user: cannot toggle disabled.
        logger.warn("Auth user missing; skipping disabled toggle", {
          uid,
          disabled,
        });
        return;
      }
      logger.warn("Failed to update Auth disabled state", {
        uid,
        disabled,
        attempt,
        error: String(error),
      });
      if (attempt < maxAttempts) {
        await new Promise((resolve) => setTimeout(resolve, 250 * attempt));
      }
    }
  }

  throw new Error(
    `Failed to set Auth disabled=${disabled} for ${uid}: ${String(lastError)}`,
  );
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
 * Event snapshots capture a specific write, but Cloud Functions can retry
 * and admins can toggle rapidly. Always re-reading status prevents a stale
 * ban/restore delivery from disabling Auth after a restore (or the reverse).
 *
 * Auth failures still throw so the trigger retries; recipe fan-out aborts
 * mid-flight when a newer status wins and this helper re-converges.
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
    // Auth sync failures must be redelivered. Handler converges to *live*
    // status, so stale retries after a rapid toggle remain safe.
    retry: true,
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
