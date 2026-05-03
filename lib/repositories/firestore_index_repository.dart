import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tastie/models/card_data.dart';
import 'package:tastie/repositories/paginated_posts_result.dart';

class FirestoreIndexRepository {
  final FirebaseFirestore _db;
  final String collectionPath;

  FirestoreIndexRepository({
    FirebaseFirestore? db,
    // Home feed should show the real recipes users create.
    this.collectionPath = 'recipes',
  }) : _db = db ?? FirebaseFirestore.instance;

  /// Explore feed: cursor pagination by [createdAt] descending (newest first).
  ///
  /// [startAfterDocument] is the last document from the previous page; `null` loads the first page.
  Future<PaginatedPostsResult> getPostsPaginated({
    int limit = 10,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
  }) async {
    Query<Map<String, dynamic>> query = _db
        .collection(collectionPath)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfterDocument != null) {
      query = query.startAfterDocument(startAfterDocument);
    }

    final snapshot = await query.get();
    final docs = snapshot.docs;

    final items = docs
        .map((doc) => CardData.fromJson(_normalizeCardDataJson(doc.id, doc.data())))
        .toList(growable: false);

    final hasMore = docs.length == limit;
    final DocumentSnapshot<Map<String, dynamic>>? lastDocument =
        docs.isEmpty ? null : docs.last;

    return PaginatedPostsResult(
      items: items,
      hasMore: hasMore,
      lastDocument: lastDocument,
    );
  }

  /// Full collection read — avoid for Explore; use [getPostsPaginated] instead.
  @Deprecated('Use getPostsPaginated for the Explore feed')
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

