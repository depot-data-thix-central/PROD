// lib/presentation/thix_urgent/services/sirene_service.dart
import 'package:audioplayers/audioplayers.dart';
import '../controllers/urgent_controller.dart';
import 'package:flutter/foundation.dart';

class SireneService {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  Future<void> startIfNeeded(EmergencyType type) async {
    // Pas de sirène pour dénoncer anonyme (sécurité victime)
    if (type == EmergencyType.denoncer) return;
    if (_isPlaying) return;

    try {
      _isPlaying = true;
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1.0);
      // Son local pour pas dépendre du réseau
      // await _player.play(AssetSource('sounds/sirene_110db.mp3'));
      // Pour test:
      await _player.play(AssetSource('sounds/sirene.mp3'));
    } catch (e) {
      debugPrint('sirene error $e');
      _isPlaying = false;
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
      _isPlaying = false;
    } catch (_) {}
  }

  // Appelée depuis Chambre de Crise par gardien distant
  Future<void> triggerRemoteSirene(String criseId) async {
    await startIfNeeded(EmergencyType.police);
  }
}
