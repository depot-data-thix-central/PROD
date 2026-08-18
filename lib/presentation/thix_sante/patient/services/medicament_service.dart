import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/medicament_model.dart';

class MedicamentService {
  final _db = Supabase.instance.client;
  static const _pharmaTable = 'thix_pharmacies';
  static const _medTable = 'thix_medicines';
  static const _cartTable = 'thix_medicine_cart';

  // ===== PHARMACIES =====
  Future<List<ThixPharmacy>> getNearbyPharmacies({double? lat, double? lng, String? category, String? search}) async {
    var query = _db.from(_pharmaTable).select().eq('is_open', true);
    if(search!=null && search.isNotEmpty) {
      query = query.ilike('nom', '%$search%');
    }
    final res = await query.order('rating', ascending: false).limit(30);
    var pharmacies = (res as List).map((e)=> ThixPharmacy.fromJson(e)).toList();

    if(lat!=null && lng!=null) {
      for(var p in pharmacies) { p.calculateDistance(lat, lng); }
      pharmacies.sort((a,b)=> (a.distanceKm??999).compareTo(b.distanceKm??999));
    }

    if(category!=null) {
      final meds = await _db.from(_medTable).select('pharmacy_id').eq('categorie', category).gt('stock', 0);
      final ids = meds.map((e)=> e['pharmacy_id']).toSet();
      pharmacies = pharmacies.where((p)=> ids.contains(p.id)).toList();
    }
    return pharmacies;
  }

  // ===== MEDICAMENTS =====
  Future<List<ThixMedicine>> getMedicinesByPharmacy(String pharmacyId) async {
    final res = await _db.from(_medTable).select().eq('pharmacy_id', pharmacyId).gt('stock', 0).order('nom');
    return (res as List).map((e)=> ThixMedicine.fromJson(e)).toList();
  }

  Future<List<ThixMedicine>> searchMedicines({required String query, String? filter, String? category}) async {
    var req = _db.from(_medTable).select('*, thix_pharmacies(*)');
    if(query.isNotEmpty) {
      req = req.or('nom.ilike.%$query%,dci.ilike.%$query%');
    }
    if(category!=null) req = req.eq('categorie', category);
    if(filter=='dispo') req = req.gt('stock', 0);
    
    // Order
    if(filter=='prixAsc') req = req.order('prix', ascending: true);
    else if(filter=='prixDesc') req = req.order('prix', ascending: false);
    else if(filter=='stock') req = req.order('stock', ascending: false);
    else req = req.order('nom');

    final res = await req.limit(100);
    return (res as List).map((e)=> ThixMedicine.fromJson(e)).toList();
  }

  // ===== CART - FULL PROD =====
  Future<List<ThixCartItem>> getCart() async {
    final user = _db.auth.currentUser;
    if(user==null) return [];
    final res = await _db.from(_cartTable).select('*, thix_medicines(*, thix_pharmacies(*))').eq('user_id', user.id).order('created_at');
    return (res as List).map((e)=> ThixCartItem.fromJson(e)).toList();
  }

  Future<void> addToCart(String medicineId, {int quantity=1}) async {
    final user = _db.auth.currentUser;
    if(user==null) throw Exception('Non connecté');
    // upsert: si existe déjà on incrémente
    final existing = await _db.from(_cartTable).select().eq('user_id', user.id).eq('medicine_id', medicineId).maybeSingle();
    if(existing!=null) {
      await _db.from(_cartTable).update({'quantity': (existing['quantity'] as int)+quantity}).eq('id', existing['id']);
    } else {
      await _db.from(_cartTable).insert({'user_id': user.id, 'medicine_id': medicineId, 'quantity': quantity});
    }
  }

  Future<void> updateQuantity(String medicineId, int quantity) async {
    final user = _db.auth.currentUser;
    if(user==null) return;
    if(quantity<=0) {
      await _db.from(_cartTable).delete().eq('user_id', user.id).eq('medicine_id', medicineId);
    } else {
      await _db.from(_cartTable).update({'quantity': quantity}).eq('user_id', user.id).eq('medicine_id', medicineId);
    }
  }

  Future<void> removeFromCart(String medicineId) async {
    final user = _db.auth.currentUser;
    if(user==null) return;
    await _db.from(_cartTable).delete().eq('user_id', user.id).eq('medicine_id', medicineId);
  }

  Future<void> clearCart() async {
    final user = _db.auth.currentUser;
    if(user==null) return;
    await _db.from(_cartTable).delete().eq('user_id', user.id);
  }

  // ===== COMMANDE =====
  Future<String> createOrder({required String pharmacyId, required double total, String? notes}) async {
    final user = _db.auth.currentUser;
    if(user==null) throw Exception('Non connecté');
    final cart = await getCart();
    if(cart.isEmpty) throw Exception('Panier vide');

    final order = await _db.from('thix_medicine_orders').insert({
      'user_id': user.id,
      'pharmacy_id': pharmacyId,
      'total': total,
      'status': 'en_cours',
      'delivery_time_min': 20,
      'notes': notes,
    }).select().single();

    // items
    final items = cart.map((c)=> {
      'order_id': order['id'],
      'medicine_id': c.medicineId,
      'quantity': c.quantity,
      'prix': c.medicine?.prix??0,
    }).toList();
    await _db.from('thix_medicine_order_items').insert(items);

    // Clear cart après commande
    await clearCart();
    return order['id'] as String;
  }
}
