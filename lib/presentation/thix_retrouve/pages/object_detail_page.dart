/// Object Detail Page (Production Enterprise)
/// ✅ ThixPolicy + i18n 8 langues + sanitization
/// ✅ CachedNetworkImage + Semantics + HapticFeedback
/// ✅ Logs structurés + validation des props
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const int _kMaxTitleLength = 100;
const int _kMaxDescriptionLength = 2000;
const int _kMaxLocationLength = 150;

// ============================================================================
// VALIDATORS & SANITIZERS
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
    required this.title,
    required this.status,
    required this.location,
    required this.time,
    required this.description,
    this.reward = '',
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isLost = status.toUpperCase() == 'PERDU';
    final accentColor = isLost ? ThixPolicy.danger : ThixPolicy.success;

    // ✅ Sanitization de tous les textes
    final safeTitle = _DetailSanitizer.sanitize(title, maxLength: _kMaxTitleLength);
    final safeDescription = _DetailSanitizer.sanitize(description, maxLength: _kMaxDescriptionLength);
    final safeLocation = _DetailSanitizer.sanitize(location, maxLength: _kMaxLocationLength);
    final safeReward = _DetailSanitizer.sanitize(reward, maxLength: 50);
    final safeImageUrl = _DetailSanitizer.sanitizeImageUrl(imageUrl);

    debugPrint('[ObjectDetail] 🚀 Page built: ${safeTitle.substring(0, safeTitle.length.clamp(0, 30))}');

    return Scaffold(
      backgroundColor: ThixPolicy.inkDeep,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        leading: Semantics(
          button: true,
          label: l10n.t('common_back'),
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: ThixPolicy.textMain, size: 20),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
          ),
        ),
        title: Text(
          l10n.t('object_detail_title'),
          style: ThixPolicy.h3Style.copyWith(
            color: ThixPolicy.textMain,
            fontWeight: ThixPolicy.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Semantics(
            button: true,
            label: l10n.t('common_more_options'),
            child: IconButton(
              icon: Icon(Icons.more_vert_rounded, color: ThixPolicy.textMain),
              onPressed: () {
                HapticFeedback.selectionClick();
                _showOptionsMenu(context, l10n, safeTitle, safeDescription, safeImageUrl);
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ──
            _buildImageSection(
              context,
              l10n,
              safeImageUrl,
              isLost,
              accentColor,
            ),
            const SizedBox(height: 16),

            // ── Title ──
            Semantics(
              header: true,
              child: Text(
                safeTitle.isEmpty ? l10n.t('object_no_title') : safeTitle,
                style: ThixPolicy.h2Style.copyWith(
                  color: ThixPolicy.textMain,
                  fontWeight: ThixPolicy.bold,
                ),
              ),
            ),
            const SizedBox(height: 6),

            // ── Status + Time ──
            Semantics(
              label: '${status}, ${time}',
              child: Text(
                '$status • $time',
                style: ThixPolicy.bodySmallStyle.copyWith(
                  color: accentColor,
                  fontWeight: ThixPolicy.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),

            // ── Location ──
            if (safeLocation.isNotEmpty)
              Semantics(
                label: l10n.t('object_location_label', args: [safeLocation]),
                child: Row(
                  children: [
                    Icon(Icons.location_on_rounded,
                        size: 14, color: ThixPolicy.textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        safeLocation,
                        style: ThixPolicy.captionStyle
                            .copyWith(color: ThixPolicy.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // ── Description ──
            if (safeDescription.isNotEmpty)
              Semantics(
                label: l10n.t('object_description_label'),
                child: Text(
                  safeDescription,
                  style: ThixPolicy.bodyStyle.copyWith(
                    color: ThixPolicy.textMain,
                    height: 1.5,
                  ),
                ),
              ),
            const SizedBox(height: 20),

            // ── Reward ──
            if (safeReward.isNotEmpty)
              _buildRewardCard(context, l10n, safeReward),
            const SizedBox(height: 24),

            // ── Action Buttons ──
            _buildActionButtons(context, l10n, safeTitle, safeDescription, safeImageUrl),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // IMAGE SECTION
  // ========================================================================

  Widget _buildImageSection(
    BuildContext context,
    AppLocalizations l10n,
    String? imageUrl,
    bool isLost,
    Color accentColor,
  ) {
    return RepaintBoundary(
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(ThixPolicy.rLg),
            child: Container(
              width: double.infinity,
              height: 240,
              color: ThixPolicy.surfaceSoft,
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 240,
                      placeholder: (context, url) => Center(
                        child: CircularProgressIndicator(
                          color: accentColor,
                          strokeWidth: 2,
                        ),
                      ),
                      errorWidget: (context, url, error) {
                        debugPrint('[ObjectDetail] ❌ Image load failed: $error');
                        return Center(
                          child: Icon(
                            Icons.broken_image_rounded,
                            size: 60,
                            color: ThixPolicy.textMuted,
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Icon(
                        Icons.inventory_2_outlined,
                        size: 70,
                        color: ThixPolicy.textMuted,
                      ),
                    ),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Semantics(
                label: l10n.t('object_status_label', args: [status]),
                child: Text(
                  status,
                  style: ThixPolicy.captionStyle.copyWith(
                    color: ThixPolicy.textMain,
                    fontWeight: ThixPolicy.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // REWARD CARD
  // ========================================================================

  Widget _buildRewardCard(
    BuildContext context,
    AppLocalizations l10n,
    String reward,
  ) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ThixPolicy.warning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          border: Border.all(color: ThixPolicy.warning.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.card_giftcard_rounded,
                color: ThixPolicy.warning, size: 24),
            const SizedBox(width: 10),
            Semantics(
              label: l10n.t('object_reward_label'),
              child: Text(
                l10n.t('object_reward'),
                style: ThixPolicy.bodyStyle.copyWith(
                  color: ThixPolicy.textMain,
                  fontWeight: ThixPolicy.bold,
                ),
              ),
            ),
            const Spacer(),
            Semantics(
              label: l10n.t('object_reward_amount', args: [reward]),
              child: Text(
                reward,
                style: ThixPolicy.h3Style.copyWith(
                  color: ThixPolicy.warning,
                  fontWeight: ThixPolicy.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // ACTION BUTTONS
  // ========================================================================

  Widget _buildActionButtons(
    BuildContext context,
    AppLocalizations l10n,
    String title,
    String description,
    String? imageUrl,
  ) {
    return Column(
      children: [
        // ── Contact Button ──
        Semantics(
          button: true,
          label: l10n.t('object_contact_button'),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: ThixPolicy.textMain,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                ),
                elevation: 0,
              ),
              onPressed: () {
                HapticFeedback.mediumImpact();
                _handleContact(context, l10n, title);
              },
              child: Text(
                l10n.t('object_contact_button'),
                style: ThixPolicy.titleStyle.copyWith(
                  color: ThixPolicy.textMain,
                  fontWeight: ThixPolicy.bold,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Share Button ──
        Semantics(
          button: true,
          label: l10n.t('object_share_button'),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: ThixPolicy.textMain,
                side: BorderSide(color: ThixPolicy.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                ),
              ),
              onPressed: () {
                HapticFeedback.mediumImpact();
                _handleShare(context, l10n, title, description, imageUrl);
              },
              child: Text(
                l10n.t('object_share_button'),
                style: ThixPolicy.titleStyle.copyWith(
                  color: ThixPolicy.textMain,
                  fontWeight: ThixPolicy.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ========================================================================
  // ACTION HANDLERS
  // ========================================================================

  void _handleContact(
    BuildContext context,
    AppLocalizations l10n,
    String title,
  ) {
    debugPrint('[ObjectDetail] 📞 Contact tapped for: ${title.substring(0, title.length.clamp(0, 30))}');
    
    // TODO: Implémenter la logique de contact (chat, appel, etc.)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: ThixPolicy.textMain, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.t('object_contact_coming_soon'),
                style: TextStyle(color: ThixPolicy.textMain, fontSize: 13),
              ),
            ),
          ],
        ),
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
    String? imageUrl,
  ) async {
    debugPrint('[ObjectDetail] 📤 Share tapped for: ${title.substring(0, title.length.clamp(0, 30))}');
    
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
    } catch (e, stack) {
      debugPrint('[ObjectDetail] ❌ Share failed: $e');
      if (kDebugMode) {
        debugPrint('[ObjectDetail] Stack: ${stack.toString().split('\n').first}');
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline_rounded, color: ThixPolicy.textMain, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.t('object_share_error'),
                    style: TextStyle(color: ThixPolicy.textMain, fontSize: 13),
                  ),
                ),
              ],
            ),
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
    String? imageUrl,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ThixPolicy.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(ThixPolicy.rLg)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ThixPolicy.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Semantics(
              button: true,
              label: l10n.t('object_report'),
              child: ListTile(
                leading: Icon(Icons.flag_rounded, color: ThixPolicy.danger),
                title: Text(
                  l10n.t('object_report'),
                  style: TextStyle(color: ThixPolicy.textMain),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  HapticFeedback.mediumImpact();
                  debugPrint('[ObjectDetail] 🚩 Report tapped');
                  // TODO: Implémenter le signalement
                },
              ),
            ),
            Semantics(
              button: true,
              label: l10n.t('object_share_button'),
              child: ListTile(
                leading: Icon(Icons.share_rounded, color: ThixPolicy.primary),
                title: Text(
                  l10n.t('object_share_button'),
                  style: TextStyle(color: ThixPolicy.textMain),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _handleShare(context, l10n, title, description, imageUrl);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
