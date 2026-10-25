// lib/presentation/mon_pays/pages/provinces/province_detail_page.dart
//
// ============================================================================
// 🏛️ PROVINCE DETAIL PAGE — v3 « DESIGN INSTITUTIONNEL »
// ============================================================================
// • Refonte design 100 % : style institutionnel (navy / or / ivoire),
//   masthead officiel, en-têtes de section à filet doré, cartes sobres.
// • Services & sites : TOUTES les photos affichées (bande défilante dans la
//   carte + grille complète dans la fiche détaillée).
// • Actualités : clic → page article (texte intégral, source officielle, partage).
// • Textes longs : widget ExpandableText « Voir plus / Voir moins ».
// • Corrections : titre non rogné, clé l10n brute, budgets illisibles, vides.
// ============================================================================
import 'dart:async';
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
  String get flag => ['🇫🇷', '🇨', '🇩', '🇩', '🇩'][index];
}

final languageProvider = StateProvider<NationalLanguage>((_) => NationalLanguage.french);

class _Tr {
  static const Map<String, List<String>> _d = {
    'news': ['📢 Actualités', '📢 Nsango', '📢 Habari', '📢 Makani', '📢 Bansangu'],
    'projects': ['🏗️ Projets en cours', '🏗️ Misala', '🏗️ Miradi', '🏗️ Miseu', '🏗️ Bisalu'],
    'services': ['🏛️ Services publics', '🏛️ Misala ya leta', '🏛️ Huduma', '🏛️ Miseu ya leta', '🏛️ Bisalu ya leta'],
    'citizen': ['🗳️ Engagement citoyen', '🗳️ Bato', '🗳️ Raia', '🗳️ Bantu', '🗳️ Wantu'],
    'budget': ['💰 Budget', '💰 Mbongo', '️ Bajeti', '🏛️ Mbongo', '🏛️ Mbongo'],
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
    'demo': ['📈 Démographie', '📈 Bato', '📈 Idadi', '📈 Bantu', '📈 Bantu'],
    'achievements': ['🏆 Réalisations', '🏆 Misala', '🏆 Mafanikio', '🏆 Miseu', '🏆 Bisalu'],
    'divisions': ['🧭 Découpage administratif', '🧭 Bokabuani', '🧭 Mgawanyo', '🧭 Bukabuanyi', '🧭 Kabu'],
    'more': ['Voir plus', 'Koba mingi', 'Soma zaidi', 'Mona diaka', 'Mona diaka'],
    'less': ['Voir moins', 'Kokita', 'Punguza', 'Mona moke', 'Mona moke'],
    'photos': ['Photos', 'Bilili', 'Picha', 'Bifanishu', 'Bifanisu'],
    'read': ['Lire l\'article', 'Tanga', 'Soma makala', 'Tanga', 'Tanga'],
    'source': ['Source officielle', 'Mokanda ya leta', 'Chanzo rasmi', 'Mukanda wa leta', 'Mukanda wa leta'],
    'all': ['Tout voir', 'Nyonso', 'Yote', 'Yonso', 'Yonso'],
  };
  static String t(String key, NationalLanguage lang) => _d[key]?[lang.index] ?? key;
  static String plain(String key, NationalLanguage lang) =>
      t(key, lang).replaceFirst(RegExp(r'^\S+\s'), '');
}

/// Sur-titres institutionnels (français, langue administrative).
const Map<String, String> _kickers = {
  'news': 'COMMUNICATION OFFICIELLE',
  'projects': 'PROGRAMME D\'INVESTISSEMENT',
  'services': 'ADMINISTRATION PUBLIQUE',
  'citizen': 'PARTICIPATION CITOYENNE',
  'budget': 'FINANCES PUBLIQUES',
  'docs': 'JOURNAL OFFICIEL',
  'media': 'MÉDIATHÈQUE',
  'hymn': 'SYMBOLES OFFICIELS',
  'map': 'GÉOGRAPHIE',
  'gallery': 'PHOTHÈQUE',
  'authorities': 'GOUVERNEMENT PROVINCIAL',
  'cities': 'COMMUNES & VILLES',
  'tourism': 'PATRIMOINE & SITES',
  'economy': 'POTENTIEL ÉCONOMIQUE',
  'culture': 'CULTURE & TRADITIONS',
  'quiz': 'ÉDUCATION CIVIQUE',
  'emergency': 'PROTECTION CIVILE',
  'demo': 'STATISTIQUES',
  'achievements': 'BILAN OFFICIEL',
  'divisions': 'DÉCOUPAGE TERRITORIAL',
};

// ════════════════════════════════════════════════════════════════════════
// 2. ACCESSIBILITÉ
// ════════════════════════════════════════════════════════════════════════
class AccessibilitySettings {
  final double textScale;
  const AccessibilitySettings({this.textScale = 1.0});
  AccessibilitySettings copyWith({double? textScale}) =>
      AccessibilitySettings(textScale: textScale ?? this.textScale);
}

final accessibilityProvider =
    StateProvider<AccessibilitySettings>((_) => const AccessibilitySettings());

// ════════════════════════════════════════════════════════════════════════
// 3. PROVIDERS SUPABASE
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
  } catch (e) {
    return null;
  }
});
final _famousProv = FutureProvider.family<List<Map<String, dynamic>>, String>((r, id) async =>
    await _safeRows(() => _db.from('province_famous_people').select().eq('province_id', id).eq('is_active', true).order('name').limit(20)));
final _gastroProv = FutureProvider.family<List<Map<String, dynamic>>, String>((r, id) async =>
    await _safeRows(() => _db.from('province_gastronomy').select().eq('province_id', id).eq('is_active', true).order('name').limit(20)));
final _proverbsProv = FutureProvider.family<List<Map<String, dynamic>>, String>((r, id) async =>
    await _safeRows(() => _db.from('province_proverbs').select().eq('province_id', id).eq('is_active', true).order('created_at', ascending: false).limit(20)));
final _quizProv = FutureProvider.family<List<Map<String, dynamic>>, String>((r, id) async =>
    await _safeRows(() => _db.from('province_quiz_questions').select().eq('province_id', id).eq('is_active', true).order('order_index').limit(10)));
final _demoProv = FutureProvider.family<List<Map<String, dynamic>>, String>((r, id) async =>
    await _safeRows(() => _db.from('province_demographics').select().eq('province_id', id).order('year')));

final favoriteProvincesProvider =
    StateNotifierProvider<FavoriteProvincesNotifier, Set<String>>((ref) => FavoriteProvincesNotifier());

class FavoriteProvincesNotifier extends StateNotifier<Set<String>> {
  FavoriteProvincesNotifier() : super({}) {
    _load();
  }
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    state = (prefs.getStringList('favorite_provinces') ?? []).toSet();
  }

  Future<void> toggle(String id) async {
    final s = Set<String>.from(state);
    if (s.contains(id)) {
      s.remove(id);
    } else {
      s.add(id);
    }
    state = s;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorite_provinces', s.toList());
  }
}

final provinceSearchDebouncedProvider =
    StateNotifierProvider.family<_SearchDebounced, List<Map<String, dynamic>>, String>(
        (r, id) => _SearchDebounced(id));

class _SearchDebounced extends StateNotifier<List<Map<String, dynamic>>> {
  final String _id;
  Timer? _t;
  _SearchDebounced(this._id) : super([]);

  void search(String raw) {
    _t?.cancel();
    final q = raw.replaceAll(RegExp(r'[%,()*]'), ' ').trim();
    if (q.isEmpty) {
      state = [];
      return;
    }
    _t = Timer(const Duration(milliseconds: 400), () async {
      final results = <Map<String, dynamic>>[];
      try {
        for (final t in ['province_news', 'province_projects', 'province_services']) {
          final rows = await _db
              .from(t)
              .select()
              .eq('province_id', _id)
              .or('title.ilike.%$q%,name.ilike.%$q%,summary.ilike.%$q%,description.ilike.%$q%')
              .limit(5);
          for (final r in rows.whereType<Map>()) {
            results.add({...Map<String, dynamic>.from(r), '_source': t});
          }
        }
        final cities =
            await _db.from('cities').select().eq('province_id', _id).ilike('name', '%$q%').limit(5);
        for (final r in cities.whereType<Map>()) {
          results.add({...Map<String, dynamic>.from(r), '_source': 'city'});
        }
      } catch (e) {
        debugPrint('[search] $e');
      }
      if (mounted) state = results;
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }
}

// ════════════════════════════════════════════════════════════════════════
// 4. SYSTÈME DE DESIGN INSTITUTIONNEL
// ════════════════════════════════════════════════════════════════════════
class Inst {
  static const navy = Color(0xFF12365C);
  static const navyDeep = Color(0xFF0B2440);
  static const blue = Color(0xFF1F4E79);
  static const gold = Color(0xFFC9A227);
  static const goldDeep = Color(0xFF9C7B14);
  static const ivory = Color(0xFFF5F3EE);
  static const paper = Color(0xFFFFFFFF);
  static const line = Color(0xFFE3DED2);
  static const ink = Color(0xFF152A3E);
  static const muted = Color(0xFF64748B);
  static const danger = Color(0xFFB3261E);
  static const green = Color(0xFF2E7D32);

  static const TextStyle kicker = TextStyle(
      fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 2.0, color: goldDeep);
  static const TextStyle h1 = TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: ink, height: 1.25);
  static const TextStyle h2 = TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: ink, height: 1.2);
  static const TextStyle h3 = TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ink);
  static const TextStyle body = TextStyle(fontSize: 13, height: 1.6, color: ink);
  static const TextStyle bodyS = TextStyle(fontSize: 12, height: 1.55, color: muted);
  static const TextStyle micro = TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: muted);
  static const TextStyle label = TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ink);
}

/// Carte institutionnelle : papier blanc, filet sable, ombre discrète.
class ICard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final double? radius;
  const ICard({super.key, required this.child, this.onTap, this.padding, this.radius});

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius ?? 12);
    return Container(
      decoration: BoxDecoration(
        color: Inst.paper,
        borderRadius: r,
        border: Border.all(color: Inst.line),
        boxShadow: const [
          BoxShadow(color: Color(0x0D12365C), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: r,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding ?? const EdgeInsets.all(14), child: child),
        ),
      ),
    );
  }
}

// Compatibilité avec les anciens imports éventuels.
typedef GlassCard = ICard;

/// Texte long replié avec « Voir plus / Voir moins ».
class ExpandableText extends StatefulWidget {
  final String text;
  final int maxLines;
  final TextStyle? style;
  final TextAlign? textAlign;
  final String? moreLabel;
  final String? lessLabel;
  const ExpandableText(
    this.text, {
    super.key,
    this.maxLines = 3,
    this.style,
    this.textAlign,
    this.moreLabel,
    this.lessLabel,
  });

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _exp = false;
  @override
  Widget build(BuildContext context) {
    final needMore = widget.text.length > widget.maxLines * 90;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: _exp ? null : widget.maxLines,
          overflow: _exp ? TextOverflow.visible : TextOverflow.ellipsis,
          style: widget.style ?? Inst.body,
          textAlign: widget.textAlign,
        ),
        if (needMore)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _exp = !_exp),
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _exp ? (widget.lessLabel ?? 'Voir moins') : (widget.moreLabel ?? 'Voir plus'),
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800, color: Inst.goldDeep, letterSpacing: 0.4),
                  ),
                  Icon(
                    _exp ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: Inst.goldDeep,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? kicker;
  final int? count;
  final VoidCallback? onViewAll;
  final String? viewAllLabel;
  const SectionHeader({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.kicker,
    this.count,
    this.onViewAll,
    this.viewAllLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(width: 3, height: 36, color: Inst.gold),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (kicker != null) Text(kicker!, style: Inst.kicker),
                if (kicker != null) const SizedBox(height: 2),
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Inst.h2),
              ],
            ),
          ),
          if (count != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Inst.line),
              ),
              child: Text('$count', style: Inst.label.copyWith(color: color)),
            ),
          if (onViewAll != null)
            GestureDetector(
              onTap: onViewAll,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      viewAllLabel ?? 'Tout voir',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Inst.goldDeep),
                    ),
                    const Icon(Icons.arrow_forward_rounded, size: 12, color: Inst.goldDeep),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        physics: const BouncingScrollPhysics(),
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => SizedBox(width: itemWidth, child: children[i]),
      ),
    );
  }
}

class _SectionSkeleton extends StatelessWidget {
  final double height;
  const _SectionSkeleton({this.height = 120});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Inst.ivory,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Inst.line),
        ),
      ),
    );
  }
}

Widget _asyncList(
  AsyncValue<List<Map<String, dynamic>>> v,
  Widget Function(List<Map<String, dynamic>>) builder, {
  double skeleton = 120,
}) {
  return v.when(
    loading: () => _SectionSkeleton(height: skeleton),
    error: (_, __) => const SizedBox.shrink(),
    data: (items) => items.isEmpty ? const SizedBox.shrink() : builder(items),
  );
}

String fmtNum(num n) => n
    .toStringAsFixed(0)
    .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

/// Montant lisible : « 12 500 000 USD », « — » si nul/absent.
String _money(dynamic v) {
  if (v == null) return '—';
  num? n;
  if (v is num) {
    n = v;
  } else {
    n = num.tryParse(v.toString().replaceAll(RegExp(r'[^\d.]'), ''));
  }
  if (n == null) return v.toString();
  if (n == 0) return '—';
  return '${fmtNum(n)} USD';
}

/// Extrait TOUTES les photos d'un élément (liste ou champs uniques).
List<String> _photosOf(Map<String, dynamic> m) {
  final out = <String>[];
  void add(dynamic v) {
    if (v is String) {
      if (v.trim().isNotEmpty) out.add(v.trim());
    } else if (v is Map) {
      final u = v['url'] ?? v['image_url'] ?? v['photo_url'] ?? v['thumbnail_url'];
      if (u is String && u.trim().isNotEmpty) out.add(u.trim());
    }
  }

  for (final k in ['photos', 'images', 'media', 'gallery', 'image_urls', 'pictures']) {
    final v = m[k];
    if (v is List) v.forEach(add);
  }
  for (final k in ['image_url', 'photo_url', 'thumbnail_url', 'cover_url', 'image']) {
    add(m[k]);
  }
  return out.toSet().toList();
}

Widget _img(String url, {double? h, double? w, BoxFit fit = BoxFit.cover, double radius = 0}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: CachedNetworkImage(
      imageUrl: url,
      height: h,
      width: w,
      fit: fit,
      placeholder: (_, __) => Container(height: h, width: w, color: Inst.ivory),
      errorWidget: (_, __, ___) => Container(
        height: h,
        width: w,
        color: Inst.ivory,
        child: const Icon(Icons.image_outlined, color: Inst.muted),
      ),
    ),
  );
}

/// Bande horizontale affichant TOUTES les photos d'un élément.
Widget _photoStrip(List<String> photos, {double height = 110, double radius = 12, bool top = true}) {
  if (photos.isEmpty) {
    return Container(
      height: height,
      color: Inst.ivory,
      child: Center(child: Icon(Icons.image_outlined, color: Inst.muted.withOpacity(0.45), size: 26)),
    );
  }
  return ClipRRect(
    borderRadius: BorderRadius.vertical(
      top: Radius.circular(top ? radius : 0),
      bottom: Radius.circular(top ? 0 : radius),
    ),
    child: SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: photos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) => _img(photos[i], h: height, w: 150),
      ),
    ),
  );
}

/// Grille complète des photos (fiche détaillée).
Widget _photoGrid(List<String> photos) {
  return GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.15,
    ),
    itemCount: photos.length,
    itemBuilder: (_, i) => _img(photos[i], radius: 10),
  );
}

Widget _blockLabel(String text) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(text.toUpperCase(), style: Inst.kicker),
    );

Future<void> _launch(String url) async {
  var u = url.trim();
  if (u.isEmpty) return;
  if (!u.startsWith('http://') && !u.startsWith('https://')) u = 'https://$u';
  final uri = Uri.tryParse(u);
  if (uri == null || !uri.hasAuthority) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('[launch] $e');
  }
}

/// Fiche détaillée institutionnelle (bottom sheet).
void showGlassSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  String? imageUrl,
  IconData? icon,
  Color color = Inst.blue,
  required List<Widget> children,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        color: Inst.paper,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 44,
              height: 4,
              decoration: BoxDecoration(color: Inst.line, borderRadius: BorderRadius.circular(4)),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imageUrl != null && imageUrl.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          imageUrl,
                          height: 190,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(height: 110, color: Inst.ivory),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ] else if (icon != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: color.withOpacity(0.25)),
                        ),
                        child: Icon(icon, color: color, size: 32),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Text(title, style: Inst.h2),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ExpandableText(subtitle, maxLines: 3, style: Inst.bodyS),
                    ],
                    Container(height: 1, color: Inst.gold.withOpacity(0.4), margin: const EdgeInsets.symmetric(vertical: 14)),
                    ...children,
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget sheetRow(IconData icon, String label, String value, {Color color = Inst.blue}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Text('$label : ', style: Inst.bodyS),
        Expanded(child: Text(value, style: Inst.bodyS.copyWith(color: Inst.ink, fontWeight: FontWeight.w800))),
      ],
    ),
  );
}

Widget _pill(String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withOpacity(0.35)),
    ),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.8),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════
// 5. BANDE RACCOURCIS ÉPINGLÉE
// ════════════════════════════════════════════════════════════════════════
class _Shortcut {
  final String id;
  final String label;
  final IconData icon;
  const _Shortcut(this.id, this.label, this.icon);
}

List<_Shortcut> _shortcuts(NationalLanguage lang) => [
      _Shortcut('actu', _Tr.plain('news', lang), Icons.newspaper_rounded),
      _Shortcut('projets', _Tr.plain('projects', lang), Icons.construction_rounded),
      _Shortcut('services', _Tr.plain('services', lang), Icons.badge_rounded),
      _Shortcut('citoyen', _Tr.plain('citizen', lang), Icons.how_to_vote_rounded),
      _Shortcut('budget', _Tr.plain('budget', lang), Icons.account_balance_wallet_rounded),
      _Shortcut('docs', _Tr.plain('docs', lang), Icons.description_rounded),
      _Shortcut('media', _Tr.plain('media', lang), Icons.play_circle_rounded),
      _Shortcut('hymn', _Tr.plain('hymn', lang), Icons.music_note_rounded),
      _Shortcut('carte', _Tr.plain('map', lang), Icons.map_rounded),
      _Shortcut('galerie', _Tr.plain('gallery', lang), Icons.photo_library_rounded),
      _Shortcut('autorites', _Tr.plain('authorities', lang), Icons.account_balance_rounded),
      _Shortcut('villes', _Tr.plain('cities', lang), Icons.location_city_rounded),
      _Shortcut('tourisme', _Tr.plain('tourism', lang), Icons.landscape_rounded),
      _Shortcut('economie', _Tr.plain('economy', lang), Icons.storefront_rounded),
      _Shortcut('culture', _Tr.plain('culture', lang), Icons.theater_comedy_rounded),
      _Shortcut('quiz', _Tr.plain('quiz', lang), Icons.quiz_rounded),
      _Shortcut('urgences', _Tr.plain('emergency', lang), Icons.emergency_rounded),
    ];

class _ShortcutBar extends ConsumerWidget {
  final ValueChanged<String> onTap;
  final String active;
  const _ShortcutBar({required this.onTap, required this.active});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final items = _shortcuts(lang);
    return Container(
      width: double.infinity,
      color: Inst.navyDeep,
      child: SizedBox(
        height: 56,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final s = items[i];
            final isActive = s.id == active;
            return GestureDetector(
              onTap: () => onTap(s.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? Inst.gold : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isActive ? Inst.gold : Colors.white.withOpacity(0.28)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(s.icon, size: 14, color: isActive ? Inst.navyDeep : Colors.white70),
                    const SizedBox(width: 6),
                    Text(
                      s.label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: isActive ? Inst.navyDeep : Colors.white,
                      ),
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

class _BarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final int version;
  _BarDelegate({required this.child, required this.version});
  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      SizedBox.expand(child: child);
  @override
  bool shouldRebuild(covariant _BarDelegate old) => old.version != version;
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
  String _active = 'actu';
  int _barVersion = 0;

  static const _ids = [
    'actu', 'projets', 'services', 'citoyen', 'budget', 'docs', 'media', 'hymn', 'carte',
    'galerie', 'autorites', 'villes', 'tourisme', 'economie', 'culture', 'quiz', 'urgences',
  ];
  late final Map<String, GlobalKey> _keys = {for (final id in _ids) id: GlobalKey()};

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final s = _scroll.offset > 400;
      if (s != _showTop) setState(() => _showTop = s);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _goTo(String id) {
    final ctx = _keys[id]?.currentContext;
    setState(() {
      _active = id;
      _barVersion++;
    });
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
        alignment: 0.10,
      );
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
        backgroundColor: Inst.ivory,
        body: Stack(
          children: [
            async.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Inst.gold)),
              error: (_, __) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: ICard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 40, color: Inst.danger),
                        const SizedBox(height: 12),
                        Text('Erreur de chargement', style: Inst.bodyS),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () =>
                              ref.invalidate(provinceWithAllRelationsProvider(widget.provinceId)),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: Text(l10n.t('common_retry')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Inst.navy,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              data: (p) => RefreshIndicator(
                color: Inst.gold,
                backgroundColor: Inst.navyDeep,
                onRefresh: () async {
                  ref.invalidate(provinceWithAllRelationsProvider(widget.provinceId));
                },
                child: CustomScrollView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  slivers: [
                    _Header(
                      province: p,
                      onShare: () async {
                        await Share.share('🏛️ ${p.name} — RDC\n📍 ${p.capital}\nVia THIX ID');
                        HapticFeedback.lightImpact();
                      },
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _BarDelegate(
                        version: _barVersion + lang.index * 100,
                        child: _ShortcutBar(onTap: _goTo, active: _active),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          _Masthead(province: p),
                          _TopActions(),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    SliverToBoxAdapter(key: _keys['actu'], child: _NewsSection(id: widget.provinceId, lang: lang, provinceName: p.name)),
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
                    SliverToBoxAdapter(
                      key: _keys['villes'],
                      child: Column(
                        children: [
                          _CitiesSection(province: p, lang: lang),
                          _DivisionsSection(province: p, lang: lang),
                          if (p.achievements.isNotEmpty)
                            _AchievementsSection(province: p, lang: lang),
                        ],
                      ),
                    ),
                    SliverToBoxAdapter(key: _keys['tourisme'], child: _TourismSection(province: p, lang: lang)),
                    SliverToBoxAdapter(key: _keys['economie'], child: _EconomySection(province: p, lang: lang)),
                    SliverToBoxAdapter(key: _keys['culture'], child: _CultureSection(province: p, id: widget.provinceId, lang: lang)),
                    SliverToBoxAdapter(key: _keys['quiz'], child: _QuizSection(id: widget.provinceId, name: p.name, lang: lang)),
                    SliverToBoxAdapter(key: _keys['urgences'], child: _EmergencySection(province: p, lang: lang)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 90),
                        child: _Footer(province: p),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_showTop)
              Positioned(
                right: 20,
                bottom: 30,
                child: GestureDetector(
                  onTap: () => _scroll.animateTo(
                    0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                  ),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Inst.navy,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Inst.gold.withOpacity(0.6)),
                      boxShadow: const [BoxShadow(color: Color(0x330B2440), blurRadius: 10, offset: Offset(0, 4))],
                    ),
                    child: const Icon(Icons.arrow_upward_rounded, color: Inst.gold, size: 20),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// HEADER + MASTHEAD
// ════════════════════════════════════════════════════════════════════════
Widget _sqBtn(IconData icon, VoidCallback onTap, {Color color = Colors.white}) {
  return Padding(
    padding: const EdgeInsets.only(right: 6),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 18),
        onPressed: onTap,
        padding: const EdgeInsets.all(9),
        constraints: const BoxConstraints(),
      ),
    ),
  );
}

class _Header extends ConsumerWidget {
  final Province province;
  final VoidCallback onShare;
  const _Header({required this.province, required this.onShare});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(favoriteProvincesProvider).contains(province.id);
    final cover = province.coverImageUrl ?? '';
    return SliverAppBar(
      expandedHeight: 230,
      pinned: true,
      backgroundColor: Inst.navyDeep,
      elevation: 0,
      leadingWidth: 48,
      shape: const Border(bottom: BorderSide(color: Inst.gold, width: 2)),
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: _sqBtn(Icons.arrow_back_rounded, () => Navigator.pop(context)),
      ),
      title: Text(
        province.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.6),
      ),
      actions: [
        _sqBtn(Icons.search_rounded, () => _openSearch(context, province.id)),
        _sqBtn(Icons.share_rounded, onShare),
        _sqBtn(
          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          () {
            ref.read(favoriteProvincesProvider.notifier).toggle(province.id);
            HapticFeedback.lightImpact();
          },
          color: isFav ? const Color(0xFFE57373) : Colors.white,
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            cover.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: cover,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(color: Inst.navyDeep),
                  )
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Inst.navyDeep, Inst.blue],
                      ),
                    ),
                  ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Inst.navyDeep.withOpacity(0.25), Inst.navyDeep.withOpacity(0.88)],
                  stops: const [0.25, 1],
                ),
              ),
            ),
            Positioned(
              left: 20,
              bottom: 14,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: Inst.gold, borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      province.code,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Inst.navyDeep, letterSpacing: 1.2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.location_on_rounded, size: 13, color: Colors.white70),
                  const SizedBox(width: 3),
                  Text(
                    province.capital,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white),
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

class _Masthead extends StatelessWidget {
  final Province province;
  const _Masthead({required this.province});

  Widget _vDiv() => Container(width: 1, height: 36, color: Inst.line);

  Widget _statBox(String label, String value) => Expanded(
        child: Column(
          children: [
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: Inst.h3.copyWith(fontSize: 13)),
            const SizedBox(height: 3),
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Inst.micro.copyWith(fontSize: 8, letterSpacing: 1.2),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = province;
    final hasCoat = (p.coatOfArmsUrl ?? '').isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: ICard(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Inst.ivory,
                    border: Border.all(color: Inst.gold, width: 2),
                  ),
                  child: ClipOval(
                    child: hasCoat
                        ? CachedNetworkImage(
                            imageUrl: p.coatOfArmsUrl!,
                            fit: BoxFit.contain,
                            errorWidget: (_, __, ___) => const Icon(Icons.shield_rounded, color: Inst.blue, size: 28),
                          )
                        : const Icon(Icons.shield_rounded, color: Inst.blue, size: 28),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('RÉPUBLIQUE DÉMOCRATIQUE DU CONGO', style: Inst.kicker),
                      const SizedBox(height: 4),
                      Text(p.name, style: Inst.h2),
                      if ((p.motto ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '« ${p.motto} »',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Inst.bodyS.copyWith(fontStyle: FontStyle.italic),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _pill(p.region.toUpperCase(), Inst.blue),
              ],
            ),
            Container(height: 1, margin: const EdgeInsets.symmetric(vertical: 14), color: Inst.gold.withOpacity(0.4)),
            Row(
              children: [
                _statBox('Capitale', p.capital),
                _vDiv(),
                _statBox('Population', p.population != null ? fmtNum(p.population!) : '—'),
                _vDiv(),
                _statBox('Superficie', p.area != null ? '${fmtNum(p.area!)} km²' : '—'),
                if (p.territoriesCount != null) ...[
                  _vDiv(),
                  _statBox('Territoires', '${p.territoriesCount}'),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TopActions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: ICard(
              radius: 10,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              onTap: () => _langSheet(context, ref),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(lang.flag, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(lang.name, style: Inst.label),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Inst.muted),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          ICard(
            radius: 10,
            padding: const EdgeInsets.all(10),
            onTap: () => _a11ySheet(context),
            child: const Icon(Icons.accessibility_new_rounded, color: Inst.blue, size: 18),
          ),
        ],
      ),
    );
  }
}

void _langSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        color: Inst.paper,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 44, height: 4, decoration: BoxDecoration(color: Inst.line, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 18),
            const Text('LANGUE NATIONALE', style: Inst.kicker),
            const SizedBox(height: 6),
            Text('Choisir la langue', style: Inst.h2),
            const SizedBox(height: 16),
            ...NationalLanguage.values.map((l) {
              final active = ref.read(languageProvider) == l;
              return InkWell(
                onTap: () {
                  ref.read(languageProvider.notifier).state = l;
                  Navigator.pop(context);
                  HapticFeedback.selectionClick();
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: active ? Inst.navy.withOpacity(0.06) : Inst.ivory,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: active ? Inst.gold : Inst.line, width: active ? 2 : 1),
                  ),
                  child: Row(
                    children: [
                      Text(l.flag, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 14),
                      Expanded(child: Text(l.name, style: Inst.h3)),
                      if (active) const Icon(Icons.check_circle_rounded, color: Inst.goldDeep, size: 20),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    ),
  );
}

void _a11ySheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => Consumer(
      builder: (context, ref, _) {
        final s = ref.watch(accessibilityProvider);
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Container(
            color: Inst.paper,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 44, height: 4, decoration: BoxDecoration(color: Inst.line, borderRadius: BorderRadius.circular(4))),
                ),
                const SizedBox(height: 18),
                const Text('ACCESSIBILITÉ', style: Inst.kicker),
                const SizedBox(height: 6),
                Text('Taille du texte', style: Inst.h2),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('A', style: Inst.bodyS),
                    Expanded(
                      child: Slider(
                        value: s.textScale,
                        min: 0.8,
                        max: 1.5,
                        divisions: 7,
                        activeColor: Inst.gold,
                        inactiveColor: Inst.navy.withOpacity(0.15),
                        onChanged: (v) =>
                            ref.read(accessibilityProvider.notifier).state = s.copyWith(textScale: v),
                      ),
                    ),
                    Text('A', style: Inst.h2),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

void _openSearch(BuildContext context, String provinceId) {
  showGlassSheet(
    context,
    title: 'Rechercher',
    icon: Icons.search_rounded,
    children: [
      Consumer(
        builder: (context, ref, _) {
          final notifier = ref.read(provinceSearchDebouncedProvider(provinceId).notifier);
          final results = ref.watch(provinceSearchDebouncedProvider(provinceId));
          return Column(
            children: [
              TextField(
                autofocus: true,
                onChanged: notifier.search,
                decoration: InputDecoration(
                  hintText: 'Ville, projet, actualité…',
                  prefixIcon: const Icon(Icons.search_rounded, color: Inst.blue),
                  filled: true,
                  fillColor: Inst.ivory,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Inst.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Inst.gold, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (results.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('Commencez à taper…', style: Inst.bodyS),
                )
              else
                ...results.map((r) {
                  final source = r['_source']?.toString() ?? '';
                  final label = (r['name'] ?? r['title'] ?? '').toString();
                  return InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Inst.ivory,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Inst.line),
                      ),
                      child: Row(
                        children: [
                          _pill(source.replaceAll('province_', '').toUpperCase(), Inst.blue),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Inst.label),
                          ),
                          const Icon(Icons.chevron_right_rounded, size: 18, color: Inst.muted),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    ],
  );
}

// ════════════════════════════════════════════════════════════════════════
// ACTUALITÉS — cliquables → page article
// ════════════════════════════════════════════════════════════════════════
String _articleBody(Map<String, dynamic> m) {
  for (final k in ['content', 'body', 'article', 'full_text', 'text', 'description', 'summary']) {
    final v = m[k];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return '';
}

class _ArticlePage extends StatelessWidget {
  final Map<String, dynamic> item;
  final String provinceName;
  const _ArticlePage({required this.item, this.provinceName = ''});

  @override
  Widget build(BuildContext context) {
    final img = (item['image_url'] ?? '').toString();
    final category = (item['category'] ?? 'INFO').toString();
    final isAlert = item['is_alert'] == true;
    final date = item['published_at']?.toString().split('T').first ?? '';
    final url = item['url']?.toString() ?? '';
    final body = _articleBody(item);
    return Scaffold(
      backgroundColor: Inst.ivory,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: Inst.navyDeep,
            elevation: 0,
            leadingWidth: 48,
            shape: const Border(bottom: BorderSide(color: Inst.gold, width: 2)),
            leading: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: _sqBtn(Icons.arrow_back_rounded, () => Navigator.pop(context)),
            ),
            title: Text(
              category.toUpperCase(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.6, color: Inst.gold),
            ),
            actions: [
              _sqBtn(Icons.share_rounded, () async {
                await Share.share('📰 ${item['title'] ?? ''}\n$provinceName — Via THIX ID');
              }),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  img.isNotEmpty
                      ? _img(img)
                      : Container(color: Inst.navy),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Inst.navyDeep.withOpacity(0.15), Inst.navyDeep.withOpacity(0.9)],
                        stops: const [0.3, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    bottom: 14,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: isAlert ? Inst.danger : Inst.gold,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            category.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              color: isAlert ? Colors.white : Inst.navyDeep,
                            ),
                          ),
                        ),
                        if (date.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(date, style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w700)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['title']?.toString() ?? '', style: Inst.h1),
                  Container(height: 3, width: 56, color: Inst.gold, margin: const EdgeInsets.symmetric(vertical: 14)),
                  if (isAlert) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Inst.danger.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Inst.danger.withOpacity(0.35)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.campaign_rounded, size: 16, color: Inst.danger),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Communiqué officiel — province',
                              style: Inst.bodyS.copyWith(color: Inst.danger, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (body.isNotEmpty) ExpandableText(body, maxLines: 6, style: Inst.body),
                  if (url.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _launch(url),
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('Lire la source officielle'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Inst.navy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsSection extends ConsumerWidget {
  final String id;
  final NationalLanguage lang;
  final String provinceName;
  const _NewsSection({required this.id, required this.lang, this.provinceName = ''});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _asyncList(ref.watch(_newsProv(id)), (items) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.newspaper_rounded,
            color: Inst.blue,
            kicker: _kickers['news'],
            title: _Tr.t('news', lang),
            count: items.length,
            viewAllLabel: _Tr.t('all', lang),
            onViewAll: () => showGlassSheet(
              context,
              title: _Tr.t('news', lang),
              icon: Icons.newspaper_rounded,
              children: items
                  .map((n) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ICard(
                          padding: const EdgeInsets.all(12),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => _ArticlePage(item: n, provinceName: provinceName)),
                            );
                          },
                          child: Row(
                            children: [
                              if ((n['image_url'] ?? '').toString().isNotEmpty)
                                _img(n['image_url'].toString(), h: 54, w: 54, radius: 8),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(n['title']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: Inst.label),
                                    const SizedBox(height: 3),
                                    Text(n['published_at']?.toString().split('T').first ?? '', style: Inst.micro),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, size: 18, color: Inst.muted),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          HScroll(
            height: 218,
            itemWidth: 290,
            children: items.map((n) => _NewsCard(item: n, provinceName: provinceName, lang: lang)).toList(),
          ),
          const SizedBox(height: 12),
        ],
      );
    }, skeleton: 200);
  }
}

class _NewsCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String provinceName;
  final NationalLanguage lang;
  const _NewsCard({required this.item, this.provinceName = '', required this.lang});

  @override
  Widget build(BuildContext context) {
    final isAlert = item['is_alert'] == true;
    final img = (item['image_url'] ?? '').toString();
    return ICard(
      padding: EdgeInsets.zero,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _ArticlePage(item: item, provinceName: provinceName)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              img.isNotEmpty ? _img(img, h: 116, w: double.infinity) : Container(height: 116, color: Inst.ivory),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isAlert ? Inst.danger : Inst.gold,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    (item['category']?.toString() ?? 'INFO').toUpperCase(),
                    style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: isAlert ? Colors.white : Inst.navyDeep),
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
                Text(item['title']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: Inst.h3),
                const SizedBox(height: 4),
                Text(item['summary']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: Inst.bodyS),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(item['published_at']?.toString().split('T').first ?? '', style: Inst.micro),
                    const Spacer(),
                    Text(_Tr.plain('read', lang).toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1, color: Inst.goldDeep)),
                    const Icon(Icons.arrow_forward_rounded, size: 12, color: Inst.goldDeep),
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

// ════════════════════════════════════════════════════════════════════════
// PROJETS
// ════════════════════════════════════════════════════════════════════════
class _ProjectsSection extends ConsumerWidget {
  final String id;
  final NationalLanguage lang;
  const _ProjectsSection({required this.id, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _asyncList(ref.watch(_projectsProv(id)), (items) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.construction_rounded,
            color: const Color(0xFFB26A00),
            kicker: _kickers['projects'],
            title: _Tr.t('projects', lang),
            count: items.length,
          ),
          HScroll(height: 218, itemWidth: 280, children: items.map((p) => _ProjectCard(item: p)).toList()),
          const SizedBox(height: 12),
        ],
      );
    }, skeleton: 180);
  }
}

class _ProjectCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ProjectCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final raw = (item['progress'] as num?)?.toDouble() ?? 0;
    final progress = (raw > 1 ? raw / 100 : raw).clamp(0.0, 1.0);
    final pct = (progress * 100).round();
    final color = pct >= 75 ? Inst.green : pct >= 50 ? const Color(0xFFB26A00) : Inst.blue;
    final photos = _photosOf(item);
    return ICard(
      padding: const EdgeInsets.all(14),
      onTap: () => showGlassSheet(
        context,
        title: item['name']?.toString() ?? '',
        subtitle: item['description']?.toString(),
        icon: Icons.construction_rounded,
        color: color,
        children: [
          if (photos.isNotEmpty) ...[
            _blockLabel('Photos (${photos.length})'),
            _photoGrid(photos),
          ],
          const SizedBox(height: 8),
          sheetRow(Icons.payments_rounded, 'Budget', _money(item['budget'])),
          sheetRow(Icons.event_rounded, 'Échéance', item['deadline']?.toString() ?? '—'),
          sheetRow(Icons.trending_up_rounded, 'Progression', '$pct%', color: color),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 4.5,
                        backgroundColor: color.withOpacity(0.15),
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                    Text('$pct%', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: color)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _pill((item['category']?.toString() ?? 'PROJET').toUpperCase(), color)),
            ],
          ),
          const SizedBox(height: 10),
          Text(item['name']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: Inst.h3),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              item['description']?.toString() ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Inst.bodyS,
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: color.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Flexible(
                child: Text('💰 ${_money(item['budget'])}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Inst.micro),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text('📅 ${item['deadline'] ?? '—'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Inst.micro),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// SERVICES — toutes les photos affichées
// ════════════════════════════════════════════════════════════════════════
class _ServicesSection extends ConsumerWidget {
  final String id;
  final NationalLanguage lang;
  const _ServicesSection({required this.id, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _asyncList(ref.watch(_servicesProv(id)), (items) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.badge_rounded,
            color: Inst.green,
            kicker: _kickers['services'],
            title: _Tr.t('services', lang),
            count: items.length,
          ),
          HScroll(height: 246, itemWidth: 260, children: items.map((s) => _ServiceCard(item: s)).toList()),
          const SizedBox(height: 12),
        ],
      );
    }, skeleton: 200);
  }
}

class _ServiceCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ServiceCard({required this.item});

  @override
  Widget build(BuildContext context) {
    const colors = [Inst.blue, Inst.green, const Color(0xFFB26A00), const Color(0xFF6A1B9A), Inst.danger];
    final color = colors[(item['category']?.toString().hashCode ?? 0).abs() % colors.length];
    final photos = _photosOf(item);
    return ICard(
      padding: EdgeInsets.zero,
      onTap: () => showGlassSheet(
        context,
        title: item['name']?.toString() ?? '',
        subtitle: item['description']?.toString(),
        icon: Icons.badge_rounded,
        color: color,
        children: [
          if (photos.isNotEmpty) ...[
            _blockLabel('${_Tr.t('photos', NationalLanguage.french)} (${photos.length})'),
            _photoGrid(photos),
            const SizedBox(height: 6),
          ],
          sheetRow(Icons.category_rounded, 'Catégorie', item['category']?.toString() ?? '—'),
          sheetRow(Icons.access_time_rounded, 'Horaires', item['hours']?.toString() ?? '—'),
          sheetRow(Icons.location_on_rounded, 'Adresse', item['address']?.toString() ?? '—'),
          if ((item['phone'] ?? '').toString().isNotEmpty)
            sheetRow(Icons.phone_rounded, 'Téléphone', item['phone'].toString()),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              _photoStrip(photos, height: 118, top: true),
              if (photos.length > 1)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      '${photos.length} photos',
                      style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Colors.white),
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
                  (item['category']?.toString() ?? '').toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: color),
                ),
                const SizedBox(height: 4),
                Text(item['name']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: Inst.h3),
                const Spacer(),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 11, color: Inst.muted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item['hours']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Inst.micro,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text(
                      'FICHE DÉTAILLÉE',
                      style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 1, color: Inst.goldDeep),
                    ),
                    const Icon(Icons.arrow_forward_rounded, size: 11, color: Inst.goldDeep),
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

// ════════════════════════════════════════════════════════════════════════
// ENGAGEMENT CITOYEN
// ════════════════════════════════════════════════════════════════════════
class _EngagementSection extends ConsumerWidget {
  final String id;
  final NationalLanguage lang;
  const _EngagementSection({required this.id, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _asyncList(ref.watch(_engagementsProv(id)), (items) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.how_to_vote_rounded,
            color: const Color(0xFF6A1B9A),
            kicker: _kickers['citizen'],
            title: _Tr.t('citizen', lang),
            count: items.length,
          ),
          HScroll(height: 200, itemWidth: 270, children: items.map((e) => _EngagementCard(item: e, pid: id, ref: ref)).toList()),
          const SizedBox(height: 12),
        ],
      );
    }, skeleton: 180);
  }
}

class _EngagementCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String pid;
  final WidgetRef ref;
  const _EngagementCard({required this.item, required this.pid, required this.ref});

  Future<void> _participate() async {
    try {
      final row = await _db
          .from('province_engagements')
          .select('participants_count')
          .eq('id', item['id'])
          .maybeSingle();
      if (row != null) {
        final c = (row['participants_count'] as num? ?? 0).toInt();
        await _db.from('province_engagements').update({'participants_count': c + 1}).eq('id', item['id']);
        ref.invalidate(_engagementsProv(pid));
      }
    } catch (e) {
      debugPrint('[eng] $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = item['type']?.toString() ?? 'SONDAGE';
    final lower = type.toLowerCase();
    final color = lower == 'vote' ? Inst.green : lower == 'pétition' ? const Color(0xFFB26A00) : const Color(0xFF6A1B9A);
    final participants = (item['participants_count'] as num?)?.toInt() ?? 0;
    return ICard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pill(type.toUpperCase(), color),
          const SizedBox(height: 8),
          Text(item['title']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: Inst.h3),
          const SizedBox(height: 4),
          Expanded(
            child: Text(item['description']?.toString() ?? '', maxLines: 3, overflow: TextOverflow.ellipsis, style: Inst.bodyS),
          ),
          Row(
            children: [
              Icon(Icons.people_rounded, size: 13, color: color),
              const SizedBox(width: 4),
              Text(fmtNum(participants), style: Inst.label.copyWith(color: color)),
              const Spacer(),
              GestureDetector(
                onTap: _participate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                  child: const Text('Participer', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// BUDGET
// ════════════════════════════════════════════════════════════════════════
class _BudgetSection extends ConsumerWidget {
  final String id;
  final NationalLanguage lang;
  const _BudgetSection({required this.id, required this.lang});

  static const _palette = [
    Inst.navy,
    Inst.gold,
    Inst.blue,
    Color(0xFF00695C),
    Color(0xFF8E24AA),
    Color(0xFFB3261E),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _asyncList(ref.watch(_budgetProv(id)), (items) {
      final total = items.fold<num>(0, (s, i) => s + ((i['amount'] as num?) ?? 0));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.account_balance_wallet_rounded,
            color: Inst.green,
            kicker: _kickers['budget'],
            title: _Tr.t('budget', lang),
            count: items.length,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ICard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(
                    height: 180,
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: 42,
                        sectionsSpace: 2,
                        sections: items.asMap().entries.map((e) {
                          final pct = ((e.value['percentage'] as num?)?.toDouble() ?? 0).clamp(0.0, 100.0);
                          return PieChartSectionData(
                            color: _palette[e.key % _palette.length],
                            value: pct,
                            radius: 46,
                            title: '${pct.toInt()}%',
                            titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: items.asMap().entries.map((e) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(color: _palette[e.key % _palette.length], borderRadius: BorderRadius.circular(2)),
                          ),
                          const SizedBox(width: 5),
                          Text(e.value['sector']?.toString() ?? '', style: Inst.bodyS.copyWith(color: Inst.ink, fontWeight: FontWeight.w700)),
                        ],
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Inst.navy.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Inst.navy.withOpacity(0.2)),
                    ),
                    child: Text(
                      'TOTAL : ${_money(total)}',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Inst.navy),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      );
    }, skeleton: 240);
  }
}

// ════════════════════════════════════════════════════════════════════════
// DÉMOGRAPHIE
// ════════════════════════════════════════════════════════════════════════
class _DemoSection extends ConsumerWidget {
  final String id;
  final NationalLanguage lang;
  const _DemoSection({required this.id, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(_demoProv(id)).when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (items) {
            if (items.length < 2) return const SizedBox.shrink();
            final maxY = items.fold<double>(0, (m, i) {
                  final v = (i['population'] as num?)?.toDouble() ?? 0;
                  return v > m ? v : m;
                }) *
                1.15;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(icon: Icons.analytics_rounded, color: Inst.blue, kicker: _kickers['demo'], title: _Tr.t('demo', lang)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ICard(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      height: 160,
                      child: BarChart(
                        BarChartData(
                          maxY: maxY,
                          alignment: BarChartAlignment.spaceAround,
                          barTouchData: BarTouchData(enabled: false),
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (v, _) => Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    v.toInt() < items.length ? (items[v.toInt()]['year']?.toString() ?? '') : '',
                                    style: Inst.micro,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          barGroups: items.asMap().entries.map((e) {
                            return BarChartGroupData(
                              x: e.key,
                              barRods: [
                                BarChartRodData(
                                  toY: (e.value['population'] as num?)?.toDouble() ?? 0,
                                  width: 26,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                  gradient: const LinearGradient(
                                    colors: [Inst.navy, Inst.blue],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            );
          },
        );
  }
}

// ════════════════════════════════════════════════════════════════════════
// DOCUMENTS
// ════════════════════════════════════════════════════════════════════════
class _DocumentsSection extends ConsumerWidget {
  final String id;
  final NationalLanguage lang;
  const _DocumentsSection({required this.id, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _asyncList(ref.watch(_documentsProv(id)), (items) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.description_rounded,
            color: Inst.navy,
            kicker: _kickers['docs'],
            title: _Tr.t('docs', lang),
            count: items.length,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ICard(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: items.map((d) {
                  return InkWell(
                    onTap: () {
                      final u = d['file_url']?.toString();
                      if (u != null && u.isNotEmpty) _launch(u);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: Inst.navy.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Inst.navy.withOpacity(0.18)),
                            ),
                            child: const Icon(Icons.gavel_rounded, color: Inst.navy, size: 16),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(d['title']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: Inst.label),
                                const SizedBox(height: 2),
                                Text('${d['type'] ?? ''} • ${d['published_at']?.toString().split('T').first ?? ''}', style: Inst.micro),
                              ],
                            ),
                          ),
                          const Icon(Icons.download_rounded, size: 17, color: Inst.goldDeep),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      );
    }, skeleton: 140);
  }
}

// ════════════════════════════════════════════════════════════════════════
// MÉDIA
// ════════════════════════════════════════════════════════════════════════
class _MediaSection extends ConsumerWidget {
  final String id;
  final NationalLanguage lang;
  const _MediaSection({required this.id, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _asyncList(ref.watch(_mediaProv(id)), (items) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.play_circle_rounded,
            color: Inst.danger,
            kicker: _kickers['media'],
            title: _Tr.t('media', lang),
            count: items.length,
          ),
          HScroll(height: 196, itemWidth: 250, children: items.map((m) => _MediaCard(item: m)).toList()),
          const SizedBox(height: 12),
        ],
      );
    }, skeleton: 170);
  }
}

class _MediaCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _MediaCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final thumb = (item['thumbnail_url'] ?? '').toString();
    return ICard(
      padding: EdgeInsets.zero,
      onTap: () {
        final u = item['url']?.toString();
        if (u != null && u.isNotEmpty) _launch(u);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              thumb.isNotEmpty ? _img(thumb, h: 112, w: double.infinity) : Container(height: 112, color: Inst.ivory),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.94), shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow_rounded, color: Inst.danger, size: 24),
              ),
              if ((item['duration'] ?? '').toString().isNotEmpty)
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                    child: Text(item['duration'].toString(), style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text(item['title']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: Inst.label),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// HYMNE
// ════════════════════════════════════════════════════════════════════════
class _HymnSection extends ConsumerStatefulWidget {
  final String id;
  final String name;
  final NationalLanguage lang;
  const _HymnSection({required this.id, required this.name, required this.lang});

  @override
  ConsumerState<_HymnSection> createState() => _HymnSectionState();
}

class _HymnSectionState extends ConsumerState<_HymnSection> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _sub;
  bool _playing = false;
  bool _instrumental = false;

  @override
  void initState() {
    super.initState();
    _sub = _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle(Map<String, dynamic>? h) async {
    if (h == null) return;
    final url = (_instrumental ? h['instrumental_url'] : h['audio_url'])?.toString();
    if (url == null || url.isEmpty) return;
    try {
      if (_playing) {
        await _player.pause();
      } else {
        await _player.play(UrlSource(url));
      }
      HapticFeedback.selectionClick();
    } catch (e) {
      debugPrint('[hymn] $e');
    }
  }

  Future<void> _switchVersion(bool instrumental) async {
    if (_instrumental == instrumental) return;
    await _player.stop();
    if (mounted) setState(() => _instrumental = instrumental);
  }

  Widget _verChip(String label, bool sel, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: sel ? Inst.navy : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: sel ? Inst.navy : Inst.line),
        ),
        child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: sel ? Colors.white : Inst.muted)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ref.watch(_hymnProv(widget.id)).when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (h) {
            if (h == null) return const SizedBox.shrink();
            final lyrics = h['lyrics']?.toString() ?? '';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(icon: Icons.music_note_rounded, color: Inst.goldDeep, kicker: _kickers['hymn'], title: _Tr.t('hymn', widget.lang)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ICard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Inst.gold.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Inst.gold.withOpacity(0.35)),
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => _toggle(h),
                                child: Container(
                                  width: 46,
                                  height: 46,
                                  decoration: const BoxDecoration(color: Inst.navy, shape: BoxShape.circle),
                                  child: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Inst.gold, size: 24),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(h['title']?.toString() ?? 'Hymne provincial', style: Inst.h3),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        _verChip('Officielle', !_instrumental, () => _switchVersion(false)),
                                        const SizedBox(width: 6),
                                        _verChip('Instrumentale', _instrumental, () => _switchVersion(true)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (lyrics.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Inst.ivory, borderRadius: BorderRadius.circular(8), border: Border.all(color: Inst.line)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('PAROLES (EXTRAIT)', style: Inst.kicker),
                                const SizedBox(height: 6),
                                ExpandableText(lyrics, maxLines: 4, style: Inst.bodyS.copyWith(fontStyle: FontStyle.italic)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            );
          },
        );
  }
}

// ════════════════════════════════════════════════════════════════════════
// CARTE
// ════════════════════════════════════════════════════════════════════════
class _MapCard extends StatelessWidget {
  final Province province;
  final NationalLanguage lang;
  const _MapCard({required this.province, required this.lang});

  @override
  Widget build(BuildContext context) {
    final url = province.mapUrl;
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(icon: Icons.map_rounded, color: Inst.blue, kicker: _kickers['map'], title: _Tr.t('map', lang)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ICard(
            padding: EdgeInsets.zero,
            onTap: () => showDialog(
              context: context,
              builder: (_) => Dialog(
                backgroundColor: Colors.transparent,
                child: ICard(
                  padding: const EdgeInsets.all(8),
                  child: InteractiveViewer(minScale: 1, maxScale: 4, child: _img(url, h: 380, w: double.infinity)),
                ),
              ),
            ),
            child: Stack(
              children: [
                _img(url, h: 190, w: double.infinity, radius: 12),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// GALERIE
// ════════════════════════════════════════════════════════════════════════
class _GallerySection extends StatelessWidget {
  final Province province;
  final NationalLanguage lang;
  const _GallerySection({required this.province, required this.lang});

  @override
  Widget build(BuildContext context) {
    final media = province.galleryMedia;
    if (media.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.photo_library_rounded,
          color: Inst.blue,
          kicker: _kickers['gallery'],
          title: _Tr.t('gallery', lang),
          count: media.length,
          viewAllLabel: _Tr.t('all', lang),
          onViewAll: () => showGlassSheet(
            context,
            title: _Tr.t('gallery', lang),
            icon: Icons.photo_library_rounded,
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: media.length,
                itemBuilder: (_, i) => _img(media[i]['url']?.toString() ?? '', radius: 8),
              ),
            ],
          ),
        ),
        HScroll(height: 150, itemWidth: 160, children: media.map((m) => _img(m['url']?.toString() ?? '', h: 150, w: 160, radius: 10)).toList()),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// AUTORITÉS
// ════════════════════════════════════════════════════════════════════════
class _AuthoritiesSection extends StatelessWidget {
  final Province province;
  final NationalLanguage lang;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.account_balance_rounded,
          color: Inst.navy,
          kicker: _kickers['authorities'],
          title: _Tr.t('authorities', lang),
          count: executives.length + ministers.length,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ICard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (executives.isNotEmpty)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: executives.length,
                    itemBuilder: (_, i) => _ExecutiveCard(
                      role: executives[i]['role']!,
                      name: executives[i]['name']!,
                      photoUrl: executives[i]['photo'],
                    ),
                  ),
                if (ministers.isNotEmpty) ...[
                  if (executives.isNotEmpty) const SizedBox(height: 16),
                  Text('MINISTRES PROVINCIAUX (${ministers.length})', style: Inst.kicker),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: ministers.length,
                    itemBuilder: (_, i) {
                      final m = ministers[i];
                      return _MinisterCard(
                        name: m['name']?.toString() ?? '—',
                        role: m['role']?.toString() ?? 'Ministre',
                        photoUrl: (m['photoUrl'] ?? m['photo_url'] ?? '').toString(),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _ExecutiveCard extends StatelessWidget {
  final String role;
  final String name;
  final String? photoUrl;
  const _ExecutiveCard({required this.role, required this.name, this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    final isGov = role.toLowerCase().contains('gouverneur') && !role.toLowerCase().contains('vice');
    final color = isGov ? Inst.goldDeep : Inst.blue;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        showGlassSheet(
          context,
          title: name,
          subtitle: role,
          imageUrl: hasPhoto ? photoUrl : null,
          icon: Icons.person_rounded,
          color: color,
          children: [
            sheetRow(Icons.workspace_premium_rounded, 'Fonction', role, color: color),
            sheetRow(Icons.account_balance_rounded, 'Institution', 'Gouvernement provincial'),
          ],
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: Inst.ivory,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Inst.line),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 2.5)),
              child: CircleAvatar(
                radius: 32,
                backgroundColor: Colors.white,
                backgroundImage: hasPhoto ? CachedNetworkImageProvider(photoUrl!) : null,
                child: hasPhoto ? null : Icon(Icons.person_rounded, size: 30, color: Inst.muted),
              ),
            ),
            const SizedBox(height: 10),
            _pill(role.toUpperCase(), color),
            const SizedBox(height: 6),
            Text(name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: Inst.h3),
          ],
        ),
      ),
    );
  }
}

class _MinisterCard extends StatelessWidget {
  final String name;
  final String role;
  final String photoUrl;
  const _MinisterCard({required this.name, required this.role, required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl.isNotEmpty;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        showGlassSheet(
          context,
          title: name,
          subtitle: role,
          imageUrl: hasPhoto ? photoUrl : null,
          icon: Icons.person_rounded,
          children: [sheetRow(Icons.work_rounded, 'Portefeuille', role)],
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(color: Inst.ivory, borderRadius: BorderRadius.circular(10), border: Border.all(color: Inst.line)),
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white,
              backgroundImage: hasPhoto ? CachedNetworkImageProvider(photoUrl) : null,
              child: hasPhoto ? null : const Icon(Icons.person_rounded, size: 20, color: Inst.muted),
            ),
            const SizedBox(height: 6),
            Text(role, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: Inst.micro),
            const SizedBox(height: 2),
            Text(name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: Inst.label),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// VILLES / DÉCOUPAGE / RÉALISATIONS
// ════════════════════════════════════════════════════════════════════════
class _CitiesSection extends StatelessWidget {
  final Province province;
  final NationalLanguage lang;
  const _CitiesSection({required this.province, required this.lang});

  @override
  Widget build(BuildContext context) {
    if (province.cities.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.location_city_rounded,
          color: Inst.blue,
          kicker: _kickers['cities'],
          title: _Tr.t('cities', lang),
          count: province.cities.length,
        ),
        HScroll(
          height: 196,
          itemWidth: 220,
          children: province.cities.map((c) {
            final dyn = c as dynamic;
            final img = (dyn.imageUrl ?? '').toString();
            return ICard(
              padding: EdgeInsets.zero,
              onTap: () => showGlassSheet(
                context,
                title: c.name,
                subtitle: c.isCapital ? 'Chef-lieu de la province' : null,
                imageUrl: img.isNotEmpty ? img : null,
                icon: Icons.location_city_rounded,
                color: Inst.blue,
                children: [
                  if (c.population != null)
                    sheetRow(Icons.groups_rounded, 'Population', '${fmtNum(int.tryParse(c.population ?? '0') ?? 0)} hab'),
                  if ((c.mayor ?? '').isNotEmpty) sheetRow(Icons.person_rounded, 'Maire', c.mayor!),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      img.isNotEmpty
                          ? _img(img, h: 100, w: double.infinity)
                          : Container(
                              height: 100,
                              width: double.infinity,
                              color: Inst.ivory,
                              child: const Icon(Icons.location_city_rounded, color: Inst.blue, size: 30),
                            ),
                      if (c.isCapital)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(color: Inst.goldDeep, borderRadius: BorderRadius.circular(4)),
                            child: const Text('CHEF-LIEU', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.8)),
                          ),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Inst.h3),
                        if (c.population != null)
                          Text('${fmtNum(int.tryParse(c.population ?? '0') ?? 0)} hab', style: Inst.micro),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _DivisionsSection extends StatelessWidget {
  final Province province;
  final NationalLanguage lang;
  const _DivisionsSection({required this.province, required this.lang});

  @override
  Widget build(BuildContext context) {
    if (province.administrativeDivisions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.dashboard_customize_rounded,
          color: const Color(0xFF6A1B9A),
          kicker: _kickers['divisions'],
          title: _Tr.t('divisions', lang),
          count: province.administrativeDivisions.length,
        ),
        HScroll(
          height: 140,
          itemWidth: 230,
          children: province.administrativeDivisions.map((d) {
            final dyn = d as dynamic;
            return ICard(
              padding: const EdgeInsets.all(12),
              onTap: () => showGlassSheet(
                context,
                title: dyn.name?.toString() ?? '',
                icon: Icons.dashboard_customize_rounded,
                color: const Color(0xFF6A1B9A),
                children: [
                  sheetRow(Icons.category_rounded, 'Type', dyn.type?.toString() ?? '—'),
                  if ((dyn.capital ?? '').toString().isNotEmpty) sheetRow(Icons.star_rounded, 'Chef-lieu', dyn.capital.toString()),
                  if ((dyn.administrator ?? '').toString().isNotEmpty)
                    sheetRow(Icons.person_rounded, 'Administrateur', dyn.administrator.toString()),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6A1B9A).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF6A1B9A).withOpacity(0.25)),
                        ),
                        child: const Icon(Icons.dashboard_customize_rounded, color: Color(0xFF6A1B9A), size: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(dyn.name?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: Inst.label),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _pill((dyn.type?.toString() ?? '').toUpperCase(), const Color(0xFF6A1B9A)),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _AchievementsSection extends StatelessWidget {
  final Province province;
  final NationalLanguage lang;
  const _AchievementsSection({required this.province, required this.lang});

  @override
  Widget build(BuildContext context) {
    if (province.achievements.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.emoji_events_rounded,
          color: Inst.goldDeep,
          kicker: _kickers['achievements'],
          title: _Tr.t('achievements', lang),
          count: province.achievements.length,
        ),
        HScroll(
          height: 178,
          itemWidth: 250,
          children: province.achievements.map((a) {
            final title = a['title']?.toString() ?? '';
            final desc = a['description']?.toString() ?? '';
            final date = a['date']?.toString() ?? '';
            return ICard(
              padding: const EdgeInsets.all(14),
              onTap: () => showGlassSheet(
                context,
                title: title,
                subtitle: desc,
                icon: Icons.verified_rounded,
                color: Inst.goldDeep,
                children: [if (date.isNotEmpty) sheetRow(Icons.event_rounded, 'Date', date)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Inst.gold.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Inst.gold.withOpacity(0.35)),
                    ),
                    child: const Icon(Icons.verified_rounded, color: Inst.goldDeep, size: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Inst.h3),
                  const Spacer(),
                  Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: Inst.bodyS),
                  if (date.isNotEmpty) Text(date, style: Inst.micro),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// TOURISME — toutes les photos
// ════════════════════════════════════════════════════════════════════════
class _TourismSection extends StatelessWidget {
  final Province province;
  final NationalLanguage lang;
  const _TourismSection({required this.province, required this.lang});

  @override
  Widget build(BuildContext context) {
    if (province.tourismSites.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.landscape_rounded,
          color: Inst.blue,
          kicker: _kickers['tourism'],
          title: _Tr.t('tourism', lang),
          count: province.tourismSites.length,
        ),
        HScroll(
          height: 216,
          itemWidth: 240,
          children: province.tourismSites.map((s) {
            final dyn = s as dynamic;
            final mediaList = (dyn.media as List?) ?? [];
            final photos = <String>[];
            for (final m in mediaList) {
              if (m is Map) {
                final u = m['url']?.toString();
                if (u != null && u.isNotEmpty) photos.add(u);
              } else if (m is String) {
                photos.add(m);
              }
            }
            return ICard(
              padding: EdgeInsets.zero,
              onTap: () => showGlassSheet(
                context,
                title: dyn.name?.toString() ?? '',
                subtitle: dyn.description?.toString(),
                icon: Icons.landscape_rounded,
                color: Inst.blue,
                children: [
                  if (photos.isNotEmpty) ...[
                    _blockLabel('Photos (${photos.length})'),
                    _photoGrid(photos),
                  ],
                  if ((dyn.type ?? '').toString().isNotEmpty) sheetRow(Icons.category_rounded, 'Type', dyn.type.toString()),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      _photoStrip(photos, height: 112, top: true),
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(color: Inst.blue, borderRadius: BorderRadius.circular(4)),
                          child: Text(
                            (dyn.type?.toString() ?? 'SITE').toUpperCase(),
                            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.8),
                          ),
                        ),
                      ),
                      if (photos.length > 1)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                            child: Text('${photos.length} photos', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white)),
                          ),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dyn.name?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: Inst.h3),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// ÉCONOMIE
// ════════════════════════════════════════════════════════════════════════
class _EconomySection extends StatelessWidget {
  final Province province;
  final NationalLanguage lang;
  const _EconomySection({required this.province, required this.lang});

  @override
  Widget build(BuildContext context) {
    final r = province.economicResources;
    if (r.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.storefront_rounded,
          color: Inst.green,
          kicker: _kickers['economy'],
          title: _Tr.t('economy', lang),
          count: r.length,
        ),
        HScroll(
          height: 172,
          itemWidth: 250,
          children: r.map((res) {
            return ICard(
              padding: const EdgeInsets.all(12),
              onTap: () => showGlassSheet(
                context,
                title: res.name,
                subtitle: res.description,
                icon: Icons.monetization_on_rounded,
                color: Inst.green,
                children: const [],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Inst.green.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Inst.green.withOpacity(0.25)),
                        ),
                        child: const Icon(Icons.monetization_on_rounded, color: Inst.green, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(res.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Inst.label)),
                    ],
                  ),
                  const Spacer(),
                  Text(res.description ?? '', maxLines: 3, overflow: TextOverflow.ellipsis, style: Inst.micro.copyWith(height: 1.45)),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// CULTURE
// ════════════════════════════════════════════════════════════════════════
class _CultureSection extends StatelessWidget {
  final Province province;
  final String id;
  final NationalLanguage lang;
  const _CultureSection({required this.province, required this.id, required this.lang});

  Widget _infoRow(IconData icon, Color color, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: label, style: Inst.label),
                  TextSpan(text: value, style: Inst.bodyS),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _monoTile(BuildContext context, String label, String content, IconData icon) {
    return InkWell(
      onTap: () => showGlassSheet(
        context,
        title: label,
        icon: icon,
        children: [ExpandableText(content, maxLines: 200, style: Inst.body)],
      ),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Inst.ivory, borderRadius: BorderRadius.circular(8), border: Border.all(color: Inst.line)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: Inst.blue),
                const SizedBox(width: 8),
                Expanded(child: Text(label, style: Inst.label)),
                const Icon(Icons.chevron_right_rounded, size: 15, color: Inst.muted),
              ],
            ),
            const SizedBox(height: 6),
            ExpandableText(content, maxLines: 2, style: Inst.micro.copyWith(height: 1.5)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = province;
    final tribes = p.tribes;
    final hasLang = (p.languages ?? '').isNotEmpty;
    final hasDesc = (p.description ?? '').isNotEmpty;
    final hasResources = (p.resources ?? '').isNotEmpty;
    final hasTribes = tribes.isNotEmpty;
    final hasMono = (p.history ?? '').isNotEmpty ||
        (p.climate ?? '').isNotEmpty ||
        (p.infrastructure ?? '').isNotEmpty ||
        (p.education ?? '').isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.theater_comedy_rounded,
          color: Inst.goldDeep,
          kicker: _kickers['culture'],
          title: _Tr.t('culture', lang),
          count: hasTribes ? tribes.length : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ICard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasLang) _infoRow(Icons.forum_rounded, Inst.blue, 'Langues : ', p.languages!),
                if (hasResources) _infoRow(Icons.diamond_rounded, Inst.goldDeep, 'Ressources : ', p.resources!),
                if (hasDesc) ...[
                  const SizedBox(height: 6),
                  ExpandableText(p.description!, maxLines: 4, style: Inst.body),
                ],
                if (hasTribes) ...[
                  _blockLabel('Peuples & Tribus'),
                  SizedBox(
                    height: 148,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: tribes.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final t = tribes[i];
                        final name = t['name']?.toString() ?? 'Tribu';
                        final zone = t['zone']?.toString() ?? '';
                        final history = t['history']?.toString() ?? '';
                        return SizedBox(
                          width: 220,
                          child: ICard(
                            padding: const EdgeInsets.all(12),
                            radius: 10,
                            onTap: () => showGlassSheet(
                              context,
                              title: name,
                              subtitle: zone.isNotEmpty ? 'Zone : $zone' : null,
                              icon: Icons.groups_rounded,
                              children: [if (history.isNotEmpty) ExpandableText(history, maxLines: 200, style: Inst.body)],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: Inst.blue.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Inst.blue.withOpacity(0.22)),
                                      ),
                                      child: const Icon(Icons.groups_rounded, color: Inst.blue, size: 14),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Inst.label)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (zone.isNotEmpty)
                                  Text('📍 $zone', maxLines: 1, overflow: TextOverflow.ellipsis, style: Inst.micro.copyWith(color: Inst.blue)),
                                const Spacer(),
                                Text(history, maxLines: 2, overflow: TextOverflow.ellipsis, style: Inst.micro.copyWith(height: 1.45)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                if (hasMono) ...[
                  _blockLabel('Monographie'),
                  if ((p.history ?? '').isNotEmpty) _monoTile(context, 'Histoire & Origines', p.history!, Icons.menu_book_rounded),
                  if ((p.climate ?? '').isNotEmpty) _monoTile(context, 'Climat & Relief', p.climate!, Icons.wb_sunny_rounded),
                  if ((p.infrastructure ?? '').isNotEmpty) _monoTile(context, 'Infrastructures', p.infrastructure!, Icons.bolt_rounded),
                  if ((p.education ?? '').isNotEmpty) _monoTile(context, 'Éducation & Santé', p.education!, Icons.school_rounded),
                ],
                _FamousBlock(id: id),
                _GastroBlock(id: id),
                _ProverbsBlock(id: id),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _FamousBlock extends ConsumerWidget {
  final String id;
  const _FamousBlock({required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(_famousProv(id)).valueOrNull ?? const <Map<String, dynamic>>[];
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _blockLabel('Personnalités célèbres'),
        SizedBox(
          height: 186,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final f = items[i];
              final photo = (f['photo_url'] ?? '').toString();
              final achievement = (f['achievement'] ?? '').toString();
              return SizedBox(
                width: 190,
                child: ICard(
                  padding: const EdgeInsets.all(12),
                  radius: 10,
                  onTap: () => showGlassSheet(
                    context,
                    title: f['name']?.toString() ?? '',
                    subtitle: f['bio']?.toString(),
                    imageUrl: photo.isNotEmpty ? photo : null,
                    icon: Icons.emoji_events_rounded,
                    color: Inst.goldDeep,
                    children: [
                      if (achievement.isNotEmpty)
                        sheetRow(Icons.workspace_premium_rounded, 'Distinction', achievement, color: Inst.goldDeep),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Inst.gold, width: 2)),
                        child: ClipOval(
                          child: photo.isNotEmpty
                              ? CachedNetworkImage(imageUrl: photo, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.person, color: Inst.muted))
                              : const Icon(Icons.person, color: Inst.muted),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(f['name']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: Inst.label),
                      Text(f['field']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: Inst.micro.copyWith(color: Inst.goldDeep)),
                      const Spacer(),
                      if (achievement.isNotEmpty)
                        Text(achievement, maxLines: 1, overflow: TextOverflow.ellipsis, style: Inst.micro),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GastroBlock extends ConsumerWidget {
  final String id;
  const _GastroBlock({required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(_gastroProv(id)).valueOrNull ?? const <Map<String, dynamic>>[];
    if (items.isEmpty) return const SizedBox.shrink();
    const accent = Color(0xFFAD1457);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _blockLabel('Gastronomie'),
        SizedBox(
          height: 186,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final g = items[i];
              final photos = _photosOf(g);
              return SizedBox(
                width: 200,
                child: ICard(
                  padding: EdgeInsets.zero,
                  radius: 10,
                  onTap: () {
                    final ingredients = (g['ingredients'] is List)
                        ? (g['ingredients'] as List).map((e) => e.toString()).toList()
                        : (g['ingredients']?.toString() ?? '').split(',').where((e) => e.trim().isNotEmpty).toList();
                    showGlassSheet(
                      context,
                      title: g['name']?.toString() ?? '',
                      subtitle: g['description']?.toString(),
                      imageUrl: photos.isNotEmpty ? photos.first : null,
                      icon: Icons.restaurant_rounded,
                      color: accent,
                      children: [
                        if (photos.length > 1) ...[
                          _blockLabel('Photos (${photos.length})'),
                          _photoGrid(photos),
                        ],
                        if (ingredients.isNotEmpty) ...[
                          _blockLabel('Ingrédients'),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: ingredients
                                .map((ing) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(color: accent.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: accent.withOpacity(0.3))),
                                      child: Text(ing.trim(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: accent)),
                                    ))
                                .toList(),
                          ),
                        ],
                      ],
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _photoStrip(photos, height: 88, top: true),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(g['name']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: Inst.label),
                            Text(g['description']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: Inst.micro),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProverbsBlock extends ConsumerWidget {
  final String id;
  const _ProverbsBlock({required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(_proverbsProv(id)).valueOrNull ?? const <Map<String, dynamic>>[];
    if (items.isEmpty) return const SizedBox.shrink();
    const accent = Color(0xFF00695C);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _blockLabel('Proverbes & Contes'),
        SizedBox(
          height: 156,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final pr = items[i];
              final meaning = (pr['meaning'] ?? '').toString();
              return SizedBox(
                width: 240,
                child: ICard(
                  padding: const EdgeInsets.all(12),
                  radius: 10,
                  onTap: () => showGlassSheet(
                    context,
                    title: pr['text']?.toString() ?? '',
                    subtitle: pr['translation']?.toString(),
                    icon: Icons.format_quote_rounded,
                    color: accent,
                    children: [if (meaning.isNotEmpty) ExpandableText(meaning, maxLines: 200, style: Inst.body)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.format_quote_rounded, size: 15, color: accent),
                          const Spacer(),
                          _pill((pr['language']?.toString() ?? '').toUpperCase(), accent),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('"${pr['text'] ?? ''}"', maxLines: 3, overflow: TextOverflow.ellipsis, style: Inst.label.copyWith(fontStyle: FontStyle.italic)),
                      const Spacer(),
                      Text(pr['translation']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: Inst.micro),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// QUIZ
// ════════════════════════════════════════════════════════════════════════
class _QuizSection extends ConsumerStatefulWidget {
  final String id;
  final String name;
  final NationalLanguage lang;
  const _QuizSection({required this.id, required this.name, required this.lang});

  @override
  ConsumerState<_QuizSection> createState() => _QuizSectionState();
}

class _QuizSectionState extends ConsumerState<_QuizSection> {
  int _index = 0;
  int _score = 0;
  int? _selected;
  bool _done = false;

  void _answer(int choice, int correct, int total) {
    if (_selected != null) return;
    setState(() => _selected = choice);
    if (choice == correct) _score++;
    HapticFeedback.selectionClick();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _selected = null;
        _index++;
        if (_index >= total) _done = true;
      });
    });
  }

  void _reset() {
    setState(() {
      _index = 0;
      _score = 0;
      _selected = null;
      _done = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    const accent = Inst.navy;
    const green = Inst.green;
    const red = Inst.danger;
    return _asyncList(ref.watch(_quizProv(widget.id)), (questions) {
      final total = questions.length;
      final q = _index < total ? questions[_index] : null;
      final options = q == null ? <String>[] : ((q['options'] as List?) ?? []).map((e) => e.toString()).toList();
      final correct = (q?['correct_answer'] as num?)?.toInt() ?? 0;
      final good = _score >= total / 2;
      Widget body;
      if (!_done && q != null && options.isNotEmpty) {
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Question ${_index + 1}/$total', style: Inst.label.copyWith(color: accent)),
                const Spacer(),
                Text('Score : $_score', style: Inst.label.copyWith(color: green)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_index + 1) / total,
                minHeight: 5,
                backgroundColor: accent.withOpacity(0.12),
                valueColor: const AlwaysStoppedAnimation(accent),
              ),
            ),
            const SizedBox(height: 16),
            Text(q['question']?.toString() ?? '', style: Inst.h3),
            const SizedBox(height: 14),
            ...options.asMap().entries.map((e) {
              final isSel = _selected == e.key;
              final isCorrect = e.key == correct;
              final showState = _selected != null;
              Color bg = Inst.ivory;
              Color bd = Inst.line;
              if (showState && isCorrect) {
                bg = green.withOpacity(0.10);
                bd = green;
              } else if (showState && isSel && !isCorrect) {
                bg = red.withOpacity(0.08);
                bd = red;
              }
              return InkWell(
                onTap: () => _answer(e.key, correct, total),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: bd)),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(color: accent.withOpacity(0.10), borderRadius: BorderRadius.circular(6)),
                        child: Center(
                          child: Text(String.fromCharCode(65 + e.key), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: accent)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(e.value, style: Inst.label.copyWith(fontWeight: FontWeight.w700))),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      } else {
        body = Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: (good ? green : red).withOpacity(0.10),
                shape: BoxShape.circle,
                border: Border.all(color: (good ? green : red).withOpacity(0.4)),
              ),
              child: Text('$_score/$total', style: Inst.h1.copyWith(color: good ? green : red)),
            ),
            const SizedBox(height: 12),
            Text(good ? '🎉 Excellent !' : '💪 À améliorer', style: Inst.h2),
            const SizedBox(height: 6),
            Text('Vous connaissez ${good ? 'bien' : 'encore peu'} ${widget.name} !', textAlign: TextAlign.center, style: Inst.bodyS),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Rejouer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => Share.share('🎮 Quiz ${widget.name} : $_score/$total sur THIX ID !'),
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text('Partager'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    side: const BorderSide(color: accent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(icon: Icons.quiz_rounded, color: accent, kicker: _kickers['quiz'], title: _Tr.t('quiz', widget.lang), count: total),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ICard(padding: const EdgeInsets.all(18), child: body),
          ),
          const SizedBox(height: 12),
        ],
      );
    }, skeleton: 220);
  }
}

// ════════════════════════════════════════════════════════════════════════
// URGENCES
// ════════════════════════════════════════════════════════════════════════
class _EmergencySection extends StatelessWidget {
  final Province province;
  final NationalLanguage lang;
  const _EmergencySection({required this.province, required this.lang});

  @override
  Widget build(BuildContext context) {
    if (province.emergencyContacts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: Icons.emergency_rounded,
          color: Inst.danger,
          kicker: _kickers['emergency'],
          title: _Tr.t('emergency', lang),
          count: province.emergencyContacts.length,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ICard(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: province.emergencyContacts.map((c) {
                final dyn = c as dynamic;
                final service = dyn.service?.toString() ?? 'Service';
                final phone = dyn.phone?.toString() ?? '';
                final dial = phone.replaceAll(RegExp(r'[^0-9+*#]'), '');
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Inst.ivory,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Inst.danger.withOpacity(0.25)),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Inst.danger.withOpacity(0.10), shape: BoxShape.circle),
                      child: const Icon(Icons.phone_in_talk_rounded, color: Inst.danger, size: 16),
                    ),
                    title: Text(service, style: Inst.label),
                    subtitle: Text(phone, style: Inst.bodyS.copyWith(color: Inst.ink, fontWeight: FontWeight.w700)),
                    trailing: dial.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.call_rounded, color: Inst.green, size: 19),
                            onPressed: () async {
                              HapticFeedback.lightImpact();
                              try {
                                await launchUrl(Uri.parse('tel:$dial'));
                              } catch (e) {
                                debugPrint('[tel] $e');
                              }
                            },
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// PIED DE PAGE INSTITUTIONNEL
// ════════════════════════════════════════════════════════════════════════
class _Footer extends StatelessWidget {
  final Province province;
  const _Footer({required this.province});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(height: 1, color: Inst.gold.withOpacity(0.4)),
        const SizedBox(height: 14),
        const Text('RÉPUBLIQUE DÉMOCRATIQUE DU CONGO', style: Inst.kicker),
        const SizedBox(height: 4),
        Text(
          'Province du ${province.name} — Portail officiel THIX ID',
          textAlign: TextAlign.center,
          style: Inst.micro,
        ),
        if ((province.website ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          InkWell(
            onTap: () => _launch(province.website!),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: Inst.paper, borderRadius: BorderRadius.circular(8), border: Border.all(color: Inst.line)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.language_rounded, size: 14, color: Inst.blue),
                  const SizedBox(width: 6),
                  Flexible(child: Text(province.website!, maxLines: 1, overflow: TextOverflow.ellipsis, style: Inst.label.copyWith(color: Inst.blue))),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
