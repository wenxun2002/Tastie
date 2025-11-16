class Ingredient {
  final String name;
  final double amount;
  final String unit;

  Ingredient({
    required this.name,
    required this.amount,
    required this.unit,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      name: json['name'] as String,
      amount: (json['amount'] as num).toDouble(),
      unit: json['unit'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'unit': unit,
    };
  }
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

  factory Nutrition.fromJson(Map<String, dynamic> json) {
    return Nutrition(
      calories: json['calories'] as int,
      fat: (json['fat'] as num).toDouble(),
      carbs: (json['carbs'] as num).toDouble(),
      fiber: (json['fiber'] as num).toDouble(),
      sugar: (json['sugar'] as num).toDouble(),
      protein: (json['protein'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'fat': fat,
      'carbs': carbs,
      'fiber': fiber,
      'sugar': sugar,
      'protein': protein,
    };
  }
}

class Author {
  final String nickname;
  final String avatar;

  Author({
    required this.nickname,
    required this.avatar,
  });

  factory Author.fromJson(Map<String, dynamic> json) {
    return Author(
      nickname: json['nickname'] as String,
      avatar: json['avatar'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nickname': nickname,
      'avatar': avatar,
    };
  }
}

class CardDetailData {
  final int id;
  final int uid;
  final String title;
  final String content;
  final Author author;
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
    required this.author,
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

  // Backward compatibility getters for existing UI code
  String get avatar => author.avatar;
  String get nickname => author.nickname;

  factory CardDetailData.fromJson(Map<String, dynamic> json) {
    return CardDetailData(
      id: json['id'] as int,
      uid: json['uid'] as int,
      title: json['title'] as String,
      content: json['content'] as String,
      author: Author.fromJson(json['author'] as Map<String, dynamic>),
      fav: json['fav'] as int,
      like: json['like'] as int,
      comment: json['commentCount'] as int? ??
          0, // Optional: defaults to 0 if not present
      date: json['date'] as String,
      address: json['address'] as String,
      images:
          (json['images'] as List<dynamic>).map((e) => e as String).toList(),
      tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
      ingredients: (json['ingredients'] as List<dynamic>)
          .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
          .toList(),
      procedures: (json['procedures'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      nutrition: json['nutrition'] != null
          ? Nutrition.fromJson(json['nutrition'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uid': uid,
      'title': title,
      'content': content,
      'author': author.toJson(),
      'fav': fav,
      'like': like,
      'commentCount': comment,
      'date': date,
      'address': address,
      'images': images,
      'tags': tags,
      'ingredients': ingredients.map((e) => e.toJson()).toList(),
      'procedures': procedures,
      'nutrition': nutrition?.toJson(),
    };
  }
}
