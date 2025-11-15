import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:tastie/models/card_detail_data.dart';
import 'package:tastie/models/comment.dart';
import 'package:tastie/mock/mock_card_detail.dart';

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

  void getIndexDetailData(int id) {
    // 模拟网络请求延迟
    Future.delayed(const Duration(milliseconds: 500), () {
      try {
        // 从 mock 数据中查找对应 id 的数据
        final found = MockCardDetail.cardDetailDataList.firstWhere(
          (item) => item.id == id,
          orElse: () => MockCardDetail.cardDetailDataList.first,
        );
        cardDetailData = found;
        isFail = false;
      } catch (e) {
        isFail = true;
      } finally {
        isLoading = false;
        update();
      }
    });
  }

  void getCommentList() {
    // 模拟网络请求延迟
    Future.delayed(const Duration(milliseconds: 300), () {
      commentList = MockCardDetail.commentList;
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
    // 分享逻辑
    debugPrint("Share clicked");
  }
}
