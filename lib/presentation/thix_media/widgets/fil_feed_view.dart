/// FilFeedView (Production Enterprise)
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/media_content.dart';
import 'package:thix_id/presentation/thix_media/providers/thix_media_provider.dart';
import 'package:thix_id/services/media_service.dart';

import '../utils/media_constants.dart';
import 'comments_sheet.dart';
import 'feed_video_player.dart';

const Duration _kLikeThrottle = Duration(milliseconds: 400);
const double _kBackgroundBlur = kIsWeb ? 8 : 20;
const double _kOverlayBlur = kIsWeb ? 6 : 15;

class _FeedLogger {
  static const _tag = 'FilFeed';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);
  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d == null
        ? ''
        : ' ' +
            d.entries
                .map((e) => e.key + '=' + e.value.toString())
                .join(', ');
    debugPrint('[$_tag] [$l] $m$data');
  }
}

class FilFeedView extends ConsumerStatefulWidget {
  final List<MediaContent> catalog;
  final ValueChanged<MediaContent> onOpenDetail;

  const FilFeedView({
    super.key,
    required this.catalog,
    required this.onOpenDetail,
  });

  @override
  ConsumerState<FilFeedView> createState() => _FilFeedViewState();
}

class _FilFeedViewState extends ConsumerState<FilFeedView> {
  int _currentIndex = 0;
  final Map<String, bool> _localLikes = {};
  final Map<String, int> _localLikeCounts = {};
  late List<MediaContent> _shuffledCatalog;
  DateTime? _lastLikeTap;

  @override
  void initState() {
    super.initState();
    _shuffledCatalog = List<MediaContent>.from(widget.catalog)..shuffle();
    _initLikes();
    _FeedLogger.info('Feed initialized', {'items': _shuffledCatalog.length});
  }

  @override
  void didUpdateWidget(covariant FilFeedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.catalog.length != oldWidget.catalog.length) {
      final newItems = widget.catalog
          .where((e) => !_shuffledCatalog.any((s) => s.id == e.id))
          .toList()
        ..shuffle();
      if (newItems.isNotEmpty) {
        _shuffledCatalog.addAll(newItems);
        for (final item in newItems) {
          _localLikeCounts[item.id] = item.likeCount;
        }
        _syncLikedStatus();
      }
    }
  }

  void _initLikes() {
    for (final item in _shuffledCatalog) {
      _localLikeCounts[item.id] = item.likeCount;
    }
    _syncLikedStatus();
  }

  Future<void> _syncLikedStatus() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null || _shuffledCatalog.isEmpty) return;
    try {
      final ids = _shuffledCatalog.map((e) => e.id).toList();
      final res = await MediaService().getLikedMediaIds(ids);
      if (!mounted) return;
      setState(() {
        for (final id in res) {
          _localLikes[id] = true;
        }
      });
    } catch (e) {
      _FeedLogger.error('Sync liked status failed', {'error': '$e'});
    }
  }

  Future<void> _toggleLike(MediaContent item) async {
    final now = DateTime.now();
    if (_lastLikeTap != null &&
        now.difference(_lastLikeTap!) < _kLikeThrottle) {
      return;
    }
    _lastLikeTap = now;

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t('feed_login_required')),
          backgroundColor: ThixPolicy.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.selectionClick();
    final wasLiked = _localLikes[item.id] ?? false;
    final currentCount = _localLikeCounts[item.id] ?? item.likeCount;
    setState(() {
      _localLikes[item.id] = !wasLiked;
      _localLikeCounts[item.id] =
          wasLiked ? (currentCount - 1).clamp(0, 999999) : currentCount + 1;
    });
    try {
      await MediaService().toggleLike(item.id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _localLikes[item.id] = wasLiked;
        _localLikeCounts[item.id] = currentCount;
      });
    }
  }

  void _openCommentsDirectly(MediaContent item) {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CommentsSheet(mediaId: item.id, mediaTitle: item.title),
    ).then((_) {
      if (mounted) ref.invalidate(commentCountProvider(item.id));
    });
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    AnalyticsBatcher.register(_shuffledCatalog[index].id);
    if (index >= _shuffledCatalog.length - 3) {
      ref.read(thixMediaListProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_shuffledCatalog.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return Center(
        child: Text(
          l10n.t('feed_empty'),
          style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMuted),
        ),
      );
    }

    return PageView.builder(
      scrollDirection: Axis.vertical,
      allowImplicitScrolling: true,
      onPageChanged: _onPageChanged,
      itemCount: _shuffledCatalog.length,
      itemBuilder: (context, index) {
        final isNear = (index - _currentIndex).abs() <= 1;
        return _buildFeedItem(
          _shuffledCatalog[index],
          index == _currentIndex,
          warmup: isNear,
        );
      },
    );
  }

  Widget _buildFeedItem(MediaContent item, bool isCurrent, {required bool warmup}) {
    final isLiked = _localLikes[item.id] ?? false;
    final likeCount = _localLikeCounts[item.id] ?? item.likeCount;
    final live = ref.watch(mediaCountsPollingProvider(item.id)).valueOrNull;
    final commentCount = live?.commentCount ?? item.commentCount;
    final viewCount = live?.viewCount ?? item.viewCount;

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackgroundImage(item.coverUrl),
          Center(
            child: FeedVideoPlayer(
              videoUrl: item.videoUrl,
              coverUrl: item.coverUrl,
              isPlaying: isCurrent,
              onPlayStateChanged: (_) {},
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _buildInfoOverlay(
              item,
              isLiked,
              likeCount,
              commentCount,
              viewCount,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundImage(String url) {
    if (url.trim().isEmpty) return Container(color: ThixPolicy.inkDeep);
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Container(color: ThixPolicy.inkDeep),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: _kBackgroundBlur,
            sigmaY: _kBackgroundBlur,
          ),
          child: Container(color: Colors.black.withValues(alpha: 0.6)),
        ),
      ],
    );
  }

  Widget _buildInfoOverlay(
    MediaContent item,
    bool isLiked,
    int likeCount,
    int commentCount,
    int viewCount,
  ) {
    final l10n = AppLocalizations.of(context);

    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _kOverlayBlur, sigmaY: _kOverlayBlur),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: ThixPolicy.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.type.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (item.isPaid) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.lock_rounded, size: 12, color: ThixPolicy.warning),
                    ],
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
                if (item.userId != null && item.userId!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _CreatorRow(userId: item.userId!),
                ],
                const SizedBox(height: 8),
                Container(height: 1, color: Colors.white.withValues(alpha: 0.2)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _actionBtn(
                      icon: isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      text: formatMediaNumber(likeCount),
                      color: isLiked ? ThixPolicy.danger : Colors.white,
                      label: l10n.t('band_like'),
                      onTap: () => _toggleLike(item),
                    ),
                    _actionBtn(
                      icon: Icons.chat_bubble_outline_rounded,
                      text: formatMediaNumber(commentCount),
                      color: Colors.white,
                      label: l10n.t('band_comments'),
                      onTap: () => _openCommentsDirectly(item),
                    ),
                    _actionBtn(
                      icon: Icons.visibility_outlined,
                      text: formatMediaNumber(viewCount),
                      color: Colors.white.withValues(alpha: 0.7),
                      label: l10n.t('band_views'),
                      onTap: null,
                    ),
                    _actionBtn(
                      icon: Icons.fullscreen_rounded,
                      text: '',
                      color: Colors.white,
                      label: l10n.t('band_fullscreen'),
                      onTap: () => widget.onOpenDetail(item),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String text,
    required Color color,
    required String label,
    VoidCallback? onTap,
  }) {
    return Semantics(
      button: true,
      label: text.isNotEmpty ? '$label $text' : label,
      child: GestureDetector(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap();
              },
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              if (text.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  text,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CreatorRow extends ConsumerWidget {
  final String userId;
  const _CreatorRow({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider(userId)).valueOrNull;
    final following = ref.watch(isFollowingProvider(userId)).valueOrNull ?? false;
    final me = Supabase.instance.client.auth.currentUser?.id;
    final rawName =
        (profile?['username'] ?? profile?['full_name'] ?? '').toString().trim();
    final name = rawName.isEmpty ? 'Créateur' : rawName;
    final avatar = profile?['avatar_url']?.toString();
    final showFollow = me != null && me != userId && !following;

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              context.push('/profile/$userId');
            },
            child: Row(
              children: [
                _CreatorAvatar(url: avatar),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    name.startsWith('@') ? name : '@$name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showFollow)
          GestureDetector(
            onTap: () async {
              HapticFeedback.mediumImpact();
              try {
                await MediaService().toggleFollow(userId);
                ref.invalidate(isFollowingProvider(userId));
              } catch (e) {
                _FeedLogger.error('Follow failed', {'error': '$e'});
              }
            },
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Text(
                '+',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CreatorAvatar extends StatelessWidget {
  final String? url;
  const _CreatorAvatar({this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: ClipOval(
        child: url != null && url!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Icon(
                  Icons.person,
                  size: 14,
                  color: ThixPolicy.textMuted,
                ),
              )
            : Icon(Icons.person, size: 14, color: ThixPolicy.textMuted),
      ),
    );
  }
}
