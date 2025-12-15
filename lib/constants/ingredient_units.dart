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

  static const List<String> allUnits = [...normalUnits, ...specialUnits];
}
