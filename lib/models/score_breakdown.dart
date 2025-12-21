/// Score Breakdown for explainability and debugging
///
/// Provides detailed information about how a post's score was calculated,
/// useful for demos, debugging, and justifying behavior during presentation.
class ScoreBreakdown {
  final double contextScore;
  final double popularityScore;
  final double finalScore;
  final String appliedWeatherState;
  final List<String> promotedTagsHit;
  final List<String> suppressedTagsHit;
  final List<String> neutralTagsHit;

  const ScoreBreakdown({
    required this.contextScore,
    required this.popularityScore,
    required this.finalScore,
    required this.appliedWeatherState,
    required this.promotedTagsHit,
    required this.suppressedTagsHit,
    required this.neutralTagsHit,
  });

  /// Convert to a readable string for debugging
  @override
  String toString() {
    return 'ScoreBreakdown(\n'
        '  contextScore: ${contextScore.toStringAsFixed(3)},\n'
        '  popularityScore: ${popularityScore.toStringAsFixed(3)},\n'
        '  finalScore: ${finalScore.toStringAsFixed(3)},\n'
        '  weatherState: $appliedWeatherState,\n'
        '  promotedTags: $promotedTagsHit,\n'
        '  neutralTags: $neutralTagsHit,\n'
        '  suppressedTags: $suppressedTagsHit,\n'
        ')';
  }
}

