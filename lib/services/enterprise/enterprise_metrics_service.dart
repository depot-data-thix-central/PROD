import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';

class EnterpriseOverviewMetrics {
  final int totalEmployees;
  final int verifiedEmployees;
  final int verificationRequests;
  final int securityAlerts;
  final int activeUsers;
  final int attendanceToday;
  final int fraudAttempts;
  final String complianceStatus;

  const EnterpriseOverviewMetrics({
    required this.totalEmployees,
    required this.verifiedEmployees,
    required this.verificationRequests,
    required this.securityAlerts,
    required this.activeUsers,
    required this.attendanceToday,
    required this.fraudAttempts,
    required this.complianceStatus,
  });

  static EnterpriseOverviewMetrics placeholder() => const EnterpriseOverviewMetrics(
        totalEmployees: 128,
        verifiedEmployees: 103,
        verificationRequests: 7,
        securityAlerts: 3,
        activeUsers: 41,
        attendanceToday: 88,
        fraudAttempts: 2,
        complianceStatus: 'OK',
      );
}

/// Metrics aggregation for the Enterprise dashboard.
///
/// We intentionally keep this tolerant: if tables are missing during early dev,
/// the UI still renders with placeholders.
class EnterpriseMetricsService {
  static const String companies = 'thix_enterprise_companies';
  static const String memberships = 'thix_enterprise_memberships';
  static const String alerts = 'thix_enterprise_security_alerts';
  static const String verificationRequests = 'thix_enterprise_verification_requests';
  static const String attendance = 'thix_enterprise_attendance_events';
  static const String sessions = 'thix_enterprise_sessions';

  final Map<String, Future<EnterpriseOverviewMetrics>> _cache = {};

  void invalidate({required String companySlug}) => _cache.remove(companySlug.trim().toLowerCase());

  Future<EnterpriseOverviewMetrics> fetchOverview({required String companySlug}) {
    final slug = companySlug.trim().toLowerCase();
    return _cache.putIfAbsent(slug, () => _fetch(slug));
  }

  Future<EnterpriseOverviewMetrics> _fetch(String slug) async {
    try {
      final company = await SupabaseConfig.client.from(companies).select('id').eq('slug', slug).maybeSingle();
      if (company == null) return EnterpriseOverviewMetrics.placeholder();
      final companyId = (company['id'] ?? '').toString();
      if (companyId.isEmpty) return EnterpriseOverviewMetrics.placeholder();

      final totalEmployees = await _count(table: memberships, companyId: companyId);
      final verifiedEmployees = await _count(table: memberships, companyId: companyId, extraEq: const {'employee_verified': true});
      final vrCount = await _count(table: verificationRequests, companyId: companyId);
      final alertsCount = await _count(table: alerts, companyId: companyId, extraEq: const {'status': 'open'});
      final activeUsers = await _count(table: sessions, companyId: companyId, extraGt: {'last_seen_at': DateTime.now().subtract(const Duration(hours: 24)).toIso8601String()});
      final attendanceToday = await _count(table: attendance, companyId: companyId, extraEq: {'day_key': _dayKey(DateTime.now())});
      final fraudAttempts = await _count(table: alerts, companyId: companyId, extraEq: const {'type': 'fraud_attempt'});

      return EnterpriseOverviewMetrics(
        totalEmployees: totalEmployees,
        verifiedEmployees: verifiedEmployees,
        verificationRequests: vrCount,
        securityAlerts: alertsCount,
        activeUsers: activeUsers,
        attendanceToday: attendanceToday,
        fraudAttempts: fraudAttempts,
        complianceStatus: 'OK',
      );
    } catch (e) {
      debugPrint('EnterpriseMetricsService._fetch failed err=$e');
      return EnterpriseOverviewMetrics.placeholder();
    }
  }

  String _dayKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<int> _count({required String table, required String companyId, Map<String, dynamic>? extraEq, Map<String, dynamic>? extraGt}) async {
    try {
      // We keep this SDK-version-agnostic: just fetch ids and use length.
      dynamic q = SupabaseConfig.client.from(table).select('id');
      q = q.eq('company_id', companyId);
      if (extraEq != null) {
        for (final e in extraEq.entries) {
          q = q.eq(e.key, e.value);
        }
      }
      if (extraGt != null) {
        for (final e in extraGt.entries) {
          q = q.gte(e.key, e.value);
        }
      }
      final res = await q;
      if (res is List) return res.length;
      return 0;
    } catch (e) {
      if (e is PostgrestException) {
        if (e.code == 'PGRST205' || e.message.contains('Could not find the table')) return 0;
      }
      debugPrint('EnterpriseMetricsService._count failed table=$table err=$e');
      return 0;
    }
  }
}
