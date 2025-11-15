class CardData {
  final int id;
  final int uid;
  final String cover; // 封面图片
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
}

