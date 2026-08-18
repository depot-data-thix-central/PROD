enum StatutObjet { perdu, trouve, recupere }

class ObjetModel {
  final String id;
  final String titre;
  final String description;
  final StatutObjet statut;
  final String lieu;
  final DateTime date;
  final String? imageUrl;
  final String? recompense;
  final double? latitude;
  final double? longitude;
  final String? categorie;
  final String? userId;
  final String? contactInfo;
  final DateTime createdAt;

  const ObjetModel({
    required this.id,
    required this.titre,
    required this.description,
    required this.statut,
    required this.lieu,
    required this.date,
    this.imageUrl,
    this.recompense,
    this.latitude,
    this.longitude,
    this.categorie,
    this.userId,
    this.contactInfo,
    required this.createdAt,
  });

  bool get hasRecompense => recompense != null && recompense!.isNotEmpty;

  String get statutLabel {
    switch (statut) {
      case StatutObjet.perdu:
        return 'PERDU';
      case StatutObjet.trouve:
        return 'TROUVÉ';
      case StatutObjet.recupere:
        return 'RÉCUPÉRÉ';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'titre': titre,
        'description': description,
        'statut': statut.name,
        'lieu': lieu,
        'date': date.toIso8601String(),
        'image_url': imageUrl,
        'recompense': recompense,
        'latitude': latitude,
        'longitude': longitude,
        'categorie': categorie,
        'user_id': userId,
        'contact_info': contactInfo,
        'created_at': createdAt.toIso8601String(),
      };

  factory ObjetModel.fromJson(Map<String, dynamic> json) {
    return ObjetModel(
      id: json['id'] as String,
      titre: json['titre'] as String,
      description: json['description'] as String? ?? '',
      statut: StatutObjet.values.firstWhere(
        (e) => e.name == json['statut'],
        orElse: () => StatutObjet.perdu,
      ),
      lieu: json['lieu'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      imageUrl: json['image_url'] as String?,
      recompense: json['recompense'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      categorie: json['categorie'] as String?,
      userId: json['user_id'] as String?,
      contactInfo: json['contact_info'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
