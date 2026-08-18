// lib/presentation/mon_pays/models/province_emergency.dart

class ProvinceEmergencyContact {
  final String id;
  final String provinceId;
  final String service; // 'Police provinciale', 'Protection Civile', 'Hôpital de référence', 'Pompiers', 'Ambulance'
  final String phone;
  final String? address;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProvinceEmergencyContact({
    required this.id,
    required this.provinceId,
    required this.service,
    required this.phone,
    this.address,
    this.createdAt,
    this.updatedAt,
  });

  factory ProvinceEmergencyContact.fromJson(Map<String, dynamic> json) {
    return ProvinceEmergencyContact(
      id: json['id'] as String,
      provinceId: json['province_id'] as String,
      service: json['service'] as String,
      phone: json['phone'] as String,
      address: json['address'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'province_id': provinceId,
    'service': service,
    'phone': phone,
    'address': address,
  };
}
