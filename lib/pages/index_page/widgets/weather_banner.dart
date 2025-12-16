import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tastie/common/services/weather_service.dart';
import 'package:tastie/constants/color_plate.dart';
import 'package:tastie/models/weather_data.dart';

class WeatherBanner extends StatefulWidget {
  final WeatherData weatherData;
  final String? locationName;

  const WeatherBanner({
    super.key,
    required this.weatherData,
    this.locationName,
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

    // Reset to left (0) - text starts从左侧开始
    _scrollController.jumpTo(0);

    // Wait a moment, then scroll smoothly to right
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted || !_scrollController.hasClients) return;

      // Scroll smoothly from left to right
      _scrollController
          .animateTo(
        maxScroll,
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

  String _formatCoreStats(WeatherData w) {
    final temp = w.temperature.toStringAsFixed(1);
    final feels = w.feelsLike.toStringAsFixed(1);
    final hum = w.humidity.toStringAsFixed(0);
    return '$temp°C | feels like $feels°C | $hum% humidity | ${w.condition}';
  }

  @override
  Widget build(BuildContext context) {
    final message = _generateWeatherMessage(widget.weatherData);
    final coreStats = _formatCoreStats(widget.weatherData);
    final locationPrefix =
        (widget.locationName != null && widget.locationName!.isNotEmpty)
            ? '[${widget.locationName}] '
            : '';

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
              '$locationPrefix$coreStats  •  $message',
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
