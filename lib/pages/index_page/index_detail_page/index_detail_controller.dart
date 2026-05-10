import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tastie/constants/pages.dart';
import 'package:tastie/models/recipe_firestore.dart';
import 'package:tastie/models/comment.dart';
import 'package:tastie/pages/auth/auth_controller.dart';
import 'package:tastie/pages/report/report_reason_page.dart';
import 'package:tastie/repositories/firestore_recipe_repository.dart';
import 'package:tastie/repositories/recipe_engagement_repository.dart';
import 'package:tastie/services/recipe_analytics_service.dart';
import 'package:tastie/services/recipe_storage_service.dart';
import 'package:tastie/data/tag_policy.dart';
import 'package:tastie/pages/index_page/index_controller.dart';
import 'package:tastie/utils/recipe_weather_promoted_match.dart';
import 'package:tastie/utils/weather_classifier.dart';

class IndexDetailController extends GetxController {
  late RecipeFirestore recipe;
  late String id;
  bool isLoading = true;
  bool isFail = false;
  List<Comment> commentList = [];

  /// From Firestore `users/{uid}/likes/{recipeId}`.
  bool isLiked = false;
  /// From Firestore `users/{uid}/collections/{recipeId}`.
  bool isFavorited = false;
  Map<int, bool> commentLikedMap = {};

  bool isLikeBusy = false;
  bool isFavBusy = false;

  final RecipeEngagementRepository _engagement = RecipeEngagementRepository();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _recipeSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _likeSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _collectionSub;
  StreamSubscription<User?>? _authSub;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    final dynamic argId = (args is Map) ? args['id'] : null;
    if (argId is String && argId.trim().isNotEmpty) {
      id = argId;
    } else {
      id = '';
    }
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
    getIndexDetailData(id);
    getCommentList();
  }

  void _onAuthChanged(User? user) {
    if (id.isEmpty || isFail) {
      isLiked = false;
      isFavorited = false;
      update();
      return;
    }
    _bindUserEngagementStreams(user?.uid);
  }

  void _bindUserEngagementStreams(String? uid) {
    _likeSub?.cancel();
    _likeSub = null;
    _collectionSub?.cancel();
    _collectionSub = null;

    if (uid == null || id.isEmpty) {
      isLiked = false;
      isFavorited = false;
      update();
      return;
    }

    _likeSub = _engagement.watchLike(uid, id).listen((snap) {
      isLiked = snap.exists;
      update();
    });
    _collectionSub = _engagement.watchCollection(uid, id).listen((snap) {
      isFavorited = snap.exists;
      update();
    });
  }

  void _startRecipeStream() {
    if (id.isEmpty) return;
    _recipeSub?.cancel();
    _recipeSub = _engagement.watchRecipe(id).listen((snap) {
      if (!snap.exists || snap.data() == null) return;
      recipe = RecipeFirestore.fromFirestore(snap.id, snap.data()!);
      update();
    });
  }

  @override
  void onClose() {
    _recipeSub?.cancel();
    _likeSub?.cancel();
    _collectionSub?.cancel();
    _authSub?.cancel();
    super.onClose();
  }

  void getIndexDetailData(String id) async {
    await Future.delayed(const Duration(milliseconds: 500));
    try {
      final repository = FirestoreRecipeRepository();
      final found = await repository.getById(id);

      if (found != null) {
        recipe = found;
        isFail = false;
      } else {
        isFail = true;
      }
    } catch (e) {
      isFail = true;
    } finally {
      isLoading = false;
      if (!isFail && id.isNotEmpty) {
        _startRecipeStream();
        _bindUserEngagementStreams(FirebaseAuth.instance.currentUser?.uid);
        _maybeRecordRecipeClick();
      } else {
        _recipeSub?.cancel();
        _recipeSub = null;
        _bindUserEngagementStreams(null);
      }
      update();
    }
  }

  RecipeClickSource? _recipeClickSourceFromArgs(dynamic args) {
    if (args is! Map) return null;
    final dynamic v = args['recipeClickSource'];
    if (v is RecipeClickSource) return v;
    if (v is String) {
      for (final s in RecipeClickSource.values) {
        if (s.firestoreValue == v) return s;
      }
    }
    return null;
  }

  /// Explore-only: classify promoted vs not using Firestore [recipe.tags] and the
  /// same promoted list as the feed ([IndexController.exploreFilterPromotedTags],
  /// falling back to [getTagPolicy] for current selector weather).
  RecipeClickSource _resolveExploreWeatherClickSource() {
    List<String> promoted = const [];
    try {
      final IndexController idx = Get.find<IndexController>();
      promoted = idx.exploreFilterPromotedTags;
      if (promoted.isEmpty) {
        promoted = List<String>.from(
          getTagPolicy(classifyWeather(idx.selectorWeather)).promoted,
        );
      }
    } catch (_) {
      promoted = const [];
    }
    final bool hit =
        recipeTagsIntersectPromotedTags(recipe.tags, promoted);
    return hit
        ? RecipeClickSource.weatherPromoted
        : RecipeClickSource.weatherNotPromoted;
  }

  void _maybeRecordRecipeClick() {
    final dynamic args = Get.arguments;
    if (args is! Map || args['recordExploreDetailOpen'] != true) return;
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    RecipeClickSource? source = _recipeClickSourceFromArgs(args);
    if (source == null) return;

    // Override CardData-based routing with authoritative recipe.tags + promoted list.
    if (source == RecipeClickSource.weatherPromoted ||
        source == RecipeClickSource.weatherNotPromoted) {
      source = _resolveExploreWeatherClickSource();
    }

    final String? weatherCode = args['currentWeatherCode'] as String?;
    final analytics = RecipeAnalyticsService();
    unawaited(
      analytics
          .logRecipeClick(
            recipeId: id,
            userId: user.uid,
            source: source,
            currentWeatherCode:
                (weatherCode != null && weatherCode.isNotEmpty) ? weatherCode : null,
          )
          .catchError((Object e) {
            debugPrint('RecipeAnalytics logRecipeClick failed: $e');
          }),
    );
  }

  void getCommentList() {
    Future.delayed(const Duration(milliseconds: 300), () {
      commentList = [];
      for (var comment in commentList) {
        commentLikedMap[comment.id] = comment.isLike;
      }
      update();
    });
  }

  Future<void> toggleLike() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Get.snackbar(
        'Sign in required',
        'Log in to like recipes.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (isLikeBusy || id.isEmpty || isFail) return;
    isLikeBusy = true;
    update();
    try {
      await _engagement.toggleLike(userId: user.uid, recipeId: id);
    } catch (e) {
      Get.snackbar(
        'Like failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLikeBusy = false;
      update();
    }
  }

  Future<void> toggleFavorite() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Get.snackbar(
        'Sign in required',
        'Log in to save recipes.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (isFavBusy || id.isEmpty || isFail) return;
    isFavBusy = true;
    update();
    try {
      await _engagement.toggleFavorite(userId: user.uid, recipeId: id);
    } catch (e) {
      Get.snackbar(
        'Save failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isFavBusy = false;
      update();
    }
  }

  void toggleCommentLike(int commentId) {
    commentLikedMap[commentId] = !(commentLikedMap[commentId] ?? false);
    update();
  }

  Future<void> share() {
    final shareText = buildShareText(recipe);
    return onShareText(shareText);
  }

  bool get isOwnPost {
    final auth = Get.find<AuthController>();
    final User? user = auth.currentUser.value;
    if (user == null) return false;
    return user.uid == recipe.userId;
  }

  bool get canReport {
    final auth = Get.find<AuthController>();
    if (auth.currentUser.value == null) return false;
    return !isOwnPost;
  }

  void report() {
    if (!canReport) {
      return;
    }
    Get.toNamed(
      Pages.reportReason,
      arguments: ReportReasonPage.getReportArguments(
        recipeId: id,
        recipeTitle: recipe.title,
        authorUsername: recipe.authorNickname,
        createdAt: recipe.createdAt,
      ),
    );
  }

  Future<void> deleteRecipe(BuildContext context) async {
    if (!isOwnPost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only delete your own recipe.')),
      );
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete recipe?'),
        content: const Text(
          'This action cannot be undone. The recipe will be removed from your profile and the home feed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffd32f2f),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await FirestoreRecipeRepository().delete(id);

      try {
        await RecipeStorageService().deleteByUrls(recipe.imageUrls);
      } catch (_) {}

      if (context.mounted) {
        Navigator.pop(context, true);
      }

      try {
        final index = Get.find<IndexController>();
        await index.refreshPosts();
      } catch (_) {}
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }
}

String buildShareText(RecipeFirestore recipe) {
  final buffer = StringBuffer();

  buffer.writeln(recipe.title);
  buffer.writeln();

  buffer.writeln('Ingredients:');
  for (final ingredient in recipe.ingredients) {
    final name = (ingredient['name'] ?? '').toString();
    final amount = ingredient['amount'];
    final unit = (ingredient['unit'] ?? '').toString();
    if (amount == null || (amount is num && amount == 0)) {
      buffer.writeln('$name - $unit');
    } else {
      buffer.writeln('$name - $amount$unit');
    }
  }
  buffer.writeln();

  buffer.writeln('Procedures:');
  for (int i = 0; i < recipe.procedures.length; i++) {
    String step = recipe.procedures[i];
    step = step.replaceFirst(RegExp(r'^\d+\.?\s*'), '');
    buffer.writeln('${i + 1}. $step');
  }

  return buffer.toString();
}

Future<void> onShareText(String shareText) async {
  await SharePlus.instance.share(ShareParams(text: shareText));
  Clipboard.setData(ClipboardData(text: shareText));
}
