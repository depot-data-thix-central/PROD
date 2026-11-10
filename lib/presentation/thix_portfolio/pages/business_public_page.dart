// ════════════════════════════════════════════════════════════════════════════
//  THIX PORTFOLIO BUSINESS — PAGE PUBLIQUE « CORPORATE PREMIUM »
//  Fichier  : lib/presentation/thix_portfolio/pages/business_public_page.dart
//  Module   : THIX Portfolio Business
//  Éditeur  : SONATHIX GROUP — Kinshasa, RDC
//  Version  : 9.1.1 — Novembre 2026 (V9.1 + correctifs mockup & syntaxe)
// ════════════════════════════════════════════════════════════════════════════
//
//  ✅ v9.1.1 — CORRECTIFS :
//  • FIX 1 : _GallerySectionState._next() → .toDouble() sur clamp()
//  • FIX 2 : _AboutSection → null-safety sur imageUrl + suppression mockup 7/120/12
//  • FIX 3 : _HeroStatsGlass → stats RÉELLES uniquement (plus de '120+'/'45')
//  • FIX 4 : _TeamRow → suppression bouton "in" factice, chevron si bio existe
//  • FIX 5 : _TestimonialRow → rating défensif (try/catch)
//  • FIX 6 : Suppression de _ServiceCard (dead code)
//  • NEW   : _AboutRealStats — stats calculées depuis le contenu réel
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
    'identity_title': "Fiche d'identité",
    'identity_note': 'Lecture en Z — volontairement désalignée pour un rendu éditorial, pas administratif.',
    'copy': 'Copier',
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
    'identity_title': 'Identity card',
    'identity_note': 'Z-reading — deliberately misaligned for an editorial look, not administrative.',
    'copy': 'Copy',
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

// ── V9.1 : PHOTOS HORIZONTALES — helpers ──
/// Photos de repli (Unsplash) quand un item n'a pas d'image propre.
/// Garantit que SERVICES / ÉQUIPE / PRODUITS / EXTRAS affichent TOUJOURS une photo.
const List<String> _kFallbackPhotos = [
  'https://images.unsplash.com/photo-1550751827-4bd374c3f58b?w=400&q=80',
  'https://images.unsplash.com/photo-1512941937669-90a1b58e7e9c?w=400&q=80',
  'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=400&q=80',
  'https://images.unsplash.com/photo-1552664730-d307ca884978?w=400&q=80',
  'https://images.unsplash.com/photo-1522202176988-66273c2fd55f?w=400&q=80',
  'https://images.unsplash.com/photo-1551434678-e076c223a692?w=400&q=80',
  'https://images.unsplash.com/photo-1521737604893-d14cc237f11d?w=400&q=80',
  'https://images.unsplash.com/photo-1556761175-b413da4baf72?w=400&q=80',
];

String _fallbackPhoto(int index) => _kFallbackPhotos[index % _kFallbackPhotos.length];
String _photoOrFallback(String? url, int index) =>
    (url != null && url.trim().isNotEmpty) ? url.trim() : _fallbackPhoto(index);

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

/// Vignette photo horizontale : TOUJOURS une photo, coins 16, tap -> plein écran.
class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.url, required this.index, this.width = 76, this.height = 76, this.radius = 16, this.icon});
  final String? url;
  final int index;
  final double width;
  final double height;
  final double radius;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final photo = _photoOrFallback(url, index);
    return _Tap(
      onTap: () => _viewImage(context, photo),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: width, height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _img(photo),
              Container(color: Colors.black.withValues(alpha: 0.04)),
              if (icon != null)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Icon(icon, size: 18, color: _ink(context)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bandeau photos horizontal (scroll).
class _HorizontalPhotoStrip extends StatelessWidget {
  const _HorizontalPhotoStrip({required this.urls, this.height = 96});
  final List<String> urls;
  final double height;
  @override
  Widget build(BuildContext context) {
    final list = urls.where((u) => u.trim().isNotEmpty).toList();
    if (list.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) => _Tap(
          onTap: () => _viewImage(ctx, list[i]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(width: height * 1.35, height: height, child: _img(list[i])),
          ),
        ),
      ),
    );
  }
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
  String? eyebrow,
  String? number,
}) {
  final scheme = Theme.of(context).colorScheme;
  final eyebrowText = eyebrow ?? _eyebrowFor(title);
  return Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrowText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              eyebrowText.toUpperCase(),
              style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800,
                letterSpacing: 2.2, color: Color(0xFFB8860B),
              ),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                _tt(context, title),
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.15, color: _ink(context)),
              ),
            ),
            if (onMore != null) ...[
              const SizedBox(width: 12),
              _MoreLink(label: moreLabel ?? _tr(context, 'see_all'), onTap: onMore),
            ],
            if (trailing != null) trailing,
          ],
        ),
      ],
    ),
  );
}

/// Eyebrow éditorial.
String _eyebrowFor(String title) {
  final t = title.trim().toLowerCase();
  if (t.contains('propos') || t.contains('about')) return '02 — À propos';
  if (t.contains('service')) return '03 — Expertises';
  if (t.contains('produit') || t.contains('product')) return '03 — Produits';
  if (t.contains('galerie') || t.contains('réalisation') || t.contains('realisation')) return '04 — Preuves';
  if (t.contains('équipe') || t.contains('equipe') || t.contains('team')) return '05 — Humain';
  if (t.contains('actualit') || t.contains('news')) return '06 — Actualités';
  if (t.contains('témoignage') || t.contains('temoignage') || t.contains('avis')) return '07 — Ils nous font confiance';
  return '';
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
              SliverToBoxAdapter(
                child: _Wrap(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(24, -32, 24, 0),
                    child: _HeroStatsGlass(bundle: bundle),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _Band(
                  index: 1,
                  child: _IdentityStrip(business: bundle.business),
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
    final bg = index.isEven ? Colors.white : const Color(0xFFF7F8FA);
    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(vertical: 32),
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
// HERO V9
// ─────────────────────────────────────────────────────────────────────────────
class _Hero extends StatelessWidget {
  const _Hero({required this.bundle, required this.images, required this.onContact, required this.onDiscover});
  final BusinessBundle bundle;
  final List<String> images;
  final VoidCallback onContact;
  final VoidCallback onDiscover;
  @override
  Widget build(BuildContext context) {
    final theme = bundle.theme;
    final b = bundle.business;
    final size = MediaQuery.sizeOf(context);
    final height = math.min(math.max(440.0, size.height * 0.52), 620.0);
    final narrow = size.width < 700;
    final navy = Color.lerp(theme.primary, Colors.black, 0.45)!;
    final accent = theme.accent ?? const Color(0xFFEAB308);
    final words = b.name.trim().split(RegExp(r'\s+'));
    final line1 = words.first;
    final line2 = words.skip(1).join(' ');
    final desc = b.description?.trim() ?? '';
    final lang = _LangScope.of(context);
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
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  stops: const [0, 0.45, 1],
                  colors: [navy.withValues(alpha: 0.25), navy.withValues(alpha: 0.35), navy.withValues(alpha: 0.92)],
                ),
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kMaxW),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 56),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Column(
                      mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.place_rounded, size: 13, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                (b.city != null && b.city!.isNotEmpty ? '${b.city} — ' : '') + (lang == 'en' ? 'Since ${b.sinceYear ?? ''}' : 'Depuis ${b.sinceYear ?? ''}'),
                                style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
                              ),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _Rise(
                          child: Text(line1.toUpperCase(), maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white, fontSize: narrow ? 40 : 62, height: 1.0, fontWeight: FontWeight.w900, letterSpacing: -1.5)),
                        ),
                        if (line2.isNotEmpty)
                          _Rise(delay: 80, child: Text(line2.toUpperCase(), maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: accent, fontSize: narrow ? 40 : 62, height: 1.0, fontWeight: FontWeight.w900, letterSpacing: -1.5))),
                        if (b.claim != null && b.claim!.trim().isNotEmpty)
                          Padding(padding: const EdgeInsets.only(top: 14),
                            child: _Rise(delay: 160, child: Text(b.claim!, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800, height: 1.3)))),
                        if (desc.isNotEmpty)
                          Padding(padding: const EdgeInsets.only(top: 10),
                            child: Text(desc, maxLines: 3, overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13.5, height: 1.55))),
                        const SizedBox(height: 22),
                        Wrap(spacing: 12, runSpacing: 12, children: [
                          FilledButton(
                            onPressed: onDiscover,
                            style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: navy, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14), shape: const StadiumBorder()),
                            child: Text(_tr(context, 'discover'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          ),
                          OutlinedButton(
                            onPressed: onContact,
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white, width: 1.2), padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14), shape: const StadiumBorder()),
                            child: Text(_tr(context, 'contact_us'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          ),
                        ]),
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

/// GLASSFLOU n°2 — barre stats qui chevauche le hero. STATS RÉELLES uniquement.
class _HeroStatsGlass extends StatelessWidget {
  const _HeroStatsGlass({required this.bundle});
  final BusinessBundle bundle;

  @override
  Widget build(BuildContext context) {
    final b = bundle.business;
    final lang = _LangScope.of(context);

    // ✅ STATS RÉELLES UNIQUEMENT — plus aucun '120+' ni '45' inventé
    final stats = <(String, String)>[];

    // 1. Années d'expérience (calculées depuis sinceYear)
    if (b.sinceYear != null && b.sinceYear! > 1900) {
      final years = DateTime.now().year - b.sinceYear!;
      if (years > 0) {
        stats.add((
          '$years+',
          lang == 'en' ? 'years of experience' : "ans d'expérience",
        ));
      }
    }

    // 2. Collaborateurs (uniquement si renseigné)
    if (b.employees != null && b.employees! > 0) {
      stats.add((
        '${b.employees}',
        lang == 'en' ? 'collaborators' : 'collaborateurs',
      ));
    }

    // 3. Nombre RÉEL de services publiés
    final svc = bundle.sectionOfType(BusinessSectionType.services)?.content;
    if (svc is ServicesContent && svc.items.isNotEmpty) {
      stats.add((
        '${svc.items.length}',
        lang == 'en' ? 'services' : 'services',
      ));
    }

    // 4. Nombre RÉEL de produits publiés
    final prod = bundle.sectionOfType(BusinessSectionType.products)?.content;
    if (prod is ProductsContent && prod.items.isNotEmpty) {
      stats.add((
        '${prod.items.length}',
        lang == 'en' ? 'products' : 'produits',
      ));
    }

    // 5. Nombre RÉEL de membres d'équipe
    final team = bundle.sectionOfType(BusinessSectionType.team)?.content;
    if (team is TeamContent && team.members.isNotEmpty) {
      stats.add((
        '${team.members.length}',
        lang == 'en' ? 'team members' : 'collaborateurs',
      ));
    }

    // Si aucune donnée réelle → on n'affiche RIEN (pas de barre vide)
    if (stats.isEmpty) return const SizedBox.shrink();

    // On plafonne à 3 colonnes pour rester lisible
    final visible = stats.take(3).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.86),
          border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 12))
          ],
        ),
        child: Row(children: [
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0)
              Container(
                  width: 1,
                  height: 36,
                  color: Colors.black.withValues(alpha: 0.08)),
            Expanded(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(visible[i].$1,
                    style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: _ink(context))),
                const SizedBox(height: 2),
                Text(visible[i].$2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 10.5,
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant)),
              ]),
            ),
          ],
        ]),
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
// IDENTITÉ V9 — ÉDITORIALE DÉSALIGNÉE
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
    Future<void> copyId() async {
      await Clipboard.setData(ClipboardData(text: b.thixId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text('${_tr(context, 'copied')}${b.thixId}')));
    }
    final rows = <(String, String, double, VoidCallback?)>[
      (_tr(context, 'f_name'), b.name, 0, null),
      if (b.sector != null && b.sector!.trim().isNotEmpty) (_tr(context, 'f_sector'), b.sector!, 18, null),
      if (where.isNotEmpty) (_tr(context, 'f_hq'), where, 0, null),
      if (b.sinceYear != null) (_tr(context, 'f_since'), '${b.sinceYear} — ${b.city ?? ''}'.trim(), 18, null),
      if (b.employees != null) (_tr(context, 'f_staff'), '${b.employees} ${_tr(context, 'staff')}', 0, null),
      (_tr(context, 'f_status'), _tr(context, 'verified_status'), 8, null),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _secHead(context, _tr(context, 'identity_title'), eyebrow: '01 — Profil'),
        for (final r in rows)
          Padding(
            padding: EdgeInsets.only(left: r.$3, top: 0, bottom: 0),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.$1.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 5),
                  Row(children: [
                    Expanded(child: Text(r.$2, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink(context)))),
                    if (r.$1 == _tr(context, 'f_status')) Container(width: 9, height: 9, decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle)),
                  ]),
                ])),
              ]),
            ),
          ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
          decoration: BoxDecoration(color: _ink(context), borderRadius: BorderRadius.circular(18), border: const Border(left: BorderSide(color: Color(0xFFFFB800), width: 5))),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_tr(context, 'f_id').toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.6, color: Colors.white.withValues(alpha: 0.6))),
              const SizedBox(height: 5),
              Text(b.thixId, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: Colors.white)),
            ])),
            FilledButton.icon(
              onPressed: copyId,
              icon: const Icon(Icons.content_copy_rounded, size: 16),
              label: Text(_tr(context, 'copy'), style: const TextStyle(fontWeight: FontWeight.w800)),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFB800), foregroundColor: _ink(context), elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11), shape: const StadiumBorder()),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
          if (b.website != null && b.website!.isNotEmpty) _Tap(onTap: () => _openUrl(b.website), child: Text(_tr(context, 'f_web'), style: TextStyle(fontWeight: FontWeight.w700, color: scheme.primary))),
          if (b.phone != null && b.phone!.isNotEmpty) ...[Text('•', style: TextStyle(color: scheme.onSurfaceVariant)), _Tap(onTap: () => _openTel(b.phone!), child: Text(_tr(context, 'f_phone'), style: TextStyle(fontWeight: FontWeight.w700, color: scheme.primary)))],
          if (b.email != null && b.email!.isNotEmpty) ...[Text('•', style: TextStyle(color: scheme.onSurfaceVariant)), _Tap(onTap: () => _openMail(b.email!), child: Text(_tr(context, 'f_email'), style: TextStyle(fontWeight: FontWeight.w700, color: scheme.primary)))],
        ]),
        const SizedBox(height: 14),
        Center(child: Text(_tr(context, 'identity_note'), textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: scheme.onSurfaceVariant))),
      ],
    );
  }
}

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
        return const SizedBox.shrink();
    }
  }
}

// ── À PROPOS V9 — null-safety + suppression mockup 7/120/12 ──
class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.content});
  final AboutContent content;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // ✅ Promotion null-safe : on extrait le non-null UNE FOIS
    final rawUrl = content.imageUrl;
    final imageUrl = (rawUrl != null && rawUrl.trim().isNotEmpty) ? rawUrl : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _secHead(context, content.title, eyebrow: '02 — À propos'),
        if (content.tagline != null && content.tagline!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(content.tagline!,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    color: scheme.primary)),
          ),
        _ExpandText(content.body,
            maxLines: 6,
            style: TextStyle(
                fontSize: 14.5,
                height: 1.8,
                color: scheme.onSurfaceVariant)),
        if (imageUrl != null) ...[
          const SizedBox(height: 24),
          _Tap(
            onTap: () => _viewImage(context, imageUrl),
            child: Stack(children: [
              Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                          border: Border.all(
                              color: const Color(0xFFFFB800), width: 2),
                          borderRadius: BorderRadius.circular(20)))),
              Padding(
                padding: const EdgeInsets.only(right: 12, bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                      height: 240,
                      width: double.infinity,
                      child: _img(imageUrl)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          // ✅ Stats réelles uniquement — suppression du mockup 7/120/12
          _AboutRealStats(content: content, lang: _LangScope.of(context)),
          const SizedBox(height: 18),
          _HorizontalPhotoStrip(
            urls: [imageUrl, _fallbackPhoto(1), _fallbackPhoto(3)],
            height: 84,
          ),
        ],
      ],
    );
  }
}

/// Stats réelles calculées depuis le contenu (pas de chiffres inventés).
class _AboutRealStats extends StatelessWidget {
  const _AboutRealStats({required this.content, required this.lang});
  final AboutContent content;
  final String lang;
  @override
  Widget build(BuildContext context) {
    final items = <(String, String)>[];
    // On n'affiche QUE ce qu'on peut réellement compter
    final textLen = content.body.trim().length;
    if (textLen > 0) {
      items.add(('${(textLen / 100).round() * 100}+',
          lang == 'en' ? 'words about us' : 'mots sur nous'));
    }
    if (content.tagline != null && content.tagline!.trim().isNotEmpty) {
      items.add(('✓', lang == 'en' ? 'verified identity' : 'identité vérifiée'));
    }
    if (items.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('—', style: TextStyle(color: Colors.black26)),
            ),
          Text(items[i].$1,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: _ink(context))),
          const SizedBox(width: 4),
          Text(items[i].$2,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ],
    );
  }
}

// ── SERVICES V9 — lignes HORIZONTALES avec PHOTO à gauche ──
class _ServicesSection extends StatelessWidget {
  const _ServicesSection({required this.content});
  final ServicesContent content;
  void _openAll(BuildContext context) {
    final items = content.items;
    showModalBottomSheet<void>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(color: Theme.of(ctx).colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: SafeArea(child: ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.85),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.fromLTRB(24, 24, 24, 8), child: Text(_tt(ctx, content.title), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _ink(ctx)))),
            Expanded(child: ListView.separated(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), separatorBuilder: (_, __) => const SizedBox(height: 8), itemCount: items.length,
              itemBuilder: (c, i) => _ServiceRow(item: items[i], index: i))),
          ]))),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final items = content.items;
    final photos = [for (var i = 0; i < items.length; i++) _photoOrFallback(items[i].imageUrl, i)];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _secHead(context, content.title, onMore: items.length > 4 ? () => _openAll(context) : null, eyebrow: '03 — Expertises'),
      if (photos.isNotEmpty) ...[
        _HorizontalPhotoStrip(urls: photos, height: 88),
        const SizedBox(height: 16),
      ],
      for (var i = 0; i < items.length; i++) Padding(padding: const EdgeInsets.only(bottom: 12), child: _ServiceRow(item: items[i], index: i)),
    ]);
  }
}

class _ServiceRow extends StatefulWidget {
  const _ServiceRow({required this.item, required this.index});
  final ServiceItem item;
  final int index;
  @override
  State<_ServiceRow> createState() => _ServiceRowState();
}

class _ServiceRowState extends State<_ServiceRow> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _kIconPalette[widget.index % _kIconPalette.length];
    final item = widget.item;
    final icon = [Icons.auto_awesome_rounded, Icons.phone_iphone_rounded, Icons.cloud_rounded, Icons.explore_rounded, Icons.school_rounded][widget.index % 5];
    return _Tap(
      onTap: () => _showDetail(context, title: item.title, image: _photoOrFallback(item.imageUrl, widget.index), chip: item.price, text: item.description),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            _PhotoThumb(url: item.imageUrl, index: widget.index, width: 76, height: 76, radius: 16, icon: icon),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.25, color: _ink(context))),
              const SizedBox(height: 5),
              Text(item.description ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, height: 1.5, color: scheme.onSurfaceVariant)),
              if (item.price != null && item.price!.trim().isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 5), child: Text(item.price!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color))),
            ])),
            const SizedBox(width: 10),
            Column(children: [
              Text('0${widget.index + 1}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: scheme.onSurfaceVariant.withValues(alpha: 0.45))),
              const SizedBox(height: 4),
              _Tap(onTap: () => setState(() => _open = !_open), child: Icon(_open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 20, color: scheme.onSurfaceVariant)),
            ]),
          ]),
          if (_open && (item.description ?? '').isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 12),
              child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF7F8FA), borderRadius: BorderRadius.circular(12)),
                child: Text(item.description!, style: TextStyle(fontSize: 12.5, height: 1.6, color: scheme.onSurfaceVariant)))),
        ]),
      ),
    );
  }
}

// ── PRODUITS V9 ──
class _ProductsSection extends StatelessWidget {
  const _ProductsSection({required this.content});
  final ProductsContent content;
  @override
  Widget build(BuildContext context) {
    final items = content.items;
    final photos = [for (var i = 0; i < items.length; i++) _photoOrFallback(items[i].imageUrl, i)];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _secHead(context, content.title, eyebrow: '03 — Produits'),
      if (photos.isNotEmpty) ...[_HorizontalPhotoStrip(urls: photos, height: 88), const SizedBox(height: 16)],
      for (var i = 0; i < items.length; i++) Padding(padding: const EdgeInsets.only(bottom: 12), child: _ProductCard(item: items[i], index: i)),
    ]);
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.item, this.index = 0});
  final ProductItem item;
  final int index;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    void more() => _showDetail(context, title: item.title, image: _photoOrFallback(item.imageUrl, index), chip: item.price, text: item.description, url: item.url);
    return _Tap(
      onTap: more,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          _PhotoThumb(url: item.imageUrl, index: index, width: 92, height: 92, radius: 16),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _ink(context))),
            if (item.description != null && item.description!.trim().isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 5), child: Text(item.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(height: 1.5, fontSize: 12.5, color: scheme.onSurfaceVariant))),
            if (item.price != null && item.price!.trim().isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 6), child: Text(item.price!, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: scheme.primary))),
          ])),
          Icon(Icons.arrow_forward_rounded, size: 18, color: scheme.onSurfaceVariant),
        ]),
      ),
    );
  }
}

// ── GALERIE V9 ──
class _GallerySection extends StatefulWidget {
  const _GallerySection({required this.content});
  final GalleryContent content;
  @override
  State<_GallerySection> createState() => _GallerySectionState();
}
class _GallerySectionState extends State<_GallerySection> {
  final ScrollController _c = ScrollController();
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  void _next() {
    if (!_c.hasClients) return;
    // ✅ FIX 1 : clamp() renvoie num → cast obligatoire en double
    final target = (_c.offset + _c.position.viewportDimension * 0.8)
        .clamp(0.0, _c.position.maxScrollExtent)
        .toDouble();
    _c.animateTo(target, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
  }
  @override
  Widget build(BuildContext context) {
    final imgs = widget.content.images;
    if (imgs.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _secHead(context, widget.content.title, eyebrow: '04 — Preuves'),
      _Tap(
        onTap: () => _viewImage(context, imgs.first.url),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(height: 220, width: double.infinity, child: Stack(fit: StackFit.expand, children: [
            _img(imgs.first.url),
            if (imgs.first.caption != null && imgs.first.caption!.isNotEmpty)
              Positioned(left: 0, right: 0, bottom: 0, child: Container(padding: const EdgeInsets.fromLTRB(16, 32, 16, 14),
                decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87])),
                child: Text(imgs.first.caption!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)))),
          ])),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 132,
        child: Stack(children: [
          ListView.separated(
            controller: _c, scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(right: MediaQuery.sizeOf(context).width < 700 ? 64 : 24),
            itemCount: imgs.length, separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (ctx, i) => _Tap(
              onTap: () => _viewImage(ctx, imgs[i].url),
              child: Container(width: 180, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: _softShadow(ctx)),
                child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Stack(fit: StackFit.expand, children: [
                  _img(imgs[i].url),
                  if (imgs[i].caption != null && imgs[i].caption!.isNotEmpty)
                    Positioned(left: 0, right: 0, bottom: 0, child: Container(padding: const EdgeInsets.fromLTRB(10, 20, 10, 8),
                      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87])),
                      child: Text(imgs[i].caption!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11)))),
                ]))),
            ),
          ),
          if (imgs.length > 2)
            Positioned(right: 0, top: 0, bottom: 0, child: Center(child: _Tap(onTap: _next, child: Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: _softShadow(context)), child: Icon(Icons.arrow_forward_rounded, size: 20, color: _ink(context)))))),
        ]),
      ),
    ]);
  }
}

// ── ÉQUIPE V9 — FIX 4 : suppression bouton "in" factice ──
class _TeamSection extends StatelessWidget {
  const _TeamSection({required this.content});
  final TeamContent content;
  @override
  Widget build(BuildContext context) {
    final members = content.members;
    final photos = [for (var i = 0; i < members.length; i++) _photoOrFallback(members[i].photoUrl, i)];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _secHead(context, content.title, eyebrow: '05 — Humain'),
      if (photos.isNotEmpty) ...[
        _HorizontalPhotoStrip(urls: photos, height: 104),
        const SizedBox(height: 16),
      ],
      for (var i = 0; i < members.length; i++) Padding(padding: const EdgeInsets.only(bottom: 10), child: _TeamRow(member: members[i], index: i)),
    ]);
  }
}

class _TeamRow extends StatelessWidget {
  const _TeamRow({required this.member, required this.index});
  final dynamic member;
  final int index;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = (member.name as String?) ?? '';
    final role = (member.role as String?) ?? '';
    final bio = (member.bio as String?) ?? '';
    final photoUrl = member.photoUrl as String?;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    return _Tap(
      onTap: bio.trim().isEmpty ? null : () => _showDetail(context, title: name, subtitle: role, image: _photoOrFallback(photoUrl, index), text: bio),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5))),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: index.isEven ? const Color(0xFFFFB800) : _ink(context), width: 2)),
            child: ClipOval(child: SizedBox(width: 60, height: 60, child: hasPhoto ? _img(photoUrl!) : ColoredBox(color: index.isEven ? const Color(0xFFFFB800) : _ink(context), child: Center(child: Text(_initials(name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)))))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _ink(context))),
            if (role.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(role, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant))),
            if (bio.trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(bio, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant.withValues(alpha: 0.8)))),
          ])),
          const SizedBox(width: 10),
          // ✅ FIX 4 : chevron réel — visible uniquement si une bio existe
          if (bio.trim().isNotEmpty)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_forward_rounded,
                  size: 16, color: scheme.primary),
            ),
        ]),
      ),
    );
  }
}

// ── ACTUALITÉS V9 ──
class _NewsSection extends StatelessWidget {
  const _NewsSection({required this.content});
  final NewsContent content;
  @override
  Widget build(BuildContext context) {
    final lang = _LangScope.of(context);
    final posts = content.posts;
    final photos = [for (var i = 0; i < posts.length; i++) _photoOrFallback(posts[i].imageUrl, i)];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _secHead(context, content.title, eyebrow: '06 — Actualités'),
      if (photos.isNotEmpty) ...[_HorizontalPhotoStrip(urls: photos, height: 88), const SizedBox(height: 16)],
      for (var i = 0; i < posts.length; i++) Padding(padding: const EdgeInsets.only(bottom: 12), child: _NewsCard(post: posts[i], date: posts[i].publishedAt == null ? null : _fmtDate(lang, posts[i].publishedAt!), index: i)),
    ]);
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.post, this.date, this.index = 0});
  final NewsPost post;
  final String? date;
  final int index;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    void more() => _showDetail(context, title: post.title, subtitle: date, image: _photoOrFallback(post.imageUrl, index), text: post.excerpt, url: post.url, urlLabel: _tr(context, 'read_full'));
    return _Tap(
      onTap: more,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          _PhotoThumb(url: post.imageUrl, index: index, width: 96, height: 96, radius: 16),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (date != null) Text(date!.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: scheme.primary)),
            const SizedBox(height: 5),
            Text(post.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, height: 1.3, color: _ink(context))),
            if (post.excerpt != null && post.excerpt!.trim().isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 5), child: Text(post.excerpt!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(height: 1.5, fontSize: 12.5, color: scheme.onSurfaceVariant))),
          ])),
          Icon(Icons.arrow_forward_rounded, size: 18, color: scheme.onSurfaceVariant),
        ]),
      ),
    );
  }
}

// ── TÉMOIGNAGES V9 — FIX 5 : rating défensif ──
class _TestimonialsSection extends StatelessWidget {
  const _TestimonialsSection({required this.content});
  final TestimonialsContent content;
  @override
  Widget build(BuildContext context) {
    final items = content.items;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _secHead(context, content.title, eyebrow: '07 — Ils nous font confiance'),
      for (var i = 0; i < items.length; i++) Padding(padding: const EdgeInsets.only(bottom: 12), child: _TestimonialRow(item: items[i], index: i)),
    ]);
  }
}

class _TestimonialRow extends StatelessWidget {
  const _TestimonialRow({required this.item, required this.index});
  final dynamic item;
  final int index;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final quote = (item.quote as String?) ?? '';
    final author = (item.author as String?) ?? '';
    final role = (item.role as String?) ?? '';

    // ✅ FIX 5 : rating défensif — pas de crash si le champ est absent
    int? rating;
    try {
      final raw = item.rating;
      if (raw is int) rating = raw;
    } catch (_) {
      rating = null;
    }

    void more() => _showDetail(context, title: author, subtitle: role, text: quote);
    return _Tap(
      onTap: more,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(shape: BoxShape.circle, color: index.isEven ? const Color(0xFFFFB800) : _ink(context)),
            child: Center(child: Text(_initials(author.isNotEmpty ? author : '?'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (rating != null) ...[for (var i = 0; i < 5; i++) Icon(i < rating ? Icons.star_rounded : Icons.star_border_rounded, size: 13, color: _accent(context))],
              const Spacer(),
              Icon(Icons.format_quote_rounded, color: _accent(context), size: 20),
            ]),
            const SizedBox(height: 6),
            Text(quote, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(height: 1.6, fontSize: 13, fontStyle: FontStyle.italic, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text(author, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _ink(context))),
            if (role.isNotEmpty) Text(role, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
          ])),
        ]),
      ),
    );
  }
}

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

// ── BANNIÈRE CTA ──
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
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [theme.primary, navy]), borderRadius: BorderRadius.circular(18)),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(_tr(context, 'work_together'), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
              const SizedBox(height: 3),
              Text(_tr(context, 'work_sub'), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12)),
            ])),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: onContact,
              style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Color.lerp(navy, Colors.black, 0.3), elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: const StadiumBorder()),
              child: Text(_tr(context, 'contact_us'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 10 RUBRIQUES AVANCÉES
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
            for (final it in items) Padding(padding: const EdgeInsets.only(bottom: 10), child: _LogoCard(item: it)),
          ],
        );
      case BizLayout.steps:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _secHead(context, title),
            for (var i = 0; i < items.length; i++)
              Padding(padding: const EdgeInsets.only(bottom: 12), child: _StepCard(item: items[i], number: i + 1)),
          ],
        );
      case BizLayout.standard:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _secHead(context, title),
            for (final it in items)
              Padding(padding: const EdgeInsets.only(bottom: 12), child: _StdCard(item: it, kind: spec.key)),
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
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5))),
        child: Row(children: [
          _PhotoThumb(url: img.isEmpty ? null : img, index: _v(item, 'title').length, width: 56, height: 56, radius: 14),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_v(item, 'title'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _ink(context))),
            if (sub.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant))),
          ])),
          if (link.isNotEmpty) Icon(Icons.arrow_outward_rounded, size: 16, color: scheme.onSurfaceVariant),
        ]),
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
    void more() => _showDetail(context, title: _v(item, 'title'), image: img, chip: '${_tr(context, 'step')} $number', text: text);
    return _Tap(
      onTap: text.isEmpty ? null : more,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Stack(children: [
            _PhotoThumb(url: img.isEmpty ? null : img, index: number, width: 72, height: 72, radius: 14),
            Positioned(right: 4, bottom: 4, child: Container(width: 24, height: 24, decoration: const BoxDecoration(color: Color(0xFFFFB800), shape: BoxShape.circle), child: Center(child: Text('$number', style: TextStyle(color: _ink(context), fontWeight: FontWeight.w900, fontSize: 11))))),
          ]),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_v(item, 'title'), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: _ink(context))),
            if (text.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(height: 1.5, fontSize: 12.5, color: scheme.onSurfaceVariant))),
          ])),
        ]),
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
    final ctaLabel = kind == 'careers' ? _tr(context, 'apply') : _tr(context, 'learn_more');
    final target = link.isNotEmpty ? link : video;
    final targetLabel = link.isEmpty && video.isNotEmpty ? _tr(context, 'watch') : ctaLabel;
    void more() => _showDetail(context, title: _v(item, 'title'), subtitle: sub, image: img, chip: meta, text: text, url: target, urlLabel: targetLabel);
    return _Tap(
      onTap: more,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Stack(children: [
            _PhotoThumb(url: img.isEmpty ? null : img, index: _v(item, 'title').length, width: 92, height: 92, radius: 16),
            if (video.isNotEmpty) Positioned.fill(child: Center(child: Container(padding: const EdgeInsets.all(7), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(Icons.play_arrow_rounded, color: _ink(context), size: 20)))),
          ]),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_v(item, 'title'), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: _ink(context))),
            if (sub.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant))),
            if (text.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(height: 1.5, fontSize: 12.5, color: scheme.onSurfaceVariant))),
            if (meta.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 5), child: Text(meta.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: scheme.primary))),
          ])),
          Icon(Icons.arrow_forward_rounded, size: 18, color: scheme.onSurfaceVariant),
        ]),
      ),
    );
  }
}

// ── FOOTER V9 — 1 seule ligne ──
class _Footer extends StatelessWidget {
  const _Footer({required this.bundle, required this.links, required this.onTop});
  final BusinessBundle bundle;
  final List<(String, VoidCallback)> links;
  final VoidCallback onTop;
  @override
  Widget build(BuildContext context) {
    final theme = bundle.theme;
    final b = bundle.business;
    final navy = Color.lerp(theme.primary, Colors.black, 0.72)!;
    final publicUrl = '$kThixPublicBaseUrl/b/${b.thixId}';
    final section = bundle.sectionOfType(BusinessSectionType.contact);
    final channels = section?.content is ContactContent ? (section!.content as ContactContent).channels : const <ContactChannel>[];
    return Container(
      width: double.infinity, color: navy,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: _Wrap(
        child: Row(children: [
          _Avatar(url: b.logoUrl, name: b.name, radius: 16),
          const SizedBox(width: 10),
          Expanded(child: Text('${b.name}  •  © ${DateTime.now().year}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5))),
          for (final c in channels.take(3))
            Padding(padding: const EdgeInsets.only(left: 8), child: _Tap(
              onTap: () async { final uri = c.launchUri; if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication); },
              child: Container(width: 32, height: 32, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10)), child: Icon(_contactIcon(c.type), size: 14, color: Colors.white)),
            )),
          Padding(padding: const EdgeInsets.only(left: 8), child: _Tap(onTap: () => Share.share(publicUrl), child: Container(width: 32, height: 32, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10)), child: const Icon(Icons.ios_share_rounded, size: 14, color: Colors.white)))),
          Padding(padding: const EdgeInsets.only(left: 8), child: _Tap(onTap: onTop, child: Container(width: 32, height: 32, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFFFB800)), child: Icon(Icons.arrow_upward_rounded, size: 16, color: _ink(context))))),
        ]),
      ),
    );
  }
}

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
