import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';
import 'package:thix_id/services/admin_audit_service.dart';

/// Admin onboarding: requests for admin portal access.
///
/// Expected table: `public.thix_admin_access_requests`
///
/// This service assumes RLS policies restrict reading/updating to admins.
class AdminAccessRequestService {
  static const String table = 'thix_admin_access_requests';

  AdminAccessRequestService({SupabaseClient? client, AdminAuditService? audit})
      : _client = client ?? SupabaseConfig.client,
        _audit = audit ?? AdminAuditService();

  final SupabaseClient _client;
  final AdminAuditService _audit;

  Future<List<Map<String, dynamic>>> fetchLatest({String status = 'pending', int limit = 80}) async {
    try {
      var q = _client.from(table).select('*');
      if (status.trim().isNotEmpty) q = q.eq('status', status);
      final rows = await q.order('created_at', ascending: false).limit(limit);
      return (rows is List) ? rows.cast<Map<String, dynamic>>() : const <Map<String, dynamic>>[];
    } catch (e) {
      debugPrint('AdminAccessRequestService.fetchLatest failed err=$e');
      rethrow;
    }
  }

  /// Realtime stream with polling fallback.
  Stream<List<Map<String, dynamic>>> streamLatest({String status = 'pending', int limit = 80}) {
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    RealtimeChannel? channel;
    Timer? poll;

    Future<void> emit() async {
      try {
        controller.add(await fetchLatest(status: status, limit: limit));
      } catch (_) {
        controller.add(const <Map<String, dynamic>>[]);
      }
    }

    void startPolling() {
      poll?.cancel();
      poll = Timer.periodic(const Duration(seconds: 3), (_) => unawaited(emit()));
    }

    controller.onListen = () {
      unawaited(emit());
      try {
        channel = _client.channel('admin_access_requests:$status');
        channel!
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: table,
              callback: (_) => unawaited(emit()),
            )
            .subscribe((s, err) {
              final msg = (err ?? '').toString().toLowerCase();
              if (s == RealtimeSubscribeStatus.channelError || msg.contains('permission') || msg.contains('rls')) startPolling();
            });
      } catch (e) {
        debugPrint('AdminAccessRequestService.streamLatest realtime failed; polling. err=$e');
        startPolling();
      }
    };

    controller.onCancel = () async {
      poll?.cancel();
      final ch = channel;
      if (ch != null) {
        try {
          await _client.removeChannel(ch);
        } catch (_) {}
      }
    };

    return controller.stream;
  }

  Future<void> decide({required String requestId, required String newStatus, String? decidedRole}) async {
    final status = newStatus.trim().toLowerCase();
    if (status != 'approved' && status != 'rejected') {
      throw ArgumentError('newStatus must be approved or rejected');
    }
    try {
      await _client.from(table).update({
        'status': status,
        if ((decidedRole ?? '').trim().isNotEmpty) 'decided_role': decidedRole!.trim(),
        'decided_by': _client.auth.currentUser?.id,
        'decided_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', requestId);

      await _audit.log(
        action: 'admin_access_request_$status',
        entityType: table,
        entityId: requestId,
        metadata: {'decided_role': (decidedRole ?? '').trim()},
      );
    } catch (e) {
      debugPrint('AdminAccessRequestService.decide failed id=$requestId status=$status err=$e');
      rethrow;
    }
  }
}
