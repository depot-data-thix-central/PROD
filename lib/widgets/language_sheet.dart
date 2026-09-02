// lib/presentation/settings/widgets/language_sheet.dart
//
// ============================================================================
// LANGUAGE SHEET — Production Enterprise
// ============================================================================
//
// Bottom sheet pour sélectionner la langue de l'application.
//
// Langues supportées (8) — synchronisées avec locale_controller.dart :
//   🇫🇷 Français (fr)
//   🇬🇧 English (en)
//   🇪🇸 Español (es)
//   🇵🇹 Português (pt)
//   🇨🇩 Lingála (ln)
//   🇨🇩 Kiswahili (sw)
//   🇨🇩 Kikongo (kg)
//   🇨🇩 Tshiluba (lu)
//
// Fonctionnalités :
//   - Option "Langue du système" pour revenir à la locale du téléphone
//   - Indicateur visuel de la langue active (check icon + gras)
//   - Fermeture automatique après sélection
//   - Feedback tactile (HapticFeedback) différencié
//   - Gestion d'erreur avec snackbar
//   - SafeArea + scroll pour petits écrans
//
// Architecture :
//   - ConsumerWidget (Riverpod, cohérent avec le reste de l'app)
//   - Utilise kSupportedLanguages pour la liste (DRY, source unique)
//   - Logs structurés [LanguageSheet]
//
// Usage :
//   ```dart
//   showModalBottomSheet(
//     context: context,
//     isScrollControlled: true,
//     backgroundColor: Colors.transparent,
//     builder: (_) => const LanguageSheet(),
//   );
//   ```
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
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
const double _kItemVerticalPadding = 12.0;

// ============================================================================
// LANGUAGE SHEET WIDGET
// ============================================================================

/// Bottom sheet pour sélectionner la langue de l'application.
class LanguageSheet extends ConsumerWidget {
  const LanguageSheet({super.key});

  /// Méthode utilitaire pour afficher le sheet avec les bons paramètres.
  static Future<T?> show<T>(BuildContext context) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LanguageSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.watch(localeControllerProvider);
    final currentCode = controller.locale.languageCode;
    final useSystem = controller.useSystem;

    debugPrint('[LanguageSheet] 🚀 Opened (current: $currentCode, '
        'system: $useSystem)');

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(_kSheetBorderRadius),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHandle(),
              const SizedBox(height: 16),
              _buildTitle(l10n),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSystemLanguageOption(
                        context,
                        ref,
                        controller,
                        currentCode,
                        useSystem,
                        l10n,
                      ),
                      _buildDivider(),
                      ...kSupportedLanguages.values.map((info) {
                        return _buildLanguageItem(
                          context: context,
                          ref: ref,
                          controller: controller,
                          info: info,
                          currentCode: currentCode,
                          useSystem: useSystem,
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── HANDLE ─────────────────────────────────────────────────────────

  Widget _buildHandle() {
    return Semantics(
      label: 'Drag handle',
      child: Container(
        width: _kHandleWidth,
        height: _kHandleHeight,
        decoration: BoxDecoration(
          color: ThixPolicy.border,
          borderRadius: BorderRadius.circular(_kHandleBorderRadius),
        ),
      ),
    );
  }

  // ─── TITLE ──────────────────────────────────────────────────────────

  Widget _buildTitle(AppLocalizations l10n) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        header: true,
        child: Text(
          l10n.t('settings_choose_language'),
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

  Widget _buildSystemLanguageOption(
    BuildContext context,
    WidgetRef ref,
    LocaleController controller,
    String currentCode,
    bool useSystem,
    AppLocalizations l10n,
  ) {
    final systemLocale = controller.getSystemOrDefault();
    final systemInfo = kSupportedLanguages[systemLocale.languageCode];
    final systemName = systemInfo?.nativeName ?? systemLocale.languageCode;
    final isSystemActive = useSystem;

    return RepaintBoundary(
      child: Semantics(
        button: true,
        selected: isSystemActive,
        label: '${l10n.t("settings_system_default")} ($systemName)',
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(
            vertical: _kItemVerticalPadding / 2,
          ),
          leading: Container(
            width: _kFlagFontSize + 8,
            height: _kFlagFontSize + 8,
            decoration: BoxDecoration(
              color: ThixPolicy.surfaceSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.phone_android_rounded,
              size: 18,
              color: isSystemActive
                  ? ThixPolicy.primary
                  : ThixPolicy.textMuted,
            ),
          ),
          title: Text(
            l10n.t('settings_system_default'),
            style: TextStyle(
              fontWeight: isSystemActive ? FontWeight.bold : FontWeight.w500,
              color: ThixPolicy.textMain,
            ),
          ),
          subtitle: Text(
            systemName,
            style: TextStyle(
              fontSize: _kSubtitleFontSize,
              color: ThixPolicy.textMuted,
            ),
          ),
          trailing: isSystemActive
              ? Icon(
                  Icons.check_circle_rounded,
                  color: ThixPolicy.success,
                  size: _kCheckIconSize,
                )
              : null,
          onTap: () => _selectSystemLanguage(context, ref),
        ),
      ),
    );
  }

  // ─── DIVIDER ────────────────────────────────────────────────────────

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Divider(height: 1),
    );
  }

  // ─── LANGUAGE ITEM ──────────────────────────────────────────────────

  Widget _buildLanguageItem({
    required BuildContext context,
    required WidgetRef ref,
    required LocaleController controller,
    required LanguageInfo info,
    required String currentCode,
    required bool useSystem,
  }) {
    // Active = même code ET pas en mode système
    final isActive = !useSystem && currentCode == info.code;

    return RepaintBoundary(
      child: Semantics(
        button: true,
        selected: isActive,
        label: info.nativeName,
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(
            vertical: _kItemVerticalPadding / 2,
          ),
          leading: SizedBox(
            width: _kFlagFontSize + 8,
            height: _kFlagFontSize + 8,
            child: Center(
              child: Text(
                info.flag ?? '🌐',
                style: const TextStyle(fontSize: _kFlagFontSize),
              ),
            ),
          ),
          title: Text(
            info.nativeName,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: ThixPolicy.textMain,
            ),
          ),
          subtitle: info.nativeName != info.englishName
              ? Text(
                  info.englishName,
                  style: TextStyle(
                    fontSize: _kSubtitleFontSize,
                    color: ThixPolicy.textMuted,
                  ),
                )
              : null,
          trailing: isActive
              ? Icon(
                  Icons.check_circle_rounded,
                  color: ThixPolicy.success,
                  size: _kCheckIconSize,
                )
              : null,
          onTap: () => _selectLanguage(context, ref, info.code, info.nativeName),
        ),
      ),
    );
  }

  // ─── ACTIONS ────────────────────────────────────────────────────────

  Future<void> _selectLanguage(
    BuildContext context,
    WidgetRef ref,
    String code,
    String name,
  ) async {
    final controller = ref.read(localeControllerProvider);
    final currentCode = controller.locale.languageCode;
    final useSystem = controller.useSystem;

    // Déjà active ?
    if (!useSystem && currentCode == code) {
      debugPrint('[LanguageSheet] ℹ️ Already active: $name ($code)');
      HapticFeedback.lightImpact();
      if (context.mounted) Navigator.pop(context);
      return;
    }

    HapticFeedback.selectionClick();
    debugPrint('[LanguageSheet] ✓ Selected: $name ($code)');

    final success = await controller.setLocale(Locale(code));

    if (!success && context.mounted) {
      _showError(
        context,
        AppLocalizations.of(context).t('settings_language_change_failed'),
      );
      return;
    }

    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _selectSystemLanguage(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final controller = ref.read(localeControllerProvider);

    if (controller.useSystem) {
      debugPrint('[LanguageSheet] ℹ️ Already using system language');
      HapticFeedback.lightImpact();
      if (context.mounted) Navigator.pop(context);
      return;
    }

    HapticFeedback.selectionClick();
    debugPrint('[LanguageSheet] ✓ Selected: System language');

    final success = await controller.setSystem();

    if (!success && context.mounted) {
      _showError(
        context,
        AppLocalizations.of(context).t('settings_language_change_failed'),
      );
      return;
    }

    if (context.mounted) Navigator.pop(context);
  }

  // ─── HELPERS ────────────────────────────────────────────────────────

  void _showError(BuildContext context, String message) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
