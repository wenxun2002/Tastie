import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

  Future<User?> signInWithGoogle() async {
    if (isLoading.value) return currentUser.value;
    try {
      isLoading.value = true;

      final googleProvider = GoogleAuthProvider();
      final userCredential =
          await _auth.signInWithProvider(googleProvider);
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
    await _auth.signOut();
  }
}

