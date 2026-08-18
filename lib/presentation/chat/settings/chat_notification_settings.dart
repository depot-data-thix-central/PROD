// ============================================================
// 📁 lib/presentation/chat/settings/chat_notification_settings.dart
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/chat/chat_settings_provider.dart';
import 'widgets/chat_settings_switch.dart';

class ChatNotificationSettings extends StatelessWidget {
  const ChatNotificationSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatSettingsProvider>();
    final settings = provider.settings;

    if (settings == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        children: [
          ChatSettingsSwitch(
            title: 'Messages',
            subtitle: 'Notifications pour les nouveaux messages',
            value: settings.notifMessages,
            onChanged: (val) async {
              final newSettings = settings.copyWith(notifMessages: val);
              await provider.updateSettings(newSettings);
            },
          ),
          ChatSettingsSwitch(
            title: 'Appels',
            subtitle: 'Notifications pour les appels entrants',
            value: settings.notifCalls,
            onChanged: (val) async {
              final newSettings = settings.copyWith(notifCalls: val);
              await provider.updateSettings(newSettings);
            },
          ),
          ChatSettingsSwitch(
            title: 'Son',
            subtitle: 'Son de notification',
            value: settings.notifSound,
            onChanged: (val) async {
              final newSettings = settings.copyWith(notifSound: val);
              await provider.updateSettings(newSettings);
            },
          ),
          ChatSettingsSwitch(
            title: 'Vibration',
            subtitle: 'Vibration lors des notifications',
            value: settings.notifVibration,
            onChanged: (val) async {
              final newSettings = settings.copyWith(notifVibration: val);
              await provider.updateSettings(newSettings);
            },
          ),
          ChatSettingsSwitch(
            title: 'Aperçu du message',
            subtitle: 'Afficher le contenu du message dans la notification',
            value: settings.notifPreview,
            onChanged: (val) async {
              final newSettings = settings.copyWith(notifPreview: val);
              await provider.updateSettings(newSettings);
            },
          ),
        ],
      ),
    );
  }
}
