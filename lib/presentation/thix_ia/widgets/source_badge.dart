// lib/presentation/thix_ia/widgets/source_badge.dart
//
// SourceBadge — "Monochrome Glass" (Production Enterprise)
//
// Design : 2 couleurs (blanc #FFF + encre #0B1220)
// Différenciation de type par ICÔNE + OPACITÉ (pas de couleurs).
//
// SÉCURITÉ (AUDIT PRIORITAIRE) :
// ✅ Sanitization XSS : suppression HTML/scripts/control chars
// ✅ Validation type : whitelist (official/banque_mondiale/government/default)
// ✅ MaxLength : source 100 chars
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
const int _kMaxSourceLength = 100;

const Set<String> _kAllowedTypes = {
  'official',
  'banque_mondiale',
  'government',
  'default'
};

// ============================================================================
// SANITIZER (SÉCURITÉ XSS)
// ============================================================================

class _SourceSanitizer {
  _SourceSanitizer._();

  /// Supprime HTML, scripts, control chars, et tronque
  static String sanitizeSource(String? source) {
    if (source == null || source.trim().isEmpty) return '';

    var sanitized = source
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
    if (sanitized.length > _kMaxSourceLength) {
      sanitized = '${sanitized.substring(0, _kMaxSourceLength)}…';
    }

    return sanitized;
  }

  /// Valide et sanitise le type (whitelist stricte)
  static String sanitizeType(String? type) {
    if (type == null) return 'default';
    final lower = type.toLowerCase().trim();
    return _kAllowedTypes.contains(lower) ? lower : 'default';
  }
}

// ============================================================================
// TYPE CONFIG (hiérarchie par opacités + icônes, sans couleur)
// ============================================================================

class _SourceTypeConfig {
  final IconData icon;
  final double iconAlpha;
  final double badgeAlpha;
  final double borderAlpha;
  final double textAlpha;

  const _SourceTypeConfig({
    required this.icon,
    required this.iconAlpha,
    required this.badgeAlpha,
    required this.borderAlpha,
    required this.textAlpha,
  });

  static _SourceTypeConfig from(String type) {
    switch (type) {
      case 'official':
        return const _SourceTypeConfig(
          icon: Icons.verified_user_rounded,
          iconAlpha: 1.00,
          badgeAlpha: 0.15,
          borderAlpha: 0.50,
          textAlpha: 1.00,
        );
      case 'banque_mondiale':
        return const _SourceTypeConfig(
          icon: Icons.public_rounded,
          iconAlpha: 0.95,
          badgeAlpha: 0.13,
          borderAlpha: 0.45,
          textAlpha: 0.95,
        );
      case 'government':
        return const _SourceTypeConfig(
          icon: Icons.account_balance_rounded,
          iconAlpha: 0.90,
          badgeAlpha: 0.12,
          borderAlpha: 0.40,
          textAlpha: 0.90,
        );
      case 'default':
      default:
        return const _SourceTypeConfig(
          icon: Icons.source_rounded,
          iconAlpha: 0.70,
          badgeAlpha: 0.08,
          borderAlpha: 0.25,
          textAlpha: 0.70,
        );
    }
  }
}

// ============================================================================
// WIDGET
// ============================================================================

class SourceBadge extends StatelessWidget {
  const SourceBadge({
    super.key,
    required this.source,
    this.type = 'official',
  });

  final String source;
  final String type;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // ═══ SANITIZATION (SÉCURITÉ XSS) ═══
    final safeSource = _SourceSanitizer.sanitizeSource(source);
    final safeType = _SourceSanitizer.sanitizeType(type);

    // Fallback si source vide après sanitization
    if (safeSource.isEmpty) {
      return const SizedBox.shrink();
    }

    final config = _SourceTypeConfig.from(safeType);

    final typeLabel = safeType == 'official'
        ? l10n.t('source_type_official')
        : safeType == 'banque_mondiale'
            ? l10n.t('source_type_world_bank')
            : safeType == 'government'
                ? l10n.t('source_type_government')
                : l10n.t('source_type_default');

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _kGlassBlur, sigmaY: _kGlassBlur),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _IaPalette.white.withValues(alpha: config.badgeAlpha),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: _IaPalette.white.withValues(alpha: config.borderAlpha),
                width: 1,
              ),
            ),
            child: Semantics(
              label: '${l10n.t("source_aria_label")}: $safeSource ($typeLabel)',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    config.icon,
                    size: 10,
                    color:
                        _IaPalette.white.withValues(alpha: config.iconAlpha),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      safeSource.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            _IaPalette.white.withValues(alpha: config.textAlpha),
                        fontWeight: FontWeight.w800,
                        fontSize: 8,
                        letterSpacing: 0.3,
                      ),
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
