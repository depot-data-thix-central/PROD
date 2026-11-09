// ════════════════════════════════════════════════════════════════════════════
//  THIX PORTFOLIO BUSINESS — MODÈLE DE THÈME
//  Fichier  : lib/presentation/thix_portfolio/models/business_theme.dart
//  Module   : THIX Portfolio Business
//  Éditeur  : SONATHIX GROUP — Kinshasa, RDC
//  Version  : 1.0.2 — Novembre 2026 (CORRIGÉ CI)
// ════════════════════════════════════════════════════════════════════════════
//
//  Corrections CI :
//    • `GoogleFonts.asMap()[fontFamily]?.fontFamily` → `GoogleFonts.getFont(fontFamily).fontFamily`
//      (GoogleFonts.asMap() retourne des FONCTIONS TextStyle Function(...), pas des TextStyle)
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Style d'animation
// ─────────────────────────────────────────────────────────────────────────────

enum BusinessAnimationStyle {
  elegant(durationScale: 1.0, curve: Curves.easeOutCubic, parallax: 0.35, glow: true, staggerMs: 90),
  dynamic(durationScale: 0.65, curve: Curves.easeOutBack, parallax: 0.60, glow: true, staggerMs: 55),
  minimal(durationScale: 1.25, curve: Curves.easeOut, parallax: 0.0, glow: false, staggerMs: 130);

  const BusinessAnimationStyle({
    required this.durationScale,
    required this.curve,
    required this.parallax,
    required this.glow,
    required this.staggerMs,
  });

  final double durationScale;
  final Curve curve;
  final double parallax;
  final bool glow;
  final int staggerMs;

  static BusinessAnimationStyle fromSlug(String? slug) => values.firstWhere(
        (e) => e.name == slug,
        orElse: () => BusinessAnimationStyle.elegant,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Utilitaires hex
// ─────────────────────────────────────────────────────────────────────────────

class ThixColorUtils {
  const ThixColorUtils._();

  static final RegExp _hexRegex = RegExp(r'^#?([0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$');

  static bool isValidHex(String hex) => _hexRegex.hasMatch(hex.trim());

  static String normalizeHex(String hex) {
    var h = hex.trim().replaceFirst('#', '').toUpperCase();
    if (h.length == 8) h = h.substring(2);
    return '#$h';
  }

  static Color toColor(String hex) =>
      Color(int.parse(normalizeHex(hex).substring(1), radix: 16) | 0xFF000000);

  static String lerpHex(String from, String to, double t) {
    final a = _rgb(from);
    final b = _rgb(to);
    final k = t.clamp(0.0, 1.0);
    String ch(int x, int y) =>
        (x + (y - x) * k).round().toRadixString(16).padLeft(2, '0');
    return '#${ch(a.$1, b.$1)}${ch(a.$2, b.$2)}${ch(a.$3, b.$3)}'.toUpperCase();
  }

  static (int, int, int) _rgb(String hex) {
    final v = int.parse(normalizeHex(hex).substring(1), radix: 16);
    return ((v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Thème d'une entreprise
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class BusinessTheme {
  const BusinessTheme({
    required this.primaryHex,
    required this.secondaryHex,
    required this.accentHex,
    this.darkMode = false,
    this.fontFamily = kDefaultFont,
    this.cornerRadius = kDefaultRadius,
    this.animationStyle = BusinessAnimationStyle.elegant,
    this.updatedAt,
  });

  static const String kDefaultFont = 'Plus Jakarta Sans';
  static const double kDefaultRadius = 24;
  static const double kMinRadius = 4;
  static const double kMaxRadius = 40;

  final String primaryHex;
  final String secondaryHex;
  final String accentHex;
  final bool darkMode;
  final String fontFamily;
  final double cornerRadius;
  final BusinessAnimationStyle animationStyle;
  final DateTime? updatedAt;

  Color get primary => ThixColorUtils.toColor(primaryHex);
  Color get secondary => ThixColorUtils.toColor(secondaryHex);
  Color get accent => ThixColorUtils.toColor(accentHex);

  List<Color> get heroGradient => [primary, secondary];

  /// ✅ FIX CI : utilise GoogleFonts.getFont() directement (pas asMap())
  /// asMap() retourne Map<String, TextStyle Function(...)>, pas Map<String, TextStyle>
  String get resolvedFontFamily {
    try {
      return GoogleFonts.getFont(fontFamily).fontFamily ?? fontFamily;
    } catch (_) {
      return fontFamily;
    }
  }

  BorderRadius get radius => BorderRadius.circular(cornerRadius);
  BorderRadius get radiusSm => BorderRadius.circular(cornerRadius * 0.6);
  BorderRadius get radiusLg => BorderRadius.circular(cornerRadius * 1.25);

  factory BusinessTheme.fromJson(Map<String, dynamic> json) {
    String safeHex(Object? v, String fallback) =>
        (v is String && ThixColorUtils.isValidHex(v))
            ? ThixColorUtils.normalizeHex(v)
            : fallback;
    return BusinessTheme(
      primaryHex: safeHex(json['primary_hex'], '#1E5AE8'),
      secondaryHex: safeHex(json['secondary_hex'], '#0B2E6B'),
      accentHex: safeHex(json['accent_hex'], '#F5B301'),
      darkMode: json['dark_mode'] as bool? ?? false,
      fontFamily: (json['font_family'] as String?) ?? kDefaultFont,
      cornerRadius: (json['corner_radius'] as num?)?.toDouble() ?? kDefaultRadius,
      animationStyle: BusinessAnimationStyle.fromSlug(json['animation_style'] as String?),
      updatedAt: DateTime.tryParse('${json['updated_at'] ?? ''}'),
    );
  }

  Map<String, dynamic> toJson() => {
        'primary_hex': primaryHex,
        'secondary_hex': secondaryHex,
        'accent_hex': accentHex,
        'dark_mode': darkMode,
        'font_family': fontFamily,
        'corner_radius': cornerRadius,
        'animation_style': animationStyle.name,
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };

  Map<String, Object?> toSupabaseRow(String businessId) => {
        'business_id': businessId,
        ...toJson()..remove('updated_at'),
        'updated_at': DateTime.now().toIso8601String(),
      };

  BusinessTheme validate() => BusinessTheme(
        primaryHex: ThixColorUtils.isValidHex(primaryHex) ? ThixColorUtils.normalizeHex(primaryHex) : '#1E5AE8',
        secondaryHex: ThixColorUtils.isValidHex(secondaryHex) ? ThixColorUtils.normalizeHex(secondaryHex) : '#0B2E6B',
        accentHex: ThixColorUtils.isValidHex(accentHex) ? ThixColorUtils.normalizeHex(accentHex) : '#F5B301',
        darkMode: darkMode,
        fontFamily: fontFamily.trim().isEmpty ? kDefaultFont : fontFamily,
        cornerRadius: cornerRadius.clamp(kMinRadius, kMaxRadius),
        animationStyle: animationStyle,
        updatedAt: updatedAt,
      );

  ThemeData toThemeData() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      secondary: secondary,
      tertiary: accent,
      brightness: darkMode ? Brightness.dark : Brightness.light,
    );
    final font = resolvedFontFamily;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: font,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          fontFamily: font,
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: TextStyle(fontFamily: font, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: TextStyle(fontFamily: font, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: radiusSm)),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radiusSm),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    );
  }

  static BusinessTheme lerp(BusinessTheme a, BusinessTheme b, double t) {
    final k = t.clamp(0.0, 1.0);
    return BusinessTheme(
      primaryHex: ThixColorUtils.lerpHex(a.primaryHex, b.primaryHex, k),
      secondaryHex: ThixColorUtils.lerpHex(a.secondaryHex, b.secondaryHex, k),
      accentHex: ThixColorUtils.lerpHex(a.accentHex, b.accentHex, k),
      darkMode: k < 0.5 ? a.darkMode : b.darkMode,
      fontFamily: k < 0.5 ? a.fontFamily : b.fontFamily,
      cornerRadius: a.cornerRadius + (b.cornerRadius - a.cornerRadius) * k,
      animationStyle: k < 0.5 ? a.animationStyle : b.animationStyle,
    );
  }

  BusinessTheme copyWith({
    String? primaryHex,
    String? secondaryHex,
    String? accentHex,
    bool? darkMode,
    String? fontFamily,
    double? cornerRadius,
    BusinessAnimationStyle? animationStyle,
  }) =>
      BusinessTheme(
        primaryHex: primaryHex ?? this.primaryHex,
        secondaryHex: secondaryHex ?? this.secondaryHex,
        accentHex: accentHex ?? this.accentHex,
        darkMode: darkMode ?? this.darkMode,
        fontFamily: fontFamily ?? this.fontFamily,
        cornerRadius: cornerRadius ?? this.cornerRadius,
        animationStyle: animationStyle ?? this.animationStyle,
        updatedAt: DateTime.now(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BusinessTheme &&
          other.primaryHex == primaryHex &&
          other.secondaryHex == secondaryHex &&
          other.accentHex == accentHex &&
          other.darkMode == darkMode &&
          other.fontFamily == fontFamily &&
          other.cornerRadius == cornerRadius &&
          other.animationStyle == animationStyle);

  @override
  int get hashCode => Object.hash(
        primaryHex, secondaryHex, accentHex, darkMode,
        fontFamily, cornerRadius, animationStyle,
      );

  @override
  String toString() =>
      'BusinessTheme($primaryHex / $secondaryHex / $accentHex, '
      'font: $fontFamily, radius: $cornerRadius, anim: ${animationStyle.name})';
}

// ─────────────────────────────────────────────────────────────────────────────
// Presets
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class BusinessThemePreset {
  const BusinessThemePreset({
    required this.id,
    required this.label,
    required this.description,
    required this.theme,
  });
  final String id;
  final String label;
  final String description;
  final BusinessTheme theme;
}

class BusinessThemePresets {
  const BusinessThemePresets._();

  static const List<BusinessThemePreset> all = [
    BusinessThemePreset(id: 'ocean', label: 'Océan Profond', description: 'Tech, SaaS, finance',
        theme: BusinessTheme(primaryHex: '#0A66C2', secondaryHex: '#063A75', accentHex: '#22D3EE', fontFamily: 'Plus Jakarta Sans')),
    BusinessThemePreset(id: 'savane', label: 'Soleil Africain', description: 'Commerce, agro, tourisme',
        theme: BusinessTheme(primaryHex: '#E8590C', secondaryHex: '#862E0C', accentHex: '#FAB005', fontFamily: 'Poppins', cornerRadius: 28)),
    BusinessThemePreset(id: 'emeraude', label: 'Émeraude Business', description: 'Santé, énergie, ONG',
        theme: BusinessTheme(primaryHex: '#0CA678', secondaryHex: '#065F46', accentHex: '#F59F00', fontFamily: 'Manrope')),
    BusinessThemePreset(id: 'royal', label: 'Violet Royal', description: 'Créatif, médias, mode',
        theme: BusinessTheme(primaryHex: '#6741D9', secondaryHex: '#3B2A86', accentHex: '#F06595', fontFamily: 'Sora', cornerRadius: 32, animationStyle: BusinessAnimationStyle.dynamic)),
    BusinessThemePreset(id: 'minuit', label: 'Minuit Premium', description: 'Luxe, immobilier, auto',
        theme: BusinessTheme(primaryHex: '#38BDF8', secondaryHex: '#1E293B', accentHex: '#F5B301', darkMode: true, fontFamily: 'Outfit', cornerRadius: 20, animationStyle: BusinessAnimationStyle.minimal)),
    BusinessThemePreset(id: 'terre_or', label: 'Terre & Or', description: 'Artisanat, café, patrimoine',
        theme: BusinessTheme(primaryHex: '#946300', secondaryHex: '#5C3D00', accentHex: '#D4AF37', fontFamily: 'Space Grotesk')),
    BusinessThemePreset(id: 'rubis', label: 'Rubis Corporate', description: 'Événementiel, restauration',
        theme: BusinessTheme(primaryHex: '#C2255C', secondaryHex: '#7A1436', accentHex: '#F5B301', fontFamily: 'Nunito', cornerRadius: 26, animationStyle: BusinessAnimationStyle.dynamic)),
  ];

  static BusinessThemePreset? byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }
}
