// ─────────────────────────────────────────────
//  Polyticks – On-Device Image Compression
// ─────────────────────────────────────────────
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Compresses an image file on-device so identity documents stay small
/// (target < 150 KB) before they are uploaded to Supabase Storage.
///
/// Keeps storage usage near $0 and dramatically speeds up uploads.
class ImageCompressor {
  ImageCompressor._();

  /// Target maximum size in bytes for identity documents (150 KB).
  static const int _targetBytes = 150 * 1024;

  /// Compresses [sourcePath] to a temporary file whose size is below
  /// [_targetBytes] when possible. Falls back to the original if compression
  /// fails so the user flow is never blocked.
  ///
  /// Returns the path of the compressed file (and cleans up the original
  /// when [deleteOriginal] is true).
  static Future<String> compressId(
    String sourcePath, {
    bool deleteOriginal = true,
  }) async {
    try {
      final compressedPath = await _compressToTarget(sourcePath, _targetBytes);
      if (compressedPath == null) return sourcePath;

      if (deleteOriginal && compressedPath != sourcePath) {
        final original = File(sourcePath);
        if (await original.exists()) {
          await original.delete();
        }
      }
      return compressedPath;
    } catch (e) {
      debugPrint('ImageCompressor: compression failed, using original. $e');
      return sourcePath;
    }
  }

  /// Iteratively reduces quality/size until the file fits within [targetBytes]
  /// or quality drops below the floor.
  static Future<String?> _compressToTarget(
    String path,
    int targetBytes,
  ) async {
    final original = File(path);
    if (!await original.exists()) return null;

    // Fast path: already small enough.
    final originalSize = await original.length();
    if (originalSize <= targetBytes) return path;

    const minQuality = 35;
    final dir = original.parent.path;

    for (var quality = 90; quality >= minQuality; quality -= 10) {
      final outPath = '$dir/compressed_q$quality.jpg';
      final result = await FlutterImageCompress.compressAndGetFile(
        path,
        outPath,
        quality: quality,
      );
      if (result == null) continue;

      final size = await result.length();
      if (size <= targetBytes || quality == minQuality) {
        // Delete any earlier higher-quality scratch files in this loop.
        for (var q = quality + 10; q <= 100; q += 10) {
          final stale = File('$dir/compressed_q$q.jpg');
          if (await stale.exists()) {
            await stale.delete();
          }
        }
        return result.path;
      }
      // Not small enough – remove this scratch file and try lower quality.
      await File(result.path).delete();
    }

    return path;
  }
}
