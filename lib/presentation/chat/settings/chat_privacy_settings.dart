// lib/presentation/chat/settings/chat_privacy_settings.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/chat/providers/chat_settings_provider.dart';
import 'package:thix_id/presentation/chat/settings/widgets/chat_settings_switch.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const List<String> _kVisibilityOptions = ['everyone', 'contacts', 'nobody'];

// ============================================================================
// PRIVACY SETTINGS PAGE
// ============================================================================

/// Page de configuration de la confidentialité.
///
/// Gère : Dernière activité, Photo de profil, Confirmations de lecture, Indicateur de saisie.
class ChatPrivacySettings extends ConsumerStatefulWidget {
  const ChatPrivacySettings({super.key});

  @override
  ConsumerState<ChatPrivacySettings> createState() => _ChatPrivacySettingsState();
}

class _ChatPrivacySettingsState extends ConsumerState<ChatPrivacySettings> {
  bool _isSaving = false;

  Future<void> _updateSetting<T>(
    T newValue,
    Future<bool> Function(T) updateFn,
    String settingName,
  ) async {
    if (_isSaving) return; // Protection double-tap
    
    setState(() => _isSaving = true);
    HapticFeedback.selectionClick();
    
    debugPrint('[Privacy] 💾 Updating $settingName to: $newValue');

    try {
      final success = await updateFn(newValue);
      
      if (!mounted) return;
      setState(() => _isSaving = false);

      if (!success) {
        _showError(settingName);
      } else {
        debugPrint('[Privacy] ✓ $settingName updated successfully');
        // Optionnel : SnackBar de succès discret
      }
    } catch (e) {
      debugPrint('[Privacy] ❌ Error updating $settingName: $e');
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

  String _getVisibilityLabel(String value, AppLocalizations l10n) {
    switch (value) {
      case 'everyone': return l10n.t('settings_visibility_everyone');
      case 'contacts': return l10n.t('settings_visibility_contacts');
      case 'nobody': return l10n.t('settings_visibility_nobody');
      default: return l10n.t('settings_visibility_everyone');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settingsState = ref.watch(chatSettingsProvider);
    final settings = settingsState.settings;
    final isLoading = settingsState.isLoading;

    // Valeurs par défaut sécurisées
    final lastSeen = settings?.lastSeenVisibility ?? 'everyone';
    final profilePhoto = settings?.profilePhotoVisibility ?? 'everyone';
    final readReceipts = settings?.readReceipts ?? true;
    final typingIndicator = settings?.typingIndicator ?? true;

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        title: Text(
          l10n.t('settings_privacy_title'),
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
                    // ── Dernière activité ──
                    _buildDropdownTile(
                      l10n: l10n,
                      icon: Icons.visibility_rounded,
                      title: l10n.t('settings_last_seen'),
                      value: lastSeen,
                      items: _kVisibilityOptions.map((v) => DropdownMenuItem(
                        value: v,
                        child: Text(_getVisibilityLabel(v, l10n)),
                      )).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          _updateSetting(
                            val,
                            (v) => ref.read(chatSettingsProvider.notifier).updateSettings(
                              settings.copyWith(lastSeenVisibility: v),
                            ),
                            l10n.t('settings_last_seen'),
                          );
                        }
                      },
                    ),
                    
                    const Divider(height: 1, color: ThixPolicy.border),

                    // ── Photo de profil ──
                    _buildDropdownTile(
                      l10n: l10n,
                      icon: Icons.image_rounded,
                      title: l10n.t('settings_profile_photo'),
                      value: profilePhoto,
                      items: _kVisibilityOptions.map((v) => DropdownMenuItem(
                        value: v,
                        child: Text(_getVisibilityLabel(v, l10n)),
                      )).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          _updateSetting(
                            val,
                            (v) => ref.read(chatSettingsProvider.notifier).updateSettings(
                              settings.copyWith(profilePhotoVisibility: v),
                            ),
                            l10n.t('settings_profile_photo'),
                          );
                        }
                      },
                    ),

                    const Divider(height: 1, color: ThixPolicy.border),

                    // ── Confirmations de lecture ──
                    Container(
                      color: ThixPolicy.card,
                      child: ChatSettingsSwitch(
                        icon: Icons.check_circle_outline_rounded,
                        title: l10n.t('settings_read_receipts'),
                        subtitle: l10n.t('settings_read_receipts_desc'),
                        value: readReceipts,
                        isEnabled: !_isSaving,
                        onChanged: (val) {
                          _updateSetting(
                            val,
                            (v) => ref.read(chatSettingsProvider.notifier).updateSettings(
                              settings.copyWith(readReceipts: v),
                            ),
                            l10n.t('settings_read_receipts'),
                          );
                        },
                      ),
                    ),

                    const Divider(height: 1, color: ThixPolicy.border),

                    // ── Indicateur de saisie ──
                    Container(
                      color: ThixPolicy.card,
                      child: ChatSettingsSwitch(
                        icon: Icons.edit_note_rounded,
                        title: l10n.t('settings_typing_indicator'),
                        subtitle: l10n.t('settings_typing_indicator_desc'),
                        value: typingIndicator,
                        isEnabled: !_isSaving,
                        onChanged: (val) {
                          _updateSetting(
                            val,
                            (v) => ref.read(chatSettingsProvider.notifier).updateSettings(
                              settings.copyWith(typingIndicator: v),
                            ),
                            l10n.t('settings_typing_indicator'),
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
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      color: ThixPolicy.card,
      child: ListTile(
        leading: Icon(icon, color: ThixPolicy.primary),
        title: Text(
          title,
          style: ThixPolicy.bodyStyle.copyWith(fontWeight: FontWeight.w600),
        ),
        trailing: DropdownButton<String>(
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
