import 'package:tastie/models/recipe_click_metrics.dart';

/// Represents a recipe document in Firestore `recipes` collection.
/// Used when creating and reading recipes (Create → Firestore, My Recipe → list/detail).
class RecipeFirestore {
  const RecipeFirestore({
    this.id,
    required this.userId,
    required this.authorNickname,
    required this.authorAvatar,
    required this.imageUrls,
    required this.title,
    required this.content,
    required this.tags,
    required this.ingredients,
    required this.procedures,
    this.nutrition,
    required this.likeCount,
    required this.favCount,
    required this.commentCount,
    this.status,
    this.clickMetrics = RecipeClickMetrics.zero,
    this.createdAt,
  });

  /// Firestore document ID (null when creating, set after add).
  final String? id;
  /// Firebase Auth UID of the author.
  final String userId;
  final String authorNickname;
  final String authorAvatar;
  final List<String> imageUrls;
  final String title;
  final String content;
  final List<String> tags;
  final List<Map<String, dynamic>> ingredients;
  final List<String> procedures;
  final Map<String, dynamic>? nutrition;
  /// Aggregated counts (source of truth for UI list/detail).
  final int likeCount;
  final int favCount;
  final int commentCount;
  /// Admin moderation: `active` / `banned`. Null/empty treated as active (legacy docs).
  final String? status;
  /// Click breakdown (`click_metrics`). Maintained by Cloud Functions from `recipe_click_events`.
  final RecipeClickMetrics clickMetrics;
  /// Firestore Timestamp or milliseconds since epoch. Null when creating (server sets it).
  final dynamic createdAt;

  bool get isHiddenFromPublicCatalog =>
      (status ?? '').toString().toLowerCase() == 'banned';

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'userId': userId,
      'authorUid': userId,
      'author': <String, dynamic>{
        'nickname': authorNickname,
        'avatar': authorAvatar,
      },
      'imageUrls': imageUrls,
      'title': title,
      'content': content,
      'tags': tags,
      'ingredients': ingredients,
      'procedures': procedures,
      if (nutrition != null) 'nutrition': nutrition,
      'likeCount': likeCount,
      'favCount': favCount,
      'commentCount': commentCount,
      if (status != null) 'status': status,
      'click_metrics': clickMetrics.toFirestoreMap(),
      if (createdAt != null) 'createdAt': createdAt,
    };
  }

  Map<String, dynamic> toFirestore() => toJson();

  static Map<String, dynamic> _asStringKeyedMap(dynamic value) {
    if (value is! Map) return const <String, dynamic>{};
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static List<String> _asStringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value.map((item) => item.toString()).toList(growable: false);
  }

  static List<Map<String, dynamic>> _parseIngredients(dynamic value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
        .toList(growable: false);
  }

  static int _asInt(dynamic value) {
    return value is num ? value.toInt() : 0;
  }

  static String _asString(dynamic value) {
    return value is String ? value : '';
  }

  static RecipeClickMetrics _parseClickMetrics(Map<String, dynamic> data) {
    final raw = data['click_metrics'];
    if (raw is Map) {
      return RecipeClickMetrics.fromFirestoreMap(
        _asStringKeyedMap(raw),
      );
    }
    final legacy = _asInt(data['clicked']);
    return RecipeClickMetrics(
      weatherPromoted: 0,
      weatherNotPromoted: 0,
      normalBrowse: 0,
      search: 0,
      total: legacy,
    );
  }

  /// Build from Firestore document (doc.id + doc.data()).
  factory RecipeFirestore.fromFirestore(String docId, Map<String, dynamic> data) {
    final author = _asStringKeyedMap(data['author']);
    return RecipeFirestore(
      id: docId,
      userId: _asString(data['userId']),
      authorNickname: _asString(author['nickname']),
      authorAvatar: _asString(author['avatar']),
      imageUrls: _asStringList(data['imageUrls']),
      title: _asString(data['title']),
      content: _asString(data['content']),
      tags: _asStringList(data['tags']),
      ingredients: _parseIngredients(data['ingredients']),
      procedures: _asStringList(data['procedures']),
      nutrition: data['nutrition'] is Map
          ? _asStringKeyedMap(data['nutrition'])
          : null,
      likeCount: _asInt(data['likeCount']),
      favCount: _asInt(data['favCount']),
      commentCount: _asInt(data['commentCount']),
      status: data['status'] is String ? data['status'] as String : null,
      clickMetrics: _parseClickMetrics(data),
      createdAt: data['createdAt'],
    );
  }
}
