/// Object Detail Page — Enterprise Glass Design (Production)
/// ✅ Cohérent avec THIX RETROUVE : glass monochrome, texte blanc
/// ✅ Pastilles de statut (pas de badges solides)
/// ✅ i18n complet + sanitization + Semantics + HapticFeedback
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

// ============================================================================
// DESIGN TOKENS (identiques à l'écran RETROUVE)
// ============================================================================

const double _kGlassSurface = 0.05;
const double _kGlassSurfaceHi = 0.08;
const double _kGlassBorder = 0.09;
const double _kRadiusLg = 20.0;
const double _kRadiusMd = 16.0;
const double _kRadiusSm = 12.0;

const int _kMaxTitleLength = 100;
const int _kMaxDescriptionLength = 2000;
const int _kMaxLocationLength = 150;

// Texte primaire GARANTI blanc sur fond sombre (indépendant du thème)
const Color _kTextPrimary = Colors.white;

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
// GLASS CARD
// ============================================================================

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = _kRadiusMd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: _kGlassSurfaceHi),
            Colors.white.withValues(alpha: _kGlassSurface),
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.white.withValues(alpha: _kGlassBorder),
          width: 1,
        ),
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
  final String? imageUrl;

  const ObjectDetailPage({
    super.key,
    this.title = '',
    this.status = '',
    this.location = '',
    this.time = '',
    this.description = '',
    this.reward = '',
    this.imageUrl,
  });

  Color _statusColor(String status) {
    final s = status.toUpperCase();
    if (s.contains('PERDU') || s.contains('LOST')) {
      return ThixPolicy.domainOpportunity;
    }
    if (s.contains('TROUV') || s.contains('FOUND')) {
      return ThixPolicy.success;
    }
    return ThixPolicy.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final statusColor = _statusColor(status);

    final safeTitle =
        _DetailSanitizer.sanitize(title, maxLength: _kMaxTitleLength);
    final safeDescription = _DetailSanitizer.sanitize(description,
        maxLength: _kMaxDescriptionLength);
    final safeLocation =
        _DetailSanitizer.sanitize(location, maxLength: _kMaxLocationLength);
    final safeReward = _DetailSanitizer.sanitize(reward, maxLength: 50);
    final safeImageUrl = _DetailSanitizer.sanitizeImageUrl(imageUrl);

    debugPrint('[ObjectDetail] 🚀 Page built: '
        '${safeTitle.substring(0, safeTitle.length.clamp(0, 30))}');

    return Scaffold(
      backgroundColor: ThixPolicy.inkDeep,
      // ✅ AppBar transparente, fond unifié
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Semantics(
          button: true,
          label: l10n.t('common_back'),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: _kTextPrimary, size: 20),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
          ),
        ),
        title: Text(
          l10n.t('object_detail_title'),
          style: const TextStyle(
            color: _kTextPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          Semantics(
            button: true,
            label: l10n.t('common_more_options'),
            child: IconButton(
              icon: const Icon(Icons.more_vert_rounded,
                  color: _kTextPrimary, size: 20),
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
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image (glass card) ──
            _buildImageSection(l10n, safeImageUrl, statusColor),
            const SizedBox(height: 18),

            // ── Title + status pill ──
            Semantics(
              header: true,
              child: Text(
                safeTitle.isEmpty ? l10n.t('object_no_title') : safeTitle,
                style: const TextStyle(
                  color: _kTextPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _statusPill(statusColor, status),
                if (time.isNotEmpty)
                  Text(
                    time,
                    style: TextStyle(
                      color: ThixPolicy.textMuted,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Location (chip glass) ──
            if (safeLocation.isNotEmpty)
              _GlassCard(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                radius: _kRadiusSm,
                child: Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 14, color: ThixPolicy.textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        safeLocation,
                        style: TextStyle(
                          color: ThixPolicy.textMuted,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),

            // ── Description (glass card) ──
            if (safeDescription.isNotEmpty) ...[
              Text(
                l10n.t('object_description_label'),
                style: TextStyle(
                  color: ThixPolicy.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              _GlassCard(
                child: Text(
                  safeDescription,
                  style: const TextStyle(
                    color: _kTextPrimary,
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ── Reward (glass teinté subtil) ──
            if (safeReward.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ThixPolicy.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(_kRadiusMd),
                  border: Border.all(
                    color: ThixPolicy.warning.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.card_giftcard_rounded,
                        color: ThixPolicy.warning, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.t('object_reward'),
                        style: TextStyle(
                          color: ThixPolicy.textMuted,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    Text(
                      safeReward,
                      style: const TextStyle(
                        color: _kTextPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
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
    AppLocalizations l10n,
    String? imageUrl,
    Color statusColor,
  ) {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kRadiusLg),
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              height: 250,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: _kGlassSurfaceHi),
                    Colors.white.withValues(alpha: _kGlassSurface),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: _kGlassBorder),
                ),
              ),
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _kTextPrimary,
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Icon(
                        Icons.broken_image_rounded,
                        size: 48,
                        color: _kTextPrimary.withValues(alpha: 0.25),
                      ),
                    )
                  : Center(
                      child: Icon(
                        Icons.inventory_2_outlined,
                        size: 56,
                        color: _kTextPrimary.withValues(alpha: 0.25),
                      ),
                    ),
            ),
            // ✅ Pastille glass (plus de badge solide)
            if (status.isNotEmpty)
              Positioned(
                top: 12,
                left: 12,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: ThixPolicy.inkDeep.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.4),
                        ),
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
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
        // ── Contact (plein, bleu) ──
        Semantics(
          button: true,
          label: l10n.t('object_contact_button'),
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
                l10n.t('object_contact_button'),
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

        // ── Share (glass outline) ──
        Semantics(
          button: true,
          label: l10n.t('object_share_button'),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.mediumImpact();
                _handleShare(context, l10n, title, description, location,
                    imageUrl);
              },
              borderRadius: BorderRadius.circular(_kRadiusMd),
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: _kGlassSurface),
                  borderRadius: BorderRadius.circular(_kRadiusMd),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.share_rounded,
                        color: _kTextPrimary, size: 17),
                    const SizedBox(width: 8),
                    Text(
                      l10n.t('object_share_button'),
                      style: const TextStyle(
                        color: _kTextPrimary,
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
        content: Text(l10n.t('object_contact_coming_soon'),
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
${l10n.t('object_share_text')}

📦 $title
📍 $location
📝 $description
${imageUrl != null ? '🖼️ $imageUrl' : ''}

${l10n.t('object_share_via_thix')}
''';
      await Share.share(shareText, subject: title);
      HapticFeedback.mediumImpact();
      debugPrint('[ObjectDetail] ✓ Share successful');
    } catch (e) {
      debugPrint('[ObjectDetail] ❌ Share failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.t('object_share_error'),
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
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: ThixPolicy.inkDeep.withValues(alpha: 0.7),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _menuItem(
                    sheetCtx,
                    icon: Icons.flag_rounded,
                    tint: ThixPolicy.danger,
                    label: l10n.t('object_report'),
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
                    label: l10n.t('object_share_button'),
                    onTap: () => _handleShare(context, l10n, title,
                        description, location, imageUrl),
                  ),
                ],
              ),
            ),
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
          child: _GlassCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: tint, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: _kTextPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: ThixPolicy.textMuted, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
