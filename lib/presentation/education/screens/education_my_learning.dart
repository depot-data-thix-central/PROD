// lib/presentation/education/pages/education_my_learning.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:thix_id/presentation/education/providers/education_provider.dart'; 
import 'package:thix_id/presentation/education/widgets/formation_detail/formation_module_list.dart'; // Pour accéder à completedLessonsProvider
import '../widgets/common/education_empty_state.dart';
import '../widgets/common/education_loading_shimmer.dart';
import '../models/formation.dart';

class EducationMyLearning extends ConsumerStatefulWidget {
  const EducationMyLearning({super.key});

  @override
  ConsumerState<EducationMyLearning> createState() => _EducationMyLearningState();
}

class _EducationMyLearningState extends ConsumerState<EducationMyLearning> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 300) {
      final userId = ref.read(currentUserIdProvider).value;
      if (userId != null) {
        ref.read(myEnrollmentsProvider(userId).notifier).loadMore();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider).value; 

    if (userId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7FAFF),
        appBar: AppBar(title: const Text('Mon apprentissage', style: TextStyle(fontWeight: FontWeight.w800)), backgroundColor: Colors.white),
        body: const Center(child: Text('Non connecté')),
      );
    }

    final enrollmentsAsync = ref.watch(myEnrollmentsProvider(userId));

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFF),
      appBar: AppBar(
        title: const Text('Mon apprentissage', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A2E)), onPressed: () => Navigator.pop(context)),
      ),
      body: enrollmentsAsync.when(
        loading: () => const EducationLoadingShimmer(),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (enrollments) {
          if (enrollments.isEmpty) {
            return EducationEmptyState(
              title: 'Aucune formation en cours',
              subtitle: 'Inscrivez-vous à une formation pour commencer à apprendre',
              icon: Icons.play_circle_outline_rounded,
              buttonText: 'Découvrir les formations',
              onButtonPressed: () => context.go('/education'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myEnrollmentsProvider(userId));
              ref.invalidate(completedLessonsProvider);
            },
            color: const Color(0xFF2D6CDF),
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: enrollments.length + 1,
              itemBuilder: (context, index) {
                if (index == enrollments.length) {
                  final hasMore = ref.read(myEnrollmentsProvider(userId).notifier).hasMore;
                  return hasMore ? const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator(color: Color(0xFF2D6CDF)))) : const SizedBox(height: 32);
                }
                final enrollment = enrollments[index];
                final formation = enrollment.formation;
                if (formation == null) return const SizedBox();
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CompactEnrollmentCard(
                    formation: formation,
                    fallbackProgress: enrollment.progress?.toDouble(),
                    onTap: () => context.push('/education/formation/${formation.id}'),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Carte compacte ConsumerWidget pour calculer la progression en direct depuis user_progress
class _CompactEnrollmentCard extends ConsumerWidget {
  final Formation formation;
  final double? fallbackProgress;
  final VoidCallback onTap;

  const _CompactEnrollmentCard({
    required this.formation,
    required this.fallbackProgress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // On écoute les leçons complétées en temps réel depuis user_progress
    final completedLessonsAsync = ref.watch(completedLessonsProvider);

    double calculatedProgress = fallbackProgress ?? 0.0;

    completedLessonsAsync.whenData((completedIds) {
      int totalLessons = 0;
      int completedCount = 0;

      if (formation.modules != null) {
        for (var module in formation.modules!) {
          if (module.lessons != null) {
            for (var lesson in module.lessons!) {
              totalLessons++;
              if (completedIds.contains(lesson.id)) {
                completedCount++;
              }
            }
          }
        }
      }

      if (totalLessons > 0) {
        calculatedProgress = completedCount / totalLessons;
      }
    });

    final p = calculatedProgress.clamp(0.0, 1.0);
    final percentage = (p * 100).toInt();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          children: [
            // Miniature compacte
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: formation.imageUrl != null && formation.imageUrl!.isNotEmpty
                  ? Image.network(formation.imageUrl!, width: 64, height: 64, fit: BoxFit.cover)
                  : Container(
                      width: 64,
                      height: 64,
                      color: const Color(0xFF2D6CDF).withOpacity(0.1),
                      child: const Icon(Icons.school_rounded, color: Color(0xFF2D6CDF), size: 28),
                    ),
            ),
            const SizedBox(width: 14),
            // Informations et barre de progression dynamique
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formation.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: p,
                            backgroundColor: const Color(0xFFF1F5F9),
                            color: p >= 1.0 ? const Color(0xFF10B981) : const Color(0xFF2D6CDF),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$percentage%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: p >= 1.0 ? const Color(0xFF10B981) : const Color(0xFF2D6CDF),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF7386A8), size: 20),
          ],
        ),
      ),
    );
  }
}
