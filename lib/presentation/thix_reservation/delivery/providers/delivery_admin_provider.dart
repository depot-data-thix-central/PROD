// ================================================================
// CHEMIN: lib/presentation/thix_reservation/delivery/providers/delivery_admin_provider.dart
// ROLE: Provider ADMIN - Celui qui fixe le prix par trajet
//       4 pages admin utilisent ce provider
//       CRUD complet sur delivery_routes
// SCALABLE: cache invalidé à chaque modif + logs
// ================================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/delivery_models.dart';
import '../data/delivery_service.dart';

class DeliveryAdminProvider extends ChangeNotifier {
  final _supa = Supabase.instance.client;
  final _service = DeliveryService();

  bool isLoading = true;
  List<DeliveryRoute> routes = [];
  List<DeliveryShipment> allShipments = [];
  Map<String, int> stats = {'total': 0, 'pending': 0, 'delivered': 0, 'today': 0};
  String? error;

  // --------------------------------------------------------------
  // INIT ADMIN DASHBOARD
  // --------------------------------------------------------------
  Future<void> init() async {
    isLoading = true;
    notifyListeners();
    try {
      // Chargement parallèle routes + stats
      await Future.wait([loadRoutes(), loadStats(), loadAllShipments()]);
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // --------------------------------------------------------------
  // 1. ROUTES - Liste pour dashboard admin
  // --------------------------------------------------------------
  Future<void> loadRoutes({bool force = true}) async {
    try {
      routes = await _service.getActiveRoutes(forceRefresh: force);
      notifyListeners();
    } catch (e) {
      error = e.toString();
    }
  }

  // --------------------------------------------------------------
  // 2. CREATE - Admin crée un trajet avec prix
  //    Ex: Abidjan -> Korhogo = 6000 base / 9000 express
  // --------------------------------------------------------------
  Future<void> createRoute({
    required String fromCity,
    required String toCity,
    required int basePrice,
    required int expressPrice,
    int pricePerKg = 500,
    int distanceKm = 0,
    bool isInternational = false,
  }) async {
    try {
      final user = _supa.auth.currentUser;
      // Vérif que from/to pas vide
      if (fromCity.trim().isEmpty || toCity.trim().isEmpty) throw Exception("Villes obligatoires");
      if (basePrice <= 0 || expressPrice <= 0) throw Exception("Prix invalide");

      await _supa.from('delivery_routes').insert({
        'from_city': fromCity.trim(),
        'to_city': toCity.trim(),
        'base_price': basePrice,
        'express_price': expressPrice,
        'price_per_kg': pricePerKg,
        'distance_km': distanceKm,
        'is_international': isInternational,
        'is_active': true,
        'created_by': user?.id,
      });

      // On recharge liste + invalide cache service
      await loadRoutes();
    } catch (e) {
      error = e.toString();
      rethrow;
    }
  }

  // --------------------------------------------------------------
  // 3. UPDATE - Modifier prix par trajet
  // --------------------------------------------------------------
  Future<void> updateRoute({
    required String id,
    required int basePrice,
    required int expressPrice,
    int? pricePerKg,
    bool? isActive,
  }) async {
    try {
      await _supa.from('delivery_routes').update({
        'base_price': basePrice,
        'express_price': expressPrice,
        if (pricePerKg != null) 'price_per_kg': pricePerKg,
        if (isActive != null) 'is_active': isActive,
      }).eq('id', id);

      await loadRoutes();
    } catch (e) {
      rethrow;
    }
  }

  // --------------------------------------------------------------
  // 4. DELETE - Supprimer trajet
  // --------------------------------------------------------------
  Future<void> deleteRoute(String id) async {
    try {
      await _supa.from('delivery_routes').delete().eq('id', id);
      routes.removeWhere((r) => r.id == id);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  // --------------------------------------------------------------
  // 5. STATS - Dashboard admin
  // --------------------------------------------------------------
  Future<void> loadStats() async {
    try {
      // Comptage total, pending, delivered, today
      final today = DateTime.now().toIso8601String().substring(0, 10);
      
      final totalRes = await _supa.from('delivery_shipments').select('id').count();
      final pendingRes = await _supa.from('delivery_shipments').select('id').eq('status', 'pending').count();
      final deliveredRes = await _supa.from('delivery_shipments').select('id').eq('status', 'delivered').count();
      final todayRes = await _supa.from('delivery_shipments').select('id').gte('created_at', '${today}T00:00:00').count();

      stats = {
        'total': totalRes.count,
        'pending': pendingRes.count,
        'delivered': deliveredRes.count,
        'today': todayRes.count,
      };
      notifyListeners();
    } catch (e) {
      debugPrint("STATS ERROR: $e");
    }
  }

  // --------------------------------------------------------------
  // 6. ALL SHIPMENTS - Pour page admin colis
  // --------------------------------------------------------------
  Future<void> loadAllShipments() async {
    try {
      final data = await _supa.from('delivery_shipments').select().order('created_at', ascending: false).limit(50);
      allShipments = (data as List).map((e) => DeliveryShipment.fromJson(e)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint("LOAD ALL SHIPMENTS ERROR: $e");
    }
  }

  // --------------------------------------------------------------
  // 7. SCAN - Changer statut via QR code
  // --------------------------------------------------------------
  Future<void> updateShipmentStatus(String shipmentId, ShipmentStatus newStatus, String location) async {
    try {
      await _supa.from('delivery_shipments').update({'status': newStatus.name}).eq('id', shipmentId);

      // On ajoute event dans timeline
      await _supa.from('delivery_tracking_events').insert({
        'shipment_id': shipmentId,
        'status': newStatus.name,
        'location': location,
        'description': _statusDescription(newStatus),
      });

      await loadAllShipments();
    } catch (e) {
      rethrow;
    }
  }

  String _statusDescription(ShipmentStatus s) => switch (s) {
    ShipmentStatus.picked => "Colis ramassé par le transporteur",
    ShipmentStatus.inTransit => "Colis en cours d'acheminement",
    ShipmentStatus.outForDelivery => "Colis en livraison finale",
    ShipmentStatus.delivered => "Colis livré avec succès",
    _ => s.name,
  };
}
