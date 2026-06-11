import 'package:flutter_test/flutter_test.dart';
import 'package:tastie/data/weather_category.dart';
import 'package:tastie/mock/mock_weather.dart';
import 'package:tastie/utils/weather_classifier.dart';

void main() {
  group('MockWeather profiles align with classifyWeather', () {
    for (final option in MockWeather.allOptions) {
      test('${option.label} → ${option.category.name}', () {
        expect(
          classifyWeather(option.data),
          option.category,
          reason:
              'Manual test-plan profile "${option.label}" must classify as '
              '${option.category.name}',
        );
      });
    }
  });

  test('allOptions cover every WeatherCategory once', () {
    final categories = MockWeather.allOptions.map((o) => o.category).toList();
    expect(categories, hasLength(WeatherCategory.values.length));
    expect(categories.toSet(), WeatherCategory.values.toSet());
  });
}
