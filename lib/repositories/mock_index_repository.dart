import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tastie/models/card_data.dart';

/// Repository for loading index list data from JSON
/// 
/// This mimics a future Firebase/backend data source.
/// To integrate with Firebase, replace loadFromAsset() with loadFromFirestore().
class MockIndexRepository {
  /// Load all index cards from JSON file
  /// 
  /// Returns a list of all card data.
  /// Throws an exception if the JSON file cannot be loaded or parsed.
  Future<List<CardData>> getAll() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/mock/index_list.json',
      );
      final List<dynamic> jsonList = json.decode(jsonString);
      
      return jsonList
          .map((json) => CardData.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load index list data: $e');
    }
  }

  /// Get a single card by ID
  /// 
  /// Returns the card with the matching ID, or null if not found.
  Future<CardData?> getById(int id) async {
    final allData = await getAll();
    try {
      return allData.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }
}

