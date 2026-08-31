// lib/presentation/chat/settings/chat_notification_settings.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/providers/chat/chat_settings_provider.dart';
import 'package:thix_id/presentation/chat/settings/widgets/chat_settings_switch.dart';

// ============================================================================
// NOTIFICATION SETTINGS PAGE
// ============================================================================

/// Page de configuration des notifications.
///
/// Gère : Messages, Appels, Son, Vibration, Aperçu.
class ChatNotificationSettings extends ConsumerStatefulWidget {
  const ChatNotificationSettings({super.key});

  @override
  ConsumerState<ChatNotificationSettings> createState() => _ChatNotificationSettingsState();
}

class _ChatNotificationSettingsState extends ConsumerState<ChatNotificationSettings> {
  bool _isSaving = false;

  /// Méthode générique pour mettre à jour un paramètre avec gestion d'erreur et UI
  Future<void> _updateSetting<T>(
    T newValue,
    Future<bool> Function(T) updateFn,
    String settingName,
  ) async {
    if (_isSaving) {
      debugPrint('[Notifications] ⚠️ Save already in progress, ignoring tap');
      return; // Protection double-tap
    }

    setState(() => _isSaving = true);
    HapticFeedback.selectionClick();
    
    debugPrint('[Notifications] 💾 Updating $settingName to: $newValue');

    try {
      final success = await updateFn(newValue);
      
      if (!mounted) return;
      setState(() => _isSaving = false);

      if (!success) {
        _showError(settingName);
      } else {
        debugPrint('[Notifications] ✓ $settingName updated successfully');
      }
    } catch (e) {
      debugPrint('[Notifications] ❌ Error updating $settingName: $e');
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settingsState = ref.watch(chatSettingsProvider);
    final settings = settingsState.settings;

    // Valeurs par défaut sécurisées
    final notifMessages = settings?.notifMessages ?? true;
    final notifCalls = settings?.notifCalls ?? true;
    final notifSound = settings?.notifSound ?? true;
    final notifVibration = settings?.notifVibration ?? true;
    final notifPreview = settings?.notifPreview ?? true;

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        title: Text(
          l10n.t('settings_notifications_title'),
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
      body: settings == null
          ? Center(
              child: Text(
                l10n.t('settings_load_error'),
                style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMuted),
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // ── Messages ─
                Container(
                  color: ThixPolicy.card,
                  child: ChatSettingsSwitch(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: l10n.t('settings_notif_messages'),
                    subtitle: l10n.t('settings_notif_messages_desc'),
                    value: notifMessages,
                    isEnabled: !_isSaving,
                    onChanged: (val) {
                      _updateSetting(
                        val,
                        (v) => ref.read(chatSettingsProvider.notifier).updateSettings(
                          settings.copyWith(notifMessages: v),
                        ),
                        l10n.t('settings_notif_messages'),
                      );
                    },
                  ),
                ),
                
                const Divider(height: 1, color: ThixPolicy.border),

                // ── Appels ──
                Container(
                  color: ThixPolicy.card,
                  child: ChatSettingsSwitch(
                    icon: Icons.phone_outlined,
                    title: l10n.t('settings_notif_calls'),
                    subtitle: l10n.t('settings_notif_calls_desc'),
                    value: notifCalls,
                    isEnabled: !_isSaving,
                    onChanged: (val) {
                      _updateSetting(
                        val,
                        (v) => ref.read(chatSettingsProvider.notifier).updateSettings(
                          settings.copyWith(notifCalls: v),
                        ),
                        l10n.t('settings_notif_calls'),
                      );
                    },
                  ),
                ),

                const Divider(height: 1, color: ThixPolicy.border),

                // ── Son ──
                Container(
                  color: ThixPolicy.card,
                  child: ChatSettingsSwitch(
                    icon: Icons.volume_up_outlined,
                    title: l10n.t('settings_notif_sound'),
                    subtitle: l10n.t('settings_notif_sound_desc'),
                    value: notifSound,
                    isEnabled: !_isSaving,
                    onChanged: (val) {
                      _updateSetting(
                        val,
                        (v) => ref.read(chatSettingsProvider.notifier).updateSettings(
                          settings.copyWith(notifSound: v),
                        ),
                        l10n.t('settings_notif_sound'),
                      );
                    },
                  ),
                ),

                const Divider(height: 1, color: ThixPolicy.border),

                // ── Vibration ──
                Container(
                  color: ThixPolicy.card,
                  child: ChatSettingsSwitch(
                    icon: Icons.vibration_rounded,
                    title: l10n.t('settings_notif_vibration'),
                    subtitle: l10n.t('settings_notif_vibration_desc'),
                    value: notifVibration,
                    isEnabled: !_isSaving,
                    onChanged: (val) {
                      _updateSetting(
                        val,
                        (v) => ref.read(chatSettingsProvider.notifier).updateSettings(
                          settings.copyWith(notifVibration: v),
                        ),
                        l10n.t('settings_notif_vibration'),
                      );
                    },
                  ),
                ),

                const Divider(height: 1, color: ThixPolicy.border),

                // ── Aperçu ──
                Container(
                  color: ThixPolicy.card,
                  child: ChatSettingsSwitch(
                    icon: Icons.visibility_outlined,
                    title: l10n.t('settings_notif_preview'),
                    subtitle: l10n.t('settings_notif_preview_desc'),
                    value: notifPreview,
                    isEnabled: !_isSaving,
                    onChanged: (val) {
                      _updateSetting(
                        val,
                        (v) => ref.read(chatSettingsProvider.notifier).updateSettings(
                          settings.copyWith(notifPreview: v),
                        ),
                        l10n.t('settings_notif_preview'),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
