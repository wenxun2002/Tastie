import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tastie/models/card_detail_data.dart';

class FirestoreCardDetailRepository {
  final FirebaseFirestore _db;
  final String collectionPath;

  FirestoreCardDetailRepository({
    FirebaseFirestore? db,
    this.collectionPath = 'card_details',
  }) : _db = db ?? FirebaseFirestore.instance;

  Future<List<CardDetailData>> getAll() async {
    final snapshot = await _db.collection(collectionPath).orderBy('id').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return CardDetailData.fromJson(_normalizeCardDetailJson(data));
    }).toList(growable: false);
  }

  Future<CardDetailData?> getById(int id) async {
    final doc = await _db.collection(collectionPath).doc(id.toString()).get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    return CardDetailData.fromJson(_normalizeCardDetailJson(data));
  }

  Map<String, dynamic> _normalizeCardDetailJson(Map<String, dynamic> json) {
    int toInt(dynamic value) => (value as num).toInt();
    double toDouble(dynamic value) => (value as num).toDouble();

    final ingredients = (json['ingredients'] as List<dynamic>).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return <String, dynamic>{
        ...m,
        'amount': toDouble(m['amount']),
      };
    }).toList();

    final nutritionRaw = json['nutrition'];
    final nutrition = nutritionRaw == null
        ? null
        : (() {
            final m = Map<String, dynamic>.from(nutritionRaw as Map);
            return <String, dynamic>{
              ...m,
              'calories': toInt(m['calories']),
              'fat': toDouble(m['fat']),
              'carbs': toDouble(m['carbs']),
              'fiber': toDouble(m['fiber']),
              'sugar': toDouble(m['sugar']),
              'protein': toDouble(m['protein']),
            };
          })();

    return <String, dynamic>{
      ...json,
      'id': toInt(json['id']),
      'uid': toInt(json['uid']),
      'fav': toInt(json['fav']),
      'like': toInt(json['like']),
      'commentCount': toInt(json['commentCount'] ?? 0),
      'images':
          (json['images'] as List<dynamic>).map((e) => e.toString()).toList(),
      'tags': (json['tags'] as List<dynamic>).map((e) => e.toString()).toList(),
      'ingredients': ingredients,
      'procedures': (json['procedures'] as List<dynamic>)
          .map((e) => e.toString())
          .toList(),
      'nutrition': nutrition,
      'author': Map<String, dynamic>.from(json['author'] as Map),
    };
  }
}

