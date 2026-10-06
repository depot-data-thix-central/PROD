// lib/presentation/mon_pays/pages/provinces/province_detail_page.dart
//
// ProvinceDetailPage — PRODUCTION (Portail Institutionnel RDC)
// ✨ Glassmorphism clair + Disposition horizontale ultra moderne
// 🗣️ Multilingue (FR/LN/SW/TL/KG) + ♿ Accessibilité
// 🔌 Connecté 100% à Supabase via Riverpod (zéro mock)

import 'dart:async';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

import '../../providers/provinces_provider.dart';
import '../../models/province.dart';
import '../../models/city.dart';

// ============================================================================
// LANGUES NATIONALES RDC
// ============================================================================
enum NationalLanguage { french, lingala, swahili, tshiluba, kikongo }

extension LanguageX on NationalLanguage {
  String get code {
    switch (this) {
      case NationalLanguage.french: return 'fr';
      case NationalLanguage.lingala: return 'ln';
      case NationalLanguage.swahili: return 'sw';
      case NationalLanguage.tshiluba: return 'lu';
      case NationalLanguage.kikongo: return 'kg';
    }
  }

  String get name {
    switch (this) {
      case NationalLanguage.french: return 'Français';
      case NationalLanguage.lingala: return 'Lingala';
      case NationalLanguage.swahili: return 'Swahili';
      case NationalLanguage.tshiluba: return 'Tshiluba';
      case NationalLanguage.kikongo: return 'Kikongo';
    }
  }

  String get flag {
    switch (this) {
      case NationalLanguage.french: return '🇫🇷';
      case NationalLanguage.lingala: return '🇨🇩';
      case NationalLanguage.swahili: return '🇨🇩';
      case NationalLanguage.tshiluba: return '🇨🇩';
      case NationalLanguage.kikongo: return '🇨🇩';
    }
  }
}

// ============================================================================
// TRADUCTIONS UI (clés statiques, indépendantes du backend)
// ============================================================================
class ProvinceTranslations {
  static String translate(String key, NationalLanguage lang) {
    final translations = <String, Map<NationalLanguage, String>>{
      'latest_news': {
        NationalLanguage.french: '📢 Actualités',
        NationalLanguage.lingala: '📢 Nsango ya sika',
        NationalLanguage.swahili: '📢 Habari za hivi karibuni',
        NationalLanguage.tshiluba: '📢 Makani mapya',
        NationalLanguage.kikongo: '📢 Bansangu ya mpa',
      },
      'ongoing_projects': {
        NationalLanguage.french: '🏗️ Projets en cours',
        NationalLanguage.lingala: '🏗️ Misala ezali kokende',
        NationalLanguage.swahili: '🏗️ Miradi inayoendelea',
        NationalLanguage.tshiluba: '🏗️ Miseu miikala kudienda',
        NationalLanguage.kikongo: '🏗️ Bisalu ke na kenda',
      },
      'public_services': {
        NationalLanguage.french: '🏛️ Services publics',
        NationalLanguage.lingala: '🏛️ Misala ya leta',
        NationalLanguage.swahili: '🏛️ Huduma za umma',
        NationalLanguage.tshiluba: '🏛️ Miseu ya leta',
        NationalLanguage.kikongo: '🏛️ Bisalu ya leta',
      },
      'citizen_engagement': {
        NationalLanguage.french: '🗳️ Engagement citoyen',
        NationalLanguage.lingala: '🗳️ Mosala ya bato',
        NationalLanguage.swahili: '🗳️ Ushiriki wa raia',
        NationalLanguage.tshiluba: '🗳️ Miseu ya bantu',
        NationalLanguage.kikongo: '🗳️ Bisalu ya wantu',
      },
      'budget': {
        NationalLanguage.french: '💰 Budget provincial',
        NationalLanguage.lingala: '💰 Mbongo ya province',
        NationalLanguage.swahili: '💰 Bajeti ya mkoa',
        NationalLanguage.tshiluba: '💰 Mbongo wa province',
        NationalLanguage.kikongo: '💰 Mbongo wa province',
      },
      'official_docs': {
        NationalLanguage.french: '📄 Documents officiels',
        NationalLanguage.lingala: '📄 Mikanda ya leta',
        NationalLanguage.swahili: '📄 Nyaraka rasmi',
        NationalLanguage.tshiluba: '📄 Mikanda ya leta',
        NationalLanguage.kikongo: '📄 Mikanda ya leta',
      },
      'mediatheque': {
        NationalLanguage.french: '🎥 Médiathèque',
        NationalLanguage.lingala: '🎥 Bilanga ya vidéo',
        NationalLanguage.swahili: '🎥 Maktaba ya media',
        NationalLanguage.tshiluba: '🎥 Bilanga ya vidéo',
        NationalLanguage.kikongo: '🎥 Bilanga ya vidéo',
      },
      'hymn': {
        NationalLanguage.french: '🎵 Hymne provincial',
        NationalLanguage.lingala: '🎵 Nzémbo ya province',
        NationalLanguage.swahili: '🎵 Wimbo wa mkoa',
        NationalLanguage.tshiluba: '🎵 Nyimbo wa province',
        NationalLanguage.kikongo: '🎵 Nkunga wa province',
      },
      'famous_people': {
        NationalLanguage.french: '🌟 Personnalités',
        NationalLanguage.lingala: '🌟 Bato ya lokumu',
        NationalLanguage.swahili: '🌟 Watu mashuhuri',
        NationalLanguage.tshiluba: '🌟 Bantu ba lukumu',
        NationalLanguage.kikongo: '🌟 Bantu ba lukumu',
      },
      'gastronomy': {
        NationalLanguage.french: '🍲 Gastronomie',
        NationalLanguage.lingala: '🍲 Bilei ya mboka',
        NationalLanguage.swahili: '🍲 Chakula cha asili',
        NationalLanguage.tshiluba: '🍲 Bilei dia mboka',
        NationalLanguage.kikongo: '🍲 Madia ma nsi',
      },
      'proverbs': {
        NationalLanguage.french: '📖 Proverbes & Contes',
        NationalLanguage.lingala: '📖 Masese',
        NationalLanguage.swahili: '📖 Methali na hadithi',
        NationalLanguage.tshiluba: '📖 Tshisangale',
        NationalLanguage.kikongo: '📖 Bingana',
      },
      'local_businesses': {
        NationalLanguage.french: '🏢 Entreprises locales',
        NationalLanguage.lingala: '🏢 Bisaleli ya mboka',
        NationalLanguage.swahili: '🏢 Biashara za mahali',
        NationalLanguage.tshiluba: '🏢 Miseu ya mboka',
        NationalLanguage.kikongo: '🏢 Bisalu ya nsi',
      },
      'local_products': {
        NationalLanguage.french: '🛒 Produits du terroir',
        NationalLanguage.lingala: '🛒 Biloko ya mboka',
        NationalLanguage.swahili: '🛒 Bidhaa za mahali',
        NationalLanguage.tshiluba: '🛒 Biloko bia mboka',
        NationalLanguage.kikongo: '🛒 Bima bia nsi',
      },
      'quiz': {
        NationalLanguage.french: '🎮 Quiz',
        NationalLanguage.lingala: '🎮 Masano',
        NationalLanguage.swahili: '🎮 Maswali',
        NationalLanguage.tshiluba: '🎮 Masano',
        NationalLanguage.kikongo: '🎮 Masano',
      },
      'demography': {
        NationalLanguage.french: '📈 Démographie',
        NationalLanguage.lingala: '📈 Bato ya province',
        NationalLanguage.swahili: '📈 Idadi ya watu',
        NationalLanguage.tshiluba: '📈 Bantu ba province',
        NationalLanguage.kikongo: '📈 Bantu ba province',
      },
      'governance': {
        NationalLanguage.french: '🏛️ Gouvernance',
        NationalLanguage.lingala: '🏛️ Bokambi',
        NationalLanguage.swahili: '🏛️ Uongozi',
        NationalLanguage.tshiluba: '🏛️ Bukambi',
        NationalLanguage.kikongo: '🏛️ Nkambu',
      },
      'see_all': {
        NationalLanguage.french: 'Voir tout',
        NationalLanguage.lingala: 'Tala nyonso',
        NationalLanguage.swahili: 'Ona yote',
        NationalLanguage.tshiluba: 'Tala yonso',
        NationalLanguage.kikongo: 'Tala yawonso',
      },
      'loading': {
        NationalLanguage.french: 'Chargement...',
        NationalLanguage.lingala: 'Ezali kokanga...',
        NationalLanguage.swahili: 'Inapakia...',
        NationalLanguage.tshiluba: 'Ikala kuloda...',
        NationalLanguage.kikongo: 'Ke na kuzitisa...',
      },
      'no_data': {
        NationalLanguage.french: 'Aucune donnée disponible',
        NationalLanguage.lingala: 'Likambo moko te',
        NationalLanguage.swahili: 'Hakuna data',
        NationalLanguage.tshiluba: 'Kadilu ka moyi',
        NationalLanguage.kikongo: 'Kadiambu ko',
      },
    };
    return translations[key]?[lang] ?? key;
  }
}

// ============================================================================
// SETTINGS PROVIDERS (accessibilité + langue)
// ============================================================================
class AccessibilitySettings {
  final double textScale;
  final bool highContrast;
  final bool audioMode;

  const AccessibilitySettings({
    this.textScale = 1.0,
    this.highContrast = false,
    this.audioMode = false,
  });

  AccessibilitySettings copyWith({
    double? textScale,
    bool? highContrast,
    bool? audioMode,
  }) {
    return AccessibilitySettings(
      textScale: textScale ?? this.textScale,
      highContrast: highContrast ?? this.highContrast,
      audioMode: audioMode ?? this.audioMode,
    );
  }
}

final accessibilityProvider = StateProvider<AccessibilitySettings>(
  (_) => const AccessibilitySettings(),
);

final languageProvider = StateProvider<NationalLanguage>(
  (_) => NationalLanguage.french,
);

// ============================================================================
// PROVIDERS RIVERPOD — SUPABASE (PRODUCTION)
// ============================================================================

SupabaseClient get _db => Supabase.instance.client;

// ─── ACTUALITÉS ───
final provinceNewsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, provinceId) async {
  try {
    final rows = await _db
        .from('province_news')
        .select()
        .eq('province_id', provinceId)
        .eq('is_published', true)
        .order('published_at', ascending: false)
        .limit(20);
    return List<Map<String, dynamic>>.from(rows as List);
  } catch (e) {
    debugPrint('[provinceNewsProvider] error: $e');
    return [];
  }
});

// ─── PROJETS EN COURS ───
final provinceProjectsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, provinceId) async {
  try {
    final rows = await _db
        .from('province_projects')
        .select()
        .eq('province_id', provinceId)
        .eq('status', 'ongoing')
        .order('progress', ascending: false)
        .limit(20);
    return List<Map<String, dynamic>>.from(rows as List);
  } catch (e) {
    debugPrint('[provinceProjectsProvider] error: $e');
    return [];
  }
});

// ─── SERVICES PUBLICS ───
final provinceServicesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, provinceId) async {
  try {
    final rows = await _db
        .from('province_services')
        .select()
        .eq('province_id', provinceId)
        .eq('is_active', true)
        .order('name', ascending: true)
        .limit(30);
    return List<Map<String, dynamic>>.from(rows as List);
  } catch (e) {
    debugPrint('[provinceServicesProvider] error: $e');
    return [];
  }
});

// ─── ENGAGEMENT CITOYEN ───
final provinceEngagementsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, provinceId) async {
  try {
    final rows = await _db
        .from('province_engagements')
        .select()
        .eq('province_id', provinceId)
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(20);
    return List<Map<String, dynamic>>.from(rows as List);
  } catch (e) {
    debugPrint('[provinceEngagementsProvider] error: $e');
    return [];
  }
});

// ─── BUDGET ───
final provinceBudgetProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, provinceId) async {
  try {
    final rows = await _db
        .from('province_budget')
        .select()
        .eq('province_id', provinceId)
        .order('percentage', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  } catch (e) {
    debugPrint('[provinceBudgetProvider] error: $e');
    return [];
  }
});

// ─── DOCUMENTS OFFICIELS ───
final provinceDocumentsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, provinceId) async {
  try {
    final rows = await _db
        .from('province_documents')
        .select()
        .eq('province_id', provinceId)
        .eq('is_published', true)
        .order('published_at', ascending: false)
        .limit(20);
    return List<Map<String, dynamic>>.from(rows as List);
  } catch (e) {
    debugPrint('[provinceDocumentsProvider] error: $e');
    return [];
  }
});

// ─── MÉDIATHÈQUE ───
final provinceMediaProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, provinceId) async {
  try {
    final rows = await _db
        .from('province_media')
        .select()
        .eq('province_id', provinceId)
        .eq('is_published', true)
        .order('published_at', ascending: false)
        .limit(20);
    return List<Map<String, dynamic>>.from(rows as List);
  } catch (e) {
    debugPrint('[provinceMediaProvider] error: $e');
    return [];
  }
});

// ─── HYMNE ───
final provinceHymnProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, provinceId) async {
  try {
    final row = await _db
        .from('province_hymn')
        .select()
        .eq('province_id', provinceId)
        .maybeSingle();
    return row != null ? Map<String, dynamic>.from(row as Map) : null;
  } catch (e) {
    debugPrint('[provinceHymnProvider] error: $e');
    return null;
  }
});

// ─── PERSONNALITÉS CÉLÈBRES ───
final provinceFamousPeopleProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, provinceId) async {
  try {
    final rows = await _db
        .from('province_famous_people')
        .select()
        .eq('province_id', provinceId)
        .eq('is_active', true)
        .order('name', ascending: true)
        .limit(20);
    return List<Map<String, dynamic>>.from(rows as List);
  } catch (e) {
    debugPrint('[provinceFamousPeopleProvider] error: $e');
    return [];
  }
});

// ─── GASTRONOMIE ───
final provinceGastronomyProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, provinceId) async {
  try {
    final rows = await _db
        .from('province_gastronomy')
        .select()
        .eq('province_id', provinceId)
        .eq('is_active', true)
        .order('name', ascending: true)
        .limit(20);
    return List<Map<String, dynamic>>.from(rows as List);
  } catch (e) {
    debugPrint('[provinceGastronomyProvider] error: $e');
    return [];
  }
});

// ─── PROVERBES ───
final provinceProverbsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, provinceId) async {
  try {
    final rows = await _db
        .from('province_proverbs')
        .select()
        .eq('province_id', provinceId)
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(20);
    return List<Map<String, dynamic>>.from(rows as List);
  } catch (e) {
    debugPrint('[provinceProverbsProvider] error: $e');
    return [];
  }
});

// ─── ENTREPRISES LOCALES ───
final provinceBusinessesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, provinceId) async {
  try {
    final rows = await _db
        .from('province_businesses')
        .select()
        .eq('province_id', provinceId)
        .eq('is_active', true)
        .order('name', ascending: true)
        .limit(20);
    return List<Map<String, dynamic>>.from(rows as List);
  } catch (e) {
    debugPrint('[provinceBusinessesProvider] error: $e');
    return [];
  }
});

// ─── PRODUITS DU TERROIR ───
final provinceProductsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, provinceId) async {
  try {
    final rows = await _db
        .from('province_products')
        .select()
        .eq('province_id', provinceId)
        .eq('is_active', true)
        .order('name', ascending: true)
        .limit(20);
    return List<Map<String, dynamic>>.from(rows as List);
  } catch (e) {
    debugPrint('[provinceProductsProvider] error: $e');
    return [];
  }
});

// ─── QUIZ ───
final provinceQuizProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, provinceId) async {
  try {
    final rows = await _db
        .from('province_quiz_questions')
        .select()
        .eq('province_id', provinceId)
        .eq('is_active', true)
        .order('order_index', ascending: true)
        .limit(10);
    return List<Map<String, dynamic>>.from(rows as List);
  } catch (e) {
    debugPrint('[provinceQuizProvider] error: $e');
    return [];
  }
});

// ─── DÉMOGRAPHIE (séries temporelles) ───
final provinceDemographicsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, provinceId) async {
  try {
    final rows = await _db
        .from('province_demographics')
        .select()
        .eq('province_id', provinceId)
        .order('year', ascending: true);
    return List<Map<String, dynamic>>.from(rows as List);
  } catch (e) {
    debugPrint('[provinceDemographicsProvider] error: $e');
    return [];
  }
});

// ─── FAVORIS ───
final favoriteProvincesProvider = StateNotifierProvider<FavoriteProvincesNotifier, Set<String>>((ref) {
  return FavoriteProvincesNotifier();
});

class FavoriteProvincesNotifier extends StateNotifier<Set<String>> {
  FavoriteProvincesNotifier() : super({}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('favorite_provinces') ?? [];
    state = list.toSet();
  }

  Future<void> toggle(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final newSet = Set<String>.from(state);
    if (newSet.contains(id)) {
      newSet.remove(id);
    } else {
      newSet.add(id);
    }
    state = newSet;
    await prefs.setStringList('favorite_provinces', newSet.toList());
  }

  bool isFavorite(String id) => state.contains(id);
}

// ============================================================================
// GLASSMORPHISM HELPERS
// ============================================================================
class GlassTheme {
  static const Color glassBackground = Color(0xE6FFFFFF);
  static const Color glassBorder = Color(0x40FFFFFF);
  static const double glassBlur = 20.0;
  static const double glassRadius = 24.0;

  static BoxDecoration glassDecoration({
    Color? backgroundColor,
    double? blur,
    double? radius,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: backgroundColor ?? glassBackground,
      borderRadius: BorderRadius.circular(radius ?? glassRadius),
      border: Border.all(color: borderColor ?? glassBorder, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final double? blur;
  final double? radius;
  final Color? backgroundColor;

  const GlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.blur,
    this.radius,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius ?? GlassTheme.glassRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blur ?? GlassTheme.glassBlur,
          sigmaY: blur ?? GlassTheme.glassBlur,
        ),
        child: Container(
          decoration: GlassTheme.glassDecoration(
            backgroundColor: backgroundColor,
            blur: blur,
            radius: radius,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(radius ?? GlassTheme.glassRadius),
              child: Padding(
                padding: padding ?? const EdgeInsets.all(16),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SECTION HEADER (utilisé par toutes les sections horizontales)
// ============================================================================
class HorizontalGlassSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final AsyncValue<List<Map<String, dynamic>>> data;
  final Widget Function(Map<String, dynamic> item) builder;
  final int? forcedCount;
  final VoidCallback? onViewAll;

  const HorizontalGlassSection({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.data,
    required this.builder,
    this.forcedCount,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: ThixPolicy.h3Style.copyWith(
                      color: ThixPolicy.inkDeep,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                data.when(
                  data: (items) {
                    final count = forcedCount ?? items.length;
                    if (count == 0) return const SizedBox.shrink();
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color.withOpacity(0.15), color.withOpacity(0.08)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: color.withOpacity(0.2)),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                        ),
                        if (onViewAll != null && count > 3) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: onViewAll,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Voir tout',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                  loading: () => SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  ),
                  error: (_, __) => Icon(Icons.error_outline, color: color, size: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Contenu horizontal
          SizedBox(
            height: 220,
            child: data.when(
              loading: () => ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: 3,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (_, __) => const _SkeletonCard(width: 280, height: 220),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Erreur de chargement',
                    style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.danger),
                  ),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      'Aucune donnée disponible',
                      style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted),
                    ),
                  );
                }
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (_, i) => SizedBox(
                    width: 280,
                    child: builder(items[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Skeleton card pour le loading
class _SkeletonCard extends StatelessWidget {
  final double width;
  final double height;
  const _SkeletonCard({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(GlassTheme.glassRadius),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(GlassTheme.glassRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: height * 0.5,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.2),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 10,
                    width: 140,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// VERTICAL SECTION (pour sections non-horizontales)
// ============================================================================
class VerticalGlassSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;
  final int? count;

  const VerticalGlassSection({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: ThixPolicy.h3Style.copyWith(
                      color: ThixPolicy.inkDeep,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (count != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class ProvinceDetailPage extends ConsumerStatefulWidget {
  final String provinceId;
  const ProvinceDetailPage({required this.provinceId, super.key});

  @override
  ConsumerState<ProvinceDetailPage> createState() => _ProvinceDetailPageState();
}

class _ProvinceDetailPageState extends ConsumerState<ProvinceDetailPage> {
  final ScrollController _scrollController = ScrollController();
  bool _showBackToTop = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      setState(() {
        _showBackToTop = _scrollController.offset > 400;
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _shareProvince(Province province) async {
    final text = '''
🏛️ ${province.name} - République Démocratique du Congo

📍 Chef-lieu : ${province.capital}
👥 Population : ${province.population ?? 'N/A'} hab
🗺️ Superficie : ${province.area ?? 'N/A'} km²

🔗 Découvrez plus sur THIX ID
''';
    await Share.share(text);
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = ref.watch(languageProvider);
    final accessibility = ref.watch(accessibilityProvider);
    final provinceAsync = ref.watch(provinceWithAllRelationsProvider(widget.provinceId));

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(accessibility.textScale),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F8),
        body: Stack(
          children: [
            // Background gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFF0F4F8),
                    const Color(0xFFE8EEF5),
                    const Color(0xFFF8FAFC),
                  ],
                ),
              ),
            ),
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      ThixPolicy.primary.withOpacity(0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      ThixPolicy.gold.withOpacity(0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            provinceAsync.when(
              loading: () => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        color: ThixPolicy.primary,
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      ProvinceTranslations.translate('loading', lang),
                      style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary),
                    ),
                  ],
                ),
              ),
              error: (e, _) => _buildErrorState(context, l10n, () {
                ref.invalidate(provinceWithAllRelationsProvider(widget.provinceId));
              }),
              data: (province) => RefreshIndicator(
                color: ThixPolicy.primary,
                onRefresh: () async {
                  ref.invalidate(provinceWithAllRelationsProvider(widget.provinceId));
                  ref.invalidate(provinceNewsProvider(widget.provinceId));
                  ref.invalidate(provinceProjectsProvider(widget.provinceId));
                  ref.invalidate(provinceServicesProvider(widget.provinceId));
                },
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  slivers: [
                    // HEADER
                    _GlassHeader(
                      province: province,
                      onShare: () => _shareProvince(province),
                      onSearch: () {
                        // TODO: ouvrir search modal
                      },
                    ),

                    SliverPadding(
                      padding: const EdgeInsets.only(top: 12, bottom: 80),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // 0. TOP ACTIONS (langue + accessibilité)
                          _TopActionButtons(),
                          const SizedBox(height: 24),

                          // 1. IDENTITÉ
                          _ProvinceIdentityCard(province: province, lang: lang),
                          const SizedBox(height: 24),

                          // 2. ACTUALITÉS (Supabase)
                          _NewsSection(provinceId: widget.provinceId, lang: lang),

                          // 3. PROJETS (Supabase)
                          _ProjectsSection(provinceId: widget.provinceId, lang: lang),

                          // 4. SERVICES PUBLICS (Supabase)
                          _ServicesSection(provinceId: widget.provinceId, lang: lang),

                          // 5. ENGAGEMENT CITOYEN (Supabase)
                          _EngagementsSection(provinceId: widget.provinceId, lang: lang),

                          // 6. BUDGET (Supabase)
                          _BudgetSection(provinceId: widget.provinceId, lang: lang),

                          // 7. DOCUMENTS (Supabase)
                          _DocumentsSection(provinceId: widget.provinceId, lang: lang),

                          // 8. MÉDIATHÈQUE (Supabase)
                          _MediaSection(provinceId: widget.provinceId, lang: lang),

                          // 9. HYMNE (Supabase)
                          _HymnSectionWidget(provinceId: widget.provinceId, provinceName: province.name, lang: lang),

                          // 10. PERSONNALITÉS (Supabase)
                          _FamousPeopleSection(provinceId: widget.provinceId, lang: lang),

                          // 11. GASTRONOMIE (Supabase)
                          _GastronomySection(provinceId: widget.provinceId, lang: lang),

                          // 12. PROVERBES (Supabase)
                          _ProverbsSection(provinceId: widget.provinceId, lang: lang),

                          // 13. QUIZ (Supabase)
                          _QuizSectionWidget(provinceId: widget.provinceId, lang: lang),

                          // 14. ENTREPRISES (Supabase)
                          _BusinessesSection(provinceId: widget.provinceId, lang: lang),

                          // 15. PRODUITS (Supabase)
                          _ProductsSection(provinceId: widget.provinceId, lang: lang),

                          // 16. CARTE INTERACTIVE
                          if (province.mapUrl != null && province.mapUrl!.trim().isNotEmpty)
                            _InteractiveMapCard(url: province.mapUrl!, provinceName: province.name),

                          // 17. DÉMOGRAPHIE (Supabase)
                          _DemographicsSectionWidget(provinceId: widget.provinceId, lang: lang),

                          // 18. GALERIE (Province.galleryMedia existant)
                          if (province.galleryMedia != null && province.galleryMedia!.isNotEmpty)
                            HorizontalGlassSection(
                              title: l10n.t('province_gallery'),
                              icon: Icons.perm_media_rounded,
                              color: ThixPolicy.primary,
                              data: AsyncValue.data(province.galleryMedia!),
                              builder: (item) => _GalleryMediaCard(
                                media: item,
                                onTap: () => _openMediaGallery(context, [item], title: province.name),
                              ),
                              onViewAll: () => _openMediaGrid(context, province.galleryMedia!, title: province.name),
                            ),

                          // 19. GOUVERNANCE (Province existant)
                          if ((province.governor != null && province.governor!.isNotEmpty) ||
                              (province.ministers != null && province.ministers!.isNotEmpty))
                            _GovernanceGlassSection(province: province, lang: lang),

                          // 20. RÉALISATIONS (Province existant)
                          if (province.achievements != null && province.achievements!.isNotEmpty)
                            HorizontalGlassSection(
                              title: l10n.t('province_achievements'),
                              icon: Icons.emoji_events_rounded,
                              color: ThixPolicy.gold,
                              data: AsyncValue.data(province.achievements!),
                              builder: (item) => _AchievementCard(achievement: item),
                            ),

                          // 21. VILLES (Province existant)
                          if (province.cities.isNotEmpty)
                            HorizontalGlassSection(
                              title: l10n.t('province_cities'),
                              icon: Icons.location_city_rounded,
                              color: const Color(0xFF1565C0),
                              data: AsyncValue.data(
                                province.cities.map((c) => {
                                  'name': c.name,
                                  'is_capital': c.isCapital,
                                  'population': c.population,
                                  'image_url': (c as dynamic).imageUrl,
                                }).toList(),
                              ),
                              builder: (item) => _CityCardFromData(city: item),
                            ),

                          // 22. DÉCOUPAGE (Province existant)
                          if (province.administrativeDivisions.isNotEmpty)
                            HorizontalGlassSection(
                              title: l10n.t('province_divisions'),
                              icon: Icons.dashboard_customize_rounded,
                              color: const Color(0xFF6A1B9A),
                              data: AsyncValue.data(
                                province.administrativeDivisions.map((d) => {
                                  'name': (d as dynamic).name,
                                  'type': (d as dynamic).type,
                                  'capital': (d as dynamic).capital,
                                  'population': (d as dynamic).population,
                                }).toList(),
                              ),
                              builder: (item) => _DivisionCardFromData(division: item),
                            ),

                          // 23. TOURISME (Province existant)
                          if (province.tourismSites.isNotEmpty)
                            HorizontalGlassSection(
                              title: l10n.t('province_tourism'),
                              icon: Icons.landscape_rounded,
                              color: const Color(0xFF1565C0),
                              data: AsyncValue.data(
                                province.tourismSites.map((s) => {
                                  'name': (s as dynamic).name,
                                  'type': (s as dynamic).type,
                                  'description': (s as dynamic).description,
                                }).toList(),
                              ),
                              builder: (item) => _TourismCardFromData(site: item),
                            ),

                          // 24. ÉCONOMIE (Province existant)
                          if (province.economicResources.isNotEmpty)
                            HorizontalGlassSection(
                              title: l10n.t('province_economy'),
                              icon: Icons.monetization_on_rounded,
                              color: const Color(0xFF2E7D32),
                              data: AsyncValue.data(
                                province.economicResources.map((r) => {
                                  'name': (r as dynamic).name,
                                  'description': (r as dynamic).description,
                                }).toList(),
                              ),
                              builder: (item) => _ResourceCardFromData(resource: item),
                            ),

                          // 25. CULTURE & TRIBUS (Province existant)
                          if (_hasCultureData(province))
                            _CultureGlassSection(province: province),

                          // 26. HISTOIRE (Province existant)
                          if (_hasInstitutionalData(province))
                            _MonographyGlassSection(province: province),

                          // 27. URGENCES (Province existant)
                          if (province.emergencyContacts.isNotEmpty)
                            VerticalGlassSection(
                              title: l10n.t('province_emergency'),
                              icon: Icons.emergency_rounded,
                              color: ThixPolicy.danger,
                              count: province.emergencyContacts.length,
                              children: province.emergencyContacts
                                  .map((c) => _EmergencyTileFromData(contact: c))
                                  .toList(),
                            ),

                          // 28. IDENTITÉ VISUELLE (Province existant)
                          _VisualIdentityGlassSection(province: province),

                          const SizedBox(height: 40),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_showBackToTop)
              Positioned(
                bottom: 90,
                right: 20,
                child: _FloatingActionButton(
                  icon: Icons.arrow_upward_rounded,
                  onTap: () {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _hasCultureData(Province p) {
    return (p.description?.trim().isNotEmpty == true) ||
        (p.languages?.trim().isNotEmpty == true) ||
        (p.resources?.trim().isNotEmpty == true) ||
        (p.tribes != null && p.tribes!.isNotEmpty);
  }

  bool _hasInstitutionalData(Province p) {
    return (p.history?.trim().isNotEmpty == true) ||
        (p.climate?.trim().isNotEmpty == true) ||
        (p.infrastructure?.trim().isNotEmpty == true) ||
        (p.education?.trim().isNotEmpty == true);
  }

  Widget _buildErrorState(BuildContext context, AppLocalizations l10n, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: ThixPolicy.danger.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded, size: 48, color: ThixPolicy.danger),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.t('province_error_loading'),
                style: ThixPolicy.h3Style.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.t('common_retry')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  foregroundColor: ThixPolicy.onBrand,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// TOP ACTION BUTTONS
// ============================================================================
class _TopActionButtons extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(languageProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              onTap: () => _showLanguageSelector(context, ref),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(currentLang.flag, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    currentLang.name,
                    style: ThixPolicy.labelStyle.copyWith(
                      color: ThixPolicy.inkDeep,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: ThixPolicy.textSecondary, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GlassCard(
            padding: const EdgeInsets.all(10),
            onTap: () => _showAccessibilityPanel(context, ref),
            child: Icon(Icons.accessibility_new_rounded, color: ThixPolicy.primary, size: 20),
          ),
        ],
      ),
    );
  }

  void _showLanguageSelector(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 20),
                Text(
                  'Choisir la langue',
                  style: ThixPolicy.h3Style.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 20),
                ...NationalLanguage.values.map((lang) {
                  final isCurrent = ref.read(languageProvider) == lang;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          ref.read(languageProvider.notifier).state = lang;
                          Navigator.pop(context);
                          HapticFeedback.selectionClick();
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isCurrent ? ThixPolicy.primary.withOpacity(0.1) : ThixPolicy.surfaceSoft,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isCurrent ? ThixPolicy.primary : ThixPolicy.border,
                              width: isCurrent ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(lang.flag, style: const TextStyle(fontSize: 28)),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lang.name,
                                      style: ThixPolicy.labelStyle.copyWith(
                                        color: ThixPolicy.inkDeep,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      '(${lang.code.toUpperCase()})',
                                      style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              if (isCurrent)
                                Icon(Icons.check_circle_rounded, color: ThixPolicy.primary, size: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAccessibilityPanel(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _AccessibilityBottomSheet(),
    );
  }
}

class _AccessibilityBottomSheet extends ConsumerWidget {
  const _AccessibilityBottomSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(accessibilityProvider);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '♿ Accessibilité',
                style: ThixPolicy.h3Style.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 24),
              Text(
                'Taille du texte',
                style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800),
              ),
              Row(
                children: [
                  Text('A', style: TextStyle(fontSize: 12, color: ThixPolicy.textSecondary)),
                  Expanded(
                    child: Slider(
                      value: settings.textScale,
                      min: 0.8,
                      max: 1.5,
                      divisions: 7,
                      activeColor: ThixPolicy.primary,
                      inactiveColor: ThixPolicy.primary.withOpacity(0.2),
                      onChanged: (v) {
                        ref.read(accessibilityProvider.notifier).state = settings.copyWith(textScale: v);
                      },
                    ),
                  ),
                  Text('A', style: TextStyle(fontSize: 24, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// GLASS HEADER
// ============================================================================
class _GlassHeader extends ConsumerWidget {
  final Province province;
  final VoidCallback onShare;
  final VoidCallback onSearch;

  const _GlassHeader({
    required this.province,
    required this.onShare,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(favoriteProvincesProvider).contains(province.id);

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leadingWidth: 56,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(16),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ),
      ),
      actions: [
        _GlassIconButton(icon: Icons.search_rounded, onTap: onSearch),
        _GlassIconButton(icon: Icons.share_rounded, onTap: onShare),
        _GlassIconButton(
          icon: isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          onTap: () {
            ref.read(favoriteProvincesProvider.notifier).toggle(province.id);
            HapticFeedback.lightImpact();
          },
          color: isFavorite ? ThixPolicy.danger : Colors.white,
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 20, right: 20),
        title: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                province.name,
                style: ThixPolicy.h3Style.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  shadows: const [Shadow(blurRadius: 8, color: Colors.black38)],
                ),
              ),
            ),
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            province.coverImageUrl != null && province.coverImageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: province.coverImageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: ThixPolicy.primary,
                      child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: ThixPolicy.primary,
                      child: const Icon(Icons.image_not_supported, color: Colors.white),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [ThixPolicy.primary, ThixPolicy.primaryDeep],
                      ),
                    ),
                  ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.6),
                  ],
                  stops: const [0.3, 1.0],
                ),
              ),
            ),
            Positioned(
              bottom: 70,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: ThixPolicy.danger,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: ThixPolicy.danger.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  province.code,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _GlassIconButton({required this.icon, required this.onTap, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              icon: Icon(icon, color: color, size: 20),
              onPressed: onTap,
              padding: const EdgeInsets.all(10),
              constraints: const BoxConstraints(),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _FloatingActionButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: ThixPolicy.primary.withOpacity(0.85),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: ThixPolicy.primary.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                onTap();
              },
              child: Icon(icon, color: Colors.white, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 1. IDENTITÉ
// ============================================================================
class _ProvinceIdentityCard extends StatelessWidget {
  final Province province;
  final NationalLanguage lang;

  const _ProvinceIdentityCard({required this.province, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: (province.coatOfArmsUrl != null && province.coatOfArmsUrl!.isNotEmpty)
                      ? () => _openMediaGallery(
                            context,
                            [{'url': province.coatOfArmsUrl, 'type': 'photo'}],
                            title: 'Blason — ${province.name}',
                          )
                      : null,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: ThixPolicy.primary.withOpacity(0.3), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: ThixPolicy.primary.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: province.coatOfArmsUrl != null && province.coatOfArmsUrl!.isNotEmpty
                          ? _buildCachedImage(province.coatOfArmsUrl!, fit: BoxFit.contain)
                          : Container(
                              color: ThixPolicy.surfaceSoft,
                              child: Icon(Icons.shield_rounded, color: ThixPolicy.primary, size: 40),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        province.name,
                        style: ThixPolicy.h2Style.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [ThixPolicy.danger.withOpacity(0.15), ThixPolicy.danger.withOpacity(0.05)],
                              ),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: ThixPolicy.danger.withOpacity(0.3)),
                            ),
                            child: Text(
                              province.code,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: ThixPolicy.danger,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Région ${province.region}',
                            style: ThixPolicy.captionStyle.copyWith(
                              color: ThixPolicy.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _GlassStatItem(
                  icon: Icons.location_city_rounded,
                  label: 'Capitale',
                  value: province.capital,
                  color: ThixPolicy.primary,
                ),
                _GlassStatItem(
                  icon: Icons.groups_rounded,
                  label: 'Population',
                  value: province.population != null ? '${_fmtNumber(province.population!)}' : 'N/A',
                  color: const Color(0xFF43A047),
                ),
                _GlassStatItem(
                  icon: Icons.map_rounded,
                  label: 'Superficie',
                  value: province.area != null ? '${_fmtNumber(province.area!)} km²' : 'N/A',
                  color: const Color(0xFFFB8C00),
                ),
                if (province.territoriesCount != null)
                  _GlassStatItem(
                    icon: Icons.format_list_numbered_rounded,
                    label: 'Territoires',
                    value: '${province.territoriesCount}',
                    color: const Color(0xFF8E24AA),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassStatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _GlassStatItem({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color.withOpacity(0.15), color.withOpacity(0.05)]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: ThixPolicy.captionStyle.copyWith(
            color: ThixPolicy.inkDeep,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

// ============================================================================
// SECTIONS SUPABASE (production)
// ============================================================================

// ─── NEWS ───
class _NewsSection extends ConsumerWidget {
  final String provinceId;
  final NationalLanguage lang;
  const _NewsSection({required this.provinceId, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(provinceNewsProvider(provinceId));
    return HorizontalGlassSection(
      title: ProvinceTranslations.translate('latest_news', lang),
      icon: Icons.newspaper_rounded,
      color: const Color(0xFF1E88E5),
      data: data,
      builder: (item) => _NewsCardFromData(item: item),
    );
  }
}

class _NewsCardFromData extends StatelessWidget {
  final Map<String, dynamic> item;
  const _NewsCardFromData({required this.item});

  @override
  Widget build(BuildContext context) {
    final title = item['title']?.toString() ?? 'Actualité';
    final category = item['category']?.toString() ?? 'INFO';
    final summary = item['summary']?.toString() ?? '';
    final date = item['published_at']?.toString().split('T').first ?? '';
    final imageUrl = item['image_url']?.toString() ?? '';
    final isAlert = (item['is_alert'] ?? false) == true;

    return GlassCard(
      padding: EdgeInsets.zero,
      onTap: () {
        final url = item['url']?.toString();
        if (url != null && url.isNotEmpty) _launchUrlSafe(url);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        height: 110,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        height: 110,
                        color: ThixPolicy.surfaceSoft,
                        child: const Icon(Icons.image, color: ThixPolicy.textMuted),
                      ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isAlert ? ThixPolicy.danger : ThixPolicy.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.8),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  summary,
                  style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  date,
                  style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── PROJECTS ───
class _ProjectsSection extends ConsumerWidget {
  final String provinceId;
  final NationalLanguage lang;
  const _ProjectsSection({required this.provinceId, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(provinceProjectsProvider(provinceId));
    return HorizontalGlassSection(
      title: ProvinceTranslations.translate('ongoing_projects', lang),
      icon: Icons.construction_rounded,
      color: const Color(0xFFFB8C00),
      data: data,
      builder: (item) => _ProjectCardFromData(item: item),
    );
  }
}

class _ProjectCardFromData extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ProjectCardFromData({required this.item});

  @override
  Widget build(BuildContext context) {
    final name = item['name']?.toString() ?? 'Projet';
    final category = item['category']?.toString() ?? 'INFRASTRUCTURE';
    final progress = ((item['progress'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);
    final budget = item['budget']?.toString() ?? '';
    final deadline = item['deadline']?.toString() ?? '';
    final imageUrl = item['image_url']?.toString() ?? '';
    final percent = (progress * 100).round();

    final progressColor = percent >= 75
        ? const Color(0xFF43A047)
        : percent >= 50
            ? const Color(0xFFFB8C00)
            : const Color(0xFF1E88E5);

    return GlassCard(
      padding: EdgeInsets.zero,
      onTap: () => _showDetailSheet(context, name, item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(imageUrl: imageUrl, height: 90, width: double.infinity, fit: BoxFit.cover)
                    : Container(height: 90, color: ThixPolicy.surfaceSoft),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: progressColor, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    category,
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.8),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    '$percent%',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: progressColor.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('💰 $budget',
                        style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w700)),
                    Text('📅 $deadline',
                        style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SERVICES ───
class _ServicesSection extends ConsumerWidget {
  final String provinceId;
  final NationalLanguage lang;
  const _ServicesSection({required this.provinceId, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(provinceServicesProvider(provinceId));
    return HorizontalGlassSection(
      title: ProvinceTranslations.translate('public_services', lang),
      icon: Icons.badge_rounded,
      color: const Color(0xFF43A047),
      data: data,
      builder: (item) => _ServiceCardFromData(item: item),
    );
  }
}

class _ServiceCardFromData extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ServiceCardFromData({required this.item});

  IconData _iconForCategory(String category) {
    final c = category.toLowerCase();
    if (c.contains('civil') || c.contains('identité')) return Icons.badge_rounded;
    if (c.contains('immigration') || c.contains('passeport')) return Icons.flight_takeoff_rounded;
    if (c.contains('transport')) return Icons.directions_car_rounded;
    if (c.contains('économie') || c.contains('commerce')) return Icons.business_rounded;
    if (c.contains('santé')) return Icons.local_hospital_rounded;
    if (c.contains('éducation')) return Icons.school_rounded;
    return Icons.miscellaneous_services_rounded;
  }

  Color _colorForCategory(String category) {
    final c = category.toLowerCase();
    if (c.contains('civil') || c.contains('identité')) return const Color(0xFF1E88E5);
    if (c.contains('immigration')) return const Color(0xFF43A047);
    if (c.contains('transport')) return const Color(0xFFFB8C00);
    if (c.contains('économie')) return const Color(0xFF8E24AA);
    if (c.contains('santé')) return const Color(0xFFE53935);
    return const Color(0xFF43A047);
  }

  @override
  Widget build(BuildContext context) {
    final name = item['name']?.toString() ?? 'Service';
    final category = item['category']?.toString() ?? 'ADMINISTRATIF';
    final hours = item['hours']?.toString() ?? '';
    final address = item['address']?.toString() ?? '';
    final icon = _iconForCategory(category);
    final color = _colorForCategory(category);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      onTap: () => _showDetailSheet(context, name, item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color.withOpacity(0.2), color.withOpacity(0.05)]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: ThixPolicy.microStyle.copyWith(color: color, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          const Divider(height: 16, color: ThixPolicy.border),
          Row(
            children: [
              Icon(Icons.access_time_rounded, size: 14, color: ThixPolicy.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hours,
                  style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.location_on_rounded, size: 14, color: ThixPolicy.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  address,
                  style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── ENGAGEMENTS ───
class _EngagementsSection extends ConsumerWidget {
  final String provinceId;
  final NationalLanguage lang;
  const _EngagementsSection({required this.provinceId, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(provinceEngagementsProvider(provinceId));
    return HorizontalGlassSection(
      title: ProvinceTranslations.translate('citizen_engagement', lang),
      icon: Icons.how_to_vote_rounded,
      color: const Color(0xFF8E24AA),
      data: data,
      builder: (item) => _EngagementCardFromData(item: item),
    );
  }
}

class _EngagementCardFromData extends StatelessWidget {
  final Map<String, dynamic> item;
  const _EngagementCardFromData({required this.item});

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'sondage': return Icons.poll_rounded;
      case 'vote': return Icons.how_to_vote_rounded;
      case 'pétition': return Icons.edit_note_rounded;
      case 'requête': return Icons.report_problem_rounded;
      default: return Icons.how_to_vote_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type.toLowerCase()) {
      case 'sondage': return const Color(0xFF1E88E5);
      case 'vote': return const Color(0xFF43A047);
      case 'pétition': return const Color(0xFFFB8C00);
      case 'requête': return const Color(0xFFE53935);
      default: return const Color(0xFF8E24AA);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = item['title']?.toString() ?? 'Engagement';
    final type = item['type']?.toString() ?? 'SONDAGE';
    final description = item['description']?.toString() ?? '';
    final participants = (item['participants_count'] as num?)?.toInt() ?? 0;
    final icon = _iconForType(type);
    final color = _colorForType(type);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      onTap: () => _showDetailSheet(context, title, item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color.withOpacity(0.2), color.withOpacity(0.05)]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.toUpperCase(),
                      style: ThixPolicy.microStyle.copyWith(color: color, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            description,
            style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.4),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.people_rounded, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                '${_fmtNumber(participants)} participants',
                style: ThixPolicy.captionStyle.copyWith(color: color, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── BUDGET ───
class _BudgetSection extends ConsumerWidget {
  final String provinceId;
  final NationalLanguage lang;
  const _BudgetSection({required this.provinceId, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(provinceBudgetProvider(provinceId));
    return data.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();

        final totalAmount = items.fold<num>(
          0,
          (sum, item) => sum + ((item['amount'] as num?) ?? 0),
        );

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFF43A047).withOpacity(0.15), const Color(0xFF43A047).withOpacity(0.05)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF43A047).withOpacity(0.2)),
                      ),
                      child: Icon(Icons.account_balance_rounded, color: const Color(0xFF43A047), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ProvinceTranslations.translate('budget', lang),
                            style: ThixPolicy.h3Style.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900),
                          ),
                          Text(
                            'Année fiscale ${DateTime.now().year}',
                            style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF43A047).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_fmtNumber(totalAmount)} USD',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF43A047),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sections: _buildBudgetPieSections(items),
                      centerSpaceRadius: 40,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: items.take(6).map((s) {
                    final colorHex = s['color']?.toString() ?? '#1E88E5';
                    final color = _colorFromHex(colorHex);
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          s['sector']?.toString() ?? '',
                          style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w700),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<PieChartSectionData> _buildBudgetPieSections(List<Map<String, dynamic>> items) {
    final colors = [
      const Color(0xFF1E88E5),
      const Color(0xFF43A047),
      const Color(0xFFFB8C00),
      const Color(0xFF8E24AA),
      const Color(0xFFE53935),
      const Color(0xFF5E35B1),
    ];
    return items.asMap().entries.map((e) {
      final item = e.value;
      final percentage = ((item['percentage'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 100.0);
      final sector = item['sector']?.toString() ?? '';
      return PieChartSectionData(
        color: colors[e.key % colors.length],
        value: percentage,
        title: '$sector\n${percentage.toInt()}%',
        radius: 50,
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
      );
    }).toList();
  }
}

// ─── DOCUMENTS ───
class _DocumentsSection extends ConsumerWidget {
  final String provinceId;
  final NationalLanguage lang;
  const _DocumentsSection({required this.provinceId, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(provinceDocumentsProvider(provinceId));
    return data.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return VerticalGlassSection(
          title: ProvinceTranslations.translate('official_docs', lang),
          icon: Icons.description_rounded,
          color: const Color(0xFF5E35B1),
          count: items.length,
          children: items.map((d) => _DocumentTileFromData(doc: d)).toList(),
        );
      },
    );
  }
}

class _DocumentTileFromData extends StatelessWidget {
  final Map<String, dynamic> doc;
  const _DocumentTileFromData({required this.doc});

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'ordonnance': return Icons.gavel_rounded;
      case 'pv': return Icons.article_rounded;
      case 'marché': return Icons.receipt_long_rounded;
      default: return Icons.description_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = doc['title']?.toString() ?? 'Document';
    final type = doc['type']?.toString() ?? 'DOCUMENT';
    final date = doc['published_at']?.toString().split('T').first ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            final url = doc['file_url']?.toString();
            if (url != null && url.isNotEmpty) _launchUrlSafe(url);
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ThixPolicy.surfaceSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ThixPolicy.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5E35B1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_iconForType(type), color: const Color(0xFF5E35B1), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            type,
                            style: ThixPolicy.microStyle.copyWith(color: const Color(0xFF5E35B1), fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            date,
                            style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.download_rounded, color: ThixPolicy.primary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── MEDIA ───
class _MediaSection extends ConsumerWidget {
  final String provinceId;
  final NationalLanguage lang;
  const _MediaSection({required this.provinceId, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(provinceMediaProvider(provinceId));
    return HorizontalGlassSection(
      title: ProvinceTranslations.translate('mediatheque', lang),
      icon: Icons.play_circle_fill_rounded,
      color: const Color(0xFFE53935),
      data: data,
      builder: (item) => _MediaCardFromData(item: item),
    );
  }
}

class _MediaCardFromData extends StatelessWidget {
  final Map<String, dynamic> item;
  const _MediaCardFromData({required this.item});

  @override
  Widget build(BuildContext context) {
    final title = item['title']?.toString() ?? 'Média';
    final type = item['type']?.toString() ?? 'video';
    final duration = item['duration']?.toString() ?? '';
    final thumbnail = item['thumbnail_url']?.toString() ?? '';
    final isVideo = type == 'video';
    final isAudio = type == 'audio';
    final icon = isVideo
        ? Icons.play_circle_fill_rounded
        : isAudio
            ? Icons.audiotrack_rounded
            : Icons.image_rounded;

    return GlassCard(
      padding: EdgeInsets.zero,
      onTap: () {
        final url = item['url']?.toString();
        if (url != null && url.isNotEmpty) _launchUrlSafe(url);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: thumbnail.isNotEmpty
                    ? CachedNetworkImage(imageUrl: thumbnail, height: 110, width: double.infinity, fit: BoxFit.cover)
                    : Container(height: 110, color: ThixPolicy.surfaceSoft),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
                    child: Icon(
                      icon,
                      color: isVideo ? ThixPolicy.primary : ThixPolicy.gold,
                      size: 32,
                    ),
                  ),
                ),
              ),
              if (duration.isNotEmpty)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      duration,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isVideo ? ThixPolicy.primary : ThixPolicy.gold,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    type.toUpperCase(),
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.8),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── HYMN ───
class _HymnSectionWidget extends ConsumerStatefulWidget {
  final String provinceId;
  final String provinceName;
  final NationalLanguage lang;

  const _HymnSectionWidget({required this.provinceId, required this.provinceName, required this.lang});

  @override
  ConsumerState<_HymnSectionWidget> createState() => _HymnSectionWidgetState();
}

class _HymnSectionWidgetState extends ConsumerState<_HymnSectionWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlay(String? url) async {
    if (url == null || url.isEmpty) return;
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
    } else {
      await _audioPlayer.play(UrlSource(url));
      setState(() => _isPlaying = true);
    }
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(provinceHymnProvider(widget.provinceId));
    return data.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (hymn) {
        if (hymn == null) return const SizedBox.shrink();
        final audioUrl = hymn['audio_url']?.toString();
        final instrumentalUrl = hymn['instrumental_url']?.toString();
        final lyrics = hymn['lyrics']?.toString() ?? '';

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [ThixPolicy.gold.withOpacity(0.2), ThixPolicy.gold.withOpacity(0.05)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: ThixPolicy.gold.withOpacity(0.3)),
                      ),
                      child: Icon(Icons.music_note_rounded, color: ThixPolicy.gold, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ProvinceTranslations.translate('hymn', widget.lang),
                            style: ThixPolicy.h3Style.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900),
                          ),
                          Text(
                            widget.provinceName,
                            style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [ThixPolicy.gold.withOpacity(0.1), ThixPolicy.gold.withOpacity(0.02)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ThixPolicy.gold.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => _togglePlay(audioUrl),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: ThixPolicy.gold,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: ThixPolicy.gold.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Version officielle',
                              style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: _isPlaying ? null : 0,
                                backgroundColor: ThixPolicy.gold.withOpacity(0.2),
                                valueColor: const AlwaysStoppedAnimation<Color>(ThixPolicy.gold),
                                minHeight: 4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (lyrics.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ThixPolicy.surfaceSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Paroles (extrait) :',
                          style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          lyrics.length > 200 ? '${lyrics.substring(0, 200)}...' : lyrics,
                          style: ThixPolicy.bodySmallStyle.copyWith(
                            color: ThixPolicy.textSecondary,
                            fontStyle: FontStyle.italic,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── FAMOUS PEOPLE ───
class _FamousPeopleSection extends ConsumerWidget {
  final String provinceId;
  final NationalLanguage lang;
  const _FamousPeopleSection({required this.provinceId, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(provinceFamousPeopleProvider(provinceId));
    return HorizontalGlassSection(
      title: ProvinceTranslations.translate('famous_people', lang),
      icon: Icons.emoji_events_rounded,
      color: ThixPolicy.gold,
      data: data,
      builder: (item) => _FamousPersonCardFromData(item: item),
    );
  }
}

class _FamousPersonCardFromData extends StatelessWidget {
  final Map<String, dynamic> item;
  const _FamousPersonCardFromData({required this.item});

  @override
  Widget build(BuildContext context) {
    final name = item['name']?.toString() ?? '';
    final field = item['field']?.toString() ?? '';
    final bio = item['bio']?.toString() ?? '';
    final photo = item['photo_url']?.toString() ?? '';
    final achievement = item['achievement']?.toString();

    return GlassCard(
      padding: const EdgeInsets.all(16),
      onTap: () => _showDetailSheet(context, name, item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ThixPolicy.gold.withOpacity(0.3), width: 2),
                ),
                child: ClipOval(
                  child: photo.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: photo,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: ThixPolicy.surfaceSoft,
                            child: const Icon(Icons.person, color: ThixPolicy.textMuted),
                          ),
                        )
                      : Container(
                          color: ThixPolicy.surfaceSoft,
                          child: const Icon(Icons.person, color: ThixPolicy.textMuted),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      field,
                      style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.gold, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            bio,
            style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.4),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (achievement != null && achievement.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: ThixPolicy.gold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                achievement,
                style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.gold, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── GASTRONOMY ───
class _GastronomySection extends ConsumerWidget {
  final String provinceId;
  final NationalLanguage lang;
  const _GastronomySection({required this.provinceId, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(provinceGastronomyProvider(provinceId));
    return HorizontalGlassSection(
      title: ProvinceTranslations.translate('gastronomy', lang),
      icon: Icons.restaurant_rounded,
      color: const Color(0xFFD81B60),
      data: data,
      builder: (item) => _GastronomyCardFromData(item: item),
    );
  }
}

class _GastronomyCardFromData extends StatelessWidget {
  final Map<String, dynamic> item;
  const _GastronomyCardFromData({required this.item});

  @override
  Widget build(BuildContext context) {
    final name = item['name']?.toString() ?? '';
    final description = item['description']?.toString() ?? '';
    final image = item['image_url']?.toString() ?? '';

    return GlassCard(
      padding: EdgeInsets.zero,
      onTap: () => _showDetailSheet(context, name, item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: image.isNotEmpty
                ? CachedNetworkImage(imageUrl: image, height: 100, width: double.infinity, fit: BoxFit.cover)
                : Container(height: 100, color: ThixPolicy.surfaceSoft),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── PROVERBS ───
class _ProverbsSection extends ConsumerWidget {
  final String provinceId;
  final NationalLanguage lang;
  const _ProverbsSection({required this.provinceId, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(provinceProverbsProvider(provinceId));
    return HorizontalGlassSection(
      title: ProvinceTranslations.translate('proverbs', lang),
      icon: Icons.auto_stories_rounded,
      color: const Color(0xFF00897B),
      data: data,
      builder: (item) => _ProverbCardFromData(item: item),
    );
  }
}

class _ProverbCardFromData extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ProverbCardFromData({required this.item});

  @override
  Widget build(BuildContext context) {
    final text = item['text']?.toString() ?? '';
    final translation = item['translation']?.toString() ?? '';
    final language = item['language']?.toString() ?? 'FR';

    return GlassCard(
      padding: const EdgeInsets.all(16),
      onTap: () => _showDetailSheet(context, text, item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF00897B).withOpacity(0.2), const Color(0xFF00897B).withOpacity(0.05)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00897B).withOpacity(0.3)),
                ),
                child: Icon(Icons.format_quote_rounded, color: const Color(0xFF00897B), size: 20),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00897B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  language,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF00897B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '"$text"',
            style: ThixPolicy.bodyStyle.copyWith(
              color: ThixPolicy.inkDeep,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Text(
            translation,
            style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.4),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── QUIZ ───
class _QuizSectionWidget extends ConsumerStatefulWidget {
  final String provinceId;
  final NationalLanguage lang;
  const _QuizSectionWidget({required this.provinceId, required this.lang});

  @override
  ConsumerState<_QuizSectionWidget> createState() => _QuizSectionWidgetState();
}

class _QuizSectionWidgetState extends ConsumerState<_QuizSectionWidget> {
  int _currentQuestion = 0;
  int _score = 0;
  bool _showResult = false;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(provinceQuizProvider(widget.provinceId));

    return data.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (questions) {
        if (questions.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFF8E24AA).withOpacity(0.2), const Color(0xFF8E24AA).withOpacity(0.05)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF8E24AA).withOpacity(0.3)),
                      ),
                      child: Icon(Icons.quiz_rounded, color: const Color(0xFF8E24AA), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ProvinceTranslations.translate('quiz', widget.lang),
                            style: ThixPolicy.h3Style.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900),
                          ),
                          Text(
                            'Connaissez-vous votre province ?',
                            style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (!_showResult && _currentQuestion < questions.length) ...[
                  Row(
                    children: [
                      Text(
                        'Question ${_currentQuestion + 1}/${questions.length}',
                        style: ThixPolicy.labelStyle.copyWith(
                          color: const Color(0xFF8E24AA),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Score: $_score',
                        style: ThixPolicy.labelStyle.copyWith(
                          color: const Color(0xFF43A047),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: (_currentQuestion + 1) / questions.length,
                      backgroundColor: const Color(0xFF8E24AA).withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8E24AA)),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    questions[_currentQuestion]['question']?.toString() ?? '',
                    style: ThixPolicy.h3Style.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  ..._buildOptions(questions[_currentQuestion]),
                ] else ...[
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _score >= (questions.length / 2)
                                    ? const Color(0xFF43A047).withOpacity(0.2)
                                    : const Color(0xFFE53935).withOpacity(0.2),
                                _score >= (questions.length / 2)
                                    ? const Color(0xFF43A047).withOpacity(0.05)
                                    : const Color(0xFFE53935).withOpacity(0.05),
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$_score/${questions.length}',
                            style: ThixPolicy.h1Style.copyWith(
                              color: _score >= (questions.length / 2)
                                  ? const Color(0xFF43A047)
                                  : const Color(0xFFE53935),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _score >= (questions.length / 2) ? '🎉 Excellent !' : 'À améliorer',
                          style: ThixPolicy.h2Style.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _currentQuestion = 0;
                              _score = 0;
                              _showResult = false;
                            });
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Rejouer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8E24AA),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildOptions(Map<String, dynamic> question) {
    final options = (question['options'] as List?)?.cast<String>() ?? [];
    final correct = (question['correct_answer'] as num?)?.toInt() ?? 0;

    return options.asMap().entries.map((entry) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (entry.key == correct) _score++;
              setState(() {
                _currentQuestion++;
                if (_currentQuestion >= ref.read(provinceQuizProvider(widget.provinceId)).value!.length) {
                  _showResult = true;
                }
              });
              HapticFeedback.selectionClick();
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ThixPolicy.surfaceSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ThixPolicy.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8E24AA).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        String.fromCharCode(65 + entry.key),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF8E24AA),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}

// ─── BUSINESSES ───
class _BusinessesSection extends ConsumerWidget {
  final String provinceId;
  final NationalLanguage lang;
  const _BusinessesSection({required this.provinceId, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(provinceBusinessesProvider(provinceId));
    return HorizontalGlassSection(
      title: ProvinceTranslations.translate('local_businesses', lang),
      icon: Icons.business_rounded,
      color: const Color(0xFF3949AB),
      data: data,
      builder: (item) => _BusinessCardFromData(item: item),
    );
  }
}

class _BusinessCardFromData extends StatelessWidget {
  final Map<String, dynamic> item;
  const _BusinessCardFromData({required this.item});

  @override
  Widget build(BuildContext context) {
    final name = item['name']?.toString() ?? '';
    final sector = item['sector']?.toString() ?? '';
    final description = item['description']?.toString() ?? '';
    final logo = item['logo_url']?.toString() ?? '';
    final employees = (item['employees'] as num?)?.toInt() ?? 0;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      onTap: () => _showDetailSheet(context, name, item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ThixPolicy.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: logo.isNotEmpty
                      ? CachedNetworkImage(imageUrl: logo, fit: BoxFit.cover)
                      : Container(
                          color: ThixPolicy.surfaceSoft,
                          child: const Icon(Icons.business, color: ThixPolicy.textMuted),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sector,
                      style: ThixPolicy.microStyle.copyWith(
                        color: const Color(0xFF3949AB),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            description,
            style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.4),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.people_rounded, size: 14, color: const Color(0xFF3949AB)),
              const SizedBox(width: 6),
              Text(
                '${_fmtNumber(employees)} employés',
                style: ThixPolicy.captionStyle.copyWith(color: const Color(0xFF3949AB), fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── PRODUCTS ───
class _ProductsSection extends ConsumerWidget {
  final String provinceId;
  final NationalLanguage lang;
  const _ProductsSection({required this.provinceId, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(provinceProductsProvider(provinceId));
    return HorizontalGlassSection(
      title: ProvinceTranslations.translate('local_products', lang),
      icon: Icons.shopping_basket_rounded,
      color: const Color(0xFF689F38),
      data: data,
      builder: (item) => _ProductCardFromData(item: item),
    );
  }
}

class _ProductCardFromData extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ProductCardFromData({required this.item});

  @override
  Widget build(BuildContext context) {
    final name = item['name']?.toString() ?? '';
    final category = item['category']?.toString() ?? '';
    final image = item['image_url']?.toString() ?? '';
    final price = item['price']?.toString() ?? '';

    return GlassCard(
      padding: EdgeInsets.zero,
      onTap: () => _showDetailSheet(context, name, item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: image.isNotEmpty
                ? CachedNetworkImage(imageUrl: image, height: 100, width: double.infinity, fit: BoxFit.cover)
                : Container(height: 100, color: ThixPolicy.surfaceSoft),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: ThixPolicy.microStyle.copyWith(
                    color: const Color(0xFF689F38),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      price,
                      style: ThixPolicy.captionStyle.copyWith(
                        color: const Color(0xFF689F38),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Icon(Icons.shopping_cart_rounded, size: 16, color: const Color(0xFF689F38)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── MAP ───
class _InteractiveMapCard extends StatelessWidget {
  final String url;
  final String provinceName;

  const _InteractiveMapCard({required this.url, required this.provinceName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: GlassCard(
        padding: EdgeInsets.zero,
        onTap: () => _openMediaGallery(context, [{'url': url, 'type': 'photo'}], title: 'Carte — $provinceName'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [ThixPolicy.primary.withOpacity(0.2), ThixPolicy.primary.withOpacity(0.05)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ThixPolicy.primary.withOpacity(0.3)),
                    ),
                    child: Icon(Icons.map_rounded, color: ThixPolicy.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Carte interactive',
                      style: ThixPolicy.h3Style.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900),
                    ),
                  ),
                  Icon(Icons.fullscreen_rounded, color: ThixPolicy.primary, size: 24),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  _buildCachedImage(url, height: 200, width: double.infinity),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.3)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.zoom_in_rounded, size: 14, color: ThixPolicy.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Toucher pour agrandir',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ThixPolicy.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── DEMOGRAPHICS ───
class _DemographicsSectionWidget extends ConsumerWidget {
  final String provinceId;
  final NationalLanguage lang;
  const _DemographicsSectionWidget({required this.provinceId, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(provinceDemographicsProvider(provinceId));
    return data.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFF1565C0).withOpacity(0.2), const Color(0xFF1565C0).withOpacity(0.05)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.3)),
                      ),
                      child: Icon(Icons.analytics_rounded, color: const Color(0xFF1565C0), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        ProvinceTranslations.translate('demography', lang),
                        style: ThixPolicy.h3Style.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 180,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: items.fold<num>(0, (max, i) {
                        final v = (i['population'] as num?)?.toDouble() ?? 0;
                        return v > max ? v : max;
                      }) * 1.1,
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              if (value.toInt() >= items.length) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  items[value.toInt()]['year']?.toString() ?? '',
                                  style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textSecondary),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: items.asMap().entries.map((e) {
                        final pop = (e.value['population'] as num?)?.toDouble() ?? 0;
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: pop,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              width: 28,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── GOUVERNANCE (Province existant) ───
class _GovernanceGlassSection extends StatelessWidget {
  final Province province;
  final NationalLanguage lang;
  const _GovernanceGlassSection({required this.province, required this.lang});

  @override
  Widget build(BuildContext context) {
    final hasGovernor = province.governor != null && province.governor!.isNotEmpty;
    final hasVice = province.viceGovernor != null && province.viceGovernor!.isNotEmpty;
    final ministers = province.ministers ?? [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [ThixPolicy.primary.withOpacity(0.2), ThixPolicy.primary.withOpacity(0.05)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ThixPolicy.primary.withOpacity(0.3)),
                  ),
                  child: Icon(Icons.account_balance_rounded, color: ThixPolicy.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  ProvinceTranslations.translate('governance', lang),
                  style: ThixPolicy.h3Style.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (hasGovernor)
              _GovernancePersonCard(
                role: 'Gouverneur',
                name: province.governor!,
                photoUrl: province.governorPhotoUrl,
                isMain: true,
              ),
            if (hasVice) ...[
              const SizedBox(height: 12),
              _GovernancePersonCard(
                role: 'Vice-Gouverneur',
                name: province.viceGovernor!,
                photoUrl: province.viceGovernorPhotoUrl,
                isMain: false,
              ),
            ],
            if (ministers.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Ministres (${ministers.length})',
                style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ministers.take(6).map((m) {
                  final name = (m as dynamic).name?.toString() ?? '';
                  final role = (m as dynamic).role?.toString() ?? 'Ministre';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: ThixPolicy.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$role - $name',
                      style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.primary, fontWeight: FontWeight.w700),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GovernancePersonCard extends StatelessWidget {
  final String role;
  final String name;
  final String? photoUrl;
  final bool isMain;

  const _GovernancePersonCard({
    required this.role,
    required this.name,
    required this.photoUrl,
    required this.isMain,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    final color = isMain ? ThixPolicy.gold : ThixPolicy.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ThixPolicy.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2.5),
            ),
            child: ClipOval(
              child: hasPhoto
                  ? CachedNetworkImage(imageUrl: photoUrl!, fit: BoxFit.cover)
                  : Container(
                      color: ThixPolicy.card,
                      child: Icon(Icons.person, color: ThixPolicy.textMuted, size: 28),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    role.toUpperCase(),
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: color),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── CULTURE ───
class _CultureGlassSection extends StatelessWidget {
  final Province province;
  const _CultureGlassSection({required this.province});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [ThixPolicy.primary.withOpacity(0.2), ThixPolicy.primary.withOpacity(0.05)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ThixPolicy.primary.withOpacity(0.3)),
                  ),
                  child: Icon(Icons.people_alt_rounded, color: ThixPolicy.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Culture & Tribus',
                  style: ThixPolicy.h3Style.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (province.languages?.trim().isNotEmpty == true) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.forum_rounded, size: 18, color: ThixPolicy.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Langues : ',
                            style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800),
                          ),
                          TextSpan(
                            text: province.languages!,
                            style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            if (province.description?.trim().isNotEmpty == true) ...[
              Text(
                province.description!,
                style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.inkDeep, height: 1.5),
              ),
            ],
            if (province.tribes != null && province.tribes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Tribus (${province.tribes!.length})',
                style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: province.tribes!.take(6).map((t) {
                  final name = (t as dynamic).name?.toString() ?? 'Tribu';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: ThixPolicy.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      name,
                      style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.primary, fontWeight: FontWeight.w700),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── MONOGRAPHY ───
class _MonographyGlassSection extends StatelessWidget {
  final Province province;
  const _MonographyGlassSection({required this.province});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    if (province.history?.trim().isNotEmpty == true) {
      items.add(_MonographyItem(label: 'Histoire', content: province.history!, icon: Icons.menu_book_rounded));
    }
    if (province.climate?.trim().isNotEmpty == true) {
      items.add(_MonographyItem(label: 'Climat', content: province.climate!, icon: Icons.wb_sunny_rounded));
    }
    if (province.infrastructure?.trim().isNotEmpty == true) {
      items.add(_MonographyItem(label: 'Infrastructures', content: province.infrastructure!, icon: Icons.bolt_rounded));
    }
    if (province.education?.trim().isNotEmpty == true) {
      items.add(_MonographyItem(label: 'Éducation', content: province.education!, icon: Icons.school_rounded));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [ThixPolicy.primary.withOpacity(0.2), ThixPolicy.primary.withOpacity(0.05)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ThixPolicy.primary.withOpacity(0.3)),
                  ),
                  child: Icon(Icons.history_edu_rounded, color: ThixPolicy.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Monographie',
                  style: ThixPolicy.h3Style.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...items,
          ],
        ),
      ),
    );
  }
}

class _MonographyItem extends StatelessWidget {
  final String label;
  final String content;
  final IconData icon;
  const _MonographyItem({required this.label, required this.content, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isLong = content.length > 200;
    return InkWell(
      onTap: isLong ? () => _showTextSheet(context, label, content, icon) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: ThixPolicy.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ThixPolicy.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 17, color: ThixPolicy.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              content,
              maxLines: isLong ? 3 : null,
              overflow: isLong ? TextOverflow.ellipsis : TextOverflow.visible,
              style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.inkDeep, height: 1.5),
            ),
            if (isLong)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Lire la suite',
                  style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.primary, fontWeight: FontWeight.w800),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── VISUAL IDENTITY ───
class _VisualIdentityGlassSection extends StatelessWidget {
  final Province province;
  const _VisualIdentityGlassSection({required this.province});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [ThixPolicy.primary.withOpacity(0.2), ThixPolicy.primary.withOpacity(0.05)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ThixPolicy.primary.withOpacity(0.3)),
                  ),
                  child: Icon(Icons.image_rounded, color: ThixPolicy.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Identité visuelle',
                  style: ThixPolicy.h3Style.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _VisualThumb(
                    label: 'Couverture',
                    url: province.coverImageUrl,
                    fallbackIcon: Icons.image_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _VisualThumb(
                    label: 'Blason',
                    url: province.coatOfArmsUrl,
                    fallbackIcon: Icons.shield_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _VisualThumb(
                    label: 'Carte',
                    url: province.mapUrl,
                    fallbackIcon: Icons.map_outlined,
                  ),
                ),
              ],
            ),
            if (province.website != null && province.website!.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              InkWell(
                onTap: () => _launchUrlSafe(province.website!),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: ThixPolicy.surfaceSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ThixPolicy.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.language_rounded, size: 16, color: ThixPolicy.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          province.website!,
                          style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.primary, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VisualThumb extends StatelessWidget {
  final String label;
  final String? url;
  final IconData fallbackIcon;

  const _VisualThumb({required this.label, required this.url, required this.fallbackIcon});

  @override
  Widget build(BuildContext context) {
    final hasImg = url != null && url!.isNotEmpty;
    return GestureDetector(
      onTap: hasImg
          ? () => _openMediaGallery(context, [{'url': url, 'type': 'photo'}], title: label)
          : null,
      child: Column(
        children: [
          Container(
            height: 74,
            width: double.infinity,
            decoration: BoxDecoration(
              color: ThixPolicy.surfaceSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ThixPolicy.border),
            ),
            child: hasImg
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: _buildCachedImage(url!, fit: BoxFit.cover),
                  )
                : Icon(fallbackIcon, color: ThixPolicy.textMuted.withOpacity(0.4)),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted, fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// WIDGETS DE DONNÉES EXISTANTES (Province)
// ============================================================================

class _GalleryMediaCard extends StatelessWidget {
  final Map<String, dynamic> media;
  final VoidCallback onTap;
  const _GalleryMediaCard({required this.media, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final url = media['url']?.toString() ?? '';
    return GlassCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: ThixPolicy.surfaceSoft,
                  child: const Icon(Icons.image, color: ThixPolicy.textMuted),
                ),
              )
            : Container(color: ThixPolicy.surfaceSoft),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final Map<String, dynamic> achievement;
  const _AchievementCard({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final title = achievement['title']?.toString() ?? 'Réalisation';
    final desc = achievement['description']?.toString() ?? '';
    final date = achievement['date']?.toString() ?? '';

    return GlassCard(
      padding: const EdgeInsets.all(16),
      onTap: () => _showDetailSheet(context, title, achievement),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ThixPolicy.gold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.verified_rounded, color: ThixPolicy.gold, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          if (desc.isNotEmpty)
            Text(
              desc,
              style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (date.isNotEmpty)
            Text(
              date,
              style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted, fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }
}

class _CityCardFromData extends StatelessWidget {
  final Map<String, dynamic> city;
  const _CityCardFromData({required this.city});

  @override
  Widget build(BuildContext context) {
    final name = city['name']?.toString() ?? '';
    final isCapital = city['is_capital'] == true;
    final population = (city['population'] as num?)?.toInt();
    final image = city['image_url']?.toString() ?? '';

    return GlassCard(
      padding: EdgeInsets.zero,
      onTap: () => _showDetailSheet(context, name, city),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: image.isNotEmpty
                ? CachedNetworkImage(imageUrl: image, height: 100, width: double.infinity, fit: BoxFit.cover)
                : Container(
                    height: 100,
                    color: isCapital ? const Color(0xFF8A6B00).withOpacity(0.1) : ThixPolicy.surfaceSoft,
                    child: Icon(
                      isCapital ? Icons.star_rounded : Icons.location_city_rounded,
                      color: isCapital ? const Color(0xFF8A6B00) : ThixPolicy.primary,
                      size: 40,
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isCapital)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8A6B00),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'CHEF-LIEU',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.8),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (population != null)
                  Text(
                    '${_fmtNumber(population)} hab',
                    style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DivisionCardFromData extends StatelessWidget {
  final Map<String, dynamic> division;
  const _DivisionCardFromData({required this.division});

  @override
  Widget build(BuildContext context) {
    final name = division['name']?.toString() ?? '';
    final type = division['type']?.toString() ?? 'Division';
    final capital = division['capital']?.toString() ?? '';

    return GlassCard(
      padding: const EdgeInsets.all(16),
      onTap: () => _showDetailSheet(context, name, division),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF6A1B9A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.dashboard_customize_rounded, color: const Color(0xFF6A1B9A), size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            name,
            style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Text(
            type,
            style: ThixPolicy.captionStyle.copyWith(color: const Color(0xFF6A1B9A), fontWeight: FontWeight.w800),
          ),
          if (capital.isNotEmpty)
            Text(
              'Chef-lieu : $capital',
              style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textSecondary),
            ),
        ],
      ),
    );
  }
}

class _TourismCardFromData extends StatelessWidget {
  final Map<String, dynamic> site;
  const _TourismCardFromData({required this.site});

  @override
  Widget build(BuildContext context) {
    final name = site['name']?.toString() ?? '';
    final type = site['type']?.toString() ?? '';
    final desc = site['description']?.toString() ?? '';

    return GlassCard(
      padding: const EdgeInsets.all(16),
      onTap: () => _showDetailSheet(context, name, site),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.landscape_rounded, color: const Color(0xFF1565C0), size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            name,
            style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          if (type.isNotEmpty)
            Text(
              type,
              style: ThixPolicy.captionStyle.copyWith(color: const Color(0xFF1565C0), fontWeight: FontWeight.w800),
            ),
          if (desc.isNotEmpty)
            Text(
              desc,
              style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

class _ResourceCardFromData extends StatelessWidget {
  final Map<String, dynamic> resource;
  const _ResourceCardFromData({required this.resource});

  @override
  Widget build(BuildContext context) {
    final name = resource['name']?.toString() ?? '';
    final desc = resource['description']?.toString() ?? '';

    return GlassCard(
      padding: const EdgeInsets.all(16),
      onTap: () => _showDetailSheet(context, name, resource),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.monetization_on_rounded, color: const Color(0xFF2E7D32), size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            name,
            style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          if (desc.isNotEmpty)
            Text(
              desc,
              style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

class _EmergencyTileFromData extends StatelessWidget {
  final dynamic contact;
  const _EmergencyTileFromData({required this.contact});

  @override
  Widget build(BuildContext context) {
    final service = (contact as dynamic).service?.toString() ?? 'Service';
    final phone = (contact as dynamic).phone?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: ThixPolicy.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ThixPolicy.danger.withOpacity(0.25)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ThixPolicy.danger.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.phone_in_talk_rounded, color: ThixPolicy.danger),
        ),
        title: Text(
          service,
          style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          phone,
          style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w600),
        ),
        trailing: phone.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.call_rounded, color: Color(0xFF2E7D32)),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  launchUrl(Uri.parse('tel:$phone'));
                },
              )
            : null,
      ),
    );
  }
}

// ============================================================================
// UTILITIES
// ============================================================================

Future<void> _launchUrlSafe(String rawUrl) async {
  var u = rawUrl.trim();
  if (!u.startsWith('http://') && !u.startsWith('https://')) u = 'https://$u';
  final uri = Uri.tryParse(u);
  if (uri != null) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

String _fmtNumber(num n) => n
    .toString()
    .replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]} ',
    );

Color _colorFromHex(String hex) {
  hex = hex.replaceAll('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  return Color(int.parse(hex, radix: 16));
}

Widget _buildCachedImage(String url, {BoxFit fit = BoxFit.cover, double? width, double? height}) {
  return CachedNetworkImage(
    imageUrl: url,
    width: width,
    height: height,
    fit: fit,
    placeholder: (context, url) => Container(
      width: width,
      height: height,
      color: ThixPolicy.surfaceSoft,
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary),
        ),
      ),
    ),
    errorWidget: (context, url, error) => Container(
      width: width,
      height: height,
      color: ThixPolicy.surfaceSoft,
      child: Icon(Icons.broken_image_rounded, color: ThixPolicy.textMuted, size: 32),
    ),
  );
}

void _showDetailSheet(BuildContext context, String title, Map<String, dynamic> data) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: ThixPolicy.h2Style.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),
                ...data.entries.where((e) => e.value != null && e.value.toString().isNotEmpty).map((e) {
                  final label = e.key.replaceAll('_', ' ');
                  final value = e.value.toString();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: ThixPolicy.captionStyle.copyWith(
                            color: ThixPolicy.textSecondary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          value,
                          style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.inkDeep, height: 1.5),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void _showTextSheet(BuildContext context, String title, String text, IconData icon) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(icon, color: ThixPolicy.primary, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: ThixPolicy.h2Style.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  text,
                  style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.inkDeep, height: 1.6),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void _openMediaGallery(
  BuildContext context,
  List<Map<String, dynamic>> media, {
  int initialIndex = 0,
  String title = 'Galerie',
}) {
  if (media.isEmpty) return;
  showDialog(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(28),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: ThixPolicy.h3Style.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: media[initialIndex]['url']?.toString() ?? '',
                    height: 300,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThixPolicy.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Fermer'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void _openMediaGrid(
  BuildContext context,
  List<Map<String, dynamic>> media, {
  String title = 'Galerie',
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: Text(title),
          backgroundColor: ThixPolicy.primary,
          foregroundColor: Colors.white,
        ),
        body: GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: media.length,
          itemBuilder: (_, i) => ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: media[i]['url']?.toString() ?? '',
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    ),
  );
}
