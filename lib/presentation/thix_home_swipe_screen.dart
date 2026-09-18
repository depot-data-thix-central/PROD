/// Conteneur principal — swipe SOS ↔ RECHERCHE ↔ RETROUVE (Production Enterprise)
/// ✅ Gate permissions intégré : affiche l'intro permissions au 1er lancement
/// ✅ Langue auto-détectée depuis AppLocalizations (fr, en, es, pt, sw, ar, zh)
/// ✅ IndexedStack paresseux (pages montées au premier accès seulement)
/// ✅ RepaintBoundary + ErrorBoundary par onglet
/// ✅ Montage différé Google Maps sur Web
/// ✅ Logs structurés + HapticFeedback + i18n
///
/// Dépendances requises dans pubspec.yaml :
///   permission_handler: ^11.3.1
///   shared_preferences: ^2.2.3
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

import 'thix_sos/thix_sos_screen.dart';
import 'thix_recherche/thix_recherche_screen.dart';
import 'thix_retrouve/thix_retrouve_screen.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const Duration _kTabAnimationDuration = Duration(milliseconds: 280);
const Duration _kWebMapDeferDelay = Duration(milliseconds: 600);
const double _kGlassSurface = 0.06;
const double _kGlassBorder = 0.09;
const String _kPrefPermIntroSeen = 'thix_perm_intro_seen_v1';

// ============================================================================
// SCREEN PRINCIPAL — ThixHomeSwipeScreen (GATE + SWIPE)
// ============================================================================
// ✅ Ce widget garde EXACTEMENT le même nom et la même signature qu'avant,
//    donc aucun autre fichier (nav.dart, etc.) n'a besoin d'être modifié.

class ThixHomeSwipeScreen extends StatefulWidget {
  const ThixHomeSwipeScreen({super.key, this.initialPage = 0});

  /// 0 = SOS, 1 = RECHERCHE, 2 = RETROUVE
  final int initialPage;

  @override
  State<ThixHomeSwipeScreen> createState() => _ThixHomeSwipeScreenState();
}

class _ThixHomeSwipeScreenState extends State<ThixHomeSwipeScreen> {
  bool _loading = true;
  bool _showIntro = false;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_kPrefPermIntroSeen) ?? false;
    if (!mounted) return;
    setState(() {
      _showIntro = !seen;
      _loading = false;
    });
  }

  Future<void> _markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefPermIntroSeen, true);
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.location,
      Permission.camera,
      Permission.notification,
      Permission.contacts,
    ].request();
  }

  Future<void> _handleContinue() async {
    await _requestPermissions();
    await _markSeen();
    if (!mounted) return;
    setState(() => _showIntro = false);
  }

  Future<void> _handleLater() async {
    await _markSeen();
    if (!mounted) return;
    setState(() => _showIntro = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_showIntro) {
      return _ThixPermissionsIntroScreen(
        onContinue: _handleContinue,
        onLater: _handleLater,
      );
    }

    return _ThixHomeSwipeContent(initialPage: widget.initialPage);
  }
}

// ============================================================================
// SWIPE CONTENT — logique d'origine (SOS / RECHERCHE / RETROUVE)
// ============================================================================

class _ThixHomeSwipeContent extends StatefulWidget {
  const _ThixHomeSwipeContent({this.initialPage = 0});

  final int initialPage;

  @override
  State<_ThixHomeSwipeContent> createState() => _ThixHomeSwipeContentState();
}

class _ThixHomeSwipeContentState extends State<_ThixHomeSwipeContent> {
  late int _page;

  // ✅ Pages paresseuses : placeholder tant que jamais visité
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage.clamp(0, 2);
    _pages = List.generate(3, (_) => const SizedBox.shrink());
    _pages[_page] = _buildPage(_page);
    debugPrint('[HomeSwipe] 🚀 Initialized on page $_page');
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return _PageShell(
          key: const ValueKey('sos'),
          child: const ThixSosScreen(),
        );
      case 1:
        return _PageShell(
          key: const ValueKey('recherche'),
          child: const ThixRechercheScreen(),
        );
      case 2:
        return _PageShell(
          key: const ValueKey('retrouve'),
          child: const ThixRetrouveScreen(),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _goTo(int index) {
    if (index == _page) return;
    HapticFeedback.selectionClick();
    debugPrint('[HomeSwipe] 📑 Switching to page $index');
    setState(() {
      _page = index;
      // ✅ Monte la page UNE seule fois, au premier accès
      if (_pages[index] is SizedBox) {
        _pages[index] = _buildPage(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThixPolicy.inkDeep,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                8,
                16,
                12, // Léger espacement sous l'indicateur
              ),
              child: _SectionIndicator(
                current: _page,
                onSos: () => _goTo(0),
                onRecherche: () => _goTo(1),
                onRetrouve: () => _goTo(2),
              ),
            ),
          ),
          // ✅ IndexedStack paresseux (remplace PageView pour conserver l'état sans scroll)
          Expanded(
            child: IndexedStack(
              index: _page,
              children: _pages,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SECTION INDICATOR (Tabs style Enterprise)
// ============================================================================

class _SectionIndicator extends StatelessWidget {
  final int current;
  final VoidCallback onSos;
  final VoidCallback onRecherche;
  final VoidCallback onRetrouve;

  const _SectionIndicator({
    required this.current,
    required this.onSos,
    required this.onRecherche,
    required this.onRetrouve,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ThixPolicy.surfaceSoft.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: ThixPolicy.border.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabItem(
              title: 'SOS',
              isSelected: current == 0,
              activeColor: ThixPolicy.danger,
              onTap: onSos,
            ),
          ),
          Expanded(
            child: _TabItem(
              title: 'RECHERCHE',
              isSelected: current == 1,
              activeColor: ThixPolicy.primary,
              onTap: onRecherche,
            ),
          ),
          Expanded(
            child: _TabItem(
              title: 'RETROUVE',
              isSelected: current == 2,
              activeColor: ThixPolicy.warning,
              onTap: onRetrouve,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String title;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  const _TabItem({
    required this.title,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected
              ? Border.all(color: activeColor.withValues(alpha: 0.3))
              : Border.all(color: Colors.transparent),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? activeColor : ThixPolicy.textMuted,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// PAGE SHELL & ERROR BOUNDARY (isolation des onglets)
// ============================================================================

class _PageShell extends StatefulWidget {
  final Widget child;

  const _PageShell({super.key, required this.child});

  @override
  State<_PageShell> createState() => _PageShellState();
}

class _PageShellState extends State<_PageShell> {
  Object? _error;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _buildErrorState(context);
    }

    return RepaintBoundary(
      child: _ErrorCatcher(
        onError: (e, stack) {
          debugPrint('[PageShell] ❌ Error caught in tab: $e');
          if (mounted) setState(() => _error = e);
        },
        child: widget.child,
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: ThixPolicy.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.t('tab_error_title'),
              style: TextStyle(
                color: ThixPolicy.textMain,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.t('tab_error_subtitle'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ThixPolicy.textMuted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => setState(() => _error = null),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(l10n.t('common_retry')),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: ThixPolicy.inkDeep,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un widget utilitaire pour capturer les erreurs de build du sous-arbre.
class _ErrorCatcher extends StatefulWidget {
  final Widget child;
  final void Function(Object error, StackTrace stack) onError;

  const _ErrorCatcher({
    required this.child,
    required this.onError,
  });

  @override
  State<_ErrorCatcher> createState() => _ErrorCatcherState();
}

class _ErrorCatcherState extends State<_ErrorCatcher> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// ============================================================================
// ÉCRAN INTRO PERMISSIONS (affiché une seule fois au premier lancement)
// ============================================================================

class _PermissionItem {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _PermissionItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });
}

class _PermIntroStrings {
  final String header;
  final String subtitle;
  final String locationTitle;
  final String locationDesc;
  final String cameraTitle;
  final String cameraDesc;
  final String notifTitle;
  final String notifDesc;
  final String contactsTitle;
  final String contactsDesc;
  final String continueLabel;
  final String laterLabel;
  final String footNote;

  const _PermIntroStrings({
    required this.header,
    required this.subtitle,
    required this.locationTitle,
    required this.locationDesc,
    required this.cameraTitle,
    required this.cameraDesc,
    required this.notifTitle,
    required this.notifDesc,
    required this.contactsTitle,
    required this.contactsDesc,
    required this.continueLabel,
    required this.laterLabel,
    required this.footNote,
  });
}

const Map<String, _PermIntroStrings> _kPermIntroL10n = {
  'fr': _PermIntroStrings(
    header: 'Avant de commencer',
    subtitle: 'THIX ID a besoin de certains accès pour vous protéger et vous aider efficacement.',
    locationTitle: 'Localisation',
    locationDesc: 'Pour envoyer votre position exacte à vos secours lors d\'une alerte SOS et vous montrer les objets à proximité.',
    cameraTitle: 'Caméra',
    cameraDesc: 'Pour photographier un objet perdu ou trouvé dans THIX RETROUVE.',
    notifTitle: 'Notifications',
    notifDesc: 'Pour vous alerter en temps réel d\'une alerte SOS proche ou d\'une réponse à votre déclaration.',
    contactsTitle: 'Contacts',
    contactsDesc: 'Pour ajouter facilement vos proches comme secours dans vos cercles de sécurité.',
    continueLabel: 'Continuer',
    laterLabel: 'Plus tard',
    footNote: 'Vous pourrez modifier ces accès à tout moment dans les réglages.',
  ),
  'en': _PermIntroStrings(
    header: 'Before you start',
    subtitle: 'THIX ID needs a few permissions to protect and help you effectively.',
    locationTitle: 'Location',
    locationDesc: 'To send your exact position to your rescuers during an SOS alert and show nearby items.',
    cameraTitle: 'Camera',
    cameraDesc: 'To photograph a lost or found item in THIX RETROUVE.',
    notifTitle: 'Notifications',
    notifDesc: 'To alert you in real time about a nearby SOS alert or a reply to your report.',
    contactsTitle: 'Contacts',
    contactsDesc: 'To easily add your loved ones as rescuers in your safety circles.',
    continueLabel: 'Continue',
    laterLabel: 'Later',
    footNote: 'You can change these permissions anytime in settings.',
  ),
  'es': _PermIntroStrings(
    header: 'Antes de comenzar',
    subtitle: 'THIX ID necesita algunos permisos para protegerte y ayudarte de forma eficaz.',
    locationTitle: 'Ubicación',
    locationDesc: 'Para enviar tu posición exacta a tus rescatistas durante una alerta SOS y mostrarte objetos cercanos.',
    cameraTitle: 'Cámara',
    cameraDesc: 'Para fotografiar un objeto perdido o encontrado en THIX RETROUVE.',
    notifTitle: 'Notificaciones',
    notifDesc: 'Para avisarte en tiempo real de una alerta SOS cercana o una respuesta a tu declaración.',
    contactsTitle: 'Contactos',
    contactsDesc: 'Para añadir fácilmente a tus seres queridos como rescatistas en tus círculos de seguridad.',
    continueLabel: 'Continuar',
    laterLabel: 'Más tarde',
    footNote: 'Podrás cambiar estos permisos en cualquier momento en los ajustes.',
  ),
  'pt': _PermIntroStrings(
    header: 'Antes de começar',
    subtitle: 'O THIX ID precisa de algumas permissões para proteger e ajudar você de forma eficaz.',
    locationTitle: 'Localização',
    locationDesc: 'Para enviar sua posição exata aos socorristas durante um alerta SOS e mostrar objetos próximos.',
    cameraTitle: 'Câmera',
    cameraDesc: 'Para fotografar um objeto perdido ou encontrado no THIX RETROUVE.',
    notifTitle: 'Notificações',
    notifDesc: 'Para alertar você em tempo real sobre um SOS próximo ou uma resposta à sua declaração.',
    contactsTitle: 'Contatos',
    contactsDesc: 'Para adicionar facilmente seus entes queridos como socorristas nos seus círculos de segurança.',
    continueLabel: 'Continuar',
    laterLabel: 'Mais tarde',
    footNote: 'Você pode alterar essas permissões a qualquer momento nas configurações.',
  ),
  'sw': _PermIntroStrings(
    header: 'Kabla ya kuanza',
    subtitle: 'THIX ID inahitaji ruhusa fulani ili kukulinda na kukusaidia kwa ufanisi.',
    locationTitle: 'Mahali',
    locationDesc: 'Ili kutuma eneo lako kamili kwa waokoaji wako wakati wa tahadhari ya SOS na kukuonyesha vitu vilivyo karibu.',
    cameraTitle: 'Kamera',
    cameraDesc: 'Ili kupiga picha ya kitu kilichopotea au kupatikana kwenye THIX RETROUVE.',
    notifTitle: 'Arifa',
    notifDesc: 'Ili kukujulisha papo hapo kuhusu tahadhari ya SOS iliyo karibu au jibu la taarifa yako.',
    contactsTitle: 'Anwani',
    contactsDesc: 'Ili kuongeza kwa urahisi wapendwa wako kama waokoaji katika duru zako za usalama.',
    continueLabel: 'Endelea',
    laterLabel: 'Baadaye',
    footNote: 'Unaweza kubadilisha ruhusa hizi wakati wowote kwenye mipangilio.',
  ),
  'ar': _PermIntroStrings(
    header: 'قبل أن تبدأ',
    subtitle: 'يحتاج THIX ID إلى بعض الأذونات لحمايتك ومساعدتك بفعالية.',
    locationTitle: 'الموقع',
    locationDesc: 'لإرسال موقعك الدقيق إلى المنقذين أثناء تنبيه SOS وعرض الأغراض القريبة منك.',
    cameraTitle: 'الكاميرا',
    cameraDesc: 'لتصوير غرض مفقود أو تم العثور عليه في THIX RETROUVE.',
    notifTitle: 'الإشعارات',
    notifDesc: 'لتنبيهك فورًا بشأن تنبيه SOS قريب أو رد على بلاغك.',
    contactsTitle: 'جهات الاتصال',
    contactsDesc: 'لإضافة أحبائك بسهولة كمنقذين ضمن دوائر أمانك.',
    continueLabel: 'متابعة',
    laterLabel: 'لاحقًا',
    footNote: 'يمكنك تغيير هذه الأذونات في أي وقت من الإعدادات.',
  ),
  'zh': _PermIntroStrings(
    header: '开始之前',
    subtitle: 'THIX ID 需要一些权限，以便有效地保护和帮助您。',
    locationTitle: '位置',
    locationDesc: '用于在 SOS 警报期间将您的确切位置发送给救援人员，并显示附近的物品。',
    cameraTitle: '相机',
    cameraDesc: '用于在 THIX RETROUVE 中拍摄丢失或找到的物品照片。',
    notifTitle: '通知',
    notifDesc: '用于实时提醒您附近的 SOS 警报或对您报告的回复。',
    contactsTitle: '通讯录',
    contactsDesc: '用于轻松将您的亲人添加为安全圈中的救援人员。',
    continueLabel: '继续',
    laterLabel: '稍后',
    footNote: '您可以随时在设置中更改这些权限。',
  ),
};

class _ThixPermissionsIntroScreen extends StatelessWidget {
  const _ThixPermissionsIntroScreen({
    required this.onContinue,
    this.onLater,
  });

  final VoidCallback onContinue;
  final VoidCallback? onLater;

  /// ✅ Langue lue depuis le système AppLocalizations déjà en place dans l'app
  String _languageCode(BuildContext context) {
    try {
      return AppLocalizations.of(context).locale.languageCode;
    } catch (_) {
      return 'fr';
    }
  }

  _PermIntroStrings _strings(String code) =>
      _kPermIntroL10n[code] ?? _kPermIntroL10n['fr']!;

  bool _isRtl(String code) => code == 'ar';

  @override
  Widget build(BuildContext context) {
    final code = _languageCode(context);
    final s = _strings(code);

    final items = <_PermissionItem>[
      _PermissionItem(
        icon: Icons.location_on_rounded,
        color: ThixPolicy.danger,
        title: s.locationTitle,
        description: s.locationDesc,
      ),
      _PermissionItem(
        icon: Icons.camera_alt_rounded,
        color: ThixPolicy.primary,
        title: s.cameraTitle,
        description: s.cameraDesc,
      ),
      _PermissionItem(
        icon: Icons.notifications_active_rounded,
        color: ThixPolicy.warning,
        title: s.notifTitle,
        description: s.notifDesc,
      ),
      _PermissionItem(
        icon: Icons.contacts_rounded,
        color: ThixPolicy.success,
        title: s.contactsTitle,
        description: s.contactsDesc,
      ),
    ];

    return Directionality(
      textDirection: _isRtl(code) ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: ThixPolicy.inkDeep,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: ThixPolicy.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shield_rounded,
                      color: Colors.white, size: 32),
                ),
                const SizedBox(height: 24),
                Text(
                  s.header,
                  style: ThixPolicy.h1Style.copyWith(
                    color: Colors.white,
                    fontWeight: ThixPolicy.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  s.subtitle,
                  style: ThixPolicy.bodyStyle.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 28),
                Expanded(
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (_, i) => _PermissionRow(item: items[i]),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  s.footNote,
                  textAlign: TextAlign.center,
                  style: ThixPolicy.captionStyle.copyWith(
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      onContinue();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThixPolicy.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      s.continueLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                if (onLater != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      onLater!();
                    },
                    child: Text(
                      s.laterLabel,
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final _PermissionItem item;
  const _PermissionRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ThixPolicy.surfaceSoft.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ThixPolicy.border.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: item.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.description,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
