import 'dart:convert';
import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// Compresses picked photos and returns base64 payloads for `smartGenerate`.
class SmartGenerateImageEncoder {
  SmartGenerateImageEncoder._();

  /// Cap count & size for callable payload and Gemini limits.
  static const int maxImages = 4;
  static const int maxBytesPerImage = 4 * 1024 * 1024;

  static Future<List<Map<String, String>>> encodePaths(
    List<String> filePaths,
  ) async {
    if (filePaths.isEmpty) return [];
    final tempDir = await getTemporaryDirectory();
    final out = <Map<String, String>>[];
    final slice = filePaths.take(maxImages).toList(growable: false);

    for (var i = 0; i < slice.length; i++) {
      final path = slice[i];
      final src = File(path);
      if (!await src.exists()) continue;

      final targetPath =
          '${tempDir.path}/sg_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      String readPath = path;
      try {
        final compressed = await FlutterImageCompress.compressAndGetFile(
          path,
          targetPath,
          quality: 78,
          minWidth: 960,
        );
        if (compressed != null && await File(compressed.path).exists()) {
          readPath = compressed.path;
        }
      } catch (_) {
        // fall back to original
      }

      final bytes = await File(readPath).readAsBytes();
      if (bytes.isEmpty || bytes.length > maxBytesPerImage) continue;

      out.add(<String, String>{
        'mimeType': 'image/jpeg',
        'data': base64Encode(bytes),
      });
    }
    return out;
  }
}
