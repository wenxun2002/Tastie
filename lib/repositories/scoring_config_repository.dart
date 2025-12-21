/// Scoring Config Repository - Backend-Ready Abstraction Layer
///
/// This repository provides an abstraction for loading scoring configuration.
/// Currently uses hardcoded constants, but can be easily switched to fetch from backend API.
///
/// Future backend integration:
/// - Replace [loadFromLocal] with [loadFromBackend] method
/// - Backend API endpoint: GET /api/scoring/config
/// - Expected response format: { "promotedMultiplier": 1.0, "neutralMultiplier": 0.4, ... }

import 'package:tastie/constants/scoring_config.dart' as scoring_config;

/// Scoring configuration model
class ScoringConfig {
  final double promotedMultiplier;
  final double neutralMultiplier;
  final double suppressMultiplier;
  final double defaultContextWeight;
  final double defaultPopularityWeight;
  final double neutralContextWeight;
  final double neutralPopularityWeight;
  final double noiseMax;

  const ScoringConfig({
    required this.promotedMultiplier,
    required this.neutralMultiplier,
    required this.suppressMultiplier,
    required this.defaultContextWeight,
    required this.defaultPopularityWeight,
    required this.neutralContextWeight,
    required this.neutralPopularityWeight,
    required this.noiseMax,
  });

  /// Create from JSON (for backend integration)
  factory ScoringConfig.fromJson(Map<String, dynamic> json) {
    return ScoringConfig(
      promotedMultiplier: (json['promotedMultiplier'] as num?)?.toDouble() ?? 1.0,
      neutralMultiplier: (json['neutralMultiplier'] as num?)?.toDouble() ?? 0.4,
      suppressMultiplier: (json['suppressMultiplier'] as num?)?.toDouble() ?? 0.1,
      defaultContextWeight: (json['defaultContextWeight'] as num?)?.toDouble() ?? 0.8,
      defaultPopularityWeight: (json['defaultPopularityWeight'] as num?)?.toDouble() ?? 0.2,
      neutralContextWeight: (json['neutralContextWeight'] as num?)?.toDouble() ?? 0.4,
      neutralPopularityWeight: (json['neutralPopularityWeight'] as num?)?.toDouble() ?? 0.6,
      noiseMax: (json['noiseMax'] as num?)?.toDouble() ?? 0.05,
    );
  }

  /// Convert to JSON (for backend integration)
  Map<String, dynamic> toJson() {
    return {
      'promotedMultiplier': promotedMultiplier,
      'neutralMultiplier': neutralMultiplier,
      'suppressMultiplier': suppressMultiplier,
      'defaultContextWeight': defaultContextWeight,
      'defaultPopularityWeight': defaultPopularityWeight,
      'neutralContextWeight': neutralContextWeight,
      'neutralPopularityWeight': neutralPopularityWeight,
      'noiseMax': noiseMax,
    };
  }
}

/// Abstract interface for scoring config loading
abstract class IScoringConfigRepository {
  /// Load scoring configuration from data source
  Future<ScoringConfig> load();
}

/// Scoring Config Repository Implementation
///
/// Currently loads from hardcoded local constants.
/// To integrate with backend:
/// 1. Implement [loadFromBackend] method
/// 2. Update [load] method to call backend (with local fallback)
/// 3. Add caching mechanism for offline support
class ScoringConfigRepository implements IScoringConfigRepository {
  /// Load scoring configuration
  ///
  /// Currently uses local hardcoded constants.
  /// Future: Will fetch from backend API with local fallback.
  @override
  Future<ScoringConfig> load() async {
    // TODO: When backend is ready, implement:
    // try {
    //   return await loadFromBackend();
    // } catch (e) {
    //   debugPrint('Failed to load from backend, using local fallback: $e');
    //   return loadFromLocal();
    // }
    return loadFromLocal();
  }

  /// Load scoring config from backend API
  ///
  /// Future implementation:
  /// ```dart
  /// final response = await http.get(
  ///   Uri.parse('$baseUrl/api/scoring/config'),
  ///   headers: {'Authorization': 'Bearer $token'},
  /// );
  /// final json = jsonDecode(response.body);
  /// return ScoringConfig.fromJson(json);
  /// ```
  Future<ScoringConfig> loadFromBackend() async {
    // TODO: Implement backend API call
    throw UnimplementedError('Backend integration not yet implemented');
  }

  /// Load scoring config from local hardcoded constants
  ///
  /// This is the current implementation and serves as fallback.
  ScoringConfig loadFromLocal() {
    return ScoringConfig(
      promotedMultiplier: scoring_config.promotedMultiplier,
      neutralMultiplier: scoring_config.neutralMultiplier,
      suppressMultiplier: scoring_config.suppressMultiplier,
      defaultContextWeight: scoring_config.defaultContextWeight,
      defaultPopularityWeight: scoring_config.defaultPopularityWeight,
      neutralContextWeight: scoring_config.neutralContextWeight,
      neutralPopularityWeight: scoring_config.neutralPopularityWeight,
      noiseMax: scoring_config.noiseMax,
    );
  }
}

