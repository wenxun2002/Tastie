import 'package:flutter/material.dart';
import 'package:fade_shimmer/fade_shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// 图片加载工具类
/// 自动判断是本地资源还是网络URL
class ImageUtils {
  /// 判断是否为网络URL
  static bool isNetworkUrl(String url) {
    return url.startsWith('http://') ||
        url.startsWith('https://') ||
        url.startsWith('//');
  }

  /// 智能加载图片 - 自动判断本地资源或网络图片
  static Widget loadImage(
    String url, {
    double? width,
    double? height,
    BoxFit? fit,
    Color? color,
    Key? key,
  }) {
    if (isNetworkUrl(url)) {
      final double shimmerWidth =
          (width == null || width == double.infinity) ? 80 : width;
      final double shimmerHeight =
          (height == null || height == double.infinity) ? 80 : height;

      final int? memCacheWidth =
          (width != null && width != double.infinity) ? (width * 2).toInt() : null;
      final int? memCacheHeight =
          (height != null && height != double.infinity) ? (height * 2).toInt() : null;

      return CachedNetworkImage(
        imageUrl: url,
        cacheKey: url,
        key: key ?? ValueKey(url),
        width: width,
        height: height,
        fit: fit,
        color: color,
        memCacheWidth: memCacheWidth,
        memCacheHeight: memCacheHeight,
        maxWidthDiskCache: memCacheWidth,
        maxHeightDiskCache: memCacheHeight,
        placeholder: (context, _) => Container(
          width: width,
          height: height,
          color: Colors.grey[200],
          child: FadeShimmer(
            width: shimmerWidth,
            height: shimmerHeight,
            radius: 0,
            fadeTheme: FadeTheme.light,
            millisecondsDelay: 0,
          ),
        ),
        errorWidget: (context, _, error) {
          debugPrint('ImageUtils: Network image load failed: $url ($error)');
          return Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: const Icon(Icons.error, color: Colors.grey),
          );
        },
      );
    } else {
      // 本地资源 - 使用缓存优化性能
      int? cacheWidth;
      if (width != null && width != double.infinity) {
        cacheWidth = (width * 2).toInt();
      } else {
        cacheWidth = 400; // 2x for retina = 800px max
      }

      return Image.asset(
        url,
        key: key ?? ValueKey(url),
        width: width,
        height: height,
        fit: fit ?? BoxFit.cover,
        color: color,
        cacheWidth: cacheWidth,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('ImageUtils: Asset image load failed: $url');
          return Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: const Icon(Icons.error, color: Colors.grey),
          );
        },
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          // 图片加载完成前显示占位符
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 200),
            child: child,
          );
        },
      );
    }
  }
}
