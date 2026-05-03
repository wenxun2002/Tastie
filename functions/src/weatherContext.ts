/**
 * BFF: OpenWeather + classifyWeather + TagPolicy
 * (mirrors Flutter weather_classifier and tag_policy.dart).
 * Set OPENWEATHER_API_KEY in functions/.env (or deploy env).
 */

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

const TAG_POLICY: Record<WeatherCategoryKey, TagBuckets> = {
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
 * Classifies weather (mirrors Flutter `classifyWeather`).
 * @param {WeatherSignals} w Signals derived from OpenWeather.
 * @return {WeatherCategoryKey} Category for tag policy lookup.
 */
function classifyWeather(w: WeatherSignals): WeatherCategoryKey {
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
  if (rainByText || rainByCode || w.precipitation > 0.5) {
    return "rainy";
  }

  if (
    w.feelsLike >= 38 ||
    (w.temperature >= 33 && w.humidity >= 70) ||
    (w.uvIndex >= 8 && w.temperature >= 30)
  ) {
    return "hotHumid";
  }

  if (w.temperature <= 26 || w.feelsLike <= 27) {
    return "cold";
  }

  if (w.feelsLike >= 32 || (w.temperature >= 28 && w.humidity >= 60)) {
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
    });

    const policy = TAG_POLICY[category];
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
