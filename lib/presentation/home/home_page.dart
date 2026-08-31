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

import 'package:thix_id/core/theme/thix_design_policy.dart';

import 'widgets/home_background.dart';
import 'widgets/home_header_delegate.dart';
import 'widgets/home_search.dart';
import 'widgets/home_headlines_carousel.dart';
import 'widgets/home_quick_actions.dart';
import 'widgets/home_services_constellation.dart';
import 'widgets/home_premium_card.dart';
import 'widgets/home_personalised.dart';
import 'widgets/account_request_sheet.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 20);
const Duration _kUploadTimeout = Duration(seconds: 60);
const Duration _kRetryDelay = Duration(milliseconds: 500);
const int _kMaxRetries = 2;
const int _kMaxFileSizeBytes = 5 * 1024 * 1024; // 5MB max
const int _kMaxTitleLength = 100;
const int _kMaxTagLength = 30;
const int _kMinImageWidth = 800;
const int _kMinImageHeight = 400;
const double _kMaxAspectRatio = 2.5; // 2.5:1 max
const List<String> _kAllowedMimeTypes = ['image/jpeg', 'image/png', 'image/webp'];

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
    // UUID v4 format
    return RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$').hasMatch(uid.trim());
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
    final ext = extension.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'webp'].contains(ext);
  }

  static bool isValidFileSize(int bytes) {
    return bytes > 0 && bytes <= _kMaxFileSizeBytes;
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static Future<bool> isValidImage(Uint8List bytes) async {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return false;
      
      final width = image.width;
      final height = image.height;
      
      if (width < _kMinImageWidth || height < _kMinImageHeight) {
        return false;
      }
      
      final aspectRatio = width / height;
      if (aspectRatio > _kMaxAspectRatio || aspectRatio < 1 / _kMaxAspectRatio) {
        return false;
      }
      
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

// ============================================================================
// HELPERS
// ============================================================================
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
      debugPrint('[HomePage] ⏱️ $label timeout — retry $attempt/$maxRetries');
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
    debugPrint('[HomePage] 🏠 Page opened');
    _checkAdminRole();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _headlinesController.dispose();
    debugPrint('[HomePage] 👋 Page disposed');
    super.dispose();
  }

  // ============================================================
  // ADMIN ROLE CHECK
  // ============================================================
  Future<void> _checkAdminRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final data = await _homeRetry(
        () => Supabase.instance.client
            .from('profiles')
            .select('role, account_type')
            .eq('id', user.id)
            .maybeSingle(),
        label: 'checkAdminRole',
      );

      if (!mounted) return;

      if (data != null) {
        final role = (data['role'] ?? data['account_type'] ?? '').toString().toLowerCase();
        final isAdmin = role == 'admin' || role == 'entreprise' || role == 'support';
        setState(() => _isAdmin = isAdmin);
        debugPrint('[HomePage] ✓ Admin check: $isAdmin (role=$role)');
      }
    } catch (e) {
      debugPrint('[HomePage] ⚠️ Admin check failed (non-critical): $e');
    }
  }

  // ============================================================
  // ADMIN: ADD BANNER
  // ============================================================
  Future<void> _showAddBannerDialog() async {
    if (!_isAdmin) {
      debugPrint('[HomePage] ⚠️ Non-admin tried to access banner upload');
      return;
    }

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
  }

  Future<void> _pickAndUploadBanner(String title, String type) async {
    if (!_isAdmin) return;

    final l10n = AppLocalizations.of(context);

    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result == null || result.files.isEmpty) {
        debugPrint('[HomePage] ℹ️ Banner upload cancelled');
        return;
      }

      final file = result.files.first;
      
      // Validation 1: Type de fichier
      if (!_HomeValidators.isValidFileType(file.extension)) {
        _showError(l10n.t('home_banner_invalid_type'));
        return;
      }

      // Validation 2: Taille
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

      // Validation 3: Image valide (dimensions, format)
      final isValidImage = await _HomeValidators.isValidImage(bytes);
      if (!isValidImage) {
        _showError(l10n.t('home_banner_invalid_dimensions'));
        return;
      }

      // Sanitization des inputs
      final sanitizedTitle = _HomeValidators.sanitize(
        title.isEmpty ? l10n.t('home_banner_default_title') : title,
        maxLength: _kMaxTitleLength,
      );
      final sanitizedType = _HomeValidators.sanitize(
        type.isEmpty ? l10n.t('home_banner_default_tag') : type,
        maxLength: _kMaxTagLength,
      );

      setState(() => _uploadingBanner = true);
      debugPrint('[HomePage] 📤 Uploading banner (${_HomeValidators.formatFileSize(bytes.length)})');

      final ext = file.extension ?? 'jpg';
      final fileName = 'banner_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storagePath = 'annonces/$fileName';

      // Upload Storage avec timeout
      await _homeRetry(
        () => Supabase.instance.client.storage
            .from('banners')
            .uploadBinary(storagePath, bytes),
        label: 'uploadBanner',
        timeout: _kUploadTimeout,
      );

      final publicUrl = Supabase.instance.client.storage
          .from('banners')
          .getPublicUrl(storagePath);

      // Insert DB avec timeout
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

      if (mounted) {
        _showSuccess(l10n.t('home_banner_uploaded'));
      }
      debugPrint('[HomePage] ✓ Banner uploaded: $fileName');
    } catch (e) {
      debugPrint('[HomePage] ❌ Banner upload error: $e');
      if (mounted) _showError(_HomeValidators.friendlyError(e));
    } finally {
      if (mounted) setState(() => _uploadingBanner = false);
    }
  }

  // ============================================================
  // SEARCH & VERIFY
  // ============================================================
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
    debugPrint('[HomePage] 🔍 Verifying ${isThix ? "THIX ID" : "UID"}');

    try {
      ThixProfile? profile;
      if (isThix) {
        profile = await _homeRetry(
          () => _profileService.fetchPublicProfileByThixId(normalized),
          label: 'fetchProfileByThixId',
        );
      } else {
        profile = await _homeRetry(
          () => _profileService.fetchPublicProfileByUserId(raw),
          label: 'fetchProfileByUid',
        );
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

  // ============================================================
  // NAVIGATION & ACTIONS
  // ============================================================
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
    if (auth.isAuthenticated) {
      context.push('/thix-ia');
    } else {
      context.push(AppRoutes.login);
    }
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
    if (auth.isAuthenticated) {
      context.push('/home-swipe');
    } else {
      if (!mounted) return;
      context.push(AppRoutes.login);
    }
  }

  void _openDocumentVault() {
    HapticFeedback.selectionClick();
    final auth = context.read<AuthController>();
    if (auth.isAuthenticated) {
      context.push(AppRoutes.vault);
    } else {
      context.push(AppRoutes.login);
    }
  }

  void _openScanQr() {
    HapticFeedback.selectionClick();
    ThixIdentitySheets.showQrScanSheet(context);
  }

  void _openMiniApps() {
    HapticFeedback.selectionClick();
    final l10n = AppLocalizations.of(context);
    _showInfo(l10n.t('home_mini_apps_coming_soon'));
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
        if (auth.isAuthenticated) {
          await auth.signOut();
        }
        if (mounted) {
          context.push(AppRoutes.personalReg);
        }
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
      if (section != null) {
        _counters.markSectionSeen(uid: uid, section: section);
      }
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
      case 'thixMedia': return ThixSection.media;
      case 'thixMarket': return ThixSection.market;
      case 'formations': return ThixSection.formations;
      case 'emplois': return ThixSection.jobs;
      case 'thixInfo': return ThixSection.info;
      case 'opportunites': return ThixSection.opportunities;
      case 'evenements': return ThixSection.events;
      case 'reseauPro': return ThixSection.network;
      case 'thixSante': return ThixSection.health;
      case 'thixMoney': return ThixSection.money;
      case 'monPays': return ThixSection.monPays;
      case 'reservation': return ThixSection.reservation;
      default: return null;
    }
  }

  String? _getServiceRoute(String key) {
    switch (key) {
      case 'thixMedia': return AppRoutes.thixMedia;
      case 'thixMarket': return AppRoutes.thixMarket;
      case 'formations': return AppRoutes.trainingHome;
      case 'emplois': return AppRoutes.jobs;
      case 'thixInfo': return AppRoutes.thixInfo;
      case 'opportunites': return AppRoutes.opportunities;
      case 'evenements': return '/thix-event';
      case 'reseauPro': return 'go:${AppRoutes.network}';
      case 'thixSante': return AppRoutes.thixSante;
      case 'thixMoney': return AppRoutes.thixMoney;
      case 'monPays': return AppRoutes.monPays;
      case 'reservation': return AppRoutes.reservation;
      case 'thixRetrouve': return '/home-swipe';
      default: return null;
    }
  }

  // ============================================================
  // FEEDBACK
  // ============================================================
  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.warning,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
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
      backgroundColor: ThixPolicy.surfaceSoft,
      body: Stack(
        children: [
          _HomeBackground(),
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
          if (_searching) _SearchingOverlay(),
        ],
      ),
    );
  }
}

// ============================================================================
// COMPOSANTS
// ============================================================================

class _HomeBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -50,
          child: _BlurOrb(color: ThixPolicy.primary.withOpacity(0.04), size: 300),
        ),
        Positioned(
          bottom: 200,
          left: -100,
          child: _BlurOrb(color: ThixPolicy.primaryDeep.withOpacity(0.03), size: 350),
        ),
        const HomeSoftBackground(),
      ],
    );
  }
}

class _BlurOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _BlurOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}

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
        const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s12)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
            child: HomeSearch(
              controller: searchController,
              isSearching: searching,
              onVerify: onSearchVerify,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s12)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
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
                    child: _AdminBannerButton(
                      isUploading: uploadingBanner,
                      onTap: onAddBanner,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s12)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
            child: HomeQuickActions(
              onScanTap: onScanTap,
              onDocumentTap: onDocumentTap,
              onChatTap: onChatTap,
              onSecurityTap: onSecurityTap,
              badgeCountsStream: badgeCountsStream,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s12)),
        SliverToBoxAdapter(
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
        const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s12)),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
            child: HomePremiumCard(),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s12)),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
            child: HomePersonalised(),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 4)),
                ],
              ),
              child: isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary),
                    )
                  : const Icon(Icons.add_a_photo_rounded, size: 20, color: ThixPolicy.primaryDeep),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchingOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Colors.white.withOpacity(0.6),
            child: const Center(
              child: CircularProgressIndicator(color: ThixPolicy.primary),
            ),
          ),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.8)),
        ),
        title: Text(
          l10n.t('home_new_announcement'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: ThixPolicy.textMain),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              maxLength: _kMaxTitleLength,
              decoration: InputDecoration(
                labelText: l10n.t('home_banner_title'),
                filled: true,
                fillColor: Colors.white.withOpacity(0.5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: typeController,
              maxLength: _kMaxTagLength,
              decoration: InputDecoration(
                labelText: l10n.t('home_banner_tag'),
                filled: true,
                fillColor: Colors.white.withOpacity(0.5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: isUploading ? null : onCancel,
            child: Text(l10n.t('home_cancel'), style: const TextStyle(color: ThixPolicy.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: isUploading ? null : onUpload,
            child: Text(l10n.t('home_choose_photo'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
