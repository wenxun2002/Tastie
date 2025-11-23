class CreatePostData {
  CreatePostData({
    this.photos = const [],
    this.title = '',
    this.content = '',
    this.tags = const [],
    this.ingredients = const [],
    NutritionData? nutrition,
    this.procedures = const [],
  }) : nutrition = nutrition ?? NutritionData.initial();

  final List<String> photos;
  final String title;
  final String content;
  final List<String> tags;
  final List<IngredientData> ingredients;
  final NutritionData nutrition;
  final List<String> procedures;

  CreatePostData copyWith({
    List<String>? photos,
    String? title,
    String? content,
    List<String>? tags,
    List<IngredientData>? ingredients,
    NutritionData? nutrition,
    List<String>? procedures,
  }) {
    return CreatePostData(
      photos: photos ?? this.photos,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      ingredients: ingredients ?? this.ingredients,
      nutrition: nutrition ?? this.nutrition,
      procedures: procedures ?? this.procedures,
    );
  }
}

class IngredientData {
  IngredientData({
    this.name = '',
    this.amount = 0,
    this.unit = 'g',
  });

  final String name;
  final double amount;
  final String unit;

  IngredientData copyWith({
    String? name,
    double? amount,
    String? unit,
  }) {
    return IngredientData(
      name: name ?? this.name,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
    );
  }
}

class NutritionData {
  NutritionData({
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
  });

  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  factory NutritionData.initial() => NutritionData(
        calories: 0,
        protein: 0,
        carbs: 0,
        fat: 0,
      );

  NutritionData copyWith({
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
  }) {
    return NutritionData(
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
    );
  }
}

