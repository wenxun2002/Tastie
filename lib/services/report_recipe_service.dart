import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for submitting recipe reports to Firestore `reports` collection.
class ReportRecipeService {
  ReportRecipeService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  static const String _collection = 'reports';

  /// Submits a report. Requires a logged-in user.
  /// Returns null on success; throws or returns error message on failure.
  Future<void> submitReport({
    required String recipeId,
    required String recipeTitle,
    required String authorUsername,
    required String reportedBy,
    required String reason,
    required String description,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('You must be logged in to report a recipe.');
    }
    if (reportedBy != user.uid) {
      throw StateError('Report must be submitted by the current user.');
    }

    await _db.collection(_collection).add({
      'recipeId': recipeId,
      'recipeTitle': recipeTitle,
      'authorUsername': authorUsername,
      'reportedBy': reportedBy,
      'reason': reason,
      'description': description,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
