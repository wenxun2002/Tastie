import 'package:flutter_test/flutter_test.dart';
import 'package:tastie/models/card_data.dart';
import 'package:tastie/models/recipe_firestore.dart';

void main() {
  test('RecipeFirestore.fromFirestore tolerates poisoned author/ingredients/nutrition', () {
    final recipe = RecipeFirestore.fromFirestore('r1', <String, dynamic>{
      'userId': 'alice',
      'author': 'not-a-map',
      'imageUrls': 'not-a-list',
      'title': 42,
      'content': null,
      'tags': 'Cooling',
      'ingredients': <dynamic>['flour', {'name': 'egg', 'amount': 1, 'unit': 'whole'}],
      'procedures': <dynamic>['Mix', 3],
      'nutrition': 'bad',
      'likeCount': '12',
      'favCount': true,
      'commentCount': null,
      'clicked': '7',
      'status': 1,
    });

    expect(recipe.id, 'r1');
    expect(recipe.userId, 'alice');
    expect(recipe.authorNickname, '');
    expect(recipe.imageUrls, isEmpty);
    expect(recipe.title, '');
    expect(recipe.content, '');
    expect(recipe.tags, isEmpty);
    expect(recipe.ingredients, hasLength(1));
    expect(recipe.ingredients.first['name'], 'egg');
    expect(recipe.procedures, <String>['Mix', '3']);
    expect(recipe.nutrition, isNull);
    expect(recipe.likeCount, 12);
    expect(recipe.favCount, 0);
    expect(recipe.commentCount, 0);
    expect(recipe.clickMetrics.total, 7);
    expect(recipe.status, isNull);
  });

  test('CardData.fromJson tolerates string counters and non-list tags', () {
    final card = CardData.fromJson(<String, dynamic>{
      'id': 'c1',
      'uid': 'alice',
      'cover': '',
      'title': 'Soup',
      'content': 'Warm',
      'avatar': '',
      'nickname': 'Alice',
      'fav': '3',
      'like': '9',
      'comment': '1',
      'tags': 'Cooling',
    });

    expect(card.fav, 3);
    expect(card.like, 9);
    expect(card.comment, 1);
    expect(card.tags, isEmpty);
  });
}
