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
 */

import type {Schema} from "@google/generative-ai";
import {GoogleGenerativeAI, SchemaType} from "@google/generative-ai";
import {setGlobalOptions} from "firebase-functions";
import {HttpsError, onCall} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";

setGlobalOptions({maxInstances: 10});

/** `gemini-1.5-flash` is often unavailable (404); use a current Flash model. */
const DEFAULT_GEMINI_MODEL = "gemini-2.0-flash";

const ALLOWED_UNITS = new Set([
  "g",
  "kg",
  "ml",
  "l",
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

    if (!title && !content && !userInput) {
      throw new HttpsError(
        "invalid-argument",
        "Provide title, content, or userInput for Smart Generate.",
      );
    }

    const userPromptParts = [
      "You generate ONLY structured recipe data for the TasTie app.",
      "",
      "Hard constraints:",
      "1) Unit Constraint: each ingredient.unit must be EXACTLY one " +
        "of these strings:",
      "\"g\", \"kg\", \"ml\", \"l\", \"a few drops\", \"a pinch\", " +
        "\"to taste\", \"as needed\", \"handful\".",
      "If unit is one of: a few drops, a pinch, to taste, as needed, " +
        "handful — then amount MUST be 0.",
      "For g, kg, ml, l use a positive numeric amount appropriate for " +
        "one recipe.",
      "",
      "2) Nutrition Constraint: estimate total-dish calories, protein, " +
        "carbs, fat with common sense.",
      "All nutrition values must be numbers and >= 0.",
      "",
      "3) Language Constraint: Regardless of input language (e.g. Chinese),",
      "ingredient names and procedure steps MUST be written in English only.",
      "",
      "Context from the user:",
      title ? `Title:\n${title}` : "",
      content ? `Description:\n${content}` : "",
      userInput ? `Additional notes:\n${userInput}` : "",
    ].filter(Boolean);

    const prompt = userPromptParts.join("\n");

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

      const result = await model.generateContent(prompt);
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
