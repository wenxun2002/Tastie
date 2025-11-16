import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tastie/models/card_detail_data.dart';

/// Repository for loading card detail data from JSON
/// 
/// This mimics a future Firebase/backend data source.
/// To integrate with Firebase, replace loadFromAsset() with loadFromFirestore().
class MockCardDetailRepository {
  /// Load all card details from JSON file
  /// 
  /// Returns a list of all card details.
  /// Throws an exception if the JSON file cannot be loaded or parsed.
  Future<List<CardDetailData>> getAll() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/mock/card_detail_list.json',
      );
      final List<dynamic> jsonList = json.decode(jsonString);
      
      return jsonList
          .map((json) => CardDetailData.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load card detail data: $e');
    }
  }

  /// Get a single card detail by ID
  /// 
  /// Returns the card detail with the matching ID, or null if not found.
  Future<CardDetailData?> getById(int id) async {
    final allData = await getAll();
    try {
      return allData.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }
}

