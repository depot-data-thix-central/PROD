import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/services/verification_status.dart';
import 'package:thix_id/supabase/supabase_config.dart';

@immutable
class VerificationQueueItem {
  final String table; // formations | experiences | profiles
  final int? linkedRowId; // bigint for formations/experiences
  final String userId; // profile id
  final String title;
  final Map<String, dynamic> payload;
  final VerificationStatus status;
  final DateTime? createdAt;

  const VerificationQueueItem({
    required this.table,
    required this.linkedRowId,
    required this.userId,
    required this.title,
    required this.payload,
    required this.status,
    required this.createdAt,
  });
}

class AdminVerificationService {
  final SupabaseClient _client;
  AdminVerificationService({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  SupabaseClient get client => _client;

  // New THIX ID schema (Supabase):
  // - public.national_identity (identity submissions)
  // - public.user_education_records (diplomas / trainings with evidence)
  static const identityTable = 'national_identity';
  static const educationTable = 'user_education_records';

  Future<List<VerificationQueueItem>> fetchQueue({int limit = 250}) async {
    final items = <VerificationQueueItem>[];
    items.addAll(await _fetchEducation(limit: limit));
    items.addAll(await _fetchIdentity(limit: limit));
    items.sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
    return items;
  }

  Future<List<VerificationQueueItem>> _fetchEducation({required int limit}) async {
    try {
      final rows = await _client
          .from(educationTable)
          .select('id,user_id,title,institution,degree,certificate_path,certificate_file_name,verification_status,created_at,updated_at')
          .order('created_at', ascending: false)
          .limit(limit);
      if (rows is! List) return const [];
      final list = rows.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList(growable: false);
      return list.map((r) {
        final status = VerificationStatusX.parse(r['verification_status']);
        final title = (r['title'] ?? r['degree'] ?? '').toString().trim();
        final inst = (r['institution'] ?? '').toString().trim();
        final createdAt = DateTime.tryParse((r['created_at'] ?? '').toString());
        return VerificationQueueItem(
          table: educationTable,
          linkedRowId: (r['id'] is int) ? r['id'] as int : int.tryParse((r['id'] ?? '').toString()),
          userId: (r['user_id'] ?? '').toString(),
          title: title.isEmpty ? (inst.isEmpty ? 'Formation' : inst) : title,
          payload: r,
          status: status,
          createdAt: createdAt,
        );
      }).where((it) => it.status == VerificationStatus.pending).toList(growable: false);
    } catch (e) {
      debugPrint('AdminVerificationService: fetch education failed err=$e');
      return const [];
    }
  }

  Future<List<VerificationQueueItem>> _fetchIdentity({required int limit}) async {
    try {
      final rows = await _client
          .from(identityTable)
          .select('id,user_id,full_name,document_type,national_id_number,front_path,back_path,selfie_path,status,rejection_reason,created_at,updated_at')
          .order('updated_at', ascending: false)
          .limit(limit);
      if (rows is! List) return const [];
      final list = rows.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList(growable: false);
      return list.map((r) {
        final status = VerificationStatusX.parse(r['status']);
        final name = (r['full_name'] ?? '').toString().trim();
        return VerificationQueueItem(
          table: identityTable,
          linkedRowId: (r['id'] is int) ? r['id'] as int : int.tryParse((r['id'] ?? '').toString()),
          userId: (r['user_id'] ?? '').toString(),
          title: name.isEmpty ? 'Identité nationale' : 'Identité — $name',
          payload: r,
          status: status,
          createdAt: DateTime.tryParse((r['created_at'] ?? r['updated_at'] ?? '').toString()),
        );
      }).where((it) => it.status == VerificationStatus.pending).toList(growable: false);
    } catch (e) {
      debugPrint('AdminVerificationService: fetch identity failed err=$e');
      return const [];
    }
  }

  Future<void> setStatus({required VerificationQueueItem item, required VerificationStatus status}) async {
    final id = item.linkedRowId;
    if (id == null) throw ArgumentError('Missing linkedRowId for ${item.table}');

    if (item.table == identityTable) {
      await _client.from(identityTable).update({
        'status': status.value,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);

      // Badge automation (best-effort): update public profile.
      if (status == VerificationStatus.verified) {
        try {
          await _client.from('thix_public_profiles').update({
            'account_status': 'verified',
            'trust_level': 'verified',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('user_id', item.userId);
        } catch (e) {
          debugPrint('AdminVerificationService: profile automation failed err=$e');
        }
      }
      return;
    }

    if (item.table == educationTable) {
      await _client.from(educationTable).update({
        'verification_status': status.value,
        'verified_at': status == VerificationStatus.verified ? DateTime.now().toUtc().toIso8601String() : null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
      return;
    }

    // Unknown table; best-effort generic update.
    await _client.from(item.table).update({'verification_status': status.value, 'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }
}
