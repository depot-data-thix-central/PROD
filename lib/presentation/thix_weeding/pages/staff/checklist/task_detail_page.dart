// lib/presentation/thix_weeding/pages/staff/checklist/task_detail_page.dart
// ============================================================================
// THIX WEDDING & EVENTS — TASK DETAIL (PRODUCTION)
// Design royal + Édition complète + Timeline + Priorité + Catégorie + Suppression
// Branché sur providers & services EXISTANTS du dépôt
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/services/thix_weeding_services.dart';

// ============================================================================
// PROVIDER LOCAL
// ============================================================================
final checklistDetailProvider =
    FutureProvider.family<ChecklistModel, String>((ref, taskId) async {
  return await ref.read(checklistServiceProvider).getById(taskId);
});

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
// CATÉGORIES & PRIORITÉS
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

enum _Priority { low, medium, high, urgent }

_Priority _parsePriority(String? p) {
  switch (p) {
    case 'high': return _Priority.high;
    case 'urgent': return _Priority.urgent;
    case 'low': return _Priority.low;
    default: return _Priority.medium;
  }
}

Color _priorityColor(_Priority p) {
  switch (p) {
    case _Priority.low: return _R.text2;
    case _Priority.medium: return _R.blue;
    case _Priority.high: return _R.amber;
    case _Priority.urgent: return _R.rose;
  }
}

String _priorityLabel(_Priority p) {
  switch (p) {
    case _Priority.low: return 'Basse';
    case _Priority.medium: return 'Moyenne';
    case _Priority.high: return 'Haute';
    case _Priority.urgent: return 'Urgente';
  }
}

// ============================================================================
// PAGE
// ============================================================================
class TaskDetailPage extends ConsumerStatefulWidget {
  final String weddingId;
  final String taskId;

  const TaskDetailPage({super.key, required this.weddingId, required this.taskId});

  @override
  ConsumerState<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends ConsumerState<TaskDetailPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime? _dueDate;
  bool _isDone = false;
  String _category = 'autre';
  String _priority = 'medium';
  bool _isLoading = false;
  bool _isInitialized = false;

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
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ============================================================================
  // ACTIONS
  // ============================================================================
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await ref.read(checklistServiceProvider).update(widget.taskId, {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'due_date': _dueDate?.toIso8601String().split('T')[0],
        'is_done': _isDone,
        'category': _category,
        'priority': _priority,
      });

      ref.invalidate(checklistDetailProvider(widget.taskId));
      ref.invalidate(checklistProvider(widget.weddingId));
      ref.invalidate(dashboardStatsProvider(widget.weddingId));

      if (mounted) {
        _showSuccess('Tâche mise à jour ✓');
        context.pop();
      }
    } catch (e) {
      if (mounted) _showError('Erreur: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleDone(bool? value) async {
    setState(() => _isDone = value ?? false);
    try {
      await ref.read(checklistServiceProvider).toggle(widget.taskId, _isDone);
      ref.invalidate(checklistDetailProvider(widget.taskId));
      ref.invalidate(checklistProvider(widget.weddingId));
      ref.invalidate(dashboardStatsProvider(widget.weddingId));
      if (mounted && _isDone) _showSuccess('Tâche accomplie 🎉');
    } catch (e) {
      if (mounted) _showError('Erreur: $e');
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (_) => _DeleteDialog(),
    );
    if (ok != true) return;

    try {
      await ref.read(checklistServiceProvider).delete(widget.taskId);
      ref.invalidate(checklistProvider(widget.weddingId));
      ref.invalidate(dashboardStatsProvider(widget.weddingId));
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) _showError('Erreur: $e');
    }
  }

  Future<void> _pickDueDate() async {
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

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
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

  // ============================================================================
  // BUILD
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    final taskAsync = ref.watch(checklistDetailProvider(widget.taskId));

    return Scaffold(
      backgroundColor: _R.surface,
      body: taskAsync.when(
        loading: () => const _LoadingView(),
        error: (e, _) => _ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(checklistDetailProvider(widget.taskId)),
        ),
        data: (task) {
          if (!_isInitialized) {
            _titleCtrl.text = task.title;
            _descCtrl.text = task.description ?? '';
            _isDone = task.isDone;
            _dueDate = task.dueDate;
            _category = task.category ?? 'autre';
            _priority = task.priority ?? 'medium';
            _isInitialized = true;
          }

          return FadeTransition(
            opacity: _fadeAnim,
            child: Form(
              key: _formKey,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _DetailAppBar(
                    task: task,
                    isDone: _isDone,
                    onToggle: _toggleDone,
                    onDelete: _delete,
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // ── STATUT HERO ────────────────────────────────
                        _StatusHero(
                          task: task,
                          isDone: _isDone,
                          onToggle: _toggleDone,
                        ),
                        const SizedBox(height: 16),

                        // ── TITRE + DESCRIPTION ──────────────────────
                        _SectionCard(
                          title: 'Informations',
                          icon: Icons.info_outline,
                          color: _R.blue,
                          children: [
                            _RoyalTextField(
                              controller: _titleCtrl,
                              label: 'Titre de la tâche',
                              hint: 'Ex: Réserver le traiteur',
                              icon: Icons.task_alt_outlined,
                              validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
                            ),
                            const SizedBox(height: 14),
                            _RoyalTextField(
                              controller: _descCtrl,
                              label: 'Description (optionnel)',
                              hint: 'Détails supplémentaires...',
                              icon: Icons.notes_outlined,
                              maxLines: 4,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ── CATÉGORIE ─────────────────────────────────
                        _SectionCard(
                          title: 'Catégorie',
                          icon: Icons.category_outlined,
                          color: _R.purple,
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _CATEGORIES.map((c) {
                                final isSelected = c.key == _category;
                                return Material(
                                  color: isSelected ? c.color : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  child: InkWell(
                                    onTap: () => setState(() => _category = c.key),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isSelected ? c.color : _R.border,
                                          width: isSelected ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(c.icon, size: 14, color: isSelected ? Colors.white : c.color),
                                          const SizedBox(width: 5),
                                          Text(
                                            c.label,
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: isSelected ? Colors.white : _R.text,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ── PRIORITÉ ──────────────────────────────────
                        _SectionCard(
                          title: 'Priorité',
                          icon: Icons.flag_outlined,
                          color: _R.amber,
                          children: [
                            Row(
                              children: _Priority.values.map((p) {
                                final isSelected = _priority == p.name;
                                final color = _priorityColor(p);
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Material(
                                      color: isSelected ? color : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      child: InkWell(
                                        onTap: () => setState(() => _priority = p.name),
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: isSelected ? color : _R.border,
                                              width: isSelected ? 1.5 : 1,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              _priorityLabel(p),
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: isSelected ? Colors.white : _R.text,
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
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ── PLANIFICATION ─────────────────────────────
                        _SectionCard(
                          title: 'Planification',
                          icon: Icons.schedule_outlined,
                          color: _R.gold,
                          children: [
                            _DueDateTile(
                              dueDate: _dueDate,
                              onTap: _pickDueDate,
                              onClear: () => setState(() => _dueDate = null),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ── MÉTADONNÉES ───────────────────────────────
                        _MetaCard(task: task),
                        const SizedBox(height: 24),

                        // ── BOUTONS D'ACTION ──────────────────────────
                        _SaveButton(isLoading: _isLoading, onSave: _save),
                        const SizedBox(height: 12),
                        _DeleteButton(onDelete: _delete),
                      ]),
                    ),
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

// ============================================================================
// APP BAR DÉTAIL
// ============================================================================
class _DetailAppBar extends StatelessWidget {
  final ChecklistModel task;
  final bool isDone;
  final Function(bool?) onToggle;
  final VoidCallback onDelete;

  const _DetailAppBar({
    required this.task,
    required this.isDone,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final priority = _parsePriority(task.priority);
    final pColor = _priorityColor(priority);
    final category = _findCategory(task.category);

    return SliverAppBar(
      expandedHeight: 160,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
          ),
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
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(10),
              child: const Icon(Icons.delete_outline, color: _R.rose, size: 20),
            ),
          ),
        ),
        const SizedBox(width: 10),
      ],
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: isDone ? _R.greenG : _R.royal,
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
                            child: Icon(
                              isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isDone ? 'TÂCHE ACCOMPLIE' : 'DÉTAIL DE LA TÂCHE',
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
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(category.icon, size: 12, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  category.label,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: pColor.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _priorityLabel(priority),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
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

// ============================================================================
// STATUS HERO
// ============================================================================
class _StatusHero extends StatelessWidget {
  final ChecklistModel task;
  final bool isDone;
  final Function(bool?) onToggle;

  const _StatusHero({
    required this.task,
    required this.isDone,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue = !isDone && task.dueDate != null && task.dueDate!.isBefore(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isDone
            ? _R.greenG
            : isOverdue
                ? _R.roseG
                : _R.goldG,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isDone ? _R.green : isOverdue ? _R.rose : _R.gold).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDone ? Icons.verified : isOverdue ? Icons.warning_amber : Icons.schedule,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDone
                      ? 'Tâche terminée'
                      : isOverdue
                          ? 'En retard !'
                          : 'En cours',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  isDone
                      ? 'Cette tâche a été accomplie'
                      : isOverdue
                          ? 'Échéance dépassée — action requise'
                          : task.dueDate != null
                              ? 'Échéance : ${_fmtDateLong(task.dueDate!)}'
                              : 'Aucune échéance définie',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          if (!isDone)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onToggle(true),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Terminer',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
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
// SECTION CARD
// ============================================================================
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _R.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

// ============================================================================
// TEXT FIELD ROYAL
// ============================================================================
class _RoyalTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final String? Function(String?)? validator;

  const _RoyalTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.inter(color: _R.text2, fontSize: 13),
        hintStyle: GoogleFonts.inter(color: _R.text2.withOpacity(0.6), fontSize: 13),
        prefixIcon: Icon(icon, color: _R.blue, size: 20),
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
          borderSide: const BorderSide(color: _R.blue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _R.rose),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: validator,
    );
  }
}

// ============================================================================
// DUE DATE TILE
// ============================================================================
class _DueDateTile extends StatelessWidget {
  final DateTime? dueDate;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DueDateTile({
    required this.dueDate,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue = dueDate != null && dueDate!.isBefore(DateTime.now());

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: dueDate != null
                ? (isOverdue ? _R.rose.withOpacity(0.08) : _R.blue.withOpacity(0.05))
                : _R.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: dueDate != null
                  ? (isOverdue ? _R.rose.withOpacity(0.3) : _R.blue.withOpacity(0.2))
                  : _R.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: dueDate != null
                      ? (isOverdue ? _R.rose : _R.blue).withOpacity(0.15)
                      : _R.border.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.calendar_today_outlined,
                  size: 20,
                  color: dueDate != null
                      ? (isOverdue ? _R.rose : _R.blue)
                      : _R.text2,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date d\'échéance',
                      style: GoogleFonts.inter(fontSize: 11, color: _R.text2),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dueDate != null ? _fmtDateLong(dueDate!) : 'Non définie',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: dueDate != null
                            ? (isOverdue ? _R.rose : _R.text)
                            : _R.text2,
                      ),
                    ),
                  ],
                ),
              ),
              if (dueDate != null)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: _R.text2),
                  onPressed: onClear,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// META CARD
// ============================================================================
class _MetaCard extends StatelessWidget {
  final ChecklistModel task;

  const _MetaCard({required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _R.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _R.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _R.text2.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.fingerprint, size: 14, color: _R.text2),
              ),
              const SizedBox(width: 8),
              Text(
                'Métadonnées',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _R.text2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MetaRow(label: 'ID unique', value: task.id),
          _MetaRow(
            label: 'Créée le',
            value: _fmtDateTime(task.createdAt),
          ),
          if (task.orderIndex != null)
            _MetaRow(label: 'Ordre', value: '${task.orderIndex}'),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 11, color: _R.text2),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _R.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SAVE BUTTON
// ============================================================================
class _SaveButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onSave;

  const _SaveButton({required this.isLoading, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: isLoading ? null : _R.royal,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isLoading
            ? null
            : [
                BoxShadow(
                  color: _R.blue.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Material(
        color: isLoading ? _R.border : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: isLoading ? null : onSave,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.save_outlined, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Enregistrer les modifications',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// DELETE BUTTON
// ============================================================================
class _DeleteButton extends StatelessWidget {
  final VoidCallback onDelete;

  const _DeleteButton({required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _R.rose.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onDelete,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.delete_outline, color: _R.rose, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Supprimer cette tâche',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _R.rose,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// DELETE DIALOG
// ============================================================================
class _DeleteDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                gradient: _R.roseG,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 18),
            Text(
              'Supprimer cette tâche ?',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _R.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cette action est irréversible. La tâche sera définitivement supprimée de la checklist.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: _R.text2),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _R.text,
                      side: const BorderSide(color: _R.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Supprimer'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _R.rose,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
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
              decoration: const BoxDecoration(gradient: _R.goldG, shape: BoxShape.circle),
              child: const Icon(Icons.hourglass_empty, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'Chargement...',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _R.text2),
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
                child: const Icon(Icons.error_outline, color: _R.rose, size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                'Impossible de charger',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
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
String _fmtDateLong(DateTime dt) {
  const months = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}

String _fmtDateTime(DateTime dt) {
  const months = [
    'jan', 'fév', 'mar', 'avr', 'mai', 'jun',
    'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'
  ];
  final day = dt.day.toString().padLeft(2, '0');
  final month = months[dt.month - 1];
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$day $month ${dt.year} à $h:$m';
}
