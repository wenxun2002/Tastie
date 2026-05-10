/// Whether [recipeTags] intersects the weather **promoted** tag list for analytics.
///
/// Uses case-insensitive trim matching so `cooling` matches `Cooling`.
bool recipeTagsIntersectPromotedTags(
  List<String> recipeTags,
  List<String> promotedTags,
) {
  if (promotedTags.isEmpty) return false;
  final promoted = promotedTags
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet();
  if (promoted.isEmpty) return false;
  for (final t in recipeTags) {
    final key = t.trim().toLowerCase();
    if (key.isEmpty) continue;
    if (promoted.contains(key)) return true;
  }
  return false;
}
