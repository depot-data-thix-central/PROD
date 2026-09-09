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
const double _kButtonSize = 40.0; // ← Augmenté pour a11y (min 40dp)
const double _kLoaderSize = 18.0;
const double _kTrackHeight = 4.0; // ← Augmenté pour touch
const double _kTouchAreaHeight = 32.0; // ← Zone de touch réelle
const double _kThumbRadius = 7.0;
const double _kOverlayRadius = 14.0;
const double _kFontSizeTime = 10.0;
const double _kFontSizeRate = 10.0;
const List<double> _kPlaybackRates = [1.0, 1.5, 2.0];
const int _kMaxUrlLength = 2048;
const Duration _kSeekThrottle = Duration(milliseconds: 100);

// ============================================================================
// VALIDATORS
// ============================================================================
class _PlayerValidators {
  _PlayerValidators._();

  static String? sanitizeUrl(String? url) {
    if (url == null) return null;
    final t = url.trim();
    if (t.isEmpty || t.length > _kMaxUrlLength) return null;
    if (!t.startsWith('http://') && !t.startsWith('https://')) return null;
    // Nettoyage caractères de contrôle
    return t.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  static String friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'audio_error_timeout';
    if (msg.contains('network') || msg.contains('socket')) return 'audio_error_network';
    if (msg.contains('not found') || msg.contains('404')) return 'audio_error_not_found';
    if (msg.contains('format') || msg.contains('decode')) return 'audio_error_format';
    return 'audio_error_generic';
  }
}

// ============================================================================
// AUDIO PLAYER WIDGET
// ============================================================================
class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final int? totalDuration;
  final Color? primaryColor;
  final Color? accentColor;
  final VoidCallback? onPlay;
  final VoidCallback? onComplete;
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
  
  // ✅ ValueNotifiers pour éviter les rebuilds globaux
  final ValueNotifier<bool> _isPlaying = ValueNotifier(false);
  final ValueNotifier<Duration> _position = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> _duration = ValueNotifier(Duration.zero);
  
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorKey;
  double _playbackRate = 1.0;
  String? _currentUrl;
  
  StreamSubscription? _posSub, _durSub, _stateSub;
  Timer? _seekThrottleTimer;
  double? _pendingSeek;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _currentUrl = widget.audioUrl;
    _init();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant AudioPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ✅ Recharge l'audio si l'URL change
    if (oldWidget.audioUrl != widget.audioUrl) {
      _currentUrl = widget.audioUrl;
      _reset();
      _init();
    }
  }

  void _subscribe() {
    _posSub = _player.onPositionChanged.listen((p) {
      if (!mounted) return;
      _position.value = p;
      widget.onProgressChanged?.call(_computeProgress());
    });

    _durSub = _player.onDurationChanged.listen((d) {
      if (!mounted) return;
      _duration.value = d;
    });

    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      _isPlaying.value = s == PlayerState.playing;
      
      if (s == PlayerState.completed) {
        widget.onComplete?.call();
        // ✅ Seek synchrone après completion pour éviter la race
        unawaited(_player.pause().then((_) {
          if (mounted) {
            _player.seek(Duration.zero);
            _position.value = Duration.zero;
          }
        }));
      }
    });
  }

  @override
  void dispose() {
    _seekThrottleTimer?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    _isPlaying.dispose();
    _position.dispose();
    _duration.dispose();
    super.dispose();
  }

  double _computeProgress() {
    final d = _duration.value.inMilliseconds;
    if (d <= 0) return 0.0;
    return (_position.value.inMilliseconds / d).clamp(0.0, 1.0);
  }

  Future<void> _reset() async {
    try {
      await _player.stop();
      _position.value = Duration.zero;
      _duration.value = Duration.zero;
      _isPlaying.value = false;
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorKey = null;
      });
    } catch (_) {}
  }

  Future<void> _init() async {
    final safeUrl = _PlayerValidators.sanitizeUrl(_currentUrl);
    if (safeUrl == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorKey = 'audio_error_invalid_url';
        });
      }
      return;
    }

    try {
      await _player.setSourceUrl(safeUrl).timeout(_kLoadTimeout);
      final d = await _player.getDuration();
      if (d != null && d.inMilliseconds > 0) {
        _duration.value = d;
      } else if (widget.totalDuration != null && widget.totalDuration! > 0) {
        _duration.value = Duration(seconds: widget.totalDuration!);
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorKey = _PlayerValidators.friendlyError(e);
        });
      }
    }
  }

  Future<void> _toggle() async {
    if (_isLoading || _hasError) return;
    
    await HapticFeedback.mediumImpact();
    
    if (_isPlaying.value) {
      await _player.pause();
    } else {
      // Si à la fin, reset d'abord
      if (_position.value >= _duration.value && _duration.value.inMilliseconds > 0) {
        await _player.seek(Duration.zero);
        _position.value = Duration.zero;
      }
      await _player.resume();
      widget.onPlay?.call();
    }
  }

  Future<void> _cycleRate() async {
    await HapticFeedback.selectionClick();
    final i = _kPlaybackRates.indexOf(_playbackRate);
    final n = _kPlaybackRates[(i + 1) % _kPlaybackRates.length];
    
    setState(() => _playbackRate = n);
    await _player.setPlaybackRate(n);
  }

  /// ✅ Seek avec throttle pour éviter le spam
  void _seek(double p) {
    if (_duration.value.inMilliseconds <= 0) return;
    final safeP = p.clamp(0.0, 1.0);
    _pendingSeek = safeP;
    
    _seekThrottleTimer ??= Timer(_kSeekThrottle, () {
      if (_pendingSeek == null) return;
      final ms = (_duration.value.inMilliseconds * _pendingSeek!).round();
      _player.seek(Duration(milliseconds: ms));
      HapticFeedback.selectionClick();
      _pendingSeek = null;
      _seekThrottleTimer = null;
    });
  }

  /// ✅ Formatage robuste (gère les durées > 1h)
  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primary = widget.primaryColor ?? ThixPolicy.primary;
    final surface = ThixPolicy.surfaceSoft;
    final border = ThixPolicy.border;
    final textMuted = ThixPolicy.textMuted;

    if (_isLoading) {
      return _buildContainer(
        surface: surface,
        border: border,
        child: Row(
          children: [
            SizedBox(
              width: _kButtonSize,
              height: _kButtonSize,
              child: Center(
                child: SizedBox(
                  width: _kLoaderSize,
                  height: _kLoaderSize,
                  child: CircularProgressIndicator(strokeWidth: 2, color: primary),
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
      );
    }

    if (_hasError) {
      return _buildContainer(
        surface: surface,
        border: border,
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, size: 20, color: ThixPolicy.danger),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.t(_errorKey ?? 'player_error'),
                style: const TextStyle(fontSize: _kFontSizeTime, color: ThixPolicy.danger),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Tooltip(
              message: l10n.t('player_retry'),
              child: IconButton(
                iconSize: 20,
                color: primary,
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  _reset();
                  _init();
                },
              ),
            ),
          ],
        ),
      );
    }

    return RepaintBoundary(
      child: _buildContainer(
        surface: surface,
        border: border,
        child: Row(
          children: [
            // ✅ IconButton au lieu de GestureDetector (meilleure a11y)
            ValueListenableBuilder<bool>(
              valueListenable: _isPlaying,
              builder: (_, playing, __) => Semantics(
                button: true,
                label: playing ? l10n.t('player_pause') : l10n.t('player_play'),
                child: IconButton(
                  onPressed: _toggle,
                  iconSize: 22,
                  color: Colors.white,
                  style: IconButton.styleFrom(
                    backgroundColor: primary,
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(_kButtonSize, _kButtonSize),
                    shadowColor: primary.withValues(alpha: 0.25),
                    elevation: 4,
                  ),
                  icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ✅ Slider isolé dans ValueListenableBuilder
                  SizedBox(
                    height: _kTouchAreaHeight,
                    child: ValueListenableBuilder<Duration>(
                      valueListenable: _position,
                      builder: (ctx, pos, __) {
                        return ValueListenableBuilder<Duration>(
                          valueListenable: _duration,
                          builder: (ctx, dur, __) {
                            final progress = dur.inMilliseconds > 0
                                ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                                : 0.0;
                            return Semantics(
                              label: l10n.t('player_seek'),
                              value: '${(progress * 100).toInt()}%',
                              // ✅ Accessibilité : gestes d'incrément
                              increasedValue: '${((progress + 0.05) * 100).clamp(0, 100).toInt()}%',
                              decreasedValue: '${((progress - 0.05) * 100).clamp(0, 100).toInt()}%',
                              onIncrease: () => _seek(progress + 0.05),
                              onDecrease: () => _seek(progress - 0.05),
                              child: SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: _kTrackHeight,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: _kThumbRadius),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: _kOverlayRadius),
                                  activeTrackColor: primary,
                                  inactiveTrackColor: border,
                                  thumbColor: primary,
                                  overlayColor: primary.withValues(alpha: 0.15),
                                ),
                                child: Slider(
                                  value: progress,
                                  min: 0,
                                  max: 1,
                                  onChanged: _seek,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ValueListenableBuilder<Duration>(
                        valueListenable: _position,
                        builder: (_, pos, __) => Text(
                          _fmt(pos),
                          style: TextStyle(
                            fontSize: _kFontSizeTime,
                            color: textMuted,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Tooltip(
                            message: l10n.t('player_speed'),
                            child: InkWell(
                              onTap: _cycleRate,
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: primary.withValues(alpha: 0.15)),
                                ),
                                child: Text(
                                  _playbackRate == 1.0 ? '1x' : '${_playbackRate.toStringAsFixed(1)}x',
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
                          ValueListenableBuilder<Duration>(
                            valueListenable: _duration,
                            builder: (_, dur, __) => Text(
                              _fmt(dur),
                              style: TextStyle(
                                fontSize: _kFontSizeTime,
                                color: textMuted,
                                fontFeatures: const [FontFeature.tabularFigures()],
                                fontWeight: FontWeight.w500,
                              ),
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

  Widget _buildContainer({
    required Color surface,
    required Color border,
    required Widget child,
  }) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: child,
      ),
    );
  }
}
