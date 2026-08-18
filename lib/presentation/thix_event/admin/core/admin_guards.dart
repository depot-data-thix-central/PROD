// lib/presentation/thix_event/admin/core/admin_guards.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_constants.dart';

enum AdminRole { superAdmin, eventManager, viewer, none }

class AdminGuard {
  static final _supabase = Supabase.instance.client;

  static Future<AdminRole> getCurrentRole() async {
    if (AdminConstants.isDevOpenAccess) return AdminRole.superAdmin; // DEV: libre

    final user = _supabase.auth.currentUser;
    if (user == null) return AdminRole.none;

    // En PROD: tu liras depuis table `profiles` ou `admin_roles`
    // SELECT role FROM admin_roles WHERE user_id = user.id
    try {
      final res = await _supabase.from('admin_roles').select('role').eq('user_id', user.id).maybeSingle();
      return _parseRole(res?['role']);
    } catch (_) {
      return AdminRole.none;
    }
  }

  static AdminRole _parseRole(String? r) {
    switch(r) {
      case 'super_admin': return AdminRole.superAdmin;
      case 'event_manager': return AdminRole.eventManager;
      default: return AdminRole.none;
    }
  }

  static bool canWrite(AdminRole role) => role == AdminRole.superAdmin || role == AdminRole.eventManager;
  static bool canDelete(AdminRole role) => role == AdminRole.superAdmin;
}
