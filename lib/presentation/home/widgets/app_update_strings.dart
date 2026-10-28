// lib/presentation/home/widgets/app_update_strings.dart

/// Textes du panneau / indicateur de mise à jour : FR, EN, SW.
class AppUpdateStrings {
  final String hintTag;
  final String hintAction;
  final String title;
  final String body;
  final String action;
  final String later;
  final String installed;

  const AppUpdateStrings({
    required this.hintTag,
    required this.hintAction,
    required this.title,
    required this.body,
    required this.action,
    required this.later,
    required this.installed,
  });

  static const AppUpdateStrings _fr = AppUpdateStrings(
    hintTag: 'Update',
    hintAction: 'Mettre à jour',
    title: 'Mise à jour disponible',
    body: 'Une nouvelle version de Thix Hub est disponible sur le Play Store. '
        'Mettez à jour pour profiter des dernières améliorations et fonctionnalités.',
    action: 'Mettre à jour',
    later: 'Me le rappeler plus tard',
    installed: 'Version installée',
  );

  static const AppUpdateStrings _en = AppUpdateStrings(
    hintTag: 'Update',
    hintAction: 'Update now',
    title: 'Update available',
    body: 'A new version of Thix Hub is available on the Play Store. '
        'Update to enjoy the latest improvements and features.',
    action: 'Update',
    later: 'Remind me later',
    installed: 'Installed version',
  );

  static const AppUpdateStrings _sw = AppUpdateStrings(
    hintTag: 'Update',
    hintAction: 'Sasisha',
    title: 'Toleo jipya linapatikana',
    body: 'Toleo jipya la Thix Hub linapatikana kwenye Play Store. '
        'Sasisha ili ufurahie maboresho na vipengele vipya zaidi.',
    action: 'Sasisha',
    later: 'Nikumbushe baadaye',
    installed: 'Toleo lililosakinishwa',
  );

  /// [languageCode] : 'fr' | 'en' | 'sw' (autre → français).
  static AppUpdateStrings of(String languageCode) {
    switch (languageCode.toLowerCase()) {
      case 'en':
        return _en;
      case 'sw':
        return _sw;
      default:
        return _fr;
    }
  }
}
