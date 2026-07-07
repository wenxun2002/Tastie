import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tastie/pages/auth/banned_account_dialog.dart';
import 'package:tastie/repositories/firestore_user_repository.dart';

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>['email'],
  );
  final FirestoreUserRepository _userRepository = FirestoreUserRepository();

  final Rxn<User> currentUser = Rxn<User>();
  final RxBool isLoading = false.obs;
  final RxBool isSessionLoading = true.obs;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;
  var _isHandlingBan = false;

  @override
  void onInit() {
    super.onInit();
    isSessionLoading.value = _auth.currentUser != null;
    _authSub = _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  @override
  void onClose() {
    unawaited(_profileSub?.cancel());
    unawaited(_authSub?.cancel());
    super.onClose();
  }

  Future<void> _onAuthStateChanged(User? user) async {
    await _profileSub?.cancel();
    _profileSub = null;

    if (user == null) {
      currentUser.value = null;
      isSessionLoading.value = false;
      return;
    }

    isSessionLoading.value = true;

    try {
      if (await _userRepository.isBanned(user.uid)) {
        await _handleBannedAccount(showDialog: true);
        return;
      }

      currentUser.value = user;
      isSessionLoading.value = false;
      _bindProfileListener(user.uid);
      _userRepository.upsertFromAuthUser(user);
    } catch (_) {
      currentUser.value = user;
      isSessionLoading.value = false;
      _bindProfileListener(user.uid);
      Get.snackbar(
        'Account status unavailable',
        'Unable to verify account status. Please try again later.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void _bindProfileListener(String uid) {
    _profileSub = _userRepository.watchUserProfile(uid).listen(
      (snapshot) {
        if (!snapshot.exists || _isHandlingBan) {
          return;
        }
        final data = snapshot.data();
        if (data == null) {
          return;
        }
        final status =
            (data['status'] ?? 'active').toString().toLowerCase();
        if (status == 'banned') {
          unawaited(_handleBannedAccount(showDialog: true));
        }
      },
      onError: (_) {},
    );
  }

  Future<void> _handleBannedAccount({required bool showDialog}) async {
    if (_isHandlingBan) {
      return;
    }
    _isHandlingBan = true;

    await _profileSub?.cancel();
    _profileSub = null;
    currentUser.value = null;
    isSessionLoading.value = false;
    await _signOutSilently();

    if (showDialog) {
      await BannedAccountDialog.show();
    }

    _isHandlingBan = false;
  }

  /// Native Google Sign-In flow (google_sign_in 6.x).
  Future<User?> signInWithGoogle() async {
    if (isLoading.value) return currentUser.value;
    try {
      isLoading.value = true;

      final GoogleSignInAccount? googleUser =
          await _googleSignIn.signIn();

      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        return null;
      }

      if (await _userRepository.isBanned(user.uid)) {
        await _handleBannedAccount(showDialog: true);
        return null;
      }

      await _userRepository.upsertFromAuthUser(user);
      currentUser.value = user;
      _bindProfileListener(user.uid);
      return user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-disabled') {
        await BannedAccountDialog.show();
      } else {
        Get.snackbar(
          'Login failed',
          _mapAuthError(e),
          snackPosition: SnackPosition.BOTTOM,
        );
      }
      return null;
    } catch (e) {
      Get.snackbar(
        'Login failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signOut() async {
    await _profileSub?.cancel();
    _profileSub = null;
    await _googleSignIn.signOut();
    await _auth.signOut();
    currentUser.value = null;
    isSessionLoading.value = false;
  }

  Future<void> _signOutSilently() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return FirestoreUserRepository.bannedAccountMessage;
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid credentials. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }
}
