// lib/presentation/home/widgets/app_update_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:thix_id/l10n/locale_controller.dart';
import 'package:thix_id/services/app_update_service.dart';

import 'app_update_strings.dart';
import 'home_theme.dart';

class AppUpdateSheet extends StatefulWidget {
  final String languageCode;
  const AppUpdateSheet({super.key, this.languageCode = 'fr'});

  /// Affiche le panneau et enregistre l'heure (rappel max 1 fois / 24 h).
  static Future<void> show(BuildContext context) async {
    await AppUpdateService.instance.markPromptedNow();
    if (!context.mounted) return;

    // Langue lue depuis le contexte appelant (fr / en / sw).
    String code;
    try {
      code = context.read<LocaleController>().locale.languageCode;
    } catch (_) {
      code = Localizations.localeOf(context).languageCode;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AppUpdateSheet(languageCode: code),
    );
  }

  @override
  State<AppUpdateSheet> createState() => _AppUpdateSheetState();
}

class _AppUpdateSheetState extends State<AppUpdateSheet> {
  bool _loading = false;

  Future<void> _onUpdate() async {
    if (_loading) return;
    HapticFeedback.mediumImpact();
    setState(() => _loading = true);
    await AppUpdateService.instance.startUpdate();
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.of(context).pop();
  }

  void _onLater() {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppUpdateStrings.of(widget.languageCode);
    final svc = AppUpdateService.instance;
    final installed = svc.installedVersion.isEmpty
        ? ''
        : '${t.installed} : ${svc.installedVersion}${svc.installedBuild.isEmpty ? '' : ' (${svc.installedBuild})'}';

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: HomeTheme.skyDeep.withOpacity(0.18),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: HomeTheme.line,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 22),
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [HomeTheme.sky, HomeTheme.skyDeep],
                ),
                boxShadow: [
                  BoxShadow(
                    color: HomeTheme.skyDeep.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.system_update_rounded, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 18),
            Text(
              t.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: HomeTheme.ink,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              t.body,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, height: 1.45, color: HomeTheme.inkSoft),
            ),
            if (installed.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: HomeTheme.skySoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: HomeTheme.sky.withOpacity(0.25)),
                ),
                child: Text(
                  installed,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: HomeTheme.skyDeep,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _onUpdate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: HomeTheme.skyDeep,
                  disabledBackgroundColor: HomeTheme.skyDeep.withOpacity(0.6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                      )
                    : Text(
                        t.action,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: _loading ? null : _onLater,
              child: Text(
                t.later,
                style: const TextStyle(
                  color: HomeTheme.inkSoft,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
