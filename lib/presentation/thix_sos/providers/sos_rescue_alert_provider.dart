
// lib/presentation/thix_sos/providers/sos_rescue_alert_provider.dart
/// THIX SOS — Provider alertes secours cercle 1 (Production Enterprise)
/// ✅ SÉCURISÉ : autoDispose, removeChannel, timeouts, retry, mounted guards
/// ✅ ROBUSTE : validation IDs/dates, logs structurés, throttle realtime
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kQueryTimeout = Duration(seconds: 15);
const Duration _kBootstrapTimeout = Duration(seconds: 30);
const Duration _kAuthThrottle = Duration(seconds: 2);
const Duration _kRealtimeThrottle = Duration(milliseconds: 500);
const int _kMaxHistoryEvents = 10;
const int _kMaxRetries = 1;
const Duration _kRetryDelay = Duration(milliseconds: 600);

// ============================================================================
// MODEL
// ============================================================================
/// SOS actif dont l'utilisateur courant est secours cercle 1.
class RescueAlert {
  final String incidentId;
  final String victimId;
  final String publicId;
  final String? conversationId;
  final String? victimName;
  final DateTime startedAt;

  const RescueAlert({
    required this.incidentId,
    required this.victimId,
    required this.publicId,
    this.conversationId,
    this.victimName,
    required this.startedAt,
  });

  /// ✅ Égalité par ID pour éviter les rebuilds inutiles
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RescueAlert &&
          runtimeType == other.runtimeType &&
          incidentId == other.incidentId;

  @override
  int get hashCode => incidentId.hashCode;
}

// ============================================================================
// VALIDATORS
// ============================================================================
class _AlertValidators {
  _AlertValidators._();

  static bool isValidId(String? id) {
    if (id == null) return false;
    final trimmed = id.trim();
    return trimmed.isNotEmpty && trimmed.length <= 64;
  }

  static List<String> safeCircleList(dynamic raw) {
    if (raw == null) return const <String>[];
    if (raw is! List) return const <String>[];
    return raw
        .where((e) => e != null)
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static DateTime safeDateTime(dynamic raw, {DateTime? fallback}) {
    if (raw == null) return fallback ?? DateTime.now();
    final parsed = DateTime.tryParse(raw.toString());
    return parsed ?? fallback ?? DateTime.now();
  }
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _alertRetry<T>(
  Future<T> Function() fn, {
  required String label,
  Duration timeout = _kQueryTimeout,
  int maxRetries = _kMaxRetries,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(timeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[RescueAlert] ❌ $label: timeout after $attempt');
        rethrow;
      }
      debugPrint('[RescueAlert] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[RescueAlert] ❌ $label: $e');
        rethrow;
      }
      await Future.delayed(_kRetryDelay);
    }
  }
}

// ============================================================================
// NOTIFIER
// ============================================================================
class SosRescueAlertNotifier extends StateNotifier<RescueAlert?> {
  SosRescueAlertNotifier(this._client) : super(null) {
    _safeBootstrap();
    _authSub = _client.auth.onAuthStateChange.listen((_) {
      _handleAuthChange();
    });
  }

  final SupabaseClient _client;
  RealtimeChannel? _ch;
  StreamSubscription<AuthState>? _authSub;
  bool _bootstrapped = false;
  bool _bootstrapping = false;
  DateTime? _lastAuthChange;
  DateTime? _lastRealtimeEvent;
  bool _isDisposed = false;

  String? get _myId => SupabaseConfig.currentUser?.id;

  // ✅ FIX P0 : throttle sur auth change + protection double-bootstrap
  Future<void> _handleAuthChange() async {
    final now = DateTime.now();
    if (_lastAuthChange != null &&
        now.difference(_lastAuthChange!) < _kAuthThrottle) {
      debugPrint('[RescueAlert] ⚠️ Auth change throttled');
      return;
    }
    _lastAuthChange = now;
    await _safeBootstrap();
  }

  // ✅ FIX P0 : wrap bootstrap dans try/finally
  Future<void> _safeBootstrap() async {
    if (_bootstrapping || _isDisposed) return;
    _bootstrapping = true;
    try {
      await _bootstrap().timeout(_kBootstrapTimeout);
    } on TimeoutException {
      debugPrint('[RescueAlert] ❌ Bootstrap timeout');
    } catch (e, stack) {
      debugPrint('[RescueAlert] ❌ Bootstrap error: $e');
      debugPrint('[RescueAlert] Stack: $stack');
    } finally {
      _bootstrapping = false;
    }
  }

  Future<void> _bootstrap() async {
    final myId = _myId;
    if (!_AlertValidators.isValidId(myId)) {
      debugPrint('[RescueAlert] ⚠️ No valid user ID, skip bootstrap');
      return;
    }
    if (_bootstrapped) return;
    _bootstrapped = true;

    debugPrint('[RescueAlert] 🚀 Bootstrap for $myId');

    // 1) Rattrapage : derniers SOS_STARTED où je suis cercle 1
    try {
      final res = await _alertRetry(
        () => _client
            .from('thix_sos_events')
            .select()
            .eq('type', 'SOS_STARTED')
            .order('created_at', ascending: false)
            .limit(_kMaxHistoryEvents),
        label: 'bootstrapHistory',
      );

      for (final row in res as List) {
        if (_isDisposed) return;
        final meta = Map<String, dynamic>.from(
            (row['payload'] as Map?) ?? {});
        final circle1 = _AlertValidators.safeCircleList(
            meta['circle1_user_ids']);
        if (!circle1.contains(myId)) continue;

        final incidentId = (row['incident_id'] ?? '').toString();
        if (!_AlertValidators.isValidId(incidentId)) continue;

        final alert = await _loadActiveAlert(incidentId, meta);
        if (alert != null && !_isDisposed) {
          state = alert;
          debugPrint('[RescueAlert] ✓ Active alert loaded: ${alert.incidentId}');
          break;
        }
      }
    } catch (e) {
      debugPrint('[RescueAlert] ❌ Bootstrap history: $e');
    }

    if (!_isDisposed) _subscribe(myId!);
  }

  // ✅ FIX P0 : logs structurés + validation + safe date
  Future<RescueAlert?> _loadActiveAlert(
    String incidentId,
    Map<String, dynamic> meta,
  ) async {
    if (!_AlertValidators.isValidId(incidentId)) return null;

    try {
      final inc = await _alertRetry(
        () => _client
            .from('thix_sos_incidents')
            .select()
            .eq('id', incidentId)
            .maybeSingle(),
        label: 'loadIncident[$incidentId]',
      );
      if (inc == null) return null;

      final status = (inc['status'] ?? '').toString();
      if (['resolved', 'cancelled', 'archived'].contains(status)) {
        debugPrint('[RescueAlert] ⏭️ Incident $incidentId is $status, skip');
        return null;
      }

      final victimId = (inc['victim_id'] ?? meta['victim_id'] ?? '')
          .toString()
          .trim();

      String? victimName;
      if (_AlertValidators.isValidId(victimId)) {
        try {
          final prof = await _alertRetry(
            () => _client
                .from('profiles')
                .select('full_name')
                .eq('id', victimId)
                .maybeSingle(),
            label: 'loadVictimProfile[$victimId]',
          );
          victimName = prof?['full_name']?.toString();
        } catch (e) {
          // ✅ FIX : log au lieu de catch silencieux
          debugPrint('[RescueAlert] ⚠️ Victim profile load failed: $e');
        }
      }

      final rawPublicId = (inc['public_id'] ?? meta['public_id'])?.toString();
      final publicId = (rawPublicId != null && rawPublicId.isNotEmpty)
          ? rawPublicId
          : 'SOS-$incidentId';

      final startedAt = _AlertValidators.safeDateTime(
        inc['started_at'],
        fallback: DateTime.now(),
      );

      return RescueAlert(
        incidentId: incidentId,
        victimId: victimId,
        publicId: publicId,
        conversationId: (inc['chat_conversation_id'] ??
                meta['conversation_id'])
            ?.toString(),
        victimName: victimName,
        startedAt: startedAt,
      );
    } catch (e) {
      debugPrint('[RescueAlert] ❌ loadActiveAlert[$incidentId]: $e');
      return null;
    }
  }

  // ✅ FIX P0 : throttle realtime + mounted guards + safe state write
  void _subscribe(String myId) {
    // ✅ FIX : unsubscribe + removeChannel (pas juste unsubscribe)
    _unsubscribeChannel();

    try {
      _ch = _client
          .channel('sos_rescue_alert_$myId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'thix_sos_events',
            callback: (payload) => _handleRealtimeEvent(payload, myId),
          )
          .subscribe((status, [error]) {
            if (error != null) {
              debugPrint('[RescueAlert] ❌ Subscribe error: $error');
            } else {
              debugPrint('[RescueAlert] ✓ Subscribed: $status');
            }
          });
    } catch (e) {
      debugPrint('[RescueAlert] ❌ Subscribe failed: $e');
    }
  }

  Future<void> _handleRealtimeEvent(
    PostgresChangePayload payload,
    String myId,
  ) async {
    if (_isDisposed) return;

    // ✅ FIX : throttle realtime (500ms)
    final now = DateTime.now();
    if (_lastRealtimeEvent != null &&
        now.difference(_lastRealtimeEvent!) < _kRealtimeThrottle) {
      return;
    }
    _lastRealtimeEvent = now;

    final rec = payload.newRecord;
    final type = (rec['type'] ?? '').toString();
    final incidentId = (rec['incident_id'] ?? '').toString();

    if (!_AlertValidators.isValidId(incidentId)) return;

    if (type == 'SOS_STARTED') {
      final meta = Map<String, dynamic>.from(
          (rec['payload'] as Map?) ?? {});
      final circle1 = _AlertValidators.safeCircleList(
          meta['circle1_user_ids']);
      if (!circle1.contains(myId)) return;

      final alert = await _loadActiveAlert(incidentId, meta);
      // ✅ FIX : double-check _isDisposed après async
      if (alert != null && !_isDisposed && mounted) {
        state = alert;
        debugPrint('[RescueAlert] 🚨 New alert: ${alert.incidentId}');
      }
    } else if (type == 'SOS_RESOLVED' || type == 'SOS_CANCELLED') {
      if (!_isDisposed &&
          mounted &&
          state != null &&
          state!.incidentId == incidentId) {
        state = null;
        debugPrint('[RescueAlert] ✓ Alert cleared: $incidentId ($type)');
      }
    }
  }

  /// ✅ Marque l'alerte comme accusée (pour badge UI)
  void acknowledge() {
    if (state == null) return;
    debugPrint('[RescueAlert] ✓ Acknowledged: ${state!.incidentId}');
    // Le badge sera géré côté UI via un provider dédié
    // Cette méthode sert de hook si logique serveur future (ex: mark_ack)
  }

  /// ✅ Unsubscribe + removeChannel (fix canal orphelin)
  void _unsubscribeChannel() {
    final ch = _ch;
    if (ch == null) return;
    try {
      ch.unsubscribe();
      _client.removeChannel(ch);
    } catch (e) {
      debugPrint('[RescueAlert] ⚠️ Unsubscribe error: $e');
    }
    _ch = null;
  }

  @override
  void dispose() {
    _isDisposed = true;
    debugPrint('[RescueAlert] 👋 Disposing');

    _unsubscribeChannel();

    try {
      _authSub?.cancel();
    } catch (e) {
      debugPrint('[RescueAlert] ⚠️ Auth sub cancel error: $e');
    }
    _authSub = null;

    super.dispose();
  }
}

// ============================================================================
// PROVIDER — ✅ FIX P0 : autoDispose pour éviter les fuites mémoire
// ============================================================================
final sosRescueAlertProvider = StateNotifierProvider.autoDispose<
    SosRescueAlertNotifier, RescueAlert?>((ref) {
  final notifier = SosRescueAlertNotifier(Supabase.instance.client);
  ref.onDispose(() {
    debugPrint('[RescueAlert] 🧹 Provider disposed');
  });
  return notifier;
});
