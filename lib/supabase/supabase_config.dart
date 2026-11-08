// lib/supabase/supabase_config.dart
//
// v2 :
//  ✅ FIX OFFLINE — expose `isInitialized` pour le router (redirect)
//  ✅ FIX OFFLINE — retry-safe : attrape "already initialized" et considère OK
//  ✅ FIX OFFLINE — `resetForRetry()` pour pouvoir retenter après un échec réseau
//                   sans que le flag interne de Supabase ne bloque.
//
// v1 : version originale (credentials depuis env, SupabaseService CRUD).

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SupabaseConfig {
  /// Supabase credentials.
  /// Récupérées depuis l'environnement au moment du build ou de l'exécution.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  /// Clé publique (publishable/anon key).
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool _initialized = false;
  // ✅ NOUVEAU : indique qu'une tentative précédente a échoué (pour log/debug)
  static bool _lastAttemptFailed = false;

  // ============================================================================
  // PUBLIC STATE
  // ============================================================================

  /// ✅ NOUVEAU — `true` si Supabase a été initialisé avec succès au moins une fois.
  /// Utilisé par le router pour distinguer :
  ///   - app jamais initialisée → écran "pas de connexion"
  ///   - app initialisée mais offline → snapshot Hive
  ///   - app initialisée + en ligne → navigation normale
  static bool get isInitialized => _initialized;

  /// ✅ NOUVEAU — vrai si la dernière tentative d'initialisation a échoué
  /// (utile pour l'UI / le retry automatique).
  static bool get lastAttemptFailed => _lastAttemptFailed;

  // ============================================================================
  // INITIALISATION (retry-safe)
  // ============================================================================

  /// Initialise Supabase. Peut être appelé plusieurs fois :
  ///   - Si déjà initialisé avec succès → retour immédiat
  ///   - Si Supabase a été initialisé par un autre chemin (par ex. en parallèle)
  ///     et que `Supabase.initialize()` lève "already initialized" → considéré OK
  ///   - Sinon → tente l'initialisation
  static Future<void> initialize() async {
    if (_initialized) {
      debugPrint('[SupabaseConfig] ℹ️ already initialized, skip');
      return;
    }

    // ✅ Garde-fou : si quelqu'un d'autre a déjà initialisé Supabase
    // (ex: un listener parallèle, un hot reload), on détecte via Supabase.instance.
    // Dans supabase_flutter, `Supabase.instance` existe dès que l'initialisation
    // a réussi au moins une fois.
    try {
      final existingClient = Supabase.instance.client;
      if (existingClient != null) {
        _initialized = true;
        _lastAttemptFailed = false;
        debugPrint('[SupabaseConfig] ✅ Supabase already initialized '
            '(detected via instance), marking as ready');
        return;
      }
    } catch (e) {
      // Supabase.instance lève si jamais initialisé → c'est normal, on continue
      debugPrint('[SupabaseConfig] ℹ️ Supabase.instance not yet available '
          '($e), proceeding with initialize()');
    }

    if (supabaseUrl.trim().isEmpty || anonKey.trim().isEmpty) {
      final err = Exception(
        'Supabase URL ou Anon Key manquant ! '
        'Assurez-vous de passer les variables d\'environnement.',
      );
      debugPrint('❌ [SupabaseConfig] $err');
      _lastAttemptFailed = true;
      throw err;
    }

    debugPrint('[SupabaseConfig] 🔄 Initializing...');
    debugPrint('[SupabaseConfig] 📡 URL: $supabaseUrl');

    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: anonKey,
        debug: kDebugMode,
      );

      _initialized = true;
      _lastAttemptFailed = false;
      debugPrint('[SupabaseConfig] ✅ Supabase initialisé avec succès');
    } on Exception catch (e) {
      final msg = e.toString().toLowerCase();
      // ✅ FIX : si déjà initialisé par un chemin parallèle, considérer comme OK
      if (msg.contains('already initialized') ||
          msg.contains('already been initialized')) {
        _initialized = true;
        _lastAttemptFailed = false;
        debugPrint('[SupabaseConfig] ✅ Supabase already initialized '
            '(race handled), marking as ready');
        return;
      }

      _lastAttemptFailed = true;
      debugPrint('[SupabaseConfig] ❌ Échec initialisation: $e');
      rethrow;
    }
  }

  /// ✅ NOUVEAU — Force la prochaine tentative à refaire `Supabase.initialize()`.
  /// Utile si tu veux relancer depuis zéro (ex: après un reset de l'app).
  /// Attention : à utiliser avec parcimonie, `Supabase.initialize()`
  /// ne supporte pas plusieurs vrais appels en principe.
  static void resetForRetry() {
    _initialized = false;
    _lastAttemptFailed = false;
    debugPrint('[SupabaseConfig] 🔄 Reset for retry');
  }

  // ============================================================================
  // ACCESSORS
  // ============================================================================

  /// ⚠️ Lève si `isInitialized == false`. Vérifie toujours avant.
  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;
  static SupabaseStorageClient get storage => client.storage;

  /// Convenience: current authenticated user (null si pas de session)
  static User? get currentUser {
    if (!_initialized) return null;
    try {
      return auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Convenience: auth state changes
  static Stream<AuthState> get onAuthStateChange => auth.onAuthStateChange;
}

// ============================================================================
// GENERIC DATABASE SERVICE (inchangé)
// ============================================================================
/// Generic database service for CRUD operations
class SupabaseService {
  /// Select multiple records from a table
  static Future<List<Map<String, dynamic>>> select(
    String table, {
    String? select,
    Map<String, dynamic>? filters,
    String? orderBy,
    bool ascending = true,
    int? limit,
  }) async {
    try {
      dynamic query = SupabaseConfig.client.from(table).select(select ?? '*');

      if (filters != null) {
        for (final entry in filters.entries) {
          query = query.eq(entry.key, entry.value);
        }
      }

      if (orderBy != null) {
        query = query.order(orderBy, ascending: ascending);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      final res = await query;
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      throw _handleDatabaseError('select', table, e);
    }
  }

  /// Select a single record
  static Future<Map<String, dynamic>?> selectSingle(
    String table, {
    String? select,
    required Map<String, dynamic> filters,
  }) async {
    try {
      dynamic query = SupabaseConfig.client.from(table).select(select ?? '*');

      for (final entry in filters.entries) {
        query = query.eq(entry.key, entry.value);
      }

      return await query.maybeSingle();
    } catch (e) {
      throw _handleDatabaseError('selectSingle', table, e);
    }
  }

  /// Insert a record
  static Future<List<Map<String, dynamic>>> insert(
    String table,
    Map<String, dynamic> data,
  ) async {
    try {
      final res = await SupabaseConfig.client.from(table).insert(data).select();
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      throw _handleDatabaseError('insert', table, e);
    }
  }

  /// Insert multiple records
  static Future<List<Map<String, dynamic>>> insertMultiple(
    String table,
    List<Map<String, dynamic>> data,
  ) async {
    try {
      final res = await SupabaseConfig.client.from(table).insert(data).select();
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      throw _handleDatabaseError('insertMultiple', table, e);
    }
  }

  /// Update records
  static Future<List<Map<String, dynamic>>> update(
    String table,
    Map<String, dynamic> data, {
    required Map<String, dynamic> filters,
  }) async {
    try {
      var query = SupabaseConfig.client.from(table).update(data);

      for (final entry in filters.entries) {
        query = query.eq(entry.key, entry.value);
      }

      final res = await query.select();
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      throw _handleDatabaseError('update', table, e);
    }
  }

  /// Delete records
  static Future<void> delete(
    String table, {
    required Map<String, dynamic> filters,
  }) async {
    try {
      var query = SupabaseConfig.client.from(table).delete();

      for (final entry in filters.entries) {
        query = query.eq(entry.key, entry.value);
      }

      await query;
    } catch (e) {
      throw _handleDatabaseError('delete', table, e);
    }
  }

  /// Get direct table reference for complex queries
  static SupabaseQueryBuilder from(String table) =>
      SupabaseConfig.client.from(table);

  /// Handle database errors
  static Exception _handleDatabaseError(
    String operation,
    String table,
    dynamic error,
  ) {
    if (error is PostgrestException) {
      return Exception('Failed to $operation on $table: ${error.message}');
    }
    return Exception('Failed to $operation on $table: ${error.toString()}');
  }
}
