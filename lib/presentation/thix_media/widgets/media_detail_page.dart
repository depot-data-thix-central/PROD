/// MediaDetailPage (Production Enterprise)
///
/// Page de détail média avec :
/// - Lecteur vidéo avec preview limit (30s avant paywall)
/// - Épisodes multiples (séries)
/// - Section créateur + follow
/// - Actions (like, comment, vues, sauver)
/// - Suggestions (même catalogue)
/// - Paywall premium avec unlock
///
/// ✅ ThixPolicy + i18n 8 langues + go_router + Semantics + HapticFeedback
/// ✅ Logs structurés + mounted checks + RepaintBoundary + throttling
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
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/media_service.dart';
import 'package:thix_id/presentation/thix_media/providers/thix_media_provider.dart';

import '../utils/media_constants.dart';
import 'comments_sheet.dart';
import 'feed_video_player.dart';
import 'media_poster_card.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const int _kPreviewSeconds = 30;
const int _kMaxSuggestions = 4;
const Duration _kTapThrottle = Duration(milliseconds: 400);
const double _kAppBarBlur = kIsWeb ? 6 : 10;
const double _kPaywallBlur = kIsWeb ? 10 : 20;

// ============================================================================
// LOGGING
// ============================================================================

class _DetailLogger {
  static const _tag = 'MediaDetail';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);
  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d != null
        ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}'
        : '';
    debugPrint('[$_tag] [$l] $m$data');
  }
}

// ============================================================================
// SANITIZER
// ============================================================================

class _DetailSanitizer {
  static String title(String? input) {
    if (input == null) return '';
    final s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > 100 ? s.substring(0, 100) : s;
  }

  static double price(num? input) {
    if (input == null || input < 0 || !input.isFinite) return 0.0;
    return input.toDouble();
  }
}

// ============================================================================
// PAGE
// ============================================================================

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
  final Set<String> _newlyFollowed = {};
  List<MediaContent> _suggestions = [];
  DateTime? _lastTap;

  @override
  void initState() {
    super.initState();
    _episodes = [widget.item.videoUrl, ...widget.item.episodesUrls]
        .where((u) => u.isNotEmpty)
        .toList();
    _syncLiked();
    _loadSuggestions();
    _DetailLogger.info('Page initialized', {
      'id': widget.item.id,
      'episodes': _episodes.length,
    });
  }

  bool _throttle() {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!) < _kTapThrottle) {
      _DetailLogger.warn('Tap throttled');
      return false;
    }
    _lastTap = now;
    return true;
  }

  void _loadSuggestions() {
    final otherVideos =
        widget.catalog.where((e) => e.id != widget.item.id).toList();
    otherVideos.shuffle();
    _suggestions = otherVideos.take(_kMaxSuggestions).toList();
  }

  Future<void> _syncLiked() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final res = await MediaService().getLikedMediaIds([widget.item.id]);
      if (mounted && res.contains(widget.item.id)) {
        setState(() => _liked = true);
      }
    } catch (e) {
      _DetailLogger.error('Sync liked failed', {'error': '$e'});
    }
  }

  Future<void> _toggleLike() async {
    if (!_throttle()) return;
    final l10n = AppLocalizations.of(context);
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t('detail_login_required')),
          backgroundColor: ThixPolicy.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _liked = !_liked);
    try {
      await MediaService().toggleLike(widget.item.id);
      _DetailLogger.info('Like toggled', {'liked': _liked});
    } catch (e) {
      _DetailLogger.error('Toggle like failed', {'error': '$e'});
      if (mounted) setState(() => _liked = !_liked); // rollback
    }
  }

  void _toggleSave() {
    if (!_throttle()) return;
    HapticFeedback.lightImpact();
    setState(() => _saved = !_saved);
    _DetailLogger.info('Save toggled', {'saved': _saved});
  }

  void _openComments() {
    if (!_throttle()) return;
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CommentsSheet(
        mediaId: widget.item.id,
        mediaTitle: widget.item.title,
      ),
    ).then((_) {
      if (mounted) {
        ref.invalidate(commentCountProvider(widget.item.id));
      }
    });
    _DetailLogger.info('Comments opened');
  }

  void _openCreatorProfile(String creatorId) {
    if (!_throttle()) return;
    HapticFeedback.selectionClick();
    // ✅ go_router au lieu de Navigator.push
    context.pushNamed(AppRoutes.profile, extra: creatorId);
    _DetailLogger.info('Creator profile opened', {'creatorId': creatorId});
  }

  void _openSuggestion(MediaContent suggestion) {
    if (!_throttle()) return;
    HapticFeedback.mediumImpact();
    // ✅ go_router push (PAS pushReplacement qui casse la stack)
    context.push(
      '${AppRoutes.mediaDetail}/${suggestion.id}',
      extra: {'item': suggestion, 'catalog': widget.catalog},
    );
    _DetailLogger.info('Suggestion opened', {'id': suggestion.id});
  }

  Future<void> _followCreator(String creatorId) async {
    if (!_throttle()) return;
    HapticFeedback.mediumImpact();
    setState(() => _newlyFollowed.add(creatorId));
    try {
      await MediaService().toggleFollow(creatorId);
      _DetailLogger.info('Follow toggled', {'creatorId': creatorId});
    } catch (e) {
      _DetailLogger.error('Follow failed', {'error': '$e'});
    }
  }

  Future<void> _unlockPremium() async {
    if (!_throttle()) return;
    final l10n = AppLocalizations.of(context);

    // Confirmation avant unlock payant
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        title: Text(
          l10n.t('detail_confirm_unlock_title'),
          style: TextStyle(color: ThixPolicy.textMain),
        ),
        content: Text(
          l10n.t('detail_confirm_unlock_message',
              args: {'price': _formatPrice(l10n)}),
          style: TextStyle(color: ThixPolicy.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.t('common_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.t('detail_unlock'),
              style: TextStyle(color: ThixPolicy.warning),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    HapticFeedback.heavyImpact();
    // TODO: Intégrer avec le système de paiement réel
    setState(() {
      _unlocked = true;
      _previewExpired = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.t('detail_unlocked')),
        backgroundColor: ThixPolicy.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
    _DetailLogger.info('Premium unlocked', {'price': _formatPrice(l10n)});
  }

  String _formatPrice(AppLocalizations l10n) {
    final price = _DetailSanitizer.price(widget.item.price);
    // TODO: format selon locale (USD, EUR, FC...)
    return '\$${price.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
        : (creatorProfile?['full_name'] ??
            creatorProfile?['username'] ??
            l10n.t('detail_creator_default'));

    return Scaffold(
      backgroundColor: ThixPolicy.inkDeep,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Semantics(
          button: true,
          label: l10n.t('common_back'),
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios_rounded,
                color: ThixPolicy.textMain),
            onPressed: () {
              HapticFeedback.lightImpact();
              context.pop();
            },
          ),
        ),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(
                sigmaX: _kAppBarBlur, sigmaY: _kAppBarBlur),
            child: Container(
                color: ThixPolicy.inkDeep.withValues(alpha: 0.6)),
          ),
        ),
        title: Text(
          _DetailSanitizer.title(item.title),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: ThixPolicy.textMain,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVideoSection(item, requiresPayment, enforcePreview, l10n),
            if (isSeries && !requiresPayment)
              RepaintBoundary(child: _buildEpisodesSection(l10n)),
            _buildCreatorSection(
              l10n,
              creatorProfile,
              creatorId,
              creatorIsOfficial,
              displayName,
              showFollowBtn,
            ),
            RepaintBoundary(child: _buildActionsBar(l10n, live)),
            if (item.subtitle != null && item.subtitle!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Text(
                  item.subtitle!,
                  style: TextStyle(
                    color: ThixPolicy.textMuted,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              )
            else
              const SizedBox(height: 24),
            if (_suggestions.isNotEmpty)
              RepaintBoundary(
                  child: _buildSuggestionsSection(l10n)),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoSection(MediaContent item, bool requiresPayment,
      bool enforcePreview, AppLocalizations l10n) {
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
      color: ThixPolicy.inkDeep,
      child: Center(
        child: requiresPayment
            ? _buildPaywall(item, l10n)
            : FeedVideoPlayer(
                key: ValueKey('${item.id}_$_currentEpisode'),
                videoUrl: _episodes.isEmpty
                    ? item.videoUrl
                    : _episodes[_currentEpisode.clamp(0, _episodes.length - 1)],
                coverUrl: item.coverUrl,
                isPlaying: true,
                enforcePreviewLimit: enforcePreview,
                previewSeconds: _kPreviewSeconds,
                onPreviewLimitReached: () {
                  if (mounted) setState(() => _previewExpired = true);
                },
                onPlayStateChanged: (_) {},
              ),
      ),
    );
  }

  Widget _buildEpisodesSection(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.t('detail_episodes'),
              style: TextStyle(
                color: ThixPolicy.textMain,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_episodes.length, (i) {
              final active = i == _currentEpisode;
              final label = l10n.t('detail_part_n', args: {'n': '${i + 1}'});
              return Semantics(
                button: true,
                selected: active,
                label: label,
                child: GestureDetector(
                  onTap: () {
                    if (!_throttle()) return;
                    HapticFeedback.selectionClick();
                    setState(() => _currentEpisode = i);
                    _DetailLogger.info('Episode changed', {'index': i});
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: active
                          ? ThixPolicy.textMain
                          : ThixPolicy.textMain.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: active
                            ? ThixPolicy.textMain
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: active ? ThixPolicy.inkDeep : ThixPolicy.textMain,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
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
    AppLocalizations l10n,
    Map<String, dynamic>? creatorProfile,
    String creatorId,
    bool creatorIsOfficial,
    String displayName,
    bool showFollowBtn,
  ) {
    final item = widget.item;
    final avatarUrl = creatorProfile?['avatar_url'] as String?;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Row(
        children: [
          Semantics(
            button: !creatorIsOfficial,
            label: creatorIsOfficial
                ? 'TDIA'
                : l10n.t('detail_open_creator', args: {'name': displayName}),
            child: GestureDetector(
              onTap: !creatorIsOfficial && creatorId.isNotEmpty
                  ? () => _openCreatorProfile(creatorId)
                  : null,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ThixPolicy.textMain.withValues(alpha: 0.8),
                    width: 1.6,
                  ),
                  image: avatarUrl != null
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(avatarUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: avatarUrl == null
                    ? Icon(Icons.person,
                        size: 24, color: ThixPolicy.textMuted)
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@$displayName',
                  style: TextStyle(
                    color: ThixPolicy.textMain,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  item.type,
                  style: TextStyle(
                    color: ThixPolicy.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (showFollowBtn)
            Semantics(
              button: true,
              label: l10n.t('detail_follow'),
              child: GestureDetector(
                onTap: () => _followCreator(creatorId),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: ThixPolicy.textMain,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    l10n.t('detail_follow'),
                    style: TextStyle(
                      color: ThixPolicy.inkDeep,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionsBar(AppLocalizations l10n, dynamic live) {
    final item = widget.item;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _kAppBarBlur, sigmaY: _kAppBarBlur),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: ThixPolicy.textMain.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: ThixPolicy.textMain.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                _detailActionBtn(
                  icon: _liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: formatMediaNumber(live?.likeCount ?? item.likeCount),
                  color: _liked ? ThixPolicy.danger : ThixPolicy.textMain,
                  labelL10n: l10n.t('detail_likes'),
                  onTap: _toggleLike,
                ),
                _detailActionBtn(
                  icon: Icons.chat_bubble_outline_rounded,
                  label:
                      formatMediaNumber(live?.commentCount ?? item.commentCount),
                  color: ThixPolicy.textMain,
                  labelL10n: l10n.t('detail_comments'),
                  onTap: _openComments,
                ),
                _detailActionBtn(
                  icon: Icons.remove_red_eye_outlined,
                  label: formatMediaNumber(live?.viewCount ?? item.viewCount),
                  color: ThixPolicy.textMuted,
                  labelL10n: l10n.t('detail_views'),
                  onTap: () {},
                ),
                _detailActionBtn(
                  icon: _saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  label: l10n.t('detail_save'),
                  color: _saved ? ThixPolicy.textMain : ThixPolicy.textMuted,
                  labelL10n: l10n.t('detail_save'),
                  onTap: _toggleSave,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailActionBtn({
    required IconData icon,
    required String label,
    required String labelL10n,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Semantics(
        button: true,
        label: '$labelL10n $label',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Semantics(
            header: true,
            child: Text(
              l10n.t('detail_suggestions'),
              style: TextStyle(
                color: ThixPolicy.textMain,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
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
            onTap: () => _openSuggestion(_suggestions[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildPaywall(MediaContent item, AppLocalizations l10n) {
    return Container(
      decoration: item.coverUrl.isNotEmpty
          ? BoxDecoration(
              image: DecorationImage(
                image: CachedNetworkImageProvider(item.coverUrl),
                fit: BoxFit.cover,
              ),
            )
          : BoxDecoration(color: ThixPolicy.card),
      child: BackdropFilter(
        filter: ImageFilter.blur(
            sigmaX: _kPaywallBlur, sigmaY: _kPaywallBlur),
        child: Container(
          color: ThixPolicy.inkDeep.withValues(alpha: 0.75),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ThixPolicy.warning,
                ),
                child: Icon(Icons.lock_rounded,
                    size: 40, color: ThixPolicy.inkDeep),
              ),
              const SizedBox(height: 20),
              Semantics(
                header: true,
                child: Text(
                  l10n.t('detail_premium_title'),
                  style: TextStyle(
                    color: ThixPolicy.textMain,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Text(
                  l10n.t('detail_premium_message',
                      args: {'price': _formatPrice(l10n)}),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ThixPolicy.textMuted,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Semantics(
                button: true,
                label: l10n.t('detail_unlock_button',
                    args: {'price': _formatPrice(l10n)}),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThixPolicy.warning,
                    foregroundColor: ThixPolicy.inkDeep,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: _unlockPremium,
                  child: Text(
                    l10n.t('detail_unlock_button',
                        args: {'price': _formatPrice(l10n)}),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
