// lib/models/certification_tier.dart
import 'package:flutter/material.dart';

/// Niveaux de certification THIX (alignés sur l'image produit)
enum CertificationTier {
  free,       // Gris  — compte gratuit (défaut)
  standard,   // Bleu  — utilisateurs individuels
  premium,    // Or    — fonctionnalités avancées
  enterprise, // Noir  — organisations
  official,   // Rouge — institutions / officiels
}

extension CertificationTierX on CertificationTier {
  /// Valeur stockée en DB — DOIT correspondre à l'enum Postgres
  /// certification_tier_enum ('gratuit','standard','premium','entreprise','officiel')
  String get value => switch (this) {
        CertificationTier.free => 'gratuit',
        CertificationTier.standard => 'standard',
        CertificationTier.premium => 'premium',
        CertificationTier.enterprise => 'entreprise',
        CertificationTier.official => 'officiel',
      };

  String get labelFr => switch (this) {
        CertificationTier.free => 'Compte Gratuit',
        CertificationTier.standard => 'Compte Standard',
        CertificationTier.premium => 'Compte Premium',
        CertificationTier.enterprise => 'Compte Entreprise',
        CertificationTier.official => 'Officiel / Institutions',
      };

  String get shortLabel => switch (this) {
        CertificationTier.free => 'Gratuit',
        CertificationTier.standard => 'Standard',
        CertificationTier.premium => 'Premium',
        CertificationTier.enterprise => 'Entreprise',
        CertificationTier.official => 'Officiel',
      };

  String get descriptionFr => switch (this) {
        CertificationTier.free =>
          'Accès de base gratuit. Publication limitée, idéal pour découvrir THIX ID.',
        CertificationTier.standard =>
          'Pour les utilisateurs individuels. Accès aux fonctionnalités de base et à la certification d\'identité.',
        CertificationTier.premium =>
          'Pour ceux qui veulent plus. Fonctionnalités avancées, certification prioritaire et expérience améliorée.',
        CertificationTier.enterprise =>
          'Pour les organisations et entreprises. Gestion d\'équipe, contrôle avancé et solutions sur mesure.',
        CertificationTier.official =>
          'Pour les entités officielles et les institutions de confiance. Niveau d\'accès le plus élevé et certification renforcée.',
      };

  /// Couleur principale du sceau (image)
  Color get badgeColor => switch (this) {
        CertificationTier.free => const Color(0xFF9CA3AF), // gris
        CertificationTier.standard => const Color(0xFF2563EB), // bleu
        CertificationTier.premium => const Color(0xFFD4A017), // or
        CertificationTier.enterprise => const Color(0xFF111827), // noir
        CertificationTier.official => const Color(0xFFDC2626), // rouge
      };

  IconData get icon => switch (this) {
        CertificationTier.free => Icons.person_outline_rounded,
        CertificationTier.standard => Icons.person_rounded,
        CertificationTier.premium => Icons.workspace_premium_rounded,
        CertificationTier.enterprise => Icons.business_center_rounded,
        CertificationTier.official => Icons.verified_user_rounded,
      };

  int get rank => switch (this) {
        CertificationTier.free => 0,
        CertificationTier.standard => 1,
        CertificationTier.premium => 2,
        CertificationTier.enterprise => 3,
        CertificationTier.official => 4,
      };

  bool get isAtLeastPremium => rank >= CertificationTier.premium.rank;
  bool get isOrganization =>
      this == CertificationTier.enterprise || this == CertificationTier.official;

  static CertificationTier parse(Object? raw) {
    final v = (raw ?? '').toString().trim().toLowerCase();
    return switch (v) {
      'standard' => CertificationTier.standard,
      'premium' => CertificationTier.premium,
      'enterprise' || 'entreprise' => CertificationTier.enterprise,
      'official' || 'officiel' || 'institution' => CertificationTier.official,
      _ => CertificationTier.free, // 'gratuit', 'free', 'none', '', valeur inconnue
    };
  }

  /// Prix en USD (0 = gratuit, null = sur invitation)
  double? get priceUsd => switch (this) {
        CertificationTier.free => 0.0,
        CertificationTier.standard => 3.0,
        CertificationTier.premium => 7.0,
        CertificationTier.enterprise => 30.0,
        CertificationTier.official => null,
      };

  bool get isInviteOnly => this == CertificationTier.official;
  bool get isPaid => priceUsd != null && priceUsd! > 0;
}

/// Statut de la demande / génération de certification
enum CertificationStatus {
  none,
  pending,
  approved,
  rejected,
  generated, // ex. Premium "GÉNÉRÉ" sur l'image
}

extension CertificationStatusX on CertificationStatus {
  String get value => name;

  String get labelFr => switch (this) {
        CertificationStatus.none => 'Non certifié',
        CertificationStatus.pending => 'En cours',
        CertificationStatus.approved => 'Approuvé',
        CertificationStatus.rejected => 'Rejeté',
        CertificationStatus.generated => 'Généré',
      };

  static CertificationStatus parse(Object? raw) {
    final v = (raw ?? '').toString().trim().toLowerCase();
    return switch (v) {
      'pending' || 'en_cours' => CertificationStatus.pending,
      'approved' || 'approuve' || 'vérifié' || 'verified' => CertificationStatus.approved,
      'rejected' || 'rejete' => CertificationStatus.rejected,
      'generated' || 'genere' => CertificationStatus.generated,
      _ => CertificationStatus.none,
    };
  }
}
