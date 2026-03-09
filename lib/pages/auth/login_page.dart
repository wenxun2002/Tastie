import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sign_in_button/sign_in_button.dart';
import 'package:tastie/constants/color_plate.dart';
import 'package:tastie/pages/auth/auth_controller.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController controller = Get.find<AuthController>();

    return Scaffold(
      backgroundColor: ColorPlate.secondary,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 80),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo 居中
                  Center(
                    child: SizedBox(
                      width: 220,
                      height: 220,
                      child: Image.asset(
                        'assets/images/LogowithNameT.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
              child: Center(
                child: SizedBox(
                  width: 260,
                  child: Obx(() {
                    if (controller.isLoading.value) {
                      return AbsorbPointer(
                        absorbing: true,
                        child: Opacity(
                          opacity: 0.7,
                          child: SignInButton(
                            Buttons.google,
                            text: 'Signing in...',
                            onPressed: () {},
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(27),
                            ),
                          ),
                        ),
                      );
                    }

                    return SignInButton(
                      Buttons.google,
                      text: 'Continue with Google',
                      onPressed: () {
                        controller.signInWithGoogle();
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(27),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

