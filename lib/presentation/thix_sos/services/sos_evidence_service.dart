/// Preuves chambre de crise — production.
/// Capture téléphone victime → Storage → table evidence → groupe SOS.
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/services/chat/chat_service.dart';
import 'package:thix_id/supabase/supabase_config.dart';

import 'sos_service.dart';

class SosEvidence {
  final String type;
  final String? url;
  final String localPath;
  final DateTime at;
  final bool postedToChat;
  final int? durationMs;

  const SosEvidence({
    required this.type,
    required this.localPath,
    this.url,
    required this.at,
    this.postedToChat = false,
    this.durationMs,
  });
}

class SosEvidenceService {
  SosEvidenceService({SosService? sos}) : _sos = sos ?? SosService();

  final SosService _sos;
  final _picker = ImagePicker();
  final _recorder = AudioRecorder();
  bool _recordingAudio = false;
  String? _audioPath;
  CameraController? _camCtrl;

  bool get isRecordingAudio => _recordingAudio;

  Future<String?> _resolveConversationId(
    String incidentId,
    String? conversationId,
  ) async {
    if (conversationId != null && conversationId.isNotEmpty) {
      return conversationId;
    }
    try {
      final inc = await _sos.getIncidentById(incidentId);
      return inc?.chatConversationId;
    } catch (_) {
      try {
        final inc = await _sos.getIncidentForRescue(incidentId);
        return inc?.chatConversationId;
      } catch (_) {
        return null;
      }
    }
  }

  Future<void> _ensureCamera({bool audio = false}) async {
    if (kIsWeb) {
      throw Exception('Capture silencieuse indisponible sur web — app native requise');
    }
    if (_camCtrl != null && _camCtrl!.value.isInitialized) return;
    final cams = await availableCameras();
    if (cams.isEmpty) throw Exception('Aucune caméra');
    final rear = cams.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cams.first,
    );
    _camCtrl = CameraController(
      rear,
      ResolutionPreset.medium,
      enableAudio: audio,
    );
    await _camCtrl!.initialize();
  }

  Future<SosEvidence?> takePhoto(
    String incidentId, {
    String? conversationId,
    String source = 'rescue',
  }) async {
    String? path;
    try {
      await _ensureCamera(audio: false);
      final x = await _camCtrl!.takePicture();
      path = x.path;
    } catch (e) {
      debugPrint('SosEvidence photo silencieuse: $e');
    }

    if (path == null && !kIsWeb) {
      final x = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 72,
        maxWidth: 1600,
      );
      if (x == null) return null;
      path = x.path;
    }
    if (path == null) return null;

    return _persist(
      incidentId,
      type: 'photo',
      path: path,
      mime: 'image/jpeg',
      conversationId: conversationId,
      source: source,
    );
  }

  /// Vidéo silencieuse. Défaut 10s (clip victime / commande secours).
  Future<SosEvidence?> recordVideo(
    String incidentId, {
    String? conversationId,
    Duration duration = const Duration(seconds: 10),
    String source = 'rescue',
  }) async {
    String? path;
    try {
      await _ensureCamera(audio: true);
      await _camCtrl!.startVideoRecording();
      await Future.delayed(duration);
      final x = await _camCtrl!.stopVideoRecording();
      path = x.path;
    } catch (e) {
      debugPrint('SosEvidence vidéo silencieuse: $e');
      try {
        if (_camCtrl != null && _camCtrl!.value.isRecordingVideo) {
          final x = await _camCtrl!.stopVideoRecording();
          path = x.path;
        }
      } catch (_) {}
    }

    if (path == null && !kIsWeb) {
      final x = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: duration,
      );
      if (x == null) return null;
      path = x.path;
    }
    if (path == null) return null;

    return _persist(
      incidentId,
      type: 'video',
      path: path,
      mime: 'video/mp4',
      conversationId: conversationId,
      source: source,
      durationMs: duration.inMilliseconds,
    );
  }

  Future<void> disposeCamera() async {
    try {
      await _camCtrl?.dispose();
    } catch (_) {}
    _camCtrl = null;
  }

  Future<void> startAudio() async {
    if (_recordingAudio) return;
    final dir = await getTemporaryDirectory();
    _audioPath =
        p.join(dir.path, 'sos_audio_${DateTime.now().millisecondsSinceEpoch}.m4a');
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _audioPath!,
    );
    _recordingAudio = true;
  }

  Future<SosEvidence?> stopAudio(
    String incidentId, {
    String? conversationId,
    String source = 'rescue',
  }) async {
    if (!_recordingAudio) return null;
    final path = await _recorder.stop() ?? _audioPath;
    _recordingAudio = false;
    if (path == null || path.isEmpty) return null;
    return _persist(
      incidentId,
      type: 'audio',
      path: path,
      mime: 'audio/mp4',
      conversationId: conversationId,
      source: source,
    );
  }

  Future<bool> postInstructionToGroup({
    required String incidentId,
    required String text,
    String? conversationId,
  }) async {
    final conv = await _resolveConversationId(incidentId, conversationId);
    var posted = false;
    if (conv != null && conv.isNotEmpty) {
      try {
        await ChatService(Supabase.instance.client).sendMessage(
          conversationId: conv,
          content: '📢 SECOURS : $text',
        );
        posted = true;
      } catch (e) {
        debugPrint('instruct chat: $e');
      }
    }
    try {
      await Supabase.instance.client.from('thix_sos_evidence').insert({
        'incident_id': incidentId,
        'conversation_id': conv,
        'type': 'instruct',
        'source': 'rescue',
        'posted_to_chat': posted,
        'payload': {'text': text},
        'created_by': SupabaseConfig.currentUser?.id,
      });
    } catch (e) {
      debugPrint('instruct evidence row: $e');
    }
    return posted;
  }

  Future<SosEvidence> _persist(
    String incidentId, {
    required String type,
    required String path,
    required String mime,
    String? conversationId,
    String source = 'victim',
    int? durationMs,
  }) async {
    String? url;
    String? storagePath;
    int? bytes;
    try {
      final up = await _upload(incidentId, type: type, path: path, mime: mime);
      url = up?.url;
      storagePath = up?.path;
      bytes = await File(path).length();
    } catch (e) {
      debugPrint('SosEvidence upload: $e');
    }

    final conv = await _resolveConversationId(incidentId, conversationId);

    var posted = false;
    if (conv != null && conv.isNotEmpty && url != null && url.isNotEmpty) {
      for (var i = 0; i < 3 && !posted; i++) {
        try {
          await _postToSosGroup(
            conversationId: conv,
            type: type,
            url: url,
            path: path,
          );
          posted = true;
        } catch (e) {
          debugPrint('SosEvidence chat retry $i: $e');
          await Future.delayed(Duration(milliseconds: 400 * (i + 1)));
        }
      }
    }

    try {
      await Supabase.instance.client.from('thix_sos_evidence').insert({
        'incident_id': incidentId,
        'conversation_id': conv,
        'type': type,
        'url': url,
        'storage_path': storagePath,
        'mime': mime,
        'bytes': bytes,
        'duration_ms': durationMs,
        'source': source,
        'posted_to_chat': posted,
        'payload': {'local_path': path},
        'created_by': SupabaseConfig.currentUser?.id,
      });
    } catch (e) {
      debugPrint('SosEvidence table: $e');
    }

    await _sos.logEventPublic(incidentId, 'EVIDENCE_${type.toUpperCase()}', {
      'local_path': path,
      if (url != null) 'url': url,
      if (conv != null) 'conversation_id': conv,
      'posted_to_chat': posted,
      if (durationMs != null) 'duration_ms': durationMs,
      'source': source,
    });

    return SosEvidence(
      type: type,
      localPath: path,
      url: url,
      at: DateTime.now(),
      postedToChat: posted,
      durationMs: durationMs,
    );
  }

  Future<void> _postToSosGroup({
    required String conversationId,
    required String type,
    required String url,
    required String path,
  }) async {
    final chat = ChatService(Supabase.instance.client);
    final name = p.basename(path);
    final size = await File(path).length();
    final label = switch (type) {
      'photo' => '📸 Preuve SOS — photo',
      'video' => '🎥 Preuve SOS — vidéo',
      'audio' => '🎤 Preuve SOS — audio',
      _ => '📎 Preuve SOS',
    };
    await chat.sendMessage(
      conversationId: conversationId,
      content: label,
      mediaUrl: url,
      mediaType: type,
      mediaName: name,
      mediaSize: size,
    );
  }

  Future<({String url, String path})?> _upload(
    String incidentId, {
    required String type,
    required String path,
    required String mime,
  }) async {
    final uid = SupabaseConfig.currentUser?.id ?? 'anon';
    final ext = p.extension(path).isEmpty ? '.bin' : p.extension(path);
    final storagePath =
        'sos/\( incidentId/ \){uid}_\( {type}_ \){DateTime.now().millisecondsSinceEpoch}$ext';
    final fileBytes = await File(path).readAsBytes();
    final client = Supabase.instance.client;

    for (final bucket in const [
      'sos-evidence',
      'chat-media',
      'status-media',
      'audio_uploads',
    ]) {
      try {
        await client.storage.from(bucket).uploadBinary(
              storagePath,
              fileBytes,
              fileOptions: FileOptions(upsert: true, contentType: mime),
            );
        return (
          url: client.storage.from(bucket).getPublicUrl(storagePath),
          path: storagePath,
        );
      } catch (e) {
        debugPrint('upload $bucket failed: $e');
      }
    }
    return null;
  }
}
