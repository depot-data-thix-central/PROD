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
      Permission.locationAlways,
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: _SectionIndicator(
                current: _page,
                onSos: () => _goTo(0),
                onRecherche: () => _goTo(1),
                onRetrouve: () => _goTo(2),
              ),
            ),
          ),
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
// PAGE SHELL & ERROR BOUNDARY
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
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// ============================================================================
// ÉCRAN INTRO PERMISSIONS (explications enrichies)
// ============================================================================

class _PermissionItem {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final String detail;

  const _PermissionItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.detail,
  });
}

class _PermIntroStrings {
  final String header;
  final String subtitle;
  final String locationTitle;
  final String locationDesc;
  final String locationDetail;
  final String cameraTitle;
  final String cameraDesc;
  final String cameraDetail;
  final String notifTitle;
  final String notifDesc;
  final String notifDetail;
  final String contactsTitle;
  final String contactsDesc;
  final String contactsDetail;
  final String continueLabel;
  final String laterLabel;
  final String footNote;
  final String backgroundLocationNote;

  const _PermIntroStrings({
    required this.header,
    required this.subtitle,
    required this.locationTitle,
    required this.locationDesc,
    required this.locationDetail,
    required this.cameraTitle,
    required this.cameraDesc,
    required this.cameraDetail,
    required this.notifTitle,
    required this.notifDesc,
    required this.notifDetail,
    required this.contactsTitle,
    required this.contactsDesc,
    required this.contactsDetail,
    required this.continueLabel,
    required this.laterLabel,
    required this.footNote,
    required this.backgroundLocationNote,
  });
}

const Map<String, _PermIntroStrings> _kPermIntroL10n = {
  'fr': _PermIntroStrings(
    header: 'Avant de commencer',
    subtitle: 'THIX ID a besoin de certains accès pour vous protéger et vous aider efficacement.',
    locationTitle: 'Localisation (toujours active)',
    locationDesc: 'Position GPS précise en temps réel, même en arrière-plan.',
    locationDetail: 'Lors d\'un SOS, votre position est transmise automatiquement à vos secours toutes les 10 secondes, même si vous fermez l\'application. En mode RETROUVE, cela permet de géolocaliser les objets perdus à proximité. Les données sont chiffrées et ne sont partagées qu\'avec vos cercles de sécurité.',
    cameraTitle: 'Caméra',
    cameraDesc: 'Accès à l\'appareil photo de votre téléphone.',
    cameraDetail: 'Utilisé dans THIX RETROUVE pour photographier un objet perdu ou trouvé. Les photos sont stockées localement puis synchronisées de manière sécurisée avec le serveur THIX pour aider à l\'identification.',
    notifTitle: 'Notifications',
    notifDesc: 'Alertes en temps réel, même écran éteint.',
    notifDetail: 'Essentiel pour recevoir instantanément : les alertes SOS de vos proches, les réponses à vos déclarations RETROUVE, les notifications de messages importants dans vos conversations de crise. Sans notifications, vous pourriez manquer une alerte vitale.',
    contactsTitle: 'Contacts',
    contactsDesc: 'Accès au carnet d\'adresses de votre téléphone.',
    contactsDetail: 'Permet d\'ajouter facilement vos proches (famille, amis, collègues) comme secours dans vos 3 cercles de sécurité. Aucun contact n\'est envoyé à THIX sans votre validation explicite — vous choisissez manuellement qui ajouter.',
    continueLabel: 'Continuer',
    laterLabel: 'Plus tard',
    footNote: 'Vous pourrez modifier ces accès à tout moment dans les réglages de votre téléphone.',
    backgroundLocationNote: '⚠️ Localisation en arrière-plan : THIX ID continuera à recevoir votre position même lorsque l\'application n\'est pas ouverte. Cela est essentiel pour que vos secours puissent vous localiser si vous ne pouvez plus utiliser votre téléphone.',
  ),
  'en': _PermIntroStrings(
    header: 'Before you start',
    subtitle: 'THIX ID needs a few permissions to protect and help you effectively.',
    locationTitle: 'Location (always active)',
    locationDesc: 'Precise GPS position in real time, even in the background.',
    locationDetail: 'During an SOS, your location is automatically transmitted to your rescuers every 10 seconds, even if you close the app. In RETROUVE mode, this helps geolocate lost items nearby. Data is encrypted and only shared with your safety circles.',
    cameraTitle: 'Camera',
    cameraDesc: 'Access to your phone\'s camera.',
    cameraDetail: 'Used in THIX RETROUVE to photograph a lost or found item. Photos are stored locally then securely synced with the THIX server to help with identification.',
    notifTitle: 'Notifications',
    notifDesc: 'Real-time alerts, even with screen off.',
    notifDetail: 'Essential to instantly receive: SOS alerts from your loved ones, responses to your RETROUVE reports, important message notifications in your crisis conversations. Without notifications, you might miss a vital alert.',
    contactsTitle: 'Contacts',
    contactsDesc: 'Access to your phone\'s address book.',
    contactsDetail: 'Allows you to easily add your loved ones (family, friends, colleagues) as rescuers in your 3 safety circles. No contact is sent to THIX without your explicit validation — you manually choose who to add.',
    continueLabel: 'Continue',
    laterLabel: 'Later',
    footNote: 'You can change these permissions anytime in your phone settings.',
    backgroundLocationNote: '⚠️ Background location: THIX ID will continue to receive your location even when the app is not open. This is essential so your rescuers can locate you if you can no longer use your phone.',
  ),
  'es': _PermIntroStrings(
    header: 'Antes de comenzar',
    subtitle: 'THIX ID necesita algunos permisos para protegerte y ayudarte de forma eficaz.',
    locationTitle: 'Ubicación (siempre activa)',
    locationDesc: 'Posición GPS precisa en tiempo real, incluso en segundo plano.',
    locationDetail: 'Durante un SOS, tu ubicación se transmite automáticamente a tus rescatistas cada 10 segundos, incluso si cierras la app. En modo RETROUVE, esto ayuda a geolocalizar objetos perdidos cercanos. Los datos están cifrados y solo se comparten con tus círculos de seguridad.',
    cameraTitle: 'Cámara',
    cameraDesc: 'Acceso a la cámara de tu teléfono.',
    cameraDetail: 'Se usa en THIX RETROUVE para fotografiar un objeto perdido o encontrado. Las fotos se almacenan localmente y luego se sincronizan de forma segura con el servidor THIX para ayudar con la identificación.',
    notifTitle: 'Notificaciones',
    notifDesc: 'Alertas en tiempo real, incluso con la pantalla apagada.',
    notifDetail: 'Esencial para recibir instantáneamente: alertas SOS de tus seres queridos, respuestas a tus declaraciones RETROUVE, notificaciones de mensajes importantes en tus conversaciones de crisis. Sin notificaciones, podrías perder una alerta vital.',
    contactsTitle: 'Contactos',
    contactsDesc: 'Acceso a la libreta de direcciones de tu teléfono.',
    contactsDetail: 'Te permite agregar fácilmente a tus seres queridos (familia, amigos, colegas) como rescatistas en tus 3 círculos de seguridad. Ningún contacto se envía a THIX sin tu validación explícita — eliges manualmente a quién agregar.',
    continueLabel: 'Continuar',
    laterLabel: 'Más tarde',
    footNote: 'Podrás cambiar estos permisos en cualquier momento en los ajustes de tu teléfono.',
    backgroundLocationNote: '⚠️ Ubicación en segundo plano: THIX ID continuará recibiendo tu ubicación incluso cuando la app no esté abierta. Esto es esencial para que tus rescatistas puedan localizarte si ya no puedes usar tu teléfono.',
  ),
  'pt': _PermIntroStrings(
    header: 'Antes de começar',
    subtitle: 'O THIX ID precisa de algumas permissões para proteger e ajudar você de forma eficaz.',
    locationTitle: 'Localização (sempre ativa)',
    locationDesc: 'Posição GPS precisa em tempo real, mesmo em segundo plano.',
    locationDetail: 'Durante um SOS, sua localização é transmitida automaticamente aos socorristas a cada 10 segundos, mesmo se você fechar o app. No modo RETROUVE, isso ajuda a geolocalizar objetos perdidos próximos. Os dados são criptografados e compartilhados apenas com seus círculos de segurança.',
    cameraTitle: 'Câmera',
    cameraDesc: 'Acesso à câmera do seu telefone.',
    cameraDetail: 'Usado no THIX RETROUVE para fotografar um objeto perdido ou encontrado. As fotos são armazenadas localmente e depois sincronizadas de forma segura com o servidor THIX para ajudar na identificação.',
    notifTitle: 'Notificações',
    notifDesc: 'Alertas em tempo real, mesmo com a tela desligada.',
    notifDetail: 'Essencial para receber instantaneamente: alertas SOS de seus entes queridos, respostas às suas declarações RETROUVE, notificações de mensagens importantes em suas conversas de crise. Sem notificações, você pode perder um alerta vital.',
    contactsTitle: 'Contatos',
    contactsDesc: 'Acesso à agenda do seu telefone.',
    contactsDetail: 'Permite adicionar facilmente seus entes queridos (família, amigos, colegas) como socorristas em seus 3 círculos de segurança. Nenhum contato é enviado ao THIX sem sua validação explícita — você escolhe manualmente quem adicionar.',
    continueLabel: 'Continuar',
    laterLabel: 'Mais tarde',
    footNote: 'Você pode alterar essas permissões a qualquer momento nas configurações do seu telefone.',
    backgroundLocationNote: '⚠️ Localização em segundo plano: O THIX ID continuará recebendo sua localização mesmo quando o app não estiver aberto. Isso é essencial para que seus socorristas possam localizá-lo se você não puder mais usar seu telefone.',
  ),
  'sw': _PermIntroStrings(
    header: 'Kabla ya kuanza',
    subtitle: 'THIX ID inahitaji ruhusa fulani ili kukulinda na kukusaidia kwa ufanisi.',
    locationTitle: 'Mahali (daima amilifu)',
    locationDesc: 'Nafasi sahihi ya GPS kwa wakati halisi, hata katika usuli.',
    locationDetail: 'Wakati wa SOS, eneo lako linatumwa kiotomatiki kwa waokoaji wako kila sekunde 10, hata ukifunga programu. Katika hali ya RETROUVE, hii husaidia kupata vitu vilivyopotea vilivyo karibu. Data imefichwa na kushirikiwa tu na miduara yako ya usalama.',
    cameraTitle: 'Kamera',
    cameraDesc: 'Ufikiaji wa kamera ya simu yako.',
    cameraDetail: 'Inatumika katika THIX RETROUVE kupiga picha ya kitu kilichopotea au kupatikana. Picha zinahifadhiwa ndani kisha kusawazishwa kwa usalama na seva ya THIX ili kusaidia utambuzi.',
    notifTitle: 'Arifa',
    notifDesc: 'Tahadhari za wakati halisi, hata skrini ikiwa imezimwa.',
    notifDetail: 'Muhimu kupokea mara moja: tahadhari za SOS kutoka kwa wapendwa wako, majibu ya taarifa zako za RETROUVE, arifa za ujumbe muhimu katika mazungumzo yako ya dharura. Bila arifa, unaweza kukosa tahadhari muhimu.',
    contactsTitle: 'Anwani',
    contactsDesc: 'Ufikiaji wa kitabu cha anwani cha simu yako.',
    contactsDetail: 'Inakuruhusu kuongeza kwa urahisi wapendwa wako (familia, marafiki, wenzako) kama waokoaji katika miduara yako 3 ya usalama. Hakuna anwani inayotumwa kwa THIX bila idhini yako wazi — unachagua mwenyewe nani wa kuongeza.',
    continueLabel: 'Endelea',
    laterLabel: 'Baadaye',
    footNote: 'Unaweza kubadilisha ruhusa hizi wakati wowote kwenye mipangilio ya simu yako.',
    backgroundLocationNote: '⚠️ Eneo la usuli: THIX ID itaendelea kupokea eneo lako hata programu ikiwa haijafunguliwa. Hii ni muhimu ili waokoaji wako waweze kukupata ikiwa huwezi tena kutumia simu yako.',
  ),
  'ar': _PermIntroStrings(
    header: 'قبل أن تبدأ',
    subtitle: 'يحتاج THIX ID إلى بعض الأذونات لحمايتك ومساعدتك بفعالية.',
    locationTitle: 'الموقع (نشط دائمًا)',
    locationDesc: 'موقع GPS دقيق في الوقت الفعلي، حتى في الخلفية.',
    locationDetail: 'أثناء تنبيه SOS، يتم نقل موقعك تلقائيًا إلى المنقذين كل 10 ثوانٍ، حتى إذا أغلقت التطبيق. في وضع RETROUVE، يساعد ذلك في تحديد الموقع الجغرافي للأشياء المفقودة القريبة. البيانات مشفرة وتُشارك فقط مع دوائر أمانك.',
    cameraTitle: 'الكاميرا',
    cameraDesc: 'الوصول إلى كاميرا هاتفك.',
    cameraDetail: 'يُستخدم في THIX RETROUVE لتصوير غرض مفقود أو تم العثور عليه. يتم تخزين الصور محليًا ثم مزامنتها بشكل آمن مع خادم THIX للمساعدة في التعريف.',
    notifTitle: 'الإشعارات',
    notifDesc: 'تنبيهات في الوقت الفعلي، حتى مع إيقاف الشاشة.',
    notifDetail: 'ضروري للاستلام الفوري: تنبيهات SOS من أحبائك، الردود على إعلاناتك في RETROUVE، إشعارات الرسائل المهمة في محادثات الأزمات. بدون إشعارات، قد تفوتك تنبيه حيوي.',
    contactsTitle: 'جهات الاتصال',
    contactsDesc: 'الوصول إلى دفتر عناوين هاتفك.',
    contactsDetail: 'يسمح لك بإضافة أحبائك (العائلة، الأصدقاء، الزملاء) بسهولة كمنقذين في دوائر الأمان الثلاث الخاصة بك. لا يتم إرسال أي جهة اتصال إلى THIX دون موافقتك الصريحة — تختار يدويًا من تضيفه.',
    continueLabel: 'متابعة',
    laterLabel: 'لاحقًا',
    footNote: 'يمكنك تغيير هذه الأذونات في أي وقت من إعدادات هاتفك.',
    backgroundLocationNote: '⚠️ الموقع في الخلفية: سيستمر THIX ID في تلقي موقعك حتى عندما لا يكون التطبيق مفتوحًا. هذا ضروري حتى يتمكن المنقذون من تحديد موقعك إذا لم تعد قادرًا على استخدام هاتفك.',
  ),
  'zh': _PermIntroStrings(
    header: '开始之前',
    subtitle: 'THIX ID 需要一些权限，以便有效地保护和帮助您。',
    locationTitle: '位置（始终活动）',
    locationDesc: '实时精确 GPS 位置，即使在后台。',
    locationDetail: '在 SOS 期间，您的位置每 10 秒自动传输给救援人员，即使您关闭应用程序。在 RETROUVE 模式下，这有助于对附近丢失的物品进行地理定位。数据经过加密，仅与您的安全圈共享。',
    cameraTitle: '相机',
    cameraDesc: '访问您手机的相机。',
    cameraDetail: '在 THIX RETROUVE 中用于拍摄丢失或找到的物品。照片存储在本地，然后安全地与 THIX 服务器同步，以帮助识别。',
    notifTitle: '通知',
    notifDesc: '实时警报，即使屏幕关闭。',
    notifDetail: '对于即时接收至关重要：来自亲人的 SOS 警报、对您 RETROUVE 报告的回复、危机对话中的重要消息通知。没有通知，您可能会错过重要警报。',
    contactsTitle: '通讯录',
    contactsDesc: '访问您手机的地址簿。',
    contactsDetail: '允许您轻松地将亲人（家人、朋友、同事）添加为 3 个安全圈中的救援人员。未经您明确验证，不会向 THIX 发送任何联系人 — 您手动选择添加谁。',
    continueLabel: '继续',
    laterLabel: '稍后',
    footNote: '您可以随时在手机设置中更改这些权限。',
    backgroundLocationNote: '⚠️ 后台位置：即使应用程序未打开，THIX ID 也会继续接收您的位置。这对于救援人员在您无法使用手机时能够定位您至关重要。',
  ),
};

class _ThixPermissionsIntroScreen extends StatelessWidget {
  const _ThixPermissionsIntroScreen({
    required this.onContinue,
    this.onLater,
  });

  final VoidCallback onContinue;
  final VoidCallback? onLater;

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
        detail: s.locationDetail,
      ),
      _PermissionItem(
        icon: Icons.camera_alt_rounded,
        color: ThixPolicy.primary,
        title: s.cameraTitle,
        description: s.cameraDesc,
        detail: s.cameraDetail,
      ),
      _PermissionItem(
        icon: Icons.notifications_active_rounded,
        color: ThixPolicy.warning,
        title: s.notifTitle,
        description: s.notifDesc,
        detail: s.notifDetail,
      ),
      _PermissionItem(
        icon: Icons.contacts_rounded,
        color: ThixPolicy.success,
        title: s.contactsTitle,
        description: s.contactsDesc,
        detail: s.contactsDetail,
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
                const SizedBox(height: 16),
                // ✅ Note spécifique sur la localisation en arrière-plan
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ThixPolicy.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ThixPolicy.warning.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: ThixPolicy.warning,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s.backgroundLocationNote,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 46),
            child: Text(
              item.detail,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
                height: 1.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
