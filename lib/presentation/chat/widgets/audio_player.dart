import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class _C {
  static const bg = Colors.white;
  static const searchBg = Color(0xFFF8FAFC);
  static const border = Color(0xFFE2E8F0);
  static const primary = Color(0xFF1D4ED8);
  static const primaryLight = Color(0xFFEFF6FF);
  static const textMain = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
}

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
  bool _isPlaying = false;
  bool _isLoading = true;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _playbackRate = 1.0;
  final _rates = [1.0, 1.5, 2.0];
  StreamSubscription? _posSub, _durSub, _stateSub;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _init();
    _posSub = _player.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
      widget.onProgressChanged?.call(_duration.inMilliseconds > 0 ? p.inMilliseconds / _duration.inMilliseconds : 0);
    });
    _durSub = _player.onDurationChanged.listen((d) { if (mounted) setState(() => _duration = d); });
    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() => _isPlaying = s == PlayerState.playing);
      if (s == PlayerState.completed) {
        widget.onComplete?.call();
        _player.seek(Duration.zero);
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

  Future<void> _init() async {
    try {
      await _player.setSourceUrl(widget.audioUrl);
      final d = await _player.getDuration();
      if (d != null) setState(() => _duration = d);
    } catch (e) {
      debugPrint('audio error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggle() async {
    if (_isLoading) return;
    if (_isPlaying) {
      await _player.pause();
    } else {
      if (_position >= _duration && _duration.inMilliseconds > 0) await _player.seek(Duration.zero);
      await _player.resume();
      widget.onPlay?.call();
    }
  }

  void _rate() async {
    final i = _rates.indexOf(_playbackRate);
    final n = _rates[(i + 1) % _rates.length];
    setState(() => _playbackRate = n);
    await _player.setPlaybackRate(n);
  }

  void _seek(double p) => _player.seek(Duration(milliseconds: (_duration.inMilliseconds * p).round()));
  String _fmt(Duration d) => '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final primary = widget.primaryColor ?? _C.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: _C.searchBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: _C.border)),
      child: Row(children: [
        GestureDetector(
          onTap: _toggle,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(shape: BoxShape.circle, color: primary, boxShadow: [BoxShadow(color: primary.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 2))]),
            child: _isLoading ? const SizedBox(width: 18, height: 18, child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))) : Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 20),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SliderTheme(
              data: SliderThemeData(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), overlayShape: const RoundSliderOverlayShape(overlayRadius: 12), activeTrackColor: primary, inactiveTrackColor: _C.border, thumbColor: primary, overlayColor: primary.withOpacity(0.15)),
              child: Slider(value: _duration.inMilliseconds > 0 ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0) : 0.0, min: 0, max: 1, onChanged: _seek),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(_fmt(_position), style: const TextStyle(fontSize: 10, color: _C.textMuted, fontFeatures: [FontFeature.tabularFigures()], fontWeight: FontWeight.w500)),
              Row(children: [
                GestureDetector(
                  onTap: _rate,
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _C.primaryLight, borderRadius: BorderRadius.circular(6), border: Border.all(color: _C.primary.withOpacity(0.15))), child: Text('${_playbackRate}x', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _C.primary))),
                ),
                const SizedBox(width: 8),
                Text(_fmt(_duration), style: const TextStyle(fontSize: 10, color: _C.textMuted, fontFeatures: [FontFeature.tabularFigures()], fontWeight: FontWeight.w500)),
              ]),
            ]),
          ]),
        ),
      ]),
    );
  }
}
