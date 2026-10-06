// lib/presentation/mon_pays/models/province.dart
//
// ✅ Province Model — Production v2.0
// ─────────────────────────────────────────────────────────────────────────────
// Compatible avec la page ProvinceDetailPage (production, glassmorphism,
// horizontal scroll, multilingue, accessibilité).
//
// Parsing tolérant :
//   - area / population / territories_count acceptent int, double ou texte
//   - les listes (ministers, achievements, tribes, galleryMedia) ne sont jamais nulles
//   - supporte snake_case (Supabase) ET camelCase (App)
//
// Données complémentaires (news, projects, services, budget, media, quiz,
// famous people, gastronomy, proverbs, businesses, products, demographics)
// sont chargées via des providers Riverpod séparés (tables relationnelles
// avec foreign key `province_id`).
// ============================================================================

import 'dart:convert';

import 'province_government.dart';
import 'province_economic.dart';
import 'province_tourism.dart';
import 'province_emergency.dart';
import 'province_administrative.dart';
import 'province_budget.dart';
import 'city.dart';

class Province {
  // ─── IDENTITÉ ───
  final String id;
  final String name;
  final String code;
  final String capital;
  final String region;
  final int? area; // km²
  final int? population;
  final String? description;

  // ─── DEVISE & FONDATION (nouveaux champs) ───
  final String? motto; // devise officielle ("Unité, Travail, Progrès")
  final int? foundedYear; // année de création de la province

  // ─── INSTITUTIONNEL & HISTORIQUE ───
  final String? history;
  final String? climate;
  final String? infrastructure;
  final String? education;

  // ─── MÉDIAS VISUELS ───
  final String? coverImageUrl;
  final String? coatOfArmsUrl;
  final String? mapUrl;
  final String? flagUrl; // 🆕 drapeau provincial
  final String? website;

  // ─── HYMNE (accès rapide sans provider séparé) ───
  final String? hymnTitle; // 🆕 titre de l'hymne
  final String? hymnAudioUrl; // 🆕 URL audio officiel
  final String? hymnInstrumentalUrl; // 🆕 URL version instrumentale
  final String? hymnLyrics; // 🆕 paroles complètes

  // ─── GOUVERNANCE ───
  final String? governor;
  final String? governorPhotoUrl;
  final String? viceGovernor;
  final String? viceGovernorPhotoUrl;
  final List<Map<String, dynamic>> ministers;

  // ─── CULTURE & RESSOURCES ───
  final String? languages;
  final String? resources;
  final int? territoriesCount;

  // ─── LISTES JSONB ───
  final List<Map<String, dynamic>> achievements;
  final List<Map<String, dynamic>> tribes;
  final List<Map<String, dynamic>> galleryMedia;

  // ─── RELATIONS ───
  final ProvinceGovernment? government;
  final List<City> cities;
  final List<ProvinceEconomicResource> economicResources;
  final List<ProvinceBudgetPriority> budgetPriorities;
  final List<ProvinceTourism> tourismSites;
  final List<ProvinceEmergencyContact> emergencyContacts;
  final List<ProvinceAdministrativeDivision> administrativeDivisions;

  // ─── MÉTADONNÉES ───
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
    this.motto,
    this.foundedYear,
    this.history,
    this.climate,
    this.infrastructure,
    this.education,
    this.coverImageUrl,
    this.coatOfArmsUrl,
    this.mapUrl,
    this.flagUrl,
    this.website,
    this.hymnTitle,
    this.hymnAudioUrl,
    this.hymnInstrumentalUrl,
    this.hymnLyrics,
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

  // ════════════════════════════════════════════════════════════════════════
  // GETTERS UTILES (stats rapides pour l'UI)
  // ════════════════════════════════════════════════════════════════════════

  /// Densité de population (hab/km²) — null si données manquantes.
  double? get density {
    if (population == null || area == null || area == 0) return null;
    return population! / area!;
  }

  /// Retourne une densité formatée ("125.4 hab/km²") ou 'N/A'.
  String get densityFormatted {
    final d = density;
    if (d == null) return 'N/A';
    return '${d.toStringAsFixed(1)} hab/km²';
  }

  /// Vrai si la province a une identité visuelle complète.
  bool get hasVisualIdentity =>
      (coverImageUrl != null && coverImageUrl!.isNotEmpty) ||
      (coatOfArmsUrl != null && coatOfArmsUrl!.isNotEmpty) ||
      (flagUrl != null && flagUrl!.isNotEmpty);

  /// Vrai si la province a un hymne configuré.
  bool get hasHymn =>
      (hymnAudioUrl != null && hymnAudioUrl!.isNotEmpty) ||
      (hymnTitle != null && hymnTitle!.isNotEmpty);

  /// Vrai si la gouvernance est renseignée.
  bool get hasGovernance =>
      (governor != null && governor!.isNotEmpty) ||
      ministers.isNotEmpty;

  /// Nombre total d'entités culturelles (tribus + réalisations).
  int get cultureItemsCount => tribes.length + achievements.length;

  /// Âge approximatif de la province en années (si foundedYear existe).
  int? get ageInYears {
    if (foundedYear == null) return null;
    return DateTime.now().year - foundedYear!;
  }

  // ════════════════════════════════════════════════════════════════════════
  // HELPERS DE PARSING (tolérants)
  // ════════════════════════════════════════════════════════════════════════

  /// Accepte int, double (121308.0), String ("121308", "121308.00", "121 308").
  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.round();
    final s = v
        .toString()
        .trim()
        .replaceAll(' ', '')
        .replaceAll('\u00A0', '') // espaces insécables
        .replaceAll(',', '.');
    if (s.isEmpty) return null;
    return int.tryParse(s) ?? double.tryParse(s)?.round();
  }

  static String _asString(dynamic v, {String fallback = ''}) =>
      v == null ? fallback : v.toString();

  static String? _asStringOrNull(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

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

  /// Parse une liste de modèles : une ligne invalide est silencieusement ignorée.
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
        // ligne ignorée silencieusement pour robustesse
      }
    }
    return out;
  }

  // ════════════════════════════════════════════════════════════════════════
  // FROM JSON (compatible Supabase + App)
  // ════════════════════════════════════════════════════════════════════════

  factory Province.fromJson(Map<String, dynamic> json) {
    ProvinceGovernment? government;
    final govRaw = json['government'];
    if (govRaw is Map) {
      try {
        government =
            ProvinceGovernment.fromJson(Map<String, dynamic>.from(govRaw));
      } catch (_) {
        government = null;
      }
    }

    return Province(
      // ─── Identité ───
      id: _asString(json['id']),
      name: _asString(json['name']),
      code: _asString(json['code'], fallback: '--'),
      capital: _asString(json['capital']),
      region: _asString(json['region']),
      area: _asInt(json['area']),
      population: _asInt(json['population']),
      description: _asStringOrNull(json['description']),

      // ─── Nouveaux champs ───
      motto: _asStringOrNull(json['motto']),
      foundedYear: _asInt(json['founded_year'] ?? json['foundedYear']),
      flagUrl: _asStringOrNull(json['flag_url'] ?? json['flagUrl']),
      hymnTitle: _asStringOrNull(json['hymn_title'] ?? json['hymnTitle']),
      hymnAudioUrl:
          _asStringOrNull(json['hymn_audio_url'] ?? json['hymnAudioUrl']),
      hymnInstrumentalUrl: _asStringOrNull(
          json['hymn_instrumental_url'] ?? json['hymnInstrumentalUrl']),
      hymnLyrics: _asStringOrNull(json['hymn_lyrics'] ?? json['hymnLyrics']),

      // ─── Institutionnel ───
      history: _asStringOrNull(json['history']),
      climate: _asStringOrNull(json['climate']),
      infrastructure: _asStringOrNull(json['infrastructure']),
      education: _asStringOrNull(json['education']),

      // ─── Médias ───
      coverImageUrl:
          _asStringOrNull(json['cover_image_url'] ?? json['coverImageUrl']),
      coatOfArmsUrl:
          _asStringOrNull(json['coat_of_arms_url'] ?? json['coatOfArmsUrl']),
      mapUrl: _asStringOrNull(json['map_url'] ?? json['mapUrl']),
      website: _asStringOrNull(json['website']),

      // ─── Gouvernance ───
      governor: _asStringOrNull(json['governor']),
      governorPhotoUrl:
          _asStringOrNull(json['governorPhotoUrl'] ?? json['governor_photo_url']),
      viceGovernor:
          _asStringOrNull(json['viceGovernor'] ?? json['vice_governor']),
      viceGovernorPhotoUrl: _asStringOrNull(
          json['viceGovernorPhotoUrl'] ?? json['vice_governor_photo_url']),
      ministers: _asMapList(json['ministers']),

      // ─── Culture ───
      languages: _asStringOrNull(json['languages']),
      resources: _asStringOrNull(json['resources']),
      territoriesCount:
          _asInt(json['territoriesCount'] ?? json['territories_count']),

      // ─── Listes JSONB ───
      achievements: _asMapList(json['achievements']),
      tribes: _asMapList(json['tribes']),
      galleryMedia: _asMapList(json['gallery_media'] ?? json['galleryMedia']),

      // ─── Relations ───
      government: government,
      cities: _asModelList<City>(json['cities'], (j) => City.fromJson(j)),
      economicResources: _asModelList<ProvinceEconomicResource>(
          json['economic_resources'],
          (j) => ProvinceEconomicResource.fromJson(j)),
      budgetPriorities: _asModelList<ProvinceBudgetPriority>(
          json['budget_priorities'],
          (j) => ProvinceBudgetPriority.fromJson(j)),
      tourismSites: _asModelList<ProvinceTourism>(
          json['tourism_sites'], (j) => ProvinceTourism.fromJson(j)),
      emergencyContacts: _asModelList<ProvinceEmergencyContact>(
          json['emergency_contacts'],
          (j) => ProvinceEmergencyContact.fromJson(j)),
      administrativeDivisions: _asModelList<ProvinceAdministrativeDivision>(
          json['administrative_divisions'],
          (j) => ProvinceAdministrativeDivision.fromJson(j)),

      // ─── Métadonnées ───
      createdAt: _asDate(json['created_at']),
      updatedAt: _asDate(json['updated_at']),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // TO JSON (snake_case pour Supabase)
  // ════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> toJson() => {
        // Identité
        'id': id,
        'name': name,
        'code': code,
        'capital': capital,
        'region': region,
        'area': area,
        'population': population,
        'description': description,

        // Nouveaux champs
        'motto': motto,
        'founded_year': foundedYear,
        'flag_url': flagUrl,
        'hymn_title': hymnTitle,
        'hymn_audio_url': hymnAudioUrl,
        'hymn_instrumental_url': hymnInstrumentalUrl,
        'hymn_lyrics': hymnLyrics,

        // Institutionnel
        'history': history,
        'climate': climate,
        'infrastructure': infrastructure,
        'education': education,

        // Médias
        'cover_image_url': coverImageUrl,
        'coat_of_arms_url': coatOfArmsUrl,
        'map_url': mapUrl,
        'website': website,

        // Gouvernance
        'governor': governor,
        'governor_photo_url': governorPhotoUrl,
        'vice_governor': viceGovernor,
        'vice_governor_photo_url': viceGovernorPhotoUrl,
        'ministers': ministers,

        // Culture
        'languages': languages,
        'resources': resources,
        'territories_count': territoriesCount,

        // Listes JSONB
        'achievements': achievements,
        'tribes': tribes,
        'gallery_media': galleryMedia,

        // Relations
        'government': government?.toJson(),
        'cities': cities.map((e) => e.toJson()).toList(),
        'economic_resources':
            economicResources.map((e) => e.toJson()).toList(),
        'budget_priorities':
            budgetPriorities.map((e) => e.toJson()).toList(),
        'tourism_sites': tourismSites.map((e) => e.toJson()).toList(),
        'emergency_contacts':
            emergencyContacts.map((e) => e.toJson()).toList(),
        'administrative_divisions':
            administrativeDivisions.map((e) => e.toJson()).toList(),

        // Métadonnées
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  // ════════════════════════════════════════════════════════════════════════
  // COPY WITH (immutable update)
  // ════════════════════════════════════════════════════════════════════════

  Province copyWith({
    String? id,
    String? name,
    String? code,
    String? capital,
    String? region,
    int? area,
    int? population,
    String? description,
    String? motto,
    int? foundedYear,
    String? history,
    String? climate,
    String? infrastructure,
    String? education,
    String? coverImageUrl,
    String? coatOfArmsUrl,
    String? mapUrl,
    String? flagUrl,
    String? website,
    String? hymnTitle,
    String? hymnAudioUrl,
    String? hymnInstrumentalUrl,
    String? hymnLyrics,
    String? governor,
    String? governorPhotoUrl,
    String? viceGovernor,
    String? viceGovernorPhotoUrl,
    List<Map<String, dynamic>>? ministers,
    String? languages,
    String? resources,
    int? territoriesCount,
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
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Province(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      capital: capital ?? this.capital,
      region: region ?? this.region,
      area: area ?? this.area,
      population: population ?? this.population,
      description: description ?? this.description,

      motto: motto ?? this.motto,
      foundedYear: foundedYear ?? this.foundedYear,

      history: history ?? this.history,
      climate: climate ?? this.climate,
      infrastructure: infrastructure ?? this.infrastructure,
      education: education ?? this.education,

      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      coatOfArmsUrl: coatOfArmsUrl ?? this.coatOfArmsUrl,
      mapUrl: mapUrl ?? this.mapUrl,
      flagUrl: flagUrl ?? this.flagUrl,
      website: website ?? this.website,

      hymnTitle: hymnTitle ?? this.hymnTitle,
      hymnAudioUrl: hymnAudioUrl ?? this.hymnAudioUrl,
      hymnInstrumentalUrl: hymnInstrumentalUrl ?? this.hymnInstrumentalUrl,
      hymnLyrics: hymnLyrics ?? this.hymnLyrics,

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
      administrativeDivisions:
          administrativeDivisions ?? this.administrativeDivisions,

      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'Province($name, code=$code, pop=$population)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Province &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
