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

/// waterfall downgrade for Explore in non-neutral weather: promoted → neutral → suppressed → done.
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

  /// neutral weather: cursor for [likeCount] descending order pagination.
  DocumentSnapshot<Map<String, dynamic>>? _cursorNeutralPopular;

  /// non-neutral: three layers of tags share the same [DocumentSnapshot] cursor; **must be set to `null` for each stage switch**.
  FetchStage _currentStage = FetchStage.promoted;
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;

  /// deduplication across stages (a recipe can hit multiple tags).
  final Set<String> _exploreSeenIds = <String>{};
  bool _neutralRemoteHasMore = true;

  /// Whether another page may exist after [data].
  bool hasMore = true;

  /// True while loading the next page (infinite scroll).
  bool isFetchingMore = false;
  String? currentLocationName; // e.g. "Kuala Lumpur, Federal Territory"
  DateTime? _lastWeatherFetchAt;
  WeatherContextDto? _weatherContextCache;

  /// BFF weather classification + Tag role (for hierarchical / filtering)
  WeatherCategory currentWeatherCategory = WeatherCategory.neutral;
  List<String> exploreFilterPromotedTags = [];
  List<String> exploreNeutralTags = [];
  List<String> exploreSuppressedTags = [];

  /// the current displayed "classified weather" in the dropdown selector (always one of the MockWeathers)
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

  /// neutral weather: not by tag, `likeCount` descending order pagination.
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

  /// single Firestore fetch (current [_currentStage]), and waterfall downgrade when `items.length < limit`.
  /// return the number of deduplicated items added to the list in this fetch.
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

  /// first screen / refresh: non-neutral fill up to about [_pageSize] items, if not enough, silently promoted → neutral → suppressed.
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

  /// refresh weather and tag policy through BFF [getWeatherContext]; if needed refresh 1st pageExplore。
  ///
  /// - if cached within 60 minutes and [forceRefresh] is false, only restore state, no network request, no reload Feed;
  /// - [forceRefresh] is true, it will re-request Callable and reload first page.
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

  /// bottom load: neutral by like count; non-neutral by [FetchStage] (promoted → neutral → suppressed).
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

  /// manually select weather: align tags with local [classifyWeather] + [getTagPolicy], and reload first page.
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

    // the Neutral here is the default fallback due to error, not the real weather returned by the API
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
              // for force refresh
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
