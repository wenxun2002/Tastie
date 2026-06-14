/// Aggregated click breakdown on `recipes/{id}` (`click_metrics` in Firestore).
class RecipeClickMetrics {
  const RecipeClickMetrics({
    this.weatherPromoted = 0,
    this.weatherNotPromoted = 0,
    this.normalBrowse = 0,
    this.search = 0,
    this.total = 0,
  });

  final int weatherPromoted;
  /// Explore feed clicks where recipe tags do **not** hit current promoted tags.
  final int weatherNotPromoted;
  final int normalBrowse;
  final int search;
  final int total;

  static const RecipeClickMetrics zero = RecipeClickMetrics();

  Map<String, dynamic> toFirestoreMap() => <String, dynamic>{
        'weather_promoted': weatherPromoted,
        'weather_notpromoted': weatherNotPromoted,
        'normal_browse': normalBrowse,
        'search': search,
        'total': total,
      };

  factory RecipeClickMetrics.fromFirestoreMap(Map<String, dynamic> data) {
    int read(String key) {
      final value = data[key];
      return value is num ? value.toInt() : 0;
    }

    return RecipeClickMetrics(
      weatherPromoted: read('weather_promoted'),
      weatherNotPromoted: read('weather_notpromoted'),
      normalBrowse: read('normal_browse'),
      search: read('search'),
      total: read('total'),
    );
  }
}
