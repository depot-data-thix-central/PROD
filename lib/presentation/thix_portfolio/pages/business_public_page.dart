// ════════════════════════════════════════════════════════════════════════════
//  THIX PORTFOLIO BUSINESS — PAGE PUBLIQUE « PROFIL ENTREPRISE PREMIUM »
//  Fichier  : lib/presentation/thix_portfolio/pages/business_public_page.dart
//  Module   : THIX Portfolio Business
//  Éditeur  : SONATHIX GROUP — Kinshasa, RDC
//  Version  : 7.0.0 — Novembre 2026 (Design Premium Glassmorphism — 360°)
// ════════════════════════════════════════════════════════════════════════════
//
//  ✅ v7.0 — REDESIGN 360° « PREMIUM GLASS » (aligné THIX PRO / Studio) :
//    • Glassmorphism partout : _Glass / _GlassIcon (blur + bordures + ombres)
//    • Orbs décoratifs en arrière-plan → profondeur du verre
//    • En-tête givré pinned (frosted) + nav pills + toggle FR/EN glass
//    • Hero conservé (carrousel) mais sublimé : chips glass, CTA pills,
//      barre de chiffres clés EN VERRE flottante dans le hero
//    • Fiche d'identité : carte glass unique, grille 2 colonnes ALIGNÉE,
//      icônes en squares glass, hairlines, spacing serré
//    • Sections : cartes glass radius 22-24, images inset radius 16
//    • FAB style THIX PRO : pill noire lisérée accent (or)
//    • Footer COMPACT (une bande navy, ~200px)
//    • FR / EN, 10 rubriques avancées, images web robustes
// ════════════════════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
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

/// Noir studio (pills, FAB) — identique à THIX PRO.
const Color _kInk = Color(0xFF0B0F14);

/// Fond de page froid très clair.
const Color _kBg = Color(0xFFF5F7FA);

// ─────────────────────────────────────────────────────────────────────────────
// i18n FR / EN
// ─────────────────────────────────────────────────────────────────────────────
const Map<String, Map<String, String>> _i18n = {
  'fr': {
    'contact_us': 'Nous contacter',
    'discover': 'Découvrir',
    'share': 'Partager',
    'contact': 'Contacter',
    'verified': 'ENTREPRISE VÉRIFIÉE',
    'verified_status': 'Entreprise vérifiée',
    'years': "ans d'expérience",
    'staff': 'collaborateurs',
    'visits': 'visites',
    'since': 'Depuis',
    'read_full': 'Lire la suite',
    'see_more': 'Voir plus',
    'see_less': 'Voir moins',
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
    'discover': 'Discover',
    'share': 'Share',
    'contact': 'Contact',
    'verified': 'VERIFIED COMPANY',
    'verified_status': 'Verified company',
    'years': 'years of experience',
    'staff': 'team members',
    'visits': 'visits',
    'since': 'Since',
    'read_full': 'Read more',
    'see_more': 'See more',
    'see_less': 'See less',
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

Future<void> _openMail(String mail) => launchUrl(Uri.parse('mailto:$mail'),
    mode: LaunchMode.externalApplication);

Color _accent(BuildContext c) =>
    Theme.of(c).extension<BusinessThemeExt>()?.accent ??
    Theme.of(c).colorScheme.tertiary;

Color _hair(BuildContext c) =>
    Theme.of(c).colorScheme.outlineVariant.withValues(alpha: 0.35);

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

// ─────────────────────────────────────────────────────────────────────────────
// BRIQUES GLASS (cœur du design premium)
// ─────────────────────────────────────────────────────────────────────────────

/// Panneau de verre dépoli : blur + dégradé translucide + bordure lumineuse.
class _Glass extends StatelessWidget {
  const _Glass({
    required this.child,
    this.radius,
    this.padding,
    this.blur = 14,
    this.tint,
    this.dark = false,
    this.border,
    this.shadow = true,
  });
  final Widget child;
  final BorderRadius? radius;
  final EdgeInsetsGeometry? padding;
  final double blur;
  final Color? tint;
  final bool dark;
  final Border? border;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? BorderRadius.circular(24);
    final Gradient? g = tint != null
        ? null
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? [
                    Colors.white.withValues(alpha: 0.16),
                    Colors.white.withValues(alpha: 0.06),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.74),
                    Colors.white.withValues(alpha: 0.46),
                  ],
          );
    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint,
            gradient: g,
            borderRadius: r,
            border: border ??
                Border.all(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.22)
                      : Colors.white.withValues(alpha: 0.75),
                  width: 1,
                ),
            boxShadow: shadow
                ? [
                    BoxShadow(
                      color: const Color(0x140B0F14),
                      blurRadius: 34,
                      offset: const Offset(0, 16),
                    ),
                  ]
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Bouton icône circulaire en verre (clair ou sombre).
class _GlassIcon extends StatelessWidget {
  const _GlassIcon({
    required this.icon,
    this.onTap,
    this.dark = false,
    this.size = 40,
    this.color,
  });
  final IconData icon;
  final VoidCallback? onTap;
  final bool dark;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Tap(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dark
                  ? Colors.white.withValues(alpha: 0.16)
                  : Colors.white.withValues(alpha: 0.62),
              border: Border.all(
                color: dark
                    ? Colors.white.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.8),
              ),
            ),
            child: Icon(
              icon,
              size: size * 0.48,
              color: color ?? (dark ? Colors.white : scheme.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}

/// Orbes décoratifs fixes → le verre a quelque chose à flouter.
class _Orbs extends StatelessWidget {
  const _Orbs();
  static Widget _orb(double s, Color c, double o) => Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [c.withValues(alpha: o), c.withValues(alpha: 0)],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = _accent(context);
    return Positioned.fill(
      child: IgnorePointer(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: SizedBox(
            width: MediaQuery.sizeOf(context).width,
            height: MediaQuery.sizeOf(context).height,
            child: Stack(
              children: [
                Positioned(
                    top: -140,
                    right: -160,
                    child: _orb(520, accent, 0.16)),
                Positioned(
                    top: 420,
                    left: -200,
                    child: _orb(480, scheme.primary, 0.10)),
                Positioned(
                    bottom: -120,
                    right: -140,
                    child: _orb(460, accent, 0.10)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Images / taps / layout / animations
// ─────────────────────────────────────────────────────────────────────────────
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
              child: _GlassIcon(
                icon: Icons.close_rounded,
                dark: true,
                size: 44,
                onTap: () => Navigator.of(context).pop(),
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
// Atomes UI premium
// ─────────────────────────────────────────────────────────────────────────────
class _Pill extends StatelessWidget {
  const _Pill(this.text, {this.big = false});
  final String text;
  final bool big;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: big ? 6 : 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: big ? 11 : 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

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
      padding: ring != null ? const EdgeInsets.all(2) : EdgeInsets.zero,
      decoration: ring != null
          ? BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: ring!, width: 1.5),
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
    final scheme = Theme.of(context).colorScheme;
    return _Tap(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(),
              style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 1.2)),
          const SizedBox(width: 6),
          Icon(icon ?? Icons.arrow_forward_rounded,
              size: 14, color: scheme.primary),
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

/// Texte tronqué + lien « Voir plus » (ouvre la fiche détail via [onMore]).
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
                padding: const EdgeInsets.only(top: 12),
                child: _MoreLink(label: _tr(c, 'see_more'), onTap: onMore),
              ),
          ],
        );
      },
    );
  }
}

/// Texte repliable en place (Voir plus / Voir moins).
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

/// Fiche détail (texte complet) — bottom sheet en verre.
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
      return _Glass(
        radius: const BorderRadius.vertical(top: Radius.circular(28)),
        blur: 24,
        tint: const Color(0xF5FFFFFF),
        shadow: false,
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.86),
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
                        color: scheme.outlineVariant.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  if (image != null && image.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: SizedBox(
                          height: 240,
                          width: double.infinity,
                          child: _img(image),
                        ),
                      ),
                    ),
                  if (chip != null && chip.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _Pill(chip),
                    ),
                  Text(title,
                      style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                          height: 1.2)),
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
                            shape: const StadiumBorder(),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(_t(lang, 'close')),
                        style: OutlinedButton.styleFrom(
                          shape: const StadiumBorder(),
                        ),
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

Widget _sectionHeader(BuildContext context, String title, {Widget? trailing}) {
  final scheme = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.only(bottom: 36),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accent(context),
                ),
              ),
              Text(
                _tt(context, title),
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  height: 1.15,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
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
    Widget block(double h, [double r = 24]) => Container(
          height: h,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(r),
          ),
        );
    return Scaffold(
      backgroundColor: _kBg,
      body: Shimmer.fromColors(
        baseColor: scheme.surfaceContainerHighest,
        highlightColor: scheme.surface,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(height: 68, color: Colors.white),
            Container(height: 420, color: Colors.white),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [block(90), block(240), block(180)]),
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
      backgroundColor: _kBg,
      body: Stack(
        children: [
          const _Orbs(),
          Center(
            child: _Glass(
              padding: const EdgeInsets.all(40),
              radius: BorderRadius.circular(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.storefront_outlined,
                        size: 72, color: theme.colorScheme.outline),
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
                        style: FilledButton.styleFrom(
                          shape: const StadiumBorder(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
      _Blk('profile', _t(lang, 'profile'),
          _ProfileBlock(business: bundle.business)),
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
      for (final s in contact)
        _Blk('s-${s.id}', _label(_titleOf(s.content)),
            _SectionRenderer(section: s)),
    ];
    final firstSection = blocks.length > 1 ? blocks[1].id : blocks.first.id;

    return _LangScope(
      code: lang,
      child: Scaffold(
        backgroundColor: _kBg,
        floatingActionButton: _ContactFab(
          label: _t(lang, 'contact'),
          accent: theme.accent ?? const Color(0xFFD9A441),
          onTap: _openContactSheet,
        ),
        body: ScrollConfiguration(
          behavior: const _DragScrollBehavior(),
          child: Stack(
            children: [
              const _Orbs(),
              CustomScrollView(
                controller: _scroll,
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    automaticallyImplyLeading: false,
                    toolbarHeight: 68,
                    backgroundColor: Colors.white.withValues(alpha: 0.55),
                    surfaceTintColor: Colors.transparent,
                    scrolledUnderElevation: 0,
                    shadowColor: Colors.transparent,
                    titleSpacing: 0,
                    flexibleSpace: ClipRect(
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: Container(
                          color: Colors.white.withValues(alpha: 0.01),
                        ),
                      ),
                    ),
                    title: _headerTitle(context, blocks),
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(1),
                      child: Container(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.6)),
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
            ],
          ),
        ),
      ),
    );
  }

  // ── En-tête givré ──
  Widget _headerTitle(BuildContext context, List<_Blk> blocks) {
    final scheme = Theme.of(context).colorScheme;
    final b = bundle.business;
    final wide = MediaQuery.sizeOf(context).width >= 960;
    final canPop = Navigator.of(context).canPop();
    final accent = _accent(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          if (canPop) ...[
            _GlassIcon(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).maybePop()),
            const SizedBox(width: 10),
          ],
          if (!wide) ...[
            _GlassIcon(
                icon: Icons.menu_rounded, onTap: () => _openMenu(blocks)),
            const SizedBox(width: 10),
          ],
          _Avatar(url: b.logoUrl, name: b.name, radius: 17, ring: accent),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        b.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            letterSpacing: -0.3),
                      ),
                    ),
                    if (b.verified) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified_rounded,
                          size: 15, color: Color(0xFF22C55E)),
                    ],
                  ],
                ),
                if (b.sector != null && b.sector!.trim().isNotEmpty)
                  Text(
                    b.sector!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10.5,
                        letterSpacing: 0.6,
                        color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          if (wide) ...[
            const SizedBox(width: 24),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  children: [
                    for (final blk in blocks)
                      TextButton(
                        onPressed: () => _goTo(blk.id),
                        style: TextButton.styleFrom(
                          foregroundColor: scheme.onSurfaceVariant,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(blk.label.toUpperCase(),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 10.5,
                                letterSpacing: 1.2)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          _Tap(
            onTap: () => setState(() => _lang = _lang == 'fr' ? 'en' : 'fr'),
            child: Tooltip(
              message: _t(_lang, 'lang_tip'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.85)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(_lang == 'fr' ? 'EN' : 'FR',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        fontSize: 11,
                        color: scheme.onSurface)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          PopupMenuButton<int>(
            icon: _GlassIcon(icon: Icons.more_vert_rounded),
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
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      isScrollControlled: true,
      builder: (ctx) => _Glass(
        radius: const BorderRadius.vertical(top: Radius.circular(28)),
        blur: 22,
        tint: const Color(0xF2FFFFFF),
        shadow: false,
        child: SafeArea(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(_t(lang, 'menu').toUpperCase(),
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.6)),
                ),
                for (final blk in blocks)
                  ListTile(
                    shape: const StadiumBorder(),
                    leading: Icon(Icons.chevron_right_rounded,
                        size: 18, color: _accent(ctx)),
                    title: Text(blk.label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      Future.delayed(
                          const Duration(milliseconds: 300),
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
        child: _Glass(
          padding: const EdgeInsets.all(28),
          radius: BorderRadius.circular(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(bundle.business.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
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
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (sheetCtx) => _Glass(
        radius: const BorderRadius.vertical(top: Radius.circular(28)),
        blur: 22,
        tint: const Color(0xF2FFFFFF),
        shadow: false,
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
                            color: Theme.of(sheetCtx)
                                .colorScheme
                                .outlineVariant
                                .withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        '${_t(lang, 'contact_prefix')} ${bundle.business.name}',
                        style: Theme.of(sheetCtx)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              for (var i = 0; i < channels.length; i++)
                                _ContactTile(
                                  channel: channels[i],
                                  last: i == channels.length - 1,
                                ),
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

/// FAB « Contacter » style THIX PRO : pill noire lisérée accent.
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
            colors: [_kInk, Color(0xFF1B2430)],
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
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bande de section : espace respirant, fond laissé aux orbes + verre.
class _Band extends StatelessWidget {
  const _Band({required this.index, required this.child});
  final int index;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
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
// HERO (carrousel conservé, sublimé glass)
// ─────────────────────────────────────────────────────────────────────────────
List<(int, String)> _stats(BuildContext context, BusinessBundle bundle) {
  final b = bundle.business;
  return <(int, String)>[
    if (b.ageYears != null && b.ageYears! > 0) (b.ageYears!, _tr(context, 'years')),
    if (b.employees != null && b.employees! > 0)
      (b.employees!, _tr(context, 'staff')),
    if ((bundle.stats?.views ?? 0) > 0) (bundle.stats!.views, _tr(context, 'visits')),
  ];
}

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
    final height = math.min(math.max(460.0, size.height * 0.52), 600.0);
    final narrow = size.width < 700;
    final navy = Color.lerp(theme.primary, Colors.black, 0.55)!;
    final accent = theme.accent ?? const Color(0xFFD9A441);
    final stats = _stats(context, bundle);
    final meta = [
      if (b.sector != null && b.sector!.trim().isNotEmpty) b.sector!.trim(),
      if (b.city != null && b.city!.trim().isNotEmpty) b.city!.trim(),
      if (b.sinceYear != null) '${_tr(context, 'since')} ${b.sinceYear}',
    ];
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _HeroCarousel(
            images: images,
            colors: theme.heroGradient,
            indicatorBottom: stats.isNotEmpty ? 108 : 24,
          ),
          // Scrim vertical navy
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.45, 1],
                  colors: [
                    navy.withValues(alpha: 0.55),
                    navy.withValues(alpha: 0.25),
                    navy.withValues(alpha: 0.92),
                  ],
                ),
              ),
            ),
          ),
          // Glow accent
          IgnorePointer(
            child: Align(
              alignment: Alignment.topRight,
              child: Container(
                width: 420,
                height: 420,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    accent.withValues(alpha: 0.28),
                    accent.withValues(alpha: 0),
                  ]),
                ),
              ),
            ),
          ),
          // Contenu
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kMaxW),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 660),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (b.verified)
                          _Rise(
                            child: _Glass(
                              dark: true,
                              shadow: false,
                              blur: 10,
                              radius: BorderRadius.circular(999),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified_rounded,
                                      size: 13, color: accent),
                                  const SizedBox(width: 8),
                                  Text(
                                    _tr(context, 'verified'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          _Rise(
                            delay: 60,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final m in meta)
                                  _Glass(
                                    dark: true,
                                    shadow: false,
                                    blur: 8,
                                    radius: BorderRadius.circular(999),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    child: Text(
                                      m.toUpperCase(),
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.88),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.6,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        _Rise(
                          delay: 120,
                          child: Text(
                            b.name,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: narrow ? 38 : 58,
                              height: 1.02,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -2,
                            ),
                          ),
                        ),
                        if (b.claim != null && b.claim!.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: _Rise(
                              delay: 200,
                              child: Text(
                                b.claim!,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: narrow ? 15 : 18,
                                  height: 1.5,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 28),
                        _Rise(
                          delay: 280,
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              FilledButton.icon(
                                onPressed: onContact,
                                icon: const Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 16),
                                label: Text(_tr(context, 'contact_us'),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.4)),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: navy,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 26, vertical: 16),
                                  shape: const StadiumBorder(),
                                ),
                              ),
                              _Tap(
                                onTap: onDiscover,
                                child: _Glass(
                                  dark: true,
                                  shadow: false,
                                  blur: 10,
                                  radius: BorderRadius.circular(999),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 16),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.arrow_forward_rounded,
                                          size: 16, color: Colors.white),
                                      const SizedBox(width: 10),
                                      Text(
                                        _tr(context, 'discover'),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.4),
                                      ),
                                    ],
                                  ),
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
          // Barre de chiffres clés en verre
          if (stats.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 20,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _kMaxW),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _Glass(
                      dark: true,
                      blur: 18,
                      radius: BorderRadius.circular(20),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 14),
                      child: Row(
                        children: [
                          for (var i = 0; i < stats.length; i++) ...[
                            if (i > 0)
                              Container(
                                  width: 1,
                                  height: 36,
                                  color: Colors.white.withValues(alpha: 0.18)),
                            Expanded(
                              child: TweenAnimationBuilder<double>(
                                tween: Tween<double>(
                                    begin: 0, end: stats[i].$1.toDouble()),
                                duration: const Duration(milliseconds: 1400),
                                curve: Curves.easeOutCubic,
                                builder: (_, v, __) => Column(
                                  children: [
                                    Text(
                                      _compact(v.round()),
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w300,
                                        color: Colors.white,
                                        letterSpacing: -1.0,
                                        height: 1.0,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      stats[i].$2.toUpperCase(),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.4,
                                        color: Colors.white
                                            .withValues(alpha: 0.65),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
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
  const _HeroCarousel({
    required this.images,
    required this.colors,
    this.indicatorBottom = 24,
  });
  final List<String> images;
  final List<Color> colors;
  final double indicatorBottom;
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
            left: 0,
            right: 0,
            bottom: widget.indicatorBottom,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _kMaxW),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      for (var i = 0; i < imgs.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(right: 6),
                          width: i == _index ? 26 : 10,
                          height: 3,
                          decoration: BoxDecoration(
                            color: i == _index ? Colors.white : Colors.white38,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FICHE D'IDENTITÉ — carte glass, grille ALIGNÉE compacte
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileBlock extends StatelessWidget {
  const _ProfileBlock({required this.business});
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
    final rows = <(IconData, String, String, VoidCallback?)>[
      (Icons.apartment_rounded, _tr(context, 'f_name'), b.name, null),
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
      if (b.verified)
        (Icons.verified_rounded, _tr(context, 'f_status'),
            _tr(context, 'verified_status'), null),
    ];
    final desc = b.description?.trim() ?? '';

    Widget colList(List<(IconData, String, String, VoidCallback?)> list) =>
        Column(
          children: [
            for (var i = 0; i < list.length; i++)
              _SpecRow(row: list[i], last: i == list.length - 1),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, _tr(context, 'identity')),
        _Glass(
          radius: BorderRadius.circular(28),
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (desc.isNotEmpty) ...[
                Text(_tr(context, 'overview').toUpperCase(),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                        color: scheme.onSurfaceVariant)),
                const SizedBox(height: 12),
                _ExpandText(desc, maxLines: 4),
                const SizedBox(height: 20),
                Container(height: 1, color: _hair(context)),
                const SizedBox(height: 8),
              ],
              LayoutBuilder(
                builder: (c, cs) {
                  if (cs.maxWidth <= 720) return colList(rows);
                  final half = (rows.length / 2).ceil();
                  final colA = rows.take(half).toList();
                  final colB = rows.skip(half).toList();
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: colList(colA)),
                      const SizedBox(width: 40),
                      Expanded(child: colList(colB)),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow({required this.row, required this.last});
  final (IconData, String, String, VoidCallback?) row;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ok = row.$1 == Icons.verified_rounded;
    return _Tap(
      onTap: row.$4,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ok
                        ? const Color(0xFF16A34A).withValues(alpha: 0.10)
                        : scheme.primary.withValues(alpha: 0.08),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.8)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    row.$1,
                    size: 18,
                    color: ok ? const Color(0xFF16A34A) : scheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.$2.toUpperCase(),
                          style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.3,
                              color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 3),
                      Text(row.$3,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: row.$4 != null && !ok
                                  ? scheme.primary
                                  : scheme.onSurface)),
                    ],
                  ),
                ),
                if (row.$4 != null && !ok)
                  Icon(Icons.arrow_outward_rounded,
                      size: 15, color: scheme.onSurfaceVariant),
              ],
            ),
            if (!last)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Container(height: 1, color: _hair(context)),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section horizontale (glisser + flèches glass)
// ─────────────────────────────────────────────────────────────────────────────
class _HSection extends StatefulWidget {
  const _HSection({
    required this.title,
    required this.height,
    required this.count,
    required this.builder,
    this.gap = 24,
  });
  final String title;
  final double height;
  final int count;
  final IndexedWidgetBuilder builder;
  final double gap;

  @override
  State<_HSection> createState() => _HSectionState();
}

class _HSectionState extends State<_HSection> {
  final ScrollController _c = ScrollController();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _go(int dir) {
    if (!_c.hasClients) return;
    final w = _c.position.viewportDimension * 0.8;
    final t = (_c.offset + dir * w).clamp(0.0, _c.position.maxScrollExtent);
    _c.animateTo(t,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final arrows = widget.count > 1
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _GlassIcon(
                  icon: Icons.chevron_left_rounded, onTap: () => _go(-1)),
              const SizedBox(width: 10),
              _GlassIcon(
                  icon: Icons.chevron_right_rounded, onTap: () => _go(1)),
            ],
          )
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, widget.title, trailing: arrows),
        SizedBox(
          height: widget.height + 24,
          child: ListView.separated(
            controller: _c,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: widget.count,
            separatorBuilder: (_, __) => SizedBox(width: widget.gap),
            itemBuilder: widget.builder,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RENDERER DE SECTIONS STANDARD
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
        return _ContactSection(content: content as ContactContent);
    }
  }
}

// ── À PROPOS ──
class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.content});
  final AboutContent content;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = content.imageUrl;
    final hasImage = url != null && url.isNotEmpty;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, content.title),
        if (content.tagline != null && content.tagline!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(
              content.tagline!,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  fontStyle: FontStyle.italic,
                  color: scheme.onSurfaceVariant,
                  height: 1.5),
            ),
          ),
        _ExpandText(content.body,
            maxLines: 7,
            style:
                TextStyle(fontSize: 16, height: 1.8, color: scheme.onSurface)),
      ],
    );
    if (!hasImage) return text;
    return LayoutBuilder(
      builder: (context, cs) {
        final image = _Tap(
          onTap: () => _viewImage(context, url),
          child: _Glass(
            padding: const EdgeInsets.all(8),
            radius: BorderRadius.circular(24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(height: 320, width: double.infinity, child: _img(url)),
            ),
          ),
        );
        if (cs.maxWidth <= 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              image,
              const SizedBox(height: 36),
              text,
            ],
          );
        }
        final imgW = cs.maxWidth * 5 / 11;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: imgW, child: image),
            const SizedBox(width: 56),
            Expanded(child: text),
          ],
        );
      },
    );
  }
}

// ── SERVICES ──
class _ServicesSection extends StatelessWidget {
  const _ServicesSection({required this.content});
  final ServicesContent content;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _HSection(
      title: content.title,
      height: 350,
      count: content.items.length,
      builder: (ctx, i) {
        final s = content.items[i];
        final hasImg = s.imageUrl != null && s.imageUrl!.isNotEmpty;
        void more() => _showDetail(ctx,
            title: s.title, image: s.imageUrl, chip: s.price, text: s.description);
        return _Glass(
          radius: BorderRadius.circular(22),
          padding: const EdgeInsets.all(10),
          child: SizedBox(
            width: 292,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 170,
                    width: double.infinity,
                    child: hasImg
                        ? _img(s.imageUrl!)
                        : ColoredBox(
                            color: scheme.surfaceContainerHighest,
                            child: Icon(Icons.business_center_rounded,
                                size: 38, color: scheme.onSurfaceVariant),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 16, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                              letterSpacing: -0.3)),
                      const SizedBox(height: 8),
                      if (s.description != null &&
                          s.description!.trim().isNotEmpty)
                        _ClampText(s.description!,
                            maxLines: 3,
                            onMore: more,
                            style: TextStyle(
                                height: 1.6,
                                fontSize: 13.5,
                                color: scheme.onSurfaceVariant)),
                      const Spacer(),
                      if (s.price != null && s.price!.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _accent(ctx).withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(s.price!,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: scheme.primary)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── PRODUITS ──
class _ProductsSection extends StatelessWidget {
  const _ProductsSection({required this.content});
  final ProductsContent content;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _HSection(
      title: content.title,
      height: 370,
      count: content.items.length,
      builder: (ctx, i) {
        final p = content.items[i];
        void more() => _showDetail(ctx,
            title: p.title,
            image: p.imageUrl,
            chip: p.price,
            text: p.description,
            url: p.url);
        return _Glass(
          radius: BorderRadius.circular(22),
          padding: const EdgeInsets.all(10),
          child: SizedBox(
            width: 252,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 190,
                    width: double.infinity,
                    child: (p.imageUrl == null || p.imageUrl!.isEmpty)
                        ? const _ImgFallback()
                        : _Tap(onTap: more, child: _img(p.imageUrl!)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15.5,
                              letterSpacing: -0.2)),
                      if (p.price != null && p.price!.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(p.price!,
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: scheme.primary)),
                        ),
                      if (p.description != null &&
                          p.description!.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: _ClampText(p.description!,
                              maxLines: 2,
                              onMore: more,
                              style: TextStyle(
                                  height: 1.6,
                                  fontSize: 13,
                                  color: scheme.onSurfaceVariant)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── GALERIE ──
class _GallerySection extends StatelessWidget {
  const _GallerySection({required this.content});
  final GalleryContent content;
  @override
  Widget build(BuildContext context) {
    return _HSection(
      title: content.title,
      height: 268,
      count: content.images.length,
      gap: 18,
      builder: (ctx, i) {
        final img = content.images[i];
        return _Glass(
          radius: BorderRadius.circular(22),
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: 356,
            child: _Tap(
              onTap: () => _viewImage(ctx, img.url),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _img(img.url),
                    if (img.caption != null && img.caption!.isNotEmpty)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 28, 16, 14),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black87],
                            ),
                          ),
                          child: Text(img.caption!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5)),
                        ),
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
}

// ── ÉQUIPE ──
class _TeamSection extends StatelessWidget {
  const _TeamSection({required this.content});
  final TeamContent content;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _HSection(
      title: content.title,
      height: 288,
      count: content.members.length,
      builder: (ctx, i) {
        final m = content.members[i];
        final hasBio = m.bio != null && m.bio!.trim().isNotEmpty;
        void more() => _showDetail(ctx,
            title: m.name, subtitle: m.role, image: m.photoUrl, text: m.bio);
        return _Glass(
          radius: BorderRadius.circular(22),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: SizedBox(
            width: 224,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Avatar(
                    url: m.photoUrl,
                    name: m.name,
                    radius: 46,
                    ring: _accent(ctx)),
                const SizedBox(height: 18),
                Text(m.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15.5)),
                if (m.role != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(m.role!,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5, color: scheme.onSurfaceVariant)),
                  ),
                if (hasBio)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _MoreLink(
                        label: _tr(ctx, 'view_profile'), onTap: more),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── ACTUALITÉS ──
class _NewsSection extends StatelessWidget {
  const _NewsSection({required this.content});
  final NewsContent content;
  @override
  Widget build(BuildContext context) {
    final lang = _LangScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return _HSection(
      title: content.title,
      height: 410,
      count: content.posts.length,
      builder: (ctx, i) {
        final p = content.posts[i];
        final hasImg = p.imageUrl != null && p.imageUrl!.isNotEmpty;
        final date =
            p.publishedAt == null ? null : _fmtDate(lang, p.publishedAt!);
        final hasText = (p.excerpt != null && p.excerpt!.trim().isNotEmpty);
        void more() => _showDetail(ctx,
            title: p.title,
            subtitle: date,
            image: p.imageUrl,
            text: p.excerpt,
            url: p.url,
            urlLabel: _tr(ctx, 'read_full'));
        return _Glass(
          radius: BorderRadius.circular(22),
          padding: const EdgeInsets.all(10),
          child: SizedBox(
            width: 336,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasImg)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          height: 190,
                          width: double.infinity,
                          child: _Tap(onTap: more, child: _img(p.imageUrl!)),
                        ),
                      ),
                      if (date != null)
                        Positioned(
                          left: 12,
                          top: 12,
                          child: _Glass(
                            dark: true,
                            shadow: false,
                            blur: 8,
                            radius: BorderRadius.circular(999),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: Text(date.toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0)),
                          ),
                        ),
                    ],
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (date != null && !hasImg)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(date.toUpperCase(),
                              style: TextStyle(
                                  fontSize: 10.5,
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0)),
                        ),
                      Text(p.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                              letterSpacing: -0.3,
                              height: 1.3)),
                      const SizedBox(height: 10),
                      if (hasText)
                        _ClampText(p.excerpt!,
                                   maxLines: 3,
                            onMore: more,
                            showLink: false,
                            style: TextStyle(
                                height: 1.6,
                                fontSize: 13.5,
                                color: scheme.onSurfaceVariant)),
                      const Spacer(),
                      if (hasText || (p.url != null && p.url!.isNotEmpty))
                        _MoreLink(label: _tr(ctx, 'read_full'), onTap: more),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── TÉMOIGNAGES ──
class _TestimonialsSection extends StatelessWidget {
  const _TestimonialsSection({required this.content});
  final TestimonialsContent content;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _HSection(
      title: content.title,
      height: 308,
      count: content.items.length,
      gap: 28,
      builder: (ctx, idx) {
        final t = content.items[idx];
        void more() => _showDetail(ctx,
            title: t.author ?? '', subtitle: t.role, text: t.quote);
        return _Glass(
          radius: BorderRadius.circular(22),
          padding: const EdgeInsets.all(26),
          child: SizedBox(
            width: 376,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote_rounded,
                    color: _accent(ctx), size: 30),
                const SizedBox(height: 14),
                _ClampText(
                  t.quote,
                  maxLines: 5,
                  onMore: more,
                  style: Theme.of(ctx)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(height: 1.6, fontStyle: FontStyle.italic),
                ),
                const Spacer(),
                Divider(height: 28, color: _hair(ctx)),
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
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14)),
                          if (t.role != null)
                            Text(t.role!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
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
                              size: 15,
                              color: _accent(ctx),
                            ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── CONTACT ──
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
  const _ContactTile({required this.channel, this.last = false});
  final ContactChannel channel;
  final bool last;

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
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.08),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.8)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_contactIcon(c.type),
                      size: 18, color: scheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.label ?? c.type.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13.5)),
                      const SizedBox(height: 3),
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
            if (!last)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Container(height: 1, color: _hair(context)),
              ),
          ],
        ),
      ),
    );
  }
}

class _ContactSection extends StatelessWidget {
  const _ContactSection({required this.content});
  final ContactContent content;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, content.title),
        _Glass(
          radius: BorderRadius.circular(24),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            children: [
              for (var i = 0; i < content.channels.length; i++)
                _ContactTile(
                  channel: content.channels[i],
                  last: i == content.channels.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 10 RUBRIQUES AVANCÉES (photos + vidéos) — cartes glass
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
        return _HSection(
          title: title,
          height: 168,
          count: items.length,
          builder: (_, i) => _LogoCard(item: items[i]),
        );
      case BizLayout.steps:
        return _HSection(
          title: title,
          height: 330,
          count: items.length,
          builder: (_, i) => _StepCard(item: items[i], number: i + 1),
        );
      case BizLayout.standard:
        return _HSection(
          title: title,
          height: 440,
          count: items.length,
          builder: (_, i) => _StdCard(item: items[i], kind: spec.key),
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
    return _Glass(
      radius: BorderRadius.circular(18),
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: 176,
        child: _Tap(
          onTap: link.isEmpty ? null : () => _openUrl(link),
          child: Column(
            children: [
              Expanded(
                child: img.isEmpty
                    ? Icon(Icons.business_rounded,
                        size: 38, color: scheme.primary)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _img(img, fit: BoxFit.contain)),
              ),
              const SizedBox(height: 12),
              Text(_v(item, 'title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 12.5)),
              if (sub.isNotEmpty)
                Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10.5, color: scheme.onSurfaceVariant)),
            ],
          ),
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
    return _Glass(
      radius: BorderRadius.circular(22),
      padding: const EdgeInsets.all(18),
      child: SizedBox(
        width: 288,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (img.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                    height: 130, width: double.infinity, child: _img(img)),
              ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _accent(context).withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Text('$number',
                      style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 14)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(_v(item, 'title'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15.5,
                          letterSpacing: -0.2)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (text.isNotEmpty)
              _ClampText(text,
                  maxLines: 4,
                  onMore: more,
                  style: TextStyle(
                      height: 1.6,
                      fontSize: 13.5,
                      color: scheme.onSurfaceVariant)),
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
    final isVideoKind = kind == 'videos';
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
    return _Glass(
      radius: BorderRadius.circular(22),
      padding: const EdgeInsets.all(10),
      child: SizedBox(
        width: 296,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 172,
              width: double.infinity,
              child: _Tap(
                onTap: () {
                  if (video.isNotEmpty) {
                    _openUrl(video);
                  } else if (img.isNotEmpty) {
                    _viewImage(context, img);
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
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
                          child: _Glass(
                            shadow: false,
                            blur: 8,
                            radius: BorderRadius.circular(999),
                            padding: const EdgeInsets.all(10),
                            child: Icon(Icons.play_arrow_rounded,
                                color: scheme.onSurface, size: 26),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_v(item, 'title'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: -0.3)),
                  if (sub.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12.5, color: scheme.onSurfaceVariant)),
                    ),
                  if (meta.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(meta.toUpperCase(),
                          style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: scheme.primary)),
                    ),
                  if (text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _ClampText(text,
                          maxLines: 3,
                          onMore: more,
                          style: TextStyle(
                              height: 1.6,
                              fontSize: 13.5,
                              color: scheme.onSurfaceVariant)),
                    ),
                  const Spacer(),
                  if (target.isNotEmpty || (isVideoKind && video.isNotEmpty))
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: _MoreLink(
                          label: targetLabel, onTap: () => _openUrl(target)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FOOTER COMPACT (une seule bande navy)
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
    final accent = theme.accent ?? const Color(0xFFD9A441);
    final lang = _LangScope.of(context);

    final brand = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Avatar(url: b.logoUrl, name: b.name, radius: 18, ring: accent),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(b.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16)),
                  ),
                  if (b.verified) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified_rounded,
                        size: 14, color: Color(0xFF22C55E)),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(b.thixId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                      fontSize: 11)),
            ],
          ),
        ),
      ],
    );

    final nav = Wrap(
      spacing: 18,
      runSpacing: 10,
      children: [
        for (final l in links.take(8))
          _Tap(
            onTap: l.$2,
            child: Text(l.$1,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500)),
          ),
      ],
    );

    final contactIcons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (b.phone != null && b.phone!.trim().isNotEmpty) ...[
          _GlassIcon(
              dark: true,
              size: 38,
              icon: Icons.phone_rounded,
              onTap: () => _openTel(b.phone!)),
          const SizedBox(width: 10),
        ],
        if (b.email != null && b.email!.trim().isNotEmpty) ...[
          _GlassIcon(
              dark: true,
              size: 38,
              icon: Icons.mail_rounded,
              onTap: () => _openMail(b.email!)),
          const SizedBox(width: 10),
        ],
        if (b.website != null && b.website!.trim().isNotEmpty)
          _GlassIcon(
              dark: true,
              size: 38,
              icon: Icons.language_rounded,
              onTap: () => _openUrl(b.website)),
      ],
    );

    return Container(
      width: double.infinity,
      color: navy,
      child: Column(
        children: [
          Container(height: 2, color: accent),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
            child: _Wrap(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (c, cs) {
                      if (cs.maxWidth > 860) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(flex: 4, child: brand),
                            const SizedBox(width: 32),
                            Expanded(flex: 5, child: nav),
                            const SizedBox(width: 32),
                            contactIcons,
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          brand,
                          const SizedBox(height: 24),
                          nav,
                          const SizedBox(height: 24),
                          contactIcons,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Container(height: 1, color: Colors.white12),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 12,
                    spacing: 16,
                    children: [
                      Text(
                        '© ${DateTime.now().year} ${b.name}. ${_t(lang, 'rights')} · ${_t(lang, 'powered')}',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 11),
                      ),
                      _Tap(
                        onTap: onTop,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.arrow_upward_rounded,
                                  size: 14, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(_tr(context, 'top'),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.0)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
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
