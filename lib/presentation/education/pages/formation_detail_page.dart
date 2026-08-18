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
  static const green = Color(0xFF10B981);
  static const textMain = Color(0xFF1E293B);
  static const textMuted = Color(0xFF7386A8);
  static const border = Color(0xFFE2E8F0);
  static const red = Color(0xFFEF4444);
}

// ==========================================
// PAGE PRINCIPALE
// ==========================================
class FormationDetailPage extends ConsumerWidget {
  final String formationId;
  const FormationDetailPage({super.key, required this.formationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formationAsync = ref.watch(formationDetailProvider(formationId));
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final enrollmentAsync = userId == null ? null : ref.watch(enrollmentProvider((userId: userId, formationId: formationId)));

    return formationAsync.when(
      loading: () => const Scaffold(body: EducationLoadingShimmer()),
      error: (e, _) => Scaffold(body: Center(child: Text('Erreur: $e', style: const TextStyle(color: _C.red)))),
      data: (formation) {
        if (formation == null) {
          return Scaffold(body: EducationEmptyState(title: 'Formation introuvable', subtitle: 'Cette formation n\'existe pas.', icon: Icons.school_rounded, buttonText: 'Retour', onButtonPressed: () => context.pop()));
        }

        final isEnrolled = enrollmentAsync?.value != null;

        return Scaffold(
          backgroundColor: _C.bg,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 250.0,
                pinned: true,
                backgroundColor: _C.surface,
                elevation: 0,
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), 
                    onPressed: () => context.pop()
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
                      
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black54, Colors.transparent, Colors.black87],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 16, left: 20, right: 20,
                        child: Text(
                          formation.title,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAuthorAndMeta(formation),
                      const SizedBox(height: 24),
                      _buildEnrollmentSection(context, ref, formation, isEnrolled, enrollmentAsync, userId),
                      const SizedBox(height: 24),
                      _buildInfoRow(formation),
                      const SizedBox(height: 24),
                      _buildDescription(formation),
                      const SizedBox(height: 32),
                      
                      const Text('Programme du cours', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _C.textMain)),
                      const SizedBox(height: 16),
                      FormationModuleList(
                        formation: formation,
                        onLessonTap: (lesson) => _openLesson(context, lesson, isEnrolled),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
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
      color: _C.primary.withOpacity(0.1),
      child: const Center(
        child: Icon(Icons.school_rounded, size: 64, color: _C.primary),
      ),
    );
  }

  Widget _buildAuthorAndMeta(Formation formation) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (formation.instructorName != null && formation.instructorName!.isNotEmpty)
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: _C.primary.withOpacity(0.2),
                child: const Icon(Icons.person, size: 16, color: _C.primary),
              ),
              const SizedBox(width: 10),
              Text(
                formation.instructorName!,
                style: const TextStyle(color: _C.textMain, fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: _C.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(
                formation.category?.name ?? 'Non catégorisé',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _C.primary),
              ),
            ),
            const SizedBox(width: 10),
            if (formation.level.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: _C.border, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  formation.level == 'beginner' ? 'Débutant' : formation.level == 'intermediate' ? 'Intermédiaire' : 'Avancé',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _C.textMain),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDescription(Formation formation) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('À propos de ce cours', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _C.textMain)),
        const SizedBox(height: 12),
        Text(formation.description, style: const TextStyle(fontSize: 14, height: 1.6, color: _C.textMuted)),
      ],
    );
  }

  Widget _buildInfoRow(Formation formation) {
    final totalLessons = formation.modules?.fold<int>(0, (sum, m) => sum + (m.lessons?.length ?? 0)) ?? 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildInfoItem(Icons.people_rounded, '${formation.enrollments?.length ?? 0}', 'Élèves'),
        _buildInfoItem(Icons.video_library_rounded, '$totalLessons', 'Leçons'),
        _buildInfoItem(Icons.timer_rounded, '${formation.duration ~/ 60}h', 'Durée'),
      ],
    );
  }

  Widget _buildInfoItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _C.surface, shape: BoxShape.circle, border: Border.all(color: _C.border)),
          child: Icon(icon, color: _C.primary, size: 24),
        ),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _C.textMain)),
        Text(label, style: const TextStyle(fontSize: 12, color: _C.textMuted, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildEnrollmentSection(BuildContext context, WidgetRef ref, Formation formation, bool isEnrolled, AsyncValue? enrollmentAsync, String? userId) {
    if (isEnrolled) {
      final progress = ((enrollmentAsync?.value?['progress'] ?? 0) * 100).toInt();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Votre progression', style: TextStyle(fontWeight: FontWeight.w700, color: _C.textMain)),
              Text('$progress%', style: const TextStyle(fontWeight: FontWeight.w800, color: _C.primary)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress / 100,
            backgroundColor: _C.border,
            color: _C.primary,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => _continueLearning(context, formation),
              icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.white),
              label: const Text('Continuer l\'apprentissage', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.primary.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: _C.primary.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Prix du cours', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _C.textMuted)),
              if (formation.price > 0)
                Text('${formation.price.toInt()} ${formation.currency}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _C.textMain))
              else
                const Text('Gratuit', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _C.green)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                if (userId == null) { 
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez vous connecter pour vous inscrire.'))); 
                  return; 
                }
                _showThixIdVerificationSheet(context, ref, userId, formation.id);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('S\'inscrire avec THIX ID', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  void _openLesson(BuildContext context, Lesson lesson, bool isEnrolled) {
    if (!isEnrolled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez vous inscrire pour accéder au contenu.')));
      return;
    }
    context.push('/education/lesson/${lesson.id}', extra: {'formationId': formationId, 'moduleId': lesson.moduleId, 'lesson': lesson});
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

  void _showThixIdVerificationSheet(BuildContext context, WidgetRef ref, String userId, String formationId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _ThixIdVerificationWidget(userId: userId, formationId: formationId, ref: ref),
      ),
    );
  }
}

// ============================================================================
// WIDGET MODAL : VÉRIFICATION THIX ID
// ============================================================================
class _ThixIdVerificationWidget extends StatefulWidget {
  final String userId;
  final String formationId;
  final WidgetRef ref;

  const _ThixIdVerificationWidget({required this.userId, required this.formationId, required this.ref});

  @override
  State<_ThixIdVerificationWidget> createState() => _ThixIdVerificationWidgetState();
}

class _ThixIdVerificationWidgetState extends State<_ThixIdVerificationWidget> {
  final _thixIdController = TextEditingController();
  bool _isVerifying = false;
  String? _errorMessage;

  Future<void> _verifyAndEnroll() async {
    final thixIdInput = _thixIdController.text.trim();
    if (thixIdInput.isEmpty) {
      setState(() => _errorMessage = "Veuillez entrer votre numéro THIX ID.");
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('thix_id', thixIdInput) 
          .eq('id', widget.userId)           
          .maybeSingle();

      if (response == null) {
        setState(() {
          _errorMessage = "Échec de l'authentification : Le numéro THIX ID est invalide ou ne correspond pas à votre compte.";
          _isVerifying = false;
        });
        return;
      }

      bool isSuccess = false;
      
      try {
        isSuccess = await widget.ref.read(enrollProvider.notifier).enroll(userId: widget.userId, formationId: widget.formationId);
      } catch (_) {
        isSuccess = false;
      }

      if (!isSuccess) {
        await Supabase.instance.client.from('enrollments').insert({
          'uid': widget.userId, 
          'formation_id': widget.formationId,
          'status': 'active',
          'progress': 0.0,
          'created_at': DateTime.now().toIso8601String(),
        });
        isSuccess = true;
      }
      
      if (mounted) {
        context.pop(); // Fermeture de la modale
        
        if (isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vérification réussie. Inscription validée !'), backgroundColor: _C.green));
          
          // 1. Invalidation de l'état pour que la page actuelle se mette à jour
          widget.ref.invalidate(enrollmentProvider((userId: widget.userId, formationId: widget.formationId)));
          
          // 2. Redirection automatique vers "Mes cours" après une légère pause pour laisser le temps de lire le message de succès
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (context.mounted) {
              context.push('/education/my-learning');
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        context.pop(); 
        if (e.toString().contains('duplicate key')) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Identité vérifiée. Vous êtes déjà inscrit à ce cours.'), backgroundColor: _C.primary));
          widget.ref.invalidate(enrollmentProvider((userId: widget.userId, formationId: widget.formationId)));
          
          // Redirection également si l'utilisateur était déjà inscrit
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (context.mounted) {
              context.push('/education/my-learning');
            }
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur détaillée : $e'), backgroundColor: _C.red));
        }
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  void dispose() {
    _thixIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _C.primary.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.security_rounded, color: _C.primary)),
              const SizedBox(width: 12),
              const Text('Passerelle de sécurité', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _C.textMain)),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Veuillez confirmer votre identité en saisissant votre numéro THIX ID avant de finaliser votre inscription.', style: TextStyle(color: _C.textMuted, fontSize: 14, height: 1.5)),
          const SizedBox(height: 24),
          TextField(
            controller: _thixIdController,
            decoration: InputDecoration(
              labelText: 'Numéro THIX ID',
              prefixIcon: const Icon(Icons.badge_rounded, color: _C.textMuted),
              filled: true,
              fillColor: _C.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _C.primary, width: 1.5)),
              errorText: _errorMessage,
            ),
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _verifyAndEnroll(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isVerifying ? null : _verifyAndEnroll,
              style: ElevatedButton.styleFrom(backgroundColor: _C.textMain, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: _isVerifying 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Vérifier et S\'inscrire', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
