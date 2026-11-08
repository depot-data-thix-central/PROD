// lib/data/services/live/audio_space_background_service.dart
//
// ============================================================================
// 🔊 AUDIO SPACE BACKGROUND SERVICE — v2
// ============================================================================
// N'a plus de moteur Agora (le manager est le seul propriétaire).
// Rôle : audio qui continue en arrière-plan
//   ✅ Service de premier plan Android (micro actif en arrière-plan)
//   ✅ Wake lock
//   ✅ Stream de cycle de vie (true = arrière-plan, false = premier plan)
//   ✅ Callbacks vers le manager (stop / mute depuis la notification)
// ============================================================================

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:thix_id/services/chat/call_foreground_service.dart';

enum BackgroundServiceStatus { idle, active, background, error }

class AudioSpaceBackgroundService with WidgetsBindingObserver {
  AudioSpaceBackgroundService._internal();
  static final AudioSpaceBackgroundService instance =
      AudioSpaceBackgroundService._internal();

  factory AudioSpaceBackgroundService() => instance;

  BackgroundServiceStatus _status = BackgroundServiceStatus.idle;
  BackgroundServiceStatus get status => _status;

  bool _observing = false;

  final StreamController<bool> _lifecycle =
      StreamController<bool>.broadcast();

  /// true = arrière-plan, false = premier plan
  Stream<bool> get onAppLifecycleChanged => _lifecycle.stream;

  /// Branchés par le manager
  VoidCallback? onStopRequested;
  void Function(bool muted)? onMuteRequested;

  // ─────────────────────────────────────────────────────────────
  Future<void> start({required String title}) async {
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }

    try {
      await WakelockPlus.enable();
    } catch (e) {
      debugPrint('[SpaceBG] ⚠️ Wake lock: $e');
    }

    // Service de premier plan : l'audio survit à l'arrière-plan (Android)
    try {
      await CallForegroundService.start(video: false);
    } catch (e) {
      debugPrint('[SpaceBG] ⚠️ Foreground service: $e');
    }

    _status = BackgroundServiceStatus.active;
    debugPrint('[SpaceBG] ✓ Actif pour "$title"');
  }

  Future<void> stop() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {}
    try {
      await CallForegroundService.stop();
    } catch (e) {
      debugPrint('[SpaceBG] ⚠️ Foreground stop: $e');
    }
    _status = BackgroundServiceStatus.idle;
    debugPrint('[SpaceBG] ✓ Arrêt');
  }

  // Compatibilité avec l'ancien code
  Future<void> stopAgora() => stop();
  Future<void> setMuted(bool muted) async => onMuteRequested?.call(muted);
  Future<void> prepareBackgroundMode() async {}

  // ─────────────────────────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      if (_status == BackgroundServiceStatus.active) {
        _status = BackgroundServiceStatus.background;
      }
      _lifecycle.add(true);
    } else if (state == AppLifecycleState.resumed) {
      if (_status == BackgroundServiceStatus.background) {
        _status = BackgroundServiceStatus.active;
      }
      _lifecycle.add(false);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// AUDIO HANDLER (pour audio_service)
// ─────────────────────────────────────────────────────────────
class ThixAudioHandler extends BaseAudioHandler {
  @override
  Future<void> stop() async {
    AudioSpaceBackgroundService.instance.onStopRequested?.call();
  }

  @override
  Future<void> pause() async {
    await AudioSpaceBackgroundService.instance.setMuted(true);
  }

  @override
  Future<void> play() async {
    await AudioSpaceBackgroundService.instance.setMuted(false);
  }
}
