import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase write helpers with schema-drift tolerance.
///
/// When PostgREST receives an unknown column, it throws `PGRST204`:
/// "Could not find the '<col>' column of '<table>' in the schema cache".
///
/// These helpers retry by removing unknown columns from the payload.
/// 
/// ⚠️ IMPORTANT : Columns marked as [criticalColumns] will cause an immediate
/// failure if they don't exist in the schema. Never remove critical columns
/// silently as this can lead to data inconsistencies.
class SupabaseSafeWrite {
  SupabaseSafeWrite._();

  static final RegExp _unknownColumnRegex = RegExp(r"Could not find the '([^']+)' column");
  static final RegExp _unknownColumnDoesNotExistRegex = RegExp(r"column\s+[a-zA-Z0-9_]+\.([a-zA-Z0-9_]+)\s+does not exist");

  static String? _extractUnknownColumn(PostgrestException e) {
    final msg = e.message;
    final m = _unknownColumnRegex.firstMatch(msg);
    if (m != null) return m.group(1);

    final m2 = _unknownColumnDoesNotExistRegex.firstMatch(msg);
    if (m2 != null) return m2.group(1);

    return null;
  }

  static bool _isUnknownColumn(PostgrestException e) {
    if (e.code == 'PGRST204') return true;
    if (e.code == '42703') return true;
    final msg = e.message;
    if (msg.contains("Could not find the '")) return true;
    if (msg.toLowerCase().contains('does not exist') && msg.toLowerCase().contains('column ')) return true;
    return false;
  }

  /// Upserts [payload] into [table].
  ///
  /// If Supabase rejects a column due to schema cache, we remove it and retry.
  /// 
  /// [criticalColumns] are columns that MUST exist in the schema. If any of them
  /// is unknown, the operation fails immediately instead of silently removing it.
  /// Example: ['thix_id', 'registration_status', 'account_status']
  static Future<void> upsert({
    required SupabaseClient client,
    required String table,
    required Map<String, dynamic> payload,
    String? onConflict,
    int maxRetries = 6, // ⭐ Réduit de 24 à 6 pour production
    List<String> criticalColumns = const [], // ⭐ NOUVEAU
    Future<void> Function()? onUnknownColumn,
  }) async {
    final data = Map<String, dynamic>.from(payload);
    var reloaded = false;
    
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        await client.from(table).upsert(data, onConflict: onConflict);
        return;
      } on PostgrestException catch (e, st) {
        if (_isUnknownColumn(e) && !reloaded && onUnknownColumn != null) {
          reloaded = true;
          try {
            await onUnknownColumn();
            continue;
          } catch (reloadErr) {
            debugPrint('SupabaseSafeWrite.upsert schema-reload failed err=$reloadErr');
          }
        }

        if (!_isUnknownColumn(e) || attempt == maxRetries) {
          debugPrint('SupabaseSafeWrite.upsert failed table=$table payloadKeys=${data.keys.toList()} err=${e.message}');
          debugPrint('$st');
          rethrow;
        }
        
        final col = _extractUnknownColumn(e);
        if (col == null) {
          debugPrint('SupabaseSafeWrite.upsert: unknown column but could not extract name. table=$table err=${e.message}');
          debugPrint('$st');
          rethrow;
        }
        
        // ⭐ NOUVEAU : Fail-fast pour les colonnes critiques
        if (criticalColumns.contains(col)) {
          final errorMsg = 'CRITICAL: Column "$col" is marked as critical but does not exist in schema. '
              'This indicates a missing migration. table=$table';
          debugPrint(errorMsg);
          debugPrint('$st');
          throw Exception(errorMsg);
        }
        
        if (!data.containsKey(col)) {
          debugPrint('SupabaseSafeWrite.upsert: unknown column "$col" not in payload keys=${data.keys.toList()} table=$table');
          debugPrint('$st');
          rethrow;
        }
        
        data.remove(col);
        // ⭐ AMÉLIORÉ : Log WARNING au lieu de debugPrint
        if (kDebugMode) {
          print('⚠️ WARNING: SupabaseSafeWrite.upsert removed unknown column "$col" from payload. '
              'This may indicate a missing migration. table=$table');
        }
      }
    }
  }

  /// Updates rows matching [filters] with [patch].
  static Future<void> update({
    required SupabaseClient client,
    required String table,
    required Map<String, dynamic> patch,
    required Map<String, dynamic> filters,
    int maxRetries = 6,
    List<String> criticalColumns = const [],
    Future<void> Function()? onUnknownColumn,
  }) async {
    final data = Map<String, dynamic>.from(patch);
    var reloaded = false;
    
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        var q = client.from(table).update(data);
        filters.forEach((k, v) => q = q.eq(k, v));
        await q;
        return;
      } on PostgrestException catch (e, st) {
        if (_isUnknownColumn(e) && !reloaded && onUnknownColumn != null) {
          reloaded = true;
          try {
            await onUnknownColumn();
            continue;
          } catch (reloadErr) {
            debugPrint('SupabaseSafeWrite.update schema-reload failed err=$reloadErr');
          }
        }

        if (!_isUnknownColumn(e) || attempt == maxRetries) {
          debugPrint('SupabaseSafeWrite.update failed table=$table filters=$filters payloadKeys=${data.keys.toList()} err=${e.message}');
          debugPrint('$st');
          rethrow;
        }
        
        final col = _extractUnknownColumn(e);
        if (col == null) {
          debugPrint('SupabaseSafeWrite.update: unknown column but could not extract name. table=$table err=${e.message}');
          debugPrint('$st');
          rethrow;
        }
        
        if (criticalColumns.contains(col)) {
          final errorMsg = 'CRITICAL: Column "$col" is marked as critical but does not exist in schema. table=$table';
          debugPrint(errorMsg);
          debugPrint('$st');
          throw Exception(errorMsg);
        }
        
        if (!data.containsKey(col)) {
          debugPrint('SupabaseSafeWrite.update: unknown column "$col" not in payload keys=${data.keys.toList()} table=$table');
          debugPrint('$st');
          rethrow;
        }
        
        data.remove(col);
        if (kDebugMode) {
          print('⚠️ WARNING: SupabaseSafeWrite.update removed unknown column "$col" from payload. table=$table');
        }
      }
    }
  }

  /// Inserts many rows into [table] with schema-drift tolerance.
  static Future<void> insertMany({
    required SupabaseClient client,
    required String table,
    required List<Map<String, dynamic>> rows,
    int maxRetries = 6,
    List<String> criticalColumns = const [],
    Future<void> Function()? onUnknownColumn,
  }) async {
    if (rows.isEmpty) return;
    final data = rows.map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
    var reloaded = false;
    final removed = <String>{};

    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        await client.from(table).insert(data);
        return;
      } on PostgrestException catch (e, st) {
        if (_isUnknownColumn(e) && !reloaded && onUnknownColumn != null) {
          reloaded = true;
          try {
            await onUnknownColumn();
            continue;
          } catch (reloadErr) {
            debugPrint('SupabaseSafeWrite.insertMany schema-reload failed err=$reloadErr');
          }
        }

        if (!_isUnknownColumn(e) || attempt == maxRetries) {
          debugPrint('SupabaseSafeWrite.insertMany failed table=$table rows=${data.length} removed=$removed err=${e.message}');
          debugPrint('$st');
          rethrow;
        }

        final col = _extractUnknownColumn(e);
        if (col == null) {
          debugPrint('SupabaseSafeWrite.insertMany: unknown column but could not extract name. table=$table err=${e.message}');
          debugPrint('$st');
          rethrow;
        }
        
        if (criticalColumns.contains(col)) {
          final errorMsg = 'CRITICAL: Column "$col" is marked as critical but does not exist in schema. table=$table';
          debugPrint(errorMsg);
          debugPrint('$st');
          throw Exception(errorMsg);
        }
        
        removed.add(col);
        for (final r in data) {
          r.remove(col);
        }
        if (kDebugMode) {
          print('⚠️ WARNING: SupabaseSafeWrite.insertMany removed unknown column "$col" from all rows. table=$table');
        }
      }
    }
  }
}
