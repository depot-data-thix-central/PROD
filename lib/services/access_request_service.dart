import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';
import 'dart:async';
import 'package:thix_id/services/supabase_safe_write.dart';

enum AccessRequestStatus { none, pending, approved, rejected }

class AccessRequestState {
  final String? requestId;
  final AccessRequestStatus status;
  final DateTime? approvedUntil;

  const AccessRequestState({required this.requestId, required this.status, this.approvedUntil});

  bool get isApproved => status == AccessRequestStatus.approved;

  bool isActiveAt(DateTime nowUtc) {
    if (!isApproved) return false;
    final until = approvedUntil;
    if (until == null) return true;
    return until.isAfter(nowUtc);
  }
}

class AccessRequestService {
  final SupabaseClient _client;
  AccessRequestService({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  static const String _table = 'profile_access_requests';

  String _activeTable = _table;
  bool _disabled = false;

  bool _isMissingTableError(Object e) => e is PostgrestException && (e.code == 'PGRST205' || e.message.contains('Could not find the table'));

  Future<void> _disableIfMissing(Object e) async {
    if (!_isMissingTableError(e)) return;
    _disabled = true;
    debugPrint('AccessRequestService: table missing ($_activeTable). Disabling access requests. err=$e');
  }

  Future<AccessRequestState> fetchState({required String requesterId, required String targetUserId}) async {
    if (_disabled) return const AccessRequestState(requestId: null, status: AccessRequestStatus.none);
    try {
      Map<String, dynamic>? row;
      try {
        final q = _client.from(_activeTable).select('id,status,approved_until').eq('requester_id', requesterId);
        row = await q.eq('profile_id', targetUserId).maybeSingle();
      } catch (e) {
        debugPrint('AccessRequestService: fetchState select approved_until failed (legacy schema). err=$e');
        final q = _client.from(_activeTable).select('id,status').eq('requester_id', requesterId);
        row = await q.eq('profile_id', targetUserId).maybeSingle();
      }
      if (row == null) return const AccessRequestState(requestId: null, status: AccessRequestStatus.none);
      final id = (row['id'] ?? '').toString();
      final status = _parseStatus((row['status'] ?? '').toString());
      final approvedUntil = _parseDateTimeOrNull(row['approved_until']);
      return AccessRequestState(requestId: id.isEmpty ? null : id, status: status, approvedUntil: approvedUntil);
    } catch (e) {
      await _disableIfMissing(e);
      debugPrint('AccessRequestService: fetchState failed requester=$requesterId target=$targetUserId err=$e');
      rethrow;
    }
  }

  /// Stream d’état par polling (sans Realtime)
  Stream<AccessRequestState> streamState({required String requesterId, required String targetUserId}) {
    if (_disabled) return const Stream<AccessRequestState>.empty();
    final controller = StreamController<AccessRequestState>.broadcast();
    Timer? pollTimer;
    bool isActive = true;

    Future<void> emitLatest() async {
      if (!isActive) return;
      try {
        final state = await fetchState(requesterId: requesterId, targetUserId: targetUserId);
        if (!controller.isClosed) controller.add(state);
      } catch (e) {
        debugPrint('AccessRequestService: emitLatest failed requester=$requesterId target=$targetUserId err=$e');
        if (!controller.isClosed) controller.add(const AccessRequestState(requestId: null, status: AccessRequestStatus.none));
      }
    }

    controller.onListen = () {
      isActive = true;
      unawaited(emitLatest());
      pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => unawaited(emitLatest()));
    };

    controller.onCancel = () {
      isActive = false;
      pollTimer?.cancel();
      controller.close();
    };

    return controller.stream;
  }

  /// Stream des requêtes entrantes (pour le propriétaire du profil) par polling
  Stream<List<Map<String, dynamic>>> streamIncomingRequests({required String ownerId, String status = 'pending'}) {
    if (_disabled) return const Stream<List<Map<String, dynamic>>>.empty();

    final authedUid = _client.auth.currentUser?.id;
    if (authedUid == null) {
      debugPrint('AccessRequestService: streamIncomingRequests skipped (no auth user).');
      return const Stream<List<Map<String, dynamic>>>.empty();
    }
    if (authedUid != ownerId) {
      debugPrint('AccessRequestService: streamIncomingRequests owner mismatch. param=$ownerId auth=$authedUid');
      ownerId = authedUid;
    }

    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    Timer? pollTimer;
    bool isActive = true;

    Future<void> emitLatest() async {
      if (!isActive) return;
      try {
        final rows = await _client
            .from(_activeTable)
            .select('id,requester_id,profile_id,status,created_at,approved_until')
            .eq('profile_id', ownerId)
            .order('created_at', ascending: false)
            .limit(50);
        final list = (rows is List) ? rows.cast<Map<String, dynamic>>() : const <Map<String, dynamic>>[];
        bool matches(String rowStatus) {
          final s = rowStatus.trim().toLowerCase();
          final f = status.trim().toLowerCase();
          if (f.isEmpty) return true;
          if (f == 'pending') return s == 'pending' || s == 'en_attente' || s == 'en attente';
          if (f == 'approved') return s == 'approved' || s == 'approuve' || s == 'approuvé';
          if (f == 'rejected') return s == 'rejected' || s == 'refuse' || s == 'refusé';
          return s == f;
        }
        final filtered = status.trim().isEmpty ? list : list.where((r) => matches((r['status'] ?? '').toString())).toList(growable: false);
        if (!controller.isClosed) controller.add(filtered);
      } catch (e) {
        await _disableIfMissing(e);
        debugPrint('AccessRequestService: streamIncomingRequests emitLatest failed owner=$ownerId err=$e');
        if (!controller.isClosed) controller.add([]);
      }
    }

    controller.onListen = () {
      isActive = true;
      unawaited(emitLatest());
      pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => unawaited(emitLatest()));
    };

    controller.onCancel = () {
      isActive = false;
      pollTimer?.cancel();
      controller.close();
    };

    return controller.stream;
  }

  Stream<int> streamIncomingPendingCount({required String ownerId}) =>
      streamIncomingRequests(ownerId: ownerId, status: 'pending').map((l) => l.length);

  Future<AccessRequestState> requestAccess({
    required String requesterId,
    required String targetUserId,
    String? message,
    String? thixId,
  }) async {
    if (_disabled) return const AccessRequestState(requestId: null, status: AccessRequestStatus.none);
    try {
      var effectiveRequesterId = requesterId;
      final authedUid = _client.auth.currentUser?.id;
      if (authedUid != null && authedUid.trim().isNotEmpty && authedUid != effectiveRequesterId) {
        debugPrint('AccessRequestService: requesterId normalized to auth.uid(). requesterId=$effectiveRequesterId authedUid=$authedUid');
        effectiveRequesterId = authedUid;
      }

      try {
        final res = await _client.rpc('thix_request_profile_access', params: {
          'p_target_user_id': targetUserId,
          'p_message': (message ?? '').trim().isEmpty ? null : message!.trim(),
          'p_thix_id': (thixId ?? '').trim().isEmpty ? null : thixId!.trim(),
        });
        final id = (res ?? '').toString();
        if (id.trim().isNotEmpty) return AccessRequestState(requestId: id.trim(), status: AccessRequestStatus.pending);
      } catch (e) {
        debugPrint('AccessRequestService: rpc thix_request_profile_access failed, fallback to upsert. err=$e');
      }

      final nowIso = DateTime.now().toUtc().toIso8601String();
      const pendingDbValue = 'en_attente';

      try {
        final updated = await _client
            .from(_activeTable)
            .update({'status': pendingDbValue, 'updated_at': nowIso})
            .eq('requester_id', effectiveRequesterId)
            .eq('profile_id', targetUserId)
            .select('id,status')
            .maybeSingle();
        if (updated != null) {
          return AccessRequestState(requestId: updated['id']?.toString(), status: _parseStatus((updated['status'] ?? '').toString()));
        }
      } catch (e) {
        debugPrint('AccessRequestService: update existing request failed, fallback to upsert. err=$e');
      }

      final payload = {
        'requester_id': effectiveRequesterId,
        'profile_id': targetUserId,
        'status': pendingDbValue,
        'created_at': nowIso,
        'updated_at': nowIso,
      };

      await SupabaseSafeWrite.upsert(
        client: _client,
        table: _activeTable,
        payload: payload,
        onConflict: 'requester_id,profile_id',
      );

      final row = await _client
          .from(_activeTable)
          .select('id,status,approved_until')
          .eq('requester_id', effectiveRequesterId)
          .eq('profile_id', targetUserId)
          .maybeSingle();
      if (row != null) {
        return AccessRequestState(
          requestId: row['id']?.toString(),
          status: _parseStatus((row['status'] ?? '').toString()),
          approvedUntil: _parseDateTimeOrNull(row['approved_until']),
        );
      }
      return await fetchState(requesterId: effectiveRequesterId, targetUserId: targetUserId);
    } catch (e) {
      await _disableIfMissing(e);
      debugPrint('AccessRequestService: requestAccess failed requester=$requesterId target=$targetUserId err=$e');
      rethrow;
    }
  }

  Future<void> setStatus({required String requestId, required String status}) async {
    if (_disabled) return;
    try {
      try {
        await _client.rpc('thix_set_access_request_status', params: {
          'p_request_id': requestId,
          'p_new_status': status,
        });
        return;
      } catch (e) {
        debugPrint('AccessRequestService: rpc thix_set_access_request_status failed, fallback to update. err=$e');
      }

      final payload = <String, dynamic>{'status': status};
      if (status.trim().toLowerCase() == 'approved') {
        payload['approved_until'] = DateTime.now().toUtc().add(const Duration(minutes: 10)).toIso8601String();
      }
      await SupabaseSafeWrite.update(client: _client, table: _activeTable, patch: payload, filters: {'id': requestId});
    } catch (e) {
      await _disableIfMissing(e);
      debugPrint('AccessRequestService: setStatus failed id=$requestId status=$status err=$e');
      rethrow;
    }
  }

  Future<void> approveFor10Minutes({required String requestId}) => setStatus(requestId: requestId, status: 'approved');

  static DateTime? _parseDateTimeOrNull(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toUtc();
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s)?.toUtc();
  }
}

AccessRequestStatus _parseStatus(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'pending':
    case 'en_attente':
    case 'en attente':
      return AccessRequestStatus.pending;
    case 'approved':
    case 'approuve':
    case 'approuvé':
      return AccessRequestStatus.approved;
    case 'rejected':
    case 'refuse':
    case 'refusé':
      return AccessRequestStatus.rejected;
    default:
      return AccessRequestStatus.none;
  }
}
