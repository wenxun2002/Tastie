class SearchCriteria {
  final String query;
  final List<String> selectedIngredients;
  final List<String> selectedTags;
  final bool isCalorieFilterEnabled;
  final int calorieMin;
  final int calorieMax;
  final bool includeHighCalorieMeals;

  const SearchCriteria({
    required this.query,
    required this.selectedIngredients,
    required this.selectedTags,
    required this.isCalorieFilterEnabled,
    required this.calorieMin,
    required this.calorieMax,
    required this.includeHighCalorieMeals,
  });

  factory SearchCriteria.initial() {
    return const SearchCriteria(
      query: '',
      selectedIngredients: <String>[],
      selectedTags: <String>[],
      isCalorieFilterEnabled: false,
      calorieMin: 200,
      calorieMax: 600,
      includeHighCalorieMeals: false,
    );
  }

  SearchCriteria copyWith({
    String? query,
    List<String>? selectedIngredients,
    List<String>? selectedTags,
    bool? isCalorieFilterEnabled,
    int? calorieMin,
    int? calorieMax,
    bool? includeHighCalorieMeals,
  }) {
    return SearchCriteria(
      query: query ?? this.query,
      selectedIngredients: selectedIngredients ?? this.selectedIngredients,
      selectedTags: selectedTags ?? this.selectedTags,
      isCalorieFilterEnabled: isCalorieFilterEnabled ?? this.isCalorieFilterEnabled,
      calorieMin: calorieMin ?? this.calorieMin,
      calorieMax: calorieMax ?? this.calorieMax,
      includeHighCalorieMeals: includeHighCalorieMeals ?? this.includeHighCalorieMeals,
    );
  }

  bool get hasIngredientOrTagCriteria =>
      selectedIngredients.isNotEmpty || selectedTags.isNotEmpty;

  String get summaryText {
    if (query.trim().isNotEmpty) return query.trim();

    final chips = <String>[...selectedIngredients, ...selectedTags];
    if (chips.isNotEmpty) {
      return chips.join(', ');
    }

    if (isCalorieFilterEnabled) {
      return '$calorieMin-$calorieMax kcal';
    }

    return 'Search something...';
  }
}

class RecipeSearchScore {
  final int ingredientMatches;
  final int tagMatches;
  final int titleQueryMatches;
  final int contentQueryMatches;

  const RecipeSearchScore({
    required this.ingredientMatches,
    required this.tagMatches,
    required this.titleQueryMatches,
    required this.contentQueryMatches,
  });

  int get totalScore =>
      ingredientMatches * 2 + tagMatches + titleQueryMatches * 2 + contentQueryMatches;

  bool get hasAnyMatch =>
      ingredientMatches > 0 || tagMatches > 0 || titleQueryMatches > 0 || contentQueryMatches > 0;
}

bool shouldIncludeRecipeByCalories({
  required int calories,
  required SearchCriteria criteria,
}) {
  if (!criteria.isCalorieFilterEnabled) {
    return true;
  }

  if (calories >= criteria.calorieMin && calories <= criteria.calorieMax) {
    return true;
  }

  if (criteria.includeHighCalorieMeals && calories > 1000) {
    return true;
  }

  return false;
}

RecipeSearchScore scoreRecipe({
  required SearchCriteria criteria,
  required String title,
  required String content,
  required List<String> tags,
  required List<String> ingredientNames,
}) {
  final normalizedTags = tags.map((e) => e.toLowerCase()).toList(growable: false);
  final normalizedIngredients =
      ingredientNames.map((e) => e.toLowerCase()).toList(growable: false);

  int ingredientMatches = 0;
  for (final selected in criteria.selectedIngredients) {
    final key = selected.toLowerCase();
    final matched = normalizedIngredients.any((item) => item.contains(key));
    if (matched) ingredientMatches++;
  }

  int tagMatches = 0;
  for (final selected in criteria.selectedTags) {
    final key = selected.toLowerCase().replaceAll('#', '');
    final matched =
        normalizedTags.any((item) => item.toLowerCase().replaceAll('#', '').contains(key));
    if (matched) tagMatches++;
  }

  int titleQueryMatches = 0;
  int contentQueryMatches = 0;
  final query = criteria.query.trim().toLowerCase();
  if (query.isNotEmpty) {
    if (title.toLowerCase().contains(query)) titleQueryMatches = 1;
    if (content.toLowerCase().contains(query)) contentQueryMatches = 1;
  }

  return RecipeSearchScore(
    ingredientMatches: ingredientMatches,
    tagMatches: tagMatches,
    titleQueryMatches: titleQueryMatches,
    contentQueryMatches: contentQueryMatches,
  );
}
