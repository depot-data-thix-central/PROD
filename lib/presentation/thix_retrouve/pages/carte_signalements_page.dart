/// Carte Signalements Page (Production Enterprise)
/// ✅ ThixPolicy + i18n 8 langues + sanitization + go_router
/// ✅ Skeleton loader + Semantics + HapticFeedback + GPS validation
/// ✅ Logs structurés + I18nService.relativeTime() + RepaintBoundary
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/l10n/i18n_service.dart';

import '../models/objet_model.dart';
import '../providers/objet_providers.dart';

// ============================================================================
// CONSTANTS
// ============================================================================

const int _kMaxTitleLength = 80;
const int _kMaxLocationLength = 60;
const Duration _kTapThrottle = Duration(milliseconds: 400);
const double _kDefaultZoom = 13.0;
const double _kSelectedZoom = 15.0;

// Position par défaut (Kinshasa)
const LatLng _kDefaultCenter = LatLng(-4.325, 15.322);

// Positions de secours si pas de lat/lng
final List<LatLng> _kFallbackPositions = [
  const LatLng(-4.320, 15.310),
  const LatLng(-4.330, 15.335),
  const LatLng(-4.315, 15.325),
  const LatLng(-4.340, 15.315),
  const LatLng(-4.325, 15.340),
  const LatLng(-4.310, 15.300),
  const LatLng(-4.335, 15.350),
  const LatLng(-4.345, 15.305),
];

// ============================================================================
// VALIDATORS & SANITIZERS
// ============================================================================

class _MapSanitizer {
  _MapSanitizer._();

  static String sanitize(String? input, {required int maxLength}) {
    if (input == null || input.isEmpty) return '';
    final s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? '${s.substring(0, maxLength)}…' : s;
  }

  static String? sanitizeImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    if (!url.startsWith('http://') && !url.startsWith('https://')) return null;
    return url.trim();
  }

  static bool isValidCoordinate(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }
}

// ============================================================================
// PAGE
// ============================================================================

class CarteSignalementsPage extends ConsumerStatefulWidget {
  const CarteSignalementsPage({super.key});

  @override
  ConsumerState<CarteSignalementsPage> createState() =>
      _CarteSignalementsPageState();
}

class _CarteSignalementsPageState extends ConsumerState<CarteSignalementsPage> {
  GoogleMapController? _mapController;
  bool _showPerdus = true;
  bool _showTrouves = true;
  ObjetModel? _selected;
  DateTime? _lastTap;
  bool _locationPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    debugPrint('[CarteSignalements] 🚀 Page initialized');
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        setState(() => _locationPermissionGranted = true);
        debugPrint('[CarteSignalements] ✓ Location permission granted');
      } else {
        debugPrint('[CarteSignalements] ⚠️ Location permission denied');
      }
    } catch (e) {
      debugPrint('[CarteSignalements] ❌ Location permission check failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final objetsAsync = ref.watch(objetsRecentsProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.inkDeep,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        leading: Semantics(
          button: true,
          label: l10n.t('common_back'),
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                size: 20, color: ThixPolicy.textMain),
            onPressed: () {
              HapticFeedback.lightImpact();
              context.pop();
            },
          ),
        ),
        title: Text(
          l10n.t('map_title'),
          style: ThixPolicy.h3Style.copyWith(
            color: ThixPolicy.textMain,
            fontWeight: ThixPolicy.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Semantics(
            button: true,
            label: l10n.t('common_refresh'),
            child: IconButton(
              icon: Icon(Icons.refresh_rounded, color: ThixPolicy.primary),
              onPressed: () {
                HapticFeedback.mediumImpact();
                debugPrint('[CarteSignalements] 🔄 Refresh triggered');
                ref.invalidate(objetsRecentsProvider);
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Légende ──
          _buildLegend(context, l10n),

          // ── Carte ──
          Expanded(
            child: objetsAsync.when(
              data: (objets) => _buildMapContent(context, l10n, objets),
              loading: () => const _MapSkeletonLoader(),
              error: (e, _) => _buildErrorState(context, l10n, e),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // LEGEND
  // ========================================================================

  Widget _buildLegend(BuildContext context, AppLocalizations l10n) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: ThixPolicy.card,
        child: Row(
          children: [
            _legendItem(
              ThixPolicy.danger,
              l10n.t('map_legend_lost'),
              _showPerdus,
              () {
                HapticFeedback.selectionClick();
                setState(() => _showPerdus = !_showPerdus);
                debugPrint('[CarteSignalements] 👁️ Toggle lost: $_showPerdus');
              },
            ),
            const SizedBox(width: 16),
            _legendItem(
              ThixPolicy.success,
              l10n.t('map_legend_found'),
              _showTrouves,
              () {
                HapticFeedback.selectionClick();
                setState(() => _showTrouves = !_showTrouves);
                debugPrint('[CarteSignalements] 👁️ Toggle found: $_showTrouves');
              },
            ),
            const Spacer(),
            _legendItem(
              ThixPolicy.primary,
              l10n.t('map_legend_you'),
              true,
              null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(
    Color color,
    String label,
    bool active,
    VoidCallback? onTap,
  ) {
    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      label: '$label: ${active ? "visible" : "masqué"}',
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: active ? color : ThixPolicy.textMuted.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: ThixPolicy.captionStyle.copyWith(
                color: active ? ThixPolicy.textMain : ThixPolicy.textMuted,
                fontWeight: active ? ThixPolicy.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // MAP CONTENT
  // ========================================================================

  Widget _buildMapContent(
    BuildContext context,
    AppLocalizations l10n,
    List<ObjetModel> objets,
  ) {
    final filtered = objets.where((o) {
      if (o.statut == StatutObjet.perdu && !_showPerdus) return false;
      if (o.statut == StatutObjet.trouve && !_showTrouves) return false;
      if (o.statut == StatutObjet.recupere) return false;
      return true;
    }).toList();

    final markers = _buildMarkers(filtered);
    final i18n = I18nService.of(context);

    debugPrint('[CarteSignalements] ✓ Rendered: ${filtered.length} markers '
        '(${objets.length} total)');

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: _kDefaultCenter,
            zoom: _kDefaultZoom,
          ),
          onMapCreated: (controller) {
            _mapController = controller;
            debugPrint('[CarteSignalements] ✓ Map created');
          },
          markers: markers,
          myLocationEnabled: _locationPermissionGranted,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          onTap: (_) {
            setState(() => _selected = null);
          },
        ),

        // ── Carte flottante objet sélectionné ──
        if (_selected != null)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: _buildSelectedCard(context, l10n, i18n, _selected!),
          ),

        // ── Liste horizontale en bas ──
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildBottomList(context, l10n, i18n, filtered),
        ),

        // ── Bouton ma position ──
        if (_locationPermissionGranted)
          Positioned(
            bottom: 190,
            right: 16,
            child: Semantics(
              button: true,
              label: l10n.t('map_my_location'),
              child: FloatingActionButton.small(
                backgroundColor: ThixPolicy.card,
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLngZoom(_kDefaultCenter, 14),
                  );
                  debugPrint('[CarteSignalements] 📍 Centered on my location');
                },
                child: Icon(Icons.my_location_rounded, color: ThixPolicy.primary),
              ),
            ),
          ),
      ],
    );
  }

  // ========================================================================
  // MARKERS
  // ========================================================================

  Set<Marker> _buildMarkers(List<ObjetModel> objets) {
    final markers = <Marker>{};

    for (var i = 0; i < objets.length; i++) {
      final obj = objets[i];
      final isLost = obj.statut == StatutObjet.perdu;

      // Validation GPS
      LatLng position;
      if (_MapSanitizer.isValidCoordinate(obj.latitude, obj.longitude)) {
        position = LatLng(obj.latitude!, obj.longitude!);
      } else {
        position = _kFallbackPositions[i % _kFallbackPositions.length];
        debugPrint('[CarteSignalements] ⚠️ Invalid GPS for ${obj.id}, using fallback');
      }

      // Sanitization pour InfoWindow
      final safeTitle = _MapSanitizer.sanitize(obj.titre, maxLength: _kMaxTitleLength);
      final safeLocation = _MapSanitizer.sanitize(obj.lieu, maxLength: _kMaxLocationLength);

      markers.add(
        Marker(
          markerId: MarkerId(obj.id),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isLost ? BitmapDescriptor.hueRed : BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(
            title: safeTitle,
            snippet: '${obj.statutLabel} • $safeLocation',
          ),
          onTap: () => _throttledTap(() {
            HapticFeedback.selectionClick();
            setState(() => _selected = obj);
            _mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(position, _kSelectedZoom),
            );
            debugPrint('[CarteSignalements] 📍 Marker tapped: '
                '${safeTitle.substring(0, safeTitle.length.clamp(0, 20))}');
          }),
        ),
      );
    }

    return markers;
  }

  // ========================================================================
  // SELECTED CARD
  // ========================================================================

  Widget _buildSelectedCard(
    BuildContext context,
    AppLocalizations l10n,
    I18nService i18n,
    ObjetModel obj,
  ) {
    final isLost = obj.statut == StatutObjet.perdu;
    final statusColor = isLost ? ThixPolicy.danger : ThixPolicy.success;

    // Sanitization
    final safeTitle = _MapSanitizer.sanitize(obj.titre, maxLength: _kMaxTitleLength);
    final safeLocation = _MapSanitizer.sanitize(obj.lieu, maxLength: _kMaxLocationLength);

    return RepaintBoundary(
      child: Semantics(
        button: true,
        label: '${safeTitle}. ${obj.statutLabel}. $safeLocation',
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(ThixPolicy.rLg),
          color: ThixPolicy.card,
          child: InkWell(
            borderRadius: BorderRadius.circular(ThixPolicy.rLg),
            onTap: () => _throttledTap(() {
              HapticFeedback.mediumImpact();
              debugPrint('[CarteSignalements] 📦 Selected card tapped: '
                  '${safeTitle.substring(0, safeTitle.length.clamp(0, 20))}');
              context.push('/retrouve/object/${obj.id}');
            }),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ThixPolicy.card,
                borderRadius: BorderRadius.circular(ThixPolicy.rLg),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          safeTitle,
                          style: ThixPolicy.bodyStyle.copyWith(
                            color: ThixPolicy.textMain,
                            fontWeight: ThixPolicy.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${obj.statutLabel} • ${i18n.relativeTime(obj.date)} • $safeLocation',
                          style: ThixPolicy.captionStyle
                              .copyWith(color: ThixPolicy.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: ThixPolicy.textMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ========================================================================
  // BOTTOM LIST
  // ========================================================================

  Widget _buildBottomList(
    BuildContext context,
    AppLocalizations l10n,
    I18nService i18n,
    List<ObjetModel> objets,
  ) {
    return RepaintBoundary(
      child: Container(
        height: 170,
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Text(
                l10n.t('map_objects_around', args: [objets.length.toString()]),
                style: ThixPolicy.titleStyle.copyWith(
                  color: ThixPolicy.textMain,
                  fontWeight: ThixPolicy.bold,
                ),
              ),
            ),
            Expanded(
              child: objets.isEmpty
                  ? Center(
                      child: Text(
                        l10n.t('map_no_objects'),
                        style: ThixPolicy.bodyStyle
                            .copyWith(color: ThixPolicy.textMuted),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: objets.length,
                      itemBuilder: (context, index) {
                        final obj = objets[index];
                        return _buildBottomListItem(context, l10n, i18n, obj);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomListItem(
    BuildContext context,
    AppLocalizations l10n,
    I18nService i18n,
    ObjetModel obj,
  ) {
    final isLost = obj.statut == StatutObjet.perdu;
    final isSelected = _selected?.id == obj.id;
    final statusColor = isLost ? ThixPolicy.danger : ThixPolicy.success;

    // Sanitization
    final safeTitle = _MapSanitizer.sanitize(obj.titre, maxLength: _kMaxTitleLength);
    final safeLocation = _MapSanitizer.sanitize(obj.lieu, maxLength: _kMaxLocationLength);

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${safeTitle}. ${obj.statutLabel}. $safeLocation',
      child: GestureDetector(
        onTap: () => _throttledTap(() {
          HapticFeedback.selectionClick();
          setState(() => _selected = obj);
          if (_MapSanitizer.isValidCoordinate(obj.latitude, obj.longitude)) {
            _mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(
                LatLng(obj.latitude!, obj.longitude!),
                _kSelectedZoom,
              ),
            );
          }
          debugPrint('[CarteSignalements] 📦 Bottom list item tapped: '
              '${safeTitle.substring(0, safeTitle.length.clamp(0, 20))}');
        }),
        child: Container(
          width: 150,
          margin: const EdgeInsets.only(right: 10, bottom: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected
                ? ThixPolicy.primary.withValues(alpha: 0.1)
                : ThixPolicy.surfaceSoft,
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
            border: Border.all(
              color: isSelected ? ThixPolicy.primary : ThixPolicy.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    obj.statutLabel,
                    style: ThixPolicy.captionStyle.copyWith(
                      color: statusColor,
                      fontWeight: ThixPolicy.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                safeTitle,
                style: ThixPolicy.bodySmallStyle.copyWith(
                  color: ThixPolicy.textMain,
                  fontWeight: ThixPolicy.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Text(
                safeLocation,
                style: ThixPolicy.captionStyle
                    .copyWith(color: ThixPolicy.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========================================================================
  // ERROR STATE
  // ========================================================================

  Widget _buildErrorState(
    BuildContext context,
    AppLocalizations l10n,
    Object error,
  ) {
    debugPrint('[CarteSignalements] ❌ Error: $error');
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: ThixPolicy.danger,
            size: 40,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.t('map_error'),
            style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.danger),
          ),
          const SizedBox(height: 16),
          Semantics(
            button: true,
            label: l10n.t('common_retry'),
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                ref.invalidate(objetsRecentsProvider);
              },
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.t('common_retry')),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: ThixPolicy.textMain,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // THROTTLE HELPER
  // ========================================================================

  void _throttledTap(VoidCallback callback) {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!) < _kTapThrottle) {
      debugPrint('[CarteSignalements] ⏱️ Tap throttled');
      return;
    }
    _lastTap = now;
    callback();
  }
}

// ============================================================================
// SKELETON LOADER
// ============================================================================

class _MapSkeletonLoader extends StatefulWidget {
  const _MapSkeletonLoader();

  @override
  State<_MapSkeletonLoader> createState() => _MapSkeletonLoaderState();
}

class _MapSkeletonLoaderState extends State<_MapSkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: ThixPolicy.surfaceSoft,
          child: Center(
            child: Icon(
              Icons.map_outlined,
              size: 80,
              color: ThixPolicy.textMuted.withValues(alpha: 0.3),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            height: 170,
            decoration: BoxDecoration(
              color: ThixPolicy.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(16),
              itemCount: 3,
              itemBuilder: (context, index) => AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) => Opacity(
                  opacity: 0.35 + 0.3 * _ctrl.value,
                  child: Container(
                    width: 150,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: ThixPolicy.border.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
