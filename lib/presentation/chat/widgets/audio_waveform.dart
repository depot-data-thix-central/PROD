import 'package:flutter/material.dart';
import 'package:flutter_audio_waveforms/flutter_audio_waveforms.dart';

class _C {
  static const bg = Colors.white;
  static const searchBg = Color(0xFFF8FAFC);
  static const border = Color(0xFFE2E8F0);
  static const primary = Color(0xFF1D4ED8);
  static const textMain = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
}

class AudioWaveformWidget extends StatefulWidget {
  final String? audioUrl;
  final String? filePath;
  final Color waveformColor;
  final Color progressColor;
  final double height;
  final double width;
  final int numberOfBars;
  final double progress;

  const AudioWaveformWidget({
    super.key,
    this.audioUrl,
    this.filePath,
    this.waveformColor = _C.primary,
    this.progressColor = _C.primary,
    this.height = 48,
    this.width = double.infinity,
    this.numberOfBars = 40,
    this.progress = 0.0,
  }) : assert(audioUrl != null || filePath != null, 'audioUrl or filePath must be provided');

  @override
  State<AudioWaveformWidget> createState() => _AudioWaveformWidgetState();
}

class _AudioWaveformWidgetState extends State<AudioWaveformWidget> {
  final PlayerController _controller = PlayerController();
  bool _isLoading = true;
  bool _hasError = false;

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
    try {
      if (widget.audioUrl != null) {
        await _controller.preparePlayer(widget.audioUrl!, noOfSamples: widget.numberOfBars);
      } else if (widget.filePath != null) {
        await _controller.preparePlayerFromFile(widget.filePath!, noOfSamples: widget.numberOfBars);
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('waveform error: $e');
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(height: widget.height, child: const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _C.primary))));
    }
    if (_hasError) {
      return SizedBox(
        height: widget.height,
        child: Center(child: Text('Impossible de charger l\'onde', style: TextStyle(fontSize: 10, color: _C.textMuted, fontStyle: FontStyle.italic))),
      );
    }
    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: AudioFileWaveforms(
        controller: _controller,
        size: Size(widget.width, widget.height),
        playerWaveStyle: PlayerWaveStyle(
          fixedWaveColor: widget.waveformColor.withOpacity(0.2),
          liveWaveColor: widget.progressColor,
          scaleFactor: 0.8,
          showSeekLine: true,
          seekLineColor: _C.primary,
          seekLineWidth: 2,
          showDurationLabel: false,
        ),
        enableScrolling: false,
        onCurrentPosition: (_) {},
      ),
    );
  }

  Future<void> play() => _controller.startPlayer();
  Future<void> pause() => _controller.pausePlayer();
  Future<void> stop() => _controller.stopPlayer();
  Future<void> seekTo(double progress) async {
    final d = await _controller.getDuration();
    if (d != null) {
      await _controller.seekTo(Duration(milliseconds: (d.inMilliseconds * progress).round()));
    }
  }
}

class MiniAudioWaveform extends StatelessWidget {
  final List<double>? waveformData;
  final double progress;
  final Color color;
  final double height;
  final int barCount;

  const MiniAudioWaveform({
    super.key,
    required this.waveformData,
    required this.progress,
    required this.color,
    this.height = 24,
    this.barCount = 20,
  });

  @override
  Widget build(BuildContext context) {
    if (waveformData == null || waveformData!.isEmpty) {
      return Container(
        height: height,
        decoration: BoxDecoration(color: _C.searchBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: _C.border)),
        child: const Center(child: Text('🎵 Audio', style: TextStyle(fontSize: 11, color: _C.textMuted))),
      );
    }
    final data = waveformData!;
    final progressIndex = (data.length * progress).floor();
    return SizedBox(
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(barCount, (i) {
          final v = data[i % data.length];
          final h = (v * height).clamp(2.0, height);
          final isP = i <= progressIndex;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Container(width: 3, height: h, decoration: BoxDecoration(color: isP ? color : color.withOpacity(0.25), borderRadius: BorderRadius.circular(2))),
          );
        }),
      ),
    );
  }
}
