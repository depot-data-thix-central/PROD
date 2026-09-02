/// ProfileVideosGrid (Production Enterprise)
/// ThixPolicy + i18n 8 langues + Semantics + logs structurés
/// Debounce 200ms + throttle refresh + mounted checks
/// Error sanitization + RepaintBoundary + empty state accessible
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/media_content.dart';

import 'profile_video_card.dart';
import '../providers/user_profile_providers.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const Duration _kScrollDebounce = Duration(milliseconds: 200);
const Duration _kRefreshThrottle = Duration(seconds: 2);
const double _kScrollThreshold = 200.0;
const int _kGridCrossAxisCount = 3;
const double _kGridChildAspectRatio = 0.65;

// ============================================================================
// LOGGING
// ============================================================================

class _GridLogger {
  static const _tag = 'ProfileVideosGrid';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);
  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d != null ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}' : '';
    debugPrint('[$_tag] [$l] $m$data');
  }
}

// ============================================================================
// GRID
// ============================================================================

/// Grille de vidéos avec pagination infinite scroll + debounce
class ProfileVideosGrid extends ConsumerStatefulWidget {
  final String userId;

  const ProfileVideosGrid({super.key, required this.userId});

  @override
  ConsumerState<ProfileVideosGrid> createState() => _ProfileVideosGridState();
}

class _ProfileVideosGridState extends ConsumerState<ProfileVideosGrid> {
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollDebounce;
  DateTime? _lastRefresh;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _GridLogger.info('Grid initialized', {'userId': widget.userId});
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollDebounce?.cancel();
    _GridLogger.info('Grid disposed');
    super.dispose();
  }

  /// Debounce 200ms pour éviter déclenchements multiples
  void _onScroll() {
    _scrollDebounce?.cancel();
    _scrollDebounce = Timer(_kScrollDebounce, () {
      if (!mounted) return;
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      if (pos.pixels >= pos.maxScrollExtent - _kScrollThreshold) {
        ref.read(userPostsProvider(widget.userId).notifier).loadMore();
        _GridLogger.info('Load more triggered', {
          'position': pos.pixels.toStringAsFixed(0),
          'maxExtent': pos.maxScrollExtent.toStringAsFixed(0),
        });
      }
    });
  }

  void _refresh() {
    // Throttle 2s
    final now = DateTime.now();
    if (_lastRefresh != null && now.difference(_lastRefresh!) < _kRefreshThrottle) {
      _GridLogger.warn('Refresh throttled');
      return;
    }
    _lastRefresh = now;

    HapticFeedback.mediumImpact();
    ref.read(userPostsProvider(widget.userId).notifier).refresh();
    _GridLogger.info('Refresh triggered');
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(userPostsProvider(widget.userId));

    return postsAsync.when(
      loading: () => SliverToBoxAdapter(
        child: _buildEmptyState(context, loading: true),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: _buildErrorState(context, e),
      ),
      data: (state) {
        if (state.posts.isEmpty) {
          return SliverToBoxAdapter(
            child: _buildEmptyState(context),
          );
        }

        final itemCount = state.posts.length + (state.hasMore ? 1 : 0);

        return RepaintBoundary(
          child: SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _kGridCrossAxisCount,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: _kGridChildAspectRatio,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index == state.posts.length) {
                    return const _LoadingIndicator();
                  }
                  return RepaintBoundary(
                    child: ProfileVideoCard(post: state.posts[index]),
                  );
                },
                childCount: itemCount,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, {bool loading = false}) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Semantics(
          header: true,
          label: loading ? l10n.t('profile_loading') : l10n.t('profile_no_posts'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ThixPolicy.surfaceSoft.withValues(alpha: 0.05),
                ),
                child: loading
                    ? const SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          color: ThixPolicy.textMuted,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(
                        Icons.video_library_rounded,
                        size: 48,
                        color: ThixPolicy.textMuted.withValues(alpha: 0.4),
                      ),
              ),
              const SizedBox(height: 16),
              Text(
                loading ? l10n.t('profile_loading') : l10n.t('profile_no_posts'),
                style: ThixPolicy.h3Style.copyWith(
                  color: ThixPolicy.textMain,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!loading) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.t('profile_no_posts_hint'),
                  style: ThixPolicy.bodySmallStyle.copyWith(
                    color: ThixPolicy.textMuted,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    final l10n = AppLocalizations.of(context);
    // Sanitize error message
    final errorMessage = error.toString().length > 200
        ? '${error.toString().substring(0, 200)}...'
        : error.toString();

    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Semantics(
          header: true,
          label: l10n.t('profile_load_error'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: ThixPolicy.danger,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.t('profile_load_error'),
                style: ThixPolicy.h3Style.copyWith(
                  color: ThixPolicy.textMain,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  errorMessage,
                  style: ThixPolicy.captionStyle.copyWith(
                    color: ThixPolicy.textMuted,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                button: true,
                label: l10n.t('common_retry'),
                child: ElevatedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l10n.t('common_retry')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThixPolicy.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// LOADING INDICATOR
// ============================================================================

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: CircularProgressIndicator(
          color: ThixPolicy.primary,
          strokeWidth: 2,
        ),
      ),
    );
  }
}
