import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';

/// Enterprise RBAC per company.
///
/// Expected table: public.thix_enterprise_memberships
/// - user_id uuid
/// - company_id uuid (FK)
/// - role text
///
/// This service is resilient: if table missing (PGRST205) or RLS blocks access,
/// it returns null.
class EnterpriseRbacService {
  static const String table = 'thix_enterprise_memberships';
  static const String companyTable = 'thix_enterprise_companies';

  Future<String?> fetchMyRole({required String companySlug}) async {
    final uid = SupabaseConfig.client.auth.currentUser?.id;
    if (uid == null || uid.trim().isEmpty) return null;
    final slug = companySlug.trim().toLowerCase();
    if (slug.isEmpty) return null;
    try {
      final company = await SupabaseConfig.client.from(companyTable).select('id').eq('slug', slug).maybeSingle();
      if (company == null) return null;
      final companyId = (company['id'] ?? '').toString();
      if (companyId.isEmpty) return null;
      final row = await SupabaseConfig.client.from(table).select('role').eq('user_id', uid).eq('company_id', companyId).maybeSingle();
      if (row == null) return null;
      final role = (row['role'] ?? '').toString().trim();
      return role.isEmpty ? null : role;
    } catch (e) {
      if (e is PostgrestException) {
        if (e.code == 'PGRST205' || e.message.contains('Could not find the table')) return null;
        if (e.code == '42501') return null;
      }
      debugPrint('EnterpriseRbacService.fetchMyRole failed err=$e');
      return null;
    }
  }
}
