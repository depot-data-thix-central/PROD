// lib/presentation/thix_media/providers/media_certification_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/models/certification_tier.dart';

/// Convertit un texte de niveau en CertificationTier avec le même parseur
/// que le dashboard. Retourne null si gratuit / inconnu.
CertificationTier? parseCertTier(String? tier, {String? status}) {
  if (tier == null || tier.trim().isEmpty) return null;
  final t = CertificationTierX.parse(tier);
  return t == CertificationTier.free ? null : t;
}

bool _statusOk(dynamic raw) {
  final s = CertificationStatusX.parse(raw);
  return s == CertificationStatus.approved ||
      s == CertificationStatus.generated;
}

/// Niveau de certification réel d'un utilisateur (null = non certifié).
/// Même source que le dashboard :
/// - mon compte : rpc_get_my_certification
/// - autres comptes : colonnes certification_* de profiles
Future<CertificationTier?> resolveUserCertTier(String userId) async {
  if (userId.trim().isEmpty) return null;
  final client = Supabase.instance.client;

  Map<String, dynamic>? row;

  if (client.auth.currentUser?.id == userId) {
    try {
      final res = await client
          .rpc('rpc_get_my_certification')
          .timeout(const Duration(seconds: 5));
      if (res is List && res.isNotEmpty) {
        row = Map<String, dynamic>.from(res.first as Map);
      }
    } catch (_) {}
  }

  if (row == null) {
    try {
      final p = await client
          .from('profiles')
          .select('certification_tier, certification_status')
          .eq('id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));
      if (p != null) row = Map<String, dynamic>.from(p);
    } catch (_) {}
  }

  if (row == null) return null;
  if (!_statusOk(row['certification_status'])) return null;

  final tier = CertificationTierX.parse(row['certification_tier']);
  return tier == CertificationTier.free ? null : tier;
}

/// Niveau de certification d'un utilisateur (mis en cache par userId).
final mediaUserCertTierProvider =
    FutureProvider.family<CertificationTier?, String>((ref, userId) {
  return resolveUserCertTier(userId);
});
