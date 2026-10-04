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
// PRODUIT DE SUPERMARCHÉ (Modèle Enrichi)
// ============================================================================
class SupermarketProduct {
  final String id;
  final String? shopId;
  final String? departmentId;
  final String? aisleNumber;
  final String title;
  final double price;
  final double? discountPrice;
  final String currency;
  final String? imageUrl;
  final num stock;
  final String? barcode;
  final bool isPerishable;
  final String? expiryDate;
  final bool isPromotion;
  final String? description;
  final String? unitMeasurement; // ex: kg, g, ml, L
  final String? brand;
  final String? origin;
  final String? nutritionalInfo;
  final String status;

  const SupermarketProduct({
    required this.id,
    this.shopId,
    this.departmentId,
    this.aisleNumber,
    required this.title,
    required this.price,
    this.discountPrice,
    required this.currency,
    this.imageUrl,
    this.stock = 0,
    this.barcode,
    this.isPerishable = false,
    this.expiryDate,
    this.isPromotion = false,
    this.description,
    this.unitMeasurement,
    this.brand,
    this.origin,
    this.nutritionalInfo,
    this.status = 'active',
  });

  factory SupermarketProduct.fromJson(Map<String, dynamic> j) {
    return SupermarketProduct(
      id: j['id']?.toString() ?? '',
      shopId: j['shop_id']?.toString(),
      departmentId: j['department_id']?.toString(),
      aisleNumber: j['aisle_number']?.toString(),
      title: j['title']?.toString() ?? '',
      price: (j['price'] as num?)?.toDouble() ?? 0.0,
      discountPrice: (j['discount_price'] as num?)?.toDouble(),
      currency: j['currency']?.toString() ?? 'CDF',
      imageUrl: j['image_url']?.toString(),
      stock: j['stock'] as num? ?? 0,
      barcode: j['barcode']?.toString(),
      isPerishable: j['is_perishable'] == true || j['is_perishable'] == 1,
      expiryDate: j['expiry_date']?.toString(),
      isPromotion: j['is_promotion'] == true || j['is_promotion'] == 1,
      description: j['description']?.toString(),
      unitMeasurement: j['unit_measurement']?.toString(),
      brand: j['brand']?.toString(),
      origin: j['origin']?.toString(),
      nutritionalInfo: j['nutritional_info']?.toString(),
      status: j['status']?.toString() ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_id': shopId,
      'department_id': departmentId,
      'aisle_number': aisleNumber,
      'title': title,
      'price': price,
      'discount_price': discountPrice,
      'currency': currency,
      'image_url': imageUrl,
      'stock': stock,
      'barcode': barcode,
      'is_perishable': isPerishable,
      'expiry_date': expiryDate,
      'is_promotion': isPromotion,
      'description': description,
      'unit_measurement': unitMeasurement,
      'brand': brand,
      'origin': origin,
      'nutritional_info': nutritionalInfo,
      'status': status,
    };
  }
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
