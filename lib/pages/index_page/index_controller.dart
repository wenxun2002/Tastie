import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tastie/constants/pages.dart';
import 'package:tastie/models/card_data.dart';
import 'package:tastie/models/weather_data.dart';
import 'package:tastie/mock/mock_weather.dart';
import 'package:tastie/repositories/mock_index_repository.dart';
import 'package:tastie/utils/post_sorter.dart';

class IndexController extends GetxController
    with GetSingleTickerProviderStateMixin {
  late TabController tabController;
  List<CardData> _allData = []; // Original unsorted data
  List<CardData> data = []; // Sorted data for display
  WeatherData currentWeather = MockWeather.weatherNeutral; // Default weather
  bool isLoadingMore = false; // Loading state for infinite scroll

  @override
  void onInit() {
    super.onInit();
    tabController = TabController(length: 3, vsync: this, initialIndex: 1);
    loadData();
    loadWeatherData();
  }

  @override
  void onClose() {
    tabController.dispose();
    super.onClose();
  }

  void loadData() async {
    // Load mock data from JSON
    try {
      final repository = MockIndexRepository();
      _allData = await repository.getAll();
      _sortData();
    } catch (e) {
      // Fallback: empty list if loading fails
      _allData = [];
      _sortData();
    }
  }

  void loadWeatherData() {
    // Load weather data - you can change this to test different weather conditions
    // currentWeather = MockWeather.weatherHotHumid;
    currentWeather = MockWeather.weatherNeutral;
    // currentWeather = MockWeather.weatherRainy;
    // currentWeather = MockWeather.weatherCold;
    // currentWeather = MockWeather.weatherNeutral;
    // currentWeather = MockWeather.weatherStormy;
    _sortData();
  }

  /// Pull-to-refresh: Clear and reload initial posts
  Future<void> refreshPosts() async {
    // 1. Clear list
    data.clear();
    update(['post_list']);

    // 2. Reload initial posts (mock or API)
    await Future.delayed(
        const Duration(milliseconds: 500)); // Simulate network delay
    try {
      final repository = MockIndexRepository();
      _allData = await repository.getAll();
      _sortData();
    } catch (e) {
      // Fallback: empty list if loading fails
      _allData = [];
      _sortData();
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
      final repository = MockIndexRepository();
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
    _sortData();
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
