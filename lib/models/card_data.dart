class CardData {
  /// Firestore document id.
  final String id;
  /// Firebase Auth uid of the author.
  final String uid;
  final String cover; // 封面图片
  final String title; // 标题
  final String content; // 内容描述
  final String avatar; // 用户头像
  final String nickname; // 用户昵称
  final int fav; // 收藏数
  final int like; // 点赞数
  final int comment; // 评论数
  final List<String> tags; // 标签列表

  CardData({
    required this.id,
    required this.uid,
    required this.cover,
    required this.title,
    required this.content,
    required this.avatar,
    required this.nickname,
    required this.fav,
    required this.like,
    required this.comment,
    required this.tags,
  });

  /// Parse tags from content string (comma-separated)
  /// Example: "Cooling, Hydrating, Light" → ["Cooling", "Hydrating", "Light"]
  static List<String> parseTagsFromContent(String content) {
    return content.split(',').map((tag) => tag.trim()).toList();
  }

  factory CardData.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic value) {
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value.trim()) ?? 0;
      return 0;
    }

    String asString(dynamic value) => value is String ? value : value?.toString() ?? '';

    final tagsRaw = json['tags'];
    final tags = tagsRaw is List
        ? tagsRaw.map((e) => e.toString()).toList(growable: false)
        : const <String>[];

    return CardData(
      id: asString(json['id']),
      uid: asString(json['uid']),
      cover: asString(json['cover']),
      title: asString(json['title']),
      content: asString(json['content']),
      avatar: asString(json['avatar']),
      nickname: asString(json['nickname']),
      fav: asInt(json['fav']),
      like: asInt(json['like']),
      comment: asInt(json['comment']),
      tags: tags,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uid': uid,
      'cover': cover,
      'title': title,
      'content': content,
      'avatar': avatar,
      'nickname': nickname,
      'fav': fav,
      'like': like,
      'comment': comment,
      'tags': tags,
    };
  }
}

