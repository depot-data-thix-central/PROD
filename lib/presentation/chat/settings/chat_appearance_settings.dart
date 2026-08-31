// lib/presentation/chat/settings/chat_appearance_settings.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/providers/chat/chat_settings_provider.dart';
import 'package:thix_id/presentation/chat/settings/widgets/chat_settings_switch.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const List<double> _kFontSizes = [12.0, 14.0, 16.0, 18.0, 20.0];
const List<String> _kThemes = ['system', 'light', 'dark'];

// ============================================================================
// APPEARANCE SETTINGS PAGE
// ============================================================================

/// Page de configuration de l'apparence.
///
/// Gère : Thème, Taille de police, Style des bulles.
class ChatAppearanceSettings extends ConsumerStatefulWidget {
  const ChatAppearanceSettings({super.key});

  @override
  ConsumerState<ChatAppearanceSettings> createState() => _ChatAppearanceSettingsState();
}

class _ChatAppearanceSettingsState extends ConsumerState<ChatAppearanceSettings> {
  bool _isSaving = false;

  Future<void> _updateSetting<T>(
    T newValue,
    Future<bool> Function(T) updateFn,
    String settingName,
  ) async {
    if (_isSaving) return; // Protection double-tap
    
    setState(() => _isSaving = true);
    HapticFeedback.selectionClick();
    
    debugPrint('[Appearance] 💾 Updating $settingName to: $newValue');

    try {
      final success = await updateFn(newValue);
      
      if (!mounted) return;
      setState(() => _isSaving = false);

      if (!success) {
        _showError(settingName);
      } else {
        debugPrint('[Appearance] ✓ $settingName updated successfully');
      }
    } catch (e) {
      debugPrint('[Appearance] ❌ Error updating $settingName: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        _showError(settingName);
      }
    }
  }

  void _showError(String settingName) {
    final l10n = AppLocalizations.of(context);
    HapticFeedback.lightImpact();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.t('settings_save_error', args: [settingName]),
            ),
          ),
        ]),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _getThemeLabel(String theme, AppLocalizations l10n) {
    switch (theme) {
      case 'light': return l10n.t('appearance_theme_light');
      case 'dark': return l10n.t('appearance_theme_dark');
      default: return l10n.t('appearance_theme_system');
    }
  }

  String _getFontSizeLabel(double size, AppLocalizations l10n) {
    if (size <= 12.0) return l10n.t('appearance_font_xs');
    if (size <= 14.0) return l10n.t('appearance_font_s');
    if (size <= 16.0) return l10n.t('appearance_font_m');
    if (size <= 18.0) return l10n.t('appearance_font_l');
    return l10n.t('appearance_font_xl');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settingsState = ref.watch(chatSettingsProvider);
    final settings = settingsState.settings;
    final isLoading = settingsState.isLoading;

    // Valeurs par défaut sécurisées
    final currentTheme = settings?.theme ?? 'system';
    final currentFontSize = settings?.fontSize ?? 16.0;
    final isRounded = (settings?.bubbleStyle ?? 'rounded') == 'rounded';

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        title: Text(
          l10n.t('appearance_title'),
          style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold),
        ),
        backgroundColor: ThixPolicy.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: Semantics(
          button: true,
          label: l10n.t('common_back'),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
            },
          ),
        ),
      ),
      body: isLoading && settings == null
          ? Center(child: CircularProgressIndicator(color: ThixPolicy.primary))
          : settings == null
              ? Center(
                  child: Text(
                    l10n.t('settings_load_error'),
                    style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMuted),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    // ── Thème ──
                    _buildDropdownTile(
                      l10n: l10n,
                      icon: Icons.palette_rounded,
                      title: l10n.t('appearance_theme'),
                      value: currentTheme,
                      items: _kThemes.map((v) => DropdownMenuItem(
                        value: v,
                        child: Text(_getThemeLabel(v, l10n)),
                      )).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          _updateSetting(
                            val,
                            (v) => ref.read(chatSettingsProvider.notifier).updateSettings(
                              settings.copyWith(theme: v),
                            ),
                            l10n.t('appearance_theme'),
                          );
                        }
                      },
                    ),
                    
                    const Divider(height: 1, color: ThixPolicy.border),

                    // ── Taille de police ──
                    _buildDropdownTile(
                      l10n: l10n,
                      icon: Icons.text_fields_rounded,
                      title: l10n.t('appearance_font_size'),
                      value: currentFontSize,
                      items: _kFontSizes.map((v) => DropdownMenuItem(
                        value: v,
                        child: Text(_getFontSizeLabel(v, l10n)),
                      )).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          _updateSetting(
                            val,
                            (v) => ref.read(chatSettingsProvider.notifier).updateSettings(
                              settings.copyWith(fontSize: v),
                            ),
                            l10n.t('appearance_font_size'),
                          );
                        }
                      },
                    ),

                    const Divider(height: 1, color: ThixPolicy.border),

                    // ── Style des bulles ─
                    Container(
                      color: ThixPolicy.card,
                      child: ChatSettingsSwitch(
                        icon: Icons.chat_bubble_rounded,
                        title: l10n.t('appearance_bubble_style'),
                        subtitle: l10n.t('appearance_bubble_style_desc'),
                        value: isRounded,
                        isEnabled: !_isSaving,
                        onChanged: (val) {
                          _updateSetting(
                            val,
                            (v) => ref.read(chatSettingsProvider.notifier).updateSettings(
                              settings.copyWith(bubbleStyle: v ? 'rounded' : 'square'),
                            ),
                            l10n.t('appearance_bubble_style'),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildDropdownTile({
    required AppLocalizations l10n,
    required IconData icon,
    required String title,
    required dynamic value,
    required List<DropdownMenuItem<dynamic>> items,
    required ValueChanged<dynamic> onChanged,
  }) {
    return Container(
      color: ThixPolicy.card,
      child: ListTile(
        leading: Icon(icon, color: ThixPolicy.primary),
        title: Text(
          title,
          style: ThixPolicy.bodyStyle.copyWith(fontWeight: FontWeight.w600),
        ),
        trailing: DropdownButton<dynamic>(
          value: value,
          underline: const SizedBox(),
          icon: const Icon(Icons.arrow_drop_down_rounded, color: ThixPolicy.textMuted),
          style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMain),
          items: items,
          onChanged: _isSaving ? null : onChanged, // Désactivé pendant sauvegarde
        ),
      ),
    );
  }
}
