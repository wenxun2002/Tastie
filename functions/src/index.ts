/**
 * TasTie Cloud Functions (compiled to functions/lib/index.js).
 *
 * Deploy: `firebase deploy --only functions`
 *
 * Set `GEMINI_API_KEY` in `functions/.env` (see Firebase env docs). Do not use
 * the same name in Secret Manager + .env — that causes deploy errors.
 *
 * Optional: `GEMINI_MODEL` — e.g. gemini-2.0-flash (default). Older IDs like
 * gemini-1.5-flash often return 404 from the API.
 *
 * Callable body may include `images`: array of `{ data: base64, mimeType? }`
 * (max 4, ~4MB each after decode) for multimodal Smart Generate.
 *
 * Weather BFF: set `OPENWEATHER_API_KEY` for `getWeatherContext`
 * (see `weatherContext.ts`).
 */

import type {InlineDataPart, Part, Schema} from "@google/generative-ai";
import {GoogleGenerativeAI, SchemaType} from "@google/generative-ai";
import {initializeApp} from "firebase-admin/app";
import type {DocumentData, Query} from "firebase-admin/firestore";
import {FieldValue, Timestamp, getFirestore} from "firebase-admin/firestore";
import {setGlobalOptions} from "firebase-functions";
import {HttpsError, onCall} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {
  onDocumentCreated,
  onDocumentDeleted,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";

export {getWeatherContext} from "./weatherContext";
export {moderateUserOnStatusChange} from "./userModeration";

setGlobalOptions({maxInstances: 10});
initializeApp();

const db = getFirestore();
const MYT_OFFSET_MS = 8 * 60 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;

const USERS_COLLECTION = "users";
const RECIPES_COLLECTION = "recipes";
const REPORTS_COLLECTION = "reports";
const RECIPE_CLICK_EVENTS_COLLECTION = "recipe_click_events";
const METRICS_DOC_PATH = "admin_metrics/dashboard_overview";
const FIRESTORE_TRIGGER_OPTS = {region: "asia-southeast1"};

type DashboardSnapshot = {
  totalUsers: number;
  totalPosts: number;
  pendingReports: number;
  bannedUsers: number;
  todayRecipes: number;
  todayHourlyRecipeCounts: number[];
  last7DailyRecipeCounts: number[];
};

type MytDateParts = {
  year: number;
  month: number;
  day: number;
  hour: number;
};

/**
 * Converts a UTC instant to Malaysia calendar parts (fixed +8h, no DST).
 * @param {Date} utcDate Instant in UTC.
 * @return {MytDateParts} Year/month/day/hour in MYT.
 */
function toMytDateParts(utcDate: Date): MytDateParts {
  const myt = new Date(utcDate.getTime() + MYT_OFFSET_MS);
  return {
    year: myt.getUTCFullYear(),
    month: myt.getUTCMonth(),
    day: myt.getUTCDate(),
    hour: myt.getUTCHours(),
  };
}

/**
 * Serializes a MYT calendar day for bucket indexing.
 * @param {Date} utcDate Document timestamp interpreted as UTC.
 * @return {number} UTC millis at MYT midnight for that local day.
 */
function mytDaySerial(utcDate: Date): number {
  const p = toMytDateParts(utcDate);
  return Date.UTC(p.year, p.month, p.day);
}

/**
 * MYT "today" window expressed in UTC for Firestore range queries.
 * @param {Date} nowUtc Current instant in UTC.
 * @return {{startUtc: Date, endUtc: Date}} Inclusive start, exclusive end.
 */
function utcBoundsForMytToday(nowUtc: Date): {startUtc: Date; endUtc: Date} {
  const p = toMytDateParts(nowUtc);
  const startUtcMs = Date.UTC(p.year, p.month, p.day) - MYT_OFFSET_MS;
  return {
    startUtc: new Date(startUtcMs),
    endUtc: new Date(startUtcMs + DAY_MS),
  };
}

/**
 * Runs a Firestore aggregate count query.
 * @param {Query<DocumentData>} query Query whose rows should be counted.
 * @return {Promise<number>} Document count.
 */
async function countQuery(query: Query<DocumentData>): Promise<number> {
  const snap = await query.count().get();
  return snap.data().count;
}

/**
 * Reads createdAt from a stored document map.
 * @param {DocumentData} data Firestore document fields.
 * @return {Date | null} Parsed instant or null if missing/invalid.
 */
function extractCreatedAt(data: DocumentData): Date | null {
  const raw = data["createdAt"];
  if (raw instanceof Timestamp) {
    return raw.toDate();
  }
  if (raw instanceof Date) {
    return raw;
  }
  return null;
}

/**
 * Checks whether a simple scalar Firestore field changed across an update.
 * @param {DocumentData | undefined} before Fields before the update.
 * @param {DocumentData | undefined} after Fields after the update.
 * @param {string} fieldName Field to compare.
 * @return {boolean} True when the field value changed.
 */
function scalarFieldChanged(
  before: DocumentData | undefined,
  after: DocumentData | undefined,
  fieldName: string,
): boolean {
  return before?.[fieldName] !== after?.[fieldName];
}

/**
 * Recomputes dashboard counters and writes `admin_metrics/dashboard_overview`.
 * @return {Promise<void>} Resolves when the metrics doc is updated.
 */
async function recomputeDashboardMetrics(): Promise<void> {
  const nowUtc = new Date();
  const todayBounds = utcBoundsForMytToday(nowUtc);
  const weekStartUtc = new Date(todayBounds.startUtc.getTime() - 6 * DAY_MS);
  const todaySerial = mytDaySerial(nowUtc);
  const weekStartSerial = todaySerial - 6 * DAY_MS;

  const usersCol = db.collection(USERS_COLLECTION);
  const recipesCol = db.collection(RECIPES_COLLECTION);
  const reportsCol = db.collection(REPORTS_COLLECTION);

  const [
    totalUsers,
    totalPosts,
    totalReports,
    resolvedReports,
    bannedUsers,
    todayRecipes,
    recipeDocsLast7Days,
  ] = await Promise.all([
    countQuery(usersCol),
    countQuery(recipesCol),
    countQuery(reportsCol),
    Promise.all([
      countQuery(reportsCol.where("status", "==", "solved")),
      countQuery(reportsCol.where("status", "==", "resolved")),
    ]).then(([solved, legacyResolved]) => solved + legacyResolved),
    countQuery(usersCol.where("status", "==", "banned")),
    countQuery(
      recipesCol
        .where("createdAt", ">=", Timestamp.fromDate(todayBounds.startUtc))
        .where("createdAt", "<", Timestamp.fromDate(todayBounds.endUtc)),
    ),
    recipesCol
      .where("createdAt", ">=", Timestamp.fromDate(weekStartUtc))
      .where("createdAt", "<", Timestamp.fromDate(todayBounds.endUtc))
      .get(),
  ]);

  const hourly = Array<number>(24).fill(0);
  const weekly = Array<number>(7).fill(0);

  for (const doc of recipeDocsLast7Days.docs) {
    const createdAt = extractCreatedAt(doc.data());
    if (!createdAt) continue;

    const myt = toMytDateParts(createdAt);
    const serial = Date.UTC(myt.year, myt.month, myt.day);
    const dayIndex = Math.floor((serial - weekStartSerial) / DAY_MS);
    if (dayIndex < 0 || dayIndex >= 7) continue;

    weekly[dayIndex] = weekly[dayIndex] + 1;
    if (dayIndex === 6 && myt.hour >= 0 && myt.hour < 24) {
      hourly[myt.hour] = hourly[myt.hour] + 1;
    }
  }

  const pendingReports = Math.max(0, totalReports - resolvedReports);
  const snapshot: DashboardSnapshot = {
    totalUsers,
    totalPosts,
    pendingReports,
    bannedUsers,
    todayRecipes,
    todayHourlyRecipeCounts: hourly,
    last7DailyRecipeCounts: weekly,
  };

  await db.doc(METRICS_DOC_PATH).set({
    ...snapshot,
    timezone: "Asia/Kuala_Lumpur",
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
}

/** `gemini-1.5-flash` is often unavailable (404); use a current Flash model. */
const DEFAULT_GEMINI_MODEL = "gemini-2.0-flash";

const ALLOWED_UNITS = new Set([
  "g",
  "kg",
  "ml",
  "l",
  "piece",
  "slice",
  "whole",
  "clove",
  "tbsp",
  "tsp",
  "cup",
  "a few drops",
  "a pinch",
  "to taste",
  "as needed",
  "handful",
]);

const SPECIAL_UNITS = new Set([
  "a few drops",
  "a pinch",
  "to taste",
  "as needed",
  "handful",
]);

interface IngredientRow {
  name: string;
  amount: number;
  unit: string;
}

interface NutritionRow {
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
}

interface SmartGenerateResult {
  ingredients: IngredientRow[];
  nutrition: NutritionRow;
  procedures: string[];
}

const responseSchema: Schema = {
  type: SchemaType.OBJECT,
  properties: {
    ingredients: {
      type: SchemaType.ARRAY,
      items: {
        type: SchemaType.OBJECT,
        properties: {
          name: {type: SchemaType.STRING},
          amount: {type: SchemaType.NUMBER},
          unit: {type: SchemaType.STRING},
        },
        required: ["name", "amount", "unit"],
      },
    },
    nutrition: {
      type: SchemaType.OBJECT,
      properties: {
        calories: {type: SchemaType.NUMBER},
        protein: {type: SchemaType.NUMBER},
        carbs: {type: SchemaType.NUMBER},
        fat: {type: SchemaType.NUMBER},
      },
      required: ["calories", "protein", "carbs", "fat"],
    },
    procedures: {
      type: SchemaType.ARRAY,
      items: {type: SchemaType.STRING},
    },
  },
  required: ["ingredients", "nutrition", "procedures"],
};

/**
 * Validates Gemini JSON output and fixes minor inconsistencies (allowed units).
 * @param {unknown} parsed Parsed JSON from the model.
 * @return {SmartGenerateResult} Normalized payload for the Flutter client.
 */
function normalizeAndValidate(parsed: unknown): SmartGenerateResult {
  if (!parsed || typeof parsed !== "object") {
    throw new HttpsError("internal", "AI returned invalid JSON.");
  }
  const raw = parsed as Record<string, unknown>;

  const ingredientsRaw = raw.ingredients;
  const nutritionRaw = raw.nutrition;
  const proceduresRaw = raw.procedures;

  if (!Array.isArray(ingredientsRaw) || ingredientsRaw.length === 0) {
    throw new HttpsError("internal", "AI response missing ingredients.");
  }
  if (!nutritionRaw || typeof nutritionRaw !== "object") {
    throw new HttpsError("internal", "AI response missing nutrition.");
  }
  if (!Array.isArray(proceduresRaw) || proceduresRaw.length === 0) {
    throw new HttpsError("internal", "AI response missing procedures.");
  }

  const ingredients: IngredientRow[] = ingredientsRaw.map((item, index) => {
    if (!item || typeof item !== "object") {
      throw new HttpsError("internal", `Invalid ingredient at index ${index}.`);
    }
    const row = item as Record<string, unknown>;
    const name = String(row.name ?? "").trim();
    if (!name) {
      throw new HttpsError(
        "internal",
        `Ingredient name missing at index ${index}.`,
      );
    }
    const unitRaw = String(row.unit ?? "").trim();
    const unit = ALLOWED_UNITS.has(unitRaw) ? unitRaw : "g";
    let amount = Number(row.amount);
    if (!Number.isFinite(amount)) {
      amount = 0;
    }
    if (SPECIAL_UNITS.has(unit)) {
      amount = 0;
    } else {
      if (amount < 0) {
        amount = 0;
      }
      if (amount <= 0) {
        amount = 1;
      }
    }
    return {name, amount, unit};
  });

  const n = nutritionRaw as Record<string, unknown>;
  const nutrition: NutritionRow = {
    calories: Math.max(0, Number(n.calories) || 0),
    protein: Math.max(0, Number(n.protein) || 0),
    carbs: Math.max(0, Number(n.carbs) || 0),
    fat: Math.max(0, Number(n.fat) || 0),
  };

  const procedures = proceduresRaw.map((step, index) => {
    const text = String(step ?? "").trim();
    if (!text) {
      throw new HttpsError(
        "internal",
        `Empty procedure step at index ${index}.`,
      );
    }
    return text;
  });

  return {ingredients, nutrition, procedures};
}

const MAX_SMART_IMAGES = 4;
const MAX_IMAGE_BYTES = 4 * 1024 * 1024;

/**
 * Parses client `images: [{ data: base64, mimeType?: string }]` for Gemini.
 * @param {unknown} raw Request field `images`.
 * @return {InlineDataPart[]} Inline image parts (max MAX_SMART_IMAGES).
 */
function buildInlineImageParts(raw: unknown): InlineDataPart[] {
  const parts: InlineDataPart[] = [];
  if (!Array.isArray(raw)) {
    return parts;
  }
  for (let i = 0; i < raw.length && parts.length < MAX_SMART_IMAGES; i++) {
    const item = raw[i];
    if (!item || typeof item !== "object") {
      continue;
    }
    const row = item as Record<string, unknown>;
    const b64 = String(row.data ?? row.base64 ?? "").trim();
    if (!b64) {
      continue;
    }
    let mime = String(row.mimeType ?? "image/jpeg").toLowerCase();
    if (!mime.startsWith("image/")) {
      mime = "image/jpeg";
    }
    let buffer: Buffer;
    try {
      buffer = Buffer.from(b64, "base64");
    } catch {
      continue;
    }
    if (buffer.length === 0 || buffer.length > MAX_IMAGE_BYTES) {
      logger.warn("smartGenerate: skip image (size)", {
        index: i,
        bytes: buffer.length,
      });
      continue;
    }
    parts.push({
      inlineData: {
        mimeType: mime,
        data: b64,
      },
    });
  }
  return parts;
}

export const smartGenerate = onCall(
  {
    region: "asia-southeast1",
    timeoutSeconds: 120,
    memory: "512MiB",
    cors: true,
  },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError(
        "unauthenticated",
        "You must be signed in to use Smart Generate.",
      );
    }

    const apiKey = process.env.GEMINI_API_KEY?.trim() ?? "";
    if (!apiKey) {
      logger.error("GEMINI_API_KEY is not set (functions/.env or deploy env)");
      throw new HttpsError(
        "failed-precondition",
        "Server missing GEMINI_API_KEY. Add it to functions/.env for deploy.",
      );
    }

    const data = (request.data ?? {}) as Record<string, unknown>;
    const title = String(data.title ?? "").trim();
    const content = String(data.content ?? "").trim();
    const userInput = String(data.userInput ?? "").trim();
    const imageParts = buildInlineImageParts(data.images);

    if (!title && !content && !userInput && imageParts.length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "Provide title, description, notes, or at least one image.",
      );
    }

    const userPromptParts = [
      "You generate ONLY structured recipe data for the TasTie app.",
      "",
      "Hard constraints:",
      "1) Unit Constraint: each ingredient.unit must be EXACTLY one " +
        "of these strings:",
      "\"g\", \"kg\", \"ml\", \"l\", \"piece\", \"slice\", \"whole\", " +
        "\"clove\", \"tbsp\", \"tsp\", \"cup\", \"a few drops\", " +
        "\"a pinch\", \"to taste\", \"as needed\", \"handful\".",
      "",
      "2) Special Rules for Units & Amounts (CRITICAL):",
      "- If unit is one of: a few drops, a pinch, to taste, as needed, " +
        "handful — then amount MUST be 0.",
      "- For countable items (e.g., strawberries, eggs, tomatoes), use " +
        "\"whole\" or \"piece\" with the exact count (e.g., amount: 2, " +
        "unit: \"whole\"). DO NOT use \"g\" for small countable items.",
      "- For portions of meat, estimate a realistic weight in grams " +
        "(e.g., 200g, 500g). DO NOT use fractional weights like 0.25g " +
        "for meat. If the image shows 1/4 of a chicken, output its " +
        "estimated weight in grams (e.g., 300g).",
      "- Spices and powders should typically use \"tsp\", \"tbsp\", " +
        "or \"g\".",
      "",
      "3) Nutrition Constraint: estimate total-dish calories, protein, " +
        "carbs, fat with common sense.",
      "All nutrition values must be numbers and >= 0.",
      "",
      "4) Language Constraint: Regardless of input language (e.g. Chinese),",
      "ingredient names and procedure steps MUST be written in English only.",
      "",
    ];

    if (imageParts.length > 0) {
      userPromptParts.push(
        `Multimodal: ${imageParts.length} food photo(s) are attached. ` +
          "When user text is short, rely primarily on the images to infer " +
          "the dish, ingredients, and realistic cooking steps. " +
          "Stay consistent with what is visible.",
        "",
      );
    }

    userPromptParts.push(
      "Context from the user:",
      title ? `Title:\n${title}` : "",
      content ? `Description:\n${content}` : "",
      userInput ? `Additional notes:\n${userInput}` : "",
    );
    const prompt = userPromptParts.filter(Boolean).join("\n");

    try {
      const modelId =
        process.env.GEMINI_MODEL?.trim() || DEFAULT_GEMINI_MODEL;
      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({
        model: modelId,
        generationConfig: {
          responseMimeType: "application/json",
          responseSchema,
        },
      });

      const parts: Array<string | Part> = [...imageParts, prompt];
      const result = await model.generateContent(parts);
      const response = result.response;
      const text = response.text();
      if (!text) {
        throw new HttpsError("internal", "Empty model response.");
      }

      let parsed: unknown;
      try {
        parsed = JSON.parse(text) as unknown;
      } catch (e) {
        logger.error("JSON parse failed", {text, error: String(e)});
        throw new HttpsError("internal", "Model returned non-JSON text.");
      }

      const normalized = normalizeAndValidate(parsed);
      logger.info("smartGenerate ok", {uid: request.auth.uid});
      return normalized;
    } catch (e: unknown) {
      if (e instanceof HttpsError) {
        throw e;
      }
      const message = e instanceof Error ? e.message : String(e);
      logger.error("smartGenerate failed", {error: message});
      throw new HttpsError("internal", `Smart Generate failed: ${message}`);
    }
  },
);

export const refreshDashboardMetricsOnUserCreate = onDocumentCreated(
  {
    ...FIRESTORE_TRIGGER_OPTS,
    document: `${USERS_COLLECTION}/{docId}`,
  },
  async () => {
    await recomputeDashboardMetrics();
  },
);

export const refreshDashboardMetricsOnUserDelete = onDocumentDeleted(
  {
    ...FIRESTORE_TRIGGER_OPTS,
    document: `${USERS_COLLECTION}/{docId}`,
  },
  async () => {
    await recomputeDashboardMetrics();
  },
);

export const refreshDashboardMetricsOnUserUpdate = onDocumentUpdated(
  {
    ...FIRESTORE_TRIGGER_OPTS,
    document: `${USERS_COLLECTION}/{docId}`,
  },
  async (event) => {
    if (scalarFieldChanged(
      event.data?.before.data(),
      event.data?.after.data(),
      "status",
    )) {
      await recomputeDashboardMetrics();
    }
  },
);

export const refreshDashboardMetricsOnRecipeCreate = onDocumentCreated(
  {
    ...FIRESTORE_TRIGGER_OPTS,
    document: `${RECIPES_COLLECTION}/{docId}`,
  },
  async () => {
    await recomputeDashboardMetrics();
  },
);

export const refreshDashboardMetricsOnRecipeDelete = onDocumentDeleted(
  {
    ...FIRESTORE_TRIGGER_OPTS,
    document: `${RECIPES_COLLECTION}/{docId}`,
  },
  async () => {
    await recomputeDashboardMetrics();
  },
);

export const refreshDashboardMetricsOnRecipeUpdate = onDocumentUpdated(
  {
    ...FIRESTORE_TRIGGER_OPTS,
    document: `${RECIPES_COLLECTION}/{docId}`,
  },
  async () => {
    // Likes, clicks, content, and moderation updates do not affect dashboard
    // counters; create/delete triggers maintain recipe totals.
    return;
  },
);

export const refreshDashboardMetricsOnReportCreate = onDocumentCreated(
  {
    ...FIRESTORE_TRIGGER_OPTS,
    document: `${REPORTS_COLLECTION}/{docId}`,
  },
  async () => {
    await recomputeDashboardMetrics();
  },
);

export const refreshDashboardMetricsOnReportDelete = onDocumentDeleted(
  {
    ...FIRESTORE_TRIGGER_OPTS,
    document: `${REPORTS_COLLECTION}/{docId}`,
  },
  async () => {
    await recomputeDashboardMetrics();
  },
);

export const refreshDashboardMetricsOnReportUpdate = onDocumentUpdated(
  {
    ...FIRESTORE_TRIGGER_OPTS,
    document: `${REPORTS_COLLECTION}/{docId}`,
  },
  async (event) => {
    if (scalarFieldChanged(
      event.data?.before.data(),
      event.data?.after.data(),
      "status",
    )) {
      await recomputeDashboardMetrics();
    }
  },
);

const CLICK_SOURCE_VALUES = new Set([
  "weather_promoted",
  "weather_notpromoted",
  "normal_browse",
  "search",
]);

/**
 * Seeds `click_metrics` from legacy `clicked` when missing, then increments
 * the bucket + total for ML telemetry (written by mobile app).
 */
export const aggregateRecipeClickMetricsOnEventCreate = onDocumentCreated(
  {
    ...FIRESTORE_TRIGGER_OPTS,
    document: `${RECIPE_CLICK_EVENTS_COLLECTION}/{eventId}`,
  },
  async (event) => {
    const snap = event.data;
    if (!snap) {
      return;
    }
    const recipeId = snap.get("recipeId") as string | undefined;
    const clickSource = snap.get("clickSource") as string | undefined;
    if (!recipeId || !clickSource || !CLICK_SOURCE_VALUES.has(clickSource)) {
      logger.warn("recipe_click_events: skip invalid payload", {
        recipeId,
        clickSource,
      });
      return;
    }

    const recipeRef = db.collection(RECIPES_COLLECTION).doc(recipeId);
    const recipeSnap = await recipeRef.get();
    if (!recipeSnap.exists) {
      logger.warn("recipe_click_events: recipe not found", {recipeId});
      return;
    }

    const recipeData = recipeSnap.data() ?? {};
    const cm = recipeData["click_metrics"];
    const needsSeed =
      cm === undefined || cm === null || typeof cm !== "object";

    if (needsSeed) {
      const rawLegacy = recipeData["clicked"];
      let legacyClicked = 0;
      if (typeof rawLegacy === "number") {
        legacyClicked = rawLegacy;
      } else if (typeof rawLegacy === "string") {
        legacyClicked = Number.parseInt(rawLegacy, 10) || 0;
      }

      await recipeRef.set(
        {
          click_metrics: {
            weather_promoted: 0,
            weather_notpromoted: 0,
            normal_browse: 0,
            search: 0,
            total: legacyClicked,
          },
        },
        {merge: true},
      );
    }

    await recipeRef.update({
      [`click_metrics.${clickSource}`]: FieldValue.increment(1),
      "click_metrics.total": FieldValue.increment(1),
    });
  },
);
