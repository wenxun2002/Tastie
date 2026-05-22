import 'package:tastie/data/weather_category.dart';
import 'package:tastie/models/weather_data.dart';

/// Weather context at recipe click time (city + category + numeric readings).
class RecipeClickWeatherSnapshot {
  const RecipeClickWeatherSnapshot({
    this.locationName,
    this.weatherCategory,
    this.temperature,
    this.feelsLike,
    this.humidity,
    this.precipitation,
    this.conditionCode,
  });

  final String? locationName;
  final String? weatherCategory;
  final double? temperature;
  final double? feelsLike;
  final double? humidity;
  final double? precipitation;
  final int? conditionCode;

  bool get isEmpty =>
      (locationName == null || locationName!.isEmpty) &&
      (weatherCategory == null || weatherCategory!.isEmpty) &&
      temperature == null &&
      feelsLike == null &&
      humidity == null &&
      precipitation == null &&
      conditionCode == null;

  factory RecipeClickWeatherSnapshot.fromState({
    String? locationName,
    required WeatherCategory category,
    required WeatherData weather,
  }) {
    return RecipeClickWeatherSnapshot(
      locationName:
          (locationName != null && locationName.isNotEmpty) ? locationName : null,
      weatherCategory: category.name,
      temperature: weather.temperature,
      feelsLike: weather.feelsLike,
      humidity: weather.humidity,
      precipitation: weather.precipitation,
      conditionCode: weather.conditionCode,
    );
  }

  factory RecipeClickWeatherSnapshot.fromArgumentsMap(dynamic args) {
    if (args is! Map) return const RecipeClickWeatherSnapshot();
    final dynamic raw = args['weatherSnapshot'];
    if (raw is RecipeClickWeatherSnapshot) return raw;
    if (raw is! Map) return const RecipeClickWeatherSnapshot();
    final m = Map<String, dynamic>.from(raw);
    return RecipeClickWeatherSnapshot(
      locationName: m['locationName'] as String?,
      weatherCategory: m['weatherCategory'] as String?,
      temperature: (m['temperature'] as num?)?.toDouble(),
      feelsLike: (m['feelsLike'] as num?)?.toDouble(),
      humidity: (m['humidity'] as num?)?.toDouble(),
      precipitation: (m['precipitation'] as num?)?.toDouble(),
      conditionCode: m['conditionCode'] as int?,
    );
  }

  Map<String, dynamic> toArgumentsMap() => toFirestoreMap();

  Map<String, dynamic> toFirestoreMap() {
    final map = <String, dynamic>{};
    if (locationName != null && locationName!.isNotEmpty) {
      map['locationName'] = locationName;
    }
    if (weatherCategory != null && weatherCategory!.isNotEmpty) {
      map['weatherCategory'] = weatherCategory;
    }
    if (temperature != null) map['temperature'] = temperature;
    if (feelsLike != null) map['feelsLike'] = feelsLike;
    if (humidity != null) map['humidity'] = humidity;
    if (precipitation != null) map['precipitation'] = precipitation;
    if (conditionCode != null) map['conditionCode'] = conditionCode;
    return map;
  }
}
