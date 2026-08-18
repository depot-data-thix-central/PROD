import 'dart:math';

class ThixPharmacy {
  final String id;
  final String nom;
  final String adresse;
  final double lat;
  final double lng;
  final double rating;
  final int totalRatings;
  final int deliveryTimeMin;
  final String? imageUrl;
  final bool isOpen;
  double? distanceKm;

  ThixPharmacy({
    required this.id, required this.nom, required this.adresse,
    required this.lat, required this.lng, required this.rating,
    required this.totalRatings, required this.deliveryTimeMin,
    this.imageUrl, required this.isOpen, this.distanceKm,
  });

  factory ThixPharmacy.fromJson(Map<String,dynamic> json) {
    return ThixPharmacy(
      id: json['id'], nom: json['nom']??'', adresse: json['adresse']??'Central Park',
      lat: (json['lat'] as num?)?.toDouble()??0, lng: (json['lng'] as num?)?.toDouble()??0,
      rating: (json['rating'] as num?)?.toDouble()??4.5,
      totalRatings: json['total_ratings']??256,
      deliveryTimeMin: json['delivery_time_min']??20,
      imageUrl: json['image_url'], isOpen: json['is_open']??true,
    );
  }

  double calculateDistance(double userLat, double userLng) {
    const R = 6371;
    final dLat = (lat - userLat) * pi / 180;
    final dLng = (lng - userLng) * pi / 180;
    final a = sin(dLat/2)*sin(dLat/2) + cos(userLat*pi/180)*cos(lat*pi/180)*sin(dLng/2)*sin(dLng/2);
    final c = 2*atan2(sqrt(a), sqrt(1-a));
    distanceKm = R*c;
    return distanceKm!;
  }
}

class ThixMedicine {
  final String id;
  final String pharmacyId;
  final String nom;
  final String? dci;
  final String categorie;
  final double prix;
  final int stock;
  final bool prescriptionRequise;
  final String packSize;
  final String? imageUrl;
  final String? description;
  ThixPharmacy? pharmacy;

  ThixMedicine({
    required this.id, required this.pharmacyId, required this.nom,
    this.dci, required this.categorie, required this.prix, required this.stock,
    required this.prescriptionRequise, required this.packSize,
    this.imageUrl, this.description, this.pharmacy,
  });

  factory ThixMedicine.fromJson(Map<String,dynamic> json) {
    return ThixMedicine(
      id: json['id'], pharmacyId: json['pharmacy_id'], nom: json['nom'],
      dci: json['dci'], categorie: json['categorie']??'Pain Relief',
      prix: (json['prix'] as num?)?.toDouble()??0, stock: json['stock']??0,
      prescriptionRequise: json['prescription_requise']??false,
      packSize: json['pack_size']??'Pack of 10',
      imageUrl: json['image_url'], description: json['description'],
      pharmacy: json['thix_pharmacies']!=null? ThixPharmacy.fromJson(json['thix_pharmacies']) : null,
    );
  }

  bool get isAvailable => stock > 0;
}

class ThixCartItem {
  final String id;
  final String userId;
  final String medicineId;
  final int quantity;
  final ThixMedicine? medicine;
  final DateTime createdAt;

  ThixCartItem({required this.id, required this.userId, required this.medicineId, required this.quantity, this.medicine, required this.createdAt});

  factory ThixCartItem.fromJson(Map<String,dynamic> json) {
    return ThixCartItem(
      id: json['id'], userId: json['user_id'], medicineId: json['medicine_id'],
      quantity: json['quantity']??1,
      medicine: json['thix_medicines']!=null? ThixMedicine.fromJson(json['thix_medicines']) : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  double get total => (medicine?.prix??0) * quantity;
}
