import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>['email'],
  );

  final Rxn<User> currentUser = Rxn<User>();
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    currentUser.value = _auth.currentUser;
    _auth.authStateChanges().listen((user) {
      currentUser.value = user;
    });
  }

  /// Native Google Sign-In flow (google_sign_in 6.x).
  ///
  /// - 调起 Android/iOS 原生账号选择弹窗。
  /// - 将 Google 账号 token 转换为 Firebase 凭据。
  /// - 用户取消弹窗时返回 null，不报错。
  Future<User?> signInWithGoogle() async {
    if (isLoading.value) return currentUser.value;
    try {
      isLoading.value = true;

      final GoogleSignInAccount? googleUser =
          await _googleSignIn.signIn();

      // 用户在弹窗中取消 / 返回
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
      return userCredential.user;
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
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}

