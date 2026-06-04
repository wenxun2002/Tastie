import 'package:flutter/material.dart';
import 'package:tastie/common/utils/image_utils.dart';
import 'package:tastie/constants/color_plate.dart';

/// Placeholder when a recipe has no displayable cover / image URLs.
class RecipeMissingImagesPlaceholder extends StatelessWidget {
  const RecipeMissingImagesPlaceholder({
    super.key,
    this.width,
    this.height,
    this.compact = false,
  });

  static const String placeholderAsset =
      'assets/images/LogoTransparent288.png';

  /// `true` for feed/search [CardItem]; `false` for recipe detail header.
  final bool compact;

  final double? width;
  final double? height;

  static bool coverUrlIsMissing(String coverUrl) =>
      coverUrl.trim().isEmpty;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 28,
        vertical: compact ? 12 : 0,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          ImageUtils.loadImage(
            placeholderAsset,
            width: compact ? 56 : 120,
            height: compact ? 56 : 120,
            fit: BoxFit.contain,
          ),
          SizedBox(height: compact ? 10 : 20),
          Text(
            'Unable to display photos',
            style: (compact ? ColorPlate.bodyTextSmall : ColorPlate.heading3)
                .copyWith(
              fontWeight: FontWeight.w600,
              fontSize: compact ? 11 : null,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: compact ? 4 : 8),
          Text(
            'This recipe has no images, or they could not be loaded.',
            style: ColorPlate.bodyTextSmall.copyWith(
              color: ColorPlate.textSecondary,
              fontSize: compact ? 10 : 12,
            ),
            textAlign: TextAlign.center,
            maxLines: compact ? 3 : 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    final decoration = BoxDecoration(
      color: ColorPlate.disabled,
      border: compact
          ? Border.all(color: ColorPlate.borderGrey, width: 0.5)
          : null,
    );

    if (height != null) {
      return SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: decoration,
          child: Center(child: content),
        ),
      );
    }

    return DecoratedBox(
      decoration: decoration,
      child: AspectRatio(
        aspectRatio: 0.8,
        child: Center(
          child: SizedBox(width: width, child: content),
        ),
      ),
    );
  }
}
