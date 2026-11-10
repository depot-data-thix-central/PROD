// ════════════════════════════════════════════════════════════════════════════
//  THIX PORTFOLIO BUSINESS — PAGE PUBLIQUE « CORPORATE PREMIUM »
//  Fichier  : lib/presentation/thix_portfolio/pages/business_public_page.dart
//  Module   : THIX Portfolio Business
//  Éditeur  : SONATHIX GROUP — Kinshasa, RDC
//  Version  : 8.0.0 — Novembre 2026 (Corporate Premium — conforme maquette)
// ════════════════════════════════════════════════════════════════════════════
//
//  ✅ v8.0 — REDESIGN 100 % « CORPORATE PREMIUM » (maquette SONATHIX) :
//    • En-tête blanc : logo + nom, BADGE VERT « Entreprise Vérifiée », EN/FR, ⋮
//    • Hero image plein cadre : titre BI-COLOR (blanc / or), claim bold,
//      paragraphe, CTA pill OR « Découvrir » + pill outline « Nous contacter »,
//      dots carrousel en bas à droite
//    • IDENTITÉ : barre info compacte en GRILLE (3 col.) qui chevauche le hero
//      → fini les lignes verticales espacées
//    • Sections : barre verticale bleue + titre bold + lien « Voir tous → »
//    • Services : GRILLE de cartes blanches à icônes colorées (sans cadre lourd)
//    • Réalisations : vignettes arrondies + bouton flèche circulaire blanc
//    • Équipe : avatars cerclés centrés, sans carte
//    • Bannière CTA navy « Travaillons ensemble ! » + bouton or
//    • Footer COMPACT 3 colonnes : marque / suivez-nous / QR code
//    • FR / EN, 10 rubriques avancées, images web robustes
// ════════════════════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/business_extras.dart';
import '../data/business_repository.dart';
import '../models/business_bundle.dart';
import '../models/business_theme.dart';
import '../widgets/reveal_on_scroll.dart';

const String kThixPublicBaseUrl = 'https://thixid.com';
const double _kMaxW = 1120;

/// Palette icônes services (comme maquette : bleu, violet, vert, orange…).
const List<Color> _kIconPalette = [
  Color(0xFF2563EB),
  Color(0xFF7C3AED),
  Color(0xFF16A34A),
  Color(0xFFF59E0B),
  Color(0xFF0EA5E9),
];

const Color _kGreen = Color(0xFF16A34A);
const Color _kPageBg = Color(0xFFF4F6FA);

// ─────────────────────────────────────────────────────────────────────────────
// i18n FR / EN
// ─────────────────────────────────────────────────────────────────────────────
const Map<String, Map<String, String>> _i18n = {
  'fr': {
    'contact_us': 'Nous contacter',
    'discover': 'Découvrir nos services',
    'share': 'Partager',
    'contact': 'Contacter',
    'verified': 'ENTREPRISE VÉRIFIÉE',
    'verified_status': 'Entreprise Vérifiée',
    'years': "ans d'expérience",
    'staff': 'collaborateurs',
    'visits': 'visites',
    'since': 'Depuis',
    'read_full': 'Lire la suite',
    'see_more': 'Voir plus',
    'see_less': 'Voir moins',
    'see_all': 'Voir tous',
    'view_profile': 'Voir le profil',
    'copy_id': "Copier l'ID",
    'copied': 'ID copié : ',
    'qr': 'QR code',
    'close': 'Fermer',
    'open': 'Ouvrir',
    'no_channel': 'Aucun canal de contact renseigné.',
    'contact_prefix': 'Contacter',
    'rights': 'Tous droits réservés.',
    'powered': 'Propulsé par THIX HUB',
    'watch': 'Voir la vidéo',
    'learn_more': 'En savoir plus',
    'apply': 'Postuler',
    'lang_tip': 'English',
    'share_msg': 'Découvrez {name} sur THIX 🚀',
    'top': 'Haut de page',
    'menu': 'Menu',
    'nav': 'Navigation',
    'contact_info': 'Contact',
    'profile': 'Profil',
    'identity': "Fiche d'identité",
    'overview': 'Présentation',
    'step': 'Étape',
    'follow': 'Suivez-nous',
    'scan': 'Scannez pour visiter notre site',
    'work_together': 'Travaillons ensemble !',
    'work_sub': 'Contactez-nous pour vos projets et partenariats.',
    'f_name': 'Dénomination',
    'f_sector': "Secteur d'activité",
    'f_hq': 'Siège',
    'f_since': 'Création',
    'f_staff': 'Effectif',
    'f_web': 'Site web',
    'f_phone': 'Téléphone',
    'f_email': 'Email',
    'f_id': 'Identifiant THIX',
    'f_status': 'Statut',
  },
  'en': {
    'contact_us': 'Contact us',
    'discover': 'Discover our services',
    'share': 'Share',
    'contact': 'Contact',
    'verified': 'VERIFIED COMPANY',
    'verified_status': 'Verified Company',
    'years': 'years of experience',
    'staff': 'team members',
    'visits': 'visits',
    'since': 'Since',
    'read_full': 'Read more',
    'see_more': 'See more',
    'see_less': 'See less',
    'see_all': 'See all',
    'view_profile': 'View profile',
    'copy_id': 'Copy ID',
    'copied': 'ID copied: ',
    'qr': 'QR code',
    'close': 'Close',
    'open': 'Open',
    'no_channel': 'No contact channel provided.',
    'contact_prefix': 'Contact',
    'rights': 'All rights reserved.',
    'powered': 'Powered by THIX HUB',
    'watch': 'Watch video',
    'learn_more': 'Learn more',
    'apply': 'Apply',
    'lang_tip': 'Français',
    'share_msg': 'Discover {name} on THIX 🚀',
    'top': 'Back to top',
    'menu': 'Menu',
    'nav': 'Navigation',
    'contact_info': 'Contact',
    'profile': 'Profile',
    'identity': 'Company profile',
    'overview': 'Overview',
    'step': 'Step',
    'follow': 'Follow us',
    'scan': 'Scan to visit our site',
    'work_together': 'Let’s work together!',
    'work_sub': 'Contact us for your projects and partnerships.',
    'f_name': 'Company name',
    'f_sector': 'Industry',
    'f_hq': 'Headquarters',
    'f_since': 'Founded',
    'f_staff': 'Team size',
    'f_web': 'Website',
    'f_phone': 'Phone',
    'f_email': 'Email',
    'f_id': 'THIX ID',
    'f_status': 'Status',
  },
};

const Map<String, String> _titlesEn = {
  'À propos': 'About',
  'À propos de nous': 'About us',
  'Nos services': 'Our services',
  'Services': 'Services',
  'Produits': 'Products',
  'Nos produits': 'Our products',
  'Galerie': 'Gallery',
  'Nos réalisations': 'Our work',
  'Équipe': 'Team',
  'Notre équipe': 'Our team',
  'Actualités': 'News',
  'Témoignages': 'Testimonials',
  'Contact': 'Contact',
  'Nos informations': 'Our information',
};

String _t(String lang, String key) => _i18n[lang]?[key] ?? key;

class _LangScope extends InheritedWidget {
  const _LangScope({required this.code, required super.child});
  final String code;
  static String of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<_LangScope>()?.code ?? 'fr';
  @override
  bool updateShouldNotify(_LangScope old) => old.code != code;
}

String _tr(BuildContext c, String key) => _t(_LangScope.of(c), key);
String _tt(BuildContext c, String title) =>
    _LangScope.of(c) == 'en' ? (_titlesEn[title.trim()] ?? title) : title;

String _fmtDate(String lang, DateTime d) {
  try {
    return DateFormat.yMMMd(lang == 'fr' ? 'fr_FR' : 'en_US').format(d);
  } catch (_) {
    return '${d.day}/${d.month}/${d.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
class _DragScrollBehavior extends MaterialScrollBehavior {
  const _DragScrollBehavior();
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

Future<void> _openUrl(String? url) async {
  if (url == null || url.trim().isEmpty) return;
  var u = url.trim();
  if (!u.startsWith('http')) u = 'https://$u';
  final uri = Uri.tryParse(u);
  if (uri != null) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Future<void> _openTel(String phone) => launchUrl(
    Uri.parse('tel:${phone.replaceAll(RegExp(r'\s+'), '')}'),
    mode: LaunchMode.externalApplication);

Future<void> _openMail(String mail) =>
    launchUrl(Uri.parse('mailto:$mail'), mode: LaunchMode.externalApplication);

Color _accent(BuildContext c) =>
    Theme.of(c).extension<BusinessThemeExt>()?.accent ??
    Theme.of(c).colorScheme.tertiary;

/// Encre navy des titres (primary assombri, comme maquette).
Color _ink(BuildContext c) =>
    Color.lerp(Theme.of(c).colorScheme.primary, Colors.black, 0.45)!;

List<BoxShadow> _softShadow(BuildContext c) => [
      BoxShadow(
        color: _ink(c).withValues(alpha: 0.08),
        blurRadius: 24,
        offset: const Offset(0, 10),
      ),
    ];

String _compact(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

String _country(String lang, String code) {
  const m = {
    'CD': ('RD Congo', 'DR Congo'),
    'CG': ('Congo-Brazzaville', 'Congo-Brazzaville'),
    'CM': ('Cameroun', 'Cameroon'),
    'FR': ('France', 'France'),
    'BE': ('Belgique', 'Belgium'),
  };
  final v = m[code.toUpperCase()];
  if (v == null) return code;
  return lang == 'fr' ? v.$1 : v.$2;
}

class _ImgFallback extends StatelessWidget {
  const _ImgFallback();
  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Colors.black.withValues(alpha: 0.03),
        child: const Center(
          child: Icon(Icons.image_not_supported_outlined,
              size: 22, color: Colors.black26),
        ),
      );
}

/// Image réseau robuste (repli <img> HTML sur le web → évite les erreurs CORS).
Widget _img(String url, {BoxFit fit = BoxFit.cover, Widget? fallback}) {
  return ColoredBox(
    color: Colors.black.withValues(alpha: 0.02),
    child: Image.network(
      url,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      frameBuilder: (c, child, frame, sync) => sync
          ? child
          : AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 400),
              child: child,
            ),
      errorBuilder: (_, __, ___) => fallback ?? const _ImgFallback(),
    ),
  );
}

void _viewImage(BuildContext context, String url) {
  showDialog<void>(
    context: context,
    builder: (_) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Tap extends StatelessWidget {
  const _Tap({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      ),
    );
  }
}

class _Wrap extends StatelessWidget {
  const _Wrap({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kMaxW),
          child: child,
        ),
      );
}

class _Rise extends StatelessWidget {
  const _Rise({required this.child, this.delay = 0, this.dy = 20});
  final Widget child;
  final int delay;
  final double dy;
  @override
  Widget build(BuildContext context) {
    final total = 650 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      builder: (_, v, ch) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - v) * dy), child: ch),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Briques UI corporate
// ─────────────────────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.url,
    required this.name,
    required this.radius,
    this.ring,
  });
  final String? url;
  final String name;
  final double radius;
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = radius * 2;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final fb = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Text(initial,
            style: TextStyle(
                fontSize: radius * 0.9,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant)),
      ),
    );
    final has = url != null && url!.isNotEmpty;
    return Container(
      padding: ring != null ? const EdgeInsets.all(3) : EdgeInsets.zero,
      decoration: ring != null
          ? BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: ring!, width: 2),
            )
          : null,
      child: ClipOval(
        child: SizedBox(
          width: d,
          height: d,
          child: has ? _img(url!, fallback: fb) : fb,
        ),
      ),
    );
  }
}

class _MoreLink extends StatelessWidget {
  const _MoreLink({required this.label, required this.onTap, this.icon});
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).colorScheme.primary;
    return _Tap(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  color: p, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(width: 6),
          Icon(icon ?? Icons.arrow_forward_rounded, size: 16, color: p),
        ],
      ),
    );
  }
}

bool _exceeds(
    BuildContext c, String text, TextStyle style, int maxLines, double w) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: maxLines,
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(c),
  )..layout(maxWidth: w);
  final over = tp.didExceedMaxLines;
  tp.dispose();
  return over;
}

class _ClampText extends StatelessWidget {
  const _ClampText(
    this.text, {
    required this.maxLines,
    required this.onMore,
    this.style,
    this.showLink = true,
  });
  final String text;
  final int maxLines;
  final VoidCallback onMore;
  final TextStyle? style;
  final bool showLink;

  @override
  Widget build(BuildContext context) {
    final st = style ??
        Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6) ??
        const TextStyle(fontSize: 14, height: 1.6);
    return LayoutBuilder(
      builder: (c, cs) {
        final over = showLink && _exceeds(c, text, st, maxLines, cs.maxWidth);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: st),
            if (over)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _MoreLink(label: _tr(c, 'see_more'), onTap: onMore),
              ),
          ],
        );
      },
    );
  }
}

class _ExpandText extends StatefulWidget {
  const _ExpandText(this.text, {this.maxLines = 6, this.style});
  final String text;
  final int maxLines;
  final TextStyle? style;
  @override
  State<_ExpandText> createState() => _ExpandTextState();
}

class _ExpandTextState extends State<_ExpandText> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    final st = widget.style ??
        Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.7) ??
        const TextStyle(fontSize: 15, height: 1.7);
    return LayoutBuilder(
      builder: (c, cs) {
        final over = _exceeds(c, widget.text, st, widget.maxLines, cs.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              alignment: Alignment.topCenter,
              child: Text(
                widget.text,
                style: st,
                maxLines: _open ? null : widget.maxLines,
                overflow: _open ? TextOverflow.visible : TextOverflow.ellipsis,
              ),
            ),
            if (over)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: _MoreLink(
                  label: _tr(c, _open ? 'see_less' : 'see_more'),
                  icon: _open
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  onTap: () => setState(() => _open = !_open),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Fiche détail (texte complet) — bottom sheet arrondi.
void _showDetail(
  BuildContext context, {
  required String title,
  String? subtitle,
  String? image,
  String? chip,
  String? text,
  String? url,
  String? urlLabel,
}) {
  final lang = _LangScope.of(context);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.85),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  if (image != null && image.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                            height: 240, width: double.infinity, child: _img(image)),
                      ),
                    ),
                  if (chip != null && chip.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _accent(ctx).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(chip.toUpperCase(),
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                                color: _ink(ctx))),
                      ),
                    ),
                  Text(title,
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                          height: 1.2,
                          color: _ink(ctx))),
                  if (subtitle != null && subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(subtitle,
                          style: TextStyle(
                              fontSize: 14, color: scheme.onSurfaceVariant)),
                    ),
                  if (text != null && text.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    SelectableText(text,
                        style: Theme.of(ctx)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(height: 1.7)),
                  ],
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      if (url != null && url.isNotEmpty) ...[
                        FilledButton.icon(
                          onPressed: () => _openUrl(url),
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          label: Text(urlLabel ?? _t(lang, 'open')),
                          style: FilledButton.styleFrom(
                              shape: const StadiumBorder()),
                        ),
                        const SizedBox(width: 12),
                      ],
                      OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(_t(lang, 'close')),
                        style: OutlinedButton.styleFrom(
                            shape: const StadiumBorder()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// En-tête de section « maquette » : barre verticale + titre bold + lien droite.
Widget _secHead(
  BuildContext context,
  String title, {
  String? moreLabel,
  VoidCallback? onMore,
  Widget? trailing,
}) {
  final scheme = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.only(bottom: 28),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _tt(context, title),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: _ink(context),
            ),
          ),
        ),
        if (onMore != null)
          _MoreLink(label: moreLabel ?? _tr(context, 'see_all'), onTap: onMore),
        if (trailing != null) trailing,
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Page racine
// ─────────────────────────────────────────────────────────────────────────────
class BusinessPublicPage extends ConsumerWidget {
  const BusinessPublicPage({super.key, required this.thixId});
  final String thixId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = ref.watch(businessPublicBundleProvider(thixId));
    return bundle.when(
      loading: () => const _PublicSkeleton(),
      error: (error, _) => _PublicNotFound(
        thixId: thixId,
        invalid: error is BusinessIdInvalidException,
        onRetry: () => ref.invalidate(businessPublicBundleProvider(thixId)),
      ),
      data: (bundle) {
        final ext = BusinessThemeExt(
          style: bundle.theme.animationStyle,
          radius: bundle.theme.radius,
          accent: bundle.theme.accent,
        );
        return Theme(
          data: bundle.theme.toThemeData().copyWith(extensions: [ext]),
          child: _BusinessSite(bundle: bundle),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton / introuvable
// ─────────────────────────────────────────────────────────────────────────────
class _PublicSkeleton extends StatelessWidget {
  const _PublicSkeleton();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget block(double h) => Container(
          height: h,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
        );
    return Scaffold(
      backgroundColor: _kPageBg,
      body: Shimmer.fromColors(
        baseColor: scheme.surfaceContainerHighest,
        highlightColor: scheme.surface,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(height: 64, color: Colors.white),
            Container(height: 420, color: Colors.white),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [block(96), block(220), block(160)]),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicNotFound extends StatelessWidget {
  const _PublicNotFound({
    required this.thixId,
    this.invalid = false,
    this.onRetry,
  });
  final String thixId;
  final bool invalid;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: _kPageBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.storefront_outlined,
                  size: 84, color: theme.colorScheme.outline),
              const SizedBox(height: 24),
              Text(
                invalid ? 'Identifiant invalide' : 'Entreprise introuvable',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                invalid
                    ? '« $thixId » n\'est pas un THIX ID Business valide.'
                    : 'Aucune entreprise publiée ne correspond à « $thixId ».',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              if (onRetry != null)
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer / Retry'),
                  style: FilledButton.styleFrom(shape: const StadiumBorder()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SITE
// ─────────────────────────────────────────────────────────────────────────────
class _Blk {
  const _Blk(this.id, this.label, this.child);
  final String id;
  final String label;
  final Widget child;
}

bool _isEmpty(BusinessSectionContent c) => switch (c) {
      AboutContent() => c.body.trim().isEmpty,
      ServicesContent() => c.items.isEmpty,
      ProductsContent() => c.items.isEmpty,
      GalleryContent() => c.images.isEmpty,
      TeamContent() => c.members.isEmpty,
      NewsContent() => c.posts.isEmpty,
      TestimonialsContent() => c.items.isEmpty,
      ContactContent() => c.channels.isEmpty,
    };

String _titleOf(BusinessSectionContent c) => switch (c) {
      AboutContent() => c.title,
      ServicesContent() => c.title,
      ProductsContent() => c.title,
      GalleryContent() => c.title,
      TeamContent() => c.title,
      NewsContent() => c.title,
      TestimonialsContent() => c.title,
      ContactContent() => c.title,
    };

class _BusinessSite extends ConsumerStatefulWidget {
  const _BusinessSite({required this.bundle});
  final BusinessBundle bundle;
  @override
  ConsumerState<_BusinessSite> createState() => _BusinessSiteState();
}

class _BusinessSiteState extends ConsumerState<_BusinessSite> {
  String _lang = 'fr';
  final ScrollController _scroll = ScrollController();
  final Map<String, GlobalKey> _keys = {};

  BusinessBundle get bundle => widget.bundle;
  GlobalKey _key(String id) => _keys.putIfAbsent(id, () => GlobalKey());

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  List<String> _heroImages() {
    final out = <String>[];
    final cover = bundle.business.coverUrl;
    if (cover != null && cover.isNotEmpty) out.add(cover);
    final g = bundle.sectionOfType(BusinessSectionType.gallery)?.content;
    if (g is GalleryContent) {
      for (final i in g.images) {
        if (i.url.isNotEmpty && !out.contains(i.url)) out.add(i.url);
      }
    }
    final n = bundle.sectionOfType(BusinessSectionType.news)?.content;
    if (n is NewsContent) {
      for (final p in n.posts) {
        final u = p.imageUrl;
        if (u != null && u.isNotEmpty && !out.contains(u)) out.add(u);
      }
    }
    return out.take(6).toList();
  }

  String _label(String title) =>
      _lang == 'en' ? (_titlesEn[title.trim()] ?? title) : title;

  void _goTo(String id) {
    final ctx = _keys[id]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOutCubic,
      alignment: 0.08,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = bundle.theme;
    final scheme = Theme.of(context).colorScheme;
    final lang = _lang;
    final sections = bundle.visibleSections;
    final extras = ref
        .watch(businessExtrasProvider(bundle.business.id))
        .maybeWhen(data: (d) => d, orElse: () => <BizExtra>[]);
    final visibleExtras = extras.where((e) => e.visible && e.hasContent).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    final main = sections
        .where((s) =>
            s.type != BusinessSectionType.contact && !_isEmpty(s.content))
        .toList();
    final contact = sections
        .where((s) =>
            s.type == BusinessSectionType.contact && !_isEmpty(s.content))
        .toList();
    final blocks = <_Blk>[
      for (final s in main)
        _Blk('s-${s.id}', _label(_titleOf(s.content)),
            _SectionRenderer(section: s)),
      for (final e in visibleExtras)
        if (kBizKindByKey[e.kind] != null)
          _Blk(
            'x-${e.kind}',
            (e.title?.trim().isNotEmpty ?? false)
                ? e.title!.trim()
                : (lang == 'en'
                    ? kBizKindByKey[e.kind]!.en
                    : kBizKindByKey[e.kind]!.fr),
            _ExtraSection(extra: e),
          ),
    ];
    final firstSection = blocks.isNotEmpty ? blocks[0].id : 'contact-cta';

    return _LangScope(
      code: lang,
      child: Scaffold(
        backgroundColor: _kPageBg,
        floatingActionButton: _ContactFab(
          label: _t(lang, 'contact'),
          accent: theme.accent ?? const Color(0xFFEAB308),
          onTap: _openContactSheet,
        ),
        body: ScrollConfiguration(
          behavior: const _DragScrollBehavior(),
          child: CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverAppBar(
                pinned: true,
                automaticallyImplyLeading: false,
                toolbarHeight: 64,
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                scrolledUnderElevation: 2,
                elevation: 0,
                titleSpacing: 0,
                title: _headerTitle(context, blocks),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Container(
                      height: 1,
                      color: scheme.outlineVariant.withValues(alpha: 0.4)),
                ),
              ),
              SliverToBoxAdapter(
                child: _Hero(
                  bundle: bundle,
                  images: _heroImages(),
                  onContact: _openContactSheet,
                  onDiscover: () => _goTo(firstSection),
                ),
              ),
              // Barre identité compacte qui chevauche le hero
              SliverToBoxAdapter(
                child: _Wrap(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(24, -52, 24, 8),
                    child: _IdentityStrip(business: bundle.business),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    for (var i = 0; i < blocks.length; i++)
                      _Band(
                        index: i,
                        child: KeyedSubtree(
                          key: _key(blocks[i].id),
                          child: RevealOnScroll(
                            style: theme.animationStyle,
                            staggerIndex: 0,
                            child: blocks[i].child,
                          ),
                        ),
                      ),
                    KeyedSubtree(
                      key: _key('contact-cta'),
                      child: _CtaBanner(
                        bundle: bundle,
                        onContact: _openContactSheet,
                      ),
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: _Footer(
                  bundle: bundle,
                  links: [
                    for (final b in blocks) (b.label, () => _goTo(b.id)),
                  ],
                  onTop: () => _scroll.animateTo(0,
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOutCubic),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── En-tête blanc : logo + nom + badge vert + EN/FR + ⋮ ──
  Widget _headerTitle(BuildContext context, List<_Blk> blocks) {
    final scheme = Theme.of(context).colorScheme;
    final b = bundle.business;
    final wide = MediaQuery.sizeOf(context).width >= 960;
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (canPop)
            IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          if (!wide)
            IconButton(
              tooltip: _t(_lang, 'menu'),
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => _openMenu(blocks),
            ),
          _Avatar(url: b.logoUrl, name: b.name, radius: 19),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  b.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15.5,
                      letterSpacing: -0.2,
                      color: _ink(context)),
                ),
                if (b.sector != null && b.sector!.trim().isNotEmpty)
                  Text(
                    b.sector!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10.5, color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          if (b.verified) ...[
            const SizedBox(width: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_rounded, size: 14, color: _kGreen),
                  const SizedBox(width: 6),
                  Text(
                    _t(_lang, 'verified_status'),
                    style: const TextStyle(
                        color: Color(0xFF15803D),
                        fontSize: 11,
                        fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
          if (wide) ...[
            const SizedBox(width: 24),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  children: [
                    for (final blk in blocks.take(6))
                      TextButton(
                        onPressed: () => _goTo(blk.id),
                        style: TextButton.styleFrom(
                          foregroundColor: _ink(context),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: Text(blk.label,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 12.5)),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          Tooltip(
            message: _t(_lang, 'lang_tip'),
            child: TextButton(
              onPressed: () => setState(() => _lang = _lang == 'fr' ? 'en' : 'fr'),
              style: TextButton.styleFrom(
                backgroundColor: scheme.primary.withValues(alpha: 0.08),
                minimumSize: const Size(44, 38),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: const StadiumBorder(),
              ),
              child: Text(_lang == 'fr' ? 'EN' : 'FR',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      fontSize: 12,
                      color: scheme.primary)),
            ),
          ),
          PopupMenuButton<int>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) {
              if (v == 0) _copyId();
              if (v == 1) _showQr();
              if (v == 2) _share();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 0,
                child: Row(children: [
                  const Icon(Icons.content_copy_rounded, size: 18),
                  const SizedBox(width: 12),
                  Text(_t(_lang, 'copy_id')),
                ]),
              ),
              PopupMenuItem(
                value: 1,
                child: Row(children: [
                  const Icon(Icons.qr_code_2_rounded, size: 18),
                  const SizedBox(width: 12),
                  Text(_t(_lang, 'qr')),
                ]),
              ),
              PopupMenuItem(
                value: 2,
                child: Row(children: [
                  const Icon(Icons.ios_share_rounded, size: 18),
                  const SizedBox(width: 12),
                  Text(_t(_lang, 'share')),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openMenu(List<_Blk> blocks) {
    final lang = _lang;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Text(_t(lang, 'menu').toUpperCase(),
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5)),
                ),
                for (final blk in blocks)
                  ListTile(
                    shape: const StadiumBorder(),
                    leading: Icon(Icons.chevron_right_rounded,
                        size: 18, color: Theme.of(ctx).colorScheme.primary),
                    title: Text(blk.label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      Future.delayed(const Duration(milliseconds: 300),
                          () => _goTo(blk.id));
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copyId() async {
    await Clipboard.setData(ClipboardData(text: bundle.business.thixId));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('${_t(_lang, 'copied')}${bundle.business.thixId}'),
      ),
    );
  }

  void _share() {
    final url = '$kThixPublicBaseUrl/b/${bundle.business.thixId}';
    Share.share(
        '${_t(_lang, 'share_msg').replaceAll('{name}', bundle.business.name)}\n$url\nID : ${bundle.business.thixId}');
  }

  void _showQr() {
    final scheme = Theme.of(context).colorScheme;
    final lang = _lang;
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(bundle.business.name,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: _ink(context))),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: QrImageView(
                  data: bundle.business.thixId,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              SelectableText(
                bundle.business.thixId,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                    letterSpacing: 0.5),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
                child: Text(_t(lang, 'close')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openContactSheet() {
    final lang = _lang;
    final section = bundle.sectionOfType(BusinessSectionType.contact);
    final channels = section?.content is ContactContent
        ? (section!.content as ContactContent).channels
        : const <ContactChannel>[];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(sheetCtx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: channels.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_t(lang, 'no_channel')),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Theme.of(sheetCtx).colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        '${_t(lang, 'contact_prefix')} ${bundle.business.name}',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _ink(sheetCtx)),
                      ),
                      const SizedBox(height: 12),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              for (final c in channels) _ContactTile(channel: c),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// FAB pill noire lisérée or (style THIX PRO).
class _ContactFab extends StatelessWidget {
  const _ContactFab({
    required this.label,
    required this.accent,
    required this.onTap,
  });
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Tap(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            colors: [Color(0xFF0B0F14), Color(0xFF1B2430)],
          ),
          border: Border.all(color: accent.withValues(alpha: 0.9), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.35),
              blurRadius: 26,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 18, color: accent),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _Band extends StatelessWidget {
  const _Band({required this.index, required this.child});
  final int index;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: _Wrap(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO (maquette : image plein cadre, titre bi-color, CTA or + outline)
// ─────────────────────────────────────────────────────────────────────────────
class _Hero extends StatelessWidget {
  const _Hero({
    required this.bundle,
    required this.images,
    required this.onContact,
    required this.onDiscover,
  });
  final BusinessBundle bundle;
  final List<String> images;
  final VoidCallback onContact;
  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    final theme = bundle.theme;
    final b = bundle.business;
    final size = MediaQuery.sizeOf(context);
    final height = math.min(math.max(480.0, size.height * 0.56), 640.0);
    final narrow = size.width < 700;
    final navy = Color.lerp(theme.primary, Colors.black, 0.45)!;
    final accent = theme.accent ?? const Color(0xFFEAB308);
    final words = b.name.trim().split(RegExp(r'\s+'));
    final line1 = words.first;
    final line2 = words.skip(1).join(' ');
    final desc = b.description?.trim() ?? '';

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _HeroCarousel(images: images, colors: theme.heroGradient),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  stops: const [0, 0.55, 1],
                  colors: [
                    navy.withValues(alpha: 0.96),
                    navy.withValues(alpha: 0.72),
                    navy.withValues(alpha: 0.10),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kMaxW),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Rise(
                          child: Text(
                            line1.toUpperCase(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: narrow ? 40 : 62,
                              height: 1.0,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.5,
                            ),
                          ),
                        ),
                        if (line2.isNotEmpty)
                          _Rise(
                            delay: 80,
                            child: Text(
                              line2.toUpperCase(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: accent,
                                fontSize: narrow ? 40 : 62,
                                height: 1.0,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.5,
                              ),
                            ),
                          ),
                        if (b.claim != null && b.claim!.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: _Rise(
                              delay: 160,
                              child: Text(
                                b.claim!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: narrow ? 20 : 26,
                                  height: 1.25,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                          ),
                        if (desc.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: _Rise(
                              delay: 220,
                              child: Text(
                                desc,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: narrow ? 13.5 : 15,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 30),
                        _Rise(
                          delay: 300,
                          child: Wrap(
                            spacing: 14,
                            runSpacing: 12,
                            children: [
                              FilledButton.icon(
                                onPressed: onDiscover,
                                icon: const Icon(Icons.rocket_launch_rounded,
                                    size: 17),
                                label: Text(_tr(context, 'discover'),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.2)),
                                style: FilledButton.styleFrom(
                                  backgroundColor: accent,
                                  foregroundColor:
                                      Color.lerp(navy, Colors.black, 0.3),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 15),
                                  shape: const StadiumBorder(),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: onContact,
                                icon: const Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 16),
                                label: Text(_tr(context, 'contact_us'),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.2)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(
                                      color: Colors.white, width: 1.4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 15),
                                  shape: const StadiumBorder(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCarousel extends StatefulWidget {
  const _HeroCarousel({required this.images, required this.colors});
  final List<String> images;
  final List<Color> colors;
  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  final PageController _pc = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    if (widget.images.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 6), (_) {
        if (!mounted || !_pc.hasClients) return;
        final next = (_index + 1) % widget.images.length;
        _pc.animateToPage(next,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOutCubic);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imgs = widget.images;
    final accent = _accent(context);
    final gradient = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.colors.length >= 2
              ? widget.colors
              : [Theme.of(context).colorScheme.primary, Colors.black87],
        ),
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        gradient,
        if (imgs.isNotEmpty)
          PageView.builder(
            controller: _pc,
            itemCount: imgs.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => _img(imgs[i], fallback: const SizedBox()),
          ),
        if (imgs.length > 1)
          Positioned(
            right: 24,
            bottom: 76,
            child: Row(
              children: [
                for (var i = 0; i < imgs.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(left: 6),
                    width: i == _index ? 10 : 8,
                    height: i == _index ? 10 : 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _index ? accent : Colors.white54,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BARRE IDENTITÉ COMPACTE (grille, chevauche le hero)
// ─────────────────────────────────────────────────────────────────────────────
class _IdentityStrip extends StatelessWidget {
  const _IdentityStrip({required this.business});
  final Business business;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lang = _LangScope.of(context);
    final b = business;
    final where = [
      if (b.city != null && b.city!.trim().isNotEmpty) b.city!.trim(),
      if (b.country.trim().isNotEmpty) _country(lang, b.country),
    ].join(', ');
    final cells = <(IconData, String, String, VoidCallback?)>[
      if (b.sector != null && b.sector!.trim().isNotEmpty)
        (Icons.category_rounded, _tr(context, 'f_sector'), b.sector!, null),
      if (where.isNotEmpty)
        (Icons.place_rounded, _tr(context, 'f_hq'), where, null),
      if (b.sinceYear != null)
        (Icons.event_rounded, _tr(context, 'f_since'), '${b.sinceYear}', null),
      if (b.employees != null)
        (Icons.groups_rounded, _tr(context, 'f_staff'),
            '${b.employees} ${_tr(context, 'staff')}', null),
      if (b.website != null && b.website!.trim().isNotEmpty)
        (Icons.language_rounded, _tr(context, 'f_web'), b.website!,
            () => _openUrl(b.website)),
      if (b.phone != null && b.phone!.trim().isNotEmpty)
        (Icons.phone_rounded, _tr(context, 'f_phone'), b.phone!,
            () => _openTel(b.phone!)),
      if (b.email != null && b.email!.trim().isNotEmpty)
        (Icons.mail_rounded, _tr(context, 'f_email'), b.email!,
            () => _openMail(b.email!)),
      (Icons.tag_rounded, _tr(context, 'f_id'), b.thixId, () async {
        await Clipboard.setData(ClipboardData(text: b.thixId));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('${_tr(context, 'copied')}${b.thixId}')));
      }),
    ];

    Widget cell((IconData, String, String, VoidCallback?) r) {
      final ok = r.$1 == Icons.verified_rounded;
      return _Tap(
        onTap: r.$4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(r.$1, size: 16, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(r.$2.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(r.$3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: r.$4 != null && !ok
                                ? scheme.primary
                                : _ink(context))),
                  ],
                ),
              ),
              if (r.$4 != null)
                Icon(Icons.arrow_outward_rounded,
                    size: 14, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _ink(context).withValues(alpha: 0.10),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (c, cs) {
          final cols = cs.maxWidth > 820 ? 3 : (cs.maxWidth > 520 ? 2 : 1);
          final rows = <List<(IconData, String, String, VoidCallback?)>>[];
          for (var i = 0; i < cells.length; i += cols) {
            rows.add(cells.skip(i).take(cols).toList());
          }
          final hair = scheme.outlineVariant.withValues(alpha: 0.35);
          return ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var r = 0; r < rows.length; r++) ...[
                  if (r > 0) Container(height: 1, color: hair),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < rows[r].length; i++) ...[
                        if (i > 0) Container(width: 1, color: hair),
                        Expanded(child: cell(rows[r][i])),
                      ],
                      // Complète la dernière ligne si incomplète
                      for (var i = rows[r].length; i < cols; i++) ...[
                        Container(width: 1, color: hair),
                        const Expanded(child: SizedBox.shrink()),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RENDERER DE SECTIONS
// ─────────────────────────────────────────────────────────────────────────────
class _SectionRenderer extends StatelessWidget {
  const _SectionRenderer({required this.section});
  final BusinessSection section;
  @override
  Widget build(BuildContext context) {
    final content = section.content;
    switch (section.type) {
      case BusinessSectionType.about:
        return _AboutSection(content: content as AboutContent);
      case BusinessSectionType.services:
        return _ServicesSection(content: content as ServicesContent);
      case BusinessSectionType.products:
        return _ProductsSection(content: content as ProductsContent);
      case BusinessSectionType.gallery:
        return _GallerySection(content: content as GalleryContent);
      case BusinessSectionType.team:
        return _TeamSection(content: content as TeamContent);
      case BusinessSectionType.news:
        return _NewsSection(content: content as NewsContent);
      case BusinessSectionType.testimonials:
        return _TestimonialsSection(content: content as TestimonialsContent);
      case BusinessSectionType.contact:
        return const SizedBox.shrink(); // remplacé par la bannière CTA
    }
  }
}

// ── À PROPOS (bande blanche, texte + image arrondie) ──
class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.content});
  final AboutContent content;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    void more() => _showDetail(
          context,
          title: _tt(context, content.title),
          image: content.imageUrl,
          text: content.body,
        );

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (content.tagline != null && content.tagline!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              content.tagline!,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: scheme.primary,
              ),
            ),
          ),
        _ExpandText(
          content.body,
          maxLines: 6,
          style: TextStyle(
            fontSize: 14.5,
            height: 1.8,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    final body = LayoutBuilder(
      builder: (context, cs) {
        // 🔑 On capture l'URL ICI : la promotion de type fonctionne
        //   car on fait le test null/empty dans le même scope.
        final url = content.imageUrl;
        if (url == null || url.isEmpty) {
          // Pas d'image → on n'affiche que le texte
          return text;
        }

        // À partir d'ici, Dart sait que `url` est un String non-null.
        final image = _Tap(
          onTap: () => _viewImage(context, url),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: _softShadow(context),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 240,
                width: double.infinity,
                child: _img(url),
              ),
            ),
          ),
        );

        if (cs.maxWidth <= 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [image, const SizedBox(height: 28), text],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: text),
            const SizedBox(width: 40),
            Expanded(flex: 5, child: image),
          ],
        );
      },
    );

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: _Wrap(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _secHead(
                context,
                content.title,
                moreLabel: _tr(context, 'learn_more'),
                onMore: more,
              ),
              body,
            ],
          ),
        ),
      ),
    );
  }
}

// ── SERVICES (grille de cartes blanches à icônes colorées) ──
class _ServicesSection extends StatelessWidget {
  const _ServicesSection({required this.content});
  final ServicesContent content;

  void _openAll(BuildContext context) {
    final items = content.items;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Text(_tt(ctx, content.title),
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _ink(ctx))),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      for (final s in items)
                        ListTile(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          leading: Icon(Icons.business_center_rounded,
                              color: Theme.of(ctx).colorScheme.primary),
                          title: Text(s.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                          subtitle: s.price != null && s.price!.isNotEmpty
                              ? Text(s.price!)
                              : null,
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _showDetail(ctx,
                                title: s.title,
                                image: s.imageUrl,
                                chip: s.price,
                                text: s.description);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = content.items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _secHead(context, content.title,
            onMore: items.length > 4 ? () => _openAll(context) : null),
        LayoutBuilder(
          builder: (c, cs) {
            final cols = cs.maxWidth > 980
                ? 5
                : cs.maxWidth > 760
                    ? 4
                    : cs.maxWidth > 520
                        ? 3
                        : 2;
            const gap = 16.0;
            final w = (cs.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (var i = 0; i < items.length; i++)
                  SizedBox(width: w, child: _ServiceCard(item: items[i], index: i)),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.item, required this.index});
  final ServiceItem item;
  final int index;

  @override
  Widget build(BuildContext context) {
    final color = _kIconPalette[index % _kIconPalette.length];
    final hasImg = item.imageUrl != null && item.imageUrl!.isNotEmpty;
    return _Tap(
      onTap: () => _showDetail(context,
          title: item.title,
          image: item.imageUrl,
          chip: item.price,
          text: item.description),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _softShadow(context),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            hasImg
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                        height: 56,
                        width: 56,
                        child: _img(item.imageUrl!, fit: BoxFit.cover)),
                  )
                : Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.12),
                    ),
                    child: Icon(Icons.business_center_rounded,
                        color: color, size: 26),
                  ),
            const SizedBox(height: 14),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: _ink(context)),
            ),
            if (item.price != null && item.price!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(item.price!,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: color)),
              ),
          ],
        ),
      ),
    );
  }
}

// ── PRODUITS (grille cartes blanches) ──
class _ProductsSection extends StatelessWidget {
  const _ProductsSection({required this.content});
  final ProductsContent content;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = content.items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _secHead(context, content.title),
        LayoutBuilder(
          builder: (c, cs) {
            final cols = cs.maxWidth > 900
                ? 4
                : cs.maxWidth > 640
                    ? 3
                    : 2;
            const gap = 16.0;
            final w = (cs.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (var i = 0; i < items.length; i++)
                  SizedBox(width: w, child: _ProductCard(item: items[i])),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.item});
  final ProductItem item;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    void more() => _showDetail(context,
        title: item.title,
        image: item.imageUrl,
        chip: item.price,
        text: item.description,
        url: item.url);
    return _Tap(
      onTap: more,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _softShadow(context),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 150,
                width: double.infinity,
                child: (item.imageUrl == null || item.imageUrl!.isEmpty)
                    ? const _ImgFallback()
                    : _img(item.imageUrl!),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: _ink(context))),
                    if (item.price != null && item.price!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(item.price!,
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: scheme.primary)),
                      ),
                    if (item.description != null &&
                        item.description!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _ClampText(item.description!,
                            maxLines: 2,
                            onMore: more,
                            showLink: false,
                            style: TextStyle(
                                height: 1.55,
                                fontSize: 12.5,
                                color: scheme.onSurfaceVariant)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── GALERIE / RÉALISATIONS (vignettes + flèche circulaire) ──
class _GallerySection extends StatefulWidget {
  const _GallerySection({required this.content});
  final GalleryContent content;
  @override
  State<_GallerySection> createState() => _GallerySectionState();
}

class _GallerySectionState extends State<_GallerySection> {
  final ScrollController _c = ScrollController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _next() {
    if (!_c.hasClients) return;
    final t = (_c.offset + _c.position.viewportDimension * 0.8)
        .clamp(0.0, _c.position.maxScrollExtent);
    _c.animateTo(t,
        duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final imgs = widget.content.images;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _secHead(context, widget.content.title),
        SizedBox(
          height: 168,
          child: Stack(
            children: [
              ListView.separated(
                controller: _c,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                    right: MediaQuery.sizeOf(context).width < 700 ? 64 : 24),
                itemCount: imgs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (ctx, i) => _Tap(
                  onTap: () => _viewImage(ctx, imgs[i].url),
                  child: Container(
                    width: 230,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: _softShadow(ctx),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _img(imgs[i].url),
                          if (imgs[i].caption != null &&
                              imgs[i].caption!.isNotEmpty)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(
                                    12, 24, 12, 10),
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.black87],
                                  ),
                                ),
                                child: Text(imgs[i].caption!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (imgs.length > 2)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _Tap(
                      onTap: _next,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: _softShadow(context),
                        ),
                        child: Icon(Icons.arrow_forward_rounded,
                            size: 20, color: _ink(context)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── ÉQUIPE (avatars cerclés centrés, sans carte) ──
class _TeamSection extends StatelessWidget {
  const _TeamSection({required this.content});
  final TeamContent content;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final members = content.members;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _secHead(context, content.title),
        LayoutBuilder(
          builder: (c, cs) {
            final cols = cs.maxWidth > 800 ? 4 : (cs.maxWidth > 480 ? 3 : 2);
            final w = cs.maxWidth / cols;
            return Wrap(
              spacing: 0,
              runSpacing: 32,
              children: [
                for (final m in members)
                  SizedBox(
                    width: w,
                    child: _Tap(
                      onTap: (m.bio == null || m.bio!.trim().isEmpty)
                          ? null
                          : () => _showDetail(context,
                              title: m.name,
                              subtitle: m.role,
                              image: m.photoUrl,
                              text: m.bio),
                      child: Column(
                        children: [
                          _Avatar(
                              url: m.photoUrl,
                              name: m.name,
                              radius: 44,
                              ring: scheme.primary),
                          const SizedBox(height: 14),
                          Text(m.name,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  color: _ink(context))),
                          if (m.role != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(m.role!,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      color: scheme.onSurfaceVariant)),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ── ACTUALITÉS (grille cartes blanches) ──
class _NewsSection extends StatelessWidget {
  const _NewsSection({required this.content});
  final NewsContent content;
  @override
  Widget build(BuildContext context) {
    final lang = _LangScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final posts = content.posts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _secHead(context, content.title),
        LayoutBuilder(
          builder: (c, cs) {
            final cols = cs.maxWidth > 900 ? 3 : (cs.maxWidth > 600 ? 2 : 1);
            const gap = 20.0;
            final w = (cs.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final p in posts)
                  SizedBox(
                    width: w,
                    child: _NewsCard(
                        post: p, date: p.publishedAt == null ? null : _fmtDate(lang, p.publishedAt!)),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.post, this.date});
  final NewsPost post;
  final String? date;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasImg = post.imageUrl != null && post.imageUrl!.isNotEmpty;
    final hasText = post.excerpt != null && post.excerpt!.trim().isNotEmpty;
    void more() => _showDetail(context,
        title: post.title,
        subtitle: date,
        image: post.imageUrl,
        text: post.excerpt,
        url: post.url,
        urlLabel: _tr(context, 'read_full'));
    return _Tap(
      onTap: more,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _softShadow(context),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasImg)
                SizedBox(
                    height: 160,
                    width: double.infinity,
                    child: _img(post.imageUrl!)),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (date != null)
                      Text(date!.toUpperCase(),
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                              color: scheme.primary)),
                    const SizedBox(height: 8),
                    Text(post.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15.5,
                            letterSpacing: -0.2,
                            height: 1.3,
                            color: _ink(context))),
                    if (hasText)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: _ClampText(post.excerpt!,
                            maxLines: 3,
                            onMore: more,
                            showLink: false,
                            style: TextStyle(
                                height: 1.6,
                                fontSize: 13,
                                color: scheme.onSurfaceVariant)),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: _MoreLink(
                          label: _tr(context, 'read_full'), onTap: more),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── TÉMOIGNAGES (cartes blanches centrées) ──
class _TestimonialsSection extends StatelessWidget {
  const _TestimonialsSection({required this.content});
  final TestimonialsContent content;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = content.items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _secHead(context, content.title),
        LayoutBuilder(
          builder: (c, cs) {
            final cols = cs.maxWidth > 900 ? 3 : (cs.maxWidth > 600 ? 2 : 1);
            const gap = 20.0;
            final w = (cs.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final t in items)
                  SizedBox(
                    width: w,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _softShadow(context),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.format_quote_rounded,
                              color: _accent(context), size: 26),
                          const SizedBox(height: 12),
                          _ClampText(
                            t.quote,
                            maxLines: 4,
                            onMore: () => _showDetail(context,
                                title: t.author ?? '',
                                subtitle: t.role,
                                text: t.quote),
                            showLink: false,
                            style: TextStyle(
                                height: 1.6,
                                fontSize: 13.5,
                                fontStyle: FontStyle.italic,
                                color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (t.author != null)
                                      Text(t.author!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                              color: _ink(context))),
                                    if (t.role != null)
                                      Text(t.role!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 11.5,
                                              color: scheme.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                              if (t.rating != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (var i = 0; i < 5; i++)
                                      Icon(
                                        i < t.rating!
                                            ? Icons.star_rounded
                                            : Icons.star_border_rounded,
                                        size: 14,
                                        color: _accent(context),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ── CONTACT (tuiles sheet + canaux footer) ──
IconData _contactIcon(ContactChannelType type) {
  switch (type) {
    case ContactChannelType.phone:
      return Icons.phone_rounded;
    case ContactChannelType.email:
      return Icons.mail_rounded;
    case ContactChannelType.whatsapp:
      return Icons.chat_rounded;
    case ContactChannelType.website:
      return Icons.language_rounded;
    case ContactChannelType.address:
      return Icons.place_rounded;
    case ContactChannelType.map:
      return Icons.map_rounded;
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.channel});
  final ContactChannel channel;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = channel;
    return _Tap(
      onTap: () async {
        final uri = c.launchUri;
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(_contactIcon(c.type), size: 18, color: scheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.label ?? c.type.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13.5)),
                  const SizedBox(height: 2),
                  Text(c.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.arrow_outward_rounded,
                size: 16, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ── BANNIÈRE CTA « Travaillons ensemble ! » ──
class _CtaBanner extends StatelessWidget {
  const _CtaBanner({required this.bundle, required this.onContact});
  final BusinessBundle bundle;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    final theme = bundle.theme;
    final navy = Color.lerp(theme.primary, Colors.black, 0.45)!;
    final accent = theme.accent ?? const Color(0xFFEAB308);
    return _Wrap(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 56),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.primary, navy],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: navy.withValues(alpha: 0.35),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (c, cs) {
              final icon = Icon(Icons.handshake_rounded,
                  color: accent, size: 40);
              final texts = Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_tr(context, 'work_together'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3)),
                    const SizedBox(height: 6),
                    Text(_tr(context, 'work_sub'),
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 13)),
                  ],
                ),
              );
              final btn = FilledButton.icon(
                onPressed: onContact,
                icon: const Icon(Icons.phone_rounded, size: 16),
                label: Text(_tr(context, 'contact_us'),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Color.lerp(navy, Colors.black, 0.3),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 14),
                  shape: const StadiumBorder(),
                ),
              );
              if (cs.maxWidth > 640) {
                return Row(
                    children: [icon, const SizedBox(width: 20), texts, btn]);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(height: 16),
                  texts,
                  const SizedBox(height: 18),
                  btn,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 10 RUBRIQUES AVANCÉES (photos + vidéos)
// ─────────────────────────────────────────────────────────────────────────────
String _v(Map<String, String> m, String k) => (m[k] ?? '').trim();

class _ExtraSection extends StatelessWidget {
  const _ExtraSection({required this.extra});
  final BizExtra extra;
  @override
  Widget build(BuildContext context) {
    final spec = kBizKindByKey[extra.kind];
    if (spec == null) return const SizedBox.shrink();
    final lang = _LangScope.of(context);
    final items = extra.items
        .where((i) => (i['title'] ?? '').trim().isNotEmpty)
        .toList();
    if (items.isEmpty) return const SizedBox.shrink();
    final custom = extra.title?.trim() ?? '';
    final title =
        custom.isNotEmpty ? custom : (lang == 'en' ? spec.en : spec.fr);
    switch (spec.layout) {
      case BizLayout.logo:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _secHead(context, title),
            Wrap(
              spacing: 20,
              runSpacing: 20,
              children: [
                for (final it in items) _LogoCard(item: it),
              ],
            ),
          ],
        );
      case BizLayout.steps:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _secHead(context, title),
            LayoutBuilder(
              builder: (c, cs) {
                final cols =
                    cs.maxWidth > 900 ? 4 : (cs.maxWidth > 600 ? 2 : 1);
                const gap = 16.0;
                final w = (cs.maxWidth - gap * (cols - 1)) / cols;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (var i = 0; i < items.length; i++)
                      SizedBox(
                          width: w,
                          child: _StepCard(item: items[i], number: i + 1)),
                  ],
                );
              },
            ),
          ],
        );
      case BizLayout.standard:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _secHead(context, title),
            LayoutBuilder(
              builder: (c, cs) {
                final cols =
                    cs.maxWidth > 900 ? 3 : (cs.maxWidth > 600 ? 2 : 1);
                const gap = 20.0;
                final w = (cs.maxWidth - gap * (cols - 1)) / cols;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final it in items)
                      SizedBox(
                          width: w, child: _StdCard(item: it, kind: spec.key)),
                  ],
                );
              },
            ),
          ],
        );
    }
  }
}

class _LogoCard extends StatelessWidget {
  const _LogoCard({required this.item});
  final Map<String, String> item;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final img = _v(item, 'image');
    final sub = _v(item, 'subtitle');
    final link = _v(item, 'link');
    return _Tap(
      onTap: link.isEmpty ? null : () => _openUrl(link),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: _softShadow(context),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 56,
              width: 56,
              child: img.isEmpty
                  ? Icon(Icons.business_rounded,
                      size: 36, color: scheme.primary)
                  : _img(img, fit: BoxFit.contain),
            ),
            const SizedBox(height: 10),
            Text(_v(item, 'title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: _ink(context))),
            if (sub.isNotEmpty)
              Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10.5, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.item, required this.number});
  final Map<String, String> item;
  final int number;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final img = _v(item, 'image');
    final text = _v(item, 'text');
    void more() => _showDetail(context,
        title: _v(item, 'title'),
        image: img,
        chip: '${_tr(context, 'step')} $number',
        text: text);
    return _Tap(
      onTap: text.isEmpty ? null : more,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _softShadow(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (img.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                    height: 120, width: double.infinity, child: _img(img)),
              ),
            if (img.isNotEmpty) const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _accent(context).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Text('$number',
                      style: TextStyle(
                          color: _ink(context),
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_v(item, 'title'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          letterSpacing: -0.2,
                          color: _ink(context))),
                ),
              ],
            ),
            if (text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _ClampText(text,
                    maxLines: 4,
                    onMore: more,
                    style: TextStyle(
                        height: 1.6,
                        fontSize: 13,
                        color: scheme.onSurfaceVariant)),
              ),
          ],
        ),
      ),
    );
  }
}

class _StdCard extends StatelessWidget {
  const _StdCard({required this.item, required this.kind});
  final Map<String, String> item;
  final String kind;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final img = _v(item, 'image');
    final video = _v(item, 'video');
    final sub = _v(item, 'subtitle');
    final meta = _v(item, 'meta');
    final text = _v(item, 'text');
    final link = _v(item, 'link');
    final ctaLabel =
        kind == 'careers' ? _tr(context, 'apply') : _tr(context, 'learn_more');
    final target = link.isNotEmpty ? link : video;
    final targetLabel = link.isEmpty && video.isNotEmpty
        ? _tr(context, 'watch')
        : ctaLabel;
    void more() => _showDetail(context,
        title: _v(item, 'title'),
        subtitle: sub,
        image: img,
        chip: meta,
        text: text,
        url: target,
        urlLabel: targetLabel);
    return _Tap(
      onTap: more,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _softShadow(context),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 160,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (img.isNotEmpty)
                      _img(img)
                    else
                      ColoredBox(
                        color: scheme.surfaceContainerHighest,
                        child: Icon(
                          video.isNotEmpty
                              ? Icons.movie_creation_outlined
                              : kBizKindByKey[kind]?.icon ??
                                  Icons.image_outlined,
                          size: 36,
                          color: scheme.onSurfaceVariant),
                      ),
                    if (video.isNotEmpty)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle),
                          child: Icon(Icons.play_arrow_rounded,
                              color: _ink(context), size: 26),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_v(item, 'title'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            letterSpacing: -0.2,
                            color: _ink(context))),
                    if (sub.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12.5,
                                color: scheme.onSurfaceVariant)),
                      ),
                    if (meta.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(meta.toUpperCase(),
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                                color: scheme.primary)),
                      ),
                    if (text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: _ClampText(text,
                            maxLines: 3,
                            onMore: more,
                            showLink: false,
                            style: TextStyle(
                                height: 1.6,
                                fontSize: 13,
                                color: scheme.onSurfaceVariant)),
                      ),
                    if (target.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: _MoreLink(label: targetLabel, onTap: more),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FOOTER COMPACT 3 COLONNES (marque / suivez-nous / QR)
// ─────────────────────────────────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  const _Footer({
    required this.bundle,
    required this.links,
    required this.onTop,
  });
  final BusinessBundle bundle;
  final List<(String, VoidCallback)> links;
  final VoidCallback onTop;

  @override
  Widget build(BuildContext context) {
    final theme = bundle.theme;
    final b = bundle.business;
    final navy = Color.lerp(theme.primary, Colors.black, 0.72)!;
    final accent = theme.accent ?? const Color(0xFFEAB308);
    final section = bundle.sectionOfType(BusinessSectionType.contact);
    final channels = section?.content is ContactContent
        ? (section!.content as ContactContent).channels
        : const <ContactChannel>[];
    final publicUrl = '$kThixPublicBaseUrl/b/${b.thixId}';

    final brand = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Avatar(url: b.logoUrl, name: b.name, radius: 22),
        const SizedBox(width: 14),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(b.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 17)),
              if (b.claim != null && b.claim!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(b.claim!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 11.5)),
                ),
            ],
          ),
        ),
      ],
    );

    final follow = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_tr(context, 'follow'),
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final c in channels.take(5))
              _Tap(
                onTap: () async {
                  final uri = c.launchUri;
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.10),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18)),
                  ),
                  child: Icon(_contactIcon(c.type),
                      size: 17, color: Colors.white),
                ),
              ),
            _Tap(
              onTap: () => Share.share(publicUrl),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.10),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: const Icon(Icons.ios_share_rounded,
                    size: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );

    final qr = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: QrImageView(
            data: publicUrl,
            version: QrVersions.auto,
            size: 84,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 120,
          child: Text(_tr(context, 'scan'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 10)),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      color: navy,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
        child: _Wrap(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (c, cs) {
                  if (cs.maxWidth > 760) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(flex: 5, child: brand),
                        Container(
                            width: 1,
                            height: 90,
                            color: Colors.white.withValues(alpha: 0.12)),
                        const SizedBox(width: 32),
                        Expanded(flex: 5, child: follow),
                        const SizedBox(width: 32),
                        qr,
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      brand,
                      const SizedBox(height: 28),
                      follow,
                      const SizedBox(height: 28),
                      qr,
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.12)),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 10,
                spacing: 16,
                children: [
                  Text(
                    '© ${DateTime.now().year} ${b.name}. ${_tr(context, 'rights')} · ${_tr(context, 'powered')}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 11),
                  ),
                  _Tap(
                    onTap: onTop,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_upward_rounded,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(_tr(context, 'top'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Extension Theme (style + radius + accent)
// ─────────────────────────────────────────────────────────────────────────────
class BusinessThemeExt extends ThemeExtension<BusinessThemeExt> {
  const BusinessThemeExt({
    required this.style,
    required this.radius,
    this.accent,
  });
  final BusinessAnimationStyle style;
  final BorderRadius radius;
  final Color? accent;

  @override
  BusinessThemeExt copyWith({
    BusinessAnimationStyle? style,
    BorderRadius? radius,
    Color? accent,
  }) =>
      BusinessThemeExt(
        style: style ?? this.style,
        radius: radius ?? this.radius,
        accent: accent ?? this.accent,
      );

  @override
  BusinessThemeExt lerp(BusinessThemeExt? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}
