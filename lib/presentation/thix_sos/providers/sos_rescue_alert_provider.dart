// lib/presentation/thix_sos/providers/sos_rescue_alert_provider.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';

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
}

class SosRescueAlertNotifier extends StateNotifier<RescueAlert?> {
  final SupabaseClient _client;
  RealtimeChannel? _ch;
  StreamSubscription<AuthState>? _authSub;
  bool _bootstrapped = false;

  SosRescueAlertNotifier(this._client) : super(null) {
    _bootstrap();
    _authSub = _client.auth.onAuthStateChange.listen((_) {
      if (!_bootstrapped) _bootstrap();
    });
  }

  String? get _myId => SupabaseConfig.currentUser?.id;

  Future<void> _bootstrap() async {
    final myId = _myId;
    if (myId == null) return;
    _bootstrapped = true;

    // 1) Rattrapage : derniers SOS_STARTED (24h) où je suis cercle 1
    try {
      final res = await _client
          .from('thix_sos_events')
          .select()
          .eq('type', 'SOS_STARTED')
          .order('created_at', ascending: false)
          .limit(10);

      for (final row in res as List) {
        final meta = Map<String, dynamic>.from((row['payload'] as Map?) ?? {});
        final circle1 =
            (meta['circle1_user_ids'] as List? ?? []).map((e) => e.toString()).toList();
        if (!circle1.contains(myId)) continue;

        final incidentId = (row['incident_id'] ?? '').toString();
        final alert = await _loadActiveAlert(incidentId, meta);
        if (alert != null) {
          state = alert;
          break;
        }
      }
    } catch (e) {
      debugPrint('SosRescueAlert bootstrap: $e');
    }

    _subscribe(myId);
  }

  Future<RescueAlert?> _loadActiveAlert(
    String incidentId,
    Map<String, dynamic> meta,
  ) async {
    if (incidentId.isEmpty) return null;
    try {
      final inc = await _client
          .from('thix_sos_incidents')
          .select()
          .eq('id', incidentId)
          .maybeSingle();
      if (inc == null) return null;

      final status = (inc['status'] ?? '').toString();
      if (['resolved', 'cancelled', 'archived'].contains(status)) return null;

      final victimId = (inc['victim_id'] ?? meta['victim_id'] ?? '').toString();
      String? victimName;
      try {
        final prof = await _client
            .from('profiles')
            .select('full_name')
            .eq('id', victimId)
            .maybeSingle();
        victimName = prof?['full_name']?.toString();
      } catch (_) {}

      return RescueAlert(
        incidentId: incidentId,
        victimId: victimId,
        publicId: (inc['public_id'] ?? meta['public_id'] ?? 'SOS').toString(),
        conversationId: (inc['chat_conversation_id'] ??
                meta['conversation_id'])
            ?.toString(),
        victimName: victimName,
        startedAt: DateTime.tryParse((inc['started_at'] ?? '').toString()) ??
            DateTime.now(),
      );
    } catch (e) {
      debugPrint('SosRescueAlert load: $e');
      return null;
    }
  }

  void _subscribe(String myId) {
    _ch?.unsubscribe();
    _ch = _client
        .channel('sos_rescue_alert_$myId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'thix_sos_events',
          callback: (payload) async {
            final rec = payload.newRecord;
            final type = (rec['type'] ?? '').toString();
            final incidentId = (rec['incident_id'] ?? '').toString();

            if (type == 'SOS_STARTED') {
              final meta = Map<String, dynamic>.from((rec['payload'] as Map?) ?? {});
              final circle1 = (meta['circle1_user_ids'] as List? ?? [])
                  .map((e) => e.toString())
                  .toList();
              if (!circle1.contains(myId)) return;
              final alert = await _loadActiveAlert(incidentId, meta);
              if (alert != null && mounted) state = alert;
            } else if (type == 'SOS_RESOLVED' || type == 'SOS_CANCELLED') {
              if (mounted && state != null && state!.incidentId == incidentId) {
                state = null;
              }
            }
          },
        )
        .subscribe();
  }

  bool get mounted => super.mounted;

  /// À appeler quand le secours ouvre la chambre (optionnel, pour badge).
  void acknowledge() {}

  @override
  void dispose() {
    _ch?.unsubscribe();
    _authSub?.cancel();
    super.dispose();
  }
}

final sosRescueAlertProvider =
    StateNotifierProvider<SosRescueAlertNotifier, RescueAlert?>((ref) {
  return SosRescueAlertNotifier(Supabase.instance.client);
});
