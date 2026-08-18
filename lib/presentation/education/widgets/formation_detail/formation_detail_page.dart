import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/formation.dart';
import '../models/lesson.dart';
import '../providers/education_providers.dart';
import '../widgets/common/education_empty_state.dart';
import '../widgets/common/education_loading_shimmer.dart';
import '../widgets/formation_detail/formation_module_list.dart';

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
      error: (e, _) => Scaffold(body: Center(child: Text('Erreur: $e'))),
      data: (formation) {
        if (formation == null) {
          return Scaffold(body: EducationEmptyState(title: 'Formation introuvable', subtitle: 'Cette formation n\'existe pas ou a été supprimée.', icon: Icons.school_rounded, buttonText: 'Retourner à la liste', onButtonPressed: () => context.pop()));
        }
        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(title: Text(formation.title, style: const TextStyle(fontWeight: FontWeight.w800)), backgroundColor: Colors.white, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop())),
          body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildHeader(formation),
            const SizedBox(height: 16),
            _buildDescription(formation),
            const SizedBox(height: 16),
            _buildInfoRow(formation),
            const SizedBox(height: 16),
            _buildEnrollButton(context, ref, formation, enrollmentAsync, userId),
            const SizedBox(height: 16),
            FormationModuleList(formation: formation, onLessonTap: (lesson) => _openLesson(context, lesson)),
            const SizedBox(height: 24),
          ])),
        );
      },
    );
  }

  Widget _buildHeader(Formation formation) {
    return Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: const Color(0xFF0A1F44).withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(formation.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
      const SizedBox(height: 8),
      if (formation.instructorName!= null && formation.instructorName!.isNotEmpty) Row(children: [const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFF7386A8)), const SizedBox(width: 4), Text(formation.instructorName!, style: const TextStyle(color: Color(0xFF7386A8), fontSize: 14))]),
      const SizedBox(height: 4),
      Row(children: [const Icon(Icons.school_rounded, size: 16, color: Color(0xFF7386A8)), const SizedBox(width: 4), Text(formation.category?.name ?? 'Non catégorisé', style: const TextStyle(color: Color(0xFF7386A8), fontSize: 14)), const Spacer(), if (formation.level.isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF2D6CDF).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Text(formation.level == 'beginner'? 'Débutant' : formation.level == 'intermediate'? 'Intermédiaire' : 'Avancé', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2D6CDF))))]),
      const SizedBox(height: 8),
      Row(children: [const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF7386A8)), const SizedBox(width: 4), Text('${formation.duration ~/ 60}h ${formation.duration % 60}min', style: const TextStyle(color: Color(0xFF7386A8), fontSize: 14)), const Spacer(), if (formation.price > 0) Text('${formation.price.toInt()} ${formation.currency}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF2D6CDF))) else Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF2D6CDF).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Text('Gratuit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2D6CDF))))]),
    ]));
  }

  Widget _buildDescription(Formation f) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: const Color(0xFF0A1F44).withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Description', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))), const SizedBox(height: 8), Text(f.description, style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF1A1A2E)))]));
  
  Widget _buildInfoRow(Formation f) {
    final totalLessons = f.modules?.fold<int>(0, (sum, m) => sum + (m.lessons?.length ?? 0)) ?? 0;
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: const Color(0xFF0A1F44).withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))]), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      _info(Icons.people_rounded, '${f.enrollments?.length ?? 0}', 'Élèves'),
      _info(Icons.video_library_rounded, '$totalLessons', 'Leçons'),
      _info(Icons.star_rounded, f.rating.toStringAsFixed(1), 'Note'),
    ]));
  }
  Widget _info(IconData i, String v, String l) => Column(children: [Icon(i, color: const Color(0xFF2D6CDF)), const SizedBox(height: 4), Text(v, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)), Text(l, style: const TextStyle(fontSize: 12, color: Color(0xFF7386A8)))]);

  Widget _buildEnrollButton(BuildContext context, WidgetRef ref, Formation formation, AsyncValue? enrollmentAsync, String? userId) {
    final isEnrolled = enrollmentAsync?.value != null;
    final progress = enrollmentAsync?.value?['progress'] ?? 0;
    if (isEnrolled) {
      return Container(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16), decoration: BoxDecoration(color: const Color(0xFF2D6CDF).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.check_circle_rounded, color: Color(0xFF2D6CDF), size: 20), const SizedBox(width: 8), Text('Inscrit · ${(progress * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2D6CDF)))]));
    }
    return SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
      onPressed: () async {
        if (userId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez vous connecter'))); return; }
        final ok = await ref.read(enrollProvider.notifier).enroll(userId: userId, formationId: formation.id);
        if (ok && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inscription réussie !')));
      },
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D6CDF), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      child: const Text('S\'inscrire à cette formation', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
    ));
  }

  void _openLesson(BuildContext context, Lesson lesson) {
    context.push('/education/lesson/${lesson.id}', extra: {'formationId': formationId, 'moduleId': lesson.moduleId, 'lesson': lesson});
  }
}
