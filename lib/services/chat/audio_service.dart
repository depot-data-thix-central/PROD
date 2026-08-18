
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as path;

/// Service pour l'enregistrement, la lecture et l'upload de messages audio.
class AudioService {
  final SupabaseClient _supabase;
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  String? _currentRecordingPath;
  bool _isRecording = false;
  Timer? _recordingTimer;
  int _recordingDuration = 0;

  /// Stream de la durée d'enregistrement (en secondes)
  final StreamController<int> _recordingDurationController = StreamController<int>.broadcast();
  Stream<int> get recordingDurationStream => _recordingDurationController.stream;

  /// Stream de l'état d'enregistrement
  final StreamController<bool> _isRecordingController = StreamController<bool>.broadcast();
  Stream<bool> get isRecordingStream => _isRecordingController.stream;

  AudioService(this._supabase) {
    _player.onPlayerStateChanged.listen((state) {
      // Gérer les changements d'état si nécessaire
    });
  }

  /// Vérifie si l'enregistrement est disponible
  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  /// Démarre l'enregistrement audio
  Future<void> startRecording() async {
    if (_isRecording) return;

    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        throw Exception('Permission microphone refusée');
      }

      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = path.join(directory.path, 'audio_$timestamp.m4a');

      await _recorder.start(
        RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );

      _currentRecordingPath = filePath;
      _isRecording = true;
      _recordingDuration = 0;
      _isRecordingController.add(true);

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _recordingDuration++;
        _recordingDurationController.add(_recordingDuration);
      });
    } catch (e) {
      debugPrint('❌ Erreur startRecording: $e');
      rethrow;
    }
  }

  /// Arrête l'enregistrement et retourne le chemin du fichier
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      _recordingTimer?.cancel();
      _recordingTimer = null;
      _isRecording = false;
      _isRecordingController.add(false);
      _recordingDurationController.add(0);

      final path = await _recorder.stop();
      _currentRecordingPath = path;
      return path;
    } catch (e) {
      debugPrint('❌ Erreur stopRecording: $e');
      return null;
    }
  }

  /// Annule l'enregistrement (supprime le fichier)
  Future<void> cancelRecording() async {
    if (_currentRecordingPath != null) {
      try {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('❌ Erreur cancelRecording: $e');
      }
    }
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _isRecording = false;
    _isRecordingController.add(false);
    _recordingDurationController.add(0);
    _currentRecordingPath = null;
  }

  /// Upload un fichier audio vers Supabase Storage
  Future<String?> uploadAudio({
    required String filePath,
    required String conversationId,
    String bucket = 'audio',
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Fichier audio introuvable');
      }

      final bytes = await file.readAsBytes();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$conversationId.m4a';
      final storagePath = 'messages/$conversationId/$fileName';

      await _supabase.storage.from(bucket).uploadBinary(storagePath, bytes);

      final publicUrl = _supabase.storage.from(bucket).getPublicUrl(storagePath);

      // Nettoyer le fichier local
      try {
        await file.delete();
      } catch (_) {}

      return publicUrl;
    } catch (e) {
      debugPrint('❌ Erreur uploadAudio: $e');
      return null;
    }
  }

  /// Récupère la durée d'un fichier audio (en secondes)
  Future<int> getAudioDuration(String filePath) async {
    try {
      final player = AudioPlayer();
      await player.setSourceDeviceFile(filePath);
      final duration = await player.getDuration();
      await player.dispose();
      return duration?.inSeconds ?? 0;
    } catch (e) {
      debugPrint('❌ Erreur getAudioDuration: $e');
      return 0;
    }
  }

  /// Jouer un audio à partir d'une URL
  Future<void> play(String url) async {
    try {
      await _player.stop();
      await _player.play(UrlSource(url));
    } catch (e) {
      debugPrint('❌ Erreur play: $e');
      rethrow;
    }
  }

  /// Pause la lecture
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      debugPrint('❌ Erreur pause: $e');
    }
  }

  /// Reprend la lecture (si en pause)
  Future<void> resume() async {
    try {
      await _player.resume();
    } catch (e) {
      debugPrint('❌ Erreur resume: $e');
    }
  }

  /// Arrête la lecture
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('❌ Erreur stop: $e');
    }
  }

  /// Seek à une position (en pourcentage 0.0 - 1.0)
  Future<void> seek(double progress) async {
    try {
      final duration = await _player.getDuration();
      if (duration != null) {
        final position = Duration(milliseconds: (duration.inMilliseconds * progress).round());
        await _player.seek(position);
      }
    } catch (e) {
      debugPrint('❌ Erreur seek: $e');
    }
  }

  /// Stream de progression de la lecture
  Stream<Duration> get positionStream => _player.onPositionChanged;
  Stream<Duration> get durationStream => _player.onDurationChanged;

  /// Libère les ressources
  void dispose() {
    _recordingTimer?.cancel();
    _player.dispose();
    _recorder.dispose();
    _recordingDurationController.close();
    _isRecordingController.close();
  }

  /// Durée actuelle d'enregistrement (en secondes)
  int get currentRecordingDuration => _recordingDuration;

  /// Indique si un enregistrement est en cours
  bool get isRecording => _isRecording;
}
