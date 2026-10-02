// lib/presentation/thix_media/user_profile_page.dart
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

import 'thix_media_page.dart' show MediaConfig, MediaLightPalette, MediaSanitizer;
import 'widgets/profile_header_widget.dart';
import 'widgets/profile_videos_grid.dart';
import 'providers/user_profile_providers.dart';

class _ProfileLogger {
  static const _tag = 'UserProfile';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);
  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d == null ? '' : ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}';
    debugPrint('[$_tag] [$l] $m$data');
  }
}

class UserProfilePage extends ConsumerStatefulWidget {
  final String userId;
  const UserProfilePage({super.key, required this.userId});

  @override
  ConsumerState<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends ConsumerState<UserProfilePage> {
  bool _showPrivate = false;
  
  // ✅ Certification chargée en direct
  String? _certTier;
  bool _isCertified = false;
  bool _certLoaded = false;

  @override
  void initState() {
    super.initState();
    _ProfileLogger.info('Page initialized', {'userId': widget.userId});
    _loadCertification();
  }

  @override
  void didUpdateWidget(covariant UserProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _loadCertification();
    }
  }

  // ✅ CHARGEMENT ROBUSTE DE LA CERTIFICATION
  Future<void> _loadCertification() async {
    final client = Supabase.instance.client;
    String? tier;
    String? status;

    try {
      // 1) Essayer depuis profiles
      final p = await client
          .from('profiles')
          .select('certification_tier, certification_status')
          .eq('id', widget.userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));

      tier = (p?['certification_tier'] as String?)?.trim();
      status = (p?['certification_status'] as String?)?.trim().toLowerCase();
      
      _ProfileLogger.info('Cert from profiles', {'tier': tier, 'status': status});

      // 2) Fallback : table certifications
      if ((tier == null || tier.isEmpty) && (status == null || status.isEmpty)) {
        final c = await client
            .from('certifications')
            .select('tier, status')
            .eq('user_id', widget.userId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle()
            .timeout(const Duration(seconds: 3));
        if (c != null) {
          tier = (c['tier'] as String?)?.trim();
          status = (c['status'] as String?)?.trim().toLowerCase();
          _ProfileLogger.info('Cert from certifications', {'tier': tier, 'status': status});
        }
      }

      // 3) Fallback : table certification_requests
      if ((tier == null || tier.isEmpty) && (status == null || status.isEmpty)) {
        final r = await client
            .from('certification_requests')
            .select('tier, status')
            .eq('user_id', widget.userId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle()
            .timeout(const Duration(seconds: 3));
        if (r != null) {
          tier = (r['tier'] as String?)?.trim();
          status = (r['status'] as String?)?.trim().toLowerCase();
          _ProfileLogger.info('Cert from certification_requests', {'tier': tier, 'status': status});
        }
      }
    } catch (e) {
      _ProfileLogger.error('Cert load failed', {'error': '$e'});
    }

    if (!mounted) return;

    // Test tolérant : toute valeur "positive" active le badge
    const okStatus = {'approved', 'generated', 'active', 'verified', 'paid', 'valid'};
    final hasTier = tier != null && 
                    tier.isNotEmpty && 
                    tier.toLowerCase() != 'free' &&
                    tier.toLowerCase() != 'none';
    final isCert = hasTier || (status != null && okStatus.contains(status));

    setState(() {
      _certTier = tier;
      _isCertified = isCert;
      _certLoaded = true;
    });

    _ProfileLogger.info('Cert final', {
      'tier': tier,
      'isCertified': isCert,
    });
  }

  String _safeTr(AppLocalizations l10n, String key, String fallback) {
    final val = l10n.t(key);
    if (val.isEmpty || val == key || val.contains(key)) return fallback;
    return val;
  }

  Future<void> _refresh() async {
    HapticFeedback.mediumImpact();
    try {
      ref.invalidate(userProfileDataProvider(widget.userId));
      ref.invalidate(userPostsProvider(widget.userId));
      ref.invalidate(userPrivatePostsProvider(widget.userId));
      await _loadCertification();
    } catch (e) {
      _ProfileLogger.error('Refresh failed', {'error': '$e'});
    }
  }

  String _getTitle(UserProfileBundle bundle, AppLocalizations l10n) {
    if (Supabase.instance.client.auth.currentUser?.id == widget.userId) {
      return _safeTr(l10n, 'profile_my_profile', 'Mon Profil');
    }
    final fname = bundle.profile?['full_name'] as String?;
    final uname = bundle.profile?['username'] as String?;
    if (fname != null && fname.trim().isNotEmpty) {
      return MediaSanitizer.text(fname, maxLength: 30);
    }
    if (uname != null && uname.trim().isNotEmpty) {
      return MediaSanitizer.text(uname, maxLength: 30);
    }
    return _safeTr(l10n, 'nav_profile', 'Profil');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profileAsync = ref.watch(userProfileDataProvider(widget.userId));

    return Scaffold(
      backgroundColor: MediaLightPalette.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: MediaLightPalette.textPrimary, size: 20),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
        ),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(
                sigmaX: MediaConfig.glassBlur, sigmaY: MediaConfig.glassBlur),
            child: Container(
              decoration: BoxDecoration(
                color: MediaLightPalette.surface.withValues(alpha: 0.85),
                border: const Border(
                    bottom: BorderSide(color: MediaLightPalette.border)),
              ),
            ),
          ),
        ),
        title: profileAsync.whenOrNull(
              data: (bundle) => Text(_getTitle(bundle, l10n),
                  style: const TextStyle(
                      color: MediaLightPalette.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
            ) ??
            Text(_safeTr(l10n, 'nav_profile', 'Profil'),
                style: const TextStyle(
                    color: MediaLightPalette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: profileAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: ThixPolicy.primary)),
        error: (e, _) => _buildErrorState(l10n, e.toString()),
        data: (bundle) {
          if (bundle.hasError || bundle.profile == null) {
            return _buildNotFoundState(l10n, bundle.error ?? 'Introuvable');
          }
          return _buildProfileContent(bundle, l10n);
        },
      ),
    );
  }

  Widget _buildErrorState(AppLocalizations l10n, String error) =>
      Center(child: Text(error));

  Widget _buildNotFoundState(AppLocalizations l10n, String message) =>
      Center(child: Text(message));

  Widget _buildProfileContent(UserProfileBundle bundle, AppLocalizations l10n) {
    final isMe = Supabase.instance.client.auth.currentUser?.id == widget.userId;

    return RefreshIndicator(
      onRefresh: _refresh,
      color: ThixPolicy.primary,
      backgroundColor: MediaLightPalette.surface,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: ProfileHeaderWidget(
                profile: bundle.profile!,
                stats: bundle.stats,
                isFollowing: bundle.isFollowing,
                isMe: isMe,
                certTier: _certTier,       // ✅ Utilise la valeur chargée en direct
                isCertified: _isCertified, // ✅ Utilise la valeur chargée en direct
                onEditProfile: () {},
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: isMe ? _buildTabs(l10n) : _buildPublicTitle(l10n),
          ),
          ProfileVideosGrid(
            userId: widget.userId,
            isOwner: isMe,
            showPrivate: _showPrivate,
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildPublicTitle(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
          border: Border(
              bottom: BorderSide(color: MediaLightPalette.border, width: 1.5))),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12, right: 16),
        child: Row(
          children: [
            const Icon(Icons.grid_view_rounded,
                color: MediaLightPalette.textPrimary, size: 18),
            const SizedBox(width: 8),
            Text(_safeTr(l10n, 'profile_posts', 'Publications'),
                style: const TextStyle(
                    color: MediaLightPalette.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: MediaLightPalette.border.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildTabButton(
                title: _safeTr(l10n, 'profile_tab_public', 'Publiques'),
                icon: Icons.public_rounded,
                isSelected: !_showPrivate,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _showPrivate = false);
                },
              ),
            ),
            Expanded(
              child: _buildTabButton(
                title: _safeTr(l10n, 'profile_tab_private', 'Privées'),
                icon: Icons.lock_outline_rounded,
                isSelected: _showPrivate,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _showPrivate = true);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? MediaLightPalette.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: isSelected
                    ? MediaLightPalette.textPrimary
                    : MediaLightPalette.textSecondary),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? MediaLightPalette.textPrimary
                    : MediaLightPalette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
