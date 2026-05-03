import 'package:cloud_functions/cloud_functions.dart';
import 'package:tastie/data/weather_category.dart';
import 'package:tastie/models/weather_data.dart';

/// BFF payload from [getWeatherContext] (Firebase Callable).
class WeatherContextDto {
  const WeatherContextDto({
    required this.category,
    required this.promoted,
    required this.neutral,
    required this.suppressed,
    required this.weather,
    required this.locationName,
  });

  final WeatherCategory category;
  final List<String> promoted;
  final List<String> neutral;
  final List<String> suppressed;
  final WeatherData weather;
  final String locationName;

  static WeatherContextDto fromCallableData(dynamic raw) {
    if (raw is! Map) {
      throw const FormatException('getWeatherContext: expected map response');
    }
    final m = Map<String, dynamic>.from(raw);
    final category = parseCategory(m['category'] as String);
    final promoted = _stringList(m['promoted']);
    final neutral = _stringList(m['neutral']);
    final suppressed = _stringList(m['suppressed']);
    final locationName = (m['locationName'] as String?) ?? '';

    final weather = WeatherData(
      temperature: (m['temperature'] as num).toDouble(),
      humidity: (m['humidity'] as num).toDouble(),
      feelsLike: (m['feelsLike'] as num).toDouble(),
      condition: (m['condition'] as String?) ?? 'Unknown',
      uvIndex: (m['uvIndex'] as num?)?.toDouble() ?? 0.0,
      precipitation: (m['precipitation'] as num?)?.toDouble() ?? 0.0,
      conditionCode: m['conditionCode'] as int?,
    );

    return WeatherContextDto(
      category: category,
      promoted: promoted,
      neutral: neutral,
      suppressed: suppressed,
      weather: weather,
      locationName: locationName,
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return [];
    return value.map((e) => e.toString()).toList(growable: false);
  }
}

/// Calls Cloud Function `getWeatherContext` (OpenWeather + classification server-side).
class WeatherContextService {
  WeatherContextService._();

  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );

  static Future<WeatherContextDto> fetch({
    required double latitude,
    required double longitude,
  }) async {
    final HttpsCallable callable = _functions.httpsCallable('getWeatherContext');
    final result = await callable.call(<String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
    });
    return WeatherContextDto.fromCallableData(result.data);
  }
}
