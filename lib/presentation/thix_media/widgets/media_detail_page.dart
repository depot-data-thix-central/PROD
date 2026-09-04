// lib/presentation/thix_media/widgets/media_detail_page.dart

import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/media_content.dart';
import 'package:thix_id/services/media_service.dart';
import 'package:thix_id/presentation/thix_media/providers/thix_media_provider.dart';

import '../thix_media_page.dart' show MediaConfig, MediaLightPalette, MediaSanitizer, formatMediaNumber, AnalyticsBatcher;
import '../user_profile_page.dart';
import 'comments_sheet.dart';
import 'feed_video_player.dart';
import 'media_poster_card.dart'; // Assure-toi d'importer MediaPosterCard s'il est dans le même dossier

// ============================================================================
// LOGGING & CONSTANTS
// ============================================================================

const int _kMaxSuggestions = 4;
const Duration _kTapThrottle = Duration(milliseconds: 400);
const double _kAppBarBlur = kIsWeb ? 8 : 16;
const double _kPaywallBlur = kIsWeb ? 15 : 25;

class _DetailLogger {
  static const _tag = 'MediaDetail';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);
  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d != null ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}' : '';
    debugPrint('[$_tag] [$l] $m$data');
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
    _episodes = [widget.item.videoUrl, ...widget.item.episodesUrls].where((u) => u.isNotEmpty).toList();
    _syncLiked();
    _loadSuggestions();
  }

  // ✅ TEXTES DE SECOURS (ANTI CLÉS BRUTES)
  String _safeTr(AppLocalizations l10n, String key, String fallback, {List<String>? args}) {
    final val = args != null ? l10n.t(key, args: args) : l10n.t(key);
    if (val.isEmpty || val == key || val.contains(key)) return fallback;
    return val;
  }

  bool _throttle() {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!) < _kTapThrottle) return false;
    _lastTap = now;
    return true;
  }

  void _loadSuggestions() {
    final otherVideos = widget.catalog.where((e) => e.id != widget.item.id).toList();
    otherVideos.shuffle();
    _suggestions = otherVideos.take(_kMaxSuggestions).toList();
  }

  Future<void> _syncLiked() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final res = await MediaService().getLikedMediaIds([widget.item.id]);
      if (mounted && res.contains(widget.item.id)) setState(() => _liked = true);
    } catch (_) {}
  }

  Future<void> _toggleLike(AppLocalizations l10n) async {
    if (!_throttle()) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_safeTr(l10n, 'detail_login_required', 'Veuillez vous connecter'))));
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _liked = !_liked);
    try {
      await MediaService().toggleLike(widget.item.id);
    } catch (_) {
      if (mounted) setState(() => _liked = !_liked);
    }
  }

  void _toggleSave() {
    if (!_throttle()) return;
    HapticFeedback.lightImpact();
    setState(() => _saved = !_saved);
  }

  void _openComments() {
    if (!_throttle()) return;
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CommentsSheet(mediaId: widget.item.id, mediaTitle: widget.item.title),
    ).then((_) {
      if (mounted) ref.invalidate(mediaCommentCountProvider(widget.item.id));
    });
  }

  // ✅ CORRECTION DE LA NAVIGATION (Navigator.push au lieu de context.push)
  void _openCreatorProfile(String creatorId) {
    if (!_throttle()) return;
    HapticFeedback.selectionClick();
    Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfilePage(userId: creatorId)));
  }

  // ✅ CORRECTION DE LA NAVIGATION DES SUGGESTIONS (Plus d'écran bleu)
  void _openSuggestion(MediaContent suggestion) {
    if (!_throttle()) return;
    HapticFeedback.mediumImpact();
    AnalyticsBatcher.register(suggestion.id);
    Navigator.pushReplacement(
      context, 
      MaterialPageRoute(builder: (_) => MediaDetailPage(item: suggestion, catalog: widget.catalog))
    );
  }

  Future<void> _unlockPremium(AppLocalizations l10n) async {
    if (!_throttle()) return;
    final priceStr = _formatPrice();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MediaLightPalette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _safeTr(l10n, 'detail_confirm_unlock_title', 'Débloquer le contenu'),
          style: const TextStyle(color: MediaLightPalette.textPrimary, fontWeight: FontWeight.w800),
        ),
        content: Text(
          _safeTr(l10n, 'detail_confirm_unlock_message', 'Voulez-vous débloquer ce contenu pour $priceStr ?', args: [priceStr]),
          style: const TextStyle(color: MediaLightPalette.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_safeTr(l10n, 'common_cancel', 'Annuler'), style: const TextStyle(color: MediaLightPalette.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white, elevation: 0),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_safeTr(l10n, 'detail_unlock', 'Débloquer')),
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

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_safeTr(l10n, 'detail_unlocked', 'Contenu débloqué avec succès !')),
      backgroundColor: ThixPolicy.success,
    ));
  }

  String _formatPrice() {
    final price = widget.item.price ?? 0.0;
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
    final creatorProfile = creatorId.isNotEmpty ? ref.watch(mediaUserProfileProvider(creatorId)).valueOrNull : null;
    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    final isFollowing = creatorId.isNotEmpty ? (ref.watch(mediaIsFollowingProvider(creatorId)).valueOrNull ?? true) : true;
    final creatorIsOfficial = creatorId.isEmpty;
    final showFollowBtn = !creatorIsOfficial && creatorId.isNotEmpty && creatorId != currentUid && !isFollowing && !_newlyFollowed.contains(creatorId);
    
    final displayName = creatorIsOfficial ? 'TDIA' : (creatorProfile?['full_name'] ?? creatorProfile?['username'] ?? _safeTr(l10n, 'detail_creator_default', 'Créateur'));

    return Scaffold(
      backgroundColor: MediaLightPalette.background,
      appBar: AppBar(
        backgroundColor: MediaLightPalette.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: MediaLightPalette.textPrimary, size: 20),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
        title: Text(
          MediaSanitizer.text(item.title, maxLength: MediaConfig.maxTitleLength),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: MediaLightPalette.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVideoSection(item, requiresPayment, enforcePreview, l10n),
            if (isSeries && !requiresPayment)
              RepaintBoundary(child: _buildEpisodesSection(l10n)),
            _buildCreatorSection(l10n, creatorProfile, creatorId, creatorIsOfficial, displayName, showFollowBtn),
            RepaintBoundary(child: _buildActionsBar(l10n, live)),
            if (item.subtitle != null && item.subtitle!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Text(
                  item.subtitle!,
                  style: const TextStyle(color: MediaLightPalette.textSecondary, fontSize: 14, height: 1.5),
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

  // ✅ CORRECTION DE L'AFFICHAGE DE LA VIDÉO (Taille adaptée + Fond Noir pour les bords)
  Widget _buildVideoSection(MediaContent item, bool requiresPayment, bool enforcePreview, AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      color: Colors.black, // Le fond noir masque les bandes blanches
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
      child: Center(
        child: requiresPayment
            ? _buildPaywall(item, l10n)
            : FeedVideoPlayer(
                key: ValueKey('${item.id}_$_currentEpisode'),
                videoUrl: _episodes.isEmpty ? item.videoUrl : _episodes[_currentEpisode.clamp(0, _episodes.length - 1)],
                coverUrl: item.coverUrl,
                isPlaying: true,
                enforcePreviewLimit: enforcePreview,
                previewSeconds: MediaConfig.previewSeconds,
                enforceCoverFit: false, // Respecte le ratio originel de la vidéo sans zoomer ni déformer
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
          Text(
            _safeTr(l10n, 'detail_episodes', 'Épisodes'),
            style: const TextStyle(color: MediaLightPalette.textPrimary, fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: List.generate(_episodes.length, (i) {
              final active = i == _currentEpisode;
              final label = _safeTr(l10n, 'detail_part_n', 'Partie ${i + 1}', args: ['${i + 1}']);
              return GestureDetector(
                onTap: () {
                  if (!_throttle()) return;
                  HapticFeedback.selectionClick();
                  setState(() => _currentEpisode = i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: active ? MediaLightPalette.textPrimary : MediaLightPalette.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: active ? MediaLightPalette.textPrimary : MediaLightPalette.border, width: 1.2),
                    boxShadow: active ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: active ? Colors.white : MediaLightPalette.textSecondary,
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
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

  Widget _buildCreatorSection(AppLocalizations l10n, Map<String, dynamic>? creatorProfile, String creatorId, bool creatorIsOfficial, String displayName, bool showFollowBtn) {
    final avatarUrl = creatorProfile?['avatar_url'] as String?;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: !creatorIsOfficial && creatorId.isNotEmpty ? () => _openCreatorProfile(creatorId) : null,
            child: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: MediaLightPalette.border, width: 1.6),
                image: avatarUrl != null ? DecorationImage(image: CachedNetworkImageProvider(avatarUrl), fit: BoxFit.cover) : null,
              ),
              child: avatarUrl == null ? const Icon(Icons.person, size: 24, color: MediaLightPalette.textMuted) : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('@$displayName', style: const TextStyle(color: MediaLightPalette.textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(widget.item.type, style: const TextStyle(color: MediaLightPalette.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (showFollowBtn)
            GestureDetector(
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(color: MediaLightPalette.textPrimary, borderRadius: BorderRadius.circular(20)),
                child: Text(_safeTr(l10n, 'detail_follow', 'Suivre'), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
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
          color: MediaLightPalette.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MediaLightPalette.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            _detailActionBtn(
              icon: _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              label: formatMediaNumber(live?.likeCount ?? item.likeCount),
              color: _liked ? ThixPolicy.danger : MediaLightPalette.textPrimary,
              labelL10n: _safeTr(l10n, 'detail_likes', 'J\'aime'),
              onTap: () => _toggleLike(l10n),
            ),
            _detailActionBtn(
              icon: Icons.chat_bubble_outline_rounded,
              label: formatMediaNumber(live?.commentCount ?? item.commentCount),
              color: MediaLightPalette.textPrimary,
              labelL10n: _safeTr(l10n, 'detail_comments', 'Commentaires'),
              onTap: _openComments,
            ),
            _detailActionBtn(
              icon: Icons.remove_red_eye_outlined,
              label: formatMediaNumber(live?.viewCount ?? item.viewCount),
              color: MediaLightPalette.textSecondary,
              labelL10n: _safeTr(l10n, 'detail_views', 'Vues'),
              onTap: () {},
            ),
            _detailActionBtn(
              icon: _saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              label: _safeTr(l10n, 'detail_save', 'Enregistrer'),
              color: _saved ? ThixPolicy.primary : MediaLightPalette.textSecondary,
              labelL10n: _safeTr(l10n, 'detail_save', 'Enregistrer'),
              onTap: _toggleSave,
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailActionBtn({required IconData icon, required String label, required String labelL10n, required Color color, required VoidCallback onTap}) {
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
              Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
            ],
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
          child: Text(
            _safeTr(l10n, 'detail_suggestions', 'À découvrir aussi'),
            style: const TextStyle(color: MediaLightPalette.textPrimary, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.3),
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.70,
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
    final priceStr = _formatPrice();
    return Container(
      decoration: cover != null
          ? BoxDecoration(image: DecorationImage(image: CachedNetworkImageProvider(cover), fit: BoxFit.cover))
          : const BoxDecoration(color: Colors.black),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _kPaywallBlur, sigmaY: _kPaywallBlur),
        child: Container(
          color: Colors.black.withValues(alpha: 0.75),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                child: const Icon(Icons.lock_rounded, size: 40, color: Colors.black87),
              ),
              const SizedBox(height: 20),
              Text(
                _safeTr(l10n, 'detail_premium_title', 'Contenu Premium'),
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Text(
                  _safeTr(l10n, 'detail_premium_message', 'Fin de l\'aperçu gratuit. Débloquez la suite pour $priceStr.', args: [priceStr]),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.gold, foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: () => _unlockPremium(l10n),
                child: Text(
                  _safeTr(l10n, 'detail_unlock_button', 'Débloquer ($priceStr)', args: [priceStr]),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
