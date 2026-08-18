import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';
import 'package:thix_id/services/admin_audit_service.dart';

class AdminUserService {
  AdminUserService({SupabaseClient? client, AdminAuditService? audit})
      : _client = client ?? SupabaseConfig.client,
        _audit = audit ?? AdminAuditService();

  final SupabaseClient _client;
  final AdminAuditService _audit;

  Future<void> setSuspended({required String profileId, required bool suspended, String? reason}) async {
    try {
      await _client.from('thix_public_profiles').update({
        'is_suspended': suspended,
        'suspended_at': suspended ? DateTime.now().toIso8601String() : null,
        'suspended_reason': suspended ? (reason ?? '').trim() : null,
        'suspended_by': _client.auth.currentUser?.id,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', profileId);

      await _audit.log(
        action: suspended ? 'user_suspend' : 'user_reactivate',
        entityType: 'thix_public_profiles',
        entityId: profileId,
        metadata: {'reason': (reason ?? '').trim()},
      );
    } catch (e) {
      debugPrint('AdminUserService.setSuspended failed err=$e');
      rethrow;
    }
  }
}
