// lib/presentation/thix_urgent/controllers/recording_controller.dart
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'dart:async';

class RecordingController extends ChangeNotifier {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  Timer? _photoTimer;
  final List<String> _photoQueue = [];

  bool get isRecording => _isRecording;
  List<String> get photoQueue => List.unmodifiable(_photoQueue);

  Future<void> startLiveRecording() async {
    try {
      if (!await _recorder.hasPermission()) return;
      _isRecording = true;
      notifyListeners();
      _photoTimer = Timer.periodic(const Duration(seconds: 8), (_) {
        // capture photo fantôme toutes les 8s pour scale
      });
    } catch (e) {
      debugPrint('recording error $e');
    }
  }

  void addPhotoToQueue(String path) {
    _photoQueue.add(path);
    if (_photoQueue.length > 10) _photoQueue.removeAt(0);
    notifyListeners();
  }

  Future<void> stop() async {
    _photoTimer?.cancel();
    try { await _recorder.stop(); } catch (_) {}
    _isRecording = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _photoTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }
}
