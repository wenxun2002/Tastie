/// Weather Category Enum and Utilities
///
/// Represents different weather conditions that affect food recommendations.
/// This is a shared enum used across the app for weather classification.

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

  /// Winter: Snowy/freezing conditions (temperature < 0°C)
  winter,
}

/// Parse a string key to WeatherCategory enum
///
/// Returns the corresponding WeatherCategory, or throws an exception if the key is invalid.
WeatherCategory parseCategory(String key) {
  switch (key) {
    case 'hotHumid':
      return WeatherCategory.hotHumid;
    case 'hotDry':
      return WeatherCategory.hotDry;
    case 'rainy':
      return WeatherCategory.rainy;
    case 'cold':
      return WeatherCategory.cold;
    case 'neutral':
      return WeatherCategory.neutral;
    case 'winter':
      return WeatherCategory.winter;
    default:
      throw ArgumentError('Invalid weather category key: $key');
  }
}
