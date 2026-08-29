import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class FeedVideoPlayer extends StatefulWidget {
  final String videoUrl, coverUrl;
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

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    if (widget.videoUrl.isEmpty) return;
    
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    try {
      await _controller!.initialize().timeout(const Duration(seconds: 15));
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
      if (widget.isPlaying) _controller!.play();
    } catch (e) {
      debugPrint('[VideoPlayer] Init error: $e');
    }
  }

  void _onTick() {
    if (!mounted || _controller == null) return;
    if (!_isDragging) _pos.value = _controller!.value.position;
    
    if (widget.enforcePreviewLimit &&
        !_previewTriggered &&
        _controller!.value.position.inSeconds >= widget.previewSeconds) {
      _previewTriggered = true;
      _controller!.pause();
      widget.onPreviewLimitReached?.call();
    }
  }

  @override
  void didUpdateWidget(covariant FeedVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // ✅ Dispose et recrée si l'URL change
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
    final newPos = Duration(milliseconds: (_dur.inMilliseconds * pct).round());
    _controller!.seekTo(newPos);
    _pos.value = newPos;
  }

  @override
  Widget build(BuildContext context) {
    if (!_init || _controller == null || !_controller!.value.isInitialized) {
      return _buildPlaceholder();
    }

    return GestureDetector(
      onTap: _handleTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: Colors.black,
            child: Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            ),
          ),
          if (_paused)
            const Center(
              child: Icon(Icons.play_arrow_rounded, color: Colors.white70, size: 80),
            ),
          _buildProgressBar(),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    if (widget.coverUrl.trim().isEmpty) {
      return Container(color: Colors.black);
    }
    return CachedNetworkImage(imageUrl: widget.coverUrl, fit: BoxFit.cover);
  }

  void _handleTap() {
    if (_previewTriggered || _controller == null) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
      _paused = true;
    } else {
      _controller!.play();
      _paused = false;
    }
    setState(() {});
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
          final pct = (d.localPosition.dx / context.size!.width).clamp(0.0, 1.0);
          _pos.value = Duration(milliseconds: (_dur.inMilliseconds * pct).round());
        },
        onHorizontalDragEnd: (_) {
          _isDragging = false;
          _controller?.seekTo(_pos.value);
          if (!_paused) _controller?.play();
        },
        onTapDown: (d) => _seekToPercent((d.localPosition.dx / context.size!.width).clamp(0.0, 1.0)),
        child: Container(
          height: 20,
          color: Colors.transparent,
          alignment: Alignment.bottomCenter,
          child: ValueListenableBuilder<Duration>(
            valueListenable: _pos,
            builder: (_, pos, __) {
              final pct = _dur.inMilliseconds == 0 ? 0.0 : pos.inMilliseconds / _dur.inMilliseconds;
              return Stack(
                alignment: Alignment.bottomLeft,
                children: [
                  Container(height: _isDragging ? 6 : 2, width: double.infinity, color: Colors.white.withOpacity(0.3)),
                  Container(height: _isDragging ? 6 : 2, width: MediaQuery.of(context).size.width * pct, color: Colors.white),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
