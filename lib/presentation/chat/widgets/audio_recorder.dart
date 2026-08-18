import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/chat/audio_service.dart';

class _C {
  static const bg = Colors.white;
  static const searchBg = Color(0xFFF8FAFC);
  static const border = Color(0xFFE2E8F0);
  static const primary = Color(0xFF1D4ED8);
  static const primaryLight = Color(0xFFEFF6FF);
  static const textMain = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const red = Color(0xFFEF4444);
}

class AudioRecorderWidget extends StatefulWidget {
  final AudioService audioService;
  final void Function(String filePath, int durationSeconds)? onRecordingComplete;
  final VoidCallback? onRecordingCanceled;
  final void Function(bool isRecording)? onRecordingStateChanged;
  final int maxDuration;
  final double buttonSize;

  const AudioRecorderWidget({
    super.key,
    required this.audioService,
    this.onRecordingComplete,
    this.onRecordingCanceled,
    this.onRecordingStateChanged,
    this.maxDuration = 120,
    this.buttonSize = 56,
  });

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
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startRecording() async {
    if (_isRecording) return;
    try {
      await widget.audioService.startRecording();
      setState(() { _isRecording = true; _currentDuration = 0; _slideOffset = 0.0; _isCanceling = false; });
      widget.onRecordingStateChanged?.call(true);
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() => _currentDuration++);
        if (_currentDuration >= widget.maxDuration) _completeRecording();
      });
    } catch (e) {
      debugPrint('❌ startRecording: $e');
    }
  }

  void _completeRecording() async {
    if (!_isRecording) return;
    _timer?.cancel();
    _timer = null;
    setState(() { _isRecording = false; _isUploading = true; });
    widget.onRecordingStateChanged?.call(false);
    final filePath = await widget.audioService.stopRecording();
    if (filePath != null) {
      widget.onRecordingComplete?.call(filePath, widget.audioService.currentRecordingDuration);
    } else {
      setState(() => _isUploading = false);
      widget.onRecordingCanceled?.call();
    }
  }

  void _cancelRecording() async {
    _timer?.cancel();
    _timer = null;
    setState(() { _isRecording = false; _isCanceling = true; });
    widget.onRecordingStateChanged?.call(false);
    await widget.audioService.cancelRecording();
    widget.onRecordingCanceled?.call();
    Future.delayed(const Duration(milliseconds: 500), () { if (mounted) setState(() => _isCanceling = false); });
  }

  String _fmt(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (_isCanceling) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isRecording || _isUploading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: _C.bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: _C.border), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 2))]),
              child: Row(children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (_, __) => Container(width: 8, height: 8, decoration: BoxDecoration(color: _C.red, shape: BoxShape.circle, boxShadow: [BoxShadow(color: _C.red.withOpacity(0.4 * _pulseAnimation.value), blurRadius: 6, spreadRadius: 2)])),
                ),
                const SizedBox(width: 8),
                Text(_fmt(_currentDuration), style: const TextStyle(color: _C.textMain, fontSize: 13, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
                const SizedBox(width: 8),
                if (_isRecording) GestureDetector(onTap: _cancelRecording, child: const Icon(Icons.close_rounded, color: _C.textMuted, size: 18)),
              ]),
            ),
          if (!_isUploading)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: GestureDetector(
                onLongPress: _startRecording,
                onLongPressUp: _completeRecording,
                onPanUpdate: (d) {
                  if (_isRecording) {
                    setState(() => _slideOffset = (d.delta.dx + _slideOffset).clamp(-100.0, 0.0));
                    if (_slideOffset <= -80) _cancelRecording();
                  }
                },
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (_, __) {
                    final active = _isRecording;
                    final scale = active ? _pulseAnimation.value : 1.0;
                    final color = active ? _C.red : _C.primary;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: widget.buttonSize,
                        height: widget.buttonSize,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: (active ? _C.red : _C.primary).withOpacity(0.1), border: Border.all(color: color, width: 2.5)),
                        child: Icon(_isRecording ? Icons.mic_rounded : Icons.mic_none_rounded, color: color, size: widget.buttonSize * 0.45),
                      ),
                    );
                  },
                ),
              ),
            ),
          if (_isUploading) const Padding(padding: EdgeInsets.all(8.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: _C.primary))),
        ],
      ),
    );
  }
}
