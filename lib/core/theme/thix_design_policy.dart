import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ============================================================================
/// THIX DESIGN SYSTEM v1
/// ============================================================================
///
/// SOURCE DE VÉRITÉ UNIQUE
///
/// Utilisé par :
/// - THIX Web
/// - THIX Mobile
/// - THIX PWA
/// - Android
/// - iOS
///
/// PRINCIPES
/// ─────────────────────────────────────────────────────────────────────────────
/// 1. Les couleurs Core THIX sont centralisées ici.
/// 2. La typographie est centralisée ici.
/// 3. Les espacements sont centralisés ici.
/// 4. Les rayons sont centralisés ici.
/// 5. Les dimensions de composants sont centralisées ici.
/// 6. Web et Mobile utilisent les mêmes rôles visuels.
/// 7. Le responsive adapte la disposition, pas l'identité.
/// 8. Les domaines peuvent avoir leur propre accent.
/// 9. Les nouveaux écrans doivent utiliser ThixPolicy / ThemeData.
/// 10. Les anciennes API sont maintenues séparément dans theme.dart.
/// ============================================================================

class ThixPolicy {
  ThixPolicy._();

  // ══════════════════════════════════════════════════════════════════════════
  // 01. BRAND / CORE COLORS
  // ══════════════════════════════════════════════════════════════════════════

  /// THIX primary blue.
  static const Color primary = Color(0xFF2D6CDF);

  /// Dark brand blue.
  static const Color primaryDeep = Color(0xFF123B7A);

  /// Deep ink / brand navy.
  static const Color inkDeep = Color(0xFF0A1F44);

  /// Gold accent.
  static const Color gold = Color(0xFFE3B23C);

  /// Deep gold / premium accent.
  static const Color premiumAccent = Color(0xFFD4A017);

  // ══════════════════════════════════════════════════════════════════════════
  // 02. SURFACES
  // ══════════════════════════════════════════════════════════════════════════

  static const Color surface = Color(0xFFF0F2F5);

  static const Color surfaceSoft = Color(0xFFF7F8FA);

  static const Color surfaceStrong = Color(0xFFE8ECF2);

  static const Color card = Color(0xFFFFFFFF);

  static const Color cardElevated = Color(0xFFFFFFFF);

  static const Color border = Color(0xFFE2E8F0);

  static const Color borderStrong = Color(0xFFCBD5E1);

  static const Color tint = Color(0xFFEEF3FF);

  // ══════════════════════════════════════════════════════════════════════════
  // 03. TEXT COLORS
  // ══════════════════════════════════════════════════════════════════════════

  static const Color textMain = Color(0xFF10192E);

  static const Color textSecondary = Color(0xFF7386A8);

  static const Color textMuted = Color(0xFF94A3B8);

  static const Color textDisabled = Color(0xFFCBD5E1);

  static const Color onBrand = Colors.white;

  // ══════════════════════════════════════════════════════════════════════════
  // 04. SYSTEM STATES
  // ══════════════════════════════════════════════════════════════════════════

  static const Color success = Color(0xFF22C55E);

  static const Color warning = Color(0xFFF59E0B);

  static const Color danger = Color(0xFFEF4444);

  static const Color info = Color(0xFF0284C7);

  // ══════════════════════════════════════════════════════════════════════════
  // 05. DOMAIN COLORS
  // ══════════════════════════════════════════════════════════════════════════
  //
  // Ces couleurs ne remplacent PAS THIX primary.
  //
  // Elles représentent l'identité d'un domaine précis.
  //
  // ══════════════════════════════════════════════════════════════════════════

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

  // ══════════════════════════════════════════════════════════════════════════
  // 06. SPACING
  // ══════════════════════════════════════════════════════════════════════════
  static const double s2 = 2;
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s28 = 28;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;
  static const double s56 = 56;
  static const double s64 = 64;
  // ══════════════════════════════════════════════════════════════════════════
  // 07. RADIUS
  // ══════════════════════════════════════════════════════════════════════════

  static const double rXs = 8;

  static const double rSm = 12;

  static const double rMd = 16;

  static const double rLg = 20;

  static const double rXl = 24;

  static const double r2Xl = 32;

  static const double rFull = 999;

  // ══════════════════════════════════════════════════════════════════════════
  // 08. TYPOGRAPHY FOUNDATION
  // ══════════════════════════════════════════════════════════════════════════

  static const String fontFamily = 'Inter';

  // Sizes

  static const double display = 28;

  static const double h1 = 24;

  static const double h2 = 20;

  static const double h3 = 18;

  static const double title = 16;

  static const double body = 14;

  static const double bodySmall = 13;

  static const double label = 12;

  static const double caption = 11;

  static const double micro = 10;

  // Weights

  static const FontWeight regular = FontWeight.w400;

  static const FontWeight medium = FontWeight.w500;

  static const FontWeight semiBold = FontWeight.w600;

  static const FontWeight bold = FontWeight.w700;

  // ══════════════════════════════════════════════════════════════════════════
  // 09. TYPOGRAPHY — SEMANTIC ROLES
  // ══════════════════════════════════════════════════════════════════════════
  //
  // NOTE : ces styles utilisent désormais GoogleFonts.inter() pour charger
  // réellement la police Inter (au lieu de fontFamily: 'Inter' qui pointait
  // vers une police jamais enregistrée dans l'app → fallback système en gras
  // sur mobile). Ce sont donc des getters, pas des const.
  // ══════════════════════════════════════════════════════════════════════════

  static TextStyle get displayStyle => GoogleFonts.inter(
        fontSize: display,
        fontWeight: bold,
        height: 1.21,
        color: textMain,
      );

  static TextStyle get h1Style => GoogleFonts.inter(
        fontSize: h1,
        fontWeight: bold,
        height: 1.25,
        color: textMain,
      );

  static TextStyle get h2Style => GoogleFonts.inter(
        fontSize: h2,
        fontWeight: bold,
        height: 1.30,
        color: textMain,
      );

  static TextStyle get h3Style => GoogleFonts.inter(
        fontSize: h3,
        fontWeight: semiBold,
        height: 1.33,
        color: textMain,
      );

  static TextStyle get titleStyle => GoogleFonts.inter(
        fontSize: title,
        fontWeight: semiBold,
        height: 1.38,
        color: textMain,
      );

  static TextStyle get bodyStyle => GoogleFonts.inter(
        fontSize: body,
        fontWeight: regular,
        height: 1.43,
        color: textMain,
      );

  static TextStyle get bodyMediumStyle => GoogleFonts.inter(
        fontSize: body,
        fontWeight: medium,
        height: 1.43,
        color: textMain,
      );

  static TextStyle get bodySmallStyle => GoogleFonts.inter(
        fontSize: bodySmall,
        fontWeight: regular,
        height: 1.38,
        color: textSecondary,
      );

  static TextStyle get labelStyle => GoogleFonts.inter(
        fontSize: label,
        fontWeight: semiBold,
        height: 1.33,
        color: textMain,
      );

  static TextStyle get captionStyle => GoogleFonts.inter(
        fontSize: caption,
        fontWeight: medium,
        height: 1.45,
        color: textSecondary,
      );

  static TextStyle get microStyle => GoogleFonts.inter(
        fontSize: micro,
        fontWeight: medium,
        height: 1.4,
        color: textSecondary,
      );

  // ══════════════════════════════════════════════════════════════════════════
  // 10. TYPOGRAPHY — COMPONENT ROLES
  // ══════════════════════════════════════════════════════════════════════════

  /// Page hero / main screen title.
  static TextStyle get heroTitle => h1Style;

  /// Section title.
  static TextStyle get sectionTitle => h3Style;

  /// Card title.
  static TextStyle get cardTitle => titleStyle;

  /// Main body text.
  static TextStyle get bodyText => bodyStyle;

  /// Secondary body text.
  static TextStyle get secondaryText => bodySmallStyle;

  /// Navigation / constellation label.
  static TextStyle get navLabel => labelStyle;

  /// Button text.
  static TextStyle get buttonText => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: bold,
        height: 1.25,
        color: onBrand,
      );

  /// Chip / badge text.
  static TextStyle get chipText => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: semiBold,
        height: 1.2,
        color: onBrand,
      );

  // ══════════════════════════════════════════════════════════════════════════
  // 11. COMPONENT DIMENSIONS
  // ══════════════════════════════════════════════════════════════════════════

  static const double minTapTarget = 44;

  static const double buttonHeight = 48;

  static const double buttonHeightSmall = 40;

  static const double buttonHeightLarge = 52;

  static const double searchBarHeight = 48;

  static const double inputHeight = 48;

  static const double iconButtonSize = 44;

  static const double bottomNavHeight = 64;

  static const double appBarHeight = 72;

  static const double fabSize = 56;

  // ══════════════════════════════════════════════════════════════════════════
  // 12. CARD POLICY
  // ══════════════════════════════════════════════════════════════════════════

  static const EdgeInsets cardPadding = EdgeInsets.all(s16);

  static const EdgeInsets cardPaddingLarge = EdgeInsets.all(s20);

  static const double cardRadius = rLg;

  static const double cardBorderWidth = 1;

  // ══════════════════════════════════════════════════════════════════════════
  // 13. INPUT POLICY
  // ══════════════════════════════════════════════════════════════════════════

  static const EdgeInsets inputPadding = EdgeInsets.symmetric(
    horizontal: s16,
    vertical: s12,
  );

  static const double inputRadius = rMd;

  // ══════════════════════════════════════════════════════════════════════════
  // 14. CONSTELLATION
  // ══════════════════════════════════════════════════════════════════════════

  static const double constellationStageHeight = 360;

  static const double constellationMaxRadius = 148;

  static const double constellationInnerFactor = 0.70;

  static const double constellationHubRadius = 34;

  static const double constellationHubMenuRadius = 58;

  static const double constellationHubMenuNodeSize = 30;

  static const double constellationNodeSize = 46;

  static const double constellationNodeIconSize = 20;

  static const double constellationLabelSize = 12;

  static const double constellationLabelLineHeight = 16;

  static const FontWeight constellationLabelWeight = FontWeight.w600;

  static const double constellationNodeHalf = 23;

  static const double constellationOuterPadding = 34;

  // ══════════════════════════════════════════════════════════════════════════
  // 15. SHADOWS
  // ══════════════════════════════════════════════════════════════════════════

  static List<BoxShadow> shadowCard({
    double opacity = 0.08,
  }) {
    return [
      BoxShadow(
        color: inkDeep.withValues(alpha: opacity),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ];
  }

  static List<BoxShadow> shadowSoft({
    double opacity = 0.06,
  }) {
    return [
      BoxShadow(
        color: inkDeep.withValues(alpha: opacity),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ];
  }

  static List<BoxShadow> shadowNode({
    Color? color,
  }) {
    return [
      BoxShadow(
        color: (color ?? primary).withValues(alpha: 0.18),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ];
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 16. GRADIENTS
  // ══════════════════════════════════════════════════════════════════════════

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      inkDeep,
      primary,
    ],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      gold,
      premiumAccent,
    ],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      inkDeep,
      Color(0xFF1E3A8A),
      Color(0xFF2563EB),
    ],
  );

  // ══════════════════════════════════════════════════════════════════════════
  // 17. TEXT THEME
  // ══════════════════════════════════════════════════════════════════════════
  //
  // Devient un getter car il référence des styles GoogleFonts non-const.
  // ══════════════════════════════════════════════════════════════════════════

  static TextTheme get textTheme => TextTheme(
        displayLarge: displayStyle,

        headlineLarge: h1Style,
        headlineMedium: h2Style,
        headlineSmall: h3Style,

        titleLarge: titleStyle,
        titleMedium: titleStyle,
        titleSmall: labelStyle,

        bodyLarge: bodyStyle,
        bodyMedium: bodyStyle,
        bodySmall: bodySmallStyle,

        labelLarge: labelStyle,
        labelMedium: captionStyle,
        labelSmall: microStyle,
      );

  // ══════════════════════════════════════════════════════════════════════════
  // 18. LIGHT THEME
  // ══════════════════════════════════════════════════════════════════════════

  static ThemeData lightTheme() {
    const colorScheme = ColorScheme.light(
      primary: primary,
      onPrimary: onBrand,
      secondary: gold,
      onSecondary: inkDeep,
      surface: surface,
      onSurface: textMain,
      error: danger,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,

      brightness: Brightness.light,

      fontFamily: GoogleFonts.inter().fontFamily,

      colorScheme: colorScheme,

      scaffoldBackgroundColor: surface,

      textTheme: textTheme,

      splashFactory: InkRipple.splashFactory,

      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: surface,
        foregroundColor: textMain,
        centerTitle: false,
        toolbarHeight: appBarHeight,
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: card,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(
            color: border,
            width: cardBorderWidth,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,

        contentPadding: inputPadding,

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(
            color: border,
          ),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(
            color: border,
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(
            color: primary,
            width: 1.5,
          ),
        ),

        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(
            color: danger,
          ),
        ),

        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(
            color: danger,
            width: 1.5,
          ),
        ),

        hintStyle: bodySmallStyle.copyWith(
          color: textSecondary,
        ),

        labelStyle: bodySmallStyle.copyWith(
          color: textSecondary,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(
            minTapTarget,
            buttonHeight,
          ),
          backgroundColor: primary,
          foregroundColor: onBrand,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: s20,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(rMd),
          ),
          textStyle: buttonText,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(
            minTapTarget,
            buttonHeight,
          ),
          foregroundColor: primary,
          side: const BorderSide(
            color: primary,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: s20,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(rMd),
          ),
          textStyle: buttonText.copyWith(
            color: primary,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(
            minTapTarget,
            minTapTarget,
          ),
          foregroundColor: primary,
          textStyle: buttonText.copyWith(
            color: primary,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(rSm),
          ),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onBrand,
        elevation: 4,
        shape: CircleBorder(),
      ),

      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 19. DARK THEME
  // ══════════════════════════════════════════════════════════════════════════

  static ThemeData darkTheme() {
    const darkBackground = Color(0xFF0A1222);
    const darkSurface = Color(0xFF101B30);
    const darkCard = Color(0xFF14213A);
    const darkBorder = Color(0xFF243451);

    const darkText = Color(0xFFF8FAFC);
    const darkSecondary = Color(0xFFA8B6CC);

    const colorScheme = ColorScheme.dark(
      primary: primary,
      onPrimary: onBrand,
      secondary: gold,
      onSecondary: inkDeep,
      surface: darkSurface,
      onSurface: darkText,
      error: danger,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,

      brightness: Brightness.dark,

      fontFamily: GoogleFonts.inter().fontFamily,

      colorScheme: colorScheme,

      scaffoldBackgroundColor: darkBackground,

      textTheme: textTheme.apply(
        bodyColor: darkText,
        displayColor: darkText,
      ),

      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: darkBackground,
        foregroundColor: darkText,
        centerTitle: false,
        toolbarHeight: appBarHeight,
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: darkCard,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(
            color: darkBorder,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,

        contentPadding: inputPadding,

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(
            color: darkBorder,
          ),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(
            color: darkBorder,
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(
            color: primary,
            width: 1.5,
          ),
        ),

        hintStyle: bodySmallStyle.copyWith(
          color: darkSecondary,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(
            minTapTarget,
            buttonHeight,
          ),
          backgroundColor: primary,
          foregroundColor: onBrand,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: s20,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(rMd),
          ),
          textStyle: buttonText,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(
            minTapTarget,
            buttonHeight,
          ),
          foregroundColor: primary,
          side: const BorderSide(
            color: primary,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: s20,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(rMd),
          ),
          textStyle: buttonText.copyWith(
            color: primary,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(
            minTapTarget,
            minTapTarget,
          ),
          foregroundColor: primary,
          textStyle: buttonText.copyWith(
            color: primary,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(rSm),
          ),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onBrand,
        elevation: 4,
        shape: CircleBorder(),
      ),

      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 20. LEGACY TYPOGRAPHY ALIASES
  // ══════════════════════════════════════════════════════════════════════════

  static const double titleLg = h3;

  static const double titleMd = title;

  static TextStyle get titleLgStyle => h3Style;

  static TextStyle get titleMdStyle => titleStyle;

  // ══════════════════════════════════════════════════════════════════════════
  // 21. DOMAIN HELPER
  // ══════════════════════════════════════════════════════════════════════════

  static Color domainColor(String domain) {
    switch (domain.toLowerCase()) {
      case 'media':
        return domainMedia;

      case 'market':
        return domainMarket;

      case 'learning':
      case 'formation':
      case 'formations':
        return domainLearning;

      case 'jobs':
      case 'emploi':
      case 'emplois':
        return domainJobs;

      case 'info':
      case 'information':
        return domainInfo;

      case 'opportunity':
      case 'opportunite':
      case 'opportunités':
        return domainOpportunity;

      case 'events':
      case 'evenement':
      case 'événements':
        return domainEvents;

      case 'network':
      case 'reseau':
      case 'réseau':
        return domainNetwork;

      case 'health':
      case 'sante':
      case 'santé':
        return domainHealth;

      case 'money':
        return domainMoney;

      case 'gov':
      case 'government':
        return domainGov;

      case 'reservation':
      case 'réservation':
        return domainReservation;

      default:
        return primary;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 22. RESPONSIVE
  // ══════════════════════════════════════════════════════════════════════════

  static const double breakpointMobile = 600;

  static const double breakpointTablet = 900;

  static const double breakpointDesktop = 1200;

  static bool isMobile(BuildContext context) {
    return MediaQuery.sizeOf(context).width < breakpointMobile;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return width >= breakpointMobile &&
        width < breakpointDesktop;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= breakpointDesktop;
  }

  static double contentMaxWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (width >= breakpointDesktop) {
      return 1200;
    }

    if (width >= breakpointTablet) {
      return 960;
    }

    return double.infinity;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (width >= breakpointDesktop) {
      return const EdgeInsets.symmetric(
        horizontal: s32,
      );
    }

    if (width >= breakpointTablet) {
      return const EdgeInsets.symmetric(
        horizontal: s24,
      );
    }

    return const EdgeInsets.symmetric(
      horizontal: s16,
    );
  }
}
