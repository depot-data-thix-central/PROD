// lib/presentation/mon_pays/models/province_minister.dart

class ProvinceMinister {
  final String id;
  final String governmentId;
  final String? authorityId;
  final String portfolio;
  
  // Nouveaux champs ajoutés
  final String? name;
  final String? biography;

  ProvinceMinister({
    required this.id,
    required this.governmentId,
    this.authorityId,
    required this.portfolio,
    this.name,
    this.biography,
  });

  factory ProvinceMinister.fromJson(Map<String, dynamic> json) {
    return ProvinceMinister(
      id: json['id'] as String? ?? '',
      governmentId: json['government_id'] as String? ?? '',
      authorityId: json['authority_id'] as String?,
      portfolio: json['portfolio'] as String? ?? '',
      name: json['name'] as String?,
      biography: json['biography'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'government_id': governmentId,
      'authority_id': authorityId,
      'portfolio': portfolio,
      'name': name,
      'biography': biography,
    };
  }
}
