// lib/presentation/chat/settings/chat_data_settings.dart
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
const List<int?> _kEphemeralDurations = [null, 10, 30, 60, 300, 3600];
const List<String> _kAutoDownloadModes = ['wifi', 'mobile', 'never'];

// ============================================================================
// DATA SETTINGS PAGE
// ============================================================================

/// Page de configuration des données et du stockage.
///
/// Gère : Messages éphémères, Téléchargement auto, Cache, Export.
class ChatDataSettings extends ConsumerStatefulWidget {
  const ChatDataSettings({super.key});

  @override
  ConsumerState<ChatDataSettings> createState() => _ChatDataSettingsState();
}

class _ChatDataSettingsState extends ConsumerState<ChatDataSettings> {
  bool _isSaving = false;

  /// Méthode générique pour mettre à jour un paramètre avec gestion d'erreur et UI
  Future<void> _updateSetting<T>(
    T newValue,
    Future<bool> Function(T) updateFn,
    String settingName,
  ) async {
    if (_isSaving) {
      debugPrint('[DataSettings] ⚠️ Save already in progress, ignoring tap');
      return; // Protection double-tap
    }

    setState(() => _isSaving = true);
    HapticFeedback.selectionClick();
    
    debugPrint('[DataSettings] 💾 Updating $settingName to: $newValue');

    try {
      final success = await updateFn(newValue);
      
      if (!mounted) return;
      setState(() => _isSaving = false);

      if (!success) {
        _showError(settingName);
      } else {
        debugPrint('[DataSettings] ✓ $settingName updated successfully');
      }
    } catch (e) {
      debugPrint('[DataSettings] ❌ Error updating $settingName: $e');
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
              // CORRECTION APPLIQUÉE
              l10n.t('settings_save_error').replaceAll('{0}', settingName), 
            ),
          ),
        ]),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }


  String _getEphemeralLabel(int? duration, AppLocalizations l10n) {
    if (duration == null) return l10n.t('data_ephemeral_off');
    if (duration < 60) return '${duration}s';
    if (duration == 3600) return l10n.t('data_ephemeral_1h');
    return '${duration ~/ 60}${l10n.t('data_minutes_short')}';
  }

  String _getDownloadLabel(String mode, AppLocalizations l10n) {
    switch (mode) {
      case 'wifi': return l10n.t('data_download_wifi');
      case 'mobile': return l10n.t('data_download_mobile');
      default: return l10n.t('data_download_never');
    }
  }

  void _handleClearCache() {
    HapticFeedback.mediumImpact();
    debugPrint('[DataSettings] 🧹 Clearing cache...');
    // TODO: Implémenter la logique réelle de vidage de cache
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).t('data_cache_cleared')),
        backgroundColor: ThixPolicy.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleExportData() {
    HapticFeedback.mediumImpact();
    debugPrint('[DataSettings]  Exporting data...');
    // TODO: Implémenter la logique réelle d'export
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).t('data_export_started')),
        backgroundColor: ThixPolicy.primary,
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
    final ephemeralDuration = settings?.ephemeralDuration;
    final ephemeralDefault = settings?.ephemeralDefault ?? false;
    final autoDownload = settings?.autoDownload ?? 'wifi';

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        title: Text(
          l10n.t('data_title'),
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
                // ── Messages éphémères ──
                _buildDropdownTile(
                  l10n: l10n,
                  icon: Icons.timer_outlined,
                  title: l10n.t('data_ephemeral_default'),
                  subtitle: l10n.t('data_ephemeral_default_desc'),
                  value: ephemeralDuration,
                  items: _kEphemeralDurations.map((v) => DropdownMenuItem(
                    value: v,
                    child: Text(_getEphemeralLabel(v, l10n)),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null || ephemeralDuration != null) {
                      _updateSetting(
                        val,
                        (v) => ref.read(chatSettingsProvider.notifier).updateSettings(
                          settings.copyWith(ephemeralDuration: v),
                        ),
                        l10n.t('data_ephemeral_default'),
                      );
                    }
                  },
                ),
                
                const Divider(height: 1, color: ThixPolicy.border),

                // ── Activer éphémère par défaut ──
                Container(
                  color: ThixPolicy.card,
                  child: ChatSettingsSwitch(
                    icon: Icons.auto_delete_rounded,
                    title: l10n.t('data_ephemeral_enable'),
                    subtitle: l10n.t('data_ephemeral_enable_desc'),
                    value: ephemeralDefault,
                    isEnabled: !_isSaving,
                    onChanged: (val) {
                      _updateSetting(
                        val,
                        (v) => ref.read(chatSettingsProvider.notifier).updateSettings(
                          settings.copyWith(ephemeralDefault: v),
                        ),
                        l10n.t('data_ephemeral_enable'),
                      );
                    },
                  ),
                ),

                const Divider(height: 1, color: ThixPolicy.border),

                // ── Téléchargement automatique ──
                _buildDropdownTile(
                  l10n: l10n,
                  icon: Icons.cloud_download_rounded,
                  title: l10n.t('data_auto_download'),
                  subtitle: l10n.t('data_auto_download_desc'),
                  value: autoDownload,
                  items: _kAutoDownloadModes.map((v) => DropdownMenuItem(
                    value: v,
                    child: Text(_getDownloadLabel(v, l10n)),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      _updateSetting(
                        val,
                        (v) => ref.read(chatSettingsProvider.notifier).updateSettings(
                          settings.copyWith(autoDownload: v),
                        ),
                        l10n.t('data_auto_download'),
                      );
                    }
                  },
                ),

                const Divider(height: 1, color: ThixPolicy.border),

                // ── Vider le cache ──
                Semantics(
                  button: true,
                  label: l10n.t('data_clear_cache'),
                  child: ListTile(
                    leading: Icon(Icons.cleaning_services_rounded, color: ThixPolicy.warning),
                    title: Text(
                      l10n.t('data_clear_cache'),
                      style: ThixPolicy.bodyStyle.copyWith(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      l10n.t('data_clear_cache_desc'),
                      style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: ThixPolicy.textMuted),
                    onTap: _handleClearCache,
                  ),
                ),

                const Divider(height: 1, color: ThixPolicy.border),

                // ─ Exporter les conversations ──
                Semantics(
                  button: true,
                  label: l10n.t('data_export'),
                  child: ListTile(
                    leading: Icon(Icons.upload_file_rounded, color: ThixPolicy.success),
                    title: Text(
                      l10n.t('data_export'),
                      style: ThixPolicy.bodyStyle.copyWith(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      l10n.t('data_export_desc'),
                      style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: ThixPolicy.textMuted),
                    onTap: _handleExportData,
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
    String? subtitle,
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
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted),
              )
            : null,
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
