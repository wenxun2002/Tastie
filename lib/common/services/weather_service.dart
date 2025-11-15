import 'package:tastie/models/weather_data.dart';

/// 天气服务类 - 用于判断天气类型和生成相应的建议消息
class WeatherService {
  /// 判断是否为炎热潮湿天气
  /// temp >= 32, humidity >= 80, feelsLike >= 40
  static bool isHotHumid(WeatherData weather) {
    return weather.temperature >= 32 &&
        weather.humidity >= 80 &&
        weather.feelsLike >= 40;
  }

  /// 判断是否为炎热干燥天气
  /// temp >= 33, humidity < 40, uvIndex >= 9
  static bool isHotDry(WeatherData weather) {
    return weather.temperature >= 33 &&
        weather.humidity < 40 &&
        weather.uvIndex >= 9;
  }

  /// 判断是否为雨天
  /// condition == "Rain", precipitation > 10, humidity >= 85
  static bool isRainy(WeatherData weather) {
    return weather.condition == "Rain" &&
        weather.precipitation > 10 &&
        weather.humidity >= 85;
  }

  /// 判断是否为寒冷天气
  /// temp < 20, condition == "Clouds"
  static bool isCold(WeatherData weather) {
    return weather.temperature < 20 && weather.condition == "Clouds";
  }

  /// 判断是否为暴风雨天气
  /// condition == "Thunderstorm", precipitation > 30, humidity >= 90
  static bool isStormy(WeatherData weather) {
    return weather.condition == "Thunderstorm" &&
        weather.precipitation > 30 &&
        weather.humidity >= 90;
  }

  /// 判断是否为正常天气
  /// temp 27-29, humidity 50-65
  static bool isNeutral(WeatherData weather) {
    return weather.temperature >= 27 &&
        weather.temperature <= 29 &&
        weather.humidity >= 50 &&
        weather.humidity <= 65;
  }

  /// 根据天气数据自动判断天气类型并返回对应的消息
  static String getWeatherMessage(WeatherData weather) {
    if (isHotHumid(weather)) {
      return getHotHumidMessage();
    } else if (isHotDry(weather)) {
      return getHotDryMessage();
    } else if (isRainy(weather)) {
      return getRainyMessage();
    } else if (isCold(weather)) {
      return getColdMessage();
    } else if (isStormy(weather)) {
      return getStormyMessage();
    } else if (isNeutral(weather)) {
      return getNeutralMessage();
    } else {
      return getDefaultMessage();
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

  /// 获取暴风雨天气消息
  static String getStormyMessage() {
    return "⛈️ Stormy Weather: Stay indoors and stay safe! Perfect time for comfort foods like warm soups, hot drinks, and hearty home-cooked meals.";
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
