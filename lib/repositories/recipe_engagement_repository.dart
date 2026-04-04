import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tastie/models/recipe_firestore.dart';
import 'package:tastie/repositories/firestore_recipe_repository.dart';

/// Likes and collections under `users/{uid}/likes|collections/{recipeId}`,
/// with [RecipeFirestore.likeCount] / [RecipeFirestore.favCount] on `recipes/{id}`.
class RecipeEngagementRepository {
  RecipeEngagementRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String _recipes = 'recipes';
  static const String _users = 'users';
  static const String _likes = 'likes';
  static const String _collections = 'collections';

  DocumentReference<Map<String, dynamic>> _likeRef(String uid, String recipeId) =>
      _db.collection(_users).doc(uid).collection(_likes).doc(recipeId);

  DocumentReference<Map<String, dynamic>> _collectionRef(
    String uid,
    String recipeId,
  ) =>
      _db.collection(_users).doc(uid).collection(_collections).doc(recipeId);

  DocumentReference<Map<String, dynamic>> _recipeRef(String recipeId) =>
      _db.collection(_recipes).doc(recipeId);

  /// Document IDs of recipes the user has liked (capped for feed hint).
  Future<Set<String>> getLikedRecipeIds(String userId, {int limit = 500}) async {
    final snap = await _db
        .collection(_users)
        .doc(userId)
        .collection(_likes)
        .limit(limit)
        .get();
    return snap.docs.map((d) => d.id).toSet();
  }

  /// Live set of recipe ids the user has liked (for card heart state).
  Stream<Set<String>> watchLikedRecipeIdSet(String userId, {int limit = 500}) {
    return _db
        .collection(_users)
        .doc(userId)
        .collection(_likes)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => d.id).toSet());
  }

  /// Recipes the user liked, newest interaction first (`createdAt` on like doc).
  Stream<List<RecipeFirestore>> watchLikedRecipes(
    String userId, {
    int limit = 200,
  }) {
    final recipeRepo = FirestoreRecipeRepository(db: _db);
    return _db
        .collection(_users)
        .doc(userId)
        .collection(_likes)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snap) async {
      final ids = snap.docs.map((d) => d.id).toList();
      return recipeRepo.getByIdsInOrder(ids);
    });
  }

  /// Recipes the user saved (collection), newest first.
  Stream<List<RecipeFirestore>> watchCollectedRecipes(
    String userId, {
    int limit = 200,
  }) {
    final recipeRepo = FirestoreRecipeRepository(db: _db);
    return _db
        .collection(_users)
        .doc(userId)
        .collection(_collections)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snap) async {
      final ids = snap.docs.map((d) => d.id).toList();
      return recipeRepo.getByIdsInOrder(ids);
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchRecipe(String recipeId) =>
      _recipeRef(recipeId).snapshots();

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchLike(
    String userId,
    String recipeId,
  ) =>
      _likeRef(userId, recipeId).snapshots();

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchCollection(
    String userId,
    String recipeId,
  ) =>
      _collectionRef(userId, recipeId).snapshots();

  Future<void> toggleLike({
    required String userId,
    required String recipeId,
  }) async {
    final likeRef = _likeRef(userId, recipeId);
    final recipeRef = _recipeRef(recipeId);

    await _db.runTransaction((txn) async {
      final likeSnap = await txn.get(likeRef);
      final recipeSnap = await txn.get(recipeRef);
      if (!recipeSnap.exists) {
        throw StateError('Recipe not found');
      }
      if (likeSnap.exists) {
        txn.delete(likeRef);
        txn.update(recipeRef, {'likeCount': FieldValue.increment(-1)});
      } else {
        txn.set(likeRef, {
          'recipeId': recipeId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        txn.update(recipeRef, {'likeCount': FieldValue.increment(1)});
      }
    });
  }

  Future<void> toggleFavorite({
    required String userId,
    required String recipeId,
  }) async {
    final colRef = _collectionRef(userId, recipeId);
    final recipeRef = _recipeRef(recipeId);

    await _db.runTransaction((txn) async {
      final colSnap = await txn.get(colRef);
      final recipeSnap = await txn.get(recipeRef);
      if (!recipeSnap.exists) {
        throw StateError('Recipe not found');
      }
      if (colSnap.exists) {
        txn.delete(colRef);
        txn.update(recipeRef, {'favCount': FieldValue.increment(-1)});
      } else {
        txn.set(colRef, {
          'recipeId': recipeId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        txn.update(recipeRef, {'favCount': FieldValue.increment(1)});
      }
    });
  }
}
