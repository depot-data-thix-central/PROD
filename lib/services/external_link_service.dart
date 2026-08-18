import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class ExternalLinkService {
  static Future<bool> open(String url) async {
    final v = url.trim();
    if (v.isEmpty) return false;

    try {
      final uri = Uri.tryParse(v);
      if (uri == null) return false;

      final ok = await launchUrl(
        uri,
        mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
        webOnlyWindowName: kIsWeb ? '_blank' : null,
      );
      if (!ok) debugPrint('ExternalLinkService.open failed url=$url');
      return ok;
    } catch (e) {
      debugPrint('ExternalLinkService.open error url=$url err=$e');
      return false;
    }
  }
}
