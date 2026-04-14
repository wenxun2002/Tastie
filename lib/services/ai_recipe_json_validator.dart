import 'package:tastie/constants/ingredient_units.dart';

class AiRecipeJsonValidationResult {
  const AiRecipeJsonValidationResult({
    required this.isValid,
    required this.errors,
  });

  final bool isValid;
  final List<String> errors;
}

class AiRecipeJsonValidator {
  const AiRecipeJsonValidator._();

  static AiRecipeJsonValidationResult validate(Map<String, dynamic> json) {
    final errors = <String>[];

    final ingredientsRaw = json['ingredients'];
    final nutritionRaw = json['nutrition'];
    final proceduresRaw = json['procedures'];

    if (ingredientsRaw is! List || ingredientsRaw.isEmpty) {
      errors.add('ingredients must be a non-empty array');
    }
    if (nutritionRaw is! Map) {
      errors.add('nutrition must be an object');
    }
    if (proceduresRaw is! List || proceduresRaw.isEmpty) {
      errors.add('procedures must be a non-empty array');
    }

    if (ingredientsRaw is List) {
      for (var i = 0; i < ingredientsRaw.length; i++) {
        final item = ingredientsRaw[i];
        if (item is! Map) {
          errors.add('ingredients[$i] must be an object');
          continue;
        }
        final ingredient = Map<String, dynamic>.from(item);
        final name = (ingredient['name'] ?? '').toString().trim();
        final unit = (ingredient['unit'] ?? '').toString().trim();
        final amountRaw = ingredient['amount'];

        if (name.isEmpty) {
          errors.add('ingredients[$i].name is required');
        }
        if (!IngredientUnits.allUnits.contains(unit)) {
          errors.add(
            'ingredients[$i].unit must be one of ${IngredientUnits.allUnits.join(', ')}',
          );
        }

        final amount = amountRaw is num
            ? amountRaw.toDouble()
            : double.tryParse(amountRaw?.toString() ?? '');

        if (amount == null) {
          errors.add('ingredients[$i].amount must be a number');
          continue;
        }

        final isSpecial = IngredientUnits.specialUnits.contains(unit);
        if (isSpecial && amount != 0) {
          errors.add(
            'ingredients[$i].amount must be 0 when unit is "$unit"',
          );
        }
        if (!isSpecial && amount <= 0) {
          errors.add(
            'ingredients[$i].amount must be > 0 when unit is "$unit"',
          );
        }
      }
    }

    if (nutritionRaw is Map) {
      final nutrition = Map<String, dynamic>.from(nutritionRaw);
      for (final key in const ['calories', 'protein', 'carbs', 'fat']) {
        final value = nutrition[key];
        final number = value is num
            ? value.toDouble()
            : double.tryParse(value?.toString() ?? '');
        if (number == null) {
          errors.add('nutrition.$key must be a number');
          continue;
        }
        if (number < 0) {
          errors.add('nutrition.$key must be >= 0');
        }
      }
    }

    if (proceduresRaw is List) {
      for (var i = 0; i < proceduresRaw.length; i++) {
        final step = (proceduresRaw[i] ?? '').toString().trim();
        if (step.isEmpty) {
          errors.add('procedures[$i] cannot be empty');
        }
      }
    }

    return AiRecipeJsonValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }
}
