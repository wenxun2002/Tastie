import 'package:tastie/models/weather_data.dart';
import 'package:tastie/data/weather_tag_weight.dart';
import 'package:tastie/utils/weather_classifier.dart';

/// 天气服务类 - 负责基于统一的 WeatherCategory 生成文案。
///
/// 说明：
/// - **唯一的分类标准** 来自 `classifyWeather`（参见 `weather_classifier.dart`）
/// - 本类只做「WeatherCategory → 文案」的映射，避免出现两套不同的判断规则。
class WeatherService {
  /// 根据天气数据自动判断天气类型并返回对应的消息
  static String getWeatherMessage(WeatherData weather) {
    final category = classifyWeather(weather);

    switch (category) {
      case WeatherCategory.hotHumid:
        return getHotHumidMessage();
      case WeatherCategory.hotDry:
        return getHotDryMessage();
      case WeatherCategory.rainy:
        return getRainyMessage();
      case WeatherCategory.cold:
        return getColdMessage();
      case WeatherCategory.winter:
        return getWinterMessage();
      case WeatherCategory.neutral:
        return getNeutralMessage();
    }
  }

  /// 获取炎热潮湿天气消息
  static String getHotHumidMessage() {
    return "🌡️ Hot & Humid Weather Alert: Stay hydrated! Consider light, cooling foods like salads, fresh fruits, and cold soups. Avoid heavy, spicy meals.";
  }

  /// 获取炎热干燥天气消息
  static String getHotDryMessage() {
    return "☀️ Hot & Dry Weather: High UV index detected! Protect yourself from sun exposure. Enjoy refreshing drinks, watermelon, and hydrating foods. Stay in shade during peak hours.";
  }

  /// 获取雨天消息
  static String getRainyMessage() {
    return "🌧️ Rainy Day: Perfect weather for warm, comforting meals! Consider hot soups, stews, warm beverages, and hearty dishes to keep you cozy.";
  }

  /// 获取寒冷天气消息
  static String getColdMessage() {
    return "❄️ Cold Weather: Time for warming foods! Enjoy hot soups, warm beverages, spicy dishes, and hearty meals to keep your body warm and energized.";
  }

  /// 获取冬季 / 下雪天气消息（内部使用 WeatherCategory.stormy 表示 Winter）
  static String getWinterMessage() {
    return "⛄ Winter Weather: Cold and snowy conditions are perfect for warm, hearty comfort foods — think hot soups, stews, baked dishes, and hot drinks to keep you warm and satisfied.";
  }

  /// 获取正常天气消息
  static String getNeutralMessage() {
    return "☀️ Pleasant Weather: Enjoy balanced meals! Perfect conditions for a variety of foods. Stay hydrated and maintain a healthy diet.";
  }

  /// 获取默认消息
  static String getDefaultMessage() {
    return "🌤️ Weather Update: Current conditions suggest moderate food choices. Stay hydrated and enjoy your meals!";
  }
}
