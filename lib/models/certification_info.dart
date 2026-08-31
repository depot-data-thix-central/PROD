// lib/models/certification_info.dart

import 'package:thix_id/models/certification_tier.dart';

class CertificationInfo {
  final bool isCertified;
  final CertificationTier tier;
  final CertificationStatus status;

  const CertificationInfo({
    required this.isCertified,
    required this.tier,
    required this.status,
  });

  /// État par défaut quand l'utilisateur n'a rien demandé
  static const empty = CertificationInfo(
    isCertified: false,
    tier: CertificationTier.free,
    status: CertificationStatus.none,
  );
}
