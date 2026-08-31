// lib/presentation/home/widgets/home_premium_card.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/certification_tier.dart';
import 'package:thix_id/presentation/certification/certification_tiers_page.dart';
import 'package:thix_id/presentation/certification/providers/certification_provider.dart';

// ============================================================================
// CONSTANTS (Tailles réduites)
// ============================================================================
const double _kCardHeight = 64.0; // Réduit de 86 → 64 (-26%)
const double _kCardBorderRadius = 18.0;
const double _kIconSize = 36.0; // Réduit de 44 → 36
const double _kIconDecorationSize = 18.0; // Icône interne
const double _kButtonHeight = 28.0;
const double _kButtonBorderRadius = 12.0;
const int _kMaxTitleLength = 30;
const int _kMaxSubtitleLength = 50;

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================
class HomePremiumCard extends ConsumerWidget {
  const HomePremiumCard({super.key});

  void _openCertification(BuildContext context) {
    if (!context.mounted) return;
    HapticFeedback.selectionClick();
    debugPrint('[PremiumCard] 🎖️ Open certification');
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CertificationTiersPage()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final certAsync = ref.watch(myCertificationProvider);

    return RepaintBoundary(
      child: certAsync.when(
        loading: () => _CardShell(
          onTap: () => _openCertification(context),
          semanticsLabel: l10n.t('cert_loading'),
          child: _LoadingContent(l10n: l10n),
        ),
        error: (e, _) => _CardShell(
          onTap: () => _openCertification(context),
          semanticsLabel: l10n.t('cert_error'),
          child: _Content(
            title: l10n.t('cert_title'),
            subtitle: l10n.t('cert_tier_ladder'),
            color: ThixPolicy.primaryDeep,
            icon: Icons.verified_user_rounded,
            buttonLabel: l10n.t('cert_view'),
          ),
        ),
        data: (info) => _CardShell(
          onTap: () => _openCertification(context),
          accent: info.tier.badgeColor,
          semanticsLabel: _buildSemanticsLabel(l10n, info),
          child: _Content(
            title: _getTitle(l10n, info),
            subtitle: _getSubtitle(l10n, info),
            color: info.tier.badgeColor,
            icon: info.isCertified ? info.tier.icon : Icons.verified_user_rounded,
            buttonLabel: l10n.t('cert_view'),
          ),
        ),
      ),
    );
  }

  String _getTitle(AppLocalizations l10n, CertificationInfo info) {
    if (info.isCertified) {
      return _sanitize(info.tier.labelFr, _kMaxTitleLength);
    }
    if (info.status == CertificationStatus.pending) {
      return l10n.t('cert_pending');
    }
    return l10n.t('cert_title');
  }

  String _getSubtitle(AppLocalizations l10n, CertificationInfo info) {
    if (info.isCertified) {
      return _statusLine(l10n, info);
    }
    return l10n.t('cert_tier_ladder');
  }

  String _statusLine(AppLocalizations l10n, CertificationInfo info) {
    final statusLabel = info.status.labelFr;
    return switch (info.tier) {
      CertificationTier.official => l10n.t('cert_official_status', args: [statusLabel]),
      CertificationTier.enterprise => l10n.t('cert_enterprise_status', args: [statusLabel]),
      CertificationTier.premium => l10n.t('cert_premium_status', args: [statusLabel]),
      CertificationTier.standard => l10n.t('cert_standard_status', args: [statusLabel]),
      CertificationTier.free => l10n.t('cert_free_status', args: [statusLabel]),
    };
  }

  String _buildSemanticsLabel(AppLocalizations l10n, CertificationInfo info) {
    final title = _getTitle(l10n, info);
    final subtitle = _getSubtitle(l10n, info);
    return '$title. $subtitle';
  }

  String _sanitize(String input, int maxLength) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '—';
    return trimmed.length > maxLength ? trimmed.substring(0, maxLength) : trimmed;
  }
}

// ============================================================================
// CARD SHELL (Sans BackdropFilter = 10x plus rapide)
// ============================================================================
class _CardShell extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color? accent;
  final String semanticsLabel;

  const _CardShell({
    required this.child,
    required this.onTap,
    required this.semanticsLabel,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = accent?.withOpacity(0.4) ?? ThixPolicy.border.withOpacity(0.6);

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_kCardBorderRadius),
          child: Container(
            height: _kCardHeight,
            decoration: BoxDecoration(
              color: ThixPolicy.card,
              border: Border.all(color: borderColor, width: 1.2),
              borderRadius: BorderRadius.circular(_kCardBorderRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: ThixPolicy.s14,
              vertical: ThixPolicy.s10,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// LOADING CONTENT
// ============================================================================
class _LoadingContent extends StatelessWidget {
  final AppLocalizations l10n;

  const _LoadingContent({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: _kIconSize,
          height: _kIconSize,
          decoration: BoxDecoration(
            color: ThixPolicy.surfaceSoft,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ThixPolicy.primaryDeep,
              ),
            ),
          ),
        ),
        const SizedBox(width: ThixPolicy.s10),
        Expanded(
          child: Text(
            l10n.t('cert_loading_text'),
            style: ThixPolicy.captionStyle.copyWith(
              color: ThixPolicy.textSecondary,
              fontSize: 12,
              fontWeight: ThixPolicy.semiBold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// CONTENT
// ============================================================================
class _Content extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final String buttonLabel;

  const _Content({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.buttonLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Icône compacte
        Container(
          width: _kIconSize,
          height: _kIconSize,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3), width: 1.2),
          ),
          child: Icon(icon, color: color, size: _kIconDecorationSize),
        ),
        const SizedBox(width: ThixPolicy.s10),

        // Textes compacts
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ThixPolicy.labelStyle.copyWith(
                  color: ThixPolicy.textMain,
                  fontSize: 13,
                  fontWeight: ThixPolicy.bold,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ThixPolicy.captionStyle.copyWith(
                  color: ThixPolicy.textSecondary,
                  fontSize: 10.5,
                  fontWeight: ThixPolicy.regular,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: ThixPolicy.s8),

        // Bouton compact
        Semantics(
          button: true,
          label: buttonLabel,
          child: Container(
            height: _kButtonHeight,
            padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s12),
            decoration: BoxDecoration(
              color: ThixPolicy.primaryDeep,
              borderRadius: BorderRadius.circular(_kButtonBorderRadius),
              boxShadow: [
                BoxShadow(
                  color: ThixPolicy.primaryDeep.withOpacity(0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              buttonLabel,
              style: ThixPolicy.captionStyle.copyWith(
                color: Colors.white,
                fontWeight: ThixPolicy.bold,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
