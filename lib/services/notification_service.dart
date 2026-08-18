// lib/services/notification_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';
import 'package:thix_id/services/local_notification_service.dart';
import 'dart:async';

class NotificationService {
  final SupabaseClient _client;
  NotificationService({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  static const String _table = 'notifications';

  final Set<String> _shownPopIds = {};

  static bool _isPermanentRealtimeError(RealtimeSubscribeStatus status, Object? err) {
    if (status == RealtimeSubscribeStatus.channelError) return true;
    final msg = (err ?? '').toString().toLowerCase();
    if (msg.contains('permission denied')) return true;
    if (msg.contains('rls')) return true;
    if (msg.contains('relation') && msg.contains('does not exist')) return true;
    if (msg.contains('schema cache')) return true;
    return false;
  }

  Map<String, dynamic> _normalizeRow(Map<String, dynamic> r) {
    final data = (r['data'] is Map) ? (r['data'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    final read = (r['is_read'] as bool?) ?? false;
    final body = (r['body'] ?? r['content'] ?? '').toString();
    return <String, dynamic>{
      'id': r['id'],
      'user_id': r['user_id'],
      'sender_id': r['sender_id'],
      'post_id': r['post_id'],
      'type': (r['type'] ?? 'generic').toString(),
      'title': (r['title'] ?? 'Notification').toString(),
      'body': body,
      'read': read,
      'data': data,
      'created_at': r['created_at'],
    };
  }

  Future<void> _maybeShowPop(Map<String, dynamic> notif) async {
    final id = notif['id']?.toString();
    if (id == null) return;
    if (notif['read'] == true) return;
    if (_shownPopIds.contains(id)) return;

    _shownPopIds.add(id);
    if (_shownPopIds.length > 100) {
      _shownPopIds.remove(_shownPopIds.first);
    }

    try {
      await LocalNotificationService.instance.show(
        id: id.hashCode,
        title: notif['title'] ?? 'THIX ID',
        body: notif['body'] ?? '',
        payload: id,
      );
    } catch (e) {
      debugPrint('NotificationService: failed to show pop → $e');
    }
  }

  Stream<List<Map<String, dynamic>>> streamForUser(String uid) {
    late final StreamController<List<Map<String, dynamic>>> controller;
    final authUid = _client.auth.currentUser?.id;
    if (authUid != null && authUid != uid) {
      debugPrint('NotificationService: streamForUser uid mismatch. param=$uid auth=$authUid; using auth uid.');
      uid = authUid;
    }

    RealtimeChannel? channel;
    var closedRetries = 0;
    Timer? retryTimer;
    var isCancelled = false;
    Timer? pollTimer;
    var polling = false;

    Future<void> emitLatest() async {
      try {
        final rows = await _client
            .from(_table)
            .select('*')
            .eq('user_id', uid)
            .order('created_at', ascending: false)
            .limit(50);

        final list = rows.map((e) => _normalizeRow(e)).toList(growable: false);

        debugPrint('NotificationService: emitLatest ok uid=$uid count=${list.length}');

        if (list.isNotEmpty) {
          unawaited(_maybeShowPop(list.first));
        }

        controller.add(list);
      } catch (e) {
        debugPrint('NotificationService: emitLatest failed uid=$uid err=$e');
        controller.add(const <Map<String, dynamic>>[]);
      }
    }

    void startPolling() {
      if (polling) return;
      polling = true;
      debugPrint('NotificationService: switching to polling fallback uid=$uid');
      pollTimer?.cancel();
      pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => unawaited(emitLatest()));
    }

    controller = StreamController<List<Map<String, dynamic>>>.broadcast(
      onListen: () {
        unawaited(emitLatest());
      },
    );

    Future<void> subscribeOrRetry() async {
      if (isCancelled) return;
      retryTimer?.cancel();
      if (polling) return;

      try {
        if (channel != null) await _client.removeChannel(channel!);
      } catch (_) {}

      channel = _client.channel('notifications:user:$uid');
      try {
        channel!
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: _table,
              filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
              callback: (payload) {
                debugPrint('NotificationService: realtime change uid=$uid table=${payload.table}');
                unawaited(emitLatest());
              },
            )
            .subscribe((status, [err]) {
              debugPrint('NotificationService: subscribe status=$status err=$err uid=$uid');
              if (isCancelled) return;

              if (_isPermanentRealtimeError(status, err)) {
                startPolling();
                return;
              }

              final shouldRetry = err != null || status == RealtimeSubscribeStatus.closed;
              if (!shouldRetry) {
                closedRetries = 0;
                return;
              }

              closedRetries = (closedRetries + 1).clamp(1, 10);
              final delayMs = (500 * (1 << (closedRetries - 1))).clamp(500, 8000);
              retryTimer?.cancel();
              retryTimer = Timer(Duration(milliseconds: delayMs), () {
                debugPrint('NotificationService: retry subscribe (attempt=$closedRetries, delay=${delayMs}ms) uid=$uid');
                unawaited(subscribeOrRetry());
              });
            });
      } catch (e) {
        debugPrint('NotificationService: realtime wiring failed, falling back to polling. err=$e');
        startPolling();
      }
    }

    unawaited(subscribeOrRetry());

    controller.onCancel = () async {
      isCancelled = true;
      retryTimer?.cancel();
      pollTimer?.cancel();
      final ch = channel;
      if (ch != null) await _client.removeChannel(ch);
    };

    return controller.stream;
  }

  Stream<int> streamUnreadCount(String uid) {
    return streamForUser(uid)
        .map((rows) => rows.where((r) => (r['read'] as bool?) != true).length)
        .distinct();
  }

  /// Ajoute une notification + affiche immédiatement une pop.
  /// [senderId] et [postId] sont optionnels — utilisés par les
  /// notifications sociales THIX PRO (like, commentaire, etc.)
  Future<void> add({
    required String toUid,
    required String type,
    required String title,
    required String body,
    String? senderId,
    String? postId,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _client.from(_table).insert({
        'user_id': toUid,
        'sender_id': senderId,
        'post_id': postId,
        'type': type,
        'title': title,
        'body': body,
        'content': body, // maintenu pour compatibilité avec le code existant lisant 'content'
        'is_read': false,
        'data': data ?? const <String, dynamic>{},
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      await LocalNotificationService.instance.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: title,
        body: body,
        payload: type,
      );
    } catch (e) {
      debugPrint('NotificationService: add failed to=$toUid type=$type err=$e');
      rethrow;
    }
  }

  Future<void> markRead({required String uid, required String notificationId}) async {
    try {
      await _client
          .from(_table)
          .update({'is_read': true})
          .eq('id', notificationId)
          .eq('user_id', uid);
    } catch (e) {
      debugPrint('NotificationService: markRead failed uid=$uid id=$notificationId err=$e');
    }
  }

  Future<void> markAllRead(String uid) async {
    try {
      await _client.from(_table).update({'is_read': true}).eq('user_id', uid).eq('is_read', false);
    } catch (e) {
      debugPrint('NotificationService: markAllRead failed uid=$uid err=$e');
    }
  }
}
