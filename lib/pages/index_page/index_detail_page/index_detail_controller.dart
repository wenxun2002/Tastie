import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tastie/models/card_detail_data.dart';
import 'package:tastie/models/comment.dart';
import 'package:tastie/repositories/mock_card_detail_repository.dart';

class IndexDetailController extends GetxController {
  late CardDetailData cardDetailData;
  late int id;
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
    if (argId is int) {
      id = argId;
    } else if (argId is String) {
      id = int.tryParse(argId) ?? 1;
    } else {
      id = 1; // fallback，防止热重启或无参数时崩溃
    }
    getIndexDetailData(id);
    getCommentList();
  }

  void getIndexDetailData(int id) async {
    // 模拟网络请求延迟
    await Future.delayed(const Duration(milliseconds: 500));
    try {
      final repository = MockCardDetailRepository();
      final found = await repository.getById(id);
      
      if (found != null) {
        cardDetailData = found;
        isFail = false;
      } else {
        // Fallback: get first item if ID not found
        final allData = await repository.getAll();
        if (allData.isNotEmpty) {
          cardDetailData = allData.first;
          isFail = false;
        } else {
          isFail = true;
        }
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
  void share() {
    onShare(cardDetailData);
  }
}

/// Build formatted shareable text from card detail
String buildShareText(CardDetailData detail) {
  final buffer = StringBuffer();
  
  // Title
  buffer.writeln(detail.title);
  buffer.writeln();
  
  // Ingredients
  buffer.writeln("Ingredients:");
  for (final ingredient in detail.ingredients) {
    buffer.writeln("${ingredient.name} - ${ingredient.amount}${ingredient.unit}");
  }
  buffer.writeln();
  
  // Procedures
  buffer.writeln("Procedures:");
  for (int i = 0; i < detail.procedures.length; i++) {
    // Auto-number each step, remove any existing numbers
    String step = detail.procedures[i];
    // Remove leading numbers and dots if present
    step = step.replaceFirst(RegExp(r'^\d+\.?\s*'), '');
    buffer.writeln("${i + 1}. $step");
  }
  
  return buffer.toString();
}

/// Share card detail: opens share sheet and copies to clipboard
void onShare(CardDetailData detail) {
  final shareText = buildShareText(detail);
  
  // Open native share sheet
  Share.share(shareText);
  
  // Copy to clipboard
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
