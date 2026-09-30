import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';

class ThixPresence {
  final String userId;
  final bool isOnline;
  final DateTime lastSeenAt;

  const ThixPresence({required this.userId, required this.isOnline, required this.lastSeenAt});

  static DateTime _dt(Object? v) {
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now().toUtc();
    return DateTime.now().toUtc();
  }

  static ThixPresence fromRow(Map<String, dynamic> row) => ThixPresence(
        userId: (row['user_id'] as String?) ?? '',
        isOnline: (row['is_online'] as bool?) ?? false,
        lastSeenAt: _dt(row['last_seen_at'] ?? row['updated_at']),
      );
}

class _Watch {
  final StreamController<ThixPresence?> controller =
      StreamController<ThixPresence?>.broadcast();
  Timer? timer;
  ThixPresence? last;
  bool hasValue = false;
  bool busy = false;
}

class PresenceService {
  static const String table = 'thix_presence';
  static const Duration pollInterval = Duration(seconds: 10);

  final SupabaseClient _client;
  PresenceService({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  Timer? _heartbeat;
  bool? _lastOnlineSent;
  DateTime? _lastSentAt;

  // Partagé entre toutes les instances : un seul polling par utilisateur.
  static final Map<String, _Watch> _watches = {};
  static DateTime? _lastSchemaReload;

  bool _isTableMissing(Object e) {
    if (e is PostgrestException) {
      if (e.code == 'PGRST205') return true;
      final m = e.message.toLowerCase();
      if (m.contains('could not find the') && m.contains('in the schema cache')) return true;
      if (m.contains('relation') && m.contains('does not exist')) return true;
    }
    final m = e.toString().toLowerCase();
    return (m.contains('pgrst205') || (m.contains('relation') && m.contains('does not exist')));
  }

  Future<void> _trySchemaReload() async {
    // Au plus une tentative toutes les 5 minutes.
    final now = DateTime.now();
    if (_lastSchemaReload != null &&
        now.difference(_lastSchemaReload!) < const Duration(minutes: 5)) {
      return;
    }
    _lastSchemaReload = now;
    try {
      await _client.rpc('pgrst_schema_reload');
    } catch (e) {
      try {
        await _client.functions.invoke('pgrst_schema_reload', body: const {});
      } catch (_) {}
    }
  }

  Future<void> setOnline(bool online) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;

    // Évite les écritures inutiles : même statut envoyé il y a moins de 25 s.
    final nowLocal = DateTime.now();
    if (_lastOnlineSent == online &&
        _lastSentAt != null &&
        nowLocal.difference(_lastSentAt!) < const Duration(seconds: 25)) {
      return;
    }

    final now = nowLocal.toUtc().toIso8601String();
    try {
      await _client.from(table).upsert({
        'user_id': uid,
        'is_online': online,
        'last_seen_at': now,
        'updated_at': now,
      });
      _lastOnlineSent = online;
      _lastSentAt = nowLocal;
    } catch (e) {
      if (_isTableMissing(e)) {
        debugPrint('PresenceService: table missing/cache stale. err=$e');
        await _trySchemaReload();
        return;
      }
      debugPrint('PresenceService: setOnline failed online=$online err=$e');
    }
  }

  void startHeartbeat({Duration interval = const Duration(seconds: 30)}) {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(interval, (_) => unawaited(setOnline(true)));
  }

  void stopHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  Future<void> _poll(String userId, _Watch w) async {
    if (w.busy || w.controller.isClosed) return;
    w.busy = true;
    ThixPresence? value;
    try {
      final row = await _client.from(table).select('*').eq('user_id', userId).maybeSingle();
      value = row == null ? null : ThixPresence.fromRow(Map<String, dynamic>.from(row));
    } catch (e) {
      if (_isTableMissing(e)) {
        debugPrint('PresenceService: table missing/cache stale. err=$e');
        unawaited(_trySchemaReload());
      } else {
        debugPrint('PresenceService: poll failed userId=$userId err=$e');
      }
      value = null;
    } finally {
      w.busy = false;
    }

    if (w.controller.isClosed) return;
    final changed = !w.hasValue ||
        (value?.isOnline != w.last?.isOnline) ||
        (value?.lastSeenAt != w.last?.lastSeenAt) ||
        ((value == null) != (w.last == null));
    if (changed) {
      w.hasValue = true;
      w.last = value;
      w.controller.add(value);
    }
  }

  /// Stream de présence par polling (sans Realtime), partagé par utilisateur.
  Stream<ThixPresence?> streamPresence(String userId) {
    final existing = _watches[userId];
    if (existing != null) return existing.controller.stream;

    final w = _Watch();
    _watches[userId] = w;

    w.controller.onListen = () {
      if (w.hasValue) {
        final cached = w.last;
        Future.microtask(() {
          if (!w.controller.isClosed) w.controller.add(cached);
        });
      }
      unawaited(_poll(userId, w));
      w.timer?.cancel();
      w.timer = Timer.periodic(pollInterval, (_) => unawaited(_poll(userId, w)));
    };

    // Appelé uniquement quand le dernier écouteur se désabonne.
    w.controller.onCancel = () {
      w.timer?.cancel();
      w.timer = null;
      _watches.remove(userId);
      w.controller.close();
    };

    return w.controller.stream;
  }
}
