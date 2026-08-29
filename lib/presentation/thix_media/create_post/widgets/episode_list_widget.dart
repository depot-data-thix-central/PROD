import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../utils/create_post_constants.dart';
import '../utils/validators.dart';

class EpisodeListWidget extends StatefulWidget {
  final List<PlatformFile> episodes;
  final PlatformFile? mainVideo;
  final VoidCallback onPickEpisodes;
  final ValueChanged<int> onRemoveEpisode;

  const EpisodeListWidget({
    super.key,
    required this.episodes,
    required this.mainVideo,
    required this.onPickEpisodes,
    required this.onRemoveEpisode,
  });

  @override
  State<EpisodeListWidget> createState() => _EpisodeListWidgetState();
}

class _EpisodeListWidgetState extends State<EpisodeListWidget> {
  final Map<int, VideoPlayerController> _controllers = {};
  final Set<int> _initializedEpisodes = {};

  @override
  void initState() {
    super.initState();
    // ✅ Lazy loading : n'initialise que le premier épisode visible
    if (widget.episodes.isNotEmpty) {
      _initEpisodeController(0);
    }
  }

  @override
  void didUpdateWidget(EpisodeListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.episodes.length != oldWidget.episodes.length) {
      _cleanupControllers();
    }
  }

  void _cleanupControllers() {
    // Dispose les controllers pour les épisodes supprimés
    final currentIndices = List.generate(widget.episodes.length, (i) => i).toSet();
    final toRemove = _controllers.keys.where((i) => !currentIndices.contains(i)).toList();
    for (var index in toRemove) {
      _controllers[index]?.dispose();
      _controllers.remove(index);
      _initializedEpisodes.remove(index);
    }
  }

  Future<void> _initEpisodeController(int index) async {
    if (index >= widget.episodes.length) return;
    if (_controllers.containsKey(index)) return;

    final file = widget.episodes[index];
    if (file.path == null) return;

    final controller = VideoPlayerController.file(File(file.path!));
    _controllers[index] = controller;

    try {
      await controller.initialize().timeout(const Duration(seconds: 10));
      if (mounted) {
        setState(() => _initializedEpisodes.add(index));
      }
    } catch (e) {
      debugPrint('[Episode $index] Init error: $e');
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalParts = widget.episodes.length + (widget.mainVideo != null ? 1 : 0);
    final canAddMore = widget.episodes.length < CreatePostValidators.maxEpisodes;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Épisodes additionnels',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
              ),
              Text(
                '$totalParts partie(s)',
                style: const TextStyle(
                  color: CreatePostColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'La vidéo importée ci-dessus est la Partie 1. Ajoutez les autres épisodes ci-dessous.',
            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),

          if (widget.episodes.isNotEmpty)
            Column(
              children: List.generate(widget.episodes.length, (i) => _buildEpisodeCard(i)),
            ),

          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: canAddMore ? widget.onPickEpisodes : null,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(
                canAddMore ? 'Ajouter une partie' : 'Maximum atteint',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeCard(int index) {
    final ep = widget.episodes[index];
    final controller = _controllers[index];
    final isInitialized = _initializedEpisodes.contains(index);

    // ✅ Lazy load quand l'épisode devient visible
    if (!isInitialized && index < 3) {
      _initEpisodeController(index);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 2}',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Partie ${index + 2}',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ep.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => widget.onRemoveEpisode(index),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 140,
              width: double.infinity,
              color: Colors.black,
              child: isInitialized && controller != null
                  ? _buildEpisodePreview(controller)
                  : const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodePreview(VideoPlayerController controller) {
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
        Center(
          child: GestureDetector(
            onTap: () => setState(() {
              controller.value.isPlaying ? controller.pause() : controller.play();
            }),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
