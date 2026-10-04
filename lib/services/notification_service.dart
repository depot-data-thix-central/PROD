// lib/services/notification_service.dart
/// Notification Service v2 — architecture SQL-first
/// - Stream temps réel (Realtime + fallback polling)
/// - Pop locale DÉLÉGUÉE à PushFcmService + NotifBannerHost (plus de double-pop)
/// - Exposition complète des nouveaux champs (category, route, priority, actor…)
/// - Helpers markRead / markAllRead / delete pour le hub
import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const Duration _kQueryTimeout = Duration(seconds: 15);
const Duration _kPollingInterval = Duration(seconds: 5);
const Duration _kMinRetryDelay = Duration(milliseconds: 500);
const Duration _kMaxRetryDelay = Duration(seconds: 8);
const int _kMaxRetries = 10;
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
    return RegExp(r'^[A-Za-z0-9_\-]+$').hasMatch(uid);
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

  static String sanitizeType(String? type) =>
      sanitizeString(type, maxLength: _kMaxTypeLength).toLowerCase();

  static String sanitizeCategory(String? c) {
    final v = sanitizeString(c, maxLength: 30).toLowerCase();
    return v.isEmpty ? 'system' : v;
  }

  static String? sanitizeRoute(String? r) {
    if (r == null) return null;
    final s = sanitizeString(r, maxLength: 200);
    if (s.isEmpty) return null;
    // Sécurité : bloquer tout sauf les routes internes relatives
    if (!s.startsWith('/')) return null;
    if (s.contains('..') || s.contains('javascript:') || s.contains('://')) return null;
    return s;
  }

  static int sanitizePriority(dynamic v) {
    if (v == null) return 0;
    final p = (v as num?)?.toInt() ?? 0;
    return p.clamp(0, 10);
  }
}

// ============================================================================
// LRU CACHE — évite les re-pops si Realtime re-émet
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

  /// Cache des IDs déjà traitées (évite les re-pops sur re-émission Realtime).
  /// 5000 entrées ≈ plusieurs jours d'historique par utilisateur.
  final _LRUCache<String> _processedIds = _LRUCache<String>(5000);

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

  /// ✅ Normalisation étendue avec tous les nouveaux champs SQL.
  /// C'est cette structure que consomment le Hub et le BannerHost.
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
    final category = _Validators.sanitizeCategory((r['category'] ?? 'system').toString());
    final route = _Validators.sanitizeRoute(r['route']?.toString());
    final priority = _Validators.sanitizePriority(r['priority']);

    return <String, dynamic>{
      'id': r['id']?.toString() ?? '',
      'user_id': r['user_id']?.toString() ?? '',
      'sender_id': r['sender_id']?.toString(),
      'actor_id': r['actor_id']?.toString() ?? r['sender_id']?.toString(),
      'type': type,
      'category': category,
      'entity_type': r['entity_type']?.toString(),
      'entity_id': r['entity_id']?.toString(),
      'title': title,
      'body': body,
      'route': route,
      'priority': priority,
      'read': read,
      'read_at': r['read_at']?.toString(),
      'push_sent': (r['push_sent'] as bool?) ?? false,
      'data': data,
      'created_at': r['created_at']?.toString(),
    };
  }

  // ========================================================================
  // PUBLIC API : STREAMS
  // ========================================================================

  /// Stream temps réel des notifications (Realtime + fallback polling).
  /// La pop locale / bannière est gérée par [NotifBannerHost] côté UI
  /// et par [PushFcmService] côté push — PAS par ce service.
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

        debugPrint('[NotifService] ✓ emitLatest: ${list.length} notifs '
            'for ${_Validators.maskUid(effectiveUid)}');

        if (firstLoad) {
          // Premier chargement : on peuple le cache pour éviter les re-pops
          firstLoad = false;
          for (final n in list) {
            final id = n['id']?.toString();
            if (id != null && id.isNotEmpty) _processedIds.add(id);
          }
        }

        if (!isCancelled) controller.add(list);
      } on TimeoutException {
        debugPrint('[NotifService] ⚠️ emitLatest timeout');
        if (!isCancelled) controller.add(const <Map<String, dynamic>>[]);
      } catch (e) {
        debugPrint('[NotifService] ❌ emitLatest failed: $e');
        if (!isCancelled) controller.add(const <Map<String, dynamic>>[]);
      }
    }

    void startPolling() {
      if (polling) return;
      polling = true;
      debugPrint('[NotifService] 🔄 Fallback polling for ${_Validators.maskUid(effectiveUid)}');
      pollTimer?.cancel();
      pollTimer = Timer.periodic(_kPollingInterval, (_) => unawaited(emitLatest()));
    }

    controller = StreamController<List<Map<String, dynamic>>>.broadcast(
      onListen: () => unawaited(emitLatest()),
      onCancel: () async {
        isCancelled = true;
        retryTimer?.cancel();
        pollTimer?.cancel();
        final ch = channel;
        if (ch != null) {
          try { await _client.removeChannel(ch); } catch (_) {}
        }
      },
    );

    Future<void> subscribeOrRetry() async {
      if (isCancelled || polling) return;
      retryTimer?.cancel();
      try { if (channel != null) await _client.removeChannel(channel!); } catch (_) {}

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
              callback: (_) => unawaited(emitLatest()),
            )
            .subscribe((status, [err]) {
              if (isCancelled) return;
              if (_isPermanentRealtimeError(status, err)) {
                startPolling(); return;
              }
              final shouldRetry = err != null || status == RealtimeSubscribeStatus.closed;
              if (!shouldRetry) { closedRetries = 0; return; }
              closedRetries = (closedRetries + 1).clamp(1, _kMaxRetries);
              final delayMs = (_kMinRetryDelay.inMilliseconds * (1 << (closedRetries - 1)))
                  .clamp(_kMinRetryDelay.inMilliseconds, _kMaxRetryDelay.inMilliseconds);
              if (closedRetries >= _kMaxRetries) { startPolling(); return; }
              retryTimer?.cancel();
              retryTimer = Timer(Duration(milliseconds: delayMs),
                  () => unawaited(subscribeOrRetry()));
            });
      } catch (e) {
        startPolling();
      }
    }

    unawaited(subscribeOrRetry());
    return controller.stream;
  }

  /// Stream du nombre de notifications non lues (pour la cloche du header).
  Stream<int> streamUnreadCount(String uid) {
    return streamForUser(uid)
        .map((rows) => rows.where((r) => (r['read'] as bool?) != true).length)
        .distinct();
  }

  // ========================================================================
  // PUBLIC API : MUTATIONS
  // ========================================================================

  /// ⚠️ Insertion DIRECTE en DB — À ÉVITER sauf pour événements hors-DB.
  /// Pour 95% des cas, utilise les TRIGGERS SQL (likes, comments, orders…)
  /// ou la RPC `notify_event` (appels, SOS, live).
  Future<bool> add({
    required String toUid,
    required String type,
    required String title,
    required String body,
    String category = 'system',
    String? senderId,
    String? postId,
    String? route,
    int priority = 0,
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
      debugPrint('[NotifService] ⚠️ add: empty type');
      return false;
    }

    final sanitizedTitle = _Validators.sanitizeString(title, maxLength: _kMaxTitleLength);
    if (sanitizedTitle.isEmpty) {
      debugPrint('[NotifService] ⚠️ add: empty title');
      return false;
    }

    final sanitizedBody = _Validators.sanitizeString(body, maxLength: _kMaxBodyLength);
    final sanitizedCategory = _Validators.sanitizeCategory(category);
    final sanitizedRoute = _Validators.sanitizeRoute(route);

    try {
      await _client
          .from(_table)
          .insert({
            'user_id': toUid,
            'sender_id': senderId,
            'actor_id': senderId,
            'post_id': postId,
            'type': sanitizedType,
            'category': sanitizedCategory,
            'title': sanitizedTitle,
            'body': sanitizedBody,
            'content': sanitizedBody,
            'route': sanitizedRoute,
            'priority': priority,
            'is_read': false,
            'push_sent': false,
            'data': data ?? const <String, dynamic>{},
            'created_at': DateTime.now().toUtc().toIso8601String(),
          })
          .timeout(_kQueryTimeout);

      debugPrint('[NotifService] ✓ Notification added: type=$sanitizedType '
          'category=$sanitizedCategory to=${_Validators.maskUid(toUid)}');
      return true;
    } on TimeoutException {
      debugPrint('[NotifService] ❌ add: timeout');
      return false;
    } catch (e) {
      debugPrint('[NotifService] ❌ add failed: $e');
      return false;
    }
  }

  /// Marque une notification comme lue.
  Future<bool> markRead({
    required String uid,
    required String notificationId,
  }) async {
    if (!_Validators.isValidUid(uid)) return false;
    if (!_Validators.isValidNotificationId(notificationId)) return false;

    try {
      await _client
          .from(_table)
          .update({
            'is_read': true,
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', notificationId)
          .eq('user_id', uid)
          .timeout(_kQueryTimeout);

      debugPrint('[NotifService] ✓ Marked as read: $notificationId '
          'user=${_Validators.maskUid(uid)}');
      return true;
    } on TimeoutException {
      debugPrint('[NotifService] ❌ markRead: timeout');
      return false;
    } catch (e) {
      debugPrint('[NotifService] ❌ markRead failed: $e');
      return false;
    }
  }

  /// Marque TOUTES les notifications comme lues (hub → "Tout lire").
  Future<bool> markAllRead(String uid) async {
    if (!_Validators.isValidUid(uid)) return false;
    try {
      await _client
          .from(_table)
          .update({
            'is_read': true,
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('user_id', uid)
          .eq('is_read', false)
          .timeout(_kQueryTimeout);
      debugPrint('[NotifService] ✓ Marked all as read: ${_Validators.maskUid(uid)}');
      return true;
    } on TimeoutException {
      debugPrint('[NotifService] ❌ markAllRead: timeout');
      return false;
    } catch (e) {
      debugPrint('[NotifService] ❌ markAllRead failed: $e');
      return false;
    }
  }

  /// Supprime une notification (hub → swipe-to-delete).
  Future<bool> delete({
    required String uid,
    required String notificationId,
  }) async {
    if (!_Validators.isValidUid(uid)) return false;
    if (!_Validators.isValidNotificationId(notificationId)) return false;
    try {
      await _client
          .from(_table)
          .delete()
          .eq('id', notificationId)
          .eq('user_id', uid)
          .timeout(_kQueryTimeout);
      debugPrint('[NotifService] ✓ Deleted: $notificationId');
      return true;
    } on TimeoutException {
      debugPrint('[NotifService] ❌ delete: timeout');
      return false;
    } catch (e) {
      debugPrint('[NotifService] ❌ delete failed: $e');
      return false;
    }
  }

  /// Supprime TOUTES les notifications (hub → "Effacer l'historique").
  Future<bool> deleteAll(String uid) async {
    if (!_Validators.isValidUid(uid)) return false;
    try {
      await _client
          .from(_table)
          .delete()
          .eq('user_id', uid)
          .timeout(_kQueryTimeout);
      debugPrint('[NotifService] ✓ Deleted all for ${_Validators.maskUid(uid)}');
      return true;
    } on TimeoutException {
      debugPrint('[NotifService] ❌ deleteAll: timeout');
      return false;
    } catch (e) {
      debugPrint('[NotifService] ❌ deleteAll failed: $e');
      return false;
    }
  }

  /// ✅ Helper : marque comme lue + retourne la route pour deep-link.
  /// À appeler depuis le hub quand on tape sur une notification.
  Future<String?> openNotification({
    required String uid,
    required String notificationId,
  }) async {
    if (!_Validators.isValidUid(uid)) return null;
    if (!_Validators.isValidNotificationId(notificationId)) return null;

    try {
      final row = await _client
          .from(_table)
          .select('route')
          .eq('id', notificationId)
          .eq('user_id', uid)
          .maybeSingle()
          .timeout(_kQueryTimeout);

      if (row == null) return null;

      // Marquer comme lue (non-bloquant, best-effort)
      unawaited(markRead(uid: uid, notificationId: notificationId));

      return _Validators.sanitizeRoute(row['route']?.toString());
    } catch (e) {
      debugPrint('[NotifService] ❌ openNotification failed: $e');
      return null;
    }
  }

  /// Marque comme lues toutes les notifications d'une catégorie donnée.
  /// Utile pour "Voir tout" dans un onglet du hub.
  Future<bool> markCategoryRead({
    required String uid,
    required String category,
  }) async {
    if (!_Validators.isValidUid(uid)) return false;
    final sanitizedCategory = _Validators.sanitizeCategory(category);
    try {
      await _client
          .from(_table)
          .update({
            'is_read': true,
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('user_id', uid)
          .eq('is_read', false)
          .eq('category', sanitizedCategory)
          .timeout(_kQueryTimeout);
      debugPrint('[NotifService] ✓ Marked category $sanitizedCategory as read');
      return true;
    } on TimeoutException {
      debugPrint('[NotifService] ❌ markCategoryRead: timeout');
      return false;
    } catch (e) {
      debugPrint('[NotifService] ❌ markCategoryRead failed: $e');
      return false;
    }
  }

  /// Retourne le nombre de notifications non lues (one-shot, non réactif).
  Future<int> fetchUnreadCount(String uid) async {
    if (!_Validators.isValidUid(uid)) return 0;
    try {
      final res = await _client
          .from(_table)
          .select('id', head: true, count: CountOption.exact)
          .eq('user_id', uid)
          .eq('is_read', false)
          .timeout(_kQueryTimeout);
      return res.count ?? 0;
    } catch (e) {
      debugPrint('[NotifService] ❌ fetchUnreadCount failed: $e');
      return 0;
    }
  }
}
