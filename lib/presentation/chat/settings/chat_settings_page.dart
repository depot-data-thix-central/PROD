// lib/presentation/chat/settings/chat_settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';
import 'package:thix_id/presentation/chat/profile/chat_profile_page.dart';
import 'package:thix_id/providers/chat/chat_settings_provider.dart';
import 'package:thix_id/presentation/chat/settings/chat_appearance_settings.dart';
import 'package:thix_id/presentation/chat/settings/chat_data_settings.dart';
import 'package:thix_id/presentation/chat/settings/chat_notification_settings.dart';
import 'package:thix_id/presentation/chat/settings/chat_privacy_settings.dart';
import 'package:thix_id/presentation/chat/settings/widgets/chat_settings_section.dart';
import 'package:thix_id/presentation/chat/settings/widgets/chat_settings_tile.dart';

// ============================================================================
// CHAT SETTINGS PAGE
// ============================================================================

/// Page principale des paramètres du chat.
///
/// Regroupe : Apparence, Confidentialité, Notifications, Messages, Compte.
class ChatSettingsPage extends ConsumerStatefulWidget {
  const ChatSettingsPage({super.key});

  @override
  ConsumerState<ChatSettingsPage> createState() => _ChatSettingsPageState();
}

class _ChatSettingsPageState extends ConsumerState<ChatSettingsPage> {
  @override
  void initState() {
    super.initState();
    // Chargement asynchrone des paramètres au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
    });
  }

  Future<void> _loadSettings() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('[Settings] ⚠️ No user ID found, cannot load settings');
      return;
    }

    debugPrint('[Settings] 🔄 Loading settings for user: $userId');
    try {
      await ref.read(chatSettingsProvider.notifier).load(userId);
      debugPrint('[Settings] ✓ Settings loaded successfully');
    } catch (e) {
      debugPrint('[Settings] ❌ Error loading settings: $e');
    }
  }

  Future<void> _handleLogout() async {
    final l10n = AppLocalizations.of(context);
    HapticFeedback.mediumImpact();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: ThixPolicy.border),
        ),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: ThixPolicy.danger),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.t('settings_logout_title'),
                style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold),
              ),
            ),
          ],
        ),
        content: Text(
          l10n.t('settings_logout_message'),
          style: ThixPolicy.bodyStyle,
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(ctx, false);
            },
            child: Text(l10n.t('common_cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(ctx, true);
            },
            child: Text(l10n.t('settings_logout_confirm')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      debugPrint('[Settings] 🚪 Logging out...');
      await ref.read(authControllerProvider.notifier).signOut();
    } catch (e) {
      debugPrint('[Settings] ❌ Logout error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.t('settings_logout_error')),
            backgroundColor: ThixPolicy.danger,
          ),
        );
      }
    }
  }

  String _getThemeLabel(String theme, AppLocalizations l10n) {
    switch (theme) {
      case 'light': return l10n.t('settings_theme_light');
      case 'dark': return l10n.t('settings_theme_dark');
      default: return l10n.t('settings_theme_system');
    }
  }

  String _getVisibilityLabel(String visibility, AppLocalizations l10n) {
    switch (visibility) {
      case 'everyone': return l10n.t('settings_visibility_everyone');
      case 'contacts': return l10n.t('settings_visibility_contacts');
      case 'nobody': return l10n.t('settings_visibility_nobody');
      default: return l10n.t('settings_visibility_everyone');
    }
  }

  String _getDownloadLabel(String mode, AppLocalizations l10n) {
    switch (mode) {
      case 'wifi': return l10n.t('settings_download_wifi');
      case 'mobile': return l10n.t('settings_download_mobile');
      default: return l10n.t('settings_download_never');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settingsState = ref.watch(chatSettingsProvider);
    final settings = settingsState.settings;
    final isLoading = settingsState.isLoading;
    final chatUser = settingsState.chatUser;

    // Valeurs par défaut sécurisées
    final theme = settings?.theme ?? 'system';
    final wallpaper = settings?.wallpaper ?? 'default';
    final lastSeen = settings?.lastSeenVisibility ?? 'everyone';
    final profilePhoto = settings?.profilePhotoVisibility ?? 'everyone';
    final notifMsgs = settings?.notifMessages ?? true;
    final notifCalls = settings?.notifCalls ?? true;
    final ephemeralDuration = settings?.ephemeralDuration;
    final autoDownload = settings?.autoDownload ?? 'wifi';

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        title: Text(
          l10n.t('settings_title'),
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
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(color: ThixPolicy.primary),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                // ── Apparence ──
                ChatSettingsSection(
                  title: l10n.t('settings_section_appearance'),
                  children: [
                    ChatSettingsTile(
                      icon: Icons.palette_rounded,
                      title: l10n.t('settings_theme'),
                      subtitle: _getThemeLabel(theme, l10n),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ChatAppearanceSettings()),
                        );
                      },
                    ),
                    ChatSettingsTile(
                      icon: Icons.brush_rounded,
                      title: l10n.t('settings_wallpaper'),
                      subtitle: wallpaper == 'default'
                          ? l10n.t('settings_wallpaper_default')
                          : l10n.t('settings_wallpaper_custom'),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ChatAppearanceSettings()),
                        );
                      },
                    ),
                  ],
                ),

                // ── Confidentialité ──
                ChatSettingsSection(
                  title: l10n.t('settings_section_privacy'),
                  children: [
                    ChatSettingsTile(
                      icon: Icons.visibility_rounded,
                      title: l10n.t('settings_last_seen'),
                      subtitle: _getVisibilityLabel(lastSeen, l10n),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ChatPrivacySettings()),
                        );
                      },
                    ),
                    ChatSettingsTile(
                      icon: Icons.image_rounded,
                      title: l10n.t('settings_profile_photo'),
                      subtitle: _getVisibilityLabel(profilePhoto, l10n),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ChatPrivacySettings()),
                        );
                      },
                    ),
                  ],
                ),

                // ── Notifications ──
                ChatSettingsSection(
                  title: l10n.t('settings_section_notifications'),
                  children: [
                    ChatSettingsTile(
                      icon: Icons.notifications_rounded,
                      title: l10n.t('settings_messages'),
                      subtitle: notifMsgs
                          ? l10n.t('common_enabled')
                          : l10n.t('common_disabled'),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ChatNotificationSettings()),
                        );
                      },
                    ),
                    ChatSettingsTile(
                      icon: Icons.phone_rounded,
                      title: l10n.t('settings_calls'),
                      subtitle: notifCalls
                          ? l10n.t('common_enabled')
                          : l10n.t('common_disabled'),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ChatNotificationSettings()),
                        );
                      },
                    ),
                  ],
                ),

                // ── Messages ──
                ChatSettingsSection(
                  title: l10n.t('settings_section_messages'),
                  children: [
                    ChatSettingsTile(
                      icon: Icons.timer_rounded,
                      title: l10n.t('settings_ephemeral'),
                      subtitle: ephemeralDuration == null
                          ? l10n.t('common_disabled')
                          : '${ephemeralDuration}s',
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ChatDataSettings()),
                        );
                      },
                    ),
                    ChatSettingsTile(
                      icon: Icons.cloud_download_rounded,
                      title: l10n.t('settings_auto_download'),
                      subtitle: _getDownloadLabel(autoDownload, l10n),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ChatDataSettings()),
                        );
                      },
                    ),
                  ],
                ),

                // ── Compte ──
                ChatSettingsSection(
                  title: l10n.t('settings_section_account'),
                  children: [
                    ChatSettingsTile(
                      icon: Icons.person_rounded,
                      title: l10n.t('settings_view_profile'),
                      onTap: () {
                        if (chatUser?.id != null) {
                          HapticFeedback.selectionClick();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatProfilePage(userId: chatUser!.id),
                            ),
                          );
                        } else {
                          debugPrint('[Settings] ⚠️ Cannot view profile: user ID is null');
                        }
                      },
                    ),
                    Semantics(
                      button: true,
                      label: l10n.t('settings_logout'),
                      child: ListTile(
                        leading: Icon(Icons.logout_rounded, color: ThixPolicy.danger),
                        title: Text(
                          l10n.t('settings_logout'),
                          style: TextStyle(
                            color: ThixPolicy.danger,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onTap: _handleLogout,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}
