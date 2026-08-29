import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/models/media_content.dart';
import 'package:thix_id/services/media_service.dart';
import '../providers/thix_media_providers.dart';
import '../utils/media_constants.dart';
import 'comments_sheet.dart';
import 'feed_video_player.dart';
import 'media_poster_card.dart';
import 'package:thix_id/presentation/thix_media/user_profile_page.dart';

class MediaDetailPage extends ConsumerStatefulWidget {
  final MediaContent item;
  final List<MediaContent> catalog;

  const MediaDetailPage({super.key, required this.item, required this.catalog});

  @override
  ConsumerState<MediaDetailPage> createState() => _MediaDetailPageState();
}

class _MediaDetailPageState extends ConsumerState<MediaDetailPage> {
  late List<String> _episodes;
  int _currentEpisode = 0;
  bool _liked = false;
  bool _saved = false;
  bool _previewExpired = false;
  bool _unlocked = false;
  static const int _previewSeconds = 30;
  final Set<String> _newlyFollowed = {};
  List<MediaContent> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _episodes = [widget.item.videoUrl, ...widget.item.episodesUrls]
        .where((u) => u.isNotEmpty)
        .toList();
    _syncLiked();
    _loadSuggestions();
  }

  void _loadSuggestions() {
    final otherVideos = widget.catalog.where((e) => e.id != widget.item.id).toList();
    otherVideos.shuffle();
    _suggestions = otherVideos.take(4).toList();
  }

  Future<void> _syncLiked() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final res = await MediaService().getLikedMediaIds([widget.item.id]);
      if (mounted && res.contains(widget.item.id)) setState(() => _liked = true);
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connectez-vous pour aimer.')),
      );
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _liked = !_liked);
    try {
      await MediaService().toggleLike(widget.item.id);
    } catch (_) {}
  }

  void _toggleSave() {
    HapticFeedback.lightImpact();
    setState(() => _saved = !_saved);
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CommentsSheet(mediaId: widget.item.id, mediaTitle: widget.item.title),
    ).then((_) => ref.invalidate(commentCountProvider(widget.item.id)));
  }

  String _formatPrice() => '\$${widget.item.price.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isSeries = _episodes.length > 1;
    final requiresPayment = item.isPaid && !_unlocked && _previewExpired;
    final enforcePreview = item.isPaid && !_unlocked;

    final live = ref.watch(mediaCountsStreamProvider(item.id)).valueOrNull;
    final creatorId = item.userId ?? '';
    final creatorProfile = creatorId.isNotEmpty
        ? ref.watch(userProfileProvider(creatorId)).valueOrNull
        : null;
    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    final isFollowing = creatorId.isNotEmpty
        ? (ref.watch(isFollowingProvider(creatorId)).valueOrNull ?? true)
        : true;
    final creatorIsOfficial = creatorId.isEmpty;
    final showFollowBtn = !creatorIsOfficial &&
        creatorId.isNotEmpty &&
        creatorId != currentUid &&
        !isFollowing &&
        !_newlyFollowed.contains(creatorId);
    final displayName = creatorIsOfficial
        ? 'TDIA'
        : (creatorProfile?['full_name'] ?? creatorProfile?['username'] ?? 'Créateur');

    return Scaffold(
      backgroundColor: MediaColors.navyDeep,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: MediaColors.navyDeep.withOpacity(0.6)),
          ),
        ),
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVideoSection(item, requiresPayment, enforcePreview),
            if (isSeries && !requiresPayment) _buildEpisodesSection(),
            _buildCreatorSection(
              creatorProfile,
              creatorId,
              creatorIsOfficial,
              displayName,
              showFollowBtn,
            ),
            _buildActionsBar(live),
            if (item.subtitle != null && item.subtitle!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Text(
                  item.subtitle!,
                  style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                ),
              )
            else
              const SizedBox(height: 24),
            if (_suggestions.isNotEmpty) _buildSuggestionsSection(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoSection(MediaContent item, bool requiresPayment, bool enforcePreview) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
      color: Colors.black,
      child: Center(
        child: requiresPayment
            ? _buildPaywall(item)
            : FeedVideoPlayer(
                key: ValueKey('${item.id}_$_currentEpisode'),
                videoUrl: _episodes.isEmpty ? item.videoUrl : _episodes[_currentEpisode.clamp(0, _episodes.length - 1)],
                coverUrl: item.coverUrl,
                isPlaying: true,
                enforcePreviewLimit: enforcePreview,
                previewSeconds: _previewSeconds,
                onPreviewLimitReached: () {
                  if (mounted) setState(() => _previewExpired = true);
                },
                onPlayStateChanged: (_) {},
              ),
      ),
    );
  }

  Widget _buildEpisodesSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Épisodes', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_episodes.length, (i) {
              final active = i == _currentEpisode;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _currentEpisode = i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: active ? Colors.white : Colors.transparent),
                  ),
                  child: Text(
                    'Partie ${i + 1}',
                    style: TextStyle(
                      color: active ? MediaColors.navyDeep : Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatorSection(
    Map<String, dynamic>? creatorProfile,
    String creatorId,
    bool creatorIsOfficial,
    String displayName,
    bool showFollowBtn,
  ) {
    final item = widget.item;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (!creatorIsOfficial && creatorId.isNotEmpty) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfilePage(userId: creatorId)));
              }
            },
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.6),
                image: creatorProfile != null && creatorProfile['avatar_url'] != null
                    ? DecorationImage(image: CachedNetworkImageProvider(creatorProfile['avatar_url']), fit: BoxFit.cover)
                    : null,
              ),
              child: creatorProfile == null || creatorProfile['avatar_url'] == null
                  ? const Icon(Icons.person, size: 24, color: Colors.white70)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('@$displayName', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                Text(item.type, style: const TextStyle(color: MediaColors.whiteMuted, fontSize: 12)),
              ],
            ),
          ),
          if (showFollowBtn)
            GestureDetector(
              onTap: () {
                setState(() => _newlyFollowed.add(creatorId));
                MediaService().toggleFollow(creatorId);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: const Text('Suivre', style: TextStyle(color: MediaColors.navyDeep, fontSize: 13, fontWeight: FontWeight.w900)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionsBar(dynamic live) {
    final item = widget.item;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                _detailActionBtn(
                  icon: _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  label: formatMediaNumber(live?.likeCount ?? item.likeCount),
                  color: _liked ? MediaColors.danger : Colors.white,
                  onTap: _toggleLike,
                ),
                _detailActionBtn(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: formatMediaNumber(live?.commentCount ?? item.commentCount),
                  color: Colors.white,
                  onTap: _openComments,
                ),
                _detailActionBtn(
                  icon: Icons.remove_red_eye_outlined,
                  label: formatMediaNumber(live?.viewCount ?? item.viewCount),
                  color: Colors.white70,
                  onTap: () {},
                ),
                _detailActionBtn(
                  icon: _saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  label: 'Sauver',
                  color: _saved ? Colors.white : Colors.white70,
                  onTap: _toggleSave,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('À découvrir aussi', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 14,
            childAspectRatio: 0.68,
          ),
          itemCount: _suggestions.length,
          itemBuilder: (c, i) => MediaPosterCard(
            item: _suggestions[i],
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => MediaDetailPage(item: _suggestions[i], catalog: widget.catalog)),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _detailActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaywall(MediaContent item) {
    return Container(
      decoration: item.coverUrl.isNotEmpty
          ? BoxDecoration(image: DecorationImage(image: CachedNetworkImageProvider(item.coverUrl), fit: BoxFit.cover))
          : const BoxDecoration(color: MediaColors.card),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          color: MediaColors.navyDeep.withOpacity(0.75),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                child: const Icon(Icons.lock_rounded, size: 40, color: MediaColors.navyDeep),
              ),
              const SizedBox(height: 20),
              const Text('Contenu Premium', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Text(
                  "Fin de l'aperçu gratuit. Débloquez la suite pour ${_formatPrice()}.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.gold,
                  foregroundColor: MediaColors.navyDeep,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: () {
                  // TODO: Intégrer avec le système de paiement
                  setState(() {
                    _unlocked = true;
                    _previewExpired = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vidéo débloquée avec succès !'),
                      backgroundColor: MediaColors.success,
                    ),
                  );
                },
                child: Text('Débloquer (${_formatPrice()})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
