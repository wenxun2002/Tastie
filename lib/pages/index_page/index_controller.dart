import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tastie/constants/color_plate.dart';
import 'package:tastie/constants/pages.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tastie/data/tag_policy.dart';
import 'package:tastie/models/card_data.dart';
import 'package:tastie/repositories/recipe_engagement_repository.dart';
import 'package:tastie/models/weather_data.dart';
import 'package:tastie/mock/mock_weather.dart';
import 'package:tastie/repositories/firestore_index_repository.dart';
import 'package:tastie/data/weather_category.dart';
import 'package:tastie/services/weather_context_service.dart';
import 'package:tastie/utils/weather_classifier.dart';
import 'package:tastie/models/recipe_click_weather_snapshot.dart';
import 'package:tastie/services/recipe_analytics_service.dart';

/// 非 neutral 天气下 Explore 的瀑布降级：promoted → neutral → suppressed → 结束。
enum FetchStage { promoted, neutral, suppressed, done }

class IndexController extends GetxController
    with GetSingleTickerProviderStateMixin {
  static const int _pageSize = 10;
  static const int _maxNeutralFetchLoops = 12;
  static const int _maxBootstrapGuard = 24;

  late TabController tabController;
  List<CardData> data = []; // Explore feed
  bool isInitialLoading = true; // Show skeleton until data + images ready
  bool isDataReady = false; // Data fetched from backend
  WeatherData currentWeather = MockWeather.weatherNeutral; // Default weather

  /// neutral 天气：按 [likeCount] 分页的游标。
  DocumentSnapshot<Map<String, dynamic>>? _cursorNeutralPopular;

  /// 非 neutral：三层 tag 共用同一 [DocumentSnapshot] 游标；**每切换阶段必须置 `null`**。
  FetchStage _currentStage = FetchStage.promoted;
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;

  /// 跨阶段去重（同一菜谱可命中多组 tag）。
  final Set<String> _exploreSeenIds = <String>{};
  bool _neutralRemoteHasMore = true;

  /// Whether another page may exist after [data].
  bool hasMore = true;

  /// True while loading the next page (infinite scroll).
  bool isFetchingMore = false;
  String? currentLocationName; // e.g. "Kuala Lumpur, Federal Territory"
  DateTime? _lastWeatherFetchAt;
  WeatherContextDto? _weatherContextCache;

  /// BFF 天气分类 + Tag 角色（分层 / 过滤用）
  WeatherCategory currentWeatherCategory = WeatherCategory.neutral;
  List<String> exploreFilterPromotedTags = [];
  List<String> exploreNeutralTags = [];
  List<String> exploreSuppressedTags = [];

  /// 下拉选择器中当前展示的“分类天气”（始终是几个 MockWeather 之一）
  WeatherData selectorWeather = MockWeather.weatherNeutral;

  /// True while a manual weather switch is reloading the Explore feed.
  bool isWeatherSwitching = false;

  final RecipeEngagementRepository _engagementRepo = RecipeEngagementRepository();
  /// Cached `users/{uid}/likes/*` doc ids (cap 500) for feed heart state.
  Set<String> likedRecipeIds = {};

  @override
  void onInit() {
    super.onInit();
    tabController = TabController(length: 3, vsync: this, initialIndex: 1);
    loadData();
  }

  bool get _isWeatherCacheValid =>
      _lastWeatherFetchAt != null &&
      _weatherContextCache != null &&
      DateTime.now().difference(_lastWeatherFetchAt!).inMinutes < 60;

  /// True after a successful BFF weather fetch (used for click ML snapshots).
  bool get hasWeatherContextForAnalytics => _weatherContextCache != null;

  /// City + category + numeric weather at click time (null if BFF never succeeded).
  RecipeClickWeatherSnapshot? buildClickWeatherSnapshot() {
    if (!hasWeatherContextForAnalytics) return null;
    return RecipeClickWeatherSnapshot.fromState(
      locationName: currentLocationName,
      category: currentWeatherCategory,
      weather: currentWeather,
    );
  }

  void _resetExplorePaginationState() {
    _cursorNeutralPopular = null;
    _currentStage = FetchStage.promoted;
    _lastDoc = null;
    _exploreSeenIds.clear();
    _neutralRemoteHasMore = true;
  }

  List<String>? _tagsForFetchStage(FetchStage stage) {
    if (stage == FetchStage.done) return null;
    final List<String> raw = switch (stage) {
      FetchStage.promoted => exploreFilterPromotedTags,
      FetchStage.neutral => exploreNeutralTags,
      FetchStage.suppressed => exploreSuppressedTags,
      FetchStage.done => <String>[],
    };
    if (raw.isEmpty) return null;
    return List<String>.from(raw.take(10));
  }

  /// neutral 天气：不按 tag，`likeCount` 降序分页。
  Future<void> _pullNeutralPopularBatch({required bool forLoadMore}) async {
    final repository = FirestoreIndexRepository();
    int added = 0;
    int loops = 0;
    var cursor = forLoadMore ? _cursorNeutralPopular : null;
    var remoteHasMore = _neutralRemoteHasMore;

    while (added < _pageSize && loops < _maxNeutralFetchLoops) {
      loops++;
      final page = await repository.getPostsPaginated(
        limit: _pageSize,
        startAfterDocument: cursor,
        filterTags: null,
        sort: ExploreFeedSort.byLikeCountDesc,
      );
      cursor = page.lastDocument;
      _cursorNeutralPopular = cursor;
      remoteHasMore = page.hasMore;

      for (final item in page.items) {
        if (_exploreSeenIds.add(item.id)) {
          data.add(item);
          added++;
          if (added >= _pageSize) break;
        }
      }
      if (added >= _pageSize) break;
      if (!page.hasMore) break;
    }
    _neutralRemoteHasMore = remoteHasMore;
    hasMore = remoteHasMore;
  }

  /// 单次 Firestore 拉取（当前 [_currentStage]），并在 `items.length < limit` 时瀑布降级。
  /// 返回本次**新加入列表**的去重条数。
  Future<int> _appendOneWeatherTaggedPage() async {
    if (_currentStage == FetchStage.done) return 0;

    var tags = _tagsForFetchStage(_currentStage);
    if (tags == null || tags.isEmpty) {
      if (_currentStage == FetchStage.promoted) {
        _currentStage = FetchStage.neutral;
        _lastDoc = null;
        hasMore = true;
        return 0;
      }
      if (_currentStage == FetchStage.neutral) {
        _currentStage = FetchStage.suppressed;
        _lastDoc = null;
        hasMore = true;
        return 0;
      }
      _currentStage = FetchStage.done;
      hasMore = false;
      return 0;
    }

    final repository = FirestoreIndexRepository();
    final page = await repository.getPostsPaginated(
      limit: _pageSize,
      startAfterDocument: _lastDoc,
      filterTags: tags,
      sort: ExploreFeedSort.byCreatedAtDesc,
    );

    var appended = 0;
    for (final item in page.items) {
      if (_exploreSeenIds.add(item.id)) {
        data.add(item);
        appended++;
      }
    }

    if (page.items.length < _pageSize) {
      if (_currentStage == FetchStage.promoted) {
        _currentStage = FetchStage.neutral;
        _lastDoc = null;
        hasMore = true;
      } else if (_currentStage == FetchStage.neutral) {
        _currentStage = FetchStage.suppressed;
        _lastDoc = null;
        hasMore = true;
      } else {
        _currentStage = FetchStage.done;
        hasMore = false;
      }
    } else {
      _lastDoc = page.lastDocument;
      hasMore = true;
    }

    return appended;
  }

  /// 首屏 / 刷新：非 neutral 时填满约 [_pageSize] 条，不足则静默 promoted → neutral → suppressed。
  Future<void> _bootstrapWeatherTaggedFeed() async {
    _currentStage = FetchStage.promoted;
    _lastDoc = null;
    var guard = 0;
    while (data.length < _pageSize &&
        _currentStage != FetchStage.done &&
        guard < _maxBootstrapGuard) {
      guard++;
      final before = data.length;
      await _appendOneWeatherTaggedPage();
      if (data.length == before && _currentStage == FetchStage.done) {
        break;
      }
    }
    if (_currentStage == FetchStage.done) {
      hasMore = false;
    }
  }

  @override
  void onClose() {
    tabController.dispose();
    super.onClose();
  }

  void loadData() async {
    isInitialLoading = true;
    isDataReady = false;
    data = [];
    _resetExplorePaginationState();
    hasMore = true;
    isFetchingMore = false;
    update(['post_list']);

    await _ensureExploreWeatherContext(forceRefresh: false);

    try {
      if (currentWeatherCategory == WeatherCategory.neutral) {
        await _pullNeutralPopularBatch(forLoadMore: false);
      } else {
        await _bootstrapWeatherTaggedFeed();
      }
      await _loadLikedRecipeIds();
      isDataReady = true;
      update(['post_list']);
    } catch (e) {
      data = [];
      _resetExplorePaginationState();
      hasMore = false;
      await _loadLikedRecipeIds();
      isDataReady = true;
      update(['post_list']);
    }
  }

  Future<void> _loadLikedRecipeIds() async {
    likedRecipeIds = {};
    try {
      final String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        likedRecipeIds = await _engagementRepo.getLikedRecipeIds(uid);
      }
    } catch (_) {}
  }

  bool isRecipeLiked(String recipeId) => likedRecipeIds.contains(recipeId);

  Future<void> reloadLikedRecipeIds() async {
    await _loadLikedRecipeIds();
    update(['post_list']);
  }

  void finalizeInitialLoad() {
    if (!isInitialLoading) return;
    isInitialLoading = false;
    update(['post_list']);
  }

  /// 通过 BFF [getWeatherContext] 刷新天气与 Tag 策略；必要时重拉第一页 Explore。
  ///
  /// - 缓存 60 分钟内且 [forceRefresh] 为 false 时只恢复状态，不触发网络请求、不重拉 Feed；
  /// - [forceRefresh] 为 true 时会重新请求 Callable 并重拉第一页。
  Future<void> loadWeatherData({bool forceRefresh = false}) async {
    if (!forceRefresh && _isWeatherCacheValid) {
      _applyWeatherContextDto(_weatherContextCache!);
      update(['post_list']);
      return;
    }
    await _ensureExploreWeatherContext(forceRefresh: true);
    await _reloadExploreFirstPageWithFilter();
    update(['post_list']);
  }

  Future<void> _ensureExploreWeatherContext({required bool forceRefresh}) async {
    if (!forceRefresh && _isWeatherCacheValid) {
      _applyWeatherContextDto(_weatherContextCache!);
      return;
    }
    await _fetchWeatherContextFromNetworkWithGeolocator();
  }

  Future<void> _fetchWeatherContextFromNetworkWithGeolocator() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _handleWeatherError(
          'Location services are disabled.\n\nPlease turn on device location (GPS) and try again.',
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _handleWeatherError(
          'Location permission is not granted.\n\n'
          'Tastie uses your approximate city-level location to adjust food recommendations based on the weather.\n\n'
          'Please enable location permission in system settings and tap "Retry".',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      final dto = await WeatherContextService.fetch(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      _weatherContextCache = dto;
      _lastWeatherFetchAt = DateTime.now();
      _applyWeatherContextDto(dto);

      // ignore: avoid_print
      print(
        '[Weather/BFF] ${position.latitude}, ${position.longitude} | '
        '${dto.locationName} | category=${dto.category} | promoted=${dto.promoted}',
      );
    } on FirebaseFunctionsException catch (e) {
      // ignore: avoid_print
      print('[Weather/BFF] FirebaseFunctionsException: ${e.code} ${e.message}');
      _handleWeatherError(
        'Weather service is temporarily unavailable.\n'
        'Please check your connection and try again.',
      );
    } catch (e) {
      // ignore: avoid_print
      print('[Weather/BFF] Error: $e');
      _handleWeatherError(
        'Failed to load weather data due to a network or server issue.\n'
        'Please check your internet connection and try again.',
      );
    }
  }

  void _applyWeatherContextDto(WeatherContextDto dto) {
    currentWeather = dto.weather;
    currentLocationName = dto.locationName.isEmpty ? null : dto.locationName;
    currentWeatherCategory = dto.category;
    exploreFilterPromotedTags = List<String>.from(dto.promoted.take(10));
    exploreNeutralTags = List<String>.from(dto.neutral);
    exploreSuppressedTags = List<String>.from(dto.suppressed);
    _syncSelectorMockForCategory(dto.category);
  }

  void _syncSelectorMockForCategory(WeatherCategory category) {
    selectorWeather = MockWeather.dataForCategory(category);
    update(['weather_selector']);
  }

  Future<void> _reloadExploreFirstPageWithFilter() async {
    data = [];
    _resetExplorePaginationState();
    hasMore = true;
    try {
      if (currentWeatherCategory == WeatherCategory.neutral) {
        await _pullNeutralPopularBatch(forLoadMore: false);
      } else {
        await _bootstrapWeatherTaggedFeed();
      }
      await _loadLikedRecipeIds();
    } catch (_) {
      data = [];
      _resetExplorePaginationState();
      hasMore = false;
      await _loadLikedRecipeIds();
    }
  }

  /// Pull-to-refresh: Clear and reload first page
  Future<void> refreshPosts() async {
    isInitialLoading = true;
    isDataReady = false;
    data = [];
    _resetExplorePaginationState();
    hasMore = true;
    isFetchingMore = false;
    update(['post_list']);

    await _ensureExploreWeatherContext(forceRefresh: true);

    try {
      if (currentWeatherCategory == WeatherCategory.neutral) {
        await _pullNeutralPopularBatch(forLoadMore: false);
      } else {
        await _bootstrapWeatherTaggedFeed();
      }
      await _loadLikedRecipeIds();
      isDataReady = true;
      update(['post_list']);
    } catch (e) {
      data = [];
      _resetExplorePaginationState();
      hasMore = false;
      await _loadLikedRecipeIds();
      isDataReady = true;
      update(['post_list']);
    }
  }

  /// 触底加载：neutral 按点赞序；非 neutral 按 [FetchStage]（promoted → neutral → suppressed）。
  Future<void> loadMorePosts() async {
    if (!hasMore || isFetchingMore) return;

    if (currentWeatherCategory == WeatherCategory.neutral) {
      isFetchingMore = true;
      update(['post_list']);
      try {
        await _pullNeutralPopularBatch(forLoadMore: true);
      } catch (_) {
        // Keep existing items
      }
      isFetchingMore = false;
      update(['post_list']);
      return;
    }

    if (_currentStage == FetchStage.done) return;

    isFetchingMore = true;
    update(['post_list']);

    try {
      var totalAppended = 0;
      var guard = 0;
      while (totalAppended < _pageSize &&
          _currentStage != FetchStage.done &&
          guard < _maxBootstrapGuard) {
        guard++;
        final n = await _appendOneWeatherTaggedPage();
        totalAppended += n;
        if (n == 0 && _currentStage == FetchStage.done) {
          break;
        }
      }
    } catch (_) {
      // Keep existing items; allow retry on next scroll
    }

    isFetchingMore = false;
    update(['post_list']);
  }

  /// 手动选择天气：用本地 [classifyWeather] + [getTagPolicy] 对齐 Tag，并重拉第一页。
  Future<void> updateWeather(WeatherData weather) async {
    if (isWeatherSwitching) return;

    isWeatherSwitching = true;
    currentWeather = weather;
    selectorWeather = weather;
    currentLocationName = null;
    _weatherContextCache = null;
    _lastWeatherFetchAt = null;

    final category = classifyWeather(weather);
    currentWeatherCategory = category;
    final policy = getTagPolicy(category);
    exploreFilterPromotedTags = List<String>.from(policy.promoted.take(10));
    exploreNeutralTags = List<String>.from(policy.neutral);
    exploreSuppressedTags = List<String>.from(policy.suppressed);
    update(['weather_selector', 'post_list']);

    try {
      await _reloadExploreFirstPageWithFilter();
      final label = MockWeather.labelFor(weather);
      Get.snackbar(
        'Weather switched',
        'Demo profile: $label (${category.name})',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.white,
        colorText: Colors.black87,
        icon: const Icon(Icons.wb_sunny_outlined, color: ColorPlate.primary),
      );
    } finally {
      isWeatherSwitching = false;
      update(['weather_selector', 'post_list']);
    }
  }

  void _handleWeatherError(String message) {
    currentWeather = MockWeather.weatherNeutral;
    currentLocationName = null;
    currentWeatherCategory = WeatherCategory.neutral;
    exploreFilterPromotedTags = [];
    final neutralPolicy = getTagPolicy(WeatherCategory.neutral);
    exploreNeutralTags = List<String>.from(neutralPolicy.neutral);
    exploreSuppressedTags = [];
    selectorWeather = MockWeather.weatherNeutral;
    _weatherContextCache = null;
    _lastWeatherFetchAt = null;
    _notifyFeedOrderUnchanged();
    update(['weather_selector']);

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

  void _notifyFeedOrderUnchanged() {
    update(['post_list']);
  }

  void openIndexDetailPage(
    String id, {
    RecipeClickSource clickSource = RecipeClickSource.weatherNotPromoted,
  }) {
    final RecipeClickWeatherSnapshot? weather = buildClickWeatherSnapshot();
    Get.toNamed(
      Pages.indexDetail,
      arguments: <String, dynamic>{
        'id': id,
        'recordExploreDetailOpen': true,
        'recipeClickSource': clickSource,
        if (weather != null && !weather.isEmpty)
          'weatherSnapshot': weather.toArgumentsMap(),
      },
    );
  }

  // Alias for compatibility
  void openPost(String id) {
    openIndexDetailPage(id);
  }
}
