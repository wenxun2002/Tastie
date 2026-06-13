import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreUserRepository {
  static const String bannedAccountMessage =
      'Your account has been banned. Please contact support if you believe this is an error.';

  final FirebaseFirestore _db;
  final String collectionPath;

  FirestoreUserRepository({
    FirebaseFirestore? db,
    this.collectionPath = 'users',
  }) : _db = db ?? FirebaseFirestore.instance;

  /// Returns true when the Firestore profile is marked as banned.
  Future<bool> isBanned(String uid) async {
    final snap = await _db.collection(collectionPath).doc(uid).get();
    if (!snap.exists) return false;
    final data = snap.data();
    if (data == null) return false;
    final status = (data['status'] ?? 'active').toString().toLowerCase();
    return status == 'banned';
  }

  /// Live profile updates for moderation enforcement while signed in.
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUserProfile(String uid) {
    return _db.collection(collectionPath).doc(uid).snapshots();
  }

  /// Creates/updates the user profile document.
  ///
  /// - docId: Firebase Auth `uid` (globally unique; works across providers)
  /// - keeps a minimal profile for "Me" page and future features
  Future<void> upsertFromAuthUser(User user) async {
    final ref = _db.collection(collectionPath).doc(user.uid);

    final existing = await ref.get();
    final data = existing.data();
    final hasCreatedAt = existing.exists && data != null && data['createdAt'] != null;

    final payload = <String, dynamic>{
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      'providerIds': user.providerData.map((e) => e.providerId).toList(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    };

    // Only set once on first create (or if missing).
    if (!hasCreatedAt) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }

    await ref.set(
      payload,
      SetOptions(merge: true),
    );
  }
}

