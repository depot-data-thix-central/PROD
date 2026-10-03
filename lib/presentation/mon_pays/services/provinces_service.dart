// lib/presentation/mon_pays/services/provinces_service.dart
//
// ✅ Liste des provinces tolérante : une ligne illisible est ignorée (et loguée)
//    au lieu de faire échouer toute la liste.
// ✅ Chargement complet : relations facultatives qui n'empêchent plus la page,
//    + galerie / réalisations / tribus lues depuis leurs tables,
//    + table tourisme = province_tourism_sites (repli sur province_tourism).

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

  // ============================================================
  // HELPERS
  // ============================================================

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

  Map<String, dynamic> _withMediaList(Map<String, dynamic> r) {
    final m = r['media'];
    return <String, dynamic>{
      ...r,
      'media': m is List
          ? m.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[],
    };
  }

  // ============================================================
  // PROVINCES CRUD
  // ============================================================

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

      // Si AUCUNE ligne n'a pu être lue, on remonte l'erreur réelle.
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
      return Province.fromJson(response);
    } catch (e) {
      throw Exception('Erreur chargement province: $e');
    }
  }

  // Province complète avec toutes les relations
  Future<Province> getProvinceWithAllRelations(String id) async {
    try {
      // 1. Province de base (obligatoire)
      final province = await getProvinceById(id);

      // 2. Gouvernement + ministres (facultatif)
      ProvinceGovernment? government;
      try {
        final gov = await _client
            .from('province_governments')
            .select('*, ministers:province_ministers(*)')
            .eq('province_id', id)
            .maybeSingle();
        if (gov != null) government = ProvinceGovernment.fromJson(gov);
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

      // 5. Budget
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

      // 6. Tourisme (province_tourism_sites, repli sur province_tourism)
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

      // 9. Galerie, réalisations, tribus (tables dédiées).
      //    Si une table est vide ou absente, on garde ce que la ligne
      //    `provinces` contenait déjà.
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
      // On retire l'ID (généré par Supabase) et les relations
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

      return Province.fromJson(response);
    } catch (e) {
      throw Exception('Erreur création province: $e');
    }
  }

  Future<Province> updateProvince(Province province) async {
    try {
      final data = province.toJson();
      // On retire les relations pour ne mettre à jour que la table 'provinces'
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

      return Province.fromJson(response);
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

  // ============================================================
  // GOUVERNEMENT
  // ============================================================

  Future<ProvinceGovernment?> getGovernment(String provinceId) async {
    try {
      final response = await _client
          .from('province_governments')
          .select('*, ministers:province_ministers(*)')
          .eq('province_id', provinceId)
          .maybeSingle();

      if (response == null) return null;
      return ProvinceGovernment.fromJson(response);
    } catch (e) {
      return null; // On retourne null silencieusement si pas de gouvernement
    }
  }

  Future<ProvinceGovernment> createGovernment(ProvinceGovernment gov) async {
    try {
      final data = gov.toJson();
      data.remove('id');
      data.remove('ministers');

      final response = await _client
          .from('province_governments')
          .insert(data)
          .select()
          .single();

      return ProvinceGovernment.fromJson(response);
    } catch (e) {
      throw Exception('Erreur création gouvernement: $e');
    }
  }

  Future<ProvinceGovernment> updateGovernment(ProvinceGovernment gov) async {
    try {
      final data = gov.toJson();
      data.remove('ministers');

      await _client
          .from('province_governments')
          .update(data)
          .eq('id', gov.id);

      return gov;
    } catch (e) {
      throw Exception('Erreur mise à jour gouvernement: $e');
    }
  }

  // ============================================================
  // MINISTRES
  // ============================================================

  Future<ProvinceMinister> addMinister(ProvinceMinister minister) async {
    try {
      final data = minister.toJson();
      data.remove('id');

      final response = await _client
          .from('province_ministers')
          .insert(data)
          .select()
          .single();

      return ProvinceMinister.fromJson(response);
    } catch (e) {
      throw Exception('Erreur ajout ministre: $e');
    }
  }

  Future<void> removeMinister(String id) async {
    try {
      await _client.from('province_ministers').delete().eq('id', id);
    } catch (e) {
      throw Exception('Erreur suppression ministre: $e');
    }
  }

  // ============================================================
  // RESSOURCES ÉCONOMIQUES
  // ============================================================

  Future<List<ProvinceEconomicResource>> getEconomicResources(String provinceId) async {
    try {
      final response = await _client
          .from('province_economic_resources')
          .select('*')
          .eq('province_id', provinceId)
          .order('is_key_sector', ascending: false);

      return _parseRows<ProvinceEconomicResource>(
        response.map((e) => Map<String, dynamic>.from(e)).toList(),
        (j) => ProvinceEconomicResource.fromJson(j),
        'économie',
      );
    } catch (e) {
      throw Exception('Erreur chargement ressources économiques: $e');
    }
  }

  Future<ProvinceEconomicResource> addEconomicResource(ProvinceEconomicResource resource) async {
    try {
      final data = resource.toJson();
      data.remove('id');

      final response = await _client
          .from('province_economic_resources')
          .insert(data)
          .select()
          .single();

      return ProvinceEconomicResource.fromJson(response);
    } catch (e) {
      throw Exception('Erreur ajout ressource économique: $e');
    }
  }

  Future<void> updateEconomicResource(ProvinceEconomicResource resource) async {
    try {
      await _client
          .from('province_economic_resources')
          .update(resource.toJson())
          .eq('id', resource.id);
    } catch (e) {
      throw Exception('Erreur mise à jour ressource économique: $e');
    }
  }

  Future<void> deleteEconomicResource(String id) async {
    try {
      await _client.from('province_economic_resources').delete().eq('id', id);
    } catch (e) {
      throw Exception('Erreur suppression ressource économique: $e');
    }
  }

  // ============================================================
  // BUDGET
  // ============================================================

  Future<List<ProvinceBudgetPriority>> getBudgetPriorities(String provinceId) async {
    try {
      final response = await _client
          .from('province_budget_priorities')
          .select('*')
          .eq('province_id', provinceId)
          .order('year', ascending: false);

      return _parseRows<ProvinceBudgetPriority>(
        response.map((e) => Map<String, dynamic>.from(e)).toList(),
        (j) => ProvinceBudgetPriority.fromJson(j),
        'budget',
      );
    } catch (e) {
      throw Exception('Erreur chargement budget: $e');
    }
  }

  Future<ProvinceBudgetPriority> addBudgetPriority(ProvinceBudgetPriority budget) async {
    try {
      final data = budget.toJson();
      data.remove('id');

      final response = await _client
          .from('province_budget_priorities')
          .insert(data)
          .select()
          .single();

      return ProvinceBudgetPriority.fromJson(response);
    } catch (e) {
      throw Exception('Erreur ajout priorité budgétaire: $e');
    }
  }

  Future<void> updateBudgetPriority(ProvinceBudgetPriority budget) async {
    try {
      await _client
          .from('province_budget_priorities')
          .update(budget.toJson())
          .eq('id', budget.id);
    } catch (e) {
      throw Exception('Erreur mise à jour priorité budgétaire: $e');
    }
  }

  Future<void> deleteBudgetPriority(String id) async {
    try {
      await _client.from('province_budget_priorities').delete().eq('id', id);
    } catch (e) {
      throw Exception('Erreur suppression priorité budgétaire: $e');
    }
  }

  // ============================================================
  // TOURISME
  // ============================================================

  Future<List<ProvinceTourism>> getTourismSites(String provinceId) async {
    try {
      final response = await _client
          .from(_tourismTable)
          .select('*')
          .eq('province_id', provinceId);

      return _parseRows<ProvinceTourism>(
        response.map((e) => Map<String, dynamic>.from(e)).toList(),
        (j) => ProvinceTourism.fromJson(j),
        'tourisme',
      );
    } catch (e) {
      throw Exception('Erreur chargement sites touristiques: $e');
    }
  }

  Future<ProvinceTourism> addTourismSite(ProvinceTourism site) async {
    try {
      final data = site.toJson();
      data.remove('id');

      final response = await _client
          .from(_tourismTable)
          .insert(data)
          .select()
          .single();

      return ProvinceTourism.fromJson(response);
    } catch (e) {
      throw Exception('Erreur ajout site touristique: $e');
    }
  }

  Future<void> updateTourismSite(ProvinceTourism site) async {
    try {
      await _client
          .from(_tourismTable)
          .update(site.toJson())
          .eq('id', site.id);
    } catch (e) {
      throw Exception('Erreur mise à jour site touristique: $e');
    }
  }

  Future<void> deleteTourismSite(String id) async {
    try {
      await _client.from(_tourismTable).delete().eq('id', id);
    } catch (e) {
      throw Exception('Erreur suppression site touristique: $e');
    }
  }

  // ============================================================
  // URGENCES
  // ============================================================

  Future<List<ProvinceEmergencyContact>> getEmergencyContacts(String provinceId) async {
    try {
      final response = await _client
          .from('province_emergency_contacts')
          .select('*')
          .eq('province_id', provinceId);

      return _parseRows<ProvinceEmergencyContact>(
        response.map((e) => Map<String, dynamic>.from(e)).toList(),
        (j) => ProvinceEmergencyContact.fromJson(j),
        'urgences',
      );
    } catch (e) {
      throw Exception('Erreur chargement contacts d\'urgence: $e');
    }
  }

  Future<ProvinceEmergencyContact> addEmergencyContact(ProvinceEmergencyContact contact) async {
    try {
      final data = contact.toJson();
      data.remove('id');

      final response = await _client
          .from('province_emergency_contacts')
          .insert(data)
          .select()
          .single();

      return ProvinceEmergencyContact.fromJson(response);
    } catch (e) {
      throw Exception('Erreur ajout contact d\'urgence: $e');
    }
  }

  Future<void> updateEmergencyContact(ProvinceEmergencyContact contact) async {
    try {
      await _client
          .from('province_emergency_contacts')
          .update(contact.toJson())
          .eq('id', contact.id);
    } catch (e) {
      throw Exception('Erreur mise à jour contact d\'urgence: $e');
    }
  }

  Future<void> deleteEmergencyContact(String id) async {
    try {
      await _client.from('province_emergency_contacts').delete().eq('id', id);
    } catch (e) {
      throw Exception('Erreur suppression contact d\'urgence: $e');
    }
  }

  // ============================================================
  // DÉCOUPAGE ADMINISTRATIF
  // ============================================================

  Future<List<ProvinceAdministrativeDivision>> getAdministrativeDivisions(String provinceId) async {
    try {
      final response = await _client
          .from('province_administrative_divisions')
          .select('*')
          .eq('province_id', provinceId);

      return _parseRows<ProvinceAdministrativeDivision>(
        response.map((e) => Map<String, dynamic>.from(e)).toList(),
        (j) => ProvinceAdministrativeDivision.fromJson(j),
        'découpage',
      );
    } catch (e) {
      throw Exception('Erreur chargement découpage administratif: $e');
    }
  }

  Future<ProvinceAdministrativeDivision> addAdministrativeDivision(ProvinceAdministrativeDivision division) async {
    try {
      final data = division.toJson();
      data.remove('id');

      final response = await _client
          .from('province_administrative_divisions')
          .insert(data)
          .select()
          .single();

      return ProvinceAdministrativeDivision.fromJson(response);
    } catch (e) {
      throw Exception('Erreur ajout division administrative: $e');
    }
  }

  Future<void> updateAdministrativeDivision(ProvinceAdministrativeDivision division) async {
    try {
      await _client
          .from('province_administrative_divisions')
          .update(division.toJson())
          .eq('id', division.id);
    } catch (e) {
      throw Exception('Erreur mise à jour division administrative: $e');
    }
  }

  Future<void> deleteAdministrativeDivision(String id) async {
    try {
      await _client.from('province_administrative_divisions').delete().eq('id', id);
    } catch (e) {
      throw Exception('Erreur suppression division administrative: $e');
    }
  }

  // ============================================================
  // VILLES
  // ============================================================

  Future<City> addCity(City city) async {
    try {
      final data = city.toJson();
      data.remove('id');

      final response = await _client
          .from('cities')
          .insert(data)
          .select()
          .single();

      return City.fromJson(response);
    } catch (e) {
      throw Exception('Erreur ajout ville: $e');
    }
  }

  Future<void> updateCity(City city) async {
    try {
      await _client
          .from('cities')
          .update(city.toJson())
          .eq('id', city.id);
    } catch (e) {
      throw Exception('Erreur mise à jour ville: $e');
    }
  }

  Future<void> deleteCity(String id) async {
    try {
      await _client.from('cities').delete().eq('id', id);
    } catch (e) {
      throw Exception('Erreur suppression ville: $e');
    }
  }

  // ============================================================
  // SAUVEGARDE COMPLÈTE (Province + Relations)
  // ⚠️ Supprime puis réinsère les relations : à éviter (une erreur au milieu
  //    fait perdre des données). Le formulaire admin n'utilise plus cette méthode.
  // ============================================================

  Future<Province> saveProvinceWithRelations(Province province) async {
    try {
      // 1. Créer ou mettre à jour la province principale
      Province savedProvince;
      if (province.id.isEmpty) {
        savedProvince = await createProvince(province);
      } else {
        savedProvince = await updateProvince(province);
      }

      final provinceId = savedProvince.id;

      // 2. Villes
      final existingCities = await _client.from('cities').select('id').eq('province_id', provinceId);
      for (final c in existingCities) {
        await deleteCity(c['id']);
      }
      for (final city in province.cities) {
        final cityToSave = City(
          id: '',
          provinceId: provinceId,
          name: city.name,
          population: city.population,
          isCapital: city.isCapital,
          mayor: city.mayor,
          mayorPhotoUrl: city.mayorPhotoUrl,
          media: city.media,
        );
        await addCity(cityToSave);
      }

      // 3. Ressources économiques
      final existingEco = await _client.from('province_economic_resources').select('id').eq('province_id', provinceId);
      for (final e in existingEco) {
        await deleteEconomicResource(e['id']);
      }
      for (final resource in province.economicResources) {
        final resourceToSave = ProvinceEconomicResource(
          id: '',
          provinceId: provinceId,
          name: resource.name,
          description: resource.description,
          media: resource.media,
        );
        await addEconomicResource(resourceToSave);
      }

      // 4. Sites touristiques
      final existingTourism = await _client.from(_tourismTable).select('id').eq('province_id', provinceId);
      for (final t in existingTourism) {
        await deleteTourismSite(t['id']);
      }
      for (final site in province.tourismSites) {
        final siteToSave = ProvinceTourism(
          id: '',
          provinceId: provinceId,
          name: site.name,
          type: site.type,
          description: site.description,
          media: site.media,
        );
        await addTourismSite(siteToSave);
      }

      // 5. Divisions administratives
      final existingAdmin = await _client.from('province_administrative_divisions').select('id').eq('province_id', provinceId);
      for (final a in existingAdmin) {
        await deleteAdministrativeDivision(a['id']);
      }
      for (final division in province.administrativeDivisions) {
        final divisionToSave = ProvinceAdministrativeDivision(
          id: '',
          provinceId: provinceId,
          type: division.type,
          name: division.name,
          capital: division.capital,
          population: division.population,
          area: division.area,
          administrator: division.administrator,
          media: division.media,
        );
        await addAdministrativeDivision(divisionToSave);
      }

      // 6. Contacts d'urgence
      final existingEmergency = await _client.from('province_emergency_contacts').select('id').eq('province_id', provinceId);
      for (final e in existingEmergency) {
        await deleteEmergencyContact(e['id']);
      }
      for (final contact in province.emergencyContacts) {
        final contactToSave = ProvinceEmergencyContact(
          id: '',
          provinceId: provinceId,
          service: contact.service,
          phone: contact.phone,
        );
        await addEmergencyContact(contactToSave);
      }

      return savedProvince;
    } catch (e) {
      throw Exception('Erreur sauvegarde complète province: $e');
    }
  }
}
