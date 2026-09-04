// lib/presentation/thix_media/widgets/feed_video_player.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart'; // ✅ Gère l'écran toujours allumé

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import '../thix_media_page.dart' show MediaSanitizer;

const Duration _kInitTimeout = Duration(seconds: 15);
const Duration _kTapThrottle = Duration(milliseconds: 400);

class FeedVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String coverUrl;
  final bool isPlaying;
  final bool enforcePreviewLimit;
  final int previewSeconds;
  final VoidCallback? onPreviewLimitReached;
  final ValueChanged<bool> onPlayStateChanged;

  const FeedVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.coverUrl,
    required this.isPlaying,
    required this.onPlayStateChanged,
    this.enforcePreviewLimit = false,
    this.previewSeconds = 30,
    this.onPreviewLimitReached,
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
    final safeUrl = MediaSanitizer.imageUrl(widget.videoUrl);
    if (safeUrl == null) return;

    _controller = VideoPlayerController.networkUrl(Uri.parse(safeUrl));

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
        WakelockPlus.enable(); // 💡 Garde l'écran allumé
      }
    } catch (e) {
      debugPrint('Video Init Error: $e');
    }
  }

  void _onTick() {
    if (!mounted || _controller == null) return;
    if (!_isDragging) {
      _pos.value = _controller!.value.position;
    }

    if (widget.enforcePreviewLimit && !_previewTriggered && _controller!.value.position.inSeconds >= widget.previewSeconds) {
      _previewTriggered = true;
      _controller!.pause();
      WakelockPlus.disable(); // 💡 Autorise l'écran à s'éteindre si paywall
      widget.onPreviewLimitReached?.call();
    }
  }

  @override
  void didUpdateWidget(covariant FeedVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.videoUrl != oldWidget.videoUrl) {
      _disposeController();
      _init = false;
      _previewTriggered = false;
      _initPlayer();
      return;
    }

    if (!_init || _controller == null) return;

    if (widget.isPlaying && !oldWidget.isPlaying && !_previewTriggered) {
      _paused = false;
      _controller!.play();
      WakelockPlus.enable(); // 💡 Garde l'écran allumé
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      _controller!.pause();
      _controller!.seekTo(Duration.zero);
      _previewTriggered = false;
      WakelockPlus.disable(); // 💡 Autorise l'écran à s'éteindre
    }
  }

  void _disposeController() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    _controller = null;
    WakelockPlus.disable();
  }

  @override
  void dispose() {
    _disposeController();
    _pos.dispose();
    super.dispose();
  }

  void _seekToPercent(double pct) {
    if (!_init || _controller == null) return;
    final newPos = Duration(milliseconds: (_dur.inMilliseconds * pct).round());
    _controller!.seekTo(newPos);
    _pos.value = newPos;
  }

  void _handleTap() {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!) < _kTapThrottle) return;
    _lastTap = now;

    if (_previewTriggered || _controller == null) return;

    HapticFeedback.selectionClick();

    if (_controller!.value.isPlaying) {
      _controller!.pause();
      WakelockPlus.disable();
      _paused = true;
    } else {
      _controller!.play();
      WakelockPlus.enable();
      _paused = false;
    }
    setState(() {});
    widget.onPlayStateChanged(_paused);
  }

  @override
  Widget build(BuildContext context) {
    if (!_init || _controller == null || !_controller!.value.isInitialized) {
      final cover = MediaSanitizer.imageUrl(widget.coverUrl);
      return cover == null ? Container(color: Colors.black) : CachedNetworkImage(imageUrl: cover, fit: BoxFit.contain);
    }

    return RepaintBoundary(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque, // ✅ Rends tout l'écran cliquable
        onTap: _handleTap, // ✅ Tap pour Play/Pause
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ✅ S'ADAPTE À LA VRAIE TAILLE DE LA VIDÉO (Sans perte de qualité)
            Container(
              color: Colors.black,
              child: Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              ),
            ),
            
            // Icône de pause au centre
            if (_paused)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 60),
                ),
              ),

            // ✅ BARRE DE PROGRESSION (Plus grande, cliquable, tout en bas)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) {
                  _isDragging = true;
                  _controller?.pause();
                },
                onHorizontalDragUpdate: (d) {
                  final width = context.size?.width ?? MediaQuery.of(context).size.width;
                  final pct = (d.localPosition.dx / width).clamp(0.0, 1.0);
                  _pos.value = Duration(milliseconds: (_dur.inMilliseconds * pct).round());
                },
                onHorizontalDragEnd: (_) {
                  _isDragging = false;
                  _controller?.seekTo(_pos.value);
                  if (!_paused) _controller?.play();
                },
                onTapDown: (d) {
                  final width = context.size?.width ?? MediaQuery.of(context).size.width;
                  _seekToPercent((d.localPosition.dx / width).clamp(0.0, 1.0));
                },
                child: Container(
                  height: 30, // Zone tactile invisible plus grande pour attraper le doigt facilement
                  alignment: Alignment.bottomCenter,
                  child: ValueListenableBuilder<Duration>(
                    valueListenable: _pos,
                    builder: (_, pos, __) {
                      final pct = _dur.inMilliseconds == 0 ? 0.0 : pos.inMilliseconds / _dur.inMilliseconds;
                      return Stack(
                        alignment: Alignment.bottomLeft,
                        children: [
                          Container(height: _isDragging ? 6 : 3, width: double.infinity, color: Colors.white.withValues(alpha: 0.3)),
                          Container(height: _isDragging ? 6 : 3, width: MediaQuery.of(context).size.width * pct, color: ThixPolicy.primary),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
