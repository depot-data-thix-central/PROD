// lib/presentation/thix_media/providers/media_certification_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/models/certification_tier.dart';

const Set<String> _kOkStatus = {
  'approved',
  'generated',
  'active',
  'verified',
  'paid',
  'valid',
};

/// Convertit (tier, status) texte en niveau de certification.
/// Retourne null si l'utilisateur n'est pas certifié.
CertificationTier? parseCertTier(String? tier, {String? status}) {
  final t = (tier ?? '').trim().toLowerCase();
  final s = (status ?? '').trim().toLowerCase();

  switch (t) {
    case 'standard':
      return CertificationTier.standard;
    case 'premium':
      return CertificationTier.premium;
    case 'enterprise':
      return CertificationTier.enterprise;
    case 'official':
      return CertificationTier.official;
  }
  if (_kOkStatus.contains(s)) return CertificationTier.standard;
  return null;
}

/// Niveau de certification d'un utilisateur (mis en cache par userId).
final mediaUserCertTierProvider =
    FutureProvider.family<CertificationTier?, String>((ref, userId) async {
  if (userId.trim().isEmpty) return null;
  final client = Supabase.instance.client;
  String? tier;
  String? status;

  try {
    final p = await client
        .from('profiles')
        .select('certification_tier, certification_status')
        .eq('id', userId)
        .maybeSingle()
        .timeout(const Duration(seconds: 5));
    tier = (p?['certification_tier'] as String?)?.trim();
    status = (p?['certification_status'] as String?)?.trim();
  } catch (_) {}

  if ((tier == null || tier.isEmpty) && (status == null || status.isEmpty)) {
    try {
      final c = await client
          .from('certifications')
          .select('tier, status')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 3));
      if (c != null) {
        tier = (c['tier'] as String?)?.trim();
        status = (c['status'] as String?)?.trim();
      }
    } catch (_) {}
  }

  return parseCertTier(tier, status: status);
});
