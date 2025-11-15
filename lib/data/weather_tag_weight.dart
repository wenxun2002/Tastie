/// Weather category enum
///
/// Represents different weather conditions that affect food recommendations
enum WeatherCategory {
  /// Hot & Humid: High temperature (≥32°C) with high humidity (≥80%)
  hotHumid,

  /// Hot but Dry: High temperature (>33°C) with low humidity (<40%)
  hotDry,

  /// Rainy: Rainy conditions with high humidity (≥85%) and precipitation >10mm/h
  rainy,

  /// Cold: Low temperature (<20°C) with cloudy conditions
  cold,

  /// Neutral: Normal/comfortable weather (27-29°C, humidity 50-65%)
  neutral,

  /// Stormy: Thunderstorm with very high precipitation (>30mm/h) and humidity (≥90%)
  stormy,
}

/// WeatherCategory → (tagName → weight)
///
/// Weight mapping for food tags based on weather conditions.
///
/// Weight range: [0.0, 1.0]
/// - 1.0 = very strong priority for this tag under that weather condition
/// - 0.0 or missing = no preference
/// - Negative values can be used to indicate avoidance (will be clamped to 0.0 if needed)
const Map<WeatherCategory, Map<String, double>> kWeatherTagWeight = {
  // Hot & Humid Weather
  // High temperature with high humidity - prefer cooling, hydrating, and light foods
  WeatherCategory.hotHumid: {
    'Cooling': 1.0,
    'Hydrating': 0.9,
    'Light': 0.7,
    'Energy': 0.1,
    'Warming': -0.3, // Negative indicates avoidance
    'Comfort': 0.2,
  },

  // Hot but Dry Weather
  // High temperature with low humidity - hydrating is most important
  WeatherCategory.hotDry: {
    'Cooling': 0.7,
    'Hydrating': 1.0,
    'Light': 0.6,
    'Energy': 0.2,
    'Warming': 0.0,
    'Comfort': 0.2,
  },

  // Rainy Weather
  // Rainy, slightly cooler, high humidity - prefer warming and comfort foods
  WeatherCategory.rainy: {
    'Cooling': 0.1,
    'Hydrating': 0.3,
    'Light': 0.4,
    'Energy': 0.6,
    'Warming': 1.0,
    'Comfort': 0.9,
  },

  // Cold Weather
  // Low temperature - prefer warming and energy foods
  WeatherCategory.cold: {
    'Cooling': 0.0,
    'Hydrating': 0.2,
    'Light': 0.3,
    'Energy': 1.0,
    'Warming': 1.0,
    'Comfort': 0.7,
  },

  // Neutral Weather
  // Normal/comfortable weather - balanced mix, all tags have medium priority
  WeatherCategory.neutral: {
    'Cooling': 0.5,
    'Hydrating': 0.5,
    'Light': 0.5,
    'Energy': 0.5,
    'Warming': 0.5,
    'Comfort': 0.5,
  },

  // Stormy Weather
  // Thunderstorm/very heavy rain - comfort and warming are strongly preferred
  WeatherCategory.stormy: {
    'Cooling': 0.0,
    'Hydrating': 0.3,
    'Light': 0.3,
    'Energy': 0.6,
    'Warming': 1.0,
    'Comfort': 1.0,
  },
};

/// Get the weight for a specific tag under a given weather category
///
/// Returns the weight value for the tag, or 0.0 if:
/// - The weather category is not found in the map
/// - The tag is not found for that weather category
///
/// Negative weights are returned as-is (can be clamped to 0.0 in sorting logic if needed)
///
/// Example:
/// ```dart
/// final weight = getTagWeight(
///   weather: WeatherCategory.hotHumid,
///   tag: 'Cooling',
/// );
/// // Returns: 1.0
/// ```
double getTagWeight({
  required WeatherCategory weather,
  required String tag,
}) {
  final weights = kWeatherTagWeight[weather];
  if (weights == null) return 0.0;
  return weights[tag] ?? 0.0;
}
