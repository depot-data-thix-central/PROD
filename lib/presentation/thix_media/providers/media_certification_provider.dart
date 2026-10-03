// lib/presentation/thix_media/providers/media_certification_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/models/certification_tier.dart';

/// Même règle que le dashboard : seuls approved / generated comptent.
const Set<String> _kOkStatus = {'approved', 'generated'};

bool _statusOk(dynamic raw) =>
    _kOkStatus.contains((raw ?? '').toString().trim().toLowerCase());

/// Convertit un texte de niveau en CertificationTier.
/// Retourne null si vide, gratuit ou inconnu : jamais de niveau par défaut.
CertificationTier? parseCertTier(String? tier, {String? status}) {
  final raw = (tier ?? '').trim().toLowerCase();
  if (raw.isEmpty || raw == 'free' || raw == 'none' || raw == 'gratuit') {
    return null;
  }
  final t = CertificationTierX.parse(raw);
  return t == CertificationTier.free ? null : t;
}

/// Niveau de certification réel d'un utilisateur (null = non certifié).
/// - mon compte : rpc_get_my_certification (même source que le dashboard)
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

  if (kDebugMode) {
    debugPrint(
        '[MediaCert] $userId tier=${row['certification_tier']} status=${row['certification_status']}');
  }

  if (!_statusOk(row['certification_status'])) return null;
  return parseCertTier(row['certification_tier']?.toString());
}

/// Niveau de certification d'un utilisateur (mis en cache par userId).
final mediaUserCertTierProvider =
    FutureProvider.family<CertificationTier?, String>((ref, userId) {
  return resolveUserCertTier(userId);
});
