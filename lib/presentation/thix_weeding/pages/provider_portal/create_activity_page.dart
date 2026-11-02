// lib/presentation/thix_weeding/pages/provider_portal/create_activity_page.dart
// ============================================================================
// CRÉER / MODIFIER UNE ACTIVITÉ PRESTATAIRE (choix du métier)
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/provider_providers.dart';

class _P {
  static const bg = Color(0xFFFFF5F8);
  static const rose = Color(0xFFFF4D6D);
  static const roseLight = Color(0xFFFF85A1);
  static const ink = Color(0xFF1A1A2E);
  static const inkSoft = Color(0xFF6B7280);
  static const line = Color(0xFFE5E7EB);
  static const green = Color(0xFF10B981);
  static const grad = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFF4D6D), Color(0xFFFF85A1)]);
}

class _Cat {
  final String key, label;
  final IconData icon;
  const _Cat(this.key, this.label, this.icon);
}

const _cats = [
  _Cat('traiteur', 'Traiteur', Icons.restaurant_outlined),
  _Cat('salle', 'Salle de réception', Icons.villa_outlined),
  _Cat('photographe', 'Photographe', Icons.camera_alt_outlined),
  _Cat('videaste', 'Vidéaste', Icons.videocam_outlined),
  _Cat('decorateur', 'Décorateur', Icons.auto_awesome_outlined),
  _Cat('dj', 'DJ / Sonorisation', Icons.music_note_outlined),
  _Cat('mc', 'MC / Animateur', Icons.mic_outlined),
  _Cat('maquilleur', 'Maquillage / Coiffure', Icons.face_retouching_natural_outlined),
  _Cat('patissier', 'Pâtissier', Icons.cake_outlined),
  _Cat('fleuriste', 'Fleuriste', Icons.local_florist_outlined),
];

class CreateActivityPage extends ConsumerStatefulWidget {
  final String? editId; // null = création
  const CreateActivityPage({super.key, this.editId});
  @override
  ConsumerState<CreateActivityPage> createState() => _CreateActivityPageState();
}

class _CreateActivityPageState extends ConsumerState<CreateActivityPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  String? _category;
  bool _busy = false;

  bool get _isEdit => widget.editId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _load();
  }

  Future<void> _load() async {
    final a = await ref.read(activityDetailProvider(widget.editId!).future);
    if (a == null || !mounted) return;
    setState(() {
      _name.text = a.businessName;
      _category = a.category;
      _city.text = a.city ?? '';
      _phone.text = a.phone ?? '';
      _email.text = a.email ?? '';
      _desc.text = a.description ?? '';
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _desc, _city, _phone, _email]) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _category == null) {
      if (_category == null) _toast('Choisissez un métier', _P.rose);
      return;
    }
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) { setState(() => _busy = false); return; }
    try {
      if (_isEdit) {
        await updateActivity(widget.editId!, {
          'business_name': _name.text.trim(),
          'category': _category,
          'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
          'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
          'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
        });
        ref.invalidate(activityDetailProvider(widget.editId!));
      } else {
        final created = await createActivity(
          userId: user.id,
          businessName: _name.text.trim(),
          category: _category!,
          description: _desc.text.trim(),
          city: _city.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
        );
        // on ouvre directement le dashboard sur la nouvelle activité
        ref.read(selectedActivityIdProvider.notifier).state = created.id;
      }
      ref.invalidate(myActivitiesProvider(user.id));
      ref.invalidate(myProviderProvider(user.id));
      if (!mounted) return;
      _toast(_isEdit ? 'Activité mise à jour ✓' : 'Activité créée ✓', _P.green);
      context.canPop() ? context.pop() : context.go('/thix-weeding/provider/activities');
    } catch (e) {
      _toast('Erreur: $e', _P.rose);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: c, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _P.bg,
      appBar: AppBar(
        backgroundColor: _P.rose, foregroundColor: Colors.white, elevation: 0,
        title: Text(_isEdit ? 'Modifier l\'activité' : 'Nouvelle activité', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => context.pop()),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Votre métier', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: _P.ink)),
            const SizedBox(height: 4),
            Text('Choisissez la catégorie de cette activité. Vous pourrez créer plusieurs activités (traiteur + salle + DJ…).',
                style: GoogleFonts.inter(fontSize: 12, color: _P.inkSoft, height: 1.4)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _cats.map((c) {
                final sel = _category == c.key;
                return ChoiceChip(
                  selected: sel,
                  onSelected: (_) => setState(() => _category = c.key),
                  selectedColor: _P.rose.withOpacity(0.15),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: sel ? _P.rose : _P.line, width: sel ? 2 : 1),
                  avatar: Icon(c.icon, size: 18, color: sel ? _P.rose : _P.inkSoft),
                  label: Text(c.label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: sel ? _P.rose : _P.ink)),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            _field(_name, 'Nom commercial *', 'Ex: KAUKA EVENT — Service Traiteur', Icons.storefront_outlined,
                validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null),
            const SizedBox(height: 12),
            _field(_desc, 'Description', 'Ce que vous proposez pour ce métier…', Icons.description_outlined, maxLines: 3),
            const SizedBox(height: 12),
            _field(_city, 'Ville', 'Ex: Douala', Icons.place_outlined),
            const SizedBox(height: 12),
            _field(_phone, 'Téléphone', 'Ex: +237 6XX XX XX XX', Icons.phone_outlined, keyboard: TextInputType.phone),
            const SizedBox(height: 12),
            _field(_email, 'Email', 'contact@…', Icons.mail_outlined, keyboard: TextInputType.emailAddress),
            const SizedBox(height: 24),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Icon(_isEdit ? Icons.check : Icons.add_circle_outline),
                label: Text(_isEdit ? 'Enregistrer' : 'Créer l\'activité', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
                style: FilledButton.styleFrom(backgroundColor: _P.rose, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, String hint, IconData icon, {int maxLines = 1, TextInputType? keyboard, String? Function(String?)? validator}) {
    return TextFormField(
      controller: c, maxLines: maxLines, keyboardType: keyboard, validator: validator,
      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        labelStyle: GoogleFonts.inter(color: _P.inkSoft),
        hintStyle: GoogleFonts.inter(color: _P.inkSoft.withOpacity(0.6)),
        prefixIcon: Icon(icon, color: _P.rose, size: 20),
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _P.line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _P.line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _P.rose, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
