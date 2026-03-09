import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tastie/constants/color_plate.dart';
import 'package:tastie/pages/auth/auth_controller.dart';
import 'package:tastie/pages/auth/login_page.dart';
import 'package:tastie/pages/home_page/home_page.dart';

class AuthGatePage extends StatelessWidget {
  const AuthGatePage({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(AuthController(), permanent: true);

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: ColorPlate.secondary,
            body: Center(
              child: CircularProgressIndicator(
                color: ColorPlate.primary,
              ),
            ),
          );
        }

        if (snapshot.hasData) {
          return HomePage();
        }

        return const LoginPage();
      },
    );
  }
}

