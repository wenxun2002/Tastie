import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:tastie/data/weather_tag_weight.dart';
import 'package:tastie/models/card_data.dart';
import 'package:tastie/models/weather_data.dart';
import 'package:tastie/utils/weather_classifier.dart';

/// Sorts posts based on weather conditions and popularity
///
/// Scoring formula:
/// - Weather score (80%): Based on tag weights matching weather category
/// - Popularity score (20%): Based on like count normalized to 0.0-1.0
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
    final weatherScore = _computeWeatherScore(post, category);
    final popularityScore = _computePopularityScore(post, maxLikes);
    final noise = random.nextDouble() * 0.05; // 0.0 ~ 0.05

    final finalScore = weatherScore * 0.8 + popularityScore * 0.2 + noise;

    // Debug print in debug mode
    if (kDebugMode) {
      debugPrint(
        'Post ${post.id} (${post.content}): '
        'weather=${weatherScore.toStringAsFixed(2)}, '
        'popularity=${popularityScore.toStringAsFixed(2)}, '
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

/// Computes weather-based score for a post
///
/// Sums the weights of all tags in the post that match the weather category.
/// Optionally normalizes by the number of tags.
double _computeWeatherScore(CardData post, WeatherCategory category) {
  final weights = weatherWeights[category] ?? {};
  double sum = 0.0;

  for (final tag in post.tags) {
    final weight = weights[tag] ?? 0.0;
    // Clamp negative weights to 0.0
    sum += weight < 0.0 ? 0.0 : weight;
  }

  // Normalize by number of tags (optional, but helps with fairness)
  if (post.tags.isNotEmpty) {
    sum /= post.tags.length;
  }

  return sum;
}

/// Computes popularity score based on like count
///
/// Normalizes like count to 0.0-1.0 range based on the maximum likes in the dataset.
double _computePopularityScore(CardData post, int maxLikes) {
  if (maxLikes <= 0) return 0.0;
  return post.like / maxLikes; // 0.0 ~ 1.0
}

