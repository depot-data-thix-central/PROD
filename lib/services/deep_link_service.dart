// lib/services/deep_link_service.dart
// Deep-links : thix://post/ID + https://thix.app/post/ID → ouvrent l'app
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

/// URLs publiques de partage (utilisées par PostShareSheet)
class PostShareLinks {
  PostShareLinks._();
  static const String base = 'https://thix.app';
  static String post(String id) => '$base/post/$id';
  static String profile(String id) => '$base/profile/$id';
}

class DeepLinkService {
  DeepLinkService._();
  static AppLinks? _links;
  static StreamSubscription<Uri>? _sub;

  static Future<void> init(GoRouter router) async {
    if (kIsWeb) return;
    try {
      _links = AppLinks();

      // Lien qui a ouvert l'app (froid)
      final initial = await _links!.getInitialLink();
      if (initial != null) route(initial, router);

      // Liens pendant que l'app tourne (chaud)
      _sub = _links!.uriLinkStream.listen(
        (uri) => route(uri, router),
        onError: (e) => debugPrint('[DeepLink] stream error: $e'),
      );
      debugPrint('[DeepLink] ✓ initialized');
    } catch (e) {
      debugPrint('[DeepLink] ❌ init: $e');
    }
  }

  static void route(Uri uri, GoRouter router) {
    debugPrint('[DeepLink] → $uri');
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();

    // thix://post/ID  |  https://thix.app/post/ID
    if (segs.isNotEmpty && segs[0] == 'post' && segs.length > 1) {
      router.go('/network/comments/${segs[1]}');
      return;
    }
    // thix://profile/ID | https://thix.app/profile/ID
    if (segs.isNotEmpty && segs[0] == 'profile' && segs.length > 1) {
      router.go('/network/profile/${segs[1]}');
      return;
    }
    // URL web interne /network/comments/ID
    if (segs.length >= 3 && segs[0] == 'network' && segs[1] == 'comments') {
      router.go('/network/comments/${segs[2]}');
      return;
    }
    // ?post=ID
    final q = uri.queryParameters['post'];
    if (q != null && q.isNotEmpty) router.go('/network/comments/$q');
  }

  static void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
