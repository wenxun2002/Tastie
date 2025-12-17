import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tastie/config/weather_api_config.dart';
import 'package:tastie/models/weather_data.dart';

class WeatherRepository {
  /// OpenWeather Current Weather Data (free tier) endpoint.
  static const String _currentUrl =
      'https://api.openweathermap.org/data/2.5/weather';

  /// 通过经纬度获取当前天气和城市/地区名称
  ///
  /// - 使用 `units=metric`，温度和体感温度为摄氏度；
  /// - 城市名直接使用返回中的 `name` 字段（例如 Putrajaya）；
  /// - 分类逻辑保持不变，仅更换数据来源。
  static Future<({WeatherData weather, String locationName})>
  getCurrentWeather({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(_currentUrl).replace(
      queryParameters: {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'appid': WeatherApiConfig.apiKey,
        'units': 'metric', // 摄氏度
      },
    );

    final resp = await http.get(uri).timeout(const Duration(seconds: 10));

    if (resp.statusCode != 200) {
      throw Exception(
        'OpenWeather current weather request failed: ${resp.statusCode}',
      );
    }

    final Map<String, dynamic> json =
        jsonDecode(resp.body) as Map<String, dynamic>;

    final main = json['main'] as Map<String, dynamic>;
    final List<dynamic> weatherArray =
        (json['weather'] as List<dynamic>? ?? <dynamic>[]);
    final Map<String, dynamic> weather0 = weatherArray.isNotEmpty
        ? weatherArray.first as Map<String, dynamic>
        : {};

    final double temperature = (main['temp'] as num).toDouble();
    final double feelsLike = (main['feels_like'] as num).toDouble();
    final double humidity = (main['humidity'] as num).toDouble();

    // `data/2.5/weather` 不提供 UV 指数，保持为 0.0（不会影响其它分类，只影响 hotDry 中的 UV 条件）
    const double uvIndex = 0.0;

    // 降水量：优先使用 rain.1h，其次 snow.1h，单位 mm
    final double precipitation = (() {
      final rain = json['rain'];
      final snow = json['snow'];
      if (rain is Map<String, dynamic> && rain['1h'] != null) {
        return (rain['1h'] as num).toDouble();
      }
      if (snow is Map<String, dynamic> && snow['1h'] != null) {
        return (snow['1h'] as num).toDouble();
      }
      return 0.0;
    })();

    final String conditionText =
        (weather0['description'] as String?) ?? 'Unknown';
    final int? conditionCode = weather0['id'] as int?;

    final weather = WeatherData(
      temperature: temperature,
      humidity: humidity,
      feelsLike: feelsLike,
      condition: conditionText,
      uvIndex: uvIndex,
      precipitation: precipitation,
      conditionCode: conditionCode,
    );

    final String name = (json['name'] as String?) ?? '';
    final String? country = (json['sys']?['country'] as String?);
    final String locationName =
        (name.isNotEmpty && country != null && country.isNotEmpty)
        ? '$name, $country'
        : name;

    // 调试用：打印 OpenWeather 解析出来的坐标 & 城市
    // ignore: avoid_print
    print(
      '[OpenWeather] Mapped location: $locationName '
      '(lat=${json['coord']?['lat']}, lon=${json['coord']?['lon']})',
    );

    return (weather: weather, locationName: locationName);
  }
}
