// lib/presentation/thix_weeding/pages/provider_portal/provider_auth_pages.dart
// ============================================================================
// THIX WEDDING PROVIDER AUTH (PRODUCTION ENTERPRISE)
// ✅ Login + Registration Multi-étapes
// ✅ Design glassmorphism premium
// ✅ Validation stricte des champs
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/provider_models.dart';
import '../../providers/provider_providers.dart';

class _P {
  static const Color bg = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;
  static const Color rose = Color(0xFFFF4D6D);
  static const Color roseLight = Color(0xFFFF85A1);
  static const Color ink = Color(0xFF1A1A2E);
  static const Color inkSoft = Color(0xFF6B7280);
  static const Color line = Color(0xFFE5E7EB);
}

// ═══════════════════════════════════════════════════════════════════════════
// LOGIN PAGE
// ═══════════════════════════════════════════════════════════════════════════
class ProviderLoginPage extends ConsumerStatefulWidget {
  const ProviderLoginPage({super.key});

  @override
  ConsumerState<ProviderLoginPage> createState() => _ProviderLoginPageState();
}

class _ProviderLoginPageState extends ConsumerState<ProviderLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );

      if (!mounted) return;

      if (res.user != null) {
        // Vérifier si c'est un prestataire
        final provider = await ref.read(providerServiceProvider).getProviderByUserId(res.user!.id);
        
        if (provider != null) {
          context.go('/thix-weeding/provider/dashboard');
        } else {
          context.go('/thix-weeding/provider/register');
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: _P.rose),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _P.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // LOGO
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_P.rose, _P.roseLight]),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: _P.rose.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Espace Prestataire',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: _P.ink, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connectez-vous pour gérer votre activité',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 14, color: _P.inkSoft),
                  ),
                  const SizedBox(height: 40),

                  // EMAIL
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDecoration(label: 'Email', icon: Icons.email_outlined),
                    validator: (v) => v == null || !v.contains('@') ? 'Email invalide' : null,
                  ),
                  const SizedBox(height: 16),

                  // PASSWORD
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    decoration: _inputDecoration(
                      label: 'Mot de passe',
                      icon: Icons.lock_outline,
                      suffix: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: _P.inkSoft),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => v == null || v.length < 6 ? 'Min 6 caractères' : null,
                  ),
                  const SizedBox(height: 32),

                  // BUTTON
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _P.rose,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('Se connecter', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // LINK
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Pas encore prestataire ?', style: GoogleFonts.inter(color: _P.inkSoft)),
                      TextButton(
                        onPressed: () => context.push('/thix-weeding/provider/register'),
                        child: Text('S\'inscrire', style: GoogleFonts.inter(color: _P.rose, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String label, required IconData icon, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _P.inkSoft),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _P.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _P.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _P.rose, width: 2),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// REGISTER PAGE (Multi-étapes)
// ═══════════════════════════════════════════════════════════════════════════
class ProviderRegisterPage extends ConsumerStatefulWidget {
  const ProviderRegisterPage({super.key});

  @override
  ConsumerState<ProviderRegisterPage> createState() => _ProviderRegisterPageState();
}

class _ProviderRegisterPageState extends ConsumerState<ProviderRegisterPage> {
  int _step = 0;
  final _formKey = GlobalKey<FormState>();
  
  // Step 1: Auth
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  
  // Step 2: Info
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  ProviderCategory? _category;
  
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_formKey.currentState!.validate()) {
      if (_step == 0) {
        setState(() => _step = 1);
      } else if (_step == 1) {
        if (_category == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Veuillez choisir une catégorie')),
          );
          return;
        }
        setState(() => _step = 2); // Preview & Submit
      }
    }
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      // 1. Créer le compte Auth
      final authRes = await Supabase.instance.client.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );

      if (authRes.user == null) throw Exception('Erreur création compte');

      // 2. Créer le profil Prestataire
      await ref.read(createProviderProvider)(
        userId: authRes.user!.id,
        category: _category!,
        businessName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
      );

      if (!mounted) return;
      
      // Rediriger vers le dashboard
      context.go('/thix-weeding/provider/dashboard');
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: _P.rose),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _P.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: _P.ink),
                onPressed: () => setState(() => _step--),
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Progress Bar
                _StepperIndicator(step: _step),
                const SizedBox(height: 32),

                if (_step == 0) _buildAuthStep(),
                if (_step == 1) _buildInfoStep(),
                if (_step == 2) _buildPreviewStep(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Créer votre compte', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: _P.ink)),
        const SizedBox(height: 8),
        Text('Étape 1 sur 2 : Informations de connexion', style: GoogleFonts.inter(color: _P.inkSoft)),
        const SizedBox(height: 32),
        TextFormField(
          controller: _emailCtrl,
          decoration: _inputDecoration('Email professionnel', Icons.email_outlined),
          validator: (v) => v == null || !v.contains('@') ? 'Email invalide' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passCtrl,
          obscureText: true,
          decoration: _inputDecoration('Mot de passe', Icons.lock_outline),
          validator: (v) => v == null || v.length < 6 ? 'Min 6 caractères' : null,
        ),
        const SizedBox(height: 32),
        _NextButton(onPressed: _next, isLoading: false),
      ],
    );
  }

  Widget _buildInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Votre Activité', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: _P.ink)),
        const SizedBox(height: 8),
        Text('Étape 2 sur 2 : Détails professionnels', style: GoogleFonts.inter(color: _P.inkSoft)),
        const SizedBox(height: 32),
        TextFormField(
          controller: _nameCtrl,
          decoration: _inputDecoration('Nom de l\'entreprise', Icons.business),
          validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: _inputDecoration('Téléphone', Icons.phone),
          validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
        ),
        const SizedBox(height: 24),
        Text('Catégorie', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: _P.ink)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ProviderCategory.values.map((cat) {
            final isSelected = _category == cat;
            return ChoiceChip(
              label: Text(cat.displayName),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _category = selected ? cat : null);
              },
              selectedColor: _P.rose,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : _P.ink,
                fontWeight: FontWeight.w600,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 32),
        _NextButton(onPressed: _next, isLoading: false),
      ],
    );
  }

  Widget _buildPreviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Confirmation', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: _P.ink)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _P.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PreviewRow(label: 'Email', value: _emailCtrl.text),
              _PreviewRow(label: 'Entreprise', value: _nameCtrl.text),
              _PreviewRow(label: 'Téléphone', value: _phoneCtrl.text),
              _PreviewRow(label: 'Catégorie', value: _category?.displayName ?? ''),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _NextButton(
          onPressed: _submit,
          isLoading: _isLoading,
          label: 'Créer mon compte',
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _P.inkSoft),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _P.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _P.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _P.rose, width: 2)),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final String label;
  final String value;
  const _PreviewRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(color: _P.inkSoft, fontSize: 14)),
          Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _P.ink, fontSize: 14)),
        ],
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;
  final String label;

  const _NextButton({required this.onPressed, required this.isLoading, this.label = 'Continuer'});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _P.rose,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _StepperIndicator extends StatelessWidget {
  final int step;
  const _StepperIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (index) {
        final isActive = index <= step;
        return Expanded(
          child: Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: isActive ? _P.rose : _P.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
