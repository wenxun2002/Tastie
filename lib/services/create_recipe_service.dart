import 'dart:io';

import 'package:get/get.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
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

    // 1. Compress + upload images
    onProgress?.call('Compressing images...');
    List<String> imageUrls = [];
    if (data.photos.isNotEmpty) {
      final compressedPhotos = await _compressPhotos(
        data.photos,
        userId: userId,
        onProgress: onProgress,
      );

      onProgress?.call('Uploading images...');
      final urls = <String>[];
      for (var i = 0; i < compressedPhotos.length; i++) {
        onProgress?.call('Uploading images... (${i + 1}/${compressedPhotos.length})');
        final url = await _storage.uploadImage(
          userId: userId,
          filePath: compressedPhotos[i],
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

  /// Compresses photos before upload, preserving aspect ratio (no crop).
  /// - quality: 80
  /// - minWidth: 1080 (high-res images will be scaled down proportionally)
  Future<List<String>> _compressPhotos(
    List<String> originalPaths, {
    required String userId,
    CreateRecipeProgressCallback? onProgress,
  }) async {
    final resultPaths = <String>[];
    if (originalPaths.isEmpty) return resultPaths;

    final tempDir = await getTemporaryDirectory();

    for (var i = 0; i < originalPaths.length; i++) {
      final srcPath = originalPaths[i];
      onProgress?.call('Compressing images... (${i + 1}/${originalPaths.length})');

      final srcFile = File(srcPath);
      if (!await srcFile.exists()) {
        resultPaths.add(srcPath);
        continue;
      }

      final targetPath =
          '${tempDir.path}/recipe_${userId}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';

      try {
        final compressed = await FlutterImageCompress.compressAndGetFile(
          srcFile.path,
          targetPath,
          quality: 80,
          minWidth: 1080,
        );

       if (compressed != null &&
          await File(compressed.path).exists()) {
        resultPaths.add(compressed.path);
      } else {
        resultPaths.add(srcPath);
      }
      } catch (e) {
        // Avoid failing the whole flow because of one compression error.
        // ignore: avoid_print
        print('Image compress failed for $srcPath: $e');
        resultPaths.add(srcPath);
      }
    }

    return resultPaths;
  }
}

class CreateRecipeException implements Exception {
  CreateRecipeException(this.message);
  final String message;
  @override
  String toString() => 'CreateRecipeException: $message';
}
