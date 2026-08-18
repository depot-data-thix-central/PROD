import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';

/// Role-Based Access Control (RBAC) for the Admin web portal.
///
/// Expected table (recommended): `public.thix_admin_memberships`
/// Columns:
/// - user_id (uuid) PK/FK -> auth.users.id
/// - role (text) NOT NULL
/// - created_at (timestamptz) default now()
/// - updated_at (timestamptz) default now()
///
/// This service is resilient: if the table is missing (PGRST205) or RLS blocks
/// access, it returns null (no admin access).
class AdminRbacService {
  static const String table = 'thix_admin_memberships';

  Future<String?> fetchMyRole() async {
    final uid = SupabaseConfig.client.auth.currentUser?.id;
    if (uid == null || uid.trim().isEmpty) return null;
    try {
      final row = await SupabaseConfig.client.from(table).select('role').eq('user_id', uid).maybeSingle();
      if (row == null) return null;
      final role = (row['role'] ?? '').toString().trim();
      return role.isEmpty ? null : role;
    } catch (e) {
      if (e is PostgrestException) {
        // Missing table / schema cache not updated.
        if (e.code == 'PGRST205' || e.message.contains('Could not find the table')) return null;
        // Unauthorized due to RLS.
        if (e.code == '42501') return null;
      }
      debugPrint('AdminRbacService.fetchMyRole failed err=$e');
      return null;
    }
  }

  /// Minimal role hierarchy.
  ///
  /// Order: higher index => higher privileges.
  static int roleLevel(String role) {
    switch (role.trim().toLowerCase()) {
      case 'super admin':
      case 'super_admin':
      case 'superadmin':
        return 6;
      case 'admin':
        return 5;
      case 'moderator':
        return 4;
      case 'support agent':
      case 'support_agent':
      case 'support':
        return 3;
      case 'institution':
        return 2;
      case 'university partner':
      case 'university_partner':
      case 'university':
        return 2;
      case 'recruiter':
        return 2;
      default:
        return 0;
    }
  }

  static bool canAccess({required String? role, required int minLevel}) {
    if (role == null) return false;
    return roleLevel(role) >= minLevel;
  }
}
