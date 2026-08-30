// lib/presentation/thix_market/delivery/tracking_map.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../delivery_provider.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const double _kDefaultLat = 5.359952;   // Abidjan (fallback)
const double _kDefaultLng = -4.008256;
const double _kDriverZoom = 14.5;
const double _kInitialZoom = 12.0;
const double _kCameraAnimationDuration = 800; // ms

// ============================================================================
// VALIDATEURS
// ============================================================================
class _MapValidators {
  _MapValidators._();

  /// Valide et normalise des coordonnées GPS
  static LatLng? safeLatLng(double? lat, double? lng) {
    if (lat == null || lng == null) return null;
    if (lat.isNaN || lng.isNaN) return null;
    if (lat.isInfinite || lng.isInfinite) return null;
    if (lat < -90 || lat > 90) return null;
    if (lng < -180 || lng > 180) return null;
    return LatLng(lat, lng);
  }

  static String sanitize(String? input, {int maxLength = 100}) {
    if (input == null || input.trim().isEmpty) return '';
    var s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static bool isValidOrderId(String? id) {
    if (id == null || id.trim().isEmpty) return false;
    return RegExp(r'^[0-9a-fA-F-]{8,}$').hasMatch(id.trim());
  }
}

// ============================================================================
// LOCALIZATION HELPER
// ============================================================================
extension _MapL10n on BuildContext {
  String mapT(String fr, String en) {
    final lang = Localizations.localeOf(this).languageCode;
    return lang == 'fr' ? fr : en;
  }
}

// ============================================================================
// WIDGET PRINCIPAL
// ============================================================================
class TrackingMap extends StatefulWidget {
  final String orderId;
  final double? destLatitude;
  final double? destLongitude;

  const TrackingMap({
    super.key,
    required this.orderId,
    this.destLatitude,
    this.destLongitude,
  });

  @override
  State<TrackingMap> createState() => _TrackingMapState();
}

class _TrackingMapState extends State<TrackingMap> {
  GoogleMapController? _mapController;
  LatLng? _driverLocation;
  LatLng? _destinationLocation;
  LatLng? _lastCameraTarget;
  bool _isMapReady = false;
  String? _error;
  String? _driverName;

  // Dernière clé de tracking connue pour éviter re-renders inutiles
  String? _lastTrackingKey;

  @override
  void initState() {
    super.initState();
    debugPrint('[TrackingMap] 🗺️ Init for order ${_shortId(widget.orderId)}');

    if (!_MapValidators.isValidOrderId(widget.orderId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _error = context.mapT('Identifiant invalide', 'Invalid ID'));
      });
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _startTracking());
  }

  @override
  void didUpdateWidget(covariant TrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId) {
      debugPrint('[TrackingMap] 🔄 Order changed, restarting tracking');
      _stopTracking();
      WidgetsBinding.instance.addPostFrameCallback((_) => _startTracking());
    }
  }

  @override
  void dispose() {
    _stopTracking();
    _mapController?.dispose();
    debugPrint('[TrackingMap] 👋 Disposed');
    super.dispose();
  }

  String _shortId(String id) => id.length > 8 ? id.substring(0, 8) : id;

  void _startTracking() {
    if (!mounted) return;
    try {
      final provider = context.read<DeliveryProvider>();
      provider.trackDelivery(widget.orderId);
      debugPrint('[TrackingMap] 📡 Tracking started');
    } catch (e) {
      debugPrint('[TrackingMap] ❌ Start tracking error: $e');
      if (mounted) {
        setState(() => _error = context.mapT('Impossible de démarrer le suivi', 'Unable to start tracking'));
      }
    }
  }

  void _stopTracking() {
    try {
      final provider = context.read<DeliveryProvider>();
      // Appeler stopTracking si disponible (non-bloquant)
      try {
        (provider as dynamic).stopTracking?.call();
      } catch (_) {
        // Méthode non disponible, ignoré
      }
    } catch (_) {
      // Provider déjà disposed, ignoré
    }
  }

  /// Calcule les marqueurs sans setState (évite rebuilds en cascade)
  _MapSnapshot _computeSnapshot(DeliveryProvider provider) {
    final driver = provider.currentTracking?['driver'] as Map?;
    final driverLat = (driver?['current_lat'] as num?)?.toDouble();
    final driverLng = (driver?['current_lng'] as num?)?.toDouble();
    final newDriverLocation = _MapValidators.safeLatLng(driverLat, driverLng);

    final destLat = widget.destLatitude ?? (provider.currentTracking?['dest_latitude'] as num?)?.toDouble();
    final destLng = widget.destLongitude ?? (provider.currentTracking?['dest_longitude'] as num?)?.toDouble();
    final newDestLocation = _MapValidators.safeLatLng(destLat, destLng);

    final driverName = _MapValidators.sanitize(
      driver?['name']?.toString() ?? driver?['full_name']?.toString(),
      maxLength: 60,
    );

    return _MapSnapshot(
      driverLocation: newDriverLocation,
      destinationLocation: newDestLocation,
      driverName: driverName.isNotEmpty ? driverName : null,
    );
  }

  /// Construit les markers Google Maps de manière pure
  Set<Marker> _buildMarkers(_MapSnapshot snapshot) {
    final markers = <Marker>{};

    if (snapshot.driverLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: snapshot.driverLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(
          title: context.mapT('Livreur', 'Driver'),
          snippet: snapshot.driverName,
        ),
        zIndex: 2,
      ));
    }

    if (snapshot.destinationLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: snapshot.destinationLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: context.mapT('Livraison', 'Delivery'),
          snippet: context.mapT('Votre destination', 'Your destination'),
        ),
        zIndex: 1,
      ));
    }

    return markers;
  }

  /// Anime la caméra vers la position du livreur (avec protection)
  Future<void> _animateToDriver(LatLng target) async {
    if (!mounted || !_isMapReady) return;
    final controller = _mapController;
    if (controller == null) return;

    // Évite animation si déjà proche (< ~500m)
    if (_lastCameraTarget != null) {
      final distance = _distanceMeters(_lastCameraTarget!, target);
      if (distance < 500) return;
    }

    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(target, _kDriverZoom),
      );
      _lastCameraTarget = target;
    } catch (e) {
      debugPrint('[TrackingMap] ⚠️ Camera animation error: $e');
    }
  }

  /// Distance approximative entre 2 LatLng (Haversine simplifiée)
  double _distanceMeters(LatLng a, LatLng b) {
    const earthRadius = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final sinLat = math.sin(dLat / 2);
    final sinLng = math.sin(dLng / 2);
    final aVal = sinLat * sinLat +
        math.cos(a.latitude * math.pi / 180) *
            math.cos(b.latitude * math.pi / 180) *
            sinLng * sinLng;
    return earthRadius * 2 * math.atan2(math.sqrt(aVal), math.sqrt(1 - aVal));
  }

  void _onMapCreated(GoogleMapController controller) {
    if (!mounted) return;
    _mapController = controller;
    _isMapReady = true;
    debugPrint('[TrackingMap] ✅ Map ready');
  }

  void _onMyLocationButtonPressed() {
    HapticFeedback.selectionClick();
    debugPrint('[TrackingMap] 📍 My location requested');
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _ErrorState(
        message: _error!,
        retryLabel: context.mapT('Réessayer', 'Retry'),
        onRetry: () {
          HapticFeedback.mediumImpact();
          setState(() => _error = null);
          _startTracking();
        },
      );
    }

    return Consumer<DeliveryProvider>(
      builder: (context, provider, _) {
        if (provider.isLoadingTracking && !_isMapReady) {
          return const _MapSkeleton();
        }

        // IMPORTANT : calcul pur, pas de setState dans build
        final snapshot = _computeSnapshot(provider);
        final markers = _buildMarkers(snapshot);

        // Détection changement driver pour animation
        final newKey = '${snapshot.driverLocation?.latitude},${snapshot.driverLocation?.longitude}';
        if (newKey != _lastTrackingKey && snapshot.driverLocation != null) {
          _lastTrackingKey = newKey;
          // Animer après le build pour éviter setState-during-build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _animateToDriver(snapshot.driverLocation!);
          });
        }

        // Position initiale : driver > destination > fallback
        final initialTarget = snapshot.driverLocation ??
            snapshot.destinationLocation ??
            const LatLng(_kDefaultLat, _kDefaultLng);

        return Semantics(
          label: context.mapT('Carte de suivi en direct', 'Live tracking map'),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(ThixPolicy.rLg),
            child: Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: initialTarget,
                    zoom: _kInitialZoom,
                  ),
                  markers: markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                  compassEnabled: true,
                  mapToolbarEnabled: false,
                  onCameraMoveStarted: () {
                    // Utilisateur interagit → stop auto-camera
                    _lastCameraTarget = null;
                  },
                  style: _mapStyle,
                ),

                // Badge "En direct" en haut à gauche
                if (snapshot.driverLocation != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _LiveBadge(label: context.mapT('EN DIRECT', 'LIVE')),
                  ),

                // Bouton recentrer sur livreur
                if (snapshot.driverLocation != null)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: _RecenterButton(
                      label: context.mapT('Recentrer', 'Recenter'),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        _animateToDriver(snapshot.driverLocation!);
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Style sombre premium pour la map (optionnel)
  static const String _mapStyle = '''
  [
    {
      "featureType": "poi",
      "elementType": "labels",
      "stylers": [{"visibility": "off"}]
    }
  ]
  ''';
}

// ============================================================================
// MODÈLE INTERNE (snapshot immutable)
// ============================================================================
class _MapSnapshot {
  final LatLng? driverLocation;
  final LatLng? destinationLocation;
  final String? driverName;

  const _MapSnapshot({
    required this.driverLocation,
    required this.destinationLocation,
    this.driverName,
  });
}

// ============================================================================
// COMPOSANTS RÉUTILISABLES
// ============================================================================

class _LiveBadge extends StatefulWidget {
  final String label;
  const _LiveBadge({required this.label});

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ThixPolicy.danger,
        borderRadius: BorderRadius.circular(8),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, child) => Opacity(
              opacity: 0.5 + _ctrl.value * 0.5,
              child: child,
            ),
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            widget.label,
            style: ThixPolicy.microStyle.copyWith(
              color: Colors.white,
              fontWeight: ThixPolicy.bold,
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required super.listenable,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) => builder(context, child);
}

class _RecenterButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _RecenterButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: ThixPolicy.card,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Icon(
              Icons.my_location_rounded,
              color: ThixPolicy.primary,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _MapSkeleton extends StatelessWidget {
  const _MapSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ThixPolicy.surfaceSoft,
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
      ),
      child: Stack(
        children: [
          // Background pattern (simule une carte)
          CustomPaint(
            size: Size.infinite,
            painter: _GridPainter(color: ThixPolicy.border.withOpacity(0.3)),
          ),
          // Skeleton content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: ThixPolicy.primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.map_outlined,
                    size: 48,
                    color: ThixPolicy.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.mapT('Chargement de la carte...', 'Loading map...'),
                  style: ThixPolicy.labelStyle.copyWith(
                    color: ThixPolicy.textMuted,
                    fontWeight: ThixPolicy.semiBold,
                  ),
                ),
                const SizedBox(height: 12),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: ThixPolicy.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ErrorState extends StatelessWidget {
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThixPolicy.danger.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_off_rounded, size: 40, color: ThixPolicy.danger),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: ThixPolicy.labelStyle.copyWith(
              color: ThixPolicy.textMain,
              fontWeight: ThixPolicy.semiBold,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(retryLabel),
            style: OutlinedButton.styleFrom(
              foregroundColor: ThixPolicy.primary,
              side: BorderSide(color: ThixPolicy.primary.withOpacity(0.4)),
            ),
          ),
        ],
      ),
    );
  }
}
