// lib/core/utils/web_redirect.dart
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// URL de base RÉELLE de l'app web (inclut le sous-dossier GitHub Pages).
/// Ex: https://org.github.io/PROD/  (et non https://org.github.io/)
String webRedirectBase(BuildContext context) {
  final base = Uri.base;
  var path = base.path;
  try {
    // On retire la portion de route GoRouter (ex: /login) pour ne garder que le base-href
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc.isNotEmpty && loc != '/' && path.endsWith(loc)) {
      path = path.substring(0, path.length - loc.length);
    }
  } catch (_) {}
  if (!path.endsWith('/')) path = '$path/';
  return base.origin + path;
}
