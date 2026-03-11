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
    return CardData(
      id: json['id'] as String,
      uid: json['uid'] as String,
      cover: json['cover'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      avatar: json['avatar'] as String,
      nickname: json['nickname'] as String,
      fav: json['fav'] as int,
      like: json['like'] as int,
      comment: json['comment'] as int? ?? 0, // Optional: defaults to 0 if not present
      tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
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

