import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tastie/config/weather_api_config.dart';
import 'package:tastie/models/weather_data.dart';

class WeatherRepository {
  static const String _baseUrl = 'http://api.weatherapi.com/v1/current.json';

  /// 通过经纬度获取当前天气和城市/地区名称
  static Future<({WeatherData weather, String locationName})> getCurrentWeather({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'key': WeatherApiConfig.apiKey,
      'q': '$latitude,$longitude',
      'aqi': 'no',
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('WeatherAPI request failed: ${response.statusCode}');
    }

    final Map<String, dynamic> json = jsonDecode(response.body);

    if (!json.containsKey('location') || !json.containsKey('current')) {
      throw Exception('Invalid WeatherAPI response');
    }

    final location = json['location'] as Map<String, dynamic>;
    final current = json['current'] as Map<String, dynamic>;

    final weather = WeatherData(
      temperature: (current['temp_c'] as num).toDouble(),
      humidity: (current['humidity'] as num).toDouble(),
      feelsLike: (current['feelslike_c'] as num).toDouble(),
      condition: (current['condition']?['text'] as String?) ?? 'Unknown',
      uvIndex: (current['uv'] as num?)?.toDouble() ?? 0.0,
      precipitation: (current['precip_mm'] as num?)?.toDouble() ?? 0.0,
      conditionCode: current['condition']?['code'] as int?,
    );

    final name = (location['name'] as String?) ?? '';
    final region = (location['region'] as String?) ?? '';
    final cityDisplay =
        (name.isNotEmpty && region.isNotEmpty) ? '$name, $region' : name;

    // 调试用：打印 WeatherAPI 解析出来的经纬度和城市，方便你对比 Emulator 设置的位置
    // ignore: avoid_print
    print(
      '[WeatherAPI] Mapped location: $name, $region '
      '(lat=${location['lat']}, lon=${location['lon']})',
    );

    return (weather: weather, locationName: cityDisplay);
  }
}


