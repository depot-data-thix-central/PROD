// ════════════════════════════════════════════════════════════════════════════
//  THIX PORTFOLIO BUSINESS — COUCHE DATA (REPOSITORY)
//  Fichier  : lib/presentation/thix_portfolio/data/business_repository.dart
//  Module   : THIX Portfolio Business
//  Éditeur  : SONATHIX GROUP — Kinshasa, RDC
//  Version  : 1.0.0 — Novembre 2026
// ════════════════════════════════════════════════════════════════════════════
//
//  Seul point d'accès à Supabase pour tout le module portfolio business.
//
//  Principes clés :
//    • L'identifiant THIX est **toujours généré côté DB** via RPC
//      `generate_thix_biz_id` (atomicité + sécurité garanties).
//    • Création = appel unique `create_business` (transactionnel).
//    • Lecture publique = jointure 1 requête business + theme + sections.
//    • `trackView` est fire-and-forget (non bloquant, silencieux en erreur).
//    • Les exceptions Supabase sont converties en erreurs métier typées.
//
//  Prérequis :
//    1. Migration SQL 20261109_thix_portfolio_business.sql exécutée.
//    2. Un provider `supabaseClientProvider` existant dans ton projet
//       (déjà présent dans `lib/supabase/`).
//    3. `flutter_riverpod` + `supabase_flutter` dans le pubspec ✅.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/thix_business_id.dart';
import '../models/business_bundle.dart';
import '../models/business_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Erreurs métier (typées, traçables, localisables)
// ─────────────────────────────────────────────────────────────────────────────

@immutable
abstract class BusinessError implements Exception {
  const BusinessError(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() =>
      '$runtimeType: $message${cause == null ? '' : ' ($cause)'}';
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

  // ── SELECT business + theme + sections (jointure) ──────────────────────

  /// Charge un bundle complet par `thix_id`.
  ///
  /// Lance [BusinessNotFoundException] si l'entreprise n'existe pas ou
  /// n'est pas publiée. Lance [BusinessIdInvalidException] si l'ID
  /// fourni ne passe pas la validation offline ([ThixBusinessId.isValid]).
  Future<BusinessBundle> fetchPublicBundle(String thixId) async {
    if (!ThixBusinessId.isValid(thixId)) {
      throw const BusinessIdInvalidException('');
    }
    final normalized = ThixBusinessId.parse(thixId).raw;

    try {
      // Jointure 1 requête : business → theme (1:1) → sections (1:N)
      final row = await _db
          .from(_tableBusinesses)
          .select(
              '*, business_themes(*), business_sections(*)')
          .eq('thix_id', normalized)
          .eq('status', BusinessStatus.published.slug)
          .maybeSingle();

      if (row == null) throw BusinessNotFoundException(normalized);

      // Track de la vue (non bloquant)
      unawaited(trackView(normalized));

      return BusinessBundle.fromJson(row);
    } on BusinessNotFoundException {
      rethrow;
    } catch (e, s) {
      debugPrint('BusinessRepository.fetchPublicBundle erreur: $e\n$s');
      throw BusinessNotFoundException(normalized);
    }
  }

  /// Récupère le bundle pour l'**owner** (draft inclus).
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

  /// Liste des entreprises de l'utilisateur courant (studio / dashboard).
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

  // ── CREATE (génération ID côté DB) ─────────────────────────────────────

  /// Crée une entreprise. L'identifiant THIX est **entièrement généré
  /// côté serveur** par la fonction Postgres `create_business`.
  ///
  /// Retourne le [BusinessCreationResult] contenant l'ID généré.
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

      return BusinessCreationResult.fromJson(
          Map<String, dynamic>.from(response));
    } on PostgrestException catch (e) {
      throw BusinessCreationException(
          'Création impossible : ${e.message}', e);
    } catch (e) {
      throw BusinessCreationException(
          'Erreur inattendue lors de la création.', e);
    }
  }

  /// Expose directement la RPC de génération d'ID (utile pour prévisualiser
  /// un ID avant de finaliser la création — ex : démo studio).
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

  // ── UPDATE (business + theme + sections) ───────────────────────────────

  /// Met à jour les champs d'identité de l'entreprise.
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
      if (_isRlsAuthError(e)) {
        throw const BusinessNotAuthorizedException();
      }
      rethrow;
    }
  }

  /// Remplace le thème complet (upsert = insert si absent, update sinon).
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
      if (_isRlsAuthError(e)) {
        throw const BusinessNotAuthorizedException();
      }
      rethrow;
    }
  }

  /// Remplace toutes les sections d'une entreprise (transaction logique :
  /// on écrase la liste en une seule requête d'upsert sur (business_id,type)).
  Future<List<BusinessSection>> upsertSections({
    required String businessId,
    required List<BusinessSection> sections,
  }) async {
    final rows = sections
        .map((s) => {
              'id': s.id,
              'business_id': businessId,
              'type': s.type.slug,
              'position': s.position,
              'visible': s.visible,
              'content': s.content.toJson(),
              'updated_at': DateTime.now().toIso8601String(),
            })
        .toList(growable: false);

    try {
      final res = await _db
          .from(_tableSections)
          .upsert(rows, onConflict: 'business_id,type')
          .select();
      final list = res
          .map((e) =>
              BusinessSection.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => a.position.compareTo(b.position));
      return list;
    } on PostgrestException catch (e) {
      if (_isRlsAuthError(e)) {
        throw const BusinessNotAuthorizedException();
      }
      rethrow;
    }
  }

  // ── PUBLISH / UNPUBLISH ────────────────────────────────────────────────

  /// Publie le site. Refuse si aucun logo / cover / description / nom.
  Future<Business> publish(String businessId) async {
    final bundle = await fetchOwnerBundle(businessId);
    final b = bundle.business;
    if (b.name.trim().isEmpty) {
      throw const BusinessPublishException('Le nom est obligatoire.');
    }
    if ((b.description ?? '').trim().isEmpty) {
      throw const BusinessPublishException(
          'Ajoutez une description avant de publier.');
    }
    if (b.logoUrl == null || b.logoUrl!.isEmpty) {
      throw const BusinessPublishException(
          'Ajoutez un logo avant de publier.');
    }
    if (b.coverUrl == null || b.coverUrl!.isEmpty) {
      throw const BusinessPublishException(
          'Ajoutez une image de couverture avant de publier.');
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

  /// Passe en draft (le site reste accessible à l'owner seulement).
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

  // ── STATS ──────────────────────────────────────────────────────────────

  /// Enregistre une vue sur le site public (fire-and-forget).
  Future<void> trackView(String thixId) async {
    try {
      await _db.rpc('track_business_view', params: {'p_thix_id': thixId});
    } catch (e) {
      // Silencieux : une vue ratée ne doit pas casser l'UX.
      debugPrint('trackView ignoré: $e');
    }
  }

  /// Charge les stats agrégées (30 derniers jours + total) pour l'owner.
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
        (acc, r) => acc +
            BusinessStats.fromJson(Map<String, dynamic>.from(r)),
      );
    } catch (_) {
      return const BusinessStats();
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────

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

/// Provider du repository (singleton pour toute la durée de vie de l'app).
///
/// Dépend du provider `supabaseClientProvider` existant dans ton projet.
/// Si ton app l'expose différemment (ex: `supabaseProvider`), remplace.
final businessRepositoryProvider = Provider<BusinessRepository>((ref) {
  return BusinessRepository(Supabase.instance.client);
});

/// Provider du bundle public — mis en cache 5 min par thixId.
final businessPublicBundleProvider = FutureProvider.autoDispose
    .family<BusinessBundle, String>((ref, thixId) async {
  final repo = ref.watch(businessRepositoryProvider);
  ref.keepAlive();
  // TTL 5 min
  Future.delayed(const Duration(minutes: 5), ref.invalidateSelf);
  return repo.fetchPublicBundle(thixId);
});

/// Provider des entreprises de l'utilisateur courant.
final myBusinessesProvider =
    FutureProvider.autoDispose<List<Business>>((ref) async {
  return ref.watch(businessRepositoryProvider).listMine();
});

/// Provider du bundle d'une entreprise pour l'owner (par businessId).
final ownerBusinessBundleProvider = FutureProvider.autoDispose
    .family<BusinessBundle, String>((ref, businessId) async {
  return ref.watch(businessRepositoryProvider).fetchOwnerBundle(businessId);
});

/// Provider des stats d'une entreprise.
final businessStatsProvider = FutureProvider.autoDispose
    .family<BusinessStats, String>((ref, businessId) async {
  return ref.watch(businessRepositoryProvider).fetchStats(businessId);
});
