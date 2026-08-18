// ============================================================
// 📁 lib/presentation/chat/settings/chat_settings_page.dart
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // IMPORTANT: Ajouté pour avoir l'ID de l'utilisateur

import '../../../providers/chat/chat_settings_provider.dart';
import 'widgets/chat_settings_tile.dart';
import 'widgets/chat_settings_section.dart';

import 'chat_appearance_settings.dart';
import 'chat_privacy_settings.dart';
import 'chat_notification_settings.dart';
import 'chat_data_settings.dart';
import '../profile/chat_profile_page.dart';

class ChatSettingsPage extends StatefulWidget {
  const ChatSettingsPage({super.key});

  @override
  State<ChatSettingsPage> createState() => _ChatSettingsPageState();
}

class _ChatSettingsPageState extends State<ChatSettingsPage> {
  static const Color primaryBlue = Color(0xFF4A8BFF);
  static const Color navyDeep = Color(0xFF0A1F44);
  static const Color ivory = Color(0xFFF3F5FA);
  static const Color danger = Color(0xFFD64545);
  static const Color mutedText = Color(0xFF6B7690);

  // ✅ NOUVEAU : On charge les données dès l'ouverture de la page !
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        context.read<ChatSettingsProvider>().load(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatSettingsProvider>();
    final settings = provider.settings;

    final theme = settings?.theme ?? 'system';
    final wallpaper = settings?.wallpaper ?? 'default';
    final lastSeen = settings?.lastSeenVisibility ?? 'everyone';
    final profilePhoto = settings?.profilePhotoVisibility ?? 'everyone';
    final notifMsgs = settings?.notifMessages ?? true;
    final notifCalls = settings?.notifCalls ?? true;
    final ephemeralDuration = settings?.ephemeralDuration;
    final autoDownload = settings?.autoDownload ?? 'wifi';

    return Scaffold(
      backgroundColor: ivory,
      appBar: AppBar(
        title: const Text('Paramètres du chat', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: navyDeep,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryBlue))
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                ChatSettingsSection(
                  title: 'Apparence',
                  children: [
                    ChatSettingsTile(
                      icon: Icons.palette_rounded,
                      title: 'Thème',
                      subtitle: _getThemeLabel(theme),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatAppearanceSettings())),
                    ),
                    ChatSettingsTile(
                      icon: Icons.brush_rounded,
                      title: 'Fond d\'écran',
                      subtitle: wallpaper == 'default' ? 'Par défaut' : 'Personnalisé',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatAppearanceSettings())),
                    ),
                  ],
                ),
                ChatSettingsSection(
                  title: 'Confidentialité',
                  children: [
                    ChatSettingsTile(
                      icon: Icons.visibility_rounded,
                      title: 'Dernière activité',
                      subtitle: _getVisibilityLabel(lastSeen),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatPrivacySettings())),
                    ),
                    ChatSettingsTile(
                      icon: Icons.image_rounded,
                      title: 'Photo de profil',
                      subtitle: _getVisibilityLabel(profilePhoto),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatPrivacySettings())),
                    ),
                  ],
                ),
                ChatSettingsSection(
                  title: 'Notifications',
                  children: [
                    ChatSettingsTile(
                      icon: Icons.notifications_rounded,
                      title: 'Messages',
                      subtitle: notifMsgs ? 'Activé' : 'Désactivé',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatNotificationSettings())),
                    ),
                    ChatSettingsTile(
                      icon: Icons.phone_rounded,
                      title: 'Appels',
                      subtitle: notifCalls ? 'Activé' : 'Désactivé',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatNotificationSettings())),
                    ),
                  ],
                ),
                ChatSettingsSection(
                  title: 'Messages',
                  children: [
                    ChatSettingsTile(
                      icon: Icons.timer_rounded,
                      title: 'Messages éphémères',
                      subtitle: ephemeralDuration == null ? 'Désactivé' : '${ephemeralDuration}s',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatDataSettings())),
                    ),
                    ChatSettingsTile(
                      icon: Icons.cloud_download_rounded,
                      title: 'Téléchargement auto',
                      subtitle: _getDownloadLabel(autoDownload),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatDataSettings())),
                    ),
                  ],
                ),
                ChatSettingsSection(
                  title: 'Compte',
                  children: [
                    ChatSettingsTile(
                      icon: Icons.person_rounded,
                      title: 'Voir mon profil',
                      onTap: () {
                        if (provider.chatUser?.id != null) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ChatProfilePage(userId: provider.chatUser!.id))); 
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.logout_rounded, color: danger),
                      title: const Text('Se déconnecter', style: TextStyle(color: danger, fontWeight: FontWeight.bold)),
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  String _getThemeLabel(String theme) {
    switch (theme) {
      case 'light': return 'Clair';
      case 'dark': return 'Sombre';
      default: return 'Système';
    }
  }

  String _getVisibilityLabel(String visibility) {
    switch (visibility) {
      case 'everyone': return 'Tout le monde';
      case 'contacts': return 'Mes contacts';
      case 'nobody': return 'Personne';
      default: return 'Tout le monde';
    }
  }

  String _getDownloadLabel(String mode) {
    switch (mode) {
      case 'wifi': return 'Wi-Fi uniquement';
      case 'mobile': return 'Données mobiles';
      default: return 'Jamais';
    }
  }
}
