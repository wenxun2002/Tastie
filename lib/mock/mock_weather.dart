import 'package:tastie/data/weather_category.dart';
import 'package:tastie/models/weather_data.dart';

/// Demo / manual-override weather profiles for the hidden weather selector.
///
/// Each profile is tuned so [classifyWeather] resolves to exactly one
/// [WeatherCategory] — use [allOptions] or [mock_weather_test.dart] in test plans.
class MockWeatherOption {
  const MockWeatherOption({
    required this.label,
    required this.data,
    required this.category,
  });

  final String label;
  final WeatherData data;
  final WeatherCategory category;
}

class MockWeather {
  MockWeather._();

  // Hot & Humid — feelsLike >= 38 (priority 3)
  static const WeatherData weatherHotHumid = WeatherData(
    temperature: 33.5,
    humidity: 85.0,
    feelsLike: 42.0,
    condition: 'Clear',
    uvIndex: 9.5,
    precipitation: 0.0,
    conditionCode: 1000,
  );

  // Hot & Dry — dry heat, feelsLike 32–37 (priority 5)
  static const WeatherData weatherHotDry = WeatherData(
    temperature: 34.0,
    humidity: 35.0,
    feelsLike: 34.0,
    condition: 'Clear',
    uvIndex: 7.0,
    precipitation: 0.0,
    conditionCode: 1000,
  );

  // Rainy — condition text + precipitation (priority 2)
  static const WeatherData weatherRainy = WeatherData(
    temperature: 24.0,
    humidity: 90.0,
    feelsLike: 26.0,
    condition: 'Rain',
    uvIndex: 2.0,
    precipitation: 15.5,
    conditionCode: 1183,
  );

  // Cold — temp <= 26 (priority 4)
  static const WeatherData weatherCold = WeatherData(
    temperature: 18.0,
    humidity: 70.0,
    feelsLike: 16.0,
    condition: 'Clouds',
    uvIndex: 3.0,
    precipitation: 0.0,
    conditionCode: 1006,
  );

  // Neutral — mild, between cold and hot-dry thresholds (priority 6)
  static const WeatherData weatherNeutral = WeatherData(
    temperature: 27.0,
    humidity: 55.0,
    feelsLike: 28.0,
    condition: 'Clear',
    uvIndex: 6.0,
    precipitation: 0.0,
    conditionCode: 1000,
  );

  // Winter — snow condition + snow code (priority 1)
  static const WeatherData weatherWinter = WeatherData(
    temperature: -2.0,
    humidity: 80.0,
    feelsLike: -5.0,
    condition: 'Snow',
    uvIndex: 1.0,
    precipitation: 0.0,
    conditionCode: 601,
  );

  /// All manual-switch options with their intended [WeatherCategory].
  static const List<MockWeatherOption> allOptions = [
    MockWeatherOption(
      label: 'Hot & Humid',
      data: weatherHotHumid,
      category: WeatherCategory.hotHumid,
    ),
    MockWeatherOption(
      label: 'Hot & Dry',
      data: weatherHotDry,
      category: WeatherCategory.hotDry,
    ),
    MockWeatherOption(
      label: 'Rainy',
      data: weatherRainy,
      category: WeatherCategory.rainy,
    ),
    MockWeatherOption(
      label: 'Cold',
      data: weatherCold,
      category: WeatherCategory.cold,
    ),
    MockWeatherOption(
      label: 'Neutral',
      data: weatherNeutral,
      category: WeatherCategory.neutral,
    ),
    MockWeatherOption(
      label: 'Winter',
      data: weatherWinter,
      category: WeatherCategory.winter,
    ),
  ];

  static String labelFor(WeatherData data) {
    for (final option in allOptions) {
      if (option.data == data) return option.label;
    }
    return data.condition;
  }

  static WeatherCategory? categoryFor(WeatherData data) {
    for (final option in allOptions) {
      if (option.data == data) return option.category;
    }
    return null;
  }

  static WeatherData dataForCategory(WeatherCategory category) {
    for (final option in allOptions) {
      if (option.category == category) return option.data;
    }
    return weatherNeutral;
  }
}
