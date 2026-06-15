import 'package:tastie/data/weather_category.dart';
import 'package:tastie/models/weather_data.dart';

/// weather classifier
///
/// Input signals:
/// - w.temperature (°C)
/// - w.feelsLike (°C)
/// - w.humidity (%)
/// - w.condition (condition_text)
/// - w.conditionCode (OpenWeather weather[id])
/// - w.uvIndex
/// - w.precipitation (mm/h)
///
/// Priority (waterfall):
/// 1. Snowy / Winter    →  WeatherCategory.winter  (winter category, mainly used for countries with snow)
/// 2. Rainy / Gloomy    →  WeatherCategory.rainy
/// 3. Extreme Heat      →  WeatherCategory.hotHumid
/// 4. Cold / Chilly     →  WeatherCategory.cold
/// 5. Hot & dry         →  WeatherCategory.hotDry
/// 6. Mild / Neutral    →  WeatherCategory.neutral
///
/// Tag Policy configuration is managed by C-Model system (see `data/tag_policy.dart`).
WeatherCategory classifyWeather(WeatherData w) {
  final String conditionText = w.condition.toLowerCase();
  final int? code = w.conditionCode;

  bool hasAny(Iterable<String> tokens) =>
      tokens.any((t) => conditionText.contains(t));

  // OpenWeather code description (simplified):
  // 2xx: Thunderstorm, 3xx: Drizzle, 5xx: Rain, 6xx: Snow
  bool isSnowCode(int c) => c >= 600 && c < 700;
  bool isRainLikeCode(int c) =>
      (c >= 200 && c < 300) || (c >= 300 && c < 400) || (c >= 500 && c < 600);

  // Priority 1: Snowy / Winter (global compatibility, mapped to WeatherCategory.winter weight)
  final bool snowByText = hasAny(['snow', 'sleet', 'blizzard', 'ice']);
  final bool snowByCode = code != null && isSnowCode(code);
  if (snowByText || snowByCode) {
    return WeatherCategory.winter;
  }

  // Priority 2: Rainy / Gloomy (psychological focus on rainy weather)
  final bool rainByText = hasAny(['rain', 'drizzle', 'storm', 'thunder']);
  final bool rainByCode = code != null && isRainLikeCode(code);
  if (rainByText || rainByCode || w.precipitation > 0.5) {
    return WeatherCategory.rainy;
  }

  // Priority 3: Extreme Heat (Hot & humid) - Heat stress
  if (w.feelsLike >= 38 ||
      (w.temperature >= 33 && w.humidity >= 70) ||
      (w.uvIndex >= 8 && w.temperature >= 30)) {
    return WeatherCategory.hotHumid;
  }

  // Priority 4: Cold / Chilly (air conditioning feeling)
  if (w.temperature <= 26 || w.feelsLike <= 27) {
    return WeatherCategory.cold;
  }

  // Priority 5: Hot & dry / Standard tropical heat (standard tropical heat)
  if (w.feelsLike >= 32 || (w.temperature >= 28 && w.humidity >= 60)) {
    return WeatherCategory.hotDry;
  }

  // Default: Mild / Neutral (neutral weather)
  return WeatherCategory.neutral;
}
