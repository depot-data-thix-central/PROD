class ProvinceAdministrativeDivision {
  final String id;
  final String provinceId;
  final String type;
  final String name;
  final String? capital;
  final int? population;
  final double? area;
  final String? administrator;
  final List<Map<String, dynamic>>? media;

  const ProvinceAdministrativeDivision({
    required this.id, required this.provinceId, required this.type, required this.name,
    this.capital, this.population, this.area, this.administrator, this.media,
  });

  factory ProvinceAdministrativeDivision.fromJson(Map<String, dynamic> json) {
    return ProvinceAdministrativeDivision(
      id: json['id']?.toString() ?? '', provinceId: json['province_id']?.toString() ?? '',
      type: json['type']?.toString() ?? '', name: json['name']?.toString() ?? '',
      capital: json['capital']?.toString(), population: json['population'] != null ? int.tryParse(json['population'].toString()) : null,
      area: json['area'] != null ? double.tryParse(json['area'].toString()) : null,
      administrator: json['administrator']?.toString(),
      media: json['media'] != null ? List<Map<String, dynamic>>.from(json['media']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id.isEmpty ? null : id, 'province_id': provinceId, 'type': type, 'name': name,
    'capital': capital, 'population': population, 'area': area, 'administrator': administrator, 'media': media,
  };
}
