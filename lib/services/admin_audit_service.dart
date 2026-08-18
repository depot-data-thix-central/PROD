import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';

/// Centralized admin audit logging.
///
/// Expected table: `public.thix_admin_audit_logs`
/// - id (bigserial)
/// - actor_user_id (uuid)
/// - actor_role (text)
/// - action (text)
/// - entity_type (text)
/// - entity_id (text)
/// - metadata (jsonb)
/// - created_at (timestamptz)
///
/// This is schema-safe: if the table is missing or blocked by RLS,
/// it becomes a no-op.
class AdminAuditService {
  static const String table = 'thix_admin_audit_logs';

  AdminAuditService({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;
  final SupabaseClient _client;

  bool _disabled = false;

  Future<void> log({
    required String action,
    required String entityType,
    String? entityId,
    Map<String, dynamic>? metadata,
    String? actorRole,
  }) async {
    if (_disabled) return;
    try {
      await _client.from(table).insert({
        'actor_user_id': _client.auth.currentUser?.id,
        'actor_role': actorRole,
        'action': action,
        'entity_type': entityType,
        'entity_id': entityId,
        'metadata': metadata ?? <String, dynamic>{},
      });
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205' || e.message.contains('Could not find the table') || e.message.contains('schema cache')) {
        _disabled = true;
        debugPrint('AdminAuditService: table missing; disabling audit logs.');
        return;
      }
      if (e.code == '42501') {
        // blocked by RLS
        debugPrint('AdminAuditService: RLS blocked audit insert: ${e.message}');
        return;
      }
      debugPrint('AdminAuditService.log PostgrestException: ${e.code} ${e.message}');
    } catch (e) {
      debugPrint('AdminAuditService.log failed: $e');
    }
  }
}
