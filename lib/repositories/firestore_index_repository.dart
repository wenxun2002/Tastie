import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tastie/models/card_data.dart';

class FirestoreIndexRepository {
  final FirebaseFirestore _db;
  final String collectionPath;

  FirestoreIndexRepository({
    FirebaseFirestore? db,
    // Home feed should show the real recipes users create.
    this.collectionPath = 'recipes',
  }) : _db = db ?? FirebaseFirestore.instance;

  Future<List<CardData>> getAll() async {
    final snapshot =
        await _db.collection(collectionPath).orderBy('createdAt', descending: true).get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return CardData.fromJson(_normalizeCardDataJson(doc.id, data));
    }).toList(growable: false);
  }

  Future<CardData?> getById(String id) async {
    final doc = await _db.collection(collectionPath).doc(id).get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    return CardData.fromJson(_normalizeCardDataJson(doc.id, data));
  }

  Map<String, dynamic> _normalizeCardDataJson(String docId, Map<String, dynamic> json) {
    int toInt(dynamic value) => (value as num?)?.toInt() ?? 0;

    final author = (json['author'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final images = (json['imageUrls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const <String>[];
    final tags = (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const <String>[];

    return <String, dynamic>{
      'id': docId,
      'uid': (json['userId'] ?? json['authorUid'] ?? '').toString(),
      'cover': images.isNotEmpty ? images.first : '',
      'title': (json['title'] ?? '').toString(),
      'content': (json['content'] ?? '').toString(),
      'avatar': (author['avatar'] ?? '').toString(),
      'nickname': (author['nickname'] ?? '').toString(),
      'fav': toInt(json['favCount'] ?? json['fav']),
      'like': toInt(json['likeCount'] ?? json['like']),
      'comment': toInt(json['commentCount'] ?? json['comment']),
      'tags': tags,
    };
  }
}

