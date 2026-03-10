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
        title: const Text("Settings"),
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Debug / Auth',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ColorPlate.textSecondary,
              ),
            ),
          ),
          // 按钮一：普通登出
          ListTile(
            title: const Text('Sign Out'),
            subtitle: const Text('Clear local session only'),
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
          // 按钮二：彻底重置（模拟初次登录）
          ListTile(
            title: const Text('Disconnect Account (Reset)'),
            subtitle: const Text(
              'Disconnect + sign out to force the account picker next time',
            ),
            leading:
                const Icon(Icons.delete_forever, color: ColorPlate.textSecondary),
            onTap: () async {
              final googleSignIn = GoogleSignIn(scopes: <String>['email']);
              try {
                try {
                  await googleSignIn.disconnect();
                } catch (_) {
                  // 如果当前没有连接账户，disconnect 可能抛错，忽略即可
                }
                await googleSignIn.signOut();
                await FirebaseAuth.instance.signOut();

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Disconnected. Next sign-in will show account picker.',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Reset failed: $e')),
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
