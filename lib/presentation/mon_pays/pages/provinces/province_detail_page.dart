// lib/presentation/mon_pays/pages/provinces/province_detail_page.dart
//
// ProvinceDetailPage — Production Enterprise (Portail Institutionnel RDC)
// Design System ThixPolicy + i18n + Accessibilité + CachedNetworkImage

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

import '../../providers/provinces_provider.dart';
import '../../models/province.dart';
import '../../models/city.dart';

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class ProvinceDetailPage extends ConsumerWidget {
  final String provinceId;
  const ProvinceDetailPage({required this.provinceId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provinceAsync = ref.watch(provinceWithAllRelationsProvider(provinceId));

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      body: provinceAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: ThixPolicy.primary),
        ),
        error: (e, _) => _buildErrorState(context, l10n, () {
          ref.invalidate(provinceWithAllRelationsProvider(provinceId));
        }),
        data: (province) => RefreshIndicator(
          color: ThixPolicy.primary,
          onRefresh: () =>
              ref.refresh(provinceWithAllRelationsProvider(provinceId).future),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              _ProvinceHeader(province: province),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // 1. IDENTITÉ
                    _ProvinceIdentityCard(province: province),
                    const SizedBox(height: 16),

                    // 2. CARTOGRAPHIE
                    if (province.mapUrl != null &&
                        province.mapUrl!.trim().isNotEmpty) ...[
                      _SectionCard(
                        icon: Icons.map_rounded,
                        color: ThixPolicy.primary,
                        title: l10n.t('province_cartography'),
                        children: [
                          _MapContent(
                            url: province.mapUrl!,
                            provinceName: province.name,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 3. GALERIE
                    if (province.galleryMedia != null &&
                        province.galleryMedia!.isNotEmpty) ...[
                      _SectionCard(
                        icon: Icons.perm_media_rounded,
                        color: ThixPolicy.primary,
                        title: l10n.t('province_gallery'),
                        count: province.galleryMedia!.length,
                        children: [
                          _GalleryBanner(
                            media: province.galleryMedia!,
                            provinceName: province.name,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 4. GOUVERNANCE
                    _SectionCard(
                      icon: Icons.account_balance_rounded,
                      color: ThixPolicy.primary,
                      title: l10n.t('province_governance'),
                      children: [_GovernanceContent(province: province)],
                    ),
                    const SizedBox(height: 16),

                    // 5. RÉALISATIONS
                    if (province.achievements != null &&
                        province.achievements!.isNotEmpty) ...[
                      _SectionCard(
                        icon: Icons.emoji_events_rounded,
                        color: ThixPolicy.gold,
                        title: l10n.t('province_achievements'),
                        count: province.achievements!.length,
                        children: [
                          _AchievementsSection(
                            achievements: province.achievements!,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 6. VILLES
                    if (province.cities.isNotEmpty) ...[
                      _SectionCard(
                        icon: Icons.location_city_rounded,
                        color: ThixPolicy.primary,
                        title: l10n.t('province_cities'),
                        count: province.cities.length,
                        children: [_CitiesSection(cities: province.cities)],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 7. DÉCOUPAGE
                    if (province.administrativeDivisions.isNotEmpty) ...[
                      _SectionCard(
                        icon: Icons.dashboard_customize_rounded,
                        color: const Color(0xFF6A1B9A),
                        title: l10n.t('province_divisions'),
                        count: province.administrativeDivisions.length,
                        children: [
                          _AdministrativeSection(
                            divisions: province.administrativeDivisions,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 8. TOURISME
                    if (province.tourismSites.isNotEmpty) ...[
                      _SectionCard(
                        icon: Icons.landscape_rounded,
                        color: const Color(0xFF1565C0),
                        title: l10n.t('province_tourism'),
                        count: province.tourismSites.length,
                        children: [
                          _TourismSection(sites: province.tourismSites),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 9. ÉCONOMIE
                    if (province.economicResources.isNotEmpty) ...[
                      _SectionCard(
                        icon: Icons.monetization_on_rounded,
                        color: const Color(0xFF2E7D32),
                        title: l10n.t('province_economy'),
                        count: province.economicResources.length,
                        children: [
                          _EconomySection(resources: province.economicResources),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 10. CULTURE
                    if (_hasCultureData(province)) ...[
                      _SectionCard(
                        icon: Icons.people_alt_rounded,
                        color: ThixPolicy.primary,
                        title: l10n.t('province_culture'),
                        children: [_CultureAndTribesContent(province: province)],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 11. HISTOIRE
                    if (_hasInstitutionalData(province)) ...[
                      _SectionCard(
                        icon: Icons.history_edu_rounded,
                        color: ThixPolicy.primary,
                        title: l10n.t('province_history'),
                        children: [_MonographyContent(province: province)],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 12. URGENCES
                    if (province.emergencyContacts.isNotEmpty) ...[
                      _SectionCard(
                        icon: Icons.emergency_rounded,
                        color: ThixPolicy.danger,
                        title: l10n.t('province_emergency'),
                        count: province.emergencyContacts.length,
                        children: [
                          _EmergencySection(contacts: province.emergencyContacts),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 13. IDENTITÉ VISUELLE
                    _SectionCard(
                      icon: Icons.image_rounded,
                      color: ThixPolicy.primary,
                      title: l10n.t('province_visual_identity'),
                      children: [_VisualIdentityContent(province: province)],
                    ),
                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ],
          ),
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

  Widget _buildErrorState(
    BuildContext context,
    AppLocalizations l10n,
    VoidCallback onRetry,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: ThixPolicy.danger,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.t('province_error_loading'),
              style: ThixPolicy.bodyStyle.copyWith(
                color: ThixPolicy.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(l10n.t('common_retry')),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: ThixPolicy.onBrand,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// UTILITAIRES
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

// ============================================================================
// IMAGE LOADER (CachedNetworkImage)
// ============================================================================
Widget _buildCachedImage(
  String url, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
}) {
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
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: ThixPolicy.primary,
        ),
      ),
    ),
    errorWidget: (context, url, error) => Container(
      width: width,
      height: height,
      color: ThixPolicy.surfaceSoft,
      child: Icon(
        Icons.broken_image_rounded,
        color: ThixPolicy.textMuted,
        size: 32,
      ),
    ),
  );
}

// ============================================================================
// SECTION CARD
// ============================================================================
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final int? count;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.color,
    required this.title,
    this.count,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: ThixPolicy.titleStyle.copyWith(
                    color: ThixPolicy.inkDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (count != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
          Divider(
            height: 22,
            color: ThixPolicy.border,
            thickness: 1,
          ),
          ...children,
        ],
      ),
    );
  }
}

// ============================================================================
// GALERIE PLEIN ÉCRAN
// ============================================================================
void _openMediaGallery(
  BuildContext context,
  List<Map<String, dynamic>> media, {
  int initialIndex = 0,
  String title = 'Galerie',
}) {
  if (media.isEmpty) return;
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, __, ___) => _MediaGalleryPage(
        media: media,
        initialIndex: initialIndex,
        title: title,
      ),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}

void _openMediaGrid(
  BuildContext context,
  List<Map<String, dynamic>> media, {
  String title = 'Galerie',
}) {
  if (media.isEmpty) return;
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => _MediaGridPage(media: media, title: title)),
  );
}

class _MediaGalleryPage extends StatefulWidget {
  final List<Map<String, dynamic>> media;
  final int initialIndex;
  final String title;

  const _MediaGalleryPage({
    required this.media,
    required this.title,
    this.initialIndex = 0,
  });

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
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_circle_fill_rounded,
                          color: Colors.white,
                          size: 64,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Contenu vidéo',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => _launchUrlSafe(url),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('Lire la vidéo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThixPolicy.gold,
                          foregroundColor: ThixPolicy.inkDeep,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return InteractiveViewer(
                panEnabled: true,
                minScale: 1.0,
                maxScale: 4.0,
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: (_, __, ___) => const Center(
                    child: Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 44,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _RoundIconButton(
                  icon: Icons.close_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_index + 1} / ${widget.media.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          customBorder: const CircleBorder(),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.black45,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      );
}

class _MediaGridPage extends StatelessWidget {
  final List<Map<String, dynamic>> media;
  final String title;

  const _MediaGridPage({required this.media, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        title: Text(
          title,
          style: ThixPolicy.titleStyle.copyWith(
            color: ThixPolicy.onBrand,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: ThixPolicy.primary,
        foregroundColor: ThixPolicy.onBrand,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: media.length,
          itemBuilder: (_, i) {
            final item = media[i];
            final isVideo = item['type'] == 'video';
            return Semantics(
              button: true,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _openMediaGallery(
                    context,
                    media,
                    initialIndex: i,
                    title: title,
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                  child: isVideo
                      ? Container(
                          color: ThixPolicy.primary,
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        )
                      : _buildCachedImage(item['url']?.toString() ?? ''),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// GALERIE BANNER (AUTO-SCROLLING)
// ============================================================================
class _GalleryBanner extends StatefulWidget {
  final List<Map<String, dynamic>> media;
  final String provinceName;

  const _GalleryBanner({
    required this.media,
    required this.provinceName,
  });

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

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
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
                return Semantics(
                  button: true,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _openMediaGallery(
                        context,
                        display,
                        initialIndex: i,
                        title: widget.provinceName,
                      );
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        isVideo
                            ? Container(
                                color: ThixPolicy.primary,
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 44,
                                ),
                              )
                            : _buildCachedImage(url),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.5),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              _openMediaGrid(context, widget.media, title: widget.provinceName);
            },
            icon: const Icon(Icons.grid_view_rounded, size: 16),
            label: Text(
              'Voir toute la galerie (${widget.media.length})',
              style: ThixPolicy.labelStyle.copyWith(
                fontWeight: FontWeight.w700,
                color: ThixPolicy.primary,
              ),
            ),
            style: TextButton.styleFrom(foregroundColor: ThixPolicy.primary),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// HEADER
// ============================================================================
class _ProvinceHeader extends StatelessWidget {
  final Province province;

  const _ProvinceHeader({required this.province});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: ThixPolicy.primary,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
        title: Text(
          province.name,
          style: ThixPolicy.h3Style.copyWith(
            color: ThixPolicy.onBrand,
            fontWeight: FontWeight.w900,
            shadows: const [Shadow(blurRadius: 8, color: Colors.black54)],
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              button: true,
              child: GestureDetector(
                onTap: (province.coverImageUrl != null &&
                        province.coverImageUrl!.isNotEmpty)
                    ? () {
                        HapticFeedback.lightImpact();
                        _openMediaGallery(
                          context,
                          [
                            {'url': province.coverImageUrl, 'type': 'photo'}
                          ],
                          title: province.name,
                        );
                      }
                    : null,
                child: province.coverImageUrl != null &&
                        province.coverImageUrl!.isNotEmpty
                    ? _buildCachedImage(province.coverImageUrl!)
                    : Container(color: ThixPolicy.primary),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    ThixPolicy.primary.withOpacity(0.95),
                  ],
                  stops: const [0.3, 1],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// IDENTITÉ
// ============================================================================
class _ProvinceIdentityCard extends StatelessWidget {
  final Province province;

  const _ProvinceIdentityCard({required this.province});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.04),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Semantics(
                button: true,
                child: GestureDetector(
                  onTap: (province.coatOfArmsUrl != null &&
                          province.coatOfArmsUrl!.isNotEmpty)
                      ? () {
                          HapticFeedback.lightImpact();
                          _openMediaGallery(
                            context,
                            [
                              {
                                'url': province.coatOfArmsUrl,
                                'type': 'photo'
                              }
                            ],
                            title: 'Blason — ${province.name}',
                          );
                        }
                      : null,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: ThixPolicy.border),
                      color: ThixPolicy.surfaceSoft,
                    ),
                    child: province.coatOfArmsUrl != null &&
                            province.coatOfArmsUrl!.isNotEmpty
                        ? ClipOval(
                            child: _buildCachedImage(
                              province.coatOfArmsUrl!,
                              fit: BoxFit.contain,
                            ),
                          )
                        : Icon(Icons.shield_rounded, color: ThixPolicy.primary),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      province.name,
                      style: ThixPolicy.h3Style.copyWith(
                        color: ThixPolicy.inkDeep,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: ThixPolicy.danger,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            province.code,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: ThixPolicy.onBrand,
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
          Divider(height: 24, color: ThixPolicy.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                icon: Icons.location_city_rounded,
                label: 'Capitale',
                value: province.capital,
              ),
              _StatItem(
                icon: Icons.groups_rounded,
                label: 'Population',
                value: province.population != null
                    ? '${_fmtNumber(province.population!)} hab'
                    : 'N/A',
              ),
              _StatItem(
                icon: Icons.map_rounded,
                label: 'Superficie',
                value: province.area != null
                    ? '${_fmtNumber(province.area!)} km²'
                    : 'N/A',
              ),
              if (province.territoriesCount != null)
                _StatItem(
                  icon: Icons.format_list_numbered_rounded,
                  label: 'Territoires',
                  value: '${province.territoriesCount}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, size: 20, color: ThixPolicy.primary),
          const SizedBox(height: 4),
          Text(
            value,
            style: ThixPolicy.captionStyle.copyWith(
              color: ThixPolicy.inkDeep,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted),
          ),
        ],
      );
}

// ============================================================================
// GOUVERNANCE
// ============================================================================
class _GovernanceContent extends StatelessWidget {
  final Province province;

  const _GovernanceContent({required this.province});

  @override
  Widget build(BuildContext context) {
    final items = <Map<String, String?>>[];
    if (province.governor != null && province.governor!.isNotEmpty) {
      items.add({
        'role': 'Gouverneur',
        'name': province.governor,
        'photo': province.governorPhotoUrl,
      });
    }
    if (province.viceGovernor != null && province.viceGovernor!.isNotEmpty) {
      items.add({
        'role': 'Vice-Gouverneur',
        'name': province.viceGovernor,
        'photo': province.viceGovernorPhotoUrl,
      });
    }
    final ministers = province.ministers ?? [];

    if (items.isEmpty && ministers.isEmpty) {
      return Text(
        'Aucune donnée de gouvernance renseignée.',
        style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (items.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) => _ExecutiveCard(
              role: items[i]['role']!,
              name: items[i]['name']!,
              photoUrl: items[i]['photo'],
            ),
          ),
        if (ministers.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Ministres',
            style: ThixPolicy.labelStyle.copyWith(
              color: ThixPolicy.inkDeep,
              fontWeight: FontWeight.w800,
            ),
          ),
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
              final m = ministers[i] as Map;
              final name = m['name']?.toString() ?? '—';
              final role = m['role']?.toString() ?? 'Ministre';
              final photo = m['photoUrl']?.toString() ??
                  m['photo_url']?.toString();
              final hasPhoto = photo != null && photo.trim().isNotEmpty;
              return Semantics(
                button: true,
                label: '$name, $role',
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showDetailSheet(
                      context,
                      icon: Icons.person_rounded,
                      color: ThixPolicy.primary,
                      title: name,
                      badge: role,
                      headerPhotoUrl: photo,
                      media: hasPhoto
                          ? [
                              {'url': photo, 'type': 'photo'}
                            ]
                          : [],
                    );
                  },
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                  child: Container(
                    decoration: BoxDecoration(
                      color: ThixPolicy.surfaceSoft,
                      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                      border: Border.all(color: ThixPolicy.border),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: ThixPolicy.card,
                          backgroundImage:
                              hasPhoto ? CachedNetworkImageProvider(photo) : null,
                          child: !hasPhoto
                              ? Icon(
                                  Icons.person_rounded,
                                  size: 20,
                                  color: ThixPolicy.textMuted,
                                )
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          role,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: ThixPolicy.microStyle.copyWith(
                            color: ThixPolicy.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: ThixPolicy.captionStyle.copyWith(
                            color: ThixPolicy.inkDeep,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _ExecutiveCard extends StatelessWidget {
  final String role;
  final String name;
  final String? photoUrl;

  const _ExecutiveCard({
    required this.role,
    required this.name,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.trim().isNotEmpty;
    final isGov = role.toLowerCase().contains('gouverneur') &&
        !role.toLowerCase().contains('vice');
    final color = isGov ? ThixPolicy.gold : ThixPolicy.primary;

    return Semantics(
      button: true,
      label: '$name, $role',
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _showDetailSheet(
            context,
            icon: Icons.person_rounded,
            color: color,
            title: name,
            badge: role,
            headerPhotoUrl: photoUrl,
            media: hasPhoto ? [{'url': photoUrl, 'type': 'photo'}] : [],
          );
        },
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        child: Container(
          decoration: BoxDecoration(
            color: ThixPolicy.surfaceSoft,
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
            border: Border.all(color: ThixPolicy.border),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2.5),
                ),
                child: CircleAvatar(
                  radius: 34,
                  backgroundColor: ThixPolicy.card,
                  backgroundImage:
                      hasPhoto ? CachedNetworkImageProvider(photoUrl!) : null,
                  child: !hasPhoto
                      ? Icon(
                          Icons.person_rounded,
                          size: 32,
                          color: ThixPolicy.textMuted,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  role.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: isGov ? const Color(0xFF8A6B00) : ThixPolicy.primary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: ThixPolicy.labelStyle.copyWith(
                  color: ThixPolicy.inkDeep,
                  fontWeight: FontWeight.w900,
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
// RÉALISATIONS
// ============================================================================
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
        final media = a['media'] != null
            ? List<Map<String, dynamic>>.from(a['media'])
            : <Map<String, dynamic>>[];

        final meta = <Widget>[
          if (date.isNotEmpty) _metaChip(Icons.calendar_today_rounded, date),
          if (location.isNotEmpty)
            _metaChip(Icons.location_on_rounded, location),
        ];

        return _EntityCard(
          icon: Icons.verified_rounded,
          color: ThixPolicy.primary,
          title: title,
          metaLines: meta,
          preview: desc,
          media: media,
          onTap: () {
            HapticFeedback.lightImpact();
            _showDetailSheet(
              context,
              icon: Icons.verified_rounded,
              color: ThixPolicy.primary,
              title: title,
              chips: meta,
              sections: desc.isNotEmpty
                  ? [
                      _DetailSection(
                        label: 'Description détaillée',
                        content: desc,
                        icon: Icons.notes_rounded,
                      ),
                    ]
                  : [],
              media: media,
            );
          },
        );
      }).toList(),
    );
  }
}

// ============================================================================
// VILLES
// ============================================================================
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
          if (dynC.media != null) {
            media = List<Map<String, dynamic>>.from(dynC.media);
          }
          if (media.isEmpty &&
              dynC.imageUrl != null &&
              dynC.imageUrl.toString().isNotEmpty) {
            media = [{'url': dynC.imageUrl, 'type': 'photo'}];
          }
        } catch (_) {}
        final mayor = c.mayor ?? '';
        final mayorPhoto = c.mayorPhotoUrl;

        final meta = <Widget>[
          if (c.population != null)
            _metaChip(Icons.groups_rounded, '${c.population} hab'),
          if (c.isCapital)
            _metaChip(
              Icons.star_rounded,
              'Chef-lieu',
              color: const Color(0xFF8A6B00),
            ),
          if (mayor.isNotEmpty) _metaChip(Icons.person_rounded, mayor),
        ];

        return _EntityCard(
          icon: c.isCapital
              ? Icons.star_rounded
              : Icons.location_city_rounded,
          color: c.isCapital ? const Color(0xFF8A6B00) : ThixPolicy.primary,
          title: c.name,
          metaLines: meta,
          media: media,
          onTap: () {
            HapticFeedback.lightImpact();
            _showDetailSheet(
              context,
              icon: c.isCapital
                  ? Icons.star_rounded
                  : Icons.location_city_rounded,
              color: c.isCapital ? const Color(0xFF8A6B00) : ThixPolicy.primary,
              title: c.name,
              badge: c.isCapital ? 'Chef-lieu de province' : null,
              headerPhotoUrl: mayorPhoto,
              chips: meta,
              sections: mayor.isNotEmpty
                  ? [
                      _DetailSection(
                        label: 'Autorité (Maire / Bourgmestre)',
                        content: mayor,
                        icon: Icons.person_rounded,
                      ),
                    ]
                  : [],
              media: media,
            );
          },
        );
      }).toList(),
    );
  }
}

// ============================================================================
// DÉCOUPAGE ADMINISTRATIF
// ============================================================================
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
        try {
          administrator = dyn.administrator?.toString() ?? '';
        } catch (_) {}
        List<Map<String, dynamic>> media = [];
        try {
          if (dyn.media != null) {
            media = List<Map<String, dynamic>>.from(dyn.media);
          }
        } catch (_) {}

        final meta = <Widget>[
          if (capital.isNotEmpty)
            _metaChip(Icons.star_rounded, 'Chef-lieu : $capital'),
          if (pop.isNotEmpty) _metaChip(Icons.groups_rounded, '$pop hab'),
          if (area.isNotEmpty) _metaChip(Icons.map_rounded, '$area km²'),
          if (administrator.isNotEmpty)
            _metaChip(Icons.person_rounded, administrator),
        ];

        return _EntityCard(
          icon: Icons.dashboard_customize_rounded,
          color: const Color(0xFF6A1B9A),
          title: name,
          badge: type,
          metaLines: meta,
          media: media,
          onTap: () {
            HapticFeedback.lightImpact();
            _showDetailSheet(
              context,
              icon: Icons.dashboard_customize_rounded,
              color: const Color(0xFF6A1B9A),
              title: name,
              badge: type,
              chips: meta,
              sections: administrator.isNotEmpty
                  ? [
                      _DetailSection(
                        label: 'Administrateur',
                        content: administrator,
                        icon: Icons.person_rounded,
                      ),
                    ]
                  : [],
              media: media,
            );
          },
        );
      }).toList(),
    );
  }
}

// ============================================================================
// TOURISME
// ============================================================================
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
        try {
          if (dyn.media != null) {
            media = List<Map<String, dynamic>>.from(dyn.media);
          }
        } catch (_) {}
        if (media.isEmpty) {
          try {
            if (dyn.imageUrl != null && dyn.imageUrl.toString().isNotEmpty) {
              media = [
                {'url': dyn.imageUrl, 'type': 'photo'}
              ];
            }
          } catch (_) {}
        }
        return _EntityCard(
          icon: Icons.landscape_rounded,
          color: const Color(0xFF1565C0),
          title: name,
          badge: type.isNotEmpty ? type : null,
          preview: desc,
          media: media,
          onTap: () {
            HapticFeedback.lightImpact();
            _showDetailSheet(
              context,
              icon: Icons.landscape_rounded,
              color: const Color(0xFF1565C0),
              title: name,
              badge: type,
              sections: desc.isNotEmpty
                  ? [
                      _DetailSection(
                        label: 'Description',
                        content: desc,
                        icon: Icons.notes_rounded,
                      ),
                    ]
                  : [],
              media: media,
            );
          },
        );
      }).toList(),
    );
  }
}

// ============================================================================
// ÉCONOMIE
// ============================================================================
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
        try {
          if (dyn.media != null) {
            media = List<Map<String, dynamic>>.from(dyn.media);
          }
        } catch (_) {}
        if (media.isEmpty) {
          try {
            if (dyn.imageUrl != null && dyn.imageUrl.toString().isNotEmpty) {
              media = [
                {'url': dyn.imageUrl, 'type': 'photo'}
              ];
            }
          } catch (_) {}
        }
        return _EntityCard(
          icon: Icons.monetization_on_rounded,
          color: const Color(0xFF2E7D32),
          title: name,
          preview: desc,
          media: media,
          onTap: () {
            HapticFeedback.lightImpact();
            _showDetailSheet(
              context,
              icon: Icons.monetization_on_rounded,
              color: const Color(0xFF2E7D32),
              title: name,
              sections: desc.isNotEmpty
                  ? [
                      _DetailSection(
                        label: 'Détails',
                        content: desc,
                        icon: Icons.notes_rounded,
                      ),
                    ]
                  : [],
              media: media,
            );
          },
        );
      }).toList(),
    );
  }
}

// ============================================================================
// CULTURE & TRIBUS
// ============================================================================
class _CultureAndTribesContent extends StatelessWidget {
  final Province province;

  const _CultureAndTribesContent({required this.province});

  @override
  Widget build(BuildContext context) {
    final tribes = province.tribes ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                        text: 'Langues parlées : ',
                        style: ThixPolicy.captionStyle.copyWith(
                          color: ThixPolicy.inkDeep,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(
                        text: province.languages!,
                        style: ThixPolicy.captionStyle.copyWith(
                          color: ThixPolicy.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        if (province.resources?.trim().isNotEmpty == true) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.diamond_rounded, size: 18, color: ThixPolicy.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Ressources principales : ',
                        style: ThixPolicy.captionStyle.copyWith(
                          color: ThixPolicy.inkDeep,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(
                        text: province.resources!,
                        style: ThixPolicy.captionStyle.copyWith(
                          color: ThixPolicy.textSecondary,
                        ),
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
            style: ThixPolicy.bodySmallStyle.copyWith(
              color: ThixPolicy.inkDeep,
              height: 1.5,
            ),
          ),
        ],
        if (tribes.isNotEmpty) ...[
          const SizedBox(height: 18),
          Divider(color: ThixPolicy.border),
          const SizedBox(height: 10),
          Text(
            'Peuples & Tribus de la Province',
            style: ThixPolicy.labelStyle.copyWith(
              color: ThixPolicy.inkDeep,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ...tribes.map((t) {
            final name = t['name']?.toString() ?? 'Tribu';
            final zone = t['zone']?.toString() ?? '';
            final history = t['history']?.toString() ?? '';
            final media = t['media'] != null
                ? List<Map<String, dynamic>>.from(t['media'])
                : <Map<String, dynamic>>[];
            return _EntityCard(
              icon: Icons.groups_rounded,
              color: ThixPolicy.primary,
              title: name,
              metaLines: zone.isNotEmpty
                  ? [_metaChip(Icons.place_rounded, zone)]
                  : [],
              preview: history,
              media: media,
              onTap: () {
                HapticFeedback.lightImpact();
                _showDetailSheet(
                  context,
                  icon: Icons.groups_rounded,
                  color: ThixPolicy.primary,
                  title: name,
                  chips: zone.isNotEmpty
                      ? [_metaChip(Icons.place_rounded, zone)]
                      : [],
                  sections: history.isNotEmpty
                      ? [
                          _DetailSection(
                            label: 'Histoire, origines & coutumes',
                            content: history,
                            icon: Icons.menu_book_rounded,
                          ),
                        ]
                      : [],
                  media: media,
                );
              },
            );
          }),
        ],
      ],
    );
  }
}

// ============================================================================
// MONOGRAPHIE
// ============================================================================
class _MonographyContent extends StatelessWidget {
  final Province province;

  const _MonographyContent({required this.province});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    if (province.history?.trim().isNotEmpty == true) {
      items.add(_buildItem(
        context,
        'Historique complet & Origines de la province',
        province.history!,
        Icons.menu_book_rounded,
      ));
    }
    if (province.climate?.trim().isNotEmpty == true) {
      items.add(_buildItem(
        context,
        'Climat, Relief & Environnement',
        province.climate!,
        Icons.wb_sunny_rounded,
      ));
    }
    if (province.infrastructure?.trim().isNotEmpty == true) {
      items.add(_buildItem(
        context,
        'Infrastructures, Transports & Énergie',
        province.infrastructure!,
        Icons.bolt_rounded,
      ));
    }
    if (province.education?.trim().isNotEmpty == true) {
      items.add(_buildItem(
        context,
        'Éducation, Recherche & Santé',
        province.education!,
        Icons.school_rounded,
      ));
    }

    return Column(children: items);
  }

  Widget _buildItem(
    BuildContext context,
    String label,
    String content,
    IconData icon,
  ) {
    final isLong = content.length > 200;
    return Semantics(
      button: isLong,
      child: InkWell(
        onTap: isLong
            ? () {
                HapticFeedback.lightImpact();
                _showTextSheet(
                  context,
                  title: label,
                  text: content,
                  icon: icon,
                  color: ThixPolicy.primary,
                );
              }
            : null,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: ThixPolicy.surfaceSoft,
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
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
                      style: ThixPolicy.captionStyle.copyWith(
                        color: ThixPolicy.inkDeep,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                content,
                maxLines: isLong ? 3 : null,
                overflow: isLong ? TextOverflow.ellipsis : TextOverflow.visible,
                style: ThixPolicy.bodySmallStyle.copyWith(
                  color: ThixPolicy.inkDeep,
                  height: 1.5,
                ),
              ),
              if (isLong)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Lire la suite',
                    style: ThixPolicy.microStyle.copyWith(
                      color: ThixPolicy.primary,
                      fontWeight: FontWeight.w800,
                    ),
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
// URGENCES
// ============================================================================
class _EmergencySection extends StatelessWidget {
  final List<dynamic> contacts;

  const _EmergencySection({required this.contacts});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: contacts.map((c) {
        final dyn = c as dynamic;
        final service =
            dyn.service?.toString() ?? dyn.serviceName?.toString() ?? 'Service';
        final phone =
            dyn.phone?.toString() ?? dyn.phoneNumber?.toString() ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: ThixPolicy.surfaceSoft,
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
            border: Border.all(
              color: ThixPolicy.danger.withOpacity(0.25),
            ),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ThixPolicy.danger.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.phone_in_talk_rounded,
                color: ThixPolicy.danger,
              ),
            ),
            title: Text(
              service,
              style: ThixPolicy.labelStyle.copyWith(
                color: ThixPolicy.inkDeep,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Text(
              phone,
              style: ThixPolicy.captionStyle.copyWith(
                color: ThixPolicy.inkDeep,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: phone.isNotEmpty
                ? Semantics(
                    button: true,
                    label: 'Appeler $service',
                    child: IconButton(
                      icon: Icon(
                        Icons.call_rounded,
                        color: const Color(0xFF2E7D32),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        launchUrl(Uri.parse('tel:$phone'));
                      },
                    ),
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }
}

// ============================================================================
// IDENTITÉ VISUELLE
// ============================================================================
class _VisualIdentityContent extends StatelessWidget {
  final Province province;

  const _VisualIdentityContent({required this.province});

  @override
  Widget build(BuildContext context) {
    final hasWebsite =
        province.website != null && province.website!.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _visualThumb(
                context,
                'Photo de couverture',
                province.coverImageUrl,
                Icons.image_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _visualThumb(
                context,
                'Blason / Armoiries',
                province.coatOfArmsUrl,
                Icons.shield_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _visualThumb(
                context,
                'Carte géographique',
                province.mapUrl,
                Icons.map_outlined,
              ),
            ),
          ],
        ),
        if (hasWebsite) ...[
          const SizedBox(height: 14),
          Semantics(
            button: true,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                _launchUrlSafe(province.website!);
              },
              borderRadius: BorderRadius.circular(ThixPolicy.rSm),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: ThixPolicy.surfaceSoft,
                  borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                  border: Border.all(color: ThixPolicy.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.language_rounded,
                      size: 16,
                      color: ThixPolicy.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      province.website!,
                      style: ThixPolicy.captionStyle.copyWith(
                        color: ThixPolicy.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _visualThumb(
    BuildContext context,
    String label,
    String? url,
    IconData fallbackIcon,
  ) {
    final hasImg = url != null && url.trim().isNotEmpty;
    return Semantics(
      button: hasImg,
      child: GestureDetector(
        onTap: hasImg
            ? () {
                HapticFeedback.lightImpact();
                _openMediaGallery(
                  context,
                  [
                    {'url': url, 'type': 'photo'}
                  ],
                  title: label,
                );
              }
            : null,
        child: Column(
          children: [
            Container(
              height: 74,
              width: double.infinity,
              decoration: BoxDecoration(
                color: ThixPolicy.surfaceSoft,
                borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                border: Border.all(color: ThixPolicy.border),
              ),
              child: hasImg
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                      child: _buildCachedImage(url, fit: BoxFit.cover),
                    )
                  : Icon(
                      fallbackIcon,
                      color: ThixPolicy.textMuted.withOpacity(0.4),
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: ThixPolicy.microStyle.copyWith(
                color: ThixPolicy.textMuted,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// UTILITAIRES UI
// ============================================================================
Widget _metaChip(
  IconData icon,
  String text, {
  Color color = ThixPolicy.primary,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );
}

class _DetailSection {
  final String label;
  final String content;
  final IconData icon;

  const _DetailSection({
    required this.label,
    required this.content,
    this.icon = Icons.notes_rounded,
  });
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
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: ThixPolicy.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Row(
                    children: [
                      if (headerPhotoUrl != null &&
                          headerPhotoUrl.trim().isNotEmpty)
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: color, width: 2),
                          ),
                          child: ClipOval(
                            child: _buildCachedImage(headerPhotoUrl),
                          ),
                        )
                      else
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(icon, color: color, size: 26),
                        ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: ThixPolicy.h3Style.copyWith(
                                color: ThixPolicy.inkDeep,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (badge != null && badge.trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  badge,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: color,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (chips.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: chips,
                    ),
                  ],
                  for (final s in sections) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Icon(s.icon, size: 16, color: color),
                        const SizedBox(width: 6),
                        Text(
                          s.label,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.content,
                      style: ThixPolicy.bodySmallStyle.copyWith(
                        color: ThixPolicy.inkDeep,
                        height: 1.55,
                      ),
                    ),
                  ],
                  if (media.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Photos & Vidéos (${media.length})',
                          style: ThixPolicy.labelStyle.copyWith(
                            color: ThixPolicy.inkDeep,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            _openMediaGrid(context, media, title: title);
                          },
                          child: Text(
                            'Voir tout',
                            style: ThixPolicy.captionStyle.copyWith(
                              color: ThixPolicy.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: media.length,
                      itemBuilder: (_, i) {
                        final m = media[i];
                        final isVideo = m['type'] == 'video';
                        return Semantics(
                          button: true,
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _openMediaGallery(
                                context,
                                media,
                                initialIndex: i,
                                title: title,
                              );
                            },
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(ThixPolicy.rSm),
                              child: isVideo
                                  ? Container(
                                      color: ThixPolicy.primary,
                                      child: Icon(
                                        Icons.play_arrow_rounded,
                                        color: Colors.white,
                                      ),
                                    )
                                  : _buildCachedImage(m['url']?.toString() ?? ''),
                            ),
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

void _showTextSheet(
  BuildContext context, {
  required String title,
  required String text,
  required IconData icon,
  required Color color,
}) {
  _showDetailSheet(
    context,
    icon: icon,
    color: color,
    title: title,
    sections: [
      _DetailSection(label: title, content: text, icon: icon),
    ],
  );
}

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
    required this.icon,
    required this.color,
    required this.title,
    this.badge,
    this.metaLines = const [],
    this.preview,
    this.media = const [],
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: ThixPolicy.surfaceSoft,
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
            border: Border.all(color: ThixPolicy.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: ThixPolicy.labelStyle.copyWith(
                                  color: ThixPolicy.inkDeep,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (badge != null && badge!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: ThixPolicy.card,
                                  border: Border.all(color: ThixPolicy.border),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  badge!,
                                  style: ThixPolicy.microStyle.copyWith(
                                    color: ThixPolicy.textMuted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (metaLines.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: metaLines,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: ThixPolicy.textMuted,
                  ),
                ],
              ),
              if (preview != null && preview!.trim().isNotEmpty) ...[
                const SizedBox(height: 9),
                Text(
                  preview!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ThixPolicy.captionStyle.copyWith(
                    color: ThixPolicy.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
              if (media.isNotEmpty) ...[
                const SizedBox(height: 9),
                _MediaStrip(
                  media: media,
                  onTapItem: (i) {
                    HapticFeedback.lightImpact();
                    _openMediaGallery(
                      context,
                      media,
                      initialIndex: i,
                      title: title,
                    );
                  },
                ),
              ],
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Voir plus',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
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
            Semantics(
              button: true,
              child: GestureDetector(
                onTap: () => onTapItem(i),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                      child: shown[i]['type'] == 'video'
                          ? Container(
                              width: 56,
                              height: 56,
                              color: ThixPolicy.primary,
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                              ),
                            )
                          : _buildCachedImage(
                              shown[i]['url']?.toString() ?? '',
                              width: 56,
                              height: 56,
                            ),
                    ),
                    if (i == shown.length - 1 && remaining > 0)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius:
                                BorderRadius.circular(ThixPolicy.rSm),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '+$remaining',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _MapContent extends StatelessWidget {
  final String url;
  final String provinceName;

  const _MapContent({required this.url, required this.provinceName});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          _openMediaGallery(
            context,
            [
              {'url': url, 'type': 'photo'}
            ],
            title: 'Carte — $provinceName',
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          child: Stack(
            children: [
              _buildCachedImage(url, height: 200, width: double.infinity),
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.zoom_in_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
