import 'package:flutter/material.dart';
import 'package:tastie/constants/color_plate.dart';
import 'package:tastie/mock/mock_weather.dart';
import 'package:tastie/models/weather_data.dart';
import 'package:tastie/pages/index_page/index_controller.dart';

/// Hidden dev/demo entry: long-press the home header logo to open this sheet.
Future<void> showWeatherSelectorSheet(
  BuildContext context,
  IndexController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Switch weather',
              style: ColorPlate.heading2.copyWith(color: ColorPlate.primary),
            ),
          ),
          WeatherSelector(controller: controller),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class WeatherSelector extends StatelessWidget {
  final IndexController controller;

  const WeatherSelector({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    // Weather options mapping
    final weatherOptions = [
      ('Hot & Humid', MockWeather.weatherHotHumid),
      ('Hot & Dry', MockWeather.weatherHotDry),
      ('Rainy', MockWeather.weatherRainy),
      ('Cold', MockWeather.weatherCold),
      ('Neutral', MockWeather.weatherNeutral),
      ('Winter', MockWeather.weatherwinter),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: DropdownButton<WeatherData>(
        // 只允许下拉框的 value 使用几个固定的 MockWeather，避免值不在 items 中
        value: controller.selectorWeather,
        isExpanded: true,
        underline: Container(), // Remove default underline
        items: weatherOptions.map((option) {
          return DropdownMenuItem<WeatherData>(
            value: option.$2,
            child: Text(
              option.$1,
              style: ColorPlate.bodyText,
            ),
          );
        }).toList(),
        onChanged: (WeatherData? newWeather) {
          if (newWeather != null) {
            controller.updateWeather(newWeather);
          }
        },
        selectedItemBuilder: (BuildContext context) {
          return weatherOptions.map((option) {
            return Container(
              alignment: Alignment.centerLeft,
              child: Text(
                option.$1,
                style: ColorPlate.bodyText.copyWith(
                  color: ColorPlate.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList();
        },
      ),
    );
  }
}

