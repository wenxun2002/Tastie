import 'package:tastie/data/weather_tag_weight.dart';
import 'package:tastie/models/weather_data.dart';

/// 根据 WeatherAPI 的 condition code / 文本 + 温度 + 体感温度 + 湿度 + 降水
/// 将当前天气归类到业务上的 6 个 WeatherCategory。
///
/// 设计原则（从高优先级到低优先级）：
///
/// 1. **极端/强对流天气优先**：
///    - 雷暴（thunderstorm）→ [WeatherCategory.stormy]
/// 2. **显著降水**：
///    - 各类雨（rain / drizzle / shower）→ [WeatherCategory.rainy]
/// 3. **冰雪/极冷**：
///    - snow / sleet / blizzard / ice pellets → [WeatherCategory.cold]
/// 4. **雾霾类**：
///    - fog / mist / haze，根据温度决定 cold / neutral
/// 5. **晴/多云场景**：
///    - 使用温度 + 体感温度(feelsLike) + 湿度 + UV 指数
///      - 高温高湿高体感 → [WeatherCategory.hotHumid]
///      - 高温低湿高 UV   → [WeatherCategory.hotDry]
///      - 低温            → [WeatherCategory.cold]
///      - 其它满足舒适区间 → [WeatherCategory.neutral]
/// 6. **兜底**：未匹配到任何条件时，回落到 [WeatherCategory.neutral]。
WeatherCategory classifyWeather(WeatherData w) {
  final text = w.condition.toLowerCase();
  final code = w.conditionCode;

  bool hasText(String token) => text.contains(token);
  bool hasAnyText(Iterable<String> tokens) =>
      tokens.any((t) => text.contains(t));

  bool isThunder(int c) => {1273, 1276, 1279, 1282}.contains(c);
  bool isRainCode(int c) =>
      (c >= 1063 && c <= 1201) || (c >= 1240 && c <= 1246);
  bool isSnowOrSleetCode(int c) =>
      (c >= 1066 && c <= 1237) || (c >= 1249 && c <= 1264);
  bool isFogCode(int c) => {1030, 1135, 1147}.contains(c);

  // -------- 1. 雷暴 / 暴风雨（最高优先级） --------
  final thunderByText = hasText('thunder');
  final thunderByCode = code != null && isThunder(code);
  if (thunderByText || thunderByCode) {
    // 如果有明显雷暴或强降水则归为 stormy
    if (w.precipitation >= 20 || w.humidity >= 90) {
      return WeatherCategory.stormy;
    }
    // 轻微雷雨则至少按 rainy 处理
    return WeatherCategory.rainy;
  }

  // -------- 2. 各类雨 / 毛毛雨 / 阵雨 --------
  final rainByText =
      hasAnyText(['rain', 'drizzle', 'shower']) && !hasText('snow');
  final rainByCode = code != null && isRainCode(code);
  if (rainByText || rainByCode) {
    if (w.precipitation >= 5 || w.humidity >= 80) {
      return WeatherCategory.rainy;
    }
    // 小雨但气候整体偏热湿
    if (_isHotAndHumid(w)) {
      return WeatherCategory.hotHumid;
    }
    return WeatherCategory.neutral;
  }

  // -------- 3. 雪 / 雨夹雪 / 冰粒 / 暴风雪 --------
  final snowByText = hasAnyText([
    'snow',
    'sleet',
    'blizzard',
    'ice pellets',
    'blowing snow',
  ]);
  final snowByCode = code != null && isSnowOrSleetCode(code);
  if (snowByText || snowByCode) {
    return WeatherCategory.cold;
  }

  // -------- 4. 雾 / 霾 / 薄雾 --------
  final fogByText = hasAnyText(['fog', 'mist', 'haze']);
  final fogByCode = code != null && isFogCode(code);
  if (fogByText || fogByCode) {
    // 冷雾：体感温度偏低时归为 cold，否则 neutral
    if (w.feelsLike < 18 || w.temperature < 18) {
      return WeatherCategory.cold;
    }
    return WeatherCategory.neutral;
  }

  // -------- 5. 无明显降水：用温度 + 体感温度 + 湿度 + UV --------
  if (_isHotAndHumid(w)) {
    return WeatherCategory.hotHumid;
  }

  if (_isHotAndDry(w)) {
    return WeatherCategory.hotDry;
  }

  if (_isCold(w)) {
    return WeatherCategory.cold;
  }

  if (_isComfortableNeutral(w)) {
    return WeatherCategory.neutral;
  }

  // -------- 6. 兜底：中性天气 --------
  return WeatherCategory.neutral;
}

/// 是否属于“闷热潮湿”：高温 + 高湿 + 体感温度显著偏高
bool _isHotAndHumid(WeatherData w) {
  // 与 WeatherService.isHotHumid 保持一致：temp ≥32, humidity ≥80, feelsLike ≥40
  return w.temperature >= 32 && w.humidity >= 80 && w.feelsLike >= 40;
}

/// 是否属于“炎热干燥”：高温 + 低湿 + 高 UV（与 WeatherService.isHotDry 对齐）
bool _isHotAndDry(WeatherData w) {
  return w.temperature >= 33 && w.humidity < 40 && w.uvIndex >= 9;
}

/// 是否属于“寒冷”：实际温度或体感温度偏低（略宽松，用 feelsLike 加强体感判断）
bool _isCold(WeatherData w) {
  return w.temperature < 20 || w.feelsLike < 18;
}

/// 是否属于“舒适中性”：温度、体感温度、湿度都在适中区间
bool _isComfortableNeutral(WeatherData w) {
  final inTempRange = w.temperature >= 24 && w.temperature <= 30;
  final inFeelRange = w.feelsLike >= 24 && w.feelsLike <= 32;
  final inHumidityRange = w.humidity >= 40 && w.humidity <= 70;
  return inTempRange && inFeelRange && inHumidityRange;
}
