// ============================================================
// PROVIDERS – PHASE 3.0 (PRODUCTION)
// ============================================================
// Fichier n°13 : providers/provinces_provider.dart
// lib/presentation/mon_pays/providers/provinces_provider.dart
//
// ✅ Compatible avec Province v2.0 et ProvincesService v3.0
// ✅ 16 nouvelles tables (news, projects, services, engagements,
//    budget, documents, media, hymns, famous_people, gastronomy,
//    proverbs, businesses, products, quiz_questions, demographics)
// ✅ Providers pour counts/stats (badges UI)
// ✅ Providers d'interactions utilisateur (sondages, signalements)
// ✅ Provider favoris (SharedPreferences)
// ✅ Provider recherche globale multi-entités
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/province.dart';
import '../models/province_government.dart';
import '../models/province_minister.dart';
import '../models/province_economic.dart';
import '../models/province_tourism.dart';
import '../models/province_emergency.dart';
import '../models/province_administrative.dart';
import '../models/province_budget.dart';
import '../models/city.dart';
import '../services/provinces_service.dart';

// ════════════════════════════════════════════════════════════════════════
// 1. SERVICE PROVIDER
// ════════════════════════════════════════════════════════════════════════

final provincesServiceProvider = Provider<ProvincesService>((ref) {
  return ProvincesService();
});

// ════════════════════════════════════════════════════════════════════════
// 2. LISTE PUBLIQUE (avec filtres)
// ════════════════════════════════════════════════════════════════════════

/// Liste des provinces filtrée par région (null = toutes).
final provincesProvider =
    FutureProvider.family<List<Province>, String?>((ref, region) async {
  final service = ref.watch(provincesServiceProvider);
  return service.getProvinces(region: region);
});

/// Recherche de provinces par nom/capitale.
final searchProvincesProvider =
    FutureProvider.family<List<Province>, String>((ref, query) async {
  final service = ref.watch(provincesServiceProvider);
  return service.getProvinces(search: query);
});

// ════════════════════════════════════════════════════════════════════════
// 3. PROVINCE COMPLÈTE (avec toutes les relations)
// ════════════════════════════════════════════════════════════════════════

/// Province avec toutes les relations historiques chargées.
final provinceWithAllRelationsProvider =
    FutureProvider.family<Province, String>((ref, id) async {
  final service = ref.watch(provincesServiceProvider);
  return service.getProvinceWithAllRelations(id);
});

// ════════════════════════════════════════════════════════════════════════
// 4. SOUS-RESSOURCES D'UNE PROVINCE (RELATIONS HISTORIQUES)
// ════════════════════════════════════════════════════════════════════════

final provinceGovernmentProvider =
    FutureProvider.family<ProvinceGovernment?, String>((ref, provinceId) async {
  final service = ref.watch(provincesServiceProvider);
  return service.getGovernment(provinceId);
});

final provinceMinistersProvider =
    FutureProvider.family<List<ProvinceMinister>, String>((ref, provinceId) async {
  final service = ref.watch(provincesServiceProvider);
  final gov = await service.getGovernment(provinceId);
  return gov?.ministers ?? [];
});

final provinceEconomicResourcesProvider =
    FutureProvider.family<List<ProvinceEconomicResource>, String>(
        (ref, provinceId) async {
  final service = ref.watch(provincesServiceProvider);
  return service.getEconomicResources(provinceId);
});

final provinceBudgetPrioritiesProvider =
    FutureProvider.family<List<ProvinceBudgetPriority>, String>(
        (ref, provinceId) async {
  final service = ref.watch(provincesServiceProvider);
  return service.getBudgetPriorities(provinceId);
});

final provinceTourismSitesProvider =
    FutureProvider.family<List<ProvinceTourism>, String>((ref, provinceId) async {
  final service = ref.watch(provincesServiceProvider);
  return service.getTourismSites(provinceId);
});

final provinceEmergencyContactsProvider =
    FutureProvider.family<List<ProvinceEmergencyContact>, String>(
        (ref, provinceId) async {
  final service = ref.watch(provincesServiceProvider);
  return service.getEmergencyContacts(provinceId);
});

final provinceAdministrativeDivisionsProvider =
    FutureProvider.family<List<ProvinceAdministrativeDivision>, String>(
        (ref, provinceId) async {
  final service = ref.watch(provincesServiceProvider);
  return service.getAdministrativeDivisions(provinceId);
});

final provinceCitiesProvider =
    FutureProvider.family<List<City>, String>((ref, provinceId) async {
  final service = ref.watch(provincesServiceProvider);
  return service.getCities(provinceId);
});

// ════════════════════════════════════════════════════════════════════════
// 5. NOUVELLES TABLES (PAGE PRODUCTION)
// ════════════════════════════════════════════════════════════════════════

// ─── ACTUALITÉS ───
final provinceNewsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, provinceId) async {
  try {
    final service = ref.watch(provincesServiceProvider);
    return await service.getNews(provinceId, limit: 20);
  } catch (e) {
    debugPrint('[provinceNewsProvider] error: $e');
    return [];
  }
});

// ─── PROJETS EN COURS ───
final provinceProjectsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, provinceId) async {
  try {
    final service = ref.watch(provincesServiceProvider);
    return await service.getProjects(provinceId, limit: 20);
  } catch (e) {
    debugPrint('[provinceProjectsProvider] error: $e');
    return [];
  }
});

// ─── SERVICES PUBLICS ───
final provinceServicesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, provinceId) async {
  try {
    final service = ref.watch(provincesServiceProvider);
    return await service.getServices(provinceId, limit: 30);
  } catch (e) {
    debugPrint('[provinceServicesProvider] error: $e');
    return [];
  }
});

// ─── ENGAGEMENT CITOYEN ───
final provinceEngagementsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, provinceId) async {
  try {
    final service = ref.watch(provincesServiceProvider);
    return await service.getEngagements(provinceId, limit: 20);
  } catch (e) {
    debugPrint('[provinceEngagementsProvider] error: $e');
    return [];
  }
});

// ─── BUDGET (PIE CHART) ───
final provinceBudgetChartProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, provinceId) async {
  try {
    final service = ref.watch(provincesServiceProvider);
    return await service.getBudget(provinceId);
  } catch (e) {
    debugPrint('[provinceBudgetChartProvider] error: $e');
    return [];
  }
});

// ─── DOCUMENTS OFFICIELS ───
final provinceDocumentsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, provinceId) async {
  try {
    final service = ref.watch(provincesServiceProvider);
    return await service.getDocuments(provinceId, limit: 20);
  } catch (e) {
    debugPrint('[provinceDocumentsProvider] error: $e');
    return [];
  }
});

// ─── MÉDIATHÈQUE ───
final provinceMediaProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, provinceId) async {
  try {
    final service = ref.watch(provincesServiceProvider);
    return await service.getMediaLibrary(provinceId, limit: 20);
  } catch (e) {
    debugPrint('[provinceMediaProvider] error: $e');
    return [];
  }
});

// ─── HYMNE PROVINCIAL ───
final provinceHymnProvider =
    FutureProvider.family<Map<String, dynamic>?, String>(
        (ref, provinceId) async {
  try {
    final service = ref.watch(provincesServiceProvider);
    return await service.getHymn(provinceId);
  } catch (e) {
    debugPrint('[provinceHymnProvider] error: $e');
    return null;
  }
});

// ─── PERSONNALITÉS CÉLÈBRES ───
final provinceFamousPeopleProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, provinceId) async {
  try {
    final service = ref.watch(provincesServiceProvider);
    return await service.getFamousPeople(provinceId, limit: 20);
  } catch (e) {
    debugPrint('[provinceFamousPeopleProvider] error: $e');
    return [];
  }
});

// ─── GASTRONOMIE ───
final provinceGastronomyProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, provinceId) async {
  try {
    final service = ref.watch(provincesServiceProvider);
    return await service.getGastronomy(provinceId, limit: 20);
  } catch (e) {
    debugPrint('[provinceGastronomyProvider] error: $e');
    return [];
  }
});

// ─── PROVERBES & CONTES ───
final provinceProverbsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, provinceId) async {
  try {
    final service = ref.watch(provincesServiceProvider);
    return await service.getProverbs(provinceId, limit: 20);
  } catch (e) {
    debugPrint('[provinceProverbsProvider] error: $e');
    return [];
  }
});

// ─── ENTREPRISES LOCALES ───
final provinceBusinessesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, provinceId) async {
  try {
    final service = ref.watch(provincesServiceProvider);
    return await service.getBusinesses(provinceId, limit: 20);
  } catch (e) {
    debugPrint('[provinceBusinessesProvider] error: $e');
    return [];
  }
});

// ─── PRODUITS DU TERROIR ───
final provinceProductsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, provinceId) async {
  try {
    final service = ref.watch(provincesServiceProvider);
    return await service.getProducts(provinceId, limit: 20);
  } catch (e) {
    debugPrint('[provinceProductsProvider] error: $e');
    return [];
  }
});

// ─── QUIZ ───
final provinceQuizProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, provinceId) async {
  try {
    final service = ref.watch(provincesServiceProvider);
    return await service.getQuizQuestions(provinceId, limit: 10);
  } catch (e) {
    debugPrint('[provinceQuizProvider] error: $e');
    return [];
  }
});

// ─── DÉMOGRAPHIE (SÉRIES TEMPORELLES) ───
final provinceDemographicsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, provinceId) async {
  try {
    final service = ref.watch(provincesServiceProvider);
    return await service.getDemographics(provinceId);
  } catch (e) {
    debugPrint('[provinceDemographicsProvider] error: $e');
    return [];
  }
});

// ════════════════════════════════════════════════════════════════════════
// 6. COUNTS / STATS (pour badges UI)
// ════════════════════════════════════════════════════════════════════════

/// Compteurs de toutes les entités d'une province (pour badges).
final provinceCountsProvider =
    FutureProvider.family<Map<String, int>, String>((ref, provinceId) async {
  try {
    final service = ref.watch(provincesServiceProvider);
    return await service.getProvinceCounts(provinceId);
  } catch (e) {
    debugPrint('[provinceCountsProvider] error: $e');
    return {};
  }
});

/// Compteurs avec auto-refresh (utilise les providers individuels).
/// Fallback si `getProvinceCounts` échoue.
final provinceCountsFromProvidersProvider =
    Provider.family<Map<String, int>, String>((ref, provinceId) {
  final news = ref.watch(provinceNewsProvider(provinceId));
  final projects = ref.watch(provinceProjectsProvider(provinceId));
  final services = ref.watch(provinceServicesProvider(provinceId));
  final engagements = ref.watch(provinceEngagementsProvider(provinceId));
  final docs = ref.watch(provinceDocumentsProvider(provinceId));
  final media = ref.watch(provinceMediaProvider(provinceId));
  final famous = ref.watch(provinceFamousPeopleProvider(provinceId));
  final gastro = ref.watch(provinceGastronomyProvider(provinceId));
  final proverbs = ref.watch(provinceProverbsProvider(provinceId));
  final businesses = ref.watch(provinceBusinessesProvider(provinceId));
  final products = ref.watch(provinceProductsProvider(provinceId));

  return {
    'news': news.valueOrNull?.length ?? 0,
    'projects': projects.valueOrNull?.length ?? 0,
    'services': services.valueOrNull?.length ?? 0,
    'engagements': engagements.valueOrNull?.length ?? 0,
    'documents': docs.valueOrNull?.length ?? 0,
    'media': media.valueOrNull?.length ?? 0,
    'famous_people': famous.valueOrNull?.length ?? 0,
    'gastronomy': gastro.valueOrNull?.length ?? 0,
    'proverbs': proverbs.valueOrNull?.length ?? 0,
    'businesses': businesses.valueOrNull?.length ?? 0,
    'products': products.valueOrNull?.length ?? 0,
  };
});

// ════════════════════════════════════════════════════════════════════════
// 7. RECHERCHE GLOBALE
// ════════════════════════════════════════════════════════════════════════

/// Recherche multi-entités dans une province.
final provinceSearchProvider = FutureProvider.family<
    List<Map<String, dynamic>>,
    ({String provinceId, String query})>((ref, params) async {
  if (params.query.trim().isEmpty) return [];
  try {
    final service = ref.watch(provincesServiceProvider);
    return await service.searchInProvince(params.provinceId, params.query);
  } catch (e) {
    debugPrint('[provinceSearchProvider] error: $e');
    return [];
  }
});

/// Recherche globale avec debounce (utilisé par la barre de recherche UI).
final provinceSearchDebouncedProvider =
    StateNotifierProvider.family<ProvinceSearchDebouncedNotifier,
        List<Map<String, dynamic>>, String>((ref, provinceId) {
  return ProvinceSearchDebouncedNotifier(ref, provinceId);
});

class ProvinceSearchDebouncedNotifier
    extends StateNotifier<List<Map<String, dynamic>>> {
  final Ref _ref;
  final String _provinceId;
  Timer? _debounce;

  ProvinceSearchDebouncedNotifier(this._ref, this._provinceId) : super([]);

  void search(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      state = [];
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final service = _ref.read(provincesServiceProvider);
        final results = await service.searchInProvince(_provinceId, query);
        state = results;
      } catch (e) {
        debugPrint('[ProvinceSearchDebounced] error: $e');
        state = [];
      }
    });
  }

  void clear() {
    _debounce?.cancel();
    state = [];
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

// ════════════════════════════════════════════════════════════════════════
// 8. FAVORIS (SharedPreferences)
// ════════════════════════════════════════════════════════════════════════

final favoriteProvincesProvider =
    StateNotifierProvider<FavoriteProvincesNotifier, Set<String>>((ref) {
  return FavoriteProvincesNotifier();
});

class FavoriteProvincesNotifier extends StateNotifier<Set<String>> {
  FavoriteProvincesNotifier() : super({}) {
    _load();
  }

  static const String _key = 'favorite_provinces';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_key) ?? [];
      state = list.toSet();
    } catch (e) {
      debugPrint('[FavoriteProvinces] load error: $e');
    }
  }

  Future<void> toggle(String provinceId) async {
    final newSet = Set<String>.from(state);
    if (newSet.contains(provinceId)) {
      newSet.remove(provinceId);
    } else {
      newSet.add(provinceId);
    }
    state = newSet;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, newSet.toList());
    } catch (e) {
      debugPrint('[FavoriteProvinces] save error: $e');
    }
  }

  Future<void> add(String provinceId) async {
    final newSet = Set<String>.from(state)..add(provinceId);
    state = newSet;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, newSet.toList());
    } catch (e) {
      debugPrint('[FavoriteProvinces] save error: $e');
    }
  }

  Future<void> remove(String provinceId) async {
    final newSet = Set<String>.from(state)..remove(provinceId);
    state = newSet;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, newSet.toList());
    } catch (e) {
      debugPrint('[FavoriteProvinces] save error: $e');
    }
  }

  bool isFavorite(String provinceId) => state.contains(provinceId);
}

// ════════════════════════════════════════════════════════════════════════
// 9. INTERACTIONS UTILISATEUR
// ════════════════════════════════════════════════════════════════════════

/// Enregistrer une réponse à un engagement (sondage/vote).
final submitEngagementResponseProvider =
    FutureProvider.family<bool, _EngagementResponseParams>((ref, params) async {
  try {
    final service = ref.read(provincesServiceProvider);
    await service.submitEngagementResponse(
      engagementId: params.engagementId,
      userId: params.userId,
      choice: params.choice,
      comment: params.comment,
    );
    // Invalider pour rafraîchir le nombre de participants
    ref.invalidate(provinceEngagementsProvider(params.provinceId));
    return true;
  } catch (e) {
    debugPrint('[submitEngagementResponse] error: $e');
    return false;
  }
});

class _EngagementResponseParams {
  final String engagementId;
  final String provinceId;
  final String userId;
  final String choice;
  final String? comment;

  const _EngagementResponseParams({
    required this.engagementId,
    required this.provinceId,
    required this.userId,
    required this.choice,
    this.comment,
  });
}

/// Helper pour créer les paramètres facilement.
_EngagementResponseParams engagementResponseParams({
  required String engagementId,
  required String provinceId,
  required String userId,
  required String choice,
  String? comment,
}) {
  return _EngagementResponseParams(
    engagementId: engagementId,
    provinceId: provinceId,
    userId: userId,
    choice: choice,
    comment: comment,
  );
}

/// Signaler un problème (engagement citoyen).
final submitIssueReportProvider =
    FutureProvider.family<bool, _IssueReportParams>((ref, params) async {
  try {
    final service = ref.read(provincesServiceProvider);
    await service.submitIssueReport(
      provinceId: params.provinceId,
      userId: params.userId,
      category: params.category,
      description: params.description,
      location: params.location,
      imageUrl: params.imageUrl,
    );
    return true;
  } catch (e) {
    debugPrint('[submitIssueReport] error: $e');
    return false;
  }
});

class _IssueReportParams {
  final String provinceId;
  final String userId;
  final String category;
  final String description;
  final String? location;
  final String? imageUrl;

  const _IssueReportParams({
    required this.provinceId,
    required this.userId,
    required this.category,
    required this.description,
    this.location,
    this.imageUrl,
  });
}

_IssueReportParams issueReportParams({
  required String provinceId,
  required String userId,
  required String category,
  required String description,
  String? location,
  String? imageUrl,
}) {
  return _IssueReportParams(
    provinceId: provinceId,
    userId: userId,
    category: category,
    description: description,
    location: location,
    imageUrl: imageUrl,
  );
}

// ════════════════════════════════════════════════════════════════════════
// 10. ADMIN PROVINCES (CRUD avec StateNotifier)
// ════════════════════════════════════════════════════════════════════════

final adminProvincesProvider = StateNotifierProvider<AdminProvincesNotifier,
    AsyncValue<List<Province>>>((ref) {
  return AdminProvincesNotifier(ref);
});

class AdminProvincesNotifier extends StateNotifier<AsyncValue<List<Province>>> {
  final Ref _ref;

  AdminProvincesNotifier(this._ref) : super(const AsyncValue.loading()) {
    loadProvinces();
  }

  Future<void> loadProvinces() async {
    state = const AsyncValue.loading();
    try {
      final service = _ref.read(provincesServiceProvider);
      final list = await service.getProvinces();
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  // ─── PROVINCES ───

  Future<void> createProvince(Province province) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.createProvince(province);
      _ref.invalidate(provincesProvider);
      await loadProvinces();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updateProvince(Province province) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.updateProvince(province);
      _ref.invalidate(provincesProvider);
      _ref.invalidate(provinceWithAllRelationsProvider(province.id));
      await loadProvinces();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deleteProvince(String id) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.deleteProvince(id);
      _ref.invalidate(provincesProvider);
      _ref.invalidate(provinceWithAllRelationsProvider(id));
      await loadProvinces();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // ─── GOUVERNEMENT ───

  Future<void> updateGovernment(ProvinceGovernment gov) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.updateGovernment(gov);
      _ref.invalidate(provinceWithAllRelationsProvider(gov.provinceId));
      await loadProvinces();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // ─── MINISTRES ───

  Future<void> addMinister(ProvinceMinister minister) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.addMinister(minister);
      await loadProvinces();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> removeMinister(String ministerId) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.removeMinister(ministerId);
      await loadProvinces();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // ─── RESSOURCES ÉCONOMIQUES ───

  Future<void> addEconomicResource(ProvinceEconomicResource resource) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.addEconomicResource(resource);
      _ref.invalidate(provinceWithAllRelationsProvider(resource.provinceId));
      await loadProvinces();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deleteEconomicResource(String id) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.deleteEconomicResource(id);
      await loadProvinces();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // ─── BUDGET PRIORITIES ───

  Future<void> addBudgetPriority(ProvinceBudgetPriority budget) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.addBudgetPriority(budget);
      _ref.invalidate(provinceWithAllRelationsProvider(budget.provinceId));
      await loadProvinces();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deleteBudgetPriority(String id) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.deleteBudgetPriority(id);
      await loadProvinces();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // ─── TOURISME ───

  Future<void> addTourismSite(ProvinceTourism site) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.addTourismSite(site);
      _ref.invalidate(provinceWithAllRelationsProvider(site.provinceId));
      await loadProvinces();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deleteTourismSite(String id) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.deleteTourismSite(id);
      await loadProvinces();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // ─── URGENCES ───

  Future<void> addEmergencyContact(ProvinceEmergencyContact contact) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.addEmergencyContact(contact);
      _ref.invalidate(provinceWithAllRelationsProvider(contact.provinceId));
      await loadProvinces();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deleteEmergencyContact(String id) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.deleteEmergencyContact(id);
      await loadProvinces();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // ─── DÉCOUPAGE ADMINISTRATIF ───

  Future<void> addAdministrativeDivision(
      ProvinceAdministrativeDivision division) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.addAdministrativeDivision(division);
      _ref.invalidate(provinceWithAllRelationsProvider(division.provinceId));
      await loadProvinces();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deleteAdministrativeDivision(String id) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.deleteAdministrativeDivision(id);
      await loadProvinces();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // ─── VILLES ───

  Future<void> addCity(City city) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.addCity(city);
      _ref.invalidate(provinceWithAllRelationsProvider(city.provinceId));
      await loadProvinces();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deleteCity(String id) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.deleteCity(id);
      await loadProvinces();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // 🆕 CRUD NOUVELLES TABLES (page production)
  // ════════════════════════════════════════════════════════════════════════

  // ─── ACTUALITÉS ───

  Future<void> addNews(String provinceId, Map<String, dynamic> data) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.addNews({...data, 'province_id': provinceId});
      _ref.invalidate(provinceNewsProvider(provinceId));
      _ref.invalidate(provinceCountsProvider(provinceId));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updateNews(String id, Map<String, dynamic> data) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.updateNews(id, data);
      // Invalider tous les providers news (par sécurité)
      _ref.invalidate(provincesProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deleteNews(String id, String provinceId) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.deleteNews(id);
      _ref.invalidate(provinceNewsProvider(provinceId));
      _ref.invalidate(provinceCountsProvider(provinceId));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // ─── PROJETS ───

  Future<void> addProject(String provinceId, Map<String, dynamic> data) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.addProject({...data, 'province_id': provinceId});
      _ref.invalidate(provinceProjectsProvider(provinceId));
      _ref.invalidate(provinceCountsProvider(provinceId));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updateProject(String id, Map<String, dynamic> data) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.updateProject(id, data);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deleteProject(String id, String provinceId) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.deleteProject(id);
      _ref.invalidate(provinceProjectsProvider(provinceId));
      _ref.invalidate(provinceCountsProvider(provinceId));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // ─── SERVICES ───

  Future<void> addService(String provinceId, Map<String, dynamic> data) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.addService({...data, 'province_id': provinceId});
      _ref.invalidate(provinceServicesProvider(provinceId));
      _ref.invalidate(provinceCountsProvider(provinceId));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updateService(String id, Map<String, dynamic> data) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.updateService(id, data);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deleteService(String id, String provinceId) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.deleteService(id);
      _ref.invalidate(provinceServicesProvider(provinceId));
      _ref.invalidate(provinceCountsProvider(provinceId));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // ─── ENGAGEMENTS ───

  Future<void> addEngagement(String provinceId, Map<String, dynamic> data) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.addEngagement({...data, 'province_id': provinceId});
      _ref.invalidate(provinceEngagementsProvider(provinceId));
      _ref.invalidate(provinceCountsProvider(provinceId));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updateEngagement(String id, Map<String, dynamic> data) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.updateEngagement(id, data);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deleteEngagement(String id, String provinceId) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.deleteEngagement(id);
      _ref.invalidate(provinceEngagementsProvider(provinceId));
      _ref.invalidate(provinceCountsProvider(provinceId));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // ─── BUDGET (PIE CHART) ───

  Future<void> addBudgetItem(String provinceId, Map<String, dynamic> data) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.addBudgetItem({...data, 'province_id': provinceId});
      _ref.invalidate(provinceBudgetChartProvider(provinceId));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updateBudgetItem(String id, Map<String, dynamic> data) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.updateBudgetItem(id, data);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deleteBudgetItem(String id, String provinceId) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.deleteBudgetItem(id);
      _ref.invalidate(provinceBudgetChartProvider(provinceId));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // ─── DOCUMENTS ───

  Future<void> addDocument(String provinceId, Map<String, dynamic> data) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.addDocument({...data, 'province_id': provinceId});
      _ref.invalidate(provinceDocumentsProvider(provinceId));
      _ref.invalidate(provinceCountsProvider(provinceId));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updateDocument(String id, Map<String, dynamic> data) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.updateDocument(id, data);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deleteDocument(String id, String provinceId) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.deleteDocument(id);
      _ref.invalidate(provinceDocumentsProvider(provinceId));
      _ref.invalidate(provinceCountsProvider(provinceId));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // ─── MÉDIATHÈQUE ───

  Future<void> addMedia(String provinceId, Map<String, dynamic> data) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.addMedia({...data, 'province_id': provinceId});
      _ref.invalidate(provinceMediaProvider(provinceId));
      _ref.invalidate(provinceCountsProvider(provinceId));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updateMedia(String id, Map<String, dynamic> data) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.updateMedia(id, data);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deleteMedia(String id, String provinceId) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.deleteMedia(id);
      _ref.invalidate(provinceMediaProvider(provinceId));
      _ref.invalidate(provinceCountsProvider(provinceId));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // ─── HYMNE ───

  Future<void> saveHymn(String provinceId, Map<String, dynamic> data) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.saveHymn(provinceId, data);
      _ref.invalidate(provinceHymnProvider(provinceId));
      _ref.invalidate(provinceWithAllRelationsProvider(provinceId));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // ─── PERSONNALITÉS CÉLÈBRES ───

  Future<void> addFamousPerson(String provinceId, Map<String, dynamic> data) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.addFamousPerson({...data, 'province_id': provinceId});
      _ref.invalidate(provinceFamousPeopleProvider(provinceId));
      _ref.invalidate(provinceCountsProvider(provinceId));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updateFamousPerson(String id, Map<String, dynamic> data) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.updateFamousPerson(id, data);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deleteFamousPerson(String id, String provinceId) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.deleteFamousPerson(id);
      _ref.invalidate(provinceFamousPeopleProvider(provinceId));
      _ref.invalidate(provinceCountsProvider(provinceId));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // ─── GASTRONOMIE ───

  Future<void> addGastronomy(String provinceId, Map<String, dynamic> data) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.addGastronomy({...data, 'province_id': provinceId});
      _ref.invalidate(provinceGastronomyProvider(provinceId));
      _ref.invalidate(provinceCountsProvider(provinceId));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updateGastronomy(String id, Map<String, dynamic> data) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.updateGastronomy(id, data);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deleteGastronomy(String id, String provinceId) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.deleteGastronomy(id);
      _ref.invalidate(provinceGastronomyProvider(provinceId));
      _ref.invalidate(provinceCountsProvider(provinceId));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // ─── PROVERBES ───

  Future<void> addProverb(String provinceId, Map<String, dynamic> data) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.addProverb({...data, 'province_id': provinceId});
      _ref.invalidate(provinceProverbsProvider(provinceId));
      _ref.invalidate(provinceCountsProvider(provinceId));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updateProverb(String id, Map<String, dynamic> data) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.updateProverb(id, data);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deleteProverb(String id, String provinceId) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.deleteProverb(id);
      _ref.invalidate(provinceProverbsProvider(provinceId));
      _ref.invalidate(provinceCountsProvider(provinceId));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // ─── ENTREPRISES ───

  Future<void> addBusiness(String provinceId, Map<String, dynamic> data) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.addBusiness({...data, 'province_id': provinceId});
      _ref.invalidate(provinceBusinessesProvider(provinceId));
      _ref.invalidate(provinceCountsProvider(provinceId));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updateBusiness(String id, Map<String, dynamic> data) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.updateBusiness(id, data);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deleteBusiness(String id, String provinceId) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.deleteBusiness(id);
      _ref.invalidate(provinceBusinessesProvider(provinceId));
      _ref.invalidate(provinceCountsProvider(provinceId));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // ─── PRODUITS DU TERROIR ───

  Future<void> addProduct(String provinceId, Map<String, dynamic> data) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.addProduct({...data, 'province_id': provinceId});
      _ref.invalidate(provinceProductsProvider(provinceId));
      _ref.invalidate(provinceCountsProvider(provinceId));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updateProduct(String id, Map<String, dynamic> data) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.updateProduct(id, data);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deleteProduct(String id, String provinceId) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.deleteProduct(id);
      _ref.invalidate(provinceProductsProvider(provinceId));
      _ref.invalidate(provinceCountsProvider(provinceId));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // ─── QUIZ ───

  Future<void> addQuizQuestion(String provinceId, Map<String, dynamic> data) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.addQuizQuestion({...data, 'province_id': provinceId});
      _ref.invalidate(provinceQuizProvider(provinceId));
      _ref.invalidate(provinceCountsProvider(provinceId));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updateQuizQuestion(String id, Map<String, dynamic> data) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.updateQuizQuestion(id, data);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deleteQuizQuestion(String id, String provinceId) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.deleteQuizQuestion(id);
      _ref.invalidate(provinceQuizProvider(provinceId));
      _ref.invalidate(provinceCountsProvider(provinceId));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // ─── DÉMOGRAPHIE ───

  Future<void> addDemographicPoint(
      String provinceId, Map<String, dynamic> data) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.addDemographicPoint({...data, 'province_id': provinceId});
      _ref.invalidate(provinceDemographicsProvider(provinceId));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updateDemographicPoint(
      String id, Map<String, dynamic> data) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.updateDemographicPoint(id, data);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deleteDemographicPoint(String id, String provinceId) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      await service.deleteDemographicPoint(id);
      _ref.invalidate(provinceDemographicsProvider(provinceId));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // ─── SAUVEGARDE COMPLÈTE (legacy) ───

  Future<Province> saveProvinceWithRelations(Province province) async {
    try {
      final service = _ref.read(provincesServiceProvider);
      final saved = await service.saveProvinceWithRelations(province);
      _ref.invalidate(provincesProvider);
      _ref.invalidate(provinceWithAllRelationsProvider(saved.id));
      await loadProvinces();
      return saved;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

// ════════════════════════════════════════════════════════════════════════
// 11. CONVENIENCE : REFRESH GROUPÉ
// ════════════════════════════════════════════════════════════════════════

/// Rafraîchit tous les providers d'une province (utile après modification admin).
void refreshAllProvinceProviders(WidgetRef ref, String provinceId) {
  ref.invalidate(provinceWithAllRelationsProvider(provinceId));
  ref.invalidate(provinceNewsProvider(provinceId));
  ref.invalidate(provinceProjectsProvider(provinceId));
  ref.invalidate(provinceServicesProvider(provinceId));
  ref.invalidate(provinceEngagementsProvider(provinceId));
  ref.invalidate(provinceBudgetChartProvider(provinceId));
  ref.invalidate(provinceDocumentsProvider(provinceId));
  ref.invalidate(provinceMediaProvider(provinceId));
  ref.invalidate(provinceHymnProvider(provinceId));
  ref.invalidate(provinceFamousPeopleProvider(provinceId));
  ref.invalidate(provinceGastronomyProvider(provinceId));
  ref.invalidate(provinceProverbsProvider(provinceId));
  ref.invalidate(provinceBusinessesProvider(provinceId));
  ref.invalidate(provinceProductsProvider(provinceId));
  ref.invalidate(provinceQuizProvider(provinceId));
  ref.invalidate(provinceDemographicsProvider(provinceId));
  ref.invalidate(provinceCountsProvider(provinceId));
  ref.invalidate(provincesProvider);
}
