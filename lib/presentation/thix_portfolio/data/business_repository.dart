// ════════════════════════════════════════════════════════════════════════════
//  THIX PORTFOLIO BUSINESS — COUCHE DATA (REPOSITORY)
//  Fichier  : lib/presentation/thix_portfolio/data/business_repository.dart
//  Module   : THIX Portfolio Business
//  Éditeur  : SONATHIX GROUP — Kinshasa, RDC
//  Version  : 1.2.0 — Novembre 2026
// ════════════════════════════════════════════════════════════════════════════
//
//  v1.2.0 : Ajout de `searchBusinessesByName` pour l'autocomplétion 
//           dans le header de recherche.
//  v1.1.0 : FIX upsertSections — les sections sans id (nouvelles) ne
//           envoient plus `id: ''` (uuid invalide). Postgres génère l'uuid.
//  v1.0.2 : import 'dart:async' pour unawaited()
//
//  Seul point d'accès à Supabase pour tout le module portfolio business.
// ════════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/thix_business_id.dart';
import '../models/business_bundle.dart';
import '../models/business_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Erreurs métier
// ─────────────────────────────────────────────────────────────────────────────

@immutable
abstract class BusinessError implements Exception {
  const BusinessError(this.message, [this.cause]);
  final String message;
  final Object? cause;
  @override
  String toString() => '$runtimeType: $message${cause == null ? '' : ' ($cause)'}';
}

class BusinessNotFoundException extends BusinessError {
  const BusinessNotFoundException(String thixId)
      : super('Entreprise introuvable ou non publiée pour l\'ID « $thixId »');
}

class BusinessIdInvalidException extends BusinessError {
  const BusinessIdInvalidException(String input)
      : super('L\'identifiant saisi « $input » n\'est pas un THIX ID Business valide.');
}

class BusinessCreationException extends BusinessError {
  const BusinessCreationException(super.message, [super.cause]);
}

class BusinessNotAuthorizedException extends BusinessError {
  const BusinessNotAuthorizedException()
      : super('Vous n\'êtes pas autorisé à modifier cette entreprise.');
}

class BusinessPublishException extends BusinessError {
  const BusinessPublishException(super.message);
}

// ─────────────────────────────────────────────────────────────────────────────
// Repository
// ─────────────────────────────────────────────────────────────────────────────

class BusinessRepository {
  BusinessRepository(this._db);
  final SupabaseClient _db;

  static const String _tableBusinesses = 'businesses';
  static const String _tableThemes = 'business_themes';
  static const String _tableSections = 'business_sections';
  static const String _tableStats = 'business_stats';

  // ── SELECT public ───────────────────────────────────────────────────

  Future<BusinessBundle> fetchPublicBundle(String thixId) async {
    if (!ThixBusinessId.isValid(thixId)) {
      throw BusinessIdInvalidException(thixId);
    }
    final normalized = ThixBusinessId.parse(thixId).raw;

    try {
      final row = await _db
          .from(_tableBusinesses)
          .select('*, business_themes(*), business_sections(*)')
          .eq('thix_id', normalized)
          .eq('status', BusinessStatus.published.slug)
          .maybeSingle();

      if (row == null) throw BusinessNotFoundException(normalized);

      unawaited(trackView(normalized));

      return BusinessBundle.fromJson(row);
    } on BusinessNotFoundException {
      rethrow;
    } catch (e, s) {
      debugPrint('BusinessRepository.fetchPublicBundle erreur: $e\n$s');
      throw BusinessNotFoundException(normalized);
    }
  }

  Future<BusinessBundle> fetchOwnerBundle(String businessId) async {
    try {
      final row = await _db
          .from(_tableBusinesses)
          .select('*, business_themes(*), business_sections(*)')
          .eq('id', businessId)
          .single();
      return BusinessBundle.fromJson(row);
    } catch (e) {
      throw BusinessNotFoundException(businessId);
    }
  }

  Future<List<Business>> listMine() async {
    final rows = await _db
        .from(_tableBusinesses)
        .select()
        .eq('owner_uid', _db.auth.currentUser?.id ?? '')
        .order('created_at', ascending: false);
    return rows
        .map((e) => Business.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  // ✅ NOUVEAU : RECHERCHE POUR L'AUTOCOMPLÉTION
  /// Recherche des entreprises par nom (uniquement les publiées).
  /// Utilisé par la barre de recherche du Header.
  Future<List<Map<String, dynamic>>> searchBusinessesByName(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    try {
      final response = await _db
          .from(_tableBusinesses)
          .select('thix_id, name, logo_url')
          .eq('status', BusinessStatus.published.slug)
          .ilike('name', '%$cleanQuery%') // Recherche insensible à la casse
          .limit(5); // Maximum 5 suggestions

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('searchBusinessesByName erreur: $e');
      return [];
    }
  }

  // ── CREATE (génération ID côté DB) ──────────────────────────────────

  Future<BusinessCreationResult> create({
    required String name,
    String? sector,
    String? city,
    String? country,
  }) async {
    if (name.trim().length < 2) {
      throw const BusinessCreationException(
          'Le nom de l\'entreprise doit contenir au moins 2 caractères.');
    }
    try {
      final response = await _db.rpc(
        'create_business',
        params: {
          'p_name': name.trim(),
          'p_sector': sector?.trim(),
          'p_city': city?.trim(),
          'p_country': (country ?? 'CD').trim(),
        },
      );
      if (response is! Map) {
        throw const BusinessCreationException(
            'Réponse inattendue du serveur lors de la création.');
      }
      return BusinessCreationResult.fromJson(Map<String, dynamic>.from(response));
    } on PostgrestException catch (e) {
      throw BusinessCreationException('Création impossible : ${e.message}', e);
    } catch (e) {
      throw BusinessCreationException('Erreur inattendue lors de la création.', e);
    }
  }

  Future<ThixBusinessId> previewNextId() async {
    final response = await _db.rpc('generate_thix_biz_id');
    final raw = (response as String).trim();
    final parsed = ThixBusinessId.tryParse(raw);
    if (parsed == null) {
      throw const BusinessCreationException(
          'Le serveur a renvoyé un identifiant invalide.');
    }
    return parsed;
  }

  // ── UPDATE ──────────────────────────────────────────────────────────

  Future<Business> updateBusiness({
    required String businessId,
    required Business business,
  }) async {
    try {
      final row = await _db
          .from(_tableBusinesses)
          .update({
            'name': business.name,
            'claim': business.claim,
            'description': business.description,
            'sector': business.sector,
            'city': business.city,
            'country': business.country,
            'since_year': business.sinceYear,
            'employees': business.employees,
            'website': business.website,
            'phone': business.phone,
            'email': business.email,
            'logo_url': business.logoUrl,
            'cover_url': business.coverUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', businessId)
          .select()
          .single();
      return Business.fromJson(Map<String, dynamic>.from(row));
    } on PostgrestException catch (e) {
      if (_isRlsAuthError(e)) throw const BusinessNotAuthorizedException();
      rethrow;
    }
  }

  Future<BusinessTheme> upsertTheme({
    required String businessId,
    required BusinessTheme theme,
  }) async {
    final validated = theme.validate();
    final row = {
      'business_id': businessId,
      ...validated.toJson()..remove('updated_at'),
      'updated_at': DateTime.now().toIso8601String(),
    };
    try {
      final res = await _db
          .from(_tableThemes)
          .upsert(row, onConflict: 'business_id')
          .select()
          .single();
      return BusinessTheme.fromJson(Map<String, dynamic>.from(res));
    } on PostgrestException catch (e) {
      if (_isRlsAuthError(e)) throw const BusinessNotAuthorizedException();
      rethrow;
    }
  }

  /// ✅ v1.1.0 : gère les sections NOUVELLES (id vide) et EXISTANTES.
  /// - id vide  → la clé `id` n'est pas envoyée, Postgres génère l'uuid.
  /// - id rempli → conservé tel quel.
  /// Les deux groupes sont envoyés séparément pour éviter `id = null`.
  Future<List<BusinessSection>> upsertSections({
    required String businessId,
    required List<BusinessSection> sections,
  }) async {
    final now = DateTime.now().toIso8601String();

    Map<String, dynamic> toRow(BusinessSection s) {
      final hasId = s.id.trim().isNotEmpty;
      return {
        if (hasId) 'id': s.id,
        'business_id': businessId,
        'type': s.type.slug,
        'position': s.position,
        'visible': s.visible,
        'content': s.content.toJson(),
        'updated_at': now,
      };
    }

    final withId = <Map<String, dynamic>>[];
    final withoutId = <Map<String, dynamic>>[];
    for (final s in sections) {
      (s.id.trim().isNotEmpty ? withId : withoutId).add(toRow(s));
    }

    try {
      if (withId.isNotEmpty) {
        await _db
            .from(_tableSections)
            .upsert(withId, onConflict: 'business_id,type');
      }
      if (withoutId.isNotEmpty) {
        await _db
            .from(_tableSections)
            .upsert(withoutId, onConflict: 'business_id,type');
      }

      // Relecture complète : renvoie toujours la liste à jour, avec les ids.
      final res = await _db
          .from(_tableSections)
          .select()
          .eq('business_id', businessId)
          .order('position', ascending: true);
      final list = res
          .map((e) => BusinessSection.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => a.position.compareTo(b.position));
      return list;
    } on PostgrestException catch (e) {
      debugPrint('upsertSections erreur: ${e.code} ${e.message}');
      if (_isRlsAuthError(e)) throw const BusinessNotAuthorizedException();
      rethrow;
    }
  }

  // ── PUBLISH / UNPUBLISH ─────────────────────────────────────────────

  Future<Business> publish(String businessId) async {
    final bundle = await fetchOwnerBundle(businessId);
    final b = bundle.business;
    if (b.name.trim().isEmpty) {
      throw const BusinessPublishException('Le nom est obligatoire.');
    }
    if ((b.description ?? '').trim().isEmpty) {
      throw const BusinessPublishException('Ajoutez une description avant de publier.');
    }
    if (b.logoUrl == null || b.logoUrl!.isEmpty) {
      throw const BusinessPublishException('Ajoutez un logo avant de publier.');
    }
    if (b.coverUrl == null || b.coverUrl!.isEmpty) {
      throw const BusinessPublishException('Ajoutez une image de couverture avant de publier.');
    }
    final now = DateTime.now();
    final row = await _db
        .from(_tableBusinesses)
        .update({
          'status': BusinessStatus.published.slug,
          'published_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        })
        .eq('id', businessId)
        .select()
        .single();
    return Business.fromJson(Map<String, dynamic>.from(row));
  }

  Future<Business> unpublish(String businessId) async {
    final row = await _db
        .from(_tableBusinesses)
        .update({
          'status': BusinessStatus.draft.slug,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', businessId)
        .select()
        .single();
    return Business.fromJson(Map<String, dynamic>.from(row));
  }

  // ── STATS ───────────────────────────────────────────────────────────

  Future<void> trackView(String thixId) async {
    try {
      await _db.rpc('track_business_view', params: {'p_thix_id': thixId});
    } catch (e) {
      debugPrint('trackView ignoré: $e');
    }
  }

  Future<BusinessStats> fetchStats(String businessId) async {
    try {
      final rows = await _db
          .from(_tableStats)
          .select()
          .eq('business_id', businessId)
          .gte(
            'day',
            DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
          );
      return rows.fold<BusinessStats>(
        const BusinessStats(),
        (acc, r) => acc + BusinessStats.fromJson(Map<String, dynamic>.from(r)),
      );
    } catch (_) {
      return const BusinessStats();
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  bool _isRlsAuthError(PostgrestException e) {
    final code = e.code?.toLowerCase() ?? '';
    final msg = e.message.toLowerCase();
    return code == '42501' ||
        code == 'pgrst301' ||
        msg.contains('row-level security') ||
        msg.contains('new row violates');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers Riverpod
// ─────────────────────────────────────────────────────────────────────────────

final businessRepositoryProvider = Provider<BusinessRepository>((ref) {
  return BusinessRepository(Supabase.instance.client);
});

final businessPublicBundleProvider = FutureProvider.autoDispose
    .family<BusinessBundle, String>((ref, thixId) async {
  final repo = ref.watch(businessRepositoryProvider);
  ref.keepAlive();
  Future.delayed(const Duration(minutes: 5), ref.invalidateSelf);
  return repo.fetchPublicBundle(thixId);
});

final myBusinessesProvider =
    FutureProvider.autoDispose<List<Business>>((ref) async {
  return ref.watch(businessRepositoryProvider).listMine();
});

final ownerBusinessBundleProvider = FutureProvider.autoDispose
    .family<BusinessBundle, String>((ref, businessId) async {
  return ref.watch(businessRepositoryProvider).fetchOwnerBundle(businessId);
});

final businessStatsProvider = FutureProvider.autoDispose
    .family<BusinessStats, String>((ref, businessId) async {
  return ref.watch(businessRepositoryProvider).fetchStats(businessId);
});
