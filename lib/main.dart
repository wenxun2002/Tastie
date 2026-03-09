import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:tastie/firebase_options.dart';
import 'package:tastie/constants/pages.dart';
import 'package:tastie/constants/color_plate.dart';
import 'package:tastie/pages/routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Load .env configuration (e.g. API keys)
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Warning: Failed to load .env file: $e');
  }

  // NOTE: Tag policies and scoring config are now loaded on-demand
  // When backend is ready, initialize repositories here:
  // final tagPolicyRepo = TagPolicyRepository();
  // final scoringConfigRepo = ScoringConfigRepository();
  // await tagPolicyRepo.load();
  // await scoringConfigRepo.load();

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
      initialRoute: Pages.init,
    );
  }
}
