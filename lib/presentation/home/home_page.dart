// lib/presentation/home/home_page.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:image/image.dart' as img;

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

import 'widgets/home_background.dart';
import 'widgets/home_header_delegate.dart';
import 'widgets/home_search.dart';
import 'widgets/home_headlines_carousel.dart';
import 'widgets/home_quick_actions.dart';
import 'widgets/home_services_constellation.dart';
import 'widgets/home_premium_card.dart';
import 'widgets/home_theme.dart';
import 'widgets/account_request_sheet.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 20);
const Duration _kUploadTimeout = Duration(seconds: 60);
const Duration _kRetryDelay = Duration(milliseconds: 500);
const int _kMaxRetries = 2;
const int _kMaxFileSizeBytes = 5 * 1024 * 1024;
const int _kMaxTitleLength = 100;
const int _kMaxTagLength = 30;
const int _kMinImageWidth = 800;
const int _kMinImageHeight = 400;
const double _kMaxAspectRatio = 2.5;

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

  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static bool isValidFileType(String? extension) {
    if (extension == null) return false;
    return ['jpg', 'jpeg', 'png', 'webp'].contains(extension.toLowerCase());
  }

  static bool isValidFileSize(int bytes) => bytes > 0 && bytes <= _kMaxFileSizeBytes;

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static Future<bool> isValidImage(Uint8List bytes) async {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return false;
      if (image.width < _kMinImageWidth || image.height < _kMinImageHeight) return false;
      final ratio = image.width / image.height;
      if (ratio > _kMaxAspectRatio || ratio < 1 / _kMaxAspectRatio) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  static String friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('permission') || msg.contains('policy')) return 'Accès non autorisé.';
    if (msg.contains('not found')) return 'Ressource introuvable.';
    if (msg.contains('storage')) return 'Erreur de stockage. Réessayez.';
    return 'Une erreur est survenue. Réessayez.';
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
  final PageController _headlinesController = PageController();
  final NotificationCountersService _counters = NotificationCountersService();
  final ProfileService _profileService = ProfileService();

  bool _searching = false;
  bool _isAdmin = false;
  bool _uploadingBanner = false;

  @override
  void initState() {
    super.initState();
    _checkAdminRole();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _headlinesController.dispose();
    super.dispose();
  }

  // ── ADMIN ──
  Future<void> _checkAdminRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final data = await _homeRetry(
        () => Supabase.instance.client.from('profiles').select('role, account_type').eq('id', user.id).maybeSingle(),
        label: 'checkAdminRole',
      );
      if (!mounted) return;
      if (data != null) {
        final role = (data['role'] ?? data['account_type'] ?? '').toString().toLowerCase();
        setState(() => _isAdmin = role == 'admin' || role == 'entreprise' || role == 'support');
      }
    } catch (e) {
      debugPrint('[HomePage] ⚠️ Admin check failed (non-critical): $e');
    }
  }

  Future<void> _showAddBannerDialog() async {
    if (!_isAdmin) return;
    HapticFeedback.mediumImpact();
    final l10n = AppLocalizations.of(context);
    final titleCtrl = TextEditingController();
    final typeCtrl = TextEditingController(text: l10n.t('home_banner_default_tag'));

    await showDialog(
      context: context,
      builder: (ctx) => _BannerUploadDialog(
        titleController: titleCtrl,
        typeController: typeCtrl,
        isUploading: _uploadingBanner,
        onUpload: () {
          Navigator.pop(ctx);
          _pickAndUploadBanner(titleCtrl.text.trim(), typeCtrl.text.trim());
        },
        onCancel: () => Navigator.pop(ctx),
      ),
    );
    titleCtrl.dispose();
    typeCtrl.dispose();
  }

  Future<void> _pickAndUploadBanner(String title, String type) async {
    if (!_isAdmin) return;
    final l10n = AppLocalizations.of(context);

    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;

      if (!_HomeValidators.isValidFileType(file.extension)) {
        _showError(l10n.t('home_banner_invalid_type'));
        return;
      }

      final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);
      if (bytes == null) {
        _showError(l10n.t('home_banner_read_error'));
        return;
      }

      if (!_HomeValidators.isValidFileSize(bytes.length)) {
        _showError(
          '${l10n.t('home_banner_too_large')} (${_HomeValidators.formatFileSize(bytes.length)} / ${_HomeValidators.formatFileSize(_kMaxFileSizeBytes)})',
        );
        return;
      }

      if (!await _HomeValidators.isValidImage(bytes)) {
        _showError(l10n.t('home_banner_invalid_dimensions'));
        return;
      }

      final sanitizedTitle = _HomeValidators.sanitize(
        title.isEmpty ? l10n.t('home_banner_default_title') : title,
        maxLength: _kMaxTitleLength,
      );
      final sanitizedType = _HomeValidators.sanitize(
        type.isEmpty ? l10n.t('home_banner_default_tag') : type,
        maxLength: _kMaxTagLength,
      );

      setState(() => _uploadingBanner = true);

      final ext = file.extension ?? 'jpg';
      final fileName = 'banner_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storagePath = 'annonces/$fileName';

      await _homeRetry(
        () => Supabase.instance.client.storage.from('banners').uploadBinary(storagePath, bytes),
        label: 'uploadBanner',
        timeout: _kUploadTimeout,
      );

      final publicUrl = Supabase.instance.client.storage.from('banners').getPublicUrl(storagePath);

      await _homeRetry(
        () => Supabase.instance.client.from('banners').insert({
          'image_url': publicUrl,
          'title': sanitizedTitle,
          'tag': sanitizedType,
          'is_active': true,
          'created_at': DateTime.now().toIso8601String(),
        }),
        label: 'insertBanner',
      );

      if (mounted) _showSuccess(l10n.t('home_banner_uploaded'));
    } catch (e) {
      debugPrint('[HomePage] ❌ Banner upload error: $e');
      if (mounted) _showError(_HomeValidators.friendlyError(e));
    } finally {
      if (mounted) setState(() => _uploadingBanner = false);
    }
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

  Future<void> _openThixChat() async {
    HapticFeedback.selectionClick();
    final auth = context.read<AuthController>();
    if (auth.isAuthenticated) {
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

  void _openMiniApps() {
    HapticFeedback.selectionClick();
    _showInfo(AppLocalizations.of(context).t('home_mini_apps_coming_soon'));
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

  void _handleServiceTap(String serviceKey) {
    HapticFeedback.selectionClick();
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
      case 'thixRetrouve':
        return '/home-swipe';
      default:
        return null;
    }
  }

  // ── FEEDBACK ──
  void _snack(String message, Color bg, IconData icon) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ]),
          backgroundColor: bg,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
  }

  void _showSuccess(String m) => _snack(m, ThixPolicy.success, Icons.check_circle_rounded);

  void _showError(String m) {
    HapticFeedback.lightImpact();
    _snack(m, ThixPolicy.danger, Icons.error_outline_rounded);
  }

  void _showInfo(String m) => _snack(m, HomeTheme.ink, Icons.info_outline_rounded);

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

    final badgeCountsStream = auth.currentUser == null
        ? Stream<SectionBadgeCounts>.value(SectionBadgeCounts.zero)
        : _counters.streamCounts(auth.currentUser!.id);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          const Positioned.fill(child: HomeSoftBackground()),
          _HomeContent(
            safeTop: safeTop,
            displayName: displayName,
            photoUrl: photoUrl,
            auth: auth,
            badgeCountsStream: badgeCountsStream,
            searchController: _searchController,
            headlinesController: _headlinesController,
            isAdmin: _isAdmin,
            uploadingBanner: _uploadingBanner,
            searching: _searching,
            onProfileTap: _onProfileTap,
            onAccountRequest: _handleRequestAccount,
            onSearchVerify: _handleHomeSearchVerify,
            onAddBanner: _showAddBannerDialog,
            onScanTap: _openThixAi,
            onDocumentTap: _openDocumentVault,
            onChatTap: _openThixChat,
            onSecurityTap: _openEmergency,
            onServiceTap: _handleServiceTap,
            onMiniAppsTap: _openMiniApps,
            onScanQrTap: _openScanQr,
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
  final Stream<SectionBadgeCounts> badgeCountsStream;
  final TextEditingController searchController;
  final PageController headlinesController;
  final bool isAdmin;
  final bool uploadingBanner;
  final bool searching;
  final VoidCallback onProfileTap;
  final VoidCallback onAccountRequest;
  final VoidCallback onSearchVerify;
  final VoidCallback onAddBanner;
  final VoidCallback onScanTap;
  final VoidCallback onDocumentTap;
  final VoidCallback onChatTap;
  final VoidCallback onSecurityTap;
  final ValueChanged<String> onServiceTap;
  final VoidCallback onMiniAppsTap;
  final VoidCallback onScanQrTap;

  const _HomeContent({
    required this.safeTop,
    required this.displayName,
    required this.photoUrl,
    required this.auth,
    required this.badgeCountsStream,
    required this.searchController,
    required this.headlinesController,
    required this.isAdmin,
    required this.uploadingBanner,
    required this.searching,
    required this.onProfileTap,
    required this.onAccountRequest,
    required this.onSearchVerify,
    required this.onAddBanner,
    required this.onScanTap,
    required this.onDocumentTap,
    required this.onChatTap,
    required this.onSecurityTap,
    required this.onServiceTap,
    required this.onMiniAppsTap,
    required this.onScanQrTap,
  });

  @override
  Widget build(BuildContext context) {
    const hPad = EdgeInsets.symmetric(horizontal: ThixPolicy.s20);

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
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s16)),
        SliverToBoxAdapter(
          child: Padding(
            padding: hPad,
            child: HomeSearch(controller: searchController, isSearching: searching, onVerify: onSearchVerify),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s16)),
        SliverToBoxAdapter(
          child: Padding(
            padding: hPad,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                HomeHeadlinesCarousel(
                  controller: headlinesController,
                  uid: auth.currentUser?.id,
                  onThixInfoTap: () => context.push(AppRoutes.thixInfo),
                  onOpportunityTap: () => context.push(AppRoutes.opportunities),
                ),
                if (isAdmin)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _AdminBannerButton(isUploading: uploadingBanner, onTap: onAddBanner),
                  ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s16)),
        SliverToBoxAdapter(
          child: Padding(
            padding: hPad,
            child: HomeQuickActions(
              onScanTap: onScanTap,
              onDocumentTap: onDocumentTap,
              onChatTap: onChatTap,
              onSecurityTap: onSecurityTap,
              badgeCountsStream: badgeCountsStream,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s16)),
        // Constellation dans un panneau verre clair
        SliverToBoxAdapter(
          child: Padding(
            padding: hPad,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withOpacity(0.92), HomeTheme.skyMist.withOpacity(0.85)],
                ),
                border: Border.all(color: Colors.white, width: 1.4),
                boxShadow: HomeTheme.softShadow(0.09),
              ),
              child: StreamBuilder<SectionBadgeCounts>(
                stream: badgeCountsStream,
                builder: (context, snap) {
                  final counts = snap.data ?? SectionBadgeCounts.zero;
                  return HomeServicesConstellation(
                    counts: counts,
                    avatarUrl: photoUrl,
                    onServiceTap: onServiceTap,
                    onHomeTap: onProfileTap,
                    onMiniAppsTap: onMiniAppsTap,
                    onDocumentsTap: onDocumentTap,
                    onProfileTap: onProfileTap,
                    onScanTap: onScanQrTap,
                  );
                },
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s16)),
        const SliverToBoxAdapter(
          child: Padding(padding: hPad, child: HomePremiumCard()),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 110)),
      ],
    );
  }
}

// ============================================================================
// COMPOSANTS
// ============================================================================
class _AdminBannerButton extends StatelessWidget {
  final bool isUploading;
  final VoidCallback onTap;
  const _AdminBannerButton({required this.isUploading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).t('home_add_banner'),
      enabled: !isUploading,
      child: GestureDetector(
        onTap: isUploading ? null : onTap,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.95), width: 1.5),
              ),
              alignment: Alignment.center,
              child: isUploading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: HomeTheme.sky))
                  : const Icon(Icons.add_a_photo_rounded, size: 19, color: HomeTheme.skyDeep),
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

class _BannerUploadDialog extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController typeController;
  final bool isUploading;
  final VoidCallback onUpload;
  final VoidCallback onCancel;

  const _BannerUploadDialog({
    required this.titleController,
    required this.typeController,
    required this.isUploading,
    required this.onUpload,
    required this.onCancel,
  });

  InputDecoration _deco(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: HomeTheme.skyMist,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: HomeTheme.sky, width: 1.4)),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.96),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        title: Text(
          l10n.t('home_new_announcement'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: HomeTheme.ink),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, maxLength: _kMaxTitleLength, decoration: _deco(l10n.t('home_banner_title'))),
            const SizedBox(height: 10),
            TextField(controller: typeController, maxLength: _kMaxTagLength, decoration: _deco(l10n.t('home_banner_tag'))),
          ],
        ),
        actions: [
          TextButton(
            onPressed: isUploading ? null : onCancel,
            child: Text(l10n.t('home_cancel'), style: const TextStyle(color: HomeTheme.inkSoft)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: HomeTheme.skyDeep,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: isUploading ? null : onUpload,
            child: Text(l10n.t('home_choose_photo'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
