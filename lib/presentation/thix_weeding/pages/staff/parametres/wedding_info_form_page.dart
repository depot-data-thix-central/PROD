// lib/presentation/thix_weeding/pages/staff/parametres/wedding_info_form_page.dart
// ============================================================================
// THIX WEDDING & EVENTS — WEDDING INFO FORM (PRODUCTION)
// Design royal + Validation + Date picker stylé + Feedback premium
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
  static const Color surface = Color(0xFFF8FAFC);
  static const Color cream = Color(0xFFFFFBF5);
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
// PAGE PRINCIPALE
// ============================================================================
class WeddingInfoFormPage extends StatefulWidget {
  final String weddingId;
  const WeddingInfoFormPage({super.key, required this.weddingId});

  @override
  State<WeddingInfoFormPage> createState() => _WeddingInfoFormPageState();
}

class _WeddingInfoFormPageState extends State<WeddingInfoFormPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _brideCtrl = TextEditingController();
  final _groomCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  DateTime? _weddingDate;
  bool _isLoading = true;
  bool _isSaving = false;

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
    _loadWedding();
  }

  @override
  void dispose() {
    _brideCtrl.dispose();
    _groomCtrl.dispose();
    _venueCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ============================================================================
  // LOAD
  // ============================================================================
  Future<void> _loadWedding() async {
    try {
      final w = await Supabase.instance.client
          .from('thix_weeding_weddings')
          .select()
          .eq('id', widget.weddingId)
          .single();

      setState(() {
        _brideCtrl.text = w['bride_name'] as String? ?? '';
        _groomCtrl.text = w['groom_name'] as String? ?? '';
        _venueCtrl.text = w['venue'] as String? ?? '';
        if (w['wedding_date'] != null) {
          _weddingDate = DateTime.parse(w['wedding_date'] as String);
        }
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Erreur chargement: $e');
      }
    }
  }

  // ============================================================================
  // SAVE
  // ============================================================================
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await Supabase.instance.client
          .from('thix_weeding_weddings')
          .update({
            'bride_name': _brideCtrl.text.trim(),
            'groom_name': _groomCtrl.text.trim(),
            'venue': _venueCtrl.text.trim().isEmpty ? null : _venueCtrl.text.trim(),
            'wedding_date': _weddingDate?.toIso8601String().split('T')[0],
          })
          .eq('id', widget.weddingId);

      if (mounted) {
        _showSuccess('Informations du mariage mises à jour ✓');
        context.pop();
      }
    } catch (e) {
      if (mounted) _showError('Erreur: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ============================================================================
  // DATE PICKER
  // ============================================================================
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _weddingDate ?? DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1460)),
      helpText: 'Date du mariage',
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
    if (picked != null) setState(() => _weddingDate = picked);
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
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _R.cream,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(gradient: _R.goldG, shape: BoxShape.circle),
                child: const Icon(Icons.favorite, color: Colors.white, size: 36),
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

    return Scaffold(
      backgroundColor: _R.cream,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Form(
          key: _formKey,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── APP BAR ROYALE ──────────────────────────────────────
              _RoyalAppBar(
                onSave: _save,
                isSaving: _isSaving,
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── HERO BANNER ──────────────────────────────────
                    _HeroBanner(
                      brideName: _brideCtrl.text,
                      groomName: _groomCtrl.text,
                    ),
                    const SizedBox(height: 20),

                    // ── SECTION COUPLE ───────────────────────────────
                    _SectionCard(
                      title: 'Les mariés',
                      icon: Icons.favorite,
                      color: _R.rose,
                      children: [
                        _RoyalTextField(
                          controller: _brideCtrl,
                          label: 'Nom de la mariée',
                          hint: 'Ex: Sophie Martin',
                          icon: Icons.person,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Nom de la mariée requis' : null,
                        ),
                        const SizedBox(height: 14),
                        _RoyalTextField(
                          controller: _groomCtrl,
                          label: 'Nom du marié',
                          hint: 'Ex: Thomas Dupont',
                          icon: Icons.person,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Nom du marié requis' : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── SECTION DATE ─────────────────────────────────
                    _SectionCard(
                      title: 'Date du mariage',
                      icon: Icons.calendar_today,
                      color: _R.gold,
                      children: [
                        _DateTile(
                          date: _weddingDate,
                          onTap: _pickDate,
                          onClear: () => setState(() => _weddingDate = null),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── SECTION LIEU ─────────────────────────────────
                    _SectionCard(
                      title: 'Lieu de réception',
                      icon: Icons.place,
                      color: _R.blue,
                      children: [
                        _RoyalTextField(
                          controller: _venueCtrl,
                          label: 'Lieu / Salle',
                          hint: 'Ex: Château de Versailles, Paris',
                          icon: Icons.location_on_outlined,
                          maxLines: 2,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── BOUTON SOUMETTRE ─────────────────────────────
                    _SubmitButton(
                      isSaving: _isSaving,
                      onTap: _save,
                    ),
                    const SizedBox(height: 16),

                    // ── MÉTADONNÉES ──────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _R.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _R.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _R.text2.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.fingerprint, size: 14, color: _R.text2),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Wedding ID',
                                  style: GoogleFonts.inter(fontSize: 10, color: _R.text2),
                                ),
                                Text(
                                  widget.weddingId,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _R.text,
                                    fontFamily: 'monospace',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
}

// ============================================================================
// APP BAR ROYALE
// ============================================================================
class _RoyalAppBar extends StatelessWidget {
  final VoidCallback onSave;
  final bool isSaving;

  const _RoyalAppBar({required this.onSave, required this.isSaving});

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
        'Infos mariage',
        style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: _R.blue, fontSize: 18),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: Material(
            color: isSaving ? _R.border : _R.green,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: isSaving ? null : onSave,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check, size: 16, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            'Enregistrer',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// HERO BANNER
// ============================================================================
class _HeroBanner extends StatelessWidget {
  final String brideName;
  final String groomName;

  const _HeroBanner({required this.brideName, required this.groomName});

  @override
  Widget build(BuildContext context) {
    final hasNames = brideName.isNotEmpty || groomName.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: _R.goldG,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _R.gold.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            'INFORMATIONS DU MARIAGE',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white.withOpacity(0.9),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          if (hasNames)
            Text(
              '${brideName.isEmpty ? '?' : brideName} & ${groomName.isEmpty ? '?' : groomName}',
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Text(
              'Personnalisez votre événement',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
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
// DATE TILE
// ============================================================================
class _DateTile extends StatelessWidget {
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DateTile({required this.date, required this.onTap, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final hasDate = date != null;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: hasDate ? _R.gold.withOpacity(0.08) : _R.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasDate ? _R.gold.withOpacity(0.4) : _R.border,
              width: hasDate ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: hasDate ? _R.goldG : null,
                  color: hasDate ? null : _R.border.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.calendar_today,
                  size: 20,
                  color: hasDate ? Colors.white : _R.text2,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date du mariage',
                      style: GoogleFonts.inter(fontSize: 11, color: _R.text2),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasDate ? _formatDateLong(date!) : 'Non définie',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: hasDate ? _R.text : _R.text2,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasDate)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: _R.text2),
                  onPressed: onClear,
                )
              else
                const Icon(Icons.chevron_right, size: 20, color: _R.text2),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateLong(DateTime dt) {
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

// ============================================================================
// SUBMIT BUTTON
// ============================================================================
class _SubmitButton extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onTap;

  const _SubmitButton({required this.isSaving, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: isSaving ? null : _R.royal,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isSaving
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
        color: isSaving ? _R.border : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: isSaving ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: isSaving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.save_outlined, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Enregistrer les modifications',
                        style: GoogleFonts.inter(
                          fontSize: 16,
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
