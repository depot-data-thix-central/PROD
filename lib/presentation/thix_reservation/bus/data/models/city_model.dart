/// ============================================================================
/// CityModel
/// ============================================================================
///
/// Représentation d'une ville dans le système THIX.
///
/// Utilisée pour :
/// - Sélecteur de villes de départ/arrivée
/// - Recherche et filtrage
/// - Affichage dans les listes
/// - Géolocalisation (futures features)
///
/// Features :
/// - Parsing robuste depuis JSON (gestion null, types incorrects)
/// - Serialization bidirectionnelle (toJson/fromJson)
/// - Égalité structurelle (== et hashCode)
/// - CopyWith pour modifications immuables
/// - Getters utilitaires (flag emoji, searchKey, displayName)
/// - Recherche fuzzy (matchesQuery)
/// - Support coordonnées GPS (lat/lng)
/// - Flag "populaire" pour tri prioritaire
/// - Validation des champs
///
/// ============================================================================
class CityModel {
  // ─── Identifiants ─────────────────────────────────────────
  final String id;
  final String name;
  final String countryCode;

  // ─── Médias ───────────────────────────────────────────────
  final String? imageUrl;

  // ─── Métadonnées ──────────────────────────────────────────
  final bool isPopular;
  final String? region;
  final double? latitude;
  final double? longitude;

  const CityModel({
    required this.id,
    required this.name,
    required this.countryCode,
    this.imageUrl,
    this.isPopular = false,
    this.region,
    this.latitude,
    this.longitude,
  });

  // ─── Factory from JSON ────────────────────────────────────
  factory CityModel.fromJson(Map<String, dynamic> json) {
    return CityModel(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      countryCode: ((json['country_code'] as String?) ?? 
                    (json['countryCode'] as String?) ?? 
                    '').toUpperCase(),
      imageUrl: json['image_url'] as String? ?? json['imageUrl'] as String?,
      isPopular: _parseBoolSafe(json['is_popular'] ?? json['isPopular']),
      region: json['region'] as String?,
      latitude: _parseDoubleSafe(json['latitude'] ?? json['lat']),
      longitude: _parseDoubleSafe(json['longitude'] ?? json['lng'] ?? json['lon']),
    );
  }

  // ─── Serialization to JSON ────────────────────────────────
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'country_code': countryCode,
      if (imageUrl != null) 'image_url': imageUrl,
      'is_popular': isPopular,
      if (region != null) 'region': region,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }

  // ─── CopyWith ─────────────────────────────────────────────
  CityModel copyWith({
    String? id,
    String? name,
    String? countryCode,
    String? imageUrl,
    bool? isPopular,
    String? region,
    double? latitude,
    double? longitude,
    bool clearImageUrl = false,
    bool clearRegion = false,
    bool clearLatitude = false,
    bool clearLongitude = false,
  }) {
    return CityModel(
      id: id ?? this.id,
      name: name ?? this.name,
      countryCode: countryCode ?? this.countryCode,
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
      isPopular: isPopular ?? this.isPopular,
      region: clearRegion ? null : (region ?? this.region),
      latitude: clearLatitude ? null : (latitude ?? this.latitude),
      longitude: clearLongitude ? null : (longitude ?? this.longitude),
    );
  }

  // ─── Getters utilitaires ──────────────────────────────────

  /// Nom formaté pour affichage (avec pays si disponible)
  String get displayName {
    if (countryCode.isEmpty) return name;
    return '$name, $countryCode';
  }

  /// Drapeau emoji du pays
  /// Ex: "CD" → "🇨🇩", "FR" → "🇫🇷"
  String get flag {
    if (countryCode.isEmpty || countryCode.length != 2) return '🏙️';
    
    final code = countryCode.toUpperCase();
    final base = 0x1F1E6; // Regional Indicator Symbol Letter A
    final first = base + (code.codeUnitAt(0) - 65);
    final second = base + (code.codeUnitAt(1) - 65);
    
    return String.fromCharCodes([first, second]);
  }

  /// Clé de recherche normalisée (lowercase, sans accents)
  /// Utilisée pour le filtrage et la recherche
  String get searchKey {
    return _normalizeString('$name $countryCode $region');
  }

  /// La ville est-elle valide ? (champs obligatoires présents)
  bool get isValid =>
      id.isNotEmpty &&
      name.isNotEmpty &&
      countryCode.length == 2;

  /// La ville a-t-elle des coordonnées GPS ?
  bool get hasCoordinates => latitude != null && longitude != null;

  /// La ville a-t-elle une image ?
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  /// Vérifie si la ville correspond à une requête de recherche
  /// (insensible à la casse et aux accents)
  bool matchesQuery(String query) {
    if (query.isEmpty) return true;
    final normalizedQuery = _normalizeString(query);
    return searchKey.contains(normalizedQuery);
  }

  /// Distance approximative avec une autre ville (en km)
  /// Utilise la formule de Haversine si coordonnées disponibles
  double? distanceTo(CityModel other) {
    if (!hasCoordinates || !other.hasCoordinates) return null;

    const earthRadius = 6371.0; // km

    final lat1 = latitude! * (3.14159265359 / 180);
    final lat2 = other.latitude! * (3.14159265359 / 180);
    final deltaLat = (other.latitude! - latitude!) * (3.14159265359 / 180);
    final deltaLon = (other.longitude! - longitude!) * (3.14159265359 / 180);

    final a = _sin(deltaLat / 2) * _sin(deltaLat / 2) +
        _cos(lat1) * _cos(lat2) * _sin(deltaLon / 2) * _sin(deltaLon / 2);
    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));

    return earthRadius * c;
  }

  // ─── Égalité et hash ──────────────────────────────────────
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CityModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          countryCode == other.countryCode;

  @override
  int get hashCode => Object.hash(id, name, countryCode);

  @override
  String toString() {
    return 'CityModel($name, $countryCode${isPopular ? ", popular" : ""})';
  }

  // ─── Helpers de parsing ───────────────────────────────────
  static bool _parseBoolSafe(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      return lower == 'true' || lower == '1' || lower == 'yes';
    }
    return false;
  }

  static double? _parseDoubleSafe(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static String _normalizeString(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ýÿ]'), 'y')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .trim();
  }

  // ─── Helpers mathématiques (pour distanceTo) ──────────────
  static double _sin(double x) => _math.sin(x);
  static double _cos(double x) => _math.cos(x);
  static double _sqrt(double x) => _math.sqrt(x);
  static double _atan2(double y, double x) => _math.atan2(y, x);
}

// Import math pour les calculs de distance
import 'dart:math' as _math;

/// ============================================================================
/// CityExtensions — Extensions utilitaires pour List<CityModel>
/// ============================================================================
extension CityListExtensions on List<CityModel> {
  /// Filtre les villes selon une requête
  List<CityModel> search(String query) {
    if (query.isEmpty) return this;
    return where((city) => city.matchesQuery(query)).toList();
  }

  /// Trie les villes : populaires d'abord, puis alphabétique
  List<CityModel> sortedByPopularity() {
    final sorted = List<CityModel>.from(this);
    sorted.sort((a, b) {
      // Populaires d'abord
      if (a.isPopular != b.isPopular) {
        return a.isPopular ? -1 : 1;
      }
      // Puis alphabétique
      return a.name.compareTo(b.name);
    });
    return sorted;
  }

  /// Groupe les villes par pays
  Map<String, List<CityModel>> groupByCountry() {
    final map = <String, List<CityModel>>{};
    for (final city in this) {
      map.putIfAbsent(city.countryCode, () => []).add(city);
    }
    return map;
  }

  /// Récupère les villes populaires
  List<CityModel> get popular => where((c) => c.isPopular).toList();

  /// Récupère une ville par ID
  CityModel? findById(String id) {
    try {
      return firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Récupère une ville par nom
  CityModel? findByName(String name) {
    try {
      return firstWhere((c) => c.name.toLowerCase() == name.toLowerCase());
    } catch (_) {
      return null;
    }
  }
}
