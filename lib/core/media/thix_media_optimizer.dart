//lib/core/media/thix_media_optimizer.dart

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:light_compressor_v2/light_compressor_v2.dart';
import 'package:video_player/video_player.dart';

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

  static final LightCompressor _compressor = LightCompressor();

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
  /// ≤ [maxMB] (2 passes si besoin). Mobile uniquement.
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

    // Le plugin raisonne en MB décimaux → on garde une marge sous la limite.
    final targetMb = math.max(1, maxMB - 4);

    StreamSubscription<double>? sub;
    if (onProgress != null) {
      sub = _compressor.onProgressUpdated.listen(onProgress);
    }
    try {
      // Passe 1 : découpage et/ou compression vers la taille cible.
      var out = await _compressOnce(
        path,
        quality: needsCompress ? VideoQuality.medium : VideoQuality.high,
        targetMb: needsCompress ? targetMb : null,
        twoPass: needsCompress,
        trim: trim,
      );

      // Passe 2 (plus agressive) si échec ou encore trop gros.
      if (out == null || await File(out).length() > maxBytes) {
        out = await _compressOnce(
          out ?? path,
          quality: VideoQuality.low,
          targetMb: targetMb,
          twoPass: true,
          trim: out == null ? trim : null, // déjà découpé si la passe 1 a réussi
        );
      }

      if (out != null && await File(out).length() <= maxBytes) {
        return OptimizedVideo(
          path: out,
          bytes: await File(out).readAsBytes(),
          ext: 'mp4',
        );
      }
      throw MediaOptimizeException(
        'Vidéo toujours trop volumineuse après compression (max $maxMB MB).',
      );
    } finally {
      await sub?.cancel();
    }
  }

  static Future<String?> _compressOnce(
    String path, {
    required VideoQuality quality,
    required int? targetMb,
    required bool twoPass,
    VideoTrimRange? trim,
  }) async {
    final result = await _compressor.compressVideo(
      path: path,
      videoQuality: quality,
      isMinBitrateCheckEnabled: false, // force le traitement (trim inclus)
      android: AndroidConfig(isSharedStorage: false), // stockage app, pas la galerie
      ios: IOSConfig(saveInGallery: false),
      video: Video(
        videoName: 'status_${DateTime.now().millisecondsSinceEpoch}.mp4',
        targetSizeMb: targetMb,
        twoPass: twoPass,
      ),
      edit: trim == null
          ? null
          : VideoEdit(trimStartMs: trim.startMs, trimEndMs: trim.endMs),
    );
    if (result is OnSuccess) return result.destinationPath;
    debugPrint('[Optimizer] ❌ échec compression vidéo: $result');
    return null;
  }

  static String _extOf(String path) {
    final i = path.lastIndexOf('.');
    return i == -1 ? 'mp4' : path.substring(i + 1).toLowerCase();
  }
}
