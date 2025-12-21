import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 天气后端配置（当前使用 OpenWeather One Call API 3.0）
///
/// 注意：出于安全原因，前端应用（包括 Flutter）中无法完全隐藏 API Key，
/// 但我们可以通过 .env 文件避免把 key 写死在源码里，并减少在 UI 中暴露。
class WeatherApiConfig {
  /// 从 .env 中读取 OPENWEATHER_API_KEY，key 为空时返回空字符串。
  static String get apiKey => dotenv.env['OPENWEATHER_API_KEY'] ?? '';

  /// 缓存有效期（分钟）
  static const int cacheMinutes = 60;
}
