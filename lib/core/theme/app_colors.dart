import 'package:flutter/material.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

/// AppColors — façade stable pour tout le projet.
/// Toutes les valeurs viennent de ThixPolicy (même aspect Web + Mobile).
class AppColors {
  AppColors._();

  // ── Marque ──────────────────────────────────────────────
  static const Color primaryBlue = ThixPolicy.primary;       // 0xFF2D6CDF
  static const Color darkNavy = ThixPolicy.inkDeep;          // 0xFF0A1F44
  static const Color premiumAccent = ThixPolicy.primaryDeep; // 0xFF123B7A
  static const Color goldBadge = ThixPolicy.gold;            // 0xFFE3B23C

  // ── Surfaces ────────────────────────────────────────────
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGrayBg = ThixPolicy.surface;       // 0xFFF0F2F5
  static const Color cardBorder = ThixPolicy.border;         // 0xFFE2E8F0

  // ── Texte ───────────────────────────────────────────────
  static const Color darkText = ThixPolicy.textMain;         // 0xFF10192E
  static const Color textSecondary = ThixPolicy.textSecondary; // 0xFF7386A8

  // ── États ───────────────────────────────────────────────
  static const Color successGreen = ThixPolicy.success;      // 0xFF22C55E
  static const Color dangerRed = ThixPolicy.danger;          // 0xFFEF4444

  // ── Ombres (alpha inclus) ───────────────────────────────
  static const Color shadowLight = Color(0x0F000000);
  static const Color shadowSecondary = Color(0x0A000000);

  // ── Premium soft (cartes / fonds) ───────────────────────
  static const Color premiumSoftStart = Color(0xFFEAF2FF);
  static const Color premiumSoftEnd = Color(0xFFFFFFFF);

  // ── Domaines (constellation / services) ─────────────────
  static const Color domainMedia = Color(0xFF7C3AED);
  static const Color domainMarket = Color(0xFFF97316);
  static const Color domainLearning = Color(0xFF2563EB);
  static const Color domainJobs = Color(0xFF16A34A);
  static const Color domainInfo = Color(0xFF0284C7);
  static const Color domainOpportunity = Color(0xFFF59E0B);
  static const Color domainEvents = Color(0xFFEF4444);
  static const Color domainNetwork = Color(0xFF4F46E5);
  static const Color domainHealth = Color(0xFFE11D48);
  static const Color domainMoney = Color(0xFF059669);
  static const Color domainGov = Color(0xFF334155);
  static const Color domainReservation = Color(0xFF0D9488);
}

class AppSpacing {
  static const double xs = ThixPolicy.s4;
  static const double s = ThixPolicy.s8;
  static const double m = ThixPolicy.s12;
  static const double l = ThixPolicy.s16;
  static const double xl = ThixPolicy.s20;
  static const double xxl = ThixPolicy.s24;
  static const double xxxl = 28;
  static const double huge = ThixPolicy.s32;
}

class AppRadius {
  static const double searchBar = 24;
  static const double mainCard = ThixPolicy.rXl;      // 24
  static const double serviceCard = ThixPolicy.rLg;   // 20
  static const double button = 14;
  static const double bottomNav = 30;
  static const double avatar = 50;
  static const double qrContainer = ThixPolicy.rMd;   // 16
}

class AppShadows {
  static List<BoxShadow> main = ThixPolicy.shadowCard();
  static List<BoxShadow> secondary = ThixPolicy.shadowSoft();
}
