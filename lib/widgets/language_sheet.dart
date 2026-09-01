import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/l10n/locale_controller.dart';

class LanguageSheet extends StatelessWidget {
  const LanguageSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = context.read<LocaleController>();
    final currentCode = context.watch<LocaleController>().locale.languageCode;

    final langs = [
      {'code': 'fr', 'name': 'Français', 'flag': '🇫🇷'},
      {'code': 'en', 'name': 'English', 'flag': '🇬🇧'},
      {'code': 'ar', 'name': 'العربية', 'flag': '🇸🇦'},
      {'code': 'zh', 'name': '中文', 'flag': '🇨🇳'},
      {'code': 'pt', 'name': 'Português', 'flag': '🇵🇹'},
      {'code': 'sw', 'name': 'Kiswahili', 'flag': '🇹🇿'},
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 5, decoration: BoxDecoration(color: Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            // CORRECTION ICI : on utilise t() et pas .commonChooseLang
            child: Text(
              l10n.t('choose_language'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 12),
          ...langs.map((lang) {
            final isActive = currentCode == lang['code'];
            return ListTile(
              leading: Text(lang['flag'] as String, style: const TextStyle(fontSize: 24)),
              title: Text(lang['name'] as String, style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.w500)),
              trailing: isActive ? const Icon(Icons.check_circle, color: Color(0xFFF7B500)) : null,
              onTap: () async {
                await controller.setLocale(Locale(lang['code'] as String));
                if (context.mounted) Navigator.pop(context);
              },
            );
          }),
        ],
      ),
    );
  }
}
