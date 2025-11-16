import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tastie/constants/pages.dart';
import 'package:tastie/constants/color_plate.dart';
import 'package:tastie/data/weather_tag_weight.dart';
import 'package:tastie/pages/routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load weather tag weights from JSON on app start
  try {
    final repository = WeatherWeightRepository();
    weatherWeights = await repository.load();
  } catch (e) {
    // If loading fails, the app will still run but weather sorting won't work
    // In production, you might want to show an error or use fallback data
    debugPrint('Warning: Failed to load weather weights: $e');
    // Initialize with empty map as fallback
    weatherWeights = {};
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Tastie',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: ColorPlate.primary),
        useMaterial3: true,
      ),
      getPages: Routes.getPages,
      initialRoute: Pages.home,
    );
  }
}
