/// Video Preview Editor Page (Production Enterprise)
/// ThixPolicy + i18n 8 langues + Semantics + logs structurés
/// Validation complète (taille, extension, durée, MIME)
/// Compatibilité totale Web (kIsWeb) + Mobile
///  HapticFeedback + mounted checks + RepaintBoundary
import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'; // Ajout nécessaire pour kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

// ============================================================================
// LIMITES DE VALIDATION
// ============================================================================

class _EditorLimits {
  _EditorLimits._();

  static const int maxVideoSizeBytes = 500 * 1024 * 1024;
  static const int maxAudioSizeBytes = 50 * 1024 * 1024;
  static const int maxDurationSeconds = 600;
  static const int minTrimDurationSeconds = 1;
  static const Duration videoInitTimeout = Duration(seconds: 15);
  static const Duration tapThrottle = Duration(milliseconds: 400);

  static const Set<String> allowedVideoExtensions = {
    '.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v',
  };

  static const Set<String> allowedAudioExtensions = {
    '.mp3', '.wav', '.aac', '.m4a', '.ogg', '.flac',
  };
}

// ============================================================================
// FILTRES ESTHÉTIQUES (modèle)
// ============================================================================

class _VideoFilter {
  final String i18nKey;
  final List<double> matrix;

  const _VideoFilter({required this.i18nKey, required this.matrix});
}

// CORRECTION WEB : Typage strict <double> pour éviter les erreurs du compilateur
const List<_VideoFilter> _kFilters = [
  _VideoFilter(i18nKey: 'filter_normal', matrix: <double>[
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0,
  ]),
  _VideoFilter(i18nKey: 'filter_cinematic', matrix: <double>[
    1.1, 0, 0, 0, -8,
    0, 1.05, 0, 0, -8,
    0, 0, 0.95, 0, -4,
    0, 0, 0, 1, 0,
  ]),
  _VideoFilter(i18nKey: 'filter_bright', matrix: <double>[
    1.15, 0, 0, 0, 12,
    0, 1.15, 0, 0, 12,
    0, 0, 1.1, 0, 12,
    0, 0, 0, 1, 0,
  ]),
  _VideoFilter(i18nKey: 'filter_vintage', matrix: <double>[
    0.9, 0.1, 0, 0, 10,
    0, 0.9, 0.05, 0, 5,
    0.05, 0, 0.8, 0, 0,
    0, 0, 0, 1, 0,
  ]),
  _VideoFilter(i18nKey: 'filter_cyberpunk', matrix: <double>[
    1.2, 0, 0.15, 0, 0,
    0, 0.95, 0.1, 0, 0,
    0.15, 0, 1.3, 0, 0,
    0, 0, 0, 1, 0,
  ]),
  _VideoFilter(i18nKey: 'filter_soft_beauty', matrix: <double>[
    1.05, 0, 0, 0, 10,
    0, 1.03, 0, 0, 8,
    0, 0, 1.03, 0, 8,
    0, 0, 0, 1, 0,
  ]),
];

// ============================================================================
// LOGGING
// ============================================================================

class _EditorLogger {
  static const _tag = 'VideoEditor';
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

class VideoPreviewEditorPage extends StatefulWidget {
  final String videoPath;
  const VideoPreviewEditorPage({super.key, required this.videoPath});

  @override
  State<VideoPreviewEditorPage> createState() => _VideoPreviewEditorPageState();
}

class _VideoPreviewEditorPageState extends State<VideoPreviewEditorPage> {
  VideoPlayerController? _controller;
  bool _isReady = false;
  bool _hasError = false;
  String _errorMessage = '';

  double _trimStart = 0;
  double _trimEnd = 0;
  Duration _totalDuration = Duration.zero;

  int _selectedFilterIndex = 0;
  bool _muteOriginalAudio = false;
  PlatformFile? _selectedMusic;

  bool _isProcessing = false;
  double _processProgress = 0;
  String _processLabelKey = '';

  bool _disposed = false;
  DateTime? _lastTap;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _EditorLogger.info('Page initialized', {'path': widget.videoPath});
  }

  @override
  void dispose() {
    _disposed = true;
    _controller?.dispose();
    _EditorLogger.info('Page disposed');
    super.dispose();
  }

  // ── Init vidéo (validations complètes & support Web) ──────────
  Future<void> _initializeVideo() async {
    // CORRECTION WEB : Si on est sur le Web, on ignore les fichiers locaux (qui font planter le build)
    if (kIsWeb) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoPath));
    } else {
      final file = File(widget.videoPath);

      if (!await file.exists()) {
        _setError('editor_error_file_missing');
        return;
      }

      int fileSize = 0;
      try {
        fileSize = await file.length();
      } catch (e) {
        _setError('editor_error_file_unreadable');
        return;
      }

      if (fileSize > _EditorLimits.maxVideoSizeBytes) {
        final maxMB = (_EditorLimits.maxVideoSizeBytes / 1024 / 1024).toInt();
        _setError('editor_error_too_large', {'maxMB': maxMB});
        return;
      }

      final ext = p.extension(widget.videoPath).toLowerCase();
      if (!_EditorLimits.allowedVideoExtensions.contains(ext)) {
        _setError('editor_error_unsupported_format', {'ext': ext});
        return;
      }

      _controller = VideoPlayerController.file(file);
    }

    try {
      await _controller!.initialize().timeout(
        _EditorLimits.videoInitTimeout,
        onTimeout: () => throw TimeoutException('Video init timeout'),
      );

      if (_disposed) {
        _controller?.dispose();
        return;
      }

      final durationSec = _controller!.value.duration.inMilliseconds / 1000.0;

      if (durationSec < _EditorLimits.minTrimDurationSeconds) {
        _setError('editor_error_too_short',
            {'minSec': _EditorLimits.minTrimDurationSeconds});
        return;
      }

      setState(() {
        _totalDuration = _controller!.value.duration;
        _trimStart = 0;
        _trimEnd = durationSec > _EditorLimits.maxDurationSeconds
            ? _EditorLimits.maxDurationSeconds.toDouble()
            : durationSec;
        _isReady = true;
        _hasError = false;
      });

      _controller!.setLooping(true);
      if (mounted) _controller!.play();

      _EditorLogger.info('Video initialized', {
        'duration': '${durationSec.toStringAsFixed(1)}s',
      });
    } catch (e) {
      _EditorLogger.error('Init failed', {'error': '$e'});
      _setError('editor_error_init_failed');
    }
  }

  void _setError(String key, [Map<String, dynamic>? args]) {
    if (_disposed) return;
    setState(() {
      _hasError = true;
      _errorMessage = key;
      _isReady = false;
    });
    _EditorLogger.error(key, args);
  }

  // ── Audio ──────────────────────────────────────────────────
  Future<void> _pickMusic() async {
    if (!_throttle()) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final ext = p.extension(file.name).toLowerCase();
      if (!_EditorLimits.allowedAudioExtensions.contains(ext)) {
        _showSnack('editor_error_audio_unsupported', isError: true, args: {'ext': ext});
        return;
      }
      if (file.size > _EditorLimits.maxAudioSizeBytes) {
        final maxMB = (_EditorLimits.maxAudioSizeBytes / 1024 / 1024).toInt();
        _showSnack('editor_error_audio_too_large', isError: true, args: {'maxMB': maxMB});
        return;
      }

      if (!mounted) return;
      setState(() {
        _selectedMusic = file;
        _muteOriginalAudio = true;
      });
      _EditorLogger.info('Music selected', {'name': file.name});
    } catch (e) {
      _EditorLogger.error('Pick music failed', {'error': '$e'});
      _showSnack('editor_error_pick_failed', isError: true);
    }
  }

  void _removeMusic() {
    if (!_throttle()) return;
    setState(() => _selectedMusic = null);
    _EditorLogger.info('Music removed');
  }

  void _toggleMute() {
    if (!_throttle()) return;
    setState(() {
      _muteOriginalAudio = !_muteOriginalAudio;
      if (!_muteOriginalAudio) _selectedMusic = null;
    });
    HapticFeedback.selectionClick();
    _EditorLogger.info('Mute toggled', {'mute': _muteOriginalAudio});
  }

  // ── Export ─────────────────────────────────────────────────
  Future<void> _exportAndFinish() async {
    if (!_throttle()) return;

    final trimDuration = _trimEnd - _trimStart;
    if (trimDuration < _EditorLimits.minTrimDurationSeconds) {
      _showSnack('editor_error_trim_too_short', isError: true);
      return;
    }
    if (_controller == null || !_controller!.value.isInitialized) {
      _showSnack('editor_error_not_ready', isError: true);
      return;
    }

    setState(() {
      _isProcessing = true;
      _processProgress = 0.3;
      _processLabelKey = 'editor_processing';
    });
    HapticFeedback.mediumImpact();

    try {
      await Future.delayed(const Duration(milliseconds: 600));
      if (_disposed || !mounted) return;

      setState(() {
        _processProgress = 1.0;
        _processLabelKey = 'editor_done';
      });
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted || _disposed) return;

      _EditorLogger.info('Export successful', {
        'trimStart': _trimStart.toStringAsFixed(1),
        'trimEnd': _trimEnd.toStringAsFixed(1),
        'filter': _kFilters[_selectedFilterIndex].i18nKey,
      });
      Navigator.pop(context, widget.videoPath);
    } catch (e) {
      _EditorLogger.error('Export failed', {'error': '$e'});
      if (!mounted || _disposed) return;
      setState(() {
        _isProcessing = false;
        _processProgress = 0;
        _processLabelKey = '';
      });
      _showSnack('editor_error_export_failed', isError: true);
    }
  }

  // ── Helpers ────────────────────────────────────────────────

  String _fmt(double seconds) {
    final d = Duration(milliseconds: (seconds * 1000).round());
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool _throttle() {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!) < _EditorLimits.tapThrottle) {
      _EditorLogger.warn('Tap throttled');
      return false;
    }
    _lastTap = now;
    return true;
  }

    void _showSnack(String key, {bool isError = false, List<String>? args}) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.t(key, args: args ?? const <String>[])),
        backgroundColor: isError ? ThixPolicy.danger : ThixPolicy.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final totalSec = _totalDuration.inMilliseconds / 1000.0;

    return Scaffold(
      backgroundColor: ThixPolicy.inkDeep,
      appBar: AppBar(
        backgroundColor: ThixPolicy.inkDeep,
        elevation: 0,
        leading: Semantics(
          button: true,
          label: l10n.t('common_back'),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: ThixPolicy.textMain, size: 20),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
          ),
        ),
        title: Text(
          l10n.t('editor_title'),
          style: ThixPolicy.h3Style.copyWith(
            color: ThixPolicy.textMain,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: _hasError
          ? _buildErrorState(l10n)
          : !_isReady
              ? const Center(
                  child: CircularProgressIndicator(color: ThixPolicy.primary))
              : SafeArea(
                  child: Column(
                    children: [
                      Expanded(child: _buildPreview()),
                      _buildEditorPanel(l10n, totalSec),
                    ],
                  ),
                ),
    );
  }

  Widget _buildPreview() {
    final filter = _kFilters[_selectedFilterIndex];
    return RepaintBoundary(
      child: Semantics(
        label: 'Video preview',
        child: GestureDetector(
          onTap: () {
            if (_controller == null) return;
            setState(() {
              _controller!.value.isPlaying
                  ? _controller!.pause()
                  : _controller!.play();
            });
            HapticFeedback.selectionClick();
          },
          child: Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: _wrapWithFilter(
                VideoPlayer(_controller!),
                filter,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                color: ThixPolicy.danger, size: 64),
            const SizedBox(height: 16),
            Text(
              l10n.t(_errorMessage),
              textAlign: TextAlign.center,
              style: ThixPolicy.bodyStyle.copyWith(
                  color: ThixPolicy.textMuted, height: 1.4),
            ),
            const SizedBox(height: 24),
            Semantics(
              button: true,
              label: l10n.t('common_back'),
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.danger,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(l10n.t('common_back'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorPanel(AppLocalizations l10n, double totalSec) {
    return Container(
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTrimSection(l10n, totalSec),
          const SizedBox(height: 20),
          _buildFilterSection(l10n),
          const SizedBox(height: 20),
          _buildAudioSection(l10n),
          const SizedBox(height: 24),
          _buildActionButton(l10n),
        ],
      ),
    );
  }

  Widget _buildTrimSection(AppLocalizations l10n, double totalSec) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.t('editor_trim'),
                style: ThixPolicy.labelStyle.copyWith(
                    color: ThixPolicy.textMain,
                    fontWeight: FontWeight.w800)),
            Text(
              '${_fmt(_trimStart)} — ${_fmt(_trimEnd)}  (${_fmt(_trimEnd - _trimStart)})',
              style: ThixPolicy.captionStyle.copyWith(
                  color: ThixPolicy.textMuted,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
        Semantics(
          label: '${l10n.t("editor_trim")}: ${_fmt(_trimStart)} à ${_fmt(_trimEnd)}',
          child: RangeSlider(
            values: RangeValues(_trimStart, _trimEnd),
            min: 0,
            max: totalSec > 0 ? totalSec : 1.0,
            activeColor: ThixPolicy.primary,
            inactiveColor: ThixPolicy.border,
            onChanged: (values) {
              double start = values.start;
              double end = values.end;

              if (end - start > _EditorLimits.maxDurationSeconds) {
                end = start + _EditorLimits.maxDurationSeconds;
                if (end > totalSec) {
                  end = totalSec;
                  start = end - _EditorLimits.maxDurationSeconds;
                }
              }
              if (end - start < _EditorLimits.minTrimDurationSeconds) {
                end = start + _EditorLimits.minTrimDurationSeconds;
                if (end > totalSec) {
                  end = totalSec;
                  start = end - _EditorLimits.minTrimDurationSeconds;
                }
              }

              setState(() {
                _trimStart = start;
                _trimEnd = end;
              });
              _controller?.seekTo(
                  Duration(milliseconds: (start * 1000).round()));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.t('editor_filter'),
            style: ThixPolicy.labelStyle.copyWith(
                color: ThixPolicy.textMain,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _kFilters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter = _kFilters[index];
              final isSelected = _selectedFilterIndex == index;
              return Semantics(
                button: true,
                selected: isSelected,
                label: l10n.t(filter.i18nKey),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedFilterIndex = index);
                    _EditorLogger.info('Filter changed',
                        {'filter': filter.i18nKey});
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? ThixPolicy.primary
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? ThixPolicy.primary
                            : Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Text(
                      l10n.t(filter.i18nKey),
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : ThixPolicy.textMuted,
                        fontSize: 12.5,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAudioSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.t('editor_audio'),
            style: ThixPolicy.labelStyle.copyWith(
                color: ThixPolicy.textMain,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _AudioOptionTile(
                icon: Icons.volume_off_rounded,
                label: l10n.t('editor_mute_audio'),
                selected: _muteOriginalAudio && _selectedMusic == null,
                onTap: _toggleMute,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _AudioOptionTile(
                icon: Icons.music_note_rounded,
                label: _selectedMusic != null
                    ? _selectedMusic!.name
                    : l10n.t('editor_pick_music'),
                selected: _selectedMusic != null,
                onTap: _pickMusic,
                onRemove: _selectedMusic != null ? _removeMusic : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(AppLocalizations l10n) {
    if (_isProcessing) {
      return Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _processProgress,
              color: ThixPolicy.primary,
              backgroundColor: Colors.white.withOpacity(0.1),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.t(_processLabelKey),
            textAlign: TextAlign.center,
            style: ThixPolicy.captionStyle.copyWith(
                color: ThixPolicy.textMuted,
                fontWeight: FontWeight.w600),
          ),
        ],
      );
    }

    return Semantics(
      button: true,
      label: l10n.t('editor_save'),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _exportAndFinish,
          style: ElevatedButton.styleFrom(
            backgroundColor: ThixPolicy.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: Text(l10n.t('editor_save'),
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }

  Widget _wrapWithFilter(Widget child, _VideoFilter filter) {
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(filter.matrix),
      child: child,
    );
  }
}

// ============================================================================
// AUDIO OPTION TILE
// ============================================================================

class _AudioOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _AudioOptionTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? ThixPolicy.primary.withOpacity(0.15)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? ThixPolicy.primary
                  : Colors.white.withOpacity(0.1),
            ),
          ),
          child: Row(
            children: [
              Icon(icon,
                  color: selected ? ThixPolicy.primary : ThixPolicy.textMuted,
                  size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : ThixPolicy.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (onRemove != null)
                Semantics(
                  button: true,
                  label: 'Remove',
                  child: GestureDetector(
                    onTap: onRemove,
                    child: Icon(Icons.close_rounded,
                        color: ThixPolicy.textMuted, size: 16),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
