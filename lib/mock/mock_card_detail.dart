import 'package:tastie/models/card_detail_data.dart';
import 'package:tastie/models/comment.dart';

class MockCardDetail {
  // 辅助函数：从 title 生成 tags
  static List<String> _generateTagsFromTitle(String title) {
    return title.split(',').map((tag) => tag.trim()).toList();
  }

  // 生成示例配料列表
  static List<Ingredient> _generateIngredients() {
    return [
      Ingredient(name: "Sugar", amount: 200, unit: "g"),
      Ingredient(name: "Butter", amount: 500, unit: "g"),
      Ingredient(name: "Egg", amount: 1, unit: "pcs"),
      Ingredient(name: "Cake Flour", amount: 1.2, unit: "kg"),
      Ingredient(name: "Vanilla extract", amount: 0, unit: "few drops"),
      Ingredient(name: "Milk", amount: 1200, unit: "ml"),
      Ingredient(name: "Water", amount: 2, unit: "spoons"),
      Ingredient(name: "Garlic, minced", amount: 20, unit: "g"),
    ];
  }

  // 生成示例步骤列表
  static List<String> _generateProcedures() {
    return [
      "Combine cake mix, chocolate chips, oil, and eggs in a mixing bowl.",
      "Using an ice cream scoop or your hand, form golf ball-sized balls of cookie dough and transfer to a parchment paper-lined baking sheet.",
      "Bake at 350°C for 10-12 minutes.",
    ];
  }

  // 生成示例营养信息
  static Nutrition _generateNutrition() {
    return Nutrition(
      calories: 500,
      fat: 8,
      carbs: 37,
      fiber: 28,
      sugar: 23,
      protein: 3,
    );
  }

  // MIGRATED TO JSON — This data has been moved to assets/mock/card_detail_list.json
  // Use MockCardDetailRepository to load data from JSON instead
  // This is kept for reference only
  /*
  static List<CardDetailData> cardDetailDataList = [
    CardDetailData(
      id: 1,
      uid: 1000,
      title: "Comfort",
      content:
          "This is a detailed content about Comfort. It can be a long description about the product or experience.",
      avatar: "assets/images/Frame 22.png",
      nickname: "Tastie user 1",
      fav: 119,
      like: 10,
      comment: 2,
      date: "2023-08-09 10:54:27",
      address: "Malaysia",
      images: [
        "assets/images/Cover/Comfort.png",
        "assets/images/Cover/Comfort.png",
      ],
      tags: _generateTagsFromTitle("Comfort"),
      ingredients: _generateIngredients(),
      procedures: _generateProcedures(),
      nutrition: _generateNutrition(),
    ),
    CardDetailData(
      id: 2,
      uid: 1001,
      title: "Cooling, Hydrating, Light",
      content:
          "This is a detailed content about Cooling, Hydrating, Light. It can be a long description about the product or experience.",
      avatar: "assets/images/image 13 1.png",
      nickname: "Tastie user 2",
      fav: 39,
      like: 12,
      comment: 0,
      date: "2023-08-07 06:24:27",
      address: "Malaysia",
      images: [
        "assets/images/Cover/Cooling,Hydrating,Light.png",
        "assets/images/Cover/Cooling,Hydrating,Light.png",
        "assets/images/Cover/Cooling,Hydrating,Light.png",
      ],
      tags: _generateTagsFromTitle("Cooling, Hydrating, Light"),
      ingredients: _generateIngredients(),
      procedures: _generateProcedures(),
      nutrition: _generateNutrition(),
    ),
    CardDetailData(
      id: 3,
      uid: 1003,
      title: "Cooling, Hydrating",
      content:
          "This is a detailed content about Cooling, Hydrating. It can be a long description about the product or experience.",
      avatar: "assets/images/Frame 22.png",
      nickname: "Tastie user 3",
      fav: 983,
      like: 13,
      comment: 1,
      date: "2023-06-07 09:24:27",
      address: "Malaysia",
      images: [
        "assets/images/Cover/Cooling,Hydrating.png",
      ],
      tags: _generateTagsFromTitle("Cooling, Hydrating"),
      ingredients: _generateIngredients(),
      procedures: _generateProcedures(),
      nutrition: _generateNutrition(),
    ),
    CardDetailData(
      id: 4,
      uid: 1004,
      title: "Energy, Comfort",
      content:
          "This is a detailed content about Energy, Comfort. It can be a long description about the product or experience.",
      avatar: "assets/images/image 13 1.png",
      nickname: "Tastie user 4",
      fav: 81381,
      like: 93,
      comment: 17,
      date: "2023-06-09 16:54:27",
      address: "Malaysia",
      images: [
        "assets/images/Cover/Energy,Comfort.png",
      ],
      tags: _generateTagsFromTitle("Energy, Comfort"),
      ingredients: _generateIngredients(),
      procedures: _generateProcedures(),
      nutrition: _generateNutrition(),
    ),
    CardDetailData(
      id: 5,
      uid: 1005,
      title: "Energy",
      content:
          "This is a detailed content about Energy. It can be a long description about the product or experience.",
      avatar: "assets/images/Frame 22.png",
      nickname: "Tastie user 5",
      fav: 1837,
      like: 31,
      comment: 5,
      date: "2023-06-09 16:54:27",
      address: "Malaysia",
      images: [
        "assets/images/Cover/Energy.png",
        "assets/images/Cover/Energy.png",
        "assets/images/Cover/Energy.png",
        "assets/images/Cover/Energy.png",
      ],
      tags: _generateTagsFromTitle("Energy"),
      ingredients: _generateIngredients(),
      procedures: _generateProcedures(),
      nutrition: _generateNutrition(),
    ),
    CardDetailData(
      id: 6,
      uid: 1006,
      title: "Hydrating, Cooling",
      content:
          "This is a detailed content about Hydrating, Cooling. It can be a long description about the product or experience.",
      avatar: "assets/images/image 13 1.png",
      nickname: "Tastie user 6",
      fav: 1237,
      like: 63,
      comment: 6,
      date: "2023-06-15 16:54:27",
      address: "Malaysia",
      images: [
        "assets/images/Cover/Hydrating,Cooling.png",
        "assets/images/Cover/Hydrating,Cooling.png",
        "assets/images/Cover/Hydrating,Cooling.png",
        "assets/images/Cover/Hydrating,Cooling.png",
      ],
      tags: _generateTagsFromTitle("Hydrating, Cooling"),
      ingredients: _generateIngredients(),
      procedures: _generateProcedures(),
      nutrition: _generateNutrition(),
    ),
    CardDetailData(
      id: 7,
      uid: 1007,
      title: "Hydrating",
      content:
          "This is a detailed content about Hydrating. It can be a long description about the product or experience.",
      avatar: "assets/images/Frame 22.png",
      nickname: "Tastie user 7",
      fav: 456,
      like: 28,
      comment: 3,
      date: "2023-06-15 16:54:27",
      address: "Malaysia",
      images: [
        "assets/images/Cover/Hydrating.png",
      ],
      tags: _generateTagsFromTitle("Hydrating"),
      ingredients: _generateIngredients(),
      procedures: _generateProcedures(),
      nutrition: _generateNutrition(),
    ),
    CardDetailData(
      id: 8,
      uid: 1008,
      title: "Light, Comfort",
      content:
          "This is a detailed content about Light, Comfort. It can be a long description about the product or experience.",
      avatar: "assets/images/image 13 1.png",
      nickname: "Tastie user 8",
      fav: 789,
      like: 45,
      comment: 8,
      date: "2023-06-15 16:54:27",
      address: "Malaysia",
      images: [
        "assets/images/Cover/Light,Comfort.png",
        "assets/images/Cover/Light,Comfort.png",
      ],
      tags: _generateTagsFromTitle("Light, Comfort"),
      ingredients: _generateIngredients(),
      procedures: _generateProcedures(),
      nutrition: _generateNutrition(),
    ),
    CardDetailData(
      id: 9,
      uid: 1009,
      title: "Light, Hydrating",
      content:
          "This is a detailed content about Light, Hydrating. It can be a long description about the product or experience.",
      avatar: "assets/images/Frame 22.png",
      nickname: "Tastie user 9",
      fav: 234,
      like: 19,
      comment: 4,
      date: "2023-06-15 16:54:27",
      address: "Malaysia",
      images: [
        "assets/images/Cover/Light,Hydrating.png",
      ],
      tags: _generateTagsFromTitle("Light, Hydrating"),
      ingredients: _generateIngredients(),
      procedures: _generateProcedures(),
      nutrition: _generateNutrition(),
    ),
    CardDetailData(
      id: 10,
      uid: 1010,
      title: "Light, Warming",
      content:
          "This is a detailed content about Light, Warming. It can be a long description about the product or experience.",
      avatar: "assets/images/image 13 1.png",
      nickname: "Tastie user 10",
      fav: 567,
      like: 37,
      comment: 7,
      date: "2023-06-15 16:54:27",
      address: "Malaysia",
      images: [
        "assets/images/Cover/Light,Warming.png",
        "assets/images/Cover/Light,Warming.png",
        "assets/images/Cover/Light,Warming.png",
      ],
      tags: _generateTagsFromTitle("Light, Warming"),
      ingredients: _generateIngredients(),
      procedures: _generateProcedures(),
      nutrition: _generateNutrition(),
    ),
    CardDetailData(
      id: 11,
      uid: 1011,
      title: "Warming, Comfort",
      content:
          "This is a detailed content about Warming, Comfort. It can be a long description about the product or experience.",
      avatar: "assets/images/Frame 22.png",
      nickname: "Tastie user 11",
      fav: 890,
      like: 52,
      comment: 9,
      date: "2023-06-15 16:54:27",
      address: "Malaysia",
      images: [
        "assets/images/Cover/Warming,Comfort 2.png",
      ],
      tags: _generateTagsFromTitle("Warming, Comfort"),
      ingredients: _generateIngredients(),
      procedures: _generateProcedures(),
      nutrition: _generateNutrition(),
    ),
    CardDetailData(
      id: 12,
      uid: 1012,
      title: "Warming, Comfort",
      content:
          "This is a detailed content about Warming, Comfort. It can be a long description about the product or experience.",
      avatar: "assets/images/image 13 1.png",
      nickname: "Tastie user 12",
      fav: 345,
      like: 24,
      comment: 5,
      date: "2023-06-15 16:54:27",
      address: "Malaysia",
      images: [
        "assets/images/Cover/Warming,Comfort.png",
        "assets/images/Cover/Warming,Comfort.png",
      ],
      tags: _generateTagsFromTitle("Warming, Comfort"),
      ingredients: _generateIngredients(),
      procedures: _generateProcedures(),
      nutrition: _generateNutrition(),
    ),
    CardDetailData(
      id: 13,
      uid: 1013,
      title: "Warming, Energy, Comfort",
      content:
          "This is a detailed content about Warming, Energy, Comfort. It can be a long description about the product or experience.",
      avatar: "assets/images/Frame 22.png",
      nickname: "Tastie user 13",
      fav: 678,
      like: 41,
      comment: 6,
      date: "2023-06-15 16:54:27",
      address: "Malaysia",
      images: [
        "assets/images/Cover/Warming,Energy,Comfort.png",
      ],
      tags: _generateTagsFromTitle("Warming, Energy, Comfort"),
      ingredients: _generateIngredients(),
      procedures: _generateProcedures(),
      nutrition: _generateNutrition(),
    ),
    CardDetailData(
      id: 14,
      uid: 1014,
      title: "Warming",
      content:
          "This is a detailed content about Warming. It can be a long description about the product or experience.",
      avatar: "assets/images/image 13 1.png",
      nickname: "Tastie user 14",
      fav: 912,
      like: 58,
      comment: 10,
      date: "2023-06-15 16:54:27",
      address: "Malaysia",
      images: [
        "assets/images/Cover/Warming.png",
        "assets/images/Cover/Warming.png",
        "assets/images/Cover/Warming.png",
      ],
      tags: _generateTagsFromTitle("Warming"),
      ingredients: _generateIngredients(),
      procedures: _generateProcedures(),
      nutrition: _generateNutrition(),
    ),
  ];
  */

  // Empty list as fallback - data now loaded from JSON via MockCardDetailRepository
  static List<CardDetailData> cardDetailDataList = [];

  // COMMENT FEATURE DISABLED — RESERVED FOR FUTURE USE
  // Comment data is commented out but structure preserved for future re-enabling
  // Uncomment to re-enable comment feature
  /*
  static List<Comment> commentList = [
    Comment(
      id: 1,
      nickname: "Alice",
      avatar: "assets/images/Frame 22.png",
      content: "noneed to care",
      createDate: "2023-06-15 16:54:27",
      like: 1,
      isLike: false,
      address: "Malaysia",
    ),
    Comment(
      id: 2,
      nickname: "momo",
      avatar: "assets/images/image 13 1.png",
      content:
          "This is test content, idk can how long so test only,testttttttttttttttttttttttttt onlyyyyyyyyyyyyyyyyy",
      createDate: "2023-06-17 16:54:27",
      like: 6,
      isLike: false,
      address: "Malaysia",
    ),
  ];
  */

  // Empty list as fallback for disabled comment feature
  static List<Comment> commentList = [];
}
