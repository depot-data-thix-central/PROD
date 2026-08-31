// lib/presentation/chat/widgets/audio_player.dart
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kLoadTimeout = Duration(seconds: 30);
const double _kButtonSize = 36.0;
const double _kLoaderSize = 18.0;
const double _kTrackHeight = 3.0;
const double _kThumbRadius = 6.0;
const double _kOverlayRadius = 12.0;
const double _kFontSizeTime = 10.0;
const double _kFontSizeRate = 10.0;
const List<double> _kPlaybackRates = [1.0, 1.5, 2.0];

// ============================================================================
// VALIDATORS
// ============================================================================
class _PlayerValidators {
  _PlayerValidators._();

  /// Valide et sanitise une URL audio (http/https uniquement)
  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final t = url.trim();
    if (!t.startsWith('http://') && !t.startsWith('https://')) return null;
    return t.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  static String friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('not found')) return 'Fichier audio introuvable.';
    if (msg.contains('format') || msg.contains('decode')) return 'Format audio non supporté.';
    return 'Une erreur est survenue lors du chargement.';
  }
}

// ============================================================================
// AUDIO PLAYER WIDGET
// ============================================================================

/// Lecteur audio compact avec contrôles de lecture, progression et vitesse.
///
/// Supporte :
/// - Lecture/Pause
/// - Seek (glisser sur la barre)
/// - Changement de vitesse (1x, 1.5x, 2x)
/// - Callbacks pour événements (play, complete, progress)
///
/// Exemple :
/// ```dart
/// AudioPlayerWidget(
///   audioUrl: message.mediaUrl,
///   onComplete: () => HapticFeedback.mediumImpact(),
/// )
/// ```
class AudioPlayerWidget extends StatefulWidget {
  /// URL de l'audio (http/https uniquement)
  final String audioUrl;

  /// Durée totale en secondes (optionnel, utilisé comme fallback)
  final int? totalDuration;

  /// Couleur principale (bouton, track active)
  final Color? primaryColor;

  /// Couleur d'accentuation (optionnel)
  final Color? accentColor;

  /// Callback au démarrage de la lecture
  final VoidCallback? onPlay;

  /// Callback à la fin de la lecture
  final VoidCallback? onComplete;

  /// Callback lors du changement de progression (0.0 à 1.0)
  final void Function(double progress)? onProgressChanged;

  const AudioPlayerWidget({
    super.key,
    required this.audioUrl,
    this.totalDuration,
    this.primaryColor,
    this.accentColor,
    this.onPlay,
    this.onComplete,
    this.onProgressChanged,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _player;
  bool _isPlaying = false;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _playbackRate = 1.0;
  StreamSubscription? _posSub, _durSub, _stateSub;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _init();
    
    // Subscriptions aux événements
    _posSub = _player.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
      widget.onProgressChanged?.call(_getProgress());
    });

    _durSub = _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() => _isPlaying = s == PlayerState.playing);
      
      if (s == PlayerState.completed) {
        debugPrint('[AudioPlayer] ⏹️ Completed');
        widget.onComplete?.call();
        _player.seek(Duration.zero);
        setState(() => _position = Duration.zero);
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }

  double _getProgress() {
    if (_duration.inMilliseconds <= 0) return 0.0;
    return (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
  }

  Future<void> _init() async {
    final safeUrl = _PlayerValidators.sanitizeUrl(widget.audioUrl);
    if (safeUrl == null) {
      debugPrint('[AudioPlayer]  Invalid URL provided');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'URL invalide';
      });
      return;
    }

    debugPrint('[AudioPlayer] 🎵 Initializing player for: ${safeUrl.substring(0, safeUrl.length > 40 ? 40 : safeUrl.length)}...');

    try {
      await _player.setSourceUrl(safeUrl).timeout(_kLoadTimeout);
      final d = await _player.getDuration();
      if (d != null) {
        setState(() => _duration = d);
        debugPrint('[AudioPlayer] ✓ Duration loaded: ${_duration.inSeconds}s');
      } else if (widget.totalDuration != null) {
        setState(() => _duration = Duration(seconds: widget.totalDuration!));
      }
    } catch (e) {
      debugPrint('[AudioPlayer] ❌ Init error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = _PlayerValidators.friendlyError(e);
        });
      }
    } finally {
      if (mounted && !_hasError) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggle() async {
    if (_isLoading || _hasError) return;
    
    HapticFeedback.mediumImpact();
    
    if (_isPlaying) {
      debugPrint('[AudioPlayer] ⏸️ Pausing');
      await _player.pause();
    } else {
      // Si à la fin, revenir au début
      if (_position >= _duration && _duration.inMilliseconds > 0) {
        await _player.seek(Duration.zero);
      }
      debugPrint('[AudioPlayer] ▶️ Resuming');
      await _player.resume();
      widget.onPlay?.call();
    }
  }

  void _cycleRate() async {
    HapticFeedback.selectionClick();
    final i = _kPlaybackRates.indexOf(_playbackRate);
    final n = _kPlaybackRates[(i + 1) % _kPlaybackRates.length];
    
    debugPrint('[AudioPlayer] ⏩ Changing rate: ${_playbackRate}x → ${n}x');
    
    setState(() => _playbackRate = n);
    await _player.setPlaybackRate(n);
  }

  void _seek(double p) {
    if (_duration.inMilliseconds <= 0) return;
    final safeP = p.clamp(0.0, 1.0);
    final ms = (_duration.inMilliseconds * safeP).round();
    
    debugPrint('[AudioPlayer]  Seeking to ${ms}ms (${(safeP * 100).toInt()}%)');
    _player.seek(Duration(milliseconds: ms));
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primary = widget.primaryColor ?? ThixPolicy.primary;
    final surface = ThixPolicy.surfaceSoft;
    final border = ThixPolicy.border;
    final textMuted = ThixPolicy.textMuted;
    final textMain = ThixPolicy.textMain;

    if (_isLoading) {
      return RepaintBoundary(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              SizedBox(
                width: _kButtonSize,
                height: _kButtonSize,
                child: Center(
                  child: SizedBox(
                    width: _kLoaderSize,
                    height: _kLoaderSize,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.t('player_loading'),
                  style: TextStyle(fontSize: _kFontSizeTime, color: textMuted),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasError) {
      return RepaintBoundary(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 20, color: ThixPolicy.danger),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _errorMessage ?? l10n.t('player_error'),
                  style: TextStyle(fontSize: _kFontSizeTime, color: ThixPolicy.danger),
                ),
              ),
              Semantics(
                button: true,
                label: l10n.t('player_retry'),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _isLoading = true;
                      _hasError = false;
                      _errorMessage = null;
                    });
                    _init();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.refresh_rounded, size: 18, color: primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final progress = _getProgress();
    final rateLabel = '${_playbackRate.toStringAsFixed(1)}x';

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            // Bouton Play/Pause
            Semantics(
              button: true,
              label: _isPlaying ? l10n.t('player_pause') : l10n.t('player_play'),
              child: GestureDetector(
                onTap: _toggle,
                child: Container(
                  width: _kButtonSize,
                  height: _kButtonSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primary,
                    boxShadow: [
                      BoxShadow(
                        color: primary.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            
            // Contrôles (Slider + Temps)
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Slider
                  Semantics(
                    label: l10n.t('player_seek'),
                    value: '${(progress * 100).toInt()}%',
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: _kTrackHeight,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: _kThumbRadius),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: _kOverlayRadius),
                        activeTrackColor: primary,
                        inactiveTrackColor: border,
                        thumbColor: primary,
                        overlayColor: primary.withOpacity(0.15),
                      ),
                      child: Slider(
                        value: progress,
                        min: 0,
                        max: 1,
                        onChanged: _seek,
                      ),
                    ),
                  ),
                  
                  // Ligne temps + vitesse
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Temps actuel
                      Text(
                        _fmt(_position),
                        style: TextStyle(
                          fontSize: _kFontSizeTime,
                          color: textMuted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      
                      Row(
                        children: [
                          // Vitesse
                          Semantics(
                            button: true,
                            label: '${l10n.t('player_speed')}: $rateLabel',
                            child: GestureDetector(
                              onTap: _cycleRate,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: primary.withOpacity(0.15)),
                                ),
                                child: Text(
                                  rateLabel,
                                  style: TextStyle(
                                    fontSize: _kFontSizeRate,
                                    fontWeight: FontWeight.w800,
                                    color: primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          
                          // Durée totale
                          Text(
                            _fmt(_duration),
                            style: TextStyle(
                              fontSize: _kFontSizeTime,
                              color: textMuted,
                              fontFeatures: const [FontFeature.tabularFigures()],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
