import 'package:flutter/foundation.dart';

/// Verification status used across the app for profile credentials (formations,
/// cursus scolaire, experiences) and identity documents.
///
/// Stored as a simple string to stay compatible with jsonb payloads in Supabase.
enum VerificationStatus {
  pending,
  verified,
  rejected,
}

extension VerificationStatusX on VerificationStatus {
  String get value => switch (this) {
        VerificationStatus.pending => 'pending',
        VerificationStatus.verified => 'verified',
        VerificationStatus.rejected => 'rejected',
      };

  String get labelFr => switch (this) {
        VerificationStatus.pending => 'En attente de vérification',
        VerificationStatus.verified => 'Vérifié',
        VerificationStatus.rejected => 'Rejeté',
      };

  static VerificationStatus parse(Object? raw) {
    final v = (raw ?? '').toString().trim().toLowerCase();
    if (v == 'verified' || v == 'verifie' || v == 'vérifié') return VerificationStatus.verified;
    if (v == 'rejected' || v == 'rejete' || v == 'rejeté') return VerificationStatus.rejected;
    return VerificationStatus.pending;
  }
}

@immutable
class EvidenceFileRef {
  /// Supabase Storage object path (preferred) or any URL.
  final String storagePathOrUrl;
  final String? label;

  const EvidenceFileRef({required this.storagePathOrUrl, this.label});

  Map<String, dynamic> toJson() => {'path': storagePathOrUrl, if (label != null) 'label': label};

  static EvidenceFileRef? tryParse(Object? raw) {
    if (raw is String) {
      final t = raw.trim();
      if (t.isEmpty) return null;
      return EvidenceFileRef(storagePathOrUrl: t);
    }
    if (raw is Map) {
      final m = raw.cast<String, dynamic>();
      final path = (m['path'] ?? m['url'] ?? '').toString().trim();
      if (path.isEmpty) return null;
      final label = (m['label'] ?? m['title'])?.toString();
      return EvidenceFileRef(storagePathOrUrl: path, label: (label ?? '').trim().isEmpty ? null : label);
    }
    return null;
  }
}
