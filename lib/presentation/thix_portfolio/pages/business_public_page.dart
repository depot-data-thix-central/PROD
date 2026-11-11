// ════════════════════════════════════════════════════════════════════════════
//  THIX PORTFOLIO BUSINESS — PAGE PUBLIQUE « INSTITUTIONNEL STARTUP »
//  Fichier  : lib/presentation/thix_portfolio/pages/business_public_page.dart
//  Module   : THIX Portfolio Business
//  Éditeur  : SONATHIX GROUP — Kinshasa, RDC
//  Version  : 10.1.0 — Novembre 2026
//
//  v10.1 : fiche d'identité en tableau (en-tête + lignes), identifiant THIX
//          sur UNE seule ligne (FittedBox), cartes vidéo avec miniature
//          (YouTube auto) ou visuel lecteur, partenaires en tuiles logo,
//          rubriques avancées numérotées, CTA sur les cartes.
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
const double _kMaxW = 1160;

const Color _kPageBg = Color(0xFFF8FAFC);
const Color _kLine = Color(0xFFE2E8F0);
const Color _kMuted = Color(0xFF64748B);
const Color _kGreen = Color(0xFF16A34A);

// ─────────────────────────────────────────────────────────────────────────────
// i18n FR / EN
// ─────────────────────────────────────────────────────────────────────────────
const Map<String, Map<String, String>> _i18n = {
  'fr': {
    'contact_us': 'Nous contacter',
    'discover': 'Découvrir nos services',
    'share': 'Partager',
    'contact': 'Contacter',
    'verified_status': 'Entreprise vérifiée',
    'staff': 'collaborateurs',
    'since': 'Depuis',
    'read_full': 'Lire la suite',
    'see_more': 'Voir plus',
    'see_less': 'Voir moins',
    'see_all': 'Voir tous',
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
    'menu': 'Menu',
    'step': 'Étape',
    'work_together': 'Travaillons ensemble',
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
    'copy': 'Copier',
  },
  'en': {
    'contact_us': 'Contact us',
    'discover': 'Discover our services',
    'share': 'Share',
    'contact': 'Contact',
    'verified_status': 'Verified company',
    'staff': 'team members',
    'since': 'Since',
    'read_full': 'Read more',
    'see_more': 'See more',
    'see_less': 'See less',
    'see_all': 'See all',
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
    'menu': 'Menu',
    'step': 'Step',
    'work_together': 'Let’s work together',
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
    'identity_title': 'Company profile',
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

const Map<String, String> _eyebrowEn = {
  'Profil': 'Profile',
  'À propos': 'About',
  'Expertises': 'Expertise',
  'Produits': 'Products',
  'Preuves': 'Proof',
  'Humain': 'People',
  'Actualités': 'News',
  'Ils nous font confiance': 'Trusted by',
  'Complément': 'More',
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

/// Accent assombri pour le texte (contraste sur fond blanc).
Color _accentText(BuildContext c) => Color.lerp(_accent(c), Colors.black, 0.3)!;

/// Encre navy (primary assombri).
Color _ink(BuildContext c) =>
    Color.lerp(Theme.of(c).colorScheme.primary, Colors.black, 0.45)!;

BoxDecoration _cardDeco(BuildContext c, {Color? color}) => BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _kLine),
    );

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

String _initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

/// Miniature YouTube automatique (null si ce n'est pas un lien YouTube).
String? _ytThumb(String url) {
  final u = url.trim();
  if (u.isEmpty) return null;
  final m = RegExp(
          r'(?:youtube\.com/(?:watch\?(?:.*&)?v=|embed/|shorts/)|youtu\.be/)([A-Za-z0-9_-]{11})')
      .firstMatch(u);
  if (m == null) return null;
  return 'https://img.youtube.com/vi/${m.group(1)}/hqdefault.jpg';
}

class _ImgFallback extends StatelessWidget {
  const _ImgFallback();
  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Color(0xFFF1F5F9),
        child: Center(
          child: Icon(Icons.image_not_supported_outlined,
              size: 22, color: Colors.black26),
        ),
      );
}

/// Image réseau robuste (repli <img> HTML sur le web → évite les erreurs CORS).
Widget _img(String url, {BoxFit fit = BoxFit.cover, Widget? fallback}) {
  return ColoredBox(
    color: const Color(0xFFF1F5F9),
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

/// Grille responsive (1 → 3 colonnes selon la largeur disponible).
class _Grid extends StatelessWidget {
  const _Grid({required this.children, this.minWidth = 320, this.gap = 16});
  final List<Widget> children;
  final double minWidth;
  final double gap;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (c, cs) {
      final maxW = cs.maxWidth;
      final cols = math.max(1, ((maxW + gap) / (minWidth + gap)).floor());
      final w = (maxW - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final ch in children) SizedBox(width: w, child: ch)],
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Briques UI
// ─────────────────────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.url,
    required this.name,
    required this.radius,
    this.square = false,
  });
  final String? url;
  final String name;
  final double radius;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final d = radius * 2;
    final ink = _ink(context);
    final fb = ColoredBox(
      color: ink.withValues(alpha: 0.08),
      child: Center(
        child: Text(_initials(name),
            style: TextStyle(
                fontSize: radius * 0.8,
                fontWeight: FontWeight.w800,
                color: ink)),
      ),
    );
    final has = url != null && url!.isNotEmpty;
    final content = SizedBox(
      width: d,
      height: d,
      child: has ? _img(url!, fallback: fb) : fb,
    );
    return square
        ? ClipRRect(
            borderRadius: BorderRadius.circular(radius * 0.5), child: content)
        : ClipOval(child: content);
  }
}

/// Vignette : image si disponible, sinon monogramme / icône sobre.
class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.url,
    required this.label,
    this.size = 56,
    this.radius = 12,
    this.icon,
  });
  final String? url;
  final String label;
  final double size;
  final double radius;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final ink = _ink(context);
    final has = url != null && url!.trim().isNotEmpty;
    final ph = Container(
      color: ink.withValues(alpha: 0.06),
      alignment: Alignment.center,
      child: icon != null
          ? Icon(icon, size: size * 0.42, color: ink.withValues(alpha: 0.7))
          : Text(_initials(label),
              style: TextStyle(
                  fontSize: size * 0.3,
                  fontWeight: FontWeight.w800,
                  color: ink.withValues(alpha: 0.65))),
    );
    return _Tap(
      onTap: has ? () => _viewImage(context, url!.trim()) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: size,
          height: size,
          child: has ? _img(url!.trim(), fallback: ph) : ph,
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
    final c = _ink(context);
    return _Tap(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  color: c, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(width: 6),
          Icon(icon ?? Icons.arrow_forward_rounded, size: 16, color: c),
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
        const TextStyle(fontSize: 15.5, height: 1.75, color: _kMuted);
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

/// Fiche détail — bottom sheet sobre.
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
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (ctx) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
                maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: _kLine,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  if (image != null && image.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                            height: 240,
                            width: double.infinity,
                            child: _img(image)),
                      ),
                    ),
                  if (chip != null && chip.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _ink(ctx).withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(chip.toUpperCase(),
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
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
                          style:
                              const TextStyle(fontSize: 14, color: _kMuted)),
                    ),
                  if (text != null && text.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    SelectableText(text,
                        style: const TextStyle(
                            fontSize: 15,
                            height: 1.75,
                            color: Color(0xFF334155))),
                  ],
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      if (url != null && url.isNotEmpty) ...[
                        FilledButton.icon(
                          onPressed: () => _openUrl(url),
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          label: Text(urlLabel ?? _t(lang, 'open')),
                          style: FilledButton.styleFrom(
                              backgroundColor: _ink(ctx),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10))),
                        ),
                        const SizedBox(width: 12),
                      ],
                      OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: _ink(ctx),
                            side: const BorderSide(color: _kLine),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                        child: Text(_t(lang, 'close')),
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

/// En-tête de section : numéro + filet + libellé, puis titre fort.
Widget _secHead(
  BuildContext context,
  String title, {
  String? moreLabel,
  VoidCallback? onMore,
  String? eyebrow,
}) {
  final lang = _LangScope.of(context);
  final narrow = MediaQuery.sizeOf(context).width < 700;
  final eb = eyebrow ?? _eyebrowFor(title);
  var num = '';
  var label = eb;
  if (eb.contains(' — ')) {
    final p = eb.split(' — ');
    num = p.first;
    label = p.sublist(1).join(' — ');
  }
  if (lang == 'en') label = _eyebrowEn[label] ?? label;
  return Padding(
    padding: EdgeInsets.only(bottom: narrow ? 22 : 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eb.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              if (num.isNotEmpty) ...[
                Text(num,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: _accentText(context))),
                Container(
                    width: 28,
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    color: const Color(0xFFCBD5E1)),
              ],
              Flexible(
                child: Text(label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.8,
                        color: _kMuted)),
              ),
            ]),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                _tt(context, title),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: narrow ? 26 : 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.9,
                    height: 1.15,
                    color: _ink(context)),
              ),
            ),
            if (onMore != null) ...[
              const SizedBox(width: 12),
              _MoreLink(
                  label: moreLabel ?? _tr(context, 'see_all'), onTap: onMore),
            ],
          ],
        ),
      ],
    ),
  );
}

String _eyebrowFor(String title) {
  final t = title.trim().toLowerCase();
  if (t.contains('propos') || t.contains('about')) return '02 — À propos';
  if (t.contains('service')) return '03 — Expertises';
  if (t.contains('produit') || t.contains('product')) return '03 — Produits';
  if (t.contains('galerie') ||
      t.contains('réalisation') ||
      t.contains('realisation')) return '04 — Preuves';
  if (t.contains('équipe') || t.contains('equipe') || t.contains('team')) {
    return '05 — Humain';
  }
  if (t.contains('actualit') || t.contains('news')) return '06 — Actualités';
  if (t.contains('témoignage') ||
      t.contains('temoignage') ||
      t.contains('avis')) return '07 — Ils nous font confiance';
  return '';
}

/// Carte média verticale : image / miniature vidéo / visuel lecteur / filet.
class _MediaCard extends StatelessWidget {
  const _MediaCard({
    required this.title,
    this.image,
    this.eyebrow,
    this.text,
    this.meta,
    this.onTap,
    this.video = false,
    this.cta,
  });
  final String title;
  final String? image;
  final String? eyebrow;
  final String? text;
  final String? meta;
  final VoidCallback? onTap;
  final bool video;
  final String? cta;

  @override
  Widget build(BuildContext context) {
    final ink = _ink(context);
    final has = image != null && image!.trim().isNotEmpty;

    Widget playBadge() => Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25), blurRadius: 16)
            ],
          ),
          child: Icon(Icons.play_arrow_rounded, color: ink, size: 30),
        );

    Widget media;
    if (has) {
      media = AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(fit: StackFit.expand, children: [
          _img(image!.trim()),
          if (video) ...[
            Container(color: Colors.black.withValues(alpha: 0.18)),
            Center(child: playBadge()),
          ],
        ]),
      );
    } else if (video) {
      media = AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [ink, Color.lerp(ink, Colors.black, 0.5)!],
            ),
          ),
          child: Center(child: playBadge()),
        ),
      );
    } else {
      media = Container(height: 3, color: _accent(context));
    }

    return _Tap(
      onTap: onTap,
      child: Container(
        decoration: _cardDeco(context),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            media,
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (eyebrow != null && eyebrow!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(eyebrow!.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.3,
                              color: _accentText(context))),
                    ),
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                          letterSpacing: -0.2,
                          color: ink)),
                  if (text != null && text!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(text!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13.5, height: 1.6, color: _kMuted)),
                    ),
                  if (meta != null && meta!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: ink.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(meta!,
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: ink)),
                      ),
                    ),
                  if (onTap != null && cta != null && cta!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(cta!,
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: ink)),
                        const SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, size: 14, color: ink),
                      ]),
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
    Widget block(double h) => Container(
          height: h,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
        );
    return Scaffold(
      backgroundColor: _kPageBg,
      body: Shimmer.fromColors(
        baseColor: const Color(0xFFE2E8F0),
        highlightColor: const Color(0xFFF8FAFC),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(height: 68, color: Colors.white),
            Container(height: 460, color: Colors.white),
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
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

/// Statistiques RÉELLES uniquement (aucun chiffre inventé).
List<(String, String)> _realStats(BusinessBundle bundle, String lang) {
  final b = bundle.business;
  final stats = <(String, String)>[];
  if (b.sinceYear != null && b.sinceYear! > 1900) {
    final years = DateTime.now().year - b.sinceYear!;
    if (years > 0) {
      stats.add((
        '$years+',
        lang == 'en' ? 'years of experience' : "ans d'expérience"
      ));
    }
  }
  if (b.employees != null && b.employees! > 0) {
    stats.add(
        ('${b.employees}', lang == 'en' ? 'team members' : 'collaborateurs'));
  }
  final svc = bundle.sectionOfType(BusinessSectionType.services)?.content;
  if (svc is ServicesContent && svc.items.isNotEmpty) {
    stats.add(('${svc.items.length}', 'services'));
  }
  final prod = bundle.sectionOfType(BusinessSectionType.products)?.content;
  if (prod is ProductsContent && prod.items.isNotEmpty) {
    stats.add(('${prod.items.length}', lang == 'en' ? 'products' : 'produits'));
  }
  return stats;
}

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
      alignment: 0.06,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = bundle.theme;
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
    final blocks = <_Blk>[
      for (final s in main)
        _Blk('s-${s.id}', _label(_titleOf(s.content)),
            _SectionRenderer(section: s)),
      for (var k = 0; k < visibleExtras.length; k++)
        if (kBizKindByKey[visibleExtras[k].kind] != null)
          _Blk(
            'x-${visibleExtras[k].kind}',
            (visibleExtras[k].title?.trim().isNotEmpty ?? false)
                ? visibleExtras[k].title!.trim()
                : (lang == 'en'
                    ? kBizKindByKey[visibleExtras[k].kind]!.en
                    : kBizKindByKey[visibleExtras[k].kind]!.fr),
            _ExtraSection(extra: visibleExtras[k], number: 8 + k),
          ),
    ];
    final firstSection = blocks.isNotEmpty ? blocks[0].id : 'contact-cta';
    final stats = _realStats(bundle, lang);

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
                toolbarHeight: 68,
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                scrolledUnderElevation: 0,
                elevation: 0,
                titleSpacing: 0,
                title: _headerTitle(context, blocks),
                bottom: const PreferredSize(
                  preferredSize: Size.fromHeight(1),
                  child: Divider(height: 1, thickness: 1, color: _kLine),
                ),
              ),
              SliverToBoxAdapter(
                child: _HeroBlock(
                  bundle: bundle,
                  images: _heroImages(),
                  stats: stats,
                  onContact: _openContactSheet,
                  onDiscover: () => _goTo(firstSection),
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
    final b = bundle.business;
    final wide = MediaQuery.sizeOf(context).width >= 960;
    final canPop = Navigator.of(context).canPop();
    final ink = _ink(context);
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
          _Avatar(url: b.logoUrl, name: b.name, radius: 19, square: true),
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
                      letterSpacing: -0.3,
                      color: ink),
                ),
                if (b.sector != null && b.sector!.trim().isNotEmpty)
                  Text(
                    b.sector!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: _kMuted),
                  ),
              ],
            ),
          ),
          if (b.verified && wide) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                border: Border.all(color: const Color(0xFFBBF7D0)),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_rounded, size: 13, color: _kGreen),
                  const SizedBox(width: 5),
                  Text(
                    _t(_lang, 'verified_status'),
                    style: const TextStyle(
                        color: Color(0xFF15803D),
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
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
                          foregroundColor: ink,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        child: Text(blk.label,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                  ],
                ),
              ),
            ),
          ] else
            const Spacer(),
          const SizedBox(width: 8),
          Tooltip(
            message: _t(_lang, 'lang_tip'),
            child: OutlinedButton(
              onPressed: () =>
                  setState(() => _lang = _lang == 'fr' ? 'en' : 'fr'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ink,
                side: const BorderSide(color: _kLine),
                minimumSize: const Size(44, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(_lang == 'fr' ? 'EN' : 'FR',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      fontSize: 12)),
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
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                          letterSpacing: 1.8,
                          color: _kMuted)),
                ),
                for (final blk in blocks)
                  ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    leading: Icon(Icons.chevron_right_rounded,
                        size: 18, color: _ink(ctx)),
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
    final lang = _lang;
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
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
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kLine),
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
                    color: _ink(context),
                    letterSpacing: 0.5),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                    foregroundColor: _ink(context),
                    side: const BorderSide(color: _kLine),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
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
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: _kLine,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        '${_t(lang, 'contact_prefix')} ${bundle.business.name}',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
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

/// FAB pill navy.
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: _ink(context),
          boxShadow: [
            BoxShadow(
              color: _ink(context).withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 10),
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
                  fontSize: 13.5,
                  letterSpacing: 0.2),
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
    final narrow = MediaQuery.sizeOf(context).width < 700;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : _kPageBg,
        border: const Border(top: BorderSide(color: _kLine)),
      ),
      padding: EdgeInsets.symmetric(vertical: narrow ? 44 : 72),
      child: _Wrap(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: narrow ? 20 : 32),
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO
// ─────────────────────────────────────────────────────────────────────────────
class _HeroBlock extends StatelessWidget {
  const _HeroBlock({
    required this.bundle,
    required this.images,
    required this.stats,
    required this.onContact,
    required this.onDiscover,
  });
  final BusinessBundle bundle;
  final List<String> images;
  final List<(String, String)> stats;
  final VoidCallback onContact;
  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    final theme = bundle.theme;
    final b = bundle.business;
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < 700;
    final height = math.min(math.max(500.0, size.height * 0.6), 700.0);
    final navy = Color.lerp(theme.primary, Colors.black, 0.55)!;
    final accent = theme.accent ?? const Color(0xFFEAB308);
    final desc = b.description?.trim() ?? '';
    final lang = _LangScope.of(context);
    final hasStats = stats.isNotEmpty;
    final pad = narrow ? 20.0 : 32.0;
    final place = [
      if (b.city != null && b.city!.isNotEmpty) b.city!,
      if (b.sinceYear != null)
        (lang == 'en' ? 'Since ${b.sinceYear}' : 'Depuis ${b.sinceYear}'),
    ].join('  ·  ');

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
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
                          colors: [
                            navy.withValues(alpha: 0.94),
                            navy.withValues(alpha: 0.72),
                            navy.withValues(alpha: 0.38),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.6, 1],
                          colors: [
                            Colors.transparent,
                            navy.withValues(alpha: 0.55),
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
                          padding: EdgeInsets.fromLTRB(
                              pad, 32, pad, hasStats ? 96 : 48),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 680),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (place.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.10),
                                      border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.25)),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                  color: accent,
                                                  shape: BoxShape.circle)),
                                          const SizedBox(width: 8),
                                          Text(place,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: 0.3)),
                                        ]),
                                  ),
                                const SizedBox(height: 24),
                                Container(
                                    width: 48,
                                    height: 4,
                                    decoration: BoxDecoration(
                                        color: accent,
                                        borderRadius:
                                            BorderRadius.circular(2))),
                                const SizedBox(height: 18),
                                _Rise(
                                  child: Text(b.name,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: narrow ? 38 : 60,
                                          height: 1.04,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: narrow ? -1.2 : -2)),
                                ),
                                if (b.claim != null &&
                                    b.claim!.trim().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 18),
                                    child: _Rise(
                                      delay: 120,
                                      child: Text(b.claim!,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: narrow ? 17 : 21,
                                              fontWeight: FontWeight.w500,
                                              height: 1.4)),
                                    ),
                                  ),
                                if (desc.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Text(desc,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.75),
                                            fontSize: 14.5,
                                            height: 1.6)),
                                  ),
                                const SizedBox(height: 28),
                                Wrap(spacing: 12, runSpacing: 12, children: [
                                  FilledButton(
                                    onPressed: onDiscover,
                                    style: FilledButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: navy,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 24, vertical: 16),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10))),
                                    child: Text(_tr(context, 'discover'),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14)),
                                  ),
                                  OutlinedButton(
                                    onPressed: onContact,
                                    style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: BorderSide(
                                            color: Colors.white
                                                .withValues(alpha: 0.6)),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 24, vertical: 16),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10))),
                                    child: Text(_tr(context, 'contact_us'),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14)),
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
            ),
            if (hasStats)
              Positioned(
                left: 0,
                right: 0,
                bottom: -40,
                child: _Wrap(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: pad),
                    child:
                        _StatsBar(stats: stats.take(narrow ? 3 : 4).toList()),
                  ),
                ),
              ),
          ],
        ),
        if (hasStats) const SizedBox(height: 56),
      ],
    );
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.stats});
  final List<(String, String)> stats;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kLine),
        boxShadow: [
          BoxShadow(
              color: _ink(context).withValues(alpha: 0.10),
              blurRadius: 32,
              offset: const Offset(0, 14)),
        ],
      ),
      child: Row(children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) Container(width: 1, height: 40, color: _kLine),
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(stats[i].$1,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      color: _ink(context))),
              const SizedBox(height: 4),
              Text(stats[i].$2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11.5, color: _kMuted)),
            ]),
          ),
        ],
      ]),
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
            right: 32,
            bottom: 64,
            child: Row(
              children: [
                for (var i = 0; i < imgs.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(left: 6),
                    width: i == _index ? 22 : 8,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: i == _index ? accent : Colors.white38,
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
// IDENTITÉ — fiche en tableau + identifiant THIX sur une seule ligne
// ─────────────────────────────────────────────────────────────────────────────
class _IdentityStrip extends StatelessWidget {
  const _IdentityStrip({required this.business});
  final Business business;

  @override
  Widget build(BuildContext context) {
    final lang = _LangScope.of(context);
    final ink = _ink(context);
    final b = business;
    final where = [
      if (b.city != null && b.city!.trim().isNotEmpty) b.city!.trim(),
      if (b.country.trim().isNotEmpty) _country(lang, b.country),
    ].join(', ');

    Future<void> copyId() async {
      await Clipboard.setData(ClipboardData(text: b.thixId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('${_tr(context, 'copied')}${b.thixId}')));
    }

    // (libellé, valeur, statut vert ?)
    final rows = <(String, String, bool)>[
      if (b.sector != null && b.sector!.trim().isNotEmpty)
        (_tr(context, 'f_sector'), b.sector!.trim(), false),
      if (where.isNotEmpty) (_tr(context, 'f_hq'), where, false),
      if (b.sinceYear != null)
        (_tr(context, 'f_since'), '${b.sinceYear}', false),
      if (b.employees != null)
        (
          _tr(context, 'f_staff'),
          '${b.employees} ${_tr(context, 'staff')}',
          false
        ),
      if (b.verified) (_tr(context, 'f_status'), _tr(context, 'verified_status'), true),
    ];

    final links = <Widget>[
      if (b.website != null && b.website!.isNotEmpty)
        _LinkChip(
            icon: Icons.language_rounded,
            label: _tr(context, 'f_web'),
            onTap: () => _openUrl(b.website)),
      if (b.phone != null && b.phone!.isNotEmpty)
        _LinkChip(
            icon: Icons.phone_rounded,
            label: _tr(context, 'f_phone'),
            onTap: () => _openTel(b.phone!)),
      if (b.email != null && b.email!.isNotEmpty)
        _LinkChip(
            icon: Icons.mail_rounded,
            label: _tr(context, 'f_email'),
            onTap: () => _openMail(b.email!)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _secHead(context, _tr(context, 'identity_title'),
            eyebrow: '01 — Profil'),
        Container(
          width: double.infinity,
          decoration: _cardDeco(context),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // En-tête : logo + dénomination
              Container(
                color: ink.withValues(alpha: 0.035),
                padding: const EdgeInsets.all(18),
                child: Row(children: [
                  _Avatar(
                      url: b.logoUrl, name: b.name, radius: 24, square: true),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_tr(context, 'f_name').toUpperCase(),
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4,
                                color: _kMuted)),
                        const SizedBox(height: 3),
                        Text(b.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                height: 1.2,
                                color: ink)),
                      ],
                    ),
                  ),
                ]),
              ),
              for (final r in rows) ...[
                const Divider(height: 1, thickness: 1, color: _kLine),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(r.$1,
                            style: const TextStyle(
                                fontSize: 13, color: _kMuted)),
                      ),
                      Expanded(
                        flex: 6,
                        child: Row(children: [
                          if (r.$3)
                            Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: const BoxDecoration(
                                    color: _kGreen, shape: BoxShape.circle)),
                          Flexible(
                            child: Text(r.$2,
                                style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    height: 1.3,
                                    color: r.$3
                                        ? const Color(0xFF15803D)
                                        : ink)),
                          ),
                        ]),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Identifiant THIX — UNE seule ligne, taille auto-ajustée
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
          decoration: BoxDecoration(
            color: ink,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Icon(Icons.badge_outlined,
                size: 20, color: Colors.white.withValues(alpha: 0.7)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_tr(context, 'f_id').toUpperCase(),
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: Colors.white.withValues(alpha: 0.6))),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(b.thixId,
                        maxLines: 1,
                        softWrap: false,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: Colors.white)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _Tap(
              onTap: copyId,
              child: Tooltip(
                message: _tr(context, 'copy'),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.content_copy_rounded,
                      size: 17, color: Colors.white),
                ),
              ),
            ),
          ]),
        ),
        if (links.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: links),
        ],
      ],
    );
  }
}

class _LinkChip extends StatelessWidget {
  const _LinkChip(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return _Tap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _kLine),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: _ink(context)),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: _ink(context))),
        ]),
      ),
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

// ── À PROPOS ──
class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.content});
  final AboutContent content;

  @override
  Widget build(BuildContext context) {
    final rawUrl = content.imageUrl;
    final imageUrl =
        (rawUrl != null && rawUrl.trim().isNotEmpty) ? rawUrl.trim() : null;
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (content.tagline != null && content.tagline!.trim().isNotEmpty)
          Container(
            padding: const EdgeInsets.only(left: 16),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
                border: Border(
                    left: BorderSide(color: _accent(context), width: 3))),
            child: Text(content.tagline!,
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                    letterSpacing: -0.2,
                    color: _ink(context))),
          ),
        _ExpandText(content.body, maxLines: 8),
      ],
    );

    final image = imageUrl == null
        ? null
        : _Tap(
            onTap: () => _viewImage(context, imageUrl),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(aspectRatio: 4 / 3, child: _img(imageUrl)),
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _secHead(context, content.title, eyebrow: '02 — À propos'),
        if (image == null)
          text
        else if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: text),
              const SizedBox(width: 48),
              Expanded(flex: 5, child: image),
            ],
          )
        else ...[
          image,
          const SizedBox(height: 28),
          text,
        ],
      ],
    );
  }
}

// ── SERVICES ──
class _ServicesSection extends StatelessWidget {
  const _ServicesSection({required this.content});
  final ServicesContent content;

  @override
  Widget build(BuildContext context) {
    final items = content.items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _secHead(context, content.title, eyebrow: '03 — Expertises'),
        _Grid(
          minWidth: 340,
          children: [
            for (var i = 0; i < items.length; i++)
              _ServiceCard(item: items[i], index: i),
          ],
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
    const icons = [
      Icons.auto_awesome_rounded,
      Icons.phone_iphone_rounded,
      Icons.cloud_rounded,
      Icons.explore_rounded,
      Icons.school_rounded,
    ];
    final desc = item.description ?? '';
    final num = (index + 1).toString().padLeft(2, '0');
    return _Tap(
      onTap: () => _showDetail(context,
          title: item.title,
          image: item.imageUrl,
          chip: item.price,
          text: item.description),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _cardDeco(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Thumb(
                url: item.imageUrl,
                label: item.title,
                size: 52,
                radius: 12,
                icon: icons[index % icons.length]),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                          letterSpacing: -0.2,
                          color: _ink(context))),
                  if (desc.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(desc,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13.5, height: 1.6, color: _kMuted)),
                    ),
                  if (item.price != null && item.price!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(item.price!,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: _accentText(context))),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(num,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: _kMuted.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }
}

// ── PRODUITS ──
class _ProductsSection extends StatelessWidget {
  const _ProductsSection({required this.content});
  final ProductsContent content;
  @override
  Widget build(BuildContext context) {
    final items = content.items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _secHead(context, content.title, eyebrow: '03 — Produits'),
        _Grid(
          minWidth: 300,
          children: [
            for (final it in items)
              _MediaCard(
                title: it.title,
                image: it.imageUrl,
                text: it.description,
                meta: it.price,
                cta: _tr(context, 'learn_more'),
                onTap: () => _showDetail(context,
                    title: it.title,
                    image: it.imageUrl,
                    chip: it.price,
                    text: it.description,
                    url: it.url),
              ),
          ],
        ),
      ],
    );
  }
}

// ── GALERIE ──
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
    final target = (_c.offset + _c.position.viewportDimension * 0.8)
        .clamp(0.0, _c.position.maxScrollExtent)
        .toDouble();
    _c.animateTo(target,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic);
  }

  Widget _caption(String text, double size) => Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: Container(
          padding: EdgeInsets.fromLTRB(size, 28, size, size * 0.8),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black87],
            ),
          ),
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: size > 12 ? 14 : 11)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final imgs = widget.content.images;
    if (imgs.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _secHead(context, widget.content.title, eyebrow: '04 — Preuves'),
        _Tap(
          onTap: () => _viewImage(context, imgs.first.url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 8,
              child: Stack(fit: StackFit.expand, children: [
                _img(imgs.first.url),
                if (imgs.first.caption != null &&
                    imgs.first.caption!.isNotEmpty)
                  _caption(imgs.first.caption!, 20),
              ]),
            ),
          ),
        ),
        if (imgs.length > 1) ...[
          const SizedBox(height: 14),
          SizedBox(
            height: 124,
            child: Stack(children: [
              ListView.separated(
                controller: _c,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                    right: MediaQuery.sizeOf(context).width < 700 ? 64 : 24),
                itemCount: imgs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (ctx, i) => _Tap(
                  onTap: () => _viewImage(ctx, imgs[i].url),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 176,
                      child: Stack(fit: StackFit.expand, children: [
                        _img(imgs[i].url),
                        if (imgs[i].caption != null &&
                            imgs[i].caption!.isNotEmpty)
                          _caption(imgs[i].caption!, 8),
                      ]),
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
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: _kLine),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 12)
                          ],
                        ),
                        child: Icon(Icons.arrow_forward_rounded,
                            size: 19, color: _ink(context)),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ],
      ],
    );
  }
}

// ── ÉQUIPE ──
class _TeamSection extends StatelessWidget {
  const _TeamSection({required this.content});
  final TeamContent content;
  @override
  Widget build(BuildContext context) {
    final members = content.members;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _secHead(context, content.title, eyebrow: '05 — Humain'),
        _Grid(
          minWidth: 320,
          children: [
            for (var i = 0; i < members.length; i++)
              _TeamRow(member: members[i], index: i),
          ],
        ),
      ],
    );
  }
}

class _TeamRow extends StatelessWidget {
  const _TeamRow({required this.member, required this.index});
  final dynamic member;
  final int index;
  @override
  Widget build(BuildContext context) {
    final name = (member.name as String?) ?? '';
    final role = (member.role as String?) ?? '';
    final bio = (member.bio as String?) ?? '';
    final photoUrl = member.photoUrl as String?;
    return _Tap(
      onTap: bio.trim().isEmpty
          ? null
          : () => _showDetail(context,
              title: name, subtitle: role, image: photoUrl, text: bio),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDeco(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipOval(
              child: SizedBox(
                width: 64,
                height: 64,
                child: (photoUrl != null && photoUrl.isNotEmpty)
                    ? _img(photoUrl, fallback: _monogram(context, name))
                    : _monogram(context, name),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: -0.2,
                          color: _ink(context))),
                  if (role.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(role,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: _accentText(context))),
                    ),
                  if (bio.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(bio,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5, height: 1.55, color: _kMuted)),
                    ),
                ],
              ),
            ),
            if (bio.trim().isNotEmpty) ...[
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, size: 16, color: _kMuted),
            ],
          ],
        ),
      ),
    );
  }

  Widget _monogram(BuildContext context, String name) => ColoredBox(
        color: _ink(context).withValues(alpha: 0.07),
        child: Center(
          child: Text(_initials(name),
              style: TextStyle(
                  color: _ink(context),
                  fontWeight: FontWeight.w800,
                  fontSize: 19)),
        ),
      );
}

// ── ACTUALITÉS ──
class _NewsSection extends StatelessWidget {
  const _NewsSection({required this.content});
  final NewsContent content;
  @override
  Widget build(BuildContext context) {
    final lang = _LangScope.of(context);
    final posts = content.posts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _secHead(context, content.title, eyebrow: '06 — Actualités'),
        _Grid(
          minWidth: 300,
          children: [
            for (final p in posts)
              _MediaCard(
                title: p.title,
                image: p.imageUrl,
                eyebrow: p.publishedAt == null
                    ? null
                    : _fmtDate(lang, p.publishedAt!),
                text: p.excerpt,
                cta: _tr(context, 'read_full'),
                onTap: () => _showDetail(context,
                    title: p.title,
                    subtitle: p.publishedAt == null
                        ? null
                        : _fmtDate(lang, p.publishedAt!),
                    image: p.imageUrl,
                    text: p.excerpt,
                    url: p.url,
                    urlLabel: _tr(context, 'read_full')),
              ),
          ],
        ),
      ],
    );
  }
}

// ── TÉMOIGNAGES ──
class _TestimonialsSection extends StatelessWidget {
  const _TestimonialsSection({required this.content});
  final TestimonialsContent content;
  @override
  Widget build(BuildContext context) {
    final items = content.items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _secHead(context, content.title,
            eyebrow: '07 — Ils nous font confiance'),
        _Grid(
          minWidth: 340,
          children: [
            for (var i = 0; i < items.length; i++)
              _TestimonialRow(item: items[i], index: i),
          ],
        ),
      ],
    );
  }
}

class _TestimonialRow extends StatelessWidget {
  const _TestimonialRow({required this.item, required this.index});
  final dynamic item;
  final int index;
  @override
  Widget build(BuildContext context) {
    final quote = (item.quote as String?) ?? '';
    final author = (item.author as String?) ?? '';
    final role = (item.role as String?) ?? '';

    int? rating;
    try {
      final raw = item.rating;
      if (raw is int) rating = raw;
    } catch (_) {
      rating = null;
    }

    return _Tap(
      onTap: () =>
          _showDetail(context, title: author, subtitle: role, text: quote),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: _cardDeco(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.format_quote_rounded,
                  color: _accent(context), size: 30),
              const Spacer(),
              if (rating != null)
                for (var i = 0; i < 5; i++)
                  Icon(
                      i < rating ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 15,
                      color: _accent(context)),
            ]),
            const SizedBox(height: 8),
            Text(quote,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    height: 1.7, fontSize: 14.5, color: Color(0xFF334155))),
            const SizedBox(height: 18),
            Container(height: 1, color: _kLine),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _ink(context).withValues(alpha: 0.07)),
                child: Center(
                  child: Text(_initials(author.isNotEmpty ? author : '?'),
                      style: TextStyle(
                          color: _ink(context),
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: _ink(context))),
                    if (role.isNotEmpty)
                      Text(role,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(fontSize: 12, color: _kMuted)),
                  ],
                ),
              ),
            ]),
          ],
        ),
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
    final c = channel;
    return _Tap(
      onTap: () async {
        final uri = c.launchUri;
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: _cardDeco(context),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _ink(context).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_contactIcon(c.type), size: 18, color: _ink(context)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.label ?? c.type.name,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: _ink(context))),
                  const SizedBox(height: 2),
                  Text(c.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: _kMuted)),
                ],
              ),
            ),
            const Icon(Icons.arrow_outward_rounded, size: 16, color: _kMuted),
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
    final navy = Color.lerp(theme.primary, Colors.black, 0.55)!;
    final accent = theme.accent ?? const Color(0xFFEAB308);
    final narrow = MediaQuery.sizeOf(context).width < 700;
    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_tr(context, 'work_together'),
            style: TextStyle(
                color: Colors.white,
                fontSize: narrow ? 24 : 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8)),
        const SizedBox(height: 8),
        Text(_tr(context, 'work_sub'),
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 14.5,
                height: 1.5)),
      ],
    );
    final button = FilledButton(
      onPressed: onContact,
      style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: navy,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      child: Text(_tr(context, 'contact_us'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
    );
    return Container(
      width: double.infinity,
      color: navy,
      padding: EdgeInsets.symmetric(vertical: narrow ? 44 : 64),
      child: _Wrap(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: narrow ? 20 : 32),
          child: narrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [texts, const SizedBox(height: 24), button])
              : Row(children: [
                  Expanded(child: texts),
                  const SizedBox(width: 24),
                  button
                ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RUBRIQUES AVANCÉES (numérotées 08, 09, …)
// ─────────────────────────────────────────────────────────────────────────────
String _v(Map<String, String> m, String k) => (m[k] ?? '').trim();

class _ExtraSection extends StatelessWidget {
  const _ExtraSection({required this.extra, required this.number});
  final BizExtra extra;
  final int number;
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
    final eyebrow = '${number.toString().padLeft(2, '0')} — Complément';
    switch (spec.layout) {
      case BizLayout.logo:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _secHead(context, title, eyebrow: eyebrow),
            _Grid(
              minWidth: 150,
              gap: 12,
              children: [for (final it in items) _LogoCard(item: it)],
            ),
          ],
        );
      case BizLayout.steps:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _secHead(context, title, eyebrow: eyebrow),
            _Grid(
              minWidth: 320,
              children: [
                for (var i = 0; i < items.length; i++)
                  _StepCard(item: items[i], number: i + 1),
              ],
            ),
          ],
        );
      case BizLayout.standard:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _secHead(context, title, eyebrow: eyebrow),
            _Grid(
              minWidth: 300,
              children: [
                for (final it in items) _StdCard(item: it, kind: spec.key),
              ],
            ),
          ],
        );
    }
  }
}

/// Tuile partenaire / client : logo centré, nom dessous.
class _LogoCard extends StatelessWidget {
  const _LogoCard({required this.item});
  final Map<String, String> item;
  @override
  Widget build(BuildContext context) {
    final ink = _ink(context);
    final img = _v(item, 'image');
    final title = _v(item, 'title');
    final sub = _v(item, 'subtitle');
    final link = _v(item, 'link');
    final mono = Container(
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(_initials(title),
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: ink.withValues(alpha: 0.65))),
    );
    return _Tap(
      onTap: link.isEmpty ? null : () => _openUrl(link),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: _cardDeco(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 68,
              width: double.infinity,
              child: img.isEmpty
                  ? mono
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _img(img, fit: BoxFit.contain, fallback: mono),
                    ),
            ),
            const SizedBox(height: 12),
            Text(title,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    height: 1.3,
                    color: ink)),
            if (sub.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(sub,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: _kMuted)),
              ),
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
        padding: const EdgeInsets.all(20),
        decoration: _cardDeco(context),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: _ink(context), borderRadius: BorderRadius.circular(10)),
            child: Center(
              child: Text('$number',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_v(item, 'title'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: -0.2,
                      color: _ink(context))),
              if (text.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(text,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            height: 1.6, fontSize: 13.5, color: _kMuted))),
            ]),
          ),
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
    final img = _v(item, 'image');
    final video = _v(item, 'video');
    final sub = _v(item, 'subtitle');
    final meta = _v(item, 'meta');
    final text = _v(item, 'text');
    final link = _v(item, 'link');
    final ctaLabel =
        kind == 'careers' ? _tr(context, 'apply') : _tr(context, 'learn_more');
    final target = link.isNotEmpty ? link : video;
    final targetLabel =
        link.isEmpty && video.isNotEmpty ? _tr(context, 'watch') : ctaLabel;
    // Miniature : image fournie, sinon miniature YouTube automatique.
    final shownImage = img.isNotEmpty ? img : (_ytThumb(video) ?? '');
    return _MediaCard(
      title: _v(item, 'title'),
      image: shownImage.isEmpty ? null : shownImage,
      eyebrow: sub,
      text: text,
      meta: meta,
      video: video.isNotEmpty,
      cta: targetLabel,
      onTap: () => _showDetail(context,
          title: _v(item, 'title'),
          subtitle: sub,
          image: shownImage,
          chip: meta,
          text: text,
          url: target,
          urlLabel: targetLabel),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FOOTER
// ─────────────────────────────────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  const _Footer(
      {required this.bundle, required this.links, required this.onTop});
  final BusinessBundle bundle;
  final List<(String, VoidCallback)> links;
  final VoidCallback onTop;

  @override
  Widget build(BuildContext context) {
    final theme = bundle.theme;
    final b = bundle.business;
    final navy = Color.lerp(theme.primary, Colors.black, 0.75)!;
    final accent = theme.accent ?? const Color(0xFFEAB308);
    final publicUrl = '$kThixPublicBaseUrl/b/${b.thixId}';
    final narrow = MediaQuery.sizeOf(context).width < 700;
    final section = bundle.sectionOfType(BusinessSectionType.contact);
    final channels = section?.content is ContactContent
        ? (section!.content as ContactContent).channels
        : const <ContactChannel>[];

    Widget iconBtn(IconData icon, VoidCallback onTap, {bool strong = false}) =>
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: _Tap(
            onTap: onTap,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: strong ? accent : Colors.white.withValues(alpha: 0.08),
              ),
              child: Icon(icon, size: 16, color: strong ? navy : Colors.white),
            ),
          ),
        );

    return Container(
      width: double.infinity,
      color: navy,
      padding: EdgeInsets.symmetric(
          horizontal: narrow ? 20 : 32, vertical: narrow ? 32 : 44),
      child: _Wrap(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _Avatar(url: b.logoUrl, name: b.name, radius: 18, square: true),
              const SizedBox(width: 12),
              Expanded(
                child: Text(b.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: -0.2)),
              ),
              for (final c in channels.take(3))
                iconBtn(_contactIcon(c.type), () async {
                  final uri = c.launchUri;
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }),
              iconBtn(Icons.ios_share_rounded, () => Share.share(publicUrl)),
              iconBtn(Icons.arrow_upward_rounded, onTop, strong: true),
            ]),
            if (links.isNotEmpty) ...[
              const SizedBox(height: 28),
              Wrap(
                spacing: 24,
                runSpacing: 10,
                children: [
                  for (final l in links)
                    _Tap(
                      onTap: l.$2,
                      child: Text(l.$1,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 28),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.12)),
            const SizedBox(height: 18),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                Text(
                    '© ${DateTime.now().year} ${b.name}. ${_tr(context, 'rights')}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12)),
                Text(_tr(context, 'powered'),
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12)),
              ],
            ),
          ],
        ),
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
