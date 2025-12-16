class WeatherData {
  final double temperature; // °C - 实际气温
  final double humidity; // % - 相对湿度
  final double feelsLike; // °C - 体感温度（考虑湿度和风）
  final String condition; // "Clear", "Clouds", "Rain", etc. - 文本描述
  final double uvIndex; // 0-11+
  final double precipitation; // mm/h - 降水强度

  /// 对应 WeatherAPI `current.condition.code`，用于更精细的分类
  ///
  /// 对于本地 mock 数据可以为 null。
  final int? conditionCode;

  const WeatherData({
    required this.temperature,
    required this.humidity,
    required this.feelsLike,
    required this.condition,
    required this.uvIndex,
    required this.precipitation,
    this.conditionCode,
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
        other.precipitation == precipitation &&
        other.conditionCode == conditionCode;
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
      conditionCode,
    );
  }
}
