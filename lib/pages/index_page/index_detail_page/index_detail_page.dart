import 'package:card_swiper/card_swiper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tastie/common/utils/image_utils.dart';
import 'package:tastie/constants/color_plate.dart';
import 'package:tastie/common/utils/count_format.dart';
import 'package:tastie/pages/index_page/index_detail_page/index_detail_controller.dart';
import 'package:tastie/pages/index_page/index_detail_page/index_detail_skeleton.dart';

class IndexDetailPage extends StatefulWidget {
  const IndexDetailPage({super.key});

  @override
  State<IndexDetailPage> createState() => _IndexDetailPageState();
}

class _IndexDetailPageState extends State<IndexDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _formatPostedTime(dynamic createdAt) {
    if (createdAt == null) return '—';
    DateTime? dateTime;
    if (createdAt is Timestamp) {
      dateTime = createdAt.toDate();
    } else if (createdAt is DateTime) {
      dateTime = createdAt;
    } else if (createdAt is int) {
      dateTime = DateTime.fromMillisecondsSinceEpoch(createdAt);
    } else {
      try {
        final dynamic candidateToDate = createdAt;
        final dynamic converted = candidateToDate.toDate();
        if (converted is DateTime) {
          dateTime = converted;
        }
      } catch (_) {
        // Ignore unsupported createdAt formats.
      }
    }

    if (dateTime == null) return '—';
    return DateFormat.yMMMd().add_Hm().format(dateTime.toLocal());
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showDetailMoreMenu(
      BuildContext parentContext, IndexDetailController controller) {
    showModalBottomSheet<void>(
      context: parentContext,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: ColorPlate.backgroundWhite,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controller.canReport)
                ListTile(
                  leading: const Icon(Icons.flag_outlined, color: ColorPlate.textSecondary),
                  title: Text('Report', style: ColorPlate.bodyText),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    controller.report();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.share, color: ColorPlate.primary),
                title: Text('Share', style: ColorPlate.bodyText),
                onTap: () {
                  Navigator.pop(sheetContext);
                  controller.share();
                },
              ),
              if (controller.isOwnPost)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: Text('Delete', style: ColorPlate.bodyText.copyWith(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    controller.deleteRecipe(parentContext);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final IndexDetailController controller = Get.put(IndexDetailController());

    return GetBuilder<IndexDetailController>(
      builder: (_) {
        if (controller.isLoading) {
          return const IndexDetailSkeleton();
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
                    controller.recipe.authorAvatar,
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: GestureDetector(
                      onTap: () {
                        print("Open author profile placeholder");
                      },
                      child: Text(
                        controller.recipe.authorNickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: ColorPlate.bodyText.copyWith(fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
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
                  icon: const Icon(Icons.more_vert, size: 20),
                  color: ColorPlate.primary,
                  onPressed: () => _showDetailMoreMenu(context, controller),
                ),
              ),
            ],
          ),
          backgroundColor: ColorPlate.backgroundWhite,
          body: NestedScrollView(
            headerSliverBuilder:
                (BuildContext context, bool innerBoxIsScrolled) {
                  return [
                    // Image Carousel
                    SliverToBoxAdapter(child: buildImageSwiper(controller)),
                    // Title, Content, Tags, Date
                    SliverToBoxAdapter(child: buildContent(controller)),
                    // TabBar
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SliverAppBarDelegate(
                        TabBar(
                          controller: _tabController,
                          labelColor: Colors.black,
                          unselectedLabelColor: ColorPlate.textSecondary,
                          dividerColor: Colors.transparent,
                          indicatorColor: ColorPlate.primary,
                          tabs: const [
                            Tab(text: "Ingredients"),
                            Tab(text: "Procedures"),
                          ],
                        ),
                      ),
                    ),
                  ];
                },
            body: TabBarView(
              controller: _tabController,
              children: [
                buildIngredientsTab(controller),
                buildProceduresTab(controller),
              ],
            ),
          ),
          bottomNavigationBar: buildBottom(controller),
        );
      },
    );
  }

  Widget buildImageSwiper(IndexDetailController controller) {
    if (controller.recipe.imageUrls.isEmpty) {
      return SizedBox(
        height: Get.height * 2 / 3,
        child: Container(
          color: ColorPlate.background,
          alignment: Alignment.center,
          child: const Icon(
            Icons.image_not_supported_outlined,
            size: 64,
            color: ColorPlate.textSecondary,
          ),
        ),
      );
    }

    return SizedBox(
      height: Get.height * 2 / 3,
      child: Swiper(
        itemBuilder: (BuildContext context, int index) {
          return ImageUtils.loadImage(
            controller.recipe.imageUrls[index],
            width: Get.width,
            fit: BoxFit.contain,
          );
        },
        loop: false,
        itemCount: controller.recipe.imageUrls.length,
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
          Text(controller.recipe.title, style: ColorPlate.heading2),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              controller.recipe.content,
              style: ColorPlate.bodyText,
            ),
          ),
          // Tags section - between content and date
          if (controller.recipe.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
              child: Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: controller.recipe.tags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    decoration: BoxDecoration(
                      color: ColorPlate.secondary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ColorPlate.primary, width: 1.0),
                    ),
                    child: Text(
                      "#$tag",
                      style: ColorPlate.tagText,
                      textAlign: TextAlign.center,
                    ),
                  );
                }).toList(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              "${_formatPostedTime(controller.recipe.createdAt)}",
              style: ColorPlate.caption.copyWith(
                color: ColorPlate.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildIngredientsTab(IndexDetailController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ingredients List
          ...controller.recipe.ingredients.map<Widget>((ingredient) {
            final name = (ingredient['name'] ?? '').toString();
            final amount = ingredient['amount'];
            final unit = (ingredient['unit'] ?? '').toString();
            return Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: ColorPlate.borderGrey.withOpacity(0.7),
                    width: 1.5,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: ColorPlate.bodyText,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (amount is num && amount > 0)
                        Text(
                          amount.toString(),
                          style: ColorPlate.bodyText,
                        ),
                      const SizedBox(width: 5),
                      Text(unit, style: ColorPlate.bodyText),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 15),
          // Nutrition Info Section
          if (controller.recipe.nutrition != null)
            _NutritionSection(nutrition: controller.recipe.nutrition!),
        ],
      ),
    );
  }

  Widget buildProceduresTab(IndexDetailController controller) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
      itemCount: controller.recipe.procedures.length,
      itemBuilder: (context, index) {
        final step = controller.recipe.procedures[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 5.0),
          padding: const EdgeInsets.all(10.0),
          decoration: BoxDecoration(
            color: ColorPlate.secondary,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                alignment: Alignment.topCenter,
                child: Text(
                  "${index + 1}",
                  style: ColorPlate.heading2.copyWith(
                    color: ColorPlate.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(child: Text(step, style: ColorPlate.bodyText)),
            ],
          ),
        );
      },
    );
  }

  // COMMENT FEATURE DISABLED — RESERVED FOR FUTURE USE
  // Hidden comment section (kept for future use)
  Widget buildComment(IndexDetailController controller) {
    return Visibility(
      visible: false, // Hidden but code structure preserved
      child: Padding(
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
                                            text: "",
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
              size: 28,
              color: controller.isLiked ? Colors.red : ColorPlate.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              formatEngagementCount(count),
              style: ColorPlate.bodyTextSmall.copyWith(
                fontWeight: FontWeight.w500,
              ),
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
              size: 28,
              color: controller.isFavorited
                  ? Colors.orange
                  : ColorPlate.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              formatEngagementCount(count),
              style: ColorPlate.bodyTextSmall.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // COMMENT FEATURE DISABLED — RESERVED FOR FUTURE USE
    // Comment icon and input box are hidden but code preserved for future use
    // Widget buildCommentIcon(int count) {
    //   return Visibility(
    //     visible: false,
    //     child: GestureDetector(
    //       onTap: () {
    //         debugPrint("Comment clicked");
    //       },
    //       child: Row(
    //         mainAxisSize: MainAxisSize.min,
    //         children: [
    //           const Icon(
    //             Icons.comment,
    //             size: 30,
    //             color: Colors.grey,
    //           ),
    //           const SizedBox(width: 4),
    //           Text(
    //             formatCount(count),
    //             style: ColorPlate.bodyTextSmall,
    //           ),
    //         ],
    //       ),
    //     ),
    //   );
    // }

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: ColorPlate.backgroundWhite,
          border: Border(
            top: BorderSide(
              color: ColorPlate.borderGrey.withOpacity(0.3),
              width: 1,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: ColorPlate.secondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildLikeIcon(controller.recipe.likeCount),
                  const SizedBox(width: 20),
                  Container(
                    width: 1,
                    height: 24,
                    color: ColorPlate.borderGrey.withOpacity(0.5),
                  ),
                  const SizedBox(width: 20),
                  buildFavoriteIcon(controller.recipe.favCount),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// SliverPersistentHeader delegate for TabBar
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverAppBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: ColorPlate.backgroundWhite, child: tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

// Nutrition Section with expandable animation
class _NutritionSection extends StatefulWidget {
  final Map<String, dynamic> nutrition;

  const _NutritionSection({required this.nutrition});

  @override
  State<_NutritionSection> createState() => _NutritionSectionState();
}

class _NutritionSectionState extends State<_NutritionSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(
        "Nutrition info",
        style: ColorPlate.heading2.copyWith(
          fontWeight: FontWeight.w600,
          color: ColorPlate.textPrimary,
        ),
      ),
      // Remove the border when expanded
      shape: LinearBorder.none,
      // Remove the border when collapsed
      collapsedShape: LinearBorder.none,
      trailing: Icon(
        _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
        color: ColorPlate.primary,
      ),
      onExpansionChanged: (bool expanded) {
        setState(() {
          _isExpanded = expanded;
        });
      },
      children: [
        Column(
          children: [
            _buildNutritionRow(
              "Calories",
              (widget.nutrition['calories'] ?? '').toString(),
            ),
            _buildNutritionRow("Fat", "${(widget.nutrition['fat'] ?? 0).toString()} g"),
            _buildNutritionRow(
              "Carbohydrates",
              "${(widget.nutrition['carbs'] ?? 0).toString()} g",
            ),
            _buildNutritionRow("Fiber", "${(widget.nutrition['fiber'] ?? 0).toString()} g"),
            _buildNutritionRow("Sugar", "${(widget.nutrition['sugar'] ?? 0).toString()} g"),
            _buildNutritionRow(
              "Protein",
              "${(widget.nutrition['protein'] ?? 0).toString()} g",
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNutritionRow(String label, String value) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: ColorPlate.borderGrey.withOpacity(0.7),
            width: 1.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: ColorPlate.bodyText),
          Text(value, style: ColorPlate.bodyText),
        ],
      ),
    );
  }
}
