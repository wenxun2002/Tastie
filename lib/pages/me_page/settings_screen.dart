import 'package:flutter/material.dart';
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
            trailing: const Icon(Icons.chevron_right, color: ColorPlate.textTertiary),
            onTap: () {
              // TODO: navigate to Account submenu
            },
          ),
          ListTile(
            title: const Text("General"),
            trailing: const Icon(Icons.chevron_right, color: ColorPlate.textTertiary),
            onTap: () {
              // TODO: navigate to General submenu
            },
          ),
        ],
      ),
    );
  }
}
