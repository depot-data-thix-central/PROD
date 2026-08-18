import 'package:supabase_flutter/supabase_flutter.dart';

class AdminService {
  final SupabaseClient _supabase;
  AdminService(this._supabase);

  Future<bool> isAdmin() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;
    try {
      final res = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      // Si tu utilises user_metadata : user.userMetadata?['role'] == 'admin'
      return res?['role'] == 'admin' || user.userMetadata?['role'] == 'admin';
    } catch (_) {
      return user.email?.endsWith('@thix.info') ?? false; // fallback dev
    }
  }
}
