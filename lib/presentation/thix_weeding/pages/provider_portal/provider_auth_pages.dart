// lib/presentation/thix_weeding/pages/provider_portal/provider_auth_pages.dart
// ============================================================================
// THIX WEDDING PROVIDER AUTH (PRODUCTION ENTERPRISE)
// ✅ MODE 1 (PAR DÉFAUT) : Connexion SANS auth via code THIX-P-XXXYY
// ✅ MODE 2 (optionnel) : Email + mot de passe Supabase
// ✅ FIX BOUCLE : sauvegarde de l'ID local après toute connexion réussie
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  static const Color green = Color(0xFF10B981);
  static const Color red = Color(0xFFEF4444);
}

// ═══════════════════════════════════════════════════════════════════════════
// LOGIN PAGE — 2 MODES (CODE THIX sans auth / EMAIL Supabase)
// ═══════════════════════════════════════════════════════════════════════════
class ProviderLoginPage extends ConsumerStatefulWidget {
  const ProviderLoginPage({super.key});

  @override
  ConsumerState<ProviderLoginPage> createState() => _ProviderLoginPageState();
}

class _ProviderLoginPageState extends ConsumerState<ProviderLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _useCodeMode = true; // ✅ MODE SANS AUTH par défaut
  bool _isLoading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // MODE 1 : CONNEXION PAR CODE THIX (SANS AUTHENTICATION)
  // ═══════════════════════════════════════════════════════════════════════
  Future<void> _loginWithCode() async {
    final code = _codeCtrl.text.trim().toUpperCase();

    if (!RegExp(r'^THIX-P-\d{3}[A-Z]{2}$').hasMatch(code)) {
      HapticFeedback.heavyImpact();
      setState(() => _error = 'Format invalide. Exemple : THIX-P-358GH');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    HapticFeedback.mediumImpact();

    try {
      final provider =
          await ref.read(providerServiceProvider).getProviderByCode(code);

      if (provider == null) {
        throw Exception('Code introuvable. Vérifiez votre code ou créez un compte.');
      }

      // ✅ Sauvegarde locale = session sans auth
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('thix_current_provider_id', provider.id);
      await prefs.setString('thix_current_provider_code', provider.uniqueCode);
      await prefs.setString('thix_current_provider_name', provider.businessName);

      ref.invalidate(providerByIdProvider(provider.id));

      if (!mounted) return;
      context.go('/thix-weeding/provider/dashboard');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      HapticFeedback.heavyImpact();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // MODE 2 : CONNEXION EMAIL (SUPABASE AUTH — OPTIONNEL)
  // ═══════════════════════════════════════════════════════════════════════
  Future<void> _loginWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );

      if (!mounted) return;

      if (res.user != null) {
        final provider = await ref
    .read(providerServiceProvider)
    .getByOwner(res.user!.id);

        if (provider != null) {
          // ✅ Synchronise aussi la session locale
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('thix_current_provider_id', provider.id);
          await prefs.setString('thix_current_provider_code', provider.uniqueCode);
          await prefs.setString('thix_current_provider_name', provider.businessName);
          ref.invalidate(providerByIdProvider(provider.id));
          if (!mounted) return;
          context.go('/thix-weeding/provider/dashboard');
        } else {
          // Pas de profil lié à cet email : vérifier une session locale existante
          final prefs = await SharedPreferences.getInstance();
          final localId = prefs.getString('thix_current_provider_id');
          if (!mounted) return;
          if (localId != null && localId.isNotEmpty) {
            context.go('/thix-weeding/provider/dashboard');
          } else {
            context.go('/thix-weeding/provider/register');
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Identifiants incorrects. Réessayez.');
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
                      boxShadow: [BoxShadow(color: _P.rose.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
                    ),
                    child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 24),
                  Text('Espace Prestataire', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: _P.ink, letterSpacing: -0.5)),
                  const SizedBox(height: 8),
                  Text('Accédez à votre tableau de bord', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: _P.inkSoft)),
                  const SizedBox(height: 28),

                  // ══ SWITCH DE MODE ══
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: _P.line.withOpacity(0.4), borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        _ModeTab(
                          label: 'Code THIX',
                          isSelected: _useCodeMode,
                          onTap: () => setState(() => _useCodeMode = true),
                        ),
                        _ModeTab(
                          label: 'Email',
                          isSelected: !_useCodeMode,
                          onTap: () => setState(() => _useCodeMode = false),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ══ MESSAGE D'ERREUR ══
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: _P.red.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: _P.red.withOpacity(0.3))),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: _P.red, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!, style: GoogleFonts.inter(fontSize: 12, color: _P.red, fontWeight: FontWeight.w600))),
                        ],
                      ),
                    ),

                  // ══ MODE CODE THIX ══
                  if (_useCodeMode) ...[
                    TextFormField(
                      controller: _codeCtrl,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(11),
                        UpperCaseFormatter(),
                      ],
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2, color: _P.ink),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: 'THIX-P-000AA',
                        hintStyle: GoogleFonts.inter(color: _P.line, fontWeight: FontWeight.w900, letterSpacing: 2),
                        prefixIcon: const Icon(Icons.qr_code_2_rounded, color: _P.rose),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _P.line)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _P.line)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _P.rose, width: 2)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '💡 Votre code THIX vous a été donné lors de la création de votre compte.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 11, color: _P.inkSoft, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _loginWithCode,
                        style: ElevatedButton.styleFrom(backgroundColor: _P.rose, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                        child: _isLoading
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text('Accéder à mon espace', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ] else ...[
                    // ══ MODE EMAIL ══
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecoration(label: 'Email', icon: Icons.email_outlined),
                      validator: (v) => v == null || !v.contains('@') ? 'Email invalide' : null,
                    ),
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _loginWithEmail,
                        style: ElevatedButton.styleFrom(backgroundColor: _P.rose, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                        child: _isLoading
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text('Se connecter', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Pas encore prestataire ?', style: GoogleFonts.inter(color: _P.inkSoft)),
                      TextButton(
                        onPressed: () => context.push('/thix-weeding/provider/register'),
                        child: Text("S'inscrire", style: GoogleFonts.inter(color: _P.rose, fontWeight: FontWeight.w800)),
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _P.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _P.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _P.rose, width: 2)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGETS HELPERS
// ═══════════════════════════════════════════════════════════════════════════
class _ModeTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeTab({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? _P.rose : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isSelected ? Colors.white : _P.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}

class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
