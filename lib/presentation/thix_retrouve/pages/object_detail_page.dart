/// Object Detail Page — Light Premium Design (Production)
/// ✅ FIX 1 : auto-hydratation depuis GoRouterState.extra (plus de page vide
///    si la route ne transfère pas les arguments)
/// ✅ FIX 2 : _tr() avec fallbacks → plus jamais de clé l10n brute affichée
/// ✅ Affiche TOUTES les infos : titre, statut, heure, lieu, description,
///    récompense, contact, image
/// ✅ Cohérent avec THIX RETROUVE : fond clair, cartes propres, texte sombre
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

// ============================================================================
// DESIGN TOKENS (Light Premium — identiques à ThixRetrouveScreen)
// ============================================================================

const Color _kBg = Color(0xFFF7F9FC);
const Color _kSurface = Color(0xFFFFFFFF);
const Color _kTextMain = Color(0xFF12233D);
const Color _kTextSec = Color(0xFF5A6B84);
const Color _kTextMuted = Color(0xFF93A1B5);
const Color _kBorder = Color(0xFFE5EAF1);
const Color _kGold = Color(0xFFE0A400);
const Color _kGoldDeep = Color(0xFFB07F00);
const Color _kRed = Color(0xFFE5484D);

const double _kRadiusLg = 18.0;
const double _kRadiusMd = 14.0;

const int _kMaxTitleLength = 100;
const int _kMaxDescriptionLength = 2000;
const int _kMaxLocationLength = 150;

// ============================================================================
// SANITIZER
// ============================================================================

class _DetailSanitizer {
  _DetailSanitizer._();

  static String sanitize(String? input, {required int maxLength}) {
    if (input == null || input.isEmpty) return '';
    final s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? '${s.substring(0, maxLength)}…' : s;
  }

  static String? sanitizeImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    if (!url.startsWith('http://') && !url.startsWith('https://')) return null;
    return url.trim();
  }
}

// ============================================================================
// SURFACE CARD
// ============================================================================

class _SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const _SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = _kRadiusMd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _kBorder, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ============================================================================
// PAGE
// ============================================================================

class ObjectDetailPage extends StatelessWidget {
  final String title;
  final String status;
  final String location;
  final String time;
  final String description;
  final String reward;
  final String contact;
  final String? imageUrl;

  const ObjectDetailPage({
    super.key,
    this.title = '',
    this.status = '',
    this.location = '',
    this.time = '',
    this.description = '',
    this.reward = '',
    this.contact = '',
    this.imageUrl,
  });

  // ── 🛡️ Traduction sûre : fallback FR si clé absente (jamais de clé brute) ──
  String _tr(AppLocalizations l10n, String key, String fallback) {
    final v = l10n.t(key);
    return (v == key || v.trim().isEmpty) ? fallback : v;
  }

  // ── 🔄 Auto-hydratation : extra de la route si le constructeur est vide ──
  Map<String, dynamic> _routeExtra(BuildContext context) {
    try {
      final e = GoRouterState.of(context).extra;
      if (e is Map<String, dynamic>) return e;
      if (e is Map) return Map<String, dynamic>.from(e);
    } catch (_) {}
    return const {};
  }

  Color _statusColor(String status) {
    final s = status.toUpperCase();
    if (s.contains('PERDU') || s.contains('LOST')) {
      return _kRed;
    }
    if (s.contains('TROUV') || s.contains('FOUND')) {
      return ThixPolicy.success;
    }
    return _kTextMuted;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // ✅ Fusion constructeur + extra de route (le non-vide gagne)
    final args = _routeExtra(context);
    String pick(String ctor, String key) =>
        ctor.trim().isNotEmpty ? ctor : (args[key]?.toString() ?? '').trim();

    final rawTitle = pick(title, 'title');
    final rawStatus = pick(status, 'status');
    final rawLocation = pick(location, 'location');
    final rawTime = pick(time, 'time');
    final rawDescription = pick(description, 'description');
    final rawReward = pick(reward, 'reward');
    final rawContact = pick(contact, 'contact');
    final rawImageUrl = (imageUrl?.trim().isNotEmpty ?? false)
        ? imageUrl
        : (args['imageUrl'] as String?);

    final safeTitle =
        _DetailSanitizer.sanitize(rawTitle, maxLength: _kMaxTitleLength);
    final safeDescription = _DetailSanitizer.sanitize(rawDescription,
        maxLength: _kMaxDescriptionLength);
    final safeLocation =
        _DetailSanitizer.sanitize(rawLocation, maxLength: _kMaxLocationLength);
    final safeReward = _DetailSanitizer.sanitize(rawReward, maxLength: 50);
    final safeContact =
        _DetailSanitizer.sanitize(rawContact, maxLength: 100);
    final safeImageUrl = _DetailSanitizer.sanitizeImageUrl(rawImageUrl);
    final statusColor = _statusColor(rawStatus);

    debugPrint('[ObjectDetail] 🚀 Page built: '
        '${safeTitle.substring(0, safeTitle.length.clamp(0, 30))}');

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: Semantics(
          button: true,
          label: _tr(l10n, 'common_back', 'Retour'),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: _kTextMain, size: 20),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
          ),
        ),
        title: Text(
          _tr(l10n, 'object_detail_title', 'Détail de l\'objet'),
          style: const TextStyle(
            color: _kTextMain,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          Semantics(
            button: true,
            label: _tr(l10n, 'common_more_options', 'Plus d\'options'),
            child: IconButton(
              icon: const Icon(Icons.more_vert_rounded,
                  color: _kTextMain, size: 20),
              onPressed: () {
                HapticFeedback.selectionClick();
                _showOptionsMenu(context, l10n, safeTitle, safeDescription,
                    safeLocation, safeImageUrl);
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ─
            _buildImageSection(safeImageUrl, rawStatus, statusColor),
            const SizedBox(height: 18),

            // ── Titre ──
            Semantics(
              header: true,
              child: Text(
                safeTitle.isEmpty
                    ? _tr(l10n, 'object_no_title', 'Objet sans titre')
                    : safeTitle,
                style: const TextStyle(
                  color: _kTextMain,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ── Statut + heure (affichés seulement si présents) ──
            if (rawStatus.isNotEmpty || rawTime.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (rawStatus.isNotEmpty)
                    _statusPill(statusColor, rawStatus),
                  if (rawTime.isNotEmpty)
                    Text(
                      rawTime,
                      style: const TextStyle(
                        color: _kTextSec,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 14),

            // ── Lieu ──
            if (safeLocation.isNotEmpty) ...[
              _SurfaceCard(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 16, color: _kTextSec),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        safeLocation,
                        style: const TextStyle(
                          color: _kTextSec,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ── Description ──
            if (safeDescription.isNotEmpty) ...[
              Text(
                _tr(l10n, 'object_description_label', 'DESCRIPTION'),
                style: const TextStyle(
                  color: _kTextSec,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              _SurfaceCard(
                child: Text(
                  safeDescription,
                  style: const TextStyle(
                    color: _kTextMain,
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ── Récompense ──
            if (safeReward.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kGold.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(_kRadiusMd),
                  border: Border.all(color: _kGold.withOpacity(0.30)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.card_giftcard_rounded,
                        color: _kGoldDeep, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _tr(l10n, 'object_reward', 'Récompense proposée'),
                        style: const TextStyle(
                          color: _kTextSec,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    Text(
                      safeReward,
                      style: const TextStyle(
                        color: _kGoldDeep,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ── Contact alternatif ──
            if (safeContact.isNotEmpty) ...[
              _SurfaceCard(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                child: Row(
                  children: [
                    const Icon(Icons.alternate_email_rounded,
                        size: 16, color: _kTextSec),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        safeContact,
                        style: const TextStyle(
                          color: _kTextSec,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ── Actions ──
            _buildActionButtons(context, l10n, safeTitle, safeDescription,
                safeLocation, safeImageUrl),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // IMAGE
  // ========================================================================

  Widget _buildImageSection(
    String? imageUrl,
    String status,
    Color statusColor,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_kRadiusLg),
      child: Container(
        width: double.infinity,
        height: 250,
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(_kRadiusLg),
          border: Border.all(color: _kBorder, width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A0F172A),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 250,
                    placeholder: (_, __) => const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_rounded,
                          size: 48, color: _kTextMuted),
                    ),
                  )
                : const Center(
                    child: Icon(Icons.inventory_2_outlined,
                        size: 56, color: _kTextMuted),
                  ),
            // Pastille statut (seulement si statut présent)
            if (status.isNotEmpty)
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x140F172A),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusPill(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // ACTIONS
  // ========================================================================

  Widget _buildActionButtons(
    BuildContext context,
    AppLocalizations l10n,
    String title,
    String description,
    String location,
    String? imageUrl,
  ) {
    return Column(
      children: [
        Semantics(
          button: true,
          label: _tr(l10n, 'object_contact_button', 'Contacter le déclarant'),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_kRadiusMd),
                ),
                elevation: 0,
              ),
              onPressed: () {
                HapticFeedback.mediumImpact();
                _handleContact(context, l10n, title);
              },
              child: Text(
                _tr(l10n, 'object_contact_button', 'Contacter le déclarant'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        Semantics(
          button: true,
          label: _tr(l10n, 'object_share_button', 'Partager l\'annonce'),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.mediumImpact();
                _handleShare(
                    context, l10n, title, description, location, imageUrl);
              },
              borderRadius: BorderRadius.circular(_kRadiusMd),
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  color: _kSurface,
                  borderRadius: BorderRadius.circular(_kRadiusMd),
                  border: Border.all(color: _kBorder, width: 1.2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A0F172A),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.share_rounded, color: _kTextMain, size: 17),
                    const SizedBox(width: 8),
                    Text(
                      _tr(l10n, 'object_share_button', 'Partager l\'annonce'),
                      style: const TextStyle(
                        color: _kTextMain,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
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

  // ========================================================================
  // HANDLERS
  // ========================================================================

  void _handleContact(
    BuildContext context,
    AppLocalizations l10n,
    String title,
  ) {
    debugPrint('[ObjectDetail] 📞 Contact tapped: '
        '${title.substring(0, title.length.clamp(0, 30))}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            _tr(l10n, 'object_contact_coming_soon', 'Contact bientôt disponible'),
            style: const TextStyle(fontSize: 13)),
        backgroundColor: ThixPolicy.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleShare(
    BuildContext context,
    AppLocalizations l10n,
    String title,
    String description,
    String location,
    String? imageUrl,
  ) async {
    debugPrint('[ObjectDetail] 📤 Share tapped');
    try {
      final shareText = '''
${_tr(l10n, 'object_share_text', 'Annonce THIX RETROUVE :')}

📦 $title
📍 $location
📝 $description
${imageUrl != null ? '🖼️ $imageUrl' : ''}

${_tr(l10n, 'object_share_via_thix', 'Via THIX ID CENTRAL')}
''';
      await Share.share(shareText, subject: title);
      HapticFeedback.mediumImpact();
      debugPrint('[ObjectDetail] ✓ Share successful');
    } catch (e) {
      debugPrint('[ObjectDetail] ❌ Share failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_tr(l10n, 'object_share_error', 'Partage impossible'),
                style: const TextStyle(fontSize: 13)),
            backgroundColor: ThixPolicy.danger,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showOptionsMenu(
    BuildContext context,
    AppLocalizations l10n,
    String title,
    String description,
    String location,
    String? imageUrl,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _kBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              _menuItem(
                sheetCtx,
                icon: Icons.flag_rounded,
                tint: _kRed,
                label: _tr(l10n, 'object_report', 'Signaler cette annonce'),
                onTap: () {
                  HapticFeedback.mediumImpact();
                  debugPrint('[ObjectDetail] 🚩 Report tapped');
                },
              ),
              const SizedBox(height: 10),
              _menuItem(
                sheetCtx,
                icon: Icons.share_rounded,
                tint: ThixPolicy.primary,
                label: _tr(l10n, 'object_share_button', 'Partager l\'annonce'),
                onTap: () => _handleShare(
                    context, l10n, title, description, location, imageUrl),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuItem(
    BuildContext sheetCtx, {
    required IconData icon,
    required Color tint,
    required String label,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pop(sheetCtx);
            onTap();
          },
          borderRadius: BorderRadius.circular(_kRadiusMd),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(_kRadiusMd),
              border: Border.all(color: _kBorder, width: 1.2),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: tint.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: tint, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: _kTextMain,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: _kTextMuted, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
