import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tastie/models/card_data.dart';

class FirestoreIndexRepository {
  final FirebaseFirestore _db;
  final String collectionPath;

  FirestoreIndexRepository({
    FirebaseFirestore? db,
    this.collectionPath = 'index_cards',
  }) : _db = db ?? FirebaseFirestore.instance;

  Future<List<CardData>> getAll() async {
    final snapshot = await _db.collection(collectionPath).orderBy('id').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return CardData.fromJson(_normalizeCardDataJson(data));
    }).toList(growable: false);
  }

  Future<CardData?> getById(int id) async {
    final doc = await _db.collection(collectionPath).doc(id.toString()).get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    return CardData.fromJson(_normalizeCardDataJson(data));
  }

  Map<String, dynamic> _normalizeCardDataJson(Map<String, dynamic> json) {
    int toInt(dynamic value) => (value as num).toInt();

    return <String, dynamic>{
      ...json,
      'id': toInt(json['id']),
      'uid': toInt(json['uid']),
      'fav': toInt(json['fav']),
      'like': toInt(json['like']),
      'comment': toInt(json['comment'] ?? 0),
      'tags': (json['tags'] as List<dynamic>).map((e) => e.toString()).toList(),
    };
  }
}

