import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tastie/constants/color_plate.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorPlate.background,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.white,
        foregroundColor: ColorPlate.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text("Account"),
            trailing: const Icon(
              Icons.chevron_right,
              color: ColorPlate.textTertiary,
            ),
            onTap: () {
              // TODO: navigate to Account submenu
            },
          ),
          ListTile(
            title: const Text("General"),
            trailing: const Icon(
              Icons.chevron_right,
              color: ColorPlate.textTertiary,
            ),
            onTap: () {
              // TODO: navigate to General submenu
            },
          ),
          const Divider(),
          // const Padding(
          //   padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          //   child: Text(
          //     'Debug / Auth',
          //     style: TextStyle(
          //       fontSize: 14,
          //       fontWeight: FontWeight.w600,
          //       color: ColorPlate.textSecondary,
          //     ),
          //   ),
          // ),
          // 按钮一：普通登出
          ListTile(
            title: const Text('Sign Out'),
            leading: const Icon(Icons.logout, color: ColorPlate.primary),
            onTap: () async {
              try {
                await GoogleSignIn(scopes: <String>['email']).signOut();
                await FirebaseAuth.instance.signOut();

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Signed out (local session cleared).'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Sign out failed: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
