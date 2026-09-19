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

  /// Demande d'upgrade vers un tier supérieur.
  /// ✅ FIX: l'ancienne implémentation faisait un SELECT (vérifier qu'aucune
  /// demande pending n'existe) puis un INSERT séparé — deux appels
  /// concurrents (double-tap, retry réseau) pouvaient tous deux passer le
  /// SELECT avant que l'un des deux n'écrive, créant 2 demandes pending.
  /// L'écriture passe désormais par une RPC transactionnelle
  /// (rpc_request_certification_upgrade) protégée en plus par un index
  /// unique partiel côté DB : même en cas de course, le second INSERT
  /// échoue proprement au lieu de dupliquer la ligne.
  Future<void> requestUpgrade({
    required CertificationTier requestedTier,
    String? reason,
  }) async {
    // 🔒 Règles métier simples : pas besoin d'aller en base pour celles-ci.
    if (requestedTier.isInviteOnly) {
      throw Exception(
        'Le niveau Officiel / Institutions est accessible uniquement sur invitation THIX.',
      );
    }

    if (requestedTier == CertificationTier.free) {
      throw Exception(
          'Le compte Gratuit est le niveau par défaut, aucune demande nécessaire.');
    }

    final uid = _uid;
    if (uid == null) throw Exception('Non authentifié');

    final current = await getMyCertification();
    if (requestedTier.rank <= current.tier.rank && current.isCertified) {
      throw Exception('Vous avez déjà ce niveau ou un niveau supérieur');
    }

    try {
      await _client.rpc('rpc_request_certification_upgrade', params: {
        'p_requested_tier': requestedTier.value,
        'p_reason': reason,
      });
    } on PostgrestException catch (e) {
      // ✅ On traduit les erreurs connues de la RPC en messages utilisateur
      // propres, et on ne laisse jamais un message technique brut remonter.
      if (e.message.contains('already_pending')) {
        throw Exception('Une demande est déjà en cours de traitement');
      }
      if (e.message.contains('not_authenticated')) {
        throw Exception('Non authentifié');
      }
      debugPrint('requestUpgrade rpc error: $e');
      throw Exception('Impossible d\'envoyer la demande. Réessayez plus tard.');
    }
  }

  /// Annuler sa demande en attente.
  /// ✅ FIX: passe désormais par une RPC transactionnelle qui ne remet le
  /// profil à "none" que si une demande a réellement été annulée ET que le
  /// profil est encore "pending" — élimine le risque d'écraser un statut
  /// "approved"/"generated" déjà confirmé par un webhook de paiement
  /// pendant que le client tentait ce fallback suite à une erreur réseau.
  Future<void> cancelPendingRequest() async {
    final uid = _uid;
    if (uid == null) return;

    try {
      await _client.rpc('rpc_cancel_pending_certification');
    } catch (e) {
      debugPrint('cancelPendingRequest rpc error: $e');
    }
  }
}
