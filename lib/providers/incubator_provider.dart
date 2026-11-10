// ============================================================================
// FICHIER : lib/providers/incubator_provider.dart
// Module  : thix_incubator
// Stack   : Riverpod moderne (API Notifier) — aucun package:provider
// ============================================================================
// État global du module INCUBATOR : programmes, projets, candidatures,
// mentors, activités + stats agrégées. Auto-refresh via Supabase Realtime.
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrintStack;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/incubator_activity.dart';
import '../models/incubator_application.dart';
import '../models/incubator_mentor.dart';
import '../models/incubator_program.dart';
import '../models/incubator_project.dart';
import '../services/incubator_service.dart';

// ============================================================================
// ÉTAT
// ============================================================================
enum IncubatorStatus { idle, loading, loaded, error }

@immutable
class IncubatorState {
  final IncubatorStatus status;
  final String? error;
  final bool isFirstLoad;
  final bool isAuthenticated;
  final List<IncubatorProgram> programs;
  final List<IncubatorProject> projects;
  final List<IncubatorApplication> applications;
  final List<IncubatorMentor> mentors;
  final List<IncubatorActivity> activities;
  final int unreadNotifications;

  const IncubatorState({
    this.status = IncubatorStatus.idle,
    this.error,
    this.isFirstLoad = true,
    this.isAuthenticated = false,
    this.programs = const [],
    this.projects = const [],
    this.applications = const [],
    this.mentors = const [],
    this.activities = const [],
    this.unreadNotifications = 0,
  });

  // ─── DÉRIVÉS (calculés, jamais stockés en dur) ───
  List<IncubatorProgram> get openPrograms =>
      programs.where((p) => p.isOpen).toList(growable: false);

  int get openProgramsCount => openPrograms.length;
  int get myProjectsCount => projects.length;
  int get myApplicationsCount => applications.length;

  int get averageProgressPercent {
    if (projects.isEmpty) return 0;
    final sum = projects.fold<int>(0, (acc, p) => acc + p.progress);
    return (sum / projects.length).round();
  }

  bool get isEmpty => programs.isEmpty && projects.isEmpty;

  List<IncubatorApplication> get recentApplications =>
      applications.take(3).toList(growable: false);
  List<IncubatorProject> get recentProjects =>
      projects.take(3).toList(growable: false);
  List<IncubatorActivity> get recentActivities =>
      activities.take(4).toList(growable: false);

  List<IncubatorMentor> mentorsForProgram(String programId) {
    IncubatorProgram? target;
    for (final p in programs) {
      if (p.id == programId) {
        target = p;
        break;
      }
    }
    if (target == null || target.mentorIds.isEmpty) return const [];
    return mentors
        .where((m) => target!.mentorIds.contains(m.id))
        .toList(growable: false);
  }

  IncubatorState copyWith({
    IncubatorStatus? status,
    String? error,
    bool? isFirstLoad,
    bool? isAuthenticated,
    List<IncubatorProgram>? programs,
    List<IncubatorProject>? projects,
    List<IncubatorApplication>? applications,
    List<IncubatorMentor>? mentors,
    List<IncubatorActivity>? activities,
    int? unreadNotifications,
  }) {
    return IncubatorState(
      status: status ?? this.status,
      error: error,
      isFirstLoad: isFirstLoad ?? this.isFirstLoad,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      programs: programs ?? this.programs,
      projects: projects ?? this.projects,
      applications: applications ?? this.applications,
      mentors: mentors ?? this.mentors,
      activities: activities ?? this.activities,
      unreadNotifications: unreadNotifications ?? this.unreadNotifications,
    );
  }
}

// ============================================================================
// PROVIDERS
// ============================================================================

/// Service singleton exposé à l'arbre Riverpod (testable / overridable).
final incubatorServiceProvider =
    Provider<IncubatorService>((ref) => IncubatorService.instance);

/// Notifier principal du module.
class IncubatorNotifier extends Notifier<IncubatorState> {
  StreamSubscription<void>? _rtSub;

  @override
  IncubatorState build() {
    ref.onDispose(() => _rtSub?.cancel());
    return const IncubatorState();
  }

  IncubatorService get _service => ref.read(incubatorServiceProvider);

  bool get _isAuth => Supabase.instance.client.auth.currentUser != null;

  // ─── CHARGEMENT GLOBAL ───
  Future<void> loadAll({bool forceRefresh = false}) async {
    if (state.status == IncubatorStatus.loading && !forceRefresh) return;

    state = state.copyWith(status: IncubatorStatus.loading, error: '');

    try {
      final results = await Future.wait<Object>([
        _service.listPrograms(forceRefresh: forceRefresh),
        _isAuth
            ? _service.listMyProjects()
            : Future.value(const <IncubatorProject>[]),
        _isAuth
            ? _service.listMyApplications()
            : Future.value(const <IncubatorApplication>[]),
        _service.listMentors(),
        _isAuth
            ? _service.listMyActivities()
            : Future.value(const <IncubatorActivity>[]),
        _service.countUnreadNotifications(),
      ]);

      state = IncubatorState(
        status: IncubatorStatus.loaded,
        isFirstLoad: false,
        isAuthenticated: _isAuth,
        programs: results[0] as List<IncubatorProgram>,
        projects: results[1] as List<IncubatorProject>,
        applications: results[2] as List<IncubatorApplication>,
        mentors: results[3] as List<IncubatorMentor>,
        activities: results[4] as List<IncubatorActivity>,
        unreadNotifications: results[5] as int,
      );

      _ensureRealtime();
    } catch (e, st) {
      state = state.copyWith(
        status: IncubatorStatus.error,
        error: e.toString(),
        isFirstLoad: false,
      );
      if (kDebugMode) debugPrintStack(stackTrace: st);
    }
  }

  /// Abonnement Realtime unique (invalidation auto → reload).
  void _ensureRealtime() {
    if (_rtSub != null) return;
    _rtSub = _service.realtimeUpdates().listen((_) {
      loadAll(forceRefresh: true);
    });
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
}

/// ⭐ Provider unique consommé par toutes les pages du module.
final incubatorProvider =
    NotifierProvider<IncubatorNotifier, IncubatorState>(IncubatorNotifier.new);
