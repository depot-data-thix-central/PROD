// lib/presentation/dashboard/user_dashboard_page.dart
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/models/thix_profile.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/presentation/admin/admin_enterprise_certifications_page.dart';
import 'package:thix_id/presentation/certification/widgets/certification_name_badge.dart';
import 'package:thix_id/presentation/common/thix_identity_sheets.dart';
import 'package:thix_id/services/document_service.dart';
import 'package:thix_id/services/profile_service.dart';
import 'package:thix_id/services/user_service.dart';

import 'dashboard_editors.dart';
import 'dashboard_tabs.dart';
import 'dashboard_ui.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const int _kMaxRetries = 1;
const int _kCacheStaleMinutes = 5;
const int _kMaxDisplayNameLength = 60;
const int _kMaxBioLength = 200;
const int _kMaxThixIdLength = 50;
const int _kMaxCountryLength = 40;
const int _kMaxProfessionLength = 80;

// ============================================================================
// VALIDATORS
// ============================================================================
class _DashValidators {
  _DashValidators._();

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

  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final t = url.trim();
    if (!t.startsWith('http://') && !t.startsWith('https://')) return null;
    return t.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  static String friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('permission') || msg.contains('policy')) return 'Accès non autorisé.';
    if (msg.contains('not found')) return 'Ressource introuvable.';
    return 'Une erreur est survenue. Réessayez.';
  }

  static bool isAdminRole(String? role) {
    if (role == null) return false;
    return role.toLowerCase() == 'admin';
  }
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _dashRetry<T>(
  Future<T> Function() fn, {
  required String label,
  int maxRetries = _kMaxRetries,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(_kRequestTimeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[Dashboard] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[Dashboard] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[Dashboard] ❌ $label error: $e');
      rethrow;
    }
  }
}

/// ============================================================================
// CACHE (Singleton simple)
// ============================================================================
class DashboardCache {
  static final DashboardCache _instance = DashboardCache._internal();
  DashboardCache._internal();
  factory DashboardCache() => _instance;

  ThixProfile? _lastProfile;
  DateTime? _lastFetch;

  ThixProfile? get lastProfile => _lastProfile;

  bool get isStale {
    if (_lastFetch == null) return true;
    return DateTime.now().difference(_lastFetch!).inMinutes > _kCacheStaleMinutes;
  }

  void update(ThixProfile profile) {
    _lastProfile = profile;
    _lastFetch = DateTime.now();
  }

  void clear() {
    _lastProfile = null;
    _lastFetch = null;
  }
}


// ============================================================================
// STATE MANAGEMENT
// ============================================================================
class UserDashboardCtrl extends ChangeNotifier {
  final ProfileService profileService;
  final UserService userService;
  final DocumentService docsService;

  bool loading = true;
  String? error;
  ThixProfile? profile;
  AppUser? mergedUser;
  int score = 0;
  bool isAdmin = false;

  UserDashboardCtrl({
    required this.profileService,
    required this.userService,
    required this.docsService,
  });

  Future<void> init(AppUser authUser) async {
    debugPrint('[Dashboard] 🚀 Initializing for ${authUser.id.substring(0, 8)}...');

    unawaited(
      userService
          .logSecurityEvent('dashboard_open', 'Ouverture dashboard', metadata: {'uid': authUser.id})
          .catchError((e) => debugPrint('[Dashboard] ⚠️ Log event failed: $e')),
    );

    unawaited(profileService.ensureProfileExists(user: authUser).catchError((_) {}));
    unawaited(_loadAdminStatus(authUser.id));

    final cache = DashboardCache();
    if (!cache.isStale && cache.lastProfile != null) {
      profile = cache.lastProfile;
      _mergeAndCompute(authUser);
      loading = false;
      notifyListeners();
      unawaited(refreshSilently(authUser));
      return;
    }

    loading = true;
    error = null;
    notifyListeners();

    try {
      profile = await _dashRetry(
        () => profileService.fetchPublicProfileByUserId(authUser.id),
        label: 'fetchProfile',
      );
      profile ??= ThixProfile.fallback(
        userId: authUser.id,
        thixId: authUser.thixId,
        displayName: authUser.displayName,
      );

      cache.update(profile!);
      _mergeAndCompute(authUser);
      debugPrint('[Dashboard] ✓ Profile loaded');
    } catch (e) {
      debugPrint('[Dashboard] ❌ Init error: $e');
      error = _DashValidators.friendlyError(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadAdminStatus(String uid) async {
    try {
      final row = await _dashRetry(
        () => Supabase.instance.client.from('profiles').select('role').eq('id', uid).maybeSingle(),
        label: 'checkAdminStatus',
      );
      final role = row?['role']?.toString();
      isAdmin = _DashValidators.isAdminRole(role);
      debugPrint('[Dashboard] ✓ Admin check: $isAdmin');
      notifyListeners();
    } catch (e) {
      debugPrint('[Dashboard] ⚠️ Admin check failed: $e');
      isAdmin = false;
    }
  }

  Future<void> refreshSilently(AppUser authUser) async {
    try {
      final freshProfile = await _dashRetry(
        () => profileService.fetchPublicProfileByUserId(authUser.id),
        label: 'refreshProfile',
      );
      if (freshProfile != null) {
        profile = freshProfile;
        DashboardCache().update(freshProfile);
        _mergeAndCompute(authUser);
        notifyListeners();
        debugPrint('[Dashboard] ✓ Silent refresh');
      }
    } catch (e) {
      debugPrint('[Dashboard] ⚠️ Silent refresh failed: $e');
    }
  }

  void _mergeAndCompute(AppUser authUser) {
    if (profile == null) return;

    final profileThix = profile!.thixId.trim();
    final resolvedThixId = (profileThix.isNotEmpty && !profileThix.toUpperCase().startsWith('THIX-PENDING'))
        ? profileThix
        : authUser.thixId;

    mergedUser = authUser.copyWith(
      thixId: resolvedThixId,
      displayName: profile!.displayName,
      photoUrl: profile!.photoUrl,
      bio: profile!.bio,
      countryOrOrigin: profile!.countryOrOrigin,
      occupation: profile!.occupation,
      profession: profile!.profession,
      thixChat: profile!.thixChat,
      languages: profile!.languages,
    );

    score = authUser.thixScore ?? _computeScore(authUser, profile!);
  }

  int _computeScore(AppUser u, ThixProfile p) {
    var pts = 0;
    if (u.displayName.trim().isNotEmpty) pts += 10;
    if ((p.bio ?? '').trim().length > 40) pts += 15;
    if ((p.occupation ?? '').trim().isNotEmpty) pts += 10;
    if (p.education.isNotEmpty) pts += 20;
    if (p.experience.isNotEmpty) pts += 20;
    if (p.skills.isNotEmpty) pts += 15;
    if (p.languages.isNotEmpty) pts += 10;
    return pts.clamp(0, 100);
  }
}

// ============================================================================
// PAGE DASHBOARD
// ============================================================================
class ThixUserDashboardPage extends StatefulWidget {
  const ThixUserDashboardPage({super.key});

  @override
  State<ThixUserDashboardPage> createState() => _ThixUserDashboardPageState();
}

class _ThixUserDashboardPageState extends State<ThixUserDashboardPage> {
  late final ProfileService _profileService;
  late final UserService _userService;
  late final DocumentService _docsService;
  late final UserDashboardCtrl _ctrl;
  final _docFilter = ValueNotifier<String>('Tous');

  @override
  void initState() {
    super.initState();
    _profileService = ProfileService();
    _userService = UserService(Supabase.instance.client);
    _docsService = DocumentService();

    _ctrl = UserDashboardCtrl(
      profileService: _profileService,
      userService: _userService,
      docsService: _docsService,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final me = context.read<AuthController>().currentUser;
      if (me != null) _ctrl.init(me);
    });
  }

  @override
  void dispose() {
    _docFilter.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _confirmAndLogout() async {
    final l10n = AppLocalizations.of(context);
    HapticFeedback.mediumImpact();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ThixPolicy.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.logout_rounded, color: ThixPolicy.warning, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.t('dashboard_logout_title'),
                style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(l10n.t('dashboard_logout_confirm'), style: ThixPolicy.bodyStyle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.t('common_cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.danger,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.t('common_logout')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await context.read<AuthController>().signOut();
    if (mounted) {
      DashboardCache().clear();
      debugPrint('[Dashboard] 👋 User logged out');
      context.go(AppRoutes.home);
    }
  }

  void _openAdminPanel() {
    HapticFeedback.mediumImpact();
    debugPrint('[Dashboard] 🛡️ Opening admin panel');
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdminEnterpriseCertificationsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthController>().currentUser;
    if (me == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: ThixPolicy.primary)),
      );
    }

    return ChangeNotifierProvider.value(
      value: _ctrl,
      child: DefaultTabController(
        length: 5,
        child: Scaffold(
          backgroundColor: ThixPolicy.surfaceSoft,
          body: Consumer<UserDashboardCtrl>(
            builder: (context, ctrl, _) {
              if (ctrl.loading && ctrl.profile == null) {
                return Center(child: CircularProgressIndicator(color: ThixPolicy.primary));
              }

              if (ctrl.error != null && ctrl.profile == null) {
                return _ErrorState(
                  message: ctrl.error!,
                  onRetry: () => ctrl.init(me),
                );
              }

              final profile = ctrl.profile!;
              final mergedUser = ctrl.mergedUser!;
              final score = ctrl.score;

              return SafeArea(
                top: false,
                child: RefreshIndicator(
                  color: ThixPolicy.primary,
                  onRefresh: () => ctrl.refreshSilently(me),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: _CompactCoverHeader(
                          coverUrl: _DashValidators.sanitizeUrl(profile.photoUrl) ?? '',
                          avatarUrl: _DashValidators.sanitizeUrl(mergedUser.photoUrl) ?? '',
                          displayName: _DashValidators.sanitize(mergedUser.displayName, maxLength: _kMaxDisplayNameLength),
                          thixId: _DashValidators.sanitize(mergedUser.thixId, maxLength: _kMaxThixIdLength),
                          bio: _DashValidators.sanitize(mergedUser.bio ?? '', maxLength: _kMaxBioLength),
                          country: _DashValidators.sanitize(mergedUser.countryOrOrigin ?? '', maxLength: _kMaxCountryLength),
                          profession: _DashValidators.sanitize(
                            mergedUser.occupation ?? mergedUser.profession ?? '',
                            maxLength: _kMaxProfessionLength,
                          ),
                          score: score,
                          isAdmin: ctrl.isAdmin,
                          onBack: () {
                            HapticFeedback.selectionClick();
                            context.go(AppRoutes.home);
                          },
                          onSettings: () {
                            HapticFeedback.selectionClick();
                            context.push(AppRoutes.settings);
                          },
                          onLogout: _confirmAndLogout,
                          onAdminPanel: _openAdminPanel,
                          onEditProfile: () async {
                            HapticFeedback.selectionClick();
                            await ProfileEditorSheet.show(
                              context,
                              profile: profile,
                              profileService: _profileService,
                              authUser: me,
                            );
                            if (context.mounted) ctrl.refreshSilently(me);
                          },
                        ),
                      ),
                      const SliverToBoxAdapter(child: DashboardTabsHeader()),
                      SliverFillRemaining(
                        hasScrollBody: true,
                        child: TabBarView(
                          children: [
                            KeepAliveWrapper(
                              child: ProfileTab(
                                authUser: me,
                                profile: profile,
                                score: score,
                                profileService: _profileService,
                                userService: _userService,
                              ),
                            ),
                            KeepAliveWrapper(
                              child: ValueListenableBuilder(
                                valueListenable: _docFilter,
                                builder: (_, filter, __) => DocumentsTab(
                                  uid: me.id,
                                  docs: _docsService,
                                  userService: _userService,
                                  filter: filter,
                                  onChangeFilter: (v) => _docFilter.value = v,
                                ),
                              ),
                            ),
                            KeepAliveWrapper(
                              child: ExperienceSkillsTab(profile: profile, profileService: _profileService),
                            ),
                            KeepAliveWrapper(
                              child: PaymentsTab(uid: me.id, userService: _userService, user: me),
                            ),
                            KeepAliveWrapper(
                              child: SecurityTab(uid: me.id, user: me, userService: _userService),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              HapticFeedback.mediumImpact();
              ThixIdentitySheets.showQrScanSheet(context);
            },
            icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 18),
            label: Text(
              AppLocalizations.of(context).t('dashboard_scan_id'),
              style: ThixPolicy.labelStyle.copyWith(
                color: Colors.white,
                fontWeight: ThixPolicy.bold,
                fontSize: 13,
              ),
            ),
            backgroundColor: ThixPolicy.primary,
            elevation: 4,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ERROR STATE
// ============================================================================
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ThixPolicy.danger.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 48, color: ThixPolicy.danger),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.t('dashboard_error_title'),
              style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Semantics(
              button: true,
              label: l10n.t('common_retry'),
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  onRetry();
                },
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: Text(l10n.t('common_retry'), style: const TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// COMPACT COVER HEADER
// ============================================================================
class _CompactCoverHeader extends StatelessWidget {
  final String coverUrl;
  final String avatarUrl;
  final String displayName;
  final String thixId;
  final String bio;
  final String country;
  final String profession;
  final int score;
  final bool isAdmin;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final Future<void> Function() onLogout;
  final VoidCallback onEditProfile;
  final VoidCallback onAdminPanel;

  const _CompactCoverHeader({
    required this.coverUrl,
    required this.avatarUrl,
    required this.displayName,
    required this.thixId,
    required this.bio,
    required this.country,
    required this.profession,
    required this.score,
    required this.isAdmin,
    required this.onBack,
    required this.onSettings,
    required this.onLogout,
    required this.onEditProfile,
    required this.onAdminPanel,
  });

  bool get _hasCover => coverUrl.isNotEmpty;
  bool get _hasAvatar => avatarUrl.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final topPad = MediaQuery.of(context).padding.top;

    return RepaintBoundary(
      child: Column(
        children: [
          // Zone couverture
          SizedBox(
            height: topPad + 130,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_hasCover)
                  CachedNetworkImage(
                    imageUrl: coverUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _fallbackCover(),
                    errorWidget: (_, __, ___) => _fallbackCover(),
                  )
                else
                  _fallbackCover(),

                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withOpacity(0.35), Colors.black.withOpacity(0.05)],
                    ),
                  ),
                ),

                Positioned(
                  top: topPad + 8,
                  left: 12,
                  right: 12,
                  child: Row(
                    children: [
                      _RoundIconBtn(
                        icon: Icons.arrow_back_ios_new_rounded,
                        semanticsLabel: l10n.t('common_back'),
                        onTap: onBack,
                      ),
                      const Spacer(),
                      if (isAdmin) ...[
                        _RoundIconBtn(
                          icon: Icons.admin_panel_settings_rounded,
                          semanticsLabel: l10n.t('dashboard_admin_panel'),
                          onTap: onAdminPanel,
                        ),
                        const SizedBox(width: 8),
                      ],
                      _RoundIconBtn(
                        icon: Icons.logout_rounded,
                        semanticsLabel: l10n.t('common_logout'),
                        onTap: () => onLogout(),
                      ),
                      const SizedBox(width: 8),
                      _RoundIconBtn(
                        icon: Icons.settings_rounded,
                        semanticsLabel: l10n.t('dashboard_settings'),
                        onTap: onSettings,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Carte profil
          Transform.translate(
            offset: const Offset(0, -36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: ThixPolicy.shadowSoft(opacity: 0.12),
                        ),
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: ThixPolicy.surfaceSoft,
                          backgroundImage: _hasAvatar ? CachedNetworkImageProvider(avatarUrl) : null,
                          child: !_hasAvatar
                              ? const Icon(Icons.person, size: 36, color: ThixPolicy.textMuted)
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: ThixPolicy.primary,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Text(
                            '$score ${l10n.t('dashboard_pts')}',
                            style: ThixPolicy.captionStyle.copyWith(
                              color: Colors.white,
                              fontWeight: ThixPolicy.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          displayName.isEmpty ? l10n.t('dashboard_user_default') : displayName,
                          style: ThixPolicy.titleStyle.copyWith(
                            fontWeight: ThixPolicy.bold,
                            fontSize: 18,
                            color: ThixPolicy.primaryDeep,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const CertificationNameBadge(showLabel: false, iconSize: 20, padding: EdgeInsets.only(left: 6)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    thixId.isEmpty ? '—' : thixId,
                    style: ThixPolicy.captionStyle.copyWith(
                      fontSize: 11,
                      color: ThixPolicy.textMuted,
                      fontWeight: ThixPolicy.semiBold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  if (bio.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        bio,
                        style: ThixPolicy.captionStyle.copyWith(
                          fontSize: 11.5,
                          color: ThixPolicy.textMain,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    Text(
                      l10n.t('dashboard_bio_empty'),
                      style: ThixPolicy.captionStyle.copyWith(
                        fontSize: 11.5,
                        color: ThixPolicy.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (country.isNotEmpty) ...[
                        const Icon(Icons.location_on_outlined, size: 13, color: ThixPolicy.textMuted),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            country,
                            style: ThixPolicy.captionStyle.copyWith(fontSize: 11, color: ThixPolicy.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (country.isNotEmpty && profession.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text('•', style: TextStyle(color: Colors.black38)),
                        ),
                      if (profession.isNotEmpty) ...[
                        const Icon(Icons.work_outline_rounded, size: 13, color: ThixPolicy.textMuted),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            profession,
                            style: ThixPolicy.captionStyle.copyWith(fontSize: 11, color: ThixPolicy.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Semantics(
                    button: true,
                    label: l10n.t('dashboard_edit_profile'),
                    child: SizedBox(
                      height: 34,
                      child: OutlinedButton.icon(
                        onPressed: onEditProfile,
                        icon: const Icon(Icons.edit_rounded, size: 14),
                        label: Text(
                          l10n.t('dashboard_edit_profile'),
                          style: ThixPolicy.captionStyle.copyWith(
                            fontSize: 12,
                            fontWeight: ThixPolicy.semiBold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ThixPolicy.primary,
                          side: BorderSide(color: ThixPolicy.primary.withOpacity(0.3)),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackCover() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ThixPolicy.primary, ThixPolicy.primaryDeep],
        ),
      ),
    );
  }
}

// ============================================================================
// ROUND ICON BUTTON
// ============================================================================
class _RoundIconBtn extends StatelessWidget {
  final IconData icon;
  final String semanticsLabel;
  final VoidCallback onTap;

  const _RoundIconBtn({
    required this.icon,
    required this.semanticsLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Material(
        color: Colors.white.withOpacity(0.92),
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 16, color: ThixPolicy.primaryDeep),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// KEEP ALIVE WRAPPER
// ============================================================================
class KeepAliveWrapper extends StatefulWidget {
  final Widget child;

  const KeepAliveWrapper({super.key, required this.child});

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
