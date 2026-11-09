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
import '../supabase/supabase_service.dart';

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
  // VALIDATION HELPERS
  // ─────────────────────────────────────────────────────────────────────────
  static bool _isValidId(String id) =>
      id.isNotEmpty && id.length <= 128 && RegExp(r'^[A-Za-z0-9_\-]+$').hasMatch(id);

  static String _sanitize(String s) =>
      s.replaceAll(RegExp(r'[\p{C}]', unicode: true), '').trim();

  static String _generateId(String prefix) {
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final r  = (DateTime.now().millisecond ^ (0xFFFFFFFF * (DateTime.now().microsecond / 1e6))).toInt().toRadixString(36);
    return '${prefix}_$ts$r';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PROGRAMS
  // ─────────────────────────────────────────────────────────────────────────
  Future<List<IncubatorProgram>> listPrograms({bool forceRefresh = false}) async {
    try {
      final res = await SupabaseService.select(
        _tPrograms,
        select: '*',
        orderBy: 'created_at',
        ascending: false,
        limit: 200,
      ).timeout(_timeout);

      // Filtrage client (safety si RLS fuit) : on exclut draft/archived
      final filtered = res.where((row) {
        final status = (row['status'] ?? 'open').toString();
        return status == 'open' || status == 'upcoming' || status == 'closed';
      }).toList();

      final programs = filtered.map((r) => IncubatorProgram.fromJson(r)).toList();
      await _cacheWrite(_kCachePrograms, IncubatorProgram.encodeList(programs));
      return programs;
    } on TimeoutException {
      debugPrint('IncubatorService.listPrograms timeout');
      return _cacheReadList<IncubatorProgram>(_kCachePrograms, IncubatorProgram.decodeList);
    } catch (e) {
      debugPrint('IncubatorService.listPrograms error: $e');
      return _cacheReadList<IncubatorProgram>(_kCachePrograms, IncubatorProgram.decodeList);
    }
  }

  Future<IncubatorProgram?> fetchProgram(String id) async {
    if (!_isValidId(id)) return null;
    try {
      final res = await SupabaseService.select(_tPrograms, select: '*')
          .timeout(_timeout);
      final match = res.firstWhere(
        (r) => (r['id'] ?? '').toString() == id,
        orElse: () => <String, dynamic>{},
      );
      if (match.isNotEmpty) {
        return IncubatorProgram.fromJson(match);
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
      final res = await SupabaseService.select(
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
      return _cacheReadList<IncubatorProject>(_kCacheProjects, IncubatorProject.decodeList);
    }
  }

  Future<IncubatorProject> createProject({
    required String title,
    required String sector,
    String pitch = '',
  }) async {
    final sanitized = IncubatorProject(
      id: _generateId('prj'),
      ownerThixId: _currentUserThixId(),
      title: _sanitize(title),
      sector: _sanitize(sector),
      pitch: _sanitize(pitch),
      stage: IncubatorStage.submission,
      progress: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    if (sanitized.title.isEmpty) {
      throw ArgumentError('Le titre du projet ne peut pas être vide.');
    }
    try {
      await SupabaseService.insert(_tProjects, sanitized.toJson()).timeout(_timeout);
    } catch (e) {
      debugPrint('IncubatorService.createProject error: $e');
      rethrow;
    }
    return sanitized;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // APPLICATIONS
  // ─────────────────────────────────────────────────────────────────────────
  Future<List<IncubatorApplication>> listMyApplications() async {
    try {
      final res = await SupabaseService.select(
        _tApplications,
        select: '*',
        orderBy: 'submitted_at',
        ascending: false,
        limit: 200,
      ).timeout(_timeout);
      final apps = res.map((r) => IncubatorApplication.fromJson(r)).toList();
      await _cacheWrite(_kCacheApplications, IncubatorApplication.encodeList(apps));
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
    final all = await listMyApplications();
    try {
      final match = all.firstWhere((a) => a.programId == programId);
      return match.status;
    } catch (_) {
      return 'none';
    }
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
      throw ArgumentError('Le message doit faire entre 30 et 2000 caractères.');
    }

    final app = IncubatorApplication(
      id: _generateId('app'),
      applicantThixId: _currentUserThixId(),
      programId: programId,
      programTitle: programTitle,
      projectId: projectId,
      message: sanitizedMessage,
      status: 'pending',
      submittedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await SupabaseService.insert(_tApplications, app.toJson()).timeout(_timeout);
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
      final res = await SupabaseService.select(
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
      return _cacheReadList<IncubatorMentor>(_kCacheMentors, IncubatorMentor.decodeList);
    }
  }

  Future<List<IncubatorMentor>> mentorsForProgram(String programId) async {
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
      final res = await SupabaseService.select(
        _tActivities,
        select: '*',
        orderBy: 'occurred_at',
        ascending: false,
        limit: limit,
      ).timeout(_timeout);
      final activities = res.map((r) => IncubatorActivity.fromJson(r)).toList();
      await _cacheWrite(_kCacheActivities, IncubatorActivity.encodeList(activities));
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
    // Pour l'instant on compte les candidatures qui ont bougé depuis la dernière lecture
    return 0;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REAL-TIME STREAMS (Supabase channels)
  // ─────────────────────────────────────────────────────────────────────────
  Stream<void> realtimeUpdates() {
    final client = Supabase.instance.client;
    final controller = StreamController<void>.broadcast();

    final channels = <RealtimeChannel>[
      client.channel('incubator:programs')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _tPrograms,
          callback: (_) => controller.add(null),
        ),
      client.channel('incubator:applications')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _tApplications,
          callback: (_) => controller.add(null),
        ),
      client.channel('incubator:activities')
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
        client.removeChannel(ch);
      }
    };

    return controller.stream;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS INTERNES
  // ─────────────────────────────────────────────────────────────────────────
  String _currentUserThixId() {
    final user = Supabase.instance.client.auth.currentUser;
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
