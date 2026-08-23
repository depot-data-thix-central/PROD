// lib/presentation/thix_ia/datasources/thix_ia_local_datasource.dart
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/constants/thix_ia_constants.dart';
import '../models/thix_project.dart';
import '../models/project_memory.dart';
import '../models/project_analysis.dart';

/// ============================================================================
/// LOCAL DATASOURCE - Hive Cache pour millions d'users offline
/// ============================================================================

abstract class ThixIaLocalDatasource {
  Future<void> init();

  // Projects
  Future<void> cacheProjects(List<ThixProject> projects);
  Future<List<ThixProject>> getCachedProjects();
  Future<void> cacheProject(ThixProject project);
  Future<ThixProject?> getCachedProjectByCode(String code);

  // Active Project
  Future<void> setActiveProjectCode(String code);
  Future<String?> getActiveProjectCode();
  Future<void> cacheActiveProject(ThixProject project);
  Future<ThixProject?> getCachedActiveProject();

  // Memory
  Future<void> cacheProjectMemory(ProjectMemory memory);
  Future<ProjectMemory?> getCachedMemory(String projectCode);

  // Analyses
  Future<void> cacheAnalyses(String projectCode, List<ProjectAnalysis> analyses);
  Future<List<ProjectAnalysis>> getCachedAnalyses(String projectCode);

  // Clear
  Future<void> clearAll();
  Future<void> clearProject(String projectCode);
}

class ThixIaLocalDatasourceImpl implements ThixIaLocalDatasource {
  static const String _projectsBoxName = ThixIAConstants.keyUserProjectsBox;
  static const String _activeBoxName = 'thix_active_box';
  static const String _memoryBoxName = ThixIAConstants.keyProjectMemoryBox;
  static const String _analysesBoxName = ThixIAConstants.keyAnalysesBox;

  late Box<String> _projectsBox;
  late Box<String> _activeBox;
  late Box<String> _memoryBox;
  late Box<String> _analysesBox;

  @override
  Future<void> init() async {
    await Hive.initFlutter();
    _projectsBox = await Hive.openBox<String>(_projectsBoxName);
    _activeBox = await Hive.openBox<String>(_activeBoxName);
    _memoryBox = await Hive.openBox<String>(_memoryBoxName);
    _analysesBox = await Hive.openBox<String>(_analysesBoxName);
  }

  // ────────────────────────────────────────────────────────────────────────
  // PROJECTS
  // ────────────────────────────────────────────────────────────────────────
  @override
  Future<void> cacheProjects(List<ThixProject> projects) async {
    final map = <String, String>{};
    for (final p in projects) {
      map[p.projectCode] = jsonEncode(p.toJson());
    }
    await _projectsBox.putAll(map);
  }

  @override
  Future<List<ThixProject>> getCachedProjects() async {
    try {
      return _projectsBox.values.map((e) => ThixProject.fromJson(jsonDecode(e))).toList()
       ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> cacheProject(ThixProject project) async {
    await _projectsBox.put(project.projectCode, jsonEncode(project.toJson()));
  }

  @override
  Future<ThixProject?> getCachedProjectByCode(String code) async {
    final json = _projectsBox.get(code);
    if (json == null) return null;
    try {
      return ThixProject.fromJson(jsonDecode(json));
    } catch (_) {
      return null;
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // ACTIVE PROJECT - Critique pour UX
  // ────────────────────────────────────────────────────────────────────────
  @override
  Future<void> setActiveProjectCode(String code) async {
    await _activeBox.put(ThixIAConstants.keyActiveProjectCode, code);
  }

  @override
  Future<String?> getActiveProjectCode() async {
    return _activeBox.get(ThixIAConstants.keyActiveProjectCode);
  }

  @override
  Future<void> cacheActiveProject(ThixProject project) async {
    await _activeBox.put(ThixIAConstants.keyActiveProjectJson, jsonEncode(project.toJson()));
    await setActiveProjectCode(project.projectCode);
  }

  @override
  Future<ThixProject?> getCachedActiveProject() async {
    final json = _activeBox.get(ThixIAConstants.keyActiveProjectJson);
    if (json == null) return null;
    try {
      return ThixProject.fromJson(jsonDecode(json));
    } catch (_) {
      return null;
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // MEMORY
  // ────────────────────────────────────────────────────────────────────────
  @override
  Future<void> cacheProjectMemory(ProjectMemory memory) async {
    await _memoryBox.put(memory.projectCode, jsonEncode(memory.toJson()));
  }

  @override
  Future<ProjectMemory?> getCachedMemory(String projectCode) async {
    final json = _memoryBox.get(projectCode);
    if (json == null) return null;
    try {
      return ProjectMemory.fromJson(jsonDecode(json));
    } catch (_) {
      return null;
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // ANALYSES
  // ────────────────────────────────────────────────────────────────────────
  @override
  Future<void> cacheAnalyses(String projectCode, List<ProjectAnalysis> analyses) async {
    final json = jsonEncode(analyses.map((e) => e.toSupabase()).toList());
    await _analysesBox.put(projectCode, json);
  }

  @override
  Future<List<ProjectAnalysis>> getCachedAnalyses(String projectCode) async {
    final json = _analysesBox.get(projectCode);
    if (json == null) return [];
    try {
      final List list = jsonDecode(json);
      return list.map((e) => ProjectAnalysis.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> clearAll() async {
    await Future.wait([
      _projectsBox.clear(),
      _activeBox.clear(),
      _memoryBox.clear(),
      _analysesBox.clear(),
    ]);
  }

  @override
  Future<void> clearProject(String projectCode) async {
    await _projectsBox.delete(projectCode);
    await _memoryBox.delete(projectCode);
    await _analysesBox.delete(projectCode);
  }
}
