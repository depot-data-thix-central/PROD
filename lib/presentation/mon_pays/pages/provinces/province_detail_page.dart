// ============================================================
// FICHIER - province_detail_page.dart (EXPERT EDITION v8 - BULLETPROOF STATEFUL)
// Classement : Identité > Cartographie > Galerie > Exécutif
// > Réalisations > Villes > Découpage > Tourisme > Économie
// > Peuples/Tribus > Histoire/Climat/Infra > Urgences > Identité Visuelle
// Charte THIX ID (navy #0A1F44 / gold #E3B23C)
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/provinces_provider.dart';
import '../../models/province.dart';
import '../../models/city.dart';

// ==================== PALETTE (Charte THIX ID) ====================
const Color _navyDeep = Color(0xFF0A1F44);
const Color _navy = Color(0xFF123B7A);
const Color _gold = Color(0xFFE3B23C);
const Color _ivory = Color(0xFFF6F7FB);
const Color _hairline = Color(0xFFE7EAF3);
const Color _muted = Color(0xFF6B7690);
const Color _ink = Color(0xFF10182B);
const Color _itemBg = Color(0xFFFAFBFD);
const Color _itemBorder = Color(0xFFEDEFF5);

class ProvinceDetailPage extends ConsumerWidget {
  final String provinceId;
  const ProvinceDetailPage({required this.provinceId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provinceAsync = ref.watch(provinceWithAllRelationsProvider(provinceId));

    return Scaffold(
      backgroundColor: _ivory,
      body: provinceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _navy)),
        error: (e, _) => _ErrorView(onRetry: () => ref.invalidate(provinceWithAllRelationsProvider(provinceId))),
        data: (province) => CustomScrollView(
          slivers: [
            _ProvinceHeader(province: province),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // 1. IDENTITÉ DE LA PROVINCE
                  _ProvinceIdentityCard(province: province),
                  const SizedBox(height: 16),

                  // 2. CARTOGRAPHIE
                  if (province.mapUrl != null && province.mapUrl!.trim().isNotEmpty) ...[
                    _SectionCard(
                      icon: Icons.map_rounded, color: _navy, title: 'Cartographie',
                      children: [_MapContent(url: province.mapUrl!, provinceName: province.name)],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 3. GALERIE (AUTO-SCROLLING STATEFUL)
                  if (province.galleryMedia != null && province.galleryMedia!.isNotEmpty) ...[
                    _SectionCard(
                      icon: Icons.perm_media, color: _navy, title: 'Galerie Média Globale (Photos & Vidéos)', count: province.galleryMedia!.length,
                      children: [_GalleryBanner(media: province.galleryMedia!, provinceName: province.name)],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 4. EXÉCUTIF PROVINCIAL
                  _SectionCard(
                    icon: Icons.account_balance, color: _navy, title: 'Gouvernance & Exécutif Provincial',
                    children: [_GovernanceContent(province: province)],
                  ),
                  const SizedBox(height: 16),

                  // 5. GRANDES RÉALISATIONS & PROJETS MAJEURS
                  if (province.achievements != null && province.achievements!.isNotEmpty) ...[
                    _SectionCard(
                      icon: Icons.emoji_events, color: _navy, title: 'Réalisations & Projets Majeurs', count: province.achievements!.length,
                      children: [_AchievementsSection(achievements: province.achievements!)],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 6. VILLES PRINCIPALES
                  if (province.cities.isNotEmpty) ...[
                    _SectionCard(
                      icon: Icons.location_city, color: _navy, title: 'Villes Principales (avec Galerie)', count: province.cities.length,
                      children: [_CitiesSection(cities: province.cities)],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 7. DÉCOUPAGE ADMINISTRATIF
                  if (province.administrativeDivisions.isNotEmpty) ...[
                    _SectionCard(
                      icon: Icons.dashboard_customize, color: const Color(0xFF6A1B9A), title: 'Découpage Administratif (Détaillé)', count: province.administrativeDivisions.length,
                      children: [_AdministrativeSection(divisions: province.administrativeDivisions)],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 8. TOURISME & SITES REMARQUABLES
                  if (province.tourismSites.isNotEmpty) ...[
                    _SectionCard(
                      icon: Icons.landscape, color: const Color(0xFF1565C0), title: 'Tourisme & Sites Remarquables', count: province.tourismSites.length,
                      children: [_TourismSection(sites: province.tourismSites)],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 9. ÉCONOMIE & SECTEURS CLÉS
                  if (province.economicResources.isNotEmpty) ...[
                    _SectionCard(
                      icon: Icons.monetization_on, color: const Color(0xFF2E7D32), title: 'Économie & Secteurs Clés', count: province.economicResources.length,
                      children: [_EconomySection(resources: province.economicResources)],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 10. PEUPLES & TRIBUS
                  if (_hasCultureData(province)) ...[
                    _SectionCard(
                      icon: Icons.people, color: _navy, title: 'Culture, Langues & Peuples / Tribus',
                      children: [_CultureAndTribesContent(province: province)],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 11. HISTOIRE, CLIMAT & INFRASTRUCTURES
                  if (_hasInstitutionalData(province)) ...[
                    _SectionCard(
                      icon: Icons.history_edu, color: _navy, title: 'Histoire, Climat & Infrastructures',
                      children: [_MonographyContent(province: province)],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 12. URGENCES & CONTACTS UTILES
                  if (province.emergencyContacts.isNotEmpty) ...[
                    _SectionCard(
                      icon: Icons.emergency, color: const Color(0xFFD32F2F), title: 'Urgences & Contacts Utiles', count: province.emergencyContacts.length,
                      children: [_EmergencySection(contacts: province.emergencyContacts)],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 13. IDENTITÉ VISUELLE OFFICIELLE
                  _SectionCard(
                    icon: Icons.image, color: _navy, title: 'Identité Visuelle Officielle',
                    children: [_VisualIdentityContent(province: province)],
                  ),
                  const SizedBox(height: 40),
                ]),
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
}

// ============================================================
// UTILITAIRES PARTAGÉS (WEB-SAFE)
// ============================================================
Future<void> _launchUrlSafe(String rawUrl) async {
  var u = rawUrl.trim();
  if (!u.startsWith('http://') && !u.startsWith('https://')) u = 'https://$u';
  final uri = Uri.tryParse(u);
  if (uri != null) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

String _fmtNumber(num n) => n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

/// Image loader web-safe global
Widget _buildWebSafeImage(String url, {BoxFit fit = BoxFit.cover, double? width, double? height}) {
  return Image.network(
    url,
    width: width,
    height: height,
    fit: fit,
    loadingBuilder: (context, child, progress) {
      if (progress == null) return child;
      return Container(
        width: width, height: height, color: Colors.grey.shade200,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _gold)),
      );
    },
    errorBuilder: (_, __, ___) => Container(
      width: width, height: height, color: Colors.grey.shade200,
      child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
    ),
  );
}

// ============================================================
// LA "BELLE CARTE" DE CATÉGORIE
// ============================================================
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final int? count;
  final List<Widget> children;
  const _SectionCard({required this.icon, required this.color, required this.title, this.count, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _hairline),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _navyDeep))),
            if (count != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                child: Text('$count', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color)),
              ),
          ]),
          const Divider(height: 22, color: _hairline, thickness: 1),
          ...children,
        ],
      ),
    );
  }
}

// ============================================================
// GALERIE MÉDIA PLEIN ÉCRAN & GRILLE (STATEFUL SAFE)
// ============================================================
void _openMediaGallery(BuildContext context, List<Map<String, dynamic>> media, {int initialIndex = 0, String title = 'Galerie'}) {
  if (media.isEmpty) return;
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false, barrierColor: Colors.black,
      pageBuilder: (_, __, ___) => _MediaGalleryPage(media: media, initialIndex: initialIndex, title: title),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
    ),
  );
}

void _openMediaGrid(BuildContext context, List<Map<String, dynamic>> media, {String title = 'Galerie'}) {
  if (media.isEmpty) return;
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => _MediaGridPage(media: media, title: title)));
}

class _MediaGalleryPage extends StatefulWidget {
  final List<Map<String, dynamic>> media;
  final int initialIndex;
  final String title;
  const _MediaGalleryPage({required this.media, required this.title, this.initialIndex = 0});

  @override
  State<_MediaGalleryPage> createState() => _MediaGalleryPageState();
}

class _MediaGalleryPageState extends State<_MediaGalleryPage> {
  late final PageController _pageCtrl;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageCtrl = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.media.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) {
              final item = widget.media[i];
              final url = item['url']?.toString() ?? '';
              final isVideo = item['type'] == 'video';
              
              if (isVideo) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 96, height: 96,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), shape: BoxShape.circle),
                        child: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 64),
                      ),
                      const SizedBox(height: 20),
                      const Text('Contenu vidéo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => _launchUrlSafe(url),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('Lire la vidéo'),
                        style: ElevatedButton.styleFrom(backgroundColor: _gold, foregroundColor: _navyDeep, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                      ),
                    ],
                  ),
                );
              }
              return InteractiveViewer(
                panEnabled: true, minScale: 1.0, maxScale: 4.0,
                child: Image.network(
                  url, fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(color: Colors.white)),
                  errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.error_outline, color: Colors.white, size: 50)),
                ),
              );
            },
          ),
          Positioned(
            top: 44, left: 16, right: 16,
            child: Row(
              children: [
                _RoundIconButton(icon: Icons.close, onTap: () => Navigator.of(context).pop()),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                  child: Text('${_index + 1} / ${widget.media.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 32, left: 0, right: 0,
            child: Text(widget.title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap, customBorder: const CircleBorder(),
        child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 22)),
      );
}

class _MediaGridPage extends StatelessWidget {
  final List<Map<String, dynamic>> media;
  final String title;
  const _MediaGridPage({required this.media, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ivory,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        backgroundColor: _navyDeep, foregroundColor: Colors.white, elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
          itemCount: media.length,
          itemBuilder: (_, i) {
            final item = media[i];
            final isVideo = item['type'] == 'video';
            return GestureDetector(
              onTap: () => _openMediaGallery(context, media, initialIndex: i, title: title),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: isVideo
                    ? Container(color: _navyDeep, child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30))
                    : _buildWebSafeImage(item['url']?.toString() ?? ''),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MediaStrip extends StatelessWidget {
  final List<Map<String, dynamic>> media;
  final void Function(int index) onTapItem;
  const _MediaStrip({required this.media, required this.onTapItem});

  @override
  Widget build(BuildContext context) {
    final shown = media.take(4).toList();
    final remaining = media.length - shown.length;
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          for (int i = 0; i < shown.length; i++) ...[
            GestureDetector(
              onTap: () => onTapItem(i),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: shown[i]['type'] == 'video'
                        ? Container(width: 56, height: 56, color: _navyDeep, child: const Icon(Icons.play_arrow_rounded, color: Colors.white))
                        : _buildWebSafeImage(shown[i]['url']?.toString() ?? '', width: 56, height: 56),
                  ),
                  if (i == shown.length - 1 && remaining > 0)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(10)),
                        alignment: Alignment.center,
                        child: Text('+$remaining', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// GALERIE BANNER (STATEFUL AUTO-SCROLLING)
// ============================================================
class _GalleryBanner extends StatefulWidget {
  final List<Map<String, dynamic>> media;
  final String provinceName;
  const _GalleryBanner({required this.media, required this.provinceName});

  @override
  State<_GalleryBanner> createState() => _GalleryBannerState();
}

class _GalleryBannerState extends State<_GalleryBanner> {
  late final PageController _pageCtrl;
  Timer? _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    final photos = widget.media.where((m) => m['type'] != 'video').toList();
    final display = photos.isNotEmpty ? photos : widget.media;

    if (display.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted || !_pageCtrl.hasClients) return;
        _currentIndex = (_currentIndex + 1) % display.length;
        _pageCtrl.animateToPage(
          _currentIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.media.where((m) => m['type'] != 'video').toList();
    final display = photos.isNotEmpty ? photos : widget.media;
    if (display.isEmpty) return const SizedBox.shrink();

    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _pageCtrl, 
            itemCount: display.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (_, i) {
              final item = display[i];
              final url = item['url']?.toString() ?? '';
              final isVideo = item['type'] == 'video';
              return GestureDetector(
                onTap: () => _openMediaGallery(context, display, initialIndex: i, title: widget.provinceName),
                child: Stack(fit: StackFit.expand, children: [
                  isVideo
                      ? Container(color: _navyDeep, child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 44))
                      : _buildWebSafeImage(url),
                  Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.5), Colors.transparent]))),
                ]),
              );
            },
          ),
        ),
      ),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () => _openMediaGrid(context, widget.media, title: widget.provinceName),
          icon: const Icon(Icons.grid_view_rounded, size: 16),
          label: Text('Voir toute la galerie (${widget.media.length})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          style: TextButton.styleFrom(foregroundColor: _navy),
        ),
      ),
    ]);
  }
}

// ============================================================
// FICHE DÉTAILLÉE GÉNÉRIQUE ("Voir plus")
// ============================================================
class _DetailSection {
  final String label;
  final String content;
  final IconData icon;
  const _DetailSection({required this.label, required this.content, this.icon = Icons.notes});
}

void _showDetailSheet(
  BuildContext context, {
  required IconData icon,
  required Color color,
  required String title,
  String? badge,
  String? headerPhotoUrl,
  List<Widget> chips = const [],
  List<_DetailSection> sections = const [],
  List<Map<String, dynamic>> media = const [],
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.72, minChildSize: 0.4, maxChildSize: 0.95, expand: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Row(
                    children: [
                      if (headerPhotoUrl != null && headerPhotoUrl.trim().isNotEmpty)
                        Container(
                          width: 60, height: 60,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 2)),
                          child: ClipOval(child: _buildWebSafeImage(headerPhotoUrl)),
                        )
                      else
                        Container(width: 52, height: 52, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color, size: 26)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _navyDeep)),
                            if (badge != null && badge.trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(badge, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (chips.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(spacing: 8, runSpacing: 8, children: chips),
                  ],
                  for (final s in sections) ...[
                    const SizedBox(height: 20),
                    Row(children: [
                      Icon(s.icon, size: 16, color: color),
                      const SizedBox(width: 6),
                      Text(s.label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color)),
                    ]),
                    const SizedBox(height: 6),
                    Text(s.content, style: const TextStyle(fontSize: 13.5, height: 1.55, color: _ink)),
                  ],
                  if (media.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Photos & Vidéos (${media.length})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _navyDeep)),
                      TextButton(
                        onPressed: () => _openMediaGrid(context, media, title: title),
                        child: const Text('Voir tout', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                      itemCount: media.length,
                      itemBuilder: (_, i) {
                        final m = media[i];
                        final isVideo = m['type'] == 'video';
                        return GestureDetector(
                          onTap: () => _openMediaGallery(context, media, initialIndex: i, title: title),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: isVideo
                                ? Container(color: _navyDeep, child: const Icon(Icons.play_arrow_rounded, color: Colors.white))
                                : _buildWebSafeImage(m['url']?.toString() ?? ''),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _showTextSheet(BuildContext context, {required String title, required String text, required IconData icon, required Color color}) {
  _showDetailSheet(context, icon: icon, color: color, title: title, sections: [_DetailSection(label: title, content: text, icon: icon)]);
}

Widget _metaChip(IconData icon, String text, {Color color = _navy}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 5),
      Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
    ]),
  );
}

// ============================================================
// CARTE GÉNÉRIQUE D'ITEM
// ============================================================
class _EntityCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? badge;
  final List<Widget> metaLines;
  final String? preview;
  final List<Map<String, dynamic>> media;
  final VoidCallback onTap;

  const _EntityCard({
    required this.icon, required this.color, required this.title, this.badge,
    this.metaLines = const [], this.preview, this.media = const [], required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: _itemBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _itemBorder)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: color, size: 20)),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: _navyDeep))),
                      if (badge != null && badge!.isNotEmpty)
                        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)), child: Text(badge!, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _muted))),
                    ]),
                    if (metaLines.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 6, children: metaLines),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _muted),
            ]),
            if (preview != null && preview!.trim().isNotEmpty) ...[
              const SizedBox(height: 9),
              Text(preview!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: _muted, height: 1.4)),
            ],
            if (media.isNotEmpty) ...[
              const SizedBox(height: 9),
              _MediaStrip(media: media, onTapItem: (i) => _openMediaGallery(context, media, initialIndex: i, title: title)),
            ],
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text('Voir plus', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== HEADER (bannière image de couverture) ====================
class _ProvinceHeader extends StatelessWidget {
  final Province province;
  const _ProvinceHeader({required this.province});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 260, pinned: true, backgroundColor: _navyDeep,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
        title: Text(province.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, shadows: [Shadow(blurRadius: 8, color: Colors.black54)])),
        background: Stack(fit: StackFit.expand, children: [
          GestureDetector(
            onTap: (province.coverImageUrl != null && province.coverImageUrl!.isNotEmpty)
                ? () => _openMediaGallery(context, [{'url': province.coverImageUrl, 'type': 'photo'}], title: province.name)
                : null,
            child: province.coverImageUrl != null && province.coverImageUrl!.isNotEmpty
                ? _buildWebSafeImage(province.coverImageUrl!)
                : Container(color: _navyDeep),
          ),
          Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, _navyDeep.withOpacity(0.95)], stops: const [0.3, 1]))),
        ]),
      ),
    );
  }
}

// ==================== 1. IDENTITÉ DE LA PROVINCE ====================
class _ProvinceIdentityCard extends StatelessWidget {
  final Province province;
  const _ProvinceIdentityCard({required this.province});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _hairline)),
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(children: [
          GestureDetector(
            onTap: (province.coatOfArmsUrl != null && province.coatOfArmsUrl!.isNotEmpty)
                ? () => _openMediaGallery(context, [{'url': province.coatOfArmsUrl, 'type': 'photo'}], title: 'Blason — ${province.name}')
                : null,
            child: Container(
              width: 64, height: 64, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _hairline), color: _ivory),
              child: province.coatOfArmsUrl != null && province.coatOfArmsUrl!.isNotEmpty
                  ? ClipOval(child: _buildWebSafeImage(province.coatOfArmsUrl!, fit: BoxFit.contain))
                  : const Icon(Icons.shield, color: _navyDeep),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(province.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _navyDeep)),
                const SizedBox(height: 4),
                Row(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFD32F2F), borderRadius: BorderRadius.circular(6)), child: Text(province.code, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white))),
                  const SizedBox(width: 8),
                  Text('Région ${province.region}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _navy)),
                ]),
              ],
            ),
          ),
        ]),
        const Divider(height: 24, color: _hairline),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _StatItem(icon: Icons.location_city, label: 'Capitale', value: province.capital),
          _StatItem(icon: Icons.groups, label: 'Population', value: province.population != null ? '${_fmtNumber(province.population!)} hab' : 'N/A'),
          _StatItem(icon: Icons.map, label: 'Superficie', value: province.area != null ? '${_fmtNumber(province.area!)} km²' : 'N/A'),
          if (province.territoriesCount != null)
            _StatItem(icon: Icons.format_list_numbered, label: 'Territoires', value: '${province.territoriesCount}'),
        ]),
      ]),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon; final String label, value;
  const _StatItem({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(children: [
        Icon(icon, size: 20, color: _navy), const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _ink)),
        Text(label, style: const TextStyle(fontSize: 10, color: _muted)),
      ]);
}

// ==================== 2. CARTOGRAPHIE ====================
class _MapContent extends StatelessWidget {
  final String url;
  final String provinceName;
  const _MapContent({required this.url, required this.provinceName});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openMediaGallery(context, [{'url': url, 'type': 'photo'}], title: 'Carte — $provinceName'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(children: [
          _buildWebSafeImage(url, height: 200, width: double.infinity),
          Positioned(right: 10, bottom: 10, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.zoom_in, color: Colors.white, size: 18))),
        ]),
      ),
    );
  }
}

// ==================== 4. GOUVERNANCE & EXÉCUTIF ====================
class _GovernanceContent extends StatelessWidget {
  final Province province;
  const _GovernanceContent({required this.province});

  @override
  Widget build(BuildContext context) {
    final items = <Map<String, String?>>[];
    if (province.governor != null && province.governor!.isNotEmpty) items.add({'role': 'Gouverneur', 'name': province.governor, 'photo': province.governorPhotoUrl});
    if (province.viceGovernor != null && province.viceGovernor!.isNotEmpty) items.add({'role': 'Vice-Gouverneur', 'name': province.viceGovernor, 'photo': province.viceGovernorPhotoUrl});
    final ministers = province.ministers ?? [];

    if (items.isEmpty && ministers.isEmpty) {
      return const Text('Aucune donnée de gouvernance renseignée.', style: TextStyle(fontSize: 12.5, color: _muted));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (items.isNotEmpty)
        GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.85),
          itemCount: items.length,
          itemBuilder: (_, i) => _ExecutiveCard(role: items[i]['role']!, name: items[i]['name']!, photoUrl: items[i]['photo']),
        ),
      if (ministers.isNotEmpty) ...[
        const SizedBox(height: 16),
        const Text('Ministres', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _navyDeep)),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.78),
          itemCount: ministers.length,
          itemBuilder: (_, i) {
            final m = ministers[i] as Map;
            final name = m['name']?.toString() ?? '—';
            final role = m['role']?.toString() ?? 'Ministre';
            final photo = m['photoUrl']?.toString() ?? m['photo_url']?.toString();
            final hasPhoto = photo != null && photo.trim().isNotEmpty;
            return InkWell(
              onTap: () => _showDetailSheet(context, icon: Icons.person, color: _navy, title: name, badge: role, headerPhotoUrl: photo, media: hasPhoto ? [{'url': photo, 'type': 'photo'}] : []),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(color: _itemBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _itemBorder)),
                padding: const EdgeInsets.all(10),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  CircleAvatar(
                    radius: 26, backgroundColor: Colors.white,
                    backgroundImage: hasPhoto ? NetworkImage(photo) : null,
                    onBackgroundImageError: (_, __) {},
                    child: !hasPhoto ? const Icon(Icons.person, size: 20, color: _muted) : null,
                  ),
                  const SizedBox(height: 8),
                  Text(role, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: _muted, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: _ink)),
                ]),
              ),
            );
          },
        ),
      ],
    ]);
  }
}

class _ExecutiveCard extends StatelessWidget {
  final String role, name; final String? photoUrl;
  const _ExecutiveCard({required this.role, required this.name, this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.trim().isNotEmpty;
    final isGov = role.toLowerCase().contains('gouverneur') && !role.toLowerCase().contains('vice');
    final color = isGov ? _gold : _navy;
    return InkWell(
      onTap: () => _showDetailSheet(context, icon: Icons.person, color: color, title: name, badge: role, headerPhotoUrl: photoUrl, media: hasPhoto ? [{'url': photoUrl, 'type': 'photo'}] : []),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(color: _itemBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: _itemBorder)),
        padding: const EdgeInsets.all(14),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(3), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 2.5)),
            child: CircleAvatar(
              radius: 34, backgroundColor: Colors.white,
              backgroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
              onBackgroundImageError: (_, __) {},
              child: !hasPhoto ? const Icon(Icons.person, size: 32, color: _muted) : null,
            ),
          ),
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)), child: Text(role.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: isGov ? const Color(0xFF8A6B00) : _navy))),
          const SizedBox(height: 6),
          Text(name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: _ink)),
        ]),
      ),
    );
  }
}

// ==================== 5. RÉALISATIONS ====================
class _AchievementsSection extends StatelessWidget {
  final List<Map<String, dynamic>> achievements;
  const _AchievementsSection({required this.achievements});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: achievements.map((a) {
        final title = a['title']?.toString() ?? 'Réalisation';
        final desc = a['description']?.toString() ?? '';
        final date = a['date']?.toString() ?? '';
        final location = a['location']?.toString() ?? '';
        final media = a['media'] != null ? List<Map<String, dynamic>>.from(a['media']) : <Map<String, dynamic>>[];

        final meta = <Widget>[
          if (date.isNotEmpty) _metaChip(Icons.calendar_today, date),
          if (location.isNotEmpty) _metaChip(Icons.location_on, location),
        ];

        return _EntityCard(
          icon: Icons.verified, color: _navy, title: title, metaLines: meta, preview: desc, media: media,
          onTap: () => _showDetailSheet(
            context, icon: Icons.verified, color: _navy, title: title,
            chips: meta,
            sections: desc.isNotEmpty ? [_DetailSection(label: 'Description détaillée', content: desc, icon: Icons.notes)] : [],
            media: media,
          ),
        );
      }).toList(),
    );
  }
}

// ==================== 6. VILLES PRINCIPALES ====================
class _CitiesSection extends StatelessWidget {
  final List<City> cities;
  const _CitiesSection({required this.cities});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: cities.map((c) {
        List<Map<String, dynamic>> media = [];
        try {
          final dynC = c as dynamic;
          if (dynC.media != null) media = List<Map<String, dynamic>>.from(dynC.media);
          if (media.isEmpty && dynC.imageUrl != null && dynC.imageUrl.toString().isNotEmpty) {
            media = [{'url': dynC.imageUrl, 'type': 'photo'}];
          }
        } catch (_) {}
        final mayor = c.mayor ?? '';
        final mayorPhoto = c.mayorPhotoUrl;

        final meta = <Widget>[
          if (c.population != null) _metaChip(Icons.groups, '${c.population} hab'),
          if (c.isCapital) _metaChip(Icons.star, 'Chef-lieu', color: const Color(0xFF8A6B00)),
          if (mayor.isNotEmpty) _metaChip(Icons.person, mayor),
        ];

        return _EntityCard(
          icon: c.isCapital ? Icons.star_rounded : Icons.location_city_rounded,
          color: c.isCapital ? const Color(0xFF8A6B00) : _navy,
          title: c.name, metaLines: meta, media: media,
          onTap: () => _showDetailSheet(
            context,
            icon: c.isCapital ? Icons.star_rounded : Icons.location_city_rounded,
            color: c.isCapital ? const Color(0xFF8A6B00) : _navy,
            title: c.name, badge: c.isCapital ? 'Chef-lieu de province' : null,
            headerPhotoUrl: mayorPhoto,
            chips: meta,
            sections: mayor.isNotEmpty ? [_DetailSection(label: 'Autorité (Maire / Bourgmestre)', content: mayor, icon: Icons.person)] : [],
            media: media,
          ),
        );
      }).toList(),
    );
  }
}

// ==================== 7. DÉCOUPAGE ADMINISTRATIF ====================
class _AdministrativeSection extends StatelessWidget {
  final List<dynamic> divisions;
  const _AdministrativeSection({required this.divisions});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: divisions.map((d) {
        final dyn = d as dynamic;
        final name = dyn.name?.toString() ?? 'Division';
        final type = dyn.type?.toString() ?? 'Territoire';
        final capital = dyn.capital?.toString() ?? '';
        final pop = dyn.population?.toString() ?? '';
        final area = dyn.area?.toString() ?? '';
        String administrator = '';
        try { administrator = dyn.administrator?.toString() ?? ''; } catch (_) {}
        List<Map<String, dynamic>> media = [];
        try { if (dyn.media != null) media = List<Map<String, dynamic>>.from(dyn.media); } catch (_) {}

        final meta = <Widget>[
          if (capital.isNotEmpty) _metaChip(Icons.star, 'Chef-lieu : $capital'),
          if (pop.isNotEmpty) _metaChip(Icons.groups, '$pop hab'),
          if (area.isNotEmpty) _metaChip(Icons.map, '$area km²'),
          if (administrator.isNotEmpty) _metaChip(Icons.person, administrator),
        ];

        return _EntityCard(
          icon: Icons.dashboard_customize, color: const Color(0xFF6A1B9A), title: name, badge: type, metaLines: meta, media: media,
          onTap: () => _showDetailSheet(
            context, icon: Icons.dashboard_customize, color: const Color(0xFF6A1B9A), title: name, badge: type,
            chips: meta,
            sections: administrator.isNotEmpty ? [_DetailSection(label: 'Administrateur', content: administrator, icon: Icons.person)] : [],
            media: media,
          ),
        );
      }).toList(),
    );
  }
}

// ==================== 8. TOURISME ====================
class _TourismSection extends StatelessWidget {
  final List<dynamic> sites;
  const _TourismSection({required this.sites});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: sites.map((s) {
        final dyn = s as dynamic;
        final name = dyn.name?.toString() ?? 'Site';
        final type = dyn.type?.toString() ?? 'Lieu';
        final desc = dyn.description?.toString() ?? '';
        List<Map<String, dynamic>> media = [];
        try { if (dyn.media != null) media = List<Map<String, dynamic>>.from(dyn.media); } catch (_) {}
        if (media.isEmpty) {
          try { if (dyn.imageUrl != null && dyn.imageUrl.toString().isNotEmpty) media = [{'url': dyn.imageUrl, 'type': 'photo'}]; } catch (_) {}
        }
        return _EntityCard(
          icon: Icons.landscape, color: const Color(0xFF1565C0), title: name, badge: type.isNotEmpty ? type : null, preview: desc, media: media,
          onTap: () => _showDetailSheet(context, icon: Icons.landscape, color: const Color(0xFF1565C0), title: name, badge: type,
              sections: desc.isNotEmpty ? [_DetailSection(label: 'Description', content: desc, icon: Icons.notes)] : [], media: media),
        );
      }).toList(),
    );
  }
}

// ==================== 9. ÉCONOMIE ====================
class _EconomySection extends StatelessWidget {
  final List<dynamic> resources;
  const _EconomySection({required this.resources});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: resources.map((e) {
        final dyn = e as dynamic;
        final name = dyn.name?.toString() ?? 'Secteur';
        final desc = dyn.description?.toString() ?? '';
        List<Map<String, dynamic>> media = [];
        try { if (dyn.media != null) media = List<Map<String, dynamic>>.from(dyn.media); } catch (_) {}
        if (media.isEmpty) {
          try { if (dyn.imageUrl != null && dyn.imageUrl.toString().isNotEmpty) media = [{'url': dyn.imageUrl, 'type': 'photo'}]; } catch (_) {}
        }
        return _EntityCard(
          icon: Icons.monetization_on, color: const Color(0xFF2E7D32), title: name, preview: desc, media: media,
          onTap: () => _showDetailSheet(context, icon: Icons.monetization_on, color: const Color(0xFF2E7D32), title: name,
              sections: desc.isNotEmpty ? [_DetailSection(label: 'Détails', content: desc, icon: Icons.notes)] : [], media: media),
        );
      }).toList(),
    );
  }
}

// ==================== 10. CULTURE, LANGUES & PEUPLES ====================
class _CultureAndTribesContent extends StatelessWidget {
  final Province province;
  const _CultureAndTribesContent({required this.province});

  @override
  Widget build(BuildContext context) {
    final tribes = province.tribes ?? [];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (province.languages?.trim().isNotEmpty == true) ...[
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.forum, size: 18, color: _navy), const SizedBox(width: 8),
          Expanded(child: Text.rich(TextSpan(children: [const TextSpan(text: 'Langues parlées : ', style: TextStyle(fontWeight: FontWeight.bold, color: _navyDeep)), TextSpan(text: province.languages!, style: const TextStyle(color: _muted))], style: const TextStyle(fontSize: 13)))),
        ]),
        const SizedBox(height: 10),
      ],
      if (province.resources?.trim().isNotEmpty == true) ...[
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.diamond, size: 18, color: _gold), const SizedBox(width: 8),
          Expanded(child: Text.rich(TextSpan(children: [const TextSpan(text: 'Ressources principales : ', style: TextStyle(fontWeight: FontWeight.bold, color: _navyDeep)), TextSpan(text: province.resources!, style: const TextStyle(color: _muted))], style: const TextStyle(fontSize: 13)))),
        ]),
        const SizedBox(height: 10),
      ],
      if (province.description?.trim().isNotEmpty == true) ...[
        Text(province.description!, style: const TextStyle(fontSize: 13, height: 1.5, color: _ink)),
      ],
      if (tribes.isNotEmpty) ...[
        const SizedBox(height: 18),
        const Divider(color: _hairline),
        const SizedBox(height: 10),
        const Text('Peuples & Tribus de la Province', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _navyDeep)),
        const SizedBox(height: 10),
        ...tribes.map((t) {
          final name = t['name']?.toString() ?? 'Tribu';
          final zone = t['zone']?.toString() ?? '';
          final history = t['history']?.toString() ?? '';
          final media = t['media'] != null ? List<Map<String, dynamic>>.from(t['media']) : <Map<String, dynamic>>[];
          return _EntityCard(
            icon: Icons.groups, color: _navy, title: name,
            metaLines: zone.isNotEmpty ? [_metaChip(Icons.place, zone)] : [],
            preview: history, media: media,
            onTap: () => _showDetailSheet(context, icon: Icons.groups, color: _navy, title: name,
                chips: zone.isNotEmpty ? [_metaChip(Icons.place, zone)] : [],
                sections: history.isNotEmpty ? [_DetailSection(label: 'Histoire, origines & coutumes', content: history, icon: Icons.menu_book)] : [],
                media: media),
          );
        }),
      ],
    ]);
  }
}

// ==================== 11. HISTOIRE, CLIMAT & INFRA ====================
class _MonographyContent extends StatelessWidget {
  final Province province;
  const _MonographyContent({required this.province});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    if (province.history?.trim().isNotEmpty == true) items.add(_buildItem(context, 'Historique complet & Origines de la province', province.history!, Icons.menu_book));
    if (province.climate?.trim().isNotEmpty == true) items.add(_buildItem(context, 'Climat, Relief & Environnement', province.climate!, Icons.wb_sunny));
    if (province.infrastructure?.trim().isNotEmpty == true) items.add(_buildItem(context, 'Infrastructures, Transports & Énergie', province.infrastructure!, Icons.bolt));
    if (province.education?.trim().isNotEmpty == true) items.add(_buildItem(context, 'Éducation, Recherche & Santé', province.education!, Icons.school));

    return Column(children: items);
  }

  Widget _buildItem(BuildContext context, String label, String content, IconData icon) {
    final isLong = content.length > 200;
    return InkWell(
      onTap: isLong ? () => _showTextSheet(context, title: label, text: content, icon: icon, color: _navy) : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: _itemBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _itemBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 17, color: _navy), const SizedBox(width: 8),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: _navyDeep))),
          ]),
          const SizedBox(height: 8),
          Text(content, maxLines: isLong ? 3 : null, overflow: isLong ? TextOverflow.ellipsis : TextOverflow.visible, style: const TextStyle(fontSize: 13, height: 1.5, color: _ink)),
          if (isLong) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Lire la suite', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _navy))),
        ]),
      ),
    );
  }
}

// ==================== 12. URGENCES ====================
class _EmergencySection extends StatelessWidget {
  final List<dynamic> contacts;
  const _EmergencySection({required this.contacts});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: contacts.map((c) {
        final dyn = c as dynamic;
        final service = dyn.service?.toString() ?? dyn.serviceName?.toString() ?? 'Service';
        final phone = dyn.phone?.toString() ?? dyn.phoneNumber?.toString() ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: _itemBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFD32F2F).withOpacity(0.25))),
          child: ListTile(
            leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFD32F2F).withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.phone_in_talk, color: Color(0xFFD32F2F))),
            title: Text(service, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text(phone, style: const TextStyle(fontWeight: FontWeight.w600, color: _ink)),
            trailing: phone.isNotEmpty ? IconButton(icon: const Icon(Icons.call, color: Colors.green), onPressed: () => launchUrl(Uri.parse('tel:$phone'))) : null,
          ),
        );
      }).toList(),
    );
  }
}

// ==================== 13. IDENTITÉ VISUELLE ====================
class _VisualIdentityContent extends StatelessWidget {
  final Province province;
  const _VisualIdentityContent({required this.province});

  @override
  Widget build(BuildContext context) {
    final hasWebsite = province.website != null && province.website!.trim().isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: _visualThumb(context, 'Photo de couverture', province.coverImageUrl, Icons.image_outlined)),
        const SizedBox(width: 10),
        Expanded(child: _visualThumb(context, 'Blason / Armoiries', province.coatOfArmsUrl, Icons.shield_outlined)),
        const SizedBox(width: 10),
        Expanded(child: _visualThumb(context, 'Carte géographique', province.mapUrl, Icons.map_outlined)),
      ]),
      if (hasWebsite) ...[
        const SizedBox(height: 14),
        InkWell(
          onTap: () => _launchUrlSafe(province.website!),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: _itemBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _itemBorder)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.language, size: 16, color: _navy),
              const SizedBox(width: 8),
              Text(province.website!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _navy)),
            ]),
          ),
        ),
      ],
    ]);
  }

  Widget _visualThumb(BuildContext context, String label, String? url, IconData fallbackIcon) {
    final hasImg = url != null && url.trim().isNotEmpty;
    return GestureDetector(
      onTap: hasImg ? () => _openMediaGallery(context, [{'url': url, 'type': 'photo'}], title: label) : null,
      child: Column(children: [
        Container(
          height: 74, width: double.infinity,
          decoration: BoxDecoration(color: _itemBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _itemBorder)),
          child: hasImg
              ? ClipRRect(borderRadius: BorderRadius.circular(12), child: _buildWebSafeImage(url, fit: BoxFit.cover))
              : Icon(fallbackIcon, color: Colors.grey.shade400),
        ),
        const SizedBox(height: 6),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: _muted, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

// ==================== DIVERS ====================
class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red), const SizedBox(height: 12),
        const Text('Impossible de charger'), const SizedBox(height: 12),
        ElevatedButton(onPressed: onRetry, style: ElevatedButton.styleFrom(backgroundColor: _navy), child: const Text('Réessayer', style: TextStyle(color: Colors.white))),
      ]));
}
