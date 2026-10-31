// lib/presentation/thix_weeding/pages/staff/my_weddings/create_wedding_page.dart
// ============================================================================
// THIX WEDDING & EVENTS — CREATE / EDIT WEDDING (PRODUCTION)
// Design royal + Champs typés WeddingModel + Unique Code auto + Date picker
// ⚠️ CORRIGÉ : utilise bride_name/groom_name (pas partner_one/partner_two)
// ============================================================================
import 'dart:math';

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
// GÉNÉRATEUR DE CODE UNIQUE
// ============================================================================
String _generateUniqueCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random.secure();
  return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class CreateWeddingPage extends StatefulWidget {
  final String? weddingId;
  const CreateWeddingPage({super.key, this.weddingId});

  @override
  State<CreateWeddingPage> createState() => _CreateWeddingPageState();
}

class _CreateWeddingPageState extends State<CreateWeddingPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _brideCtrl = TextEditingController();
  final _groomCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  DateTime? _weddingDate;
  bool _isLoading = false;
  bool _isFetching = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  bool get _isEditing => widget.weddingId != null;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();

    if (_isEditing) _loadWeddingData();
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
  // LOAD (pour édition)
  // ============================================================================
  Future<void> _loadWeddingData() async {
    setState(() => _isFetching = true);
    try {
      final res = await Supabase.instance.client
          .from('thix_weeding_weddings')
          .select()
          .eq('id', widget.weddingId!)
          .single();

      setState(() {
        _brideCtrl.text = res['bride_name'] as String? ?? '';
        _groomCtrl.text = res['groom_name'] as String? ?? '';
        _venueCtrl.text = res['venue'] as String? ?? '';
        if (res['wedding_date'] != null) {
          _weddingDate = DateTime.parse(res['wedding_date'] as String);
        }
      });
    } catch (e) {
      if (mounted) _showError('Erreur de chargement: $e');
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  // ============================================================================
  // SAVE
  // ============================================================================
  Future<void> _saveWedding() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        _showError('Veuillez vous connecter pour continuer');
        return;
      }

      final Map<String, dynamic> data = {
        'bride_name': _brideCtrl.text.trim(),
        'groom_name': _groomCtrl.text.trim(),
        'venue': _venueCtrl.text.trim().isEmpty ? null : _venueCtrl.text.trim(),
        'wedding_date': _weddingDate?.toIso8601String().split('T')[0],
        'owner_id': user.id,
      };

      if (_isEditing) {
        await Supabase.instance.client
            .from('thix_weeding_weddings')
            .update(data)
            .eq('id', widget.weddingId!);

        if (!mounted) return;
        _showSuccess('Mariage mis à jour avec succès ✓');
        context.pop();
      } else {
        data['unique_code'] = _generateUniqueCode();
        data['invitation_published'] = false;

        final res = await Supabase.instance.client
            .from('thix_weeding_weddings')
            .insert(data)
            .select()
            .single();

        final newId = res['id'] as String;
        if (!mounted) return;
        _showSuccess('Mariage créé avec succès ✓');
        context.go('/thix-weeding/staff/$newId');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Erreur: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================================
  // DATE PICKER
  // ============================================================================
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _weddingDate ?? DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime(2024),
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
        content: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
            child: const Icon(Icons.check, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
        ]),
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
    return Scaffold(
      backgroundColor: _R.cream,
      body: _isFetching
          ? const _LoadingView()
          : FadeTransition(
              opacity: _fadeAnim,
              child: Form(
                key: _formKey,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // ── APP BAR ROYALE ────────────────────────────────
                    _RoyalAppBar(isEditing: _isEditing),

                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // ── HERO BANNER ────────────────────────────
                          _HeroBanner(isEditing: _isEditing),
                          const SizedBox(height: 24),

                          // ── SECTION LES MARIÉS ─────────────────────
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

                          // ── SECTION DATE ───────────────────────────
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

                          // ── SECTION LIEU ───────────────────────────
                          _SectionCard(
                            title: 'Lieu de réception',
                            icon: Icons.place,
                            color: _R.blue,
                            children: [
                              _RoyalTextField(
                                controller: _venueCtrl,
                                label: 'Lieu / Salle (optionnel)',
                                hint: 'Ex: Château de Versailles, Paris',
                                icon: Icons.location_on_outlined,
                                maxLines: 2,
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // ── BOUTON SOUMETTRE ───────────────────────
                          _SubmitButton(
                            isEditing: _isEditing,
                            isLoading: _isLoading,
                            onTap: _saveWedding,
                          ),

                          // ── NOTE INFO ──────────────────────────────
                          if (!_isEditing) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [_R.blue.withOpacity(0.06), _R.purple.withOpacity(0.06)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _R.blue.withOpacity(0.15)),
                              ),
                              child: Row(children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _R.blue.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.info_outline, color: _R.blue, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Un code unique sera généré automatiquement. Vous pourrez configurer l\'invitation, les invités et le budget après la création.',
                                    style: GoogleFonts.inter(fontSize: 11, color: _R.blue, height: 1.4),
                                  ),
                                ),
                              ]),
                            ),
                          ],
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
  final bool isEditing;
  const _RoyalAppBar({required this.isEditing});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 130,
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
                        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Icon(isEditing ? Icons.edit_outlined : Icons.add_circle_outline, color: Colors.white, size: 16)),
                        const SizedBox(width: 8),
                        Text(isEditing ? 'MODIFIER LE MARIAGE' : 'NOUVEAU MARIAGE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.85), letterSpacing: 2)),
                      ]),
                      const SizedBox(height: 6),
                      Text(isEditing ? 'Mettre à jour les informations' : 'Créez votre événement', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
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
// HERO BANNER
// ============================================================================
class _HeroBanner extends StatelessWidget {
  final bool isEditing;
  const _HeroBanner({required this.isEditing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: _R.goldG,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _R.gold.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(14)),
          child: Icon(isEditing ? Icons.edit : Icons.celebration, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing ? 'MODIFICATION' : 'COMMENCEZ ICI',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white.withOpacity(0.9), letterSpacing: 2),
              ),
              const SizedBox(height: 4),
              Text(
                isEditing ? 'Mettez à jour les détails de votre mariage' : 'Remplissez les informations essentielles pour créer votre espace mariage personnalisé',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white, height: 1.3),
              ),
            ],
          ),
        ),
      ]),
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
            border: Border.all(color: hasDate ? _R.gold.withOpacity(0.4) : _R.border, width: hasDate ? 1.5 : 1),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: hasDate ? _R.goldG : null,
                color: hasDate ? null : _R.border.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.calendar_today, size: 20, color: hasDate ? Colors.white : _R.text2),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Date du mariage', style: GoogleFonts.inter(fontSize: 11, color: _R.text2)),
                  const SizedBox(height: 2),
                  Text(hasDate ? _formatDateLong(date!) : 'Non définie', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: hasDate ? _R.text : _R.text2)),
                ],
              ),
            ),
            if (hasDate) IconButton(icon: const Icon(Icons.clear, size: 18, color: _R.text2), onPressed: onClear) else const Icon(Icons.chevron_right, size: 20, color: _R.text2),
          ]),
        ),
      ),
    );
  }

  String _formatDateLong(DateTime dt) {
    const months = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

// ============================================================================
// SUBMIT BUTTON
// ============================================================================
class _SubmitButton extends StatelessWidget {
  final bool isEditing;
  final bool isLoading;
  final VoidCallback onTap;

  const _SubmitButton({required this.isEditing, required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: isLoading ? null : (isEditing ? _R.greenG : _R.royal),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isLoading ? null : [BoxShadow(color: (isEditing ? _R.green : _R.blue).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
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
                    Icon(isEditing ? Icons.check : Icons.celebration, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      isEditing ? 'Enregistrer les modifications' : 'Créer le mariage',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ]),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// LOADING VIEW
// ============================================================================
class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _R.cream,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(gradient: _R.goldG, shape: BoxShape.circle), child: const Icon(Icons.favorite, color: Colors.white, size: 36)),
          const SizedBox(height: 16),
          Text('Chargement...', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _R.text2)),
        ]),
      ),
    );
  }
}
