import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../utils/create_post_constants.dart';

class VideoPreviewWidget extends StatefulWidget {
  final PlatformFile? selectedVideo;
  final bool isSeries;
  final VoidCallback onPickVideo;
  final VoidCallback onOpenCamera;

  const VideoPreviewWidget({
    super.key,
    required this.selectedVideo,
    required this.isSeries,
    required this.onPickVideo,
    required this.onOpenCamera,
  });

  @override
  State<VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<VideoPreviewWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  @override
  void didUpdateWidget(VideoPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedVideo != oldWidget.selectedVideo) {
      _disposeController();
      _initializeVideoPlayer();
    }
  }

  Future<void> _initializeVideoPlayer() async {
    if (widget.selectedVideo == null) return;

    if (kIsWeb) {
      if (widget.selectedVideo!.bytes != null) {
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.selectedVideo!.path ?? ''),
        );
      }
    } else {
      if (widget.selectedVideo!.path != null) {
        _controller = VideoPlayerController.file(File(widget.selectedVideo!.path!));
      }
    }

    if (_controller != null) {
      try {
        await _controller!.initialize().timeout(const Duration(seconds: 15));
        _controller!.setLooping(true);
        _controller!.play();
        if (mounted) setState(() => _isInitialized = true);
      } catch (e) {
        debugPrint('[VideoPreview] Init error: $e');
        if (mounted) setState(() => _isInitialized = false);
      }
    }
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: CreatePostColors.cardLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: _isInitialized && _controller != null
          ? _buildVideoPlayer()
          : _buildPlaceholder(),
    );
  }

  Widget _buildVideoPlayer() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          ),
          Center(
            child: GestureDetector(
              onTap: () => setState(() {
                _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
              }),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _controller!.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
          if (widget.isSeries)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: CreatePostColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Partie 1',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.05),
          ),
          child: const Icon(Icons.movie_creation_outlined, color: Colors.white54, size: 36),
        ),
        const SizedBox(height: 16),
        Text(
          widget.isSeries ? 'Aucune vidéo pour la Partie 1' : 'Sélectionnez une vidéo',
          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: widget.onPickVideo,
              icon: const Icon(Icons.folder_outlined, size: 18),
              label: const Text('Importer', style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: widget.onOpenCamera,
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text('Caméra', style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: CreatePostColors.navyDeep,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
