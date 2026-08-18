import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/training_item.dart';
import 'package:thix_id/models/training_lesson.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/training_service.dart';
import 'package:thix_id/theme.dart';

class TrainingDetailsPage extends StatefulWidget {
  final String trainingId;

  const TrainingDetailsPage({required this.trainingId, super.key});

  @override
  State<TrainingDetailsPage> createState() => _TrainingDetailsPageState();
}

class _TrainingDetailsPageState extends State<TrainingDetailsPage> {
  final _svc = TrainingService();
  TrainingItem? _training;
  List<TrainingLesson> _lessons = const [];
  bool _loading = true;
  String? _error;

  // Palette exacte
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final t = await _svc.fetchTraining(widget.trainingId);
      final l = await _svc.listLessons(widget.trainingId);
      if (!mounted) return;
      setState(() {
        _training = t;
        _lessons = l;
      });
    } catch (e) {
      debugPrint('TrainingDetailsPage: load failed err=\$e');
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _enroll(BuildContext context) async {
    if (_training == null) return;
    final auth = context.read<AuthController>();
    if (auth.currentUser?.id == null) {
      context.push(AppRoutes.login);
      return;
    }
    try {
      await _svc.enroll(
        userId: auth.currentUser!.id,
        trainingId: _training!.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inscrit avec succès!')),
      );
      context.push(AppRoutes.learningDashboard);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: \$e')),
      );
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _textDark),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Détails de la formation',
          style: TextStyle(color: _textDark, fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _brandPurple))
          : _error != null
              ? Center(
                  child: Text(_error!, style: const TextStyle(color: _textGrey)),
                )
              : _training == null
                  ? const Center(
                      child: Text(
                        'Formation non trouvée',
                        style: TextStyle(color: _textGrey),
                      ),
                    )
                  : RefreshIndicator(
                      color: _brandPurple,
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
                        children: [
                          // HERO / COVER
                          Container(
                            height: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              image: const DecorationImage(
                                image: NetworkImage(
                                  'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?q=80&w=400&auto=format&fit=crop',
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    color: Colors.black.withOpacity(0.3),
                                  ),
                                ),
                                if (_training!.isFeatured)
                                  Positioned(
                                    left: 12,
                                    top: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        '★ À LA UNE',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // TITLE
                          Text(
                            _training!.title,
                            style: const TextStyle(
                              color: _textDark,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // TAGLINE
                          if (_training!.tagline != null)
                            Text(
                              _training!.tagline!,
                              style: const TextStyle(
                                color: _textGrey,
                                fontSize: 13,
                              ),
                            ),
                          const SizedBox(height: 12),

                          // RATING & STATS
                          Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Colors.amber,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _training!.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: _textDark,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '(${_training!.reviewsCount})',
                                style: const TextStyle(
                                  color: _textGrey,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                '${_training!.studentsCount} étudiants',
                                style: const TextStyle(
                                  color: _textGrey,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // DETAILS CARDS
                          Row(
                            children: [
                              _buildDetailCard(
                                icon: Icons.timer_outlined,
                                label: 'Durée',
                                value: _training!.durationMinutes != null
                                    ? '${(_training!.durationMinutes! / 60).toStringAsFixed(1)}h'
                                    : 'N/A',
                              ),
                              const SizedBox(width: 12),
                              _buildDetailCard(
                                icon: Icons.trending_up_rounded,
                                label: 'Niveau',
                                value: _training!.level,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              _buildDetailCard(
                                icon: Icons.language_rounded,
                                label: 'Langue',
                                value: _training!.language,
                              ),
                              const SizedBox(width: 12),
                              _buildDetailCard(
                                icon: Icons.videocam_rounded,
                                label: 'Mode',
                                value: _training!.deliveryMode.toUpperCase(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // DESCRIPTION
                          if (_training!.description != null) ...
                            [
                              const Text(
                                'À propos',
                                style: TextStyle(
                                  color: _textDark,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _training!.description!,
                                style: const TextStyle(
                                  color: _textGrey,
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                          // SKILLS
                          if (_training!.skills.isNotEmpty) ...
                            [
                              const Text(
                                'Compétences',
                                style: TextStyle(
                                  color: _textDark,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _training!.skills
                                    .map((s) => Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEEF2FF),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            s,
                                            style: const TextStyle(
                                              color: _brandPurple,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ))
                                    .toList(),
                              ),
                              const SizedBox(height: 20),
                            ],

                          // LESSONS
                          const Text(
                            'Contenu du cours',
                            style: TextStyle(
                              color: _textDark,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._lessons.isEmpty
                              ? [const Center(child: Text('Aucune leçon'))]
                              : _lessons
                                  .map((l) => Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color:
                                                const Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: _brandPurple,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: const Icon(
                                                Icons.play_arrow_rounded,
                                                color: Colors.white,
                                                size: 14,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    l.title,
                                                    style: const TextStyle(
                                                      color: _textDark,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  if (l.durationMinutes !=
                                                      null)
                                                    Text(
                                                      '${l.durationMinutes}'
                                                      ' min',
                                                      style: const TextStyle(
                                                        color: _textGrey,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ))
                                  .toList(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
      bottomSheet: _training != null
          ? Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, -2),
                  )
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _training!.isFree
                              ? 'Gratuit'
                              : '${_training!.priceAmount} ${_training!.currency}',
                          style: const TextStyle(
                            color: _brandPurple,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (_training!.certificationIncluded)
                          const Text(
                            '✓ Certificat inclus',
                            style: TextStyle(
                              color: _emerald,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _enroll(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandPurple,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'S\'inscrire',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(icon, color: _brandPurple, size: 20),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: _textGrey,
                fontSize: 9,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textDark,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
