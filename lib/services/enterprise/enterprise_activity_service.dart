import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';

class EnterpriseActivityItem {
  final String id;
  final String type;
  final String title;
  final String subtitle;
  final DateTime createdAt;

  const EnterpriseActivityItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.createdAt,
  });

  String get timeLabel {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  static EnterpriseActivityItem fromRow(Map<String, dynamic> row) {
    DateTime dt(Object? v) {
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return EnterpriseActivityItem(
      id: (row['id'] ?? '').toString(),
      type: (row['type'] ?? 'event').toString(),
      title: (row['title'] ?? 'Activity').toString(),
      subtitle: (row['subtitle'] ?? '').toString(),
      createdAt: dt(row['created_at'] ?? row['createdAt']),
    );
  }
}

/// Real-time activity feed.
///
/// Expected table: public.thix_enterprise_activity
/// RLS: only members of company can read.
class EnterpriseActivityService {
  static const String companies = 'thix_enterprise_companies';
  static const String table = 'thix_enterprise_activity';

  Stream<List<EnterpriseActivityItem>> stream({required String companySlug, int limit = 25}) async* {
    final slug = companySlug.trim().toLowerCase();
    if (slug.isEmpty) {
      yield const <EnterpriseActivityItem>[];
      return;
    }

    // Resolve company_id once.
    String? companyId;
    try {
      final company = await SupabaseConfig.client.from(companies).select('id').eq('slug', slug).maybeSingle();
      companyId = (company?['id'] ?? '').toString();
    } catch (e) {
      debugPrint('EnterpriseActivityService.stream: resolve company failed err=$e');
    }
    if (companyId == null || companyId!.isEmpty) {
      yield const <EnterpriseActivityItem>[];
      return;
    }

    // Initial load
    yield await _fetch(companyId: companyId!, limit: limit);

    // Realtime
    final stream = SupabaseConfig.client
        .from(table)
        .stream(primaryKey: ['id'])
        .eq('company_id', companyId!)
        .order('created_at', ascending: false)
        .limit(limit);
    await for (final rows in stream) {
      yield rows.map((e) => EnterpriseActivityItem.fromRow(e)).toList(growable: false);
    }
  }

  Future<List<EnterpriseActivityItem>> _fetch({required String companyId, required int limit}) async {
    try {
      final rows = await SupabaseConfig.client.from(table).select('*').eq('company_id', companyId).order('created_at', ascending: false).limit(limit);
      if (rows is! List) return const <EnterpriseActivityItem>[];
      return rows.map((e) => EnterpriseActivityItem.fromRow((e as Map).cast<String, dynamic>())).toList(growable: false);
    } catch (e) {
      if (e is PostgrestException && (e.code == 'PGRST205' || e.message.contains('Could not find the table'))) return const <EnterpriseActivityItem>[];
      debugPrint('EnterpriseActivityService._fetch failed err=$e');
      return const <EnterpriseActivityItem>[];
    }
  }
}
