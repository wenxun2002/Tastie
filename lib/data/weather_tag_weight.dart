// ============================================================================
// DEPRECATED: Old Weight-Based Scoring System
// ============================================================================
//
// This file contains the OLD scoring system that used fixed numeric weights.
// It has been replaced by the C-Model system (see tag_policy.dart).
//
// ⚠️  This code is kept for reference but is NO LONGER USED.
//     The new C-Model system uses semantic tag policies (promoted/neutral/suppressed)
//     instead of numeric weights.
//
// Migration Notes:
// - Old: { Cooling: 0.9, Hydrating: 1.0 } (numeric weights)
// - New: promoted: ['Cooling', 'Hydrating'] (semantic classification)
//
// If you need to reference the old implementation, see git history.
// ============================================================================

// import 'dart:convert';
// import 'package:flutter/services.dart';
// import 'package:tastie/data/weather_category.dart';
//
// /// WeatherCategory → (tagName → weight)
// ///
// /// Weight mapping for food tags based on weather conditions.
// ///
// /// Weight range: [0.0, 1.0]
// /// - 1.0 = very strong priority for this tag under that weather condition
// /// - 0.0 or missing = no preference
// /// - Negative values can be used to indicate avoidance (will be clamped to 0.0 if needed)
// ///
// /// This is loaded dynamically from JSON on app start.
// /// For Firebase integration, replace WeatherWeightRepository.load() with Firebase loader.
// late Map<WeatherCategory, Map<String, double>> weatherWeights;
//
// /// Repository for loading weather tag weights from JSON
// ///
// /// This mimics a future Firebase schema structure.
// /// To integrate with Firebase, replace the load() method to fetch from Firebase instead.
// class WeatherWeightRepository {
//   /// Load weather weights from JSON file
//   ///
//   /// Returns a map of WeatherCategory to tag weights.
//   /// Throws an exception if the JSON file cannot be loaded or parsed.
//   Future<Map<WeatherCategory, Map<String, double>>> load() async {
//     try {
//       final String jsonString = await rootBundle.loadString(
//         'assets/config/weather_tag_weight.json',
//       );
//       final Map<String, dynamic> jsonData = json.decode(jsonString);
//
//       final Map<WeatherCategory, Map<String, double>> result = {};
//
//       for (final entry in jsonData.entries) {
//         final category = parseCategory(entry.key);
//         final tagWeights = <String, double>{};
//
//         if (entry.value is Map) {
//           final tagMap = entry.value as Map<String, dynamic>;
//           for (final tagEntry in tagMap.entries) {
//             tagWeights[tagEntry.key] = (tagEntry.value as num).toDouble();
//           }
//         }
//
//         result[category] = tagWeights;
//       }
//
//       return result;
//     } catch (e) {
//       throw Exception('Failed to load weather tag weights: $e');
//     }
//   }
// }
//
// /// Get the weight for a specific tag under a given weather category
// ///
// /// Returns the weight value for the tag, or 0.0 if:
// /// - The weather category is not found in the map
// /// - The tag is not found for that weather category
// ///
// /// Negative weights are returned as-is (can be clamped to 0.0 in sorting logic if needed)
// ///
// /// Example:
// /// ```dart
// /// final weight = getTagWeight(
// ///   weather: WeatherCategory.hotHumid,
// ///   tag: 'Cooling',
// /// );
// /// // Returns: 1.0
// /// ```
// double getTagWeight({required WeatherCategory weather, required String tag}) {
//   final weights = weatherWeights[weather];
//   if (weights == null) return 0.0;
//   return weights[tag] ?? 0.0;
// }
