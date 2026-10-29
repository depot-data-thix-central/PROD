// lib/presentation/education/pages/formation_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/formation.dart';
import '../models/lesson.dart';
import 'package:thix_id/presentation/education/providers/education_provider.dart'; 
import '../widgets/common/education_empty_state.dart';
import '../widgets/common/education_loading_shimmer.dart';
import '../widgets/formation_detail/formation_module_list.dart';

// ==========================================
// CONSTANTES DE STYLE (UI Entreprise)
// ==========================================
class _C {
  static const bg = Color(0xFFF8FAFC);
  static const surface = Colors.white;
  static const primary = Color(0xFF2D6CDF);
  static const primaryDark = Color(0xFF1E4FB8);
  static const green = Color(0xFF10B981);
  static const orange = Color(0xFFF59E0B);
  static const textMain = Color(0xFF1E293B);
  static const textMuted = Color(0xFF7386A8);
  static const border = Color(0xFFE2E8F0);
  static const red = Color(0xFFEF4444);
}

// ==========================================
// PAGE PRINCIPALE
// ==========================================
class FormationDetailPage extends ConsumerStatefulWidget {
  final String formationId;
  const FormationDetailPage({super.key, required this.formationId});

  @override
  ConsumerState<FormationDetailPage> createState() => _FormationDetailPageState();
}

class _FormationDetailPageState extends ConsumerState<FormationDetailPage> {
  bool _isEnrolling = false;

  @override
  Widget build(BuildContext context) {
    final formationId = widget.formationId;
    final formationAsync = ref.watch(formationDetailProvider(formationId));
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final enrollmentAsync = userId == null 
        ? null 
        : ref.watch(enrollmentProvider((userId: userId, formationId: formationId)));

    return formationAsync.when(
      loading: () => const Scaffold(body: EducationLoadingShimmer()),
      error: (e, _) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 64, color: _C.red),
              const SizedBox(height: 16),
              Text('Erreur: $e', style: const TextStyle(color: _C.red, fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Retour'),
              ),
            ],
          ),
        ),
      ),
      data: (formation) {
        if (formation == null) {
          return Scaffold(
            body: EducationEmptyState(
              title: 'Formation introuvable',
              subtitle: 'Cette formation n\'existe pas ou a été supprimée.',
              icon: Icons.school_rounded,
              buttonText: 'Retour',
              onButtonPressed: () => context.pop(),
            ),
          );
        }

        final isEnrolled = enrollmentAsync?.value != null;
        final progress = isEnrolled ? ((enrollmentAsync?.value?['progress'] ?? 0) as num) : 0.0;

        return Scaffold(
          backgroundColor: _C.bg,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 280.0,
                pinned: true,
                backgroundColor: _C.surface,
                elevation: 0,
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (formation.imageUrl != null && formation.imageUrl!.isNotEmpty)
                        Image.network(
                          formation.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
                        )
                      else
                        _buildPlaceholderImage(),

                      // Gradient overlay amélioré
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.3),
                              Colors.black.withOpacity(0.7),
                            ],
                            stops: const [0.3, 0.6, 1.0],
                          ),
                        ),
                      ),

                      // Badge de certification
                      if (formation.certificateEnabled)
                        Positioned(
                          top: 60,
                          right: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _C.green,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: _C.green.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'Certifié',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Titre et sous-titre
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formation.title,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (formation.instructorName != null && formation.instructorName!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Colors.white24,
                                    child: const Icon(Icons.person, size: 14, color: Colors.white),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Par ${formation.instructorName!}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section stats
                    _buildStatsSection(formation),
                    
                    const SizedBox(height: 16),

                    // Section inscription ou progression
                    _buildEnrollmentSection(context, ref, formation, isEnrolled, progress, userId),

                    const SizedBox(height: 24),

                    // Badges de catégorie et niveau
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildBadgesSection(formation),
                    ),

                    const SizedBox(height: 24),

                    // Description
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildDescription(formation),
                    ),

                    const SizedBox(height: 32),

                    // Programme du cours
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _C.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.list_alt_rounded, color: _C.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Programme du cours',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: _C.textMain,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),

                    FormationModuleList(
                      formation: formation,
                      onLessonTap: (lesson) => _openLesson(context, lesson, isEnrolled),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _C.primary.withOpacity(0.2),
            _C.primary.withOpacity(0.05),
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.school_rounded, size: 80, color: _C.primary),
      ),
    );
  }

  Widget _buildStatsSection(Formation formation) {
    final totalLessons = formation.modules?.fold<int>(0, (sum, m) => sum + (m.lessons?.length ?? 0)) ?? 0;
    final totalHours = formation.duration ~/ 3600;
    final totalMinutes = (formation.duration % 3600) ~/ 60;
    final durationText = totalHours > 0 ? '${totalHours}h ${totalMinutes}min' : '${totalMinutes} min';

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            Icons.people_rounded,
            '${formation.enrollments?.length ?? 0}',
            'Élèves',
            _C.primary,
          ),
          _buildStatDivider(),
          _buildStatItem(
            Icons.video_library_rounded,
            '$totalLessons',
            'Leçons',
            _C.orange,
          ),
          _buildStatDivider(),
          _buildStatItem(
            Icons.timer_rounded,
            durationText,
            'Durée',
            _C.green,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _C.textMain,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: _C.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 40,
      color: _C.border,
    );
  }

  Widget _buildBadgesSection(Formation formation) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (formation.category != null)
          _buildBadge(
            Icons.category_rounded,
            formation.category?.name ?? 'Non catégorisé',
            _C.primary,
          ),
        if (formation.level.isNotEmpty)
          _buildBadge(
            _getLevelIcon(formation.level),
            _getLevelLabel(formation.level),
            _getLevelColor(formation.level),
          ),
        if (formation.language != null && formation.language!.isNotEmpty)
          _buildBadge(
            Icons.language_rounded,
            formation.language!.toUpperCase(),
            _C.textMuted,
          ),
      ],
    );
  }

  Widget _buildBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getLevelIcon(String level) {
    switch (level) {
      case 'beginner':
        return Icons.sentiment_satisfied_rounded;
      case 'intermediate':
        return Icons.sentiment_neutral_rounded;
      case 'advanced':
        return Icons.sentiment_very_satisfied_rounded;
      default:
        return Icons.trending_up_rounded;
    }
  }

  String _getLevelLabel(String level) {
    switch (level) {
      case 'beginner':
        return 'Débutant';
      case 'intermediate':
        return 'Intermédiaire';
      case 'advanced':
        return 'Avancé';
      default:
        return level;
    }
  }

  Color _getLevelColor(String level) {
    switch (level) {
      case 'beginner':
        return _C.green;
      case 'intermediate':
        return _C.orange;
      case 'advanced':
        return _C.red;
      default:
        return _C.textMuted;
    }
  }

  Widget _buildDescription(Formation formation) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _C.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.info_outline_rounded, color: _C.primary, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'À propos de ce cours',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _C.textMain,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          formation.description,
          style: const TextStyle(
            fontSize: 15,
            height: 1.7,
            color: _C.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildEnrollmentSection(
    BuildContext context,
    WidgetRef ref,
    Formation formation,
    bool isEnrolled,
    double progress,
    String? userId,
  ) {
    if (isEnrolled) {
      final progressPercent = (progress * 100).toInt();
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.green.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: _C.green.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _C.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: _C.green, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Inscrit à ce cours',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _C.textMain,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Votre progression',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _C.textMain,
                  ),
                ),
                Text(
                  '$progressPercent%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: _C.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: _C.border,
                valueColor: const AlwaysStoppedAnimation<Color>(_C.green),
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _continueLearning(context, formation),
                icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.white),
                label: Text(
                  progressPercent == 0 ? 'Commencer le cours' : 'Continuer l\'apprentissage',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.green,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _C.surface,
            _C.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.primary.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: _C.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Prix du cours',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _C.textMuted,
                ),
              ),
              if (formation.price > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _C.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${formation.price.toInt()} ${formation.currency}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: _C.primary,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _C.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.card_giftcard_rounded, color: _C.green, size: 20),
                      SizedBox(width: 6),
                      Text(
                        'Gratuit',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: _C.green,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isEnrolling ? null : () => _enrollInCourse(context, ref, formation.id, userId),
              icon: _isEnrolling
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.school_rounded, color: Colors.white, size: 24),
              label: Text(
                _isEnrolling ? 'Inscription en cours...' : 'S\'inscrire maintenant',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ SIMPLIFIÉ : Inscription directe sans vérification THIX ID
  Future<void> _enrollInCourse(
    BuildContext context,
    WidgetRef ref,
    String formationId,
    String? userId,
  ) async {
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez vous connecter pour vous inscrire.'),
          backgroundColor: _C.orange,
        ),
      );
      return;
    }

    setState(() => _isEnrolling = true);

    try {
      // Essayer d'abord via le provider
      bool isSuccess = false;
      try {
        isSuccess = await ref.read(enrollProvider.notifier).enroll(
              userId: userId,
              formationId: formationId,
            );
      } catch (_) {
        isSuccess = false;
      }

      // Fallback : insertion directe si le provider a échoué
      if (!isSuccess) {
        await Supabase.instance.client.from('enrollments').insert({
          'uid': userId,
          'formation_id': formationId,
          'status': 'active',
          'progress': 0.0,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Inscription réussie ! Bon apprentissage !'),
            backgroundColor: _C.green,
          ),
        );

        // Invalidation pour rafraîchir l'état
        ref.invalidate(enrollmentProvider((userId: userId, formationId: formationId)));
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('duplicate key')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vous êtes déjà inscrit à ce cours.'),
              backgroundColor: _C.primary,
            ),
          );
          ref.invalidate(enrollmentProvider((userId: userId, formationId: formationId)));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de l\'inscription : $e'),
              backgroundColor: _C.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isEnrolling = false);
      }
    }
  }

  void _openLesson(BuildContext context, Lesson lesson, bool isEnrolled) {
    if (!isEnrolled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez vous inscrire pour accéder au contenu.'),
          backgroundColor: _C.orange,
        ),
      );
      return;
    }
    context.push(
      '/education/lesson/${lesson.id}',
      extra: {
        'formationId': widget.formationId,
        'moduleId': lesson.moduleId,
        'lesson': lesson,
      },
    );
  }

  void _continueLearning(BuildContext context, Formation formation) {
    if (formation.modules != null && formation.modules!.isNotEmpty) {
      for (var module in formation.modules!) {
        if (module.lessons != null && module.lessons!.isNotEmpty) {
          _openLesson(context, module.lessons!.first, true);
          return;
        }
      }
    }
    context.push('/education/my-learning');
  }
}
