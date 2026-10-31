// lib/presentation/thix_weeding/pages/staff/prestataires/add_vendor_page.dart
// ============================================================================
// THIX WEDDING & EVENTS — ADD/EDIT VENDOR (PRODUCTION)
// Design royal + 15 Catégories + Statuts + Validation + Animations
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
// 15 CATÉGORIES DU CAHIER DES CHARGES
// ============================================================================
const List<_VendorCategory> _CATEGORIES = [
  _VendorCategory('organisateur', 'Organisateur', Icons.celebration, Color(0xFF6B46C1)),
  _VendorCategory('decorateur', 'Décorateur', Icons.auto_awesome, Color(0xFFFF6B9D)),
  _VendorCategory('photographe', 'Photographe', Icons.camera_alt_outlined, Color(0xFFE31C4E)),
  _VendorCategory('videaste', 'Vidéaste', Icons.videocam_outlined, Color(0xFFDB2777)),
  _VendorCategory('traiteur', 'Traiteur', Icons.restaurant, Color(0xFFD97706)),
  _VendorCategory('patissier', 'Pâtissier', Icons.cake_outlined, Color(0xFFBE185D)),
  _VendorCategory('maquilleur', 'Maquilleur', Icons.auto_fix_high, Color(0xFFEC4899)),
  _VendorCategory('coiffeur', 'Coiffeur', Icons.content_cut, Color(0xFF8B5CF6)),
  _VendorCategory('couturier', 'Couturier', Icons.checkroom, Color(0xFF0891B2)),
  _VendorCategory('dj', 'DJ / Orchestre', Icons.music_note, Color(0xFF7C3AED)),
  _VendorCategory('vehicule', 'Loueur véhicules', Icons.directions_car, Color(0xFF4338CA)),
  _VendorCategory('salle', 'Salle réception', Icons.place_outlined, Color(0xFF0B3B8F)),
  _VendorCategory('fleuriste', 'Fleuriste', Icons.local_florist, Color(0xFF059669)),
  _VendorCategory('securite', 'Sécurité', Icons.shield_outlined, Color(0xFF64748B)),
  _VendorCategory('materiel', 'Matériel événementiel', Icons.inventory_2_outlined, Color(0xFF78716C)),
];

class _VendorCategory {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  const _VendorCategory(this.key, this.label, this.icon, this.color);
}

_VendorCategory _findCategory(String key) =>
    _CATEGORIES.firstWhere((c) => c.key == key || c.label == key, orElse: () => _CATEGORIES.last);

// ============================================================================
// STATUTS PRESTATAIRE
// ============================================================================
const List<_VendorStatus> _STATUSES = [
  _VendorStatus('pending', 'En attente', Icons.hourglass_empty, Color(0xFF6B7280)),
  _VendorStatus('contacted', 'Contacté', Icons.phone_callback, Color(0xFF0B3B8F)),
  _VendorStatus('devis_envoye', 'Devis envoyé', Icons.description_outlined, Color(0xFF6B46C1)),
  _VendorStatus('booked', 'Réservé', Icons.event_available, Color(0xFF059669)),
  _VendorStatus('paid', 'Payé', Icons.payments, Color(0xFFD4AF37)),
  _VendorStatus('cancelled', 'Annulé', Icons.cancel_outlined, Color(0xFFE31C4E)),
];

class _VendorStatus {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  const _VendorStatus(this.key, this.label, this.icon, this.color);
}

_VendorStatus _findStatus(String key) =>
    _STATUSES.firstWhere((s) => s.key == key, orElse: () => _STATUSES[0]);

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class AddVendorPage extends ConsumerStatefulWidget {
  final String weddingId;
  final String? editVendorId;

  const AddVendorPage({super.key, required this.weddingId, this.editVendorId});

  @override
  ConsumerState<AddVendorPage> createState() => _AddVendorPageState();
}

class _AddVendorPageState extends ConsumerState<AddVendorPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _category = 'traiteur';
  String _status = 'pending';
  bool _isBooked = false;
  bool _isLoading = false;
  bool _isInitLoading = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  bool get _isEdit => widget.editVendorId != null;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    if (_isEdit) _loadVendor();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVendor() async {
    setState(() => _isInitLoading = true);
    try {
      final v = await ref.read(vendorServiceProvider).getById(widget.editVendorId!);
      setState(() {
        _nameCtrl.text = v.name;
        _contactCtrl.text = v.contactName ?? '';
        _phoneCtrl.text = v.phone ?? '';
        _emailCtrl.text = v.email ?? '';
        _priceCtrl.text = v.price?.toStringAsFixed(0) ?? '';
        _notesCtrl.text = v.notes ?? '';
        _category = v.category.isNotEmpty ? v.category : 'traiteur';
        _status = v.status.isNotEmpty ? v.status : 'pending';
        _isBooked = v.isBooked;
      });
    } catch (e) {
      if (mounted) _showError('Erreur chargement: $e');
    } finally {
      if (mounted) setState(() => _isInitLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final data = {
      'wedding_id': widget.weddingId,
      'name': _nameCtrl.text.trim(),
      'category': _category,
      'contact_name': _contactCtrl.text.trim().isEmpty ? null : _contactCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      'price': double.tryParse(_priceCtrl.text.replaceAll(RegExp(r'\D'), '')) ?? 0,
      'status': _status,
      'is_booked': _isBooked,
      'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    };

    try {
      final service = ref.read(vendorServiceProvider);
      if (!_isEdit) {
        final created = await service.create(data);
        if (mounted) _showSuccess('Prestataire créé • ID: ${created.id.substring(0, 8)} ✓');
      } else {
        await service.update(widget.editVendorId!, data);
        if (mounted) _showSuccess('Prestataire mis à jour ✓');
      }
      ref.invalidate(vendorsProvider(widget.weddingId));
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) _showError('Erreur: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _R.surface,
      body: _isInitLoading
          ? const _LoadingView()
          : FadeTransition(
              opacity: _fadeAnim,
              child: Form(
                key: _formKey,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _FormAppBar(
                      isEdit: _isEdit,
                      onSave: _save,
                      isLoading: _isLoading,
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // ── ENTREPRISE ───────────────────────────────
                          _SectionCard(
                            title: 'Entreprise',
                            icon: Icons.storefront_outlined,
                            color: _R.blue,
                            children: [
                              _RoyalTextField(
                                controller: _nameCtrl,
                                label: 'Nom de l\'entreprise',
                                hint: 'Ex: Studio Photo Royal',
                                icon: Icons.business_outlined,
                                validator: (v) => v == null || v.trim().length < 2 ? 'Nom requis (min 2 car.)' : null,
                              ),
                              const SizedBox(height: 14),
                              _CategorySelector(
                                selected: _category,
                                onChanged: (c) => setState(() => _category = c),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ── CONTACT ──────────────────────────────────
                          _SectionCard(
                            title: 'Contact',
                            icon: Icons.person_outline,
                            color: _R.purple,
                            children: [
                              _RoyalTextField(
                                controller: _contactCtrl,
                                label: 'Personne de contact',
                                hint: 'Ex: Jean Dupont',
                                icon: Icons.person_outline,
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: _RoyalTextField(
                                      controller: _phoneCtrl,
                                      label: 'Téléphone',
                                      hint: '+243 ...',
                                      icon: Icons.phone_outlined,
                                      keyboard: TextInputType.phone,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _RoyalTextField(
                                      controller: _emailCtrl,
                                      label: 'Email',
                                      hint: 'pro@mail.com',
                                      icon: Icons.email_outlined,
                                      keyboard: TextInputType.emailAddress,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ── CONTRAT & PRIX ──────────────────────────
                          _SectionCard(
                            title: 'Contrat & Tarif',
                            icon: Icons.payments_outlined,
                            color: _R.gold,
                            children: [
                              _RoyalTextField(
                                controller: _priceCtrl,
                                label: 'Prix convenu',
                                hint: '350000',
                                icon: Icons.account_balance_wallet_outlined,
                                keyboard: TextInputType.number,
                                suffix: 'FCFA',
                                formatter: FilteringTextInputFormatter.digitsOnly,
                              ),
                              const SizedBox(height: 14),
                              _StatusSelector(
                                selected: _status,
                                onChanged: (s) => setState(() => _status = s),
                              ),
                              const SizedBox(height: 14),
                              _BookedToggle(
                                value: _isBooked,
                                onChanged: (v) => setState(() => _isBooked = v),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ── NOTES ───────────────────────────────────
                          _SectionCard(
                            title: 'Notes & Détails',
                            icon: Icons.notes_outlined,
                            color: _R.text2,
                            children: [
                              _RoyalTextField(
                                controller: _notesCtrl,
                                label: 'Notes complémentaires',
                                hint: 'Conditions, horaires, prestations incluses...',
                                icon: Icons.edit_note_outlined,
                                maxLines: 4,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // ── BOUTON SOUMETTRE ────────────────────────
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
}

// ============================================================================
// APP BAR
// ============================================================================
class _FormAppBar extends StatelessWidget {
  final bool isEdit;
  final VoidCallback onSave;
  final bool isLoading;

  const _FormAppBar({
    required this.isEdit,
    required this.onSave,
    required this.isLoading,
  });

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
        isEdit ? 'Modifier prestataire' : 'Nouveau prestataire',
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
                            isEdit ? 'Enregistrer' : 'Créer',
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
  final TextInputType keyboard;
  final String? suffix;
  final TextInputFormatter? formatter;
  final String? Function(String?)? validator;
  final int maxLines;

  const _RoyalTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboard = TextInputType.text,
    this.suffix,
    this.formatter,
    this.validator,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      inputFormatters: formatter != null ? [formatter!] : null,
      maxLines: maxLines,
      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.inter(color: _R.text2, fontSize: 13),
        hintStyle: GoogleFonts.inter(color: _R.text2.withOpacity(0.6), fontSize: 13),
        prefixIcon: Icon(icon, color: _R.blue, size: 20),
        suffixText: suffix,
        suffixStyle: GoogleFonts.inter(color: _R.text2, fontWeight: FontWeight.w600, fontSize: 12),
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
// CATEGORY SELECTOR (Grid 3 colonnes)
// ============================================================================
class _CategorySelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _CategorySelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.95,
      ),
      itemCount: _CATEGORIES.length,
      itemBuilder: (context, i) {
        final cat = _CATEGORIES[i];
        final isSelected = cat.key == selected || cat.label == selected;
        return Material(
          color: isSelected ? cat.color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => onChanged(cat.key),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? cat.color : _R.border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withOpacity(0.25) : cat.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      cat.icon,
                      size: 20,
                      color: isSelected ? Colors.white : cat.color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cat.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : _R.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// STATUS SELECTOR
// ============================================================================
class _StatusSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _StatusSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _STATUSES.map((s) {
        final isSelected = s.key == selected;
        return Material(
          color: isSelected ? s.color : Colors.white,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () => onChanged(s.key),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? s.color : _R.border,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(s.icon, size: 14, color: isSelected ? Colors.white : s.color),
                  const SizedBox(width: 6),
                  Text(
                    s.label,
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
    );
  }
}

// ============================================================================
// BOOKED TOGGLE
// ============================================================================
class _BookedToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _BookedToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: value ? _R.green.withOpacity(0.08) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? _R.green : _R.border,
          width: 1.5,
        ),
      ),
      child: SwitchListTile(
        title: Text(
          'Prestataire réservé',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: value ? _R.green : _R.text,
          ),
        ),
        subtitle: Text(
          value ? 'Confirmé et bloqué pour l\'événement' : 'Pas encore confirmé',
          style: GoogleFonts.inter(fontSize: 11, color: _R.text2),
        ),
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: value ? _R.green.withOpacity(0.15) : _R.border.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            value ? Icons.event_available : Icons.event_busy,
            size: 18,
            color: value ? _R.green : _R.text2,
          ),
        ),
        value: value,
        activeColor: _R.green,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
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

  const _SubmitButton({
    required this.isEdit,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          onTap: isLoading ? null : onTap,
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
                      Icon(isEdit ? Icons.check : Icons.storefront, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        isEdit ? 'Enregistrer les modifications' : 'Créer le prestataire',
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

// ============================================================================
// LOADING VIEW
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
              child: const Icon(Icons.storefront_outlined, color: Colors.white, size: 36),
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
