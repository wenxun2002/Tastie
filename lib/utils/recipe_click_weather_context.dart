import 'package:get/get.dart';
import 'package:tastie/models/recipe_click_weather_snapshot.dart';
import 'package:tastie/pages/index_page/index_controller.dart';

/// Best-effort weather snapshot from [IndexController] when BFF context exists.
RecipeClickWeatherSnapshot? tryRecipeClickWeatherSnapshot() {
  try {
    final IndexController idx = Get.find<IndexController>();
    return idx.buildClickWeatherSnapshot();
  } catch (_) {
    return null;
  }
}
