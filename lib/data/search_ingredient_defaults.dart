/// Offline fallback when Firestore `Search_ingredient` is empty or unreachable.
const List<String> kFallbackSearchIngredientNames = [
  'Potato',
  'Corn',
  'Cheese',
  'Tomato',
  'Black Pepper',
  'Onion',
  'Garlic',
  'Broccoli',
  'Chicken Breast',
  'Eggs',
  'Salt',
  'Olive Oil',
  'Rice',
  'Pasta',
  'Chili',
  'Butter',
  'Sugar',
  'Salmon',
  'Shrimp',
  'Carrot',
  'Mushroom',
  'Banana',
  'Avocado',
  'Basil',
  'Ginger',
  'Yogurt',
  'Bread',
  'Soy Sauce',
  'Vinegar',
  'Mayonnaise',
];

int compareIngredientNames(String a, String b) {
  return a.toLowerCase().compareTo(b.toLowerCase());
}
