/// MediaPosterCard (Production Enterprise)
/// 
/// Carte poster pour catalogue vidéo avec :
/// - Badge premium (cadenas doré)
/// - Badge série (nombre d'épisodes)
/// - Overlay vues
/// - Gradient bas pour lisibilité titre
/// 
/// ✅ ThixPolicy + i18n 8 langues + Semantics + HapticFeedback
/// ✅ RepaintBoundary + throttling + mémoïsation coverUrl
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/media_content.dart';

import '../utils/media_constants.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const Duration _kTapThrottle = Duration(milliseconds: 500);
const Color _kGradientBottom = Color(0xDD000000); // 87% noir (const)

// ============================================================================
// LOGGING
// ============================================================================

class _PosterLogger {
  static const _tag = 'MediaPosterCard';
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
// WIDGET
// ============================================================================

class MediaPosterCard extends StatefulWidget {
  final MediaContent item;
  final VoidCallback onTap;
  final bool compact;

  const MediaPosterCard({
    super.key,
    required this.item,
    required this.onTap,
    this.compact = false,
  });

  @override
  State<MediaPosterCard> createState() => _MediaPosterCardState();
}

class _MediaPosterCardState extends State<MediaPosterCard> {
  DateTime? _lastTap;
  late String _trimmedCoverUrl;
  late bool _hasCover;
  late bool _isSeries;
  late int _episodesCount;

  @override
  void initState() {
    super.initState();
    _computeDerived();
  }

  @override
  void didUpdateWidget(covariant MediaPosterCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item != widget.item) {
      _computeDerived();
    }
  }

  void _computeDerived() {
    _trimmedCoverUrl = widget.item.coverUrl.trim();
    _hasCover = _trimmedCoverUrl.isNotEmpty;
    _episodesCount = widget.item.episodesUrls.length;
    _isSeries = _episodesCount > 0;
  }

  void _handleTap() {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!) < _kTapThrottle) {
      _PosterLogger.warn('Tap throttled', {'id': widget.item.id});
      return;
    }
    _lastTap = now;

    HapticFeedback.selectionClick();

    _PosterLogger.info('Card tapped', {
      'id': widget.item.id,
      'title': widget.item.title.substring(
          0, widget.item.title.length.clamp(0, 30)),
    });

    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return RepaintBoundary(
      child: Semantics(
        button: true,
        label: '${widget.item.title}. ${widget.item.viewCount} vues.',
        child: GestureDetector(
          onTap: _handleTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildCover(),
                      _buildGradient(),
                      if (widget.item.isPaid) _buildPaidBadge(l10n),
                      if (_isSeries) _buildSeriesBadge(l10n),
                      _buildViewsOverlay(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.item.title,
                maxLines: widget.compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ThixPolicy.textMain,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCover() {
    if (!_hasCover) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ThixPolicy.surfaceSoft,
              ThixPolicy.card,
            ],
          ),
        ),
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
      memCacheWidth: 400,
      memCacheHeight: 600,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, __) => Container(color: ThixPolicy.card),
      errorWidget: (_, __, ___) => Container(
        color: ThixPolicy.card,
        child: Icon(
          Icons.broken_image_rounded,
          color: ThixPolicy.textMuted.withValues(alpha: 0.4),
          size: 30,
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
          colors: [Colors.transparent, _kGradientBottom],
          stops: [0.4, 1.0],
        ),
      ),
    );
  }

  Widget _buildPaidBadge(AppLocalizations l10n) {
    return Positioned(
      top: 8,
      right: 8,
      child: Semantics(
        label: l10n.t('feed_premium'),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: ThixPolicy.inkDeep.withValues(alpha: 0.6),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.lock_rounded,
            size: 12,
            color: ThixPolicy.warning,
          ),
        ),
      ),
    );
  }

  Widget _buildSeriesBadge(AppLocalizations l10n) {
    return Positioned(
      top: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: ThixPolicy.primary.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          l10n.t('media_episodes_count',
              args: {'count': '${_episodesCount + 1}'}),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildViewsOverlay() {
    return Positioned(
      left: 8,
      right: 8,
      bottom: 8,
      child: Row(
        children: [
          Icon(
            Icons.play_circle_fill_rounded,
            color: ThixPolicy.textMain.withValues(alpha: 0.7),
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            formatMediaNumber(widget.item.viewCount),
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
