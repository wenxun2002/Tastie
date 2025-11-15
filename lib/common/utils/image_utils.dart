import 'package:flutter/material.dart';

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
      return Image.network(
        url,
        key: key ?? ValueKey(url),
        width: width,
        height: height,
        fit: fit,
        color: color,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('ImageUtils: Network image load failed: $url');
          return Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: const Icon(Icons.error, color: Colors.grey),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: width,
            height: height,
            color: Colors.grey[200],
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
      );
    } else {
      // 本地资源 - 使用缓存优化性能
      // 计算缓存尺寸，限制内存占用
      // 对于瀑布流两列布局，每列宽度约为屏幕宽度的一半
      // 使用 MediaQuery 获取屏幕宽度，但这里简化处理
      int? cacheWidth;
      if (width != null && width != double.infinity) {
        // 限制缓存宽度，减少内存占用（2x for retina display）
        cacheWidth = (width * 2).toInt();
      } else {
        // 如果没有指定宽度，使用合理的默认值（假设屏幕宽度400，两列各200）
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

