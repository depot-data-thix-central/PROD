// lib/presentation/thix_ia/widgets/risk_card.dart
//
// RiskCard — "Monochrome Glass" (Production Enterprise)
//
// Design : 2 couleurs (blanc #FFF + encre #0B1220)
// Différenciation de sévérité par OPACITÉS uniquement (pas de couleurs).
//
// SÉCURITÉ (AUDIT PRIORITAIRE) :
// ✅ Sanitization XSS : suppression HTML/scripts/control chars
// ✅ Validation level : whitelist (low/medium/high/critical)
// ✅ Validation source : suppression caractères dangereux
// ✅ MaxLength : title 500, content 2000, source 200
// ✅ RepaintBoundary + Semantics
//
// ANTI-ERREURS COMPILATION :
// - Pas de args:{} dans l10n.t()
// - Pas de const sur widgets utilisant _IaPalette
// - Pas de strings FR hardcodés
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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

const int _kMaxTitleLength = 500;
const int _kMaxContentLength = 2000;
const int _kMaxSourceLength = 200;

const Set<String> _kAllowedLevels = {'low', 'medium', 'high', 'critical'};

// ============================================================================
// SANITIZER (SÉCURITÉ XSS)
// ============================================================================

class _RiskSanitizer {
  _RiskSanitizer._();

  /// Supprime HTML, scripts, control chars, et tronque
  static String sanitizeText(String? input, {required int maxLength}) {
    if (input == null || input.trim().isEmpty) return '';

    var sanitized = input
        // Supprimer tags HTML
        .replaceAll(RegExp(r'<[^>]*>'), '')
        // Supprimer scripts inline
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'vbscript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'data:', caseSensitive: false), '')
        // Supprimer control chars (sauf \n \t)
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .trim();

    // Tronquer
    if (sanitized.length > maxLength) {
      sanitized = '${sanitized.substring(0, maxLength)}…';
    }

    return sanitized;
  }

  /// Valide et sanitise le level (whitelist stricte)
  static String sanitizeLevel(String? level) {
    if (level == null) return 'medium';
    final lower = level.toLowerCase().trim();
    return _kAllowedLevels.contains(lower) ? lower : 'medium';
  }

  /// Sanitise la source (URL-like, pas de scripts)
  static String? sanitizeSource(String? source) {
    if (source == null || source.trim().isEmpty) return null;

    var sanitized = source
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .trim();

    if (sanitized.length > _kMaxSourceLength) {
      sanitized = sanitized.substring(0, _kMaxSourceLength);
    }

    return sanitized.isEmpty ? null : sanitized;
  }
}

// ============================================================================
// SEVERITY LEVELS (hiérarchie par opacités, sans couleur)
// ============================================================================

class _SeverityLevel {
  final double borderAlpha;
  final double headerAlpha;
  final double iconAlpha;
  final double badgeAlpha;
  final FontWeight titleWeight;

  const _SeverityLevel({
    required this.borderAlpha,
    required this.headerAlpha,
    required this.iconAlpha,
    required this.badgeAlpha,
    required this.titleWeight,
  });

  static _SeverityLevel from(String level) {
    switch (level) {
      case 'critical':
        return const _SeverityLevel(
          borderAlpha: 0.70,
          headerAlpha: 1.00,
          iconAlpha: 1.00,
          badgeAlpha: 0.18,
          titleWeight: FontWeight.w800,
        );
      case 'high':
        return const _SeverityLevel(
          borderAlpha: 0.55,
          headerAlpha: 0.95,
          iconAlpha: 0.95,
          badgeAlpha: 0.15,
          titleWeight: FontWeight.w800,
        );
      case 'medium':
        return const _SeverityLevel(
          borderAlpha: 0.30,
          headerAlpha: 0.80,
          iconAlpha: 0.70,
          badgeAlpha: 0.10,
          titleWeight: FontWeight.w700,
        );
      case 'low':
      default:
        return const _SeverityLevel(
          borderAlpha: 0.15,
          headerAlpha: 0.55,
          iconAlpha: 0.45,
          badgeAlpha: 0.07,
          titleWeight: FontWeight.w600,
        );
    }
  }
}

// ============================================================================
// WIDGET
// ============================================================================

class RiskCard extends StatelessWidget {
  const RiskCard({
    super.key,
    required this.title,
    required this.content,
    this.level = 'medium',
    this.source,
  });

  final String title;
  final String content;
  final String level; // low, medium, high, critical
  final String? source;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // ═══ SANITIZATION (SÉCURITÉ XSS) ═══
    final safeTitle = _RiskSanitizer.sanitizeText(title, maxLength: _kMaxTitleLength);
    final safeContent = _RiskSanitizer.sanitizeText(content, maxLength: _kMaxContentLength);
    final safeLevel = _RiskSanitizer.sanitizeLevel(level);
    final safeSource = _RiskSanitizer.sanitizeSource(source);

    // Fallback si title vide après sanitization
    if (safeTitle.isEmpty) {
      return const SizedBox.shrink();
    }

    final severity = _SeverityLevel.from(safeLevel);

    final levelLabel = safeLevel == 'critical'
        ? l10n.t('risk_critical')
        : safeLevel == 'high'
            ? l10n.t('risk_high')
            : safeLevel == 'medium'
                ? l10n.t('risk_medium')
                : l10n.t('risk_low');

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
                color: _IaPalette.white.withValues(alpha: severity.borderAlpha),
                width: 1,
              ),
            ),
            child: Semantics(
              label: '${l10n.t("risk_aria_label")}. '
                  '${l10n.t("severity_label")}: $levelLabel. $safeTitle',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ══ HEADER (glass + severity) ══
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color:
                          _IaPalette.white.withValues(alpha: severity.badgeAlpha),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(15),
                        topRight: Radius.circular(15),
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: _IaPalette.white
                              .withValues(alpha: severity.borderAlpha * 0.5),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: _IaPalette.white
                              .withValues(alpha: severity.iconAlpha),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${l10n.t("risk_label")} • $levelLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _IaPalette.white
                                  .withValues(alpha: severity.headerAlpha),
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (safeSource != null && safeSource.isNotEmpty)
                          SourceBadge(source: safeSource, type: 'official'),
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
                          safeTitle,
                          style: TextStyle(
                            color: _IaPalette.textPrimary,
                            fontWeight: severity.titleWeight,
                            fontSize: 14,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          safeContent,
                          style: TextStyle(
                            color: _IaPalette.textSecondary,
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ══ MITIGATION ROW ══
                        Row(
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 12,
                              color: _IaPalette.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                l10n.t('risk_mitigation'),
                                style: TextStyle(
                                  color: _IaPalette.textMuted,
                                  fontSize: 11,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
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
