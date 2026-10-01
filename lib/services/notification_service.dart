/// Notification Service
/// - Stream temps réel des notifications (Realtime + fallback polling)
/// - Pop locale UNIQUEMENT pour les notifications reçues par l'utilisateur connecté
/// - Ajout / marquage de notifications
import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/services/local_notification_service.dart';
import 'package:thix_id/supabase/supabase_config.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const Duration _kQueryTimeout = Duration(seconds: 15);
const Duration _kPollingInterval = Duration(seconds: 5);
const Duration _kMinRetryDelay = Duration(milliseconds: 500);
const Duration _kMaxRetryDelay = Duration(seconds: 8);
const Duration _kPopMaxAge = Duration(minutes: 2);
const int _kMaxRetries = 10;
const int _kMaxShownPopIds = 100;
const int _kMaxPopsPerRefresh = 3;
const int _kMaxNotificationsPerQuery = 50;
const int _kMinUidLength = 20;
const int _kMaxUidLength = 64;
const int _kMaxTitleLength = 100;
const int _kMaxBodyLength = 500;
const int _kMaxTypeLength = 50;
const int _kMaxNotificationIdLength = 64;

// ============================================================================
// VALIDATORS & SANITIZERS
// ============================================================================

class _Validators {
  _Validators._();

  static bool isValidUid(String? uid) {
    if (uid == null || uid.isEmpty) return false;
    if (uid.length < _kMinUidLength || uid.length > _kMaxUidLength) return false;
    final regex = RegExp(r'^[A-Za-z0-9_\-]+$');
    return regex.hasMatch(uid);
  }

  static bool isValidNotificationId(String? id) {
    if (id == null || id.isEmpty) return false;
    if (id.length > _kMaxNotificationIdLength) return false;
    return true;
  }

  static String maskUid(String uid) {
    if (uid.length <= 8) return '***';
    return '${uid.substring(0, 4)}...${uid.substring(uid.length - 3)}';
  }

  static String sanitizeString(String? input, {required int maxLength}) {
    if (input == null) return '';
    final s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static String sanitizeType(String? type) {
    return sanitizeString(type, maxLength: _kMaxTypeLength).toLowerCase();
  }
}

// ============================================================================
// LRU CACHE
// ============================================================================

class _LRUCache<K> {
  final int maxSize;
  final LinkedHashMap<K, DateTime> _map = LinkedHashMap<K, DateTime>();

  _LRUCache(this.maxSize);

  bool contains(K key) {
    if (!_map.containsKey(key)) return false;
    final value = _map.remove(key)!;
    _map[key] = value;
    return true;
  }

  void add(K key) {
    if (_map.containsKey(key)) {
      _map.remove(key);
    } else if (_map.length >= maxSize) {
      _map.remove(_map.keys.first);
    }
    _map[key] = DateTime.now();
  }

  int get length => _map.length;
}

// ============================================================================
// SERVICE
// ============================================================================

class NotificationService {
  final SupabaseClient _client;

  NotificationService({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  static const String _table = 'notifications';

  final _LRUCache<String> _shownPopIds = _LRUCache<String>(_kMaxShownPopIds);

  // ========================================================================
  // PRIVATE HELPERS
  // ========================================================================

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
    final data = (r['data'] is Map)
        ? Map<String, dynamic>.from(r['data'] as Map)
        : <String, dynamic>{};

    final read = (r['is_read'] as bool?) ?? false;
    final body = _Validators.sanitizeString(
      (r['body'] ?? r['content'] ?? '').toString(),
      maxLength: _kMaxBodyLength,
    );
    final title = _Validators.sanitizeString(
      (r['title'] ?? 'Notification').toString(),
      maxLength: _kMaxTitleLength,
    );
    final type = _Validators.sanitizeType((r['type'] ?? 'generic').toString());

    return <String, dynamic>{
      'id': r['id']?.toString() ?? '',
      'user_id': r['user_id']?.toString() ?? '',
      'sender_id': r['sender_id']?.toString(),
      'post_id': r['post_id']?.toString(),
      'type': type,
      'title': title,
      'body': body,
      'read': read,
      'data': data,
      'created_at': r['created_at'],
    };
  }

  int _generateLocalNotificationId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return now % 100000;
  }

  bool _isRecent(Map<String, dynamic> notif) {
    final raw = notif['created_at'];
    final created = raw == null ? null : DateTime.tryParse(raw.toString());
    if (created == null) return false;
    return DateTime.now().toUtc().difference(created.toUtc()) <= _kPopMaxAge;
  }

  /// Pop locale pour une notification REÇUE par l'utilisateur connecté.
  Future<void> _maybeShowPop(Map<String, dynamic> notif) async {
    final id = notif['id']?.toString();
    if (id == null || id.isEmpty) {
      debugPrint('[NotifService] ⚠️ _maybeShowPop: invalid notification ID');
      return;
    }
    if (notif['read'] == true) return;
    if (_shownPopIds.contains(id)) return;

    // Une notification ancienne (ex. non lue depuis hier) n'ouvre pas de pop
    if (!_isRecent(notif)) {
      _shownPopIds.add(id);
      return;
    }

    _shownPopIds.add(id);

    try {
      final title = _Validators.sanitizeString(
        notif['title']?.toString() ?? 'THIX ID',
        maxLength: _kMaxTitleLength,
      );
      final body = _Validators.sanitizeString(
        notif['body']?.toString() ?? '',
        maxLength: _kMaxBodyLength,
      );

      await LocalNotificationService.instance.show(
        id: _generateLocalNotificationId(),
        title: title,
        body: body,
        payload: id,
      );
      debugPrint('[NotifService] ✓ Pop shown for notification $id');
    } catch (e) {
      debugPrint('[NotifService] ❌ Failed to show pop: $e');
    }
  }

  // ========================================================================
  // PUBLIC API : STREAMS
  // ========================================================================

  Stream<List<Map<String, dynamic>>> streamForUser(String uid) {
    if (!_Validators.isValidUid(uid)) {
      debugPrint('[NotifService] ⚠️ Invalid UID, returning empty stream');
      return Stream<List<Map<String, dynamic>>>.value(const []);
    }

    final authUid = _client.auth.currentUser?.id;
    final effectiveUid = (authUid != null && authUid != uid) ? authUid : uid;

    if (authUid != null && authUid != uid) {
      debugPrint('[NotifService] ⚠️ UID mismatch: param=${_Validators.maskUid(uid)} '
          'auth=${_Validators.maskUid(authUid)}, using auth');
    }

    debugPrint('[NotifService] 🚀 Starting stream for ${_Validators.maskUid(effectiveUid)}');

    late final StreamController<List<Map<String, dynamic>>> controller;
    RealtimeChannel? channel;
    var closedRetries = 0;
    Timer? retryTimer;
    var isCancelled = false;
    Timer? pollTimer;
    var polling = false;
    var firstLoad = true;

    Future<void> emitLatest() async {
      if (isCancelled) return;

      try {
        final rows = await _client
            .from(_table)
            .select('*')
            .eq('user_id', effectiveUid)
            .order('created_at', ascending: false)
            .limit(_kMaxNotificationsPerQuery)
            .timeout(_kQueryTimeout);

        final list = rows.map((e) => _normalizeRow(e)).toList(growable: false);

        debugPrint('[NotifService] ✓ emitLatest: ${list.length} notifications '
            'for ${_Validators.maskUid(effectiveUid)}');

        if (firstLoad) {
          // Chargement initial : on mémorise sans afficher de pop
          firstLoad = false;
          for (final n in list) {
            final id = n['id']?.toString();
            if (id != null && id.isNotEmpty) _shownPopIds.add(id);
          }
        } else {
          for (final n in list.take(_kMaxPopsPerRefresh)) {
            unawaited(_maybeShowPop(n));
          }
        }

        if (!isCancelled) {
          controller.add(list);
        }
      } on TimeoutException {
        debugPrint('[NotifService] ⚠️ emitLatest timeout for '
            '${_Validators.maskUid(effectiveUid)}');
        if (!isCancelled) controller.add(const <Map<String, dynamic>>[]);
      } catch (e) {
        debugPrint('[NotifService] ❌ emitLatest failed: $e');
        if (!isCancelled) controller.add(const <Map<String, dynamic>>[]);
      }
    }

    void startPolling() {
      if (polling) return;
      polling = true;
      debugPrint('[NotifService] 🔄 Fallback polling started for '
          '${_Validators.maskUid(effectiveUid)}');
      pollTimer?.cancel();
      pollTimer = Timer.periodic(_kPollingInterval, (_) => unawaited(emitLatest()));
    }

    controller = StreamController<List<Map<String, dynamic>>>.broadcast(
      onListen: () => unawaited(emitLatest()),
      onCancel: () async {
        isCancelled = true;
        debugPrint('[NotifService] 🛑 Stream cancelled for '
            '${_Validators.maskUid(effectiveUid)}');
        retryTimer?.cancel();
        pollTimer?.cancel();
        final ch = channel;
        if (ch != null) {
          try {
            await _client.removeChannel(ch);
          } catch (e) {
            debugPrint('[NotifService] ⚠️ Failed to remove channel: $e');
          }
        }
      },
    );

    Future<void> subscribeOrRetry() async {
      if (isCancelled || polling) return;
      retryTimer?.cancel();

      try {
        if (channel != null) await _client.removeChannel(channel!);
      } catch (e) {
        debugPrint('[NotifService] ⚠️ Failed to remove old channel: $e');
      }

      channel = _client.channel('notifications:user:$effectiveUid');
      try {
        channel!
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: _table,
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: effectiveUid,
              ),
              callback: (payload) {
                debugPrint('[NotifService] ✓ Realtime change detected');
                unawaited(emitLatest());
              },
            )
            .subscribe((status, [err]) {
              if (isCancelled) return;

              debugPrint('[NotifService] ℹ️ Subscribe status: $status');

              if (_isPermanentRealtimeError(status, err)) {
                debugPrint('[NotifService] ❌ Permanent error, starting polling');
                startPolling();
                return;
              }

              final shouldRetry = err != null || status == RealtimeSubscribeStatus.closed;
              if (!shouldRetry) {
                debugPrint('[NotifService] ✓ Realtime connected for '
                    '${_Validators.maskUid(effectiveUid)}');
                closedRetries = 0;
                return;
              }

              closedRetries = (closedRetries + 1).clamp(1, _kMaxRetries);
              final delayMs = (_kMinRetryDelay.inMilliseconds * (1 << (closedRetries - 1)))
                  .clamp(_kMinRetryDelay.inMilliseconds, _kMaxRetryDelay.inMilliseconds);

              debugPrint('[NotifService] ⏱️ Retry $closedRetries/$_kMaxRetries '
                  'in ${delayMs}ms');

              if (closedRetries >= _kMaxRetries) {
                debugPrint('[NotifService] ❌ Max retries reached, '
                    'fallback to polling');
                startPolling();
                return;
              }

              retryTimer?.cancel();
              retryTimer = Timer(Duration(milliseconds: delayMs), () {
                unawaited(subscribeOrRetry());
              });
            });
      } catch (e) {
        debugPrint('[NotifService] ❌ Realtime wiring failed: $e');
        startPolling();
      }
    }

    unawaited(subscribeOrRetry());

    return controller.stream;
  }

  Stream<int> streamUnreadCount(String uid) {
    return streamForUser(uid)
        .map((rows) => rows.where((r) => (r['read'] as bool?) != true).length)
        .distinct();
  }

  // ========================================================================
  // PUBLIC API : MUTATIONS
  // ========================================================================

  /// Insère une notification pour [toUid].
  /// Aucune pop locale ici : le destinataire la reçoit via son propre stream
  /// (ou le push FCM). Avant, la pop s'affichait sur le téléphone de l'expéditeur.
  Future<bool> add({
    required String toUid,
    required String type,
    required String title,
    required String body,
    String? senderId,
    String? postId,
    Map<String, dynamic>? data,
  }) async {
    if (!_Validators.isValidUid(toUid)) {
      debugPrint('[NotifService] ⚠️ add: invalid toUid');
      return false;
    }
    if (senderId != null && !_Validators.isValidUid(senderId)) {
      debugPrint('[NotifService] ⚠️ add: invalid senderId');
      return false;
    }

    final sanitizedType = _Validators.sanitizeType(type);
    if (sanitizedType.isEmpty) {
      debugPrint('[NotifService] ⚠️ add: empty type after sanitization');
      return false;
    }

    final sanitizedTitle = _Validators.sanitizeString(title, maxLength: _kMaxTitleLength);
    if (sanitizedTitle.isEmpty) {
      debugPrint('[NotifService] ⚠️ add: empty title after sanitization');
      return false;
    }

    final sanitizedBody = _Validators.sanitizeString(body, maxLength: _kMaxBodyLength);

    try {
      await _client
          .from(_table)
          .insert({
            'user_id': toUid,
            'sender_id': senderId,
            'post_id': postId,
            'type': sanitizedType,
            'title': sanitizedTitle,
            'body': sanitizedBody,
            'content': sanitizedBody,
            'is_read': false,
            'data': data ?? const <String, dynamic>{},
            'created_at': DateTime.now().toUtc().toIso8601String(),
          })
          .timeout(_kQueryTimeout);

      debugPrint('[NotifService] ✓ Notification added: type=$sanitizedType '
          'to=${_Validators.maskUid(toUid)}');

      return true;
    } on TimeoutException {
      debugPrint('[NotifService] ❌ add: timeout');
      return false;
    } catch (e) {
      debugPrint('[NotifService] ❌ add failed: $e');
      return false;
    }
  }

  Future<bool> markRead({
    required String uid,
    required String notificationId,
  }) async {
    if (!_Validators.isValidUid(uid)) {
      debugPrint('[NotifService] ⚠️ markRead: invalid uid');
      return false;
    }
    if (!_Validators.isValidNotificationId(notificationId)) {
      debugPrint('[NotifService] ⚠️ markRead: invalid notificationId');
      return false;
    }

    try {
      await _client
          .from(_table)
          .update({'is_read': true})
          .eq('id', notificationId)
          .eq('user_id', uid)
          .timeout(_kQueryTimeout);

      debugPrint('[NotifService] ✓ Marked as read: '
          'notification=$notificationId user=${_Validators.maskUid(uid)}');
      return true;
    } on TimeoutException {
      debugPrint('[NotifService] ❌ markRead: timeout');
      return false;
    } catch (e) {
      debugPrint('[NotifService] ❌ markRead failed: $e');
      return false;
    }
  }

  Future<bool> markAllRead(String uid) async {
    if (!_Validators.isValidUid(uid)) {
      debugPrint('[NotifService] ⚠️ markAllRead: invalid uid');
      return false;
    }

    try {
      await _client
          .from(_table)
          .update({'is_read': true})
          .eq('user_id', uid)
          .eq('is_read', false)
          .timeout(_kQueryTimeout);

      debugPrint('[NotifService] ✓ Marked all as read for '
          '${_Validators.maskUid(uid)}');
      return true;
    } on TimeoutException {
      debugPrint('[NotifService] ❌ markAllRead: timeout');
      return false;
    } catch (e) {
      debugPrint('[NotifService] ❌ markAllRead failed: $e');
      return false;
    }
  }
}
