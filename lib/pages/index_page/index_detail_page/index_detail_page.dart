import 'package:card_swiper/card_swiper.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tastie/common/utils/date_utils.dart';
import 'package:tastie/common/utils/image_utils.dart';
import 'package:tastie/constants/color_plate.dart';
import 'package:tastie/pages/index_page/index_detail_page/index_detail_controller.dart';

class IndexDetailPage extends StatelessWidget {
  const IndexDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final IndexDetailController controller = Get.put(IndexDetailController());

    return GetBuilder<IndexDetailController>(
      builder: (_) {
        if (controller.isLoading) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: ColorPlate.primary),
            ),
          );
        } else if (controller.isFail) {
          return const Scaffold(
            body: Center(child: Text("Data Load Failed, Please Try Again")),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                ClipOval(
                  child: ImageUtils.loadImage(
                    controller.cardDetailData.avatar,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Text(
                      controller.cardDetailData.nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: const ShapeDecoration(
                  shape: StadiumBorder(
                    side: BorderSide(color: ColorPlate.primary),
                  ),
                ),
                child: Text(
                  "Follow",
                  style: ColorPlate.bodyTextSmall.copyWith(
                    color: ColorPlate.primary,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12.0, right: 14),
                child: IconButton(
                  icon: const Icon(Icons.share, size: 20),
                  onPressed: () {
                    controller.share();
                  },
                ),
              ),
            ],
          ),
          backgroundColor: ColorPlate.backgroundWhite,
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      buildImageSwiper(controller),
                      buildContent(controller),
                      buildComment(controller),
                    ],
                  ),
                ),
                buildBottom(controller),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildImageSwiper(IndexDetailController controller) {
    return SizedBox(
      height: Get.height * 2 / 3,
      child: Swiper(
        itemBuilder: (BuildContext context, int index) {
          return ImageUtils.loadImage(
            controller.cardDetailData.images[index],
            width: Get.width,
            fit: BoxFit.contain,
          );
        },
        loop: false,
        itemCount: controller.cardDetailData.images.length,
        indicatorLayout: PageIndicatorLayout.SCALE,
        pagination: SwiperPagination(
          builder: DotSwiperPaginationBuilder(
            activeColor: ColorPlate.primary,
            color: ColorPlate.borderGrey,
          ),
        ),
      ),
    );
  }

  Widget buildContent(IndexDetailController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            controller.cardDetailData.title,
            style: ColorPlate.heading2,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              controller.cardDetailData.content,
              style: ColorPlate.bodyText,
            ),
          ),
          // Tags section - between content and date
          if (controller.cardDetailData.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
              child: Wrap(
                spacing: 8.0, // 标签之间的间距
                runSpacing: 8.0, // 行之间的间距
                children: controller.cardDetailData.tags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    decoration: BoxDecoration(
                      color: ColorPlate.secondary, // 背景色为 secondary
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: ColorPlate.primary,
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      "#$tag",
                      style: ColorPlate.tagText, // 文字颜色为 primary
                      textAlign: TextAlign.center,
                    ),
                  );
                }).toList(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              "${controller.cardDetailData.date} ${controller.cardDetailData.address}",
              style: ColorPlate.caption,
            ),
          ),
          const Divider(thickness: 0.5),
        ],
      ),
    );
  }

  Widget buildComment(IndexDetailController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${controller.commentList.length} Comments",
            style: ColorPlate.bodyTextSmall.copyWith(
              color: ColorPlate.textSecondary,
            ),
          ),
          ...controller.commentList.map((e) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: ClipOval(
                      child: ImageUtils.loadImage(
                        e.avatar,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.only(bottom: 14),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: ColorPlate.borderGrey,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.nickname,
                                    style: ColorPlate.heading3.copyWith(
                                      color: ColorPlate.textSecondary,
                                    ),
                                  ),
                                  RichText(
                                    text: TextSpan(
                                      style: ColorPlate.bodyText,
                                      text: e.content,
                                      children: [
                                        TextSpan(
                                          text:
                                              "  ${SDateUtils.formatDate(e.createDate)}",
                                          style: ColorPlate.caption,
                                        ),
                                        TextSpan(
                                          text: "  Reply",
                                          style: ColorPlate.bodyText,
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () {
                                              debugPrint("Reply");
                                            },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              controller.toggleCommentLike(e.id);
                            },
                            child: Column(
                              children: [
                                Icon(
                                  controller.commentLikedMap[e.id] == true
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: 20,
                                  color:
                                      controller.commentLikedMap[e.id] == true
                                          ? Colors.red
                                          : Colors.grey,
                                ),
                                Text(e.like.toString()),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget buildBottom(IndexDetailController controller) {
    Widget buildLikeIcon(int count) {
      return GestureDetector(
        onTap: () {
          controller.toggleLike();
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              controller.isLiked ? Icons.favorite : Icons.favorite_border,
              size: 30,
              color: controller.isLiked ? Colors.red : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              count.toString(),
              style: ColorPlate.bodyTextSmall,
            ),
          ],
        ),
      );
    }

    Widget buildFavoriteIcon(int count) {
      return GestureDetector(
        onTap: () {
          controller.toggleFavorite();
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              controller.isFavorited ? Icons.star : Icons.star_border,
              size: 30,
              color: controller.isFavorited ? Colors.orange : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              count.toString(),
              style: ColorPlate.bodyTextSmall,
            ),
          ],
        ),
      );
    }

    Widget buildCommentIcon(int count) {
      return GestureDetector(
        onTap: () {
          // 打开评论输入框
          debugPrint("Comment clicked");
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.comment,
              size: 30,
              color: Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              count.toString(),
              style: ColorPlate.bodyTextSmall,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 8.0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: const ShapeDecoration(
                shape: StadiumBorder(),
                color: ColorPlate.background,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Icon(
                      Icons.edit,
                      size: 20,
                      color: ColorPlate.textTertiary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      "Say something...",
                      style: ColorPlate.caption,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          buildLikeIcon(controller.cardDetailData.like),
          const SizedBox(width: 4),
          buildFavoriteIcon(controller.cardDetailData.fav),
          const SizedBox(width: 4),
          buildCommentIcon(controller.cardDetailData.comment),
        ],
      ),
    );
  }
}
