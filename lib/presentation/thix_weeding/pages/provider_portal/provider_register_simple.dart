// lib/presentation/thix_weeding/pages/provider_portal/provider_register_simple.dart
// ============================================================================
// THIX WEDDING — INSCRIPTION PRESTATAIRE SIMPLIFIÉE (SANS AUTH)
// ✅ Sauvegarde locale de l'ID du prestataire créé
// ✅ Redirection directe vers le Dashboard privé
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ⬅️ IMPORT CLÉ

import '../../models/provider_models.dart';
import '../../providers/provider_providers.dart';

class _P {
  static const Color bg = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;
  static const Color rose = Color(0xFFFF4D6D);
  static const Color ink = Color(0xFF1A1A2E);
  static const Color inkSoft = Color(0xFF6B7280);
  static const Color line = Color(0xFFE5E7EB);
  static const Color green = Color(0xFF10B981);
}

class ProviderRegisterSimplePage extends ConsumerStatefulWidget {
  const ProviderRegisterSimplePage({super.key});

  @override
  ConsumerState<ProviderRegisterSimplePage> createState() => _ProviderRegisterSimplePageState();
}

class _ProviderRegisterSimplePageState extends ConsumerState<ProviderRegisterSimplePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  ProviderCategory? _category;
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_category == null) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Veuillez choisir une catégorie'), backgroundColor: _P.rose, behavior: SnackBarBehavior.floating));
      return;
    }

    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();

    try {
      final provider = await ref.read(createProviderProvider)(
        userId: null,
        category: _category!,
        businessName: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      );

      if (!mounted) return;

      // ✅ FIX CRUCIAL : Sauvegarder l'ID localement pour identifier le propriétaire
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('thix_current_provider_id', provider.id);

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: _P.surface, borderRadius: BorderRadius.circular(24)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: _P.green.withOpacity(0.12), shape: BoxShape.circle), child: const Icon(Icons.check_circle, color: _P.green, size: 48)),
              const SizedBox(height: 16),
              Text('Compte créé !', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: _P.ink)),
              const SizedBox(height: 8),
              Text('Votre code unique est : ${provider.uniqueCode}', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: _P.inkSoft)),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: () => Navigator.pop(ctx), style: ElevatedButton.styleFrom(backgroundColor: _P.rose, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Text('Accéder à mon espace', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800)))),
            ]),
          ),
        ),
      );

      if (!mounted) return;
      ref.invalidate(providersListProvider);
      ref.invalidate(providerByIdProvider(provider.id));
      
      // ✅ REDIRECTION VERS LE DASHBOARD PRIVÉ
      context.go('/thix-weeding/provider/dashboard');
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: _P.rose, behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _P.bg,
      body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GestureDetector(onTap: () => context.pop(), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _P.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _P.line)), child: const Icon(Icons.arrow_back_ios_new, size: 16, color: _P.ink))),
          const SizedBox(width: 12),
          Expanded(child: Text('Devenir prestataire', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: _P.ink))),
        ]),
        const SizedBox(height: 28),
        
        _Field(label: 'Nom de l\'entreprise *', controller: _nameCtrl, hint: 'Ex: KALBA...', icon: Icons.business_outlined, validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null),
        _Field(label: 'Email *', controller: _emailCtrl, hint: 'contact@...', icon: Icons.email_outlined, keyboard: TextInputType.emailAddress, validator: (v) => v == null || !v.contains('@') ? 'Invalide' : null),
        _Field(label: 'Téléphone *', controller: _phoneCtrl, hint: '0970604246', icon: Icons.phone_outlined, keyboard: TextInputType.phone, validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null),
        _Field(label: 'Ville', controller: _cityCtrl, hint: 'Kinshasa, Lubumbashi...', icon: Icons.location_city_outlined),
        
        const SizedBox(height: 18),
        Text('Catégorie *', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _P.ink)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: ProviderCategory.values.map((cat) {
          final isSelected = _category == cat;
          return GestureDetector(onTap: () => setState(() => _category = isSelected ? null : cat), child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: isSelected ? _P.rose : _P.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? _P.rose : _P.line)), child: Text(cat.displayName, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : _P.ink))));
        }).toList()),
        
        const SizedBox(height: 22),
        Text('Description', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _P.ink)),
        const SizedBox(height: 8),
        TextFormField(controller: _descCtrl, maxLines: 4, style: GoogleFonts.inter(fontSize: 14, color: _P.ink), decoration: InputDecoration(hintText: 'Décrivez votre activité...', filled: true, fillColor: _P.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
        
        const SizedBox(height: 28),
        SizedBox(height: 56, width: double.infinity, child: ElevatedButton(onPressed: _submitting ? null : _submit, style: ElevatedButton.styleFrom(backgroundColor: _P.rose, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: _submitting ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.white) : Text('Créer mon compte', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)))),
      ])))),
    );
  }
}

class _Field extends StatelessWidget {
  final String label; final TextEditingController controller; final String hint; final IconData icon; final TextInputType? keyboard; final String? Function(String?)? validator;
  const _Field({required this.label, required this.controller, required this.hint, required this.icon, this.keyboard, this.validator});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _P.ink)),
    const SizedBox(height: 8),
    TextFormField(controller: controller, keyboardType: keyboard, validator: validator, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _P.ink), decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon, color: _P.rose, size: 20), filled: true, fillColor: _P.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
  ]));
}
