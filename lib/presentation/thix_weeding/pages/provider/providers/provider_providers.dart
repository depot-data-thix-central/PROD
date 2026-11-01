//Créez un fichier lib/presentation/thix_weeding/pages/provider/providers/provider_providers. dart.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Catégories (10 catégories)
const List<Map<String, dynamic>> kProviderCategories = [
  {'key': 'salle', 'label': 'Salles', 'icon': 'villa'},
  {'key': 'traiteur', 'label': 'Traiteurs', 'icon': 'restaurant'},
  {'key': 'mc', 'label': 'MC & Animation', 'icon': 'mic'},
  {'key': 'decor', 'label': 'Décoration', 'icon': 'florist'},
  {'key': 'photo', 'label': 'Photographes', 'icon': 'camera'},
  {'key': 'video', 'label': 'Vidéastes', 'icon': 'videocam'},
  {'key': 'dj', 'label': 'DJ & Son', 'icon': 'music'},
  {'key': 'robe', 'label': 'Robes', 'icon': 'checkroom'},
  {'key': 'costume', 'label': 'Costumes', 'icon': 'checkroom'},
  {'key': 'autre', 'label': 'Autres', 'icon': 'grid'},
];

class ProviderModel {
  final String id;
  final String ownerId;
  final String uniqueCode;
  final String name;
  final String category;
  final String? description;
  final String? phone;
  final String? email;
  final String? address;
  final String? logoUrl;
  final String? coverUrl;
  final bool isVerified;
  final double rating;

  ProviderModel({
    required this.id,
    required this.ownerId,
    required this.uniqueCode,
    required this.name,
    required this.category,
    this.description,
    this.phone,
    this.email,
    this.address,
    this.logoUrl,
    this.coverUrl,
    this.isVerified = false,
    this.rating = 0.0,
  });

  factory ProviderModel.fromJson(Map<String, dynamic> j) => ProviderModel(
        id: j['id'],
        ownerId: j['owner_id'],
        uniqueCode: j['unique_code'] ?? '',
        name: j['name'],
        category: j['category'],
        description: j['description'],
        phone: j['phone'],
        email: j['email'],
        address: j['address'],
        logoUrl: j['logo_url'],
        coverUrl: j['cover_url'],
        isVerified: j['is_verified'] ?? false,
        rating: (j['rating'] as num?)?.toDouble() ?? 0.0,
      );
}

// Provider pour récupérer mon espace prestataire
final myProviderSpaceProvider = FutureProvider<ProviderModel?>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;
  
  final res = await Supabase.instance.client
      .from('thix_weeding_providers')
      .select()
      .eq('owner_id', user.id)
      .maybeSingle();
      
  if (res == null) return null;
  return ProviderModel.fromJson(res);
});

// Provider pour l'annuaire public (par catégorie)
final providersDirectoryProvider = FutureProvider.family<List<ProviderModel>, String>((ref, category) async {
  final query = Supabase.instance.client
      .from('thix_weeding_providers')
      .select()
      .eq('is_verified', true);
      
  if (category != 'all') {
    query.eq('category', category);
  }
  
  final res = await query.order('rating', ascending: false);
  return (res as List).map((e) => ProviderModel.fromJson(e)).toList();
});
