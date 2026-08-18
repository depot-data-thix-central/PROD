// lib/presentation/education/instructor/dashboard/instructor_dashboard.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _C {
  static const bg = Color(0xFFF8FAFC);
  static const surface = Colors.white;
  static const border = Color(0xFFE2E8F0);
  static const primary = Color(0xFF2D6CDF);
  static const textMain = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const green = Color(0xFF10B981);
  static const orange = Color(0xFFF59E0B);
  static const purple = Color(0xFF8B5CF6);
  static const red = Color(0xFFEF4444);
  static const teal = Color(0xFF0D9488);
}

class InstructorDashboard extends ConsumerStatefulWidget {
  const InstructorDashboard({super.key});

  @override
  ConsumerState<InstructorDashboard> createState() =>
      _InstructorDashboardState();
}

class _InstructorDashboardState extends ConsumerState<InstructorDashboard> {
  int _totalCourses = 0;
  int _totalBooks = 0;
  bool _loading = true;
  List<Map<String, dynamic>> _recentCourses = [];
  List<Map<String, dynamic>> _recentBooks = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      // Cours
      final coursesRes = await Supabase.instance.client
          .from('formations')
          .select('id, title, created_at')
          .eq('instructor_id', userId)
          .order('created_at', ascending: false);

      final coursesList = List<Map<String, dynamic>>.from(coursesRes as List);

      // Livres
      int booksCount = 0;
      List<Map<String, dynamic>> booksList = [];
      try {
        final booksRes = await Supabase.instance.client
            .from('books')
            .select('id, title, created_at')
            .eq('instructor_id', userId)
            .order('created_at', ascending: false);
        booksList = List<Map<String, dynamic>>.from(booksRes as List);
        booksCount = booksList.length;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _totalCourses = coursesList.length;
          _totalBooks = booksCount;
          _recentCourses = coursesList.take(3).toList();
          _recentBooks = booksList.take(3).toList();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur dashboard formateur: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        title: const Text(
          'Tableau de bord formateur',
          style: TextStyle(
              fontWeight: FontWeight.w800, color: _C.textMain, fontSize: 18),
        ),
        backgroundColor: _C.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _C.textMain),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded, color: _C.primary),
            onPressed: () => context.push('/education'),
            tooltip: 'Espace apprenant',
          ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded, color: _C.textMain),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _C.primary))
          : RefreshIndicator(
              color: _C.primary,
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats
                    Row(
                      children: [
                        _StatCard(
                          icon: Icons.school_rounded,
                          label: 'Mes Cours',
                          value: '$_totalCourses',
                          color: _C.primary,
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          icon: Icons.menu_book_rounded,
                          label: 'Mes Livres',
                          value: '$_totalBooks',
                          color: _C.green,
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          icon: Icons.people_rounded,
                          label: 'Activité',
                          value: 'Actif',
                          color: _C.purple,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    const Text(
                      'Actions rapides',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _C.textMain),
                    ),
                    const SizedBox(height: 14),

                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _QuickAction(
                          icon: Icons.add_rounded,
                          label: 'Nouveau cours',
                          onTap: () async {
                            await context.push('/instructor/courses/create');
                            _loadDashboardData();
                          },
                          color: _C.primary,
                        ),
                        _QuickAction(
                          icon: Icons.menu_book_rounded,
                          label: 'Mes cours',
                          onTap: () async {
                            await context.push('/instructor/courses');
                            _loadDashboardData();
                          },
                          color: _C.green,
                        ),
                        _QuickAction(
                          icon: Icons.library_add_rounded,
                          label: 'Nouveau livre',
                          onTap: () async {
                            await context.push('/instructor/books/create');
                            _loadDashboardData();
                          },
                          color: _C.orange,
                        ),
                        _QuickAction(
                          icon: Icons.collections_bookmark_rounded,
                          label: 'Mes livres',
                          onTap: () async {
                            await context.push('/instructor/books');
                            _loadDashboardData();
                          },
                          color: _C.purple,
                        ),
                        _QuickAction(
                          icon: Icons.article_rounded,
                          label: 'Gérer contenu livre',
                          onTap: () async {
                            await context.push('/instructor/books');
                            _loadDashboardData();
                          },
                          color: _C.teal,
                        ),
                        _QuickAction(
                          icon: Icons.bar_chart_rounded,
                          label: 'Performance',
                          onTap: () => context.push('/instructor/performance'),
                          color: _C.orange,
                        ),
                        _QuickAction(
                          icon: Icons.announcement_rounded,
                          label: 'Annonces',
                          onTap: () =>
                              context.push('/instructor/announcements'),
                          color: _C.red,
                        ),
                        _QuickAction(
                          icon: Icons.calendar_today_rounded,
                          label: 'Calendrier',
                          onTap: () => context.push('/instructor/calendar'),
                          color: _C.teal,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Cours récents
                    const Text(
                      'Cours récents',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _C.textMain),
                    ),
                    const SizedBox(height: 14),
                    _buildRecentList(
                      items: _recentCourses,
                      emptyMessage: 'Aucun cours créé pour le moment.',
                      icon: Icons.school_rounded,
                      color: _C.primary,
                      titleBuilder: (item) =>
                          item['title'] as String? ?? 'Cours sans titre',
                      onTap: (item) {
                        context.push(
                            '/instructor/courses/edit/${item['id']}');
                      },
                    ),
                    const SizedBox(height: 24),

                    // Livres récents
                    const Text(
                      'Livres récents',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _C.textMain),
                    ),
                    const SizedBox(height: 14),
                    _buildRecentList(
                      items: _recentBooks,
                      emptyMessage: 'Aucun livre créé pour le moment.',
                      icon: Icons.menu_book_rounded,
                      color: _C.green,
                      titleBuilder: (item) =>
                          item['title'] as String? ?? 'Livre sans titre',
                      onTap: (item) {
                        // Ouvre directement la gestion du contenu
                        context.push(
                            '/instructor/books/${item['id']}/content');
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildRecentList({
    required List<Map<String, dynamic>> items,
    required String emptyMessage,
    required IconData icon,
    required Color color,
    required String Function(Map<String, dynamic>) titleBuilder,
    required void Function(Map<String, dynamic>) onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  emptyMessage,
                  style: const TextStyle(color: _C.textMuted, fontSize: 13),
                ),
              ),
            )
          : Column(
              children: items.map((item) {
                return InkWell(
                  onTap: () => onTap(item),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, size: 18, color: color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            titleBuilder(item),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _C.textMain,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            size: 20, color: _C.textMuted),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _C.textMain),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 12,
                  color: _C.textMuted,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
