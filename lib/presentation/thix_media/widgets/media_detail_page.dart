// lib/presentation/thix_media/widgets/media_detail_page.dart
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
/// ✅ Aligné sur le design "Modern Sleek Light" (Sleek Glassmorphism clair)
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
// PALETTE CLAIRE (Light Mode Premium — Cohérente avec ThixMediaPage)
// ============================================================================

class _MediaLightPalette {
  _MediaLightPalette._();

  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);
}

// ============================================================================
// CONSTANTS
// ============================================================================

const int _kPreviewSeconds = 30;
const int _kMaxSuggestions = 4;
const Duration _kTapThrottle = Duration(milliseconds: 400);
const double _kAppBarBlur = kIsWeb ? 8 : 16;
const double _kPaywallBlur = kIsWeb ? 15 : 25;

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
          content: Text(l10n.t('detail_login_required').isNotEmpty
              ? l10n.t('detail_login_required')
              : 'Veuillez vous connecter'),
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
      if (mounted) setState(() => _liked = !_liked);
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
        ref.invalidate(mediaCommentCountProvider(widget.item.id));
      }
    });
    _DetailLogger.info('Comments opened');
  }

  void _openCreatorProfile(String creatorId) {
    if (!_throttle()) return;
    HapticFeedback.selectionClick();
    context.pushNamed(AppRoutes.profile, extra: creatorId);
    _DetailLogger.info('Creator profile opened', {'creatorId': creatorId});
  }

  void _openSuggestion(MediaContent suggestion) {
    if (!_throttle()) return;
    HapticFeedback.mediumImpact();
    context.push(
      '/media/detail/${suggestion.id}',
      extra: {'item': suggestion, 'catalog': widget.catalog},
    );
    _DetailLogger.info('Suggestion opened', {'id': suggestion.id});
  }

  Future<void> _unlockPremium() async {
    if (!_throttle()) return;
    final l10n = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _MediaLightPalette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n.t('detail_confirm_unlock_title').isNotEmpty
              ? l10n.t('detail_confirm_unlock_title')
              : 'Débloquer le contenu',
          style: const TextStyle(
              color: _MediaLightPalette.textPrimary, fontWeight: FontWeight.w800),
        ),
        content: Text(
          l10n.t('detail_confirm_unlock_message',
              args: [_formatPrice(l10n)]).isNotEmpty
              ? l10n.t('detail_confirm_unlock_message',
                  args: [_formatPrice(l10n)])
              : 'Voulez-vous débloquer ce contenu pour ${_formatPrice(l10n)} ?',
          style: const TextStyle(color: _MediaLightPalette.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.t('common_cancel').isNotEmpty ? l10n.t('common_cancel') : 'Annuler',
                style: const TextStyle(color: _MediaLightPalette.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.t('detail_unlock').isNotEmpty ? l10n.t('detail_unlock') : 'Débloquer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    HapticFeedback.heavyImpact();
    setState(() {
      _unlocked = true;
      _previewExpired = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.t('detail_unlocked').isNotEmpty ? l10n.t('detail_unlocked') : 'Contenu débloqué avec succès !'),
        backgroundColor: ThixPolicy.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
    _DetailLogger.info('Premium unlocked', {'price': _formatPrice(l10n)});
  }

  String _formatPrice(AppLocalizations l10n) {
    final price = _DetailSanitizer.price(widget.item.price);
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
        ? ref.watch(mediaUserProfileProvider(creatorId)).valueOrNull
        : null;
    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    final isFollowing = creatorId.isNotEmpty
        ? (ref.watch(mediaIsFollowingProvider(creatorId)).valueOrNull ?? true)
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
            (l10n.t('detail_creator_default').isNotEmpty
                ? l10n.t('detail_creator_default')
                : 'Créateur'));

    return Scaffold(
      backgroundColor: _MediaLightPalette.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Semantics(
          button: true,
          label: l10n.t('common_back').isNotEmpty ? l10n.t('common_back') : 'Retour',
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: _MediaLightPalette.textPrimary, size: 20),
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
                color: _MediaLightPalette.surface.withValues(alpha: 0.8)),
          ),
        ),
        title: Text(
          _DetailSanitizer.title(item.title),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _MediaLightPalette.textPrimary,
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
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Text(
                  item.subtitle!,
                  style: const TextStyle(
                    color: _MediaLightPalette.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              )
            else
              const SizedBox(height: 24),
            if (_suggestions.isNotEmpty)
              RepaintBoundary(child: _buildSuggestionsSection(l10n)),
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
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.50),
      color: Colors.black,
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.t('detail_episodes').isNotEmpty ? l10n.t('detail_episodes') : 'Épisodes',
              style: const TextStyle(
                color: _MediaLightPalette.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_episodes.length, (i) {
              final active = i == _currentEpisode;
              final label = l10n.t('detail_part_n', args: ['${i + 1}']).isNotEmpty
                  ? l10n.t('detail_part_n', args: ['${i + 1}'])
                  : 'Partie ${i + 1}';
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
                          ? _MediaLightPalette.textPrimary
                          : _MediaLightPalette.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active
                            ? _MediaLightPalette.textPrimary
                            : _MediaLightPalette.border,
                        width: 1.2,
                      ),
                      boxShadow: active
                          ? []
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: active ? Colors.white : _MediaLightPalette.textSecondary,
                        fontSize: 13,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          Semantics(
            button: !creatorIsOfficial,
            label: creatorIsOfficial
                ? 'TDIA'
                : (l10n.t('detail_open_creator', args: [displayName]).isNotEmpty
                    ? l10n.t('detail_open_creator', args: [displayName])
                    : 'Voir profil de $displayName'),
            child: GestureDetector(
              onTap: !creatorIsOfficial && creatorId.isNotEmpty
                  ? () => _openCreatorProfile(creatorId)
                  : null,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _MediaLightPalette.border,
                    width: 1.6,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ],
                  image: avatarUrl != null
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(avatarUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: avatarUrl == null
                    ? const Icon(Icons.person,
                        size: 24, color: _MediaLightPalette.textMuted)
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@$displayName',
                  style: const TextStyle(
                    color: _MediaLightPalette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.type,
                  style: const TextStyle(
                    color: _MediaLightPalette.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (showFollowBtn)
            Semantics(
              button: true,
              label: l10n.t('detail_follow').isNotEmpty ? l10n.t('detail_follow') : 'Suivre',
              child: GestureDetector(
                onTap: () async {
                  if (!_throttle()) return;
                  HapticFeedback.mediumImpact();
                  setState(() => _newlyFollowed.add(creatorId));
                  try {
                    await MediaService().toggleFollow(creatorId);
                    ref.invalidate(mediaIsFollowingProvider(creatorId));
                  } catch (_) {}
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: _MediaLightPalette.textPrimary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    l10n.t('detail_follow').isNotEmpty ? l10n.t('detail_follow') : 'Suivre',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: _MediaLightPalette.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _MediaLightPalette.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            _detailActionBtn(
              icon: _liked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              label: formatMediaNumber(live?.likeCount ?? item.likeCount),
              color: _liked ? ThixPolicy.danger : _MediaLightPalette.textPrimary,
              labelL10n: l10n.t('detail_likes').isNotEmpty ? l10n.t('detail_likes') : 'J\'aime',
              onTap: _toggleLike,
            ),
            _detailActionBtn(
              icon: Icons.chat_bubble_outline_rounded,
              label:
                  formatMediaNumber(live?.commentCount ?? item.commentCount),
              color: _MediaLightPalette.textPrimary,
              labelL10n: l10n.t('detail_comments').isNotEmpty ? l10n.t('detail_comments') : 'Commentaires',
              onTap: _openComments,
            ),
            _detailActionBtn(
              icon: Icons.remove_red_eye_outlined,
              label: formatMediaNumber(live?.viewCount ?? item.viewCount),
              color: _MediaLightPalette.textSecondary,
              labelL10n: l10n.t('detail_views').isNotEmpty ? l10n.t('detail_views') : 'Vues',
              onTap: () {},
            ),
            _detailActionBtn(
              icon: _saved
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              label: l10n.t('detail_save').isNotEmpty ? l10n.t('detail_save') : 'Sauver',
              color: _saved ? ThixPolicy.primary : _MediaLightPalette.textSecondary,
              labelL10n: l10n.t('detail_save').isNotEmpty ? l10n.t('detail_save') : 'Sauver',
              onTap: _toggleSave,
            ),
          ],
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
                    fontSize: 12,
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
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Semantics(
            header: true,
            child: Text(
              l10n.t('detail_suggestions').isNotEmpty ? l10n.t('detail_suggestions') : 'À découvrir aussi',
              style: const TextStyle(
                color: _MediaLightPalette.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.70,
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
    final cover = MediaSanitizer.imageUrl(item.coverUrl);

    return Container(
      decoration: cover != null
          ? BoxDecoration(
              image: DecorationImage(
                image: CachedNetworkImageProvider(cover),
                fit: BoxFit.cover,
              ),
            )
          : const BoxDecoration(color: Colors.black),
      child: BackdropFilter(
        filter: ImageFilter.blur(
            sigmaX: _kPaywallBlur, sigmaY: _kPaywallBlur),
        child: Container(
          color: Colors.black.withValues(alpha: 0.75),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: const Icon(Icons.lock_rounded,
                    size: 40, color: Colors.black87),
              ),
              const SizedBox(height: 20),
              Semantics(
                header: true,
                child: Text(
                  l10n.t('detail_premium_title').isNotEmpty
                      ? l10n.t('detail_premium_title')
                      : 'Contenu Premium',
                  style: const TextStyle(
                    color: Colors.white,
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
                          args: [_formatPrice(l10n)])
                      .isNotEmpty
                      ? l10n.t('detail_premium_message',
                          args: [_formatPrice(l10n)])
                      : "Fin de l'aperçu gratuit. Débloquez la suite pour ${_formatPrice(l10n)}.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Semantics(
                button: true,
                label: l10n.t('detail_unlock_button',
                        args: [_formatPrice(l10n)])
                    .isNotEmpty
                    ? l10n.t('detail_unlock_button',
                        args: [_formatPrice(l10n)])
                    : 'Débloquer (${_formatPrice(l10n)})',
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThixPolicy.gold,
                    foregroundColor: Colors.black87,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: _unlockPremium,
                  child: Text(
                    l10n.t('detail_unlock_button',
                            args: [_formatPrice(l10n)])
                        .isNotEmpty
                        ? l10n.t('detail_unlock_button',
                            args: [_formatPrice(l10n)])
                        : 'Débloquer (${_formatPrice(l10n)})',
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
