// lib/presentation/thix_media/widgets/fil_feed_view.dart

import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/media_content.dart';
import 'package:thix_id/presentation/thix_media/providers/thix_media_provider.dart';
import 'package:thix_id/services/media_service.dart';

// ✅ Imports de ton fichier parent
import '../thix_media_page.dart' show MediaConfig, MediaSanitizer, formatMediaNumber;
import '../user_profile_page.dart';
import 'feed_video_player.dart';
import 'comments_sheet.dart';

// ============================================================================
// MIX INTELLIGENT DU FIL
// ============================================================================

class SmartFeedMixer {
  SmartFeedMixer._();

  static double _score(MediaContent item, Random rng) {
    final base = (item.likeCount * MediaConfig.likeWeight) + (item.commentCount * MediaConfig.commentWeight) + (item.viewCount * MediaConfig.viewWeight);
    final jitter = MediaConfig.explorationMin + rng.nextDouble() * MediaConfig.explorationRange;
    return (base <= 0 ? 1.0 : base) * jitter;
  }

  static List<MediaContent> mix(List<MediaContent> catalog, {int? seed}) {
    if (catalog.length <= 2) return List.of(catalog);
    final rng = Random(seed);

    final buckets = <String, List<MediaContent>>{};
    for (final item in catalog) {
      final key = (item.userId?.isNotEmpty ?? false) ? item.userId! : 'solo_${item.id}';
      buckets.putIfAbsent(key, () => []).add(item);
    }
    for (final bucket in buckets.values) {
      bucket.sort((a, b) => _score(b, rng).compareTo(_score(a, rng)));
    }

    final result = <MediaContent>[];
    final keys = buckets.keys.toList();
    while (keys.any((k) => buckets[k]!.isNotEmpty)) {
      final available = keys.where((k) => buckets[k]!.isNotEmpty).toList();
      final weights = available.map((k) => _score(buckets[k]!.first, rng)).toList();
      final total = weights.fold<double>(0, (a, b) => a + b);
      var pick = total <= 0 ? 0.0 : rng.nextDouble() * total;
      var chosen = 0;
      for (var i = 0; i < weights.length; i++) {
        pick -= weights[i];
        chosen = i;
        if (pick <= 0) break;
      }
      result.add(buckets[available[chosen]]!.removeAt(0));
    }
    return result;
  }
}

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================

class FilFeedView extends ConsumerStatefulWidget {
  final List<MediaContent> catalog;
  final void Function(MediaContent) onOpenDetail;

  const FilFeedView({super.key, required this.catalog, required this.onOpenDetail});

  @override
  ConsumerState<FilFeedView> createState() => _FilFeedViewState();
}

class _FilFeedViewState extends ConsumerState<FilFeedView> {
  int _currentIndex = 0;
  final Map<String, bool> _localLikes = {};
  final Map<String, int> _localLikeCounts = {};
  late List<MediaContent> _mixedFeed;
  final Set<String> _seenIds = {};

  @override
  void initState() {
    super.initState();
    _mixedFeed = SmartFeedMixer.mix(widget.catalog);
    _seenIds.addAll(_mixedFeed.map((e) => e.id));
    _initLikes();
  }

  @override
  void didUpdateWidget(covariant FilFeedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newItems = widget.catalog.where((e) => !_seenIds.contains(e.id)).toList();
    if (newItems.isNotEmpty) {
      final mixedNew = SmartFeedMixer.mix(newItems);
      setState(() {
        _mixedFeed.addAll(mixedNew);
        _seenIds.addAll(mixedNew.map((e) => e.id));
      });
      for (final item in mixedNew) {
        _localLikeCounts[item.id] = item.likeCount;
      }
      _syncLikedStatus(mixedNew.map((e) => e.id).toList());
    }
  }

  void _initLikes() {
    for (final item in _mixedFeed) {
      _localLikeCounts[item.id] = item.likeCount;
    }
    _syncLikedStatus(_mixedFeed.map((e) => e.id).toList());
  }

  Future<void> _syncLikedStatus(List<String> ids) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null || ids.isEmpty) return;
    try {
      final res = await Supabase.instance.client.rpc('get_liked_media_ids', params: {'p_media_ids': ids}).timeout(MediaConfig.networkTimeout);
      if (mounted && res is List) {
        setState(() {
          for (final id in res) {
            _localLikes[id.toString()] = true;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleLike(MediaContent item, AppLocalizations l10n) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('media_login_to_like').isNotEmpty ? l10n.t('media_login_to_like') : 'Veuillez vous connecter')));
      return;
    }
    HapticFeedback.selectionClick();
    final wasLiked = _localLikes[item.id] ?? false;
    final currentCount = _localLikeCounts[item.id] ?? item.likeCount;

    setState(() {
      _localLikes[item.id] = !wasLiked;
      _localLikeCounts[item.id] = wasLiked ? (currentCount - 1).clamp(0, 999999999) : currentCount + 1;
    });

    try {
      await Supabase.instance.client.rpc('toggle_media_like', params: {'p_media_id': item.id}).timeout(MediaConfig.networkTimeout);
    } catch (_) {
      if (mounted) {
        setState(() {
          _localLikes[item.id] = wasLiked;
          _localLikeCounts[item.id] = currentCount;
        });
      }
    }
  }

  void _openProfile(String userId) {
    if (!MediaSanitizer.isValidId(userId) || !mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfilePage(userId: userId)));
  }

  void _openComments(MediaContent item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CommentsSheet(mediaId: item.id, mediaTitle: item.title),
    ).then((_) => ref.invalidate(mediaCommentCountProvider(item.id)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_mixedFeed.isEmpty) {
      return Center(child: Text(l10n.t('media_feed_empty').isNotEmpty ? l10n.t('media_feed_empty') : 'Aucun contenu', style: const TextStyle(color: Colors.white54)));
    }

    return PageView.builder(
      scrollDirection: Axis.vertical,
      onPageChanged: (index) => setState(() => _currentIndex = index),
      itemCount: _mixedFeed.length,
      itemBuilder: (context, index) {
        final item = _mixedFeed[index];
        final isCurrent = index == _currentIndex;
        final isLiked = _localLikes[item.id] ?? false;
        final likeCount = _localLikeCounts[item.id] ?? item.likeCount;
        
        final creatorId = item.userId ?? '';
        final creatorProfile = creatorId.isNotEmpty ? ref.watch(mediaUserProfileProvider(creatorId)).valueOrNull : null;
        final currentUid = Supabase.instance.client.auth.currentUser?.id;
        final isFollowing = creatorId.isEmpty ? true : (ref.watch(mediaIsFollowingProvider(creatorId)).valueOrNull ?? true);
        final displayName = creatorId.isEmpty ? 'TDIA' : (creatorProfile?['full_name'] ?? creatorProfile?['username'] ?? 'Créateur');
        final showFollow = creatorId.isNotEmpty && creatorId != currentUid && !isFollowing;

        return _FilVideoCard(
          key: ValueKey(item.id),
          item: item,
          isCurrent: isCurrent,
          isLiked: isLiked,
          likeCount: likeCount,
          commentCount: item.commentCount,
          viewCount: item.viewCount,
          displayName: '$displayName',
          creatorAvatar: creatorProfile?['avatar_url'] as String?,
          showFollow: showFollow,
          onLike: () => _toggleLike(item, l10n),
          onDoubleTapLike: () {
            if (!(_localLikes[item.id] ?? false)) _toggleLike(item, l10n);
          },
          onComment: () => _openComments(item),
          onOpenDetail: () => widget.onOpenDetail(item),
          onOpenProfile: () => _openProfile(creatorId),
          onFollow: () async {
            HapticFeedback.selectionClick();
            try {
              await MediaService().toggleFollow(creatorId);
              ref.invalidate(mediaIsFollowingProvider(creatorId));
            } catch (_) {}
          },
        );
      },
    );
  }
}

class _FilVideoCard extends StatefulWidget {
  final MediaContent item;
  final bool isCurrent;
  final bool isLiked;
  final int likeCount, commentCount, viewCount;
  final String displayName;
  final String? creatorAvatar;
  final bool showFollow;
  final VoidCallback onLike, onDoubleTapLike, onComment, onOpenDetail, onOpenProfile, onFollow;

  const _FilVideoCard({
    super.key, required this.item, required this.isCurrent, required this.isLiked,
    required this.likeCount, required this.commentCount, required this.viewCount,
    required this.displayName, required this.creatorAvatar, required this.showFollow,
    required this.onLike, required this.onDoubleTapLike, required this.onComment,
    required this.onOpenDetail, required this.onOpenProfile, required this.onFollow,
  });

  @override
  State<_FilVideoCard> createState() => _FilVideoCardState();
}

class _FilVideoCardState extends State<_FilVideoCard> {
  bool _showHeart = false;

  void _handleDoubleTap() {
    widget.onDoubleTapLike();
    setState(() => _showHeart = true);
    Future.delayed(MediaConfig.heartPopDuration, () {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cover = MediaSanitizer.imageUrl(widget.item.coverUrl);
    final avatar = MediaSanitizer.imageUrl(widget.creatorAvatar);

    return GestureDetector(
      onDoubleTap: _handleDoubleTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (cover != null) CachedNetworkImage(imageUrl: cover, fit: BoxFit.cover) else Container(color: Colors.black),
          BackdropFilter(filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), child: Container(color: Colors.black.withValues(alpha: 0.5))),
          Center(
            child: FeedVideoPlayer(
              videoUrl: widget.item.videoUrl,
              coverUrl: widget.item.coverUrl,
              isPlaying: widget.isCurrent,
              onPlayStateChanged: (_) {},
            ),
          ),
          AnimatedOpacity(
            opacity: _showHeart ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: Center(
              child: AnimatedScale(
                scale: _showHeart ? 1.1 : 0.6,
                duration: MediaConfig.heartPopDuration,
                curve: Curves.elasticOut,
                child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 110),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 110,
            child: Column(
              children: [
                GestureDetector(
                  onTap: widget.onOpenProfile,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                        child: ClipOval(
                          child: avatar != null
                              ? CachedNetworkImage(imageUrl: avatar, fit: BoxFit.cover)
                              : Container(color: Colors.white24, child: const Icon(Icons.person, color: Colors.white)),
                        ),
                      ),
                      if (widget.showFollow)
                        Positioned(
                          bottom: -6, left: 13,
                          child: GestureDetector(
                            onTap: widget.onFollow,
                            child: Container(
                              width: 20, height: 20,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: ThixPolicy.primary, border: Border.all(color: Colors.white, width: 2)),
                              child: const Icon(Icons.add_rounded, size: 13, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _sideAction(icon: widget.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, label: formatMediaNumber(widget.likeCount), color: widget.isLiked ? ThixPolicy.danger : Colors.white, onTap: widget.onLike),
                const SizedBox(height: 16),
                _sideAction(icon: Icons.chat_bubble_rounded, label: formatMediaNumber(widget.commentCount), color: Colors.white, onTap: widget.onComment),
                const SizedBox(height: 16),
                _sideAction(icon: Icons.fullscreen_rounded, label: '', color: Colors.white, onTap: widget.onOpenDetail),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 88,
            bottom: 28,
            child: GestureDetector(
              onTap: widget.onOpenProfile,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('@${widget.displayName}', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: ThixPolicy.primary, borderRadius: BorderRadius.circular(6)),
                      child: Text(widget.item.type.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(MediaSanitizer.text(widget.item.title, maxLength: MediaConfig.maxTitleLength),
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sideAction({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }
}
