import 'package:get/get.dart';
import 'package:tastie/constants/ingredient_units.dart';
import 'package:tastie/models/create_post_data.dart';
import 'package:tastie/models/recipe_firestore.dart';
import 'package:tastie/pages/auth/auth_controller.dart';
import 'package:tastie/repositories/firestore_recipe_repository.dart';
import 'package:tastie/services/recipe_storage_service.dart';

/// Callback for progress messages (e.g. "Uploading images...", "Saving recipe...").
typedef CreateRecipeProgressCallback = void Function(String message);

/// Creates a recipe: upload images to Storage, then save document to Firestore.
class CreateRecipeService {
  CreateRecipeService({
    RecipeStorageService? storage,
    FirestoreRecipeRepository? repository,
  })  : _storage = storage ?? RecipeStorageService(),
        _repository = repository ?? FirestoreRecipeRepository();

  final RecipeStorageService _storage;
  final FirestoreRecipeRepository _repository;

  /// Creates a recipe from [data] for the current user.
  /// 1. Uploads images to Firebase Storage and gets download URLs.
  /// 2. Saves recipe document to Firestore with userId, authorUid, imageUrls, createdAt.
  /// Returns the new Firestore document ID.
  /// Throws if user is not logged in or on upload/Firestore failure.
  Future<String> createRecipe(
    CreatePostData data, {
    CreateRecipeProgressCallback? onProgress,
  }) async {
    final auth = Get.find<AuthController>();
    final user = auth.currentUser.value;
    if (user == null) {
      throw CreateRecipeException('Please sign in to create a recipe.');
    }

    final userId = user.uid;
    final authorNickname = user.displayName ?? 'User';
    final authorAvatar = user.photoURL ?? '';

    // 1. Upload images
    onProgress?.call('Uploading images...');
    List<String> imageUrls = [];
    if (data.photos.isNotEmpty) {
      // Update progress per image (at least shows which one is hanging).
      final urls = <String>[];
      for (var i = 0; i < data.photos.length; i++) {
        onProgress?.call('Uploading images... (${i + 1}/${data.photos.length})');
        final url = await _storage.uploadImage(
          userId: userId,
          filePath: data.photos[i],
          suffix: 'img_${DateTime.now().millisecondsSinceEpoch}_$i',
        );
        urls.add(url);
      }
      imageUrls = urls;
    }

    // 2. Build Firestore payload
    onProgress?.call('Saving recipe...');
    final ingredients = data.ingredients.map((ingredient) {
      final isSpecial = IngredientUnits.specialUnits.contains(ingredient.unit);
      return <String, dynamic>{
        'name': ingredient.name,
        'amount': isSpecial ? 0 : ingredient.amount,
        'unit': ingredient.unit,
      };
    }).toList();

    final nutrition = <String, dynamic>{
      'calories': data.nutrition.calories.toInt(),
      'protein': data.nutrition.protein.toInt(),
      'carbs': data.nutrition.carbs.toInt(),
      'fat': data.nutrition.fat.toInt(),
    };

    final recipe = RecipeFirestore(
      userId: userId,
      authorNickname: authorNickname,
      authorAvatar: authorAvatar,
      imageUrls: imageUrls,
      title: data.title.trim(),
      content: data.content.trim(),
      tags: data.tags,
      ingredients: ingredients,
      procedures: data.procedures,
      nutrition: nutrition,
      likeCount: 0,
      favCount: 0,
      commentCount: 0,
      createdAt: null, // server timestamp set in repository
    );

    final docId = await _repository.create(recipe);
    return docId;
  }
}

class CreateRecipeException implements Exception {
  CreateRecipeException(this.message);
  final String message;
  @override
  String toString() => 'CreateRecipeException: $message';
}
