// lib/presentation/thix_sos/services/sos_media_outbox.dart
/// File locale : photo / vidéo / audio capturés avant que le groupe Chat existe.
/// Dès que conversationId est connu → upload + sendMessage.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:thix_id/services/chat/chat_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SosOutboxItem {
  final String incidentId;
  final String type; // photo | video | audio
  final String localPath;
  final String mime;
  final DateTime at;

  SosOutboxItem({
    required this.incidentId,
    required this.type,
    required this.localPath,
    required this.mime,
    DateTime? at,
  }) : at = at ?? DateTime.now();
}

class SosMediaOutbox {
  SosMediaOutbox._();
  static final SosMediaOutbox instance = SosMediaOutbox._();

  final List<SosOutboxItem> _queue = [];
  bool _flushing = false;

  void enqueue(SosOutboxItem item) {
    if (item.localPath.isEmpty) return;
    _queue.add(item);
    debugPrint('[SosOutbox] +\( {item.type} queue= \){_queue.length}');
  }

  Future<void> flush(String incidentId, String conversationId) async {
    if (_flushing) return;
    if (conversationId.isEmpty) return;
    final pending =
        _queue.where((e) => e.incidentId == incidentId).toList();
    if (pending.isEmpty) return;

    _flushing = true;
    final chat = ChatService(Supabase.instance.client);
    try {
      for (final item in pending) {
        try {
          final file = File(item.localPath);
          if (!await file.exists()) {
            _queue.remove(item);
            continue;
          }
          final bytes = await file.readAsBytes();
          final ext = p.extension(item.localPath);
          final storagePath =
              'sos/\( incidentId/outbox_ \){item.type}_${item.at.millisecondsSinceEpoch}$ext';

          String? url;
          for (final bucket in const ['sos-evidence', 'chat-media', 'audio_uploads']) {
            try {
              await Supabase.instance.client.storage.from(bucket).uploadBinary(
                    storagePath,
                    bytes,
                    fileOptions: FileOptions(
                      upsert: true,
                      contentType: item.mime,
                    ),
                  );
              url = Supabase.instance.client.storage
                  .from(bucket)
                  .getPublicUrl(storagePath);
              break;
            } catch (_) {}
          }
          if (url == null) continue;

          final mediaType = switch (item.type) {
            'photo' => 'image',
            'video' => 'video',
            'audio' => 'audio',
            _ => item.type,
          };
          final label = switch (item.type) {
            'photo' => '📸 Preuve SOS — photo',
            'video' => '🎥 Preuve SOS — vidéo',
            'audio' => '🎤 Preuve SOS — audio',
            _ => '📎 Preuve SOS',
          };

          await chat.sendMessage(
            conversationId: conversationId,
            content: label,
            mediaUrl: url,
            mediaType: mediaType,
            mediaName: p.basename(item.localPath),
            mediaSize: bytes.length,
          );
          _queue.remove(item);
          debugPrint('[SosOutbox] sent ${item.type}');
        } catch (e) {
          debugPrint('[SosOutbox] item failed: $e');
        }
      }
    } finally {
      _flushing = false;
    }
  }
}
