import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Best-effort Supabase write helpers that gracefully handle schema mismatches.
///
/// When PostgREST receives an unknown column, it throws `PGRST204`:
/// "Could not find the '<col>' column of '<table>' in the schema cache".
///
/// In Dreamflow projects, database schema can evolve independently of the app.
/// These helpers retry by removing unknown columns from the payload instead of
/// hard-failing the whole flow (e.g., signup blocked at step 1).
class SupabaseSafeWrite {
  SupabaseSafeWrite._();

  static final RegExp _unknownColumnRegex = RegExp(r"Could not find the '([^']+)' column");
  static final RegExp _unknownColumnDoesNotExistRegex = RegExp(r"column\s+[a-zA-Z0-9_]+\.([a-zA-Z0-9_]+)\s+does not exist");

  static String? _extractUnknownColumn(PostgrestException e) {
    final msg = e.message;
    final m = _unknownColumnRegex.firstMatch(msg);
    if (m != null) return m.group(1);

    // Postgres error (example): {"code":"42703",...,"message":"column profiles.country_or_origin does not exist"}
    final m2 = _unknownColumnDoesNotExistRegex.firstMatch(msg);
    if (m2 != null) return m2.group(1);

    return null;
  }

  static bool _isUnknownColumn(PostgrestException e) {
    if (e.code == 'PGRST204') return true;
    // Postgres undefined_column.
    if (e.code == '42703') return true;
    final msg = e.message;
    if (msg.contains("Could not find the '")) return true;
    if (msg.toLowerCase().contains('does not exist') && msg.toLowerCase().contains('column ')) return true;
    return false;
  }

  /// Upserts [payload] into [table].
  ///
  /// If Supabase rejects a column due to schema cache, we remove it and retry.
  static Future<void> upsert({
    required SupabaseClient client,
    required String table,
    required Map<String, dynamic> payload,
    String? onConflict,
    // In real projects, the app payload can contain many fields while the
    // Supabase table lags behind. We therefore allow more retries than the
    // typical 5-6 so we can progressively strip multiple unknown columns.
    //
    // Note: each retry removes at most ONE column.
    int maxRetries = 24,
    Future<void> Function()? onUnknownColumn,
  }) async {
    final data = Map<String, dynamic>.from(payload);
    var reloaded = false;
    // Each retry removes at most one column, so callers should provide a
    // sufficiently large [maxRetries]. We intentionally do NOT clamp here:
    // schema drift can be large and clamping can cause premature failure.
    final int effectiveMaxRetries = maxRetries;
    for (var attempt = 0; attempt <= effectiveMaxRetries; attempt++) {
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

        if (!_isUnknownColumn(e) || attempt == effectiveMaxRetries) {
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
        if (!data.containsKey(col)) {
          // The payload might be using a different alias than the DB column.
          // In that case, retrying won't help; fail fast with context.
          debugPrint('SupabaseSafeWrite.upsert: unknown column "$col" not in payload keys=${data.keys.toList()} table=$table');
          debugPrint('$st');
          rethrow;
        }
        data.remove(col);
        debugPrint('SupabaseSafeWrite.upsert: removed unknown column "$col" and retrying. table=$table');
      }
    }
  }

  /// Updates rows matching [filters] with [patch].
  ///
  /// Same retry logic as [upsert] for unknown columns.
  static Future<void> update({
    required SupabaseClient client,
    required String table,
    required Map<String, dynamic> patch,
    required Map<String, dynamic> filters,
    int maxRetries = 24,
    Future<void> Function()? onUnknownColumn,
  }) async {
    final data = Map<String, dynamic>.from(patch);
    var reloaded = false;
    final int effectiveMaxRetries = maxRetries;
    for (var attempt = 0; attempt <= effectiveMaxRetries; attempt++) {
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

        if (!_isUnknownColumn(e) || attempt == effectiveMaxRetries) {
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
        if (!data.containsKey(col)) {
          debugPrint('SupabaseSafeWrite.update: unknown column "$col" not in payload keys=${data.keys.toList()} table=$table');
          debugPrint('$st');
          rethrow;
        }
        data.remove(col);
        debugPrint('SupabaseSafeWrite.update: removed unknown column "$col" and retrying. table=$table');
      }
    }
  }

  /// Inserts many rows into [table] with schema-drift tolerance.
  ///
  /// If PostgREST rejects an unknown column, we remove it from **all rows** and
  /// retry. This is useful for linked tables (formations/experiences) where the
  /// schema may evolve and some columns might not exist yet.
  static Future<void> insertMany({
    required SupabaseClient client,
    required String table,
    required List<Map<String, dynamic>> rows,
    int maxRetries = 24,
    Future<void> Function()? onUnknownColumn,
  }) async {
    if (rows.isEmpty) return;
    final data = rows.map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
    var reloaded = false;
    final int effectiveMaxRetries = maxRetries;

    // We keep a mutable set of removed columns to avoid redundant work.
    final removed = <String>{};

    for (var attempt = 0; attempt <= effectiveMaxRetries; attempt++) {
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

        if (!_isUnknownColumn(e) || attempt == effectiveMaxRetries) {
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
        removed.add(col);
        // Remove from all rows then retry.
        for (final r in data) {
          r.remove(col);
        }
        debugPrint('SupabaseSafeWrite.insertMany: removed unknown column "$col" from all rows and retrying. table=$table');
      }
    }
  }
}
