import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'package:thix_id/core/media/thix_media_optimizer.dart';

/// Sélecteur d'extrait : l'utilisateur choisit la partie à garder
/// (fenêtre glissante limitée à [maxSeconds]). Renvoie un [VideoTrimRange]
/// ou null si annulé.
///
/// Nommée StatusVideoTrimPage pour éviter la collision avec le
/// VideoTrimPage déjà exporté par thix_media_editor.dart.
class StatusVideoTrimPage extends StatefulWidget {
  const StatusVideoTrimPage({super.key, required this.videoPath, this.maxSeconds = 120});

  final String videoPath;
  final int maxSeconds;

  @override
  State<StatusVideoTrimPage> createState() => _VideoTrimPageState();
}

class _VideoTrimPageState extends State<StatusVideoTrimPage> {
  VideoPlayerController? _c;
  bool _ready = false;
  String? _error;

  double _totalMs = 0;
  double _startMs = 0;
  double _endMs = 0;
  bool _scrubbing = false;

  double get _maxWindowMs => widget.maxSeconds * 1000.0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final c = ThixMediaOptimizer.controllerFor(widget.videoPath);
    _c = c;
    try {
      await c.initialize();
      if (!mounted) return; // l'État a déjà libéré le contrôleur
      _totalMs = c.value.duration.inMilliseconds.toDouble();
      if (_totalMs <= 0) {
        setState(() => _error = 'Durée de la vidéo inconnue.');
        return;
      }
      _endMs = math.min(_totalMs, _maxWindowMs);
      c.addListener(_onTick);
      await c.play();
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (e) {
      debugPrint('[Trim] ❌ init: $e');
      if (mounted) setState(() => _error = 'Impossible de lire cette vidéo.');
    }
  }

  /// Boucle la lecture à l'intérieur de l'extrait sélectionné.
  void _onTick() {
    final c = _c;
    if (!mounted || c == null || !c.value.isInitialized || _scrubbing) return;
    final pos = c.value.position.inMilliseconds.toDouble();
    if (pos >= _endMs - 60 || pos < _startMs - 400) {
      c.seekTo(Duration(milliseconds: _startMs.round()));
    }
    setState(() {});
  }

  @override
  void dispose() {
    _c?.removeListener(_onTick);
    _c?.dispose();
    super.dispose();
  }

  String _fmt(double ms) {
    final d = Duration(milliseconds: ms.round());
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '${d.inMinutes}:$s';
  }

  void _onRangeChanged(RangeValues v) {
    var s = v.start;
    var e = v.end;
    final startMoved = (s - _startMs).abs() >= (e - _endMs).abs();

    // Fenêtre maximale : la poignée opposée suit.
    if (e - s > _maxWindowMs) {
      if (startMoved) {
        s = math.max(0.0, e - _maxWindowMs);
      } else {
        e = math.min(_totalMs, s + _maxWindowMs);
      }
    }
    // Extrait minimum : 1 seconde.
    if (e - s < 1000) {
      if (startMoved) {
        s = math.max(0.0, e - 1000);
      } else {
        e = math.min(_totalMs, s + 1000);
      }
    }

    setState(() {
      _startMs = s;
      _endMs = e;
    });
    // Aperçu de l'image sous la poignée déplacée.
    _c?.seekTo(Duration(milliseconds: (startMoved ? s : e).round()));
  }

  void _confirm() {
    HapticFeedback.mediumImpact();
    Navigator.pop(
      context,
      VideoTrimRange(startMs: _startMs.round(), endMs: _endMs.round()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Découper la vidéo',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: Colors.white70)))
          : !_ready || c == null
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Vidéo de ${_fmt(_totalMs)} — sélectionnez un extrait '
                        'de ${widget.maxSeconds ~/ 60} min maximum.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          c.value.isPlaying ? c.pause() : c.play();
                          setState(() {});
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Center(
                              child: AspectRatio(
                                aspectRatio: c.value.aspectRatio,
                                child: VideoPlayer(c),
                              ),
                            ),
                            if (!c.value.isPlaying)
                              const Icon(Icons.play_circle_fill_rounded,
                                  color: Colors.white70, size: 64),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_fmt(_startMs),
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w700)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Extrait : ${_fmt(_endMs - _startMs)}',
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(_fmt(_endMs),
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.white,
                        overlayColor: Colors.white24,
                        rangeThumbShape: const RoundRangeSliderThumbShape(
                            enabledThumbRadius: 12),
                      ),
                      child: RangeSlider(
                        values: RangeValues(_startMs, _endMs),
                        min: 0,
                        max: _totalMs,
                        divisions: math.max(1, (_totalMs / 1000).round()),
                        labels: RangeLabels(_fmt(_startMs), _fmt(_endMs)),
                        onChangeStart: (_) {
                          _scrubbing = true;
                          c.pause();
                        },
                        onChanged: _onRangeChanged,
                        onChangeEnd: (_) {
                          _scrubbing = false;
                          c.seekTo(Duration(milliseconds: _startMs.round()));
                          c.play();
                        },
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: _confirm,
                            icon: const Icon(Icons.content_cut_rounded),
                            label: Text(
                              'Utiliser cet extrait (${_fmt(_endMs - _startMs)})',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
