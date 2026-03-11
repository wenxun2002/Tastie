import 'dart:async';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

/// Uploads recipe images to Firebase Storage and returns download URLs.
class RecipeStorageService {
  RecipeStorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;
  static const String _bucketPath = 'recipe_images';

  /// Uploads a single image from [filePath] (local path) under [userId].
  /// Returns the download URL, or throws on failure.
  Future<String> uploadImage({
    required String userId,
    required String filePath,
    String? suffix,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw RecipeStorageException('File not found: $filePath');
    }
    final name = suffix ??
        '${DateTime.now().millisecondsSinceEpoch}_${filePath.split(RegExp(r'[/\\]')).last}';
    final ref = _storage.ref().child(_bucketPath).child(userId).child(name);
    try {
      final task = ref.putFile(file);
      await task.timeout(const Duration(minutes: 2));
      final url = await ref.getDownloadURL().timeout(const Duration(seconds: 30));
      return url;
    } on FirebaseException catch (e) {
      throw RecipeStorageException(
        'Storage upload failed (${e.code}): ${e.message ?? 'unknown error'}',
      );
    } on TimeoutException {
      throw RecipeStorageException(
        'Storage upload timed out. Please check network and Storage rules.',
      );
    } catch (e) {
      throw RecipeStorageException('Storage upload failed: $e');
    }
  }

  /// Uploads multiple images and returns their download URLs in order.
  /// [filePaths] are local file paths (e.g. from XFile.path).
  Future<List<String>> uploadImages({
    required String userId,
    required List<String> filePaths,
  }) async {
    final urls = <String>[];
    for (var i = 0; i < filePaths.length; i++) {
      final url = await uploadImage(
        userId: userId,
        filePath: filePaths[i],
        suffix: 'img_${DateTime.now().millisecondsSinceEpoch}_$i',
      );
      urls.add(url);
    }
    return urls;
  }

  /// Deletes a file in Storage by its full URL (optional, for cleanup on recipe delete).
  /// No-op if the URL is not from this bucket.
  Future<void> deleteByUrl(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } on FirebaseException catch (_) {
      // Ignore not-found or invalid URL
    }
  }

  /// Deletes multiple files by their download URLs.
  Future<void> deleteByUrls(List<String> downloadUrls) async {
    await Future.wait(downloadUrls.map(deleteByUrl));
  }
}

class RecipeStorageException implements Exception {
  RecipeStorageException(this.message);
  final String message;
  @override
  String toString() => 'RecipeStorageException: $message';
}
