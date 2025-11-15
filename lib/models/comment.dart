class Comment {
  final int id;
  final String nickname;
  final String avatar;
  final String content;
  final String createDate;
  final int like;
  final bool isLike;
  final String address;

  Comment({
    required this.id,
    required this.nickname,
    required this.avatar,
    required this.content,
    required this.createDate,
    required this.like,
    this.isLike = false,
    required this.address,
  });
}

