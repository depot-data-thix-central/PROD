// lib/presentation/vault/vault_security_service.dart
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';

import 'vault_state.dart';

class VaultSecurityService {
  final SupabaseClient _db;
  VaultSecurityService({SupabaseClient? client})
      : _db = client ?? SupabaseConfig.client;

  static String sha256Hex(Uint8List b) => sha256.convert(b).toString();

  JsonMap _asMap(dynamic r) {
    if (r is Map) return r.cast<String, dynamic>();
    if (r is List && r.isNotEmpty && r.first is Map) {
      return (r.first as Map).cast<String, dynamic>();
    }
    return <String, dynamic>{};
  }

  /// Scelle le document : empreinte SHA-256 (gelée ensuite par trigger côté DB).
  Future<void> sealDocument({
    required String uid,
    required String generatedId,
    required Uint8List bytes,
  }) async {
    await _db
        .from('documents')
        .update({'sha256': sha256Hex(bytes)})
        .eq('user_id', uid)
        .eq('generated_doc_id', generatedId);
  }

  Future<IntegrityStatus> checkIntegrity({required String url, String? expected}) async {
    if (expected == null || expected.isEmpty) return IntegrityStatus.unsealed;
    final r = await http.get(Uri.parse(url));
    if (r.statusCode != 200) throw Exception('http ${r.statusCode}');
    return sha256Hex(r.bodyBytes) == expected
        ? IntegrityStatus.ok
        : IntegrityStatus.tampered;
  }

  Future<JsonMap> signDocument(String documentId) async =>
      _asMap(await _db.rpc('sign_document', params: {'p_document_id': documentId}));

  Future<JsonMap> verifySignature(String code) async =>
      _asMap(await _db.rpc('verify_signature', params: {'p_code': code.trim()}));

  Future<bool> revokeShare(String shareId) async {
    final r = await _db.rpc('revoke_share', params: {'p_share_id': shareId});
    return r == true;
  }

  Future<void> reportDocument({required String docId, required String reason}) async {
    await _db.rpc('report_document', params: {'p_doc_id': docId, 'p_reason': reason});
  }

  // ------------------------------------------------------------ Admin
  Future<bool> isAdmin() async {
    try {
      return (await _db.rpc('is_vault_admin')) == true;
    } catch (_) {
      return false;
    }
  }

  Future<JsonMap> adminStats() async => _asMap(await _db.rpc('vault_admin_stats'));

  Future<List<JsonMap>> adminReports() async {
    final r = await _db
        .from('document_reports')
        .select()
        .order('created_at', ascending: false)
        .limit(50);
    return (r as List).cast<JsonMap>();
  }

  Future<void> resolveReport(String id, {required bool confirm}) async {
    await _db.rpc('admin_resolve_report', params: {'p_report_id': id, 'p_confirm': confirm});
  }
}
