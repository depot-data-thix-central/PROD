import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

enum MediaSaveResult { saved, denied, failed, unsupported }

class MediaSaver {
  MediaSaver._();

  static const String album = 'THIX';
  static const Duration _timeout = Duration(seconds: 60);

  static String _extension(String url, bool isVideo) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    const known = ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.mp4', '.mov', '.m4v', '.webm'];
    for (final e in known) {
      if (path.endsWith(e)) return e;
    }
    return isVideo ? '.mp4' : '.jpg';
  }

  /// Télécharge le média et l'enregistre dans la galerie (album « THIX »).
  static Future<MediaSaveResult> save(
    String url, {
    required bool isVideo,
    void Function(double progress)? onProgress,
  }) async {
    if (kIsWeb) return MediaSaveResult.unsupported;

    File? tmp;
    final client = http.Client();
    try {
      if (!await Gal.hasAccess(toAlbum: true)) {
        if (!await Gal.requestAccess(toAlbum: true)) return MediaSaveResult.denied;
      }

      final response = await client.send(http.Request('GET', Uri.parse(url))).timeout(_timeout);
      if (response.statusCode != 200) return MediaSaveResult.failed;

      final dir = await getTemporaryDirectory();
      tmp = File('${dir.path}/thix_${DateTime.now().millisecondsSinceEpoch}${_extension(url, isVideo)}');
      final sink = tmp.openWrite();
      final total = response.contentLength ?? 0;
      var received = 0;

      await for (final chunk in response.stream.timeout(_timeout)) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
      await sink.flush();
      await sink.close();

      if (isVideo) {
        await Gal.putVideo(tmp.path, album: album);
      } else {
        await Gal.putImage(tmp.path, album: album);
      }
      return MediaSaveResult.saved;
    } on GalException catch (e) {
      debugPrint('[MediaSaver] gal: ${e.type}');
      return e.type == GalExceptionType.accessDenied ? MediaSaveResult.denied : MediaSaveResult.failed;
    } catch (e) {
      debugPrint('[MediaSaver] error: $e');
      return MediaSaveResult.failed;
    } finally {
      client.close();
      try {
        if (tmp != null && await tmp.exists()) await tmp.delete();
      } catch (_) {}
    }
  }
}
