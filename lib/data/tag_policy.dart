/// Tag Policy for C-Model Weather-Aware Scoring
///
/// Defines semantic roles (promoted/neutral/suppressed) for tags
/// under different weather conditions, replacing fixed numeric weights.
library tag_policy;

import 'package:tastie/data/weather_category.dart';

/// Tag policy structure: defines which tags are promoted, neutral, or suppressed
/// for a given weather category
class TagPolicy {
  final List<String> promoted; // Strongly encouraged in this weather
  final List<String> neutral; // Acceptable but not emphasized
  final List<String> suppressed; // Contextually unsuitable, diluted

  const TagPolicy({
    required this.promoted,
    required this.neutral,
    required this.suppressed,
  });
}

/// State → Tag Policy mapping (C-Model)
///
/// Each weather state defines which tags are promoted, neutral, or suppressed.
/// This replaces the old numeric weight system with semantic classification.
///
/// This is exported for use by TagPolicyRepository.
/// In the future, this can be loaded from backend API instead.
final Map<WeatherCategory, TagPolicy> statePolicy = {
  WeatherCategory.hotHumid: const TagPolicy(
    promoted: ['Cooling', 'Hydrating', 'Light'],
    neutral: ['Comfort'],
    suppressed: ['Energy', 'Warming'],
  ),
  WeatherCategory.hotDry: const TagPolicy(
    promoted: ['Cooling', 'Hydrating'],
    neutral: ['Comfort', 'Light'],
    suppressed: ['Energy', 'Warming'],
  ),
  WeatherCategory.rainy: const TagPolicy(
    promoted: ['Comfort', 'Warming'],
    neutral: ['Energy', 'Light'],
    suppressed: ['Cooling', 'Hydrating'],
  ),
  WeatherCategory.cold: const TagPolicy(
    promoted: ['Energy', 'Warming', 'Comfort'],
    neutral: ['Light'],
    suppressed: ['Cooling', 'Hydrating'],
  ),
  WeatherCategory.winter: const TagPolicy(
    promoted: ['Warming', 'Comfort', 'Energy'],
    neutral: ['Light'],
    suppressed: ['Cooling', 'Hydrating'],
  ),
  WeatherCategory.neutral: const TagPolicy(
    promoted: [],
    neutral: ['Cooling', 'Hydrating', 'Light', 'Energy', 'Warming', 'Comfort'],
    suppressed: [],
  ),
};

/// Get the tag policy for a given weather category
TagPolicy getTagPolicy(WeatherCategory category) {
  return statePolicy[category] ??
      const TagPolicy(promoted: [], neutral: [], suppressed: []);
}
