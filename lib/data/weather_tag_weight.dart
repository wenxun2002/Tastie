import 'dart:convert';
import 'package:flutter/services.dart';

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

/// WeatherCategory → (tagName → weight)
///
/// Weight mapping for food tags based on weather conditions.
///
/// Weight range: [0.0, 1.0]
/// - 1.0 = very strong priority for this tag under that weather condition
/// - 0.0 or missing = no preference
/// - Negative values can be used to indicate avoidance (will be clamped to 0.0 if needed)
///
/// This is loaded dynamically from JSON on app start.
/// For Firebase integration, replace WeatherWeightRepository.load() with Firebase loader.
late Map<WeatherCategory, Map<String, double>> weatherWeights;

/// Repository for loading weather tag weights from JSON
///
/// This mimics a future Firebase schema structure.
/// To integrate with Firebase, replace the load() method to fetch from Firebase instead.
class WeatherWeightRepository {
  /// Load weather weights from JSON file
  ///
  /// Returns a map of WeatherCategory to tag weights.
  /// Throws an exception if the JSON file cannot be loaded or parsed.
  Future<Map<WeatherCategory, Map<String, double>>> load() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/config/weather_tag_weight.json',
      );
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      final Map<WeatherCategory, Map<String, double>> result = {};

      for (final entry in jsonData.entries) {
        final category = parseCategory(entry.key);
        final tagWeights = <String, double>{};

        if (entry.value is Map) {
          final tagMap = entry.value as Map<String, dynamic>;
          for (final tagEntry in tagMap.entries) {
            tagWeights[tagEntry.key] = (tagEntry.value as num).toDouble();
          }
        }

        result[category] = tagWeights;
      }

      return result;
    } catch (e) {
      throw Exception('Failed to load weather tag weights: $e');
    }
  }
}

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
double getTagWeight({required WeatherCategory weather, required String tag}) {
  final weights = weatherWeights[weather];
  if (weights == null) return 0.0;
  return weights[tag] ?? 0.0;
}
