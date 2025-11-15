class Ingredient {
  final String name;
  final double amount;
  final String unit;

  Ingredient({
    required this.name,
    required this.amount,
    required this.unit,
  });
}

class Nutrition {
  final int calories;
  final double fat;
  final double carbs;
  final double fiber;
  final double sugar;
  final double protein;

  Nutrition({
    required this.calories,
    required this.fat,
    required this.carbs,
    required this.fiber,
    required this.sugar,
    required this.protein,
  });
}

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
  final List<Ingredient> ingredients; // 配料列表
  final List<String> procedures; // 步骤列表
  final Nutrition? nutrition; // 营养信息（可选）

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
    required this.ingredients,
    required this.procedures,
    this.nutrition,
  });
}
