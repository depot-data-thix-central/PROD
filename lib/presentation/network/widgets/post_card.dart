// lib/presentation/network/widgets/post_card.dart
import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/features/network/presentation/providers/feed_provider.dart';
import 'package:thix_id/models/network_post.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/models/certification_tier.dart';
import 'package:thix_id/presentation/certification/widgets/certification_name_badge.dart';
import 'package:thix_id/features/network/presentation/providers/user_profile_providers.dart';

// ============================================================================
// HELPERS
// ============================================================================
String _formatCountHelper(int count) {
  if (count == 0) return '';
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
  return '$count';
}

bool _isVideoUrl(String url) {
  final lower = url.toLowerCase();
  return lower.contains('.mp4') || lower.contains('.mov') ||
      lower.contains('.m4v') || lower.contains('.webm') ||
      lower.contains('.avi') || lower.contains('.mkv') ||
      lower.contains('/videos/') || lower.contains('/video/');
}

// ============================================================================
// VALIDATEURS
// ============================================================================
class _PostCardValidators {
  _PostCardValidators._();

  static String sanitize(String? input, {int maxLength = 5000}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var sanitized = (doc.body?.text ?? input)
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return sanitized.length > maxLength ? sanitized.substring(0, maxLength) : sanitized;
  }

  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty &&
          !uri.host.contains('..');
    } catch (_) {
      return false;
    }
  }
}

// ============================================================================
// CACHE LRU POUR LIKERS & LINK PREVIEWS
// ============================================================================
class _PostCardCache {
  _PostCardCache._();
  static final _PostCardCache _instance = _PostCardCache._();
  factory _PostCardCache() => _instance;

  static const int _maxSize = 50;
  static const Duration _ttl = Duration(minutes: 5);

  final LinkedHashMap<String, _CacheEntry<List<String>>> _likersCache = LinkedHashMap();
  final LinkedHashMap<String, _CacheEntry<Map<String, dynamic>>> _linkPreviewCache = LinkedHashMap();

  List<String>? getLikers(String postId) {
    final entry = _likersCache[postId];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.timestamp) > _ttl) {
      _likersCache.remove(postId);
      return null;
    }
    _likersCache.remove(postId);
    _likersCache[postId] = entry;
    return entry.value;
  }

  void setLikers(String postId, List<String> avatars) {
    if (_likersCache.length >= _maxSize) _likersCache.remove(_likersCache.keys.first);
    _likersCache[postId] = _CacheEntry(avatars);
  }

  Map<String, dynamic>? getLinkPreview(String url) {
    final entry = _linkPreviewCache[url];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.timestamp) > _ttl) {
      _linkPreviewCache.remove(url);
      return null;
    }
    _linkPreviewCache.remove(url);
    _linkPreviewCache[url] = entry;
    return entry.value;
  }

  void setLinkPreview(String url, Map<String, dynamic> data) {
    if (_linkPreviewCache.length >= _maxSize) _linkPreviewCache.remove(_linkPreviewCache.keys.first);
    _linkPreviewCache[url] = _CacheEntry(data);
  }
}

class _CacheEntry<T> {
  final T value;
  final DateTime timestamp;
  _CacheEntry(this.value) : timestamp = DateTime.now();
}

// ============================================================================
// STATE NOTIFIER
// ============================================================================
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
        final r = await s.togglePostLike(state.id).timeout(const Duration(seconds: 10));
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

  void updateContent(String c) => state = state.copyWith(content: _PostCardValidators.sanitize(c));

  void incRepost() => state = state.copyWith(repostsCount: state.repostsCount + 1, isReposted: true);
}

// ============================================================================
// COMPOSANT PRINCIPAL — POST CARD
// ============================================================================
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

  bool _impressionRegistered = false;
  Timer? _impressionDebounce;

  static const _maxContentChars = 250;
  static const _maxParseDepth = 6;

  static final _richContentRegex = RegExp(
    r'\{c:(#[0-9A-Fa-f]{6,8})\}([\s\S]*?)\{c\}|'
    r'\*\*([\s\S]+?)\*\*|'
    r'\*([\s\S]+?)\*|'
    r'@(\w+)|'
    r'#(\w+)|'
    r'(https?:\/\/[^\s]+)',
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
    if (oldWidget.post.content != widget.post.content) {
      _cacheParsedContent();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    _quoteController.dispose();
    _impressionDebounce?.cancel();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  void _cacheParsedContent() {
    final content = _PostCardValidators.sanitize(widget.post.content);
    final baseStyle = ThixPolicy.bodyStyle.copyWith(
      color: ThixPolicy.textMain,
      fontSize: 14.5,
      height: 1.5,
    );

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
        final r = TapGestureRecognizer()
          ..onTap = () {
            if (mounted) context.push('/network/profile/$value');
          };
        _recognizers.add(r);
        spans.add(TextSpan(
          text: '@$value',
          style: baseStyle.copyWith(color: ThixPolicy.primary, fontWeight: ThixPolicy.bold),
          recognizer: r,
        ));
      } else if (match.group(6) != null) {
        final value = match.group(6)!;
        final r = TapGestureRecognizer()
          ..onTap = () {
            if (mounted) context.push('/hashtag/$value');
          };
        _recognizers.add(r);
        spans.add(TextSpan(
          text: '#$value',
          style: baseStyle.copyWith(color: ThixPolicy.primary, fontWeight: ThixPolicy.bold),
          recognizer: r,
        ));
      } else if (match.group(7) != null) {
        final url = match.group(7)!;
        if (_PostCardValidators.isValidUrl(url)) {
          final r = TapGestureRecognizer()
            ..onTap = () async {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
            };
          _recognizers.add(r);
          spans.add(TextSpan(
            text: url,
            style: baseStyle.copyWith(color: ThixPolicy.primary, decoration: TextDecoration.underline),
            recognizer: r,
          ));
        }
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

  String? _extractFirstUrl(String content) {
    final match = RegExp(r'(https?:\/\/[^\s]+)').firstMatch(content);
    final url = match?.group(0);
    if (url != null && _PostCardValidators.isValidUrl(url)) return url;
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [bgColor.withOpacity(0.9), bgColor.withOpacity(0.7)],
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          post.content,
          textAlign: TextAlign.center,
          style: ThixPolicy.h2Style.copyWith(
            color: Colors.white,
            fontSize: 22,
            height: 1.3,
            shadows: [Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
          ),
        ),
      );
    }

    final firstUrl = _extractFirstUrl(post.content);

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
                style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.primary, fontSize: 13, fontWeight: ThixPolicy.bold),
              ),
            ),
          ),
        if (firstUrl != null)
          Padding(
            padding: const EdgeInsets.only(top: ThixPolicy.s12),
            child: _PremiumLinkPreview(url: firstUrl),
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

  Widget _buildMediaGrid(List<String> urls) {
    if (urls.isEmpty) return const SizedBox.shrink();
    const spacing = 4.0;
    final radius = BorderRadius.circular(16);
    final imageOnlyUrls = urls.where((u) => !_isVideoUrl(u)).toList();

    Widget mediaTile(String url, {double? width, double? height, Alignment alignment = Alignment.center}) {
      if (_isVideoUrl(url)) {
        return _VideoThumbTile(videoUrl: url, width: width, height: height, onTap: () => _openVideoFullScreen(url));
      }
      return GestureDetector(
        onTap: () => _openGallery(imageOnlyUrls.indexOf(url), imageOnlyUrls),
        child: CachedNetworkImage(
          imageUrl: url,
          width: width,
          height: height,
          fit: BoxFit.cover,
          alignment: alignment,
          memCacheWidth: 600,
          placeholder: (context, url) => Container(
            color: Colors.white.withOpacity(0.5),
            child: const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary))),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.white.withOpacity(0.5),
            child: const Icon(Icons.broken_image_outlined, color: ThixPolicy.textMuted),
          ),
        ),
      );
    }

    if (urls.length == 1) {
      return ClipRRect(
        borderRadius: radius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 500, minHeight: 200),
          child: SizedBox(width: double.infinity, child: mediaTile(urls[0], alignment: Alignment.topCenter)),
        ),
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
                          Container(
                            color: Colors.black54,
                            alignment: Alignment.center,
                            child: Text('+${urls.length - 3}', style: ThixPolicy.h2Style.copyWith(color: Colors.white, fontSize: 22, fontWeight: ThixPolicy.bold)),
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
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.poll_rounded, size: 18, color: ThixPolicy.primary),
              const SizedBox(width: ThixPolicy.s8),
              Text('Sondage', style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 13, color: ThixPolicy.textMain)),
            ],
          ),
          const SizedBox(height: ThixPolicy.s12),
          ...options.asMap().entries.map((entry) {
            final index = entry.key;
            final opt = entry.value;
            final text = _PostCardValidators.sanitize('${opt['text'] ?? ''}');
            final voters = (opt['votes'] as List?) ?? [];
            final pct = totalVotes > 0 ? voters.length / totalVotes : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    try {
                      await ref.read(networkServiceProvider).votePoll(post.id, index);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur vote: $e'), backgroundColor: ThixPolicy.danger));
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(ThixPolicy.s12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: pct.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [ThixPolicy.primary.withOpacity(0.2), ThixPolicy.primary.withOpacity(0.1)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                text,
                                style: ThixPolicy.bodyStyle.copyWith(fontSize: 13.5, fontWeight: ThixPolicy.semiBold, color: ThixPolicy.textMain),
                              ),
                            ),
                            Text(
                              '${(pct * 100).toStringAsFixed(0)}%',
                              style: ThixPolicy.labelStyle.copyWith(fontSize: 12, fontWeight: ThixPolicy.bold, color: ThixPolicy.primary),
                            ),
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

  Widget _buildChallengeWidget(NetworkPost post) {
    final data = post.challengeData ?? {};
    final description = _PostCardValidators.sanitize('${data['description'] ?? ''}');
    final participantsCount = data['participants_count'] ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ThixPolicy.s16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ThixPolicy.gold.withOpacity(0.1), ThixPolicy.primary.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ThixPolicy.gold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(ThixPolicy.s8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [ThixPolicy.gold, Color(0xFFFFA500)]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: ThixPolicy.s10),
              Expanded(child: Text('Challenge THIX', style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 14, color: ThixPolicy.textMain))),
              Text('$participantsCount participants', style: ThixPolicy.captionStyle.copyWith(fontSize: 11, fontWeight: ThixPolicy.semiBold, color: ThixPolicy.textMuted)),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: ThixPolicy.s12),
            Text(description, style: ThixPolicy.bodyStyle.copyWith(fontSize: 13.5, height: 1.4, color: ThixPolicy.textMain)),
          ],
          const SizedBox(height: ThixPolicy.s14),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Participation enregistrée'), backgroundColor: ThixPolicy.success)),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: ThixPolicy.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: Text('RELEVER LE DÉFI', style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 12, letterSpacing: 0.3)),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ SIGNALLEMENT COMMUNAUTAIRE (remplace fact-check)
  Future<void> _showReportDialog(NetworkPost post) async {
    const reasons = [
      'Désinformation',
      'Spam ou publicité abusive',
      'Contenu inapproprié',
      'Harcèlement ou discours haineux',
      'Nudité ou contenu sexuel',
      'Violence ou contenu choquant',
      'Usurpation d\'identité',
      'Autre',
    ];

    String? selectedReason;
    final detailsController = TextEditingController();
    bool isSubmitting = false;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: Colors.white.withOpacity(0.95),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.flag_outlined, color: ThixPolicy.danger, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Signaler cette publication',
                    style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.textMain, fontSize: 16, fontWeight: ThixPolicy.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pourquoi souhaitez-vous signaler cette publication ?',
                    style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Motif du signalement *',
                    style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.8)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedReason,
                        isExpanded: true,
                        hint: Text('Choisir un motif', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 13)),
                        items: reasons
                            .map((r) => DropdownMenuItem(value: r, child: Text(r, style: ThixPolicy.bodyStyle.copyWith(fontSize: 13))))
                            .toList(),
                        onChanged: isSubmitting ? null : (v) => setDialogState(() => selectedReason = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Détails supplémentaires (optionnel)',
                    style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: detailsController,
                    maxLines: 3,
                    maxLength: 500,
                    enabled: !isSubmitting,
                    decoration: InputDecoration(
                      hintText: 'Expliquez le problème en quelques mots...',
                      hintStyle: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 13),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: ThixPolicy.primary, width: 1.5),
                      ),
                      counterText: '',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx, false),
                child: Text('Annuler', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
              ),
              ElevatedButton(
                onPressed: (selectedReason == null || isSubmitting)
                    ? null
                    : () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.danger,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: ThixPolicy.danger.withOpacity(0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Signaler'),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || selectedReason == null) return;

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vous devez être connecté pour signaler'), backgroundColor: ThixPolicy.danger),
        );
      }
      return;
    }

    try {
      await Supabase.instance.client.from('post_reports').insert({
        'post_id': post.id,
        'reporter_id': uid,
        'reason': selectedReason,
        'details': _PostCardValidators.sanitize(detailsController.text.trim(), maxLength: 500),
        'status': 'pending',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Signalement envoyé. Notre équipe l\'examinera.',
                    style: ThixPolicy.labelStyle.copyWith(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: ThixPolicy.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      debugPrint('[Report] Error: $e');
      final errorMsg = e.toString().contains('duplicate key') ||
              e.toString().contains('unique constraint')
          ? 'Vous avez déjà signalé cette publication.'
          : 'Erreur lors du signalement. Réessayez.';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: ThixPolicy.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _editPost(NetworkPost post, WidgetRef ref) async {
    final controller = TextEditingController(text: post.content);
    final newContent = await showDialog<String>(
      context: context,
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withOpacity(0.8))),
          title: Row(children: [const Icon(Icons.edit_rounded, color: ThixPolicy.textMain), const SizedBox(width: 8), Text('Modifier', style: ThixPolicy.titleStyle.copyWith(fontSize: 16))]),
          content: TextField(
            controller: controller,
            maxLines: 6,
            autofocus: true,
            maxLength: 5000,
            decoration: InputDecoration(
              hintText: 'Modifier votre texte...',
              filled: true,
              fillColor: Colors.white.withOpacity(0.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: ThixPolicy.primary, width: 1.5)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('Annuler', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textMuted))),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) Navigator.pop(dialogContext, text);
              },
              style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.textMain, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (newContent != null && newContent.isNotEmpty && mounted) {
      try {
        if (widget.onEdit != null) {
          widget.onEdit!();
        } else {
          await ref.read(networkServiceProvider).updatePost(post.id, newContent);
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Publication modifiée')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur'), backgroundColor: ThixPolicy.danger));
      }
    }
  }

  Future<void> _deletePost(NetworkPost post, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withOpacity(0.8))),
          title: Row(children: [const Icon(Icons.warning_amber_rounded, color: ThixPolicy.danger), const SizedBox(width: 8), Text('Supprimer', style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.danger))]),
          content: Text('Êtes-vous sûr de vouloir supprimer définitivement cette publication ?', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMain)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textMuted))),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Supprimer')),
          ],
        ),
      ),
    );
    if (ok == true && mounted) {
      try {
        if (widget.onDelete != null) {
          widget.onDelete!();
        } else {
          await ref.read(networkServiceProvider).deletePost(post.id);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur'), backgroundColor: ThixPolicy.danger));
      }
    }
  }

  void _registerImpression(String postId) {
    if (_impressionRegistered) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    _impressionDebounce?.cancel();
    _impressionDebounce = Timer(const Duration(milliseconds: 500), () {
      if (_impressionRegistered) return;
      _impressionRegistered = true;
      Supabase.instance.client.rpc('increment_post_impression', params: {'p_post_id': postId, 'p_user_id': uid}).catchError((_) {
        _impressionRegistered = false;
      });
    });
  }

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

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _registerImpression(post.id);
          });

          return Container(
            margin: EdgeInsets.zero,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: ThixPolicy.gold, width: 1.5)),
            ),
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.65)),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onTap ?? () => _openPostDetails(post.id),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => context.push('/network/profile/${post.userId}'),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                                        ),
                                        child: CircleAvatar(
                                          radius: 20,
                                          backgroundColor: Colors.white.withOpacity(0.5),
                                          backgroundImage: post.authorAvatar != null && post.authorAvatar!.isNotEmpty ? CachedNetworkImageProvider(post.authorAvatar!) : null,
                                          child: post.authorAvatar == null || post.authorAvatar!.isEmpty ? const Icon(Icons.person_rounded, size: 18, color: ThixPolicy.textMuted) : null,
                                        ),
                                      ),
                                      if (!isOwner && !isFollowing)
                                        Positioned(
                                          bottom: -2,
                                          right: -2,
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
                                              width: 18,
                                              height: 18,
                                              decoration: BoxDecoration(shape: BoxShape.circle, color: ThixPolicy.primary, border: Border.all(color: Colors.white, width: 2)),
                                              child: const Icon(Icons.add_rounded, size: 12, color: Colors.white),
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
                                                _PostCardValidators.sanitize(post.authorName),
                                                style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 14.5, color: ThixPolicy.textMain, letterSpacing: -0.2),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isCertified)
                                              CertificationNameBadge(tier: tier, status: status, showLabel: false, iconSize: 15, padding: const EdgeInsets.only(left: 6))
                                            else if (isLegacyVerified)
                                              const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.verified_rounded, color: ThixPolicy.gold, size: 15)),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(_getTimeAgo(post.createdAt), style: ThixPolicy.captionStyle.copyWith(fontSize: 11, color: ThixPolicy.textSecondary, fontWeight: ThixPolicy.semiBold)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            if (post.isRepostCard)
                              Padding(
                                padding: const EdgeInsets.only(top: ThixPolicy.s8, bottom: 4),
                                child: Row(children: [const Icon(Icons.repeat_rounded, size: 14, color: ThixPolicy.textMuted), const SizedBox(width: 6), Text('a reposté', style: ThixPolicy.captionStyle.copyWith(fontSize: 11.5, fontWeight: ThixPolicy.semiBold, color: ThixPolicy.textMuted))]),
                              ),

                            const SizedBox(height: ThixPolicy.s12),

                            if (post.content.isNotEmpty) _buildPostContent(post),

                            if (post.isRepostCard && post.repostOfId != null && post.repostOfId!.isNotEmpty) ...[
                              const SizedBox(height: ThixPolicy.s12),
                              _OriginalPostEmbed(postId: post.repostOfId!),
                            ],

                            if (!post.isRepostCard && (post.hasImages || post.hasVideos)) ...[
                              const SizedBox(height: ThixPolicy.s12),
                              _buildMediaGrid([...post.imageUrls, ...post.videoUrls]),
                            ],
                            if (post.hasAudio && post.audioUrls.isNotEmpty) ...[
                              const SizedBox(height: ThixPolicy.s12),
                              _PremiumAudioPlayer(audioUrl: post.audioUrls.first, duration: post.audioDurationSeconds),
                            ],
                            if (post.postType == 'poll') ...[
                              const SizedBox(height: ThixPolicy.s12),
                              _buildPollWidget(post),
                            ] else if (post.postType == 'challenge') ...[
                              const SizedBox(height: ThixPolicy.s12),
                              _buildChallengeWidget(post),
                            ],

                            const SizedBox(height: ThixPolicy.s16),

                            if (likesCount > 0) _LikersStack(count: likesCount, postId: post.id, isLikedByMe: isLiked),

                            const SizedBox(height: 8),

                            _buildActionRow(post, isLiked, isOwner, isCurrentUserFree, ref),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionRow(NetworkPost post, bool isLiked, bool isOwner, bool isFree, WidgetRef ref) {
    final impressions = (post.toJson()['impressions_count'] as num?)?.toInt() ?? 0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _ActionBtn(
            icon: isLiked ? Icons.bolt_rounded : Icons.bolt_outlined,
            label: '',
            color: isLiked ? ThixPolicy.gold : ThixPolicy.textSecondary.withOpacity(0.8),
            onTap: () async {
              HapticFeedback.selectionClick();
              await ref.read(postItemProvider.notifier).toggleLike();
            },
          ),
          const SizedBox(width: 20),
          _ActionBtn(
            icon: Icons.chat_bubble_outline_rounded,
            label: _formatCountHelper(post.commentsCount),
            color: ThixPolicy.textSecondary.withOpacity(0.8),
            onTap: widget.onComment ?? () => _openPostDetails(post.id),
          ),
          const SizedBox(width: 20),
          _ActionBtn(
            icon: Icons.repeat_rounded,
            label: _formatCountHelper(post.repostsCount),
            color: post.isReposted ? ThixPolicy.success : ThixPolicy.textSecondary.withOpacity(0.8),
            onTap: () => _repost(post, ref),
          ),
          const SizedBox(width: 20),
          _ActionBtn(
            icon: Icons.bar_chart_rounded,
            label: _formatCountHelper(impressions),
            color: ThixPolicy.textSecondary.withOpacity(0.8),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$impressions personne${impressions > 1 ? 's' : ''} touchée${impressions > 1 ? 's' : ''}'), behavior: SnackBarBehavior.floating));
            },
          ),
          const SizedBox(width: 20),
          _ActionBtn(
            icon: Icons.send_outlined,
            label: '',
            color: ThixPolicy.textSecondary.withOpacity(0.8),
            onTap: widget.onShare,
          ),
          const SizedBox(width: 20),
          _ActionBtn(
            icon: post.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            label: '',
            color: post.isSaved ? ThixPolicy.textMain : ThixPolicy.textSecondary.withOpacity(0.8),
            onTap: () {
              ref.read(postItemProvider.notifier).toggleSave();
              widget.onSave?.call();
            },
          ),
          if (isOwner && !isFree) ...[
            const SizedBox(width: 20),
            _ActionBtn(icon: Icons.edit_outlined, label: '', color: ThixPolicy.textMain, onTap: () => _editPost(post, ref)),
          ],
          if (isOwner) ...[
            const SizedBox(width: 20),
            _ActionBtn(icon: Icons.delete_outline_rounded, label: '', color: ThixPolicy.danger, onTap: () => _deletePost(post, ref)),
          ],
          if (!isOwner) ...[
            const SizedBox(width: 20),
            _ActionBtn(
              icon: Icons.visibility_off_outlined,
              label: '',
              color: ThixPolicy.textSecondary.withOpacity(0.8),
              onTap: () async {
                await ref.read(networkServiceProvider).hidePost(post.id);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Publication masquée')));
              },
            ),
            const SizedBox(width: 20),
            _ActionBtn(
              icon: Icons.flag_outlined,
              label: '',
              color: ThixPolicy.danger.withOpacity(0.8),
              onTap: () => _showReportDialog(post),
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
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withOpacity(0.8))),
          title: Text('Reposter', style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.textMain)),
          content: TextField(
            controller: _quoteController,
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Commentaire optionnel',
              filled: true,
              fillColor: Colors.white.withOpacity(0.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary))),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Reposter')),
          ],
        ),
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

// ============================================================================
// WIDGETS AUXILIAIRES
// ============================================================================

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
            Icon(icon, size: 22, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(label, style: ThixPolicy.labelStyle.copyWith(fontSize: 12.5, fontWeight: ThixPolicy.semiBold, color: color)),
            ]
          ],
        ),
      ),
    );
  }
}

/// ✅ Player audio premium avec waveform, seek et vitesse
class _PremiumAudioPlayer extends StatefulWidget {
  final String audioUrl;
  final int? duration;

  const _PremiumAudioPlayer({required this.audioUrl, this.duration});

  @override
  State<_PremiumAudioPlayer> createState() => _PremiumAudioPlayerState();
}

class _PremiumAudioPlayerState extends State<_PremiumAudioPlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _playbackSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    _audioPlayer.setSourceUrl(widget.audioUrl);
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _cycleSpeed() {
    setState(() {
      if (_playbackSpeed == 1.0) {
        _playbackSpeed = 1.5;
      } else if (_playbackSpeed == 1.5) {
        _playbackSpeed = 2.0;
      } else {
        _playbackSpeed = 1.0;
      }
      _audioPlayer.setPlaybackRate(_playbackSpeed);
    });
    HapticFeedback.selectionClick();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0 ? _position.inMilliseconds / _duration.inMilliseconds : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ThixPolicy.primary.withOpacity(0.15),
            ThixPolicy.gold.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ThixPolicy.primary.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [ThixPolicy.primary, Color(0xFF6366F1)]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text('Note vocale', style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain, fontSize: 12)),
              const Spacer(),
              if (_duration.inSeconds > 0)
                Text(_formatDuration(_duration), style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, fontWeight: ThixPolicy.bold)),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (_isPlaying) {
                    _audioPlayer.pause();
                  } else {
                    _audioPlayer.play(UrlSource(widget.audioUrl));
                  }
                  HapticFeedback.lightImpact();
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [ThixPolicy.primary, Color(0xFF6366F1)]),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: ThixPolicy.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 24),
                ),
              ),
              const SizedBox(width: 14),

              Expanded(
                child: GestureDetector(
                  onTapDown: (details) {
                    final box = context.findRenderObject() as RenderBox;
                    final localPos = box.globalToLocal(details.globalPosition);
                    final percentage = (localPos.dx - 72) / (box.size.width - 140);
                    if (percentage >= 0 && percentage <= 1 && _duration.inMilliseconds > 0) {
                      final newPosition = Duration(milliseconds: (_duration.inMilliseconds * percentage).round());
                      _audioPlayer.seek(newPosition);
                    }
                  },
                  child: CustomPaint(
                    size: const Size(double.infinity, 32),
                    painter: _WaveformPainter(progress: progress, color: ThixPolicy.primary),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              GestureDetector(
                onTap: _cycleSpeed,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ThixPolicy.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ThixPolicy.primary.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${_playbackSpeed}x',
                    style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.primary, fontWeight: ThixPolicy.bold, fontSize: 11),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          Row(
            children: [
              Text(_formatDuration(_position), style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 10)),
              const Spacer(),
              Text(
                '-${_formatDuration(_duration - _position)}',
                style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double progress;
  final Color color;

  _WaveformPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = 40;
    final barWidth = size.width / (barCount * 1.5);
    final spacing = barWidth * 0.5;

    for (int i = 0; i < barCount; i++) {
      final x = i * (barWidth + spacing);
      final heightPercentage = (sin(i * 0.5) * 0.3 + 0.5 + (i % 3) * 0.1).clamp(0.2, 0.9);
      final barHeight = size.height * heightPercentage;
      final y = (size.height - barHeight) / 2;

      final barProgress = i / barCount;
      final isActive = barProgress <= progress;

      final paint = Paint()
        ..color = isActive ? color : color.withOpacity(0.3)
        ..style = PaintingStyle.fill;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        Radius.circular(barWidth / 2),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// ✅ Aperçu de lien externe — affiche toujours une image :
/// la photo Open Graph du site si disponible, sinon le favicon du domaine en secours.
class _PremiumLinkPreview extends StatefulWidget {
  final String url;
  const _PremiumLinkPreview({required this.url});

  @override
  State<_PremiumLinkPreview> createState() => _PremiumLinkPreviewState();
}

class _PremiumLinkPreviewState extends State<_PremiumLinkPreview> {
  Map<String, dynamic>? _previewData;
  bool _isLoading = true;
  bool _networkFailed = false;

  String get _domain => Uri.tryParse(widget.url)?.host.replaceFirst('www.', '') ?? 'Lien externe';

  /// Favicon haute résolution du domaine, utilisé comme image de secours
  /// quand aucune image Open Graph n'a pu être récupérée.
  String get _faviconUrl {
    final host = Uri.tryParse(widget.url)?.host ?? '';
    return 'https://www.google.com/s2/favicons?domain=$host&sz=256';
  }

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    final cached = _PostCardCache().getLinkPreview(widget.url);
    if (cached != null) {
      if (mounted) {
        setState(() {
          _previewData = cached;
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'link-preview',
        body: {'url': widget.url},
      ).timeout(const Duration(seconds: 8));

      if (response.data != null && response.data is Map) {
        // ✅ On accepte toute réponse partielle (même sans titre/description) :
        // dès qu'on a un minimum d'info, on affiche la carte avec image (photo ou favicon).
        final data = Map<String, dynamic>.from(response.data as Map);
        _PostCardCache().setLinkPreview(widget.url, data);
        if (mounted) {
          setState(() {
            _previewData = data;
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Invalid response');
      }
    } catch (e) {
      debugPrint('[LinkPreview] Error: $e');
      // ✅ Même en cas d'échec réseau, on affiche une carte avec le favicon du domaine
      // plutôt qu'un simple bloc texte sans photo.
      if (mounted) {
        setState(() {
          _networkFailed = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildSkeleton();
    }

    final title = _PostCardValidators.sanitize(_previewData?['title']?.toString() ?? '');
    final description = _PostCardValidators.sanitize(_previewData?['description']?.toString() ?? '');
    final ogImage = _previewData?['image']?.toString();
    final hasOgImage = ogImage != null && ogImage.isNotEmpty;

    // ✅ Toujours une image : photo Open Graph si dispo, sinon favicon du domaine.
    final displayImage = hasOgImage ? ogImage : _faviconUrl;

    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(widget.url);
        if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.9)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Grande photo Open Graph si disponible (cover), sinon bandeau avec favicon centré.
            hasOgImage
                ? CachedNetworkImage(
                    imageUrl: displayImage,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      height: 160,
                      color: Colors.white.withOpacity(0.4),
                      child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary))),
                    ),
                    errorWidget: (_, __, ___) => _buildFaviconBanner(),
                  )
                : _buildFaviconBanner(),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.link_rounded, size: 12, color: ThixPolicy.primary),
                      const SizedBox(width: 4),
                      Text(_domain.toUpperCase(), style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.primary, fontWeight: ThixPolicy.bold, fontSize: 10, letterSpacing: 0.5)),
                    ],
                  ),
                  if (title.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.textMain, fontWeight: ThixPolicy.bold, fontSize: 14, height: 1.2)),
                  ] else if (_networkFailed || (_previewData == null)) ...[
                    const SizedBox(height: 6),
                    Text('Lien externe', style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.textMain, fontWeight: ThixPolicy.bold, fontSize: 14, height: 1.2)),
                  ],
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 12, height: 1.3)),
                  ] else ...[
                    const SizedBox(height: 6),
                    Text(widget.url, maxLines: 1, overflow: TextOverflow.ellipsis, style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 12, height: 1.3)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bandeau de secours avec favicon centré sur fond doux — utilisé quand
  /// aucune photo Open Graph n'est disponible ou n'a pu être chargée.
  Widget _buildFaviconBanner() {
    return Container(
      height: 100,
      width: double.infinity,
      color: ThixPolicy.primary.withOpacity(0.06),
      alignment: Alignment.center,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(12)),
          child: CachedNetworkImage(
            imageUrl: _faviconUrl,
            width: 40,
            height: 40,
            fit: BoxFit.contain,
            placeholder: (_, __) => const SizedBox(
              width: 40,
              height: 40,
              child: Icon(Icons.link_rounded, color: ThixPolicy.primary, size: 24),
            ),
            errorWidget: (_, __, ___) => const Icon(Icons.link_rounded, color: ThixPolicy.primary, size: 28),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.8)),
      ),
      child: const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary))),
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
  String? _thumbnailUrl;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  Future<void> _generateThumbnail() async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'video-thumbnail',
        body: {'video_url': widget.videoUrl},
      ).timeout(const Duration(seconds: 5));

      if (response.data != null && response.data['thumbnail_url'] != null) {
        if (mounted) {
          setState(() => _thumbnailUrl = response.data['thumbnail_url']);
        }
      }
    } catch (e) {
      debugPrint('[VideoThumb] Thumbnail error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: widget.width,
        height: widget.height,
        color: Colors.black87,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_thumbnailUrl != null)
              CachedNetworkImage(imageUrl: _thumbnailUrl!, fit: BoxFit.cover)
            else
              const Center(child: Icon(Icons.videocam_rounded, color: Colors.white24, size: 40)),
            Container(color: Colors.black.withOpacity(0.2)),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
              child: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 40),
            ),
          ],
        ),
      ),
    );
  }
}

class _LikersStack extends StatefulWidget {
  final int count;
  final String postId;
  final bool isLikedByMe;

  const _LikersStack({required this.count, required this.postId, required this.isLikedByMe});

  @override
  State<_LikersStack> createState() => _LikersStackState();
}

class _LikersStackState extends State<_LikersStack> {
  List<String> _likerAvatars = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLikersAvatars();
  }

  @override
  void didUpdateWidget(covariant _LikersStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count != oldWidget.count) {
      _fetchLikersAvatars();
    }
  }

  Future<void> _fetchLikersAvatars() async {
    if (widget.count == 0) {
      if (mounted) setState(() { _isLoading = false; _likerAvatars = []; });
      return;
    }

    final cached = _PostCardCache().getLikers(widget.postId);
    if (cached != null) {
      if (mounted) {
        setState(() {
          _likerAvatars = cached;
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('post_likes')
          .select('user_id, profiles(avatar_url)')
          .eq('post_id', widget.postId)
          .order('created_at', ascending: false)
          .limit(5);

      final List<String> avatars = [];
      if (response is List) {
        for (var row in response) {
          final profile = row['profiles'];
          if (profile != null && profile['avatar_url'] != null) {
            final url = profile['avatar_url'].toString().trim();
            if (url.isNotEmpty) avatars.add(url);
          } else {
            avatars.add('');
          }
        }
      }

      _PostCardCache().setLikers(widget.postId, avatars);

      if (mounted) {
        setState(() {
          _likerAvatars = avatars;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayCount = min(5, widget.count);
    final extra = widget.count - displayCount;

    final colors = [ThixPolicy.primary, ThixPolicy.danger, ThixPolicy.gold, ThixPolicy.info, ThixPolicy.domainMedia];

    String text;
    if (widget.isLikedByMe) {
      if (widget.count == 1) {
        text = "Vous avez envoyé une impulsion";
      } else {
        text = "Vous et ${widget.count - 1} autre${widget.count - 1 > 1 ? 's' : ''}";
      }
    } else {
      text = "${widget.count} personne${widget.count > 1 ? 's' : ''}";
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Row(
            children: List.generate(displayCount, (i) {
              final String avatarUrl = _likerAvatars.length > i ? _likerAvatars[i] : '';
              final bool hasRealAvatar = avatarUrl.isNotEmpty && !_isLoading;

              return Align(
                widthFactor: 0.7,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors[(widget.postId.hashCode + i) % colors.length],
                    border: Border.all(color: Colors.white, width: 1.5),
                    image: hasRealAvatar ? DecorationImage(image: CachedNetworkImageProvider(avatarUrl), fit: BoxFit.cover) : null,
                  ),
                  child: !hasRealAvatar ? const Icon(Icons.person, size: 12, color: Colors.white) : null,
                ),
              );
            }),
          ),
          if (extra > 0)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text('+$extra', style: ThixPolicy.captionStyle.copyWith(fontSize: 11, fontWeight: ThixPolicy.bold, color: ThixPolicy.textSecondary)),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: ThixPolicy.captionStyle.copyWith(fontSize: 11.5, fontWeight: ThixPolicy.semiBold, color: ThixPolicy.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// AUTRES WIDGETS
// ============================================================================

/// ✅ Repost original — désormais entièrement visible :
/// texte complet (plus de troncature à 3 lignes) et image affichée
/// intégralement (BoxFit.contain, sans recadrage), avec hauteur adaptative.
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
            height: 80,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.8))),
            child: const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary)),
          );
        }
        final original = snap.data;
        if (original == null) return const SizedBox.shrink();

        final originalMedia = [...original.imageUrls, ...original.videoUrls];

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.8))),
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
                          radius: 12,
                          backgroundColor: Colors.white.withOpacity(0.5),
                          backgroundImage: original.authorAvatar != null && original.authorAvatar!.isNotEmpty ? CachedNetworkImageProvider(original.authorAvatar!) : null,
                          child: original.authorAvatar == null || original.authorAvatar!.isEmpty ? const Icon(Icons.person, size: 14, color: ThixPolicy.textMuted) : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_PostCardValidators.sanitize(original.authorName), style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 12, color: ThixPolicy.textMain), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    if (original.content.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      // ✅ Texte complet, sans limite de lignes ni ellipsis.
                      Text(
                        _PostCardValidators.sanitize(original.content),
                        style: ThixPolicy.bodyStyle.copyWith(fontSize: 12.5, height: 1.4, color: ThixPolicy.textMain),
                      ),
                    ],
                    if (originalMedia.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      // ✅ Image/vidéo affichée en entier, sans recadrage forcé.
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _isVideoUrl(originalMedia.first)
                            ? SizedBox(
                                width: double.infinity,
                                height: 220,
                                child: _VideoThumbTile(videoUrl: originalMedia.first, height: 220, onTap: () {}),
                              )
                            : ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 400, minHeight: 120),
                                child: Container(
                                  width: double.infinity,
                                  color: Colors.black.withOpacity(0.03),
                                  child: CachedNetworkImage(
                                    imageUrl: originalMedia.first,
                                    fit: BoxFit.contain,
                                    placeholder: (_, __) => const SizedBox(
                                      height: 200,
                                      child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary))),
                                    ),
                                    errorWidget: (_, __, ___) => const SizedBox(
                                      height: 120,
                                      child: Center(child: Icon(Icons.broken_image_outlined, color: ThixPolicy.textMuted)),
                                    ),
                                  ),
                                ),
                              ),
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

class _FullScreenGallery extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  const _FullScreenGallery({required this.imageUrls, required this.initialIndex});
  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
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
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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
                minScale: 1,
                maxScale: 4,
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
          Center(child: _ready ? AspectRatio(aspectRatio: _controller.value.aspectRatio, child: VideoPlayer(_controller)) : const CircularProgressIndicator(color: ThixPolicy.primary)),
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
