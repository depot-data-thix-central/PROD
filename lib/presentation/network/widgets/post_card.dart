// lib/presentation/network/widgets/post_card.dart
import 'dart:math';
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
  if (count == 0) return '';
  if (count >= 1000000) {
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
  return '$count';
}

// ─── HELPER : DÉTECTION VIDÉO ───
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
// COULEURS SPÉCIFIQUES "BLANC ÉPURÉ" ET IMPULSION
// ─────────────────────────────────────────────────────────────
class _PostColors {
  static const Color surface = Colors.white;
  static const Color navyText = Color(0xFF0A1F44);
  static const Color textMuted = Color(0xFF8A94A6);
  static const Color primary = Color(0xFF2D6CDF);
  static const Color coral = Color(0xFFFF6B6B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color softBg = Color(0xFFF8FAFC);
}

class _PulseColors {
  static const gold = Color(0xFFE3B23C);
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
// COMPOSANT PRINCIPAL — POST CARD (Nouveau Design)
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
    final baseStyle = const TextStyle(color: _PostColors.navyText, fontSize: 14.5, height: 1.5);

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
          color = baseStyle.color ?? _PostColors.navyText;
        }
        spans.addAll(_parseContent(inner, baseStyle.copyWith(color: color), depth + 1));
      } else if (match.group(3) != null) {
        spans.addAll(_parseContent(match.group(3)!, baseStyle.copyWith(fontWeight: FontWeight.bold), depth + 1));
      } else if (match.group(4) != null) {
        spans.addAll(_parseContent(match.group(4)!, baseStyle.copyWith(fontStyle: FontStyle.italic), depth + 1));
      } else if (match.group(5) != null) {
        final value = match.group(5)!;
        final r = TapGestureRecognizer()..onTap = () { if (mounted) context.push('/network/profile/$value'); };
        _recognizers.add(r);
        spans.add(TextSpan(text: '@$value', style: baseStyle.copyWith(color: _PostColors.primary, fontWeight: FontWeight.bold), recognizer: r));
      } else if (match.group(6) != null) {
        final value = match.group(6)!;
        final r = TapGestureRecognizer()..onTap = () { if (mounted) context.push('/hashtag/$value'); };
        _recognizers.add(r);
        spans.add(TextSpan(text: '#$value', style: baseStyle.copyWith(color: _PostColors.primary, fontWeight: FontWeight.bold), recognizer: r));
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
      try { return Color(int.parse(hexCode.length == 6 ? 'FF$hexCode' : hexCode, radix: 16)); } catch (_) {}
    }
    return null;
  }

  Widget _buildPostContent(NetworkPost post) {
    if (post.content.isEmpty) return const SizedBox.shrink();
    final bgColor = _parseColor(post.bgColor);
    if (bgColor != null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
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
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _isExpanded ? 'Voir moins' : 'Voir plus',
                style: const TextStyle(color: _PostColors.primary, fontSize: 13, fontWeight: FontWeight.w700),
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

  // ── MÉDIAS MIXTES ──
  Widget _buildMediaGrid(List<String> urls) {
    if (urls.isEmpty) return const SizedBox.shrink();
    const spacing = 4.0;
    final radius = BorderRadius.circular(16.0); 
    final imageOnlyUrls = urls.where((u) => !_isVideoUrl(u)).toList();

    Widget mediaTile(String url, {double? width, double? height}) {
      if (_isVideoUrl(url)) {
        return _VideoThumbTile(videoUrl: url, width: width, height: height, onTap: () => _openVideoFullScreen(url));
      }
      return GestureDetector(
        onTap: () => _openGallery(imageOnlyUrls.indexOf(url), imageOnlyUrls),
        child: CachedNetworkImage(
          imageUrl: url, width: width, height: height, fit: BoxFit.cover,
          placeholder: (context, url) => Container(color: _PostColors.softBg, child: const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: _PostColors.primary)))),
          errorWidget: (context, url, error) => Container(color: _PostColors.softBg, child: const Icon(Icons.broken_image_outlined, color: _PostColors.textMuted)),
        ),
      );
    }

    if (urls.length == 1) {
      return LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = (w * 0.75).clamp(220.0, 480.0);
          return ClipRRect(borderRadius: radius, child: SizedBox(width: w, height: h, child: mediaTile(urls[0], width: w, height: h)));
        },
      );
    }

    Widget cell(int i, double h) => Expanded(child: ClipRRect(borderRadius: radius, child: mediaTile(urls[i], height: h, width: double.infinity)));

    if (urls.length == 2) {
      return SizedBox(height: 220, child: Row(children: [cell(0, 220), const SizedBox(width: spacing), cell(1, 220)]));
    }

    return SizedBox(
      height: 260,
      child: Row(
        children: [
          Expanded(flex: 3, child: ClipRRect(borderRadius: radius, child: mediaTile(urls[0], height: 260, width: double.infinity))),
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
                          Container(color: Colors.black54, alignment: Alignment.center, child: Text('+${urls.length - 3}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
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
    for (final opt in options) { totalVotes += ((opt['votes'] as List?)?.length ?? 0); }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _PostColors.softBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: _PostColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(children: [Icon(Icons.poll_rounded, size: 18, color: _PostColors.primary), SizedBox(width: 8), Text('Sondage', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _PostColors.navyText))]),
          const SizedBox(height: 12),
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
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    try { await ref.read(networkServiceProvider).votePoll(post.id, index); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur vote: $e'), backgroundColor: _PostColors.coral)); }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _PostColors.border)),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft, widthFactor: pct.clamp(0.0, 1.0),
                            child: Container(decoration: BoxDecoration(color: _PostColors.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8))),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _PostColors.navyText))),
                            Text('${(pct * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _PostColors.primary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _PostColors.softBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: _PostColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: _PostColors.navyText, shape: BoxShape.circle), child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 18)),
              const SizedBox(width: 10),
              const Expanded(child: Text('Challenge THIX', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _PostColors.navyText))),
              Text('$participantsCount participants', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _PostColors.textMuted)),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(description, style: const TextStyle(fontSize: 13.5, height: 1.4, color: _PostColors.navyText)),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Participation enregistrée'), backgroundColor: Colors.green)),
              style: OutlinedButton.styleFrom(foregroundColor: _PostColors.navyText, side: const BorderSide(color: _PostColors.navyText), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
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
      width: double.infinity, margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _PostColors.coral.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: const Border(left: BorderSide(color: _PostColors.coral, width: 4))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: _PostColors.coral, size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Fact-Check THIX IA', style: TextStyle(color: _PostColors.coral, fontWeight: FontWeight.w800, fontSize: 11.5)),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(color: _PostColors.navyText, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ACTIONS MODIFICATION ET SUPPRESSION (Anciens 3 points)
  // ─────────────────────────────────────────────────────────────
  Future<void> _editPost(NetworkPost post, WidgetRef ref) async {
    final controller = TextEditingController(text: post.content);
    final newContent = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _PostColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [Icon(Icons.edit_rounded, color: _PostColors.navyText), SizedBox(width: 8), Text('Modifier', style: TextStyle(fontSize: 16))]),
        content: TextField(
          controller: controller, maxLines: 6, autofocus: true,
          decoration: InputDecoration(
            hintText: 'Modifier votre texte...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _PostColors.primary, width: 1.5)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler', style: TextStyle(color: _PostColors.textMuted))),
          ElevatedButton(
            onPressed: () { final text = controller.text.trim(); if (text.isNotEmpty) Navigator.pop(dialogContext, text); },
            style: ElevatedButton.styleFrom(backgroundColor: _PostColors.navyText, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (newContent != null && newContent.isNotEmpty && mounted) {
      try {
        if (widget.onEdit != null) widget.onEdit!(); else await ref.read(networkServiceProvider).updatePost(post.id, newContent);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Publication modifiée')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur'), backgroundColor: _PostColors.coral));
      }
    }
  }

  Future<void> _deletePost(NetworkPost post, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _PostColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: _PostColors.coral), SizedBox(width: 8), Text('Supprimer', style: TextStyle(color: _PostColors.coral))]),
        content: const Text('Êtes-vous sûr de vouloir supprimer définitivement cette publication ?', style: TextStyle(color: _PostColors.navyText)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler', style: TextStyle(color: _PostColors.textMuted))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: _PostColors.coral, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        if (widget.onDelete != null) widget.onDelete!(); else await ref.read(networkServiceProvider).deletePost(post.id);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur'), backgroundColor: _PostColors.coral));
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD GLOBAL DE LA CARTE
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ProviderScope(
      overrides: [postItemProvider.overrideWith((ref) => PostItemNotifier(widget.post, ref))],
      child: Consumer(
        builder: (context, ref, _) {
          final post = ref.watch(postItemProvider);
          final isLiked = ref.watch(postItemProvider.select((p) => p.isLiked));
          final likesCount = ref.watch(postItemProvider.select((p) => p.likesCount));
          final isOwner = widget.currentProfileId == post.userId;
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

          final currentUserProfile = ref.watch(userProfileProvider(widget.currentProfileId)).valueOrNull;
          bool isCurrentUserFree = true;
          if (currentUserProfile != null) {
            final currentTierStr = (currentUserProfile['certification_tier']?.toString().toLowerCase()) ?? 'gratuit';
            isCurrentUserFree = currentTierStr == 'gratuit' || currentTierStr == 'none';
          }

          final isFollowingDB = ref.watch(followStatusProvider(post.userId)).valueOrNull;
          final isFollowing = isFollowingDB ?? _isFollowingLocal;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: _PostColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _PostColors.border.withOpacity(0.5)),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: widget.onTap ?? () => _openPostDetails(post.id),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ─── 1. HEADER (Avatar, Nom, Temps, SANS LES 3 POINTS) ───
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => context.push('/network/profile/${post.userId}'),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: _PostColors.softBg,
                                  backgroundImage: post.authorAvatar != null && post.authorAvatar!.isNotEmpty
                                      ? CachedNetworkImageProvider(post.authorAvatar!)
                                      : null,
                                  child: post.authorAvatar == null || post.authorAvatar!.isEmpty
                                      ? const Icon(Icons.person_rounded, size: 18, color: _PostColors.textMuted)
                                      : null,
                                ),
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
                                        } catch (_) { if (mounted) setState(() => _isFollowingLocal = false); } 
                                        finally { if (mounted) setState(() => _followBusy = false); }
                                      },
                                      child: Container(
                                        width: 18, height: 18,
                                        decoration: BoxDecoration(shape: BoxShape.circle, color: _PostColors.primary, border: Border.all(color: Colors.white, width: 2)),
                                        child: const Icon(Icons.add_rounded, size: 12, color: Colors.white),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
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
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: _PostColors.navyText, letterSpacing: -0.2),
                                          maxLines: 1, overflow: TextOverflow.ellipsis
                                        ),
                                      ),
                                      if (isCertified)
                                        CertificationNameBadge(tier: tier, status: status, showLabel: false, iconSize: 15, padding: const EdgeInsets.only(left: 6))
                                      else if (isLegacyVerified)
                                        const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.verified_rounded, color: Color(0xFFE3B23C), size: 15)),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(_getTimeAgo(post.createdAt), style: const TextStyle(fontSize: 11, color: _PostColors.textMuted, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (post.isRepostCard)
                        const Padding(
                          padding: EdgeInsets.only(top: 8, bottom: 4),
                          child: Row(children: [Icon(Icons.repeat_rounded, size: 14, color: _PostColors.textMuted), SizedBox(width: 6), Text('a reposté', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _PostColors.textMuted))]),
                        ),

                      const SizedBox(height: 12),

                      // ─── 2. TEXTE DU POST ───
                      if (post.content.isNotEmpty)
                        _buildPostContent(post),

                      if (post.isRepostCard && post.repostOfId != null && post.repostOfId!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _OriginalPostEmbed(postId: post.repostOfId!),
                      ],

                      // ─── 3. AUTRES TYPES DE CONTENU ───
                      if (!post.isRepostCard && (post.hasImages || post.hasVideos)) ...[
                        const SizedBox(height: 12),
                        _buildMediaGrid([...post.imageUrls, ...post.videoUrls]),
                      ],
                      if (post.hasAudio && post.audioUrls.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _ThixWaveformAudioPlayer(audioUrl: post.audioUrls.first),
                      ],
                      if (post.postType == 'poll') ...[
                        const SizedBox(height: 12),
                        _buildPollWidget(post),
                      ] else if (post.postType == 'challenge') ...[
                        const SizedBox(height: 12),
                        _buildChallengeWidget(post),
                      ],

                      _buildFactCheckBanner(post.isMisinformation, post.factCheckMessage),

                      const SizedBox(height: 16),
                      
                      // ─── 4. AFFICHAGE DES IMPULSIONS (LES LIKERS) ───
                      if (likesCount > 0)
                        _buildLikersStack(likesCount, isLiked, post.id),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1, color: _PostColors.border, thickness: 0.5),
                      ),

                      // ─── 5. BARRE D'ACTIONS COMPLÈTE EN BAS (Scrollable) ───
                      _buildActionRow(post, isLiked, likesCount, isOwner, isCurrentUserFree, ref),
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

  // ── AFFICHAGE DES LIKERS (Impulsions) ──
  Widget _buildLikersStack(int likesCount, bool isLiked, String postId) {
    final displayCount = min(5, likesCount);
    final extra = likesCount - displayCount;
    final colors = [
      const Color(0xFF2D6CDF), const Color(0xFFFF6B6B), const Color(0xFFE3B23C), 
      const Color(0xFF0FA3A3), const Color(0xFF7C3AED)
    ];

    String text;
    if (isLiked) {
      if (likesCount == 1) text = "Vous avez envoyé une impulsion";
      else text = "Vous et ${likesCount - 1} autre${likesCount - 1 > 1 ? 's' : ''}";
    } else {
      text = "$likesCount personne${likesCount > 1 ? 's' : ''}";
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Row(
            children: List.generate(displayCount, (i) => Align(
              widthFactor: 0.7,
              child: Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, 
                  color: colors[(postId.hashCode + i) % colors.length], 
                  border: Border.all(color: Colors.white, width: 1.5)
                ),
                child: const Icon(Icons.person, size: 12, color: Colors.white),
              ),
            )),
          ),
          if (extra > 0)
            Padding(
              padding: const EdgeInsets.only(left: 6), 
              child: Text('+$extra', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _PostColors.textMuted))
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _PostColors.textMuted), overflow: TextOverflow.ellipsis)
          ),
        ],
      ),
    );
  }

  // ── BARRE D'ACTIONS COMPLÈTE EN BAS ──
  Widget _buildActionRow(NetworkPost post, bool isLiked, int likesCount, bool isOwner, bool isFree, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(

        children: [
          _ActionBtn(
            icon: isLiked ? Icons.bolt_rounded : Icons.bolt_outlined,
            label: _formatCountHelper(likesCount),
            color: isLiked ? _PulseColors.gold : _PostColors.textMuted,
            onTap: () async {
              HapticFeedback.selectionClick();
              await ref.read(postItemProvider.notifier).toggleLike();
            },
          ),
          const SizedBox(width: 12),
          _ActionBtn(
            icon: Icons.chat_bubble_outline_rounded,
            label: _formatCountHelper(post.commentsCount),
            color: _PostColors.textMuted,
            onTap: widget.onComment ?? () => _openPostDetails(post.id),
          ),
          const SizedBox(width: 12),
          _ActionBtn(
            icon: Icons.repeat_rounded,
            label: _formatCountHelper(post.repostsCount),
            color: post.isReposted ? ThixPolicy.success : _PostColors.textMuted,
            onTap: () => _repost(post, ref),
          ),
          const SizedBox(width: 12),
          _ActionBtn(
            icon: Icons.send_outlined,
            label: '',
            color: _PostColors.textMuted,
            onTap: widget.onShare,
          ),
          const SizedBox(width: 12),
          _ActionBtn(
            icon: post.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            label: '',
            color: post.isSaved ? _PostColors.navyText : _PostColors.textMuted,
            onTap: () {
              ref.read(postItemProvider.notifier).toggleSave();
              widget.onSave?.call();
            },
          ),
          // Actions de Propriétaire (Remplacent les 3 points)
          if (isOwner && !isFree) ...[
            const SizedBox(width: 12),
            _ActionBtn(
              icon: Icons.edit_outlined,
              label: '',
              color: _PostColors.navyText,
              onTap: () => _editPost(post, ref),
            ),
          ],
          if (isOwner) ...[
            const SizedBox(width: 12),
            _ActionBtn(
              icon: Icons.delete_outline_rounded,
              label: '',
              color: _PostColors.coral,
              onTap: () => _deletePost(post, ref),
            ),
          ],
          if (!isOwner) ...[
            const SizedBox(width: 12),
            _ActionBtn(
              icon: Icons.visibility_off_outlined,
              label: '',
              color: _PostColors.textMuted,
              onTap: () async {
                await ref.read(networkServiceProvider).hidePost(post.id);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Publication masquée')));
              },
            ),
          ]
        ],
      ),
    );
  }

  Future<void> _repost(NetworkPost post, WidgetRef ref) async {
    if (_isReposting) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reposter'),
        content: TextField(
          controller: _quoteController, maxLines: 3,
          decoration: InputDecoration(hintText: 'Commentaire optionnel', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler', style: TextStyle(color: _PostColors.textMuted))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: _PostColors.primary, foregroundColor: Colors.white), child: const Text('Reposter')),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reposté sur votre fil'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: _PostColors.coral));
    } finally {
      if (mounted) setState(() => _isReposting = false);
      _quoteController.clear();
    }
  }
}

// ─────────────────────────────────────────────────────────────
// WIDGET BOUTON D'ACTION
// ─────────────────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionBtn({required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: color)),
            ]
          ],
        ),
      ),
    );
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
            decoration: BoxDecoration(color: _PostColors.softBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: _PostColors.border)),
            child: const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: _PostColors.primary)),
          );
        }
        final original = snap.data;
        if (original == null) return const SizedBox.shrink();

        final originalMedia = [...original.imageUrls, ...original.videoUrls];

        return Container(
          decoration: BoxDecoration(color: _PostColors.softBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: _PostColors.border)),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.push('/network/comments/${original.id}'),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12, backgroundColor: _PostColors.border,
                          backgroundImage: original.authorAvatar != null && original.authorAvatar!.isNotEmpty ? CachedNetworkImageProvider(original.authorAvatar!) : null,
                          child: original.authorAvatar == null || original.authorAvatar!.isEmpty ? const Icon(Icons.person, size: 14, color: _PostColors.textMuted) : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(original.authorName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _PostColors.navyText), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    if (original.content.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(original.content, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, height: 1.35, color: _PostColors.navyText)),
                    ],
                    if (originalMedia.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _isVideoUrl(originalMedia.first)
                            ? _VideoThumbTile(videoUrl: originalMedia.first, height: 120, onTap: () {})
                            : CachedNetworkImage(imageUrl: originalMedia.first, height: 120, width: double.infinity, fit: BoxFit.cover),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// GALERIE & VIDEO & AUDIO PLAYERS
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
                child: CachedNetworkImage(imageUrl: widget.imageUrls[index], fit: BoxFit.contain),
              ),
            ),
          ),
          Positioned(top: 12, right: 12, child: SafeArea(child: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close, color: Colors.white)))),
        ],
      ),
    );
  }
}

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
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))..initialize().then((_) { if (mounted) setState(() => _ready = true); });
  }

  @override
  void dispose() { _controller?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: widget.width, height: widget.height, color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_ready && _controller != null) FittedBox(fit: BoxFit.cover, child: SizedBox(width: _controller!.value.size.width, height: _controller!.value.size.height, child: VideoPlayer(_controller!)))
            else const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54))),
            Container(color: Colors.black.withValues(alpha: 0.2)),
            const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 46)),
          ],
        ),
      ),
    );
  }
}

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
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))..initialize().then((_) { if (mounted) { setState(() => _ready = true); _controller.play(); } });
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(child: _ready ? AspectRatio(aspectRatio: _controller.value.aspectRatio, child: VideoPlayer(_controller)) : const CircularProgressIndicator(color: _PostColors.primary)),
          if (_ready)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _controller.value.isPlaying ? _controller.pause() : _controller.play()),
                child: AnimatedOpacity(opacity: _controller.value.isPlaying ? 0 : 1, duration: const Duration(milliseconds: 200), child: const Center(child: Icon(Icons.play_arrow_rounded, color: Colors.white70, size: 72))),
              ),
            ),
          Positioned(top: 12, right: 12, child: SafeArea(child: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close, color: Colors.white)))),
        ],
      ),
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0 ? _position.inMilliseconds / _duration.inMilliseconds : 0.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: _PostColors.softBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: _PostColors.border)),
      child: Row(
        children: [
          GestureDetector(
            onTap: () { if (_isPlaying) _audioPlayer.pause(); else _audioPlayer.play(UrlSource(widget.audioUrl)); },
            child: Container(width: 44, height: 44, decoration: const BoxDecoration(color: _PostColors.primary, shape: BoxShape.circle), child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 24)),
          ),
          const SizedBox(width: 16),
          Expanded(child: LinearProgressIndicator(value: progress, color: _PostColors.primary, backgroundColor: _PostColors.border)),
        ],
      ),
    );
  }
}
