// lib/presentation/education/widgets/formation_detail/formation_lesson_player.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/presentation/education/services/certificate_service.dart';
import 'package:thix_id/presentation/education/models/lesson.dart';
import 'formation_video_player.dart';
import 'formation_evaluation_widget.dart';

// ============================================================
// ÉTAT DE LA LEÇON (Immuable)
// ============================================================
class LessonProgressState {
  final bool isCompleted;
  final double progress;
  final bool isLoading;
  final bool isUpdating;
  final String? error;

  const LessonProgressState({
    this.isCompleted = false,
    this.progress = 0.0,
    this.isLoading = true,
    this.isUpdating = false,
    this.error,
  });

  LessonProgressState copyWith({
    bool? isCompleted,
    double? progress,
    bool? isLoading,
    bool? isUpdating,
    String? error,
  }) {
    return LessonProgressState(
      isCompleted: isCompleted ?? this.isCompleted,
      progress: progress ?? this.progress,
      isLoading: isLoading ?? this.isLoading,
      isUpdating: isUpdating ?? this.isUpdating,
      error: error, 
    );
  }
}

// ============================================================
// PROVIDER & NOTIFIER (Logique Métier Séparée)
// ============================================================
final lessonProgressProvider = AutoDisposeNotifierProviderFamily<LessonProgressNotifier, LessonProgressState, String>(
  LessonProgressNotifier.new,
);

class LessonProgressNotifier extends AutoDisposeFamilyNotifier<LessonProgressState, String> {
  @override
  LessonProgressState build(String arg) {
    _fetchInitialProgress();
    return const LessonProgressState(isLoading: true);
  }

  Future<void> _fetchInitialProgress() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        state = state.copyWith(isLoading: false, error: 'Utilisateur non connecté');
        return;
      }

      final res = await Supabase.instance.client
          .from('user_progress') 
          .select('status, progress') 
          .eq('user_id', userId)
          .eq('lesson_id', arg)
          .maybeSingle();

      if (res != null) {
        state = state.copyWith(
          isLoading: false,
          isCompleted: res['status'] == 'completed',
          progress: (res['progress'] as num?)?.toDouble() ?? 0.0,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      debugPrint('Erreur Supabase lors du chargement de la progression : $e');
      state = state.copyWith(isLoading: false, error: 'Impossible de charger la progression.');
    }
  }

  Future<void> updateProgress(double newProgress) async {
    if (state.isCompleted) return; 

    final isDone = newProgress >= 1.0;
    state = state.copyWith(progress: newProgress, isCompleted: isDone);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final now = DateTime.now().toIso8601String();
      
      final Map<String, dynamic> data = {
        'user_id': userId,
        'lesson_id': arg,
        'status': isDone ? 'completed' : 'in_progress',
        'completed': isDone, 
        'progress': newProgress,
        'progress_percentage': (newProgress * 100).toInt(),
        'last_accessed_at': now,
        'last_accessed': now,
      };
      
      if (isDone) {
        data['completed_at'] = now;
      }

      await Supabase.instance.client.from('user_progress').upsert(
        data,
        onConflict: 'user_id,lesson_id',
      );
    } catch (e) {
      debugPrint('Erreur lors de la mise à jour de la progression: $e');
    }
  }

  // ✅ CORRECTION : Ajout de formationId pour mettre à jour la table globale enrollments
  Future<bool> markAsCompleted(String? formationId) async {
    if (state.isCompleted || state.isUpdating) return false;

    state = state.copyWith(isUpdating: true, error: null);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        state = state.copyWith(isUpdating: false, error: 'Veuillez vous connecter pour valider la leçon.');
        return false;
      }

      final now = DateTime.now().toIso8601String();

      final Map<String, dynamic> data = {
        'user_id': userId,
        'lesson_id': arg,
        'status': 'completed',
        'completed': true,
        'progress': 1.0,
        'progress_percentage': 100,
        'last_accessed_at': now,
        'last_accessed': now,
        'completed_at': now,
      };

      // 1. Enregistre que la leçon est finie
      await Supabase.instance.client.from('user_progress').upsert(
        data, 
        onConflict: 'user_id,lesson_id'
      ); 

      // ✅ 2. Synchronise le pourcentage du cours complet
      if (formationId != null) {
        await _syncEnrollmentProgress(userId, formationId);
      }

      state = state.copyWith(isUpdating: false, isCompleted: true, progress: 1.0);
      return true;
    } catch (e) {
      debugPrint('Erreur Supabase lors de la complétion : $e');
      state = state.copyWith(isUpdating: false, error: 'Impossible de marquer la leçon comme terminée.');
      return false;
    }
  }

  // ✅ NOUVELLE MÉTHODE : Calcule et sauvegarde le pourcentage total du cours
  Future<void> _syncEnrollmentProgress(String userId, String formationId) async {
    try {
      final supabase = Supabase.instance.client;

      final formationData = await supabase
          .from('formations')
          .select('modules(lessons(id))')
          .eq('id', formationId)
          .maybeSingle();

      if (formationData == null) return;

      int totalLessons = 0;
      final courseLessonIds = <String>[];

      for (final module in formationData['modules'] ?? []) {
        for (final lesson in module['lessons'] ?? []) {
          totalLessons++;
          courseLessonIds.add(lesson['id'].toString());
        }
      }

      if (totalLessons == 0) return;

      final completedData = await supabase
          .from('user_progress')
          .select('lesson_id')
          .eq('user_id', userId)
          .eq('status', 'completed');

      int completedCount = 0;
      for (final row in (completedData as List)) {
        if (courseLessonIds.contains(row['lesson_id'].toString())) {
          completedCount++;
        }
      }

      final double overallProgress = completedCount / totalLessons;

      await supabase.from('enrollments').update({
        'progress': overallProgress,
        'status': overallProgress >= 1.0 ? 'completed' : 'in_progress',
      }).eq('uid', userId).eq('formation_id', formationId);

      // ✅ Certificat auto à 100 %
      if (overallProgress >= 1.0) {
        try {
          final cert = await CertificateService.instance.issueIfNeeded(
            userId: userId,
            formationId: formationId,
          );
          if (cert != null) {
            debugPrint('📜 Certificat émis : ${cert.verificationHash}');
          }
        } catch (e) {
          debugPrint('Certificat non émis : $e');
        }
      }
    } catch (e) {
      debugPrint('Erreur de synchronisation globale : $e');
    }
  }
}
// ============================================================
// WIDGET UI (ConsumerWidget)
// ============================================================
class FormationLessonPlayer extends ConsumerWidget {
  final String lessonId;
  final String? formationId;
  final String? moduleId;
  final Lesson? lesson;
  final VoidCallback? onComplete;

  const FormationLessonPlayer({
    super.key,
    required this.lessonId,
    this.formationId,
    this.moduleId,
    this.lesson,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (lesson == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erreur'), leading: const BackButton()),
        body: const Center(child: Text('Détails de la leçon introuvables.')),
      );
    }

    final safeLesson = lesson!;
    
    final state = ref.watch(lessonProgressProvider(lessonId));
    final notifier = ref.read(lessonProgressProvider(lessonId).notifier);

    ref.listen<LessonProgressState>(lessonProgressProvider(lessonId), (previous, next) {
      if (next.error != null && (previous?.error != next.error)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: const Color(0xFFFF5B3D)),
        );
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          safeLesson.title,
          style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E), fontSize: 16),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A2E)),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 20),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            IconButton(
              icon: Icon(
                state.isCompleted ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: state.isCompleted ? const Color(0xFF2ECC71) : const Color(0xFF7386A8),
              ),
              onPressed: state.isCompleted
                  ? null
                  : () async {
                      // ✅ Envoi de formationId
                      final success = await notifier.markAsCompleted(formationId);
                      if (success && onComplete != null) onComplete!();
                    },
            ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2D6CDF)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. CONTENU PRINCIPAL (vidéo / quiz / texte) EN HAUT
                  _buildLessonContent(context, safeLesson, state, notifier),

                  const SizedBox(height: 24),

                  // 2. DESCRIPTION / TEXTE EN BAS
                  if (safeLesson.description != null &&
                      safeLesson.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Text(
                        safeLesson.description!,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF475569),
                          height: 1.6,
                        ),
                      ),
                    ),

                  // Si type vidéo mais content texte aussi utile :
                  // (optionnel) afficher content texte sous la vidéo
                  if (safeLesson.type == 'video' &&
                      safeLesson.content != null &&
                      safeLesson.content!.isNotEmpty &&
                      !safeLesson.content!.startsWith('http'))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Text(
                        safeLesson.content!,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF1E293B),
                          height: 1.6,
                        ),
                      ),
                    ),

                  if (!state.isCompleted &&
                      safeLesson.type != 'video' &&
                      safeLesson.type != 'quiz')
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: state.isUpdating
                            ? null
                            : () async {
                                final success =
                                    await notifier.markAsCompleted(formationId);
                                if (success && onComplete != null) onComplete!();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D6CDF),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: state.isUpdating
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Marquer comme terminé',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),

                  if (state.isCompleted)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2ECC71).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF2ECC71).withOpacity(0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: Color(0xFF2ECC71)),
                          SizedBox(width: 8),
                          Text(
                            'Leçon terminée ! 🎉',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2ECC71),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildLessonContent(BuildContext context, Lesson currentLesson, LessonProgressState state, LessonProgressNotifier notifier) {
    if (currentLesson.type == 'video' && currentLesson.content != null && currentLesson.content!.isNotEmpty) {
      return Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
        ),
        child: FormationVideoPlayer(
          videoUrl: currentLesson.content!,
          onProgress: (progress) => notifier.updateProgress(progress),
          onComplete: () async {
            // ✅ Envoi de formationId
            final success = await notifier.markAsCompleted(formationId);
            if (success && onComplete != null) onComplete!();
          },
        ),
      );
    } 
    
    if (currentLesson.type == 'quiz' && currentLesson.evaluation != null) {
      return FormationEvaluationWidget(
        evaluation: currentLesson.evaluation!,
        onComplete: (score, total) async {
          // ✅ Envoi de formationId
          final success = await notifier.markAsCompleted(formationId);
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Quiz terminé ! Score : $score/$total'),
                backgroundColor: const Color(0xFF2ECC71),
                behavior: SnackBarBehavior.floating,
              ),
            );
            if (onComplete != null) onComplete!();
          }
        },
      );
    } 
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        currentLesson.content ?? 'Contenu texte de la leçon non disponible.',
        style: const TextStyle(color: Color(0xFF1E293B), fontSize: 15, height: 1.6),
      ),
    );
  }
}
