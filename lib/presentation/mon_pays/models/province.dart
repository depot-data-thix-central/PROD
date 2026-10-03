// lib/presentation/mon_pays/models/province.dart
//
// ✅ Parsing tolérant : compatible Dart natif (APK) ET web.
//    - area / population / territories_count acceptent int, double ou texte
//      (121308, 121308.0, "121308.00")
//    - une valeur inattendue ne fait plus échouer toute la liste
//    - les listes (ministers, achievements, tribes, galleryMedia) ne sont plus nulles

import 'dart:convert';

import 'province_government.dart';
import 'province_economic.dart';
import 'province_tourism.dart';
import 'province_emergency.dart';
import 'province_administrative.dart';
import 'province_budget.dart';
import 'city.dart';

class Province {
  final String id;
  final String name;
  final String code;
  final String capital;
  final String region;
  final int? area;
  final int? population;
  final String? description;

  // Champs institutionnels, historiques et environnementaux enrichis
  final String? history;
  final String? climate;
  final String? infrastructure;
  final String? education;

  final String? coverImageUrl;
  final String? coatOfArmsUrl;
  final String? mapUrl;
  final String? website;

  // Gouvernance de base & photos
  final String? governor;
  final String? governorPhotoUrl;
  final String? viceGovernor;
  final String? viceGovernorPhotoUrl;
  final List<Map<String, dynamic>> ministers; // Liste des ministres provinciaux

  final String? languages;
  final String? resources;
  final int? territoriesCount;

  // Réalisations, Tribus et Galerie média
  final List<Map<String, dynamic>> achievements;
  final List<Map<String, dynamic>> tribes; // Tribus et peuples autochtones
  final List<Map<String, dynamic>> galleryMedia;

  final ProvinceGovernment? government; // relation 1-1
  final List<City> cities; // villes
  final List<ProvinceEconomicResource> economicResources; // ressources économiques
  final List<ProvinceBudgetPriority> budgetPriorities; // priorités budgétaires
  final List<ProvinceTourism> tourismSites; // tourisme & culture
  final List<ProvinceEmergencyContact> emergencyContacts; // numéros d'urgence
  final List<ProvinceAdministrativeDivision> administrativeDivisions; // découpage
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Province({
    required this.id,
    required this.name,
    required this.code,
    required this.capital,
    required this.region,
    this.area,
    this.population,
    this.description,
    this.history,
    this.climate,
    this.infrastructure,
    this.education,
    this.coverImageUrl,
    this.coatOfArmsUrl,
    this.mapUrl,
    this.website,
    this.governor,
    this.governorPhotoUrl,
    this.viceGovernor,
    this.viceGovernorPhotoUrl,
    List<Map<String, dynamic>>? ministers,
    this.languages,
    this.resources,
    this.territoriesCount,
    List<Map<String, dynamic>>? achievements,
    List<Map<String, dynamic>>? tribes,
    List<Map<String, dynamic>>? galleryMedia,
    this.government,
    this.cities = const [],
    this.economicResources = const [],
    this.budgetPriorities = const [],
    this.tourismSites = const [],
    this.emergencyContacts = const [],
    this.administrativeDivisions = const [],
    this.createdAt,
    this.updatedAt,
  })  : ministers = ministers ?? const [],
        achievements = achievements ?? const [],
        tribes = tribes ?? const [],
        galleryMedia = galleryMedia ?? const [];

  // ============================================================
  // HELPERS DE PARSING (tolérants)
  // ============================================================

  /// Accepte int, double (121308.0), String ("121308", "121308.00").
  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.round();
    final s = v.toString().trim().replaceAll(' ', '').replaceAll(',', '.');
    if (s.isEmpty) return null;
    return int.tryParse(s) ?? double.tryParse(s)?.round();
  }

  static String _asString(dynamic v, {String fallback = ''}) =>
      v == null ? fallback : v.toString();

  static String? _asStringOrNull(dynamic v) => v?.toString();

  static DateTime? _asDate(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());

  /// Liste de Map, même si la valeur arrive sous forme de texte JSON.
  static List<Map<String, dynamic>> _asMapList(dynamic v) {
    dynamic value = v;
    if (value is String) {
      try {
        value = jsonDecode(value);
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
    }
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Parse une liste de modèles : une ligne invalide est ignorée.
  static List<T> _asModelList<T>(
    dynamic v,
    T Function(Map<String, dynamic> json) parse,
  ) {
    if (v is! List) return <T>[];
    final out = <T>[];
    for (final item in v) {
      if (item is! Map) continue;
      try {
        out.add(parse(Map<String, dynamic>.from(item)));
      } catch (_) {
        // ligne ignorée
      }
    }
    return out;
  }

  factory Province.fromJson(Map<String, dynamic> json) {
    ProvinceGovernment? government;
    final govRaw = json['government'];
    if (govRaw is Map) {
      try {
        government = ProvinceGovernment.fromJson(Map<String, dynamic>.from(govRaw));
      } catch (_) {
        government = null;
      }
    }

    return Province(
      id: _asString(json['id']),
      name: _asString(json['name']),
      code: _asString(json['code'], fallback: '--'),
      capital: _asString(json['capital']),
      region: _asString(json['region']),
      area: _asInt(json['area']),
      population: _asInt(json['population']),
      description: _asStringOrNull(json['description']),

      history: _asStringOrNull(json['history']),
      climate: _asStringOrNull(json['climate']),
      infrastructure: _asStringOrNull(json['infrastructure']),
      education: _asStringOrNull(json['education']),

      coverImageUrl: _asStringOrNull(json['cover_image_url'] ?? json['coverImageUrl']),
      coatOfArmsUrl: _asStringOrNull(json['coat_of_arms_url'] ?? json['coatOfArmsUrl']),
      mapUrl: _asStringOrNull(json['map_url'] ?? json['mapUrl']),
      website: _asStringOrNull(json['website']),

      // Prise en charge du camelCase (Formulaire App) et du snake_case (Supabase)
      governor: _asStringOrNull(json['governor']),
      governorPhotoUrl:
          _asStringOrNull(json['governorPhotoUrl'] ?? json['governor_photo_url']),
      viceGovernor: _asStringOrNull(json['viceGovernor'] ?? json['vice_governor']),
      viceGovernorPhotoUrl: _asStringOrNull(
          json['viceGovernorPhotoUrl'] ?? json['vice_governor_photo_url']),
      ministers: _asMapList(json['ministers']),

      languages: _asStringOrNull(json['languages']),
      resources: _asStringOrNull(json['resources']),
      territoriesCount: _asInt(json['territoriesCount'] ?? json['territories_count']),

      achievements: _asMapList(json['achievements']),
      tribes: _asMapList(json['tribes']),
      galleryMedia: _asMapList(json['gallery_media'] ?? json['galleryMedia']),

      government: government,
      cities: _asModelList<City>(json['cities'], (j) => City.fromJson(j)),
      economicResources: _asModelList<ProvinceEconomicResource>(
          json['economic_resources'], (j) => ProvinceEconomicResource.fromJson(j)),
      budgetPriorities: _asModelList<ProvinceBudgetPriority>(
          json['budget_priorities'], (j) => ProvinceBudgetPriority.fromJson(j)),
      tourismSites: _asModelList<ProvinceTourism>(
          json['tourism_sites'], (j) => ProvinceTourism.fromJson(j)),
      emergencyContacts: _asModelList<ProvinceEmergencyContact>(
          json['emergency_contacts'], (j) => ProvinceEmergencyContact.fromJson(j)),
      administrativeDivisions: _asModelList<ProvinceAdministrativeDivision>(
          json['administrative_divisions'],
          (j) => ProvinceAdministrativeDivision.fromJson(j)),
      createdAt: _asDate(json['created_at']),
      updatedAt: _asDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'capital': capital,
        'region': region,
        'area': area,
        'population': population,
        'description': description,

        'history': history,
        'climate': climate,
        'infrastructure': infrastructure,
        'education': education,

        'cover_image_url': coverImageUrl,
        'coat_of_arms_url': coatOfArmsUrl,
        'map_url': mapUrl,
        'website': website,

        // Enregistrement en snake_case pour la BDD Supabase
        'governor': governor,
        'governor_photo_url': governorPhotoUrl,
        'vice_governor': viceGovernor,
        'vice_governor_photo_url': viceGovernorPhotoUrl,
        'ministers': ministers,

        'languages': languages,
        'resources': resources,
        'territories_count': territoriesCount,

        'achievements': achievements,
        'tribes': tribes,
        'gallery_media': galleryMedia,

        'government': government?.toJson(),
        'cities': cities.map((e) => e.toJson()).toList(),
        'economic_resources': economicResources.map((e) => e.toJson()).toList(),
        'budget_priorities': budgetPriorities.map((e) => e.toJson()).toList(),
        'tourism_sites': tourismSites.map((e) => e.toJson()).toList(),
        'emergency_contacts': emergencyContacts.map((e) => e.toJson()).toList(),
        'administrative_divisions':
            administrativeDivisions.map((e) => e.toJson()).toList(),
      };

  Province copyWith({
    String? governor,
    String? governorPhotoUrl,
    String? viceGovernor,
    String? viceGovernorPhotoUrl,
    List<Map<String, dynamic>>? ministers,
    String? languages,
    String? resources,
    int? territoriesCount,
    String? history,
    String? climate,
    String? infrastructure,
    String? education,
    List<Map<String, dynamic>>? achievements,
    List<Map<String, dynamic>>? tribes,
    List<Map<String, dynamic>>? galleryMedia,
    ProvinceGovernment? government,
    List<City>? cities,
    List<ProvinceEconomicResource>? economicResources,
    List<ProvinceBudgetPriority>? budgetPriorities,
    List<ProvinceTourism>? tourismSites,
    List<ProvinceEmergencyContact>? emergencyContacts,
    List<ProvinceAdministrativeDivision>? administrativeDivisions,
  }) {
    return Province(
      id: id,
      name: name,
      code: code,
      capital: capital,
      region: region,
      area: area,
      population: population,
      description: description,

      history: history ?? this.history,
      climate: climate ?? this.climate,
      infrastructure: infrastructure ?? this.infrastructure,
      education: education ?? this.education,

      coverImageUrl: coverImageUrl,
      coatOfArmsUrl: coatOfArmsUrl,
      mapUrl: mapUrl,
      website: website,

      governor: governor ?? this.governor,
      governorPhotoUrl: governorPhotoUrl ?? this.governorPhotoUrl,
      viceGovernor: viceGovernor ?? this.viceGovernor,
      viceGovernorPhotoUrl: viceGovernorPhotoUrl ?? this.viceGovernorPhotoUrl,
      ministers: ministers ?? this.ministers,

      languages: languages ?? this.languages,
      resources: resources ?? this.resources,
      territoriesCount: territoriesCount ?? this.territoriesCount,

      achievements: achievements ?? this.achievements,
      tribes: tribes ?? this.tribes,
      galleryMedia: galleryMedia ?? this.galleryMedia,

      government: government ?? this.government,
      cities: cities ?? this.cities,
      economicResources: economicResources ?? this.economicResources,
      budgetPriorities: budgetPriorities ?? this.budgetPriorities,
      tourismSites: tourismSites ?? this.tourismSites,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      administrativeDivisions: administrativeDivisions ?? this.administrativeDivisions,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
