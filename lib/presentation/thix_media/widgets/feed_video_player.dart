// lib/presentation/thix_media/widgets/feed_video_player.dart
/// FeedVideoPlayer (Production Enterprise)
/// 
/// Lecteur vidéo pour le feed avec :
/// - Preview limit (mode TikTok : 30s avant paywall)
/// - Barre de progression draggable
/// - Auto-play/pause selon visibilité
/// - Placeholder cover pendant chargement
/// - Support du plein écran (enforceCoverFit) pour le mode Fil
/// 
/// ✅ ThixPolicy + Semantics + HapticFeedback + RepaintBoundary
/// ✅ Logs structurés + throttling + mounted checks + error handling
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const Duration _kInitTimeout = Duration(seconds: 15);
const Duration _kTapThrottle = Duration(milliseconds: 400);
const double _kProgressBarHeightNormal = 2.0;
const double _kProgressBarHeightDragging = 6.0;

// ============================================================================
// LOGGING
// ============================================================================

class _PlayerLogger {
  static const _tag = 'FeedVideoPlayer';
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
// WIDGET
// ============================================================================

class FeedVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String coverUrl;
  final bool isPlaying;
  final bool enforcePreviewLimit;
  final int previewSeconds;
  final VoidCallback? onPreviewLimitReached;
  final ValueChanged<bool> onPlayStateChanged;
  final bool enforceCoverFit; // ✅ AJOUT DU PARAMÈTRE FULL SCREEN

  const FeedVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.coverUrl,
    required this.isPlaying,
    required this.onPlayStateChanged,
    this.enforcePreviewLimit = false,
    this.previewSeconds = 30,
    this.onPreviewLimitReached,
    this.enforceCoverFit = false, // ✅ PAR DÉFAUT À FALSE
  });

  @override
  State<FeedVideoPlayer> createState() => _FeedVideoPlayerState();
}

class _FeedVideoPlayerState extends State<FeedVideoPlayer> {
  VideoPlayerController? _controller;
  bool _init = false;
  bool _paused = false;
  bool _previewTriggered = false;
  final ValueNotifier<Duration> _pos = ValueNotifier(Duration.zero);
  Duration _dur = Duration.zero;
  bool _isDragging = false;
  DateTime? _lastTap;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    // Guard : URL vide
    if (widget.videoUrl.trim().isEmpty) {
      _PlayerLogger.warn('videoUrl empty, skipping init');
      return;
    }

    // Guard : URL invalide
    Uri? uri;
    try {
      uri = Uri.parse(widget.videoUrl);
      if (!uri.hasScheme || !uri.hasAuthority) {
        _PlayerLogger.error('Invalid URI', {'url': widget.videoUrl});
        return;
      }
    } catch (e) {
      _PlayerLogger.error('URI parse failed', {'url': widget.videoUrl, 'error': '$e'});
      return;
    }

    _controller = VideoPlayerController.networkUrl(uri);

    try {
      await _controller!.initialize().timeout(_kInitTimeout);
      
      if (!mounted) {
        _controller?.dispose();
        return;
      }

      _controller!.setLooping(!widget.enforcePreviewLimit);
      _controller!.setVolume(1.0);
      _controller!.addListener(_onTick);

      setState(() {
        _init = true;
        _dur = _controller!.value.duration;
      });

      if (widget.isPlaying) {
        _controller!.play();
      }

      _PlayerLogger.info('Player initialized', {
        'duration': '${_dur.inSeconds}s',
        'aspectRatio': _controller!.value.aspectRatio.toStringAsFixed(2),
      });
    } catch (e) {
      _PlayerLogger.error('Init failed', {'error': '$e'});
    }
  }

  void _onTick() {
    if (!mounted || _controller == null) return;
    if (!_isDragging) {
      _pos.value = _controller!.value.position;
    }

    // Preview limit (mode TikTok : 30s avant paywall)
    if (widget.enforcePreviewLimit &&
        !_previewTriggered &&
        _controller!.value.position.inSeconds >= widget.previewSeconds) {
      _previewTriggered = true;
      _controller!.pause();
      _PlayerLogger.info('Preview limit reached', {'seconds': widget.previewSeconds});
      widget.onPreviewLimitReached?.call();
    }
  }

  @override
  void didUpdateWidget(covariant FeedVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Dispose et recrée si l'URL change
    if (widget.videoUrl != oldWidget.videoUrl) {
      _disposeController();
      _init = false;
      _previewTriggered = false;
      _initPlayer();
      return;
    }

    if (!_init || _controller == null) return;

    // Auto-play/pause selon visibilité
    if (widget.isPlaying && !oldWidget.isPlaying && !_previewTriggered) {
      _paused = false;
      _controller!.play();
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      _controller!.pause();
      _controller!.seekTo(Duration.zero);
      _previewTriggered = false;
    }
  }

  void _disposeController() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    _disposeController();
    _pos.dispose();
    super.dispose();
  }

  void _seekToPercent(double pct) {
    if (!_init || _controller == null) return;
    try {
      final newPos = Duration(milliseconds: (_dur.inMilliseconds * pct).round());
      _controller!.seekTo(newPos);
      _pos.value = newPos;
    } catch (e) {
      _PlayerLogger.error('Seek failed', {'error': '$e'});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (!_init || _controller == null || !_controller!.value.isInitialized) {
      return _buildPlaceholder();
    }

    // ✅ LOGIQUE DE DIMENSIONNEMENT : Full Screen vs Standard
    Widget videoWidget;
    if (widget.enforceCoverFit) {
      videoWidget = SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover, // Remplit tout l'écran sans marges
          child: SizedBox(
            width: _controller!.value.size.width,
            height: _controller!.value.size.height,
            child: VideoPlayer(_controller!),
          ),
        ),
      );
    } else {
      videoWidget = Center(
        child: AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        ),
      );
    }

    return RepaintBoundary(
      child: Semantics(
        button: true,
        label: _paused ? l10n.t('video_play') : l10n.t('video_pause'),
        child: GestureDetector(
          onTap: _handleTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                color: ThixPolicy.inkDeep,
                child: videoWidget, // ✅ Affichage dynamique (Cover ou AspectRatio)
              ),
              if (_paused)
                Center(
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: ThixPolicy.textMain.withValues(alpha: 0.7),
                    size: 80,
                  ),
                ),
              _buildProgressBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    if (widget.coverUrl.trim().isEmpty) {
      return Container(color: ThixPolicy.inkDeep);
    }
    return CachedNetworkImage(
      imageUrl: widget.coverUrl,
      fit: widget.enforceCoverFit ? BoxFit.cover : BoxFit.contain, // ✅ Le placeholder s'adapte aussi
      placeholder: (_, __) => Container(color: ThixPolicy.inkDeep),
      errorWidget: (_, __, ___) => Container(
        color: ThixPolicy.inkDeep,
        child: Icon(
          Icons.broken_image_rounded,
          color: ThixPolicy.textMuted,
          size: 40,
        ),
      ),
    );
  }

  void _handleTap() {
    // Throttle anti-double-tap
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!) < _kTapThrottle) {
      _PlayerLogger.warn('Tap throttled');
      return;
    }
    _lastTap = now;

    if (_previewTriggered || _controller == null) return;

    HapticFeedback.selectionClick();

    if (_controller!.value.isPlaying) {
      _controller!.pause();
      _paused = true;
      _PlayerLogger.info('Paused');
    } else {
      _controller!.play();
      _paused = false;
      _PlayerLogger.info('Playing');
    }

    widget.onPlayStateChanged(_paused);
  }

  Widget _buildProgressBar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: GestureDetector(
        onHorizontalDragStart: (_) {
          _isDragging = true;
          _controller?.pause();
        },
        onHorizontalDragUpdate: (d) {
          // Guard : context.size peut être null
          final width = context.size?.width ?? 0;
          if (width <= 0) return;

          final pct = (d.localPosition.dx / width).clamp(0.0, 1.0);
          _pos.value = Duration(milliseconds: (_dur.inMilliseconds * pct).round());
        },
        onHorizontalDragEnd: (_) {
          _isDragging = false;
          try {
            _controller?.seekTo(_pos.value);
            if (!_paused) _controller?.play();
          } catch (e) {
            _PlayerLogger.error('Drag end seek failed', {'error': '$e'});
          }
        },
        onTapDown: (d) {
          // Guard : context.size peut être null
          final width = context.size?.width ?? 0;
          if (width <= 0) return;

          _seekToPercent((d.localPosition.dx / width).clamp(0.0, 1.0));
        },
        child: Container(
          height: 20,
          color: Colors.transparent,
          alignment: Alignment.bottomCenter,
          child: ValueListenableBuilder<Duration>(
            valueListenable: _pos,
            builder: (_, pos, __) {
              final pct = _dur.inMilliseconds == 0
                  ? 0.0
                  : pos.inMilliseconds / _dur.inMilliseconds;
              return LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    alignment: Alignment.bottomLeft,
                    children: [
                      // Background
                      Container(
                        height: _isDragging
                            ? _kProgressBarHeightDragging
                            : _kProgressBarHeightNormal,
                        width: double.infinity,
                        color: ThixPolicy.textMuted.withValues(alpha: 0.3),
                      ),
                      // Progress
                      Container(
                        height: _isDragging
                            ? _kProgressBarHeightDragging
                            : _kProgressBarHeightNormal,
                        width: constraints.maxWidth * pct,
                        color: ThixPolicy.textMain,
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
