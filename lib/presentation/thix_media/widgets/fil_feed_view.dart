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
import 'package:thix_id/models/media_content.dart';
import 'package:thix_id/presentation/thix_media/providers/thix_media_provider.dart';
import 'package:thix_id/services/media_service.dart';

import '../thix_media_page.dart' show MediaConfig, MediaSanitizer, formatMediaNumber;
import '../user_profile_page.dart';
import 'feed_video_player.dart';
import 'comments_sheet.dart';

class SmartFeedMixer {
  SmartFeedMixer._();

  static List<MediaContent> mix(List<MediaContent> catalog, {int? seed}) {
    if (catalog.isEmpty) return [];
    if (catalog.length <= 2) return List.of(catalog);
    final rng = Random(seed);

    final buckets = <String, List<MediaContent>>{};
    for (final item in catalog) {
      final key = (item.userId?.isNotEmpty ?? false) ? item.userId! : 'solo_${item.id}';
      buckets.putIfAbsent(key, () => []).add(item);
    }

    final result = <MediaContent>[];
    final keys = buckets.keys.toList();
    while (keys.any((k) => buckets[k]!.isNotEmpty)) {
      final available = keys.where((k) => buckets[k]!.isNotEmpty).toList();
      available.shuffle(rng);
      for (final k in available) {
        if (buckets[k]!.isNotEmpty) {
          result.add(buckets[k]!.removeAt(0));
        }
      }
    }
    return result;
  }
}

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
    if (widget.catalog.length != oldWidget.catalog.length) {
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

  Future<void> _toggleLike(MediaContent item) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez vous connecter pour aimer')));
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
    if (_mixedFeed.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'Aucune vidéo disponible dans le fil pour le moment.\nAjoutez des contenus via l\'admin.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      );
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
          onLike: () => _toggleLike(item),
          onDoubleTapLike: () {
            if (!(_localLikes[item.id] ?? false)) _toggleLike(item);
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
    final avatar = MediaSanitizer.imageUrl(widget.creatorAvatar);

    return GestureDetector(
      onDoubleTap: _handleDoubleTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ✅ LE LECTEUR VIDÉO GÈRE LUI-MÊME SON AFFICHAGE
          Container(
            color: Colors.black,
            child: FeedVideoPlayer(
              videoUrl: widget.item.videoUrl,
              coverUrl: widget.item.coverUrl,
              isPlaying: widget.isCurrent,
              onPlayStateChanged: (_) {},
            ),
          ),
          
          // Ombre légère en bas pour rendre le texte lisible
          Positioned(
            left: 0, right: 0, bottom: 0,
            height: 180,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                  )
                )
              ),
            )
          ),

          // Animation du cœur (Double tap)
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

          // ✅ NOUVELLE DISPOSITION COMPACTE (Texte + Boutons alignés)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24, // Légèrement au-dessus de la barre de progression
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ligne Créateur & Titre
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: widget.onOpenProfile,
                      child: Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                        child: ClipOval(
                          child: avatar != null
                              ? CachedNetworkImage(imageUrl: avatar, fit: BoxFit.cover)
                              : Container(color: Colors.white24, child: const Icon(Icons.person, color: Colors.white, size: 20)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: widget.onOpenProfile,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('@${widget.displayName}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black45, blurRadius: 4)])),
                            const SizedBox(height: 2),
                            Text(
                              MediaSanitizer.text(widget.item.title, maxLength: MediaConfig.maxTitleLength),
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500, shadows: [Shadow(color: Colors.black45, blurRadius: 4)]),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.showFollow)
                      GestureDetector(
                        onTap: widget.onFollow,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(color: ThixPolicy.primary, borderRadius: BorderRadius.circular(16)),
                          child: const Text('Suivre', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12), // ✅ Espace réduit
                // Ligne des Boutons d'Action Horizontale
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _actionBtn(
                      icon: widget.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      text: formatMediaNumber(widget.likeCount),
                      color: widget.isLiked ? ThixPolicy.danger : Colors.white,
                      onTap: widget.onLike,
                    ),
                    _actionBtn(
                      icon: Icons.chat_bubble_outline_rounded,
                      text: formatMediaNumber(widget.commentCount),
                      color: Colors.white,
                      onTap: widget.onComment,
                    ),
                    _actionBtn(
                      icon: Icons.remove_red_eye_outlined,
                      text: formatMediaNumber(widget.viewCount), // ✅ Vues bien présentes
                      color: Colors.white,
                      onTap: () {}, 
                    ),
                    _actionBtn(
                      icon: Icons.fullscreen_rounded,
                      text: '', 
                      color: Colors.white,
                      onTap: widget.onOpenDetail,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({required IconData icon, required String text, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24, shadows: const [Shadow(color: Colors.black45, blurRadius: 6)]),
          if (text.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black45, blurRadius: 4)])),
          ]
        ],
      ),
    );
  }
}
