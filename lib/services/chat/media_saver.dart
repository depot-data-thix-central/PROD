// lib/services/chat/media_saver.dart
import 'media_saver_stub.dart'
    if (dart.library.io) 'media_saver_io.dart'
    if (dart.library.html) 'media_saver_web.dart';

/// Télécharge un média (image/fichier) selon la plateforme.
/// Retourne le chemin local sauvegardé, ou null en cas d'échec.
class MediaSaver {
  static Future<String?> download({
    required String url,
    required String fileName,
  }) {
    return downloadImpl(url: url, fileName: fileName);
  }
}
