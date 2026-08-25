// lib/core/theme/thix_design_policy.dart
import 'package:flutter/material.dart';

/// ══════════════════════════════════════════════════════════════════════════
/// THIX DESIGN SYSTEM v2.0 — "Premium Light Enterprise"
/// ══════════════════════════════════════════════════════════════════════════
/// Cette charte visuelle unifie l'application autour d'un design clair, 
/// luxueux, et institutionnel (inspiré des néo-banques et de l'écosystème Apple).
/// Fini les fonds sombres/ternes, place au Glassmorphism clair et au minimalisme.

class ThixPolicy {
  ThixPolicy._();

  // ─── 1. PALETTE DE COULEURS FONDAMENTALES ────────────────────────────────
  
  /// Fond principal de l'application (Gris-Bleu ultra clair, très luxueux)
  static const Color surfaceSoft = Color(0xFFF8FAFC); // Slate 50
  
  /// Fond des cartes et conteneurs (Blanc pur)
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);

  // ─── 2. COULEURS DE MARQUE (Brand) ───────────────────────────────────────
  
  /// Bleu THIX Institutionnel (Confiance, Finance, Sécurité)
  static const Color primary = Color(0xFF2563EB); // Blue 600
  
  /// Indigo/Bleu très sombre pour les accents premium et textes forts
  static const Color primaryDeep = Color(0xFF1E1B4B); // Indigo 950
  
  /// Noir "Encre" pour les éléments nécessitant un contraste absolu
  static const Color inkDeep = Color(0xFF0F172A); // Slate 900
  
  /// Couleur de fond teintée (ex: fond d'icône avec primary)
  static const Color tint = Color(0xFFEFF6FF); // Blue 50

  // ─── 3. TEXTES & BORDURES ────────────────────────────────────────────────
  
  /// Texte principal (Presque noir, excellente lisibilité)
  static const Color textMain = Color(0xFF0F172A); // Slate 900
  
  /// Texte secondaire (Gris élégant)
  static const Color textSecondary = Color(0xFF64748B); // Slate 500
  
  /// Bordures très douces pour délimiter les cartes blanches
  static const Color border = Color(0xFFE2E8F0); // Slate 200
  static const Color borderStrong = Color(0xFFCBD5E1); // Slate 300

  // ─── 4. COULEURS SÉMANTIQUES (Feedback) ──────────────────────────────────
  
  static const Color success = Color(0xFF059669); // Emerald 600
  static const Color danger = Color(0xFFDC2626); // Red 600
  static const Color warning = Color(0xFFD97706); // Amber 600
  static const Color gold = Color(0xFFF59E0B); // Doré Premium (Amber 500)

  // ─── 5. COULEURS DES DOMAINES / MODULES ──────────────────────────────────
  // Utilisées dans la grille de services pour différencier les écosystèmes
  
  static const Color domainHealth = Color(0xFF0D9488); // Teal (THIX Santé)
  static const Color domainMarket = Color(0xFF7C3AED); // Violet (THIX Market)
  static const Color domainEvents = Color(0xFFE11D48); // Rose/Rouge (THIX Event)
  static const Color domainOpportunity = Color(0xFFD97706); // Ambre (Opportunités)
  static const Color domainJobs = Color(0xFF0284C7); // Cyan (Emplois)
  static const Color domainNetwork = Color(0xFF4F46E5); // Indigo (Réseau Pro)
  static const Color domainLearning = Color(0xFF059669); // Emeraude (Formations)
  static const Color domainMedia = Color(0xFFBE123C); // Rose foncé (Médias/TDIA)
  static const Color domainInfo = Color(0xFF475569); // Ardoise (Actualités)
  static const Color premiumAccent = Color(0xFFB45309); // Accent Doré foncé

  // ─── 6. DÉGRADÉS ─────────────────────────────────────────────────────────

  /// Dégradé Premium pour les cartes VIP, Boutons d'action majeurs, etc.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2563EB), // primary
      Color(0xFF1E3A8A), // variant deep blue
    ],
  );

  // ─── 7. TYPOGRAPHIE & ESPACEMENTS ────────────────────────────────────────

  static const double s8 = 8.0;
  static const double s12 = 12.0;
  static const double s16 = 16.0;
  static const double s20 = 20.0;
  static const double s24 = 24.0;
  static const double s32 = 32.0;

  static const double rSm = 8.0;
  static const double rMd = 12.0;
  static const double rLg = 16.0;
  static const double rXl = 24.0;
  static const double r2Xl = 32.0;
  static const double rFull = 999.0;
  
  /// Rayon standard pour les champs de texte
  static const double inputRadius = 16.0;

  // ─── 8. CONSTANTES HÉRITÉES (Rétrocompatibilité) ─────────────────────────
  // Permet de ne pas casser les widgets qui utilisent encore ces variables
  
  static const double constellationStageHeight = 340.0;
  static const double constellationHubRadius = 35.0;
  static const double constellationMaxRadius = 140.0;
  static const double constellationOuterPadding = 20.0;
  
  static const double constellationNodeSize = 48.0;
  static const double constellationNodeHalf = 24.0;
  static const double constellationNodeIconSize = 22.0;

  // ─── 9. OMBRES (Shadows) CLAIRES & PREMIUM ───────────────────────────────
  
  /// Ombre très diffuse pour faire décoller les cartes de l'arrière-plan
  static List<BoxShadow> shadowSoft() {
    return [
      BoxShadow(
        color: Colors.black.withOpacity(0.03),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ];
  }

  /// Ombre un peu plus prononcée pour les cartes interactives ou flottantes
  static List<BoxShadow> shadowCard() {
    return [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 15,
        offset: const Offset(0, 6),
      ),
    ];
  }
}
