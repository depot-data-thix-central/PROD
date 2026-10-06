// lib/presentation/mon_pays/pages/provinces/widgets/province_shortcut_bar.dart
//
// 🧭 BANDE DE RACCOURCIS (référence : bande rouge) + KIT UI PARTAGÉ
// Contient : langues nationales, traductions, providers UI,
// GlassCard / SectionHeader / HScroll / showGlassSheet utilisés par toute la page.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

// ════════════════════════════════════════════════════════════════════════
// 1. LANGUES NATIONALES RDC
// ════════════════════════════════════════════════════════════════════════
enum NationalLanguage { french, lingala, swahili, tshiluba, kikongo }

extension LanguageX on NationalLanguage {
  String get code => ['fr', 'ln', 'sw', 'lu', 'kg'][index];
  String get name => ['Français', 'Lingala', 'Swahili', 'Tshiluba', 'Kikongo'][index];
  String get flag => ['🇫🇷', '🇩', '🇩', '🇩', '🇩'][index];
}

class ProvinceTranslations {
  static const Map<String, List<String>> _tr = {
    'news': ['📢 Actualités', '📢 Nsango', '📢 Habari', '📢 Makani', '📢 Bansangu'],
    'projects': ['🏗️ Projets en cours', '🏗️ Misala', '🏗️ Miradi', '🏗️ Miseu', '🏗️ Bisalu'],
    'services': ['🏛️ Services publics', '🏛️ Misala ya leta', '🏛️ Huduma', '🏛️ Miseu ya leta', '🏛️ Bisalu ya leta'],
    'citizen': ['🗳️ Engagement citoyen', '🗳️ Bato', '🗳️ Raia', '🗳️ Bantu', '🗳️ Wantu'],
    'budget': ['💰 Budget', '💰 Mbongo', '💰 Bajeti', '💰 Mbongo', '💰 Mbongo'],
    'docs': ['📄 Documents officiels', '📄 Mikanda', '📄 Nyaraka', '📄 Mikanda', '📄 Mikanda'],
    'media': ['🎥 Médiathèque', '🎥 Vidéo', '🎥 Media', '🎥 Vidéo', '🎥 Vidéo'],
    'authorities': ['🏛️ Autorités provinciales', '🏛️ Bakambi', '🏛️ Viongozi', '🏛️ Bakambi', '🏛️ Bakambi'],
    'cities': ['🏙️ Villes', '🏙️ Mbanza', '🏙️ Miji', '🏙️ Mbanza', '🏙️ Mbanza'],
    'tourism': ['⛰️ Tourisme', '⛰️ Botamboli', '⛰️ Utalii', '⛰️ Mutambulu', '⛰️ Lutambulu'],
    'economy': ['💼 Économie locale', '💼 Mbongo', '💼 Uchumi', '💼 Mbongo', '💼 Mbongo'],
    'culture': ['🎭 Culture & Patrimoine', '🎭 Bonkoko', '🎭 Utamaduni', '🎭 Bunkole', '🎭 Kinkulu'],
    'quiz': ['🎮 Quiz', '🎮 Masano', '🎮 Maswali', '🎮 Masano', '🎮 Masano'],
    'emergency': ['🚨 Urgences', '🚨 Lisungi', '🚨 Msaada', '🚨 Dikuma', '🚨 Lusadisu'],
    'gallery': ['🖼️ Galerie', '🖼️ Bilili', '🖼️ Picha', '🖼️ Bifanishu', '🖼️ Bifanisu'],
    'map': ['🗺️ Carte', '🗺️ Karta', '🗺️ Ramani', '🗺️ Karta', '🗺️ Karta'],
    'see_all': ['Voir tout', 'Tala nyonso', 'Ona yote', 'Tala yonso', 'Tala yawonso'],
    'empty': ['Aucune donnée disponible', 'Likambo te', 'Hakuna data', 'Kadi kuaba', 'Kadi kiana'],
  };
  static String t(String key, NationalLanguage lang) => _tr[key]?[lang.index] ?? key;
}

class AccessibilitySettings {
  final double textScale;
  final bool highContrast;
  final bool audioMode;
  const AccessibilitySettings({this.textScale = 1.0, this.highContrast = false, this.audioMode = false});
  AccessibilitySettings copyWith({double? textScale, bool? highContrast, bool? audioMode}) =>
      AccessibilitySettings(
        textScale: textScale ?? this.textScale,
        highContrast: highContrast ?? this.highContrast,
        audioMode: audioMode ?? this.audioMode,
      );
}

final accessibilityProvider = StateProvider<AccessibilitySettings>((ref) => const AccessibilitySettings());
final languageProvider = StateProvider<NationalLanguage>((ref) => NationalLanguage.french);

// ════════════════════════════════════════════════════════════════════════
// 2. KIT UI PARTAGÉ (glassmorphism clair)
// ════════════════════════════════════════════════════════════════════════
class GlassTheme {
  static const Color glassBackground = Color(0xE6FFFFFF);
  static const Color glassBorder = Color(0x40FFFFFF);
  static const double glassBlur = 18.0;
  static const double glassRadius = 24.0;
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final double? radius;
  const GlassCard({super.key, required this.child, this.onTap, this.padding, this.radius});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius ?? GlassTheme.glassRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: GlassTheme.glassBlur, sigmaY: GlassTheme.glassBlur),
        child: Container(
          decoration: BoxDecoration(
            color: GlassTheme.glassBackground,
            borderRadius: BorderRadius.circular(radius ?? GlassTheme.glassRadius),
            border: Border.all(color: GlassTheme.glassBorder),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 18, offset: const Offset(0, 8))],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(radius ?? GlassTheme.glassRadius),
              child: Padding(padding: padding ?? const EdgeInsets.all(16), child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final int? count;
  final VoidCallback? onViewAll;
  final String? viewAllLabel;
  const SectionHeader({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.count,
    this.onViewAll,
    this.viewAllLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withOpacity(0.18), color.withOpacity(0.05)]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: ThixPolicy.h3Style.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (count != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
            ),
          if (onViewAll != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onViewAll,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(
                  viewAllLabel ?? 'Voir tout',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Scroll horizontal fluide (découverte).
class HScroll extends StatelessWidget {
  final double height;
  final double itemWidth;
  final List<Widget> children;
  const HScroll({super.key, required this.height, required this.itemWidth, required this.children});

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) => SizedBox(width: itemWidth, child: children[i]),
      ),
    );
  }
}

class SkeletonBox extends StatelessWidget {
  final double width, height;
  const SkeletonBox({super.key, required this.width, required this.height});
  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(20)),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary.withOpacity(0.4))),
      );
}

String fmtNum(num n) => n
    .toString()
    .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

Widget sheetRow(IconData icon, String label, String value, {Color color = ThixPolicy.primary}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text('$label : ', style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary)),
          Expanded(
            child: Text(value, style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

/// Bottom sheet glass réutilisable partout.
void showGlassSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  String? imageUrl,
  IconData? icon,
  Color color = ThixPolicy.primary,
  required List<Widget> children,
}) {
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
            color: Colors.white.withOpacity(0.97),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 42, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(4))),
                ),
                const SizedBox(height: 20),
                if (imageUrl != null && imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(imageUrl, height: 180, width: double.infinity, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(height: 120, color: ThixPolicy.surfaceSoft)),
                  )
                else if (icon != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [color.withOpacity(0.2), color.withOpacity(0.05)]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: color, size: 40),
                  ),
                const SizedBox(height: 16),
                Text(title, style: ThixPolicy.h2Style.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900)),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(subtitle, style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.5)),
                ],
                const SizedBox(height: 16),
                ...children,
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════
// 3. BANDE DE RACCOURCIS (référence : bande rouge)
// ════════════════════════════════════════════════════════════════════════
class ShortcutItem {
  final String id;
  final String label;
  final IconData icon;
  const ShortcutItem(this.id, this.label, this.icon);
}

List<ShortcutItem> provinceShortcutItems(NationalLanguage lang) => [
      ShortcutItem('actu', ProvinceTranslations.t('news', lang).replaceFirst(RegExp(r'^\S+\s'), ''), Icons.newspaper_rounded),
      ShortcutItem('projets', ProvinceTranslations.t('projects', lang).replaceFirst(RegExp(r'^\S+\s'), ''), Icons.construction_rounded),
      ShortcutItem('services', ProvinceTranslations.t('services', lang).replaceFirst(RegExp(r'^\S+\s'), ''), Icons.badge_rounded),
      ShortcutItem('citoyen', ProvinceTranslations.t('citizen', lang).replaceFirst(RegExp(r'^\S+\s'), ''), Icons.how_to_vote_rounded),
      ShortcutItem('budget', ProvinceTranslations.t('budget', lang).replaceFirst(RegExp(r'^\S+\s'), ''), Icons.account_balance_wallet_rounded),
      ShortcutItem('docs', ProvinceTranslations.t('docs', lang).replaceFirst(RegExp(r'^\S+\s'), ''), Icons.description_rounded),
      ShortcutItem('media', ProvinceTranslations.t('media', lang).replaceFirst(RegExp(r'^\S+\s'), ''), Icons.play_circle_rounded),
      ShortcutItem('carte', ProvinceTranslations.t('map', lang).replaceFirst(RegExp(r'^\S+\s'), ''), Icons.map_rounded),
      ShortcutItem('galerie', ProvinceTranslations.t('gallery', lang).replaceFirst(RegExp(r'^\S+\s'), ''), Icons.photo_library_rounded),
      ShortcutItem('autorites', ProvinceTranslations.t('authorities', lang).replaceFirst(RegExp(r'^\S+\s'), ''), Icons.account_balance_rounded),
      ShortcutItem('villes', ProvinceTranslations.t('cities', lang).replaceFirst(RegExp(r'^\S+\s'), ''), Icons.location_city_rounded),
      ShortcutItem('tourisme', ProvinceTranslations.t('tourism', lang).replaceFirst(RegExp(r'^\S+\s'), ''), Icons.landscape_rounded),
      ShortcutItem('economie', ProvinceTranslations.t('economy', lang).replaceFirst(RegExp(r'^\S+\s'), ''), Icons.storefront_rounded),
      ShortcutItem('culture', ProvinceTranslations.t('culture', lang).replaceFirst(RegExp(r'^\S+\s'), ''), Icons.theater_comedy_rounded),
      ShortcutItem('quiz', ProvinceTranslations.t('quiz', lang).replaceFirst(RegExp(r'^\S+\s'), ''), Icons.quiz_rounded),
      ShortcutItem('urgences', ProvinceTranslations.t('emergency', lang).replaceFirst(RegExp(r'^\S+\s'), ''), Icons.emergency_rounded),
    ];

class ProvinceShortcutBar extends StatelessWidget {
  final ValueChanged<String> onTap;
  const ProvinceShortcutBar({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final lang = context.read(languageProvider);
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A8A), ThixPolicy.primary, Color(0xFF6366F1)],
        ),
        boxShadow: [BoxShadow(color: Color(0x331E3A8A), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: SizedBox(
        height: 62,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          itemCount: provinceShortcutItems(lang).length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final item = provinceShortcutItems(lang)[i];
            return GestureDetector(
              onTap: () => onTap(item.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.28)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.icon, size: 15, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      item.label,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
