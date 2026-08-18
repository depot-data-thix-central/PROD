// ================================================================
// CHEMIN: lib/presentation/thix_reservation/delivery/data/delivery_service.dart
// ROLE: Couche d'accès Supabase DIRECT (pas de repo)
//       Singleton scalable pour 1M users avec cache mémoire
//       Toutes les requêtes passent ici
// ================================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import 'delivery_models.dart';

class DeliveryService {
  // --- Singleton pattern pour 1M users (1 seule instance) ---
  static final DeliveryService _instance = DeliveryService._internal();
  factory DeliveryService() => _instance;
  DeliveryService._internal();
  final _supa = Supabase.instance.client;

  // --- Cache mémoire pour éviter de re-taper Supabase à chaque fois ---
  // Important pour performance 1M users
  List<DeliveryRoute>? _routesCache;
  DateTime? _cacheTime;
  static const _cacheDuration = Duration(minutes: 5);

  // --------------------------------------------------------------
  // 1. ROUTES - Lecture prix par trajet (utilisé dans Home)
  // --------------------------------------------------------------
  Future<List<DeliveryRoute>> getActiveRoutes({bool forceRefresh = false}) async {
    // Si cache encore valide, on retourne cache (perf)
    if (!forceRefresh && _routesCache != null && _cacheTime != null) {
      if (DateTime.now().difference(_cacheTime!) < _cacheDuration) {
        return _routesCache!;
      }
    }

    // Requête Supabase avec index from_to pour perf
    final data = await _supa.from('delivery_routes').select().eq('is_active', true).order('from_city');

    final routes = (data as List).map((e) => DeliveryRoute.fromJson(e)).toList();
    
    // Mise en cache
    _routesCache = routes;
    _cacheTime = DateTime.now();
    return routes;
  }

  // Trouve prix exact pour un trajet donné
  Future<DeliveryRoute?> findRoute(String from, String to) async {
    // Recherche dans cache d'abord
    final routes = await getActiveRoutes();
    try {
      return routes.firstWhere((r) => 
        r.fromCity.toLowerCase() == from.toLowerCase() && 
        r.toCity.toLowerCase() == to.toLowerCase()
      );
    } catch (_) {
      // Si pas en cache, requête directe
      final data = await _supa.from('delivery_routes').select()
        .ilike('from_city', from).ilike('to_city', to).eq('is_active', true).maybeSingle();
      return data != null ? DeliveryRoute.fromJson(data) : null;
    }
  }

  // --------------------------------------------------------------
  // 2. OFFRES - Pour section "Offres du moment"
  // --------------------------------------------------------------
  Future<List<DeliveryOffer>> getOffers() async {
    final data = await _supa.from('delivery_offers').select().eq('is_active', true).limit(10);
    return (data as List).map((e) => DeliveryOffer.fromJson(e)).toList();
  }

  // --------------------------------------------------------------
  // 3. ADMIN - CRUD routes (fixer prix par trajet)
  // --------------------------------------------------------------
  Future<void> createRoute(DeliveryRoute route) async {
    await _supa.from('delivery_routes').insert(route.toInsert());
    _routesCache = null; // Invalide cache après création
  }

  Future<void> updateRoutePrice({required String id, required int base, required int express, int? perKg}) async {
    await _supa.from('delivery_routes').update({
      'base_price': base,
      'express_price': express,
      if (perKg != null) 'price_per_kg': perKg,
    }).eq('id', id);
    _routesCache = null; // Invalide cache
  }

  Future<void> deleteRoute(String id) async {
    await _supa.from('delivery_routes').delete().eq('id', id);
    _routesCache = null;
  }

  // --------------------------------------------------------------
  // 4. CHECK ADMIN
  // --------------------------------------------------------------
  Future<bool> isUserAdmin() async {
    final user = _supa.auth.currentUser;
    if (user == null) return false;
    final data = await _supa.from('delivery_admins').select('user_id').eq('user_id', user.id).maybeSingle();
    return data != null;
  }
}
