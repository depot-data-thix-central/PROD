// lib/presentation/home/home_page.dart
//
// ✅ REFONTE 100 % — design THIX HUB (logo, tagline, grille de tuiles).
//    • Fond : photos africaines en auto-scroll (réglable par l'admin).
//    • Bouton de personnalisation visible UNIQUEMENT pour le rôle admin.
//    • Hero banner / carrousel supprimé.
//    • « More… » ouvre tous les autres services (+ SOS, coffre, QR, certification).
import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/thix_profile.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/presentation/common/full_screen_message.dart';
import 'package:thix_id/presentation/common/thix_identity_sheets.dart';
import 'package:thix_id/services/profile_service.dart';
import 'package:thix_id/services/notification_counters_service.dart';
import 'package:thix_id/services/thix_id_service.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/widgets/no_connection_overlay.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';

import 'widgets/home_header_delegate.dart';
import 'widgets/home_hub_background.dart';
import 'widgets/home_hub_brand.dart';
import 'widgets/home_hub_customize_sheet.dart';
import 'widgets/home_hub_grid.dart';
import 'widgets/home_hub_settings.dart';
import 'widgets/home_theme.dart';
import 'widgets/account_request_sheet.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 20);
const Duration _kRetryDelay = Duration(milliseconds: 500);
const int _kMaxRetries = 2;

// Qualité réseau
const Duration _kQualityInterval = Duration(seconds: 30);
const Duration _kQualityTimeout = Duration(seconds: 3);
const int _kWeakLatencyMs = 1500;

/// ⚠️ À ADAPTER : route réelle du module THIX Business (portfolio/studio).
const String _kBusinessRoute = '/thix-business';

/// 💍 Route du module mariage (THIX WED).
const String _kWeddingRoute = '/thix-weeding';

/// 🔒 Services temporairement suspendus → « Bientôt à disposition ».
const Set<String> _kSuspended = {'thixSante', 'thixMoney'};

// ============================================================================
// VALIDATORS
// ============================================================================
class _HomeValidators {
  _HomeValidators._();

  static bool isValidThixId(String? id) {
    if (id == null || id.trim().isEmpty) return false;
    return RegExp(r'^THIX-[A-Z0-9-]{10,}$').hasMatch(id.trim());
  }

  static bool isValidUid(String? uid) {
    if (uid == null || uid.trim().isEmpty) return false;
    return RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$')
        .hasMatch(uid.trim());
  }
}

Future<T> _homeRetry<T>(
  Future<T> Function() fn, {
  required String label,
  int maxRetries = _kMaxRetries,
  Duration timeout = _kRequestTimeout,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(timeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[HomePage] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[HomePage] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================
class HomePagePremium extends StatefulWidget {
  const HomePagePremium({super.key});

  @override
  State<HomePagePremium> createState() => _HomePagePremiumState();
}

class _HomePagePremiumState extends State<HomePagePremium> {
  final TextEditingController _searchController = TextEditingController();
  final NotificationCountersService _counters = NotificationCountersService();
  final ProfileService _profileService = ProfileService();
  final HomeHubController _hub = HomeHubController();

  bool _searching = false;
  String? _adminUid;

  // ✅ Stream des badges créé UNE seule fois, en broadcast.
  Stream<SectionBadgeCounts>? _badgeStream;
  String? _badgeStreamUid;

  // ✅ Qualité réseau
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  Timer? _qualityTimer;
  bool _weakNetwork = false;
  bool _checkingQuality = false;

  @override
  void initState() {
    super.initState();
    unawaited(_hub.loadSettings());
    _initNetworkQuality();
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _qualityTimer?.cancel();
    _searchController.dispose();
    _hub.dispose();
    super.dispose();
  }

  // ── QUALITÉ RÉSEAU ──
  void _initNetworkQuality() {
    unawaited(_checkNetworkQuality());
    _connSub = Connectivity().onConnectivityChanged.listen((_) {
      unawaited(_checkNetworkQuality());
    });
    _qualityTimer = Timer.periodic(_kQualityInterval, (_) {
      unawaited(_checkNetworkQuality());
    });
  }

  Future<void> _checkNetworkQuality() async {
    if (_checkingQuality) return;
    _checkingQuality = true;
    try {
      final results = await Connectivity().checkConnectivity();
      final offline = results.isEmpty || results.every((r) => r == ConnectivityResult.none);

      // Hors ligne : géré par le routeur (page "Pas de connexion").
      if (offline) {
        _setWeak(false);
        return;
      }

      final sw = Stopwatch()..start();
      try {
        final lookup = await InternetAddress.lookup('google.com').timeout(_kQualityTimeout);
        sw.stop();
        _setWeak(lookup.isEmpty || sw.elapsedMilliseconds > _kWeakLatencyMs);
      } catch (_) {
        _setWeak(true);
      }
    } catch (e) {
      debugPrint('[HomePage] ⚠️ Network quality check failed: $e');
    } finally {
      _checkingQuality = false;
    }
  }

  void _setWeak(bool value) {
    if (!mounted || _weakNetwork == value) return;
    setState(() => _weakNetwork = value);
  }

  // ── STREAM BADGES (cache + broadcast) ──
  Stream<SectionBadgeCounts> _badgeStreamFor(String? uid) {
    if (_badgeStream != null && _badgeStreamUid == uid) {
      return _badgeStream!;
    }
    _badgeStreamUid = uid;
    if (uid == null) {
      _badgeStream = const Stream<SectionBadgeCounts>.empty().asBroadcastStream();
    } else {
      _badgeStream = _counters.streamCounts(uid).asBroadcastStream();
    }
    return _badgeStream!;
  }

  // ── ADMIN (re-vérifié quand l'utilisateur change) ──
  void _syncAdminFor(String? uid) {
    if (uid == _adminUid) return;
    _adminUid = uid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_hub.refreshAdmin());
    });
  }

  Future<void> _openCustomize() async {
    if (!_hub.isAdmin) return;
    await HubCustomizeSheet.show(context, _hub);
  }

  // ── RECHERCHE / VÉRIFICATION ──
  Future<void> _handleHomeSearchVerify() async {
    final l10n = AppLocalizations.of(context);
    final raw = _searchController.text.trim();

    if (raw.isEmpty) {
      await FullScreenMessage.showError(
        context,
        title: l10n.t('home_required_id_title'),
        message: l10n.t('home_required_id_msg'),
      );
      return;
    }

    final normalized = ThixIdService.normalize(raw);
    final isThix = _HomeValidators.isValidThixId(normalized);
    final isUid = _HomeValidators.isValidUid(raw);

    if (!isThix && !isUid) {
      await FullScreenMessage.showError(
        context,
        title: l10n.t('home_invalid_id_title'),
        message: l10n.t('home_invalid_id_msg'),
      );
      return;
    }

    setState(() => _searching = true);
    HapticFeedback.selectionClick();

    try {
      ThixProfile? profile;
      if (isThix) {
        profile = await _homeRetry(() => _profileService.fetchPublicProfileByThixId(normalized), label: 'fetchProfileByThixId');
      } else {
        profile = await _homeRetry(() => _profileService.fetchPublicProfileByUserId(raw), label: 'fetchProfileByUid');
      }

      if (!mounted) return;

      if (profile == null) {
        await FullScreenMessage.showError(
          context,
          title: l10n.t('home_profile_not_found_title'),
          message: l10n.t('home_profile_not_found_msg'),
        );
        return;
      }

      final thix = profile.thixId.trim().toUpperCase();
      if (thix.isNotEmpty && _HomeValidators.isValidThixId(thix)) {
        HapticFeedback.mediumImpact();
        context.push('${AppRoutes.publicProfile}?thixId=$thix');
      } else {
        await ThixIdentitySheets.showVerifySheet(context, initialUidOrThixId: profile.userId);
      }
    } catch (e) {
      debugPrint('[HomePage] ❌ Search verify error: $e');
      if (!mounted) return;
      await FullScreenMessage.showError(
        context,
        title: l10n.t('home_verify_error_title'),
        message: l10n.t('home_verify_error_msg'),
      );
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  // ── NAVIGATION ──
  void _onProfileTap() {
    HapticFeedback.mediumImpact();
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      context.push(AppRoutes.login);
    } else {
      context.go(AppRoutes.userDashboard);
    }
  }

  Future<void> _openThixAi() async {
    HapticFeedback.selectionClick();
    final auth = context.read<AuthController>();
    context.push(auth.isAuthenticated ? '/thix-ia' : AppRoutes.login);
  }

  /// ✅ Chat : le badge « messages » est remis à zéro à l'ouverture.
  Future<void> _openThixChat() async {
    HapticFeedback.selectionClick();
    final auth = context.read<AuthController>();
    if (auth.isAuthenticated) {
      final uid = auth.currentUser?.id;
      if (uid != null) {
        Future.sync(() => _counters.markSectionSeen(uid: uid, section: ThixSection.messages)).then(
          (_) {},
          onError: (Object e) => debugPrint('[HomePage] ⚠️ markSectionSeen(messages): $e'),
        );
      }
      context.go(AppRoutes.chat);
    } else {
      context.push(AppRoutes.login);
    }
  }

  Future<void> _openEmergency() async {
    HapticFeedback.mediumImpact();
    final auth = context.read<AuthController>();
    if (!mounted) return;
    context.push(auth.isAuthenticated ? '/home-swipe' : AppRoutes.login);
  }

  void _openDocumentVault() {
    HapticFeedback.selectionClick();
    final auth = context.read<AuthController>();
    context.push(auth.isAuthenticated ? AppRoutes.vault : AppRoutes.login);
  }

  void _openScanQr() {
    HapticFeedback.selectionClick();
    ThixIdentitySheets.showQrScanSheet(context);
  }

  void _openBusiness() {
    HapticFeedback.selectionClick();
    context.push(_kBusinessRoute);
  }

  Future<void> _handleRequestAccount() async {
    HapticFeedback.mediumImpact();
    final auth = context.read<AuthController>();
    final res = await showModalBottomSheet<AccountRequestChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const AccountRequestSheet(),
    );

    switch (res) {
      case AccountRequestChoice.personal:
        if (auth.isAuthenticated) await auth.signOut();
        if (mounted) context.push(AppRoutes.personalReg);
        return;
      case null:
        return;
    }
  }

  // ── TUILES DE LA GRILLE ──
  void _onHubTile(String key) {
    switch (key) {
      case 'social':
        _handleServiceTap('thixMedia');
        break;
      case 'chat':
        _openThixChat();
        break;
      case 'pro':
        _handleServiceTap('reseauPro');
        break;
      case 'business':
        _openBusiness();
        break;
      case 'market':
        _handleServiceTap('thixMarket');
        break;
      case 'events':
        _handleServiceTap('evenements');
        break;
      case 'sona':
        _openThixAi();
        break;
    }
  }

  // ── ACTIONS DU PANNEAU « MORE… » ──
  void _handleMoreAction(String key) {
    switch (key) {
      case 'sos':
        _openEmergency();
        break;
      case 'vault':
        _openDocumentVault();
        break;
      case 'scanQr':
        _openScanQr();
        break;
      default:
        _handleServiceTap(key);
    }
  }

  void _handleServiceTap(String serviceKey) {
    HapticFeedback.selectionClick();

    if (_kSuspended.contains(serviceKey)) {
      _showSoon();
      return;
    }

    final uid = context.read<AuthController>().currentUser?.id;

    if (uid != null) {
      final section = _mapServiceToSection(serviceKey);
      if (section != null) _counters.markSectionSeen(uid: uid, section: section);
    }

    final route = _getServiceRoute(serviceKey);
    if (route != null) {
      if (route.startsWith('go:')) {
        context.go(route.substring(3));
      } else {
        context.push(route);
      }
    }
  }

  ThixSection? _mapServiceToSection(String key) {
    switch (key) {
      case 'thixMedia':
        return ThixSection.media;
      case 'thixMarket':
        return ThixSection.market;
      case 'formations':
        return ThixSection.formations;
      case 'emplois':
        return ThixSection.jobs;
      case 'thixInfo':
        return ThixSection.info;
      case 'opportunites':
        return ThixSection.opportunities;
      case 'evenements':
        return ThixSection.events;
      case 'reseauPro':
        return ThixSection.network;
      case 'thixSante':
        return ThixSection.health;
      case 'thixMoney':
        return ThixSection.money;
      case 'monPays':
        return ThixSection.monPays;
      case 'reservation':
        return ThixSection.reservation;
      default:
        return null;
    }
  }

  String? _getServiceRoute(String key) {
    switch (key) {
      case 'thixMedia':
        return AppRoutes.thixMedia;
      case 'thixMarket':
        return AppRoutes.thixMarket;
      case 'formations':
        return AppRoutes.trainingHome;
      case 'emplois':
        return AppRoutes.jobs;
      case 'thixInfo':
        return AppRoutes.thixInfo;
      case 'opportunites':
        return AppRoutes.opportunities;
      case 'evenements':
        return '/thix-event';
      case 'reseauPro':
        return 'go:${AppRoutes.network}';
      case 'thixSante':
        return AppRoutes.thixSante;
      case 'thixMoney':
        return AppRoutes.thixMoney;
      case 'monPays':
        return AppRoutes.monPays;
      case 'reservation':
        return AppRoutes.reservation;
      case 'thixWed':
        return _kWeddingRoute;
      case 'thixRetrouve':
        return '/home-swipe';
      default:
        return null;
    }
  }

  // ── FEEDBACK ──
  void _showSoon() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          backgroundColor: ThixPolicy.primaryDeep,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Row(
            children: [
              const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hubTr(l10n, 'soon_available', 'Bientôt à disposition'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  // ── BUILD ──
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final safeTop = MediaQuery.paddingOf(context).top;
    final l10n = AppLocalizations.of(context);

    final displayName = (auth.currentUser?.displayName.trim().isNotEmpty ?? false)
        ? auth.currentUser!.displayName.trim()
        : (auth.currentUser?.email.trim().isNotEmpty ?? false)
            ? auth.currentUser!.email.trim()
            : l10n.t('home_greeting');

    final photoUrl = auth.currentUser?.photoUrl;
    final badgeCountsStream = _badgeStreamFor(auth.currentUser?.id);

    _syncAdminFor(auth.currentUser?.id);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(child: HomeHubBackground(controller: _hub)),
          _HomeContent(
            safeTop: safeTop,
            displayName: displayName,
            photoUrl: photoUrl,
            auth: auth,
            hub: _hub,
            badgeCountsStream: badgeCountsStream,
            searchController: _searchController,
            searching: _searching,
            onProfileTap: _onProfileTap,
            onAccountRequest: _handleRequestAccount,
            onSearchVerify: _handleHomeSearchVerify,
            onTileTap: _onHubTile,
            onMoreAction: _handleMoreAction,
          ),
          // ✅ Pastille qualité réseau
          Positioned(
            left: 20,
            right: 20,
            bottom: 96,
            child: IgnorePointer(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _weakNetwork
                    ? const _WeakNetworkBanner(key: ValueKey('weak'))
                    : const SizedBox.shrink(key: ValueKey('ok')),
              ),
            ),
          ),
          // 🎨 Bouton de personnalisation — ADMIN uniquement
          AnimatedBuilder(
            animation: _hub,
            builder: (context, _) {
              if (!_hub.isAdmin) return const SizedBox.shrink();
              return Positioned(
                right: 16,
                bottom: 150,
                child: _AdminCustomizeButton(
                  primary: _hub.settings.primary,
                  onTap: _openCustomize,
                ),
              );
            },
          ),
          if (_searching) const _SearchingOverlay(),
          const NoConnectionOverlay(),
        ],
      ),
    );
  }
}

// ============================================================================
// CONTENU
// ============================================================================
class _HomeContent extends StatelessWidget {
  final double safeTop;
  final String displayName;
  final String? photoUrl;
  final AuthController auth;
  final HomeHubController hub;
  final Stream<SectionBadgeCounts> badgeCountsStream;
  final TextEditingController searchController;
  final bool searching;
  final VoidCallback onProfileTap;
  final VoidCallback onAccountRequest;
  final VoidCallback onSearchVerify;
  final ValueChanged<String> onTileTap;
  final ValueChanged<String> onMoreAction;

  const _HomeContent({
    required this.safeTop,
    required this.displayName,
    required this.photoUrl,
    required this.auth,
    required this.hub,
    required this.badgeCountsStream,
    required this.searchController,
    required this.searching,
    required this.onProfileTap,
    required this.onAccountRequest,
    required this.onSearchVerify,
    required this.onTileTap,
    required this.onMoreAction,
  });

  @override
  Widget build(BuildContext context) {
    const hPad = EdgeInsets.symmetric(horizontal: ThixPolicy.s20);
    final h = MediaQuery.sizeOf(context).height;
    // Espace qui laisse respirer la photo entre la tagline et la grille.
    final photoGap = (h * 0.20).clamp(90.0, 220.0).toDouble();

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: HomeHeaderDelegate(
            safeTop: safeTop,
            displayName: displayName,
            photoUrl: photoUrl,
            isAuthenticated: auth.isAuthenticated,
            badgeCountsStream: badgeCountsStream,
            onProfileTap: onProfileTap,
            onAccountRequest: onAccountRequest,
            searchController: searchController,
            isSearching: searching,
            onVerify: onSearchVerify,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s16)),
        SliverToBoxAdapter(
          child: Padding(
            padding: hPad,
            child: AnimatedBuilder(
              animation: hub,
              builder: (context, _) {
                final s = hub.settings;
                return HubBrand(primary: s.primary, accent: s.accent);
              },
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: photoGap)),
        SliverToBoxAdapter(
          child: Padding(
            padding: hPad,
            child: AnimatedBuilder(
              animation: hub,
              builder: (context, _) {
                final s = hub.settings;
                return StreamBuilder<SectionBadgeCounts>(
                  stream: badgeCountsStream,
                  initialData: SectionBadgeCounts.zero,
                  builder: (context, snap) {
                    final counts = snap.data ?? SectionBadgeCounts.zero;
                    return HomeHubGrid(
                      counts: counts,
                      primary: s.primary,
                      accent: s.accent,
                      onTap: onTileTap,
                      onMoreAction: onMoreAction,
                    );
                  },
                );
              },
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 110)),
      ],
    );
  }
}

// ============================================================================
// COMPOSANTS
// ============================================================================
class _WeakNetworkBanner extends StatelessWidget {
  const _WeakNetworkBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: HomeTheme.ink.withOpacity(0.92),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.signal_cellular_connected_no_internet_0_bar_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Connexion instable — chargement lent possible',
                style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminCustomizeButton extends StatelessWidget {
  final Color primary;
  final VoidCallback onTap;
  const _AdminCustomizeButton({required this.primary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Personnaliser l\'accueil (admin)',
      child: GestureDetector(
        onTap: onTap,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.78),
                shape: BoxShape.circle,
                border: Border.all(color: primary.withOpacity(0.35), width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: primary.withOpacity(0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(Icons.palette_rounded, size: 22, color: primary),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchingOverlay extends StatelessWidget {
  const _SearchingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          color: Colors.white.withOpacity(0.6),
          child: const Center(child: CircularProgressIndicator(color: HomeTheme.sky)),
        ),
      ),
    );
  }
}
