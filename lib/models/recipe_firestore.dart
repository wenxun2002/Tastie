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
    this.clicked = 0,
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
  /// Implicit feedback: Explore 详情打开次数（`FieldValue.increment` 维护）。
  final int clicked;
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
      'clicked': clicked,
      if (createdAt != null) 'createdAt': createdAt,
    };
  }

  Map<String, dynamic> toFirestore() => toJson();

  /// Build from Firestore document (doc.id + doc.data()).
  factory RecipeFirestore.fromFirestore(String docId, Map<String, dynamic> data) {
    final author = data['author'] as Map<String, dynamic>? ?? {};
    final ingredients = (data['ingredients'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
    return RecipeFirestore(
      id: docId,
      userId: data['userId'] as String? ?? '',
      authorNickname: author['nickname'] as String? ?? '',
      authorAvatar: author['avatar'] as String? ?? '',
      imageUrls: (data['imageUrls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      title: data['title'] as String? ?? '',
      content: data['content'] as String? ?? '',
      tags: (data['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      ingredients: ingredients,
      procedures: (data['procedures'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      nutrition: data['nutrition'] != null
          ? Map<String, dynamic>.from(data['nutrition'] as Map)
          : null,
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      favCount: (data['favCount'] as num?)?.toInt() ?? 0,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      status: data['status'] as String?,
      clicked: (data['clicked'] as num?)?.toInt() ?? 0,
      createdAt: data['createdAt'],
    );
  }
}
