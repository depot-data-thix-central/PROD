import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/models/training_enrollment.dart';
import 'package:thix_id/models/training_lesson.dart';
import 'package:thix_id/services/training_service.dart';

class LessonPlayerPage extends StatefulWidget {
  final String enrollmentId;

  const LessonPlayerPage({required this.enrollmentId, super.key});

  @override
  State<LessonPlayerPage> createState() => _LessonPlayerPageState();
}

class _LessonPlayerPageState extends State<LessonPlayerPage> {
  final _svc = TrainingService();
  TrainingEnrollment? _enrollment;
  List<TrainingLesson> _lessons = const [];
  int _currentLessonIndex = 0;
  bool _loading = true;

  static const _brandPurple = Color(0xFF6366F1);
  static const _bgLight = Color(0xFFF8FAFC);
  static const _textDark = Color(0xFF1E293B);
  static const _textGrey = Color(0xFF64748B);
  static const Color _emerald = Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final e = await _svc.fetchEnrollmentById(widget.enrollmentId);
      if (e == null) throw Exception('Enrollment not found');
      final l = await _svc.listLessons(e.trainingId);
      if (!mounted) return;
      setState(() {
        _enrollment = e;
        _lessons = l;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markComplete() async {
    if (_enrollment == null) return;
    try {
      await _svc.saveProgress(
        enrollmentId: _enrollment!.id,
        progressPercent: 100,
        markCompleted: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Formation complétée!')),
      );
    } catch (e) {
      debugPrint('Mark complete failed: \$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLesson = _currentLessonIndex < _lessons.length
        ? _lessons[_currentLessonIndex]
        : null;

    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _textDark),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Lecteur de leçon',
          style: TextStyle(color: _textDark, fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _brandPurple),
            )
          : _enrollment == null
              ? const Center(
                  child: Text('Enregistrement non trouvé'),
                )
              : ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    // VIDEO PLAYER PLACEHOLDER
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.play_circle_outline_rounded,
                          color: Colors.white,
                          size: 64,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // LESSON INFO
                    if (currentLesson != null) ...
                      [
                        Text(
                          currentLesson.title,
                          style: const TextStyle(
                            color: _textDark,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (currentLesson.description != null)
                          Text(
                            currentLesson.description!,
                            style: const TextStyle(
                              color: _textGrey,
                              fontSize: 12,
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],

                    // PROGRESS
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Progression',
                                style: TextStyle(
                                  color: _textGrey,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                '${_enrollment!.progressPercent.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  color: _brandPurple,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: _enrollment!.progressPercent / 100,
                            backgroundColor: const Color(0xFFF1F5F9),
                            color: _brandPurple,
                            minHeight: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // LESSONS LIST
                    const Text(
                      'Leçons',
                      style: TextStyle(
                        color: _textDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._lessons
                        .asMap()
                        .entries
                        .map((entry) {
                          final idx = entry.key;
                          final lesson = entry.value;
                          final isActive = idx == _currentLessonIndex;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isActive ? _brandPurple : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: isActive
                                  ? null
                                  : Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                            ),
                            child: InkWell(
                              onTap: () => setState(() =>
                                  _currentLessonIndex = idx),
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Text(
                                      '${idx + 1}',
                                      style: TextStyle(
                                        color: isActive
                                            ? Colors.white
                                            : _textGrey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            lesson.title,
                                            style: TextStyle(
                                              color: isActive
                                                  ? Colors.white
                                                  : _textDark,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (lesson.durationMinutes != null)
                                            Text(
                                              '${lesson.durationMinutes} min',
                                              style: TextStyle(
                                                color: isActive
                                                    ? Colors.white70
                                                    : _textGrey,
                                                fontSize: 11,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        })
                        .toList(),
                    const SizedBox(height: 20),

                    // COMPLETE BUTTON
                    if (_enrollment!.status != 'completed')
                      ElevatedButton(
                        onPressed: _markComplete,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _emerald,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Marquer comme complétée',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}
