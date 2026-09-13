// lib/core/security/thix_input_guard.dart
// 🛡️ Garde-fou de sanitisation THIX — appliqué à TOUT contenu distant affiché.
//
// Protège contre :
//  • XSS / injection HTML (balises injectées depuis Supabase ou API)
//  • Attaques "Trojan Source" (caractères bidi invisibles qui inversent le code)
//  • Zero-width chars (espions invisibles / casse de layout)
//  • Caractères de contrôle (crash de rendu, overflow)
//  • URLs malveillantes (javascript:, data:, file:, userinfo@)
//  • Débordement de mémoire (strings géants → limites strictes)

class ThixInputGuard {
  ThixInputGuard._();

  static final RegExp _htmlTags = RegExp('<[^>]*>');
  static final RegExp _controlChars = RegExp('[\u0000-\u001F\u007F]');
  static final RegExp _zeroWidth = RegExp('[\u200B-\u200F\u2060\uFEFF]');
  static final RegExp _bidiOverrides = RegExp('[\u202A-\u202E\u2066-\u2069]');
  static final RegExp _whitespace = RegExp(r'\s+');

  /// ✅ Texte sûr pour affichage Flutter (jamais de HTML interprété)
  static String text(
    String? input, {
    int maxLength = 200,
    String fallback = '—',
  }) {
    if (input == null) return fallback;
    var s = input;
    s = s.replaceAll(_htmlTags, ' ');
    s = s.replaceAll(_controlChars, '');
    s = s.replaceAll(_zeroWidth, '');
    s = s.replaceAll(_bidiOverrides, '');
    s = s.replaceAll(_whitespace, ' ').trim();
    if (s.isEmpty) return fallback;
    if (s.length > maxLength) s = '${s.substring(0, maxLength)}…';
    return s;
  }

  /// ✅ Texte multiligne sûr (description, contenu)
  static String multiline(
    String? input, {
    int maxLength = 5000,
    String fallback = '',
  }) {
    if (input == null) return fallback;
    var s = input;
    s = s.replaceAll(_htmlTags, '');
    s = s.replaceAll(_controlChars, '');
    s = s.replaceAll(_zeroWidth, '');
    s = s.replaceAll(_bidiOverrides, '');
    s = s.trim();
    if (s.isEmpty) return fallback;
    if (s.length > maxLength) s = '${s.substring(0, maxLength)}…';
    return s;
  }

  /// ✅ URL sûre : uniquement http/https, host valide, sans userinfo
  /// Retourne null si l'URL est dangereuse → ne jamais charger.
  static String? url(String? raw) {
    if (raw == null) return null;
    final t = raw.trim();
    if (t.isEmpty || t.length > 2048) return null;
    final uri = Uri.tryParse(t);
    if (uri == null || !uri.hasScheme) return null;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return null; // bloque javascript:, data:, file:…
    final host = uri.host.toLowerCase();
    if (host.isEmpty || uri.userInfo.isNotEmpty) return null;
    if (!host.contains('.') && host != 'localhost') return null;
    return uri.toString();
  }

  static bool isSafeUrl(String? raw) => url(raw) != null;

  /// ✅ Date bornée (évite countdown absurde / crash de parsing)
  static DateTime safeDate(DateTime? d, {DateTime? fallback}) {
    final min = DateTime(2000);
    final max = DateTime(2100);
    if (d == null) return fallback ?? DateTime.now();
    if (d.isBefore(min) || d.isAfter(max)) return fallback ?? DateTime.now();
    return d;
  }
}
