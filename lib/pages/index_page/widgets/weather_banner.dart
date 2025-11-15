import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tastie/common/services/weather_service.dart';
import 'package:tastie/constants/color_plate.dart';
import 'package:tastie/models/weather_data.dart';

class WeatherBanner extends StatefulWidget {
  final WeatherData weatherData;

  const WeatherBanner({
    super.key,
    required this.weatherData,
  });

  @override
  State<WeatherBanner> createState() => _WeatherBannerState();
}

class _WeatherBannerState extends State<WeatherBanner> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    // Wait for the widget to be built and measured
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndStartScroll();
    });
  }

  void _checkAndStartScroll() {
    if (!mounted) return;

    // Wait a bit for layout to complete
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted || !_scrollController.hasClients) return;

      // Check if content overflows
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll > 0) {
        // Content overflows, start auto-scrolling
        _startAutoScrollAnimation();
      }
    });
  }

  void _startAutoScrollAnimation() {
    if (!mounted || !_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    // Reset to right (maxScrollExtent) - text starts from right side
    _scrollController.jumpTo(maxScroll);

    // Wait a moment for text to appear from right, then scroll smoothly to left
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted || !_scrollController.hasClients) return;

      // Scroll smoothly from right to left
      _scrollController
          .animateTo(
        0,
        duration: Duration(
            milliseconds: maxScroll.toInt() * 30), // Smooth scrolling speed
        curve: Curves.easeInOut, // Smooth curve for better visual effect
      )
          .then((_) {
        if (!mounted) return;
        // Wait before next cycle, then reset to right and start again
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            _startAutoScrollAnimation();
          }
        });
      });
    });
  }

  String _generateWeatherMessage(WeatherData weather) {
    // 使用 WeatherService 来获取天气消息
    return WeatherService.getWeatherMessage(weather);
  }

  @override
  Widget build(BuildContext context) {
    final message = _generateWeatherMessage(widget.weatherData);

    return Container(
      height: 40,
      width: double.infinity,
      color: ColorPlate.secondary,
      child: ClipRect(
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics:
              const NeverScrollableScrollPhysics(), // Disable manual scroll
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
            child: Text(
              message,
              style: ColorPlate.bodyText.copyWith(
                color: ColorPlate.primary,
                fontSize: 14,
              ),
              textAlign: TextAlign.left,
            ),
          ),
        ),
      ),
    );
  }
}
