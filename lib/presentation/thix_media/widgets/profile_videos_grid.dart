// lib/presentation/thix_media/widgets/profile_videos_grid.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import '../thix_media_page.dart' show MediaLightPalette;
import 'profile_video_card.dart';
import '../providers/user_profile_providers.dart';

const Duration _kScrollDebounce = Duration(milliseconds: 200);
const Duration _kRefreshThrottle = Duration(seconds: 2);
const double _kScrollThreshold = 200.0;
const int _kGridCrossAxisCount = 3;
const double _kGridChildAspectRatio = 0.65;

class ProfileVideosGrid extends ConsumerStatefulWidget {
  final String userId;
  final bool isOwner;
  final bool showPrivate;

  const ProfileVideosGrid({
    super.key, 
    required this.userId,
    this.isOwner = false,
    this.showPrivate = false,
  });

  @override
  ConsumerState<ProfileVideosGrid> createState() => _ProfileVideosGridState();
}

class _ProfileVideosGridState extends ConsumerState<ProfileVideosGrid> {
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollDebounce;
  DateTime? _lastRefresh;

  AutoDisposeStateNotifierProviderFamily<UserPostsNotifier, AsyncValue<UserPostsState>, String> get _provider {
    return widget.showPrivate ? userPrivatePostsProvider : userPostsProvider;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollDebounce?.cancel();
    super.dispose();
  }

  String _safeTr(AppLocalizations l10n, String key, String fallback) {
    final val = l10n.t(key);
    if (val.isEmpty || val == key || val.contains(key)) return fallback;
    return val;
  }

  void _onScroll() {
    _scrollDebounce?.cancel();
    _scrollDebounce = Timer(_kScrollDebounce, () {
      if (!mounted || !_scrollController.hasClients) return;
      final pos = _scrollController.position;
      if (pos.pixels >= pos.maxScrollExtent - _kScrollThreshold) {
        HapticFeedback.lightImpact();
        ref.read(_provider(widget.userId).notifier).loadMore();
      }
    });
  }

  void _refresh() {
    final now = DateTime.now();
    if (_lastRefresh != null && now.difference(_lastRefresh!) < _kRefreshThrottle) return;
    _lastRefresh = now;
    HapticFeedback.mediumImpact();
    ref.read(_provider(widget.userId).notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(_provider(widget.userId));

    return postsAsync.when(
      loading: () => SliverToBoxAdapter(child: _buildEmptyState(context, loading: true)),
      error: (e, _) => SliverToBoxAdapter(child: _buildErrorState(context, e)),
      data: (state) {
        if (state.posts.isEmpty) {
          return SliverToBoxAdapter(child: _buildEmptyState(context));
        }
        final itemCount = state.posts.length + (state.hasMore ? 1 : 0);

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _kGridCrossAxisCount,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: _kGridChildAspectRatio,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == state.posts.length) return const _LoadingIndicator();
                return RepaintBoundary(
                  child: ProfileVideoCard(
                    post: state.posts[index],
                    ownerUserId: widget.userId,
                    isOwner: widget.isOwner,
                  ),
                );
              },
              childCount: itemCount,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, {bool loading = false}) {
    final l10n = AppLocalizations.of(context);
    
    String title;
    IconData icon;
    String? subtitle;

    if (loading) {
      title = _safeTr(l10n, 'profile_loading', 'Chargement...');
      icon = Icons.hourglass_empty_rounded;
    } else if (widget.showPrivate) {
      title = _safeTr(l10n, 'profile_no_private_posts', 'Aucune vidéo privée');
      icon = Icons.lock_outline_rounded;
      subtitle = _safeTr(l10n, 'profile_no_private_hint', 'Vos vidéos privées apparaîtront ici');
    } else {
      title = _safeTr(l10n, 'profile_no_posts', 'Aucune publication');
      icon = Icons.video_library_rounded;
      subtitle = widget.isOwner 
          ? _safeTr(l10n, 'profile_no_posts_hint_owner', 'Créez votre première vidéo')
          : _safeTr(l10n, 'profile_no_posts_hint_other', 'Cet utilisateur n\'a pas encore publié');
    }

    return Padding(
      padding: const EdgeInsets.only(top: 60, bottom: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MediaLightPalette.border.withOpacity(0.5),
              ),
              child: loading
                  ? const SizedBox(
                      width: 48, 
                      height: 48, 
                      child: CircularProgressIndicator(
                        color: ThixPolicy.primary, 
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(icon, size: 48, color: MediaLightPalette.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(
              title, 
              style: const TextStyle(
                color: MediaLightPalette.textPrimary, 
                fontSize: 16, 
                fontWeight: FontWeight.w800,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle, 
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: MediaLightPalette.textSecondary, 
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (widget.isOwner && !loading && !widget.showPrivate) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: Naviguer vers la page de création
                  HapticFeedback.mediumImpact();
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(_safeTr(l10n, 'profile_create_first', 'Créer une vidéo')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 60, bottom: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ThixPolicy.danger.withOpacity(0.1),
              ),
              child: const Icon(
                Icons.error_outline_rounded, 
                color: ThixPolicy.danger, 
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _safeTr(l10n, 'profile_load_error', 'Erreur de chargement'), 
              style: const TextStyle(
                color: MediaLightPalette.textPrimary, 
                fontSize: 16, 
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _safeTr(l10n, 'profile_load_error_hint', 'Vérifiez votre connexion'),
              style: const TextStyle(
                color: MediaLightPalette.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(_safeTr(l10n, 'common_retry', 'Réessayer')),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary, 
                foregroundColor: Colors.white, 
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: ThixPolicy.primary, 
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }
}
