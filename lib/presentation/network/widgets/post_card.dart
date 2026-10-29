// lib/presentation/network/widgets/post_card.dart
//
// PostCard — v6
// ✅ compteurs commentaires / reposts / vues / J'aime toujours visibles
// ✅ médias à ratio fixe (cartes stables) + photos nettes
// ✅ aperçu de lien sans doublon (URL masquée du texte, pas de double image)
// ✅ appui long ⚡ = 5 réactions · @mention → profil · "Voir le profil" dans ⋯
// Les parties communes sont dans post_card_parts.dart
import 'dart:async';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/features/network/presentation/providers/feed_provider.dart';
import 'package:thix_id/features/network/presentation/providers/user_profile_providers.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/certification_tier.dart';
import 'package:thix_id/models/network_post.dart';
import 'package:thix_id/presentation/certification/widgets/certification_name_badge.dart';
import 'package:thix_id/presentation/network/widgets/post_card_parts.dart';
import 'package:thix_id/presentation/network/widgets/post_share_sheet.dart';

export 'package:thix_id/presentation/network/widgets/post_card_parts.dart' show postItemProvider, PostItemNotifier;

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
  final bool isFirst;
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
    this.isFirst = false,
  });

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isReposting = false;
  bool _isExpanded = false;
  bool _pollVoteBusy = false;
  final _quoteController = TextEditingController();
  bool _isFollowingLocal = false;
  bool _followBusy = false;
  DateTime? _lastFollowTap;
  DateTime? _lastVoteTap;
  DateTime? _lastReportSubmit;
  DateTime? _lastRepostSubmit;
  bool _impressionRegistered = false;
  Timer? _impressionDebounce;
  DateTime? _lastContentUpdate;

  final GlobalKey _likeKey = GlobalKey();

  List<InlineSpan>? _cachedFullSpans;
  List<InlineSpan>? _cachedTruncatedSpans;
  List<List<InlineSpan>>? _cachedParagraphSpans;
  bool _isMultiParagraph = false;
  bool _isTruncatable = false;
  String _displayContent = '';
  String? _previewUrl;
  final List<GestureRecognizer> _recognizers = [];
  bool _parsedOnce = false;
  Locale? _parsedLocale;

  static const Map<String, PcBadgeStyle> _badgeStyles = {
    'urgent': PcBadgeStyle(Color(0xFFE53935), Icons.priority_high_rounded, pulse: true),
    'alert': PcBadgeStyle(Color(0xFFD84315), Icons.warning_amber_rounded, pulse: true),
    'flash': PcBadgeStyle(Color(0xFFF57C00), Icons.bolt_rounded),
    'important': PcBadgeStyle(Color(0xFFF9A825), Icons.error_outline_rounded),
    'info': PcBadgeStyle(Color(0xFF1E88E5), Icons.info_outline_rounded),
    'new': PcBadgeStyle(Color(0xFF43A047), Icons.fiber_new_rounded),
    'official': PcBadgeStyle(ThixPolicy.gold, Icons.verified_rounded),
    'event': PcBadgeStyle(Color(0xFF8E24AA), Icons.celebration_rounded),
    'promo': PcBadgeStyle(Color(0xFF00897B), Icons.local_offer_rounded),
    'reminder': PcBadgeStyle(Color(0xFF3949AB), Icons.alarm_rounded),
  };

  bool get _isAuthenticated => Supabase.instance.client.auth.currentUser != null;

  @override
  void initState() {
    super.initState();
    _isFollowingLocal = widget.isFollowingAuthor;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    if (!_parsedOnce || _parsedLocale != locale) {
      _parsedOnce = true;
      _parsedLocale = locale;
      _cacheParsedContent();
    }
  }

  @override
  void didUpdateWidget(covariant PostCard old) {
    super.didUpdateWidget(old);
    if (old.isFollowingAuthor != widget.isFollowingAuthor) _isFollowingLocal = widget.isFollowingAuthor;
    if (old.post.content != widget.post.content) {
      final now = DateTime.now();
      if (_lastContentUpdate == null || now.difference(_lastContentUpdate!) > PcConfig.contentDebounce) {
        _lastContentUpdate = now;
        _cacheParsedContent();
      }
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
      try {
        r.dispose();
      } catch (_) {}
    }
    _recognizers.clear();
  }

  bool _throttle(DateTime? Function() get, void Function(DateTime) set, Duration window) {
    final now = DateTime.now();
    final last = get();
    if (last != null && now.difference(last) < window) return false;
    set(now);
    return true;
  }

  bool _throttleFollow() => _throttle(() => _lastFollowTap, (t) => _lastFollowTap = t, PcConfig.followThrottle);
  bool _throttleVote() => _throttle(() => _lastVoteTap, (t) => _lastVoteTap = t, PcConfig.voteThrottle);
  bool _throttleReport() => _throttle(() => _lastReportSubmit, (t) => _lastReportSubmit = t, PcConfig.reportThrottle);
  bool _throttleRepost() => _throttle(() => _lastRepostSubmit, (t) => _lastRepostSubmit = t, PcConfig.repostThrottle);

  // ── Texte ──
  String _truncate(String content) {
    var t = content;
    final lines = t.split('\n');
    if (lines.length > PcConfig.maxContentLines) t = lines.take(PcConfig.maxContentLines).join('\n');
    if (t.length > PcConfig.maxContentChars) {
      t = t.substring(0, PcConfig.maxContentChars);
      final lastSpace = t.lastIndexOf(RegExp(r'\s'));
      if (lastSpace > 0) t = t.substring(0, lastSpace);
    }
    return t.trimRight();
  }

  List<String> _splitParagraphs(String c) =>
      c.split(RegExp(r'\n{2,}')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();

  /// ✅ Retire la 1re URL du texte (elle est affichée dans l'aperçu)
  String _stripFirstUrl(String c) {
    final m = kUrlFinder.firstMatch(c);
    if (m == null) return c;
    var s = c.replaceRange(m.start, m.end, '');
    s = s.replaceAll(RegExp(r'[ \t]+\n'), '\n').replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return s.trim();
  }

  String? _extractFirstUrl(String content) {
    final match = kUrlFinder.firstMatch(content);
    var url = match?.group(0);
    if (url == null) return null;
    url = url.replaceAll(kUrlTrailingPunct, '');
    url = pcNormalizeUrl(url);
    return PcValidators.isValidUrl(url) ? url : null;
  }

  void _cacheParsedContent() {
    final raw = PcValidators.sanitize(widget.post.content);
    _previewUrl = _extractFirstUrl(raw);
    final content = _previewUrl != null ? _stripFirstUrl(raw) : raw;
    _displayContent = content;
    final l10n = AppLocalizations.of(context);
    final baseStyle = ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMain, fontSize: 14.5, height: 1.5);

    _disposeRecognizers();
    _cachedFullSpans = _parseContent(content, baseStyle, 0, l10n);
    final paras = _splitParagraphs(content);
    _isMultiParagraph = paras.length > 1;
    _cachedParagraphSpans = _isMultiParagraph ? paras.map((p) => _parseContent(p, baseStyle, 0, l10n)).toList() : null;

    final truncated = _truncate(content);
    _isTruncatable = truncated.length < content.length;
    _cachedTruncatedSpans = _isTruncatable ? _parseContent('$truncated…', baseStyle, 0, l10n) : _cachedFullSpans;
  }

  List<InlineSpan> _parseContent(String content, TextStyle baseStyle, int depth, AppLocalizations l10n) {
    if (depth > PcConfig.maxParseDepth || content.isEmpty) return [TextSpan(text: content, style: baseStyle)];
    final spans = <InlineSpan>[];
    var lastIndex = 0;
    for (final match in kRichContentRegex.allMatches(content)) {
      if (match.start > lastIndex) spans.add(TextSpan(text: content.substring(lastIndex, match.start), style: baseStyle));
      if (match.group(1) != null) {
        final hex = match.group(1)!.replaceFirst('#', '');
        final inner = match.group(2) ?? '';
        Color color;
        try {
          color = Color(int.parse(hex.length == 8 ? hex : 'FF$hex', radix: 16));
        } catch (_) {
          color = baseStyle.color ?? ThixPolicy.textMain;
        }
        spans.addAll(_parseContent(inner, baseStyle.copyWith(color: color), depth + 1, l10n));
      } else if (match.group(3) != null) {
        spans.addAll(_parseContent(match.group(3)!, baseStyle.copyWith(fontWeight: FontWeight.bold), depth + 1, l10n));
      } else if (match.group(4) != null) {
        spans.addAll(_parseContent(match.group(4)!, baseStyle.copyWith(fontStyle: FontStyle.italic), depth + 1, l10n));
      } else if (match.group(5) != null) {
        final username = match.group(5)!;
        final rec = TapGestureRecognizer()..onTap = () => _openMention(username);
        _recognizers.add(rec);
        spans.add(TextSpan(
          text: '@$username',
          style: baseStyle.copyWith(color: PcMono.accent, fontWeight: FontWeight.bold),
          recognizer: rec,
          semanticsLabel: l10n.t('post_mention', args: [username]),
        ));
      } else if (match.group(6) != null) {
        final tag = match.group(6)!;
        final rec = TapGestureRecognizer()
          ..onTap = () {
            if (!mounted) return;
            HapticFeedback.selectionClick();
            context.push('/hashtag/$tag');
          };
        _recognizers.add(rec);
        spans.add(TextSpan(
          text: '#$tag',
          style: baseStyle.copyWith(color: PcMono.accent, fontWeight: FontWeight.bold),
          recognizer: rec,
          semanticsLabel: l10n.t('post_hashtag', args: [tag]),
        ));
      } else if (match.group(7) != null) {
        var raw = match.group(7)!;
        var trailing = '';
        final punct = kUrlTrailingPunct.firstMatch(raw);
        if (punct != null) {
          trailing = punct.group(0)!;
          raw = raw.substring(0, punct.start);
        }
        final url = pcNormalizeUrl(raw);
        if (PcValidators.isValidRichTextUrl(url)) {
          final rec = TapGestureRecognizer()
            ..onTap = () async {
              if (!mounted) return;
              HapticFeedback.selectionClick();
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
            };
          _recognizers.add(rec);
          spans.add(TextSpan(
            text: raw,
            style: baseStyle.copyWith(color: PcMono.accent, decoration: TextDecoration.underline),
            recognizer: rec,
            semanticsLabel: l10n.t('post_link'),
          ));
        } else {
          spans.add(TextSpan(text: raw, style: baseStyle));
        }
        if (trailing.isNotEmpty) spans.add(TextSpan(text: trailing, style: baseStyle));
      }
      lastIndex = match.end;
    }
    if (lastIndex < content.length) spans.add(TextSpan(text: content.substring(lastIndex), style: baseStyle));
    return spans;
  }

  Color? _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return null;
    final hex = hexColor.replaceAll('#', '');
    if (hex.length != 6 && hex.length != 8) return null;
    try {
      return Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
    } catch (_) {
      return null;
    }
  }

  // ── Navigation ──
  void _openPostDetails(String postId) {
    if (!mounted || !PcValidators.isValidId(postId)) return;
    HapticFeedback.mediumImpact();
    context.push('/network/comments/$postId');
  }

  void _openProfile(String userId) {
    if (!mounted || !PcValidators.isValidId(userId)) return;
    HapticFeedback.selectionClick();
    context.push('/network/profile/$userId');
  }

  /// ✅ @mention → retrouve le profil par THIX Chat puis l'ouvre
  Future<void> _openMention(String username) async {
    if (!mounted) return;
    HapticFeedback.selectionClick();
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .ilike('thix_chat', '@$username')
          .limit(1)
          .maybeSingle()
          .timeout(PcConfig.networkTimeout);
      final id = res?['id']?.toString();
      if (!mounted) return;
      if (PcValidators.isValidId(id)) {
        context.push('/network/profile/$id');
      } else {
        pcToast(context, 'Profil @$username introuvable');
      }
    } catch (_) {
      if (mounted) pcToast(context, 'Impossible d’ouvrir @$username', bg: ThixPolicy.danger);
    }
  }

  void _openGallery(int initialIndex, List<String> urls) {
    if (!mounted || urls.isEmpty) return;
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PcFullScreenGallery(imageUrls: urls, initialIndex: initialIndex.clamp(0, urls.length - 1)),
    ));
  }

  void _openVideoFullScreen(String url) {
    if (!mounted || !PcValidators.isValidUrl(url)) return;
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PcFullScreenVideoPlayer(videoUrl: url)));
  }

  // ── Partage ──
  String _shareExcerpt(NetworkPost post) {
    final c = PcValidators.sanitizeLine(pcPlainText(post.content), maxLength: 140);
    return c.isEmpty ? 'Découvrez ce post sur THIX Hub' : c;
  }

  String? _shareImage(NetworkPost post) => post.imageUrls.isNotEmpty ? pcSafeImageUrl(post.imageUrls.first) : null;

  void _sharePost(NetworkPost post) {
    PostShareSheet.show(context, postId: post.id, postExcerpt: _shareExcerpt(post), imageUrl: _shareImage(post));
  }

  // ── Pin ──
  Future<void> _togglePin(NetworkPost post, WidgetRef ref, AppLocalizations l10n) async {
    if (!_isAuthenticated) return;
    HapticFeedback.selectionClick();
    final wasPinned = post.isPinned;
    try {
      final service = ref.read(networkServiceProvider);
      if (wasPinned) {
        await service.unpinPost(post.id).timeout(PcConfig.networkTimeout);
      } else {
        await service.pinPost(post.id).timeout(PcConfig.networkTimeout);
      }
      if (!mounted) return;
      pcToast(
        context,
        wasPinned ? pcTr(l10n, 'post_unpinned', 'Post désépinglé') : pcTr(l10n, 'post_pinned_ok', 'Post épinglé sur votre profil'),
        bg: ThixPolicy.success,
      );
      widget.onRefresh?.call();
    } catch (e) {
      PcLog.error('togglePin failed', {'postId': post.id});
      if (mounted) pcToast(context, 'Erreur : ${e.toString().split('\n').first}', bg: ThixPolicy.danger);
    }
  }

  // ── Contenu ──
  Widget _buildPostContent(NetworkPost post, AppLocalizations l10n) {
    if (post.content.isEmpty) return const SizedBox.shrink();
    final bgColor = _parseColor(post.bgColor);
    if (bgColor != null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [bgColor.withValues(alpha: 0.9), bgColor.withValues(alpha: 0.7)],
          ),
        ),
        alignment: Alignment.center,
        child: SelectableText(
          PcValidators.sanitize(post.content),
          textAlign: TextAlign.center,
          style: ThixPolicy.h2Style.copyWith(
            color: Colors.white,
            fontSize: 22,
            height: 1.3,
            shadows: [Shadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 2))],
          ),
        ),
      );
    }

    final hasMedia = post.hasImages || post.hasVideos;
    final preview = _previewUrl != null
        ? Padding(
            padding: EdgeInsets.only(top: _displayContent.isEmpty ? 0 : 12),
            child: PcLinkPreview(url: _previewUrl!, hasMedia: hasMedia),
          )
        : const SizedBox.shrink();

    if (_displayContent.isEmpty) return preview;

    if (_isMultiParagraph && _cachedParagraphSpans != null) {
      final list = _cachedParagraphSpans!;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (int i = 0; i < list.length; i++) ...[
          SelectableText.rich(TextSpan(children: list[i]), onTap: widget.onTap ?? () => _openPostDetails(post.id)),
          if (i < list.length - 1) const SizedBox(height: 12),
        ],
        preview,
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Semantics(
        label: pcPlainText(_displayContent),
        child: SelectableText.rich(
          TextSpan(children: _isExpanded ? (_cachedFullSpans ?? []) : (_cachedTruncatedSpans ?? [])),
          onTap: widget.onTap ?? () => _openPostDetails(post.id),
        ),
      ),
      if (_isTruncatable)
        Semantics(
          button: true,
          label: _isExpanded ? l10n.t('post_see_less') : l10n.t('post_see_more'),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _isExpanded = !_isExpanded);
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _isExpanded ? l10n.t('post_see_less') : l10n.t('post_see_more'),
                style: ThixPolicy.labelStyle.copyWith(color: PcMono.accent, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      preview,
    ]);
  }

  Widget _buildPostBadge(NetworkPost post, AppLocalizations l10n) {
    if (!post.hasBadge) return const SizedBox.shrink();
    final style = _badgeStyles[post.postBadge];
    if (style == null) return const SizedBox.shrink();
    final label = pcTr(l10n, 'cp_badge_${post.postBadge}', post.postBadge!.toUpperCase());
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: style.pulse ? PcPulsingBadge(style: style, label: label) : PcStaticBadgeChip(style: style, label: label),
      ),
    );
  }

  // ── ✅ Grille média à RATIO FIXE (aucun saut de hauteur) ──
  Widget _buildMediaGrid(List<String> rawUrls, AppLocalizations l10n) {
    final urls = rawUrls.where(PcValidators.isValidUrl).toList();
    if (urls.isEmpty) return const SizedBox.shrink();
    const spacing = 4.0;
    final radius = BorderRadius.circular(16);
    final imageOnly = urls.where((u) => !pcIsVideoUrl(u)).toList();
    final cacheW = pcCacheWidth(context, fraction: urls.length == 1 ? 1 : 0.7);

    Widget tile(String url) {
      if (pcIsVideoUrl(url)) return PcVideoThumbTile(videoUrl: url, onTap: () => _openVideoFullScreen(url));
      return Stack(fit: StackFit.expand, children: [
        GestureDetector(
          onTap: () => _openGallery(imageOnly.indexOf(url), imageOnly),
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            memCacheWidth: cacheW,
            filterQuality: FilterQuality.high,
            fadeInDuration: const Duration(milliseconds: 100),
            placeholder: (_, __) => Container(
              color: Colors.black.withValues(alpha: 0.05),
              child: const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: PcMono.accent))),
            ),
            errorWidget: (_, __, ___) => Container(
              color: Colors.black.withValues(alpha: 0.05),
              child: const Icon(Icons.broken_image_outlined, color: ThixPolicy.textMuted),
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: PcMediaChipButton(
            icon: Icons.download_rounded,
            semanticsLabel: pcTr(l10n, 'post_download_photo', 'Télécharger la photo'),
            onTap: () => pcDownloadMedia(context, url),
          ),
        ),
      ]);
    }

    Widget cell(int i) => Expanded(child: ClipRRect(borderRadius: radius, child: tile(urls[i])));

    if (urls.length == 1) {
      final ratio = pcIsVideoUrl(urls[0]) ? PcConfig.videoRatio : PcConfig.singleMediaRatio;
      return ClipRRect(borderRadius: radius, child: AspectRatio(aspectRatio: ratio, child: tile(urls[0])));
    }
    if (urls.length == 2) {
      return AspectRatio(
        aspectRatio: PcConfig.twoMediaRatio,
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [cell(0), const SizedBox(width: spacing), cell(1)]),
      );
    }
    return AspectRatio(
      aspectRatio: PcConfig.multiMediaRatio,
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(flex: 3, child: ClipRRect(borderRadius: radius, child: tile(urls[0]))),
        const SizedBox(width: spacing),
        Expanded(
          flex: 2,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: ClipRRect(borderRadius: radius, child: tile(urls[1]))),
            const SizedBox(height: spacing),
            Expanded(
              child: ClipRRect(
                borderRadius: radius,
                child: Stack(fit: StackFit.expand, children: [
                  tile(urls[2]),
                  if (urls.length > 3)
                    IgnorePointer(
                      child: Container(
                        color: Colors.black54,
                        alignment: Alignment.center,
                        child: Text('+${urls.length - 3}',
                            style: ThixPolicy.h2Style.copyWith(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Sondage ──
  Widget _buildPollWidget(NetworkPost post, AppLocalizations l10n) {
    if (!PcValidators.isValidPollData(post.pollData)) return const SizedBox.shrink();
    final options = (post.pollData!['options'] as List);
    var totalVotes = 0;
    for (final opt in options) {
      totalVotes += ((opt['votes'] as List?)?.length ?? 0);
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.poll_rounded, size: 18, color: PcMono.accent),
          const SizedBox(width: 8),
          Text(l10n.t('post_poll_title'),
              style: ThixPolicy.labelStyle.copyWith(fontWeight: FontWeight.bold, fontSize: 13, color: ThixPolicy.textMain)),
          const Spacer(),
          Text('$totalVotes ${pcTr(l10n, 'post_poll_votes', 'vote(s)')}',
              style: ThixPolicy.captionStyle.copyWith(fontSize: 11, color: ThixPolicy.textMuted, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 12),
        ...options.asMap().entries.map((entry) {
          final index = entry.key;
          final opt = entry.value;
          final text = PcValidators.sanitizeLine('${opt['text'] ?? ''}');
          final voters = (opt['votes'] as List?) ?? [];
          final pct = totalVotes > 0 ? voters.length / totalVotes : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _votePoll(post, index, l10n),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white),
                  ),
                  child: Stack(children: [
                    Positioned.fill(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: pct.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [PcMono.accent.withValues(alpha: 0.2), PcMono.accent.withValues(alpha: 0.1)]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    Row(children: [
                      Expanded(
                        child: Text(text,
                            style: ThixPolicy.bodyStyle.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600, color: ThixPolicy.textMain)),
                      ),
                      Text('${(pct * 100).toStringAsFixed(0)}%',
                          style: ThixPolicy.labelStyle.copyWith(fontSize: 12, fontWeight: FontWeight.bold, color: PcMono.accent)),
                    ]),
                  ]),
                ),
              ),
            ),
          );
        }),
      ]),
    );
  }

  Future<void> _votePoll(NetworkPost post, int index, AppLocalizations l10n) async {
    if (_pollVoteBusy || !_throttleVote() || !_isAuthenticated) return;
    if (!PcValidators.isValidPollData(post.pollData)) return;
    final options = post.pollData!['options'] as List;
    if (index < 0 || index >= options.length) return;
    setState(() => _pollVoteBusy = true);
    HapticFeedback.selectionClick();
    try {
      await ref.read(networkServiceProvider).votePoll(post.id, index).timeout(PcConfig.networkTimeout);
    } catch (_) {
      PcLog.error('votePoll failed', {'postId': post.id});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('post_vote_error')), backgroundColor: ThixPolicy.danger));
      }
    } finally {
      if (mounted) setState(() => _pollVoteBusy = false);
    }
  }

  // ── Challenge ──
  Widget _buildChallengeWidget(NetworkPost post, AppLocalizations l10n) {
    final data = post.challengeData ?? <String, dynamic>{};
    final description = PcValidators.sanitize('${data['description'] ?? ''}');
    final participants = (data['participants_count'] is num) ? data['participants_count'] as num : 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [PcMono.accent.withValues(alpha: 0.1), PcMono.accent.withValues(alpha: 0.03)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PcMono.accent.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [PcMono.accent, PcMono.accentDeep]), shape: BoxShape.circle),
            child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(l10n.t('post_challenge_title'),
                style: ThixPolicy.labelStyle.copyWith(fontWeight: FontWeight.bold, fontSize: 14, color: ThixPolicy.textMain)),
          ),
          Text(l10n.t('post_challenge_participants', args: ['$participants']),
              style: ThixPolicy.captionStyle.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: ThixPolicy.textMuted)),
        ]),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(description, style: ThixPolicy.bodyStyle.copyWith(fontSize: 13.5, height: 1.4, color: ThixPolicy.textMain)),
        ],
        const SizedBox(height: 14),
        SizedBox(
          height: 44,
          child: ElevatedButton.icon(
            onPressed: () {
              if (!_isAuthenticated) return;
              HapticFeedback.selectionClick();
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(l10n.t('post_challenge_joined')), backgroundColor: ThixPolicy.success));
            },
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: PcMono.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: Text(l10n.t('post_challenge_cta'),
                style: ThixPolicy.labelStyle.copyWith(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.3)),
          ),
        ),
      ]),
    );
  }

  // ── Signalement ──
  static const List<String> _reportReasonCodes = [
    'spam', 'nudity', 'violence', 'harassment', 'misinformation', 'impersonation', 'inappropriate', 'other',
  ];

  Future<void> _showReportDialog(NetworkPost post, AppLocalizations l10n) async {
    if (!_isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('report_error_auth')), backgroundColor: ThixPolicy.danger));
      return;
    }
    String? selected;
    final detailsController = TextEditingController();
    bool isSubmitting = false;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: PcConfig.dialogBlurSigma, sigmaY: PcConfig.dialogBlurSigma),
          child: AlertDialog(
            backgroundColor: Colors.white.withValues(alpha: 0.95),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(children: [
              const Icon(Icons.flag_outlined, color: ThixPolicy.danger, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l10n.t('report_title'),
                    style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.textMain, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ]),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l10n.t('report_prompt'),
                    style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 13, height: 1.4)),
                const SizedBox(height: 16),
                Text(l10n.t('report_reason_label'),
                    style: ThixPolicy.labelStyle.copyWith(fontWeight: FontWeight.bold, color: ThixPolicy.textMain, fontSize: 12)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selected,
                      isExpanded: true,
                      hint: Text(l10n.t('report_reason_hint'),
                          style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 13)),
                      items: _reportReasonCodes
                          .map((c) => DropdownMenuItem(value: c, child: Text(l10n.t('reason_$c'), style: ThixPolicy.bodyStyle.copyWith(fontSize: 13))))
                          .toList(),
                      onChanged: isSubmitting ? null : (v) => setDialogState(() => selected = v),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(l10n.t('report_details_label'),
                    style: ThixPolicy.labelStyle.copyWith(fontWeight: FontWeight.bold, color: ThixPolicy.textMain, fontSize: 12)),
                const SizedBox(height: 8),
                TextField(
                  controller: detailsController,
                  maxLines: 3,
                  maxLength: PcConfig.maxReportDetailsLength,
                  enabled: !isSubmitting,
                  decoration: InputDecoration(
                    hintText: l10n.t('report_details_hint'),
                    hintStyle: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 13),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: PcMono.accent, width: 1.5)),
                    counterText: '',
                  ),
                ),
              ]),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx, false),
                child: Text(l10n.t('report_cancel'), style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
              ),
              ElevatedButton(
                onPressed: (selected == null || isSubmitting) ? null : () => Navigator.pop(dialogCtx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.danger,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: ThixPolicy.danger.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(l10n.t('report_submit')),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || selected == null) {
      detailsController.dispose();
      return;
    }
    if (!_throttleReport()) {
      detailsController.dispose();
      return;
    }
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      detailsController.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('report_error_auth')), backgroundColor: ThixPolicy.danger));
      }
      return;
    }
    final details = PcValidators.sanitize(detailsController.text.trim(), maxLength: PcConfig.maxReportDetailsLength);
    detailsController.dispose();
    try {
      await Supabase.instance.client.from('post_reports').insert(<String, dynamic>{
        'post_id': post.id,
        'reporter_id': uid,
        'reason_code': selected,
        'details': details,
        'status': 'pending',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (mounted) pcToast(context, l10n.t('report_sent'), bg: ThixPolicy.success);
    } catch (e) {
      PcLog.error('Report insert failed', {'postId': post.id});
      final dup = e.toString().contains('duplicate key') || e.toString().contains('unique constraint');
      if (mounted) pcToast(context, dup ? l10n.t('report_error_duplicate') : l10n.t('report_error_generic'), bg: ThixPolicy.danger);
    }
  }

  // ── Édition / suppression / repost / masquer ──
  Future<void> _editPost(NetworkPost post, WidgetRef ref, AppLocalizations l10n) async {
    if (!_isAuthenticated || widget.currentProfileId != post.userId) return;
    final controller = TextEditingController(text: post.content);
    final newContent = await showDialog<String>(
      context: context,
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: PcConfig.dialogBlurSigma, sigmaY: PcConfig.dialogBlurSigma),
        child: AlertDialog(
          backgroundColor: Colors.white.withValues(alpha: 0.95),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withValues(alpha: 0.8))),
          title: Row(children: [
            const Icon(Icons.edit_rounded, color: ThixPolicy.textMain),
            const SizedBox(width: 8),
            Text(l10n.t('edit_title'), style: ThixPolicy.titleStyle.copyWith(fontSize: 16)),
          ]),
          content: TextField(
            controller: controller,
            maxLines: 6,
            autofocus: true,
            maxLength: PcConfig.maxSanitizedLength,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              hintText: l10n.t('edit_hint'),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: PcMono.accent, width: 1.5)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.t('edit_cancel'), style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                final text = PcValidators.sanitize(controller.text.trim());
                if (text.isNotEmpty) Navigator.pop(dialogContext, text);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.textMain, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(l10n.t('edit_save')),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (newContent == null || newContent.isEmpty || !mounted) return;
    try {
      if (widget.onEdit != null) {
        widget.onEdit!();
      } else {
        await ref.read(networkServiceProvider).updatePost(post.id, newContent).timeout(PcConfig.networkTimeout);
      }
      if (mounted) {
        ref.read(postItemProvider.notifier).updateContent(newContent);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('edit_success'))));
      }
    } catch (_) {
      PcLog.error('editPost failed', {'postId': post.id});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('edit_error')), backgroundColor: ThixPolicy.danger));
    }
  }

  Future<void> _deletePost(NetworkPost post, WidgetRef ref, AppLocalizations l10n) async {
    if (!_isAuthenticated || widget.currentProfileId != post.userId) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: PcConfig.dialogBlurSigma, sigmaY: PcConfig.dialogBlurSigma),
        child: AlertDialog(
          backgroundColor: Colors.white.withValues(alpha: 0.95),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withValues(alpha: 0.8))),
          title: Row(children: [
            const Icon(Icons.warning_amber_rounded, color: ThixPolicy.danger),
            const SizedBox(width: 8),
            Text(l10n.t('delete_title'), style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.danger)),
          ]),
          content: Text(l10n.t('delete_confirm'), style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMain)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: Text(l10n.t('delete_cancel'), style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textMuted)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.danger, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(l10n.t('delete_confirm_btn')),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      if (widget.onDelete != null) {
        widget.onDelete!();
      } else {
        await ref.read(networkServiceProvider).deletePost(post.id).timeout(PcConfig.networkTimeout);
      }
    } catch (_) {
      PcLog.error('deletePost failed', {'postId': post.id});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('delete_error')), backgroundColor: ThixPolicy.danger));
    }
  }

  Future<void> _repost(NetworkPost post, WidgetRef ref, AppLocalizations l10n) async {
    if (_isReposting || !_isAuthenticated) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: PcConfig.dialogBlurSigma, sigmaY: PcConfig.dialogBlurSigma),
        child: AlertDialog(
          backgroundColor: Colors.white.withValues(alpha: 0.95),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withValues(alpha: 0.8))),
          title: Text(l10n.t('repost_title'), style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.textMain)),
          content: TextField(
            controller: _quoteController,
            maxLines: 3,
            maxLength: PcConfig.maxRepostQuoteLength,
            decoration: InputDecoration(
              hintText: l10n.t('repost_hint'),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: Text(l10n.t('repost_cancel'), style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: PcMono.accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(l10n.t('repost_submit')),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) {
      _quoteController.clear();
      return;
    }
    if (!_throttleRepost()) return;
    setState(() => _isReposting = true);
    final quote = PcValidators.sanitize(_quoteController.text.trim(), maxLength: PcConfig.maxRepostQuoteLength);
    try {
      final created = await ref
          .read(networkServiceProvider)
          .repostPost(post.id, quote: quote.isEmpty ? null : quote)
          .timeout(PcConfig.networkTimeout);
      if (!mounted) return;
      ref.read(postItemProvider.notifier).incrementRepost();
      if (created != null) ref.read(feedProvider.notifier).addPostOnTop(created);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('repost_success')), backgroundColor: ThixPolicy.success));
    } catch (_) {
      PcLog.error('repost failed', {'postId': post.id});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('repost_error')), backgroundColor: ThixPolicy.danger));
    } finally {
      if (mounted) setState(() => _isReposting = false);
      _quoteController.clear();
    }
  }

  Future<void> _hidePost(NetworkPost post, AppLocalizations l10n) async {
    if (!_isAuthenticated) return;
    HapticFeedback.selectionClick();
    try {
      await ref.read(networkServiceProvider).hidePost(post.id).timeout(PcConfig.networkTimeout);
      if (mounted) {
        pcToast(context, l10n.t('post_hidden'));
        widget.onRefresh?.call();
      }
    } catch (_) {
      PcLog.error('hidePost failed', {'postId': post.id});
    }
  }

  void _registerImpression(String postId) {
    if (_impressionRegistered || !_isAuthenticated) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    _impressionDebounce?.cancel();
    _impressionDebounce = Timer(PcConfig.impressionDebounce, () {
      if (_impressionRegistered || !mounted) return;
      _impressionRegistered = true;
      Supabase.instance.client
          .rpc('increment_post_impression', params: <String, dynamic>{'p_post_id': postId, 'p_user_id': uid})
          .catchError((e) {
        PcLog.error('impression rpc failed', {'postId': postId});
        _impressionRegistered = false;
      });
    });
  }

  // ── ✅ Réactions (appui long sur ⚡) ──
  Future<void> _showReactions(WidgetRef ref) async {
    if (!_isAuthenticated) return;
    HapticFeedback.mediumImpact();
    Rect anchor = Rect.zero;
    final box = _likeKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.attached) anchor = box.localToGlobal(Offset.zero) & box.size;
    final code = await PcReactionPicker.show(context, anchor);
    if (code == null || !mounted) return;
    await ref.read(postItemProvider.notifier).react(code);
    if (mounted) setState(() {});
  }

  // ── Menu ⋯ ──
  int _impressionsOf(NetworkPost post) => post.views ?? 0;

  void _showStats(NetworkPost post, AppLocalizations l10n) {
    final rows = <MapEntry<String, int>>[
      MapEntry(pcTr(l10n, 'post_stats_impressions', 'Impressions'), _impressionsOf(post)),
      MapEntry(pcTr(l10n, 'post_stats_likes', 'J’aime'), post.likesCount),
      MapEntry(pcTr(l10n, 'post_stats_comments', 'Commentaires'), post.commentsCount),
      MapEntry(pcTr(l10n, 'post_stats_reposts', 'Republications'), post.repostsCount),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text(pcTr(l10n, 'post_stats_title', 'Statistiques du post'),
                style: ThixPolicy.titleStyle.copyWith(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(pcFullDate(post.createdAt), style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary)),
            const SizedBox(height: 14),
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Expanded(child: Text(r.key, style: ThixPolicy.bodyStyle)),
                  Text('${r.value}', style: ThixPolicy.titleStyle.copyWith(fontWeight: FontWeight.bold, fontSize: 15)),
                ]),
              ),
          ]),
        ),
      ),
    );
  }

  Future<void> _showPostMenu(NetworkPost post, bool isOwner, bool isCurrentUserFree, WidgetRef ref, AppLocalizations l10n) async {
    HapticFeedback.selectionClick();
    final text = pcPlainText(post.content);
    final images = post.imageUrls.where(PcValidators.isValidUrl).toList();
    final videos = post.videoUrls.where(PcValidators.isValidUrl).toList();
    final canCopyId = PcValidators.isValidId(post.id);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        Widget tile(IconData icon, String label, VoidCallback onTap, {Color? color}) {
          return ListTile(
            dense: true,
            leading: Icon(icon, color: color ?? ThixPolicy.textMain, size: 22),
            title: Text(label, style: ThixPolicy.bodyStyle.copyWith(color: color ?? ThixPolicy.textMain, fontWeight: FontWeight.w600, fontSize: 14)),
            onTap: () {
              Navigator.pop(sheetCtx);
              onTap();
            },
          );
        }

        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetCtx).size.height * 0.82),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 10, bottom: 12),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2)),
                ),
                if (!isOwner) tile(Icons.person_outline_rounded, pcTr(l10n, 'post_view_profile', 'Voir le profil'), () => _openProfile(post.userId)),
                if (text.isNotEmpty)
                  tile(Icons.copy_rounded, pcTr(l10n, 'post_copy_text', 'Copier le texte'),
                      () => pcCopy(context, text, pcTr(l10n, 'post_text_copied', 'Texte copié'))),
                if (canCopyId)
                  tile(Icons.link_rounded, pcTr(l10n, 'post_copy_link', 'Copier le lien'),
                      () => pcCopy(context, pcPostLink(post.id), pcTr(l10n, 'post_link_copied', 'Lien copié'))),
                tile(Icons.send_outlined, l10n.t('post_share'), () => _sharePost(post)),
                tile(
                  post.isSaved ? Icons.bookmark_remove_outlined : Icons.bookmark_add_outlined,
                  post.isSaved ? pcTr(l10n, 'post_unsave_menu', 'Retirer des enregistrements') : pcTr(l10n, 'post_save_menu', 'Enregistrer'),
                  () => _toggleSaveUi(post, ref, l10n),
                ),
                if (images.length == 1)
                  tile(Icons.download_rounded, pcTr(l10n, 'post_download_photo', 'Télécharger la photo'), () => pcDownloadMedia(context, images.first)),
                if (images.length > 1)
                  tile(Icons.collections_rounded, '${pcTr(l10n, 'post_view_photos', 'Voir et télécharger les photos')} (${images.length})',
                      () => _openGallery(0, images)),
                if (videos.isNotEmpty)
                  tile(Icons.download_rounded, pcTr(l10n, 'post_download_video', 'Télécharger la vidéo'), () => pcDownloadMedia(context, videos.first)),
                const Divider(height: 8),
                if (isOwner) ...[
                  tile(
                    post.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                    post.isPinned ? pcTr(l10n, 'post_unpin_menu', 'Désépingler du profil') : pcTr(l10n, 'post_pin_menu', 'Épingler sur le profil'),
                    () => _togglePin(post, ref, l10n),
                  ),
                  tile(Icons.insights_rounded, pcTr(l10n, 'post_stats_menu', 'Voir les statistiques'), () => _showStats(post, l10n)),
                  if (!isCurrentUserFree) tile(Icons.edit_outlined, l10n.t('post_edit'), () => _editPost(post, ref, l10n)),
                  tile(Icons.delete_outline_rounded, l10n.t('post_delete'), () => _deletePost(post, ref, l10n), color: ThixPolicy.danger),
                ] else ...[
                  tile(Icons.visibility_off_outlined, l10n.t('post_hide'), () => _hidePost(post, l10n)),
                  tile(Icons.flag_outlined, l10n.t('post_report'), () => _showReportDialog(post, l10n), color: ThixPolicy.danger),
                ],
              ]),
            ),
          ),
        );
      },
    );
  }

  void _toggleSaveUi(NetworkPost post, WidgetRef ref, AppLocalizations l10n) {
    if (!_isAuthenticated) return;
    HapticFeedback.selectionClick();
    final was = post.isSaved;
    ref.read(postItemProvider.notifier).toggleSave();
    widget.onSave?.call();
    pcToast(context, was ? pcTr(l10n, 'post_save_removed', 'Retiré des enregistrements') : pcTr(l10n, 'post_save_done', 'Enregistré'), seconds: 1);
  }

  Widget _buildPinnedBadge(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ThixPolicy.gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ThixPolicy.gold.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.push_pin_rounded, size: 12, color: ThixPolicy.gold),
        const SizedBox(width: 5),
        Text(l10n.t('post_pinned_label'),
            style: ThixPolicy.captionStyle.copyWith(fontSize: 10.5, fontWeight: FontWeight.w800, color: ThixPolicy.gold, letterSpacing: 0.3)),
      ]),
    );
  }

  Widget _buildHeader(
    NetworkPost post,
    bool isOwner,
    bool isFollowing,
    bool isCertified,
    CertificationTier? tier,
    CertificationStatus? status,
    bool isLegacyVerified,
    bool isCurrentUserFree,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final authorName = PcValidators.sanitizeLine(post.authorName, maxLength: 100);
    return Row(children: [
      Semantics(
        button: true,
        label: l10n.t('post_open_profile', args: [authorName]),
        child: GestureDetector(
          onTap: () => _openProfile(post.userId),
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
                color: ThixPolicy.surfaceSoft,
              ),
              child: ClipOval(
                child: pcSafeImageUrl(post.authorAvatar) != null
                    ? CachedNetworkImage(imageUrl: pcSafeImageUrl(post.authorAvatar)!, fit: BoxFit.cover, memCacheWidth: 200)
                    : const Icon(Icons.person_rounded, size: 20, color: ThixPolicy.textMuted),
              ),
            ),
            if (!isOwner && !isFollowing)
              Positioned(
                bottom: -2,
                right: -2,
                child: Semantics(
                  button: true,
                  label: l10n.t('post_follow'),
                  child: GestureDetector(
                    onTap: () async {
                      if (_followBusy || !_throttleFollow() || !_isAuthenticated) return;
                      setState(() {
                        _followBusy = true;
                        _isFollowingLocal = true;
                      });
                      HapticFeedback.selectionClick();
                      try {
                        await ref.read(networkServiceProvider).followUser(post.userId).timeout(PcConfig.networkTimeout);
                        if (!mounted) return;
                        ref.invalidate(followStatusProvider(post.userId));
                        ref.invalidate(userProfileProvider(post.userId));
                        widget.onFollow?.call();
                      } catch (_) {
                        PcLog.error('followUser failed', {'userId': post.userId});
                        if (mounted) setState(() => _isFollowingLocal = false);
                      } finally {
                        if (mounted) setState(() => _followBusy = false);
                      }
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: PcMono.accent, border: Border.all(color: Colors.white, width: 2)),
                      child: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openProfile(post.userId),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(
                  authorName,
                  style: ThixPolicy.titleStyle.copyWith(fontWeight: FontWeight.bold, fontSize: 14.5, color: ThixPolicy.textMain, letterSpacing: -0.2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isCertified)
                CertificationNameBadge(tier: tier, status: status, showLabel: false, iconSize: 15, padding: const EdgeInsets.only(left: 6))
              else if (isLegacyVerified)
                const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.verified_rounded, color: PcMono.accent, size: 15)),
            ]),
            const SizedBox(height: 2),
            Tooltip(
              message: pcFullDate(post.createdAt),
              triggerMode: TooltipTriggerMode.longPress,
              child: Text(pcTimeAgo(context, post.createdAt),
                  style: ThixPolicy.captionStyle.copyWith(fontSize: 11, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ),
      IconButton(
        tooltip: pcTr(l10n, 'post_more_options', 'Plus d’options'),
        onPressed: () => _showPostMenu(post, isOwner, isCurrentUserFree, ref, l10n),
        icon: const Icon(Icons.more_horiz_rounded, color: ThixPolicy.textSecondary),
      ),
    ]);
  }

  // ── ✅ Barre d'actions : une seule ligne, compteurs toujours visibles ──
  Widget _buildActionRow(NetworkPost post, bool isLiked, bool isOwner, WidgetRef ref, AppLocalizations l10n) {
    final emoji = isLiked ? pcReactionEmoji(PcCache.instance.myReactions[post.id]) : null;
    final grey = ThixPolicy.textSecondary.withValues(alpha: 0.85);
    final impressions = _impressionsOf(post);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        PcActionBtn(
          key: _likeKey,
          icon: isLiked ? Icons.bolt_rounded : Icons.bolt_outlined,
          iconWidget: emoji != null ? Text(emoji, style: const TextStyle(fontSize: 21, height: 1.1)) : null,
          label: pcCount(post.likesCount),
          color: isLiked ? ThixPolicy.danger : grey,
          onTap: () async {
            if (!_isAuthenticated) return;
            HapticFeedback.selectionClick();
            await ref.read(postItemProvider.notifier).toggleLike();
            if (mounted) setState(() {});
          },
          onLongPress: () => _showReactions(ref),
          semanticsLabel: isLiked ? l10n.t('post_unlike') : l10n.t('post_like'),
        ),
        PcActionBtn(
          icon: Icons.chat_bubble_outline_rounded,
          label: pcCount(post.commentsCount),
          color: grey,
          onTap: widget.onComment ?? () => _openPostDetails(post.id),
          semanticsLabel: l10n.t('post_comments'),
        ),
        PcActionBtn(
          icon: Icons.repeat_rounded,
          label: pcCount(post.repostsCount),
          color: post.isReposted ? ThixPolicy.success : grey,
          onTap: () => _repost(post, ref, l10n),
          semanticsLabel: l10n.t('post_repost'),
        ),
        PcActionBtn(
          icon: Icons.bar_chart_rounded,
          label: pcCount(impressions),
          color: grey,
          onTap: () {
            HapticFeedback.selectionClick();
            if (isOwner) {
              _showStats(post, l10n);
            } else {
              pcToast(context, l10n.t('post_impressions', args: ['$impressions']));
            }
          },
          semanticsLabel: l10n.t('post_impressions_label'),
        ),
        PcActionBtn(
          icon: Icons.send_outlined,
          label: '',
          color: grey,
          onTap: widget.onShare ?? () => _sharePost(post),
          semanticsLabel: l10n.t('post_share'),
        ),
        PcActionBtn(
          icon: post.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          label: '',
          color: post.isSaved ? ThixPolicy.textMain : grey,
          onTap: () => _toggleSaveUi(post, ref, l10n),
          semanticsLabel: post.isSaved ? l10n.t('post_unsave') : l10n.t('post_save'),
        ),
      ],
    );
  }

  // ── BUILD ──
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
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
          var isCertified = false;
          var isLegacyVerified = false;
          if (authorProfile != null) {
            tier = CertificationTierX.parse(authorProfile['certification_tier']);
            status = CertificationStatusX.parse(authorProfile['certification_status']);
            isCertified = status == CertificationStatus.approved || status == CertificationStatus.generated;
            isLegacyVerified = authorProfile['is_verified'] == true;
          }
          final currentUserProfile = ref.watch(userProfileProvider(widget.currentProfileId)).valueOrNull;
          var isCurrentUserFree = true;
          if (currentUserProfile != null) {
            final t = (currentUserProfile['certification_tier']?.toString().toLowerCase()) ?? 'gratuit';
            isCurrentUserFree = t == 'gratuit' || t == 'none';
          }
          final isFollowingDB = ref.watch(followStatusProvider(post.userId)).valueOrNull;
          final isFollowing = isFollowingDB ?? _isFollowingLocal;
          final showContent = post.content.isNotEmpty && !pcIsGhostRepost(post);
          WidgetsBinding.instance.addPostFrameCallback((_) => _registerImpression(post.id));

          // ✅ Plus de BackdropFilter : fond translucide simple → pas de scintillement
          return RepaintBoundary(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                border: Border(
                  top: widget.isFirst
                      ? const BorderSide(color: ThixPolicy.gold, width: PcConfig.cardFirstTopBorderWidth)
                      : BorderSide.none,
                  bottom: const BorderSide(color: ThixPolicy.gold, width: PcConfig.cardBottomBorderWidth),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap ?? () => _openPostDetails(post.id),
                  onLongPress: () => _showPostMenu(post, isOwner, isCurrentUserFree, ref, l10n),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (post.isPinned) _buildPinnedBadge(l10n),
                      _buildPostBadge(post, l10n),
                      _buildHeader(post, isOwner, isFollowing, isCertified, tier, status, isLegacyVerified, isCurrentUserFree, ref, l10n),
                      if (post.isRepostCard)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: Row(children: [
                            const Icon(Icons.repeat_rounded, size: 14, color: ThixPolicy.textMuted),
                            const SizedBox(width: 6),
                            Text(l10n.t('reposted_label'),
                                style: ThixPolicy.captionStyle.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600, color: ThixPolicy.textMuted)),
                          ]),
                        ),
                      const SizedBox(height: 12),
                      if (showContent) _buildPostContent(post, l10n),
                      if (post.isRepostCard && PcValidators.isValidId(post.repostOfId)) ...[
                        const SizedBox(height: 12),
                        PcOriginalPostEmbed(postId: post.repostOfId!),
                      ],
                      if (!post.isRepostCard && (post.hasImages || post.hasVideos)) ...[
                        const SizedBox(height: 12),
                        RepaintBoundary(child: _buildMediaGrid([...post.imageUrls, ...post.videoUrls], l10n)),
                      ],
                      if (post.hasAudio && post.audioUrls.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        RepaintBoundary(child: PcAudioPlayer(audioUrl: post.audioUrls.first, duration: post.audioDurationSeconds)),
                      ],
                      if (post.postType == PostType.poll && PcValidators.isValidPollData(post.pollData)) ...[
                        const SizedBox(height: 12),
                        SizedBox(width: double.infinity, child: _buildPollWidget(post, l10n)),
                      ] else if (post.postType == PostType.challenge) ...[
                        const SizedBox(height: 12),
                        SizedBox(width: double.infinity, child: _buildChallengeWidget(post, l10n)),
                      ],
                      const SizedBox(height: 14),
                      if (likesCount > 0)
                        RepaintBoundary(child: PcLikersStack(count: likesCount, postId: post.id, isLikedByMe: isLiked, l10n: l10n)),
                      const SizedBox(height: 4),
                      _buildActionRow(post, isLiked, isOwner, ref, l10n),
                    ]),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
