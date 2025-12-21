import 'package:tastie/data/weather_category.dart';
import 'package:tastie/models/weather_data.dart';

/// 新版天气分类逻辑（用于 FYP 报告）
///
/// 输入信号：
/// - w.temperature (°C)
/// - w.feelsLike (°C)
/// - w.humidity (%)
/// - w.condition (condition_text)
/// - w.conditionCode (OpenWeather weather[id])
/// - w.uvIndex
/// - w.precipitation (mm/h)
///
/// 优先级（waterfall）：
/// 1. Snowy / Winter    →  WeatherCategory.winter  （"冬天"类，主要给有雪国家用）
/// 2. Rainy / Gloomy    →  WeatherCategory.rainy
/// 3. Extreme Heat      →  WeatherCategory.hotHumid
/// 4. Cold / Chilly     →  WeatherCategory.cold
/// 5. Hot & dry         →  WeatherCategory.hotDry
/// 6. Mild / Neutral    →  WeatherCategory.neutral
///
/// Tag Policy 配置由 C-Model 系统管理（见 `data/tag_policy.dart`）。
WeatherCategory classifyWeather(WeatherData w) {
  final String conditionText = w.condition.toLowerCase();
  final int? code = w.conditionCode;

  bool hasAny(Iterable<String> tokens) =>
      tokens.any((t) => conditionText.contains(t));

  // OpenWeather code 说明（简化版）:
  // 2xx: Thunderstorm, 3xx: Drizzle, 5xx: Rain, 6xx: Snow
  bool isSnowCode(int c) => c >= 600 && c < 700;
  bool isRainLikeCode(int c) =>
      (c >= 200 && c < 300) || (c >= 300 && c < 400) || (c >= 500 && c < 600);

  // Priority 1: Snowy / Winter （全局兼容，映射到 WeatherCategory.stormy = “冬天”权重）
  final bool snowByText = hasAny(['snow', 'sleet', 'blizzard', 'ice']);
  final bool snowByCode = code != null && isSnowCode(code);
  if (snowByText || snowByCode) {
    return WeatherCategory.winter;
  }

  // Priority 2: Rainy / Gloomy (psychological focus)
  final bool rainByText = hasAny(['rain', 'drizzle', 'storm', 'thunder']);
  final bool rainByCode = code != null && isRainLikeCode(code);
  if (rainByText || rainByCode || w.precipitation > 0.5) {
    return WeatherCategory.rainy;
  }

  // Priority 3: Extreme Heat (Hot & humid) - Heat Stress
  if (w.feelsLike >= 38 ||
      (w.temperature >= 33 && w.humidity >= 70) ||
      (w.uvIndex >= 8 && w.temperature >= 30)) {
    return WeatherCategory.hotHumid;
  }

  // Priority 4: Cold / Chilly（马来西亚语境，空调感）
  if (w.temperature <= 26 || w.feelsLike <= 27) {
    return WeatherCategory.cold;
  }

  // Priority 5: Hot & dry / Standard tropical heat
  if (w.feelsLike >= 32 || (w.temperature >= 28 && w.humidity >= 60)) {
    return WeatherCategory.hotDry;
  }

  // Default: Mild / Neutral
  return WeatherCategory.neutral;
}
