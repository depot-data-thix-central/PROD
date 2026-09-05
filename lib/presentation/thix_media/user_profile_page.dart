// lib/presentation/thix_media/user_profile_page.dart
/// UserProfilePage (Production Enterprise)
///
/// - Design : Modern Sleek Light (Glassmorphism, clair, épuré)
/// - Sécurité : Sanitization des noms, gestion stricte des états de chargement
/// - i18n : Fallbacks automatiques (anti-clés brutes)
/// - UX : HapticFeedback, RepaintBoundary, Pull-to-refresh optimisé

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

// ============================================================================
// LOGGING
// ============================================================================

class _ProfileLogger {
  static const _tag = 'UserProfile';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);
  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d != null ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}' : '';
    debugPrint('[$_tag] [$l] $m$data');
  }
}

// ============================================================================
// PAGE
// ============================================================================

class UserProfilePage extends ConsumerStatefulWidget {
  final String userId;
  const UserProfilePage({super.key, required this.userId});

  @override
  ConsumerState<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends ConsumerState<UserProfilePage> {
  
  @override
  void initState() {
    super.initState();
    _ProfileLogger.info('Page initialized', {'userId': widget.userId});
  }

  // ✅ TEXTES DE SECOURS (ANTI CLÉS BRUTES)
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
      _ProfileLogger.info('Profile refreshed');
    } catch (e) {
      _ProfileLogger.error('Refresh failed', {'error': '$e'});
    }
  }

  String _getTitle(UserProfileBundle bundle, AppLocalizations l10n) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == widget.userId) return _safeTr(l10n, 'profile_my_profile', 'Mon Profil');
    
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
        leading: Semantics(
          button: true,
          label: _safeTr(l10n, 'common_back', 'Retour'),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: MediaLightPalette.textPrimary, size: 20),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
          ),
        ),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: MediaConfig.glassBlur, sigmaY: MediaConfig.glassBlur),
            child: Container(
              decoration: BoxDecoration(
                color: MediaLightPalette.surface.withValues(alpha: 0.85),
                border: const Border(bottom: BorderSide(color: MediaLightPalette.border)),
              ),
            ),
          ),
        ),
        title: profileAsync.whenOrNull(
          data: (bundle) => Text(
            _getTitle(bundle, l10n),
            style: const TextStyle(color: MediaLightPalette.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ) ?? Text(_safeTr(l10n, 'nav_profile', 'Profil'), style: const TextStyle(color: MediaLightPalette.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: profileAsync.when(
        loading: () => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: ThixPolicy.primary),
              const SizedBox(height: 16),
              Text(_safeTr(l10n, 'profile_loading', 'Chargement du profil...'), style: const TextStyle(color: MediaLightPalette.textSecondary, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        error: (e, _) => _buildErrorState(l10n, e.toString()),
        data: (bundle) {
          if (bundle.hasError || bundle.profile == null) {
            return _buildNotFoundState(l10n, bundle.error ?? _safeTr(l10n, 'profile_not_found', 'Profil introuvable'));
          }
          return _buildProfileContent(bundle, l10n);
        },
      ),
    );
  }

  Widget _buildErrorState(AppLocalizations l10n, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: ThixPolicy.danger.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded, color: ThixPolicy.danger, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              _safeTr(l10n, 'profile_load_error', 'Une erreur est survenue.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: MediaLightPalette.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: MediaLightPalette.textMuted, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refresh,
              style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white, elevation: 0),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(_safeTr(l10n, 'common_retry', 'Réessayer')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFoundState(AppLocalizations l10n, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: MediaLightPalette.border, shape: BoxShape.circle),
              child: const Icon(Icons.person_off_rounded, color: MediaLightPalette.textSecondary, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: MediaLightPalette.textSecondary, fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: MediaLightPalette.textPrimary, foregroundColor: Colors.white, elevation: 0),
              child: Text(_safeTr(l10n, 'common_back', 'Retour')),
            ),
          ],
        ),
      ),
    );
  }

    Widget _buildProfileContent(UserProfileBundle bundle, AppLocalizations l10n) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isMe = currentUserId == widget.userId;

    return RefreshIndicator(
      onRefresh: _refresh,
      color: ThixPolicy.primary,
      backgroundColor: MediaLightPalette.surface,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: RepaintBoundary(
                child: ProfileHeaderWidget(
                  profile: bundle.profile!,
                  stats: bundle.stats,
                  isFollowing: bundle.isFollowing,
                  isMe: isMe,
                  onEditProfile: () {
                    HapticFeedback.selectionClick();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_safeTr(l10n, 'profile_edit_soon', 'L\'édition du profil sera bientôt disponible')),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: ThixPolicy.primary,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // Séparateur + Titre "Publications"
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: MediaLightPalette.border, width: 1.5)),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12, right: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.grid_view_rounded, color: MediaLightPalette.textPrimary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _safeTr(l10n, 'profile_posts', 'Publications'),
                          style: const TextStyle(color: MediaLightPalette.textPrimary, fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          
          ProfileVideosGrid(userId: widget.userId),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

