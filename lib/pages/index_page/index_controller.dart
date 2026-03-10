import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tastie/constants/pages.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tastie/models/card_data.dart';
import 'package:tastie/models/weather_data.dart';
import 'package:tastie/mock/mock_weather.dart';
import 'package:tastie/repositories/weather_repository.dart';
import 'package:tastie/repositories/firestore_index_repository.dart';
import 'package:tastie/utils/post_sorter.dart';
import 'package:tastie/data/weather_category.dart';
import 'package:tastie/utils/weather_classifier.dart';

class IndexController extends GetxController
    with GetSingleTickerProviderStateMixin {
  late TabController tabController;
  List<CardData> _allData = []; // Original unsorted data
  List<CardData> data = []; // Sorted data for display
  bool isInitialLoading = true; // Show skeleton until data + images ready
  bool isDataReady = false; // Data fetched from backend
  WeatherData currentWeather = MockWeather.weatherNeutral; // Default weather
  bool isLoadingMore = false; // Loading state for infinite scroll
  String? currentLocationName; // e.g. "Kuala Lumpur, Federal Territory"
  DateTime? _lastWeatherFetchAt;
  WeatherData? _cachedWeather;

  /// 下拉选择器中当前展示的“分类天气”（始终是几个 MockWeather 之一）
  WeatherData selectorWeather = MockWeather.weatherNeutral;

  @override
  void onInit() {
    super.onInit();
    tabController = TabController(length: 3, vsync: this, initialIndex: 1);
    loadData();
    // 异步加载当前位置天气（带缓存 & 错误处理）
    loadWeatherData();
  }

  @override
  void onClose() {
    tabController.dispose();
    super.onClose();
  }

  void loadData() async {
    // Start full reload with skeleton
    isInitialLoading = true;
    isDataReady = false;
    update(['post_list']);

    // Load data from Firestore
    try {
      final repository = FirestoreIndexRepository();
      _allData = await repository.getAll();
      _sortData();
      isDataReady = true;
      update(['post_list']);
    } catch (e) {
      // Fallback: empty list if loading fails
      _allData = [];
      _sortData();
      isDataReady = true;
      update(['post_list']);
    }
  }

  void finalizeInitialLoad() {
    if (!isInitialLoading) return;
    isInitialLoading = false;
    update(['post_list']);
  }

  /// 加载当前所在地的天气数据（带缓存）
  ///
  /// - 默认缓存 60 分钟，只要在缓存期内就直接使用上次的天气数据；
  /// - 任何错误（定位失败 / 请求失败 / 解析失败）都会回退到 Neutral 天气；
  /// - 出错时会弹出对话框提示用户并可选择重试。
  Future<void> loadWeatherData({bool forceRefresh = false}) async {
    // 如果有缓存且仍在有效期内，则直接使用缓存数据
    if (!forceRefresh &&
        _lastWeatherFetchAt != null &&
        _cachedWeather != null &&
        DateTime.now().difference(_lastWeatherFetchAt!).inMinutes < 60) {
      currentWeather = _cachedWeather!;
      final cachedCategory = classifyWeather(currentWeather);
      // ignore: avoid_print
      print('[Weather] Category (cached from API): $cachedCategory');
      _updateSelectorWeatherFromCurrent();
      _sortData();
      return;
    }

    try {
      // 1. 检查 & 请求定位权限
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _handleWeatherError(
          'Location services are disabled.\n\nPlease turn on device location (GPS) and try again.',
        );
        return;
      }

      final permission = await Geolocator.checkPermission();
      LocationPermission finalPermission = permission;

      if (permission == LocationPermission.denied) {
        finalPermission = await Geolocator.requestPermission();
      }

      if (finalPermission == LocationPermission.denied ||
          finalPermission == LocationPermission.deniedForever) {
        _handleWeatherError(
          'Location permission is not granted.\n\n'
          'Tastie uses your approximate city-level location to adjust food recommendations based on the weather.\n\n'
          'Please enable location permission in system settings and tap "Retry".',
        );
        return;
      }

      // 2. 获取当前经纬度
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      // 3. 请求 WeatherAPI 当前天气
      final result = await WeatherRepository.getCurrentWeather(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      // 4. 更新状态 & 缓存
      currentWeather = result.weather;
      currentLocationName = result.locationName;
      _cachedWeather = result.weather;
      _lastWeatherFetchAt = DateTime.now();
      _updateSelectorWeatherFromCurrent();
      _sortData();

      // 5. 输出到终端（Console）
      // ignore: avoid_print
      print(
        '[Weather] Raw position: ${position.latitude}, ${position.longitude}',
      );
      // ignore: avoid_print
      print(
        '[Weather] Location: $currentLocationName | temp=${currentWeather.temperature}°C, '
        'humidity=${currentWeather.humidity}%, feelsLike=${currentWeather.feelsLike}°C, '
        'condition=${currentWeather.condition}',
      );
      final category = classifyWeather(currentWeather);
      // ignore: avoid_print
      print('[Weather] Category (from API): $category');
    } catch (e) {
      // 不在弹窗中暴露完整异常（包含 URL 和 API key），只给用户友好提示
      _handleWeatherError(
        'Failed to load weather data due to a network or server issue.\n'
        'Please check your internet connection and try again.',
      );
      // 在控制台中仍然打印原始错误，方便调试
      // ignore: avoid_print
      print('[Weather] Error while loading weather data: $e');
    }
  }

  /// Pull-to-refresh: Clear and reload initial posts
  Future<void> refreshPosts() async {
    // Start skeleton while refreshing
    isInitialLoading = true;
    isDataReady = false;
    // 1. Clear list
    data.clear();
    update(['post_list']);

    // 2. Reload initial posts (mock or API)
    await Future.delayed(
      const Duration(milliseconds: 500),
    ); // Simulate network delay
    try {
      final repository = FirestoreIndexRepository();
      _allData = await repository.getAll();
      _sortData();
      isDataReady = true;
      update(['post_list']);

      // 强制刷新天气（忽略缓存），确保下拉刷新会拿到最新天气
      await loadWeatherData(forceRefresh: true);
    } catch (e) {
      // Fallback: empty list if loading fails
      _allData = [];
      _sortData();
      isDataReady = true;
      update(['post_list']);
    }
  }

  /// Infinite scroll: Load more posts when reaching bottom
  Future<void> loadMorePosts() async {
    if (isLoadingMore) return;

    isLoadingMore = true;
    update(['post_list']);

    // Simulate loading more posts from server or mock
    await Future.delayed(const Duration(milliseconds: 800));

    // For mock data, we'll duplicate existing data to simulate loading more
    // In real app, you would fetch from API
    try {
      final repository = FirestoreIndexRepository();
      final morePosts = await repository.getAll();
      _allData.addAll(morePosts);
      _sortData();
    } catch (e) {
      // If loading fails, just continue with existing data
    }

    isLoadingMore = false;
    update(['post_list']);
  }

  /// Update weather and re-sort data
  void updateWeather(WeatherData weather) {
    currentWeather = weather;
    selectorWeather = weather;
    _sortData();
  }

  /// 根据当前实时天气计算天气分类，并映射到一个固定的 MockWeather
  void _updateSelectorWeatherFromCurrent() {
    final category = classifyWeather(currentWeather);
    switch (category) {
      case WeatherCategory.hotHumid:
        selectorWeather = MockWeather.weatherHotHumid;
        break;
      case WeatherCategory.hotDry:
        selectorWeather = MockWeather.weatherHotDry;
        break;
      case WeatherCategory.rainy:
        selectorWeather = MockWeather.weatherRainy;
        break;
      case WeatherCategory.cold:
        selectorWeather = MockWeather.weatherCold;
        break;
      case WeatherCategory.neutral:
        selectorWeather = MockWeather.weatherNeutral;
        break;
      case WeatherCategory.winter:
        selectorWeather = MockWeather.weatherwinter;
        break;
    }
  }

  void _handleWeatherError(String message) {
    // 出错时回退到 Neutral 天气 & 默认排序
    currentWeather = MockWeather.weatherNeutral;
    currentLocationName = null;
    _sortData();

    if (Get.context == null) return;

    // 这里的 Neutral 是由错误触发的默认回退，而不是 API 返回的真实天气
    const fallbackCategory = WeatherCategory.neutral;
    // ignore: avoid_print
    print('[Weather] Category (fallback due to error): $fallbackCategory');

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Unable to update weather',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          '$message\n\nWe\'re temporarily using a neutral weather profile so your feed still works.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Close')),
          FilledButton(
            onPressed: () {
              Get.back();
              // 强制刷新，忽略缓存
              loadWeatherData(forceRefresh: true);
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  /// Sort data based on current weather
  void _sortData() {
    data = sortPostsByWeather(
      posts: List.from(_allData), // Create a copy to avoid modifying original
      weather: currentWeather,
    );
    update(['post_list']); // Only update post_list, not entire page
  }

  void openIndexDetailPage(int id) {
    Get.toNamed(Pages.indexDetail, arguments: {"id": id});
  }

  // Alias for compatibility
  void openPost(int id) {
    openIndexDetailPage(id);
  }
}
