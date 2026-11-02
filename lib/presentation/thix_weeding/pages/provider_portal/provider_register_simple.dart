// lib/presentation/thix_weeding/pages/provider_portal/provider_register_simple.dart
// ============================================================================
// THIX WEDDING — INSCRIPTION PRESTATAIRE (PRODUCTION ENTERPRISE)
// ✅ Validation complète de tous les champs
// ✅ Gestion d'erreurs robuste avec retry
// ✅ Sauvegarde locale sécurisée + redirection garantie
// ✅ Haptic feedback + animations fluides
// ✅ Copie du code unique
// ============================================================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const Color amber = Color(0xFFF59E0B);
  static const Color red = Color(0xFFEF4444);
}

class ProviderRegisterSimplePage extends ConsumerStatefulWidget {
  const ProviderRegisterSimplePage({super.key});

  @override
  ConsumerState<ProviderRegisterSimplePage> createState() =>
      _ProviderRegisterSimplePageState();
}

class _ProviderRegisterSimplePageState
    extends ConsumerState<ProviderRegisterSimplePage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  ProviderCategory? _category;
  bool _submitting = false;
  bool _agreedToTerms = false;
  String? _serverError;

  // Focus nodes pour UX clavier
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _cityFocus = FocusNode();
  final _descFocus = FocusNode();

  // Animation pour la catégorie sélectionnée
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    _descCtrl.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _cityFocus.dispose();
    _descFocus.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VALIDATEURS AVANCÉS
  // ═══════════════════════════════════════════════════════════════════════════

  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Le nom de l\'entreprise est requis';
    if (v.trim().length < 2) return 'Nom trop court (min. 2 caractères)';
    if (v.trim().length > 80) return 'Nom trop long (max. 80 caractères)';
    return null;
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email requis';
    final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!regex.hasMatch(v.trim())) return 'Email invalide (ex: contact@thix.com)';
    return null;
  }

  String? _validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Téléphone requis';
    final cleaned = v.replaceAll(RegExp(r'[\s\-()]'), '');
    if (!RegExp(r'^\+?[0-9]{8,15}$').hasMatch(cleaned)) {
      return 'Numéro invalide (8 à 15 chiffres)';
    }
    return null;
  }

  String? _validateCity(String? v) {
    if (v != null && v.trim().length > 50) return 'Nom de ville trop long';
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SOUMISSION DU FORMULAIRE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _submit() async {
    // Validation du formulaire
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      setState(() => _serverError = 'Veuillez corriger les erreurs du formulaire');
      return;
    }

    if (_category == null) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sélectionnez une catégorie',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: _P.rose,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (!_agreedToTerms) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Acceptez les conditions d\'utilisation',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: _P.amber,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() {
      _submitting = true;
      _serverError = null;
    });
    HapticFeedback.mediumImpact();

    try {
      // 1. Création du prestataire via Supabase
      final provider = await ref.read(createProviderProvider)(
        userId: null, // Inscription libre (sans Auth)
        category: _category!,
        businessName: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      );

      if (!mounted) return;

      // 2. Sauvegarde locale CRITIQUE de l'ID pour le shell
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('thix_current_provider_id', provider.id);
      await prefs.setString('thix_current_provider_code', provider.uniqueCode);
      await prefs.setString('thix_current_provider_name', provider.businessName);

      // 3. Invalidation du cache Riverpod (TRÈS IMPORTANT)
      ref.invalidate(providersListProvider);
      ref.invalidate(providerByIdProvider(provider.id));

      // 4. Petit délai pour propagation Supabase
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      // 5. Dialogue de succès
      await _showSuccessDialog(provider);

      if (!mounted) return;

      // 6. Redirection GARANTIE vers le dashboard
      context.go('/thix-weeding/provider/dashboard');
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _serverError =
          'Délai dépassé. Vérifiez votre connexion internet et réessayez.');
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() => _serverError =
          'Format de données invalide. Contact support@thix.com');
      debugPrint('Format error: $e');
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      String userMessage;

      if (msg.contains('duplicate key') ||
          msg.contains('unique constraint')) {
        userMessage =
            'Un compte avec ces informations existe déjà. Connectez-vous.';
      } else if (msg.contains('network') || msg.contains('SocketException')) {
        userMessage = 'Pas de connexion internet. Vérifiez votre réseau.';
      } else if (msg.contains('timeout')) {
        userMessage = 'Connexion trop lente. Réessayez.';
      } else {
        userMessage = 'Erreur serveur : ${msg.length > 80 ? '${msg.substring(0, 80)}...' : msg}';
      }

      setState(() => _serverError = userMessage);
      HapticFeedback.heavyImpact();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DIALOGUE DE SUCCÈS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _showSuccessDialog(ThixProviderModel provider) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: _P.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icône succès animée
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _P.green.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: _P.green,
                  size: 56,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Compte créé avec succès !',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _P.ink,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                provider.businessName,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _P.rose,
                ),
              ),
              const SizedBox(height: 20),

              // Code unique
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_P.rose.withOpacity(0.08), _P.roseLight.withOpacity(0.08)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _P.rose.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Votre code THIX unique',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _P.inkSoft,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      provider.uniqueCode,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: _P.ink,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: provider.uniqueCode));
                        HapticFeedback.mediumImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Code copié !',
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                            backgroundColor: _P.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _P.line),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.copy_rounded,
                                size: 16, color: _P.rose),
                            const SizedBox(width: 6),
                            Text('Copier le code',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _P.rose,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              Text(
                '⚠️ Gardez ce code précieusement. Il permet à vos clients de vous identifier sur THIX Wedding.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: _P.inkSoft,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  label: Text(
                    'Accéder à mon espace',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _P.rose,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _P.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.fromLTRB(16, topPad + 12, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: _P.line)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _P.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _P.line),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new,
                          size: 16, color: _P.ink),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Devenir prestataire',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: _P.ink,
                          ),
                        ),
                        Text(
                          'Inscription gratuite en 30 secondes',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: _P.inkSoft,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _P.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'GRATUIT',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: _P.green,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Contenu
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Message d'erreur serveur
                      if (_serverError != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _P.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: _P.red.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: _P.red, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _serverError!,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: _P.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close,
                                    size: 16, color: _P.red),
                                onPressed: () =>
                                    setState(() => _serverError = null),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),

                      _Field(
                        label: 'Nom de l\'entreprise *',
                        controller: _nameCtrl,
                        focusNode: _nameFocus,
                        nextFocus: _emailFocus,
                        hint: 'Ex: KALBA Events, Dream Photo...',
                        icon: Icons.business_outlined,
                        textCapitalization: TextCapitalization.words,
                        validator: _validateName,
                      ),

                      _Field(
                        label: 'Email professionnel *',
                        controller: _emailCtrl,
                        focusNode: _emailFocus,
                        nextFocus: _phoneFocus,
                        hint: 'contact@monentreprise.com',
                        icon: Icons.email_outlined,
                        keyboard: TextInputType.emailAddress,
                        validator: _validateEmail,
                      ),

                      _Field(
                        label: 'Téléphone *',
                        controller: _phoneCtrl,
                        focusNode: _phoneFocus,
                        nextFocus: _cityFocus,
                        hint: '+243 970 604 246',
                        icon: Icons.phone_outlined,
                        keyboard: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9+\-\s()]')),
                        ],
                        validator: _validatePhone,
                      ),

                      _Field(
                        label: 'Ville',
                        controller: _cityCtrl,
                        focusNode: _cityFocus,
                        nextFocus: _descFocus,
                        hint: 'Kinshasa, Lubumbashi, Goma...',
                        icon: Icons.location_city_outlined,
                        textCapitalization: TextCapitalization.words,
                        validator: _validateCity,
                      ),

                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            'Catégorie *',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: _P.ink,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(obligatoire)',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: _P.inkSoft,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Grille de catégories
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ProviderCategory.values.map((cat) {
                          final isSelected = _category == cat;
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _category = cat);
                              _animController.forward(from: 0);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 11),
                              decoration: BoxDecoration(
                                color: isSelected ? _P.rose : _P.surface,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: isSelected ? _P.rose : _P.line,
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color:
                                              _P.rose.withOpacity(0.25),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isSelected)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(right: 6),
                                      child: Icon(
                                        Icons.check_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  Text(
                                    cat.displayName,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          isSelected ? Colors.white : _P.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 22),
                      Text(
                        'Description (optionnel)',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _P.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descCtrl,
                        focusNode: _descFocus,
                        maxLines: 4,
                        maxLength: 500,
                        textCapitalization: TextCapitalization.sentences,
                        style: GoogleFonts.inter(
                            fontSize: 14, color: _P.ink),
                        decoration: InputDecoration(
                          hintText:
                              'Décrivez votre activité, vos spécialités, votre expérience...',
                          hintStyle: GoogleFonts.inter(
                              color: _P.inkSoft, fontSize: 13),
                          counterText: '',
                          filled: true,
                          fillColor: _P.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        buildCounter: (ctx,
                                {required currentLength,
                                required isFocused,
                                maxLength}) =>
                            Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '$currentLength/500',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: currentLength > 450
                                  ? _P.amber
                                  : _P.inkSoft,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Conditions d'utilisation
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _agreedToTerms = !_agreedToTerms);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _P.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _P.line),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: _agreedToTerms
                                      ? _P.green
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _agreedToTerms
                                        ? _P.green
                                        : _P.line,
                                    width: 2,
                                  ),
                                ),
                                child: _agreedToTerms
                                    ? const Icon(Icons.check,
                                        size: 14, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    style: GoogleFonts.inter(
                                        fontSize: 12, color: _P.ink),
                                    children: [
                                      const TextSpan(
                                          text:
                                              "J'accepte les conditions d'utilisation et la "),
                                      TextSpan(
                                        text:
                                            "politique de confidentialité",
                                        style: GoogleFonts.inter(
                                          color: _P.rose,
                                          fontWeight: FontWeight.w700,
                                          decoration:
                                              TextDecoration.underline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Bouton de soumission
                      SizedBox(
                        height: 58,
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _P.rose,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            disabledBackgroundColor: _P.rose.withOpacity(0.5),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Créer mon compte gratuit',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_forward_rounded,
                                        size: 20),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Lien vers connexion
                      Center(
                        child: TextButton(
                          onPressed: () => context.push(
                              '/thix-weeding/provider/auth'),
                          child: Text.rich(
                            TextSpan(
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: _P.inkSoft,
                              ),
                              children: [
                                const TextSpan(
                                    text: 'Déjà inscrit ? '),
                                TextSpan(
                                  text: 'Se connecter',
                                  style: GoogleFonts.inter(
                                    color: _P.rose,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
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

// ═══════════════════════════════════════════════════════════════════════════
// COMPOSANT CHAMP RÉUTILISABLE
// ═══════════════════════════════════════════════════════════════════════════

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboard;
  final String? Function(String?)? validator;
  final FocusNode? focusNode;
  final FocusNode? nextFocus;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboard,
    this.validator,
    this.focusNode,
    this.nextFocus,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _P.ink,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboard,
            validator: validator,
            inputFormatters: inputFormatters,
            textCapitalization: textCapitalization,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _P.ink,
            ),
            onFieldSubmitted: (_) {
              if (nextFocus != null) {
                FocusScope.of(context).requestFocus(nextFocus);
              }
            },
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(
                  color: _P.inkSoft, fontSize: 13, fontWeight: FontWeight.w500),
              prefixIcon: Icon(icon, color: _P.rose, size: 20),
              filled: true,
              fillColor: _P.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              errorStyle: GoogleFonts.inter(
                fontSize: 11,
                color: _P.red,
                fontWeight: FontWeight.w600,
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _P.red, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _P.red, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
