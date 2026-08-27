/// Preuves chambre de crise — contrôlées par le SECOURS.
/// Chaque fichier est poussé dans le groupe SOS auto-créé.
import 'dart:io';

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
  final String type; // photo | video | audio
  final String? url;
  final String localPath;
  final DateTime at;
  final bool postedToChat;

  const SosEvidence({
    required this.type,
    required this.localPath,
    this.url,
    required this.at,
    this.postedToChat = false,
  });
}

class SosEvidenceService {
  SosEvidenceService({SosService? sos}) : _sos = sos ?? SosService();

  final SosService _sos;
  final _picker = ImagePicker();
  final _recorder = AudioRecorder();
  bool _recordingAudio = false;
  String? _audioPath;
  DateTime? _audioStartedAt;

  bool get isRecordingAudio => _recordingAudio;

  Future<SosEvidence?> takePhoto(
    String incidentId, {
    String? conversationId,
  }) async {
    final x = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 72,
      maxWidth: 1600,
    );
    if (x == null) return null;
    return _persist(
      incidentId,
      type: 'photo',
      path: x.path,
      mime: 'image/jpeg',
      conversationId: conversationId,
    );
  }

  Future<SosEvidence?> recordVideo(
    String incidentId, {
    String? conversationId,
  }) async {
    final x = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 30),
    );
    if (x == null) return null;
    return _persist(
      incidentId,
      type: 'video',
      path: x.path,
      mime: 'video/mp4',
      conversationId: conversationId,
    );
  }

  Future<void> startAudio() async {
    if (_recordingAudio) return;
    final dir = await getTemporaryDirectory();
    _audioPath =
        p.join(dir.path, 'sos_audio_${DateTime.now().millisecondsSinceEpoch}.m4a');
    _audioStartedAt = DateTime.now();
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _audioPath!,
    );
    _recordingAudio = true;
  }

  Future<SosEvidence?> stopAudio(
    String incidentId, {
    String? conversationId,
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
    );
  }

  Future<SosEvidence> _persist(
    String incidentId, {
    required String type,
    required String path,
    required String mime,
    String? conversationId,
  }) async {
    String? url;
    try {
      url = await _upload(incidentId, type: type, path: path, mime: mime);
    } catch (e) {
      debugPrint('SosEvidence upload: $e');
    }

    var posted = false;
    if (conversationId != null &&
        conversationId.isNotEmpty &&
        url != null &&
        url.isNotEmpty) {
      try {
        await _postToSosGroup(
          conversationId: conversationId,
          type: type,
          url: url,
          path: path,
        );
        posted = true;
      } catch (e) {
        debugPrint('SosEvidence chat: $e');
      }
    }

    await _sos.logEventPublic(incidentId, 'EVIDENCE_${type.toUpperCase()}', {
      'local_path': path,
      if (url != null) 'url': url,
      if (conversationId != null) 'conversation_id': conversationId,
      'posted_to_chat': posted,
    });

    return SosEvidence(
      type: type,
      localPath: path,
      url: url,
      at: DateTime.now(),
      postedToChat: posted,
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

  Future<String?> _upload(
    String incidentId, {
    required String type,
    required String path,
    required String mime,
  }) async {
    final uid = SupabaseConfig.currentUser?.id ?? 'anon';
    final ext = p.extension(path).isEmpty ? '.bin' : p.extension(path);
    final storagePath =
        'sos/$incidentId/${uid}_${type}_${DateTime.now().millisecondsSinceEpoch}$ext';
    final bytes = await File(path).readAsBytes();
    final client = Supabase.instance.client;

    for (final bucket in const [
      'chat-media',
      'sos-evidence',
      'status-media',
      'audio_uploads'
    ]) {
      try {
        await client.storage.from(bucket).uploadBinary(
              storagePath,
              bytes,
              fileOptions: FileOptions(upsert: true, contentType: mime),
            );
        return client.storage.from(bucket).getPublicUrl(storagePath);
      } catch (e) {
        debugPrint('upload $bucket failed: $e');
      }
    }
    return null;
  }
}
