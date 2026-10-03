// lib/services/supermarket_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'dart:typed_data';
import 'package:thix_id/presentation/thix_market/models/supermarket_models.dart';

class SupermarketService {
  final _client = Supabase.instance.client;
  static const _timeout = Duration(seconds: 12);

  // ──────────── CRÉATION SUPERMARCHÉ ────────────
  Future<String> createSupermarket({
    required String name,
    required String city,
    String? address,
    String? description,
    String? logoUrl,
    String? coverUrl,
  }) async {
    final ownerId = _client.auth.currentUser?.id;
    if (ownerId == null) throw Exception('Non connecté');

    final res = await _client
        .from('shops')
        .insert({
          'owner_id': ownerId,
          'name': name,
          'type': 'supermarket',
          'status': 'active',
          'city': city,
          'address': address,
          'description': description,
          'logo_url': logoUrl,
          'cover_url': coverUrl,
          'is_featured': false,
          'is_verified': false,
          'rating': 0,
          'followers_count': 0,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select('id')
        .single()
        .timeout(_timeout);
    return res['id'].toString();
  }

  /// Crée les 12 rayons standards d'un vrai supermarché.
  Future<void> createDefaultDepartments(String supermarketId) async {
    final rows = [
      for (int i = 0; i < kDefaultDepartments.length; i++)
        {
          'supermarket_id': supermarketId,
          'name': kDefaultDepartments[i].label,
          'icon_key': kDefaultDepartments[i].iconKey,
          'color_hex': kDefaultDepartments[i].colorHex,
          'position': i,
          'is_active': true,
        },
    ];
    await _client
        .from('supermarket_departments')
        .insert(rows)
        .timeout(_timeout);
  }

  Future<void> createDepartment({
    required String supermarketId,
    required String name,
    required String iconKey,
    required String colorHex,
    required int position,
  }) async {
    await _client.from('supermarket_departments').insert({
      'supermarket_id': supermarketId,
      'name': name,
      'icon_key': iconKey,
      'color_hex': colorHex,
      'position': position,
      'is_active': true,
    }).timeout(_timeout);
  }

  Future<void> deleteDepartment(String departmentId) async {
    await _client
        .from('supermarket_departments')
        .update({'is_active': false})
        .eq('id', departmentId)
        .timeout(_timeout);
  }

  // ──────────── LIAISON PRODUIT → RAYON ────────────
  Future<void> assignProductToDepartment(
      String productId, String departmentId, int aisleNumber) async {
    await _client.from('products').update({
      'department_id': departmentId,
      'aisle_number': aisleNumber,
    }).eq('id', productId).timeout(_timeout);
  }

  // ──────────── LECTURES ────────────
  Future<Map<String, dynamic>?> getSupermarket(String id) async {
    final res = await _client
        .from('shops')
        .select()
        .eq('id', id)
        .maybeSingle()
        .timeout(_timeout);
    return res == null ? null : Map<String, dynamic>.from(res);
  }

  Future<List<SupermarketDepartment>> getDepartments(String supermarketId) async {
    final res = await _client
        .from('supermarket_departments')
        .select()
        .eq('supermarket_id', supermarketId)
        .eq('is_active', true)
        .order('position')
        .timeout(_timeout);
    return (res as List)
        .map((e) => SupermarketDepartment.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getDepartmentProducts(
      String departmentId) async {
    final res = await _client
        .from('products')
        .select('id, title, price, discount_price, currency, image_url, stock, '
            'city, brand, created_at, shop:shops(name)')
        .eq('department_id', departmentId)
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(100)
        .timeout(_timeout);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> getSupermarketPromos(
      String supermarketId) async {
    final res = await _client
        .from('products')
        .select('id, title, price, discount_price, currency, image_url, stock, '
            'city, brand, created_at, shop:shops(name)')
        .eq('shop_id', supermarketId)
        .eq('status', 'active')
        .not('discount_price', 'is', null)
        .order('created_at', ascending: false)
        .limit(10)
        .timeout(_timeout);
    return List<Map<String, dynamic>>.from(res);
  }

  // ──────────── UPLOAD IMAGES ────────────
  Future<String?> uploadImage(String fileName, List<int> bytes,
      {String contentType = 'image/jpeg'}) async {
    final path = 'supermarkets/${const Uuid().v4()}-$fileName';
    await _client.storage
        .from('shop_images')
        .uploadBinary(path, Uint8List.fromList(bytes),
            fileOptions: FileOptions(contentType: contentType))
        .timeout(_timeout);
    return _client.storage.from('shop_images').getPublicUrl(path);
  }
}
