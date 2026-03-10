import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreUserRepository {
  final FirebaseFirestore _db;
  final String collectionPath;

  FirestoreUserRepository({
    FirebaseFirestore? db,
    this.collectionPath = 'users',
  }) : _db = db ?? FirebaseFirestore.instance;

  /// Creates/updates the user profile document.
  ///
  /// - docId: Firebase Auth `uid` (globally unique; works across providers)
  /// - keeps a minimal profile for "Me" page and future features
  Future<void> upsertFromAuthUser(User user) async {
    final ref = _db.collection(collectionPath).doc(user.uid);

    final payload = <String, dynamic>{
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      'providerIds': user.providerData.map((e) => e.providerId).toList(),
      'lastLoginAt': FieldValue.serverTimestamp(),
      // Only set once on first create
      'createdAt': FieldValue.serverTimestamp(),
    };

    await ref.set(
      payload,
      SetOptions(merge: true),
    );
  }
}

