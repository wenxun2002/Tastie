/**
 * BFF: OpenWeather + classifyWeather + TagPolicy
 * (mirrors Flutter weather_classifier and tag_policy.dart).
 * Set OPENWEATHER_API_KEY in functions/.env (or deploy env).
 */

import * as admin from "firebase-admin";
import {HttpsError, onCall} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";

export type WeatherCategoryKey =
  | "hotHumid"
  | "hotDry"
  | "rainy"
  | "cold"
  | "neutral"
  | "winter";

type TagBuckets = {
  promoted: string[];
  neutral: string[];
  suppressed: string[];
};

type CategoryRule = {
  thresholds: Record<string, number>;
  tags: TagBuckets;
};

type WeatherRulesDocument = Record<WeatherCategoryKey, CategoryRule> & {
  lastUpdated?: string;
};

const CATEGORY_KEYS: WeatherCategoryKey[] = [
  "hotHumid",
  "hotDry",
  "rainy",
  "cold",
  "winter",
  "neutral",
];

const DEFAULT_TAG_POLICY: Record<WeatherCategoryKey, TagBuckets> = {
  hotHumid: {
    promoted: ["Cooling", "Hydrating", "Light"],
    neutral: ["Comfort"],
    suppressed: ["Energy", "Warming"],
  },
  hotDry: {
    promoted: ["Cooling", "Hydrating"],
    neutral: ["Comfort", "Light"],
    suppressed: ["Energy", "Warming"],
  },
  rainy: {
    promoted: ["Comfort", "Warming"],
    neutral: ["Energy", "Light"],
    suppressed: ["Cooling", "Hydrating"],
  },
  cold: {
    promoted: ["Energy", "Warming", "Comfort"],
    neutral: ["Light"],
    suppressed: ["Cooling", "Hydrating"],
  },
  winter: {
    promoted: ["Warming", "Comfort", "Energy"],
    neutral: ["Light"],
    suppressed: ["Cooling", "Hydrating"],
  },
  neutral: {
    promoted: [],
    neutral: [
      "Cooling",
      "Hydrating",
      "Light",
      "Energy",
      "Warming",
      "Comfort",
    ],
    suppressed: [],
  },
};

const DEFAULT_THRESHOLDS: Record<WeatherCategoryKey, Record<string, number>> = {
  hotHumid: {
    minFeelsLike: 38,
    minTemp: 33,
    minHumidity: 70,
    minUvIndex: 8,
    minTempForUv: 30,
  },
  hotDry: {
    minFeelsLike: 32,
    minTemp: 28,
    minHumidity: 60,
  },
  rainy: {
    minPrecipitation: 0.5,
  },
  cold: {
    maxTemp: 26,
    maxFeelsLike: 27,
  },
  winter: {},
  neutral: {},
};

const LEGACY_DEFAULT_TEMPERATURE_THRESHOLDS = {
  hot: 33,
  cold: 26,
  hotHumidFeelsLike: 38,
  hotHumidHumidity: 70,
  uvHigh: 8,
  uvCompanionTemp: 30,
  coldFeelsLike: 27,
  hotDryFeelsLike: 32,
  hotDryTemp: 28,
  hotDryHumidity: 60,
  rainPrecipitationMm: 0.5,
};

const DEFAULT_WEATHER_RULES: WeatherRulesDocument = {
  hotHumid: {
    thresholds: {...DEFAULT_THRESHOLDS.hotHumid},
    tags: {
      promoted: [...DEFAULT_TAG_POLICY.hotHumid.promoted],
      neutral: [...DEFAULT_TAG_POLICY.hotHumid.neutral],
      suppressed: [...DEFAULT_TAG_POLICY.hotHumid.suppressed],
    },
  },
  hotDry: {
    thresholds: {...DEFAULT_THRESHOLDS.hotDry},
    tags: {
      promoted: [...DEFAULT_TAG_POLICY.hotDry.promoted],
      neutral: [...DEFAULT_TAG_POLICY.hotDry.neutral],
      suppressed: [...DEFAULT_TAG_POLICY.hotDry.suppressed],
    },
  },
  rainy: {
    thresholds: {...DEFAULT_THRESHOLDS.rainy},
    tags: {
      promoted: [...DEFAULT_TAG_POLICY.rainy.promoted],
      neutral: [...DEFAULT_TAG_POLICY.rainy.neutral],
      suppressed: [...DEFAULT_TAG_POLICY.rainy.suppressed],
    },
  },
  cold: {
    thresholds: {...DEFAULT_THRESHOLDS.cold},
    tags: {
      promoted: [...DEFAULT_TAG_POLICY.cold.promoted],
      neutral: [...DEFAULT_TAG_POLICY.cold.neutral],
      suppressed: [...DEFAULT_TAG_POLICY.cold.suppressed],
    },
  },
  winter: {
    thresholds: {...DEFAULT_THRESHOLDS.winter},
    tags: {
      promoted: [...DEFAULT_TAG_POLICY.winter.promoted],
      neutral: [...DEFAULT_TAG_POLICY.winter.neutral],
      suppressed: [...DEFAULT_TAG_POLICY.winter.suppressed],
    },
  },
  neutral: {
    thresholds: {...DEFAULT_THRESHOLDS.neutral},
    tags: {
      promoted: [...DEFAULT_TAG_POLICY.neutral.promoted],
      neutral: [...DEFAULT_TAG_POLICY.neutral.neutral],
      suppressed: [...DEFAULT_TAG_POLICY.neutral.suppressed],
    },
  },
};

if (!admin.apps.length) {
  admin.initializeApp();
}

interface WeatherSignals {
  temperature: number;
  feelsLike: number;
  humidity: number;
  conditionText: string;
  conditionCode: number | null;
  uvIndex: number;
  precipitation: number;
}

/**
 * Parses a value as a finite number or returns a fallback.
 * @param {unknown} v Input value.
 * @param {number} fallback Default when not a finite number.
 * @return {number} Parsed number or fallback.
 */
function numOr(v: unknown, fallback: number): number {
  const n = Number(v);
  return Number.isFinite(n) ? n : fallback;
}

/**
 * Normalizes Firestore list fields to trimmed non-empty strings.
 * @param {unknown} v Raw field value.
 * @return {string[]} String list.
 */
function toStringList(v: unknown): string[] {
  if (!Array.isArray(v)) return [];
  return v
    .map((x) => String(x ?? "").trim())
    .filter((x) => x.length > 0);
}

/**
 * Merges optional tag bucket arrays with schema defaults.
 * @param {unknown} raw Firestore `tags` payload or absent.
 * @param {TagBuckets} fallback Default buckets when raw is invalid.
 * @return {TagBuckets} Effective buckets.
 */
function mergeTagBuckets(raw: unknown, fallback: TagBuckets): TagBuckets {
  if (!raw || typeof raw !== "object") {
    return {
      promoted: [...fallback.promoted],
      neutral: [...fallback.neutral],
      suppressed: [...fallback.suppressed],
    };
  }
  const o = raw as Record<string, unknown>;
  return {
    promoted:
      "promoted" in o ? toStringList(o.promoted) : [...fallback.promoted],
    neutral: "neutral" in o ? toStringList(o.neutral) : [...fallback.neutral],
    suppressed:
      "suppressed" in o ? toStringList(o.suppressed) : [...fallback.suppressed],
  };
}

/**
 * Merges numeric threshold fields from Firestore with defaults.
 * @param {unknown} raw Firestore `thresholds` map or absent.
 * @param {Record<string, number>} fallback Default thresholds.
 * @return {Record<string, number>} Effective thresholds.
 */
function mergeThresholds(
  raw: unknown,
  fallback: Record<string, number>,
): Record<string, number> {
  const out: Record<string, number> = {...fallback};
  if (!raw || typeof raw !== "object") return out;
  const o = raw as Record<string, unknown>;
  for (const [k, v] of Object.entries(o)) {
    if (typeof v === "number" && Number.isFinite(v)) {
      out[k] = v;
    }
  }
  return out;
}

/**
 * Parses the current Firestore shape for weather rules.
 * @param {Record<string, unknown>} raw Document fields.
 * @return {WeatherRulesDocument} Normalized rules with defaults filled.
 */
function normalizeRulesFromNewShape(
  raw: Record<string, unknown>,
): WeatherRulesDocument {
  const out: WeatherRulesDocument = {
    hotHumid: {
      thresholds: {...DEFAULT_THRESHOLDS.hotHumid},
      tags: mergeTagBuckets(null, DEFAULT_TAG_POLICY.hotHumid),
    },
    hotDry: {
      thresholds: {...DEFAULT_THRESHOLDS.hotDry},
      tags: mergeTagBuckets(null, DEFAULT_TAG_POLICY.hotDry),
    },
    rainy: {
      thresholds: {...DEFAULT_THRESHOLDS.rainy},
      tags: mergeTagBuckets(null, DEFAULT_TAG_POLICY.rainy),
    },
    cold: {
      thresholds: {...DEFAULT_THRESHOLDS.cold},
      tags: mergeTagBuckets(null, DEFAULT_TAG_POLICY.cold),
    },
    winter: {
      thresholds: {...DEFAULT_THRESHOLDS.winter},
      tags: mergeTagBuckets(null, DEFAULT_TAG_POLICY.winter),
    },
    neutral: {
      thresholds: {...DEFAULT_THRESHOLDS.neutral},
      tags: mergeTagBuckets(null, DEFAULT_TAG_POLICY.neutral),
    },
  };

  for (const key of CATEGORY_KEYS) {
    const cat = raw[key];
    if (!cat || typeof cat !== "object") continue;
    const c = cat as Record<string, unknown>;
    out[key] = {
      thresholds: mergeThresholds(c.thresholds, DEFAULT_THRESHOLDS[key]),
      tags: mergeTagBuckets(c.tags, DEFAULT_TAG_POLICY[key]),
    };
  }

  if (typeof raw.lastUpdated === "string") {
    out.lastUpdated = raw.lastUpdated;
  }
  return out;
}

/**
 * Parses legacy Firestore layout (threshold + policy maps).
 * @param {Record<string, unknown>} raw Document fields.
 * @return {WeatherRulesDocument} Normalized rules with defaults filled.
 */
function normalizeRulesFromLegacyShape(
  raw: Record<string, unknown>,
): WeatherRulesDocument {
  const tempRaw =
    raw.temperature_thresholds &&
    typeof raw.temperature_thresholds === "object" ?
      (raw.temperature_thresholds as Record<string, unknown>) :
      {};
  const policyRaw =
    raw.tag_policies && typeof raw.tag_policies === "object" ?
      (raw.tag_policies as Record<string, unknown>) :
      {};

  return {
    hotHumid: {
      thresholds: {
        minFeelsLike: numOr(
          tempRaw.hotHumidFeelsLike,
          LEGACY_DEFAULT_TEMPERATURE_THRESHOLDS.hotHumidFeelsLike,
        ),
        minTemp: numOr(tempRaw.hot, LEGACY_DEFAULT_TEMPERATURE_THRESHOLDS.hot),
        minHumidity: numOr(
          tempRaw.hotHumidHumidity,
          LEGACY_DEFAULT_TEMPERATURE_THRESHOLDS.hotHumidHumidity,
        ),
        minUvIndex: numOr(
          tempRaw.uvHigh,
          LEGACY_DEFAULT_TEMPERATURE_THRESHOLDS.uvHigh,
        ),
        minTempForUv: numOr(
          tempRaw.uvCompanionTemp,
          LEGACY_DEFAULT_TEMPERATURE_THRESHOLDS.uvCompanionTemp,
        ),
      },
      tags: mergeTagBuckets(policyRaw.hotHumid, DEFAULT_TAG_POLICY.hotHumid),
    },
    hotDry: {
      thresholds: {
        minFeelsLike: numOr(
          tempRaw.hotDryFeelsLike,
          LEGACY_DEFAULT_TEMPERATURE_THRESHOLDS.hotDryFeelsLike,
        ),
        minTemp: numOr(
          tempRaw.hotDryTemp,
          LEGACY_DEFAULT_TEMPERATURE_THRESHOLDS.hotDryTemp,
        ),
        minHumidity: numOr(
          tempRaw.hotDryHumidity,
          LEGACY_DEFAULT_TEMPERATURE_THRESHOLDS.hotDryHumidity,
        ),
      },
      tags: mergeTagBuckets(policyRaw.hotDry, DEFAULT_TAG_POLICY.hotDry),
    },
    rainy: {
      thresholds: {
        minPrecipitation: numOr(
          tempRaw.rainPrecipitationMm,
          LEGACY_DEFAULT_TEMPERATURE_THRESHOLDS.rainPrecipitationMm,
        ),
      },
      tags: mergeTagBuckets(policyRaw.rainy, DEFAULT_TAG_POLICY.rainy),
    },
    cold: {
      thresholds: {
        maxTemp: numOr(
          tempRaw.cold,
          LEGACY_DEFAULT_TEMPERATURE_THRESHOLDS.cold,
        ),
        maxFeelsLike: numOr(
          tempRaw.coldFeelsLike,
          LEGACY_DEFAULT_TEMPERATURE_THRESHOLDS.coldFeelsLike,
        ),
      },
      tags: mergeTagBuckets(policyRaw.cold, DEFAULT_TAG_POLICY.cold),
    },
    winter: {
      thresholds: {},
      tags: mergeTagBuckets(policyRaw.winter, DEFAULT_TAG_POLICY.winter),
    },
    neutral: {
      thresholds: {},
      tags: mergeTagBuckets(policyRaw.neutral, DEFAULT_TAG_POLICY.neutral),
    },
  };
}

/**
 * Loads and normalizes weather rules from a Firestore document.
 * @param {FirebaseFirestore.DocumentData | undefined} data Raw doc data.
 * @return {WeatherRulesDocument} Effective rules for classification.
 */
function parseWeatherRulesFromFirestore(
  data: FirebaseFirestore.DocumentData | undefined,
): WeatherRulesDocument {
  if (!data || typeof data !== "object") {
    return DEFAULT_WEATHER_RULES;
  }
  const raw = data as Record<string, unknown>;

  const hasNewShape = CATEGORY_KEYS.some((k) => {
    const v = raw[k];
    return v && typeof v === "object";
  });
  if (hasNewShape) return normalizeRulesFromNewShape(raw);

  const hasTempObj =
    raw.temperature_thresholds &&
    typeof raw.temperature_thresholds === "object";
  const hasPolicyObj =
    raw.tag_policies && typeof raw.tag_policies === "object";
  const hasLegacyShape = hasTempObj || hasPolicyObj;
  if (hasLegacyShape) return normalizeRulesFromLegacyShape(raw);

  return DEFAULT_WEATHER_RULES;
}

let cachedWeatherRules: WeatherRulesDocument | null = null;
let lastRulesFetchTime = 0;
const CACHE_TTL_MS = 10 * 60 * 1000;

/**
 * Fetches weather rules from Firestore with a short in-memory cache.
 * @return {Promise<WeatherRulesDocument>} Rules or defaults on failure.
 */
async function getDynamicWeatherRules(): Promise<WeatherRulesDocument> {
  const now = Date.now();
  if (cachedWeatherRules && now - lastRulesFetchTime < CACHE_TTL_MS) {
    return cachedWeatherRules;
  }
  try {
    const snap = await admin
      .firestore()
      .collection("system_configs")
      .doc("weather_rules")
      .get();
    if (!snap.exists) {
      cachedWeatherRules = DEFAULT_WEATHER_RULES;
      lastRulesFetchTime = now;
      logger.info("getDynamicWeatherRules: doc missing, using defaults");
      return cachedWeatherRules;
    }
    cachedWeatherRules = parseWeatherRulesFromFirestore(snap.data());
    lastRulesFetchTime = now;
    return cachedWeatherRules;
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    logger.error("getDynamicWeatherRules failed, using defaults", {error: msg});
    return DEFAULT_WEATHER_RULES;
  }
}

/**
 * Classifies weather (mirrors Flutter `classifyWeather`).
 * @param {WeatherSignals} w Signals derived from OpenWeather.
 * @param {WeatherRulesDocument} rules Dynamic thresholds from Firestore.
 * @return {WeatherCategoryKey} Category for tag policy lookup.
 */
function classifyWeather(
  w: WeatherSignals,
  rules: WeatherRulesDocument,
): WeatherCategoryKey {
  const conditionText = w.conditionText.toLowerCase();
  const code = w.conditionCode;

  const hasAny = (tokens: string[]) =>
    tokens.some((t) => conditionText.includes(t));

  const isSnowCode = (c: number) => c >= 600 && c < 700;
  const isRainLikeCode = (c: number) =>
    (c >= 200 && c < 300) || (c >= 300 && c < 400) || (c >= 500 && c < 600);

  const snowByText = hasAny(["snow", "sleet", "blizzard", "ice"]);
  const snowByCode = code != null && isSnowCode(code);
  if (snowByText || snowByCode) {
    return "winter";
  }

  const rainByText = hasAny(["rain", "drizzle", "storm", "thunder"]);
  const rainByCode = code != null && isRainLikeCode(code);
  const rainyThreshold = numOr(
    rules.rainy.thresholds.minPrecipitation,
    DEFAULT_THRESHOLDS.rainy.minPrecipitation,
  );
  if (rainByText || rainByCode || w.precipitation > rainyThreshold) {
    return "rainy";
  }

  const hotHumid = rules.hotHumid.thresholds;
  const hhMinFeels = numOr(
    hotHumid.minFeelsLike,
    DEFAULT_THRESHOLDS.hotHumid.minFeelsLike,
  );
  const hhMinTemp = numOr(
    hotHumid.minTemp,
    DEFAULT_THRESHOLDS.hotHumid.minTemp,
  );
  const hhMinHum = numOr(
    hotHumid.minHumidity,
    DEFAULT_THRESHOLDS.hotHumid.minHumidity,
  );
  const hhMinUv = numOr(
    hotHumid.minUvIndex,
    DEFAULT_THRESHOLDS.hotHumid.minUvIndex,
  );
  const hhMinUvTemp = numOr(
    hotHumid.minTempForUv,
    DEFAULT_THRESHOLDS.hotHumid.minTempForUv,
  );
  const hotHumidByFeel = w.feelsLike >= hhMinFeels;
  const hotHumidByTempHum =
    w.temperature >= hhMinTemp && w.humidity >= hhMinHum;
  const hotHumidByUv = w.uvIndex >= hhMinUv && w.temperature >= hhMinUvTemp;
  if (hotHumidByFeel || hotHumidByTempHum || hotHumidByUv) {
    return "hotHumid";
  }

  const cold = rules.cold.thresholds;
  const coldMaxT = numOr(cold.maxTemp, DEFAULT_THRESHOLDS.cold.maxTemp);
  const coldMaxFeel = numOr(
    cold.maxFeelsLike,
    DEFAULT_THRESHOLDS.cold.maxFeelsLike,
  );
  if (w.temperature <= coldMaxT || w.feelsLike <= coldMaxFeel) {
    return "cold";
  }

  const hotDry = rules.hotDry.thresholds;
  const hdMinFeels = numOr(
    hotDry.minFeelsLike,
    DEFAULT_THRESHOLDS.hotDry.minFeelsLike,
  );
  const hdMinTemp = numOr(hotDry.minTemp, DEFAULT_THRESHOLDS.hotDry.minTemp);
  const hdMinHum = numOr(
    hotDry.minHumidity,
    DEFAULT_THRESHOLDS.hotDry.minHumidity,
  );
  const hotDryByFeel = w.feelsLike >= hdMinFeels;
  const hotDryByTempHum =
    w.temperature >= hdMinTemp && w.humidity >= hdMinHum;
  if (hotDryByFeel || hotDryByTempHum) {
    return "hotDry";
  }

  return "neutral";
}

interface OpenWeatherCurrentJson {
  name?: string;
  sys?: {country?: string};
  coord?: {lat?: number; lon?: number};
  main?: {
    temp?: number;
    feels_like?: number;
    humidity?: number;
  };
  weather?: Array<{id?: number; description?: string}>;
  rain?: Record<string, number>;
  snow?: Record<string, number>;
}

/**
 * Reads 1h precipitation (mm) from OpenWeather rain/snow objects.
 * @param {OpenWeatherCurrentJson} json Parsed API response.
 * @return {number} Millimeters in the last hour.
 */
function readPrecipitation(json: OpenWeatherCurrentJson): number {
  const rain = json.rain;
  const snow = json.snow;
  if (rain && typeof rain["1h"] === "number") {
    return rain["1h"];
  }
  if (snow && typeof snow["1h"] === "number") {
    return snow["1h"];
  }
  return 0;
}

/**
 * Callable: `{ latitude, longitude }` → category + tag roles + UI snapshot.
 */
export const getWeatherContext = onCall(
  {
    region: "asia-southeast1",
    timeoutSeconds: 30,
    memory: "256MiB",
    cors: true,
  },
  async (request) => {
    const apiKey = process.env.OPENWEATHER_API_KEY?.trim() ?? "";
    if (!apiKey) {
      logger.error("OPENWEATHER_API_KEY is not set");
      throw new HttpsError(
        "failed-precondition",
        "Server missing OPENWEATHER_API_KEY " +
          "(functions/.env or deploy env).",
      );
    }

    const rulesDoc = await getDynamicWeatherRules();
    const data = (request.data ?? {}) as Record<string, unknown>;
    const lat = Number(data.latitude);
    const lon = Number(data.longitude);
    if (!Number.isFinite(lat) || !Number.isFinite(lon)) {
      throw new HttpsError(
        "invalid-argument",
        "Provide numeric latitude and longitude.",
      );
    }

    const url = new URL("https://api.openweathermap.org/data/2.5/weather");
    url.searchParams.set("lat", String(lat));
    url.searchParams.set("lon", String(lon));
    url.searchParams.set("appid", apiKey);
    url.searchParams.set("units", "metric");

    let json: OpenWeatherCurrentJson;
    try {
      const res = await fetch(url.toString(), {method: "GET"});
      if (!res.ok) {
        throw new Error(`OpenWeather HTTP ${res.status}`);
      }
      json = (await res.json()) as OpenWeatherCurrentJson;
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      logger.error("OpenWeather request failed", {error: msg});
      throw new HttpsError(
        "unavailable",
        `Weather service failed: ${msg}`,
      );
    }

    const main = json.main ?? {};
    const temperature = Number(main.temp ?? 0);
    const feelsLike = Number(main.feels_like ?? temperature);
    const humidity = Number(main.humidity ?? 0);
    const w0 =
      Array.isArray(json.weather) && json.weather.length > 0 ?
        json.weather[0] :
        {};
    const conditionText = String(w0.description ?? "Unknown");
    const conditionCode = typeof w0.id === "number" ? w0.id : null;
    const uvIndex = 0;
    const precipitation = readPrecipitation(json);

    const category = classifyWeather({
      temperature,
      feelsLike,
      humidity,
      conditionText,
      conditionCode,
      uvIndex,
      precipitation,
    }, rulesDoc);

    const policy = rulesDoc[category].tags;
    const name = String(json.name ?? "");
    const country = json.sys?.country;
    const locationName = name && country ? `${name}, ${country}` : name;

    logger.info("getWeatherContext ok", {category, locationName});

    return {
      category,
      promoted: policy.promoted,
      neutral: policy.neutral,
      suppressed: policy.suppressed,
      locationName,
      temperature,
      feelsLike,
      humidity,
      condition: conditionText,
      conditionCode,
      precipitation,
      uvIndex,
    };
  },
);
