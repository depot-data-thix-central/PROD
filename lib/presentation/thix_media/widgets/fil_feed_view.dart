import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/models/media_content.dart';
import 'package:thix_id/services/media_service.dart';
import '../providers/thix_media_providers.dart';
import '../utils/media_constants.dart';
import 'feed_video_player.dart';

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

  @override
  void initState() {
    super.initState();
    _shuffledCatalog = List.from(widget.catalog)..shuffle();
    _initLikes();
  }

  @override
  void didUpdateWidget(covariant FilFeedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.catalog.length != oldWidget.catalog.length) {
      final newItems = widget.catalog.where((e) => !_shuffledCatalog.any((s) => s.id == e.id)).toList()..shuffle();
      if (newItems.isNotEmpty) {
        _shuffledCatalog.addAll(newItems);
        for (var item in newItems) {
          _localLikeCounts[item.id] = item.likeCount;
        }
        _syncLikedStatus();
      }
    }
  }

  void _initLikes() {
    for (var item in _shuffledCatalog) {
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
      if (mounted) {
        setState(() {
          for (var id in res) {
            _localLikes[id] = true;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleLike(MediaContent item) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connectez-vous pour aimer.')),
      );
      return;
    }

    HapticFeedback.selectionClick();
    final isCurrentlyLiked = _localLikes[item.id] ?? false;
    final currentCount = _localLikeCounts[item.id] ?? item.likeCount;

    setState(() {
      _localLikes[item.id] = !isCurrentlyLiked;
      _localLikeCounts[item.id] = isCurrentlyLiked
          ? (currentCount - 1).clamp(0, 999999)
          : currentCount + 1;
    });

    try {
      await MediaService().toggleLike(item.id);
    } catch (_) {
      if (mounted) {
        setState(() {
          _localLikes[item.id] = isCurrentlyLiked;
          _localLikeCounts[item.id] = currentCount;
        });
      }
    }
  }

  void _openCommentsDirectly(MediaContent item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CommentsSheet(mediaId: item.id, mediaTitle: item.title),
    ).then((_) => ref.invalidate(commentCountProvider(item.id)));
  }

  @override
  Widget build(BuildContext context) {
    if (_shuffledCatalog.isEmpty) {
      return const Center(
        child: Text('Le fil est vide pour le moment.', style: TextStyle(color: Colors.white54)),
      );
    }

    return PageView.builder(
      scrollDirection: Axis.vertical,
      onPageChanged: (index) => setState(() => _currentIndex = index),
      itemCount: _shuffledCatalog.length,
      itemBuilder: (context, index) => _buildFeedItem(_shuffledCatalog[index], index == _currentIndex),
    );
  }

  Widget _buildFeedItem(MediaContent item, bool isCurrent) {
    final isLiked = _localLikes[item.id] ?? false;
    final likeCount = _localLikeCounts[item.id] ?? item.likeCount;
    final live = ref.watch(mediaCountsStreamProvider(item.id)).valueOrNull;
    final commentCount = live?.commentCount ?? item.commentCount;
    final viewCount = live?.viewCount ?? item.viewCount;

    // Enregistrer la vue
    if (isCurrent) {
      AnalyticsBatcher.register(item.id);
    }

    return Stack(
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
          child: _buildInfoOverlay(item, isLiked, likeCount, commentCount, viewCount),
        ),
      ],
    );
  }

  Widget _buildBackgroundImage(String url) {
    if (url.trim().isEmpty) {
      return Container(color: Colors.black);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(color: Colors.black.withOpacity(0.6)),
        ),
      ],
    );
  }

  Widget _buildInfoOverlay(MediaContent item, bool isLiked, int likeCount, int commentCount, int viewCount) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => widget.onOpenDetail(item),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: MediaColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.type.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (item.isPaid) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.lock_rounded, size: 12, color: MediaColors.gold),
                        ],
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(height: 1, color: Colors.white.withOpacity(0.2)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _actionBtn(
                    icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    text: formatMediaNumber(likeCount),
                    color: isLiked ? MediaColors.danger : Colors.white,
                    onTap: () => _toggleLike(item),
                  ),
                  _actionBtn(
                    icon: Icons.chat_bubble_outline_rounded,
                    text: formatMediaNumber(commentCount),
                    color: Colors.white,
                    onTap: () => _openCommentsDirectly(item),
                  ),
                  _actionBtn(
                    icon: Icons.visibility_outlined,
                    text: formatMediaNumber(viewCount),
                    color: Colors.white70,
                    onTap: null,
                  ),
                  _actionBtn(
                    icon: Icons.fullscreen_rounded,
                    text: '',
                    color: Colors.white,
                    onTap: () => widget.onOpenDetail(item),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String text,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            if (text.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(text, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ],
        ),
      ),
    );
  }
}
