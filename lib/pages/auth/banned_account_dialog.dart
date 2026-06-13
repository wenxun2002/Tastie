import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tastie/constants/color_plate.dart';
import 'package:tastie/repositories/firestore_user_repository.dart';

/// Non-dismissible dialog shown when a banned account tries to sign in or is
/// force-signed-out while already logged in.
class BannedAccountDialog {
  BannedAccountDialog._();

  static Future<void> show() async {
    if (Get.isDialogOpen ?? false) {
      return;
    }

    await Get.dialog<void>(
      AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Account banned',
          style: TextStyle(
            color: ColorPlate.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          FirestoreUserRepository.bannedAccountMessage,
          style: TextStyle(height: 1.4),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ColorPlate.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: Get.back<void>,
            child: const Text('OK'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }
}
