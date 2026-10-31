// lib/presentation/thix_weeding/pages/staff/planning/task_form_page.dart
// ============================================================================
// THIX WEDDING & EVENTS — TASK FORM (PRODUCTION)
// Design royal + Validation + Date/Time pickers stylés + Priorités + Statuts
// Branché sur Supabase EXISTANT du dépôt
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
// STATUTS & PRIORITÉS
// ============================================================================
const List<_StatusOption> _STATUSES = [
  _StatusOption('todo', 'À faire', Icons.radio_button_unchecked, Color(0xFF6B7280)),
  _StatusOption('in_progress', 'En cours', Icons.play_circle_outline, Color(0xFF0B3B8F)),
  _StatusOption('done', 'Terminée', Icons.check_circle, Color(0xFF059669)),
  _StatusOption('cancelled', 'Annulée', Icons.cancel_outlined, Color(0xFFE31C4E)),
];

class _StatusOption {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const _StatusOption(this.value, this.label, this.icon, this.color);
}

const List<_PriorityOption> _PRIORITIES = [
  _PriorityOption('low', 'Basse', Color(0xFF6B7280)),
  _PriorityOption('medium', 'Moyenne', Color(0xFFD97706)),
  _PriorityOption('high', 'Haute', Color(0xFFE31C4E)),
  _PriorityOption('urgent', 'Urgente', Color(0xFFDC2626)),
];

class _PriorityOption {
  final String value;
  final String label;
  final Color color;
  const _PriorityOption(this.value, this.label, this.color);
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class TaskFormPage extends StatefulWidget {
  final String weddingId;
  final String? editTaskId;

  const TaskFormPage({super.key, required this.weddingId, this.editTaskId});

  @override
  State<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends State<TaskFormPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  DateTime _date = DateTime.now();
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  String _status = 'todo';
  String _priority = 'medium';
  bool _isLoading = false;
  bool _isInitLoading = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  bool get _isEdit => widget.editTaskId != null;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();

    if (_isEdit) _loadTask();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ============================================================================
  // LOAD
  // ============================================================================
  Future<void> _loadTask() async {
    setState(() => _isInitLoading = true);
    try {
      final t = await Supabase.instance.client
          .from('thix_weeding_planning')
          .select()
          .eq('id', widget.editTaskId!)
          .single();

      setState(() {
        _titleCtrl.text = t['title'] as String? ?? '';
        _descCtrl.text = t['description'] as String? ?? '';
        _locationCtrl.text = t['location'] as String? ?? '';
        _status = t['status'] as String? ?? 'todo';
        _priority = t['priority'] as String? ?? 'medium';

        if (t['date'] != null) {
          _date = DateTime.parse(t['date'] as String);
        }
        if (t['time'] != null) {
          final parts = (t['time'] as String).split(':');
          if (parts.length >= 2) {
            _time = TimeOfDay(
              hour: int.tryParse(parts[0]) ?? 9,
              minute: int.tryParse(parts[1]) ?? 0,
            );
          }
        }
      });
    } catch (e) {
      if (mounted) _showError('Erreur chargement: $e');
    } finally {
      if (mounted) setState(() => _isInitLoading = false);
    }
  }

  // ============================================================================
  // SAVE
  // ============================================================================
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final data = {
        'wedding_id': widget.weddingId,
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'date': _date.toIso8601String().split('T')[0],
        'time': '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
        'location': _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
        'status': _status,
        'priority': _priority,
      };

      if (!_isEdit) {
        final inserted = await Supabase.instance.client
            .from('thix_weeding_planning')
            .insert(data)
            .select()
            .single();
        if (mounted) {
          _showSuccess('Tâche créée • ID: ${(inserted['id'] as String).substring(0, 8)} ✓');
        }
      } else {
        await Supabase.instance.client
            .from('thix_weeding_planning')
            .update(data)
            .eq('id', widget.editTaskId!);
        if (mounted) _showSuccess('Tâche mise à jour ✓');
      }

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) _showError('Erreur: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================================
  // PICKERS
  // ============================================================================
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      helpText: 'Date de la tâche',
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
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'Heure de la tâche',
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
    if (picked != null) setState(() => _time = picked);
  }

  // ============================================================================
  // FEEDBACK
  // ============================================================================
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
    if (_isInitLoading) {
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
              Text('Chargement...', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _R.text2)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _R.surface,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Form(
          key: _formKey,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── APP BAR ──────────────────────────────────────────────
              _FormAppBar(
                isEdit: _isEdit,
                onSave: _save,
                isLoading: _isLoading,
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── TITRE + DESCRIPTION ────────────────────────────
                    _SectionCard(
                      title: 'Informations',
                      icon: Icons.info_outline,
                      color: _R.blue,
                      children: [
                        _RoyalTextField(
                          controller: _titleCtrl,
                          label: 'Titre de la tâche',
                          hint: 'Ex: Dégustation traiteur',
                          icon: Icons.title_outlined,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Titre requis' : null,
                        ),
                        const SizedBox(height: 14),
                        _RoyalTextField(
                          controller: _descCtrl,
                          label: 'Description (optionnel)',
                          hint: 'Détails supplémentaires...',
                          icon: Icons.notes_outlined,
                          maxLines: 3,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── DATE + HEURE ───────────────────────────────────
                    _SectionCard(
                      title: 'Planification',
                      icon: Icons.schedule_outlined,
                      color: _R.gold,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _DateTimeTile(
                                icon: Icons.calendar_today_outlined,
                                label: 'Date',
                                value: _formatDate(_date),
                                onTap: _pickDate,
                                color: _R.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _DateTimeTile(
                                icon: Icons.access_time_outlined,
                                label: 'Heure',
                                value: _time.format(context),
                                onTap: _pickTime,
                                color: _R.purple,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _RoyalTextField(
                          controller: _locationCtrl,
                          label: 'Lieu (optionnel)',
                          hint: 'Ex: Salle principale, Église...',
                          icon: Icons.place_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── STATUT ─────────────────────────────────────────
                    _SectionCard(
                      title: 'Statut',
                      icon: Icons.flag_outlined,
                      color: _R.green,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _STATUSES.map((s) {
                            final isSelected = _status == s.value;
                            return Material(
                              color: isSelected ? s.color : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                onTap: () => setState(() => _status = s.value),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? s.color : _R.border,
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(s.icon, size: 16, color: isSelected ? Colors.white : s.color),
                                      const SizedBox(width: 6),
                                      Text(
                                        s.label,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
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

                    // ── PRIORITÉ ───────────────────────────────────────
                    _SectionCard(
                      title: 'Priorité',
                      icon: Icons.priority_high_outlined,
                      color: _R.amber,
                      children: [
                        Row(
                          children: _PRIORITIES.map((p) {
                            final isSelected = _priority == p.value;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Material(
                                  color: isSelected ? p.color : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  child: InkWell(
                                    onTap: () => setState(() => _priority = p.value),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isSelected ? p.color : _R.border,
                                          width: isSelected ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          p.label,
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
                    const SizedBox(height: 24),

                    // ── BOUTON SOUMETTRE ──────────────────────────────
                    _SubmitButton(
                      isEdit: _isEdit,
                      isLoading: _isLoading,
                      onTap: _save,
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun', 'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

// ============================================================================
// APP BAR
// ============================================================================
class _FormAppBar extends StatelessWidget {
  final bool isEdit;
  final VoidCallback onSave;
  final bool isLoading;

  const _FormAppBar({required this.isEdit, required this.onSave, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: Colors.white,
      elevation: 0,
      foregroundColor: _R.text,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        onPressed: () => context.pop(),
      ),
      title: Text(
        isEdit ? 'Modifier la tâche' : 'Nouvelle tâche',
        style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: _R.blue, fontSize: 18),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: Material(
            color: isLoading ? _R.border : _R.green,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: isLoading ? null : onSave,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: isLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.check, size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(isEdit ? 'Enregistrer' : 'Créer', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                      ]),
              ),
            ),
          ),
        ),
      ],
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

  const _SectionCard({required this.title, required this.icon, required this.color, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _R.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _R.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _R.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _R.blue, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _R.rose)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: validator,
    );
  }
}

// ============================================================================
// DATE/TIME TILE
// ============================================================================
class _DateTimeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final Color color;

  const _DateTimeTile({required this.icon, required this.label, required this.value, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: _R.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: GoogleFonts.inter(fontSize: 11, color: _R.text2)),
                    const SizedBox(height: 2),
                    Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: _R.text)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: _R.text2),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SUBMIT BUTTON
// ============================================================================
class _SubmitButton extends StatelessWidget {
  final bool isEdit;
  final bool isLoading;
  final VoidCallback onTap;

  const _SubmitButton({required this.isEdit, required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: isLoading ? null : _R.royal,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isLoading ? null : [BoxShadow(color: _R.blue.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Material(
        color: isLoading ? _R.border : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: isLoading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(isEdit ? Icons.check : Icons.add_task, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      isEdit ? 'Enregistrer les modifications' : 'Créer la tâche',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ]),
          ),
        ),
      ),
    );
  }
}
