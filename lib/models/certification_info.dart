// lib/models/certification_info.dart

import 'package:thix_id/models/certification_tier.dart';

// Si tu n'as pas non plus l'enum CertificationStatus défini ailleurs, 
// tu peux le laisser ici. S'il existe déjà dans certification_tier.dart, 
// supprime juste cette partie `enum CertificationStatus {...}`.
enum CertificationStatus {
  none,
  pending,
  approved,
  rejected,
}

extension CertificationStatusExtension on CertificationStatus {
  String get labelFr {
    switch (this) {
      case CertificationStatus.pending:
        return 'En attente';
      case CertificationStatus.approved:
        return 'Validé';
      case CertificationStatus.rejected:
        return 'Rejeté';
      case CertificationStatus.none:
        return 'Non certifié';
    }
  }
}

// La fameuse classe qui te manquait :
class CertificationInfo {
  final bool isCertified;
  final CertificationTier tier;
  final CertificationStatus status;

  const CertificationInfo({
    required this.isCertified,
    required this.tier,
    required this.status,
  });

  // Juste au cas où tu aurais besoin d'un état par défaut
  static const empty = CertificationInfo(
    isCertified: false,
    tier: CertificationTier.free, // ou le nom exact de ton tier gratuit
    status: CertificationStatus.none,
  );
}
