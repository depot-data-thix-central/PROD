// lib/services/admin_certification_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PendingEnterpriseCertification {
  final String userId;
  final String? displayName;
  final String? thixId;
  final String paymentId;
  final double amountUsd;
  final double amountCdf;
  final DateTime? paidAt;
  final String? requestId;
  final String? reason;

  const PendingEnterpriseCertification({
    required this.userId,
    this.displayName,
    this.thixId,
    required this.paymentId,
    required this.amountUsd,
    required this.amountCdf,
    this.paidAt,
    this.requestId,
    this.reason,
  });

  factory PendingEnterpriseCertification.fromMap(Map<String, dynamic> m) {
    return PendingEnterpriseCertification(
      userId: m['user_id'].toString(),
      displayName: m['display_name']?.toString(),
      thixId: m['thix_id']?.toString(),
      paymentId: m['payment_id'].toString(),
      amountUsd: (m['amount_usd'] as num?)?.toDouble() ?? 0,
      amountCdf: (m['amount_cdf'] as num?)?.toDouble() ?? 0,
      paidAt: m['paid_at'] != null ? DateTime.tryParse(m['paid_at'].toString()) : null,
      requestId: m['request_id']?.toString(),
      reason: m['reason']?.toString(),
    );
  }
}

class AdminCertificationService {
  final SupabaseClient _client;
  AdminCertificationService(this._client);

  /// Liste des demandes Entreprise payées en attente d'approbation admin
  Future<List<PendingEnterpriseCertification>> getPendingEnterprise() async {
    final rows = await _client
        .from('pending_enterprise_certifications')
        .select();
    return (rows as List)
        .map((r) => PendingEnterpriseCertification.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<void> approve(String userId, {String? notes}) async {
    try {
      await _client.rpc('rpc_admin_approve_enterprise_certification', params: {
        'p_user_id': userId,
        'p_notes': notes,
      });
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> reject(String userId, {String? notes}) async {
    try {
      await _client.rpc('rpc_admin_reject_enterprise_certification', params: {
        'p_user_id': userId,
        'p_notes': notes,
      });
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }
}
