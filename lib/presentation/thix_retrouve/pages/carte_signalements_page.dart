/// Carte Signalements Page (Production Enterprise)
/// ✅ FIX 1 : Web-safe — GoogleMap monté seulement si clé API dispo,
///    sinon panneau de repli (plus de crash "Null check operator")
/// ✅ FIX 2 : _tr() fallbacks → plus jamais de clé l10n brute
/// ✅ FIX 3 : navigation corrigée → pushNamed('thixRetrouveDetail', extra: …)
/// ✅ FIX 4 : thème clair unifié (fond #F7F9FC)
/// ✅ Skeleton loader + Semantics + HapticFeedback + GPS validation + throttle
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
// DESIGN TOKENS (Light Premium — cohérent RETROUVE / Detail / Recherches)
// ============================================================================

const Color _kBg = Color(0xFFF7F9FC);
const Color _kSurface = Color(0xFFFFFFFF);
const Color _kTextMain = Color(0xFF12233D);
const Color _kTextSec = Color(0xFF5A6B84);
const Color _kTextMuted = Color(0xFF93A1B5);
const Color _kBorder = Color(0xFFE5EAF1);
const Color _kSkeleton = Color(0xFFE8EDF3);

// ============================================================================
// CONSTANTS
// ============================================================================

const int _kMaxTitleLength = 80;
const int _kMaxLocationLength = 60;
const Duration _kTapThrottle = Duration(milliseconds: 400);
const double _kDefaultZoom = 13.0;
const double _kSelectedZoom = 15.0;

/// 🔑 Clé Google Maps injectée au build :
///    flutter build web --release --dart-define=GOOGLE_MAPS_API_KEY=xxx
///    (+ script <script src="https://maps.googleapis.com/maps/api/js?key=…">
///     dans web/index.html)
const String _kMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

/// Sur Web, google_maps_flutter CRASHE ("Null check operator…") sans clé.
/// On ne monte la carte que si la clé est présente.
bool get _canUseGoogleMap => !kIsWeb || _kMapsApiKey.isNotEmpty;

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

  /// 🛡️ Traduction sûre : fallback FR si clé absente (jamais de clé brute)
  String _tr(AppLocalizations l10n, String key, String fallback) {
    final v = l10n.t(key);
    return (v == key || v.trim().isEmpty) ? fallback : v;
  }

  /// Libellé "X objets autour de vous" avec fallback sûr (gère args)
  String _objectsAroundLabel(AppLocalizations l10n, int n) {
    final v = l10n.t('map_objects_around', args: [n.toString()]);
    if (v == 'map_objects_around' || v.trim().isEmpty || v.contains('{')) {
      return '$n objets autour de vous';
    }
    return v;
  }

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
        if (!mounted) return;
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
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Semantics(
          button: true,
          label: _tr(l10n, 'common_back', 'Retour'),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 20, color: _kTextMain),
            onPressed: () {
              HapticFeedback.lightImpact();
              context.pop();
            },
          ),
        ),
        title: Text(
          _tr(l10n, 'map_title', 'Carte des signalements'),
          style: ThixPolicy.h3Style.copyWith(
            color: _kTextMain,
            fontWeight: ThixPolicy.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Semantics(
            button: true,
            label: _tr(l10n, 'common_refresh', 'Actualiser'),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded,
                  color: ThixPolicy.primary),
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

          // ── Carte / repli ──
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
  // LEGEND (clair)
  // ========================================================================

  Widget _buildLegend(BuildContext context, AppLocalizations l10n) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          color: _kSurface,
          border: Border(bottom: BorderSide(color: _kBorder)),
        ),
        child: Row(
          children: [
            _legendItem(
              ThixPolicy.danger,
              _tr(l10n, 'map_legend_lost', 'Perdus'),
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
              _tr(l10n, 'map_legend_found', 'Trouvés'),
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
              _tr(l10n, 'map_legend_you', 'Vous'),
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
                color: active ? color : _kTextMuted.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: ThixPolicy.captionStyle.copyWith(
                color: active ? _kTextMain : _kTextMuted,
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
        // ✅ GARDE WEB : pas de GoogleMap sans clé → plus de crash null-check
        if (_canUseGoogleMap)
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
          )
        else
          _buildMapUnavailable(l10n),

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
        if (_locationPermissionGranted && _canUseGoogleMap)
          Positioned(
            bottom: 190,
            right: 16,
            child: Semantics(
              button: true,
              label: _tr(l10n, 'map_my_location', 'Ma position'),
              child: FloatingActionButton.small(
                backgroundColor: _kSurface,
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLngZoom(_kDefaultCenter, 14),
                  );
                  debugPrint('[CarteSignalements] 📍 Centered on my location');
                },
                child: const Icon(Icons.my_location_rounded,
                    color: ThixPolicy.primary),
              ),
            ),
          ),
      ],
    );
  }

  // ========================================================================
  // REPLI SANS GOOGLE MAPS (Web sans clé)
  // ========================================================================

  Widget _buildMapUnavailable(AppLocalizations l10n) {
    return Container(
      color: _kBg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.map_outlined,
                size: 64,
                color: _kTextMuted.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                _tr(l10n, 'map_unavailable_title', 'Carte indisponible'),
                style: ThixPolicy.bodyStyle.copyWith(
                  color: _kTextMain,
                  fontWeight: ThixPolicy.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _tr(
                  l10n,
                  'map_unavailable_msg',
                  'La carte nécessite une clé Google Maps. '
                      'Utilisez la liste des objets ci-dessous.',
                ),
                style: ThixPolicy.captionStyle.copyWith(color: _kTextSec),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
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
      final safeTitle =
          _MapSanitizer.sanitize(obj.titre, maxLength: _kMaxTitleLength);
      final safeLocation =
          _MapSanitizer.sanitize(obj.lieu, maxLength: _kMaxLocationLength);

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
    final safeTitle =
        _MapSanitizer.sanitize(obj.titre, maxLength: _kMaxTitleLength);
    final safeLocation =
        _MapSanitizer.sanitize(obj.lieu, maxLength: _kMaxLocationLength);
    final safeDescription =
        _MapSanitizer.sanitize(obj.description, maxLength: 500);
    final safeReward =
        _MapSanitizer.sanitize(obj.recompense ?? '', maxLength: 50);
    final safeImageUrl = _MapSanitizer.sanitizeImageUrl(obj.imageUrl);

    return RepaintBoundary(
      child: Semantics(
        button: true,
        label: '${safeTitle}. ${obj.statutLabel}. $safeLocation',
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(ThixPolicy.rLg),
          color: _kSurface,
          child: InkWell(
            borderRadius: BorderRadius.circular(ThixPolicy.rLg),
            onTap: () => _throttledTap(() {
              HapticFeedback.mediumImpact();
              debugPrint('[CarteSignalements] 📦 Selected card tapped: '
                  '${safeTitle.substring(0, safeTitle.length.clamp(0, 20))}');
              // ✅ FIX ROUTE : route nommée + extra complet (plus de 404)
              context.pushNamed(
                'thixRetrouveDetail',
                extra: {
                  'title': safeTitle,
                  'status': obj.statutLabel,
                  'location': safeLocation,
                  'time': i18n.relativeTime(obj.date),
                  'description': safeDescription,
                  'reward': safeReward,
                  'contact': obj.contactInfo ?? '',
                  'imageUrl': safeImageUrl,
                },
              );
            }),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kSurface,
                borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                border: Border.all(color: _kBorder),
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
                            color: _kTextMain,
                            fontWeight: ThixPolicy.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${obj.statutLabel} • ${i18n.relativeTime(obj.date)} • $safeLocation',
                          style: ThixPolicy.captionStyle
                              .copyWith(color: _kTextSec),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: _kTextMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ========================================================================
  // BOTTOM LIST (clair)
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
        decoration: const BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: _kBorder)),
          boxShadow: [
            BoxShadow(
              color: Color(0x0A0F172A),
              blurRadius: 12,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Text(
                _objectsAroundLabel(l10n, objets.length),
                style: ThixPolicy.titleStyle.copyWith(
                  color: _kTextMain,
                  fontWeight: ThixPolicy.bold,
                ),
              ),
            ),
            Expanded(
              child: objets.isEmpty
                  ? Center(
                      child: Text(
                        _tr(l10n, 'map_no_objects', 'Aucun objet à proximité'),
                        style: ThixPolicy.bodyStyle
                            .copyWith(color: _kTextMuted),
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
    final safeTitle =
        _MapSanitizer.sanitize(obj.titre, maxLength: _kMaxTitleLength);
    final safeLocation =
        _MapSanitizer.sanitize(obj.lieu, maxLength: _kMaxLocationLength);

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
                ? ThixPolicy.primary.withValues(alpha: 0.10)
                : _kBg,
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
            border: Border.all(
              color: isSelected ? ThixPolicy.primary : _kBorder,
              width: isSelected ? 1.5 : 1.2,
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
                  color: _kTextMain,
                  fontWeight: ThixPolicy.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Text(
                safeLocation,
                style: ThixPolicy.captionStyle.copyWith(color: _kTextMuted),
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
  // ERROR STATE (clair)
  // ========================================================================

  Widget _buildErrorState(
    BuildContext context,
    AppLocalizations l10n,
    Object error,
  ) {
    debugPrint('[CarteSignalements] ❌ Error: $error');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
              _tr(l10n, 'map_error', 'Chargement de la carte impossible'),
              style: ThixPolicy.bodyStyle.copyWith(color: _kTextSec),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Semantics(
              button: true,
              label: _tr(l10n, 'common_retry', 'Réessayer'),
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  ref.invalidate(objetsRecentsProvider);
                },
                icon: const Icon(Icons.refresh_rounded),
                label: Text(_tr(l10n, 'common_retry', 'Réessayer')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
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
// SKELETON LOADER (clair)
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
          color: _kBg,
          child: Center(
            child: Icon(
              Icons.map_outlined,
              size: 80,
              color: _kTextMuted.withValues(alpha: 0.4),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            height: 170,
            decoration: const BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(top: BorderSide(color: _kBorder)),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(16),
              itemCount: 3,
              itemBuilder: (context, index) => AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) => Opacity(
                  opacity: 0.5 + 0.3 * _ctrl.value,
                  child: Container(
                    width: 150,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: _kSkeleton,
                      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                      border: Border.all(color: _kBorder),
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
