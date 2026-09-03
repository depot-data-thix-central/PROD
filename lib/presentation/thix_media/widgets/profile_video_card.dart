/// ProfileVideoCard (Production Enterprise)
/// 
/// Carte vidéo individuelle pour la grille de profil.
/// 
/// ✅ SANS Stream.periodic (utilise le provider existant)
/// ✅ Navigation type-safe via MediaRoutes + guard videoUrl
/// ✅ ThixPolicy + i18n + Semantics + HapticFeedback + RepaintBoundary
/// ✅ Throttling sur taps + logs structurés + mémoïsation coverUrl
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/media_content.dart';
import 'package:thix_id/presentation/thix_media/media_routes.dart';
import 'package:thix_id/presentation/thix_media/providers/thix_media_provider.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const Duration _kTapThrottle = Duration(milliseconds: 500);

// ============================================================================
// LOGGING
// ============================================================================

class _CardLogger {
  static const _tag = 'ProfileVideoCard';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);
  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode) return;
    final data = d != null
        ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}'
        : '';
    debugPrint('[$_tag] [$l] $m$data');
  }
}

// ============================================================================
// CARD
// ============================================================================

/// Carte vidéo individuelle pour la grille de profil.
///
/// ✅ SANS Stream.periodic (utilise le provider existant)
/// ✅ Navigation type-safe via MediaRoutes
class ProfileVideoCard extends ConsumerStatefulWidget {
  final MediaContent post;

  const ProfileVideoCard({super.key, required this.post});

  @override
  ConsumerState<ProfileVideoCard> createState() => _ProfileVideoCardState();
}

class _ProfileVideoCardState extends ConsumerState<ProfileVideoCard> {
  DateTime? _lastTap;

  /// CoverUrl trimmé et mis en cache (évite allocation à chaque build)
  late String _trimmedCoverUrl;
  late bool _hasCover;

  @override
  void initState() {
    super.initState();
    _trimmedCoverUrl = widget.post.coverUrl.trim();
    _hasCover = _trimmedCoverUrl.isNotEmpty;
  }

  @override
  void didUpdateWidget(covariant ProfileVideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.coverUrl != widget.post.coverUrl) {
      _trimmedCoverUrl = widget.post.coverUrl.trim();
      _hasCover = _trimmedCoverUrl.isNotEmpty;
    }
  }

  void _handleTap() {
    // Throttle anti-double-tap
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!) < _kTapThrottle) {
      _CardLogger.warn('Tap throttled', {'id': widget.post.id});
      return;
    }
    _lastTap = now;

    HapticFeedback.selectionClick();

    // Guard : pas de navigation si videoUrl vide
    if (widget.post.videoUrl.trim().isEmpty) {
      _CardLogger.warn('Video URL empty, skipping navigation', {
        'id': widget.post.id,
        'title': widget.post.title,
      });
      return;
    }

    _CardLogger.info('Card tapped', {
      'id': widget.post.id,
      'title': widget.post.title.substring(
          0, widget.post.title.length.clamp(0, 30)),
    });

    MediaRoutes.goToVideoPlayer(
      context,
      videoUrl: widget.post.videoUrl,
      title: widget.post.title,
    );
  }

  String _formatNumber(int num) {
    if (num < 0) return '0';
    if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}K';
    return num.toString();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Utilise le stream provider partagé (auto-dispose + cleanup automatique)
    final liveStats = ref.watch(mediaCountsStreamProvider(widget.post.id));
    final views = liveStats.valueOrNull?.viewCount ?? widget.post.viewCount;

    return RepaintBoundary(
      child: Semantics(
        button: true,
        label: '${widget.post.title}. ${_formatNumber(views)} vues.',
        child: GestureDetector(
          onTap: _handleTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildCover(),
                _buildGradient(),
                if (widget.post.isPaid) _buildPaidBadge(l10n),
                _buildViewsOverlay(views),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCover() {
    if (!_hasCover) {
      return Container(
        color: ThixPolicy.surfaceSoft,
        child: Icon(
          Icons.play_circle_outline_rounded,
          color: ThixPolicy.textMuted.withValues(alpha: 0.4),
          size: 40,
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: _trimmedCoverUrl,
      fit: BoxFit.cover,
      memCacheWidth: 200,
      memCacheHeight: 300,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, __) => Container(color: ThixPolicy.surfaceSoft),
      errorWidget: (_, __, ___) => Container(
        color: ThixPolicy.surfaceSoft,
        child: Icon(
          Icons.broken_image_rounded,
          color: ThixPolicy.textMuted,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildGradient() {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Color(0x1A000000), // 10% black
            Color(0xCC000000), // 80% black
          ],
          stops: [0.5, 0.7, 1.0],
        ),
      ),
    );
  }

  Widget _buildPaidBadge(AppLocalizations l10n) {
    return Positioned(
      top: 6,
      right: 6,
      child: Semantics(
        label: l10n.t('feed_premium'),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: ThixPolicy.warning,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.lock_rounded,
            size: 10,
            color: ThixPolicy.inkDeep,
          ),
        ),
      ),
    );
  }

  Widget _buildViewsOverlay(int views) {
    return Positioned(
      bottom: 6,
      left: 6,
      child: Row(
        children: [
          const Icon(
            Icons.play_arrow_rounded,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 2),
          Text(
            _formatNumber(views),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Color(0x80000000),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
