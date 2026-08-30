// lib/presentation/thix_market/delivery/pickup_points_page.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'delivery_provider.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const double _kDefaultLat = -4.322447; // Kinshasa (fallback)
const double _kDefaultLng = 15.307045;
const double _kDefaultZoom = 13.0;
const double _kFocusedZoom = 15.0;
const int _kMaxNameLength = 80;
const int _kMaxAddressLength = 200;
const int _kMaxHoursLength = 60;
const int _kPreviewCount = 3;

// ============================================================================
// VALIDATEURS
// ============================================================================
class _PickupValidators {
  _PickupValidators._();

  static bool isValidId(String? id) {
    if (id == null || id.trim().isEmpty) return false;
    return RegExp(r'^[0-9a-zA-Z_\-]{2,}$').hasMatch(id.trim());
  }

  /// Valide et normalise des coordonnées GPS (évite crash Google Maps)
  static LatLng? safeLatLng(dynamic lat, dynamic lng) {
    final latNum = (lat as num?)?.toDouble();
    final lngNum = (lng as num?)?.toDouble();
    if (latNum == null || lngNum == null) return null;
    if (latNum.isNaN || lngNum.isNaN) return null;
    if (latNum.isInfinite || lngNum.isInfinite) return null;
    if (latNum < -90 || latNum > 90) return null;
    if (lngNum < -180 || lngNum > 180) return null;
    return LatLng(latNum, lngNum);
  }

  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static double safeDouble(dynamic v, {double fallback = 0.0}) {
    if (v == null) return fallback;
    final parsed = (v as num?)?.toDouble() ?? fallback;
    return parsed < 0 || parsed.isNaN || parsed.isInfinite ? fallback : parsed;
  }

  static String formatDistance(double km, String locale) {
    if (km < 0 || km.isNaN || km.isInfinite) return '0';
    try {
      if (km < 1) {
        final meters = (km * 1000).round();
        return '$meters m';
      }
      return NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: 1).format(km);
    } catch (_) {
      return km < 1 ? '${(km * 1000).round()} m' : km.toStringAsFixed(1);
    }
  }

  static String friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('permission') || msg.contains('location')) return 'Permission de localisation requise.';
    return 'Une erreur est survenue. Réessayez.';
  }
}

// ============================================================================
// LOCALIZATION HELPER
// ============================================================================
extension _PickupL10n on BuildContext {
  String pickT(String fr, String en) {
    final lang = Localizations.localeOf(this).languageCode;
    return lang == 'fr' ? fr : en;
  }

  String get localeCode => Localizations.localeOf(this).languageCode;
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class PickupPointsPage extends StatefulWidget {
  final Function(Map<String, dynamic>)? onPointSelected;

  const PickupPointsPage({super.key, this.onPointSelected});

  @override
  State<PickupPointsPage> createState() => _PickupPointsPageState();
}

class _PickupPointsPageState extends State<PickupPointsPage> {
  GoogleMapController? _mapController;
  LatLng? _userLocation;
  String? _selectedPointId;
  bool _isSelecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    debugPrint('[PickupPoints] 📍 Page opened');
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  @override
  void dispose() {
    _mapController?.dispose();
    debugPrint('[PickupPoints] 👋 Page disposed');
    super.dispose();
  }

  Future<void> _initialize() async {
    if (!mounted) return;
    try {
      final provider = context.read<DeliveryProvider>();
      await provider.loadNearbyPickupPoints();

      if (!mounted) return;

      if (provider.currentPosition != null) {
        final userLoc = _PickupValidators.safeLatLng(
          provider.currentPosition!.latitude,
          provider.currentPosition!.longitude,
        );
        if (userLoc != null) {
          setState(() => _userLocation = userLoc);
          debugPrint('[PickupPoints] ✓ User location set');
        }
      }
    } catch (e) {
      debugPrint('[PickupPoints] ❌ Init error: $e');
      if (mounted) {
        setState(() => _error = _PickupValidators.friendlyError(e));
      }
    }
  }

  Future<void> _retry() async {
    HapticFeedback.mediumImpact();
    setState(() => _error = null);
    await _initialize();
  }

  void _onMapCreated(GoogleMapController controller) {
    if (!mounted) return;
    _mapController = controller;
    debugPrint('[PickupPoints] ✅ Map ready');
    _focusOnUser();
  }

  Future<void> _focusOnUser() async {
    if (!mounted || _userLocation == null) return;
    try {
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_userLocation!, _kDefaultZoom),
      );
    } catch (e) {
      debugPrint('[PickupPoints] ⚠️ Focus user error: $e');
    }
  }

  Future<void> _focusOnPoint(LatLng position) async {
    if (!mounted) return;
    HapticFeedback.selectionClick();
    try {
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(position, _kFocusedZoom),
      );
    } catch (e) {
      debugPrint('[PickupPoints] ⚠️ Focus point error: $e');
    }
  }

  Set<Marker> _buildMarkers(DeliveryProvider provider) {
    final markers = <Marker>{};

    // Marqueur utilisateur
    if (_userLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('user'),
        position: _userLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(title: context.pickT('Votre position', 'Your location')),
        zIndex: 2,
      ));
    }

    // Marqueurs points relais (avec validation coordonnées)
    for (final point in provider.pickupPoints) {
      final position = _PickupValidators.safeLatLng(point['latitude'], point['longitude']);
      if (position == null) {
        debugPrint('[PickupPoints] ⚠️ Invalid coords for point ${point['id']}, skipped');
        continue;
      }

      final name = _PickupValidators.sanitize(point['name']?.toString(), maxLength: _kMaxNameLength);
      final address = _PickupValidators.sanitize(point['address']?.toString(), maxLength: _kMaxAddressLength);
      final pointId = point['id']?.toString() ?? '';

      markers.add(Marker(
        markerId: MarkerId(pointId),
        position: position,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(title: name.isEmpty ? context.pickT('Point relais', 'Pickup point') : name, snippet: address),
        onTap: () => _showPointDetails(point),
        zIndex: 1,
      ));
    }

    return markers;
  }

  // ============================================================
  // POINT DETAILS BOTTOM SHEET
  // ============================================================
  void _showPointDetails(Map<String, dynamic> point) {
    final pointId = point['id']?.toString();
    if (!_PickupValidators.isValidId(pointId)) {
      _showError(context.pickT('Point relais invalide', 'Invalid pickup point'));
      return;
    }

    HapticFeedback.selectionClick();
    setState(() => _selectedPointId = pointId);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _PickupBottomSheet(
        point: point,
        locale: context.localeCode,
        onSelect: () => _selectPoint(point),
        titleLabel: context.pickT('Point relais', 'Pickup point'),
        distanceSuffix: context.pickT('km de vous', 'km from you'),
        hoursLabel: context.pickT('Heures d\'ouverture', 'Opening hours'),
        defaultHours: context.pickT('08h00 - 18h00', '8:00 AM - 6:00 PM'),
        selectLabel: context.pickT('Livrer à ce point relais', 'Deliver to this pickup point'),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _selectedPointId = null);
    });
  }

  Future<void> _selectPoint(Map<String, dynamic> point) async {
    if (_isSelecting) return;
    setState(() => _isSelecting = true);

    HapticFeedback.mediumImpact();
    final pointId = point['id']?.toString();
    debugPrint('[PickupPoints] ✓ Selected: ${pointId != null ? _shortId(pointId) : 'unknown'}');

    try {
      widget.onPointSelected?.call(point);
      if (!mounted) return;
      Navigator.pop(context); // Ferme bottom sheet
      if (!mounted) return;
      Navigator.pop(context); // Retour au checkout
    } catch (e) {
      debugPrint('[PickupPoints] ❌ Select error: $e');
    } finally {
      if (mounted) setState(() => _isSelecting = false);
    }
  }

  String _shortId(String id) => id.length > 8 ? id.substring(0, 8) : id;

  void _showError(String message) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        title: Text(
          context.pickT('Points relais THIX', 'THIX Pickup Points'),
          style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
        ),
        backgroundColor: ThixPolicy.card.withOpacity(0.95),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: ThixPolicy.textMain),
        leading: Semantics(
          button: true,
          label: context.pickT('Retour', 'Back'),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
            },
          ),
        ),
      ),
      body: Consumer<DeliveryProvider>(
        builder: (context, provider, _) {
          if (_error != null && provider.pickupPoints.isEmpty) {
            return _ErrorPickupState(
              message: _error!,
              retryLabel: context.pickT('Réessayer', 'Retry'),
              onRetry: _retry,
            );
          }

          final markers = _buildMarkers(provider);
          final initialTarget = _userLocation ?? const LatLng(_kDefaultLat, _kDefaultLng);

          return Stack(
            children: [
              Semantics(
                label: context.pickT('Carte des points relais', 'Pickup points map'),
                child: GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(target: initialTarget, zoom: _kDefaultZoom),
                  markers: markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  compassEnabled: true,
                  mapToolbarEnabled: false,
                ),
              ),

              // Bouton recentrer sur utilisateur
              if (_userLocation != null)
                Positioned(
                  bottom: 180,
                  right: 16,
                  child: Semantics(
                    button: true,
                    label: context.pickT('Ma position', 'My location'),
                    child: Material(
                      color: ThixPolicy.card,
                      shape: const CircleBorder(),
                      elevation: 3,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _focusOnUser();
                        },
                        customBorder: const CircleBorder(),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          child: Icon(Icons.my_location_rounded, color: ThixPolicy.primary, size: 22),
                        ),
                      ),
                    ),
                  ),
                ),

              // Skeleton loading premium
              if (provider.isLoadingPickupPoints) const _SkeletonMap(),

              // Empty state
              if (!provider.isLoadingPickupPoints && provider.pickupPoints.isEmpty && _error == null)
                _EmptyPickupState(
                  title: context.pickT('Aucun point relais', 'No pickup points'),
                  subtitle: context.pickT(
                    'Aucun point relais disponible à proximité',
                    'No pickup points available nearby',
                  ),
                  retryLabel: context.pickT('Réessayer', 'Retry'),
                  onRetry: _retry,
                ),

              // Panneau flottant résultats
              if (!provider.isLoadingPickupPoints && provider.pickupPoints.isNotEmpty)
                _NearbyPanel(
                  points: provider.pickupPoints.take(_kPreviewCount).toList(),
                  locale: context.localeCode,
                  title: context.pickT('Points relais à proximité', 'Nearby pickup points'),
                  onTapPoint: (point) {
                    final pos = _PickupValidators.safeLatLng(point['latitude'], point['longitude']);
                    if (pos != null) _focusOnPoint(pos);
                    _showPointDetails(point);
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================================
// COMPOSANTS RÉUTILISABLES
// ============================================================================

class _PickupBottomSheet extends StatelessWidget {
  final Map<String, dynamic> point;
  final String locale;
  final VoidCallback onSelect;
  final String titleLabel;
  final String distanceSuffix;
  final String hoursLabel;
  final String defaultHours;
  final String selectLabel;

  const _PickupBottomSheet({
    required this.point,
    required this.locale,
    required this.onSelect,
    required this.titleLabel,
    required this.distanceSuffix,
    required this.hoursLabel,
    required this.defaultHours,
    required this.selectLabel,
  });

  @override
  Widget build(BuildContext context) {
    final name = _PickupValidators.sanitize(point['name']?.toString(), maxLength: _kMaxNameLength);
    final address = _PickupValidators.sanitize(point['address']?.toString(), maxLength: _kMaxAddressLength);
    final hours = _PickupValidators.sanitize(
      point['opening_hours']?.toString() ?? defaultHours,
      maxLength: _kMaxHoursLength,
    );
    final distanceKm = _PickupValidators.safeDouble(point['distance_km']);
    final formattedDistance = _PickupValidators.formatDistance(distanceKm, locale);

    return Container(
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // Header : nom + distance
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ThixPolicy.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.storefront_rounded, color: ThixPolicy.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? titleLabel : name,
                      style: ThixPolicy.titleStyle.copyWith(
                        fontSize: 18,
                        fontWeight: ThixPolicy.bold,
                        color: ThixPolicy.textMain,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.near_me_rounded, size: 14, color: ThixPolicy.primary),
                        const SizedBox(width: 4),
                        Text(
                          '$formattedDistance km $distanceSuffix',
                          style: ThixPolicy.captionStyle.copyWith(
                            color: ThixPolicy.primary,
                            fontWeight: ThixPolicy.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: ThixPolicy.border.withOpacity(0.6)),
          ),

          // Adresse
          _InfoRow(
            icon: Icons.location_on_rounded,
            value: address.isEmpty ? context.pickT('Adresse non disponible', 'Address unavailable') : address,
          ),
          const SizedBox(height: 12),

          // Heures d'ouverture
          _InfoRow(icon: Icons.access_time_filled_rounded, value: hours.isEmpty ? defaultHours : hours),

          const SizedBox(height: 24),

          // Bouton sélection
          Semantics(
            button: true,
            label: selectLabel,
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: onSelect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  selectLabel,
                  style: ThixPolicy.labelStyle.copyWith(
                    fontWeight: ThixPolicy.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String value;

  const _InfoRow({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: ThixPolicy.textMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: ThixPolicy.bodyStyle.copyWith(
              fontSize: 14,
              height: 1.4,
              color: ThixPolicy.textMain,
            ),
          ),
        ),
      ],
    );
  }
}

class _NearbyPanel extends StatelessWidget {
  final List<Map<String, dynamic>> points;
  final String locale;
  final String title;
  final ValueChanged<Map<String, dynamic>> onTapPoint;

  const _NearbyPanel({
    required this.points,
    required this.locale,
    required this.title,
    required this.onTapPoint,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: ThixPolicy.shadowSoft(opacity: 0.12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.storefront_rounded, color: ThixPolicy.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: ThixPolicy.titleStyle.copyWith(
                      fontWeight: ThixPolicy.bold,
                      fontSize: 16,
                      color: ThixPolicy.textMain,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: ThixPolicy.border.withOpacity(0.6)),
            ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: points.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: ThixPolicy.border.withOpacity(0.6)),
              itemBuilder: (context, index) {
                final point = points[index];
                final name = _PickupValidators.sanitize(point['name']?.toString(), maxLength: _kMaxNameLength);
                final distanceKm = _PickupValidators.safeDouble(point['distance_km']);
                final formattedDistance = _PickupValidators.formatDistance(distanceKm, locale);

                return Semantics(
                  button: true,
                  label: '$name, $formattedDistance km',
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(
                      name.isEmpty ? context.pickT('Point relais', 'Pickup point') : name,
                      style: ThixPolicy.labelStyle.copyWith(
                        fontWeight: ThixPolicy.bold,
                        fontSize: 15,
                        color: ThixPolicy.textMain,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '$formattedDistance km',
                      style: ThixPolicy.captionStyle.copyWith(
                        color: ThixPolicy.primary,
                        fontSize: 13,
                        fontWeight: ThixPolicy.bold,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ThixPolicy.surfaceSoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chevron_right_rounded, color: ThixPolicy.textMuted, size: 20),
                    ),
                    onTap: () => onTapPoint(point),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonMap extends StatelessWidget {
  const _SkeletonMap();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ThixPolicy.card.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ThixPolicy.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.storefront_rounded, size: 48, color: ThixPolicy.primary),
            ),
            const SizedBox(height: 16),
            Text(
              context.pickT('Recherche des points relais...', 'Searching pickup points...'),
              style: ThixPolicy.labelStyle.copyWith(
                color: ThixPolicy.textMain,
                fontWeight: ThixPolicy.semiBold,
              ),
            ),
            const SizedBox(height: 12),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: ThixPolicy.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPickupState extends StatelessWidget {
  final String title;
  final String subtitle;
  final String retryLabel;
  final VoidCallback onRetry;

  const _EmptyPickupState({
    required this.title,
    required this.subtitle,
    required this.retryLabel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ThixPolicy.card.withOpacity(0.9),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: ThixPolicy.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.storefront_outlined, size: 64, color: ThixPolicy.textMuted),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Semantics(
                button: true,
                label: retryLabel,
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    onRetry();
                  },
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  label: Text(retryLabel, style: const TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThixPolicy.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

class _ErrorPickupState extends StatelessWidget {
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  const _ErrorPickupState({required this.message, required this.retryLabel, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ThixPolicy.card.withOpacity(0.9),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: ThixPolicy.danger.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded, size: 56, color: ThixPolicy.danger),
              ),
              const SizedBox(height: 20),
              Text(
                context.pickT('Erreur de chargement', 'Loading error'),
                style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Semantics(
                button: true,
                label: retryLabel,
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    onRetry();
                  },
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  label: Text(retryLabel, style: const TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThixPolicy.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
