// lib/services/certification_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/models/certification_tier.dart';

class CertificationInfo {
  final CertificationTier tier;
  final CertificationStatus status;
  final DateTime? certifiedAt;
  final String? idVerificationStatus;

  const CertificationInfo({
    required this.tier,
    required this.status,
    this.certifiedAt,
    this.idVerificationStatus,
  });

  bool get isCertified =>
      status == CertificationStatus.approved ||
      status == CertificationStatus.generated;
}

class CertificationService {
  final SupabaseClient _client;

  CertificationService(this._client);

  String? get _uid => _client.auth.currentUser?.id;

  Future<CertificationInfo> getMyCertification() async {
    try {
      final row = await _client.rpc('rpc_get_my_certification');
      if (row is List && row.isNotEmpty) {
        final m = Map<String, dynamic>.from(row.first as Map);
        return CertificationInfo(
          tier: CertificationTierX.parse(m['certification_tier']),
          status: CertificationStatusX.parse(m['certification_status']),
          certifiedAt: m['certified_at'] != null
              ? DateTime.tryParse(m['certified_at'].toString())
              : null,
          idVerificationStatus: m['id_verification_status']?.toString(),
        );
      }
    } catch (e) {
      debugPrint('❌ getMyCertification rpc: $e');
    }

    // Fallback lecture directe profiles
    try {
      final uid = _uid;
      if (uid == null) {
        return const CertificationInfo(
          tier: CertificationTier.free,
          status: CertificationStatus.none,
        );
      }
      final p = await _client
          .from('profiles')
          .select(
            'certification_tier, certification_status, certified_at, id_verification_status',
          )
          .eq('id', uid)
          .maybeSingle();

      if (p == null) {
        return const CertificationInfo(
          tier: CertificationTier.free,
          status: CertificationStatus.none,
        );
      }

      return CertificationInfo(
        tier: CertificationTierX.parse(p['certification_tier']),
        status: CertificationStatusX.parse(p['certification_status']),
        certifiedAt: p['certified_at'] != null
            ? DateTime.tryParse(p['certified_at'].toString())
            : null,
        idVerificationStatus: p['id_verification_status']?.toString(),
      );
    } catch (e) {
      debugPrint('❌ getMyCertification fallback: $e');
      return const CertificationInfo(
        tier: CertificationTier.free,
        status: CertificationStatus.none,
      );
    }
  }

  /// Demande d'upgrade vers un tier supérieur
  Future<void> requestUpgrade({
    required CertificationTier requestedTier,
    String? reason,
  }) async {
    // 🔒 Blocage pour le niveau "Officiel / Institutions"
    if (requestedTier.isInviteOnly) {
      throw Exception(
        'Le niveau Officiel / Institutions est accessible uniquement sur invitation THIX.',
      );
    }

    // Le palier gratuit n'est pas une demande d'upgrade valide
    if (requestedTier == CertificationTier.free) {
      throw Exception('Le compte Gratuit est le niveau par défaut, aucune demande nécessaire.');
    }

    final uid = _uid;
    if (uid == null) throw Exception('Non authentifié');

    final current = await getMyCertification();

    if (requestedTier.rank <= current.tier.rank && current.isCertified) {
      throw Exception('Vous avez déjà ce niveau ou un niveau supérieur');
    }

    // Empêcher plusieurs demandes pending
    final existing = await _client
        .from('certification_requests')
        .select('id')
        .eq('user_id', uid)
        .eq('status', 'pending')
        .maybeSingle();

    if (existing != null) {
      throw Exception('Une demande est déjà en cours de traitement');
    }

    await _client.from('certification_requests').insert({
      'user_id': uid,
      'requested_tier': requestedTier.value,
      'current_tier': current.tier.value,
      'status': 'pending',
      'reason': reason,
    });

    // Marquer le profil en pending
    await _client.from('profiles').update({
      'certification_status': CertificationStatus.pending.value,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', uid);
  }

  /// Annuler sa demande en attente
  Future<void> cancelPendingRequest() async {
    final uid = _uid;
    if (uid == null) return;

    await _client
        .from('certification_requests')
        .update({
          'status': 'cancelled',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', uid)
        .eq('status', 'pending');

    await _client.from('profiles').update({
      'certification_status': CertificationStatus.none.value,
    }).eq('id', uid);
  }
}
