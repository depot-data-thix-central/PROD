// lib/presentation/thix_ia/widgets/opportunity_card.dart
//
// OpportunityCard — "Monochrome Glass" (Production Enterprise)
//
// Design : 2 couleurs (blanc #FFF + encre #0B1220)
// Différenciation d'impact par OPACITÉS uniquement (pas de couleurs).
//
// ANTI-ERREURS APPLIQUÉES :
// - Pas de args:{} dans l10n.t()
// - Pas de const sur widgets utilisant _IaPalette
// - Pas de strings FR hardcodés
// - RepaintBoundary + Semantics
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

import 'source_badge.dart';

// ============================================================================
// PALETTE MONOCHROME
// ============================================================================

class _IaPalette {
  _IaPalette._();

  static const Color ink = Color(0xFF0B1220);
  static const Color white = Color(0xFFFFFFFF);

  static Color get glassStrong => white.withValues(alpha: 0.14);
  static Color get glass => white.withValues(alpha: 0.08);
  static Color get glassSoft => white.withValues(alpha: 0.05);
  static Color get glassBorder => white.withValues(alpha: 0.16);
  static Color get glassBorderSoft => white.withValues(alpha: 0.10);

  static Color get textPrimary => white;
  static Color get textSecondary => white.withValues(alpha: 0.62);
  static Color get textMuted => white.withValues(alpha: 0.40);
}

// ============================================================================
// CONSTANTS
// ============================================================================

const double _kGlassBlur = kIsWeb ? 8 : 14;

// ============================================================================
// IMPACT LEVELS (hiérarchie par opacités, sans couleur)
// ============================================================================

class _ImpactLevel {
  final double borderAlpha;
  final double headerAlpha;
  final double iconAlpha;
  final double badgeAlpha;
  final double chipAlpha;
  final FontWeight titleWeight;

  const _ImpactLevel({
    required this.borderAlpha,
    required this.headerAlpha,
    required this.iconAlpha,
    required this.badgeAlpha,
    required this.chipAlpha,
    required this.titleWeight,
  });

  static _ImpactLevel from(String impact) {
    switch (impact) {
      case 'high':
        return const _ImpactLevel(
          borderAlpha: 0.60,
          headerAlpha: 1.00,
          iconAlpha: 1.00,
          badgeAlpha: 0.15,
          chipAlpha: 0.15,
          titleWeight: FontWeight.w800,
        );
      case 'medium':
        return const _ImpactLevel(
          borderAlpha: 0.30,
          headerAlpha: 0.80,
          iconAlpha: 0.70,
          badgeAlpha: 0.10,
          chipAlpha: 0.10,
          titleWeight: FontWeight.w700,
        );
      case 'low':
      default:
        return const _ImpactLevel(
          borderAlpha: 0.15,
          headerAlpha: 0.55,
          iconAlpha: 0.45,
          badgeAlpha: 0.07,
          chipAlpha: 0.07,
          titleWeight: FontWeight.w600,
        );
    }
  }
}

// ============================================================================
// WIDGET
// ============================================================================

class OpportunityCard extends StatelessWidget {
  const OpportunityCard({
    super.key,
    required this.title,
    required this.description,
    this.impact = 'medium',
    this.source,
  });

  final String title;
  final String description;
  final String impact; // low, medium, high
  final String? source;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final level = _ImpactLevel.from(impact);

    final impactLabel = impact == 'high'
        ? l10n.t('impact_high')
        : impact == 'medium'
            ? l10n.t('impact_medium')
            : l10n.t('impact_low');

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _kGlassBlur, sigmaY: _kGlassBlur),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: _IaPalette.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _IaPalette.white.withValues(alpha: level.borderAlpha),
                width: 1,
              ),
            ),
            child: Semantics(
              label: '${l10n.t("opportunity_aria_label")}. '
                  '${l10n.t("impact_label")}: $impactLabel. $title',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ══ HEADER (glass + impact) ══
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color:
                          _IaPalette.white.withValues(alpha: level.badgeAlpha),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(15),
                        topRight: Radius.circular(15),
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: _IaPalette.white
                              .withValues(alpha: level.borderAlpha * 0.5),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.trending_up_rounded,
                          size: 16,
                          color: _IaPalette.white
                              .withValues(alpha: level.iconAlpha),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${l10n.t("opportunity_label")} • ${l10n.t("impact_label")} $impactLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _IaPalette.white
                                  .withValues(alpha: level.headerAlpha),
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (source != null && source!.trim().isNotEmpty)
                          SourceBadge(source: source!, type: 'official'),
                      ],
                    ),
                  ),

                  // ══ BODY ══
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: _IaPalette.textPrimary,
                            fontWeight: level.titleWeight,
                            fontSize: 14,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description,
                          style: TextStyle(
                            color: _IaPalette.textSecondary,
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ══ CHIP ACTION ══
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _IaPalette.white
                                .withValues(alpha: level.chipAlpha),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _IaPalette.white
                                  .withValues(alpha: level.chipAlpha * 1.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lightbulb_rounded,
                                size: 12,
                                color: _IaPalette.white
                                    .withValues(alpha: level.iconAlpha),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                l10n.t('opportunity_action_chip'),
                                style: TextStyle(
                                  color: _IaPalette.white
                                      .withValues(alpha: level.headerAlpha),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
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
    );
  }
}
