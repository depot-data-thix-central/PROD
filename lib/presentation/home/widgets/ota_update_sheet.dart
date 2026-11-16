//lib/presentation/home/widgets/ota_update_sheet.dart
import 'package:flutter/material.dart';
import 'package:thix_id/services/ota_update_service.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// THIX ID — Sheet « Mise à jour OTA prête → Redémarrer ».
///
/// Complément de AppUpdateSheet (Play Store) :
/// - AppUpdateSheet  : une nouvelle VERSION native est disponible au store.
/// - OtaUpdateSheet  : un PATCH Dart est déjà téléchargé sur l'appareil,
///                     il suffit de redémarrer (aucun téléchargement store).
///
/// Auto-régulé : throttle 24 h via OtaUpdateService.shouldPromptRestart().
/// `force: true` pour un déclenchement manuel depuis les réglages.
/// ═══════════════════════════════════════════════════════════════════════
abstract final class OtaUpdateSheet {
  static Future<void> show(BuildContext context, {bool force = false}) async {
    final svc = OtaUpdateService.instance;
    if (!svc.patchReadyToRestart.value) return;
    if (!force && !await svc.shouldPromptRestart()) return;

    await svc.markRestartPromptedNow();
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _OtaUpdateSheetBody(),
    );
  }
}

class _OtaUpdateSheetBody extends StatefulWidget {
  const _OtaUpdateSheetBody();

  @override
  State<_OtaUpdateSheetBody> createState() => _OtaUpdateSheetBodyState();
}

class _OtaUpdateSheetBodyState extends State<_OtaUpdateSheetBody> {
  bool _busy = false;

  Future<void> _restart(_OtaStrings s) async {
    if (_busy) return;
    setState(() => _busy = true);

    final closed = await OtaUpdateService.instance.restartToApply();
    if (!mounted) return;

    if (!closed) {
      // iOS : pas de fermeture programmée → on guide l'utilisateur.
      setState(() => _busy = false);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.iosRestartHint),
          duration: const Duration(seconds: 6),
        ),
      );
    }
    // Android : SystemNavigator.pop() ferme l'activité ; au prochain
    // lancement, le patch est actif. Rien d'autre à faire.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = _OtaStrings(Localizations.localeOf(context).languageCode);
    final svc = OtaUpdateService.instance;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Poignée de drag
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Icône
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.rocket_launch_rounded,
                size: 30,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            s.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            s.message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // N° de patch en attente (cosmétique)
          ValueListenableBuilder<int?>(
            valueListenable: svc.nextPatchNumber,
            builder: (context, patchNumber, _) {
              if (patchNumber == null) return const SizedBox.shrink();
              return Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    s.patchBadge(patchNumber),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // Rassure : rien à télécharger, pas de données mobiles.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.offline_pin_rounded, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  s.alreadyDownloaded,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Actions
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    foregroundColor: scheme.onSurfaceVariant,
                  ),
                  child: Text(s.later),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _restart(s),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.restart_alt_rounded, size: 20),
                  label: Text(s.restartNow),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Chaînes locales au sheet (fr / en, fallback en pour les autres langues).
/// → Pourra ensuite être fusionné dans vos AppUpdateStrings / l10n existants.
class _OtaStrings {
  const _OtaStrings(this.languageCode);
  final String languageCode;
  bool get _fr => languageCode == 'fr';

  String get title => _fr ? 'Mise à jour prête ✨' : 'Update ready ✨';

  String get message => _fr
      ? 'Une amélioration de THIX ID a été téléchargée. '
          'Redémarre l\'application pour l\'appliquer instantanément.'
      : 'An improvement for THIX ID has been downloaded. '
          'Restart the app to apply it instantly.';

  String patchBadge(int n) => _fr ? 'Patch OTA n° $n' : 'OTA patch #$n';

  String get alreadyDownloaded => _fr
      ? 'Déjà téléchargée — aucune donnée mobile nécessaire'
      : 'Already downloaded — no mobile data needed';

  String get later => _fr ? 'Plus tard' : 'Later';

  String get restartNow => _fr ? 'Redémarrer' : 'Restart now';

  String get iosRestartHint => _fr
      ? 'Ferme complètement l\'application puis relance-la '
          'pour appliquer la mise à jour.'
      : 'Fully close the app and reopen it to apply the update.';
}
