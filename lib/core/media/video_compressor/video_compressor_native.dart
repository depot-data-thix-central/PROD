import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:light_compressor_v2/light_compressor_v2.dart';

/// Implémentation Android/iOS/macOS (native, sans FFmpeg).
class VideoCompressor {
  VideoCompressor._();

  static final LightCompressor _compressor = LightCompressor();

  /// Renvoie le chemin du fichier traité (≤ maxMB), ou null si échec.
  static Future<String?> process(
    String path, {
    required int maxMB,
    required bool needsCompress,
    int? trimStartMs,
    int? trimEndMs,
    void Function(double percent)? onProgress,
  }) async {
    final maxBytes = maxMB * 1024 * 1024;
    final targetMb = math.max(1, maxMB - 4); // marge (MB décimaux côté plugin)

    StreamSubscription<double>? sub;
    if (onProgress != null) {
      sub = _compressor.onProgressUpdated.listen(onProgress);
    }
    try {
      // Passe 1 : découpage et/ou compression vers la taille cible.
      var out = await _once(
        path,
        quality: needsCompress ? VideoQuality.medium : VideoQuality.high,
        targetMb: needsCompress ? targetMb : null,
        twoPass: needsCompress,
        trimStartMs: trimStartMs,
        trimEndMs: trimEndMs,
      );

      // Passe 2 plus agressive si échec ou encore trop gros.
      if (out == null || await File(out).length() > maxBytes) {
        out = await _once(
          out ?? path,
          quality: VideoQuality.low,
          targetMb: targetMb,
          twoPass: true,
          trimStartMs: out == null ? trimStartMs : null,
          trimEndMs: out == null ? trimEndMs : null,
        );
      }

      if (out != null && await File(out).length() <= maxBytes) return out;
      return null;
    } finally {
      await sub?.cancel();
    }
  }

  static Future<String?> _once(
    String path, {
    required VideoQuality quality,
    required int? targetMb,
    required bool twoPass,
    int? trimStartMs,
    int? trimEndMs,
  }) async {
    final result = await _compressor.compressVideo(
      path: path,
      videoQuality: quality,
      isMinBitrateCheckEnabled: false,
      android: AndroidConfig(isSharedStorage: false),
      ios: IOSConfig(saveInGallery: false),
      video: Video(
        videoName: 'status_${DateTime.now().millisecondsSinceEpoch}.mp4',
        targetSizeMb: targetMb,
        twoPass: twoPass,
      ),
      edit: (trimStartMs == null && trimEndMs == null)
          ? null
          : VideoEdit(trimStartMs: trimStartMs, trimEndMs: trimEndMs),
    );
    if (result is OnSuccess) return result.destinationPath;
    debugPrint('[Optimizer] ❌ échec compression vidéo: $result');
    return null;
  }
}
