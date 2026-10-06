// lib/presentation/mon_pays/pages/provinces/province_detail_page.dart
//
// ============================================================================
// 🏠 PROVINCE DETAIL PAGE — FICHIER UNIQUE COMPLET (Production)
// ============================================================================
// ✅ Bande de raccourcis épinglée (type bande rouge)
// ✅ Disposition fluide "découverte" (scroll horizontal par section)
// ✅ Glassmorphism clair
// ✅ Multilingue 5 langues (FR/LN/SW/TL/KG)
// ✅ Accessibilité (taille texte)
// ✅ Recherche globale + Favoris + Partage
// ✅ 100% Supabase via Riverpod
// ✅ Toutes sections : identité, actu, projets, services, engagement, budget,
//    documents, média, hymne, personnalités, gastronomie, proverbes, quiz,
//    entreprises, produits, carte, démo, galerie, autorités provinciales
//    (gouverneur + vice + ministres), réalisations, villes, découpage,
//    tourisme, économie, culture/tribus, monographie, urgences, identité visuelle.
// ============================================================================

import 'dart:async';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

import '../../models/province.dart';
import '../../providers/provinces_provider.dart';

// ════════════════════════════════════════════════════════════════════════
// 1. LANGUES NATIONALES
// ════════════════════════════════════════════════════════════════════════
enum NationalLanguage { french, lingala, swahili, tshiluba, kikongo }

extension LanguageX on NationalLanguage {
  String get code => ['fr', 'ln', 'sw', 'lu', 'kg'][index];
  String get name => ['Français', 'Lingala', 'Swahili', 'Tshiluba', 'Kikongo'][index];
  String get flag => ['🇫🇷', '🇨🇩', '🇨🇩', '🇨🇩', '🇨🇩'][index];
}

final languageProvider = StateProvider<NationalLanguage>((_) => NationalLanguage.french);

class _Tr {
  static const Map<String, List<String>> _d = {
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
    'economy': ['💼 Économie', '💼 Mbongo', '💼 Uchumi', '💼 Mbongo', '💼 Mbongo'],
    'culture': ['🎭 Culture & Patrimoine', '🎭 Bonkoko', '🎭 Utamaduni', '🎭 Bunkole', '🎭 Kinkulu'],
    'quiz': ['🎮 Quiz', '🎮 Masano', '🎮 Maswali', '🎮 Masano', '🎮 Masano'],
    'emergency': ['🚨 Urgences', '🚨 Lisungi', '🚨 Msaada', '🚨 Dikuma', '🚨 Lusadisu'],
    'gallery': ['🖼️ Galerie', '🖼️ Bilili', '🖼️ Picha', '🖼️ Bifanishu', '🖼️ Bifanisu'],
    'map': ['🗺️ Carte', '🗺️ Karta', '🗺️ Ramani', '🗺️ Karta', '🗺️ Karta'],
    'hymn': ['🎵 Hymne provincial', '🎵 Nzémbo', '🎵 Wimbo', '🎵 Nyimbo', '🎵 Nkunga'],
    'famous': ['🌟 Personnalités', '🌟 Bato ya lokumu', '🌟 Watu mashuhuri', '🌟 Bantu ba lukumu', '🌟 Bantu ba lukumu'],
    'gastro': ['🍲 Gastronomie', '🍲 Bilei ya mboka', '🍲 Chakula', '🍲 Bilei', '🍲 Madia'],
    'proverbs': ['📖 Proverbes & Contes', '📖 Masese', '📖 Methali', '📖 Tshisangale', '📖 Bingana'],
    'businesses': ['🏢 Entreprises', '🏢 Bisaleli', '🏢 Biashara', '🏢 Miseu', '🏢 Bisalu'],
    'products': ['🛒 Produits du terroir', '🛒 Biloko', '🛒 Bidhaa', '🛒 Biloko', '🛒 Bima'],
    'demo': ['📈 Démographie', '📈 Bato', '📈 Idadi', '📈 Bantu', '📈 Bantu'],
    'achievements': ['🏆 Réalisations', '🏆 Misala', '🏆 Mafanikio', '🏆 Miseu', '🏆 Bisalu'],
    'divisions': ['🧭 Découpage administratif', '🧭 Bokabuani', '🧭 Mgawanyo', '🧭 Bukabuanyi', '🧭 Kabu'],
  };
  static String t(String key, NationalLanguage lang) => _d[key]?[lang.index] ?? key;
}

// ════════════════════════════════════════════════════════════════════════
// 2. ACCESSIBILITÉ
// ════════════════════════════════════════════════════════════════════════
class AccessibilitySettings {
  final double textScale;
  const AccessibilitySettings({this.textScale = 1.0});
  AccessibilitySettings copyWith({double? textScale}) => AccessibilitySettings(textScale: textScale ?? this.textScale);
}

final accessibilityProvider = StateProvider<AccessibilitySettings>((_) => const AccessibilitySettings());

// ════════════════════════════════════════════════════════════════════════
// 3. PROVIDERS SUPABASE (locaux, production)
// ════════════════════════════════════════════════════════════════════════
SupabaseClient get _db => Supabase.instance.client;

Future<List<Map<String, dynamic>>> _safeRows(Future<List<dynamic>> Function() q) async {
  try {
    final r = await q();
    return r.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  } catch (e) {
    debugPrint('[provider] error: $e');
    return [];
  }
}

final _newsProv = FutureProvider.family<List<Map<String, dynamic>>, String>((r, id) async =>
    await _safeRows(() => _db.from('province_news').select().eq('province_id', id).eq('is_published', true).order('published_at', ascending: false).limit(20)));

final _projectsProv = FutureProvider.family<List<Map<String, dynamic>>, String>((r, id) async =>
    await _safeRows(() => _db.from('province_projects').select().eq('province_id', id).order('progress', ascending: false).limit(20)));

final _servicesProv = FutureProvider.family<List<Map<String, dynamic>>, String>((r, id) async =>
    await _safeRows(() => _db.from('province_services').select().eq('province_id', id).eq('is_active', true).order('name').limit(30)));

final _engagementsProv = FutureProvider.family<List<Map<String, dynamic>>, String>((r, id) async =>
    await _safeRows(() => _db.from('province_engagements').select().eq('province_id', id).eq('is_active', true).order('created_at', ascending: false).limit(20)));

final _budgetProv = FutureProvider.family<List<Map<String, dynamic>>, String>((r, id) async =>
    await _safeRows(() => _db.from('province_budget').select().eq('province_id', id).order('percentage', ascending: false)));

final _documentsProv = FutureProvider.family<List<Map<String, dynamic>>, String>((r, id) async =>
    await _safeRows(() => _db.from('province_documents').select().eq('province_id', id).eq('is_published', true).order('published_at', ascending: false).limit(20)));

final _mediaProv = FutureProvider.family<List<Map<String, dynamic>>, String>((r, id) async =>
    await _safeRows(() => _db.from('province_media').select().eq('province_id', id).eq('is_published', true).order('published_at', ascending: false).limit(20)));

final _hymnProv = FutureProvider.family<Map<String, dynamic>?, String>((r, id) async {
  try {
    final row = await _db.from('province_hymns').select().eq('province_id', id).maybeSingle();
    return row != null ? Map<String, dynamic>.from(row as Map) : null;
  } catch (e) { return null; }
});

final _famousProv = FutureProvider.family<List<Map<String, dynamic>>, String>((r, id) async =>
    await _safeRows(() => _db.from('province_famous_people').select().eq('province_id', id).eq('is_active', true).order('name').limit(20)));

final _gastroProv = FutureProvider.family<List<Map<String, dynamic>>, String>((r, id) async =>
    await _safeRows(() => _db.from('province_gastronomy').select().eq('province_id', id).eq('is_active', true).order('name').limit(20)));

final _proverbsProv = FutureProvider.family<List<Map<String, dynamic>>, String>((r, id) async =>
    await _safeRows(() => _db.from('province_proverbs').select().eq('province_id', id).eq('is_active', true).order('created_at', ascending: false).limit(20)));

final _businessesProv = FutureProvider.family<List<Map<String, dynamic>>, String>((r, id) async =>
    await _safeRows(() => _db.from('province_businesses').select().eq('province_id', id).eq('is_active', true).order('employees', ascending: false).limit(20)));

final _productsProv = FutureProvider.family<List<Map<String, dynamic>>, String>((r, id) async =>
    await _safeRows(() => _db.from('province_products').select().eq('province_id', id).eq('is_active', true).order('name').limit(20)));

final _quizProv = FutureProvider.family<List<Map<String, dynamic>>, String>((r, id) async =>
    await _safeRows(() => _db.from('province_quiz_questions').select().eq('province_id', id).eq('is_active', true).order('order_index').limit(10)));

final _demoProv = FutureProvider.family<List<Map<String, dynamic>>, String>((r, id) async =>
    await _safeRows(() => _db.from('province_demographics').select().eq('province_id', id).order('year')));

final favoriteProvincesProvider = StateNotifierProvider<FavoriteProvincesNotifier, Set<String>>((ref) => FavoriteProvincesNotifier());

class FavoriteProvincesNotifier extends StateNotifier<Set<String>> {
  FavoriteProvincesNotifier() : super({}) { _load(); }
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = (prefs.getStringList('favorite_provinces') ?? []).toSet();
  }
  Future<void> toggle(String id) async {
    final s = Set<String>.from(state);
    s.contains(id) ? s.remove(id) : s.add(id);
    state = s;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorite_provinces', s.toList());
  }
}

// Recherche debounced
final provinceSearchDebouncedProvider = StateNotifierProvider.family<
    _SearchDebounced, List<Map<String, dynamic>>, String>((r, id) => _SearchDebounced(id));

class _SearchDebounced extends StateNotifier<List<Map<String, dynamic>>> {
  final String _id;
  Timer? _t;
  _SearchDebounced(this._id) : super([]);
  void search(String q) {
    _t?.cancel();
    if (q.trim().isEmpty) { state = []; return; }
    _t = Timer(const Duration(milliseconds: 400), () async {
      final results = <Map<String, dynamic>>[];
      try {
        for (final t in ['province_news', 'province_projects', 'province_services']) {
          final rows = await _db.from(t).select().eq('province_id', _id)
              .or('title.ilike.%$q%,name.ilike.%$q%,summary.ilike.%$q%,description.ilike.%$q%').limit(5);
          for (final r in rows.whereType<Map>()) {
            results.add({...Map<String, dynamic>.from(r), '_source': t});
          }
        }
        final cities = await _db.from('cities').select().eq('province_id', _id).ilike('name', '%$q%').limit(5);
        for (final r in cities.whereType<Map>()) {
          results.add({...Map<String, dynamic>.from(r), '_source': 'city'});
        }
      } catch (e) { debugPrint('[search] $e'); }
      state = results;
    });
  }
  @override void dispose() { _t?.cancel(); super.dispose(); }
}

// ════════════════════════════════════════════════════════════════════════
// 4. GLASS HELPERS
// ════════════════════════════════════════════════════════════════════════
class GlassCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final double? radius;
  const GlassCard({super.key, required this.child, this.onTap, this.padding, this.radius});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius ?? 24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xE6FFFFFF),
            borderRadius: BorderRadius.circular(radius ?? 24),
            border: Border.all(color: const Color(0x40FFFFFF)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 18, offset: const Offset(0, 8))],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(radius ?? 24),
              child: Padding(padding: padding ?? const EdgeInsets.all(16), child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final IconData icon; final Color color; final String title;
  final int? count; final VoidCallback? onViewAll;
  const SectionHeader({super.key, required this.icon, required this.color, required this.title, this.count, this.onViewAll});
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
          Expanded(child: Text(title, style: ThixPolicy.h3Style.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis)),
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
                child: Text('Voir tout', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class HScroll extends StatelessWidget {
  final double height, itemWidth; final List<Widget> children;
  const HScroll({super.key, required this.height, required this.itemWidth, required this.children});
  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(), itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) => SizedBox(width: itemWidth, child: children[i]),
      ),
    );
  }
}

String fmtNum(num n) => n.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

Widget _img(String url, {double? h, double? w, BoxFit fit = BoxFit.cover, double radius = 0}) => ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: url, height: h, width: w, fit: fit,
        placeholder: (_, __) => Container(height: h, width: w, color: ThixPolicy.surfaceSoft),
        errorWidget: (_, __, ___) => Container(height: h, width: w, color: ThixPolicy.surfaceSoft, child: const Icon(Icons.image_outlined, color: ThixPolicy.textMuted)),
      ),
    );

void _launch(String url) async {
  var u = url.trim();
  if (!u.startsWith('http')) u = 'https://$u';
  final uri = Uri.tryParse(u);
  if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
}

void showGlassSheet(BuildContext context, {
  required String title, String? subtitle, String? imageUrl,
  IconData? icon, Color color = ThixPolicy.primary, required List<Widget> children,
}) {
  showModalBottomSheet(
    context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
    builder: (_) => ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.97), borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
          padding: const EdgeInsets.all(24),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(4)))),
                const SizedBox(height: 20),
                if (imageUrl != null && imageUrl.isNotEmpty)
                  ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(imageUrl, height: 180, width: double.infinity, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(height: 120, color: ThixPolicy.surfaceSoft)))
                else if (icon != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [color.withOpacity(0.2), color.withOpacity(0.05)]), borderRadius: BorderRadius.circular(16)),
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

Widget sheetRow(IconData icon, String label, String value, {Color color = ThixPolicy.primary}) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: color), const SizedBox(width: 8),
        Text('$label : ', style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary)),
        Expanded(child: Text(value, style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800))),
      ]),
    );

// ════════════════════════════════════════════════════════════════════════
// 5. BANDE RACCOURCIS ÉPINGLÉE
// ════════════════════════════════════════════════════════════════════════
class _Shortcut {
  final String id, label; final IconData icon;
  const _Shortcut(this.id, this.label, this.icon);
}

List<_Shortcut> _shortcuts(NationalLanguage lang) => [
  _Shortcut('actu', _Tr.t('news', lang).replaceFirst(RegExp(r'^\S+\s'), ''), Icons.newspaper_rounded),
  _Shortcut('projets', _Tr.t('projects', lang).replaceFirst(RegExp(r'^\S+\s'), ''), Icons.construction_rounded),
  _Shortcut('services', _Tr.t('services', lang).replaceFirst(RegExp(r'^\S+\s'), ''), Icons.badge_rounded),
  _Shortcut('citoyen', _Tr.t('citizen', lang).replaceFirst(RegExp(r'^\S+\s'), ''), Icons.how_to_vote_rounded),
  _Shortcut('budget', _Tr.t('budget', lang).replaceFirst(RegExp(r'^\S+\s'), ''), Icons.account_balance_wallet_rounded),
  _Shortcut('docs', _Tr.t('docs', lang).replaceFirst(RegExp(r'^\S+\s'), ''), Icons.description_rounded),
  _Shortcut('media', _Tr.t('media', lang).replaceFirst(RegExp(r'^\S+\s'), ''), Icons.play_circle_rounded),
  _Shortcut('hymn', _Tr.t('hymn', lang).replaceFirst(RegExp(r'^\S+\s'), ''), Icons.music_note_rounded),
  _Shortcut('carte', _Tr.t('map', lang).replaceFirst(RegExp(r'^\S+\s'), ''), Icons.map_rounded),
  _Shortcut('galerie', _Tr.t('gallery', lang).replaceFirst(RegExp(r'^\S+\s'), ''), Icons.photo_library_rounded),
  _Shortcut('autorites', _Tr.t('authorities', lang).replaceFirst(RegExp(r'^\S+\s'), ''), Icons.account_balance_rounded),
  _Shortcut('villes', _Tr.t('cities', lang).replaceFirst(RegExp(r'^\S+\s'), ''), Icons.location_city_rounded),
  _Shortcut('tourisme', _Tr.t('tourism', lang).replaceFirst(RegExp(r'^\S+\s'), ''), Icons.landscape_rounded),
  _Shortcut('economie', _Tr.t('economy', lang).replaceFirst(RegExp(r'^\S+\s'), ''), Icons.storefront_rounded),
  _Shortcut('culture', _Tr.t('culture', lang).replaceFirst(RegExp(r'^\S+\s'), ''), Icons.theater_comedy_rounded),
  _Shortcut('quiz', _Tr.t('quiz', lang).replaceFirst(RegExp(r'^\S+\s'), ''), Icons.quiz_rounded),
  _Shortcut('urgences', _Tr.t('emergency', lang).replaceFirst(RegExp(r'^\S+\s'), ''), Icons.emergency_rounded),
];

class _ShortcutBar extends ConsumerWidget {
  final ValueChanged<String> onTap;
  const _ShortcutBar({required this.onTap});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF6366F1)]),
        boxShadow: [BoxShadow(color: Color(0x331E3A8A), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: SizedBox(
        height: 62,
        child: ListView.separated(
          scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          itemCount: _shortcuts(lang).length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final s = _shortcuts(lang)[i];
            return GestureDetector(
              onTap: () => onTap(s.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.28)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(s.icon, size: 15, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(s.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// 6. PAGE PRINCIPALE
// ════════════════════════════════════════════════════════════════════════
class ProvinceDetailPage extends ConsumerStatefulWidget {
  final String provinceId;
  const ProvinceDetailPage({required this.provinceId, super.key});
  @override
  ConsumerState<ProvinceDetailPage> createState() => _ProvinceDetailPageState();
}

class _ProvinceDetailPageState extends ConsumerState<ProvinceDetailPage> {
  final ScrollController _scroll = ScrollController();
  bool _showTop = false;
  static const _ids = ['actu','projets','services','citoyen','budget','docs','media','hymn','carte','galerie','autorites','villes','tourisme','economie','culture','quiz','urgences'];
  late final Map<String, GlobalKey> _keys = {for (final id in _ids) id: GlobalKey()};

  @override void initState() { super.initState(); _scroll.addListener(() { final s = _scroll.offset > 400; if (s != _showTop) setState(() => _showTop = s); }); }
  @override void dispose() { _scroll.dispose(); super.dispose(); }

  void _goTo(String id) {
    final ctx = _keys[id]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 450), curve: Curves.easeInOutCubic, alignment: 0.08);
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = ref.watch(languageProvider);
    final a11y = ref.watch(accessibilityProvider);
    final async = ref.watch(provinceWithAllRelationsProvider(widget.provinceId));

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(a11y.textScale)),
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F8),
        body: Stack(children: [
          Positioned.fill(child: DecoratedBox(
            decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF0F4F8), Color(0xFFE8EEF5), Color(0xFFF8FAFC)])),
            child: Stack(children: [
              Positioned(top: -90, right: -90, child: Container(width: 280, height: 280, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [ThixPolicy.primary.withOpacity(0.08), Colors.transparent])))),
              Positioned(bottom: -60, left: -60, child: Container(width: 200, height: 200, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [ThixPolicy.gold.withOpacity(0.06), Colors.transparent])))),
            ]),
          )),
          async.when(
            loading: () => const Center(child: CircularProgressIndicator(color: ThixPolicy.primary)),
            error: (_, __) => Center(child: Padding(padding: const EdgeInsets.all(32), child: GlassCard(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline_rounded, size: 44, color: ThixPolicy.danger),
              const SizedBox(height: 12),
              Text('Erreur de chargement', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton.icon(onPressed: () => ref.invalidate(provinceWithAllRelationsProvider(widget.provinceId)), icon: const Icon(Icons.refresh_rounded, size: 16), label: Text(l10n.t('common_retry')), style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white)),
            ])))),
            data: (p) => RefreshIndicator(
              color: ThixPolicy.primary,
              onRefresh: () async { ref.invalidate(provinceWithAllRelationsProvider(widget.provinceId)); },
              child: CustomScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  _Header(province: p, onShare: () async {
                    await Share.share('🏛️ ${p.name} — RDC\n📍 ${p.capital}\nVia THIX ID');
                    HapticFeedback.lightImpact();
                  }),
                  SliverPersistentHeader(pinned: true, delegate: _BarDelegate(child: _ShortcutBar(onTap: _goTo))),
                  SliverToBoxAdapter(child: Column(children: [
                    const SizedBox(height: 12), _TopActions(), const SizedBox(height: 12),
                    _IdentityCard(province: p), const SizedBox(height: 28),
                  ])),
                  SliverToBoxAdapter(key: _keys['actu'], child: _NewsSection(id: widget.provinceId, lang: lang)),
                  SliverToBoxAdapter(key: _keys['projets'], child: _ProjectsSection(id: widget.provinceId, lang: lang)),
                  SliverToBoxAdapter(key: _keys['services'], child: _ServicesSection(id: widget.provinceId, lang: lang)),
                  SliverToBoxAdapter(key: _keys['citoyen'], child: _EngagementSection(id: widget.provinceId, lang: lang)),
                  SliverToBoxAdapter(key: _keys['budget'], child: _BudgetSection(id: widget.provinceId, lang: lang)),
                  SliverToBoxAdapter(child: _DemoSection(id: widget.provinceId, lang: lang)),
                  SliverToBoxAdapter(key: _keys['docs'], child: _DocumentsSection(id: widget.provinceId, lang: lang)),
                  SliverToBoxAdapter(key: _keys['media'], child: _MediaSection(id: widget.provinceId, lang: lang)),
                  SliverToBoxAdapter(key: _keys['hymn'], child: _HymnSection(id: widget.provinceId, name: p.name, lang: lang)),
                  SliverToBoxAdapter(key: _keys['carte'], child: _MapCard(province: p, lang: lang)),
                  SliverToBoxAdapter(key: _keys['galerie'], child: _GallerySection(province: p, lang: lang)),
                  SliverToBoxAdapter(key: _keys['autorites'], child: _AuthoritiesSection(province: p, lang: lang)),
                  SliverToBoxAdapter(key: _keys['villes'], child: Column(children: [
                    _CitiesSection(province: p, lang: lang),
                    _DivisionsSection(province: p, lang: lang),
                    if (p.achievements.isNotEmpty) _AchievementsSection(province: p, lang: lang, l10n: l10n),
                  ])),
                  SliverToBoxAdapter(key: _keys['tourisme'], child: _TourismSection(province: p, lang: lang)),
                  SliverToBoxAdapter(key: _keys['economie'], child: _EconomySection(province: p, lang: lang)),
                  SliverToBoxAdapter(key: _keys['culture'], child: _CultureSection(province: p, id: widget.provinceId, lang: lang)),
                  SliverToBoxAdapter(key: _keys['quiz'], child: _QuizSection(id: widget.provinceId, name: p.name, lang: lang)),
                  SliverToBoxAdapter(key: _keys['urgences'], child: _EmergencySection(province: p, lang: lang)),
                  SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 80), child: _VisualIdentitySection(province: p))),
                ],
              ),
            ),
          ),
          if (_showTop) Positioned(
            right: 20, bottom: 30,
            child: GestureDetector(
              onTap: () => _scroll.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeOut),
              child: Container(width: 48, height: 48,
                decoration: BoxDecoration(color: ThixPolicy.primary.withOpacity(0.92), borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: ThixPolicy.primary.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))]),
                child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _BarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _BarDelegate({required this.child});
  @override double get minExtent => 62;
  @override double get maxExtent => 62;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => SizedBox.expand(child: child);
  @override bool shouldRebuild(covariant _BarDelegate old) => false;
}

// ════════════════════════════════════════════════════════════════════════
// HEADER
// ════════════════════════════════════════════════════════════════════════
class _Header extends ConsumerWidget {
  final Province province; final VoidCallback onShare;
  const _Header({required this.province, required this.onShare});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(favoriteProvincesProvider).contains(province.id);
    final cover = province.coverImageUrl ?? '';
    return SliverAppBar(
      expandedHeight: 250, pinned: true, backgroundColor: Colors.transparent, elevation: 0,
      leadingWidth: 56,
      leading: Padding(padding: const EdgeInsets.only(left: 12), child: _gBtn(Icons.arrow_back_rounded, () => Navigator.pop(context))),
      actions: [
        _gBtn(Icons.search_rounded, () => _openSearch(context, ref)),
        _gBtn(Icons.share_rounded, onShare),
        _gBtn(isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded, () {
          ref.read(favoriteProvincesProvider.notifier).toggle(province.id); HapticFeedback.lightImpact();
        }, color: isFav ? ThixPolicy.danger : Colors.white),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16, right: 20),
        title: ClipRRect(borderRadius: BorderRadius.circular(14), child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(14)),
            child: Text(province.name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: ThixPolicy.h3Style.copyWith(color: Colors.white, fontWeight: FontWeight.w900, shadows: const [Shadow(blurRadius: 8, color: Colors.black45)])),
          ),
        )),
        background: Stack(fit: StackFit.expand, children: [
          cover.isNotEmpty ? CachedNetworkImage(imageUrl: cover, fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(color: ThixPolicy.primary))
              : Container(color: ThixPolicy.primary),
          Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.05), Colors.black.withOpacity(0.55)], stops: const [0.35, 1]))),
          Positioned(left: 20, bottom: 56, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: ThixPolicy.danger, borderRadius: BorderRadius.circular(8)),
            child: Text(province.code, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.2)),
          )),
        ]),
      ),
    );
  }

  Widget _gBtn(IconData icon, VoidCallback onTap, {Color color = Colors.white}) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: ClipRRect(borderRadius: BorderRadius.circular(14), child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(14)),
        child: IconButton(icon: Icon(icon, color: color, size: 20), onPressed: onTap, padding: const EdgeInsets.all(10), constraints: const BoxConstraints()),
      ),
    )),
  );
}

void _openSearch(BuildContext context, WidgetRef ref) {
  final provinceId = (ModalRoute.of(context)?.settings.arguments as Map?)?['id']?.toString() ?? '';
  // Récupérer ID depuis le widget parent via la clé
  String id = '';
  context.visitAncestorElements((e) {
    if (e.widget is ProvinceDetailPage) {
      id = (e.widget as ProvinceDetailPage).provinceId;
      return false;
    }
    return true;
  });

  showGlassSheet(
    context,
    title: 'Rechercher',
    icon: Icons.search_rounded,
    children: [
      Consumer(builder: (context, ref, _) {
        final notifier = ref.read(provinceSearchDebouncedProvider(id).notifier);
        final results = ref.watch(provinceSearchDebouncedProvider(id));
        return Column(children: [
          TextField(
            autofocus: true, onChanged: notifier.search,
            decoration: InputDecoration(
              hintText: 'Ville, projet, actualité…',
              prefixIcon: const Icon(Icons.search_rounded, color: ThixPolicy.primary),
              filled: true, fillColor: ThixPolicy.surfaceSoft,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          if (results.isEmpty)
            Padding(padding: const EdgeInsets.all(20), child: Text('Commencez à taper…', style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted)))
          else ...results.map((r) {
            final source = r['_source']?.toString() ?? '';
            final label = (r['name'] ?? r['title'] ?? '').toString();
            return InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: ThixPolicy.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text(source.replaceAll('province_', ''), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: ThixPolicy.primary))),
                  const SizedBox(width: 10),
                  Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w700))),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: ThixPolicy.textMuted),
                ]),
              ),
            );
          }),
        ]);
      }),
    ],
  );
}

// ════════════════════════════════════════════════════════════════════════
// TOP ACTIONS (langue + accessibilité)
// ════════════════════════════════════════════════════════════════════════
class _TopActions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [
      Expanded(child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onTap: () => _langSheet(context, ref),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(lang.flag, style: const TextStyle(fontSize: 17)), const SizedBox(width: 8),
          Text(lang.name, style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w700)),
          const SizedBox(width: 4), const Icon(Icons.keyboard_arrow_down_rounded, size: 17, color: ThixPolicy.textSecondary),
        ]),
      )),
      const SizedBox(width: 8),
      GlassCard(padding: const EdgeInsets.all(11), onTap: () => _a11ySheet(context, ref),
        child: const Icon(Icons.accessibility_new_rounded, color: ThixPolicy.primary, size: 20)),
    ]));
  }
}

void _langSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (_) => ClipRRect(
    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
    child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), child: Container(
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.98), borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 42, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 20),
        Text('Choisir la langue', style: ThixPolicy.h3Style.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900)),
        const SizedBox(height: 20),
        ...NationalLanguage.values.map((l) {
          final active = ref.read(languageProvider) == l;
          return InkWell(
            onTap: () { ref.read(languageProvider.notifier).state = l; Navigator.pop(context); HapticFeedback.selectionClick(); },
            borderRadius: BorderRadius.circular(14),
            child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: active ? ThixPolicy.primary.withOpacity(0.1) : ThixPolicy.surfaceSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: active ? ThixPolicy.primary : ThixPolicy.border, width: active ? 2 : 1)),
              child: Row(children: [
                Text(l.flag, style: const TextStyle(fontSize: 26)), const SizedBox(width: 14),
                Expanded(child: Text(l.name, style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800))),
                if (active) const Icon(Icons.check_circle_rounded, color: ThixPolicy.primary),
              ]),
            ),
          );
        }),
      ]),
    )),
  ));
}

void _a11ySheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (_) => Consumer(builder: (context, ref, _) {
    final s = ref.watch(accessibilityProvider);
    return ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(28)), child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(decoration: BoxDecoration(color: Colors.white.withOpacity(0.98), borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 20),
          Row(children: [const Icon(Icons.accessibility_new_rounded, color: ThixPolicy.primary), const SizedBox(width: 8),
            Text('Accessibilité', style: ThixPolicy.h3Style.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900))]),
          const SizedBox(height: 20),
          Text('Taille du texte', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
          Row(children: [
            Text('A', style: TextStyle(fontSize: 12, color: ThixPolicy.textSecondary)),
            Expanded(child: Slider(value: s.textScale, min: 0.8, max: 1.5, divisions: 7, activeColor: ThixPolicy.primary,
              onChanged: (v) => ref.read(accessibilityProvider.notifier).state = s.copyWith(textScale: v))),
            Text('A', style: TextStyle(fontSize: 22, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w900)),
          ]),
        ]),
      ),
    ));
  }));
}

// ════════════════════════════════════════════════════════════════════════
// IDENTITÉ
// ════════════════════════════════════════════════════════════════════════
class _IdentityCard extends StatelessWidget {
  final Province province;
  const _IdentityCard({required this.province});
  @override
  Widget build(BuildContext context) {
    final hasCoat = (province.coatOfArmsUrl ?? '').isNotEmpty;
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(children: [
        Row(children: [
          Container(width: 78, height: 78,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ThixPolicy.primary.withOpacity(0.35), width: 3),
              boxShadow: [BoxShadow(color: ThixPolicy.primary.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))]),
            child: ClipOval(child: hasCoat
                ? CachedNetworkImage(imageUrl: province.coatOfArmsUrl!, fit: BoxFit.contain, errorWidget: (_, __, ___) => const Icon(Icons.shield_rounded, color: ThixPolicy.primary))
                : const Icon(Icons.shield_rounded, color: ThixPolicy.primary, size: 36)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(province.name, style: ThixPolicy.h2Style.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(gradient: LinearGradient(colors: [ThixPolicy.danger.withOpacity(0.15), ThixPolicy.danger.withOpacity(0.05)]),
                  borderRadius: BorderRadius.circular(6), border: Border.all(color: ThixPolicy.danger.withOpacity(0.3))),
                child: Text(province.code, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: ThixPolicy.danger, letterSpacing: 0.8))),
              const SizedBox(width: 8),
              Flexible(child: Text('Région ${province.region}', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.primary, fontWeight: FontWeight.w700))),
            ]),
            if ((province.motto ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('« ${province.motto} »', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textSecondary, fontStyle: FontStyle.italic)),
            ],
          ])),
        ]),
        const SizedBox(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _stat(Icons.location_city_rounded, ThixPolicy.primary, 'Capitale', province.capital),
          _stat(Icons.groups_rounded, const Color(0xFF43A047), 'Population', province.population != null ? fmtNum(province.population!) : 'N/A'),
          _stat(Icons.map_rounded, const Color(0xFFFB8C00), 'Superficie', province.area != null ? '${fmtNum(province.area!)} km²' : 'N/A'),
          if (province.territoriesCount != null) _stat(Icons.format_list_numbered_rounded, const Color(0xFF8E24AA), 'Territoires', '${province.territoriesCount}'),
        ]),
      ]),
    ));
  }

  Widget _stat(IconData icon, Color color, String label, String value) => Flexible(flex: 1, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(
      gradient: LinearGradient(colors: [color.withOpacity(0.16), color.withOpacity(0.05)]),
      borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.25))),
      child: Icon(icon, size: 19, color: color)),
    const SizedBox(height: 6),
    Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
      style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900, fontSize: 12)),
    const SizedBox(height: 2),
    Text(label, style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted, fontWeight: FontWeight.w600)),
  ])));
}

// ════════════════════════════════════════════════════════════════════════
// NEWS
// ════════════════════════════════════════════════════════════════════════
class _NewsSection extends ConsumerWidget {
  final String id; final NationalLanguage lang;
  const _NewsSection({required this.id, required this.lang});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(_newsProv(id)).when(
      loading: () => const SizedBox.shrink(), error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeader(icon: Icons.newspaper_rounded, color: const Color(0xFF1E88E5), title: _Tr.t('news', lang), count: items.length,
            onViewAll: () => showGlassSheet(context, title: _Tr.t('news', lang), icon: Icons.newspaper_rounded, color: const Color(0xFF1E88E5),
              children: items.map((n) => _newsTile(context, n)).toList())),
          HScroll(height: 210, itemWidth: 290, children: items.map((n) => _NewsCard(item: n)).toList()),
          const SizedBox(height: 20),
        ]);
      },
    );
  }
}

Widget _newsTile(BuildContext context, Map<String, dynamic> n) => Padding(padding: const EdgeInsets.only(bottom: 10), child: GlassCard(
  padding: const EdgeInsets.all(12),
  onTap: () { final u = n['url']?.toString(); if (u != null && u.isNotEmpty) _launch(u); },
  child: Row(children: [
    if ((n['image_url'] ?? '').toString().isNotEmpty) _img(n['image_url'].toString(), h: 56, w: 56, radius: 12),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(n['title']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: ThixPolicy.labelStyle.copyWith(fontWeight: FontWeight.w800, color: ThixPolicy.inkDeep)),
      Text(n['published_at']?.toString().split('T').first ?? '', style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted)),
    ])),
  ]),
));

class _NewsCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _NewsCard({required this.item});
  @override
  Widget build(BuildContext context) {
    final isAlert = item['is_alert'] == true;
    final img = (item['image_url'] ?? '').toString();
    return GlassCard(padding: EdgeInsets.zero,
      onTap: () { final u = item['url']?.toString(); if (u != null && u.isNotEmpty) _launch(u); },
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          img.isNotEmpty ? _img(img, h: 112, w: double.infinity) : Container(height: 112, color: ThixPolicy.surfaceSoft),
          Positioned(top: 8, left: 8, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: isAlert ? ThixPolicy.danger : const Color(0xFF1E88E5), borderRadius: BorderRadius.circular(6)),
            child: Text(item['category']?.toString() ?? 'INFO', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: .8)),
          )),
        ]),
        Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item['title']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
            style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(item['summary']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
            style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary)),
          const SizedBox(height: 6),
          Row(children: [
            Text(item['published_at']?.toString().split('T').first ?? '', style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted, fontWeight: FontWeight.w600)),
            const Spacer(),
            const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF1E88E5)),
          ]),
        ])),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// PROJETS
// ════════════════════════════════════════════════════════════════════════
class _ProjectsSection extends ConsumerWidget {
  final String id; final NationalLanguage lang;
  const _ProjectsSection({required this.id, required this.lang});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(_projectsProv(id)).when(
      loading: () => const SizedBox.shrink(), error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeader(icon: Icons.construction_rounded, color: const Color(0xFFFB8C00), title: _Tr.t('projects', lang), count: items.length),
          HScroll(height: 200, itemWidth: 280, children: items.map((p) => _ProjectCard(item: p)).toList()),
          const SizedBox(height: 20),
        ]);
      },
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ProjectCard({required this.item});
  @override
  Widget build(BuildContext context) {
    final progress = ((item['progress'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0);
    final pct = (progress * 100).round();
    final color = pct >= 75 ? const Color(0xFF43A047) : pct >= 50 ? const Color(0xFFFB8C00) : const Color(0xFF1E88E5);
    return GlassCard(padding: const EdgeInsets.all(14),
      onTap: () => showGlassSheet(context, title: item['name']?.toString() ?? '', subtitle: item['description']?.toString(),
        imageUrl: item['image_url']?.toString(), icon: Icons.construction_rounded, color: color,
        children: [
          sheetRow(Icons.payments_rounded, 'Budget', item['budget']?.toString() ?? '-'),
          sheetRow(Icons.event_rounded, 'Échéance', item['deadline']?.toString() ?? '-'),
          sheetRow(Icons.trending_up_rounded, 'Progression', '$pct%', color: color),
        ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SizedBox(width: 46, height: 46, child: Stack(alignment: Alignment.center, children: [
            SizedBox(width: 46, height: 46, child: CircularProgressIndicator(value: progress, strokeWidth: 5, backgroundColor: color.withOpacity(0.15), valueColor: AlwaysStoppedAnimation(color))),
            Text('$pct%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color)),
          ])),
          const SizedBox(width: 10),
          Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
            child: Text(item['category']?.toString() ?? 'PROJET', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: color, letterSpacing: .8)))),
        ]),
        const SizedBox(height: 10),
        Text(item['name']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
        const Spacer(),
        ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: color.withOpacity(0.12), valueColor: AlwaysStoppedAnimation(color))),
        const SizedBox(height: 8),
        Row(children: [
          Text('💰 ${item['budget'] ?? '-'}', style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('📅 ${item['deadline'] ?? '-'}', style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// SERVICES
// ════════════════════════════════════════════════════════════════════════
class _ServicesSection extends ConsumerWidget {
  final String id; final NationalLanguage lang;
  const _ServicesSection({required this.id, required this.lang});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(_servicesProv(id)).when(
      loading: () => const SizedBox.shrink(), error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeader(icon: Icons.badge_rounded, color: const Color(0xFF43A047), title: _Tr.t('services', lang), count: items.length),
          HScroll(height: 165, itemWidth: 250, children: items.map((s) => _ServiceCard(item: s)).toList()),
          const SizedBox(height: 20),
        ]);
      },
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ServiceCard({required this.item});
  @override
  Widget build(BuildContext context) {
    const colors = [Color(0xFF1E88E5), Color(0xFF43A047), Color(0xFFFB8C00), Color(0xFF8E24AA), Color(0xFFE53935)];
    final color = colors[(item['category']?.toString().hashCode ?? 0).abs() % colors.length];
    return GlassCard(padding: const EdgeInsets.all(14),
      onTap: () => showGlassSheet(context, title: item['name']?.toString() ?? '', subtitle: item['description']?.toString(),
        icon: Icons.badge_rounded, color: color,
        children: [
          sheetRow(Icons.category_rounded, 'Catégorie', item['category']?.toString() ?? '-'),
          sheetRow(Icons.access_time_rounded, 'Horaires', item['hours']?.toString() ?? '-'),
          sheetRow(Icons.location_on_rounded, 'Adresse', item['address']?.toString() ?? '-'),
        ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color.withOpacity(0.2), color.withOpacity(0.05)]), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.badge_rounded, color: color, size: 22)),
          const SizedBox(width: 10),
          Expanded(child: Text(item['category']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
            style: ThixPolicy.microStyle.copyWith(color: color, fontWeight: FontWeight.w900, letterSpacing: .8))),
        ]),
        const SizedBox(height: 8),
        Text(item['name']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
          style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
        const Spacer(),
        Row(children: [
          const Icon(Icons.access_time_rounded, size: 12, color: ThixPolicy.textMuted), const SizedBox(width: 4),
          Expanded(child: Text(item['hours']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
            style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600))),
        ]),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// ENGAGEMENT CITOYEN
// ════════════════════════════════════════════════════════════════════════
class _EngagementSection extends ConsumerWidget {
  final String id; final NationalLanguage lang;
  const _EngagementSection({required this.id, required this.lang});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(_engagementsProv(id)).when(
      loading: () => const SizedBox.shrink(), error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeader(icon: Icons.how_to_vote_rounded, color: const Color(0xFF8E24AA), title: _Tr.t('citizen', lang), count: items.length),
          HScroll(height: 200, itemWidth: 270, children: items.map((e) => _EngagementCard(item: e, pid: id, ref: ref)).toList()),
          const SizedBox(height: 20),
        ]);
      },
    );
  }
}

class _EngagementCard extends StatelessWidget {
  final Map<String, dynamic> item; final String pid; final WidgetRef ref;
  const _EngagementCard({required this.item, required this.pid, required this.ref});
  @override
  Widget build(BuildContext context) {
    final type = item['type']?.toString() ?? 'SONDAGE';
    final color = type.toLowerCase() == 'vote' ? const Color(0xFF43A047)
        : type.toLowerCase() == 'pétition' ? const Color(0xFFFB8C00) : const Color(0xFF8E24AA);
    final participants = (item['participants_count'] as num?)?.toInt() ?? 0;
    return GlassCard(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
        child: Text(type.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: color, letterSpacing: .8))),
      const SizedBox(height: 8),
      Text(item['title']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
        style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Expanded(child: Text(item['description']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
        style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary))),
      Row(children: [
        Icon(Icons.people_rounded, size: 14, color: color), const SizedBox(width: 4),
        Text(fmtNum(participants), style: ThixPolicy.captionStyle.copyWith(color: color, fontWeight: FontWeight.w800)),
        const Spacer(),
        GestureDetector(
          onTap: () async {
            try {
              final row = await _db.from('province_engagements').select('participants_count').eq('id', item['id']).maybeSingle();
              if (row != null) {
                final c = (row['participants_count'] as num? ?? 0).toInt();
                await _db.from('province_engagements').update({'participants_count': c + 1}).eq('id', item['id']);
                ref.invalidate(_engagementsProv(pid));
              }
            } catch (e) { debugPrint('[eng] $e'); }
          },
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
            child: const Text('Participer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white))),
      ]),
    ]));
  }
}

// ════════════════════════════════════════════════════════════════════════
// BUDGET (Pie chart)
// ════════════════════════════════════════════════════════════════════════
class _BudgetSection extends ConsumerWidget {
  final String id; final NationalLanguage lang;
  const _BudgetSection({required this.id, required this.lang});
  static const _palette = [Color(0xFF1E88E5), Color(0xFF43A047), Color(0xFFFB8C00), Color(0xFF8E24AA), Color(0xFFE53935), Color(0xFF5E35B1)];
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(_budgetProv(id)).when(
      loading: () => const SizedBox.shrink(), error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        final total = items.fold<num>(0, (s, i) => s + ((i['amount'] as num?) ?? 0));
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeader(icon: Icons.account_balance_wallet_rounded, color: const Color(0xFF43A047), title: _Tr.t('budget', lang), count: items.length),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: GlassCard(padding: const EdgeInsets.all(16), child: Column(children: [
            SizedBox(height: 180, child: PieChart(PieChartData(
              centerSpaceRadius: 42, sectionsSpace: 2,
              sections: items.asMap().entries.map((e) {
                final pct = ((e.value['percentage'] as num?)?.toDouble() ?? 0).clamp(0.0, 100.0);
                return PieChartSectionData(color: _palette[e.key % _palette.length], value: pct, radius: 48,
                  title: '${pct.toInt()}%', titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white));
              }).toList(),
            ))),
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 6, children: items.asMap().entries.map((e) => Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 9, height: 9, decoration: BoxDecoration(color: _palette[e.key % _palette.length], borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 5),
              Text(e.value['sector']?.toString() ?? '', style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w700)),
            ])).toList()),
            const SizedBox(height: 10),
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFF43A047).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Text('Total : ${fmtNum(total)} USD', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF43A047)))),
          ]))),
          const SizedBox(height: 20),
        ]);
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// DÉMOGRAPHIE (Bar chart)
// ════════════════════════════════════════════════════════════════════════
class _DemoSection extends ConsumerWidget {
  final String id; final NationalLanguage lang;
  const _DemoSection({required this.id, required this.lang});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(_demoProv(id)).when(
      loading: () => const SizedBox.shrink(), error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.length < 2) return const SizedBox.shrink();
        final maxY = items.fold<num>(0, (m, i) {
          final v = (i['population'] as num?)?.toDouble() ?? 0; return v > m ? v : m;
        }) * 1.15;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeader(icon: Icons.analytics_rounded, color: const Color(0xFF1565C0), title: _Tr.t('demo', lang)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: GlassCard(padding: const EdgeInsets.all(16), child: SizedBox(height: 160, child: BarChart(
            BarChartData(
              maxY: maxY, alignment: BarChartAlignment.spaceAround, barTouchData: BarTouchData(enabled: false),
              gridData: const FlGridData(show: false), borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) => Padding(padding: const EdgeInsets.only(top: 6),
                  child: Text(v.toInt() < items.length ? (items[v.toInt()]['year']?.toString() ?? '') : '', style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textSecondary))))),
              ),
              barGroups: items.asMap().entries.map((e) => BarChartGroupData(x: e.key, barRods: [
                BarChartRodData(toY: (e.value['population'] as num?)?.toDouble() ?? 0, width: 26,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF42A5F5)], begin: Alignment.bottomCenter, end: Alignment.topCenter)),
              ])).toList(),
            ),
          ))),
          const SizedBox(height: 20),
        ]);
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// DOCUMENTS
// ════════════════════════════════════════════════════════════════════════
class _DocumentsSection extends ConsumerWidget {
  final String id; final NationalLanguage lang;
  const _DocumentsSection({required this.id, required this.lang});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(_documentsProv(id)).when(
      loading: () => const SizedBox.shrink(), error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeader(icon: Icons.description_rounded, color: const Color(0xFF5E35B1), title: _Tr.t('docs', lang), count: items.length),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: GlassCard(padding: const EdgeInsets.all(12), child: Column(children: items.map((d) {
            return InkWell(onTap: () { final u = d['file_url']?.toString(); if (u != null && u.isNotEmpty) _launch(u); },
              borderRadius: BorderRadius.circular(12),
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), child: Row(children: [
                Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: const Color(0xFF5E35B1).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.gavel_rounded, color: Color(0xFF5E35B1), size: 18)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d['title']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
                  Text('${d['type'] ?? ''} • ${d['published_at']?.toString().split('T').first ?? ''}',
                    style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted)),
                ])),
                const Icon(Icons.download_rounded, size: 18, color: Color(0xFF5E35B1)),
              ])),
            );
          }).toList()))),
          const SizedBox(height: 20),
        ]);
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// MÉDIA
// ════════════════════════════════════════════════════════════════════════
class _MediaSection extends ConsumerWidget {
  final String id; final NationalLanguage lang;
  const _MediaSection({required this.id, required this.lang});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(_mediaProv(id)).when(
      loading: () => const SizedBox.shrink(), error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeader(icon: Icons.play_circle_rounded, color: const Color(0xFFE53935), title: _Tr.t('media', lang), count: items.length),
          HScroll(height: 190, itemWidth: 250, children: items.map((m) => _MediaCard(item: m)).toList()),
          const SizedBox(height: 20),
        ]);
      },
    );
  }
}

class _MediaCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _MediaCard({required this.item});
  @override
  Widget build(BuildContext context) {
    final thumb = (item['thumbnail_url'] ?? '').toString();
    return GlassCard(padding: EdgeInsets.zero,
      onTap: () { final u = item['url']?.toString(); if (u != null && u.isNotEmpty) _launch(u); },
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(alignment: Alignment.center, children: [
          thumb.isNotEmpty ? _img(thumb, h: 110, w: double.infinity) : Container(height: 110, color: ThixPolicy.surfaceSoft),
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
            child: const Icon(Icons.play_arrow_rounded, color: Color(0xFFE53935), size: 26)),
          if ((item['duration'] ?? '').toString().isNotEmpty)
            Positioned(bottom: 6, right: 6, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(5)),
              child: Text(item['duration'].toString(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)))),
        ]),
        Padding(padding: const EdgeInsets.all(10), child: Text(item['title']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
          style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800))),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// HYMNE (lecteur audio)
// ════════════════════════════════════════════════════════════════════════
class _HymnSection extends ConsumerStatefulWidget {
  final String id, name; final NationalLanguage lang;
  const _HymnSection({required this.id, required this.name, required this.lang});
  @override
  ConsumerState<_HymnSection> createState() => _HymnSectionState();
}

class _HymnSectionState extends ConsumerState<_HymnSection> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false, _instrumental = false;
  @override void dispose() { _player.dispose(); super.dispose(); }

  Future<void> _toggle(Map<String, dynamic>? h) async {
    if (h == null) return;
    final url = (_instrumental ? h['instrumental_url'] : h['audio_url'])?.toString();
    if (url == null || url.isEmpty) return;
    if (_playing) { await _player.pause(); } else { await _player.play(UrlSource(url)); }
    setState(() => _playing = !_playing); HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return ref.watch(_hymnProv(widget.id)).when(
      loading: () => const SizedBox.shrink(), error: (_, __) => const SizedBox.shrink(),
      data: (h) {
        if (h == null) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeader(icon: Icons.music_note_rounded, color: ThixPolicy.gold, title: _Tr.t('hymn', widget.lang)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: GlassCard(padding: const EdgeInsets.all(16), child: Column(children: [
            Container(padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(gradient: LinearGradient(colors: [ThixPolicy.gold.withOpacity(0.12), ThixPolicy.gold.withOpacity(0.03)]),
                borderRadius: BorderRadius.circular(16), border: Border.all(color: ThixPolicy.gold.withOpacity(0.25))),
              child: Row(children: [
                GestureDetector(onTap: () => _toggle(h), child: Container(width: 46, height: 46,
                  decoration: BoxDecoration(color: ThixPolicy.gold, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: ThixPolicy.gold.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 3))]),
                  child: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 26))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(h['title']?.toString() ?? 'Hymne provincial', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Row(children: [
                    _verChip('Officielle', !_instrumental, () => setState(() => _instrumental = false)),
                    const SizedBox(width: 6),
                    _verChip('Instrumentale', _instrumental, () => setState(() => _instrumental = true)),
                  ]),
                ])),
              ]),
            ),
            if ((h['lyrics']?.toString() ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Paroles (extrait) :', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text((h['lyrics'].toString().length > 200 ? h['lyrics'].toString().substring(0, 200) + '…' : h['lyrics'].toString()),
                  style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary, fontStyle: FontStyle.italic, height: 1.6)),
              ])),
            ],
          ]))),
          const SizedBox(height: 20),
        ]);
      },
    );
  }

  Widget _verChip(String label, bool sel, VoidCallback onTap) => GestureDetector(onTap: onTap, child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: sel ? ThixPolicy.gold : Colors.transparent, borderRadius: BorderRadius.circular(8),
      border: Border.all(color: sel ? ThixPolicy.gold : ThixPolicy.border)),
    child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: sel ? Colors.white : ThixPolicy.textSecondary)),
  ));
}

// ════════════════════════════════════════════════════════════════════════
// CARTE
// ════════════════════════════════════════════════════════════════════════
class _MapCard extends StatelessWidget {
  final Province province; final NationalLanguage lang;
  const _MapCard({required this.province, required this.lang});
  @override
  Widget build(BuildContext context) {
    final url = province.mapUrl;
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(icon: Icons.map_rounded, color: ThixPolicy.primary, title: _Tr.t('map', lang)),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: GlassCard(padding: EdgeInsets.zero,
        onTap: () => showDialog(context: context, builder: (_) => Dialog(backgroundColor: Colors.transparent, child: GlassCard(padding: const EdgeInsets.all(8),
          child: InteractiveViewer(minScale: 1, maxScale: 4, child: _img(url, h: 380, w: double.infinity))))),
        child: Stack(children: [
          _img(url, h: 190, w: double.infinity, radius: 24),
          Positioned(right: 10, bottom: 10, child: Container(padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 16))),
        ]),
      )),
      const SizedBox(height: 20),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════════
// GALERIE
// ════════════════════════════════════════════════════════════════════════
class _GallerySection extends StatelessWidget {
  final Province province; final NationalLanguage lang;
  const _GallerySection({required this.province, required this.lang});
  @override
  Widget build(BuildContext context) {
    final media = province.galleryMedia;
    if (media.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(icon: Icons.photo_library_rounded, color: ThixPolicy.primary, title: _Tr.t('gallery', lang), count: media.length,
        onViewAll: () => showGlassSheet(context, title: _Tr.t('gallery', lang), icon: Icons.photo_library_rounded, children: [
          GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
            itemCount: media.length,
            itemBuilder: (_, i) => _img(media[i]['url']?.toString() ?? '', h: 100, radius: 12)),
        ])),
      HScroll(height: 150, itemWidth: 160, children: media.map((m) => _img(m['url']?.toString() ?? '', h: 150, w: 160, radius: 20)).toList()),
      const SizedBox(height: 20),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════════
// AUTORITÉS PROVINCIALES (gouverneur + vice + ministres)
// ════════════════════════════════════════════════════════════════════════
class _AuthoritiesSection extends StatelessWidget {
  final Province province; final NationalLanguage lang;
  const _AuthoritiesSection({required this.province, required this.lang});
  @override
  Widget build(BuildContext context) {
    final executives = <Map<String, String?>>[];
    if ((province.governor ?? '').isNotEmpty) {
      executives.add({'role': 'Gouverneur', 'name': province.governor, 'photo': province.governorPhotoUrl});
    }
    if ((province.viceGovernor ?? '').isNotEmpty) {
      executives.add({'role': 'Vice-Gouverneur', 'name': province.viceGovernor, 'photo': province.viceGovernorPhotoUrl});
    }
    final ministers = province.ministers;
    if (executives.isEmpty && ministers.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(icon: Icons.account_balance_rounded, color: ThixPolicy.primary,
        title: _Tr.t('authorities', lang), count: executives.length + ministers.length),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: GlassCard(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (executives.isNotEmpty)
          GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.85),
            itemCount: executives.length,
            itemBuilder: (_, i) => _ExecutiveCard(role: executives[i]['role']!, name: executives[i]['name']!, photoUrl: executives[i]['photo'])),
        if (ministers.isNotEmpty) ...[
          if (executives.isNotEmpty) const SizedBox(height: 16),
          Text('Ministres provinciaux (${ministers.length})', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.78),
            itemCount: ministers.length,
            itemBuilder: (_, i) {
              final m = ministers[i];
              final name = m['name']?.toString() ?? '—';
              final role = m['role']?.toString() ?? 'Ministre';
              final photo = (m['photoUrl'] ?? m['photo_url'] ?? '').toString();
              return _MinisterCard(name: name, role: role, photoUrl: photo);
            }),
        ],
      ]))),
      const SizedBox(height: 20),
    ]);
  }
}

class _ExecutiveCard extends StatelessWidget {
  final String role, name; final String? photoUrl;
  const _ExecutiveCard({required this.role, required this.name, this.photoUrl});
  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    final isGov = role.toLowerCase().contains('gouverneur') && !role.toLowerCase().contains('vice');
    final color = isGov ? ThixPolicy.gold : ThixPolicy.primary;
    return InkWell(onTap: () {
      HapticFeedback.lightImpact();
      showGlassSheet(context, title: name, subtitle: role, imageUrl: hasPhoto ? photoUrl : null, icon: Icons.person_rounded, color: color, children: [
        sheetRow(Icons.workspace_premium_rounded, 'Fonction', role, color: color),
        sheetRow(Icons.account_balance_rounded, 'Institution', 'Gouvernement provincial'),
      ]);
    }, borderRadius: BorderRadius.circular(16), child: Container(
      decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(16), border: Border.all(color: ThixPolicy.border)),
      padding: const EdgeInsets.all(14),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(padding: const EdgeInsets.all(3), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 2.5)),
          child: CircleAvatar(radius: 32, backgroundColor: ThixPolicy.card,
            backgroundImage: hasPhoto ? CachedNetworkImageProvider(photoUrl!) : null,
            child: hasPhoto ? null : Icon(Icons.person_rounded, size: 30, color: ThixPolicy.textMuted))),
        const SizedBox(height: 10),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
          child: Text(role.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: isGov ? const Color(0xFF8A6B00) : ThixPolicy.primary))),
        const SizedBox(height: 6),
        Text(name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900)),
      ]),
    ));
  }
}

class _MinisterCard extends StatelessWidget {
  final String name, role, photoUrl;
  const _MinisterCard({required this.name, required this.role, required this.photoUrl});
  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl.isNotEmpty;
    return InkWell(onTap: () {
      HapticFeedback.lightImpact();
      showGlassSheet(context, title: name, subtitle: role, imageUrl: hasPhoto ? photoUrl : null, icon: Icons.person_rounded, children: [
        sheetRow(Icons.work_rounded, 'Portefeuille', role),
      ]);
    }, borderRadius: BorderRadius.circular(14), child: Container(
      decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(14), border: Border.all(color: ThixPolicy.border)),
      padding: const EdgeInsets.all(10),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        CircleAvatar(radius: 24, backgroundColor: ThixPolicy.card,
          backgroundImage: hasPhoto ? CachedNetworkImageProvider(photoUrl) : null,
          child: hasPhoto ? null : const Icon(Icons.person_rounded, size: 20, color: ThixPolicy.textMuted)),
        const SizedBox(height: 6),
        Text(role, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted, fontWeight: FontWeight.w700)),
        Text(name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
      ]),
    ));
  }
}

// ════════════════════════════════════════════════════════════════════════
// VILLES
// ════════════════════════════════════════════════════════════════════════
class _CitiesSection extends StatelessWidget {
  final Province province; final NationalLanguage lang;
  const _CitiesSection({required this.province, required this.lang});
  @override
  Widget build(BuildContext context) {
    if (province.cities.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(icon: Icons.location_city_rounded, color: const Color(0xFF1565C0), title: _Tr.t('cities', lang), count: province.cities.length),
      HScroll(height: 185, itemWidth: 220, children: province.cities.map((c) {
        final dyn = c as dynamic;
        final img = (dyn.imageUrl ?? '').toString();
        return GlassCard(padding: EdgeInsets.zero,
          onTap: () => showGlassSheet(context, title: c.name, subtitle: c.isCapital ? 'Chef-lieu de la province' : null,
            imageUrl: img.isNotEmpty ? img : null, icon: Icons.location_city_rounded, color: const Color(0xFF1565C0),
            children: [
              if (c.population != null) sheetRow(Icons.groups_rounded, 'Population', '${fmtNum(c.population!.toInt())} hab'),
              if ((c.mayor ?? '').isNotEmpty) sheetRow(Icons.person_rounded, 'Maire', c.mayor!),
            ]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Stack(children: [
              img.isNotEmpty ? _img(img, h: 90, w: double.infinity)
                  : Container(height: 90, color: const Color(0xFF1565C0).withOpacity(0.08), child: const Icon(Icons.location_city_rounded, color: Color(0xFF1565C0), size: 34)),
              if (c.isCapital) Positioned(top: 6, left: 6, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFF8A6B00), borderRadius: BorderRadius.circular(6)),
                child: const Text('CHEF-LIEU', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: .8)))),
            ]),
            Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
              if (c.population != null) Text('${fmtNum(c.population!.toInt())} hab', style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textSecondary)),
            ])),
          ]),
        );
      }).toList()),
      const SizedBox(height: 20),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════════
// DÉCOUPAGE
// ════════════════════════════════════════════════════════════════════════
class _DivisionsSection extends StatelessWidget {
  final Province province; final NationalLanguage lang;
  const _DivisionsSection({required this.province, required this.lang});
  @override
  Widget build(BuildContext context) {
    if (province.administrativeDivisions.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(icon: Icons.dashboard_customize_rounded, color: const Color(0xFF6A1B9A), title: _Tr.t('divisions', lang), count: province.administrativeDivisions.length),
      HScroll(height: 150, itemWidth: 230, children: province.administrativeDivisions.map((d) {
        final dyn = d as dynamic;
        return GlassCard(padding: const EdgeInsets.all(12),
          onTap: () => showGlassSheet(context, title: dyn.name?.toString() ?? '', icon: Icons.dashboard_customize_rounded, color: const Color(0xFF6A1B9A), children: [
            sheetRow(Icons.category_rounded, 'Type', dyn.type?.toString() ?? '-'),
            if ((dyn.capital ?? '').toString().isNotEmpty) sheetRow(Icons.star_rounded, 'Chef-lieu', dyn.capital.toString()),
            if ((dyn.administrator ?? '').toString().isNotEmpty) sheetRow(Icons.person_rounded, 'Administrateur', dyn.administrator.toString()),
          ]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF6A1B9A).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.dashboard_customize_rounded, color: Color(0xFF6A1B9A), size: 18)),
              const SizedBox(width: 8),
              Expanded(child: Text(dyn.name?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800))),
            ]),
            const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFF6A1B9A).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(dyn.type?.toString() ?? '', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF6A1B9A)))),
          ]),
        );
      }).toList()),
      const SizedBox(height: 20),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════════
// RÉALISATIONS
// ════════════════════════════════════════════════════════════════════════
class _AchievementsSection extends StatelessWidget {
  final Province province; final NationalLanguage lang; final AppLocalizations l10n;
  const _AchievementsSection({required this.province, required this.lang, required this.l10n});
  @override
  Widget build(BuildContext context) {
    if (province.achievements.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(icon: Icons.emoji_events_rounded, color: ThixPolicy.gold, title: l10n.t('province_achievements'), count: province.achievements.length),
      HScroll(height: 180, itemWidth: 250, children: province.achievements.map((a) {
        final title = a['title']?.toString() ?? '';
        final desc = a['description']?.toString() ?? '';
        final date = a['date']?.toString() ?? '';
        return GlassCard(padding: const EdgeInsets.all(14),
          onTap: () => showGlassSheet(context, title: title, subtitle: desc, icon: Icons.verified_rounded, color: ThixPolicy.gold, children: [
            if (date.isNotEmpty) sheetRow(Icons.event_rounded, 'Date', date),
          ]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: ThixPolicy.gold.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.verified_rounded, color: ThixPolicy.gold, size: 22)),
            const SizedBox(height: 10),
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
            const Spacer(),
            Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.4)),
            if (date.isNotEmpty) Text(date, style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted, fontWeight: FontWeight.w600)),
          ]),
        );
      }).toList()),
      const SizedBox(height: 20),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════════
// TOURISME
// ════════════════════════════════════════════════════════════════════════
class _TourismSection extends StatelessWidget {
  final Province province; final NationalLanguage lang;
  const _TourismSection({required this.province, required this.lang});
  @override
  Widget build(BuildContext context) {
    if (province.tourismSites.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(icon: Icons.landscape_rounded, color: const Color(0xFF1565C0), title: _Tr.t('tourism', lang), count: province.tourismSites.length),
      HScroll(height: 200, itemWidth: 240, children: province.tourismSites.map((s) {
        final dyn = s as dynamic;
        final media = (dyn.media as List?) ?? [];
        final img = media.isNotEmpty ? (media.first['url']?.toString() ?? '') : '';
        return GlassCard(padding: EdgeInsets.zero,
          onTap: () => showGlassSheet(context, title: dyn.name?.toString() ?? '', subtitle: dyn.description?.toString(),
            imageUrl: img.isNotEmpty ? img : null, icon: Icons.landscape_rounded, color: const Color(0xFF1565C0), children: [
            if ((dyn.type ?? '').toString().isNotEmpty) sheetRow(Icons.category_rounded, 'Type', dyn.type.toString()),
          ]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Stack(children: [
              img.isNotEmpty ? _img(img, h: 110, w: double.infinity)
                  : Container(height: 110, color: const Color(0xFF1565C0).withOpacity(0.08), child: const Icon(Icons.landscape_rounded, color: Color(0xFF1565C0), size: 34)),
              Positioned(top: 6, left: 6, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFF1565C0), borderRadius: BorderRadius.circular(6)),
                child: Text(dyn.type?.toString() ?? 'SITE', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: .8)))),
            ]),
            Padding(padding: const EdgeInsets.all(10), child: Text(dyn.name?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
              style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800))),
          ]),
        );
      }).toList()),
      const SizedBox(height: 20),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════════
// ÉCONOMIE
// ════════════════════════════════════════════════════════════════════════
class _EconomySection extends StatelessWidget {
  final Province province; final NationalLanguage lang;
  const _EconomySection({required this.province, required this.lang});
  @override
  Widget build(BuildContext context) {
    final r = province.economicResources;
    if (r.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(icon: Icons.storefront_rounded, color: const Color(0xFF2E7D32), title: _Tr.t('economy', lang), count: r.length),
      HScroll(height: 165, itemWidth: 250, children: r.map((res) {
        return GlassCard(padding: const EdgeInsets.all(12),
          onTap: () => showGlassSheet(context, title: res.name, subtitle: res.description, icon: Icons.monetization_on_rounded, color: const Color(0xFF2E7D32), children: const []),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: const Color(0xFF2E7D32).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.monetization_on_rounded, color: Color(0xFF2E7D32), size: 18)),
              const SizedBox(width: 10),
              Expanded(child: Text(res.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800))),
            ]),
            const Spacer(),
            Text(res.description ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
              style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.4)),
          ]),
        );
      }).toList()),
      const SizedBox(height: 20),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════════
// CULTURE (tribus, langues, description, monographie)
// ════════════════════════════════════════════════════════════════════════
class _CultureSection extends StatelessWidget {
  final Province province; final String id; final NationalLanguage lang;
  const _CultureSection({required this.province, required this.id, required this.lang});
  @override
  Widget build(BuildContext context) {
    final p = province;
    final tribes = p.tribes;
    final hasLang = (p.languages ?? '').isNotEmpty;
    final hasDesc = (p.description ?? '').isNotEmpty;
    final hasResources = (p.resources ?? '').isNotEmpty;
    final hasTribes = tribes.isNotEmpty;
    final hasMono = (p.history ?? p.climate ?? p.infrastructure ?? p.education ?? '').isNotEmpty;
    if (!hasLang && !hasDesc && !hasResources && !hasTribes && !hasMono) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(icon: Icons.theater_comedy_rounded, color: ThixPolicy.gold, title: _Tr.t('culture', lang), count: tribes.length),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: GlassCard(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (hasLang) _infoRow(Icons.forum_rounded, ThixPolicy.primary, 'Langues : ', p.languages!),
        if (hasResources) _infoRow(Icons.diamond_rounded, ThixPolicy.gold, 'Ressources : ', p.resources!),
        if (hasDesc) ...[const SizedBox(height: 8), Text(p.description!, style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.inkDeep, height: 1.5))],
        if (hasTribes) ...[
          const SizedBox(height: 16),
          Text('Peuples & Tribus', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          SizedBox(height: 150, child: ListView.separated(scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(),
            itemCount: tribes.length, separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final t = tribes[i];
              final name = t['name']?.toString() ?? 'Tribu';
              final zone = t['zone']?.toString() ?? '';
              final history = t['history']?.toString() ?? '';
              return SizedBox(width: 220, child: GlassCard(padding: const EdgeInsets.all(12), radius: 16,
                onTap: () => showGlassSheet(context, title: name, subtitle: zone.isNotEmpty ? 'Zone : $zone' : null, icon: Icons.groups_rounded,
                  children: [if (history.isNotEmpty) Text(history, style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.inkDeep, height: 1.6))]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: ThixPolicy.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.groups_rounded, color: ThixPolicy.primary, size: 16)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800))),
                  ]),
                  const SizedBox(height: 6),
                  if (zone.isNotEmpty) Text('📍 $zone', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.primary, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text(history, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.4)),
                ]),
              ));
            })),
        ],
        if (hasMono) ...[
          const SizedBox(height: 16),
          Text('Monographie', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if ((p.history ?? '').isNotEmpty) _monoTile(context, 'Histoire & Origines', p.history!, Icons.menu_book_rounded),
          if ((p.climate ?? '').isNotEmpty) _monoTile(context, 'Climat & Relief', p.climate!, Icons.wb_sunny_rounded),
          if ((p.infrastructure ?? '').isNotEmpty) _monoTile(context, 'Infrastructures', p.infrastructure!, Icons.bolt_rounded),
          if ((p.education ?? '').isNotEmpty) _monoTile(context, 'Éducation & Santé', p.education!, Icons.school_rounded),
        ],
        // Personnalités
        Consumer(builder: (context, ref, _) {
          return ref.watch(_famousProv(id)).whenOrNull(data: (items) {
            if (items.isEmpty) return const SizedBox.shrink();
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 16),
              Text('Personnalités célèbres', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              SizedBox(height: 190, child: ListView.separated(scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(),
                itemCount: items.length, separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final f = items[i];
                  final photo = (f['photo_url'] ?? '').toString();
                  return SizedBox(width: 200, child: GlassCard(padding: const EdgeInsets.all(12), radius: 16,
                    onTap: () => showGlassSheet(context, title: f['name']?.toString() ?? '', subtitle: f['bio']?.toString(),
                      imageUrl: photo.isNotEmpty ? photo : null, icon: Icons.emoji_events_rounded, color: ThixPolicy.gold, children: [
                      if ((f['achievement'] ?? '').toString().isNotEmpty) sheetRow(Icons.workspace_premium_rounded, 'Distinction', f['achievement'].toString(), color: ThixPolicy.gold),
                    ]),
                    child: Column(children: [
                      Container(width: 62, height: 62, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ThixPolicy.gold, width: 2)),
                        child: ClipOval(child: photo.isNotEmpty
                          ? CachedNetworkImage(imageUrl: photo, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.person, color: ThixPolicy.textMuted))
                          : const Icon(Icons.person, color: ThixPolicy.textMuted))),
                      const SizedBox(height: 8),
                      Text(f['name']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900)),
                      Text(f['field']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.gold, fontWeight: FontWeight.w800)),
                      const Spacer(),
                      if ((f['achievement'] ?? '').toString().isNotEmpty)
                        Text(f['achievement'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textSecondary)),
                    ]),
                  ));
                })),
            ]);
          }) ?? const SizedBox.shrink();
        }),
        // Gastronomie
        Consumer(builder: (context, ref, _) {
          return ref.watch(_gastroProv(id)).whenOrNull(data: (items) {
            if (items.isEmpty) return const SizedBox.shrink();
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 16),
              Text('Gastronomie', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              SizedBox(height: 190, child: ListView.separated(scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(),
                itemCount: items.length, separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final g = items[i];
                  final img = (g['image_url'] ?? '').toString();
                  return SizedBox(width: 200, child: GlassCard(padding: EdgeInsets.zero, radius: 16,
                    onTap: () {
                      final ingredients = (g['ingredients'] is List)
                          ? (g['ingredients'] as List).map((e) => e.toString()).toList()
                          : (g['ingredients']?.toString() ?? '').split(',').where((e) => e.trim().isNotEmpty).toList();
                      showGlassSheet(context, title: g['name']?.toString() ?? '', subtitle: g['description']?.toString(),
                        imageUrl: img.isNotEmpty ? img : null, icon: Icons.restaurant_rounded, color: const Color(0xFFD81B60), children: [
                        if (ingredients.isNotEmpty) ...[
                          Text('Ingrédients', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Wrap(spacing: 6, runSpacing: 6, children: ingredients.map((ing) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: const Color(0xFFD81B60).withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                            child: Text(ing.trim(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFD81B60))),
                          )).toList()),
                        ],
                      ]);
                    },
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      img.isNotEmpty ? ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: CachedNetworkImage(imageUrl: img, height: 90, width: double.infinity, fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(height: 90, color: ThixPolicy.surfaceSoft)))
                        : Container(height: 90, color: ThixPolicy.surfaceSoft),
                      Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(g['name']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
                        Text(g['description']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textSecondary)),
                      ])),
                    ]),
                  ));
                })),
            ]);
          }) ?? const SizedBox.shrink();
        }),
        // Proverbes
        Consumer(builder: (context, ref, _) {
          return ref.watch(_proverbsProv(id)).whenOrNull(data: (items) {
            if (items.isEmpty) return const SizedBox.shrink();
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 16),
              Text('Proverbes & Contes', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              SizedBox(height: 160, child: ListView.separated(scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(),
                itemCount: items.length, separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final pr = items[i];
                  return SizedBox(width: 240, child: GlassCard(padding: const EdgeInsets.all(12), radius: 16,
                    onTap: () => showGlassSheet(context, title: pr['text']?.toString() ?? '', subtitle: pr['translation']?.toString(),
                      icon: Icons.format_quote_rounded, color: const Color(0xFF00897B),
                      children: [if ((pr['meaning'] ?? '').toString().isNotEmpty) Text(pr['meaning'].toString(), style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.inkDeep, height: 1.6))]),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.format_quote_rounded, size: 16, color: Color(0xFF00897B)), const Spacer(),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFF00897B).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                          child: Text(pr['language']?.toString() ?? '', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF00897B)))),
                      ]),
                      const SizedBox(height: 8),
                      Text('"${pr['text'] ?? ''}"', maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic)),
                      const Spacer(),
                      Text(pr['translation']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textSecondary)),
                    ]),
                  ));
                })),
            ]);
          }) ?? const SizedBox.shrink();
        }),
      ]))),
      const SizedBox(height: 20),
    ]);
  }

  Widget _infoRow(IconData icon, Color color, String label, String value) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, size: 16, color: color), const SizedBox(width: 8),
    Expanded(child: Text.rich(TextSpan(children: [
      TextSpan(text: label, style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
      TextSpan(text: value, style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary)),
    ]))),
  ]));

  Widget _monoTile(BuildContext context, String label, String content, IconData icon) => InkWell(
    onTap: () => showGlassSheet(context, title: label, icon: icon,
      children: [Text(content, style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.inkDeep, height: 1.6))]),
    borderRadius: BorderRadius.circular(12),
    child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(12), border: Border.all(color: ThixPolicy.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 15, color: ThixPolicy.primary), const SizedBox(width: 8),
          Expanded(child: Text(label, style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800))),
          const Icon(Icons.chevron_right_rounded, size: 16, color: ThixPolicy.textMuted),
        ]),
        const SizedBox(height: 6),
        Text(content, maxLines: 2, overflow: TextOverflow.ellipsis, style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.5)),
      ]),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════
// QUIZ
// ════════════════════════════════════════════════════════════════════════
class _QuizSection extends ConsumerStatefulWidget {
  final String id, name; final NationalLanguage lang;
  const _QuizSection({required this.id, required this.name, required this.lang});
  @override
  ConsumerState<_QuizSection> createState() => _QuizSectionState();
}

class _QuizSectionState extends ConsumerState<_QuizSection> {
  int _index = 0, _score = 0; int? _selected; bool _done = false;

  void _answer(int choice, int correct, int total) {
    if (_selected != null) return;
    setState(() => _selected = choice);
    if (choice == correct) _score++;
    HapticFeedback.selectionClick();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() { _selected = null; _index++; if (_index >= total) _done = true; });
    });
  }

  void _reset() => setState(() { _index = 0; _score = 0; _selected = null; _done = false; });

  @override
  Widget build(BuildContext context) {
    return ref.watch(_quizProv(widget.id)).when(
      loading: () => const SizedBox.shrink(), error: (_, __) => const SizedBox.shrink(),
      data: (questions) {
        if (questions.isEmpty) return const SizedBox.shrink();
        final total = questions.length;
        final q = _index < total ? questions[_index] : null;
        final options = q == null ? <String>[] : ((q['options'] as List?) ?? []).map((e) => e.toString()).toList();
        final correct = (q?['correct_answer'] as num?)?.toInt() ?? 0;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeader(icon: Icons.quiz_rounded, color: const Color(0xFF8E24AA), title: _Tr.t('quiz', widget.lang), count: total),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: GlassCard(padding: const EdgeInsets.all(18),
            child: !_done && q != null ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('Question ${_index + 1}/$total', style: ThixPolicy.captionStyle.copyWith(color: const Color(0xFF8E24AA), fontWeight: FontWeight.w800)),
                const Spacer(),
                Text('Score : $_score', style: ThixPolicy.captionStyle.copyWith(color: const Color(0xFF43A047), fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 8),
              ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(
                value: (_index + 1) / total, minHeight: 6,
                backgroundColor: const Color(0xFF8E24AA).withOpacity(0.12), valueColor: const AlwaysStoppedAnimation(Color(0xFF8E24AA)))),
              const SizedBox(height: 16),
              Text(q['question']?.toString() ?? '', style: ThixPolicy.h3Style.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              ...options.asMap().entries.map((e) {
                final isSel = _selected == e.key;
                final isCorrect = e.key == correct;
                final showState = _selected != null;
                Color bg = ThixPolicy.surfaceSoft;
                Color bd = ThixPolicy.border;
                if (showState && isCorrect) { bg = const Color(0xFF43A047).withOpacity(0.12); bd = const Color(0xFF43A047); }
                else if (showState && isSel && !isCorrect) { bg = ThixPolicy.danger.withOpacity(0.1); bd = ThixPolicy.danger; }
                return InkWell(onTap: () => _answer(e.key, correct, total), borderRadius: BorderRadius.circular(12),
                  child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: bd)),
                    child: Row(children: [
                      Container(width: 26, height: 26, decoration: BoxDecoration(color: const Color(0xFF8E24AA).withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                        child: Center(child: Text(String.fromCharCode(65 + e.key), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF8E24AA))))),
                      const SizedBox(width: 10),
                      Expanded(child: Text(e.value, style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w700))),
                    ]),
                  ));
              }),
            ]) : Column(children: [
              Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  (_score >= total / 2 ? const Color(0xFF43A047) : const Color(0xFFE53935)).withOpacity(0.18),
                  Colors.transparent]), shape: BoxShape.circle),
                child: Text('$_score/$total', style: ThixPolicy.h1Style.copyWith(
                  color: _score >= total / 2 ? const Color(0xFF43A047) : const Color(0xFFE53935), fontWeight: FontWeight.w900))),
              const SizedBox(height: 12),
              Text(_score >= total / 2 ? '🎉 Excellent !' : '💪 À améliorer',
                style: ThixPolicy.h2Style.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('Vous connaissez ${_score >= total / 2 ? 'bien' : 'encore peu'} ${widget.name} !',
                textAlign: TextAlign.center, style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary)),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                ElevatedButton.icon(onPressed: _reset, icon: const Icon(Icons.refresh_rounded, size: 16), label: const Text('Rejouer'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8E24AA), foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(width: 8),
                OutlinedButton.icon(onPressed: () => Share.share('🎮 Quiz ${widget.name} : $_score/$total sur THIX ID !'),
                  icon: const Icon(Icons.share_rounded, size: 16), label: const Text('Partager'),
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF8E24AA), side: const BorderSide(color: Color(0xFF8E24AA)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
              ]),
            ]),
          )),
          const SizedBox(height: 20),
        ]);
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// URGENCES
// ════════════════════════════════════════════════════════════════════════
class _EmergencySection extends StatelessWidget {
  final Province province; final NationalLanguage lang;
  const _EmergencySection({required this.province, required this.lang});
  @override
  Widget build(BuildContext context) {
    if (province.emergencyContacts.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(icon: Icons.emergency_rounded, color: ThixPolicy.danger, title: _Tr.t('emergency', lang), count: province.emergencyContacts.length),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: GlassCard(padding: const EdgeInsets.all(12), child: Column(children: province.emergencyContacts.map((c) {
        final dyn = c as dynamic;
        final service = dyn.service?.toString() ?? 'Service';
        final phone = dyn.phone?.toString() ?? '';
        return Container(margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(14), border: Border.all(color: ThixPolicy.danger.withOpacity(0.25))),
          child: ListTile(
            leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: ThixPolicy.danger.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.phone_in_talk_rounded, color: ThixPolicy.danger, size: 18)),
            title: Text(service, style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
            subtitle: Text(phone, style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w600)),
            trailing: phone.isNotEmpty ? IconButton(
              icon: const Icon(Icons.call_rounded, color: Color(0xFF2E7D32), size: 20),
              onPressed: () { HapticFeedback.lightImpact(); launchUrl(Uri.parse('tel:$phone')); }) : null,
          ));
      }).toList()))),
      const SizedBox(height: 20),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════════
// IDENTITÉ VISUELLE (couverture + blason + drapeau + site)
// ════════════════════════════════════════════════════════════════════════
class _VisualIdentitySection extends StatelessWidget {
  final Province province;
  const _VisualIdentitySection({required this.province});
  @override
  Widget build(BuildContext context) {
    return GlassCard(padding: const EdgeInsets.all(16), child: Column(children: [
      Row(children: [
        const Icon(Icons.image_rounded, size: 18, color: ThixPolicy.primary), const SizedBox(width: 8),
        Text('Identité visuelle', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _thumb(context, 'Couverture', province.coverImageUrl, Icons.image_outlined)),
        const SizedBox(width: 10),
        Expanded(child: _thumb(context, 'Blason', province.coatOfArmsUrl, Icons.shield_outlined)),
        const SizedBox(width: 10),
        Expanded(child: _thumb(context, 'Drapeau', province.flagUrl, Icons.flag_outlined)),
      ]),
      if ((province.website ?? '').isNotEmpty) ...[
        const SizedBox(height: 12),
        InkWell(onTap: () => _launch(province.website!), borderRadius: BorderRadius.circular(12),
          child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(12), border: Border.all(color: ThixPolicy.border)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.language_rounded, size: 15, color: ThixPolicy.primary), const SizedBox(width: 6),
              Flexible(child: Text(province.website!, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.primary, fontWeight: FontWeight.w700))),
            ]))),
      ],
    ]));
  }

  Widget _thumb(BuildContext context, String label, String? url, IconData fallback) {
    final has = url != null && url.isNotEmpty;
    return GestureDetector(onTap: has ? () => showGlassSheet(context, title: label, imageUrl: url, children: const []) : null,
      child: Column(children: [
        Container(height: 70, decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(12), border: Border.all(color: ThixPolicy.border)),
          child: has ? _img(url, h: 70, w: double.infinity, radius: 12) : Icon(fallback, color: ThixPolicy.textMuted.withOpacity(0.4), size: 22)),
        const SizedBox(height: 4),
        Text(label, style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted, fontWeight: FontWeight.w600)),
      ]));
  }
}
