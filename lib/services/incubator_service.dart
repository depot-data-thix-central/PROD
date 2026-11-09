// ============================================================================
// FICHIER : lib/services/incubator_service.dart
// Module  : thix_incubator
// ============================================================================
// Service Incubator — CRUD Supabase + cache offline + streams real-time.
// Pattern identique à OpportunityService : fallback SharedPreferences si
// le réseau tombe.
//
// Sécurité :
//   - ID validés (longueur, regex safe)
//   - timeout sur les requêtes
//   - sanitization des inputs (trim + strip C0/C1 controls)
//   - RLS Supabase fait le filtre côté serveur (owner_thix_id = auth.uid())
// ============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/incubator_activity.dart';
import '../models/incubator_application.dart';
import '../models/incubator_mentor.dart';
import '../models/incubator_program.dart';
import '../models/incubator_project.dart';

class IncubatorService {
  IncubatorService._();
  static final IncubatorService instance = IncubatorService._();

  // ─── TABLES ───
  static const String _tPrograms     = 'thix_incubator_programs';
  static const String _tProjects     = 'thix_incubator_projects';
  static const String _tApplications = 'thix_incubator_applications';
  static const String _tMentors      = 'thix_incubator_mentors';
  static const String _tActivities   = 'thix_incubator_activities';

  // ─── CACHE KEYS ───
  static const String _kCachePrograms     = 'incubator:programs:v1';
  static const String _kCacheProjects     = 'incubator:projects:v1';
  static const String _kCacheApplications = 'incubator:applications:v1';
  static const String _kCacheMentors      = 'incubator:mentors:v1';
  static const String _kCacheActivities   = 'incubator:activities:v1';

  static const Duration _timeout = Duration(seconds: 12);

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS SUPABASE (accès direct au client)
  // ─────────────────────────────────────────────────────────────────────────
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<Map<String, dynamic>>> _select(
    String table, {
    String select = '*',
    String? orderBy,
    bool ascending = true,
    int? limit,
  }) async {
    var q = _client.from(table).select(select);
    if (orderBy != null) q = q.order(orderBy, ascending: ascending);
    if (limit != null) q = q.limit(limit);
    final res = await q;
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> _selectWhere(
    String table,
    String column,
    Object value, {
    String select = '*',
    String? orderBy,
    bool ascending = true,
    int? limit,
  }) async {
    var q = _client.from(table).select(select).eq(column, value);
    if (orderBy != null) q = q.order(orderBy, ascending: ascending);
    if (limit != null) q = q.limit(limit);
    final res = await q;
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<void> _insert(String table, Map<String, dynamic> data) async {
    await _client.from(table).insert(data);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // VALIDATION HELPERS
  // ─────────────────────────────────────────────────────────────────────────
  static bool _isValidId(String id) =>
      id.isNotEmpty &&
      id.length <= 128 &&
      RegExp(r'^[A-Za-z0-9_\-]+$').hasMatch(id);

  static String _sanitize(String s) =>
      s.replaceAll(RegExp(r'[\p{C}]', unicode: true), '').trim();

  static String _generateId(String prefix) {
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    // ✅ Opération 100% entière — aucun cast double → int
    final r = (DateTime.now().millisecond ^
            (DateTime.now().microsecond * 0x1000000 ~/ 1000000))
        .toRadixString(36);
    return '${prefix}_$ts$r';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PROGRAMS
  // ─────────────────────────────────────────────────────────────────────────
  Future<List<IncubatorProgram>> listPrograms({
    bool forceRefresh = false,
  }) async {
    try {
      final res = await _select(
        _tPrograms,
        select: '*',
        orderBy: 'created_at',
        ascending: false,
        limit: 200,
      ).timeout(_timeout);

      // Filtrage client (safety si RLS fuit) : on exclut draft/archived
      final filtered = res.where((row) {
        final status = (row['status'] ?? 'open').toString();
        return status == 'open' ||
            status == 'upcoming' ||
            status == 'closed';
      }).toList();

      final programs =
          filtered.map((r) => IncubatorProgram.fromJson(r)).toList();
      await _cacheWrite(_kCachePrograms, IncubatorProgram.encodeList(programs));
      return programs;
    } on TimeoutException {
      debugPrint('IncubatorService.listPrograms timeout');
      return _cacheReadList<IncubatorProgram>(
          _kCachePrograms, IncubatorProgram.decodeList);
    } catch (e) {
      debugPrint('IncubatorService.listPrograms error: $e');
      return _cacheReadList<IncubatorProgram>(
          _kCachePrograms, IncubatorProgram.decodeList);
    }
  }

  Future<IncubatorProgram?> fetchProgram(String id) async {
    if (!_isValidId(id)) return null;
    try {
      final res = await _selectWhere(_tPrograms, 'id', id)
          .timeout(_timeout);
      if (res.isNotEmpty) {
        return IncubatorProgram.fromJson(res.first);
      }
    } catch (e) {
      debugPrint('IncubatorService.fetchProgram error: $e');
    }
    // Fallback : chercher dans la liste complète en cache
    final all = await listPrograms();
    try {
      return all.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PROJECTS (propres à l'utilisateur — RLS filtre côté Supabase)
  // ─────────────────────────────────────────────────────────────────────────
  Future<List<IncubatorProject>> listMyProjects() async {
    try {
      final res = await _select(
        _tProjects,
        select: '*',
        orderBy: 'updated_at',
        ascending: false,
        limit: 100,
      ).timeout(_timeout);
      final projects = res.map((r) => IncubatorProject.fromJson(r)).toList();
      await _cacheWrite(_kCacheProjects, IncubatorProject.encodeList(projects));
      return projects;
    } catch (e) {
      debugPrint('IncubatorService.listMyProjects error: $e');
      return _cacheReadList<IncubatorProject>(
          _kCacheProjects, IncubatorProject.decodeList);
    }
  }

  Future<IncubatorProject> createProject({
    required String title,
    required String sector,
    String pitch = '',
  }) async {
    final sanitizedTitle = _sanitize(title);
    final sanitizedSector = _sanitize(sector);
    final sanitizedPitch = _sanitize(pitch);

    if (sanitizedTitle.isEmpty) {
      throw ArgumentError('Le titre du projet ne peut pas être vide.');
    }

    final project = IncubatorProject(
      id: _generateId('prj'),
      ownerThixId: _currentUserThixId(),
      title: sanitizedTitle,
      sector: sanitizedSector,
      pitch: sanitizedPitch,
      stage: IncubatorStage.submission,
      progress: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await _insert(_tProjects, project.toJson()).timeout(_timeout);
    } catch (e) {
      debugPrint('IncubatorService.createProject error: $e');
      rethrow;
    }
    return project;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // APPLICATIONS
  // ─────────────────────────────────────────────────────────────────────────
  Future<List<IncubatorApplication>> listMyApplications() async {
    try {
      final res = await _select(
        _tApplications,
        select: '*',
        orderBy: 'submitted_at',
        ascending: false,
        limit: 200,
      ).timeout(_timeout);
      final apps = res.map((r) => IncubatorApplication.fromJson(r)).toList();
      await _cacheWrite(
          _kCacheApplications, IncubatorApplication.encodeList(apps));
      return apps;
    } catch (e) {
      debugPrint('IncubatorService.listMyApplications error: $e');
      return _cacheReadList<IncubatorApplication>(
          _kCacheApplications, IncubatorApplication.decodeList);
    }
  }

  /// Vérifie si l'utilisateur courant a déjà candidaté au programme.
  /// Retourne le statut ('pending'|'accepted'…), ou 'none' si aucune candidature.
  Future<String> checkUserApplicationStatus(String programId) async {
    if (!_isValidId(programId)) return 'none';
    try {
      final res = await _selectWhere(
        _tApplications,
        'program_id',
        programId,
        orderBy: 'submitted_at',
        ascending: false,
        limit: 1,
      ).timeout(_timeout);
      if (res.isNotEmpty) {
        final app = IncubatorApplication.fromJson(res.first);
        // Vérification supplémentaire : appartient bien à l'utilisateur courant
        if (app.applicantThixId == _currentUserThixId()) {
          return app.status;
        }
      }
    } catch (e) {
      debugPrint('IncubatorService.checkUserApplicationStatus error: $e');
    }
    return 'none';
  }

  Future<IncubatorApplication> submitApplication({
    required String programId,
    required String programTitle,
    required String message,
    String? projectId,
  }) async {
    if (!_isValidId(programId)) {
      throw ArgumentError('Identifiant de programme invalide.');
    }
    final sanitizedMessage = _sanitize(message);
    if (sanitizedMessage.length < 30 || sanitizedMessage.length > 2000) {
      throw ArgumentError(
          'Le message doit faire entre 30 et 2000 caractères.');
    }

    final app = IncubatorApplication(
      id: _generateId('app'),
      applicantThixId: _currentUserThixId(),
      programId: programId,
      programTitle: _sanitize(programTitle),
      projectId: projectId,
      message: sanitizedMessage,
      status: 'pending',
      submittedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await _insert(_tApplications, app.toJson()).timeout(_timeout);
    } catch (e) {
      debugPrint('IncubatorService.submitApplication error: $e');
      rethrow;
    }

    // Invalidate cache pour forcer un rafraîchissement à la prochaine lecture
    await _cacheDelete(_kCacheApplications);
    await _cacheDelete(_kCacheActivities);
    return app;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MENTORS
  // ─────────────────────────────────────────────────────────────────────────
  Future<List<IncubatorMentor>> listMentors() async {
    try {
      final res = await _select(
        _tMentors,
        select: '*',
        orderBy: 'rating',
        ascending: false,
        limit: 100,
      ).timeout(_timeout);
      final mentors = res.map((r) => IncubatorMentor.fromJson(r)).toList();
      await _cacheWrite(_kCacheMentors, IncubatorMentor.encodeList(mentors));
      return mentors;
    } catch (e) {
      debugPrint('IncubatorService.listMentors error: $e');
      return _cacheReadList<IncubatorMentor>(
          _kCacheMentors, IncubatorMentor.decodeList);
    }
  }

  Future<List<IncubatorMentor>> mentorsForProgram(String programId) async {
    if (!_isValidId(programId)) return const [];
    final program = await fetchProgram(programId);
    if (program == null || program.mentorIds.isEmpty) return const [];
    final all = await listMentors();
    return all.where((m) => program.mentorIds.contains(m.id)).toList();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTIVITIES (flux)
  // ─────────────────────────────────────────────────────────────────────────
  Future<List<IncubatorActivity>> listMyActivities({int limit = 20}) async {
    try {
      final res = await _select(
        _tActivities,
        select: '*',
        orderBy: 'occurred_at',
        ascending: false,
        limit: limit,
      ).timeout(_timeout);
      final activities =
          res.map((r) => IncubatorActivity.fromJson(r)).toList();
      await _cacheWrite(
          _kCacheActivities, IncubatorActivity.encodeList(activities));
      return activities;
    } catch (e) {
      debugPrint('IncubatorService.listMyActivities error: $e');
      return _cacheReadList<IncubatorActivity>(
          _kCacheActivities, IncubatorActivity.decodeList);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // AGGREGATES (pour les stats de la home)
  // ─────────────────────────────────────────────────────────────────────────
  Future<int> countUnreadNotifications() async {
    // TODO : connecter au module notifications global si besoin
    // Pour l'instant on retourne 0 — la home affichera 0 notifications.
    return 0;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REAL-TIME STREAMS (Supabase channels)
  // ─────────────────────────────────────────────────────────────────────────
  Stream<void> realtimeUpdates() {
    final controller = StreamController<void>.broadcast();

    final channels = <RealtimeChannel>[
      _client.channel('incubator:programs')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _tPrograms,
          callback: (_) => controller.add(null),
        ),
      _client.channel('incubator:applications')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _tApplications,
          callback: (_) => controller.add(null),
        ),
      _client.channel('incubator:activities')
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: _tActivities,
          callback: (_) => controller.add(null),
        ),
    ];

    for (final ch in channels) {
      ch.subscribe();
    }

    controller.onCancel = () {
      for (final ch in channels) {
        _client.removeChannel(ch);
      }
    };

    return controller.stream;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS INTERNES
  // ─────────────────────────────────────────────────────────────────────────
  String _currentUserThixId() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Utilisateur non authentifié.');
    }
    return user.id;
  }

  Future<void> _cacheWrite(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (e) {
      if (kDebugMode) debugPrint('Cache write failed for $key: $e');
    }
  }

  Future<void> _cacheDelete(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {}
  }

  Future<List<T>> _cacheReadList<T>(
    String key,
    List<T> Function(String) decoder,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw != null && raw.trim().isNotEmpty) {
        return decoder(raw);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Cache read failed for $key: $e');
    }
    return const [];
  }
}
