/// Tag Policy Repository - Backend-Ready Abstraction Layer
///
/// This repository provides an abstraction for loading tag policies.
/// Currently uses hardcoded policies, but can be easily switched to fetch from backend API.
///
/// Future backend integration:
/// - Replace [loadFromLocal] with [loadFromBackend] method
/// - Backend API endpoint: GET /api/scoring/tag-policies
/// - Expected response format: { "hotHumid": { "promoted": [...], "neutral": [...], "suppressed": [...] }, ... }

import 'package:tastie/data/tag_policy.dart';
import 'package:tastie/data/weather_category.dart';

/// Abstract interface for tag policy loading
abstract class ITagPolicyRepository {
  /// Load tag policies from data source
  Future<Map<WeatherCategory, TagPolicy>> load();
}

/// Tag Policy Repository Implementation
///
/// Currently loads from hardcoded local policies.
/// To integrate with backend:
/// 1. Implement [loadFromBackend] method
/// 2. Update [load] method to call backend (with local fallback)
/// 3. Add caching mechanism for offline support
class TagPolicyRepository implements ITagPolicyRepository {
  /// Load tag policies
  ///
  /// Currently uses local hardcoded policies.
  /// Future: Will fetch from backend API with local fallback.
  @override
  Future<Map<WeatherCategory, TagPolicy>> load() async {
    // TODO: When backend is ready, implement:
    // try {
    //   return await loadFromBackend();
    // } catch (e) {
    //   debugPrint('Failed to load from backend, using local fallback: $e');
    //   return loadFromLocal();
    // }
    return loadFromLocal();
  }

  /// Load tag policies from backend API
  ///
  /// Future implementation:
  /// ```dart
  /// final response = await http.get(
  ///   Uri.parse('$baseUrl/api/scoring/tag-policies'),
  ///   headers: {'Authorization': 'Bearer $token'},
  /// );
  /// final json = jsonDecode(response.body);
  /// return _parseTagPoliciesFromJson(json);
  /// ```
  Future<Map<WeatherCategory, TagPolicy>> loadFromBackend() async {
    // TODO: Implement backend API call
    throw UnimplementedError('Backend integration not yet implemented');
  }

  /// Load tag policies from local hardcoded data
  ///
  /// This is the current implementation and serves as fallback.
  Map<WeatherCategory, TagPolicy> loadFromLocal() {
    // Import the hardcoded policies from tag_policy.dart
    // In the future, this could also load from a local JSON file
    return statePolicy;
  }
}
