import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tastie/models/recipe_firestore.dart';
import 'package:tastie/utils/recipe_catalog_policy.dart';

/// Firestore CRUD for `recipes` collection.
class FirestoreRecipeRepository {
  FirestoreRecipeRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  static const String _collection = 'recipes';

  /// Creates a new recipe document. Sets createdAt to server timestamp.
  /// Returns the new document ID.
  Future<String> create(RecipeFirestore recipe) async {
    final map = recipe.toJson();
    map['createdAt'] = FieldValue.serverTimestamp();
    // Ensure new recipes follow the latest admin schema.
    map.putIfAbsent('status', () => 'active');
    map.putIfAbsent('click_metrics', () => const <String, dynamic>{
          'weather_promoted': 0,
          'weather_notpromoted': 0,
          'normal_browse': 0,
          'search': 0,
          'total': 0,
        });
    // Optional compatibility: admin also reads these fields directly.
    map.putIfAbsent('authorUid', () => recipe.userId);

    final ref = await _db.collection(_collection).add(map);
    return ref.id;
  }

  /// Lists recipes by user ID, newest first.
  Future<List<RecipeFirestore>> getByUserId(String userId) async {
    final snapshot = await _db
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => RecipeFirestore.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  /// Watches recipes by user ID, newest first (auto-updates on create/delete).
  Stream<List<RecipeFirestore>> watchByUserId(String userId) {
    return _db
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RecipeFirestore.fromFirestore(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  /// Gets a single recipe by document ID. Returns null if not found.
  Future<RecipeFirestore?> getById(String id) async {
    final doc = await _db.collection(_collection).doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return RecipeFirestore.fromFirestore(doc.id, doc.data()!);
  }

  /// Lists all **public-catalog** recipes, newest first (excludes banned)。
  ///
  /// 不在 Firestore 层按 `status` 查询（旧文档可能无该字段）；拉全表后在内存中过滤。
  Future<List<RecipeFirestore>> getAll() async {
    final snapshot =
        await _db.collection(_collection).orderBy('createdAt', descending: true).get();
    return snapshot.docs
        .where((doc) => recipeDocIsPublicCatalogVisible(doc.data()))
        .map((doc) => RecipeFirestore.fromFirestore(doc.id, doc.data()))
        .toList(growable: false);
  }

  /// Fetches many recipes by document id, preserving [ids] order (skips missing).
  Future<List<RecipeFirestore>> getByIdsInOrder(List<String> ids) async {
    if (ids.isEmpty) return [];
    const chunkSize = 30;
    final byId = <String, RecipeFirestore>{};
    for (var i = 0; i < ids.length; i += chunkSize) {
      final end = min(i + chunkSize, ids.length);
      final chunk = ids.sublist(i, end);
      final snap = await _db
          .collection(_collection)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        byId[doc.id] = RecipeFirestore.fromFirestore(doc.id, doc.data());
      }
    }
      return ids.map((id) => byId[id]).whereType<RecipeFirestore>().toList();
  }

  /// Deletes a recipe document by ID.
  Future<void> delete(String id) async {
    await _db.collection(_collection).doc(id).delete();
  }
}
