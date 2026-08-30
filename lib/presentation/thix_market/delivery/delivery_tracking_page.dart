// lib/presentation/thix_market/delivery/delivery_tracking_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:url_launcher/url_launcher.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'delivery_provider.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const double _kDefaultLat = -4.322447;
const double _kDefaultLng = 15.307045;
const double _kDefaultZoom = 13.0;
const double _kFocusedZoom = 15.0;
const int _kMaxNameLength = 60;
const int _kMaxVehicleLength = 40;
const double _kMinAnimDistDeg = 0.001; // ~100m

// ============================================================================
// VALIDATEURS
// ============================================================================
class _TrkValidators {
  _TrkValidators._();

  static bool isValidId(String? id) {
    if (id == null || id.trim().isEmpty) return false;
    return RegExp(r'^[0-9a-fA-F-]{8,}$').hasMatch(id.trim());
  }

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

  static String? cleanPhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) return null;
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
    if (!RegExp(r'^\+?[0-9]{6,15}$').hasMatch(cleaned)) return null;
    return cleaned;
  }

  static String shortId(String? id) {
    if (id == null || id.isEmpty) return 'N/A';
    return id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
  }

  static String friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('permission')) return 'Accès non autorisé.';
    if (msg.contains('not found') || msg.contains('404')) return 'Commande introuvable.';
    return 'Une erreur est survenue. Réessayez.';
  }
}

// ============================================================================
// LOCALIZATION
// ============================================================================
extension _TrkL10n on BuildContext {
  String trkT(String fr, String en) {
    final lang = Localizations.localeOf(this).languageCode;
    return lang == 'fr' ? fr : en;
  }
}

// ============================================================================
// STATUS CONFIGURATION
// ============================================================================
class _DeliveryStep {
  final String key;
  final String labelFr;
  final String labelEn;
  final String descFr;
  final String descEn;
  final IconData icon;

  const _DeliveryStep({
    required this.key,
    required this.labelFr,
    required this.labelEn,
    required this.descFr,
    required this.descEn,
    required this.icon,
  });

  String label(BuildContext ctx) => ctx.trkT(labelFr, labelEn);
  String desc(BuildContext ctx) => ctx.trkT(descFr, descEn);
}

const List<_DeliveryStep> _kSteps = [
  _DeliveryStep(
    key: 'preparing',
    labelFr: 'Commande confirmée',
    labelEn: 'Order confirmed',
    descFr: 'Votre commande est en préparation',
    descEn: 'Your order is being prepared',
    icon: Icons.inventory_2_rounded,
  ),
  _DeliveryStep(
    key: 'picked_up',
    labelFr: 'Colis récupéré',
    labelEn: 'Package picked up',
    descFr: 'Le livreur a récupéré votre commande',
    descEn: 'Driver picked up your order',
    icon: Icons.storefront_rounded,
  ),
  _DeliveryStep(
    key: 'in_transit',
    labelFr: 'En route',
    labelEn: 'In transit',
    descFr: 'Votre commande est en chemin',
    descEn: 'Your order is on its way',
    icon: Icons.local_shipping_rounded,
  ),
  _DeliveryStep(
    key: 'out_for_delivery',
    labelFr: 'En approche',
    labelEn: 'Out for delivery',
    descFr: 'Le livreur est proche',
    descEn: 'Driver is nearby',
    icon: Icons.location_on_rounded,
  ),
  _DeliveryStep(
    key: 'delivered',
    labelFr: 'Livré',
    labelEn: 'Delivered',
    descFr: 'Commande remise avec succès',
    descEn: 'Order successfully delivered',
    icon: Icons.check_circle_rounded,
  ),
];

/// Détermine si un step est complété — robuste quand status est inconnu
bool _isStepCompleted(String currentKey, String testKey) {
  final ci = _kSteps.indexWhere((s) => s.key == currentKey);
  final ti = _kSteps.indexWhere((s) => s.key == testKey);
  if (ci == -1 || ti == -1) return false; // ← FIX CRITIQUE
  return ti < ci;
}

// ============================================================================
// PAGE
// ============================================================================
class DeliveryTrackingPage extends ConsumerStatefulWidget {
  final String orderId;
  const DeliveryTrackingPage({super.key, required this.orderId});

  @override
  ConsumerState<DeliveryTrackingPage> createState() =>
      _DeliveryTrackingPageState();
}

class _DeliveryTrackingPageState extends ConsumerState<DeliveryTrackingPage> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  LatLng? _lastDriverPos;
  bool _isRetrying = false;
  String? _lastTrackingKey;

  @override
  void initState() {
    super.initState();
    debugPrint('[Tracking] 📍 Opened for ${_TrkValidators.shortId(widget.orderId)}');

    if (!_TrkValidators.isValidId(widget.orderId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showError(context.trkT('Identifiant invalide', 'Invalid ID'));
      });
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(deliveryProvider).trackDelivery(widget.orderId);
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    debugPrint('[Tracking] 👋 Disposed');
    super.dispose();
  }

  // ─── MAP ───────────────────────────────────────────────────
  void _onMapCreated(GoogleMapController c, Map<String, dynamic> t) {
    if (!mounted) return;
    _mapController = c;
    debugPrint('[Tracking] ✅ Map ready');
    _syncMarkers(t, forceFocus: true);
  }

  void _syncMarkers(Map<String, dynamic> tracking, {bool forceFocus = false}) {
    // Safe driver cast
    final driverMap = tracking['driver'] is Map
        ? Map<String, dynamic>.from(tracking['driver'] as Map)
        : null;

    final driverPos = _TrkValidators.safeLatLng(
      driverMap?['current_lat'] ?? tracking['driver_lat'],
      driverMap?['current_lng'] ?? tracking['driver_lng'],
    );
    final destPos = _TrkValidators.safeLatLng(
      tracking['dest_lat'] ?? tracking['dest_latitude'] ?? tracking['delivery_lat'],
      tracking['dest_lng'] ?? tracking['dest_longitude'] ?? tracking['delivery_lng'],
    );

    final newMarkers = <Marker>{};

    if (driverPos != null) {
      newMarkers.add(Marker(
        markerId: const MarkerId('driver'),
        position: driverPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(title: context.trkT('Votre livreur', 'Your driver')),
        zIndex: 2,
      ));
    }

    if (destPos != null) {
      newMarkers.add(Marker(
        markerId: const MarkerId('destination'),
        position: destPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(title: context.trkT('Lieu de livraison', 'Delivery location')),
        zIndex: 1,
      ));
    }

    // Focus caméra si position driver a changé significativement (~100m)
    final shouldFocus = forceFocus || _driverMovedEnough(driverPos);
    if (shouldFocus && driverPos != null) {
      _lastDriverPos = driverPos;
      _animateTo(driverPos);
    }

    setState(() => _markers = newMarkers);
  }

  bool _driverMovedEnough(LatLng? newPos) {
    if (newPos == null) return false;
    if (_lastDriverPos == null) return true;
    final dLat = (newPos.latitude - _lastDriverPos!.latitude).abs();
    final dLng = (newPos.longitude - _lastDriverPos!.longitude).abs();
    return (dLat + dLng) > _kMinAnimDistDeg;
  }

  Future<void> _animateTo(LatLng pos) async {
    if (!mounted || _mapController == null) return;
    try {
      await _mapController!.animateCamera(CameraUpdate.newLatLngZoom(pos, _kFocusedZoom));
    } catch (e) {
      debugPrint('[Tracking] ⚠️ Camera error: $e');
    }
  }

  // ─── RETRY ─────────────────────────────────────────────────
  Future<void> _retry() async {
    if (_isRetrying) return;
    setState(() => _isRetrying = true);
    HapticFeedback.mediumImpact();
    debugPrint('[Tracking] 🔄 Retry');
    try {
      await ref.read(deliveryProvider).trackDelivery(widget.orderId);
    } catch (e) {
      debugPrint('[Tracking] ❌ Retry error: $e');
    } finally {
      if (mounted) setState(() => _isRetrying = false);
    }
  }

  // ─── CALL DRIVER ───────────────────────────────────────────
  Future<void> _callDriver(String? phone) async {
    final cleaned = _TrkValidators.cleanPhone(phone);
    if (cleaned == null) {
      _showError(context.trkT('Numéro indisponible', 'Phone unavailable'));
      return;
    }
    HapticFeedback.mediumImpact();
    debugPrint('[Tracking] 📞 Calling: $cleaned');
    final uri = Uri(scheme: 'tel', path: cleaned);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) _showError(context.trkT('Appel impossible', 'Cannot call'));
      }
    } catch (e) {
      debugPrint('[Tracking] ❌ Call error: $e');
      if (mounted) _showError(context.trkT('Erreur lors de l\'appel', 'Call error'));
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: ThixPolicy.danger,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ─── BUILD ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final prov = ref.watch(deliveryProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          context.trkT('Suivi de commande', 'Order tracking'),
          style: ThixPolicy.h3Style.copyWith(
            fontWeight: ThixPolicy.bold,
            color: ThixPolicy.textMain,
          ),
        ),
        backgroundColor: ThixPolicy.card.withOpacity(0.95),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: ThixPolicy.textMain),
        leading: Semantics(
          button: true,
          label: context.trkT('Retour', 'Back'),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            tooltip: context.trkT('Retour', 'Back'),
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
            },
          ),
        ),
      ),
      body: _body(prov),
    );
  }

  Widget _body(DeliveryProvider prov) {
    // ── Loading ──
    if (prov.isLoadingTracking && !_isRetrying) return const _SkeletonTracking();

    // ── Error ──
    if (prov.errorTracking != null) {
      return _ErrorState(
        message: _TrkValidators.friendlyError(prov.errorTracking),
        retryLabel: context.trkT('Réessayer', 'Retry'),
        isRetrying: _isRetrying,
        onRetry: _retry,
      );
    }

    // ── Empty ──
    final tracking = prov.currentTracking;
    if (tracking == null) {
      return _EmptyState(
        title: context.trkT('Suivi indisponible', 'Tracking unavailable'),
        subtitle: context.trkT(
          'Les informations de suivi pour cette\ncommande ne sont pas encore prêtes.',
          'Tracking information for this order\nis not yet available.',
        ),
        retryLabel: context.trkT('Actualiser', 'Refresh'),
        isRetrying: _isRetrying,
        onRetry: _retry,
      );
    }

    // ── Sync markers (une seule fois par changement de données) ──
    final tKey = '${tracking['status']}_${tracking['driver_lat']}_${tracking['driver_lng']}';
    if (tKey != _lastTrackingKey) {
      _lastTrackingKey = tKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncMarkers(tracking);
      });
    }

    final driver = tracking['driver'] is Map
        ? Map<String, dynamic>.from(tracking['driver'] as Map)
        : null;
    final statusKey = (tracking['status'] ?? 'preparing').toString().toLowerCase();

    return Stack(
      children: [
        // ── Carte ──
        Positioned.fill(
          child: Semantics(
            label: context.trkT('Carte de suivi', 'Tracking map'),
            child: GoogleMap(
              onMapCreated: (c) => _onMapCreated(c, tracking),
              initialCameraPosition: const CameraPosition(
                target: LatLng(_kDefaultLat, _kDefaultLng),
                zoom: _kDefaultZoom,
              ),
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: true,
              mapToolbarEnabled: false,
            ),
          ),
        ),

        // ── Panneau bas ──
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            decoration: BoxDecoration(
              color: ThixPolicy.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: ThixPolicy.shadowSoft(opacity: 0.12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: ThixPolicy.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Driver card ──
                if (driver != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _DriverCard(
                      driver: driver,
                      onCall: () => _callDriver(driver['phone']?.toString()),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Divider(height: 1, color: ThixPolicy.border.withOpacity(0.6)),
                  ),
                ],

                // ── Timeline ──
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: _Timeline(currentKey: statusKey),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// DRIVER CARD
// ============================================================================
class _DriverCard extends StatelessWidget {
  final Map<String, dynamic> driver;
  final VoidCallback onCall;

  const _DriverCard({required this.driver, required this.onCall});

  @override
  Widget build(BuildContext context) {
    final name = _TrkValidators.sanitize(
      driver['name']?.toString(),
      maxLength: _kMaxNameLength,
    );
    final vehicle = _TrkValidators.sanitize(
      driver['vehicle']?.toString(),
      maxLength: _kMaxVehicleLength,
    );
    final hasPhone = _TrkValidators.cleanPhone(driver['phone']?.toString()) != null;

    final displayName = name.isEmpty ? context.trkT('Livreur', 'Driver') : name;
    final displayVehicle = vehicle.isEmpty ? context.trkT('Véhicule THIX', 'THIX Vehicle') : vehicle;

    return Semantics(
      label: '${context.trkT('Livreur', 'Driver')}: $displayName, $displayVehicle',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ThixPolicy.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ThixPolicy.primary.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: ThixPolicy.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_rounded, color: ThixPolicy.primary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: ThixPolicy.titleStyle.copyWith(
                      fontWeight: ThixPolicy.bold,
                      fontSize: 16,
                      color: ThixPolicy.textMain,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.directions_car_rounded, size: 14, color: ThixPolicy.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          displayVehicle,
                          style: ThixPolicy.captionStyle.copyWith(
                            color: ThixPolicy.textMuted,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Semantics(
              button: true,
              enabled: hasPhone,
              label: hasPhone
                  ? context.trkT('Appeler le livreur', 'Call driver')
                  : context.trkT('Numéro indisponible', 'Phone unavailable'),
              child: Container(
                decoration: BoxDecoration(
                  color: hasPhone ? ThixPolicy.success : ThixPolicy.textDisabled,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: IconButton(
                  icon: const Icon(Icons.phone_rounded, color: Colors.white, size: 22),
                  tooltip: context.trkT('Appeler', 'Call'),
                  onPressed: hasPhone ? onCall : null,
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
// TIMELINE
// ============================================================================
class _Timeline extends StatelessWidget {
  final String currentKey;
  const _Timeline({required this.currentKey});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.trkT('Détails de la livraison', 'Delivery details'),
          style: ThixPolicy.titleStyle.copyWith(
            fontSize: 18,
            fontWeight: ThixPolicy.bold,
            color: ThixPolicy.textMain,
          ),
        ),
        const SizedBox(height: 24),
        ...List.generate(_kSteps.length, (i) {
          final step = _kSteps[i];
          final isCompleted = _isStepCompleted(currentKey, step.key);
          final isCurrent = currentKey == step.key;
          final isLast = i == _kSteps.length - 1;

          return _TimelineItem(
            step: step,
            isCompleted: isCompleted,
            isCurrent: isCurrent,
            isLast: isLast,
          );
        }),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final _DeliveryStep step;
  final bool isCompleted;
  final bool isCurrent;
  final bool isLast;

  const _TimelineItem({
    required this.step,
    required this.isCompleted,
    required this.isCurrent,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = isCompleted
        ? ThixPolicy.success
        : (isCurrent ? ThixPolicy.primary : ThixPolicy.border);
    final iconColor = (isCompleted || isCurrent)
        ? Colors.white
        : ThixPolicy.textMuted;
    final textColor = (isCompleted || isCurrent)
        ? ThixPolicy.textMain
        : ThixPolicy.textMuted;
    final descColor = isCurrent
        ? ThixPolicy.textSecondary
        : ThixPolicy.textMuted;

    return Semantics(
      label: '${step.label(context)}, '
          '${isCompleted ? context.trkT('complété', 'completed') : isCurrent ? context.trkT('en cours', 'current') : context.trkT('à venir', 'upcoming')}',
      selected: isCurrent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  boxShadow: isCurrent
                      ? [BoxShadow(
                          color: ThixPolicy.primary.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )]
                      : [],
                  border: isCurrent
                      ? Border.all(color: ThixPolicy.primary.withOpacity(0.3), width: 3)
                      : null,
                ),
                child: Icon(step.icon, color: iconColor, size: 20),
              ),
              if (!isLast)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 3,
                  height: 40,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? ThixPolicy.success.withOpacity(0.6)
                        : ThixPolicy.border.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label(context),
                    style: ThixPolicy.labelStyle.copyWith(
                      fontWeight: isCurrent ? ThixPolicy.bold : ThixPolicy.semiBold,
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step.desc(context),
                    style: ThixPolicy.captionStyle.copyWith(
                      fontSize: 13,
                      color: descColor,
                      height: 1.4,
                    ),
                  ),
                  if (!isLast) const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SKELETON / EMPTY / ERROR
// ============================================================================
class _SkeletonTracking extends StatelessWidget {
  const _SkeletonTracking();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ThixPolicy.surfaceSoft,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ThixPolicy.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_shipping_rounded, size: 56, color: ThixPolicy.primary),
            ),
            const SizedBox(height: 20),
            Text(
              context.trkT('Chargement du suivi...', 'Loading tracking...'),
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

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final String retryLabel;
  final bool isRetrying;
  final VoidCallback onRetry;

  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.retryLabel,
    required this.isRetrying,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ThixPolicy.surfaceSoft,
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
                child: const Icon(Icons.location_off_rounded, size: 64, color: ThixPolicy.textMuted),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: ThixPolicy.h3Style.copyWith(
                  fontSize: 20,
                  fontWeight: ThixPolicy.bold,
                  color: ThixPolicy.textMain,
                ),
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
                enabled: !isRetrying,
                child: ElevatedButton.icon(
                  onPressed: isRetrying ? null : onRetry,
                  icon: isRetrying
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.refresh_rounded, color: Colors.white),
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

class _ErrorState extends StatelessWidget {
  final String message;
  final String retryLabel;
  final bool isRetrying;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.retryLabel,
    required this.isRetrying,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ThixPolicy.surfaceSoft,
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
                context.trkT('Erreur de suivi', 'Tracking error'),
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
                enabled: !isRetrying,
                child: ElevatedButton.icon(
                  onPressed: isRetrying ? null : onRetry,
                  icon: isRetrying
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.refresh_rounded, color: Colors.white),
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
