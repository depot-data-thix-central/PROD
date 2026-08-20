import 'package:thix_id/supabase/supabase_config.dart';

class RechercheRoles {
  /// Rôles autorisés à créer un avis WANTED / personne recherchée
  static const adminRoles = {
    'admin',
    'super_admin',
    'police',
    'justice',
    'autorite',
  };

  static Future<bool> isAdmin() async {
    final user = SupabaseConfig.currentUser;
    if (user == null) return false;

    // 1) App metadata / user metadata
    final metaRole = (user.appMetadata['role'] ??
            user.userMetadata?['role'] ??
            '')
        .toString()
        .toLowerCase()
        .trim();
    if (adminRoles.contains(metaRole)) return true;

    // 2) Table profiles (adapte le nom de colonne si besoin)
    try {
      final row = await SupabaseConfig.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      final role = (row?['role'] ?? '').toString().toLowerCase().trim();
      return adminRoles.contains(role);
    } catch (_) {
      return false;
    }
  }
}
