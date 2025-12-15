import 'dart:convert';

import 'package:tastie/constants/ingredient_units.dart';
import 'package:tastie/models/create_post_data.dart';

/// Business logic for building the payload that will be sent to backend
/// when creating a post.
class CreatePostService {
  const CreatePostService._();

  /// Build the final JSON payload (as a Map) that would be sent to backend.
  ///
  /// This includes:
  /// - mapping ingredient units into `quantityType` / `specialValue`
  /// - keeping amount as `null` when the unit is a special unit
  static Map<String, dynamic> buildCreatePostPayload(CreatePostData data) {
    final ingredients = data.ingredients.map((ingredient) {
      final bool isSpecial = IngredientUnits.specialUnits.contains(
        ingredient.unit,
      );
      return <String, dynamic>{
        'ingredientName': ingredient.name,
        'amount': isSpecial ? null : ingredient.amount,
        'unit': ingredient.unit,
        'quantityType': isSpecial ? 'special' : 'normal',
        'specialValue': isSpecial ? ingredient.unit : null,
      };
    }).toList();

    final nutrition = <String, dynamic>{
      'calories': data.nutrition.calories,
      'protein': data.nutrition.protein,
      'carbs': data.nutrition.carbs,
      'fat': data.nutrition.fat,
    };

    return <String, dynamic>{
      'title': data.title,
      'content': data.content,
      'photos': data.photos,
      'tags': data.tags,
      'ingredients': ingredients,
      'nutrition': nutrition,
      'procedures': data.procedures,
    };
  }

  /// Helper used only for debugging in this phase (before real backend).
  /// It prints a pretty JSON representation of the payload.
  static void logCreatePostPayload(CreatePostData data) {
    final payload = buildCreatePostPayload(data);
    final encoder = const JsonEncoder.withIndent('  ');
    final pretty = encoder.convert(payload);
    // This is what you'd send to backend.
    // For now we just print it to the debug console.
    // You can search for this line in the console to inspect the payload.
    // Example filter: "CreatePost payload JSON".
    // ignore: avoid_print
    print('CreatePost payload JSON:\n$pretty');
  }
}
