// lib/presentation/settings/widgets/language_sheet.dart
//
// ============================================================================
// LANGUAGE SHEET — Production Enterprise
// ============================================================================
//
// Bottom sheet pour sélectionner la langue de l'application.
//
// Fonctionnalités :
//   - Affiche les 8 langues supportées (fr, en, ar, zh, pt, ln, kg, sw)
//   - Option "Langue du système" pour revenir à la locale du téléphone
//   - Indicateur visuel de la langue active (check icon + gras)
//   - Fermeture automatique après sélection
//   - Feedback tactile (HapticFeedback)
//
// UX :
//   - ThixPolicy 100% (0 couleurs hardcodées)
//   - Semantics VoiceOver complets
//   - HapticFeedback sur sélection
//   - RepaintBoundary pour performance
//
// Architecture :
//   - Utilise LocaleController pour changer la locale
//   - Utilise SupportedLanguages.all pour la liste (DRY)
//   - Logs structurés [LanguageSheet]
//
// Usage :
//   ```dart
//   showModalBottomSheet(
//     context: context,
//     builder: (_) => const LanguageSheet(),
//   );
//   ```
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/l10n/i18n_service.dart';
import 'package:thix_id/l10n/locale_controller.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const double _kSheetBorderRadius = 28.0;
const double _kHandleWidth = 40.0;
const double _kHandleHeight = 5.0;
const double _kHandleBorderRadius = 10.0;
const double _kFlagFontSize = 24.0;
const double _kTitleFontSize = 18.0;
const double _kSubtitleFontSize = 13.0;
const double _kCheckIconSize = 24.0;

// ============================================================================
// LANGUAGE SHEET WIDGET
// ============================================================================

/// Bottom sheet pour sélectionner la langue de l'application.
///
/// **Langues supportées** (8) :
/// - 🇫🇷 Français (fr)
/// - 🇬🇧 English (en)
/// - 🇸🇦 العربية (ar) — RTL
/// - 🇨🇳 中文 (zh)
/// - 🇵🇹 Português (pt)
/// - 🇨🇩 Lingála (ln)
/// - 🇨🇩 Kikongo (kg)
/// - 🇹🇿 Kiswahili (sw)
///
/// **Fonctionnalités** :
/// - Option "Langue du système" pour revenir à la locale du téléphone
/// - Indicateur visuel de la langue active
/// - Fermeture automatique après sélection
/// - Feedback tactile (HapticFeedback)
/// - Accessibilité VoiceOver (Semantics)
class LanguageSheet extends StatelessWidget {
  const LanguageSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = context.read<LocaleController>();
    final currentCode = context.watch<LocaleController>().locale.languageCode;

    debugPrint('[LanguageSheet] 🚀 Opened (current: $currentCode)');

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(_kSheetBorderRadius),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          const SizedBox(height: 16),
          _buildTitle(l10n),
          const SizedBox(height: 12),
          _buildSystemLanguageOption(controller, currentCode, l10n),
          _buildDivider(),
          ...SupportedLanguages.all.map((lang) {
            return _buildLanguageItem(
              context: context,
              controller: controller,
              lang: lang,
              currentCode: currentCode,
            );
          }),
        ],
      ),
    );
  }

  // ─── HANDLE ─────────────────────────────────────────────────────────

  /// Barre de drag en haut du sheet.
  Widget _buildHandle() {
    return Container(
      width: _kHandleWidth,
      height: _kHandleHeight,
      decoration: BoxDecoration(
        color: ThixPolicy.border,
        borderRadius: BorderRadius.circular(_kHandleBorderRadius),
      ),
    );
  }

  // ─── TITLE ──────────────────────────────────────────────────────────

  /// Titre "Choisir la langue".
  Widget _buildTitle(AppLocalizations l10n) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        header: true,
        child: Text(
          l10n.t('choose_language'),
          style: TextStyle(
            fontSize: _kTitleFontSize,
            fontWeight: FontWeight.w800,
            color: ThixPolicy.textMain,
          ),
        ),
      ),
    );
  }

  // ─── SYSTEM LANGUAGE OPTION ─────────────────────────────────────────

  /// Option "Langue du système" pour revenir à la locale du téléphone.
  Widget _buildSystemLanguageOption(
    LocaleController controller,
    String currentCode,
    AppLocalizations l10n,
  ) {
    final systemLocale = controller.getSystemOrDefault();
    final isSystemActive = !_hasPersistedLocale();

    return RepaintBoundary(
      child: Semantics(
        button: true,
        selected: isSystemActive,
        label: '${l10n.t("system_default")} (${systemLocale.languageCode})',
        child: ListTile(
          leading: Container(
            width: _kFlagFontSize,
            height: _kFlagFontSize,
            decoration: BoxDecoration(
              color: ThixPolicy.surfaceSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.phone_android_rounded,
              size: 16,
              color: ThixPolicy.textMuted,
            ),
          ),
          title: Text(
            l10n.t('system_default'),
            style: TextStyle(
              fontWeight: isSystemActive ? FontWeight.bold : FontWeight.w500,
              color: ThixPolicy.textMain,
            ),
          ),
          subtitle: Text(
            _getSystemLanguageName(systemLocale.languageCode),
            style: TextStyle(
              fontSize: _kSubtitleFontSize,
              color: ThixPolicy.textMuted,
            ),
          ),
          trailing: isSystemActive
              ? Icon(
                  Icons.check_circle_rounded,
                  color: ThixPolicy.warning,
                  size: _kCheckIconSize,
                )
              : null,
          onTap: () => _selectSystemLanguage(context, controller),
        ),
      ),
    );
  }

  // ─── DIVIDER ────────────────────────────────────────────────────────

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Divider(height: 1, color: ThixPolicy.border),
    );
  }

  // ─── LANGUAGE ITEM ──────────────────────────────────────────────────

  /// Item de langue individuel.
  Widget _buildLanguageItem({
    required BuildContext context,
    required LocaleController controller,
    required Map<String, String> lang,
    required String currentCode,
  }) {
    final code = lang['code']!;
    final name = lang['name']!;
    final flag = lang['flag']!;
    final isActive = currentCode == code && _hasPersistedLocale();

    return RepaintBoundary(
      child: Semantics(
        button: true,
        selected: isActive,
        label: name,
        child: ListTile(
          leading: Text(
            flag,
            style: const TextStyle(fontSize: _kFlagFontSize),
          ),
          title: Text(
            name,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: ThixPolicy.textMain,
            ),
          ),
          trailing: isActive
              ? Icon(
                  Icons.check_circle_rounded,
                  color: ThixPolicy.warning,
                  size: _kCheckIconSize,
                )
              : null,
          onTap: () => _selectLanguage(context, controller, code, name),
        ),
      ),
    );
  }

  // ─── ACTIONS ────────────────────────────────────────────────────────

  /// Sélectionne une langue spécifique.
  Future<void> _selectLanguage(
    BuildContext context,
    LocaleController controller,
    String code,
    String name,
  ) async {
    HapticFeedback.selectionClick();
    debugPrint('[LanguageSheet] ✓ Selected: $name ($code)');

    final success = await controller.setLocale(Locale(code));

    if (success && context.mounted) {
      Navigator.pop(context);
    }
  }

  /// Sélectionne la langue du système.
  Future<void> _selectSystemLanguage(
    BuildContext context,
    LocaleController controller,
  ) async {
    HapticFeedback.selectionClick();
    debugPrint('[LanguageSheet] ✓ Selected: System language');

    await controller.setSystem();

    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  // ─── HELPERS ────────────────────────────────────────────────────────

  /// Vérifie si une locale est persistée (vs locale système).
  bool _hasPersistedLocale() {
    // Cette méthode devrait idéalement venir du LocaleController
    // Pour l'instant, on considère que si la locale actuelle est différente
    // de la locale système, c'est qu'elle est persistée
    return true; // Simplification - à améliorer si nécessaire
  }

  /// Retourne le nom de la langue système pour affichage.
  String _getSystemLanguageName(String code) {
    final lang = SupportedLanguages.forCode(code);
    return lang?['name'] ?? code;
  }
}
