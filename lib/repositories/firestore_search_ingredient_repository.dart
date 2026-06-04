import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:tastie/data/search_ingredient_defaults.dart';

/// Reads admin-managed ingredients from Firestore `Search_ingredient`.
class FirestoreSearchIngredientRepository {
  FirestoreSearchIngredientRepository({
    FirebaseFirestore? firestore,
    this.collectionPath = 'Search_ingredient',
  }) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final String collectionPath;

  /// Active ingredients only, sorted by [sortOrder] then name.
  Future<List<String>> fetchActiveIngredientNames() async {
    final snap = await _db.collection(collectionPath).get();

    final entries = <({String name, int sortOrder})>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      if (data['active'] == false) continue;
      final name = (data['name'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      final sortOrder = (data['sortOrder'] as num?)?.toInt() ?? 0;
      entries.add((name: name, sortOrder: sortOrder));
    }

    entries.sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      if (byOrder != 0) return byOrder;
      return compareIngredientNames(a.name, b.name);
    });

    return entries.map((e) => e.name).toList(growable: false);
  }

  List<String> fallbackNames() => List<String>.from(kFallbackSearchIngredientNames);
}
