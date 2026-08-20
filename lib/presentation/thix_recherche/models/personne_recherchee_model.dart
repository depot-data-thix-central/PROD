/// THIX RECHERCHE — Modèle production

enum CategorieAlerte {
  disparitionInquietante,
  fugue,
  enlevement,
  autre,
}

extension CategorieAlerteX on CategorieAlerte {
  String get dbValue {
    switch (this) {
      case CategorieAlerte.disparitionInquietante:
        return 'disparition_inquietante';
      case CategorieAlerte.fugue:
        return 'fugue';
      case CategorieAlerte.enlevement:
        return 'enlevement';
      case CategorieAlerte.autre:
        return 'autre';
    }
  }

  String get labelFr {
    switch (this) {
      case CategorieAlerte.disparitionInquietante:
        return 'Disparition inquiétante';
      case CategorieAlerte.fugue:
        return 'Fugue';
      case CategorieAlerte.enlevement:
        return 'Enlèvement';
      case CategorieAlerte.autre:
        return 'Autre';
    }
  }

  static CategorieAlerte fromDb(String? v) {
    switch (v) {
      case 'fugue':
        return CategorieAlerte.fugue;
      case 'enlevement':
        return CategorieAlerte.enlevement;
      case 'autre':
        return CategorieAlerte.autre;
      default:
        return CategorieAlerte.disparitionInquietante;
    }
  }
}

enum TypeAlerte { disparue, recherchee }

enum StatutAlerte { active, retrouvee, archivee }

class PersonneRecherchee {
  final String id;
  final String nom;
  final String? prenom;
  final int? age;
  final String? sexe; // F | M | X
  final double? tailleCm;
  final TypeAlerte typeAlerte;
  final StatutAlerte statut;
  
  // --- Nouveaux champs ---
  final CategorieAlerte? categorie;
  final double? latitude;
  final double? longitude;
  final List<String> photoUrls; // 0..3
  // -----------------------
  
  final String? photoUrl; // Conservé pour rétrocompatibilité
  final String? derniereZone;
  final DateTime? derniereVueAt;
  final String? description;
  final String? contactInfo;
  final String? createdBy;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PersonneRecherchee({
    required this.id,
    required this.nom,
    this.prenom,
    this.age,
    this.sexe,
    this.tailleCm,
    required this.typeAlerte,
    required this.statut,
    this.categorie,
    this.latitude,
    this.longitude,
    this.photoUrls = const [],
    this.photoUrl,
    this.derniereZone,
    this.derniereVueAt,
    this.description,
    this.contactInfo,
    this.createdBy,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  String get nomComplet {
    final p = prenom?.trim();
    if (p == null || p.isEmpty) return nom;
    return '$prenom $nom'.trim();
  }

  String get badgeLabel {
    if (typeAlerte == TypeAlerte.disparue) {
      return (sexe == 'F') ? 'DISPARUE' : 'DISPARU';
    }
    return (sexe == 'F') ? 'RECHERCHÉE' : 'RECHERCHÉ';
  }

  String get metaLine {
    final parts = <String>[];
    if (age != null) parts.add('$age ans');
    if (sexe != null) parts.add(sexe!);
    if (tailleCm != null) {
      final m = (tailleCm! / 100).toStringAsFixed(2).replaceAll('.', ',');
      parts.add('$m m');
    }
    return parts.join(' • ');
  }

  String get derniereVueLabel {
    if (derniereZone == null || derniereZone!.isEmpty) {
      return 'Dernière vue : inconnue';
    }
    final date = derniereVueAt;
    if (date == null) return 'Dernière vue : $derniereZone';
    
    final l = date.toLocal();
    final d = '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year}';
    final h = '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
    
    return 'Dernière vue : $derniereZone\nle $d à $h';
  }

  String timeAgoLabel() {
    final diff = DateTime.now().difference(createdAt.toLocal());
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays == 1) return 'Il y a 1j';
    return 'Il y a ${diff.inDays}j';
  }

  factory PersonneRecherchee.fromJson(Map<String, dynamic> json) {
    return PersonneRecherchee(
      id: json['id'] as String,
      nom: (json['nom'] as String?)?.trim() ?? '',
      prenom: json['prenom'] as String?,
      age: json['age'] as int?,
      sexe: json['sexe'] as String?,
      tailleCm: (json['taille_cm'] as num?)?.toDouble(),
      typeAlerte: TypeAlerte.values.firstWhere(
        (e) => e.name == json['type_alerte'],
        orElse: () => TypeAlerte.disparue,
      ),
      statut: StatutAlerte.values.firstWhere(
        (e) => e.name == json['statut'],
        orElse: () => StatutAlerte.active,
      ),
      
      // --- Parsing des nouveaux champs ---
      categorie: CategorieAlerteX.fromDb(json['categorie'] as String?),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      photoUrls: (json['photo_urls'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          (json['photo_url'] != null ? [json['photo_url'] as String] : []),
      // -----------------------------------
      
      photoUrl: json['photo_url'] as String?,
      derniereZone: json['derniere_zone'] as String?,
      derniereVueAt: DateTime.tryParse(json['derniere_vue_at'] as String? ?? ''),
      description: json['description'] as String?,
      contactInfo: json['contact_info'] as String?,
      createdBy: json['created_by'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'nom': nom.trim(),
        'prenom': prenom?.trim(),
        'age': age,
        'sexe': sexe,
        'taille_cm': tailleCm,
        'type_alerte': typeAlerte.name,
        'statut': statut.name,
        
        // --- Ajout à l'insertion ---
        'categorie': categorie?.dbValue,
        'latitude': latitude,
        'longitude': longitude,
        'photo_urls': photoUrls,
        // ---------------------------
        
        // On s'assure que Supabase reçoit au moins la première image dans l'ancienne colonne si elle existe
        'photo_url': photoUrl ?? (photoUrls.isNotEmpty ? photoUrls.first : null), 
        'derniere_zone': derniereZone?.trim(),
        'derniere_vue_at': derniereVueAt?.toIso8601String(),
        'description': description?.trim(),
        'contact_info': contactInfo?.trim(),
        'created_by': createdBy,
        'is_active': isActive,
      };
}
