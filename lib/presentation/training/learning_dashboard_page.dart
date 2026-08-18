import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/training_enrollment.dart';
import 'package:thix_id/models/training_item.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/training_service.dart';

class LearningDashboardPage extends StatefulWidget {
  const LearningDashboardPage({super.key});

  @override
  State<LearningDashboardPage> createState() => _LearningDashboardPageState();
}

class _LearningDashboardPageState extends State<LearningDashboardPage> {
  final _svc = TrainingService();
  List<TrainingEnrollment> _enrollments = const [];
  Map<String, TrainingItem> _trainings = {};
  bool _loading = true;

  static const _brandPurple = Color(0xFF6366F1);
  static const _bgLight = Color(0xFFF8FAFC);
  static const _textDark = Color(0xFF1E293B);
  static const _textGrey = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthController>();
    if (auth.currentUser?.id == null) return;
    
    setState(() => _loading = true);
    try {
      final enrollments = await _svc
          .streamMyEnrollments(auth.currentUser!.id)
          .first;
      final trainings = <String, TrainingItem>{};
      for (final e in enrollments) {
        final t = await _svc.fetchTraining(e.trainingId);
        if (t != null) trainings[e.trainingId] = t;
      }
      if (!mounted) return;
      setState(() {
        _enrollments = enrollments;
        _trainings = trainings;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Mes Formations',
          style: TextStyle(
            color: _textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _brandPurple),
            )
          : _enrollments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.school_rounded,
                        size: 60,
                        color: _textGrey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Aucune formation',
                        style: TextStyle(
                          color: _textDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Explorez les formations disponibles',
                        style: TextStyle(color: _textGrey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => context.go(AppRoutes.trainingHome),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brandPurple,
                        ),
                        child: const Text(
                          'Voir les formations',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: _enrollments.length,
                  itemBuilder: (context, i) {
                    final e = _enrollments[i];
                    final t = _trainings[e.trainingId];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: InkWell(
                        onTap: () => context.push(
                          '${AppRoutes.lessonPlayer}/${e.id}',
                        ),
                        borderRadius: BorderRadius.circular(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 80,
                                    height: 60,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFEEF2FF),
                                      image: DecorationImage(
                                        image: NetworkImage(
                                          'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?q=80&w=100',
                                        ),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t?.title ?? 'Formation',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: _textDark,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        e.status,
                                        style: TextStyle(
                                          color: e.status == 'completed'
                                              ? Colors.green
                                              : _brandPurple,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: LinearProgressIndicator(
                                    value: e.progressPercent / 100,
                                    backgroundColor:
                                        const Color(0xFFF1F5F9),
                                    color: _brandPurple,
                                    minHeight: 4,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${e.progressPercent.toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    color: _textGrey,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
