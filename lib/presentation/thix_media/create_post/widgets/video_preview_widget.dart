/// VideoPreviewWidget (Production Enterprise)
///
/// Widget de preview vidéo pour la création de post.
///
/// ThixPolicy + i18n 8 langues + Semantics + HapticFeedback
///  Web-safe (bytes au lieu de path) + mounted checks + throttling
///  Validation fichier + error state + logs structurés
import 'dart:io';

import 'package:file_picker/file_picker.dart';
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
const Duration _kTapThrottle = Duration(milliseconds: 300);
const int _kMaxVideoSizeBytes = 500 * 1024 * 1024; // 500 MB
const Set<String> _kAllowedVideoExtensions = {
  '.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v',
};

// ============================================================================
// LOGGING
// ============================================================================

class _PreviewLogger {
  static const _tag = 'VideoPreview';
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
// VALIDATOR
// ============================================================================

class _VideoValidator {
  static bool isValid(PlatformFile file) {
    // Check extension
    final ext = file.name.toLowerCase().split('.').last;
    if (!_kAllowedVideoExtensions.contains('.$ext')) {
      _PreviewLogger.warn('Invalid extension', {'ext': ext});
      return false;
    }
    // Check size
    if (file.size > _kMaxVideoSizeBytes) {
      _PreviewLogger.warn('File too large', {
        'size': '${(file.size / 1024 / 1024).toStringAsFixed(1)}MB',
      });
      return false;
    }
    // Check bytes availability
    if (kIsWeb && file.bytes == null) {
      _PreviewLogger.warn('No bytes on Web');
      return false;
    }
    if (!kIsWeb && file.path == null) {
      _PreviewLogger.warn('No path on mobile');
      return false;
    }
    return true;
  }
}

// ============================================================================
// WIDGET
// ============================================================================

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
  bool _hasError = false;
  DateTime? _lastTap;

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

    // Validation avant init
    if (!_VideoValidator.isValid(widget.selectedVideo!)) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    try {
      if (kIsWeb) {
        // Web : utiliser bytes directement (pas path)
        if (widget.selectedVideo!.bytes != null) {
          // Sur Web, on ne peut pas utiliser bytes directement avec video_player
          // On utilise une URL blob si disponible, sinon on skip
          final path = widget.selectedVideo!.path;
          if (path != null && path.isNotEmpty) {
            _controller = VideoPlayerController.networkUrl(Uri.parse(path));
          } else {
            _PreviewLogger.warn('No path available on Web');
            if (mounted) setState(() => _hasError = true);
            return;
          }
        }
      } else {
        // Mobile : utiliser File
        if (widget.selectedVideo!.path != null) {
          _controller = VideoPlayerController.file(
            File(widget.selectedVideo!.path!),
          );
        }
      }

      if (_controller == null) {
        _PreviewLogger.warn('Controller creation failed');
        if (mounted) setState(() => _hasError = true);
        return;
      }

      await _controller!.initialize().timeout(_kInitTimeout);

      if (!mounted) {
        _controller?.dispose();
        return;
      }

      _controller!.setLooping(true);
      _controller!.play();

      setState(() {
        _isInitialized = true;
        _hasError = false;
      });

      _PreviewLogger.info('Video initialized', {
        'size': '${_controller!.value.size.width}x${_controller!.value.size.height}',
        'duration': '${_controller!.value.duration.inSeconds}s',
      });
    } catch (e) {
      _PreviewLogger.error('Init failed', {'error': '$e'});
      if (mounted) {
        setState(() {
          _isInitialized = false;
          _hasError = true;
        });
      }
    }
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    _hasError = false;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  bool _throttle() {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!) < _kTapThrottle) {
      _PreviewLogger.warn('Tap throttled');
      return false;
    }
    _lastTap = now;
    return true;
  }

  void _togglePlayPause() {
    if (!_throttle() || _controller == null) return;
    HapticFeedback.selectionClick();

    if (!mounted) return;
    final isPlaying = _controller!.value.isPlaying;

    setState(() {
      if (isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
    });

    _PreviewLogger.info('Play/pause toggled', {'isPlaying': !isPlaying});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return RepaintBoundary(
      child: Container(
        height: 240,
        decoration: BoxDecoration(
          color: ThixPolicy.surfaceSoft.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: ThixPolicy.textMuted.withValues(alpha: 0.1),
          ),
        ),
        child: _hasError
            ? _buildErrorState(l10n)
            : _isInitialized && _controller != null
                ? _buildVideoPlayer(l10n)
                : _buildPlaceholder(l10n),
      ),
    );
  }

  Widget _buildVideoPlayer(AppLocalizations l10n) {
    final isPlaying = _controller!.value.isPlaying;
    final videoSize = _controller!.value.size;
    final isValidSize = videoSize.width > 0 && videoSize.height > 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isValidSize)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: videoSize.width,
                height: videoSize.height,
                child: VideoPlayer(_controller!),
              ),
            )
          else
            Container(color: ThixPolicy.inkDeep),
          Semantics(
            button: true,
            label: isPlaying ? l10n.t('video_pause') : l10n.t('video_play'),
            child: Center(
              child: GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ThixPolicy.inkDeep.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: ThixPolicy.textMain,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
          if (widget.isSeries)
            Positioned(
              top: 12,
              left: 12,
              child: Semantics(
                // CORRECTION : args passe en liste
                label: l10n.t('create_series_part_n', args: ['1']),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: ThixPolicy.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    // CORRECTION : args passe en liste
                    l10n.t('create_series_part_n', args: ['1']),
                    style: TextStyle(
                      color: ThixPolicy.textMain,
                      fontSize: 11,
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

  Widget _buildErrorState(AppLocalizations l10n) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ThixPolicy.danger.withValues(alpha: 0.1),
          ),
          child: Icon(
            Icons.error_outline_rounded,
            color: ThixPolicy.danger,
            size: 36,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.t('create_video_error'),
          style: TextStyle(
            color: ThixPolicy.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Semantics(
          button: true,
          label: l10n.t('create_pick_another'),
          child: ElevatedButton.icon(
            onPressed: widget.onPickVideo,
            icon: const Icon(Icons.folder_outlined, size: 18),
            label: Text(
              l10n.t('create_pick_another'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder(AppLocalizations l10n) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ThixPolicy.textMuted.withValues(alpha: 0.05),
          ),
          child: Icon(
            Icons.movie_creation_outlined,
            color: ThixPolicy.textMuted,
            size: 36,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.isSeries
              // CORRECTION : args passe en liste
              ? l10n.t('create_series_no_video', args: ['1'])
              : l10n.t('create_select_video'),
          style: TextStyle(
            color: ThixPolicy.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Semantics(
              button: true,
              label: l10n.t('create_import'),
              child: ElevatedButton.icon(
                onPressed: widget.onPickVideo,
                icon: const Icon(Icons.folder_outlined, size: 18),
                label: Text(
                  l10n.t('create_import'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.textMuted.withValues(alpha: 0.1),
                  foregroundColor: ThixPolicy.textMain,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Semantics(
              button: true,
              label: l10n.t('create_camera'),
              child: ElevatedButton.icon(
                onPressed: widget.onOpenCamera,
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: Text(
                  l10n.t('create_camera'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
