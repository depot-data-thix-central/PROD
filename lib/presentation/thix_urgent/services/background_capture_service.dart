// lib/presentation/thix_urgent/services/background_capture_service.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:io';

class BackgroundCaptureService {
  CameraController? _controller;
  Timer? _timer;
  bool _isCapturing = false;
  int _uploadQueue = 0;

  Future<void> init() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) return;
      // Résolution LOW pour scale: 480p max = 80ko/photo
      _controller = CameraController(cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cams.first), ResolutionPreset.low, enableAudio: false);
      await _controller!.initialize();
    } catch (e) {
      debugPrint('BackgroundCapture init error $e');
    }
  }

  // Capture auto toutes les 8s + upload par lot de 3 max parallèle
  Future<void> startAutoCapture(String criseId, Function(String path) onNewPhoto) async {
    if (_isCapturing) return;
    _isCapturing = true;

    _timer = Timer.periodic(const Duration(seconds: 8), (_) async {
      if (_uploadQueue >= 3) return; // Limite parallèle pour 1M users
      if (_controller == null ||!_controller!.value.isInitialized) return;

      try {
        _uploadQueue++;
        final xfile = await _controller!.takePicture();
        onNewPhoto(xfile.path);
        await _uploadPhoto(criseId, xfile.path);
      } catch (e) {
        debugPrint('ghost capture error $e');
      } finally {
        _uploadQueue--;
      }
    });
  }

  Future<void> _uploadPhoto(String criseId, String path) async {
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      // Compression côté client avant upload (scale)
      final fileName = 'crises/$criseId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await Supabase.instance.client.storage.from('emergency-photos').uploadBinary(fileName, bytes);
      final url = Supabase.instance.client.storage.from('emergency-photos').getPublicUrl(fileName);
      await Supabase.instance.client.from('emergency_photos').insert({'crise_id': criseId, 'url': url, 'created_at': DateTime.now().toIso8601String()});
    } catch (e) {
      debugPrint('upload error $e');
    }
  }

  Future<void> stop() {
    _isCapturing = false;
    _timer?.cancel();
    _controller?.dispose();
    _controller = null;
    return Future.value();
  }
}
