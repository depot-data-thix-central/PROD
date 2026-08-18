// ============================================================
// 📁 lib/presentation/chat/settings/chat_privacy_settings.dart
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/chat/chat_settings_provider.dart';
import 'widgets/chat_settings_switch.dart';

class ChatPrivacySettings extends StatelessWidget {
  const ChatPrivacySettings({super.key});

  static const Color primaryBlue = Color(0xFF4A8BFF);
  static const Color navyDeep = Color(0xFF0A1F44);
  static const Color ivory = Color(0xFFF3F5FA);
  static const Color darkText = Color(0xFF10182B);
  static const Color mutedText = Color(0xFF6B7690);

  void _showError(BuildContext context) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la sauvegarde'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatSettingsProvider>();
    final settings = provider.settings;

    if (provider.isLoading && settings == null) {
      return Scaffold(
        backgroundColor: ivory,
        appBar: AppBar(title: const Text('Confidentialité', style: TextStyle(fontWeight: FontWeight.w800)), backgroundColor: navyDeep, foregroundColor: Colors.white, elevation: 0),
        body: const Center(child: CircularProgressIndicator(color: primaryBlue)),
      );
    }

    if (settings == null) {
      return Scaffold(
        backgroundColor: ivory,
        appBar: AppBar(title: const Text('Confidentialité', style: TextStyle(fontWeight: FontWeight.w800)), backgroundColor: navyDeep, foregroundColor: Colors.white, elevation: 0),
        body: const Center(child: Text('Impossible de charger les réglages', style: TextStyle(color: mutedText))),
      );
    }

    final lastSeen = settings.lastSeenVisibility ?? 'everyone';
    final profilePhoto = settings.profilePhotoVisibility ?? 'everyone';
    final readReceipts = settings.readReceipts ?? true;
    final typingIndicator = settings.typingIndicator ?? true;

    return Scaffold(
      backgroundColor: ivory,
      appBar: AppBar(
        title: const Text('Confidentialité', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: navyDeep,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Container(
            color: Colors.white,
            child: ListTile(
              title: const Text('Dernière activité', style: TextStyle(fontWeight: FontWeight.bold, color: darkText)),
              trailing: DropdownButton<String>(
                value: lastSeen,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'everyone', child: Text('Tout le monde')),
                  DropdownMenuItem(value: 'contacts', child: Text('Mes contacts')),
                  DropdownMenuItem(value: 'nobody', child: Text('Personne')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    provider.updateSettings(settings.copyWith(lastSeenVisibility: val)).then((success) {
                      if (!success) _showError(context);
                    });
                  }
                },
              ),
            ),
          ),
          const Divider(height: 1, color: ivory),
          Container(
            color: Colors.white,
            child: ListTile(
              title: const Text('Photo de profil', style: TextStyle(fontWeight: FontWeight.bold, color: darkText)),
              trailing: DropdownButton<String>(
                value: profilePhoto,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'everyone', child: Text('Tout le monde')),
                  DropdownMenuItem(value: 'contacts', child: Text('Mes contacts')),
                  DropdownMenuItem(value: 'nobody', child: Text('Personne')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    provider.updateSettings(settings.copyWith(profilePhotoVisibility: val)).then((success) {
                      if (!success) _showError(context);
                    });
                  }
                },
              ),
            ),
          ),
          const Divider(height: 1, color: ivory),
          Container(
            color: Colors.white,
            child: ChatSettingsSwitch(
              title: 'Confirmations de lecture',
              subtitle: 'Afficher quand vous lisez un message',
              value: readReceipts,
              onChanged: (val) {
                provider.updateSettings(settings.copyWith(readReceipts: val)).then((success) {
                  if (!success) _showError(context);
                });
              },
            ),
          ),
          const Divider(height: 1, color: ivory),
          Container(
            color: Colors.white,
            child: ChatSettingsSwitch(
              title: 'Indicateur de saisie',
              subtitle: 'Afficher quand vous tapez un message',
              value: typingIndicator,
              onChanged: (val) {
                provider.updateSettings(settings.copyWith(typingIndicator: val)).then((success) {
                  if (!success) _showError(context);
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
