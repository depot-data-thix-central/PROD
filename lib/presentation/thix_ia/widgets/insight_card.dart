// lib/presentation/thix_ia/widgets/insight_card.dart
//
// InsightCard — "Monochrome Glass" (Production Enterprise)
//
// Design : 2 couleurs (blanc #FFF + encre #0B1220)
// Différenciation de type par ICÔNE + OPACITÉ (pas de couleurs).
//
// SÉCURITÉ (AUDIT PRIORITAIRE) :
// ✅ Sanitization XSS : suppression HTML/scripts/control chars
// ✅ Validation type : whitelist (market/finance/strategy/business/insight)
// ✅ Validation confidence : clamp 0.0-1.0
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

import 'confidence_indicator.dart';
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

const Set<String> _kAllowedTypes = {
  'market',
  'finance',
  'strategy',
  'business',
  'insight'
};

// ============================================================================
// SANITIZER (SÉCURITÉ XSS)
// ============================================================================

class _InsightSanitizer {
  _InsightSanitizer._();

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

  /// Valide et sanitise le type (whitelist stricte)
  static String sanitizeType(String? type) {
    if (type == null) return 'insight';
    final lower = type.toLowerCase().trim();
    return _kAllowedTypes.contains(lower) ? lower : 'insight';
  }

  /// Valide et clamp la confidence (0.0-1.0)
  static double sanitizeConfidence(double? confidence) {
    if (confidence == null) return 0.75;
    if (confidence.isNaN || confidence.isInfinite) return 0.75;
    return confidence.clamp(0.0, 1.0);
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
// TYPE CONFIG (hiérarchie par opacités + icônes, sans couleur)
// ============================================================================

class _InsightTypeConfig {
  final IconData icon;
  final double iconAlpha;
  final double badgeAlpha;
  final double borderAlpha;

  const _InsightTypeConfig({
    required this.icon,
    required this.iconAlpha,
    required this.badgeAlpha,
    required this.borderAlpha,
  });

  static _InsightTypeConfig from(String type) {
    switch (type) {
      case 'market':
        return const _InsightTypeConfig(
          icon: Icons.trending_up_rounded,
          iconAlpha: 1.00,
          badgeAlpha: 0.15,
          borderAlpha: 0.55,
        );
      case 'finance':
        return const _InsightTypeConfig(
          icon: Icons.calculate_rounded,
          iconAlpha: 0.95,
          badgeAlpha: 0.13,
          borderAlpha: 0.50,
        );
      case 'strategy':
        return const _InsightTypeConfig(
          icon: Icons.rocket_launch_rounded,
          iconAlpha: 0.95,
          badgeAlpha: 0.13,
          borderAlpha: 0.50,
        );
      case 'business':
        return const _InsightTypeConfig(
          icon: Icons.business_center_rounded,
          iconAlpha: 0.90,
          badgeAlpha: 0.12,
          borderAlpha: 0.45,
        );
      case 'insight':
      default:
        return const _InsightTypeConfig(
          icon: Icons.lightbulb_rounded,
          iconAlpha: 0.85,
          badgeAlpha: 0.10,
          borderAlpha: 0.30,
        );
    }
  }
}

// ============================================================================
// WIDGET
// ============================================================================

class InsightCard extends StatelessWidget {
  const InsightCard({
    super.key,
    required this.title,
    required this.content,
    this.confidence = 0.75,
    this.type = 'insight',
    this.source,
  });

  final String title;
  final String content;
  final double confidence;
  final String type;
  final String? source;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // ═══ SANITIZATION (SÉCURITÉ XSS) ═══
    final safeTitle =
        _InsightSanitizer.sanitizeText(title, maxLength: _kMaxTitleLength);
    final safeContent =
        _InsightSanitizer.sanitizeText(content, maxLength: _kMaxContentLength);
    final safeType = _InsightSanitizer.sanitizeType(type);
    final safeConfidence = _InsightSanitizer.sanitizeConfidence(confidence);
    final safeSource = _InsightSanitizer.sanitizeSource(source);

    // Fallback si title vide après sanitization
    if (safeTitle.isEmpty) {
      return const SizedBox.shrink();
    }

    final config = _InsightTypeConfig.from(safeType);

    final typeLabel = safeType == 'market'
        ? l10n.t('insight_type_market')
        : safeType == 'finance'
            ? l10n.t('insight_type_finance')
            : safeType == 'strategy'
                ? l10n.t('insight_type_strategy')
                : safeType == 'business'
                    ? l10n.t('insight_type_business')
                    : l10n.t('insight_type_insight');

    final confidencePct = (safeConfidence * 100).toInt();

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _kGlassBlur, sigmaY: _kGlassBlur),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _IaPalette.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    _IaPalette.white.withValues(alpha: config.borderAlpha),
                width: 1,
              ),
            ),
            child: Semantics(
              label: '$typeLabel. $safeTitle. '
                  '${l10n.t("insight_confidence_label")}: $confidencePct%',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ══ HEADER ROW ══
                  Row(
                    children: [
                      // Icon badge (glass + type icon)
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _IaPalette.white
                              .withValues(alpha: config.badgeAlpha),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _IaPalette.white
                                .withValues(alpha: config.borderAlpha * 0.6),
                          ),
                        ),
                        child: Icon(
                          config.icon,
                          color: _IaPalette.white
                              .withValues(alpha: config.iconAlpha),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Title
                      Expanded(
                        child: Text(
                          safeTitle,
                          style: TextStyle(
                            color: _IaPalette.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Confidence indicator
                      ConfidenceIndicator(
                        value: safeConfidence,
                        size: 32,
                        showLabel: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ══ CONTENT ══
                  Text(
                    safeContent,
                    style: TextStyle(
                      color: _IaPalette.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ══ FOOTER ROW ══
                  Row(
                    children: [
                      SourceBadge(
                        source: safeSource ?? typeLabel,
                        type: 'official',
                      ),
                      const Spacer(),
                      Text(
                        l10n.t('insight_source_verified'),
                        style: TextStyle(
                          color: _IaPalette.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
