// lib/services/status_service.dart
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';
import 'package:thix_id/services/platform_file_from_path_stub.dart'
    if (dart.library.io) 'package:thix_id/services/platform_file_from_path_io.dart';

class StatusUpdate {
  final String id;
  final String uid;
  final String displayName;
  final String thixId;
  final String text;
  final String statusType; // text | photo | video | audio
  final String? mediaUrl;
  final String? mediaMime;
  final String? mediaName;
  final int? mediaSize;
  final DateTime createdAt;
  final DateTime expiresAt;

  const StatusUpdate({
    required this.id,
    required this.uid,
    required this.displayName,
    required this.thixId,
    required this.text,
    required this.statusType,
    required this.mediaUrl,
    required this.mediaMime,
    required this.mediaName,
    required this.mediaSize,
    required this.createdAt,
    required this.expiresAt,
  });

  static DateTime _dt(Object v) => (v is DateTime) ? v : DateTime.parse(v as String);

  static StatusUpdate fromRow(Map<String, dynamic> row) {
    return StatusUpdate(
      id: (row['id'] as String?) ?? '',
      uid: (row['uid'] as String?) ?? '',
      displayName: (row['display_name'] as String?) ?? 'Utilisateur',
      thixId: (row['thix_id'] as String?) ?? '',
      text: (row['text'] as String?) ?? '',
      statusType: (row['status_type'] as String?) ?? 'text',
      mediaUrl: row['media_url'] as String?,
      mediaMime: row['media_mime'] as String?,
      mediaName: row['media_name'] as String?,
      mediaSize: (row['media_size'] as num?)?.toInt(),
      createdAt: _dt(row['created_at'] as Object),
      expiresAt: _dt(row['expires_at'] as Object),
    );
  }
}

class StatusService {
  final SupabaseClient _client;
  StatusService({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  static const String table = 'thix_status_updates';
  static const String mediaBucket = 'thix-status';

  static String _guessMime(String statusType, String? extension) {
    final ext = (extension ?? '').toLowerCase();
    if (statusType == 'photo') {
      return switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'jpg' || 'jpeg' => 'image/jpeg',
        _ => 'image/jpeg',
      };
    }
    if (statusType == 'video') {
      return switch (ext) {
        'webm' => 'video/webm',
        'mov' => 'video/quicktime',
        'm4v' => 'video/x-m4v',
        _ => 'video/mp4',
      };
    }
    if (statusType == 'audio') {
      return switch (ext) {
        'wav' => 'audio/wav',
        'ogg' => 'audio/ogg',
        'aac' => 'audio/aac',
        'm4a' => 'audio/mp4',
        _ => 'audio/mpeg',
      };
    }
    return 'application/octet-stream';
  }

  Duration get ttl => const Duration(hours: 24);

  Stream<T> _poll<T>(Future<T> Function() fetch, {Duration interval = const Duration(seconds: 3)}) async* {
    while (true) {
      try {
        yield await fetch();
      } catch (e) {
        // Keep the stream alive: schema cache / RLS / network hiccups shouldn't
        // permanently kill the UI.
        debugPrint('StatusService: poll error=$e');
      }
      await Future<void>.delayed(interval);
    }
  }

  Stream<List<StatusUpdate>> streamActiveStatuses() {
    return _poll(() async {
      final now = DateTime.now().toUtc().toIso8601String();
      final rows = await _client
          .from(table)
          .select('*')
          .gt('expires_at', now)
          .order('expires_at', ascending: false)
          .order('created_at', ascending: false)
          .limit(200);
      // `select()` retourne déjà une List<Map<String, dynamic>> ; le type
      // check et le cast explicites sont donc inutiles.
      return rows.map(StatusUpdate.fromRow).toList(growable: false);
    });
  }

  Stream<List<StatusUpdate>> streamMyActiveStatuses(String uid) {
    return _poll(() async {
      final now = DateTime.now().toUtc().toIso8601String();
      final rows = await _client
          .from(table)
          .select('*')
          .eq('uid', uid)
          .gt('expires_at', now)
          .order('expires_at', ascending: false)
          .order('created_at', ascending: false)
          .limit(200);
      return rows.map(StatusUpdate.fromRow).toList(growable: false);
    });
  }

  Future<void> postTextStatus({
    required String uid,
    required String displayName,
    required String thixId,
    required String text,
  }) async {
    try {
      final now = DateTime.now().toUtc();
      await _client.from(table).insert({
        'uid': uid,
        'display_name': displayName,
        'thix_id': thixId,
        'text': text,
        'status_type': 'text',
        'created_at': now.toIso8601String(),
        'expires_at': now.add(ttl).toIso8601String(),
      });
    } catch (e) {
      debugPrint('StatusService: postTextStatus failed uid=$uid err=$e');
      rethrow;
    }
  }

  Future<void> postMediaStatus({
    required String uid,
    required String displayName,
    required String thixId,
    required String statusType,
    required PlatformFile file,
    String? caption,
  }) async {
    if (!const {'photo', 'video', 'audio'}.contains(statusType)) {
      throw ArgumentError('Unsupported statusType: $statusType');
    }
    try {
      final now = DateTime.now().toUtc();
      final ts = now.millisecondsSinceEpoch;
      final ext = (file.extension ?? '').trim();
      final mime = _guessMime(statusType, ext);
      final safeExt = ext.isEmpty ? '' : '.${ext.toLowerCase()}';
      final path = 'statuses/$uid/$ts-${file.name.replaceAll(' ', '_')}$safeExt';

      String uploadPath;
      if (kIsWeb) {
        final bytes = file.bytes;
        if (bytes == null) throw Exception('Impossible de lire le fichier (web).');
        uploadPath = await _client.storage.from(mediaBucket).uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(contentType: mime),
            );
      } else {
        final p = file.path;
        if (p == null) throw Exception('Chemin fichier invalide.');
        uploadPath = await _client.storage.from(mediaBucket).upload(
              path,
              fileFromPath(p) as dynamic,
              fileOptions: FileOptions(contentType: mime),
            );
      }

      final publicUrl = _client.storage.from(mediaBucket).getPublicUrl(uploadPath);

      await _client.from(table).insert({
        'uid': uid,
        'display_name': displayName,
        'thix_id': thixId,
        'text': (caption ?? '').trim().isEmpty ? null : caption!.trim(),
        'status_type': statusType,
        'media_url': publicUrl,
        'media_mime': mime,
        'media_name': file.name,
        'media_size': file.size,
        'created_at': now.toIso8601String(),
        'expires_at': now.add(ttl).toIso8601String(),
      });
    } catch (e) {
      debugPrint('StatusService: postMediaStatus failed uid=$uid type=$statusType err=$e');
      rethrow;
    }
  }

  Future<void> deleteStatus(String statusId) async {
    try {
      await _client.from(table).delete().eq('id', statusId);
    } catch (e) {
      debugPrint('StatusService: deleteStatus failed id=$statusId err=$e');
      rethrow;
    }
  }

  Future<int> cleanupExpired({int limit = 50}) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final expired = await _client
          .from(table)
          .select('id')
          .lte('expires_at', now)
          .order('expires_at', ascending: true)
          .limit(limit);
      // `select()` retourne déjà une List<Map<String, dynamic>> ; le type
      // check et le cast explicites sont donc inutiles.
      var deleted = 0;
      for (final row in expired) {
        final id = row['id'] as String?;
        if (id == null) continue;
        await _client.from(table).delete().eq('id', id);
        deleted++;
      }
      return deleted;
    } catch (e) {
      debugPrint('StatusService: cleanupExpired failed err=$e');
      return 0;
    }
  }
}
