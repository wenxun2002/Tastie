import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tastie/models/card_data.dart';

/// One page of Explore feed items plus the Firestore cursor for the next request.
class PaginatedPostsResult {
  const PaginatedPostsResult({
    required this.items,
    required this.hasMore,
    this.lastDocument,
  });

  final List<CardData> items;
  final bool hasMore;

  /// Last document in this page; pass to [FirestoreIndexRepository.getPostsPaginated]
  /// as [startAfterDocument] to fetch the next page.
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
}
