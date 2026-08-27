// lib/services/chat/media_saver_web.dart
// ignore: avoid_web_lib_imports
import 'dart:html' as html;

Future<String?> downloadImpl({
  required String url,
  required String fileName,
}) async {
  try {
    final anchor = html.AnchorElement(href: url)
      ..target = '_blank'
      ..download = fileName;
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    return fileName;
  } catch (_) {
    return null;
  }
}
