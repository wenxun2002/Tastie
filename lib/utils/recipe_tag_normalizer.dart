/// Canonical recipe mood tags (must match [assets/mock/tag_list.json] labels).
///
/// Firestore `arrayContainsAny` is case-sensitive; normalize on write.
class RecipeTagNormalizer {
  RecipeTagNormalizer._();

  static const List<String> canonicalLabels = [
    'Comfort',
    'Cooling',
    'Hydrating',
    'Light',
    'Energy',
    'Warming',
  ];

  static final Map<String, String> _byLowerCase = {
    for (final label in canonicalLabels) label.toLowerCase(): label,
  };

  /// Maps known tags to canonical spelling; trims; dedupes; preserves order.
  static List<String> normalize(Iterable<String> tags) {
    final seen = <String>{};
    final out = <String>[];

    for (final raw in tags) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;

      final canonical = _byLowerCase[trimmed.toLowerCase()] ?? trimmed;
      if (seen.add(canonical)) {
        out.add(canonical);
      }
    }

    return out;
  }
}
