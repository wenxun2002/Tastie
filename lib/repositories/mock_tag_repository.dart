import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:tastie/models/tag_item.dart';

/// Repository that loads tag definitions from a mock JSON file.
/// This simulates what a future backend endpoint would return.
class MockTagRepository {
  final String assetPath;

  const MockTagRepository({
    this.assetPath = 'assets/mock/tag_list.json',
  });

  Future<List<TagItem>> getAll() async {
    try {
      final String jsonString = await rootBundle.loadString(assetPath);
      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;

      return jsonList
          .map((dynamic json) =>
              TagItem.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load tag list: $e');
    }
  }
}

