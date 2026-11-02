// lib/presentation/thix_weeding/pages/provider_portal/provider_register_simple.dart
// ============================================================================
// THIX WEDDING — INSCRIPTION PRESTATAIRE SIMPLIFIÉE (SANS AUTH)
// ✅ Formulaire direct en 1 page
// ✅ Génération auto du code unique Thix-CAT-XXX
// ✅ Pas d'authentification Supabase requise (userId = null)
// ✅ Redirection vers le dashboard après création
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/provider_models.dart';
import '../../providers/provider_providers.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PALETTE
// ═══════════════════════════════════════════════════════════════════════════
class _P {
  static const Color bg = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;
  static const Color rose = Color(0xFFFF4D6D);
  static const Color roseLight = Color(0xFFFF85A1);
  static const Color roseSoft = Color(0xFFFFF0F3);
  static const Color ink = Color(0xFF1A1A2E);
  static const Color inkSoft = Color(0xFF6B7280);
  static const Color line = Color(0xFFE5E7EB);
  static const Color green = Color(0xFF10B981);
}

// ═══════════════════════════════════════════════════════════════════════════
// PAGE D'INSCRIPTION SIMPLIFIÉE
// ═══════════════════════════════════════════════════════════════════════════
class ProviderRegisterSimplePage extends ConsumerStatefulWidget {
  const ProviderRegisterSimplePage({super.key});

  @override
  ConsumerState<ProviderRegisterSimplePage> createState() =>
      _ProviderRegisterSimplePageState();
}

class _ProviderRegisterSimplePageState
    extends ConsumerState<ProviderRegisterSimplePage> {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Veuillez choisir une catégorie',
              style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: _P.rose,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();

    try {
      // ✅ SOLUTION : userId = null (la colonne est nullable en BDD)
      final provider = await ref.read(createProviderProvider)(
        userId: null,
        category: _category!,
        businessName: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      );

      if (!mounted) return;

      // ✅ Afficher le code Thix puis rediriger
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _SuccessDialog(code: provider.uniqueCode),
      );

      if (!mounted) return;
      context.go('/thix-weeding/provider/dashboard');
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e', style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: _P.rose,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _P.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── HEADER ───────────────────────────────────────────
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _P.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _P.line),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new,
                            size: 16, color: _P.ink),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Devenir prestataire',
                        style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: _P.ink,
                            letterSpacing: -0.4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Inscription gratuite — code Thix généré instantanément',
                  style: GoogleFonts.inter(fontSize: 13, color: _P.inkSoft),
                ),
                const SizedBox(height: 28),

                // ── NOM ENTREPRISE ───────────────────────────────────
                _Label(text: 'Nom de l\'entreprise *'),
                const SizedBox(height: 8),
                _Input(
                  controller: _nameCtrl,
                  hint: 'Ex: KALBA, Palais des Congrès...',
                  icon: Icons.business_outlined,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Requis' : null,
                ),
                const SizedBox(height: 18),

                // ── EMAIL ────────────────────────────────────────────
                _Label(text: 'Email *'),
                const SizedBox(height: 8),
                _Input(
                  controller: _emailCtrl,
                  hint: 'contact@entreprise.com',
                  icon: Icons.email_outlined,
                  keyboard: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || !v.contains('@')) return 'Email invalide';
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // ── TÉLÉPHONE ────────────────────────────────────────
                _Label(text: 'Téléphone *'),
                const SizedBox(height: 8),
                _Input(
                  controller: _phoneCtrl,
                  hint: '0970604246',
                  icon: Icons.phone_outlined,
                  keyboard: TextInputType.phone,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Requis' : null,
                ),
                const SizedBox(height: 18),

                // ── VILLE ────────────────────────────────────────────
                _Label(text: 'Ville (optionnel)'),
                const SizedBox(height: 8),
                _Input(
                  controller: _cityCtrl,
                  hint: 'Kinshasa, Goma, Lubumbashi...',
                  icon: Icons.location_city_outlined,
                ),
                const SizedBox(height: 18),

                // ── CATÉGORIE ────────────────────────────────────────
                _Label(text: 'Catégorie *'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ProviderCategory.values.map((cat) {
                    final isSelected = _category == cat;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _category = isSelected ? null : cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? _P.rose : _P.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: isSelected ? _P.rose : _P.line),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                      color: _P.rose.withOpacity(0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3))
                                ]
                              : null,
                        ),
                        child: Text(
                          cat.displayName,
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : _P.ink),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 22),

                // ── DESCRIPTION ──────────────────────────────────────
                _Label(text: 'Description (optionnel)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 4,
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w500, color: _P.ink),
                  decoration: InputDecoration(
                    hintText: 'Décrivez votre activité en quelques mots...',
                    hintStyle: GoogleFonts.inter(
                        fontSize: 13, color: _P.inkSoft),
                    filled: true,
                    fillColor: _P.surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _P.line)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _P.line)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: _P.rose, width: 2)),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 28),

                // ── BOUTON CRÉER ─────────────────────────────────────
                SizedBox(
                  height: 56,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _P.rose,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(
                            'Créer mon compte',
                            style: GoogleFonts.inter(
                                fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'En créant un compte, vous acceptez les conditions d\'utilisation Thix',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: _P.inkSoft),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGETS INTERNES
// ═══════════════════════════════════════════════════════════════════════════
class _Label extends StatelessWidget {
  final String text;
  const _Label({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w700, color: _P.ink),
    );
  }
}

class _Input extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboard;
  final String? Function(String?)? validator;

  const _Input({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboard,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      style: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w600, color: _P.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 13, color: _P.inkSoft),
        prefixIcon: Icon(icon, color: _P.rose, size: 20),
        filled: true,
        fillColor: _P.surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _P.line)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _P.line)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _P.rose, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      validator: validator,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DIALOGUE DE SUCCÈS
// ═══════════════════════════════════════════════════════════════════════════
class _SuccessDialog extends StatelessWidget {
  final String code;
  const _SuccessDialog({required this.code});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _P.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _P.green.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle,
                  color: _P.green, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              'Compte créé !',
              style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: _P.ink),
            ),
            const SizedBox(height: 8),
            Text(
              'Voici votre code unique à conserver',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: _P.inkSoft),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_P.rose, _P.roseLight]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    'VOTRE CODE THIX',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    code,
                    style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _P.rose,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'Accéder à mon espace',
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
