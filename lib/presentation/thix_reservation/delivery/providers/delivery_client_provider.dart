// lib/presentation/thix_reservation/delivery/providers/delivery_client_provider.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/delivery_models.dart';
import '../data/delivery_service.dart';

class DeliveryClientProvider extends ChangeNotifier {
  final _supa = Supabase.instance.client;
  final _service = DeliveryService();

  bool isLoading = true;
  bool isCalculating = false;
  bool isLoadingHistory = false;
  bool isTracking = false;
  bool hasMoreHistory = false;
  bool isNational = true;

  String userName = "";
  String fromCity = "";
  String toCity = "";
  int weightKg = 1;
  DeliveryMode deliveryMode = DeliveryMode.standard;

  int calculatedPrice = 0;
  List<DeliveryRoute> popularRoutes = [];
  List<DeliveryOffer> offers = [];
  List<DeliveryShipment> myShipments = [];
  
  DeliveryShipment? trackedShipment;
  List<DeliveryTrackingEvent> trackingEvents = [];
  DeliveryRoute? selectedRoute;

  Future<void> init() async {
    isLoading = true;
    notifyListeners();
    try {
      userName = _supa.auth.currentUser?.userMetadata?['full_name'] ?? "";
      
      // FIX : Typage explicite <void> pour éviter toute erreur de compilation Web (dart2js)
      await Future.wait<void>([
        loadRoutes(), 
        loadOffers(), 
        loadMyShipments()
      ]);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadRoutes({bool force = true}) async {
    try {
      popularRoutes = await _service.getActiveRoutes(forceRefresh: force);
      _recalculate();
    } catch (e) {
      debugPrint("LOAD ROUTES ERROR: $e");
    }
  }

  Future<void> loadOffers() async {
    try {
      final data = await _supa.from('delivery_offers').select().eq('is_active', true);
      offers = (data as List).map((e) => DeliveryOffer.fromJson(e)).toList();
    } catch (_) {}
  }

  Future<void> loadMyShipments({bool refresh = false}) async {
    isLoadingHistory = true;
    if (refresh) myShipments.clear(); // Utilisation de .clear() qui est plus performant
    notifyListeners();
    try {
      final user = _supa.auth.currentUser;
      if (user == null) return;
      
      final data = await _supa
          .from('delivery_shipments')
          .select()
          .eq('sender_id', user.id)
          .order('created_at', ascending: false)
          .limit(50);
          
      myShipments = (data as List).map((e) => DeliveryShipment.fromJson(e)).toList();
    } catch (e) {
      debugPrint("MY SHIPMENTS ERROR: $e");
    } finally {
      isLoadingHistory = false;
      notifyListeners();
    }
  }

  // FIX pour delivery_tracking_page.dart
  Future<void> trackByCode(String code) async {
    isTracking = true;
    notifyListeners();
    try {
      final shipData = await _supa
          .from('delivery_shipments')
          .select()
          .eq('tracking_code', code.trim().toUpperCase())
          .maybeSingle();
          
      if (shipData == null) throw Exception("Code introuvable");
      trackedShipment = DeliveryShipment.fromJson(shipData);
      
      final eventsData = await _supa
          .from('delivery_tracking_events')
          .select()
          .eq('shipment_id', trackedShipment!.id)
          .order('created_at', ascending: true);
          
      trackingEvents = (eventsData as List).map((e) => DeliveryTrackingEvent.fromJson(e)).toList();
    } catch (e) {
      rethrow;
    } finally {
      isTracking = false;
      notifyListeners();
    }
  }

  Future<void> trackShipment(String id) async {
    isTracking = true;
    notifyListeners();
    try {
      final shipData = await _supa.from('delivery_shipments').select().eq('id', id).single();
      trackedShipment = DeliveryShipment.fromJson(shipData);
      
      final eventsData = await _supa
          .from('delivery_tracking_events')
          .select()
          .eq('shipment_id', id)
          .order('created_at', ascending: true);
          
      trackingEvents = (eventsData as List).map((e) => DeliveryTrackingEvent.fromJson(e)).toList();
    } catch (e) {
      debugPrint("TRACK SHIPMENT ERROR: $e");
      rethrow;
    } finally {
      isTracking = false;
      notifyListeners();
    }
  }

  // FIX pour delivery_checkout_page.dart
  Future<String> createShipment({
    required String senderName,
    required String senderPhone,
    required String receiverName,
    required String receiverPhone,
    String? receiverAddress,
    String? senderAddress,
    String? packageDescription,
  }) async {
    try {
      final user = _supa.auth.currentUser;
      if (user == null) throw Exception("Non connecté");
      if (selectedRoute == null) throw Exception("Aucune route sélectionnée");

      final trackingCode = "THX${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";
      
      final payload = {
        'sender_id': user.id,
        'from_city': fromCity,
        'to_city': toCity,
        'weight_kg': weightKg,
        'delivery_mode': deliveryMode.name,
        'price': calculatedPrice,
        'route_id': selectedRoute!.id,
        'tracking_code': trackingCode,
        'status': 'pending',
        'sender_name': senderName,
        'sender_phone': senderPhone,
        'receiver_name': receiverName,
        'receiver_phone': receiverPhone,
        'receiver_address': receiverAddress ?? '',
        'sender_address': senderAddress ?? '',
        'description': packageDescription ?? '',
      };

      // FIX : On récupère l'ID inséré pour générer le premier statut de tracking
      final insertedData = await _supa.from('delivery_shipments').insert(payload).select('id').single();

      // FIX : Création de l'événement initial (sinon le tracking sera vide au départ)
      await _supa.from('delivery_tracking_events').insert({
        'shipment_id': insertedData['id'],
        'status': 'pending',
        'location': fromCity,
        'description': 'Colis enregistré, en attente de ramassage',
      });

      await loadMyShipments(refresh: true);
      return trackingCode;
    } catch (e) {
      debugPrint("CREATE SHIPMENT ERROR: $e");
      rethrow;
    }
  }

  void setNational(bool v) { isNational = v; _recalculate(); notifyListeners(); }
  void setFromCity(String v) { fromCity = v.trim().toUpperCase(); _recalculate(); notifyListeners(); }
  void setToCity(String v) { toCity = v.trim().toUpperCase(); _recalculate(); notifyListeners(); }
  void swapCities() { final tmp = fromCity; fromCity = toCity; toCity = tmp; _recalculate(); notifyListeners(); }
  void setWeight(int w) { weightKg = w; _recalculate(); notifyListeners(); }
  void setMode(DeliveryMode m) { deliveryMode = m; _recalculate(); notifyListeners(); }

  void _recalculate() {
    calculatedPrice = 0;
    selectedRoute = null;
    if (fromCity.isEmpty || toCity.isEmpty) return;
    try {
      selectedRoute = popularRoutes.firstWhere(
        (r) => r.fromCity.toUpperCase() == fromCity.toUpperCase() &&
               r.toCity.toUpperCase() == toCity.toUpperCase(),
      );
      calculatedPrice = selectedRoute!.calculatePrice(weightKg: weightKg, mode: deliveryMode);
    } catch (_) {
      // Aucun trajet trouvé, le prix reste à 0 et la route est null
      calculatedPrice = 0;
    }
  }
}

class DeliveryTrackingEvent {
  final String status;
  final String location;
  final String description;
  final DateTime date;
  
  DeliveryTrackingEvent({
    required this.status, 
    required this.location, 
    required this.description, 
    required this.date
  });
  
  factory DeliveryTrackingEvent.fromJson(Map<String,dynamic> j) => DeliveryTrackingEvent(
    status: j['status'] ?? '',
    location: j['location'] ?? '',
    description: j['description'] ?? '',
    date: DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
  );
}
