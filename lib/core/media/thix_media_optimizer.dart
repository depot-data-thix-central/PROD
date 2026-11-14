import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_player/video_player.dart';

import 'video_compressor/video_compressor.dart';

class MediaOptimizeException implements Exception {
  const MediaOptimizeException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Extrait choisi dans le trimmer (millisecondes).
class VideoTrimRange {
  const VideoTrimRange({required this.startMs, required this.endMs});
  final int startMs;
  final int endMs;
}

class OptimizedVideo {
  const OptimizedVideo({required this.path, required this.bytes, required this.ext});
  final String path;
  final Uint8List bytes;
  final String ext;
}

class ThixMediaOptimizer {
  ThixMediaOptimizer._();

  // ------------------------------------------------------------------ IMAGES
  /// Compresse par paliers (qualité puis dimensions) jusqu'à passer sous
  /// [maxMB], au lieu de rejeter le fichier. Fonctionne aussi sur le web.
  static Future<Uint8List> compressImage(Uint8List input, {int maxMB = 5}) async {
    final maxBytes = maxMB * 1024 * 1024;
    if (input.length <= maxBytes) return input;

    const steps = <(int, int)>[
      (85, 4096), (75, 3072), (65, 2560), (55, 2048), (45, 1600), (35, 1280),
    ];

    var best = input;
    for (final (quality, dim) in steps) {
      try {
        // Toujours repartir de l'original pour éviter la perte générationnelle.
        final out = await FlutterImageCompress.compressWithList(
          input,
          quality: quality,
          minWidth: dim,
          minHeight: dim,
          format: CompressFormat.jpeg,
        );
        if (out.isNotEmpty && out.length < best.length) best = out;
        if (best.length <= maxBytes) return best;
      } catch (e) {
        debugPrint('[Optimizer] compression image q=$quality: $e');
      }
    }
    if (best.length <= maxBytes) return best;
    throw MediaOptimizeException('Image impossible à compresser sous $maxMB MB.');
  }

  // ------------------------------------------------------------------ VIDÉO
  static VideoPlayerController controllerFor(String path) {
    return kIsWeb
        ? VideoPlayerController.networkUrl(Uri.parse(path))
        : VideoPlayerController.file(File(path));
  }

  static Future<Duration> videoDuration(String path) async {
    final c = controllerFor(path);
    try {
      await c.initialize();
      return c.value.duration;
    } finally {
      await c.dispose();
    }
  }

  static Future<int> fileSize(String path) => File(path).length();

  /// Découpe (optionnel) + compresse si nécessaire. Garantit un fichier
  /// ≤ [maxMB]. Mobile uniquement.
  static Future<OptimizedVideo> processVideo(
    String path, {
    int maxMB = 64,
    VideoTrimRange? trim,
    void Function(double percent)? onProgress,
  }) async {
    if (kIsWeb) {
      throw const MediaOptimizeException('Traitement vidéo indisponible sur le web.');
    }
    final maxBytes = maxMB * 1024 * 1024;
    final srcSize = await File(path).length();
    final needsCompress = srcSize > maxBytes;

    if (trim == null && !needsCompress) {
      return OptimizedVideo(
        path: path,
        bytes: await File(path).readAsBytes(),
        ext: _extOf(path),
      );
    }

    final outPath = await VideoCompressor.process(
      path,
      maxMB: maxMB,
      needsCompress: needsCompress,
      trimStartMs: trim?.startMs,
      trimEndMs: trim?.endMs,
      onProgress: onProgress,
    );
    if (outPath == null) {
      throw MediaOptimizeException(
        'Vidéo toujours trop volumineuse après compression (max $maxMB MB).',
      );
    }
    return OptimizedVideo(
      path: outPath,
      bytes: await File(outPath).readAsBytes(),
      ext: 'mp4',
    );
  }

  static String _extOf(String path) {
    final i = path.lastIndexOf('.');
    return i == -1 ? 'mp4' : path.substring(i + 1).toLowerCase();
  }
}
