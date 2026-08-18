// lib/supabase/supabase_config.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SupabaseConfig {
  /// Supabase credentials.
  ///
  /// Utilise `--dart-define` pour les passer en production (recommandé).
  ///
  /// Les valeurs par défaut correspondent à votre nouveau projet Supabase.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://lldgnysfiabakhaibgzq.supabase.co',
  );

  /// Clé publique (anciennement "anon key"). Le nom de variable est conservé
  /// pour compatibilité avec le reste du code, mais elle est désormais passée
  /// au paramètre `publishableKey` de `Supabase.initialize`.
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxsZGdueXNmaWFiYWtoYWliZ3pxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI1NzgxNjcsImV4cCI6MjA5ODE1NDE2N30.AmrEd5RECLsamIjYiUBk_F4azYtBeMV3drL5RPzFhjo',
  );

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      if (supabaseUrl.trim().isEmpty || anonKey.trim().isEmpty) {
        throw Exception('Supabase URL ou Anon Key manquant !');
      }

      debugPrint('🔄 SupabaseConfig: Initialisation...');
      debugPrint('📡 URL: $supabaseUrl');

      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: anonKey,
        debug: kDebugMode,
      );

      _initialized = true;
      debugPrint('✅ Supabase initialisé avec succès');
    } catch (e) {
      debugPrint('❌ Échec de l\'initialisation Supabase: $e');
      rethrow;
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;
  static SupabaseStorageClient get storage => client.storage;

  /// Convenience: current authenticated user
  static User? get currentUser => auth.currentUser;

  /// Convenience: auth state changes
  static Stream<AuthState> get onAuthStateChange => auth.onAuthStateChange;
}

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
