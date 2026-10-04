// lib/presentation/thix_market/providers/supermarket_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/presentation/thix_market/models/supermarket_models.dart';
import 'package:thix_id/services/supermarket_service.dart';

final supermarketServiceProvider = Provider<SupermarketService>((ref) {
  return SupermarketService();
});

/// Détails du supermarché (shop row)
final supermarketDetailsProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, id) async {
  return ref.watch(supermarketServiceProvider).getSupermarket(id);
});

/// Liste des rayons (allées)
final departmentsProvider =
    FutureProvider.family<List<SupermarketDepartment>, String>((ref, id) async {
  return ref.watch(supermarketServiceProvider).getDepartments(id);
});

/// Produits d'un rayon
final departmentProductsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, deptId) async {
  return ref.watch(supermarketServiceProvider).getDepartmentProducts(deptId);
});

/// Promos du supermarché
final supermarketPromosProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, id) async {
  return ref.watch(supermarketServiceProvider).getSupermarketPromos(id);
});


/// Tous les produits actifs du supermarché (pour la gestion des rayons)
final supermarketAllProductsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, shopId) async {
  final res = await Supabase.instance.client
      .from('products')
      .select('id, title, price, discount_price, currency, image_url, stock, '
          'department_id, aisle_number')
      .eq('shop_id', shopId)
      .eq('status', 'active')
      .order('created_at', ascending: false)
      .limit(300)
      .timeout(const Duration(seconds: 12));
  return List<Map<String, dynamic>>.from(res);
});
