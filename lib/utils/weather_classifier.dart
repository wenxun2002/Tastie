import 'package:tastie/data/weather_tag_weight.dart';
import 'package:tastie/models/weather_data.dart';

/// Classifies WeatherData into a WeatherCategory based on simple rules
///
/// Rules (in order of priority):
/// 1. If condition is "Rain" → WeatherCategory.rainy
/// 2. If condition is "Thunderstorm" → WeatherCategory.stormy
/// 3. If temperature < 20°C → WeatherCategory.cold
/// 4. If temperature > 30°C && humidity > 70% → WeatherCategory.hotHumid
/// 5. If temperature > 30°C && humidity < 50% → WeatherCategory.hotDry
/// 6. Otherwise → WeatherCategory.neutral
WeatherCategory classifyWeather(WeatherData w) {
  // Check condition first (highest priority)
  if (w.condition == "Rain") {
    return WeatherCategory.rainy;
  }

  if (w.condition == "Thunderstorm") {
    return WeatherCategory.stormy;
  }

  // Check temperature thresholds
  if (w.temperature < 20) {
    return WeatherCategory.cold;
  }

  if (w.temperature > 30) {
    if (w.humidity > 70) {
      return WeatherCategory.hotHumid;
    } else if (w.humidity < 50) {
      return WeatherCategory.hotDry;
    }
  }

  // Default to neutral
  return WeatherCategory.neutral;
}

