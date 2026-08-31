// lib/presentation/chat/widgets/audio_recorder.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/services/chat/audio_service.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kPulseDuration = Duration(milliseconds: 800);
const Duration _kCancelDelay = Duration(milliseconds: 500);
const double _kDefaultButtonSize = 56.0;
const int _kDefaultMaxDuration = 120; // 2 minutes
const double _kSlideThreshold = -80.0;
const double _kMinSlideOffset = -100.0;
const double _kIconRatio = 0.45;
const double _kBorderWidth = 2.5;
const double _kLoaderSize = 20.0;
const double _kDotSize = 8.0;
const double _kDotBlurRadius = 6.0;
const double _kDotSpreadRadius = 2.0;

// ============================================================================
// AUDIO RECORDER WIDGET
// ============================================================================

/// Widget d'enregistrement audio avec appui long et glissement pour annuler.
///
/// Fonctionnalités :
/// - Appui long pour démarrer l'enregistrement
/// - Relâcher pour arrêter et envoyer
/// - Glisser vers la gauche pour annuler
/// - Animation pulsation pendant l'enregistrement
/// - Minuteur avec formatage HH:MM:SS
///
/// Exemple :
/// ```dart
/// AudioRecorderWidget(
///   audioService: ref.read(audioServiceProvider),
///   onRecordingComplete: (path, duration) => sendMessage(path),
/// )
/// ```
class AudioRecorderWidget extends StatefulWidget {
  /// Service d'audio pour gérer l'enregistrement
  final AudioService audioService;

  /// Callback à la fin de l'enregistrement (chemin fichier + durée)
  final void Function(String filePath, int durationSeconds)? onRecordingComplete;

  /// Callback si l'enregistrement est annulé
  final VoidCallback? onRecordingCanceled;

  /// Callback lors du changement d'état (début/fin enregistrement)
  final void Function(bool isRecording)? onRecordingStateChanged;

  /// Durée maximale en secondes (défaut : 120s)
  final int maxDuration;

  /// Taille du bouton principal en pixels
  final double buttonSize;

  const AudioRecorderWidget({
    super.key,
    required this.audioService,
    this.onRecordingComplete,
    this.onRecordingCanceled,
    this.onRecordingStateChanged,
    this.maxDuration = _kDefaultMaxDuration,
    this.buttonSize = _kDefaultButtonSize,
  }) : assert(maxDuration > 0, 'maxDuration must be positive');

  @override
  State<AudioRecorderWidget> createState() => _AudioRecorderWidgetState();
}

class _AudioRecorderWidgetState extends State<AudioRecorderWidget> with TickerProviderStateMixin {
  bool _isRecording = false;
  bool _isUploading = false;
  int _currentDuration = 0;
  Timer? _timer;
  double _slideOffset = 0.0;
  bool _isCanceling = false;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: _kPulseDuration,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (_isRecording || _isUploading) return;

    debugPrint('[Recorder] 🎤 Starting recording...');
    HapticFeedback.mediumImpact();

    try {
      await widget.audioService.startRecording();
      
      if (!mounted) return;
      
      setState(() {
        _isRecording = true;
        _currentDuration = 0;
        _slideOffset = 0.0;
        _isCanceling = false;
      });
      
      widget.onRecordingStateChanged?.call(true);

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        
        setState(() => _currentDuration++);
        
        if (_currentDuration >= widget.maxDuration) {
          debugPrint('[Recorder] ⏱️ Max duration reached');
          _completeRecording();
        }
      });
    } catch (e) {
      debugPrint('[Recorder] ❌ Start error: $e');
      // Feedback utilisateur optionnel ici si nécessaire
      if (mounted) {
        // Optionnel : montrer un SnackBar d'erreur
      }
    }
  }

  Future<void> _completeRecording() async {
    if (!_isRecording) return;
    
    debugPrint('[Recorder] ⏹️ Completing recording...');
    HapticFeedback.lightImpact();
    
    _timer?.cancel();
    _timer = null;
    
    setState(() {
      _isRecording = false;
      _isUploading = true;
    });
    
    widget.onRecordingStateChanged?.call(false);

    try {
      final filePath = await widget.audioService.stopRecording();
      
      if (!mounted) return;

      if (filePath != null) {
        debugPrint('[Recorder] ✓ Recording saved: $filePath (${_currentDuration}s)');
        widget.onRecordingComplete?.call(filePath, widget.audioService.currentRecordingDuration);
      } else {
        debugPrint('[Recorder] ⚠️ Recording returned null path');
        setState(() => _isUploading = false);
        widget.onRecordingCanceled?.call();
      }
    } catch (e) {
      debugPrint('[Recorder] ❌ Stop error: $e');
      if (mounted) {
        setState(() => _isUploading = false);
        widget.onRecordingCanceled?.call();
      }
    }
  }

  Future<void> _cancelRecording() async {
    if (!_isRecording) return;
    
    debugPrint('[Recorder] 🚫 Canceling recording...');
    HapticFeedback.selectionClick();
    
    _timer?.cancel();
    _timer = null;
    
    setState(() {
      _isRecording = false;
      _isCanceling = true;
    });
    
    widget.onRecordingStateChanged?.call(false);
    
    try {
      await widget.audioService.cancelRecording();
    } catch (e) {
      debugPrint('[Recorder] ❌ Cancel error: $e');
    }
    
    widget.onRecordingCanceled?.call();
    
    // Délai avant de réinitialiser l'état visuel
    await Future.delayed(_kCancelDelay);
    if (mounted) {
      setState(() => _isCanceling = false);
    }
  }

  String _fmt(int s, AppLocalizations l10n) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primary = ThixPolicy.primary;
    final danger = ThixPolicy.danger;
    final surface = ThixPolicy.card;
    final border = ThixPolicy.border;
    final textMain = ThixPolicy.textMain;
    final textMuted = ThixPolicy.textMuted;

    if (_isCanceling) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Indicateur d'enregistrement ──
            if (_isRecording || _isUploading)
              Semantics(
                label: _isUploading 
                    ? l10n.t('recorder_uploading') 
                    : '${l10n.t('recorder_recording')} ${_fmt(_currentDuration, l10n)}',
                liveRegion: true,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: border),
                    boxShadow: ThixPolicy.shadowSoft(opacity: 0.06),
                  ),
                  child: Row(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (_, __) => Container(
                          width: _kDotSize,
                          height: _kDotSize,
                          decoration: BoxDecoration(
                            color: danger,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: danger.withOpacity(0.4 * _pulseAnimation.value),
                                blurRadius: _kDotBlurRadius,
                                spreadRadius: _kDotSpreadRadius,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _fmt(_currentDuration, l10n),
                        style: TextStyle(
                          color: textMain,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_isRecording)
                        Semantics(
                          button: true,
                          label: l10n.t('recorder_cancel'),
                          child: GestureDetector(
                            onTap: _cancelRecording,
                            child: Icon(Icons.close_rounded, color: textMuted, size: 18),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            
            // ── Bouton principal (Appui long / Glissement) ──
            if (!_isUploading)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: GestureDetector(
                  onLongPress: _startRecording,
                  onLongPressUp: _completeRecording,
                  onPanUpdate: (d) {
                    if (_isRecording) {
                      setState(() => _slideOffset = (d.delta.dx + _slideOffset).clamp(_kMinSlideOffset, 0.0));
                      if (_slideOffset <= _kSlideThreshold) {
                        _cancelRecording();
                      }
                    }
                  },
                  onPanEnd: (_) {
                    if (mounted && _isRecording) {
                      setState(() => _slideOffset = 0.0);
                    }
                  },
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (_, __) {
                      final active = _isRecording;
                      final scale = active ? _pulseAnimation.value : 1.0;
                      final color = active ? danger : primary;
                      
                      return Transform.scale(
                        scale: scale,
                        child: Semantics(
                          button: true,
                          label: active 
                              ? l10n.t('recorder_release_to_send') 
                              : l10n.t('recorder_hold_to_record'),
                          child: Container(
                            width: widget.buttonSize,
                            height: widget.buttonSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color.withOpacity(0.1),
                              border: Border.all(color: color, width: _kBorderWidth),
                            ),
                            child: Icon(
                              active ? Icons.mic_rounded : Icons.mic_none_rounded,
                              color: color,
                              size: widget.buttonSize * _kIconRatio,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            
            // ── Indicateur de chargement ──
            if (_isUploading)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Semantics(
                  label: l10n.t('recorder_uploading'),
                  child: SizedBox(
                    width: _kLoaderSize,
                    height: _kLoaderSize,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: primary,
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
