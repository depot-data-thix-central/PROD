// lib/presentation/network/widgets/post_card.dart
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';

import 'package:thix_id/features/network/presentation/providers/feed_provider.dart';
import 'package:thix_id/models/network_post.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';

// ✅ DESIGN SYSTEM THIX
import 'package:thix_id/core/theme/thix_design_policy.dart';

// ✅ CERTIFICATION & SYNCHRO PROFIL
import 'package:thix_id/models/certification_tier.dart';
import 'package:thix_id/presentation/certification/widgets/certification_name_badge.dart';
import 'package:thix_id/features/network/presentation/providers/user_profile_providers.dart';

// ─── HELPER POUR FORMATER LES COMPTEURS ───
String _formatCountHelper(int count) {
  if (count >= 1000000) {
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
  return '$count';
}

// ─── HELPER : DÉTECTION VIDÉO PAR EXTENSION ET MOT-CLÉ ───
bool _isVideoUrl(String url) {
  final lower = url.toLowerCase();
  return lower.contains('.mp4') ||
      lower.contains('.mov') ||
      lower.contains('.m4v') ||
      lower.contains('.webm') ||
      lower.contains('.avi') ||
      lower.contains('.mkv') ||
      lower.contains('/videos/') ||
      lower.contains('/video/');
}

// ─────────────────────────────────────────────────────────────
// STATE NOTIFIER DU POST
// ─────────────────────────────────────────────────────────────
final postItemProvider = StateNotifierProvider.autoDispose<PostItemNotifier, NetworkPost>(
  (ref) => throw UnimplementedError('must override'),
);

class PostItemNotifier extends StateNotifier<NetworkPost> {
  PostItemNotifier(super.post, this.ref);
  final Ref ref;
  bool _likeBusy = false;

  Future<void> toggleLike() async {
    if (_likeBusy) return;
    _likeBusy = true;

    final wasLiked = state.isLiked;
    final oldCount = state.likesCount;

    state = state.copyWith(
      isLiked: !wasLiked,
      likesCount: wasLiked ? (oldCount - 1).clamp(0, 1 << 30) : oldCount + 1,
    );

    try {
      final s = ref.read(networkServiceProvider);
      try {
        final r = await s.togglePostLike(state.id);
        state = state.copyWith(isLiked: r.liked, likesCount: r.likesCount);
      } catch (_) {
        if (wasLiked) {
          await s.unlikePost(state.id);
        } else {
          await s.likePost(state.id);
        }
      }
    } catch (_) {
      state = state.copyWith(isLiked: wasLiked, likesCount: oldCount);
    } finally {
      _likeBusy = false;
    }
  }

  Future<void> toggleSave() async {
    final was = state.isSaved;
    state = state.copyWith(isSaved: !was);
    try {
      final s = ref.read(networkServiceProvider);
      if (was) {
        await s.unsavePost(state.id);
      } else {
        await s.savePost(state.id);
      }
    } catch (_) {
      state = state.copyWith(isSaved: was);
    }
  }

  void updateContent(String c) => state = state.copyWith(content: c);

  void incRepost() => state = state.copyWith(
        repostsCount: state.repostsCount + 1,
        isReposted: true,
      );
}

// ─────────────────────────────────────────────────────────────
// COMPOSANT PRINCIPAL — POST CARD
// ─────────────────────────────────────────────────────────────
class PostCard extends ConsumerStatefulWidget {
  final NetworkPost post;
  final String currentProfileId;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onTap;
  final VoidCallback? onShare;
  final VoidCallback? onRefresh;
  final VoidCallback? onPin;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onSave;

  final bool isFollowingAuthor;
  final VoidCallback? onFollow;

  const PostCard({
    super.key,
    required this.post,
    required this.currentProfileId,
    this.onLike,
    this.onComment,
    this.onTap,
    this.onShare,
    this.onRefresh,
    this.onPin,
    this.onEdit,
    this.onDelete,
    this.onSave,
    this.isFollowingAuthor = false,
    this.onFollow,
  });

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isReposting = false;
  bool _isLikedAnimating = false;
  bool _isExpanded = false;
  final _quoteController = TextEditingController();

  bool _isFollowingLocal = false;
  bool _followBusy = false;

  static const _maxContentChars = 250;
  static const _maxParseDepth = 6;

  static final _richContentRegex = RegExp(
    r'\{c:(#[0-9A-Fa-f]{6,8})\}([\s\S]*?)\{c\}|'
    r'\*\*([\s\S]+?)\*\*|'
    r'\*([\s\S]+?)\*|'
    r'@(\w+)|'
    r'#(\w+)',
  );

  List<InlineSpan>? _cachedFullSpans;
  List<InlineSpan>? _cachedTruncatedSpans;
  bool _isTruncatable = false;
  final List<GestureRecognizer> _recognizers = [];

  @override
  void initState() {
    super.initState();
    _isFollowingLocal = widget.isFollowingAuthor;
    _cacheParsedContent();
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFollowingAuthor != widget.isFollowingAuthor) {
      _isFollowingLocal = widget.isFollowingAuthor;
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    _quoteController.dispose();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  void _cacheParsedContent() {
    final content = widget.post.content;
    final baseStyle = ThixPolicy.bodyStyle.copyWith(height: 1.48);

    _cachedFullSpans = _parseContent(content, baseStyle, 0);
    _isTruncatable = content.length > _maxContentChars;

    if (_isTruncatable) {
      var truncated = content.substring(0, _maxContentChars);
      final lastSpace = truncated.lastIndexOf(' ');
      if (lastSpace > 0) truncated = truncated.substring(0, lastSpace);
      _cachedTruncatedSpans = _parseContent('$truncated…', baseStyle, 0);
    } else {
      _cachedTruncatedSpans = _cachedFullSpans;
    }
  }

  List<InlineSpan> _parseContent(String content, TextStyle baseStyle, int depth) {
    if (depth > _maxParseDepth || content.isEmpty) {
      return [TextSpan(text: content, style: baseStyle)];
    }

    final spans = <InlineSpan>[];
    var lastIndex = 0;

    for (final match in _richContentRegex.allMatches(content)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: content.substring(lastIndex, match.start), style: baseStyle));
      }

      if (match.group(1) != null) {
        final hex = match.group(1)!.replaceFirst('#', '');
        final inner = match.group(2) ?? '';
        Color color;
        try {
          final argb = hex.length == 8 ? hex : 'FF$hex';
          color = Color(int.parse(argb, radix: 16));
        } catch (_) {
          color = baseStyle.color ?? ThixPolicy.textMain;
        }
        spans.addAll(_parseContent(inner, baseStyle.copyWith(color: color), depth + 1));
      } else if (match.group(3) != null) {
        spans.addAll(_parseContent(match.group(3)!, baseStyle.copyWith(fontWeight: ThixPolicy.bold), depth + 1));
      } else if (match.group(4) != null) {
        spans.addAll(_parseContent(match.group(4)!, baseStyle.copyWith(fontStyle: FontStyle.italic), depth + 1));
      } else if (match.group(5) != null) {
        final value = match.group(5)!;
        final r = TapGestureRecognizer()..onTap = () { if (mounted) context.push('/network/profile/$value'); };
        _recognizers.add(r);
        spans.add(TextSpan(
          text: '@$value',
          style: baseStyle.copyWith(color: ThixPolicy.primary, fontWeight: ThixPolicy.semiBold),
          recognizer: r,
        ));
      } else if (match.group(6) != null) {
        final value = match.group(6)!;
        final r = TapGestureRecognizer()..onTap = () { if (mounted) context.push('/hashtag/$value'); };
        _recognizers.add(r);
        spans.add(TextSpan(
          text: '#$value',
          style: baseStyle.copyWith(color: ThixPolicy.primaryDeep, fontWeight: ThixPolicy.semiBold),
          recognizer: r,
        ));
      }

      lastIndex = match.end;
    }

    if (lastIndex < content.length) {
      spans.add(TextSpan(text: content.substring(lastIndex), style: baseStyle));
    }

    return spans;
  }

  Color? _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return null;
    final hexCode = hexColor.replaceAll('#', '');
    if (hexCode.length == 6 || hexCode.length == 8) {
      try {
        return Color(int.parse(hexCode.length == 6 ? 'FF$hexCode' : hexCode, radix: 16));
      } catch (_) {}
    }
    return null;
  }

  Widget _buildPostContent(NetworkPost post) {
    if (post.content.isEmpty) return const SizedBox.shrink();
    final bgColor = _parseColor(post.bgColor);
    if (bgColor != null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: ThixPolicy.s8),
        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20, vertical: ThixPolicy.s40),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        alignment: Alignment.center,
        child: Text(
          post.content,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, height: 1.3),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(text: TextSpan(children: _isExpanded ? (_cachedFullSpans ?? []) : (_cachedTruncatedSpans ?? []))),
        if (_isTruncatable)
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _isExpanded ? 'Voir moins' : 'Voir plus',
                style: const TextStyle(color: ThixPolicy.primary, fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }

  String _getTimeAgo(DateTime dt) => timeago.format(dt.toLocal(), locale: 'fr');

  void _openPostDetails(String postId) {
    if (!mounted) return;
    context.push('/network/comments/$postId');
  }

  void _openGallery(int initialIndex, List<String> imageOnlyUrls) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _FullScreenGallery(imageUrls: imageOnlyUrls, initialIndex: initialIndex)));
  }

  void _openVideoFullScreen(String url) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _FullScreenVideoPlayer(videoUrl: url)));
  }

  // ── MÉDIAS MIXTES : photos + vidéos dans la même grille ──
  Widget _buildMediaGrid(List<String> urls) {
    if (urls.isEmpty) return const SizedBox.shrink();
    const spacing = 4.0;
    final radius = BorderRadius.circular(ThixPolicy.rMd);
    final imageOnlyUrls = urls.where((u) => !_isVideoUrl(u)).toList();

    Widget mediaTile(String url, {double? width, double? height}) {
      if (_isVideoUrl(url)) {
        return _VideoThumbTile(
          videoUrl: url,
          width: width,
          height: height,
          onTap: () => _openVideoFullScreen(url),
        );
      }
      return GestureDetector(
        onTap: () => _openGallery(imageOnlyUrls.indexOf(url), imageOnlyUrls),
        child: CachedNetworkImage(
          imageUrl: url,
          width: width,
          height: height,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: ThixPolicy.surfaceStrong,
            child: const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary))),
          ),
          errorWidget: (context, url, error) => Container(
            color: ThixPolicy.surfaceStrong,
            child: const Icon(Icons.broken_image_outlined, color: ThixPolicy.textMuted),
          ),
        ),
      );
    }

    if (urls.length == 1) {
      return LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = (w * 1.05).clamp(220.0, 480.0);
          return ClipRRect(
            borderRadius: radius,
            child: SizedBox(width: w, height: h, child: mediaTile(urls[0], width: w, height: h)),
          );
        },
      );
    }

    Widget cell(int i, double h) => Expanded(
          child: ClipRRect(
            borderRadius: radius,
            child: mediaTile(urls[i], height: h, width: double.infinity),
          ),
        );

    if (urls.length == 2) {
      return SizedBox(
        height: 200,
        child: Row(children: [cell(0, 200), const SizedBox(width: spacing), cell(1, 200)]),
      );
    }

    // 3+
    return SizedBox(
      height: 240,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: ClipRRect(borderRadius: radius, child: mediaTile(urls[0], height: 240, width: double.infinity)),
          ),
          const SizedBox(width: spacing),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Expanded(child: ClipRRect(borderRadius: radius, child: mediaTile(urls[1], width: double.infinity, height: double.infinity))),
                const SizedBox(height: spacing),
                Expanded(
                  child: ClipRRect(
                    borderRadius: radius,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        mediaTile(urls[2]),
                        if (urls.length > 3)
                          Container(
                            color: Colors.black54,
                            alignment: Alignment.center,
                            child: Text('+${urls.length - 3}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── SONDAGE ──
  Widget _buildPollWidget(NetworkPost post) {
    final pollData = post.pollData ?? {};
    final options = (pollData['options'] as List?) ?? [];
    if (options.isEmpty) return const SizedBox.shrink();

    var totalVotes = 0;
    for (final opt in options) {
      totalVotes += ((opt['votes'] as List?)?.length ?? 0);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ThixPolicy.s16),
      decoration: BoxDecoration(
        color: ThixPolicy.surface,
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.poll_rounded, size: 18, color: ThixPolicy.primary),
              SizedBox(width: ThixPolicy.s8),
              Text('Sondage', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: ThixPolicy.textMain)),
            ],
          ),
          const SizedBox(height: ThixPolicy.s12),
          ...options.asMap().entries.map((entry) {
            final index = entry.key;
            final opt = entry.value;
            final text = '${opt['text'] ?? ''}';
            final voters = (opt['votes'] as List?) ?? [];
            final pct = totalVotes > 0 ? voters.length / totalVotes : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                  onTap: () async {
                    try {
                      await ref.read(networkServiceProvider).votePoll(post.id, index);
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur vote: $e'), backgroundColor: ThixPolicy.danger));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(ThixPolicy.s12),
                    decoration: BoxDecoration(
                      color: ThixPolicy.card,
                      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                      border: Border.all(color: ThixPolicy.border),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: pct.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: ThixPolicy.primary.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(ThixPolicy.rXs),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: ThixPolicy.textMain))),
                            Text('${(pct * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ThixPolicy.primaryDeep)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          if (totalVotes > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('$totalVotes vote${totalVotes > 1 ? 's' : ''}', style: const TextStyle(fontSize: 11, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  // ── CHALLENGE ──
  Widget _buildChallengeWidget(NetworkPost post) {
    final data = post.challengeData ?? {};
    final description = '${data['description'] ?? ''}';
    final participantsCount = data['participants_count'] ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ThixPolicy.s16),
      decoration: BoxDecoration(
        color: ThixPolicy.surface,
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: ThixPolicy.inkDeep, shape: BoxShape.circle),
                child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(child: Text('Challenge THIX', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: ThixPolicy.textMain))),
              Text('$participantsCount participants', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ThixPolicy.textSecondary)),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(description, style: const TextStyle(fontSize: 13.5, height: 1.4, color: ThixPolicy.textMain)),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Participation enregistrée'), backgroundColor: ThixPolicy.success)),
              style: OutlinedButton.styleFrom(
                foregroundColor: ThixPolicy.textMain, 
                side: const BorderSide(color: ThixPolicy.inkDeep),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
              ),
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: const Text('RELEVER LE DÉFI', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.3)),
            ),
          ),
        ],
      ),
    );
  }

  // ── FACT-CHECK IA ──
  Widget _buildFactCheckBanner(bool isMisinformation, String? message) {
    if (!isMisinformation || message == null || message.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: ThixPolicy.s12),
      padding: const EdgeInsets.all(ThixPolicy.s12),
      decoration: BoxDecoration(
        color: ThixPolicy.danger.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border(left: BorderSide(color: ThixPolicy.danger, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.shield_outlined, color: ThixPolicy.danger, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Fact-Check THIX IA', style: TextStyle(color: ThixPolicy.danger, fontWeight: FontWeight.w800, fontSize: 11.5, letterSpacing: 0.2)),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(color: ThixPolicy.textMain, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionPill({required IconData icon, required String label, required VoidCallback? onTap, Color? color, Widget? animatedIcon}) {
    final c = color ?? ThixPolicy.textSecondary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              animatedIcon ?? Icon(icon, size: 18, color: c),
              const SizedBox(width: 6),
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w700))),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ProviderScope(
      overrides: [
        postItemProvider.overrideWith((ref) => PostItemNotifier(widget.post, ref)),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          final post = ref.watch(postItemProvider);
          final isLiked = ref.watch(postItemProvider.select((p) => p.isLiked));
          final likesCount = ref.watch(postItemProvider.select((p) => p.likesCount));
          final isOwner = widget.currentProfileId == post.userId;

          // 1. Récupération des données du profil de l'auteur
          final authorProfile = ref.watch(userProfileProvider(post.userId)).valueOrNull;
          
          CertificationTier? tier;
          CertificationStatus? status;
          bool isCertified = false;
          bool isLegacyVerified = false;

          if (authorProfile != null) {
            tier = CertificationTierX.parse(authorProfile['certification_tier']);
            status = CertificationStatusX.parse(authorProfile['certification_status']);
            isCertified = status == CertificationStatus.approved || status == CertificationStatus.generated;
            isLegacyVerified = authorProfile['is_verified'] == true;
          }

          // 2. Récupération des données du profil de l'utilisateur COURANT (pour bloquer "Modifier")
          final currentUserProfile = ref.watch(userProfileProvider(widget.currentProfileId)).valueOrNull;
          bool isCurrentUserFree = true; // Gratuit par défaut
          
          if (currentUserProfile != null) {
            final currentTierStr = (currentUserProfile['certification_tier']?.toString().toLowerCase()) ?? 'gratuit';
            isCurrentUserFree = currentTierStr == 'gratuit' || currentTierStr == 'none';
          }

          // Détermination du statut de Follow
          final isFollowingDB = ref.watch(followStatusProvider(post.userId)).valueOrNull;
          final isFollowing = isFollowingDB ?? _isFollowingLocal;

          return Container(
            decoration: BoxDecoration(
              color: ThixPolicy.card,
              borderRadius: BorderRadius.circular(ThixPolicy.cardRadius),
              border: Border.all(color: ThixPolicy.border),
              boxShadow: ThixPolicy.shadowCard(),
            ),
            clipBehavior: Clip.antiAlias,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap ?? () => _openPostDetails(post.id),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(ThixPolicy.s16, ThixPolicy.s16, ThixPolicy.s16, ThixPolicy.s12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ─── Header ───
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => context.push('/network/profile/${post.userId}'),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ThixPolicy.border, width: 1.4)),
                                  child: CircleAvatar(
                                    radius: 20,
                                    backgroundColor: ThixPolicy.tint,
                                    backgroundImage: post.authorAvatar != null && post.authorAvatar!.isNotEmpty
                                        ? CachedNetworkImageProvider(post.authorAvatar!)
                                        : null,
                                    child: post.authorAvatar == null || post.authorAvatar!.isEmpty
                                        ? const Icon(Icons.person_rounded, size: 19, color: ThixPolicy.primaryDeep)
                                        : null,
                                  ),
                                ),
                                // Bouton "+" : Synchro parfaite
                                if (!isOwner && !isFollowing)
                                  Positioned(
                                    bottom: -2, right: -2,
                                    child: GestureDetector(
                                      onTap: () async {
                                        if (_followBusy) return;
                                        setState(() => _followBusy = true);
                                        HapticFeedback.selectionClick();
                                        setState(() => _isFollowingLocal = true);
                                        
                                        try {
                                          await ref.read(networkServiceProvider).followUser(post.userId);
                                          ref.invalidate(followStatusProvider(post.userId));
                                          ref.invalidate(userProfileProvider(post.userId));
                                          widget.onFollow?.call();
                                        } catch (_) {
                                          if (mounted) setState(() => _isFollowingLocal = false);
                                        } finally {
                                          if (mounted) setState(() => _followBusy = false);
                                        }
                                      },
                                      child: Container(
                                        width: 20, height: 20,
                                        decoration: BoxDecoration(shape: BoxShape.circle, color: ThixPolicy.primary, border: Border.all(color: Colors.white, width: 2.5)),
                                        child: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: ThixPolicy.s12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => context.push('/network/profile/${post.userId}'),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          post.authorName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                            color: ThixPolicy.textMain,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isCertified)
                                        CertificationNameBadge(
                                          tier: tier,
                                          status: status,
                                          showLabel: false,
                                          iconSize: 16,
                                          padding: const EdgeInsets.only(left: 5),
                                        )
                                      else if (isLegacyVerified)
                                        const Padding(
                                          padding: EdgeInsets.only(left: 4),
                                          child: Icon(Icons.verified_rounded, color: ThixPolicy.gold, size: 15),
                                        ),
                                    ],
                                  ),
                                  if (post.authorTitle != null && post.authorTitle!.isNotEmpty)
                                    Text(post.authorTitle!, style: const TextStyle(fontSize: 10.5, color: ThixPolicy.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text(_getTimeAgo(post.createdAt), style: const TextStyle(fontSize: 10, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),

                          // ─── Menu Contextuel ───
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, size: 18, color: ThixPolicy.textSecondary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
                            onSelected: (v) async {
                              final service = ref.read(networkServiceProvider);
                              switch (v) {
                                case 'edit':
                                  final controller = TextEditingController(text: post.content);
                                  final newContent = await showDialog<String>(
                                    context: context,
                                    builder: (dialogContext) => AlertDialog(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
                                      title: const Row(children: [Icon(Icons.edit_rounded, color: ThixPolicy.primaryDeep), SizedBox(width: 8), Text('Modifier la publication', style: TextStyle(fontSize: 16))]),
                                      content: TextField(
                                        controller: controller, maxLines: 6, autofocus: true,
                                        decoration: InputDecoration(
                                          hintText: 'Modifier votre texte...',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius)),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius), borderSide: const BorderSide(color: ThixPolicy.primaryDeep, width: 1.5)),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler', style: TextStyle(color: ThixPolicy.textSecondary))),
                                        ElevatedButton(
                                          onPressed: () { final text = controller.text.trim(); if (text.isNotEmpty) Navigator.pop(dialogContext, text); },
                                          style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primaryDeep, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm))),
                                          child: const Text('Enregistrer'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (newContent != null && newContent.isNotEmpty && context.mounted) {
                                    try {
                                      if (widget.onEdit != null) widget.onEdit!(); else await service.updatePost(post.id, newContent);
                                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Publication modifiée'), behavior: SnackBarBehavior.floating));
                                    } catch (e) {
                                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors de la modification'), backgroundColor: ThixPolicy.danger, behavior: SnackBarBehavior.floating));
                                    }
                                  }
                                  break;
                                case 'delete':
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (dialogContext) => AlertDialog(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
                                      title: const Row(children: [Icon(Icons.warning_amber_rounded, color: ThixPolicy.danger), SizedBox(width: 8), Text('Supprimer', style: TextStyle(color: ThixPolicy.danger))]),
                                      content: const Text('Êtes-vous sûr de vouloir supprimer définitivement cette publication ?', style: TextStyle(color: ThixPolicy.textMain, height: 1.4)),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler', style: TextStyle(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600))),
                                        ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm))), child: const Text('Supprimer', style: TextStyle(fontWeight: FontWeight.bold))),
                                      ],
                                    ),
                                  );
                                  if (ok == true && context.mounted) {
                                    try {
                                      if (widget.onDelete != null) widget.onDelete!(); else await service.deletePost(post.id);
                                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Publication supprimée'), behavior: SnackBarBehavior.floating));
                                    } catch (e) {
                                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors de la suppression'), backgroundColor: ThixPolicy.danger, behavior: SnackBarBehavior.floating));
                                    }
                                  }
                                  break;
                                case 'save':
                                  await ref.read(postItemProvider.notifier).toggleSave();
                                  widget.onSave?.call();
                                  break;
                                case 'repost':
                                  await _repost(post, ref);
                                  break;
                                case 'hide':
                                  await service.hidePost(post.id);
                                  break;
                                case 'share':
                                  widget.onShare?.call();
                                  break;
                              }
                            },
                            itemBuilder: (_) => [
                              // ✅ MASQUER L'OPTION 'MODIFIER' POUR LES COMPTES GRATUITS
                              if (isOwner && !isCurrentUserFree) 
                                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18, color: ThixPolicy.textMain), SizedBox(width: 10), Text('Modifier')])),
                              
                              if (isOwner) const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: ThixPolicy.danger), SizedBox(width: 10), Text('Supprimer', style: TextStyle(color: ThixPolicy.danger))])),
                              const PopupMenuItem(value: 'save', child: Row(children: [Icon(Icons.bookmark_border_rounded, size: 18, color: ThixPolicy.textMain), SizedBox(width: 10), Text('Sauvegarder')])),
                              const PopupMenuItem(value: 'repost', child: Row(children: [Icon(Icons.repeat_rounded, size: 18, color: ThixPolicy.textMain), SizedBox(width: 10), Text('Reposter')])),
                              const PopupMenuItem(value: 'hide', child: Row(children: [Icon(Icons.visibility_off_outlined, size: 18, color: ThixPolicy.textMain), SizedBox(width: 10), Text('Masquer')])),
                              const PopupMenuItem(value: 'share', child: Row(children: [Icon(Icons.share_outlined, size: 18, color: ThixPolicy.textMain), SizedBox(width: 10), Text('Partager')])),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: ThixPolicy.s12),

                      if (post.isRepostCard)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(Icons.repeat_rounded, size: 14, color: ThixPolicy.textSecondary),
                              SizedBox(width: 6),
                              Text('a reposté', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ThixPolicy.textSecondary)),
                            ],
                          ),
                        ),

                      // ─── TEXTE ───
                      _buildPostContent(post),

                      if (post.isRepostCard && post.repostOfId != null && post.repostOfId!.isNotEmpty) ...[
                        const SizedBox(height: ThixPolicy.s8),
                        _OriginalPostEmbed(postId: post.repostOfId!),
                      ],

                      // ─── MÉDIAS MIXTES ───
                      if (!post.isRepostCard && (post.hasImages || post.hasVideos)) ...[
                        const SizedBox(height: 10),
                        _buildMediaGrid([...post.imageUrls, ...post.videoUrls]),
                      ],

                      // ─── AUDIO ───
                      if (post.hasAudio && post.audioUrls.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _ThixWaveformAudioPlayer(audioUrl: post.audioUrls.first),
                      ],

                      // ─── TYPES SPÉCIAUX ───
                      if (post.postType == 'poll') ...[
                        const SizedBox(height: 10),
                        _buildPollWidget(post),
                      ] else if (post.postType == 'challenge') ...[
                        const SizedBox(height: 10),
                        _buildChallengeWidget(post),
                      ],

                      // ─── FACT-CHECK ───
                      _buildFactCheckBanner(post.isMisinformation, post.factCheckMessage),

                      const SizedBox(height: ThixPolicy.s12),
                      const Divider(height: 1, color: ThixPolicy.border),

                      // ─── Actions ───
                      Row(
                        children: [
                          _actionPill(
                            icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            label: _formatCountHelper(likesCount),
                            color: isLiked ? ThixPolicy.danger : ThixPolicy.textSecondary,
                            animatedIcon: AnimatedScale(
                              scale: _isLikedAnimating ? 1.25 : 1.0,
                              duration: const Duration(milliseconds: 180),
                              child: Icon(isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isLiked ? ThixPolicy.danger : ThixPolicy.textSecondary, size: 19),
                            ),
                            onTap: () async {
                              setState(() => _isLikedAnimating = true);
                              await ref.read(postItemProvider.notifier).toggleLike();
                              Future.delayed(const Duration(milliseconds: 280), () { if (mounted) setState(() => _isLikedAnimating = false); });
                            },
                          ),
                          _actionPill(icon: Icons.chat_bubble_outline_rounded, label: _formatCountHelper(post.commentsCount), onTap: widget.onComment ?? () => _openPostDetails(post.id)),
                          _actionPill(icon: Icons.repeat_rounded, label: _formatCountHelper(post.repostsCount), color: post.isReposted ? ThixPolicy.success : ThixPolicy.textSecondary, onTap: () => _repost(post, ref)),
                          _actionPill(icon: Icons.share_rounded, label: 'Partager', onTap: widget.onShare),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _repost(NetworkPost post, WidgetRef ref) async {
    if (_isReposting) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: const Text('Reposter'),
        content: TextField(
          controller: _quoteController, maxLines: 3,
          decoration: InputDecoration(hintText: 'Commentaire optionnel', border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler', style: TextStyle(color: ThixPolicy.textSecondary))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: ThixPolicy.onBrand), child: const Text('Reposter')),
        ],
      ),
    );
    if (result != true) return;

    setState(() => _isReposting = true);
    final quote = _quoteController.text.trim();

    try {
      final created = await ref.read(networkServiceProvider).repostPost(post.id, quote: quote.isEmpty ? null : quote);
      if (!mounted) return;
      ref.read(postItemProvider.notifier).incRepost();
      if (created != null) ref.read(feedProvider.notifier).addPostOnTop(created);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reposté sur votre fil'), backgroundColor: ThixPolicy.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: ThixPolicy.danger));
    } finally {
      if (mounted) setState(() => _isReposting = false);
      _quoteController.clear();
    }
  }
}

// ─────────────────────────────────────────────────────────────
// EMBED ORIGINAL POST
// ─────────────────────────────────────────────────────────────
class _OriginalPostEmbed extends ConsumerWidget {
  final String postId;
  const _OriginalPostEmbed({required this.postId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<NetworkPost?>(
      future: ref.read(networkServiceProvider).getPostById(postId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Container(
            height: 80, alignment: Alignment.center,
            decoration: BoxDecoration(color: ThixPolicy.surface, borderRadius: BorderRadius.circular(ThixPolicy.rLg), border: Border.all(color: ThixPolicy.border)),
            child: const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: ThixPolicy.primary)),
          );
        }
        final original = snap.data;
        if (original == null) {
          return Container(
            padding: const EdgeInsets.all(ThixPolicy.s12),
            decoration: BoxDecoration(color: ThixPolicy.surface, borderRadius: BorderRadius.circular(ThixPolicy.rLg), border: Border.all(color: ThixPolicy.border)),
            child: const Row(children: [Icon(Icons.info_outline, size: 18, color: ThixPolicy.textSecondary), SizedBox(width: 8), Text('Publication d\'origine indisponible', style: TextStyle(fontSize: 12, color: ThixPolicy.textSecondary))]),
          );
        }

        final originalAuthorProfile = ref.watch(userProfileProvider(original.userId)).valueOrNull;
        
        CertificationTier? originalTier;
        CertificationStatus? originalStatus;
        bool originalIsCertified = false;
        bool originalIsLegacyVerified = false;

        if (originalAuthorProfile != null) {
          originalTier = CertificationTierX.parse(originalAuthorProfile['certification_tier']);
          originalStatus = CertificationStatusX.parse(originalAuthorProfile['certification_status']);
          originalIsCertified = originalStatus == CertificationStatus.approved || originalStatus == CertificationStatus.generated;
          originalIsLegacyVerified = originalAuthorProfile['is_verified'] == true;
        }

        final originalMedia = [...original.imageUrls, ...original.videoUrls];

        return Container(
          decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(ThixPolicy.rLg), border: Border.all(color: ThixPolicy.border)),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.push('/network/comments/${original.id}'),
              child: Padding(
                padding: const EdgeInsets.all(ThixPolicy.s12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14, backgroundColor: ThixPolicy.tint,
                          backgroundImage: original.authorAvatar != null && original.authorAvatar!.isNotEmpty ? CachedNetworkImageProvider(original.authorAvatar!) : null,
                          child: original.authorAvatar == null || original.authorAvatar!.isEmpty ? const Icon(Icons.person, size: 16, color: ThixPolicy.primaryDeep) : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  original.authorName, 
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: ThixPolicy.textMain), 
                                  maxLines: 1, 
                                  overflow: TextOverflow.ellipsis
                                ),
                              ),
                              if (originalIsCertified)
                                CertificationNameBadge(
                                  tier: originalTier, 
                                  status: originalStatus, 
                                  showLabel: false,
                                  iconSize: 14, 
                                  padding: const EdgeInsets.only(left: 4)
                                )
                              else if (originalIsLegacyVerified)
                                const Padding(
                                  padding: EdgeInsets.only(left: 4), 
                                  child: Icon(Icons.verified_rounded, color: ThixPolicy.gold, size: 14)
                                ),
                            ],
                          ),
                        ),
                        Text(timeago.format(original.createdAt.toLocal(), locale: 'fr'), style: const TextStyle(fontSize: 10, color: ThixPolicy.textSecondary)),
                      ],
                    ),
                    if (original.content.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(original.content, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, height: 1.35, color: ThixPolicy.textMain)),
                    ],
                    if (originalMedia.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                        child: _isVideoUrl(originalMedia.first)
                            ? _VideoThumbTile(videoUrl: originalMedia.first, height: 140, onTap: () {})
                            : CachedNetworkImage(
                                imageUrl: originalMedia.first, height: 140, width: double.infinity, fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => const SizedBox.shrink(),
                              ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: ThixPolicy.border),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _miniStatRow(Icons.favorite_border_rounded, _formatCountHelper(original.likesCount)),
                        const SizedBox(width: 16),
                        _miniStatRow(Icons.chat_bubble_outline_rounded, _formatCountHelper(original.commentsCount)),
                        const SizedBox(width: 16),
                        _miniStatRow(Icons.repeat_rounded, _formatCountHelper(original.repostsCount)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _miniStatRow(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: ThixPolicy.textSecondary),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ThixPolicy.textSecondary)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// GALERIE PLEIN ÉCRAN (images uniquement)
// ─────────────────────────────────────────────────────────────
class _FullScreenGallery extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  const _FullScreenGallery({required this.imageUrls, required this.initialIndex});
  @override State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.imageUrls.isEmpty ? 0 : widget.imageUrls.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() { _pageController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (_, index) => Center(
              child: InteractiveViewer(
                minScale: 1, maxScale: 4,
                child: CachedNetworkImage(
                  imageUrl: widget.imageUrls[index], fit: BoxFit.contain,
                  placeholder: (_, __) => const CircularProgressIndicator(color: ThixPolicy.primary),
                  errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 48),
                ),
              ),
            ),
          ),
          Positioned(top: 12, right: 12, child: SafeArea(child: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close, color: Colors.white)))),
          if (widget.imageUrls.length > 1)
            Positioned(top: 16, left: 0, right: 0, child: SafeArea(child: Center(child: Text('${_currentIndex + 1} / ${widget.imageUrls.length}', style: const TextStyle(color: Colors.white70))))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TUILE VIDÉO
// ─────────────────────────────────────────────────────────────
class _VideoThumbTile extends StatefulWidget {
  final String videoUrl;
  final double? width;
  final double? height;
  final VoidCallback onTap;
  const _VideoThumbTile({required this.videoUrl, this.width, this.height, required this.onTap});

  @override
  State<_VideoThumbTile> createState() => _VideoThumbTileState();
}

class _VideoThumbTileState extends State<_VideoThumbTile> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) setState(() => _ready = true);
      }).catchError((_) {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: widget.width,
        height: widget.height,
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_ready && _controller != null)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              )
            else
              const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54))),
            Container(color: Colors.black.withValues(alpha: 0.18)),
            const Center(
              child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 46),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// LECTEUR VIDÉO PLEIN ÉCRAN
// ─────────────────────────────────────────────────────────────
class _FullScreenVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const _FullScreenVideoPlayer({required this.videoUrl});

  @override
  State<_FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<_FullScreenVideoPlayer> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _ready = true);
          _controller.play();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: _ready
                ? AspectRatio(aspectRatio: _controller.value.aspectRatio, child: VideoPlayer(_controller))
                : const CircularProgressIndicator(color: ThixPolicy.primary),
          ),
          if (_ready)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _controller.value.isPlaying ? _controller.pause() : _controller.play()),
                child: AnimatedOpacity(
                  opacity: _controller.value.isPlaying ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: const Center(child: Icon(Icons.play_arrow_rounded, color: Colors.white70, size: 72)),
                ),
              ),
            ),
          Positioned(top: 12, right: 12, child: SafeArea(child: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close, color: Colors.white)))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// LECTEUR AUDIO 
// ─────────────────────────────────────────────────────────────
class _ThixWaveformAudioPlayer extends StatefulWidget {
  final String audioUrl;
  const _ThixWaveformAudioPlayer({required this.audioUrl});
  @override State<_ThixWaveformAudioPlayer> createState() => _ThixWaveformAudioPlayerState();
}

class _ThixWaveformAudioPlayerState extends State<_ThixWaveformAudioPlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  static final List<double> _wavePattern = List.generate(48, (i) {
    final base = 0.35 + 0.55 * (0.5 + 0.5 * _sinApprox(i / 48 * 6.28));
    final micro = (i % 5 == 0) ? 0.12 : 0.0;
    return (base + micro).clamp(0.22, 1.0);
  });

  static double _sinApprox(double x) {
    return _sin(x);
  }

  static double _sin(double x) {
    final x2 = x * x;
    return x - (x * x2) / 6 + (x * x2 * x2) / 120 - (x * x2 * x2 * x2) / 5040;
  }

  @override
  void initState() {
    super.initState();
    _audioPlayer.setSourceUrl(widget.audioUrl);
    _audioPlayer.onPlayerStateChanged.listen((state) { if (mounted) setState(() => _isPlaying = state == PlayerState.playing); });
    _audioPlayer.onDurationChanged.listen((d) { if (mounted) setState(() => _duration = d); });
    _audioPlayer.onPositionChanged.listen((p) { if (mounted) setState(() => _position = p); });
  }

  @override
  void dispose() { _audioPlayer.dispose(); super.dispose(); }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0 ? _position.inMilliseconds / _duration.inMilliseconds : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s16),
      decoration: BoxDecoration(
        color: ThixPolicy.inkDeep,
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        boxShadow: ThixPolicy.shadowSoft(),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () { if (_isPlaying) _audioPlayer.pause(); else _audioPlayer.play(UrlSource(widget.audioUrl)); },
            child: Container(
              width: 52, height: 52,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: ThixPolicy.inkDeep, size: 28),
            ),
          ),
          const SizedBox(width: ThixPolicy.s16),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const barWidth = 2.6;
                const spacing = 2.2;
                const totalBarWidth = barWidth + spacing;
                final barCount = (constraints.maxWidth / totalBarWidth).floor();

                return GestureDetector(
                  onTapDown: (details) {
                    if (_duration.inMilliseconds > 0) {
                      final tapProgress = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                      _audioPlayer.seek(Duration(milliseconds: (_duration.inMilliseconds * tapProgress).round()));
                    }
                  },
                  child: SizedBox(
                    height: 44,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: List.generate(barCount, (index) {
                        final baseHeight = _wavePattern[index % _wavePattern.length];
                        final isPlayed = (index / barCount) <= progress;
                        return Container(
                          width: barWidth,
                          height: 44 * baseHeight,
                          margin: const EdgeInsets.only(right: spacing),
                          decoration: BoxDecoration(
                            color: isPlayed ? Colors.white : Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: ThixPolicy.s14),
          Text(
            _formatDuration(_duration.inSeconds > 0 && !_isPlaying && _position.inSeconds == 0 ? _duration : _position),
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
