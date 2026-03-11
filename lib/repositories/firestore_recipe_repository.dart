import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tastie/models/recipe_firestore.dart';

/// Firestore CRUD for `recipes` collection.
class FirestoreRecipeRepository {
  FirestoreRecipeRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  static const String _collection = 'recipes';

  /// Creates a new recipe document. Sets createdAt to server timestamp.
  /// Returns the new document ID.
  Future<String> create(RecipeFirestore recipe) async {
    final map = recipe.toFirestore();
    map['createdAt'] = FieldValue.serverTimestamp();

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

  /// Gets a single recipe by document ID. Returns null if not found.
  Future<RecipeFirestore?> getById(String id) async {
    final doc = await _db.collection(_collection).doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return RecipeFirestore.fromFirestore(doc.id, doc.data()!);
  }

  /// Deletes a recipe document by ID.
  Future<void> delete(String id) async {
    await _db.collection(_collection).doc(id).delete();
  }
}
