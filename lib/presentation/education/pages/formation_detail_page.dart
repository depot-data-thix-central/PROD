// lib/presentation/education/pages/formation_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const gold = Color(0xFFD4AF37);
  static const navy = Color(0xFF0F172A);
  static const textMain = Color(0xFF1E293B);
  static const textMuted = Color(0xFF7386A8);
  static const border = Color(0xFFE2E8F0);
  static const red = Color(0xFFEF4444);
}

// ==========================================
// PROVIDER LOCAL : Favoris (par formation)
// ==========================================
final _formationFavoriteProvider =
    StateProvider.family<bool, String>((ref, id) => false);

// ==========================================
// ANIMATIONS
// ==========================================
class _FadeInUp extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const _FadeInUp({required this.child, this.delayMs = 0});

  @override
  State<_FadeInUp> createState() => _FadeInUpState();
}

class _FadeInUpState extends State<_FadeInUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  late final Animation<double> _anim =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
            .animate(_anim),
        child: widget.child,
      ),
    );
  }
}

class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _Pressable({required this.child, required this.onTap});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ==========================================
// PAGE PRINCIPALE
// ==========================================
class FormationDetailPage extends ConsumerStatefulWidget {
  final String formationId;
  const FormationDetailPage({super.key, required this.formationId});

  @override
  ConsumerState<FormationDetailPage> createState() =>
      _FormationDetailPageState();
}

class _FormationDetailPageState extends ConsumerState<FormationDetailPage> {
  bool _isEnrolling = false;
  bool _descriptionExpanded = false;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    // Possibilité d'ajouter un parallax ici si besoin
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formationId = widget.formationId;
    final formationAsync = ref.watch(formationDetailProvider(formationId));
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final enrollmentAsync = userId == null
        ? null
        : ref.watch(enrollmentProvider(
            (userId: userId, formationId: formationId)));

    return formationAsync.when(
      loading: () => const Scaffold(body: EducationLoadingShimmer()),
      error: (e, _) => Scaffold(
        body: _ErrorState(
          error: e.toString(),
          onBack: () => context.pop(),
          onRetry: () => ref.invalidate(formationDetailProvider(formationId)),
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
        final progress = isEnrolled
            ? ((enrollmentAsync?.value?['progress'] ?? 0) as num).toDouble()
            : 0.0;

        return Scaffold(
          backgroundColor: _C.bg,
          extendBody: true,
          body: Stack(
            children: [
              // ========== CONTENU SCROLLABLE ==========
              CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildSliverHero(formation),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: isEnrolled ? 40 : 140,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FadeInUp(child: _buildStatsSection(formation)),
                          const SizedBox(height: 16),
                          if (isEnrolled)
                            _FadeInUp(
                              delayMs: 80,
                              child: _buildEnrolledSection(
                                context,
                                formation,
                                progress,
                              ),
                            ),
                          const SizedBox(height: 20),
                          _FadeInUp(
                            delayMs: 120,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: _buildBadgesSection(formation),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _FadeInUp(
                            delayMs: 160,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: _buildDescription(formation),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _FadeInUp(
                            delayMs: 200,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: _buildWhatYoullLearn(formation),
                            ),
                          ),
                          const SizedBox(height: 32),
                          _FadeInUp(
                            delayMs: 240,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: _buildProgramHeader(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          FormationModuleList(
                            formation: formation,
                            onLessonTap: (lesson) =>
                                _openLesson(context, lesson, isEnrolled),
                          ),
                          const SizedBox(height: 24),
                          _FadeInUp(
                            delayMs: 280,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: _buildInstructorSection(formation),
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // ========== FLOATING BOTTOM BAR (si non inscrit) ==========
              if (!isEnrolled)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _FloatingEnrollBar(
                    formation: formation,
                    isEnrolling: _isEnrolling,
                    onEnroll: () =>
                        _enrollInCourse(context, ref, formation.id, userId),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // HERO IMMERSIF (340px)
  // ==========================================
  Widget _buildSliverHero(Formation formation) {
    return SliverAppBar(
      expandedHeight: 340.0,
      pinned: true,
      backgroundColor: _C.navy,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: _Pressable(
          onTap: () => context.pop(),
          child: Container(
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
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
        ),
      ),
      actions: [
        Consumer(
          builder: (context, ref, _) {
            final isFav =
                ref.watch(_formationFavoriteProvider(formation.id));
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _Pressable(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref
                      .read(_formationFavoriteProvider(formation.id).notifier)
                      .state = !isFav;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isFav ? 'Retiré des favoris' : 'Ajouté aux favoris ❤️',
                      ),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: _C.navy,
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(
                    isFav
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: isFav ? _C.red : Colors.white,
                  ),
                ),
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: _Pressable(
            onTap: () => _showShareSheet(context, formation),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(Icons.share_rounded, color: Colors.white),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Image de fond
            if (formation.imageUrl != null && formation.imageUrl!.isNotEmpty)
              Image.network(
                formation.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
              )
            else
              _buildPlaceholderImage(),

            // Gradient overlay
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.4),
                    Colors.black.withOpacity(0.85),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),

            // Badge "Certifié"
            if (formation.isCertifying)
              Positioned(
                top: 100,
                right: 20,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _C.green,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _C.green.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.workspace_premium_rounded,
                          color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Certifié',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Contenu bas
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Badge catégorie
                  if (formation.category != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        (formation.category?.name ?? 'CATÉGORIE').toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),

                  // Titre
                  Text(
                    formation.title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.15,
                      letterSpacing: -0.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 14),

                  // Rating + instructeur
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded,
                                color: _C.gold, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              formation.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (formation.instructorName != null &&
                          formation.instructorName!.isNotEmpty) ...[
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: Colors.white24,
                          child: const Icon(Icons.person,
                              size: 13, color: Colors.white),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            formation.instructorName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_C.navy, _C.primary],
        ),
      ),
      child: const Center(
        child: Icon(Icons.school_rounded, size: 80, color: Colors.white24),
      ),
    );
  }

  Widget _buildStatsSection(Formation formation) {
    final totalLessons = formation.modules?.fold<int>(
            0, (sum, m) => sum + (m.lessons?.length ?? 0)) ??
        0;
    final totalMinutes = formation.duration;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    final durationText =
        hours > 0 ? '${hours}h ${minutes}min' : '${minutes}min';
    final enrollments = formation.enrollments?.length ?? 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _StatPill(
            icon: Icons.people_rounded,
            value: enrollments >= 1000
                ? '${(enrollments / 1000).toStringAsFixed(1)}k'
                : '$enrollments',
            label: 'Élèves',
            color: _C.primary,
          ),
          _verticalDivider(),
          _StatPill(
            icon: Icons.video_library_rounded,
            value: '$totalLessons',
            label: 'Leçons',
            color: _C.orange,
          ),
          _verticalDivider(),
          _StatPill(
            icon: Icons.timer_rounded,
            value: durationText,
            label: 'Durée',
            color: _C.green,
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 36,
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
        if (formation.isCertifying)
          _buildBadge(
            Icons.workspace_premium_rounded,
            'Certifiant',
            _C.green,
          ),
      ],
    );
  }

  Widget _buildBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
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
        return Icons.trending_up_rounded;
      case 'advanced':
        return Icons.whatshot_rounded;
      default:
        return Icons.auto_awesome_rounded;
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
    final text = formation.description;
    final isLong = text.length > 180;
    final shouldTruncate = isLong && !_descriptionExpanded;
    final displayText = shouldTruncate ? '${text.substring(0, 180)}...' : text;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _C.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.info_outline_rounded,
                    color: _C.primary, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'À propos de ce cours',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _C.textMain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Text(
              displayText,
              style: const TextStyle(
                fontSize: 14,
                height: 1.7,
                color: _C.textMuted,
              ),
            ),
          ),
          if (isLong) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _descriptionExpanded = !_descriptionExpanded);
              },
              child: Text(
                _descriptionExpanded ? 'Voir moins' : 'Voir plus',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _C.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWhatYoullLearn(Formation formation) {
    final totalLessons = formation.modules?.fold<int>(
            0, (sum, m) => sum + (m.lessons?.length ?? 0)) ??
        0;
    final points = <String>[
      'Maîtrisez les fondamentaux de ${formation.category?.name ?? 'ce domaine'}',
      if (formation.instructorName != null)
        'Apprenez avec ${formation.instructorName!}, expert reconnu',
      'Accédez à $totalLessons leçons structurées et progressives',
      if (formation.isCertifying)
        'Obtenez un certificat officiel à la complétion',
      'Support et communauté pour répondre à vos questions',
      'Contenu accessible à vie, à votre rythme',
    ].take(6).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border),
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
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lightbulb_outline_rounded,
                    color: _C.green, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Ce que vous allez apprendre',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _C.textMain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(points.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: _C.green.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: _C.green, size: 12),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      points[i],
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: _C.textMain,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProgramHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _C.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.list_alt_rounded,
              color: _C.primary, size: 18),
        ),
        const SizedBox(width: 10),
        const Text(
          'Programme du cours',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _C.textMain,
          ),
        ),
      ],
    );
  }

  Widget _buildInstructorSection(Formation formation) {
    if (formation.instructorName == null ||
        formation.instructorName!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_C.navy, Color(0xFF1E293B)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _C.navy.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 2),
            ),
            child: const Icon(Icons.person_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Votre formateur',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white54,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formation.instructorName!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Expert certifié',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white60,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
              color: Colors.white54, size: 16),
        ],
      ),
    );
  }

  Widget _buildEnrolledSection(
    BuildContext context,
    Formation formation,
    double progress,
  ) {
    final progressPercent = (progress * 100).toInt();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_C.green, Color(0xFF059669)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _C.green.withOpacity(0.3),
            blurRadius: 18,
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
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Vous êtes inscrit à ce cours',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                '$progressPercent%',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _continueLearning(context, formation),
              icon: const Icon(Icons.play_circle_fill_rounded,
                  color: _C.green),
              label: Text(
                progressPercent == 0
                    ? 'Commencer le cours'
                    : 'Continuer l\'apprentissage',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: _C.green,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
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

  // ==========================================
  // INSCRIPTION
  // ==========================================
  Future<void> _enrollInCourse(
    BuildContext context,
    WidgetRef ref,
    String formationId,
    String? userId,
  ) async {
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Veuillez vous connecter pour vous inscrire.'),
          backgroundColor: _C.orange,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isEnrolling = true);
    HapticFeedback.mediumImpact();

    try {
      bool isSuccess = false;
      try {
        isSuccess = await ref.read(enrollProvider.notifier).enroll(
              userId: userId,
              formationId: formationId,
            );
      } catch (_) {
        isSuccess = false;
      }

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
          SnackBar(
            content: const Text('🎉 Inscription réussie ! Bon apprentissage !'),
            backgroundColor: _C.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
        ref.invalidate(enrollmentProvider(
            (userId: userId, formationId: formationId)));
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('duplicate key')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Vous êtes déjà inscrit à ce cours.'),
              backgroundColor: _C.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
          ref.invalidate(enrollmentProvider(
              (userId: userId, formationId: formationId)));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de l\'inscription : $e'),
              backgroundColor: _C.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
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
        SnackBar(
          content:
              const Text('Veuillez vous inscrire pour accéder au contenu.'),
          backgroundColor: _C.orange,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  void _showShareSheet(BuildContext context, Formation formation) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShareSheet(formation: formation),
    );
  }
}

// ==========================================
// STAT PILL
// ==========================================
class _StatPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatPill({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: _C.textMain,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: _C.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// FLOATING ENROLL BAR
// ==========================================
class _FloatingEnrollBar extends StatelessWidget {
  final Formation formation;
  final bool isEnrolling;
  final VoidCallback onEnroll;

  const _FloatingEnrollBar({
    required this.formation,
    required this.isEnrolling,
    required this.onEnroll,
  });

  @override
  Widget build(BuildContext context) {
    final isFree = formation.price <= 0;
    final priceLabel = isFree
        ? 'Gratuit'
        : '${formation.price.toInt()} ${formation.currency}';

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: _C.border.withOpacity(0.5)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  priceLabel,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: isFree ? _C.green : _C.textMain,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  isFree ? 'Accès illimité à vie' : 'Paiement unique',
                  style: const TextStyle(
                    fontSize: 11,
                    color: _C.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: isEnrolling ? null : onEnroll,
                icon: isEnrolling
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Icon(Icons.school_rounded,
                        color: Colors.white, size: 20),
                label: Text(
                  isEnrolling ? 'Inscription...' : 'S\'inscrire',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// SHARE SHEET
// ==========================================
class _ShareSheet extends StatelessWidget {
  final Formation formation;
  const _ShareSheet({required this.formation});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _C.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Partager cette formation',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _C.textMain,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formation.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: _C.textMuted,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ShareOption(
                icon: Icons.copy_rounded,
                label: 'Copier',
                color: _C.textMain,
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Lien copié dans le presse-papier'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              _ShareOption(
                icon: Icons.message_rounded,
                label: 'SMS',
                color: _C.green,
                onTap: () => Navigator.pop(context),
              ),
              _ShareOption(
                icon: Icons.mail_rounded,
                label: 'Email',
                color: _C.primary,
                onTap: () => Navigator.pop(context),
              ),
              _ShareOption(
                icon: Icons.more_horiz_rounded,
                label: 'Plus',
                color: _C.textMuted,
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShareOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _C.textMain,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// ERROR STATE
// ==========================================
class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onBack;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.error,
    required this.onBack,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _C.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_rounded,
                  size: 56, color: _C.red),
            ),
            const SizedBox(height: 20),
            const Text(
              'Erreur de chargement',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _C.textMain,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: _C.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Retour'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _C.textMain,
                    side: const BorderSide(color: _C.border),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Réessayer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
