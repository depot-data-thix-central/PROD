import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';

class AdminGlobalMetrics {
  final int totalUsers;
  final int activeUsers;
  final int verifiedDocuments;
  final int verificationRequests;
  final int emergencyAlerts;
  final int jobsPosted;
  final int chats;
  final int messages;

  const AdminGlobalMetrics({
    required this.totalUsers,
    required this.activeUsers,
    required this.verifiedDocuments,
    required this.verificationRequests,
    required this.emergencyAlerts,
    required this.jobsPosted,
    required this.chats,
    required this.messages,
  });

  static const empty = AdminGlobalMetrics(
    totalUsers: 0,
    activeUsers: 0,
    verifiedDocuments: 0,
    verificationRequests: 0,
    emergencyAlerts: 0,
    jobsPosted: 0,
    chats: 0,
    messages: 0,
  );
}

/// Minimal “real data” for the Admin overview.
///
/// Uses COUNT queries that are tolerant to missing tables (returns 0).
class AdminMetricsService {
  static const String profilesTable = 'profiles';
  static const String chatsTable = 'thix_chat_chats';
  static const String messagesTable = 'thix_chat_messages';
  static const String jobsTable = 'jobs';
  static const String emergencyTable = 'emergency_alerts';
  static const String verificationsTable = 'verification_requests';
  static const String documentsTable = 'documents';

  Future<int> _count(String table, {String? eqKey, Object? eqValue}) async {
    try {
      // NOTE: The current supabase_flutter version in this repo uses the legacy
      // PostgREST API which does not expose a lightweight COUNT() option.
      //
      // For the initial Admin MVP, we do a minimal select and count rows.
      // For large-scale production, replace this with an RPC (recommended):
      // `thix_admin_metrics()` returning aggregated counts.
      dynamic qb = SupabaseConfig.client.from(table).select('id');
      if (eqKey != null && eqValue != null) qb = qb.eq(eqKey, eqValue as Object);
      final res = await qb;
      if (res is List) return res.length;
      return 0;
    } catch (e) {
      if (e is PostgrestException && (e.code == 'PGRST205' || e.code == '42P01')) return 0;
      debugPrint('AdminMetricsService: count failed table=$table err=$e');
      return 0;
    }
  }

  Future<AdminGlobalMetrics> fetchGlobalMetrics() async {
    try {
      // Run counts in parallel.
      final results = await Future.wait<int>([
        _count(profilesTable),
        _count(chatsTable),
        _count(messagesTable),
        _count(jobsTable),
        _count(emergencyTable),
        _count(verificationsTable),
        _count(documentsTable),
      ]);

      final totalUsers = results[0];
      final chats = results[1];
      final messages = results[2];
      final jobs = results[3];
      final emergency = results[4];
      final verifications = results[5];
      final documents = results[6];

      // Active users is often defined differently; we approximate with “recently updated profiles” when the column exists.
      int active = 0;
      try {
        final since = DateTime.now().toUtc().subtract(const Duration(days: 7)).toIso8601String();
        final res = await SupabaseConfig.client.from(profilesTable).select('id').gte('updated_at', since);
        active = (res is List) ? res.length : 0;
      } catch (e) {
        active = 0;
      }

      // Verified documents: best-effort where status='verified' if such a column exists.
      int verifiedDocs = 0;
      try {
        final res = await SupabaseConfig.client.from(documentsTable).select('id').eq('status', 'verified');
        verifiedDocs = (res is List) ? res.length : 0;
      } catch (_) {
        verifiedDocs = 0;
      }

      return AdminGlobalMetrics(
        totalUsers: totalUsers,
        activeUsers: active,
        verifiedDocuments: verifiedDocs,
        verificationRequests: verifications,
        emergencyAlerts: emergency,
        jobsPosted: jobs,
        chats: chats,
        messages: messages,
      );
    } catch (e) {
      debugPrint('AdminMetricsService.fetchGlobalMetrics failed err=$e');
      return AdminGlobalMetrics.empty;
    }
  }
}

class FetchOptions {
  const FetchOptions();
}
