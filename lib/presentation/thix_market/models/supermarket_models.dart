// lib/presentation/thix_market/models/supermarket_models.dart
import 'package:flutter/material.dart';

// ============================================================================
// RAYON (allée) DU SUPERMARCHÉ
// ============================================================================
class SupermarketDepartment {
  final String id;
  final String supermarketId;
  final String name;
  final String iconKey;
  final String colorHex;
  final int position;
  final String? imageUrl;
  final int productCount;

  const SupermarketDepartment({
    required this.id,
    required this.supermarketId,
    required this.name,
    required this.iconKey,
    required this.colorHex,
    required this.position,
    this.imageUrl,
    this.productCount = 0,
  });

  factory SupermarketDepartment.fromJson(Map<String, dynamic> j) {
    return SupermarketDepartment(
      id: j['id']?.toString() ?? '',
      supermarketId: j['supermarket_id']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      iconKey: j['icon_key']?.toString() ?? 'basket',
      colorHex: j['color_hex']?.toString() ?? '#2563EB',
      position: (j['position'] as num?)?.toInt() ?? 0,
      imageUrl: j['image_url']?.toString(),
      productCount: (j['product_count'] as num?)?.toInt() ?? 0,
    );
  }

  Color get color {
    final hex = colorHex.replaceAll('#', '');
    final value = int.tryParse(hex, radix: 16);
    return value == null ? const Color(0xFF2563EB) : Color(0xFF000000 | value);
  }

  IconData get icon => kDepartmentIcons[iconKey] ?? Icons.shopping_basket_rounded;
}

// ============================================================================
// TEMPLATE DE RAYONS PAR DÉFAUT (à la création d'un supermarché)
// ============================================================================
class DepartmentTemplate {
  final String iconKey;
  final String label;
  final String colorHex;
  const DepartmentTemplate(this.iconKey, this.label, this.colorHex);
}

/// Les 12 rayons standards d'un vrai supermarché.
const List<DepartmentTemplate> kDefaultDepartments = [
  DepartmentTemplate('produce', 'Fruits & Légumes', '#16A34A'),
  DepartmentTemplate('butcher', 'Boucherie', '#DC2626'),
  DepartmentTemplate('fish', 'Poissonnerie', '#0891B2'),
  DepartmentTemplate('bakery', 'Boulangerie', '#D97706'),
  DepartmentTemplate('grocery', 'Épicerie salée', '#EA580C'),
  DepartmentTemplate('sweets', 'Épicerie sucrée', '#DB2777'),
  DepartmentTemplate('drinks', 'Boissons', '#2563EB'),
  DepartmentTemplate('dairy', 'Produits laitiers', '#60A5FA'),
  DepartmentTemplate('frozen', 'Surgelés', '#0EA5E9'),
  DepartmentTemplate('hygiene', 'Hygiène & Beauté', '#9333EA'),
  DepartmentTemplate('home', 'Entretien', '#0D9488'),
  DepartmentTemplate('baby', 'Bébé & Enfants', '#F472B6'),
];

// ============================================================================
// MAPPING ICÔNES (clé → IconData)
// ============================================================================
const Map<String, IconData> kDepartmentIcons = {
  'produce': Icons.eco_rounded,
  'butcher': Icons.restaurant_rounded,
  'fish': Icons.set_meal_rounded,
  'bakery': Icons.bakery_dining_rounded,
  'grocery': Icons.ramen_dining_rounded,
  'sweets': Icons.cake_rounded,
  'drinks': Icons.local_drink_rounded,
  'dairy': Icons.water_drop_rounded,
  'frozen': Icons.ac_unit_rounded,
  'hygiene': Icons.spa_rounded,
  'home': Icons.clean_hands_rounded,
  'baby': Icons.child_care_rounded,
  'basket': Icons.shopping_basket_rounded,
};
