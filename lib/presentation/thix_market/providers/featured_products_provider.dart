
// lib/presentation/thix_market/providers/featured_products_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Produits marqués "Bannière Vedette (Hero)" dans le formulaire de
/// publication (is_featured = true). Alimente à la fois le hero banner
/// et la bande "Produits en vedette" de la home.
/// Connexion directe et autonome à Supabase — n'a plus besoin de
/// bannersProvider, ce qui corrige le souci de connexion.
final featuredProductsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await Supabase.instance.client
      .from('products')
      .select()
      .eq('is_featured', true)
      .eq('status', 'active')
      .order('updated_at', ascending: false)
      .limit(12);
  return List<Map<String, dynamic>>.from(res as List);
});
