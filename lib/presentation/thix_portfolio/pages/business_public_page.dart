// ════════════════════════════════════════════════════════════════════════════
//  THIX PORTFOLIO BUSINESS — PAGE PUBLIQUE « INSTITUTIONNEL DENSE »
//  Fichier  : lib/presentation/thix_portfolio/pages/business_public_page.dart
//  Module   : THIX Portfolio Business
//  Éditeur  : SONATHIX GROUP — Kinshasa, RDC
//  Version  : 9.0.0 — Novembre 2026 (Site institutionnel sérieux, sans cadres)
// ════════════════════════════════════════════════════════════════════════════
//
//  ✅ v9.0 — RETOUR INSTITUTIONNEL, DENSE & SOBRE :
//    • AUCUN glassmorphism : fond blanc + bandes teintées via couleurs Studio
//    • Espacements RÉDUITS (bandes 48px, inter-grilles serrés, hairlines)
//    • SERVICES / PRODUITS / ACTUS / TÉMOIGNAGES : grilles « site internet »
//      sans cartes — séparateurs hairline, numérotation, typographie seule
//    • FICHE D'IDENTITÉ : tableau compact 3 colonnes (label + valeur),
//      présentation repliable au-dessus → hauteur divisée par 3
//    • Hero marine compact, chiffres clés en bandeau slim, footer resserré
//    • FR / EN, 10 rubriques avancées, images web robustes
//    • 100 % des couleurs via BusinessTheme (Studio inchangé)
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

Future<void> _openMail(String mail) =>
    launchUrl(Uri.parse('mailto:$mail'), mode: LaunchMode.externalApplication);

BorderRadius _radius(BuildContext c) =>
    Theme.of(c).extension<BusinessThemeExt>()?.radius ??
    BorderRadius.circular(4);

/// Rayon architectural sobre (max 6px).
BorderRadius _cardR(BuildContext c) =>
    BorderRadius.circular(_radius(c).topLeft.x.clamp(2.0, 6.0));

Color _accent(BuildContext c) =>
    Theme.of(c).extension<BusinessThemeExt>()?.accent ??
    Theme.of(c).colorScheme.tertiary;

/// Hairline institutionnelle.
Color _hair(BuildContext c) =>
    Theme.of(c).colorScheme.outlineVariant.withValues(alpha: 0.55);

/// Fond de bande teinté par la couleur primaire du Studio.
Color _tint(BuildContext c) =>
    Theme.of(c).colorScheme.primary.withValues(alpha: 0.035);

int _cols(double w, {int d = 3, int t = 2, int m = 1}) =>
    w > 900 ? d : (w > 600 ? t : m);

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
  const _Rise({required this.child, this.delay = 0, this.dy = 16});
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
// Briques UI institutionnelles (sans cadres)
// ─────────────────────────────────────────────────────────────────────────────
class _Pill extends StatelessWidget {
  const _Pill(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant, width: 1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 9.5,
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
              border: Border.all(color: ring!, width: 1),
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
                  fontWeight: FontWeight.w600,
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
                maxLines: maxLines, overflow: TextOverflow.ellipsis, style: st),
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
        Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.65) ??
        const TextStyle(fontSize: 14, height: 1.65);
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
                padding: const EdgeInsets.only(top: 10),
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

/// Fiche détail (texte complet) pour les cartes.
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
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 760),
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.84),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (image != null && image.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: ClipRRect(
                    borderRadius: _cardR(ctx),
                    child: SizedBox(
                        height: 240, width: double.infinity, child: _img(image)),
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
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
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
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(3)),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(_t(lang, 'close')),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(3)),
                    ),
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

/// En-tête de section institutionnel : filet accent + titre, marge réduite.
Widget _sectionHeader(BuildContext context, String title, {Widget? trailing}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 28),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 28, height: 2, color: _accent(context)),
              const SizedBox(height: 12),
              Text(
                _tt(context, title),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      height: 1.2,
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
    Widget block(double h) => Container(
          height: h,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(3),
          ),
        );
    return Scaffold(
      body: Shimmer.fromColors(
        baseColor: scheme.surfaceContainerHighest,
        highlightColor: scheme.surface,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(height: 64, color: Colors.white),
            Container(height: 380, color: Colors.white),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [block(90), block(200), block(140)]),
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
                    ?.copyWith(fontWeight: FontWeight.w700),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(3)),
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
    final navy = Color.lerp(theme.primary, Colors.black, 0.6)!;

    return _LangScope(
      code: lang,
      child: Scaffold(
        backgroundColor: scheme.surface,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openContactSheet,
          backgroundColor: navy,
          foregroundColor: Colors.white,
          elevation: 2,
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
          label: Text(_t(lang, 'contact'),
              style: const TextStyle(
                  fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
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
                backgroundColor: scheme.surface,
                surfaceTintColor: Colors.transparent,
                scrolledUnderElevation: 0,
                shadowColor: Colors.transparent,
                titleSpacing: 0,
                title: _headerTitle(context, blocks),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Container(height: 1, color: _hair(context)),
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
              SliverToBoxAdapter(child: _Figures(bundle: bundle)),
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
        ),
      ),
    );
  }

  // ── En-tête ──
  Widget _headerTitle(BuildContext context, List<_Blk> blocks) {
    final scheme = Theme.of(context).colorScheme;
    final b = bundle.business;
    final wide = MediaQuery.sizeOf(context).width >= 960;
    final canPop = Navigator.of(context).canPop();
    final nameRow = Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              b.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: -0.2),
            ),
          ),
          if (b.verified) ...[
            const SizedBox(width: 6),
            const Icon(Icons.verified_rounded, size: 15, color: Color(0xFF16A34A)),
          ],
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          if (canPop)
            IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          if (!wide)
            IconButton(
              tooltip: _t(_lang, 'menu'),
              icon: const Icon(Icons.menu_rounded, size: 20),
              onPressed: () => _openMenu(blocks),
            ),
          _Avatar(url: b.logoUrl, name: b.name, radius: 16),
          const SizedBox(width: 10),
          if (wide) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Row(mainAxisSize: MainAxisSize.min, children: [nameRow]),
            ),
            const SizedBox(width: 28),
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
                          foregroundColor: scheme.onSurface,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
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
          ] else
            Expanded(child: Row(children: [nameRow])),
          Tooltip(
            message: _t(_lang, 'lang_tip'),
            child: TextButton(
              onPressed: () => setState(() => _lang = _lang == 'fr' ? 'en' : 'fr'),
              style: TextButton.styleFrom(
                minimumSize: const Size(40, 36),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: Text(_lang == 'fr' ? 'EN' : 'FR',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, letterSpacing: 1.0, fontSize: 12)),
            ),
          ),
          PopupMenuButton<int>(
            icon: const Icon(Icons.more_vert_rounded, size: 20),
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
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(_t(lang, 'menu').toUpperCase(),
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5)),
              ),
              for (final blk in blocks)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.chevron_right_rounded, size: 18),
                  title: Text(blk.label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 14.5)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Future.delayed(
                        const Duration(milliseconds: 300), () => _goTo(blk.id));
                  },
                ),
            ],
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
      builder: (_) => AlertDialog(
        title: Text(bundle.business.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3),
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
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                  letterSpacing: 0.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_t(lang, 'close')),
          ),
        ],
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
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 680),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: channels.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_t(lang, 'no_channel')),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${_t(lang, 'contact_prefix')} ${bundle.business.name}',
                      style: Theme.of(sheetCtx)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
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
    );
  }
}

/// Bande de section : blanc / teinte Studio alternée, padding RÉDUIT (48).
class _Band extends StatelessWidget {
  const _Band({required this.index, required this.child});
  final int index;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final bg = index.isOdd ? _tint(context) : Colors.white;
    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(vertical: 48),
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
// HERO (compact, marine Studio)
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
    final height = math.min(math.max(360.0, size.height * 0.40), 460.0);
    final narrow = size.width < 700;
    final navy = Color.lerp(theme.primary, Colors.black, 0.65)!;
    final meta = [b.sector, b.city]
        .whereType<String>()
        .where((e) => e.trim().isNotEmpty)
        .join('  •  ');
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
                  stops: const [0, 0.6, 1],
                  colors: [
                    navy.withValues(alpha: 0.96),
                    navy.withValues(alpha: 0.65),
                    navy.withValues(alpha: 0.15),
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
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (b.verified)
                          _Rise(
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(2),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.verified_rounded,
                                      size: 12, color: Colors.white),
                                  const SizedBox(width: 6),
                                  Text(
                                    _tr(context, 'verified'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (meta.isNotEmpty)
                          _Rise(
                            delay: 60,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Container(width: 20, height: 2, color: theme.accent),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Text(
                                      meta.toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.85),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 2.0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        _Rise(
                          delay: 120,
                          child: Text(
                            b.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: narrow ? 32 : 48,
                              height: 1.05,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.2,
                            ),
                          ),
                        ),
                        if (b.claim != null && b.claim!.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: _Rise(
                              delay: 200,
                              child: Text(
                                b.claim!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.90),
                                  fontSize: narrow ? 14.5 : 17,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        _Rise(
                          delay: 280,
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            children: [
                              FilledButton.icon(
                                onPressed: onContact,
                                icon: const Icon(
                                    Icons.chat_bubble_outline_rounded, size: 15),
                                label: Text(_tr(context, 'contact_us'),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.4,
                                        fontSize: 13.5)),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: navy,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 13),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(2)),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: onDiscover,
                                icon: const Icon(Icons.arrow_forward_rounded,
                                    size: 15),
                                label: Text(_tr(context, 'discover'),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.4,
                                        fontSize: 13.5)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(
                                      color: Colors.white, width: 1),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 13),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(2)),
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
            bottom: 14,
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
                          height: 2,
                          decoration: BoxDecoration(
                            color: i == _index ? Colors.white : Colors.white38,
                            borderRadius: BorderRadius.circular(1),
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
// Chiffres clés (bandeau slim, hairlines)
// ─────────────────────────────────────────────────────────────────────────────
class _Figures extends StatelessWidget {
  const _Figures({required this.bundle});
  final BusinessBundle bundle;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final b = bundle.business;
    final items = <(int, String)>[
      if (b.ageYears != null && b.ageYears! > 0) (b.ageYears!, _tr(context, 'years')),
      if (b.employees != null && b.employees! > 0)
        (b.employees!, _tr(context, 'staff')),
      if ((bundle.stats?.views ?? 0) > 0) (bundle.stats!.views, _tr(context, 'visits')),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Container(height: 0.0, color: Colors.transparent),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FICHE D'IDENTITÉ — tableau compact (3 colonnes, hairlines)
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
    final cells = <(String, String, VoidCallback?)>[
      (_tr(context, 'f_sector'), b.sector ?? '—', null),
      (_tr(context, 'f_hq'), where.isEmpty ? '—' : where, null),
      (_tr(context, 'f_since'), '${b.sinceYear ?? '—'}', null),
      (_tr(context, 'f_staff'),
          b.employees == null ? '—' : '${b.employees} ${_tr(context, 'staff')}', null),
      (_tr(context, 'f_web'), b.website ?? '—', () => _openUrl(b.website)),
      (_tr(context, 'f_phone'), b.phone ?? '—', () => _openTel(b.phone ?? '')),
      (_tr(context, 'f_email'), b.email ?? '—', () => _openMail(b.email ?? '')),
      (_tr(context, 'f_id'), b.thixId, () async {
        await Clipboard.setData(ClipboardData(text: b.thixId));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('${_tr(context, 'copied')}${b.thixId}')));
      }),
      if (b.verified)
        (_tr(context, 'f_status'), _tr(context, 'verified_status'), null),
    ]..removeWhere((c) => c.$2 == '—' && c.$1 != _tr(context, 'f_id'));
    final desc = b.description?.trim() ?? '';
    final hair = _hair(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, _tr(context, 'identity')),
        if (desc.isNotEmpty) ...[
          _ExpandText(desc, maxLines: 3),
          const SizedBox(height: 20),
        ],
        LayoutBuilder(
          builder: (c, cs) {
            final cols = _cols(cs.maxWidth, d: 3, t: 2, m: 1);
            final rows = <List<(String, String, VoidCallback?)>>[];
            for (var i = 0; i < cells.length; i += cols) {
              rows.add(cells.skip(i).take(cols).toList());
            }
            return Column(
              children: [
                Container(height: 2, color: scheme.primary),
                for (final r in rows) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < r.length; i++) ...[
                        if (i > 0) Container(width: 1, color: hair),
                        Expanded(child: _SpecCell(cell: r[i])),
                      ],
                      for (var i = r.length; i < cols; i++) ...[
                        Container(width: 1, color: hair),
                        const Expanded(child: SizedBox.shrink()),
                      ],
                    ],
                  ),
                  Container(height: 1, color: hair),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SpecCell extends StatelessWidget {
  const _SpecCell({required this.cell});
  final (String, String, VoidCallback?) cell;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Tap(
      onTap: cell.$3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(cell.$1.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(cell.$2,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: cell.$3 != null ? scheme.primary : scheme.onSurface)),
          ],
        ),
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
        return _ContactSection(content: content as ContactContent);
    }
  }
}

// ── À PROPOS (texte + image, sans cadre) ──
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
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              content.tagline!,
              style: TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: scheme.onSurfaceVariant,
                  height: 1.5),
            ),
          ),
        _ExpandText(content.body,
            maxLines: 6,
            style: TextStyle(fontSize: 14.5, height: 1.75, color: scheme.onSurface)),
      ],
    );
    if (!hasImage) return text;
    return LayoutBuilder(
      builder: (context, cs) {
        final image = _Tap(
          onTap: () => _viewImage(context, url),
          child: ClipRRect(borderRadius: _cardR(context), child: _img(url)),
        );
        if (cs.maxWidth <= 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 240, width: double.infinity, child: image),
              const SizedBox(height: 28),
              text,
            ],
          );
        }
        final imgW = cs.maxWidth * 5 / 11;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: imgW, child: image),
            const SizedBox(width: 48),
            Expanded(child: text),
          ],
        );
      },
    );
  }
}

// ── SERVICES — grille « site internet », sans cartes, hairlines ──
class _ServicesSection extends StatelessWidget {
  const _ServicesSection({required this.content});
  final ServicesContent content;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = content.items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, content.title),
        LayoutBuilder(
          builder: (c, cs) {
            final cols = _cols(cs.maxWidth, d: 3, t: 2, m: 1);
            const gap = 32.0;
            final w = (cs.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: 0,
              children: [
                for (var i = 0; i < items.length; i++)
                  SizedBox(
                    width: w,
                    child: _ServiceCell(item: items[i], index: i),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ServiceCell extends StatelessWidget {
  const _ServiceCell({required this.item, required this.index});
  final ServiceItem item;
  final int index;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    void more() => _showDetail(context,
        title: item.title, image: item.imageUrl, chip: item.price, text: item.description);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _hair(context), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${(index + 1).toString().padLeft(2, '0')}.',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _accent(context)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                        letterSpacing: -0.2,
                        color: scheme.onSurface)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (item.description != null && item.description!.trim().isNotEmpty)
            _ClampText(item.description!,
                maxLines: 3,
                onMore: more,
                style: TextStyle(
                    height: 1.6, fontSize: 13, color: scheme.onSurfaceVariant)),
          if (item.price != null && item.price!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(item.price!,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: scheme.primary)),
            ),
        ],
      ),
    );
  }
}

// ── PRODUITS — grille simple image + texte ──
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
        _sectionHeader(context, content.title),
        LayoutBuilder(
          builder: (c, cs) {
            final cols = _cols(cs.maxWidth, d: 4, t: 3, m: 2);
            const gap = 20.0;
            final w = (cs.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: 24,
              children: [
                for (final p in items)
                  SizedBox(
                    width: w,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(
                          aspectRatio: 4 / 3,
                          child: (p.imageUrl == null || p.imageUrl!.isEmpty)
                              ? const _ImgFallback()
                              : ClipRRect(
                                  borderRadius: _cardR(context),
                                  child: _Tap(
                                    onTap: () => _showDetail(context,
                                        title: p.title,
                                        image: p.imageUrl,
                                        chip: p.price,
                                        text: p.description,
                                        url: p.url),
                                    child: _img(p.imageUrl!),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 10),
                        Text(p.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: scheme.onSurface)),
                        if (p.price != null && p.price!.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(p.price!,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                    color: scheme.primary)),
                          ),
                      ],
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

// ── GALERIE — grille images serrée ──
class _GallerySection extends StatelessWidget {
  const _GallerySection({required this.content});
  final GalleryContent content;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, content.title),
        LayoutBuilder(
          builder: (c, cs) {
            final cols = _cols(cs.maxWidth, d: 3, t: 2, m: 2);
            const gap = 10.0;
            final w = (cs.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final img in content.images)
                  SizedBox(
                    width: w,
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: _Tap(
                        onTap: () => _viewImage(context, img.url),
                        child: ClipRRect(
                          borderRadius: _cardR(context),
                          child: _img(img.url),
                        ),
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

// ── ÉQUIPE — grille sobre ──
class _TeamSection extends StatelessWidget {
  const _TeamSection({required this.content});
  final TeamContent content;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, content.title),
        LayoutBuilder(
          builder: (c, cs) {
            final cols = _cols(cs.maxWidth, d: 4, t: 3, m: 2);
            const gap = 24.0;
            final w = (cs.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: 24,
              children: [
                for (final m in content.members)
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
                              radius: 42,
                              ring: scheme.outlineVariant),
                          const SizedBox(height: 12),
                          Text(m.name,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: scheme.onSurface)),
                          if (m.role != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
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

// ── ACTUALITÉS — liste éditoriale 2 colonnes, hairlines ──
class _NewsSection extends StatelessWidget {
  const _NewsSection({required this.content});
  final NewsContent content;
  @override
  Widget build(BuildContext context) {
    final lang = _LangScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, content.title),
        LayoutBuilder(
          builder: (c, cs) {
            final cols = cs.maxWidth > 760 ? 2 : 1;
            const gap = 40.0;
            final w = (cs.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: 0,
              children: [
                for (final p in content.posts)
                  SizedBox(
                    width: w,
                    child: _NewsCell(
                        post: p,
                        date: p.publishedAt == null
                            ? null
                            : _fmtDate(lang, p.publishedAt!)),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _NewsCell extends StatelessWidget {
  const _NewsCell({required this.post, this.date});
  final NewsPost post;
  final String? date;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasText = post.excerpt != null && post.excerpt!.trim().isNotEmpty;
    void more() => _showDetail(context,
        title: post.title,
        subtitle: date,
        image: post.imageUrl,
        text: post.excerpt,
        url: post.url,
        urlLabel: _tr(context, 'read_full'));
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _hair(context), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (date != null)
            Text(date!.toUpperCase(),
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: scheme.primary)),
          const SizedBox(height: 6),
          Text(post.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15.5,
                  letterSpacing: -0.2,
                  height: 1.3,
                  color: scheme.onSurface)),
          if (hasText)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _ClampText(post.excerpt!,
                  maxLines: 2,
                  onMore: more,
                  showLink: false,
                  style: TextStyle(
                      height: 1.6, fontSize: 13, color: scheme.onSurfaceVariant)),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _MoreLink(label: _tr(context, 'read_full'), onTap: more),
          ),
        ],
      ),
    );
  }
}

// ── TÉMOIGNAGES — 2 colonnes, hairlines ──
class _TestimonialsSection extends StatelessWidget {
  const _TestimonialsSection({required this.content});
  final TestimonialsContent content;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, content.title),
        LayoutBuilder(
          builder: (c, cs) {
            final cols = cs.maxWidth > 760 ? 2 : 1;
            const gap = 40.0;
            final w = (cs.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: 0,
              children: [
                for (final t in content.items)
                  SizedBox(
                    width: w,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        border: Border(
                            top: BorderSide(color: _hair(context), width: 1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ClampText(
                            t.quote,
                            maxLines: 4,
                            onMore: () => _showDetail(context,
                                title: t.author ?? '', subtitle: t.role, text: t.quote),
                            style: TextStyle(
                                height: 1.6,
                                fontSize: 13.5,
                                fontStyle: FontStyle.italic,
                                color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 10),
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
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12.5,
                                              color: scheme.onSurface)),
                                    if (t.role != null)
                                      Text(t.role!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 11,
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
                                        size: 13,
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
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          children: [
            Icon(_contactIcon(c.type), size: 17, color: scheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.label ?? c.type.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(c.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.arrow_outward_rounded,
                size: 15, color: scheme.onSurfaceVariant),
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
        LayoutBuilder(
          builder: (c, cs) {
            final cols = cs.maxWidth > 760 ? 2 : 1;
            const gap = 40.0;
            final w = (cs.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              children: [
                for (final ch in content.channels)
                  SizedBox(
                    width: w,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                            top: BorderSide(color: _hair(context), width: 1)),
                      ),
                      child: _ContactTile(channel: ch),
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

// ─────────────────────────────────────────────────────────────────────────────
// 10 RUBRIQUES AVANCÉES (photos + vidéos) — grilles sobres
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
            _sectionHeader(context, title),
            Wrap(
              spacing: 28,
              runSpacing: 20,
              children: [
                for (final it in items) _LogoCell(item: it),
              ],
            ),
          ],
        );
      case BizLayout.steps:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(context, title),
            Column(
              children: [
                for (var i = 0; i < items.length; i++)
                  _StepCell(item: items[i], number: i + 1),
              ],
            ),
          ],
        );
      case BizLayout.standard:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(context, title),
            LayoutBuilder(
              builder: (c, cs) {
                final cols = _cols(cs.maxWidth, d: 3, t: 2, m: 1);
                const gap = 24.0;
                final w = (cs.maxWidth - gap * (cols - 1)) / cols;
                return Wrap(
                  spacing: gap,
                  runSpacing: 24,
                  children: [
                    for (final it in items)
                      SizedBox(
                          width: w, child: _StdCell(item: it, kind: spec.key)),
                  ],
                );
              },
            ),
          ],
        );
    }
  }
}

class _LogoCell extends StatelessWidget {
  const _LogoCell({required this.item});
  final Map<String, String> item;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final img = _v(item, 'image');
    final link = _v(item, 'link');
    return _Tap(
      onTap: link.isEmpty ? null : () => _openUrl(link),
      child: SizedBox(
        width: 130,
        child: Column(
          children: [
            SizedBox(
              height: 52,
              width: double.infinity,
              child: img.isEmpty
                  ? Icon(Icons.business_rounded, size: 34, color: scheme.primary)
                  : _img(img, fit: BoxFit.contain),
            ),
            const SizedBox(height: 8),
            Text(_v(item, 'title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                    color: scheme.onSurface)),
          ],
        ),
      ),
    );
  }
}

class _StepCell extends StatelessWidget {
  const _StepCell({required this.item, required this.number});
  final Map<String, String> item;
  final int number;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = _v(item, 'text');
    void more() => _showDetail(context,
        title: _v(item, 'title'),
        image: _v(item, 'image'),
        chip: '${_tr(context, 'step')} $number',
        text: text);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _hair(context), width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${number.toString().padLeft(2, '0')}.',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _accent(context))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_v(item, 'title'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: scheme.onSurface)),
                if (text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _ClampText(text,
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
    );
  }
}

class _StdCell extends StatelessWidget {
  const _StdCell({required this.item, required this.kind});
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: _Tap(
            onTap: () {
              if (video.isNotEmpty) {
                _openUrl(video);
              } else if (img.isNotEmpty) {
                _viewImage(context, img);
              } else {
                more();
              }
            },
            child: ClipRRect(
              borderRadius: _cardR(context),
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
                            : kBizKindByKey[kind]?.icon ?? Icons.image_outlined,
                        size: 32,
                        color: scheme.onSurfaceVariant),
                    ),
                  if (video.isNotEmpty)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            shape: BoxShape.circle),
                        child: Icon(Icons.play_arrow_rounded,
                            color: scheme.onSurface, size: 24),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(_v(item, 'title'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
                letterSpacing: -0.2,
                color: scheme.onSurface)),
        if (meta.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(meta.toUpperCase(),
                style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: scheme.primary)),
          ),
        if (text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _ClampText(text,
                maxLines: 2,
                onMore: more,
                showLink: false,
                style: TextStyle(
                    height: 1.6, fontSize: 12.5, color: scheme.onSurfaceVariant)),
          ),
        if (target.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _MoreLink(label: targetLabel, onTap: () => _openUrl(target)),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FOOTER (resserré)
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
    final navy = Color.lerp(theme.primary, Colors.black, 0.75)!;
    final lang = _LangScope.of(context);
    Widget colTitle(String s) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(s.toUpperCase(),
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
        );
    final where = [
      if (b.city != null && b.city!.trim().isNotEmpty) b.city!.trim(),
      if (b.country.trim().isNotEmpty) _country(lang, b.country),
    ].join(', ');
    Widget contactRow(IconData icon, String text, VoidCallback? onTap) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _Tap(
            onTap: onTap,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 14, color: Colors.white70),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12.5)),
                ),
              ],
            ),
          ),
        );
    final brand = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Avatar(url: b.logoUrl, name: b.name, radius: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(b.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ],
        ),
        if (b.claim != null && b.claim!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(b.claim!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    height: 1.5)),
          ),
        const SizedBox(height: 12),
        SelectableText(
          b.thixId,
          style: TextStyle(
              color: theme.accent, fontWeight: FontWeight.w600, fontSize: 11.5),
        ),
      ],
    );
    final nav = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        colTitle(_tr(context, 'nav')),
        for (final l in links.take(8))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _Tap(
              onTap: l.$2,
              child: Text(l.$1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5)),
            ),
          ),
      ],
    );
    final contact = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        colTitle(_tr(context, 'contact_info')),
        if (where.isNotEmpty) contactRow(Icons.place_rounded, where, null),
        if (b.phone != null && b.phone!.trim().isNotEmpty)
          contactRow(Icons.phone_rounded, b.phone!, () => _openTel(b.phone!)),
        if (b.email != null && b.email!.trim().isNotEmpty)
          contactRow(Icons.mail_rounded, b.email!, () => _openMail(b.email!)),
        if (b.website != null && b.website!.trim().isNotEmpty)
          contactRow(Icons.language_rounded, b.website!, () => _openUrl(b.website)),
      ],
    );
    return Container(
      width: double.infinity,
      color: navy,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 36, 24, 20),
        child: _Wrap(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (c, cs) {
                  if (cs.maxWidth > 760) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 4, child: brand),
                        const SizedBox(width: 40),
                        Expanded(flex: 3, child: nav),
                        const SizedBox(width: 40),
                        Expanded(flex: 4, child: contact),
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
                      contact,
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 10,
                spacing: 16,
                children: [
                  Text(
                    '© ${DateTime.now().year} ${b.name}. ${_tr(context, 'rights')} · ${_tr(context, 'powered')}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                    ),
                  _Tap(
                    onTap: onTop,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_upward_rounded,
                            size: 13, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(_tr(context, 'top'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
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
