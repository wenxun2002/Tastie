class WeatherData {
  final double temperature; // °C
  final double humidity; // %
  final double feelsLike; // °C
  final String condition; // "Clear", "Clouds", "Rain", etc.
  final double uvIndex; // 0-11+
  final double precipitation; // mm/h

  const WeatherData({
    required this.temperature,
    required this.humidity,
    required this.feelsLike,
    required this.condition,
    required this.uvIndex,
    required this.precipitation,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WeatherData &&
        other.temperature == temperature &&
        other.humidity == humidity &&
        other.feelsLike == feelsLike &&
        other.condition == condition &&
        other.uvIndex == uvIndex &&
        other.precipitation == precipitation;
  }

  @override
  int get hashCode {
    return Object.hash(
      temperature,
      humidity,
      feelsLike,
      condition,
      uvIndex,
      precipitation,
    );
  }
}
