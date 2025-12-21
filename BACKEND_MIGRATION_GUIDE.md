# Backend Migration Guide - C-Model Scoring System

## 📋 Overview

This document describes the code changes made to prepare for future backend integration while maintaining the current C-Model scoring system.

## 🔄 Major Changes

### 1. **File Structure Reorganization**

#### New Files Created:
- `lib/data/weather_category.dart` - Extracted `WeatherCategory` enum and `parseCategory` function (shared across app)
- `lib/repositories/tag_policy_repository.dart` - Backend-ready abstraction for tag policies
- `lib/repositories/scoring_config_repository.dart` - Backend-ready abstraction for scoring config

#### Files Updated:
- `lib/data/tag_policy.dart` - Now imports from `weather_category.dart` instead of `weather_tag_weight.dart`
- `lib/utils/post_sorter.dart` - Updated imports, uses new structure
- `lib/utils/weather_classifier.dart` - Updated imports and comments
- `lib/pages/index_page/index_controller.dart` - Updated imports
- `lib/common/services/weather_service.dart` - Updated imports
- `lib/main.dart` - Removed old weight loading logic

#### Files Deprecated (Commented Out):
- `lib/data/weather_tag_weight.dart` - **All code commented out** (old weight-based system)

### 2. **Old Weight System (DEPRECATED)**

The old system using `weather_tag_weight.json` and numeric weights has been **completely replaced** by the C-Model semantic classification system.

**Old System (Deprecated):**
```dart
// ❌ OLD: Fixed numeric weights
{ "Cooling": 0.9, "Hydrating": 1.0 }
```

**New System (Current):**
```dart
// ✅ NEW: Semantic classification
promoted: ['Cooling', 'Hydrating']
neutral: ['Comfort']
suppressed: ['Energy', 'Warming']
```

### 3. **Backend-Ready Architecture**

#### Tag Policy Repository Pattern

```dart
// Current: Loads from hardcoded local data
final repo = TagPolicyRepository();
final policies = await repo.load(); // Uses loadFromLocal()

// Future: Will automatically switch to backend
// Just implement loadFromBackend() method
```

**Backend API Endpoint (Future):**
```
GET /api/scoring/tag-policies
Response: {
  "hotHumid": {
    "promoted": ["Cooling", "Hydrating", "Light"],
    "neutral": ["Comfort"],
    "suppressed": ["Energy", "Warming"]
  },
  ...
}
```

#### Scoring Config Repository Pattern

```dart
// Current: Loads from hardcoded constants
final repo = ScoringConfigRepository();
final config = await repo.load(); // Uses loadFromLocal()

// Future: Will fetch from backend
// GET /api/scoring/config
```

**Backend API Endpoint (Future):**
```
GET /api/scoring/config
Response: {
  "promotedMultiplier": 1.0,
  "neutralMultiplier": 0.4,
  "suppressMultiplier": 0.1,
  "defaultContextWeight": 0.8,
  "defaultPopularityWeight": 0.2,
  "neutralContextWeight": 0.4,
  "neutralPopularityWeight": 0.6,
  "noiseMax": 0.05
}
```

## 🚀 Migration Steps (When Backend is Ready)

### Step 1: Implement Backend API Calls

**In `tag_policy_repository.dart`:**
```dart
Future<Map<WeatherCategory, TagPolicy>> loadFromBackend() async {
  final response = await http.get(
    Uri.parse('$baseUrl/api/scoring/tag-policies'),
    headers: {'Authorization': 'Bearer $token'},
  );
  
  if (response.statusCode == 200) {
    final json = jsonDecode(response.body);
    return _parseTagPoliciesFromJson(json);
  } else {
    throw Exception('Failed to load tag policies: ${response.statusCode}');
  }
}
```

**In `scoring_config_repository.dart`:**
```dart
Future<ScoringConfig> loadFromBackend() async {
  final response = await http.get(
    Uri.parse('$baseUrl/api/scoring/config'),
    headers: {'Authorization': 'Bearer $token'},
  );
  
  if (response.statusCode == 200) {
    final json = jsonDecode(response.body);
    return ScoringConfig.fromJson(json);
  } else {
    throw Exception('Failed to load scoring config: ${response.statusCode}');
  }
}
```

### Step 2: Update Repository Load Methods

Both repositories already have TODO comments showing where to add backend calls with local fallback:

```dart
@override
Future<Map<WeatherCategory, TagPolicy>> load() async {
  try {
    return await loadFromBackend();
  } catch (e) {
    debugPrint('Failed to load from backend, using local fallback: $e');
    return loadFromLocal(); // Automatic fallback
  }
}
```

### Step 3: Initialize Repositories in main.dart

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load .env
  await dotenv.load(fileName: '.env');
  
  // Initialize repositories (will use backend when ready)
  final tagPolicyRepo = TagPolicyRepository();
  final scoringConfigRepo = ScoringConfigRepository();
  
  // Pre-load policies and config (optional, can be lazy-loaded)
  await tagPolicyRepo.load();
  await scoringConfigRepo.load();
  
  runApp(const MyApp());
}
```

### Step 4: Add Caching (Optional but Recommended)

```dart
class TagPolicyRepository {
  Map<WeatherCategory, TagPolicy>? _cachedPolicies;
  DateTime? _cacheTimestamp;
  static const cacheDuration = Duration(hours: 1);
  
  @override
  Future<Map<WeatherCategory, TagPolicy>> load() async {
    // Use cache if valid
    if (_cachedPolicies != null && 
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < cacheDuration) {
      return _cachedPolicies!;
    }
    
    // Try backend, fallback to local
    try {
      _cachedPolicies = await loadFromBackend();
      _cacheTimestamp = DateTime.now();
      return _cachedPolicies!;
    } catch (e) {
      return loadFromLocal();
    }
  }
}
```

## 📝 Notes

### Why Keep Old Code Commented?

The old `weather_tag_weight.dart` file is kept (but commented out) for:
- **Reference**: Understanding the migration path
- **Rollback**: If needed for comparison
- **Documentation**: Shows what was replaced

### Current State

- ✅ C-Model system fully functional
- ✅ All old weight-based code commented out
- ✅ Backend-ready abstraction layers in place
- ✅ Local fallback mechanisms ready
- ⏳ Backend API integration pending (just implement the TODO methods)

### Testing

When backend is ready:
1. Implement `loadFromBackend()` methods
2. Update `load()` methods to try backend first
3. Test with backend API
4. Verify local fallback works when backend is unavailable
5. Add caching for better performance

## 🔗 Related Files

- `lib/data/tag_policy.dart` - Current tag policies (hardcoded)
- `lib/constants/scoring_config.dart` - Current scoring config (hardcoded)
- `lib/utils/post_sorter.dart` - Scoring logic (uses policies and config)
- `lib/data/weather_tag_weight.dart` - **DEPRECATED** (commented out)

