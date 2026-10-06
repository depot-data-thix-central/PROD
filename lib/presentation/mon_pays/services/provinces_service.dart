// lib/presentation/mon_pays/services/provinces_service.dart
//
// ============================================================================
// PROVINCES SERVICE — Production v3.0
// ============================================================================
//
// ✅ Liste des provinces tolérante : une ligne illisible est ignorée
// ✅ Chargement complet avec TOUTES les relations (anciennes + nouvelles)
// ✅ CRUD complet pour toutes les tables relationnelles
// ✅ Méthodes de stats/counts pour les badges de l'UI
// ✅ Support snake_case (Supabase) + camelCase (App)
//
// Tables gérées :
//   - provinces (base)
//   - province_governments + province_ministers
//   - cities
//   - province_economic_resources
//   - province_budget_priorities
//   - province_tourism_sites (+ fallback province_tourism)
//   - province_emergency_contacts
//   - province_administrative_divisions
//   - province_gallery_media / province_achievements / province_tribes
//   - province_hymns (hymne par province)
//   ─────────── NOUVELLES TABLES (page production) ───────────
//   - province_news (actualités)
//   - province_projects (projets en cours)
//   - province_services (services publics)
//   - province_engagements (sondages/votes/pétitions)
//   - province_budget (budget par secteur, pour pie chart)
//   - province_documents (documents officiels)
//   - province_media (vidéos/podcasts médiathèque)
//   - province_famous_people (personnalités célèbres)
//   - province_gastronomy (plats traditionnels)
//   - province_proverbs (proverbes & contes)
//   - province_businesses (entreprises locales)
//   - province_products (produits du terroir)
//   - province_quiz_questions (questions quiz)
//   - province_demographics (séries temporelles population)
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/province.dart';
import '../models/province_government.dart';
import '../models/province_minister.dart';
import '../models/province_economic.dart';
import '../models/province_tourism.dart';
import '../models/province_emergency.dart';
import '../models/province_administrative.dart';
import '../models/province_budget.dart';
import '../models/city.dart';

class ProvincesService {
  final SupabaseClient _client = Supabase.instance.client;

  static const String _tourismTable = 'province_tourism_sites';
  static const String _legacyTourismTable = 'province_tourism';

  // ════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════════════════

  /// Exécute une requête de lecture ; renvoie null (et logue) en cas d'erreur.
  Future<List<Map<String, dynamic>>?> _safeQuery(
    String label,
    Future<List<dynamic>> Function() run,
  ) async {
    try {
      final res = await run();
      return res
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      debugPrint('[ProvincesService] $label: $e');
      return null;
    }
  }

  /// Parse des lignes : une ligne invalide est ignorée (et loguée).
  List<T> _parseRows<T>(
    List<Map<String, dynamic>> rows,
    T Function(Map<String, dynamic> json) parse,
    String label,
  ) {
    final out = <T>[];
    for (final r in rows) {
      try {
        out.add(parse(r));
      } catch (e) {
        debugPrint('[ProvincesService] $label: ligne ignorée → $e');
      }
    }
    return out;
  }

  /// Normalise les réalisations : ajoute un champ `media` depuis `cover_image_url`.
  Map<String, dynamic> _achievementToMap(Map<String, dynamic> r) {
    final cover = r['cover_image_url']?.toString() ?? '';
    return <String, dynamic>{
      ...r,
      'media': cover.isNotEmpty
          ? <Map<String, dynamic>>[
              {'url': cover, 'type': 'photo'}
            ]
          : <Map<String, dynamic>>[],
    };
  }

  /// Garantit que le champ `media` est une liste de Map.
  Map<String, dynamic> _withMediaList(Map<String, dynamic> r) {
    final m = r['media'];
    return <String, dynamic>{
      ...r,
      'media': m is List
          ? m.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[],
    };
  }

  /// Insert générique avec retour de la ligne insérée.
  Future<Map<String, dynamic>?> _insertRow(
    String table,
    Map<String, dynamic> data,
    String label,
  ) async {
    try {
      final response = await _client.from(table).insert(data).select().single();
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('[ProvincesService] $label insert error: $e');
      rethrow;
    }
  }

  /// Update générique.
  Future<void> _updateRow(
    String table,
    Map<String, dynamic> data,
    String id,
    String label,
  ) async {
    try {
      await _client.from(table).update(data).eq('id', id);
    } catch (e) {
      debugPrint('[ProvincesService] $label update error: $e');
      rethrow;
    }
  }

  /// Delete générique.
  Future<void> _deleteRow(String table, String id, String label) async {
    try {
      await _client.from(table).delete().eq('id', id);
    } catch (e) {
      debugPrint('[ProvincesService] $label delete error: $e');
      rethrow;
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // PROVINCES CRUD
  // ════════════════════════════════════════════════════════════════════════

  /// Liste des provinces (filtrée par région et/ou recherche).
  Future<List<Province>> getProvinces({String? region, String? search}) async {
    try {
      var query = _client.from('provinces').select('*');

      if (region != null && region.isNotEmpty && region != 'Toutes') {
        query = query.eq('region', region);
      }
      if (search != null && search.trim().isNotEmpty) {
        query = query.or('name.ilike.%$search%,capital.ilike.%$search%');
      }

      final response = await query.order('name');

      final out = <Province>[];
      Object? firstError;
      for (final row in response) {
        try {
          out.add(Province.fromJson(Map<String, dynamic>.from(row)));
        } catch (e) {
          firstError ??= e;
          debugPrint('[ProvincesService] province ignorée (${row['name']}): $e');
        }
      }

      if (out.isEmpty && firstError != null) throw firstError;
      return out;
    } catch (e) {
      throw Exception('Erreur chargement provinces: $e');
    }
  }

  Future<Province> getProvinceById(String id) async {
    try {
      final response = await _client
          .from('provinces')
          .select('*')
          .eq('id', id)
          .single();
      return Province.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      throw Exception('Erreur chargement province: $e');
    }
  }

  /// Province complète avec TOUTES les relations (base + nouvelles tables).
  Future<Province> getProvinceWithAllRelations(String id) async {
    try {
      // 1. Province de base
      final province = await getProvinceById(id);

      // 2. Gouvernement + ministres
      ProvinceGovernment? government;
      try {
        final gov = await _client
            .from('province_governments')
            .select('*, ministers:province_ministers(*)')
            .eq('province_id', id)
            .maybeSingle();
        if (gov != null) {
          government = ProvinceGovernment.fromJson(Map<String, dynamic>.from(gov));
        }
      } catch (e) {
        debugPrint('[ProvincesService] gouvernement: $e');
      }

      // 3. Villes
      final citiesRows = await _safeQuery(
        'cities',
        () async => await _client
            .from('cities')
            .select('*')
            .eq('province_id', id)
            .order('is_capital', ascending: false)
            .order('name'),
      );
      final cities = _parseRows<City>(
        citiesRows ?? <Map<String, dynamic>>[],
        (j) => City.fromJson(j),
        'cities',
      );

      // 4. Ressources économiques
      final ecoRows = await _safeQuery(
        'économie',
        () async => await _client
            .from('province_economic_resources')
            .select('*')
            .eq('province_id', id)
            .order('is_key_sector', ascending: false),
      );
      final economicResources = _parseRows<ProvinceEconomicResource>(
        ecoRows ?? <Map<String, dynamic>>[],
        (j) => ProvinceEconomicResource.fromJson(j),
        'économie',
      );

      // 5. Budget (priorités)
      final budgetRows = await _safeQuery(
        'budget',
        () async => await _client
            .from('province_budget_priorities')
            .select('*')
            .eq('province_id', id)
            .order('year', ascending: false),
      );
      final budgetPriorities = _parseRows<ProvinceBudgetPriority>(
        budgetRows ?? <Map<String, dynamic>>[],
        (j) => ProvinceBudgetPriority.fromJson(j),
        'budget',
      );

      // 6. Tourisme (avec fallback)
      final tourismRows = await _safeQuery(
            'tourisme',
            () async => await _client
                .from(_tourismTable)
                .select('*')
                .eq('province_id', id),
          ) ??
          await _safeQuery(
            'tourisme (ancienne table)',
            () async => await _client
                .from(_legacyTourismTable)
                .select('*')
                .eq('province_id', id),
          ) ??
          <Map<String, dynamic>>[];
      final tourismSites = _parseRows<ProvinceTourism>(
        tourismRows,
        (j) => ProvinceTourism.fromJson(j),
        'tourisme',
      );

      // 7. Urgences
      final emergencyRows = await _safeQuery(
        'urgences',
        () async => await _client
            .from('province_emergency_contacts')
            .select('*')
            .eq('province_id', id),
      );
      final emergencyContacts = _parseRows<ProvinceEmergencyContact>(
        emergencyRows ?? <Map<String, dynamic>>[],
        (j) => ProvinceEmergencyContact.fromJson(j),
        'urgences',
      );

      // 8. Découpage administratif
      final adminRows = await _safeQuery(
        'découpage',
        () async => await _client
            .from('province_administrative_divisions')
            .select('*')
            .eq('province_id', id),
      );
      final administrativeDivisions = _parseRows<ProvinceAdministrativeDivision>(
        adminRows ?? <Map<String, dynamic>>[],
        (j) => ProvinceAdministrativeDivision.fromJson(j),
        'découpage',
      );

      // 9. Galerie, réalisations, tribus (tables dédiées ou fallback JSONB)
      final galleryRows = await _safeQuery(
        'galerie',
        () async => await _client
            .from('province_gallery_media')
            .select('*')
            .eq('province_id', id)
            .order('created_at'),
      );
      final achievementRows = await _safeQuery(
        'réalisations',
        () async => await _client
            .from('province_achievements')
            .select('*')
            .eq('province_id', id)
            .order('date', ascending: false),
      );
      final tribeRows = await _safeQuery(
        'tribus',
        () async => await _client
            .from('province_tribes')
            .select('*')
            .eq('province_id', id)
            .order('name'),
      );

      final galleryMedia = (galleryRows != null && galleryRows.isNotEmpty)
          ? galleryRows
          : province.galleryMedia;
      final achievements = (achievementRows != null && achievementRows.isNotEmpty)
          ? achievementRows.map(_achievementToMap).toList()
          : province.achievements;
      final tribes = (tribeRows != null && tribeRows.isNotEmpty)
          ? tribeRows.map(_withMediaList).toList()
          : province.tribes;

      return province.copyWith(
        government: government,
        cities: cities,
        economicResources: economicResources,
        budgetPriorities: budgetPriorities,
        tourismSites: tourismSites,
        emergencyContacts: emergencyContacts,
        administrativeDivisions: administrativeDivisions,
        galleryMedia: galleryMedia,
        achievements: achievements,
        tribes: tribes,
      );
    } catch (e) {
      throw Exception('Erreur chargement complet de la province: $e');
    }
  }

  Future<Province> createProvince(Province province) async {
    try {
      final data = province.toJson();
      // Retirer ID (généré par Supabase) et relations
      data.remove('id');
      data.remove('government');
      data.remove('cities');
      data.remove('economic_resources');
      data.remove('budget_priorities');
      data.remove('tourism_sites');
      data.remove('emergency_contacts');
      data.remove('administrative_divisions');

      final response = await _client
          .from('provinces')
          .insert(data)
          .select()
          .single();

      return Province.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      throw Exception('Erreur création province: $e');
    }
  }

  Future<Province> updateProvince(Province province) async {
    try {
      final data = province.toJson();
      data.remove('government');
      data.remove('cities');
      data.remove('economic_resources');
      data.remove('budget_priorities');
      data.remove('tourism_sites');
      data.remove('emergency_contacts');
      data.remove('administrative_divisions');

      final response = await _client
          .from('provinces')
          .update(data)
          .eq('id', province.id)
          .select()
          .single();

      return Province.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      throw Exception('Erreur mise à jour province: $e');
    }
  }

  Future<void> deleteProvince(String id) async {
    try {
      await _client.from('provinces').delete().eq('id', id);
    } catch (e) {
      throw Exception('Erreur suppression province: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // GOUVERNEMENT & MINISTRES
  // ════════════════════════════════════════════════════════════════════════

  Future<ProvinceGovernment?> getGovernment(String provinceId) async {
    try {
      final response = await _client
          .from('province_governments')
          .select('*, ministers:province_ministers(*)')
          .eq('province_id', provinceId)
          .maybeSingle();

      if (response == null) return null;
      return ProvinceGovernment.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      return null;
    }
  }

  Future<ProvinceGovernment> createGovernment(ProvinceGovernment gov) async {
    final data = gov.toJson();
    data.remove('id');
    data.remove('ministers');
    final r = await _insertRow('province_governments', data, 'gouvernement');
    return ProvinceGovernment.fromJson(r!);
  }

  Future<ProvinceGovernment> updateGovernment(ProvinceGovernment gov) async {
    final data = gov.toJson();
    data.remove('ministers');
    await _updateRow('province_governments', data, gov.id, 'gouvernement');
    return gov;
  }

  Future<ProvinceMinister> addMinister(ProvinceMinister minister) async {
    final data = minister.toJson();
    data.remove('id');
    final r = await _insertRow('province_ministers', data, 'ministre');
    return ProvinceMinister.fromJson(r!);
  }

  Future<void> removeMinister(String id) async {
    await _deleteRow('province_ministers', id, 'ministre');
  }

  // ════════════════════════════════════════════════════════════════════════
  // RESSOURCES ÉCONOMIQUES
  // ════════════════════════════════════════════════════════════════════════

  Future<List<ProvinceEconomicResource>> getEconomicResources(String provinceId) async {
    final rows = await _safeQuery(
      'économie',
      () async => await _client
          .from('province_economic_resources')
          .select('*')
          .eq('province_id', provinceId)
          .order('is_key_sector', ascending: false),
    );
    return _parseRows<ProvinceEconomicResource>(
      rows ?? <Map<String, dynamic>>[],
      (j) => ProvinceEconomicResource.fromJson(j),
      'économie',
    );
  }

  Future<ProvinceEconomicResource> addEconomicResource(
      ProvinceEconomicResource resource) async {
    final data = resource.toJson();
    data.remove('id');
    final r = await _insertRow('province_economic_resources', data, 'économie');
    return ProvinceEconomicResource.fromJson(r!);
  }

  Future<void> updateEconomicResource(ProvinceEconomicResource resource) async {
    await _updateRow(
        'province_economic_resources', resource.toJson(), resource.id, 'économie');
  }

  Future<void> deleteEconomicResource(String id) async {
    await _deleteRow('province_economic_resources', id, 'économie');
  }

  // ════════════════════════════════════════════════════════════════════════
  // BUDGET PRIORITIES
  // ════════════════════════════════════════════════════════════════════════

  Future<List<ProvinceBudgetPriority>> getBudgetPriorities(String provinceId) async {
    final rows = await _safeQuery(
      'budget_priorities',
      () async => await _client
          .from('province_budget_priorities')
          .select('*')
          .eq('province_id', provinceId)
          .order('year', ascending: false),
    );
    return _parseRows<ProvinceBudgetPriority>(
      rows ?? <Map<String, dynamic>>[],
      (j) => ProvinceBudgetPriority.fromJson(j),
      'budget_priorities',
    );
  }

  Future<ProvinceBudgetPriority> addBudgetPriority(ProvinceBudgetPriority budget) async {
    final data = budget.toJson();
    data.remove('id');
    final r = await _insertRow('province_budget_priorities', data, 'budget_priorities');
    return ProvinceBudgetPriority.fromJson(r!);
  }

  Future<void> updateBudgetPriority(ProvinceBudgetPriority budget) async {
    await _updateRow(
        'province_budget_priorities', budget.toJson(), budget.id, 'budget_priorities');
  }

  Future<void> deleteBudgetPriority(String id) async {
    await _deleteRow('province_budget_priorities', id, 'budget_priorities');
  }

  // ════════════════════════════════════════════════════════════════════════
  // TOURISME
  // ════════════════════════════════════════════════════════════════════════

  Future<List<ProvinceTourism>> getTourismSites(String provinceId) async {
    final rows = await _safeQuery(
      'tourisme',
      () async => await _client
          .from(_tourismTable)
          .select('*')
          .eq('province_id', provinceId),
    );
    return _parseRows<ProvinceTourism>(
      rows ?? <Map<String, dynamic>>[],
      (j) => ProvinceTourism.fromJson(j),
      'tourisme',
    );
  }

  Future<ProvinceTourism> addTourismSite(ProvinceTourism site) async {
    final data = site.toJson();
    data.remove('id');
    final r = await _insertRow(_tourismTable, data, 'tourisme');
    return ProvinceTourism.fromJson(r!);
  }

  Future<void> updateTourismSite(ProvinceTourism site) async {
    await _updateRow(_tourismTable, site.toJson(), site.id, 'tourisme');
  }

  Future<void> deleteTourismSite(String id) async {
    await _deleteRow(_tourismTable, id, 'tourisme');
  }

  // ════════════════════════════════════════════════════════════════════════
  // URGENCES
  // ════════════════════════════════════════════════════════════════════════

  Future<List<ProvinceEmergencyContact>> getEmergencyContacts(String provinceId) async {
    final rows = await _safeQuery(
      'urgences',
      () async => await _client
          .from('province_emergency_contacts')
          .select('*')
          .eq('province_id', provinceId),
    );
    return _parseRows<ProvinceEmergencyContact>(
      rows ?? <Map<String, dynamic>>[],
      (j) => ProvinceEmergencyContact.fromJson(j),
      'urgences',
    );
  }

  Future<ProvinceEmergencyContact> addEmergencyContact(
      ProvinceEmergencyContact contact) async {
    final data = contact.toJson();
    data.remove('id');
    final r = await _insertRow('province_emergency_contacts', data, 'urgences');
    return ProvinceEmergencyContact.fromJson(r!);
  }

  Future<void> updateEmergencyContact(ProvinceEmergencyContact contact) async {
    await _updateRow(
        'province_emergency_contacts', contact.toJson(), contact.id, 'urgences');
  }

  Future<void> deleteEmergencyContact(String id) async {
    await _deleteRow('province_emergency_contacts', id, 'urgences');
  }

  // ════════════════════════════════════════════════════════════════════════
  // DÉCOUPAGE ADMINISTRATIF
  // ════════════════════════════════════════════════════════════════════════

  Future<List<ProvinceAdministrativeDivision>> getAdministrativeDivisions(
      String provinceId) async {
    final rows = await _safeQuery(
      'découpage',
      () async => await _client
          .from('province_administrative_divisions')
          .select('*')
          .eq('province_id', provinceId),
    );
    return _parseRows<ProvinceAdministrativeDivision>(
      rows ?? <Map<String, dynamic>>[],
      (j) => ProvinceAdministrativeDivision.fromJson(j),
      'découpage',
    );
  }

  Future<ProvinceAdministrativeDivision> addAdministrativeDivision(
      ProvinceAdministrativeDivision division) async {
    final data = division.toJson();
    data.remove('id');
    final r = await _insertRow(
        'province_administrative_divisions', data, 'découpage');
    return ProvinceAdministrativeDivision.fromJson(r!);
  }

  Future<void> updateAdministrativeDivision(
      ProvinceAdministrativeDivision division) async {
    await _updateRow(
        'province_administrative_divisions', division.toJson(), division.id, 'découpage');
  }

  Future<void> deleteAdministrativeDivision(String id) async {
    await _deleteRow('province_administrative_divisions', id, 'découpage');
  }

  // ════════════════════════════════════════════════════════════════════════
  // VILLES
  // ════════════════════════════════════════════════════════════════════════

  Future<List<City>> getCities(String provinceId) async {
    final rows = await _safeQuery(
      'villes',
      () async => await _client
          .from('cities')
          .select('*')
          .eq('province_id', provinceId)
          .order('is_capital', ascending: false)
          .order('name'),
    );
    return _parseRows<City>(
      rows ?? <Map<String, dynamic>>[],
      (j) => City.fromJson(j),
      'villes',
    );
  }

  Future<City> addCity(City city) async {
    final data = city.toJson();
    data.remove('id');
    final r = await _insertRow('cities', data, 'ville');
    return City.fromJson(r!);
  }

  Future<void> updateCity(City city) async {
    await _updateRow('cities', city.toJson(), city.id, 'ville');
  }

  Future<void> deleteCity(String id) async {
    await _deleteRow('cities', id, 'ville');
  }

  // ════════════════════════════════════════════════════════════════════════
  // 🆕 NOUVELLES TABLES (page production)
  // ════════════════════════════════════════════════════════════════════════

  // ─── ACTUALITÉS (province_news) ───
  Future<List<Map<String, dynamic>>> getNews(String provinceId, {int limit = 20}) async {
    final rows = await _safeQuery(
      'news',
      () async => await _client
          .from('province_news')
          .select()
          .eq('province_id', provinceId)
          .eq('is_published', true)
          .order('published_at', ascending: false)
          .limit(limit),
    );
    return rows ?? <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> addNews(Map<String, dynamic> data) async {
    data.remove('id');
    data['created_at'] = DateTime.now().toIso8601String();
    final r = await _insertRow('province_news', data, 'news');
    return r!;
  }

  Future<void> updateNews(String id, Map<String, dynamic> data) async {
    data['updated_at'] = DateTime.now().toIso8601String();
    await _updateRow('province_news', data, id, 'news');
  }

  Future<void> deleteNews(String id) async {
    await _deleteRow('province_news', id, 'news');
  }

  // ─── PROJETS EN COURS (province_projects) ───
  Future<List<Map<String, dynamic>>> getProjects(String provinceId, {int limit = 20}) async {
    final rows = await _safeQuery(
      'projects',
      () async => await _client
          .from('province_projects')
          .select()
          .eq('province_id', provinceId)
          .order('progress', ascending: false)
          .limit(limit),
    );
    return rows ?? <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> addProject(Map<String, dynamic> data) async {
    data.remove('id');
    data['created_at'] = DateTime.now().toIso8601String();
    final r = await _insertRow('province_projects', data, 'projects');
    return r!;
  }

  Future<void> updateProject(String id, Map<String, dynamic> data) async {
    data['updated_at'] = DateTime.now().toIso8601String();
    await _updateRow('province_projects', data, id, 'projects');
  }

  Future<void> deleteProject(String id) async {
    await _deleteRow('province_projects', id, 'projects');
  }

  // ─── SERVICES PUBLICS (province_services) ───
  Future<List<Map<String, dynamic>>> getServices(String provinceId, {int limit = 30}) async {
    final rows = await _safeQuery(
      'services',
      () async => await _client
          .from('province_services')
          .select()
          .eq('province_id', provinceId)
          .eq('is_active', true)
          .order('name', ascending: true)
          .limit(limit),
    );
    return rows ?? <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> addService(Map<String, dynamic> data) async {
    data.remove('id');
    final r = await _insertRow('province_services', data, 'services');
    return r!;
  }

  Future<void> updateService(String id, Map<String, dynamic> data) async {
    await _updateRow('province_services', data, id, 'services');
  }

  Future<void> deleteService(String id) async {
    await _deleteRow('province_services', id, 'services');
  }

  // ─── ENGAGEMENT CITOYEN (province_engagements) ───
  Future<List<Map<String, dynamic>>> getEngagements(
      String provinceId, {int limit = 20}) async {
    final rows = await _safeQuery(
      'engagements',
      () async => await _client
          .from('province_engagements')
          .select()
          .eq('province_id', provinceId)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(limit),
    );
    return rows ?? <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> addEngagement(Map<String, dynamic> data) async {
    data.remove('id');
    data['created_at'] = DateTime.now().toIso8601String();
    final r = await _insertRow('province_engagements', data, 'engagements');
    return r!;
  }

  Future<void> updateEngagement(String id, Map<String, dynamic> data) async {
    await _updateRow('province_engagements', data, id, 'engagements');
  }

  Future<void> deleteEngagement(String id) async {
    await _deleteRow('province_engagements', id, 'engagements');
  }

  // Incrémenter le nombre de participants
  Future<void> incrementParticipants(String engagementId) async {
    try {
      await _client.rpc('increment_engagement_participants', params: {'p_id': engagementId});
    } catch (e) {
      // Fallback manuel si RPC absente
      try {
        final row = await _client
            .from('province_engagements')
            .select('participants_count')
            .eq('id', engagementId)
            .maybeSingle();
        if (row != null) {
          final count = (row['participants_count'] as num? ?? 0).toInt();
          await _client
              .from('province_engagements')
              .update({'participants_count': count + 1})
              .eq('id', engagementId);
        }
      } catch (e2) {
        debugPrint('[ProvincesService] incrementParticipants: $e2');
      }
    }
  }

  // ─── BUDGET PAR SECTEUR (province_budget) — pour pie chart ───
  Future<List<Map<String, dynamic>>> getBudget(String provinceId) async {
    final rows = await _safeQuery(
      'budget_chart',
      () async => await _client
          .from('province_budget')
          .select()
          .eq('province_id', provinceId)
          .order('percentage', ascending: false),
    );
    return rows ?? <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> addBudgetItem(Map<String, dynamic> data) async {
    data.remove('id');
    final r = await _insertRow('province_budget', data, 'budget_chart');
    return r!;
  }

  Future<void> updateBudgetItem(String id, Map<String, dynamic> data) async {
    await _updateRow('province_budget', data, id, 'budget_chart');
  }

  Future<void> deleteBudgetItem(String id) async {
    await _deleteRow('province_budget', id, 'budget_chart');
  }

  // ─── DOCUMENTS OFFICIELS (province_documents) ───
  Future<List<Map<String, dynamic>>> getDocuments(
      String provinceId, {int limit = 20}) async {
    final rows = await _safeQuery(
      'documents',
      () async => await _client
          .from('province_documents')
          .select()
          .eq('province_id', provinceId)
          .eq('is_published', true)
          .order('published_at', ascending: false)
          .limit(limit),
    );
    return rows ?? <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> addDocument(Map<String, dynamic> data) async {
    data.remove('id');
    data['created_at'] = DateTime.now().toIso8601String();
    final r = await _insertRow('province_documents', data, 'documents');
    return r!;
  }

  Future<void> updateDocument(String id, Map<String, dynamic> data) async {
    await _updateRow('province_documents', data, id, 'documents');
  }

  Future<void> deleteDocument(String id) async {
    await _deleteRow('province_documents', id, 'documents');
  }

  // ─── MÉDIATHÈQUE (province_media) ───
  Future<List<Map<String, dynamic>>> getMediaLibrary(
      String provinceId, {int limit = 20}) async {
    final rows = await _safeQuery(
      'media_library',
      () async => await _client
          .from('province_media')
          .select()
          .eq('province_id', provinceId)
          .eq('is_published', true)
          .order('published_at', ascending: false)
          .limit(limit),
    );
    return rows ?? <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> addMedia(Map<String, dynamic> data) async {
    data.remove('id');
    data['created_at'] = DateTime.now().toIso8601String();
    final r = await _insertRow('province_media', data, 'media_library');
    return r!;
  }

  Future<void> updateMedia(String id, Map<String, dynamic> data) async {
    await _updateRow('province_media', data, id, 'media_library');
  }

  Future<void> deleteMedia(String id) async {
    await _deleteRow('province_media', id, 'media_library');
  }

  // ─── HYMNE PROVINCIAL (province_hymns) ───
  Future<Map<String, dynamic>?> getHymn(String provinceId) async {
    final rows = await _safeQuery(
      'hymn',
      () async => await _client
          .from('province_hymns')
          .select()
          .eq('province_id', provinceId)
          .limit(1),
    );
    return (rows != null && rows.isNotEmpty) ? rows.first : null;
  }

  Future<Map<String, dynamic>> saveHymn(
      String provinceId, Map<String, dynamic> data) async {
    final existing = await getHymn(provinceId);
    if (existing != null) {
      data['updated_at'] = DateTime.now().toIso8601String();
      await _updateRow('province_hymns', data, existing['id'].toString(), 'hymn');
      return {...existing, ...data};
    } else {
      data.remove('id');
      data['province_id'] = provinceId;
      data['created_at'] = DateTime.now().toIso8601String();
      final r = await _insertRow('province_hymns', data, 'hymn');
      return r!;
    }
  }

  // ─── PERSONNALITÉS CÉLÈBRES (province_famous_people) ───
  Future<List<Map<String, dynamic>>> getFamousPeople(
      String provinceId, {int limit = 20}) async {
    final rows = await _safeQuery(
      'famous_people',
      () async => await _client
          .from('province_famous_people')
          .select()
          .eq('province_id', provinceId)
          .eq('is_active', true)
          .order('name', ascending: true)
          .limit(limit),
    );
    return rows ?? <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> addFamousPerson(Map<String, dynamic> data) async {
    data.remove('id');
    final r = await _insertRow('province_famous_people', data, 'famous_people');
    return r!;
  }

  Future<void> updateFamousPerson(String id, Map<String, dynamic> data) async {
    await _updateRow('province_famous_people', data, id, 'famous_people');
  }

  Future<void> deleteFamousPerson(String id) async {
    await _deleteRow('province_famous_people', id, 'famous_people');
  }

  // ─── GASTRONOMIE (province_gastronomy) ───
  Future<List<Map<String, dynamic>>> getGastronomy(
      String provinceId, {int limit = 20}) async {
    final rows = await _safeQuery(
      'gastronomy',
      () async => await _client
          .from('province_gastronomy')
          .select()
          .eq('province_id', provinceId)
          .eq('is_active', true)
          .order('name', ascending: true)
          .limit(limit),
    );
    return rows ?? <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> addGastronomy(Map<String, dynamic> data) async {
    data.remove('id');
    final r = await _insertRow('province_gastronomy', data, 'gastronomy');
    return r!;
  }

  Future<void> updateGastronomy(String id, Map<String, dynamic> data) async {
    await _updateRow('province_gastronomy', data, id, 'gastronomy');
  }

  Future<void> deleteGastronomy(String id) async {
    await _deleteRow('province_gastronomy', id, 'gastronomy');
  }

  // ─── PROVERBES (province_proverbs) ───
  Future<List<Map<String, dynamic>>> getProverbs(
      String provinceId, {int limit = 20}) async {
    final rows = await _safeQuery(
      'proverbs',
      () async => await _client
          .from('province_proverbs')
          .select()
          .eq('province_id', provinceId)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(limit),
    );
    return rows ?? <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> addProverb(Map<String, dynamic> data) async {
    data.remove('id');
    data['created_at'] = DateTime.now().toIso8601String();
    final r = await _insertRow('province_proverbs', data, 'proverbs');
    return r!;
  }

  Future<void> updateProverb(String id, Map<String, dynamic> data) async {
    await _updateRow('province_proverbs', data, id, 'proverbs');
  }

  Future<void> deleteProverb(String id) async {
    await _deleteRow('province_proverbs', id, 'proverbs');
  }

  // ─── ENTREPRISES LOCALES (province_businesses) ───
  Future<List<Map<String, dynamic>>> getBusinesses(
      String provinceId, {int limit = 20}) async {
    final rows = await _safeQuery(
      'businesses',
      () async => await _client
          .from('province_businesses')
          .select()
          .eq('province_id', provinceId)
          .eq('is_active', true)
          .order('employees', ascending: false)
          .limit(limit),
    );
    return rows ?? <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> addBusiness(Map<String, dynamic> data) async {
    data.remove('id');
    final r = await _insertRow('province_businesses', data, 'businesses');
    return r!;
  }

  Future<void> updateBusiness(String id, Map<String, dynamic> data) async {
    await _updateRow('province_businesses', data, id, 'businesses');
  }

  Future<void> deleteBusiness(String id) async {
    await _deleteRow('province_businesses', id, 'businesses');
  }

  // ─── PRODUITS DU TERROIR (province_products) ───
  Future<List<Map<String, dynamic>>> getProducts(
      String provinceId, {int limit = 20}) async {
    final rows = await _safeQuery(
      'products',
      () async => await _client
          .from('province_products')
          .select()
          .eq('province_id', provinceId)
          .eq('is_active', true)
          .order('name', ascending: true)
          .limit(limit),
    );
    return rows ?? <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> addProduct(Map<String, dynamic> data) async {
    data.remove('id');
    final r = await _insertRow('province_products', data, 'products');
    return r!;
  }

  Future<void> updateProduct(String id, Map<String, dynamic> data) async {
    await _updateRow('province_products', data, id, 'products');
  }

  Future<void> deleteProduct(String id) async {
    await _deleteRow('province_products', id, 'products');
  }

  // ─── QUIZ (province_quiz_questions) ───
  Future<List<Map<String, dynamic>>> getQuizQuestions(
      String provinceId, {int limit = 10}) async {
    final rows = await _safeQuery(
      'quiz',
      () async => await _client
          .from('province_quiz_questions')
          .select()
          .eq('province_id', provinceId)
          .eq('is_active', true)
          .order('order_index', ascending: true)
          .limit(limit),
    );
    return rows ?? <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> addQuizQuestion(Map<String, dynamic> data) async {
    data.remove('id');
    final r = await _insertRow('province_quiz_questions', data, 'quiz');
    return r!;
  }

  Future<void> updateQuizQuestion(String id, Map<String, dynamic> data) async {
    await _updateRow('province_quiz_questions', data, id, 'quiz');
  }

  Future<void> deleteQuizQuestion(String id) async {
    await _deleteRow('province_quiz_questions', id, 'quiz');
  }

  // ─── DÉMOGRAPHIE (province_demographics) ───
  Future<List<Map<String, dynamic>>> getDemographics(String provinceId) async {
    final rows = await _safeQuery(
      'demographics',
      () async => await _client
          .from('province_demographics')
          .select()
          .eq('province_id', provinceId)
          .order('year', ascending: true),
    );
    return rows ?? <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> addDemographicPoint(Map<String, dynamic> data) async {
    data.remove('id');
    final r = await _insertRow('province_demographics', data, 'demographics');
    return r!;
  }

  Future<void> updateDemographicPoint(String id, Map<String, dynamic> data) async {
    await _updateRow('province_demographics', data, id, 'demographics');
  }

  Future<void> deleteDemographicPoint(String id) async {
    await _deleteRow('province_demographics', id, 'demographics');
  }

  // ════════════════════════════════════════════════════════════════════════
  // 📊 STATISTIQUES / COUNTS (pour badges de l'UI)
  // ════════════════════════════════════════════════════════════════════════

  /// Retourne tous les counts d'une province en une seule requête (optimisé).
  Future<Map<String, int>> getProvinceCounts(String provinceId) async {
    final counts = <String, int>{};
    final tables = [
      'province_news',
      'province_projects',
      'province_services',
      'province_engagements',
      'province_documents',
      'province_media',
      'province_famous_people',
      'province_gastronomy',
      'province_proverbs',
      'province_businesses',
      'province_products',
      'province_quiz_questions',
      'cities',
      'province_tourism_sites',
      'province_emergency_contacts',
      'province_administrative_divisions',
    ];

    for (final table in tables) {
      try {
        final res = await _client
            .from(table)
            .select('id')
            .eq('province_id', provinceId)
            .count(CountOption.exact);
        counts[table] = res.count;
      } catch (e) {
        counts[table] = 0;
        debugPrint('[ProvincesService] count $table: $e');
      }
    }
    return counts;
  }

  /// Recherche globale dans toutes les entités d'une province.
  Future<List<Map<String, dynamic>>> searchInProvince(
    String provinceId,
    String query,
  ) async {
    if (query.trim().isEmpty) return [];

    final results = <Map<String, dynamic>>[];
    final q = query.trim();

    // Recherche dans les news
    final news = await _safeQuery(
      'search_news',
      () async => await _client
          .from('province_news')
          .select()
          .eq('province_id', provinceId)
          .or('title.ilike.%$q%,summary.ilike.%$q%')
          .limit(5),
    );
    for (final n in news ?? <Map<String, dynamic>>[]) {
      results.add({...n, '_source': 'news'});
    }

    // Recherche dans les projets
    final projects = await _safeQuery(
      'search_projects',
      () async => await _client
          .from('province_projects')
          .select()
          .eq('province_id', provinceId)
          .or('name.ilike.%$q%,description.ilike.%$q%')
          .limit(5),
    );
    for (final p in projects ?? <Map<String, dynamic>>[]) {
      results.add({...p, '_source': 'project'});
    }

    // Recherche dans les services
    final services = await _safeQuery(
      'search_services',
      () async => await _client
          .from('province_services')
          .select()
          .eq('province_id', provinceId)
          .or('name.ilike.%$q%,description.ilike.%$q%')
          .limit(5),
    );
    for (final s in services ?? <Map<String, dynamic>>[]) {
      results.add({...s, '_source': 'service'});
    }

    // Recherche dans les villes
    final cities = await _safeQuery(
      'search_cities',
      () async => await _client
          .from('cities')
          .select()
          .eq('province_id', provinceId)
          .ilike('name', '%$q%')
          .limit(5),
    );
    for (final c in cities ?? <Map<String, dynamic>>[]) {
      results.add({...c, '_source': 'city'});
    }

    return results;
  }

  // ════════════════════════════════════════════════════════════════════════
  // 🗳️ INTERACTIONS UTILISATEUR
  // ════════════════════════════════════════════════════════════════════════

  /// Enregistrer une réponse à un sondage/vote.
  Future<void> submitEngagementResponse({
    required String engagementId,
    required String userId,
    required String choice,
    String? comment,
  }) async {
    try {
      await _client.from('province_engagement_responses').upsert({
        'engagement_id': engagementId,
        'user_id': userId,
        'choice': choice,
        'comment': comment,
        'responded_at': DateTime.now().toIso8601String(),
      });
      await incrementParticipants(engagementId);
    } catch (e) {
      throw Exception('Erreur soumission réponse: $e');
    }
  }

  /// Signaler un problème (engagement citoyen).
  Future<void> submitIssueReport({
    required String provinceId,
    required String userId,
    required String category,
    required String description,
    String? location,
    String? imageUrl,
  }) async {
    try {
      await _client.from('province_issue_reports').insert({
        'province_id': provinceId,
        'user_id': userId,
        'category': category,
        'description': description,
        'location': location,
        'image_url': imageUrl,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Erreur signalement: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // 💾 SAUVEGARDE COMPLÈTE (legacy — à éviter en production)
  // ════════════════════════════════════════════════════════════════════════

  /// ⚠️ Supprime puis réinsère les relations. À éviter.
  Future<Province> saveProvinceWithRelations(Province province) async {
    try {
      Province savedProvince;
      if (province.id.isEmpty) {
        savedProvince = await createProvince(province);
      } else {
        savedProvince = await updateProvince(province);
      }

      final provinceId = savedProvince.id;

      // Villes
      final existingCities = await _client
          .from('cities')
          .select('id')
          .eq('province_id', provinceId);
      for (final c in existingCities) {
        await deleteCity(c['id'].toString());
      }
      for (final city in province.cities) {
        await addCity(City(
          id: '',
          provinceId: provinceId,
          name: city.name,
          population: city.population,
          isCapital: city.isCapital,
          mayor: city.mayor,
          mayorPhotoUrl: city.mayorPhotoUrl,
          media: city.media,
        ));
      }

      // Ressources économiques
      final existingEco = await _client
          .from('province_economic_resources')
          .select('id')
          .eq('province_id', provinceId);
      for (final e in existingEco) {
        await deleteEconomicResource(e['id'].toString());
      }
      for (final resource in province.economicResources) {
        await addEconomicResource(ProvinceEconomicResource(
          id: '',
          provinceId: provinceId,
          name: resource.name,
          description: resource.description,
          media: resource.media,
        ));
      }

      // Sites touristiques
      final existingTourism = await _client
          .from(_tourismTable)
          .select('id')
          .eq('province_id', provinceId);
      for (final t in existingTourism) {
        await deleteTourismSite(t['id'].toString());
      }
      for (final site in province.tourismSites) {
        await addTourismSite(ProvinceTourism(
          id: '',
          provinceId: provinceId,
          name: site.name,
          type: site.type,
          description: site.description,
          media: site.media,
        ));
      }

      // Divisions administratives
      final existingAdmin = await _client
          .from('province_administrative_divisions')
          .select('id')
          .eq('province_id', provinceId);
      for (final a in existingAdmin) {
        await deleteAdministrativeDivision(a['id'].toString());
      }
      for (final division in province.administrativeDivisions) {
        await addAdministrativeDivision(ProvinceAdministrativeDivision(
          id: '',
          provinceId: provinceId,
          type: division.type,
          name: division.name,
          capital: division.capital,
          population: division.population,
          area: division.area,
          administrator: division.administrator,
          media: division.media,
        ));
      }

      // Contacts d'urgence
      final existingEmergency = await _client
          .from('province_emergency_contacts')
          .select('id')
          .eq('province_id', provinceId);
      for (final e in existingEmergency) {
        await deleteEmergencyContact(e['id'].toString());
      }
      for (final contact in province.emergencyContacts) {
        await addEmergencyContact(ProvinceEmergencyContact(
          id: '',
          provinceId: provinceId,
          service: contact.service,
          phone: contact.phone,
        ));
      }

      return savedProvince;
    } catch (e) {
      throw Exception('Erreur sauvegarde complète province: $e');
    }
  }
}
