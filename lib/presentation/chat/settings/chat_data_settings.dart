// ============================================================
// 📁 lib/presentation/chat/settings/chat_data_settings.dart
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/chat/chat_settings_provider.dart';
import 'widgets/chat_settings_switch.dart';

class ChatDataSettings extends StatelessWidget {
  const ChatDataSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatSettingsProvider>();
    final settings = provider.settings;

    if (settings == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('Données du chat')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Messages éphémères par défaut'),
            subtitle: const Text('Délai d\'auto-destruction des nouveaux messages'),
            trailing: DropdownButton<int?>(
              value: settings.ephemeralDuration,
              items: const [
                DropdownMenuItem(value: null, child: Text('Désactivé')),
                DropdownMenuItem(value: 10, child: Text('10 secondes')),
                DropdownMenuItem(value: 30, child: Text('30 secondes')),
                DropdownMenuItem(value: 60, child: Text('1 minute')),
                DropdownMenuItem(value: 300, child: Text('5 minutes')),
                DropdownMenuItem(value: 3600, child: Text('1 heure')),
              ],
              onChanged: (val) async {
                final newSettings = settings.copyWith(ephemeralDuration: val);
                await provider.updateSettings(newSettings);
              },
            ),
          ),
          ChatSettingsSwitch(
            title: 'Éphémère par défaut',
            subtitle: 'Activer l\'auto-destruction pour tous les nouveaux messages',
            value: settings.ephemeralDefault,
            onChanged: (val) async {
              final newSettings = settings.copyWith(ephemeralDefault: val);
              await provider.updateSettings(newSettings);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cloud_download_rounded, color: Colors.blue),
            title: const Text('Téléchargement automatique'),
            trailing: DropdownButton<String>(
              value: settings.autoDownload,
              items: const [
                DropdownMenuItem(value: 'wifi', child: Text('Wi-Fi uniquement')),
                DropdownMenuItem(value: 'mobile', child: Text('Données mobiles')),
                DropdownMenuItem(value: 'never', child: Text('Jamais')),
              ],
              onChanged: (val) async {
                if (val != null) {
                  final newSettings = settings.copyWith(autoDownload: val);
                  await provider.updateSettings(newSettings);
                }
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cleaning_services_rounded, color: Colors.orange),
            title: const Text('Vider le cache'),
            subtitle: const Text('Supprimer les fichiers temporaires'),
            onTap: () {
              // Action de vidage du cache
            },
          ),
          ListTile(
            leading: const Icon(Icons.upload_file_rounded, color: Colors.green),
            title: const Text('Exporter les conversations'),
            subtitle: const Text('Exporter toutes vos conversations au format JSON'),
            onTap: () {
              // Action d'export
            },
          ),
        ],
      ),
    );
  }
}
