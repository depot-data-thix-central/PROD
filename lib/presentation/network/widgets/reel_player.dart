// lib/presentation/network/widgets/reel_player.dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ReelPlayer extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final String? caption;
  final int likesCount;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;

  const ReelPlayer({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
    this.caption,
    required this.likesCount,
    required this.isLiked,
    required this.onLike,
    required this.onComment,
    required this.onShare,
  });

  @override
  State<ReelPlayer> createState() => _ReelPlayerState();
}

class _ReelPlayerState extends State<ReelPlayer> {
  late VideoPlayerController _controller;
  bool _isPlaying = true;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _isPlaying = false;
      } else {
        _controller.play();
        _isPlaying = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Vidéo
        Center(
          child: _controller.value.isInitialized
              ? AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                )
              : Container(color: Colors.black),
        ),
        
        // Overlay
        Positioned.fill(
          child: GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              color: Colors.transparent,
              child: Center(
                child: _isPlaying
                    ? const SizedBox.shrink()
                    : Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow, size: 40, color: Colors.white),
                      ),
              ),
            ),
          ),
        ),
        
        // Actions latérales
        Positioned(
          bottom: 80,
          right: 16,
          child: Column(
            children: [
              _actionButton(
                icon: widget.isLiked ? Icons.favorite : Icons.favorite_border,
                color: widget.isLiked ? Colors.red : Colors.white,
                count: widget.likesCount,
                onTap: widget.onLike,
              ),
              const SizedBox(height: 20),
              _actionButton(
                icon: Icons.comment_outlined,
                count: 0,
                onTap: widget.onComment,
              ),
              const SizedBox(height: 20),
              _actionButton(
                icon: Icons.share_outlined,
                onTap: widget.onShare,
              ),
            ],
          ),
        ),
        
        // Caption
        if (widget.caption != null)
          Positioned(
            bottom: 20,
            left: 16,
            right: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.caption!,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        
        // Indicateur son
        Positioned(
          top: 60,
          right: 16,
          child: GestureDetector(
            onTap: () => setState(() => _isMuted = !_isMuted),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isMuted ? Icons.volume_off : Icons.volume_up,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    int? count,
    Color? color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color ?? Colors.white, size: 24),
          ),
          if (count != null && count > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _formatCount(count),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }
}
