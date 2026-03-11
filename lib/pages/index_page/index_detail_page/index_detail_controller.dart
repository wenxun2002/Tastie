import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tastie/models/recipe_firestore.dart';
import 'package:tastie/models/comment.dart';
import 'package:tastie/pages/auth/auth_controller.dart';
import 'package:tastie/repositories/firestore_recipe_repository.dart';

class IndexDetailController extends GetxController {
  late RecipeFirestore recipe;
  late String id;
  bool isLoading = true;
  bool isFail = false;
  List<Comment> commentList = [];
  
  // 交互状态
  bool isLiked = false;
  bool isFavorited = false;
  Map<int, bool> commentLikedMap = {}; // 评论点赞状态

  @override
  void onInit() {
    super.onInit();
    // 获取传递的参数
    final args = Get.arguments;
    final dynamic argId = (args is Map) ? args["id"] : null;
    if (argId is String && argId.trim().isNotEmpty) {
      id = argId;
    } else {
      id = ''; // fallback
    }
    getIndexDetailData(id);
    getCommentList();
  }

  void getIndexDetailData(String id) async {
    // 模拟网络请求延迟
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
      update();
    }
  }

  void getCommentList() {
    // COMMENT FEATURE DISABLED — RESERVED FOR FUTURE USE
    // 模拟网络请求延迟
    Future.delayed(const Duration(milliseconds: 300), () {
      // Comment list is empty as feature is disabled
      commentList = [];
      // 初始化评论点赞状态
      for (var comment in commentList) {
        commentLikedMap[comment.id] = comment.isLike;
      }
      update();
    });
  }

  // 切换点赞状态
  void toggleLike() {
    isLiked = !isLiked;
    update();
  }

  // 切换收藏状态
  void toggleFavorite() {
    isFavorited = !isFavorited;
    update();
  }

  // 切换评论点赞状态
  void toggleCommentLike(int commentId) {
    commentLikedMap[commentId] = !(commentLikedMap[commentId] ?? false);
    update();
  }

  // 分享功能
  Future<void> share() {
    final shareText = buildShareText(recipe);
    return onShareText(shareText);
  }

  /// Whether the current user is the author of this recipe (for showing Delete option).
  /// Requires card to have [CardDetailData.authorUid] set (e.g. from Firestore when creating post).
  bool get isOwnPost {
    final auth = Get.find<AuthController>();
    final User? user = auth.currentUser.value;
    if (user == null) return false;
    return user.uid == recipe.userId;
  }

  /// Report this recipe. Placeholder for future implementation.
  void report() {
    // TODO: implement report (e.g. open report dialog, call API).
  }

  /// Delete own recipe. Placeholder for future implementation.
  void deleteRecipe() {
    // TODO: implement delete (e.g. confirm dialog, remove from Firestore, then pop).
  }
}

/// Build formatted shareable text from recipe detail
String buildShareText(RecipeFirestore recipe) {
  final buffer = StringBuffer();

  // Title
  buffer.writeln(recipe.title);
  buffer.writeln();

  // Ingredients
  buffer.writeln("Ingredients:");
  for (final ingredient in recipe.ingredients) {
    final name = (ingredient['name'] ?? '').toString();
    final amount = ingredient['amount'];
    final unit = (ingredient['unit'] ?? '').toString();
    if (amount == null || (amount is num && amount == 0)) {
      buffer.writeln("$name - $unit");
    } else {
      buffer.writeln("$name - $amount$unit");
    }
  }
  buffer.writeln();

  // Procedures
  buffer.writeln("Procedures:");
  for (int i = 0; i < recipe.procedures.length; i++) {
    // Auto-number each step, remove any existing numbers
    String step = recipe.procedures[i];
    // Remove leading numbers and dots if present
    step = step.replaceFirst(RegExp(r'^\d+\.?\s*'), '');
    buffer.writeln("${i + 1}. $step");
  }

  return buffer.toString();
}

/// Share text: opens share sheet and copies to clipboard
Future<void> onShareText(String shareText) async {
  await SharePlus.instance.share(ShareParams(text: shareText));
  Clipboard.setData(ClipboardData(text: shareText));
}

/// Format count for display
/// 0-9999: full number
/// >=10000: "X.Xw" format (one decimal, no trailing zeros)
String formatCount(int count) {
  if (count < 10000) {
    return count.toString();
  }
  
  final double thousands = count / 1000.0;
  // Round to 1 decimal place and remove trailing zeros
  final String formatted = thousands.toStringAsFixed(1);
  return formatted.replaceAll(RegExp(r'\.?0+$'), '') + 'w';
}
