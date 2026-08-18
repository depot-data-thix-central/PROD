// ============================================================
// 📁 lib/presentation/chat/settings/chat_appearance_settings.dart
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/chat/chat_settings_provider.dart';
import 'widgets/chat_settings_switch.dart';

class ChatAppearanceSettings extends StatelessWidget {
  const ChatAppearanceSettings({super.key});

  static const Color primaryBlue = Color(0xFF4A8BFF);
  static const Color navyDeep = Color(0xFF0A1F44);
  static const Color ivory = Color(0xFFF3F5FA);
  static const Color darkText = Color(0xFF10182B);
  static const Color mutedText = Color(0xFF6B7690);

  // Fonction pour afficher l'erreur
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
        appBar: AppBar(title: const Text('Apparence', style: TextStyle(fontWeight: FontWeight.w800)), backgroundColor: navyDeep, foregroundColor: Colors.white, elevation: 0),
        body: const Center(child: CircularProgressIndicator(color: primaryBlue)),
      );
    }

    if (settings == null) {
      return Scaffold(
        backgroundColor: ivory,
        appBar: AppBar(title: const Text('Apparence', style: TextStyle(fontWeight: FontWeight.w800)), backgroundColor: navyDeep, foregroundColor: Colors.white, elevation: 0),
        body: const Center(child: Text('Impossible de charger les réglages', style: TextStyle(color: mutedText))),
      );
    }

    final currentTheme = settings.theme ?? 'system';
    final currentFontSize = settings.fontSize ?? 16.0;
    final isRounded = (settings.bubbleStyle ?? 'rounded') == 'rounded';

    return Scaffold(
      backgroundColor: ivory,
      appBar: AppBar(
        title: const Text('Apparence', style: TextStyle(fontWeight: FontWeight.w800)),
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
              title: const Text('Thème', style: TextStyle(fontWeight: FontWeight.bold, color: darkText)),
              trailing: DropdownButton<String>(
                value: currentTheme,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'light', child: Text('Clair')),
                  DropdownMenuItem(value: 'dark', child: Text('Sombre')),
                  DropdownMenuItem(value: 'system', child: Text('Système')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    provider.updateSettings(settings.copyWith(theme: val)).then((success) {
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
              title: const Text('Taille de police', style: TextStyle(fontWeight: FontWeight.bold, color: darkText)),
              trailing: DropdownButton<double>(
                value: currentFontSize,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 12.0, child: Text('Très petite')),
                  DropdownMenuItem(value: 14.0, child: Text('Petite')),
                  DropdownMenuItem(value: 16.0, child: Text('Normale')),
                  DropdownMenuItem(value: 18.0, child: Text('Grande')),
                  DropdownMenuItem(value: 20.0, child: Text('Très grande')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    provider.updateSettings(settings.copyWith(fontSize: val)).then((success) {
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
              title: 'Style des bulles',
              subtitle: 'Arrondies ou carrées',
              value: isRounded,
              onChanged: (val) {
                provider.updateSettings(settings.copyWith(bubbleStyle: val ? 'rounded' : 'square')).then((success) {
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
