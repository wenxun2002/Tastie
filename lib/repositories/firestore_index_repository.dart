import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tastie/models/card_data.dart';
import 'package:tastie/repositories/paginated_posts_result.dart';
import 'package:tastie/utils/recipe_catalog_policy.dart';

/// Sort fields for Explore list (Firestore `orderBy`).
enum ExploreFeedSort {
  /// `orderBy('createdAt', descending: true)` — non-neutral weather, default within each tag layer.
  byCreatedAtDesc,

  /// `orderBy('likeCount', descending: true)` — **neutral** weather, all library by popularity.
  ///
  /// Ensure `recipes` documents contain the numeric field `likeCount` (or only documents participating in sorting contain this field).
  byLikeCountDesc,
}

class FirestoreIndexRepository {
  final FirebaseFirestore _db;
  final String collectionPath;

  FirestoreIndexRepository({
    FirebaseFirestore? db,
    this.collectionPath = 'recipes',
  }) : _db = db ?? FirebaseFirestore.instance;

  /// Explore feed: optional `tags` filter + pagination cursor + sorting.
  ///
  /// **Index hints**
  /// - `arrayContainsAny` + `orderBy('createdAt')` → composite index: `tags` + `createdAt` descending.
  /// - Only `orderBy('likeCount')`, no `where` → typically auto-single-field index; if console prompts, rebuild.
  /// - `arrayContainsAny` + `orderBy('likeCount')` → composite index (current neutral does not filter by tags).
  Future<PaginatedPostsResult> getPostsPaginated({
    int limit = 10,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
    List<String>? filterTags,
    ExploreFeedSort sort = ExploreFeedSort.byCreatedAtDesc,
  }) async {
    final String orderField = sort == ExploreFeedSort.byLikeCountDesc
        ? 'likeCount'
        : 'createdAt';

    /// Fetch more to filter `banned`, avoid "multiple banned cards in one page of 10" showing insufficient cards.
    final int batchSize = (limit * 4).clamp(20, 80);
    const int maxBatches = 24;

    final items = <CardData>[];
    DocumentSnapshot<Map<String, dynamic>>? cursor = startAfterDocument;
    DocumentSnapshot<Map<String, dynamic>>? lastConsumed;
    var batchFull = false;
    /// This batch of Firestore documents was not fully scanned due to [limit] stopping (e.g., 28 < 40 in the entire library).
    var hasUnprocessedDocsInLastBatch = false;

    for (var b = 0; b < maxBatches && items.length < limit; b++) {
      Query<Map<String, dynamic>> query = _db.collection(collectionPath);

      if (filterTags != null && filterTags.isNotEmpty) {
        query = query.where('tags', arrayContainsAny: filterTags);
      }

      query = query.orderBy(orderField, descending: true);
      if (cursor != null) {
        query = query.startAfterDocument(cursor);
      }
      query = query.limit(batchSize);

      final snapshot = await query.get();
      final docs = snapshot.docs;
      if (docs.isEmpty) {
        batchFull = false;
        break;
      }

      batchFull = docs.length == batchSize;
      cursor = docs.last;
      hasUnprocessedDocsInLastBatch = false;

      for (var i = 0; i < docs.length; i++) {
        final doc = docs[i];
        lastConsumed = doc;
        final data = doc.data();
        if (!recipeDocIsPublicCatalogVisible(data)) continue;
        items.add(CardData.fromJson(_normalizeCardDataJson(doc.id, data)));
        if (items.length >= limit) {
          hasUnprocessedDocsInLastBatch = i < docs.length - 1;
          break;
        }
      }

      if (items.length >= limit) {
        break;
      }
    }

    /// Full page and (server may still have subsequent batches **or** unprocessed documents in this batch).
    final hasMore =
        items.length == limit && (batchFull || hasUnprocessedDocsInLastBatch);

    return PaginatedPostsResult(
      items: items,
      hasMore: hasMore,
      lastDocument: lastConsumed,
    );
  }

  @Deprecated('Use getPostsPaginated for the Explore feed')
  Future<List<CardData>> getAll() async {
    final snapshot =
        await _db.collection(collectionPath).orderBy('createdAt', descending: true).get();
    return snapshot.docs
        .where((doc) => recipeDocIsPublicCatalogVisible(doc.data()))
        .map((doc) {
      final data = doc.data();
      return CardData.fromJson(_normalizeCardDataJson(doc.id, data));
    }).toList(growable: false);
  }

  Future<CardData?> getById(String id) async {
    final doc = await _db.collection(collectionPath).doc(id).get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    if (!recipeDocIsPublicCatalogVisible(data)) return null;
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
