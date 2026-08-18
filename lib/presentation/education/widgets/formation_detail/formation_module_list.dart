// lib/presentation/education/widgets/formation_detail/formation_module_list.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/presentation/education/models/formation.dart';
import 'package:thix_id/presentation/education/models/module.dart';
import 'package:thix_id/presentation/education/models/lesson.dart';

// ============================================================
// PROVIDER GLOBAL (Optimisé pour des millions d'utilisateurs)
// ============================================================
// Télécharge TOUTES les leçons complétées en 1 seule requête SQL
final completedLessonsProvider = AsyncNotifierProvider<CompletedLessonsNotifier, Set<String>>(
  CompletedLessonsNotifier.new,
);

class CompletedLessonsNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return {};

    try {
      final res = await Supabase.instance.client
          .from('user_progress') // ✅ CORRECTION : La vraie table Supabase
          .select('lesson_id')
          .eq('user_id', userId)
          .eq('status', 'completed');

      // Stocke les IDs dans un Set pour une recherche ultra-rapide (O(1))
      return (res as List).map((e) => e['lesson_id'].toString()).toSet();
    } catch (e) {
      debugPrint('Erreur de chargement des progressions: $e');
      return {}; 
    }
  }

  // Permet de mettre à jour la barre de progression instantanément quand l'étudiant finit une leçon
  void markLessonAsCompletedLocal(String lessonId) {
    if (state.value != null && !state.value!.contains(lessonId)) {
      state = AsyncData({...state.value!, lessonId});
    }
  }
}

// ============================================================
// WIDGET UI (ConsumerWidget)
// ============================================================
class FormationModuleList extends ConsumerWidget {
  final Formation formation;
  final Function(Lesson lesson) onLessonTap;

  const FormationModuleList({
    super.key,
    required this.formation,
    required this.onLessonTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = formation.modules ?? [];
    
    // On écoute le Provider global
    final completedLessonsAsync = ref.watch(completedLessonsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Modules',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E)),
        ),
        const SizedBox(height: 12),
        
        // Affichage conditionnel selon l'état du chargement réseau
        completedLessonsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: Color(0xFF2D6CDF)),
            )
          ),
          error: (_, __) => const Text('Impossible de charger la progression.'),
          data: (completedLessonIds) {
            return Column(
              children: modules.map((module) => _buildModuleTile(module, completedLessonIds, context)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildModuleTile(Module module, Set<String> completedLessonIds, BuildContext context) {
    final lessons = module.lessons ?? [];
    final totalLessons = lessons.length;
    
    // Calcul de la progression du module localement en O(N) très rapide
    final completedLessons = lessons.where((l) => completedLessonIds.contains(l.id)).length;
    final progress = totalLessons > 0 ? completedLessons / totalLessons : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: const Color(0xFF2D6CDF),
          collapsedIconColor: const Color(0xFF7386A8),
          title: Text(
            module.title,
            style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E), fontSize: 15),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                '$totalLessons leçon(s) · ${(progress * 100).toInt()}% terminé',
                style: const TextStyle(fontSize: 12, color: Color(0xFF7386A8), fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: const Color(0xFFF1F5F9),
                  color: progress >= 1.0 ? const Color(0xFF2ECC71) : const Color(0xFF2D6CDF),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
          children: [
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Column(
                children: lessons.map((lesson) {
                  final isDone = completedLessonIds.contains(lesson.id);
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDone ? const Color(0xFF2ECC71).withOpacity(0.1) : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getLessonIcon(lesson.type),
                        size: 16,
                        color: isDone ? const Color(0xFF2ECC71) : const Color(0xFF7386A8),
                      ),
                    ),
                    title: Text(
                      lesson.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDone ? const Color(0xFF7386A8) : const Color(0xFF1A1A2E),
                        decoration: isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    subtitle: Text(
                      _getLessonDurationText(lesson),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                    trailing: isDone
                        ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2ECC71), size: 22)
                        : const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF2D6CDF), size: 28),
                    onTap: () => onLessonTap(lesson),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getLessonIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'video': return Icons.play_arrow_rounded;
      case 'quiz': return Icons.quiz_rounded;
      case 'text': return Icons.article_rounded;
      default: return Icons.import_contacts_rounded;
    }
  }

  String _getLessonDurationText(Lesson lesson) {
    if (lesson.durationMinutes != null && lesson.durationMinutes! > 0) {
      return '${lesson.durationMinutes} min';
    }
    return lesson.type == 'quiz' ? 'Évaluation' : 'Lecture';
  }
}
