import 'package:flutter/material.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

/// ============================================================================
/// THIX LEGACY THEME BRIDGE
/// ============================================================================
///
/// ⚠️ NOT THE SOURCE OF TRUTH
///
/// The official THIX Design System is:
///
///     lib/design_system/thix_policy.dart
///
/// This file exists only for backward compatibility with legacy modules.
///
/// NEW CODE:
///     Use ThixPolicy.
///     Use Theme.of(context).
///
/// Do not add new design tokens here.
/// Do not create a second theme here.
/// ============================================================================


// ════════════════════════════════════════════════════════════════════════════
// LEARNING / CYBER
// ════════════════════════════════════════════════════════════════════════════

@immutable
class LearningCyberColors {
  const LearningCyberColors._();

  static const Color bg0 = Color(0xFF070B14);
  static const Color panel = Color(0xFF101A2B);
  static const Color panelHi = Color(0xFF162238);
  static const Color stroke = Color(0xFF2A3A57);

  static const Color text = Color(0xFFEAF2FF);
  static const Color textDim = Color(0xFF9CB0D2);

  static const Color neonCyan = Color(0xFF22E7FF);
  static const Color neonViolet = Color(0xFF8B5CF6);
  static const Color electricBlue = Color(0xFF2F80FF);

  static const Color success = ThixPolicy.success;
  static const Color danger = ThixPolicy.danger;
  static const Color warning = ThixPolicy.warning;

  static const Color black = Colors.black;
  static const Color white = Colors.white;
}

@immutable
class LearningCyberGradients {
  const LearningCyberGradients._();

  static Gradient background() {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF050912),
        Color(0xFF0A1222),
        Color(0xFF101A2B),
      ],
      stops: [
        0.0,
        0.45,
        1.0,
      ],
    );
  }

  static Gradient glowBlue() {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x3322E7FF),
        Color(0x1A2F80FF),
      ],
    );
  }

  static Gradient glowViolet() {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x338B5CF6),
        Color(0x1A22E7FF),
      ],
    );
  }
}


// ════════════════════════════════════════════════════════════════════════════
// INSTITUTIONAL
// ════════════════════════════════════════════════════════════════════════════

@immutable
class InstitutionalColors {
  const InstitutionalColors._();

  static const Color civicBlue = Color(0xFF1565C0);
  static const Color civicBlueSoft = Color(0xFF4F8FD8);
  static const Color navy = Color(0xFF0C2340);
  static const Color navy2 = Color(0xFF163A63);
}


// ════════════════════════════════════════════════════════════════════════════
// ADMIN CYBER
// ════════════════════════════════════════════════════════════════════════════

@immutable
class AdminCyberColors {
  const AdminCyberColors._();

  static const Color black = LearningCyberColors.black;
  static const Color panel = LearningCyberColors.panel;
  static const Color panelHi = LearningCyberColors.panelHi;
  static const Color stroke = LearningCyberColors.stroke;

  static const Color text = LearningCyberColors.text;
  static const Color textDim = LearningCyberColors.textDim;

  static const Color neonCyan = LearningCyberColors.neonCyan;
  static const Color neonViolet = LearningCyberColors.neonViolet;
  static const Color electricBlue = LearningCyberColors.electricBlue;

  static const Color success = LearningCyberColors.success;
  static const Color danger = LearningCyberColors.danger;
}

@immutable
class AdminCyberGradients {
  const AdminCyberGradients._();

  static Gradient glowBlue() {
    return LearningCyberGradients.glowBlue();
  }

  static Gradient glowViolet() {
    return LearningCyberGradients.glowViolet();
  }
}


// ════════════════════════════════════════════════════════════════════════════
// MARKET
// ════════════════════════════════════════════════════════════════════════════

@immutable
class MarketColors {
  const MarketColors._();

  static const Color bg = ThixPolicy.surface;
  static const Color stroke = ThixPolicy.border;
  static const Color ink = ThixPolicy.textMain;
  static const Color grayText = ThixPolicy.textSecondary;

  static const Color orange = ThixPolicy.domainMarket;
  static const Color orangeDeep = Color(0xFFEA580C);
}


// ════════════════════════════════════════════════════════════════════════════
// THIX HOME
// ════════════════════════════════════════════════════════════════════════════

@immutable
class ThixHomeColors {
  const ThixHomeColors._();

  static const Color primary = ThixPolicy.domainMarket;
  static const Color primaryLight = Color(0xFFFF6B35);
  static const Color primaryDark = Color(0xFFC44A1F);

  static const Color secondary = ThixPolicy.primary;

  static const Color background = ThixPolicy.surface;
  static const Color surface = ThixPolicy.card;

  static const Color textPrimary = ThixPolicy.textMain;
  static const Color textSecondary = ThixPolicy.textSecondary;
  static const Color textLight = ThixPolicy.textMuted;

  static const Color border = ThixPolicy.border;

  static const Color success = ThixPolicy.success;
  static const Color warning = ThixPolicy.warning;
  static const Color error = ThixPolicy.danger;

  static const Color primaryBlue = ThixPolicy.primary;
  static const Color darkNavy = ThixPolicy.inkDeep;

  static const Color marketPrimary = primary;
  static const Color marketBackground = background;
  static const Color marketTextPrimary = textPrimary;
}


// ════════════════════════════════════════════════════════════════════════════
// LIGHT MODE LEGACY
// ════════════════════════════════════════════════════════════════════════════

@immutable
class LightModeColors {
  const LightModeColors._();

  static const Color background = ThixPolicy.surface;
  static const Color surface = ThixPolicy.card;
  static const Color divider = ThixPolicy.border;
  static const Color hint = ThixPolicy.textMuted;

  static const Color primary = ThixPolicy.primary;
  static const Color secondary = ThixPolicy.primaryDeep;
  static const Color accent = ThixPolicy.info;

  static const Color primaryText = ThixPolicy.textMain;
  static const Color secondaryText = ThixPolicy.textSecondary;
  static const Color onSurface = ThixPolicy.textMain;

  static const Color success = ThixPolicy.success;
  static const Color error = ThixPolicy.danger;
  static const Color emergencyRed = Color(0xFFDC2626);

  static const Color cyberDarkBlue = DarkModeColors.cyberDarkBlue;

  static const Color metalGold = ThixPolicy.gold;
  static const Color metalGoldSoft = Color(0xFFE8D89A);
  static const Color metalGoldDeep = ThixPolicy.premiumAccent;
}


// ════════════════════════════════════════════════════════════════════════════
// DARK MODE LEGACY
// ════════════════════════════════════════════════════════════════════════════

@immutable
class DarkModeColors {
  const DarkModeColors._();

  static const Color background = ThixPolicy.inkDeep;

  static const Color primary = Color(0xFF0B1220);

  static const Color cyberDarkBlue = Color(0xFF0D1B2A);

  static const Color emergencyRed = ThixPolicy.danger;

  static const Color success = ThixPolicy.success;

  static const Color metalGold = ThixPolicy.gold;
  static const Color metalGoldSoft = Color(0xFFE8D89A);
  static const Color metalGoldDeep = ThixPolicy.premiumAccent;

  static const Color text = LearningCyberColors.text;
  static const Color textDim = LearningCyberColors.textDim;
  static const Color danger = ThixPolicy.danger;
}


// ════════════════════════════════════════════════════════════════════════════
// EMERGENCY
// ════════════════════════════════════════════════════════════════════════════

@immutable
class EmergencyMedicalSheetColors {
  const EmergencyMedicalSheetColors._();

  static const Color stroke = Color(0xFF1E3A8A);
}

@immutable
class EmergencyMedicalSheetGradients {
  const EmergencyMedicalSheetGradients._();

  static Gradient background() {
    return const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF0B1220),
        Color(0xFF111C34),
      ],
    );
  }
}

@immutable
class EmergencyUrgencyScaleColors {
  const EmergencyUrgencyScaleColors._();

  static const Color stable = ThixPolicy.success;
  static const Color moderate = ThixPolicy.warning;
  static const Color urgent = Color(0xFFF97316);
  static const Color critical = ThixPolicy.danger;
}

@immutable
class EmergencyUrgentColors {
  const EmergencyUrgentColors._();

  static const Color bg0 = LearningCyberColors.bg0;
  static const Color bg1 = DarkModeColors.primary;

  static const Color panel = LearningCyberColors.panel;
  static const Color card = LearningCyberColors.panelHi;

  static const Color stroke = LearningCyberColors.stroke;

  static const Color text = LearningCyberColors.text;
  static const Color textDim = LearningCyberColors.textDim;

  static const Color danger = LearningCyberColors.danger;
  static const Color amber = ThixPolicy.warning;
  static const Color cyan = LearningCyberColors.neonCyan;

  static const Color medicalBlue = Color(0xFF38BDF8);
  static const Color fireOrange = Color(0xFFF97316);

  static const Color safetyGreen = ThixPolicy.success;
  static const Color violet = LearningCyberColors.neonViolet;

  static Color scrim() {
    return const Color(0xCC020617);
  }
}

@immutable
class EmergencyUrgentGradients {
  const EmergencyUrgentGradients._();

  static Gradient background() {
    return const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        EmergencyUrgentColors.bg0,
        EmergencyUrgentColors.bg1,
      ],
    );
  }

  static Gradient panel() {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        EmergencyUrgentColors.panel,
        EmergencyUrgentColors.card,
      ],
    );
  }
}


// ════════════════════════════════════════════════════════════════════════════
// LEGACY THEME GETTERS
// ════════════════════════════════════════════════════════════════════════════
//
// Ces getters permettent aux anciennes pages de continuer à utiliser:
//
//     theme: lightTheme
//     darkTheme: darkTheme
//
// Mais le ThemeData vient maintenant de ThixPolicy.
//

ThemeData get lightTheme => ThixPolicy.lightTheme();

ThemeData get darkTheme => ThixPolicy.darkTheme();


// ════════════════════════════════════════════════════════════════════════════
// LEGACY SPACING
// ════════════════════════════════════════════════════════════════════════════

class AppSpacing {
  const AppSpacing._();

  static const double xs = ThixPolicy.s4;
  static const double sm = ThixPolicy.s8;
  static const double sm2 = ThixPolicy.s12;

  static const double md = ThixPolicy.s16;
  static const double md2 = ThixPolicy.s20;

  static const double lg = ThixPolicy.s24;
  static const double xl = ThixPolicy.s32;
  static const double xxl = ThixPolicy.s48;

  static const EdgeInsets paddingMd = EdgeInsets.all(md);

  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(
    horizontal: md,
  );

  static const EdgeInsets verticalMd = EdgeInsets.symmetric(
    vertical: md,
  );
}


// ════════════════════════════════════════════════════════════════════════════
// LEGACY RADIUS
// ════════════════════════════════════════════════════════════════════════════

class AppRadius {
  const AppRadius._();

  static const double sm = ThixPolicy.rSm;
  static const double md = ThixPolicy.rMd;
  static const double lg = ThixPolicy.rLg;
  static const double xl = ThixPolicy.rXl;
  static const double full = ThixPolicy.rFull;
}


// ════════════════════════════════════════════════════════════════════════════
// CONTEXT EXTENSIONS
// ════════════════════════════════════════════════════════════════════════════

extension ThixThemeX on BuildContext {
  TextTheme get textStyles {
    return Theme.of(this).textTheme;
  }
}


// ════════════════════════════════════════════════════════════════════════════
// TEXT STYLE EXTENSIONS
// ════════════════════════════════════════════════════════════════════════════

extension ThixTextStyleX on TextStyle {
  TextStyle get semiBold {
    return copyWith(
      fontWeight: FontWeight.w600,
    );
  }

  TextStyle get bold {
    return copyWith(
      fontWeight: FontWeight.w700,
    );
  }
}
