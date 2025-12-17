/// 天气后端配置（当前使用 OpenWeather One Call API 3.0）
///
/// TODO: 将此处的示例 key 替换为你自己的 OpenWeather API key。
/// 你可以在 https://openweathermap.org/ 注册并获取。
class WeatherApiConfig {
  static const String apiKey = 'd908f620ebc313a4f168e7fb3858f15d';

  /// 缓存有效期（分钟）
  static const int cacheMinutes = 60;
}
