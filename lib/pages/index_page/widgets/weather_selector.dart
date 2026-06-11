import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
    return GetBuilder<IndexController>(
      id: 'weather_selector',
      init: controller,
      builder: (_) {
        final weatherOptions = MockWeather.allOptions;

        return Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: controller.isWeatherSwitching
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ColorPlate.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Updating feed for selected weather…',
                          style: ColorPlate.bodyText.copyWith(
                            color: ColorPlate.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : DropdownButton<WeatherData>(
                  value: controller.selectorWeather,
                  isExpanded: true,
                  underline: Container(),
                  items: weatherOptions.map((option) {
                    return DropdownMenuItem<WeatherData>(
                      value: option.data,
                      child: Text(
                        option.label,
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
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          option.label,
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
      },
    );
  }
}
