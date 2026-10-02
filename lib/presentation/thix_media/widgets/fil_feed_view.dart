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

import '../thix_media_page.dart' show MediaConfig, MediaSanitizer, formatMediaNumber;
import '../user_profile_page.dart';
import 'feed_video_player.dart';
import 'comments_sheet.dart';

// ============================================================================
// SMART FEED MIXER (anti-bubble, diversité créateurs)
// ============================================================================

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

// ============================================================================
// FIL FEED VIEW
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
      final res = await Supabase.instance.client
          .rpc('get_liked_media_ids', params: {'p_media_ids': ids})
          .timeout(MediaConfig.networkTimeout);
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
    final l10n = AppLocalizations.of(context);
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('detail_login_required', fallback: 'Veuillez vous connecter'))),
      );
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
      await Supabase.instance.client
          .rpc('toggle_media_like', params: {'p_media_id': item.id})
          .timeout(MediaConfig.networkTimeout);
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.videocam_off_rounded, color: Colors.white70, size: 48),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.t('fil_empty', fallback: 'Aucune vidéo disponible'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.t('fil_empty_hint', fallback: 'Ajoutez des contenus via l\'admin'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
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
        final creatorProfile = creatorId.isNotEmpty 
            ? ref.watch(mediaUserProfileProvider(creatorId)).valueOrNull 
            : null;
        final currentUid = Supabase.instance.client.auth.currentUser?.id;
        final isFollowing = creatorId.isEmpty 
            ? true 
            : (ref.watch(mediaIsFollowingProvider(creatorId)).valueOrNull ?? true);
        final displayName = creatorId.isEmpty 
            ? 'TDIA' 
            : (creatorProfile?['full_name'] ?? creatorProfile?['username'] ?? l10n.t('detail_creator_default', fallback: 'Créateur'));
        final showFollow = creatorId.isNotEmpty && creatorId != currentUid && !isFollowing;
        
        // ✅ Extraction certification
        final certTier = creatorProfile?['certification_tier'] as String?;
        final certStatus = creatorProfile?['certification_status'] as String?;
        final isCertified = certStatus == 'approved' || 
                            certStatus == 'generated' || 
                            certStatus == 'active';

        return _FilVideoCard(
          key: ValueKey(item.id),
          item: item,
          isCurrent: isCurrent,
          isLiked: isLiked,
          likeCount: likeCount,
          commentCount: item.commentCount,
          viewCount: item.viewCount,
          displayName: displayName,
          creatorAvatar: creatorProfile?['avatar_url'] as String?,
          showFollow: showFollow,
          certTier: certTier,
          isCertified: isCertified,
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

// ============================================================================
// FIL VIDEO CARD
// ============================================================================

class _FilVideoCard extends StatefulWidget {
  final MediaContent item;
  final bool isCurrent;
  final bool isLiked;
  final int likeCount, commentCount, viewCount;
  final String displayName;
  final String? creatorAvatar;
  final bool showFollow;
  final String? certTier;
  final bool isCertified;
  final VoidCallback onLike, onDoubleTapLike, onComment, onOpenDetail, onOpenProfile, onFollow;

  const _FilVideoCard({
    super.key, 
    required this.item, 
    required this.isCurrent, 
    required this.isLiked,
    required this.likeCount, 
    required this.commentCount, 
    required this.viewCount,
    required this.displayName, 
    required this.creatorAvatar, 
    required this.showFollow,
    required this.certTier,
    required this.isCertified,
    required this.onLike, 
    required this.onDoubleTapLike, 
    required this.onComment,
    required this.onOpenDetail, 
    required this.onOpenProfile, 
    required this.onFollow,
  });

  @override
  State<_FilVideoCard> createState() => _FilVideoCardState();
}

class _FilVideoCardState extends State<_FilVideoCard> with SingleTickerProviderStateMixin {
  bool _showHeart = false;
  late AnimationController _heartController;
  late Animation<double> _heartScale;
  late Animation<double> _heartOpacity;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      duration: MediaConfig.heartPopDuration,
      vsync: this,
    );
    _heartScale = Tween<double>(begin: 0.5, end: 1.2).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.elasticOut),
    );
    _heartOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _heartController, curve: const Interval(0.0, 0.3)),
    );
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    widget.onDoubleTapLike();
    setState(() => _showHeart = true);
    _heartController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() => _showHeart = false);
      }
    });
  }

  // ✅ Couleur du badge selon le tier
  Color _getCertBadgeColor() {
    if (!widget.isCertified) return Colors.white54;
    switch (widget.certTier?.toLowerCase()) {
      case 'official':
        return const Color(0xFF3B82F6); // Bleu officiel
      case 'enterprise':
        return const Color(0xFF8B5CF6); // Violet
      case 'premium':
        return const Color(0xFFF59E0B); // Or
      case 'standard':
        return const Color(0xFF06B6D4); // Cyan
      default:
        return Colors.white54;
    }
  }

  String _getCertLabel(AppLocalizations l10n) {
    if (!widget.isCertified) return '';
    switch (widget.certTier?.toLowerCase()) {
      case 'official':
        return l10n.t('certification_tier_official', fallback: 'Officiel');
      case 'enterprise':
        return l10n.t('certification_tier_enterprise', fallback: 'Entreprise');
      case 'premium':
        return l10n.t('certification_tier_premium', fallback: 'Premium');
      case 'standard':
        return l10n.t('certification_tier_standard', fallback: 'Standard');
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final avatar = MediaSanitizer.imageUrl(widget.creatorAvatar);
    final certColor = _getCertBadgeColor();
    final certLabel = _getCertLabel(l10n);

    return GestureDetector(
      onDoubleTap: _handleDoubleTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ✅ LE LECTEUR VIDÉO
          Container(
            color: Colors.black,
            child: FeedVideoPlayer(
              videoUrl: widget.item.videoUrl,
              coverUrl: widget.item.coverUrl,
              isPlaying: widget.isCurrent,
              onPlayStateChanged: (_) {},
            ),
          ),
          
          // Ombre légère en bas
          Positioned(
            left: 0, 
            right: 0, 
            bottom: 0,
            height: 200,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter, 
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.85), 
                      Colors.black.withOpacity(0.4),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // ✅ Animation du cœur améliorée
          if (_showHeart)
            AnimatedBuilder(
              animation: _heartController,
              builder: (context, child) {
                return Center(
                  child: Opacity(
                    opacity: _heartOpacity.value,
                    child: Transform.scale(
                      scale: _heartScale.value,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite_rounded, 
                          color: Colors.white, 
                          size: 80,
                          shadows: [
                            Shadow(color: Colors.black26, blurRadius: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

          // ✅ DISPOSITION COMPACTE (Texte + Boutons)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
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
                        width: 44, 
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle, 
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: ClipOval(
                          child: avatar != null
                              ? CachedNetworkImage(
                                  imageUrl: avatar, 
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: Colors.white24,
                                    child: const Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: Colors.white24,
                                    child: const Icon(Icons.person, color: Colors.white, size: 20),
                                  ),
                                )
                              : Container(
                                  color: Colors.white24, 
                                  child: const Icon(Icons.person, color: Colors.white, size: 20),
                                ),
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
                            // ✅ Nom + Badge certification
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '@${widget.displayName}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white, 
                                      fontSize: 14, 
                                      fontWeight: FontWeight.w900,
                                      shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                                    ),
                                  ),
                                ),
                                if (widget.isCertified && certLabel.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  _FilCertBadge(color: certColor, label: certLabel),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              MediaSanitizer.text(widget.item.title, maxLength: MediaConfig.maxTitleLength),
                              maxLines: 2, 
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white, 
                                fontSize: 13, 
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.showFollow)
                      GestureDetector(
                        onTap: widget.onFollow,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: ThixPolicy.primary,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: ThixPolicy.primary.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            l10n.t('detail_follow', fallback: 'Suivre'),
                            style: const TextStyle(
                              color: Colors.white, 
                              fontSize: 12, 
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                // Ligne des Boutons d'Action
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
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
                        text: formatMediaNumber(widget.viewCount),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon, 
    required String text, 
    required Color color, 
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon, 
              color: color, 
              size: 22,
              shadows: const [Shadow(color: Colors.black45, blurRadius: 6)],
            ),
            if (text.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                text, 
                style: TextStyle(
                  color: color, 
                  fontSize: 13, 
                  fontWeight: FontWeight.w800,
                  shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// BADGE CERTIFICATION (FIL)
// ============================================================================

class _FilCertBadge extends StatelessWidget {
  final Color color;
  final String label;
  
  const _FilCertBadge({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, color: color, size: 11),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
              shadows: const [Shadow(color: Colors.black26, blurRadius: 2)],
            ),
          ),
        ],
      ),
    );
  }
}
