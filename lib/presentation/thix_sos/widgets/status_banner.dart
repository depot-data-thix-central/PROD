/// THIX SOS — Bannière statut sécurité (Production Enterprise)
/// ✅ SÉCURISÉ : ThixPolicy, i18n, semantics, haptic, validation
/// ✅ DESIGN : couleurs cohérentes, withValues(alpha:), responsive
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

import '../models/sos_models.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const int _kMaxLocationLabelLength = 20;

// ============================================================================
// STATE
// ============================================================================
enum SecurityBannerState {
  safe,
  sosActive,
  networkLost,
  warning,
}

// ============================================================================
// VALIDATORS
// ============================================================================
class _BannerValidators {
  _BannerValidators._();

  static String sanitizeLabel(String? input, {int maxLength = _kMaxLocationLabelLength}) {
    if (input == null || input.trim().isEmpty) return '';
    final trimmed = input.trim();
    return trimmed.length > maxLength
        ? trimmed.substring(0, maxLength)
        : trimmed;
  }
}

// ============================================================================
// WIDGET
// ============================================================================
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    this.incident,
    this.locationLabel,
    this.onLocationTap,
    this.padding,
  });

  /// Si non null et actif → mode SOS
  final SosIncident? incident;
  final String? locationLabel;
  final VoidCallback? onLocationTap;
  final EdgeInsetsGeometry? padding;

  SecurityBannerState get _state {
    if (incident == null || !incident!.isActive) {
      return SecurityBannerState.safe;
    }
    if (incident!.status == SosStatus.networkLost) {
      return SecurityBannerState.networkLost;
    }
    return SecurityBannerState.sosActive;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = _state;

    final Color bg;
    final Color border;
    final Color iconColor;
    final Color titleColor;
    final IconData icon;
    final String title;
    final String subtitle;

    switch (state) {
      case SecurityBannerState.safe:
        bg = ThixPolicy.success.withValues(alpha: 0.15);
        border = ThixPolicy.success.withValues(alpha: 0.35);
        iconColor = ThixPolicy.success;
        titleColor = ThixPolicy.success;
        icon = Icons.verified_user_rounded;
        title = l10n.t('sos_banner_safe_title');
        subtitle = l10n.t('sos_banner_safe_subtitle');
        break;
      case SecurityBannerState.sosActive:
        bg = ThixPolicy.danger.withValues(alpha: 0.2);
        border = ThixPolicy.danger.withValues(alpha: 0.5);
        iconColor = ThixPolicy.danger;
        titleColor = Colors.white;
        icon = Icons.warning_amber_rounded;
        title = l10n.t('sos_banner_sos_title');
        subtitle = incident?.publicId ?? l10n.t('sos_incident_unknown');
        break;
      case SecurityBannerState.networkLost:
        bg = ThixPolicy.warning.withValues(alpha: 0.2);
        border = ThixPolicy.warning.withValues(alpha: 0.45);
        iconColor = ThixPolicy.warning;
        titleColor = Colors.white;
        icon = Icons.wifi_off_rounded;
        title = l10n.t('sos_banner_network_title');
        subtitle = l10n.t('sos_banner_network_subtitle');
        break;
      case SecurityBannerState.warning:
        bg = ThixPolicy.warning.withValues(alpha: 0.18);
        border = ThixPolicy.warning.withValues(alpha: 0.4);
        iconColor = ThixPolicy.warning;
        titleColor = Colors.white;
        icon = Icons.info_outline_rounded;
        title = l10n.t('sos_banner_warning_title');
        subtitle = l10n.t('sos_banner_warning_subtitle');
        break;
    }

    final safeLocationLabel = _BannerValidators.sanitizeLabel(locationLabel);

    return Semantics(
      container: true,
      label: '$title, $subtitle',
      child: Container(
        width: double.infinity,
        padding: padding ??
            const EdgeInsets.symmetric(
              horizontal: ThixPolicy.s14,
              vertical: ThixPolicy.s12,
            ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          border: Border.all(color: border, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: iconColor.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: ThixPolicy.s10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (safeLocationLabel.isNotEmpty) ...[
              const SizedBox(width: ThixPolicy.s8),
              Semantics(
                button: true,
                label: l10n.t('sos_view_location'),
                child: GestureDetector(
                  onTap: onLocationTap != null
                      ? () {
                          HapticFeedback.lightImpact();
                          onLocationTap!();
                        }
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ThixPolicy.s10,
                      vertical: ThixPolicy.s8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on,
                            size: 14, color: ThixPolicy.primary),
                        const SizedBox(width: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 90),
                          child: Text(
                            safeLocationLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ] else if (state == SecurityBannerState.safe)
              Semantics(
                label: l10n.t('sos_protection_active'),
                child: const Icon(Icons.check_circle,
                    color: ThixPolicy.success, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}
