// lib/providers/progress_provider.dart
import 'package:flutter/material.dart';
import '../services/education_service.dart';
import '../models/user_progress.dart';
import '../models/enrollment.dart';

class ProgressProvider extends ChangeNotifier {
  final EducationService _service;

  List<UserProgress> _progress = [];
  Enrollment? _currentEnrollment;
  double _overallProgress = 0.0;
  int _completedLessons = 0;
  int _totalLessons = 0;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<UserProgress> get progress => _progress;
  Enrollment? get currentEnrollment => _currentEnrollment;
  double get overallProgress => _overallProgress;
  int get completedLessons => _completedLessons;
  int get totalLessons => _totalLessons;
  bool get isLoading => _isLoading;
  String? get error => _error;

  ProgressProvider(this._service);

  // ─── CHARGEMENT ──────────────────────────────────────────────────

  Future<void> loadProgress(String userId, String formationId) async {
    _setLoading(true);
    try {
      _progress = await _service.getUserProgressForFormation(userId, formationId);
      _currentEnrollment = await _service.getEnrollment(userId, formationId);

      // Calculer la progression globale
      if (_progress.isNotEmpty) {
        _completedLessons = _progress.where((p) => p.status == 'completed').length;
        _totalLessons = _progress.length;
        _overallProgress = _completedLessons / _totalLessons;
      } else {
        _completedLessons = 0;
        _totalLessons = 0;
        _overallProgress = 0.0;
      }

      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading progress: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ─── MISE À JOUR DE LA PROGRESSION ──────────────────────────────

  Future<void> completeLesson(String userId, String lessonId) async {
    _setLoading(true);
    try {
      await _service.completeLesson(userId, lessonId);

      // Mettre à jour la progression locale
      final existing = _progress.firstWhere(
        (p) => p.lessonId == lessonId,
        orElse: () => UserProgress(
          id: '',
          userId: userId,
          lessonId: lessonId,
          status: 'completed',
          progress: 1.0,
          lastAccessedAt: DateTime.now(),
          completedAt: DateTime.now(),
        ),
      );

      if (existing.id.isNotEmpty) {
        existing.status = 'completed';
        existing.progress = 1.0;
        existing.completedAt = DateTime.now();
      } else {
        _progress.add(existing);
      }

      // Recalculer la progression globale
      _completedLessons = _progress.where((p) => p.status == 'completed').length;
      _totalLessons = _progress.length;
      _overallProgress = _totalLessons > 0 ? _completedLessons / _totalLessons : 0.0;

      // Mettre à jour l'inscription si elle existe
      if (_currentEnrollment != null) {
        await _service.updateEnrollmentProgress(
          _currentEnrollment!.id,
          _overallProgress,
        );
        _currentEnrollment!.progress = _overallProgress;
        _currentEnrollment!.status = _overallProgress >= 1.0 ? 'completed' : 'in_progress';
        if (_overallProgress >= 1.0) {
          _currentEnrollment!.completedAt = DateTime.now();
        }
      }

      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error completing lesson: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateLessonProgress(
    String userId,
    String lessonId,
    String status,
    double progress,
  ) async {
    _setLoading(true);
    try {
      await _service.updateLessonProgress(userId, lessonId, status, progress);

      // Mettre à jour localement
      final existing = _progress.firstWhere(
        (p) => p.lessonId == lessonId,
        orElse: () => UserProgress(
          id: '',
          userId: userId,
          lessonId: lessonId,
          status: status,
          progress: progress,
          lastAccessedAt: DateTime.now(),
        ),
      );

      if (existing.id.isNotEmpty) {
        existing.status = status;
        existing.progress = progress;
        existing.lastAccessedAt = DateTime.now();
        if (status == 'completed') {
          existing.completedAt = DateTime.now();
        }
      } else {
        _progress.add(existing);
      }

      // Recalculer
      _completedLessons = _progress.where((p) => p.status == 'completed').length;
      _totalLessons = _progress.length;
      _overallProgress = _totalLessons > 0 ? _completedLessons / _totalLessons : 0.0;

      // Mettre à jour l'inscription
      if (_currentEnrollment != null) {
        await _service.updateEnrollmentProgress(
          _currentEnrollment!.id,
          _overallProgress,
        );
        _currentEnrollment!.progress = _overallProgress;
        _currentEnrollment!.status = _overallProgress >= 1.0 ? 'completed' : 'in_progress';
        if (_overallProgress >= 1.0) {
          _currentEnrollment!.completedAt = DateTime.now();
        }
      }

      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error updating lesson progress: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ─── UTILITAIRES ──────────────────────────────────────────────────

  /// Vérifie si une leçon est complétée
  bool isLessonCompleted(String lessonId) {
    return _progress.any((p) => p.lessonId == lessonId && p.status == 'completed');
  }

  /// Récupère la progression d'une leçon spécifique
  UserProgress? getLessonProgress(String lessonId) {
    try {
      return _progress.firstWhere((p) => p.lessonId == lessonId);
    } catch (_) {
      return null;
    }
  }

  void reset() {
    _progress = [];
    _currentEnrollment = null;
    _overallProgress = 0.0;
    _completedLessons = 0;
    _totalLessons = 0;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
