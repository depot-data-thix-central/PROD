// lib/presentation/thix_weeding/pages/staff/planning/planning_page.dart
// ============================================================================
// THIX WEDDING & EVENTS — PLANNING JOUR J (PRODUCTION)
// Design royal + Timeline visuelle + Groupement par date + Statuts + Priorités
// Branché sur providers EXISTANTS du dépôt
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  static const LinearGradient greenG = LinearGradient(
    colors: [green, greenSoft],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient roseG = LinearGradient(
    colors: [rose, Color(0xFFFF6B9D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient amberG = LinearGradient(
    colors: [amber, Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxDecoration card({double r = 14}) => BoxDecoration(
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
// PROVIDER LOCAL (Map dynamique car table planning non modélisée)
// ============================================================================
final planningProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, weddingId) async {
  try {
    final res = await Supabase.instance.client
        .from('thix_weeding_planning')
        .select()
        .eq('wedding_id', weddingId)
        .order('date', ascending: true)
        .order('time', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  } catch (_) {
    return [];
  }
});

// ============================================================================
// STATUTS & PRIORITÉS
// ============================================================================
const Map<String, _StatusDef> _STATUS_MAP = {
  'todo': _StatusDef('À faire', Icons.radio_button_unchecked, Color(0xFF6B7280)),
  'in_progress': _StatusDef('En cours', Icons.play_circle_outline, Color(0xFF0B3B8F)),
  'done': _StatusDef('Terminée', Icons.check_circle, Color(0xFF059669)),
  'cancelled': _StatusDef('Annulée', Icons.cancel_outlined, Color(0xFFE31C4E)),
};

class _StatusDef {
  final String label;
  final IconData icon;
  final Color color;
  const _StatusDef(this.label, this.icon, this.color);
}

_StatusDef _getStatus(String? key) =>
    _STATUS_MAP[key ?? ''] ?? _STATUS_MAP['todo']!;

const Map<String, _PriorityDef> _PRIORITY_MAP = {
  'low': _PriorityDef('Basse', Color(0xFF6B7280)),
  'medium': _PriorityDef('Moyenne', Color(0xFFD97706)),
  'high': _PriorityDef('Haute', Color(0xFFE31C4E)),
  'urgent': _PriorityDef('Urgente', Color(0xFFDC2626)),
};

class _PriorityDef {
  final String label;
  final Color color;
  const _PriorityDef(this.label, this.color);
}

_PriorityDef _getPriority(String? key) =>
    _PRIORITY_MAP[key ?? ''] ?? _PRIORITY_MAP['medium']!;

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class PlanningPage extends ConsumerStatefulWidget {
  final String weddingId;
  const PlanningPage({super.key, required this.weddingId});

  @override
  ConsumerState<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends ConsumerState<PlanningPage>
    with SingleTickerProviderStateMixin {
  String _filter = 'all';

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleStatus(Map<String, dynamic> task) async {
    final currentStatus = task['status'] as String? ?? 'todo';
    final newStatus = currentStatus == 'done' ? 'todo' : 'done';
    try {
      await Supabase.instance.client
          .from('thix_weeding_planning')
          .update({'status': newStatus})
          .eq('id', task['id']);
      ref.invalidate(planningProvider(widget.weddingId));
      if (mounted && newStatus == 'done') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 16)),
            const SizedBox(width: 10),
            Expanded(child: Text('Tâche terminée ✓', style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
          ]),
          backgroundColor: _R.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: _R.rose, behavior: SnackBarBehavior.floating));
      }
    }
  }

  Future<void> _deleteTask(Map<String, dynamic> task) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(padding: const EdgeInsets.all(18), decoration: const BoxDecoration(gradient: _R.roseG, shape: BoxShape.circle), child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 36)),
            const SizedBox(height: 18),
            Text('Supprimer cette tâche ?', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('"${task['title']}" sera définitivement supprimée du planning.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: _R.text2)),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), style: OutlinedButton.styleFrom(foregroundColor: _R.text, side: const BorderSide(color: _R.border), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Annuler'))),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: FilledButton.icon(onPressed: () => Navigator.pop(context, true), icon: const Icon(Icons.delete_outline, size: 18), label: const Text('Supprimer'), style: FilledButton.styleFrom(backgroundColor: _R.rose, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
            ]),
          ]),
        ),
      ),
    );
    if (ok != true) return;
    try {
      await Supabase.instance.client.from('thix_weeding_planning').delete().eq('id', task['id']);
      ref.invalidate(planningProvider(widget.weddingId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: _R.rose, behavior: SnackBarBehavior.floating));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(planningProvider(widget.weddingId));

    return Scaffold(
      backgroundColor: _R.surface,
      body: async.when(
        loading: () => const _LoadingView(),
        error: (e, _) => _ErrorView(message: '$e', onRetry: () => ref.invalidate(planningProvider(widget.weddingId))),
        data: (tasks) => FadeTransition(
          opacity: _fadeAnim,
          child: _PlanningContent(
            weddingId: widget.weddingId,
            tasks: tasks,
            filter: _filter,
            onFilterChanged: (f) => setState(() => _filter = f),
            onToggle: _toggleStatus,
            onDelete: _deleteTask,
            onRefresh: () async => ref.invalidate(planningProvider(widget.weddingId)),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/thix-weeding/staff/${widget.weddingId}/planning/add'),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Nouvelle tâche', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
        backgroundColor: _R.blue,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

// ============================================================================
// CONTENU PRINCIPAL
// ============================================================================
class _PlanningContent extends StatelessWidget {
  final String weddingId;
  final List<Map<String, dynamic>> tasks;
  final String filter;
  final ValueChanged<String> onFilterChanged;
  final Function(Map<String, dynamic>) onToggle;
  final Function(Map<String, dynamic>) onDelete;
  final Future<void> Function() onRefresh;

  const _PlanningContent({
    required this.weddingId,
    required this.tasks,
    required this.filter,
    required this.onFilterChanged,
    required this.onToggle,
    required this.onDelete,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    // Stats
    final total = tasks.length;
    final done = tasks.where((t) => t['status'] == 'done').length;
    final inProgress = tasks.where((t) => t['status'] == 'in_progress').length;
    final todo = tasks.where((t) => t['status'] == 'todo' || t['status'] == null).length;

    // Filtrage
    final filtered = tasks.where((t) {
      if (filter == 'all') return true;
      if (filter == 'todo') return t['status'] == 'todo' || t['status'] == null;
      return t['status'] == filter;
    }).toList();

    // Groupement par date
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final t in filtered) {
      final date = (t['date'] as String?) ?? 'Sans date';
      grouped.putIfAbsent(date, () => []).add(t);
    }

    // Trier les dates
    final sortedDates = grouped.keys.toList()..sort();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── APP BAR ───────────────────────────────────────────────────
        _PlanningAppBar(
          weddingId: weddingId,
          total: total,
          done: done,
          inProgress: inProgress,
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ── STATS HERO ─────────────────────────────────────────
              _StatsHero(total: total, done: done, inProgress: inProgress, todo: todo),
              const SizedBox(height: 16),

              // ── FILTRES ────────────────────────────────────────────
              _FilterRow(filter: filter, onChanged: onFilterChanged),
              const SizedBox(height: 16),

              // ── LISTE / EMPTY ──────────────────────────────────────
              if (sortedDates.isEmpty)
                _EmptyState(filter: filter, weddingId: weddingId)
              else
                RefreshIndicator(
                  color: _R.blue,
                  onRefresh: onRefresh,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: sortedDates.map((date) {
                      final dayTasks = grouped[date]!;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: _DayGroup(
                          date: date,
                          tasks: dayTasks,
                          weddingId: weddingId,
                          onToggle: onToggle,
                          onDelete: onDelete,
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
class _PlanningAppBar extends StatelessWidget {
  final String weddingId;
  final int total;
  final int done;
  final int inProgress;

  const _PlanningAppBar({required this.weddingId, required this.total, required this.done, required this.inProgress});

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
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)]),
          child: const Icon(Icons.arrow_back_ios_new, size: 14, color: _R.text),
        ),
        onPressed: () => context.pop(),
      ),
      actions: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => context.push('/thix-weeding/staff/$weddingId/planning/add'),
            child: Container(padding: const EdgeInsets.all(10), child: const Icon(Icons.add_task_outlined, color: _R.blue, size: 20)),
          ),
        ),
        const SizedBox(width: 10),
      ],
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: _R.royal,
          borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
        ),
        child: Stack(
          children: [
            Positioned(right: -60, top: -60, child: Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08)))),
            Positioned(right: 30, bottom: -40, child: Container(width: 140, height: 140, decoration: BoxDecoration(shape: BoxShape.circle, color: _R.gold.withOpacity(0.15)))),
            FlexibleSpaceBar(
              background: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(children: [
                        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.schedule_outlined, color: Colors.white, size: 16)),
                        const SizedBox(width: 8),
                        Text('PLANNING JOUR J', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.85), letterSpacing: 2)),
                      ]),
                      const SizedBox(height: 8),
                      Text('Programme détaillé', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                      Text('$total événement${total > 1 ? 's' : ''} • $done terminé${done > 1 ? 's' : ''} • $inProgress en cours', style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.9))),
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

// ============================================================================
// STATS HERO
// ============================================================================
class _StatsHero extends StatelessWidget {
  final int total;
  final int done;
  final int inProgress;
  final int todo;

  const _StatsHero({required this.total, required this.done, required this.inProgress, required this.todo});

  @override
  Widget build(BuildContext context) {
    final ratio = total > 0 ? done / total : 0.0;
    final pctInt = (ratio * 100).toInt();
    final gradient = pctInt >= 80 ? _R.greenG : pctInt >= 50 ? _R.goldG : pctInt >= 25 ? _R.amberG : _R.roseG;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _R.blue.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Stack(alignment: Alignment.center, children: [
            SizedBox(width: 64, height: 64, child: CircularProgressIndicator(value: ratio, strokeWidth: 6, backgroundColor: Colors.white.withOpacity(0.2), valueColor: const AlwaysStoppedAnimation(Colors.white))),
            Text('$pctInt%', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
          ]),
          const SizedBox(width: 16),
          Expanded(
            child: Row(children: [
              _HeroStat(icon: Icons.list_alt, label: 'Total', value: '$total'),
              const SizedBox(width: 10),
              _HeroStat(icon: Icons.check_circle_outline, label: 'Faites', value: '$done'),
              const SizedBox(width: 10),
              _HeroStat(icon: Icons.play_circle_outline, label: 'En cours', value: '$inProgress'),
              const SizedBox(width: 10),
              _HeroStat(icon: Icons.radio_button_unchecked, label: 'À faire', value: '$todo'),
            ]),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _HeroStat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Icon(icon, color: Colors.white, size: 16),
        const SizedBox(height: 3),
        Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
        Text(label, style: GoogleFonts.inter(fontSize: 8, color: Colors.white.withOpacity(0.85))),
      ]),
    );
  }
}

// ============================================================================
// FILTER ROW
// ============================================================================
class _FilterRow extends StatelessWidget {
  final String filter;
  final ValueChanged<String> onChanged;

  const _FilterRow({required this.filter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _FilterChip(label: 'Toutes', icon: Icons.all_inbox, color: _R.blue, isSelected: filter == 'all', onTap: () => onChanged('all')),
        const SizedBox(width: 8),
        _FilterChip(label: 'À faire', icon: Icons.radio_button_unchecked, color: _R.text2, isSelected: filter == 'todo', onTap: () => onChanged('todo')),
        const SizedBox(width: 8),
        _FilterChip(label: 'En cours', icon: Icons.play_circle_outline, color: _R.blue, isSelected: filter == 'in_progress', onTap: () => onChanged('in_progress')),
        const SizedBox(width: 8),
        _FilterChip(label: 'Terminées', icon: Icons.check_circle, color: _R.green, isSelected: filter == 'done', onTap: () => onChanged('done')),
      ]),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.icon, required this.color, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? color : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : _R.border, width: isSelected ? 1.5 : 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : color),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : _R.text)),
          ]),
        ),
      ),
    );
  }
}

// ============================================================================
// DAY GROUP (avec timeline connector)
// ============================================================================
class _DayGroup extends StatelessWidget {
  final String date;
  final List<Map<String, dynamic>> tasks;
  final String weddingId;
  final Function(Map<String, dynamic>) onToggle;
  final Function(Map<String, dynamic>) onDelete;

  const _DayGroup({required this.date, required this.tasks, required this.weddingId, required this.onToggle, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isToday = date == DateTime.now().toString().substring(0, 10);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date header
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: isToday ? _R.goldG : _R.royal,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: (isToday ? _R.gold : _R.blue).withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(isToday ? Icons.today : Icons.calendar_today, color: Colors.white, size: 14),
            const SizedBox(width: 6),
            Text(
              isToday ? "AUJOURD'HUI — $date" : _formatDateHeader(date),
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(8)),
              child: Text('${tasks.length}', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ]),
        ),

        // Tasks with timeline
        ...tasks.asMap().entries.map((entry) {
          final i = entry.key;
          final t = entry.value;
          final showConnector = i < tasks.length - 1;
          return _TimelineTaskCard(
            task: t,
            weddingId: weddingId,
            onToggle: () => onToggle(t),
            onDelete: () => onDelete(t),
            showConnector: showConnector,
          );
        }),
      ],
    );
  }
}

// ============================================================================
// TIMELINE TASK CARD
// ============================================================================
class _TimelineTaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final String weddingId;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final bool showConnector;

  const _TimelineTaskCard({required this.task, required this.weddingId, required this.onToggle, required this.onDelete, required this.showConnector});

  @override
  Widget build(BuildContext context) {
    final status = _getStatus(task['status'] as String?);
    final priority = _getPriority(task['priority'] as String?);
    final isDone = status.label == 'Terminée';
    final time = task['time'] as String?;
    final location = task['location'] as String?;
    final title = task['title'] as String? ?? 'Sans titre';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline connector
          SizedBox(
            width: 32,
            child: Column(children: [
              GestureDetector(
                onTap: onToggle,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDone ? _R.green.withOpacity(0.15) : priority.color.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: isDone ? _R.green : priority.color, width: 2),
                  ),
                  child: Icon(status.icon, size: 12, color: isDone ? _R.green : priority.color),
                ),
              ),
              if (showConnector) Expanded(child: Container(width: 2, color: isDone ? _R.green.withOpacity(0.25) : _R.border)),
            ]),
          ),
          const SizedBox(width: 8),

          // Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () => context.push('/thix-weeding/staff/$weddingId/planning/add?edit=${task['id']}'),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDone ? _R.green.withOpacity(0.3) : priority.color.withOpacity(0.3), width: isDone ? 1.5 : 1),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: isDone ? FontWeight.w500 : FontWeight.w800,
                                color: isDone ? _R.text2 : _R.text,
                                decoration: isDone ? TextDecoration.lineThrough : null,
                                decorationColor: _R.text2,
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 18, color: _R.text2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onSelected: (v) {
                              if (v == 'edit') context.push('/thix-weeding/staff/$weddingId/planning/add?edit=${task['id']}');
                              if (v == 'delete') onDelete();
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(value: 'edit', child: Row(children: [const Icon(Icons.edit_outlined, size: 18, color: _R.blue), const SizedBox(width: 10), Text('Modifier', style: GoogleFonts.inter(fontSize: 13))])),
                              const PopupMenuDivider(),
                              PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete_outline, size: 18, color: _R.rose), const SizedBox(width: 10), Text('Supprimer', style: GoogleFonts.inter(fontSize: 13, color: _R.rose))])),
                            ],
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, runSpacing: 4, children: [
                          // Heure
                          if (time != null && time.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(color: _R.blue.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.access_time, size: 10, color: _R.blue),
                                const SizedBox(width: 3),
                                Text(time, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _R.blue)),
                              ]),
                            ),
                          // Lieu
                          if (location != null && location.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(color: _R.purple.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.place, size: 10, color: _R.purple),
                                const SizedBox(width: 3),
                                Text(location, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: _R.purple)),
                              ]),
                            ),
                          // Priorité
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(color: priority.color.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: priority.color.withOpacity(0.3))),
                            child: Text(priority.label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: priority.color)),
                          ),
                          // Statut
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(color: status.color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(status.icon, size: 10, color: status.color),
                              const SizedBox(width: 3),
                              Text(status.label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: status.color)),
                            ]),
                          ),
                        ]),
                      ],
                    ),
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
  final String weddingId;

  const _EmptyState({required this.filter, required this.weddingId});

  @override
  Widget build(BuildContext context) {
    final title = switch (filter) {
      'done' => 'Aucune tâche terminée',
      'todo' => 'Tout est fait ! 🎉',
      'in_progress' => 'Aucune tâche en cours',
      _ => 'Aucune tâche planifiée',
    };
    final subtitle = switch (filter) {
      'done' => 'Complétez des tâches pour les voir ici',
      'todo' => 'Bravo, toutes les tâches sont terminées',
      'in_progress' => 'Démarrez une tâche pour la voir ici',
      _ => 'Ajoutez votre première tâche au planning',
    };

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: _R.card(),
      child: Column(children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: LinearGradient(colors: [_R.blue.withOpacity(0.15), _R.purple.withOpacity(0.1)]), shape: BoxShape.circle), child: const Icon(Icons.schedule_outlined, size: 40, color: _R.blue)),
        const SizedBox(height: 16),
        Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(subtitle, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: _R.text2)),
        if (filter == 'all') ...[
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => context.push('/thix-weeding/staff/$weddingId/planning/add'),
            icon: const Icon(Icons.add_task, size: 18),
            label: const Text('Ajouter une tâche'),
            style: FilledButton.styleFrom(backgroundColor: _R.blue, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ],
      ]),
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
    return Scaffold(backgroundColor: _R.surface, body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(gradient: _R.goldG, shape: BoxShape.circle), child: const Icon(Icons.schedule_outlined, color: Colors.white, size: 36)),
      const SizedBox(height: 16),
      Text('Chargement du planning...', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _R.text2)),
    ])));
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: _R.surface, body: Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _R.rose.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.error_outline, color: _R.rose, size: 40)),
      const SizedBox(height: 16),
      Text('Impossible de charger', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: _R.text2)),
      const SizedBox(height: 20),
      FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Réessayer'), style: FilledButton.styleFrom(backgroundColor: _R.blue)),
    ]))));
  }
}

// ============================================================================
// UTILITAIRES
// ============================================================================
String _formatDateHeader(String dateStr) {
  try {
    final dt = DateTime.parse(dateStr);
    const months = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) return "AUJOURD'HUI";
    if (dt.year == tomorrow.year && dt.month == tomorrow.month && dt.day == tomorrow.day) return 'DEMAIN';
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  } catch (_) {
    return dateStr;
  }
}
