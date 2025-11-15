import 'package:flutter/material.dart';
import 'package:tastie/constants/color_plate.dart';
import 'package:tastie/mock/mock_weather.dart';
import 'package:tastie/models/weather_data.dart';
import 'package:tastie/pages/index_page/index_controller.dart';

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
      ('Stormy', MockWeather.weatherStormy),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: DropdownButton<WeatherData>(
        value: controller.currentWeather,
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

