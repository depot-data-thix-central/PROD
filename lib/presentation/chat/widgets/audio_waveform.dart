// lib/presentation/chat/widgets/audio_waveform.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_audio_waveforms/flutter_audio_waveforms.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kLoadTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const int _kMaxRetries = 1;
const double _kDefaultHeight = 48.0;
const double _kDefaultMiniHeight = 24.0;
const int _kDefaultBarCount = 40;
const int _kDefaultMiniBarCount = 20;
const double _kLoaderSize = 18.0;
const double _kBarWidth = 3.0;
const double _kBarSpacing = 1.5;
const double _kBarRadius = 2.0;
const double _kMinBarHeight = 2.0;
const double _kSeekLineWidth = 2.0;
const double _kScaleFactor = 0.8;

// ============================================================================
// VALIDATORS
// ============================================================================
class _WaveformValidators {
  _WaveformValidators._();

  /// Valide et sanitise une URL audio (http/https uniquement)
  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final t = url.trim();
    if (!t.startsWith('http://') && !t.startsWith('https://')) return null;
    return t.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  /// Clampe le progress entre 0 et 1
  static double clampProgress(double progress) {
    if (progress.isNaN || progress.isInfinite) return 0.0;
    return progress.clamp(0.0, 1.0);
  }

  /// Valide le nombre de barres (doit être > 0)
  static int validateBarCount(int barCount, int fallback) {
    if (barCount <= 0) return fallback;
    return barCount;
  }

  /// Valide les données de waveform (pas de NaN, valeurs [0,1])
  static List<double> sanitizeWaveformData(List<double>? data) {
    if (data == null || data.isEmpty) return [];
    return data
        .map((v) {
          if (v.isNaN || v.isInfinite) return 0.0;
          return v.clamp(0.0, 1.0);
        })
        .toList();
  }

  static String friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('not found')) return 'Fichier audio introuvable.';
    if (msg.contains('format') || msg.contains('decode')) return 'Format audio non supporté.';
    return 'Une erreur est survenue. Réessayez.';
  }
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _waveformRetry<T>(
  Future<T> Function() fn, {
  required String label,
  int maxRetries = _kMaxRetries,
  Duration timeout = _kLoadTimeout,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(timeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[Waveform] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[Waveform] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[Waveform] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// AUDIO WAVEFORM WIDGET
// ============================================================================

/// Widget qui affiche une waveform audio interactive avec lecture.
///
/// Supporte :
/// - URL distante (http/https) ou fichier local
/// - Chargement avec timeout + retry
/// - Lecture, pause, stop, seek
///
/// Exemple :
/// ```dart
/// AudioWaveformWidget(
///   audioUrl: message.mediaUrl,
///   onPlay: () => HapticFeedback.mediumImpact(),
/// )
/// ```
class AudioWaveformWidget extends StatefulWidget {
  /// URL de l'audio (http/https uniquement)
  final String? audioUrl;

  /// Chemin du fichier local (alternative à audioUrl)
  final String? filePath;

  /// Couleur de la waveform (non jouée)
  final Color waveformColor;

  /// Couleur de la progression (jouée)
  final Color progressColor;

  /// Hauteur du widget
  final double height;

  /// Largeur du widget
  final double width;

  /// Nombre de barres de la waveform
  final int numberOfBars;

  /// Progression initiale [0, 1]
  final double progress;

  const AudioWaveformWidget({
    super.key,
    this.audioUrl,
    this.filePath,
    this.waveformColor = ThixPolicy.primary,
    this.progressColor = ThixPolicy.primary,
    this.height = _kDefaultHeight,
    this.width = double.infinity,
    this.numberOfBars = _kDefaultBarCount,
    this.progress = 0.0,
  }) : assert(
          audioUrl != null || filePath != null,
          'audioUrl or filePath must be provided',
        );

  @override
  State<AudioWaveformWidget> createState() => _AudioWaveformWidgetState();
}

class _AudioWaveformWidgetState extends State<AudioWaveformWidget> {
  final PlayerController _controller = PlayerController();
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    final safeUrl = _WaveformValidators.sanitizeUrl(widget.audioUrl);
    final safeBars = _WaveformValidators.validateBarCount(
      widget.numberOfBars,
      _kDefaultBarCount,
    );

    debugPrint('[Waveform] 🎵 Loading waveform (bars: $safeBars)');

    try {
      if (safeUrl != null) {
        await _waveformRetry(
          () => _controller.preparePlayer(safeUrl, noOfSamples: safeBars),
          label: 'preparePlayer[url]',
        );
      } else if (widget.filePath != null) {
        await _waveformRetry(
          () => _controller.preparePlayerFromFile(
            widget.filePath!,
            noOfSamples: safeBars,
          ),
          label: 'preparePlayer[file]',
        );
      }

      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint('[Waveform] ✓ Waveform loaded');
      }
    } catch (e) {
      debugPrint('[Waveform] ❌ Load error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = _WaveformValidators.friendlyError(e);
        });
      }
    }
  }

  // ── API publique ──

  Future<void> play() async {
    HapticFeedback.mediumImpact();
    debugPrint('[Waveform] ▶️ play()');
    try {
      await _controller.startPlayer();
    } catch (e) {
      debugPrint('[Waveform] ❌ play error: $e');
    }
  }

  Future<void> pause() async {
    debugPrint('[Waveform] ⏸️ pause()');
    try {
      await _controller.pausePlayer();
    } catch (e) {
      debugPrint('[Waveform] ❌ pause error: $e');
    }
  }

  Future<void> stop() async {
    debugPrint('[Waveform] ⏹️ stop()');
    try {
      await _controller.stopPlayer();
    } catch (e) {
      debugPrint('[Waveform] ❌ stop error: $e');
    }
  }

  Future<void> seekTo(double progress) async {
    final safeProgress = _WaveformValidators.clampProgress(progress);
    debugPrint('[Waveform] ⏩ seekTo(${safeProgress.toStringAsFixed(2)})');
    try {
      final d = await _controller.getDuration();
      if (d != null) {
        await _controller.seekTo(
          Duration(
            milliseconds: (d.inMilliseconds * safeProgress).round(),
          ),
        );
      }
    } catch (e) {
      debugPrint('[Waveform] ❌ seekTo error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_isLoading) {
      return RepaintBoundary(
        child: SizedBox(
          height: widget.height,
          child: Center(
            child: SizedBox(
              width: _kLoaderSize,
              height: _kLoaderSize,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ThixPolicy.primary,
              ),
            ),
          ),
        ),
      );
    }

    if (_hasError) {
      return RepaintBoundary(
        child: SizedBox(
          height: widget.height,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 14,
                  color: ThixPolicy.danger,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _errorMessage ?? l10n.t('waveform_error'),
                    style: ThixPolicy.captionStyle.copyWith(
                      fontSize: 10,
                      color: ThixPolicy.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Semantics(
                  button: true,
                  label: l10n.t('waveform_retry'),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _load();
                    },
                    child: Icon(
                      Icons.refresh_rounded,
                      size: 14,
                      color: ThixPolicy.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: SizedBox(
        height: widget.height,
        width: widget.width,
        child: AudioFileWaveforms(
          controller: _controller,
          size: Size(widget.width, widget.height),
          playerWaveStyle: PlayerWaveStyle(
            fixedWaveColor: widget.waveformColor.withOpacity(0.2),
            liveWaveColor: widget.progressColor,
            scaleFactor: _kScaleFactor,
            showSeekLine: true,
            seekLineColor: ThixPolicy.primary,
            seekLineWidth: _kSeekLineWidth,
            showDurationLabel: false,
          ),
          enableScrolling: false,
          onCurrentPosition: (_) {},
        ),
      ),
    );
  }
}

// ============================================================================
// MINI AUDIO WAVEFORM
// ============================================================================

/// Waveform statique miniature (sans lecture).
///
/// Affiche les barres de waveform avec progression colorée.
/// Utilisée dans les bulles de messages audio.
class MiniAudioWaveform extends StatelessWidget {
  /// Données de waveform (valeurs [0, 1])
  final List<double>? waveformData;

  /// Progression [0, 1]
  final double progress;

  /// Couleur des barres
  final Color color;

  /// Hauteur du widget
  final double height;

  /// Nombre de barres affichées
  final int barCount;

  const MiniAudioWaveform({
    super.key,
    required this.waveformData,
    required this.progress,
    required this.color,
    this.height = _kDefaultMiniHeight,
    this.barCount = _kDefaultMiniBarCount,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final safeData = _WaveformValidators.sanitizeWaveformData(waveformData);
    final safeProgress = _WaveformValidators.clampProgress(progress);
    final safeBars = _WaveformValidators.validateBarCount(
      barCount,
      _kDefaultMiniBarCount,
    );

    // Fallback si pas de données
    if (safeData.isEmpty) {
      return RepaintBoundary(
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: ThixPolicy.surfaceSoft,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ThixPolicy.border),
          ),
          child: Center(
            child: Text(
              l10n.t('waveform_audio'),
              style: ThixPolicy.captionStyle.copyWith(
                fontSize: 11,
                color: ThixPolicy.textMuted,
              ),
            ),
          ),
        ),
      );
    }

    final progressIndex = (safeData.length * safeProgress).floor();

    return RepaintBoundary(
      child: Semantics(
        label: l10n.t('waveform_audio'),
        child: SizedBox(
          height: height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(safeBars, (i) {
              final v = safeData[i % safeData.length];
              final h = (v * height).clamp(_kMinBarHeight, height);
              final isPlayed = i <= progressIndex;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: _kBarSpacing),
                child: Container(
                  width: _kBarWidth,
                  height: h,
                  decoration: BoxDecoration(
                    color: isPlayed ? color : color.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(_kBarRadius),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
