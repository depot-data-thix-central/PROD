/// THIX RECHERCHE — Modèle production
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
  final String? photoUrl;
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
    final d =
        '\( {l.day.toString().padLeft(2, '0')}/ \){l.month.toString().padLeft(2, '0')}/${l.year}';
    final h =
        '\( {l.hour.toString().padLeft(2, '0')}: \){l.minute.toString().padLeft(2, '0')}';
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
        'photo_url': photoUrl,
        'derniere_zone': derniereZone?.trim(),
        'derniere_vue_at': derniereVueAt?.toIso8601String(),
        'description': description?.trim(),
        'contact_info': contactInfo?.trim(),
        'created_by': createdBy,
        'is_active': isActive,
      };
}
