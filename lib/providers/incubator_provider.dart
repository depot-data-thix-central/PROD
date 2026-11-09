// ============================================================================
// FICHIER : lib/providers/incubator_provider.dart
// Module  : thix_incubator
// ============================================================================
// ChangeNotifier — état global du module INCUBATOR.
// Expose : programmes, projets, candidatures, mentors, activités, stats
//          agrégées (compteurs, progression moyenne).
// Gère les streams Supabase real-time pour refresh auto.
// ============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/incubator_activity.dart';
import '../models/incubator_application.dart';
import '../models/incubator_mentor.dart';
import '../models/incubator_program.dart';
import '../models/incubator_project.dart';
import '../services/incubator_service.dart';

enum IncubatorState { idle, loading, loaded, error }

class IncubatorProvider extends ChangeNotifier {
  IncubatorProvider({IncubatorService? service})
      : _service = service ?? IncubatorService.instance;

  final IncubatorService _service;

  // ─── ÉTAT ───
  IncubatorState _state = IncubatorState.idle;
  String? _error;
  bool _isFirstLoad = true;

  // ─── DONNÉES ───
  List<IncubatorProgram>     _programs     = const [];
  List<IncubatorProject>     _projects     = const [];
  List<IncubatorApplication> _applications = const [];
  List<IncubatorMentor>      _mentors      = const [];
  List<IncubatorActivity>    _activities   = const [];
  int                        _unreadNotifs = 0;

  StreamSubscription<void>? _realtimeSub;

  // ─── GETTERS ───
  IncubatorState get state        => _state;
  String?        get error        => _error;
  bool           get isFirstLoad  => _isFirstLoad;
  bool           get isAuthenticated => Supabase.instance.client.auth.currentUser != null;

  List<IncubatorProgram>     get programs          => _programs;
  List<IncubatorProgram>     get openPrograms      => _programs.where((p) => p.isOpen).toList();
  List<IncubatorProject>     get projects          => _projects;
  List<IncubatorApplication> get applications      => _applications;
  List<IncubatorMentor>      get mentors           => _mentors;
  List<IncubatorActivity>    get activities        => _activities;

  List<IncubatorApplication> get recentApplications => _applications.take(3).toList();
  List<IncubatorProject>     get recentProjects     => _projects.take(3).toList();
  List<IncubatorActivity>    get recentActivities   => _activities.take(4).toList();

  int get unreadNotifications => _unreadNotifs;
  int get openProgramsCount   => openPrograms.length;
  int get myProjectsCount     => _projects.length;
  int get myApplicationsCount => _applications.length;

  int get averageProgressPercent {
    if (_projects.isEmpty) return 0;
    final sum = _projects.fold<int>(0, (acc, p) => acc + p.progress);
    return (sum / _projects.length).round();
  }

  bool get isEmpty => _programs.isEmpty && _projects.isEmpty;

  List<IncubatorMentor> mentorsForProgram(String programId) {
    final program = _programs.cast<IncubatorProgram?>().firstWhere(
      (p) => p?.id == programId,
      orElse: () => null,
    );
    if (program == null) return const [];
    return _mentors.where((m) => program.mentorIds.contains(m.id)).toList();
  }

  Stream<void> realtimeUpdates() => _service.realtimeUpdates();

  // ─── LIFECYCLE ───
  Future<void> loadAll({bool forceRefresh = false}) async {
    if (_state == IncubatorState.loading && !forceRefresh) return;

    _state = IncubatorState.loading;
    _error = null;
    if (forceRefresh) _isFirstLoad = true;
    notifyListeners();

    try {
      // Chargement en parallèle (perf)
      final results = await Future.wait([
        _service.listPrograms(forceRefresh: forceRefresh),
        if (isAuthenticated) _service.listMyProjects() else Future.value(<IncubatorProject>[]),
        if (isAuthenticated) _service.listMyApplications() else Future.value(<IncubatorApplication>[]),
        _service.listMentors(),
        if (isAuthenticated) _service.listMyActivities() else Future.value(<IncubatorActivity>[]),
        if (isAuthenticated) _service.countUnreadNotifications() else Future.value(0),
      ]);

      _programs     = results[0] as List<IncubatorProgram>;
      _projects     = results[1] as List<IncubatorProject>;
      _applications = results[2] as List<IncubatorApplication>;
      _mentors      = results[3] as List<IncubatorMentor>;
      _activities   = results[4] as List<IncubatorActivity>;
      _unreadNotifs = results[5] as int;

      _state = IncubatorState.loaded;
    } catch (e, st) {
      _state = IncubatorState.error;
      _error = e.toString();
      if (kDebugMode) debugPrintStack(stackTrace: st);
    } finally {
      _isFirstLoad = false;
      notifyListeners();
    }

    // Abonnement temps réel (une seule fois)
    if (_realtimeSub == null) {
      _realtimeSub = _service.realtimeUpdates().listen((_) {
        // Refresh auto quand un changement real-time arrive
        loadAll();
      });
    }
  }

  // ─── ACTIONS ───
  Future<IncubatorApplication> submitApplication({
    required String programId,
    required String programTitle,
    required String message,
    String? projectId,
  }) async {
    final app = await _service.submitApplication(
      programId: programId,
      programTitle: programTitle,
      message: message,
      projectId: projectId,
    );
    // Refresh la liste en background
    await loadAll(forceRefresh: true);
    return app;
  }

  Future<IncubatorProject> createProject({
    required String title,
    required String sector,
    String pitch = '',
  }) async {
    final project = await _service.createProject(
      title: title,
      sector: sector,
      pitch: pitch,
    );
    await loadAll(forceRefresh: true);
    return project;
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }
}
