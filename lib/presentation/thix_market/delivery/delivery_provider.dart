// lib/presentation/thix_market/delivery/delivery_provider.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── DÉCLARATION GLOBALE RIVERPOD ───
final deliveryProvider = ChangeNotifierProvider<DeliveryProvider>((ref) {
  return DeliveryProvider()..init();
});

class DeliveryProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  // État des adresses
  List<Map<String, dynamic>> _addresses = [];
  Map<String, dynamic>? _selectedAddress;
  bool _isLoadingAddresses = false;

  // État du tracking
  Map<String, dynamic>? _currentTracking;
  bool _isLoadingTracking = false;
  String? _errorTracking;

  // Getters
  List<Map<String, dynamic>> get addresses => _addresses;
  Map<String, dynamic>? get selectedAddress => _selectedAddress;
  bool get isLoadingAddresses => _isLoadingAddresses;
  Map<String, dynamic>? get currentTracking => _currentTracking;
  bool get isLoadingTracking => _isLoadingTracking;
  String? get errorTracking => _errorTracking;

  // --- INITIALISATION ---
  Future<void> init() async {
    await loadAddresses();
  }

  // --- TRACKING ---
  Future<void> trackDelivery(String orderId) async {
    _isLoadingTracking = true;
    _errorTracking = null;
    notifyListeners();

    try {
      final tracking = await _supabase
          .from('delivery_tracking')
          .select()
          .eq('order_id', orderId)
          .maybeSingle();

      if (tracking == null) {
        _currentTracking = null;
      } else {
        _currentTracking = {
          ...tracking,
          'driver': {
            'name': tracking['driver_name'] ?? 'Livreur THIX',
            'phone': tracking['driver_phone'] ?? '',
            'vehicle': tracking['vehicle'] ?? 'Moto',
            'current_lat': tracking['current_lat'],
            'current_lng': tracking['current_lng'],
          }
        };
      }
    } catch (e) {
      _errorTracking = e.toString();
      _currentTracking = null;
    } finally {
      _isLoadingTracking = false;
      notifyListeners();
    }
  }

  // --- GESTION ADRESSES ---
  Future<void> loadAddresses() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    _isLoadingAddresses = true;
    notifyListeners();

    try {
      final res = await _supabase
          .from('addresses')
          .select()
          .eq('user_id', uid)
          .order('is_default', ascending: false);

      _addresses = List<Map<String, dynamic>>.from(res);

      // Auto-sélection de l'adresse par défaut si aucune n'est sélectionnée
      if (_selectedAddress == null && _addresses.isNotEmpty) {
        _selectedAddress = _addresses.firstWhere(
          (a) => a['is_default'] == true,
          orElse: () => _addresses.first,
        );
      }
    } catch (e) {
      debugPrint('Error loading addresses: $e');
    } finally {
      _isLoadingAddresses = false;
      notifyListeners();
    }
  }

  Future<void> addAddress(Map<String, dynamic> address) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      throw Exception('Vous devez être connecté pour ajouter une adresse');
    }

    try {
      // Sécurité : une seule adresse par défaut
      if (address['is_default'] == true) {
        await _supabase
            .from('addresses')
            .update({'is_default': false})
            .eq('user_id', uid);
      }

      final res = await _supabase
          .from('addresses')
          .insert({...address, 'user_id': uid})
          .select()
          .single();

      _addresses.insert(0, res);

      // Auto-sélection
      if (address['is_default'] == true || _selectedAddress == null) {
        _selectedAddress = res;
      }

      notifyListeners();
      await loadAddresses();
    } catch (e) {
      debugPrint('Error adding address: $e');
      rethrow; // ← important : remonte l'erreur à l'UI
    }
  }

  Future<void> deleteAddress(String addressId) async {
    try {
      await _supabase.from('addresses').delete().eq('id', addressId);
      _addresses.removeWhere((a) => a['id'] == addressId);

      if (_selectedAddress?['id'] == addressId) {
        _selectedAddress = _addresses.isNotEmpty ? _addresses.first : null;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting address: $e');
      rethrow;
    }
  }

  Future<void> updateAddress(String id, Map<String, dynamic> data) async {
    final uid = _supabase.auth.currentUser?.id;

    try {
      if (data['is_default'] == true && uid != null) {
        await _supabase
            .from('addresses')
            .update({'is_default': false})
            .eq('user_id', uid);
      }

      await _supabase.from('addresses').update(data).eq('id', id);
      await loadAddresses();
    } catch (e) {
      debugPrint('Error updating address: $e');
      rethrow;
    }
  }

  void selectAddress(Map<String, dynamic> a) {
    _selectedAddress = a;
    notifyListeners();
  }

  void reset() {
    _selectedAddress = null;
    _currentTracking = null;
    notifyListeners();
  }
}
