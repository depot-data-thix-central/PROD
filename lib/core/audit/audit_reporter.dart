import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 📓 AuditReporter — embarqué dans l'app mobile THIX
/// Journalise les actions utilisateurs (immutable, 90 j de rétention).
class AuditReporter {
  AuditReporter._();

  static const String kTable = 'audit_events';

  /// 📝 Journaliser une action
  static Future<void> log({
    required String category,
    required String action,
    required String summary,
    Map<String, dynamic>? details,
  }) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      final profile = await _fetchProfile(client, user?.id);

      await client.from(kTable).insert({
        'category': category,
        'action': action,
        'user_id': user?.id,
        'thix_id': profile?['thix_id'],
        'display_name': profile?['display_name'],
        'summary': summary.length > 400 ? summary.substring(0, 400) : summary,
        'details': {...?details, 'platform': defaultTargetPlatform.name},
        'device': kIsWeb ? 'Web' : defaultTargetPlatform.name,
        'source': 'mobile_app',
      });
    } catch (e) {
      // Jamais bloquant
      if (kDebugMode) debugPrint('⚠️ [AuditReporter] ignoré : $e');
    }
  }

  static Future<Map<String, dynamic>?> _fetchProfile(
      SupabaseClient client, String? userId) async {
    if (userId == null) return null;
    try {
      final res = await client
          .from('profiles')
          .select('thix_id, display_name')
          .eq('id', userId)
          .maybeSingle();
      return res;
    } catch (_) {
      return null;
    }
  }

  // ─── Raccourcis métier ───
  static void loginSuccess({String? method}) =>
      log(category: 'auth', action: 'login_success',
          summary: 'Connexion réussie', details: {'method': method});

  static void logout() => log(
      category: 'auth', action: 'logout', summary: 'Déconnexion');

  static void profileUpdate({required String field}) => log(
      category: 'profile',
      action: 'profile_update',
      summary: 'Modification du profil : $field',
      details: {'field': field});

  static void sosTriggered({required int contactsNotified, String? city}) => log(
      category: 'security',
      action: 'sos_triggered',
      summary: 'Alerte SOS envoyée à $contactsNotified contact(s)',
      details: {'contacts': contactsNotified, 'city': city});

  static void postCreated() => log(
      category: 'content', action: 'post_created', summary: 'Publication d\'un post');

  static void certificationRequested({required String tier}) => log(
      category: 'certification',
      action: 'certification_requested',
      summary: 'Demande de certification : $tier',
      details: {'tier': tier});

  static void documentUploaded({required String kind}) => log(
      category: 'documents',
      action: 'document_uploaded',
      summary: 'Upload document : $kind',
      details: {'kind': kind});
}
