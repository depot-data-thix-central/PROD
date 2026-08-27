// lib/services/chat/media_saver_io.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String?> downloadImpl({
  required String url,
  required String fileName,
}) async {
  try {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;

    String? savedPath;

    // Android : tente le dossier public Download (si accessible)
    if (Platform.isAndroid) {
      try {
        final pub = Directory('/storage/emulated/0/Download');
        if (await pub.exists()) {
          final f = File(p.join(pub.path, fileName));
          await f.writeAsBytes(res.bodyBytes);
          savedPath = f.path;
        }
      } catch (e) {
        debugPrint('MediaSaver public Download: $e');
      }
    }

    // Fallback : dossier documents de l'app (toujours accessible)
    if (savedPath == null) {
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory(p.join(dir.path, 'THIX Downloads'));
      if (!await folder.exists()) await folder.create(recursive: true);
      final f = File(p.join(folder.path, fileName));
      await f.writeAsBytes(res.bodyBytes);
      savedPath = f.path;
    }

    return savedPath;
  } catch (e) {
    debugPrint('MediaSaver download error: $e');
    return null;
  }
}
