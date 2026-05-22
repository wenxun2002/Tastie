import 'package:flutter/material.dart';
import 'package:tastie/common/utils/count_format.dart';
import 'package:tastie/common/utils/image_utils.dart';
import 'package:tastie/common/widgets/recipe_missing_images_placeholder.dart';
import 'package:tastie/models/card_data.dart';

class CardItem extends StatelessWidget {
  final CardData cardData;
  final VoidCallback? onTap;
  /// When true, shows a solid heart (current user liked this recipe).
  final bool isLiked;

  const CardItem({
    super.key,
    required this.cardData,
    this.onTap,
    this.isLiked = false,
  });

  @override
  Widget build(BuildContext context) {
    // 使用 RepaintBoundary 隔离重绘，提升性能
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cover Image - 根据图片实际比例自适应高度
              // 使用 LayoutBuilder 获取实际宽度，优化缓存
              LayoutBuilder(
                builder: (context, constraints) {
                  final imageWidth = constraints.maxWidth;
                  final cover = cardData.cover.trim();
                  return ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(4)),
                    child: RecipeMissingImagesPlaceholder.coverUrlIsMissing(
                            cover)
                        ? RecipeMissingImagesPlaceholder(
                            width: imageWidth,
                            compact: true,
                          )
                        : ImageUtils.loadImage(
                            cover,
                            width: imageWidth,
                            fit: BoxFit.cover,
                          ),
                  );
                },
              ),
              // Title
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
                child: Text(
                  cardData.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              // User Info and Like
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
                child: Row(
                  children: [
                    // Avatar
                    ClipOval(
                      child: ImageUtils.loadImage(
                        cardData.avatar,
                        width: 20,
                        height: 20,
                        fit: BoxFit.cover,
                      ),
                    ),
                    // Nickname
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          cardData.nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 16,
                          color: isLiked ? Colors.red : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 44),
                          child: Text(
                            formatEngagementCount(cardData.like),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontSize: 12,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
