import 'package:tastie/models/weather_data.dart';

class MockWeather {
  // Hot & Humid
  // temp ~33, humidity >80, feelsLike >40, condition "Clear"
  static const WeatherData weatherHotHumid = WeatherData(
    temperature: 33.5,
    humidity: 85.0,
    feelsLike: 42.0,
    condition: "Clear",
    uvIndex: 9.5,
    precipitation: 0.0,
  );

  // Hot but dry
  // temp >33, humidity <40, strong UV
  static const WeatherData weatherHotDry = WeatherData(
    temperature: 35.0,
    humidity: 35.0,
    feelsLike: 38.0,
    condition: "Clear",
    uvIndex: 11.0,
    precipitation: 0.0,
  );

  // Rainy
  // lower temp, high humidity, precipitation >10
  static const WeatherData weatherRainy = WeatherData(
    temperature: 24.0,
    humidity: 90.0,
    feelsLike: 26.0,
    condition: "Rain",
    uvIndex: 2.0,
    precipitation: 15.5,
  );

  // Cold
  // temp <20, clouds
  static const WeatherData weatherCold = WeatherData(
    temperature: 18.0,
    humidity: 70.0,
    feelsLike: 16.0,
    condition: "Clouds",
    uvIndex: 3.0,
    precipitation: 0.0,
  );

  // Normal weather
  // temp around 27-29, humidity 50-65
  static const WeatherData weatherNeutral = WeatherData(
    temperature: 28.0,
    humidity: 60.0,
    feelsLike: 29.0,
    condition: "Clear",
    uvIndex: 6.0,
    precipitation: 0.0,
  );

  // Heavy thunderstorm
  // high precipitation, very high humidity
  static const WeatherData weatherStormy = WeatherData(
    temperature: 22.0,
    humidity: 95.0,
    feelsLike: 25.0,
    condition: "Thunderstorm",
    uvIndex: 1.0,
    precipitation: 45.0,
  );
}
