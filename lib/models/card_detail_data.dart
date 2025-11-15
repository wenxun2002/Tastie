class CardDetailData {
  final int id;
  final int uid;
  final String title;
  final String content;
  final String avatar;
  final String nickname;
  final int fav;
  final int like;
  final int comment;
  final String date;
  final String address;
  final List<String> images;
  final List<String> tags; // 标签列表

  CardDetailData({
    required this.id,
    required this.uid,
    required this.title,
    required this.content,
    required this.avatar,
    required this.nickname,
    required this.fav,
    required this.like,
    required this.comment,
    required this.date,
    required this.address,
    required this.images,
    required this.tags,
  });
}
