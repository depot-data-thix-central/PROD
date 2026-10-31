// lib/presentation/thix_weeding/pages/staff/checklist/checklist_page.dart
// ============================================================================
// THIX WEDDING & EVENTS — CHECKLIST (PRODUCTION)
// Design royal + Timeline + Priorités + Tâches en retard + Ajout détaillé
// Branché sur providers & services EXISTANTS du dépôt
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';

// ============================================================================
// DESIGN SYSTEM ROYAL
// ============================================================================
class _R {
  static const Color blue = Color(0xFF0B3B8F);
  static const Color purple = Color(0xFF6B46C1);
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldDark = Color(0xFFB8860B);
  static const Color rose = Color(0xFFE31C4E);
  static const Color green = Color(0xFF059669);
  static const Color greenSoft = Color(0xFF10B981);
  static const Color amber = Color(0xFFD97706);
  static const Color surface = Color(0xFFF8FAFC);
  static const Color text = Color(0xFF111827);
  static const Color text2 = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);

  static const LinearGradient royal = LinearGradient(
    colors: [blue, purple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient goldG = LinearGradient(
    colors: [gold, goldDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient roseG = LinearGradient(
    colors: [rose, Color(0xFFFF6B9D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient greenG = LinearGradient(
    colors: [green, greenSoft],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient amberG = LinearGradient(
    colors: [amber, Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxDecoration card({double r = 16}) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      );
}

// ============================================================================
// CATÉGORIES DE TÂCHES
// ============================================================================
const List<_Category> _CATEGORIES = [
  _Category('salle', 'Salle', Icons.place_outlined, Color(0xFF0B3B8F)),
  _Category('traiteur', 'Traiteur', Icons.restaurant, Color(0xFFD97706)),
  _Category('decoration', 'Décoration', Icons.auto_awesome, Color(0xFFFF6B9D)),
  _Category('photo', 'Photo/Vidéo', Icons.camera_alt_outlined, Color(0xFFE31C4E)),
  _Category('musique', 'Musique', Icons.music_note, Color(0xFFDB2777)),
  _Category('tenues', 'Tenues', Icons.checkroom, Color(0xFF0891B2)),
  _Category('administratif', 'Admin', Icons.description_outlined, Color(0xFF64748B)),
  _Category('autre', 'Autre', Icons.category_outlined, Color(0xFF6B7280)),
];

class _Category {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  const _Category(this.key, this.label, this.icon, this.color);
}

_Category _findCategory(String? key) {
  if (key == null || key.isEmpty) return _CATEGORIES.last;
  return _CATEGORIES.firstWhere((c) => c.key == key, orElse: () => _CATEGORIES.last);
}

// ============================================================================
// PRIORITÉS
// ============================================================================
enum _Priority { low, medium, high, urgent }

_Priority _parsePriority(String? p) {
  switch (p) {
    case 'high':
      return _Priority.high;
    case 'urgent':
      return _Priority.urgent;
    case 'low':
      return _Priority.low;
    default:
      return _Priority.medium;
  }
}

Color _priorityColor(_Priority p) {
  switch (p) {
    case _Priority.low:
      return _R.text2;
    case _Priority.medium:
      return _R.blue;
    case _Priority.high:
      return _R.amber;
    case _Priority.urgent:
      return _R.rose;
  }
}

String _priorityLabel(_Priority p) {
  switch (p) {
    case _Priority.low:
      return 'Basse';
    case _Priority.medium:
      return 'Moyenne';
    case _Priority.high:
      return 'Haute';
    case _Priority.urgent:
      return 'Urgente';
  }
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class ChecklistPage extends ConsumerStatefulWidget {
  final String weddingId;
  const ChecklistPage({super.key, required this.weddingId});

  @override
  ConsumerState<ChecklistPage> createState() => _ChecklistPageState();
}

class _ChecklistPageState extends ConsumerState<ChecklistPage>
    with SingleTickerProviderStateMixin {
  String _filter = 'all';
  final _newTaskCtrl = TextEditingController();
  bool _isAdding = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _newTaskCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _addQuick() async {
    final title = _newTaskCtrl.text.trim();
    if (title.isEmpty) return;

    setState(() => _isAdding = true);
    try {
      await ref.read(checklistServiceProvider).create({
        'wedding_id': widget.weddingId,
        'title': title,
        'is_done': false,
        'category': 'autre',
        'priority': 'medium',
      });
      _newTaskCtrl.clear();
      ref.invalidate(checklistProvider(widget.weddingId));
      ref.invalidate(dashboardStatsProvider(widget.weddingId));
      if (mounted) _showSuccess('Tâche ajoutée ✓');
    } catch (e) {
      if (mounted) _showError('Erreur: $e');
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _toggleDone(ChecklistModel task, bool? value) async {
    try {
      await ref.read(checklistServiceProvider).toggle(task.id, value ?? false);
      ref.invalidate(checklistProvider(widget.weddingId));
      ref.invalidate(dashboardStatsProvider(widget.weddingId));
      if (mounted && value == true) {
        _showSuccess('Tâche accomplie 🎉');
      }
    } catch (e) {
      if (mounted) _showError('Erreur: $e');
    }
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration:
                  const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(msg,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        backgroundColor: _R.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _R.rose,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(checklistProvider(widget.weddingId));

    return Scaffold(
      backgroundColor: _R.surface,
      body: tasksAsync.when(
        loading: () => const _LoadingView(),
        error: (e, _) => _ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(checklistProvider(widget.weddingId)),
        ),
        data: (tasks) => FadeTransition(
          opacity: _fadeAnim,
          child: _ChecklistContent(
            weddingId: widget.weddingId,
            tasks: tasks,
            filter: _filter,
            newTaskCtrl: _newTaskCtrl,
            isAdding: _isAdding,
            onFilterChanged: (f) => setState(() => _filter = f),
            onAddQuick: _addQuick,
            onToggle: _toggleDone,
            onRefresh: () async =>
                ref.invalidate(checklistProvider(widget.weddingId)),
            onAddDetailed: () => _showAddTaskSheet(context),
          ),
        ),
      ),
      floatingActionButton: tasksAsync.maybeWhen(
        data: (_) => _AddDetailedFAB(
          weddingId: widget.weddingId,
          onTap: () => _showAddTaskSheet(context),
        ),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }

  void _showAddTaskSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddTaskSheet(
        weddingId: widget.weddingId,
        onSaved: () {
          ref.invalidate(checklistProvider(widget.weddingId));
          ref.invalidate(dashboardStatsProvider(widget.weddingId));
        },
      ),
    );
  }
}

// ============================================================================
// CONTENU PRINCIPAL
// ============================================================================
class _ChecklistContent extends StatelessWidget {
  final String weddingId;
  final List<ChecklistModel> tasks;
  final String filter;
  final TextEditingController newTaskCtrl;
  final bool isAdding;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onAddQuick;
  final Function(ChecklistModel, bool?) onToggle;
  final Future<void> Function() onRefresh;
  final VoidCallback onAddDetailed;

  const _ChecklistContent({
    required this.weddingId,
    required this.tasks,
    required this.filter,
    required this.newTaskCtrl,
    required this.isAdding,
    required this.onFilterChanged,
    required this.onAddQuick,
    required this.onToggle,
    required this.onRefresh,
    required this.onAddDetailed,
  });

  @override
  Widget build(BuildContext context) {
    final total = tasks.length;
    final done = tasks.where((t) => t.isDone).length;
    final percent = total > 0 ? done / total : 0.0;
    final now = DateTime.now();

    final overdue = tasks.where((t) {
      if (t.isDone || t.dueDate == null) return false;
      return t.dueDate!.isBefore(now);
    }).length;

    final urgent = tasks.where((t) {
      if (t.isDone) return false;
      return _parsePriority(t.priority) == _Priority.urgent;
    }).length;

    final filtered = tasks.where((t) {
      switch (filter) {
        case 'done':
          return t.isDone;
        case 'todo':
          return !t.isDone;
        case 'overdue':
          return !t.isDone && t.dueDate != null && t.dueDate!.isBefore(now);
        case 'urgent':
          return !t.isDone && _parsePriority(t.priority) == _Priority.urgent;
        default:
          return true;
      }
    }).toList()
      ..sort((a, b) {
        if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
        final pa = _parsePriority(a.priority);
        final pb = _parsePriority(b.priority);
        if (pa != pb) return pb.index.compareTo(pa.index);
        if (a.dueDate != null && b.dueDate != null) {
          return a.dueDate!.compareTo(b.dueDate!);
        }
        if (a.dueDate != null) return -1;
        if (b.dueDate != null) return 1;
        return a.title.compareTo(b.title);
      });

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _ChecklistAppBar(
          total: total,
          done: done,
          overdue: overdue,
          urgent: urgent,
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _ProgressHero(
                done: done,
                total: total,
                percent: percent,
                overdue: overdue,
                urgent: urgent,
              ),
              const SizedBox(height: 16),
              _QuickAddField(
                controller: newTaskCtrl,
                onAdd: onAddQuick,
                isAdding: isAdding,
              ),
              const SizedBox(height: 16),
              _FilterRow(
                filter: filter,
                onChanged: onFilterChanged,
                overdueCount: overdue,
                urgentCount: urgent,
              ),
              const SizedBox(height: 16),
              _ListHeader(
                  count: filtered.length, total: total, filter: filter),
              const SizedBox(height: 10),
              if (filtered.isEmpty)
                _EmptyState(filter: filter, onAdd: onAddDetailed)
              else
                RefreshIndicator(
                  color: _R.blue,
                  onRefresh: onRefresh,
                  child: Column(
                    children: filtered.asMap().entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TaskCard(
                          task: entry.value,
                          weddingId: weddingId,
                          onToggle: onToggle,
                          showConnector: entry.key < filtered.length - 1,
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ]),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// APP BAR ROYALE
// ============================================================================
class _ChecklistAppBar extends StatelessWidget {
  final int total;
  final int done;
  final int overdue;
  final int urgent;

  const _ChecklistAppBar({
    required this.total,
    required this.done,
    required this.overdue,
    required this.urgent,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)
            ],
          ),
          child:
              const Icon(Icons.arrow_back_ios_new, size: 14, color: _R.text),
        ),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: _R.royal,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -60,
              top: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              right: 30,
              bottom: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _R.gold.withOpacity(0.15),
                ),
              ),
            ),
            FlexibleSpaceBar(
              background: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.checklist_outlined,
                                color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'CHECKLIST PRÉPARATIFS',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.85),
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Organisation du mariage',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _AppStat(label: 'Total', value: '$total'),
                          const SizedBox(width: 16),
                          _AppStat(label: 'Faites', value: '$done'),
                          if (overdue > 0) ...[
                            const SizedBox(width: 16),
                            _AppStat(
                                label: 'En retard',
                                value: '$overdue',
                                danger: true),
                          ],
                          if (urgent > 0) ...[
                            const SizedBox(width: 16),
                            _AppStat(
                                label: 'Urgentes',
                                value: '$urgent',
                                warning: true),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppStat extends StatelessWidget {
  final String label;
  final String value;
  final bool danger;
  final bool warning;

  const _AppStat({
    required this.label,
    required this.value,
    this.danger = false,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? const Color(0xFFFF6B9D)
        : warning
            ? const Color(0xFFFBBF24)
            : Colors.white;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// HERO PROGRESSION
// ============================================================================
class _ProgressHero extends StatelessWidget {
  final int done;
  final int total;
  final double percent;
  final int overdue;
  final int urgent;

  const _ProgressHero({
    required this.done,
    required this.total,
    required this.percent,
    required this.overdue,
    required this.urgent,
  });

  @override
  Widget build(BuildContext context) {
    final pctInt = (percent * 100).toInt();
    final gradient = pctInt >= 80
        ? _R.greenG
        : pctInt >= 50
            ? _R.goldG
            : pctInt >= 25
                ? _R.amberG
                : _R.roseG;
    final statusColor = pctInt >= 80
        ? _R.green
        : pctInt >= 50
            ? _R.gold
            : pctInt >= 25
                ? _R.amber
                : _R.rose;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: percent,
                  strokeWidth: 8,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$pctInt%',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'complété',
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      color: Colors.white.withOpacity(0.9),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$done / $total tâches',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  pctInt >= 80
                      ? 'Presque prêt ! Continuez ainsi 🎉'
                      : pctInt >= 50
                          ? 'Bon progrès, continuez !'
                          : pctInt >= 25
                              ? 'Bien commencé, il reste du travail'
                              : 'Commencez vos préparatifs !',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                if (overdue > 0 || urgent > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (overdue > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.warning_amber,
                                  color: Colors.white, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                '$overdue en retard',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (overdue > 0 && urgent > 0)
                        const SizedBox(width: 6),
                      if (urgent > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.bolt,
                                  color: Colors.white, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                '$urgent urgentes',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
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
    );
  }
}

// ============================================================================
// QUICK ADD FIELD
// ============================================================================
class _QuickAddField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onAdd;
  final bool isAdding;

  const _QuickAddField({
    required this.controller,
    required this.onAdd,
    required this.isAdding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _R.card(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: _R.royal,
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                const Icon(Icons.add_task_outlined, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              style: GoogleFonts.inter(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Ajouter une tâche rapide...',
                hintStyle: GoogleFonts.inter(color: _R.text2, fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onSubmitted: (_) => onAdd(),
            ),
          ),
          Material(
            color: isAdding ? _R.border : _R.blue,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: isAdding ? null : onAdd,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(10),
                child: isAdding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// FILTER ROW
// ============================================================================
class _FilterRow extends StatelessWidget {
  final String filter;
  final ValueChanged<String> onChanged;
  final int overdueCount;
  final int urgentCount;

  const _FilterRow({
    required this.filter,
    required this.onChanged,
    required this.overdueCount,
    required this.urgentCount,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: 'Toutes',
            icon: Icons.all_inbox,
            selected: filter == 'all',
            color: _R.blue,
            onTap: () => onChanged('all'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'À faire',
            icon: Icons.radio_button_unchecked,
            selected: filter == 'todo',
            color: _R.purple,
            onTap: () => onChanged('todo'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Faites',
            icon: Icons.check_circle_outline,
            selected: filter == 'done',
            color: _R.green,
            onTap: () => onChanged('done'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'En retard',
            icon: Icons.warning_amber_outlined,
            selected: filter == 'overdue',
            color: _R.rose,
            badge: overdueCount,
            onTap: () => onChanged('overdue'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Urgentes',
            icon: Icons.bolt_outlined,
            selected: filter == 'urgent',
            color: _R.amber,
            badge: urgentCount,
            onTap: () => onChanged('urgent'),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final int badge;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? color : _R.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                      size: 14,
                      color: selected ? Colors.white : color),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : _R.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (badge > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                '$badge',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// LIST HEADER
// ============================================================================
class _ListHeader extends StatelessWidget {
  final int count;
  final int total;
  final String filter;

  const _ListHeader({
    required this.count,
    required this.total,
    required this.filter,
  });

  @override
  Widget build(BuildContext context) {
    final label = switch (filter) {
      'done' => 'Tâches accomplies',
      'todo' => 'Tâches à faire',
      'overdue' => 'Tâches en retard',
      'urgent' => 'Tâches urgentes',
      _ => 'Toutes les tâches',
    };

    return Row(
      children: [
        Icon(Icons.list_alt_outlined, size: 16, color: _R.blue),
        const SizedBox(width: 6),
        Text(
          label,
          style:
              GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _R.blue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            filter == 'all' ? '$total' : '$count / $total',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _R.blue,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// TASK CARD (avec timeline connector)
// ============================================================================
class _TaskCard extends ConsumerStatefulWidget {
  final ChecklistModel task;
  final String weddingId;
  final Function(ChecklistModel, bool?) onToggle;
  final bool showConnector;

  const _TaskCard({
    required this.task,
    required this.weddingId,
    required this.onToggle,
    required this.showConnector,
  });

  @override
  ConsumerState<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends ConsumerState<_TaskCard> {
  bool _isToggling = false;

  Future<void> _handleToggle(bool? value) async {
    setState(() => _isToggling = true);
    await widget.onToggle(widget.task, value);
    if (mounted) setState(() => _isToggling = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final priority = _parsePriority(t.priority);
    final pColor = _priorityColor(priority);
    final category = _findCategory(t.category);
    final isOverdue =
        !t.isDone && t.dueDate != null && t.dueDate!.isBefore(DateTime.now());

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline connector
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: t.isDone
                        ? _R.green.withOpacity(0.15)
                        : pColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: t.isDone ? _R.green : pColor,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    t.isDone
                        ? Icons.check
                        : isOverdue
                            ? Icons.warning_amber
                            : Icons.circle_outlined,
                    size: 12,
                    color: t.isDone
                        ? _R.green
                        : isOverdue
                            ? _R.rose
                            : pColor,
                  ),
                ),
                if (widget.showConnector)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: t.isDone
                          ? _R.green.withOpacity(0.25)
                          : _R.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Card content
          Expanded(
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () => context.push(
                  '/thix-weeding/staff/${widget.weddingId}/checklist/${t.id}',
                ),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: t.isDone
                          ? _R.green.withOpacity(0.3)
                          : isOverdue
                              ? _R.rose.withOpacity(0.3)
                              : _R.border,
                      width: t.isDone || isOverdue ? 1.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Checkbox
                      _isToggling
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: _R.blue),
                            )
                          : Transform.scale(
                              scale: 1.2,
                              child: Checkbox(
                                value: t.isDone,
                                activeColor: _R.green,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6)),
                                side: BorderSide(
                                  color: pColor,
                                  width: 1.5,
                                ),
                                onChanged: _handleToggle,
                              ),
                            ),
                      const SizedBox(width: 10),

                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    t.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: t.isDone
                                          ? FontWeight.w500
                                          : FontWeight.w700,
                                      color: t.isDone
                                          ? _R.text2
                                          : _R.text,
                                      decoration: t.isDone
                                          ? TextDecoration.lineThrough
                                          : null,
                                      decorationColor: _R.text2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                // Priority badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: pColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: pColor.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    _priorityLabel(priority),
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: pColor,
                                    ),
                                  ),
                                ),
                                // Category badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color:
                                        category.color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(category.icon,
                                          size: 10,
                                          color: category.color),
                                      const SizedBox(width: 3),
                                      Text(
                                        category.label,
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: category.color,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Due date
                                if (t.dueDate != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isOverdue
                                          ? _R.rose.withOpacity(0.1)
                                          : _R.text2.withOpacity(0.08),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isOverdue
                                              ? Icons.warning_amber
                                              : Icons.calendar_today,
                                          size: 10,
                                          color: isOverdue
                                              ? _R.rose
                                              : _R.text2,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          _fmtDateShort(t.dueDate!),
                                          style: GoogleFonts.inter(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            color: isOverdue
                                                ? _R.rose
                                                : _R.text2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                // Overdue alert
                                if (isOverdue)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      gradient: _R.roseG,
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'EN RETARD',
                                      style: GoogleFonts.inter(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Menu
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert,
                            size: 18, color: _R.text2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        onSelected: (v) {
                          if (v == 'toggle') {
                            _handleToggle(!t.isDone);
                          }
                          if (v == 'detail') {
                            context.push(
                              '/thix-weeding/staff/${widget.weddingId}/checklist/${t.id}',
                            );
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'toggle',
                            child: Row(
                              children: [
                                Icon(
                                  t.isDone
                                      ? Icons.radio_button_unchecked
                                      : Icons.check_circle_outline,
                                  size: 18,
                                  color: t.isDone ? _R.text2 : _R.green,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  t.isDone
                                      ? 'Marquer à faire'
                                      : 'Marquer faite',
                                  style: GoogleFonts.inter(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'detail',
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline,
                                    size: 18, color: _R.blue),
                                const SizedBox(width: 10),
                                Text('Voir détails',
                                    style:
                                        GoogleFonts.inter(fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
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

// ============================================================================
// EMPTY STATE
// ============================================================================
class _EmptyState extends StatelessWidget {
  final String filter;
  final VoidCallback onAdd;

  const _EmptyState({required this.filter, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final icon = switch (filter) {
      'done' => Icons.celebration_outlined,
      'todo' => Icons.checklist_outlined,
      'overdue' => Icons.warning_amber_outlined,
      'urgent' => Icons.bolt_outlined,
      _ => Icons.task_alt_outlined,
    };
    final title = switch (filter) {
      'done' => 'Aucune tâche accomplie',
      'todo' => 'Tout est fait ! 🎉',
      'overdue' => 'Aucune tâche en retard',
      'urgent' => 'Aucune tâche urgente',
      _ => 'Aucune tâche',
    };
    final subtitle = switch (filter) {
      'done' => 'Complétez des tâches pour les voir ici',
      'todo' => 'Bravo, toutes les tâches sont terminées',
      'overdue' => 'Vous êtes à jour, excellent !',
      'urgent' => 'Pas de tâche urgente pour le moment',
      _ => 'Ajoutez votre première tâche pour commencer',
    };

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: _R.card(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _R.blue.withOpacity(0.15),
                  _R.purple.withOpacity(0.1)
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: _R.blue),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: _R.text2),
          ),
          if (filter == 'all' || filter == 'todo') ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_task, size: 18),
              label: const Text('Ajouter une tâche'),
              style: FilledButton.styleFrom(
                backgroundColor: _R.blue,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// FAB AJOUT DÉTAILLÉ
// ============================================================================
class _AddDetailedFAB extends StatelessWidget {
  final String weddingId;
  final VoidCallback onTap;

  const _AddDetailedFAB({required this.weddingId, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onTap,
      icon: const Icon(Icons.add_task, color: Colors.white),
      label: Text(
        'Nouvelle tâche',
        style: GoogleFonts.inter(
            color: Colors.white, fontWeight: FontWeight.w700),
      ),
      backgroundColor: _R.blue,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}

// ============================================================================
// SHEET AJOUT DÉTAILLÉ
// ============================================================================
class _AddTaskSheet extends StatefulWidget {
  final String weddingId;
  final VoidCallback onSaved;

  const _AddTaskSheet({required this.weddingId, required this.onSaved});

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  String _category = 'autre';
  String _priority = 'medium';
  DateTime? _dueDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final data = {
        'wedding_id': widget.weddingId,
        'title': _titleCtrl.text.trim(),
        'is_done': false,
        'category': _category,
        'priority': _priority,
        if (_dueDate != null)
          'due_date': _dueDate!.toIso8601String().split('T')[0],
      };

      await ProviderScope.containerOf(context)
          .read(checklistServiceProvider)
          .create(data);

      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: _R.rose,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      helpText: 'Date d\'échéance',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _R.blue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _R.text,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _R.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    gradient: _R.royal,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  child: const Icon(Icons.add_task,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Nouvelle tâche',
                  style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Titre
            TextFormField(
              controller: _titleCtrl,
              autofocus: true,
              style: GoogleFonts.inter(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Titre de la tâche *',
                hintText: 'Ex: Réserver le traiteur',
                labelStyle: GoogleFonts.inter(color: _R.text2, fontSize: 13),
                prefixIcon:
                    const Icon(Icons.title_outlined, color: _R.blue),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _R.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _R.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: _R.blue, width: 2),
                ),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: 16),

            // Catégorie
            Text(
              'Catégorie',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _R.text2),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _CATEGORIES.map((c) {
                final isSelected = c.key == _category;
                return Material(
                  color: isSelected ? c.color : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () => setState(() => _category = c.key),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? c.color : _R.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(c.icon,
                              size: 12,
                              color: isSelected ? Colors.white : c.color),
                          const SizedBox(width: 4),
                          Text(
                            c.label,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color:
                                  isSelected ? Colors.white : _R.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Priorité
            Text(
              'Priorité',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _R.text2),
            ),
            const SizedBox(height: 8),
            Row(
              children: _Priority.values.map((p) {
                final isSelected = _priority == p.name;
                final color = _priorityColor(p);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Material(
                      color: isSelected ? color : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () => setState(() => _priority = p.name),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? color : _R.border,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _priorityLabel(p),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : _R.text,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Date d'échéance
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: _R.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          color: _R.blue, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date d\'échéance (optionnel)',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: _R.text2),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _dueDate != null
                                  ? _fmtDateLong(_dueDate!)
                                  : 'Non définie',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _dueDate != null
                                    ? _R.text
                                    : _R.text2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_dueDate != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () =>
                              setState(() => _dueDate = null),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Bouton sauvegarder
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check, size: 18),
                label: Text(
                  _isSaving ? 'Création...' : 'Créer la tâche',
                  style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _R.blue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// LOADING / ERROR
// ============================================================================
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _R.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                  gradient: _R.goldG, shape: BoxShape.circle),
              child: const Icon(Icons.checklist_outlined,
                  color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'Chargement de la checklist...',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _R.text2),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _R.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _R.rose.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline,
                    color: _R.rose, size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                'Impossible de charger',
                style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: _R.text2),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
                style: FilledButton.styleFrom(backgroundColor: _R.blue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// UTILITAIRES
// ============================================================================
String _fmtDateShort(DateTime dt) {
  const months = [
    'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
    'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}

String _fmtDateLong(DateTime dt) {
  const months = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}
