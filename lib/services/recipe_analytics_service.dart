import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tastie/models/recipe_click_weather_snapshot.dart';

/// Machine-learning click attribution (mirrors Firestore `clickSource` strings).
enum RecipeClickSource {
  /// Recipe tags intersect current weather promoted tags (Explore feed).
  weatherPromoted('weather_promoted'),
  /// Explore feed but tags do not intersect promoted list for this weather.
  weatherNotPromoted('weather_notpromoted'),
  normalBrowse('normal_browse'),
  search('search');

  const RecipeClickSource(this.firestoreValue);
  final String firestoreValue;
}

/// Appends rows to `recipe_click_events`; aggregation on `recipes` is done by Cloud Functions.
class RecipeAnalyticsService {
  RecipeAnalyticsService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String _collection = 'recipe_click_events';

  Future<void> logRecipeClick({
    required String recipeId,
    required String userId,
    required RecipeClickSource source,
    RecipeClickWeatherSnapshot? weather,
  }) async {
    if (recipeId.isEmpty || userId.isEmpty) return;

    final payload = <String, dynamic>{
      'recipeId': recipeId,
      'userId': userId,
      'clickSource': source.firestoreValue,
      'timestamp': FieldValue.serverTimestamp(),
    };

    if (weather != null && !weather.isEmpty) {
      payload.addAll(weather.toFirestoreMap());
    }

    await _db.collection(_collection).add(payload);
  }
}
