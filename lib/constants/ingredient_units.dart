class IngredientUnits {
  const IngredientUnits._();

  // Special units imply quantityType = "special" and amount = null.
  static const List<String> specialUnits = [
    'a few drops',
    'a pinch',
    'to taste',
    'as needed',
    'handful',
  ];

  // Normal measurable units.
  static const List<String> normalUnits = ['g', 'kg', 'ml', 'l'];

  // Discrete / kitchen units for countable or portion-based ingredients.
  static const List<String> countableUnits = [
    'piece',
    'slice',
    'whole',
    'clove',
    'tbsp',
    'tsp',
    'cup',
  ];

  static const List<String> allUnits = [
    ...normalUnits,
    ...countableUnits,
    ...specialUnits,
  ];
}
