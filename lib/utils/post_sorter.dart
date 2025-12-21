import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:tastie/data/tag_policy.dart';
import 'package:tastie/data/weather_category.dart';
import 'package:tastie/constants/scoring_config.dart' as scoring_config;
import 'package:tastie/models/card_data.dart';
import 'package:tastie/models/weather_data.dart';
import 'package:tastie/models/score_breakdown.dart';
import 'package:tastie/utils/weather_classifier.dart';

/// Sorts posts based on weather conditions and popularity using C-Model
///
/// C-Model Scoring formula:
/// - Context score (80% default, 40% for neutral): Based on tag policy (promoted/neutral/suppressed)
/// - Popularity score (20% default, 60% for neutral): Based on like count normalized to 0.0-1.0
/// - Random noise (0-5%): Small random value to avoid ties
///
/// Returns a new sorted list (does not modify the original)
List<CardData> sortPostsByWeather({
  required List<CardData> posts,
  required WeatherData weather,
}) {
  if (posts.isEmpty) return [];

  // Classify weather
  final category = classifyWeather(weather);

  // Find max likes for normalization
  final maxLikes = posts.map((p) => p.like).reduce(max);

  // Random generator for noise
  final random = Random();

  // Score each post
  final scored = posts.map((post) {
    final contextScore = _computeContextScore(post, category);
    final popularityScore = _computePopularityScore(post, maxLikes);
    final noise = random.nextDouble() * scoring_config.noiseMax;

    final finalScore = _computeFinalScore(
      contextScore: contextScore,
      popularityScore: popularityScore,
      weatherState: category,
      noise: noise,
    );

    // Debug print in debug mode
    if (kDebugMode) {
      debugPrint(
        'Post ${post.id} (${post.content}): '
        'context=${contextScore.toStringAsFixed(3)}, '
        'popularity=${popularityScore.toStringAsFixed(3)}, '
        'noise=${noise.toStringAsFixed(3)}, '
        'final=${finalScore.toStringAsFixed(3)}',
      );
    }

    return (post: post, score: finalScore);
  }).toList();

  // Sort by score (descending)
  scored.sort((a, b) => b.score.compareTo(a.score));

  return scored.map((e) => e.post).toList();
}

/// Compute context score using C-Model (Anti "Select-All-Tags")
///
/// Tags are classified into three roles per weather state:
/// - Promoted: Strongly encouraged (multiplier: 1.0)
/// - Neutral: Acceptable but not emphasized (multiplier: 0.4)
/// - Suppressed: Contextually unsuitable (multiplier: 0.1)
///
/// The score is normalized by tag count to prevent "select all tags" abuse.
double _computeContextScore(CardData post, WeatherCategory category) {
  final policy = getTagPolicy(category);

  if (post.tags.isEmpty) return 0.0;

  double sum = 0.0;

  for (final tag in post.tags) {
    if (policy.promoted.contains(tag)) {
      sum += scoring_config.promotedMultiplier;
    } else if (policy.suppressed.contains(tag)) {
      sum += scoring_config.suppressMultiplier;
    } else {
      // Neutral or unknown tag
      sum += scoring_config.neutralMultiplier;
    }
  }

  // Anti "select all tags": normalize by tag count
  double score = sum / post.tags.length;

  // Clamp to [0, 1]
  return score.clamp(0.0, 1.0);
}

/// Compute final score with dynamic weights based on weather state
///
/// Special case: When weather is neutral, context weight is reduced to 0.4
/// and popularity weight is increased to 0.6, reflecting weaker contextual
/// relevance and stronger social influence.
double _computeFinalScore({
  required double contextScore,
  required double popularityScore,
  required WeatherCategory weatherState,
  required double noise,
}) {
  double contextWeight = scoring_config.defaultContextWeight;
  double popularityWeight = scoring_config.defaultPopularityWeight;

  // Special case: Neutral weather state
  if (weatherState == WeatherCategory.neutral) {
    contextWeight = scoring_config.neutralContextWeight;
    popularityWeight = scoring_config.neutralPopularityWeight;
  }

  return contextScore * contextWeight +
      popularityScore * popularityWeight +
      noise;
}

/// Computes popularity score based on like count
///
/// Normalizes like count to 0.0-1.0 range based on the maximum likes in the dataset.
double _computePopularityScore(CardData post, int maxLikes) {
  if (maxLikes <= 0) return 0.0;
  return post.like / maxLikes; // 0.0 ~ 1.0
}

/// Compute detailed score breakdown for explainability (optional)
///
/// Useful for demos, debugging, and justifying behavior during presentation.
ScoreBreakdown computeScoreBreakdown({
  required CardData post,
  required WeatherCategory category,
  required int maxLikes,
  required double noise,
}) {
  final policy = getTagPolicy(category);
  final contextScore = _computeContextScore(post, category);
  final popularityScore = _computePopularityScore(post, maxLikes);
  final finalScore = _computeFinalScore(
    contextScore: contextScore,
    popularityScore: popularityScore,
    weatherState: category,
    noise: noise,
  );

  // Track which tags were hit in each category
  final promotedTagsHit = <String>[];
  final suppressedTagsHit = <String>[];
  final neutralTagsHit = <String>[];

  for (final tag in post.tags) {
    if (policy.promoted.contains(tag)) {
      promotedTagsHit.add(tag);
    } else if (policy.suppressed.contains(tag)) {
      suppressedTagsHit.add(tag);
    } else {
      neutralTagsHit.add(tag);
    }
  }

  return ScoreBreakdown(
    contextScore: contextScore,
    popularityScore: popularityScore,
    finalScore: finalScore,
    appliedWeatherState: category.toString().split('.').last,
    promotedTagsHit: promotedTagsHit,
    suppressedTagsHit: suppressedTagsHit,
    neutralTagsHit: neutralTagsHit,
  );
}
