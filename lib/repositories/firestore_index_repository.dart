import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tastie/models/card_data.dart';
import 'package:tastie/repositories/paginated_posts_result.dart';
import 'package:tastie/utils/recipe_catalog_policy.dart';

/// Explore 列表排序字段（Firestore `orderBy`）。
enum ExploreFeedSort {
  /// `orderBy('createdAt', descending: true)` — 非 neutral 天气各 tag 层内默认。
  byCreatedAtDesc,

  /// `orderBy('likeCount', descending: true)` — **neutral** 天气全库按热度。
  ///
  /// 需保证 `recipes` 文档含数值字段 `likeCount`（或仅参与排序的文档含该字段）。
  byLikeCountDesc,
}

class FirestoreIndexRepository {
  final FirebaseFirestore _db;
  final String collectionPath;

  FirestoreIndexRepository({
    FirebaseFirestore? db,
    this.collectionPath = 'recipes',
  }) : _db = db ?? FirebaseFirestore.instance;

  /// Explore feed：可选 `tags` 过滤 + 分页游标 + 排序。
  ///
  /// **索引提示**
  /// - `arrayContainsAny` + `orderBy('createdAt')` → 复合索引：`tags` + `createdAt` 降序。
  /// - 仅 `orderBy('likeCount')`、无 `where` → 通常自动单字段索引；若控制台提示再建。
  /// - `arrayContainsAny` + `orderBy('likeCount')` → 需复合索引（当前 neutral 不按标签过滤）。
  Future<PaginatedPostsResult> getPostsPaginated({
    int limit = 10,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
    List<String>? filterTags,
    ExploreFeedSort sort = ExploreFeedSort.byCreatedAtDesc,
  }) async {
    final String orderField = sort == ExploreFeedSort.byLikeCountDesc
        ? 'likeCount'
        : 'createdAt';

    /// 多取一些再过滤 `banned`，避免「一页 10 条里多条被封」时露不出足够卡片。
    final int batchSize = (limit * 4).clamp(20, 80);
    const int maxBatches = 24;

    final items = <CardData>[];
    DocumentSnapshot<Map<String, dynamic>>? cursor = startAfterDocument;
    DocumentSnapshot<Map<String, dynamic>>? lastConsumed;
    var batchFull = false;

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

      for (final doc in docs) {
        lastConsumed = doc;
        final data = doc.data();
        if (!recipeDocIsPublicCatalogVisible(data)) continue;
        items.add(CardData.fromJson(_normalizeCardDataJson(doc.id, data)));
        if (items.length >= limit) {
          break;
        }
      }

      if (items.length >= limit) {
        break;
      }
    }

    /// 未满 [limit] 条视为没有下一页；满页且上一批仍「装满」说明服务器上可能还有后续文档。
    final hasMore = items.length == limit && batchFull;

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
