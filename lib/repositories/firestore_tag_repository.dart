import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tastie/models/tag_item.dart';

class FirestoreTagRepository {
  final FirebaseFirestore _db;
  final String collectionPath;

  FirestoreTagRepository({
    FirebaseFirestore? db,
    this.collectionPath = 'tags',
  }) : _db = db ?? FirebaseFirestore.instance;

  Future<List<TagItem>> getAll() async {
    final snapshot = await _db.collection(collectionPath).orderBy('id').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return TagItem.fromJson(_normalizeTagJson(data));
    }).toList(growable: false);
  }

  Map<String, dynamic> _normalizeTagJson(Map<String, dynamic> json) {
    int toInt(dynamic value) => (value as num).toInt();
    return <String, dynamic>{
      ...json,
      'id': toInt(json['id']),
      'defaultEnabled': (json['defaultEnabled'] as bool?) ?? false,
    };
  }
}

