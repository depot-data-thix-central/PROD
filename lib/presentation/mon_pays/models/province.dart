// lib/presentation/mon_pays/models/province.dart

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
  final List<Map<String, dynamic>>? ministers; // Liste des ministres provinciaux
  
  final String? languages;
  final String? resources;
  final int? territoriesCount;

  // Réalisations, Tribus et Galerie média
  final List<Map<String, dynamic>>? achievements;
  final List<Map<String, dynamic>>? tribes; // Tribus et peuples autochtones
  final List<Map<String, dynamic>>? galleryMedia;

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
    this.ministers,
    this.languages,
    this.resources,
    this.territoriesCount,
    this.achievements,
    this.tribes,
    this.galleryMedia,
    this.government,
    this.cities = const [],
    this.economicResources = const [],
    this.budgetPriorities = const [],
    this.tourismSites = const [],
    this.emergencyContacts = const [],
    this.administrativeDivisions = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory Province.fromJson(Map<String, dynamic> json) {
    return Province(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      capital: json['capital'] as String,
      region: json['region'] as String,
      area: json['area'] as int?,
      population: json['population'] as int?,
      description: json['description'] as String?,
      
      history: json['history'] as String?,
      climate: json['climate'] as String?,
      infrastructure: json['infrastructure'] as String?,
      education: json['education'] as String?,

      coverImageUrl: json['cover_image_url'] as String? ?? json['coverImageUrl'] as String?,
      coatOfArmsUrl: json['coat_of_arms_url'] as String? ?? json['coatOfArmsUrl'] as String?,
      mapUrl: json['map_url'] as String? ?? json['mapUrl'] as String?,
      website: json['website'] as String?,
      
      // Prise en charge du camelCase (Formulaire App) et du snake_case (Supabase)
      governor: json['governor'] as String?,
      governorPhotoUrl: json['governorPhotoUrl'] as String? ?? json['governor_photo_url'] as String?,
      viceGovernor: json['viceGovernor'] as String? ?? json['vice_governor'] as String?,
      viceGovernorPhotoUrl: json['viceGovernorPhotoUrl'] as String? ?? json['vice_governor_photo_url'] as String?,
      ministers: json['ministers'] != null ? List<Map<String, dynamic>>.from(json['ministers']) : null,

      languages: json['languages'] as String?,
      resources: json['resources'] as String?,
      territoriesCount: json['territoriesCount'] as int? ?? json['territories_count'] as int?,

      achievements: (json['achievements'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e))
          .toList(),
      tribes: (json['tribes'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e))
          .toList(),
      galleryMedia: (json['gallery_media'] ?? json['galleryMedia'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e))
          .toList(),

      government: json['government'] != null
          ? ProvinceGovernment.fromJson(json['government'])
          : null,
      cities: (json['cities'] as List?)?.map((e) => City.fromJson(e)).toList() ?? [],
      economicResources: (json['economic_resources'] as List?)?.map((e) => ProvinceEconomicResource.fromJson(e)).toList() ?? [],
      budgetPriorities: (json['budget_priorities'] as List?)?.map((e) => ProvinceBudgetPriority.fromJson(e)).toList() ?? [],
      tourismSites: (json['tourism_sites'] as List?)?.map((e) => ProvinceTourism.fromJson(e)).toList() ?? [],
      emergencyContacts: (json['emergency_contacts'] as List?)?.map((e) => ProvinceEmergencyContact.fromJson(e)).toList() ?? [],
      administrativeDivisions: (json['administrative_divisions'] as List?)?.map((e) => ProvinceAdministrativeDivision.fromJson(e)).toList() ?? [],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
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
    'administrative_divisions': administrativeDivisions.map((e) => e.toJson()).toList(),
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
