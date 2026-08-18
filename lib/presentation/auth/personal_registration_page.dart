import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart'; // 🌟 Requis pour le Parrainage
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/user_service.dart';
import 'package:thix_id/theme.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';

// ============================================================================
// THIX ID — GÉNÉRATION & VALIDATION
// ============================================================================
class ThixIdGenerator {
  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static final _secureRandom = Random.secure();

  static String _countryCode(String? fullCountryName) {
    switch (fullCountryName) {
      case 'République Démocratique du Congo': return 'CD';
      case 'Rwanda': return 'RW';
      case 'Burundi': return 'BI';
      case 'Ouganda': return 'UG';
      case 'Angola': return 'AO';
      case "Côte d'Ivoire": return 'CI';
      case 'Sénégal': return 'SN';
      case 'Cameroun': return 'CM';
      case 'France': return 'FR';
      case 'Belgique': return 'BE';
      case 'Canada': return 'CA';
      case 'États-Unis': return 'US';
      default: return 'XX';
    }
  }

  static int _checkDigit(String body) {
    var sum = 0;
    for (var i = 0; i < body.length; i++) {
      final code = body.codeUnitAt(i);
      final weight = (i % 2 == 0) ? 3 : 7;
      sum += code * weight;
    }
    return sum % 10;
  }

  static String generateLocal({String? countryName}) {
    final cc = _countryCode(countryName);
    final now = DateTime.now();
    final mmyy = '${now.month.toString().padLeft(2, '0')}${now.year % 100}';
    final random5 = List.generate(5, (_) => _secureRandom.nextInt(10)).join();
    final code3 = String.fromCharCodes(
      List.generate(3, (_) => _alphabet.codeUnitAt(_secureRandom.nextInt(_alphabet.length))),
    );
    final body = 'THIX-$cc-$mmyy-$random5-$code3';
    final check = _checkDigit(body);
    return '$body-$check';
  }
}

class ThixIdValidator {
  static bool isValid(String thixId) {
    final parts = thixId.split('-');
    if (parts.length != 6 || parts[0] != 'THIX') return false;
    final body = parts.sublist(0, 5).join('-');
    final expected = ThixIdGenerator._checkDigit(body);
    final actual = int.tryParse(parts[5]);
    return actual != null && actual == expected;
  }
}

// ============================================================================
// DESIGN SYSTEM
// ============================================================================
class _AppColors {
  static const Color primary = Color(0xFF0A3D62);
  static const Color primaryLight = Color(0xFF1A5A8C);
  static const Color accent = Color(0xFFF8961E);
  static const Color accentLight = Color(0xFFF9C74F);
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color textDark = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color success = Color(0xFF10B981);
  static const Color successBg = Color(0xFFD1FAE5);
}

class _PremiumField extends StatefulWidget {
  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final bool isPassword;
  final TextInputType keyboardType;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _PremiumField({
    required this.label,
    this.hint = '',
    required this.icon,
    required this.controller,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.readOnly = false,
    this.onTap,
    this.trailing,
  });

  @override
  State<_PremiumField> createState() => _PremiumFieldState();
}

class _PremiumFieldState extends State<_PremiumField> {
  late bool _obscured = widget.isPassword;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _AppColors.textDark)),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscured,
          keyboardType: widget.keyboardType,
          readOnly: widget.readOnly,
          onTap: widget.onTap,
          style: const TextStyle(fontSize: 14, color: _AppColors.textDark, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(color: _AppColors.textMuted, fontWeight: FontWeight.w400),
            prefixIcon: Icon(widget.icon, size: 20, color: _AppColors.textMuted),
            suffixIcon: widget.trailing ??
                (widget.isPassword
                    ? IconButton(
                        splashRadius: 20,
                        icon: Icon(_obscured ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20, color: _AppColors.textMuted),
                        onPressed: () => setState(() => _obscured = !_obscured),
                      )
                    : null),
            filled: true,
            fillColor: _AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _AppColors.primary, width: 1.5)),
          ),
        ),
      ],
    );
  }
}

class _PremiumDropdown extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _PremiumDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _AppColors.textDark)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          icon: const Icon(Icons.expand_more_rounded, size: 20, color: _AppColors.textMuted),
          style: const TextStyle(fontSize: 14, color: _AppColors.textDark, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: _AppColors.textMuted),
            filled: true,
            fillColor: _AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _AppColors.primary, width: 1.5)),
          ),
          hint: const Text('Sélectionner', style: TextStyle(color: _AppColors.textMuted, fontWeight: FontWeight.w400)),
          items: items.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ============================================================================
// PAGE D'INSCRIPTION PRINCIPALE
// ============================================================================
class PersonalRegistrationPage extends ConsumerStatefulWidget {
  final int? initialStep;
  const PersonalRegistrationPage({super.key, this.initialStep});

  @override
  ConsumerState<PersonalRegistrationPage> createState() => _PersonalRegistrationPageState();
}

class _PersonalRegistrationPageState extends ConsumerState<PersonalRegistrationPage> {
  final _userService = UserService(Supabase.instance.client);

  final _nameC = TextEditingController();
  final _dobC = TextEditingController();
  String? _country;
  final _occupationC = TextEditingController();

  final _emailC = TextEditingController();
  final _phoneC = TextEditingController(); // 🌟 Ajout Mobile
  final _passwordC = TextEditingController();
  final _confirmC = TextEditingController();
  final _otpC = TextEditingController();
  final _thixChatC = TextEditingController();

  String _thixIdGenerated = '';
  
  bool _otpSent = false;
  bool _isNavigating = false;
  int _step = 1;

  Timer? _resendTimer;
  int _resendCooldown = 0;
  static const int _resendCooldownDuration = 45;

  @override
  void dispose() {
    _nameC.dispose(); _dobC.dispose(); _occupationC.dispose();
    _emailC.dispose(); _phoneC.dispose(); _passwordC.dispose(); 
    _confirmC.dispose(); _otpC.dispose(); _thixChatC.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: isError ? Colors.red.shade700 : _AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _userFacingError(Object e) {
    debugPrint('[PersonalRegistration] erreur brute: $e');
    final msg = e.toString().toLowerCase();

    if (msg.contains('already registered') || msg.contains('already exists')) return 'Un compte existe déjà avec cet email ou ce numéro.';
    if (msg.contains('invalid login') || msg.contains('invalid credentials')) return 'Email ou mot de passe incorrect.';
    if (msg.contains('token') && (msg.contains('expired') || msg.contains('invalid'))) return 'Le code saisi est invalide ou a expiré. Demandez un nouveau code.';
    if (msg.contains('rate limit') || msg.contains('too many')) return 'Trop de tentatives. Merci de patienter quelques instants.';
    if (msg.contains('23505')) return 'Ce THIX CHAT est déjà pris, merci d\'en choisir un autre.';
    return 'Erreur exacte : $e';
  }

  bool _isValidEmail(String email) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

  String? _passwordIssue(String pass) {
    if (pass.length < 8) return 'Le mot de passe doit contenir au moins 8 caractères.';
    if (!RegExp(r'[A-Za-z]').hasMatch(pass) || !RegExp(r'[0-9]').hasMatch(pass)) return 'Le mot de passe doit contenir au moins une lettre et un chiffre.';
    return null;
  }

  bool _isValidThixChat(String chat) {
    return RegExp(r'^@[a-z0-9._]{3,20}$').hasMatch(chat);
  }

  Future<void> _goToStep2() async {
    if (_isNavigating) return;
    final name = _nameC.text.trim();
    final dob = _dobC.text.trim();
    if (name.isEmpty) return _snack('Nom complet requis.', isError: true);
    if (dob.isEmpty) return _snack('Date de naissance requise.', isError: true);
    if (_country == null) return _snack('Veuillez choisir votre pays.', isError: true);

    _isNavigating = true;
    setState(() => _step = 2);
    _isNavigating = false;
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendCooldown = _resendCooldownDuration);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown -= 1);
      }
    });
  }

  Future<bool> _createAuthUser() async {
    final email = _emailC.text.trim().toLowerCase();
    final phone = _phoneC.text.trim();
    final pass = _passwordC.text;
    final confirm = _confirmC.text;

    if (email.isEmpty || !_isValidEmail(email)) { _snack('Email invalide.', isError: true); return false; }
    if (phone.isEmpty) { _snack('Numéro de mobile requis.', isError: true); return false; }
    final passIssue = _passwordIssue(pass);
    if (passIssue != null) { _snack(passIssue, isError: true); return false; }
    if (pass != confirm) { _snack('Les mots de passe ne correspondent pas.', isError: true); return false; }

    final authNotifier = ref.read(authControllerProvider.notifier);
    
    try {
      await authNotifier.registerPersonal(
        email: email,
        password: pass,
        displayName: _nameC.text.trim(),
        rememberMe: true,
        profileDraft: {
          'full_name': _nameC.text.trim(),
          'date_of_birth': _dobC.text.trim(),
          'country_or_origin': _country,
          'occupation': _occupationC.text.trim(),
          'phone_number': phone, // 🌟 Ajout en DB
          'registration_status': 'draft_step1',
          'account_status': 'pending', // Requis pour le parrainage
        },
      );
      return true;
    } catch (e) {
      final message = e.toString().toLowerCase();
      if (message.contains('inscription enregistrée') || message.contains('confirm')) {
        return true;
      }
      _snack(_userFacingError(e), isError: true);
      return false;
    }
  }

  Future<void> _sendOtp() async {
    final isLoading = ref.read(authControllerProvider).isLoading;
    if (isLoading || _resendCooldown > 0) return;

    final success = await _createAuthUser();
    if (success) {
      if (!mounted) return;
      setState(() => _otpSent = true);
      _startResendCooldown();
      _snack('Un code OTP vous a été envoyé par email.');
    }
  }

  // 🌟 NOUVEAU : Logique d'affichage du QR Code de parrainage
      Future<void> _showQrParrainageDialog() async {
    final email = _emailC.text.trim().toLowerCase();
    final password = _passwordC.text;
    final phone = _phoneC.text.trim();

    if (email.isEmpty || !_isValidEmail(email)) {
      _snack('Veuillez d\'abord saisir une adresse email valide.', isError: true);
      return;
    }
    if (password.length < 8) {
      _snack('Veuillez définir un mot de passe (min. 8 caractères).', isError: true);
      return;
    }
    if (phone.isEmpty) {
      _snack('Veuillez saisir votre numéro de mobile.', isError: true);
      return;
    }

    // On s'assure que le compte Auth est créé dans Supabase avant d'ouvrir le QR
    final success = await _createAuthUser();
    if (!success) return;

    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => SecureQrParrainageDialog(
        email: email,
        phone: phone,
        fullName: _nameC.text.trim(),
        country: _country,
        occupation: _occupationC.text.trim(),
        onSuccess: () {
          _completeRegistration(isParrainage: true);
        },
      ),
    );
  }



    // Factorisation de la finalisation pour l'OTP et le Parrainage
  Future<void> _completeRegistration({required bool isParrainage}) async {
    final authNotifier = ref.read(authControllerProvider.notifier);

    try {
      if (!isParrainage) {
        // Validation OTP Classique
        final code = _otpC.text.trim();
        if (code.isEmpty) {
          _snack('Veuillez saisir le code reçu.', isError: true);
          return;
        }
        await authNotifier.verifyOTP(
          email: _emailC.text.trim().toLowerCase(),
          token: code,
        );
      }
      
      // 🌟 CORRECTION ICI : Extraction explicite et sécurisée de l'ID
      final appUser = ref.read(authControllerProvider).value;
      final supaUser = Supabase.instance.client.auth.currentUser;
      final uid = appUser?.id ?? supaUser?.id;

      if (uid == null) throw Exception('Utilisateur introuvable.');
      
      // Configuration ThixChat
      final firstName = _nameC.text.isNotEmpty ? _nameC.text.split(' ').first.toLowerCase() : 'user';
      final randomSuffix = DateTime.now().millisecondsSinceEpoch % 10000;
      final desiredChatRaw = _thixChatC.text.trim();
      final desiredChat = desiredChatRaw.isNotEmpty ? desiredChatRaw : '@$firstName$randomSuffix';
      
      if (!_isValidThixChat(desiredChat)) {
        _snack('THIX CHAT invalide (3 à 20 caractères max).', isError: true);
        return;
      }

      // Utilisation du 'uid' fraîchement extrait
      final claimed = await _userService.ensureThixChat(uid: uid, desired: desiredChat);

      // Génération THIX ID
      String officialThixId;
      try {
        final countryCode = ThixIdGenerator._countryCode(_country);
        final result = await Supabase.instance.client.rpc('generate_thix_id', params: {'country_code': countryCode});
        officialThixId = (result as String?)?.trim() ?? '';
        if (officialThixId.isEmpty || officialThixId.toUpperCase().startsWith('THIX-PENDING')) {
          throw Exception('RPC a retourné un ID invalide');
        }
      } catch (rpcErr) {
        officialThixId = ThixIdGenerator.generateLocal(countryName: _country);
      }

      // Mise à jour DB (Le profil passe en actif définitivement)
      await _userService.updateProfile(
        uid: uid,
        thixId: officialThixId,
        thixChat: claimed,
        registrationStatus: 'active',
      );

      // 🌟 CORRECTION ICI : Mise à jour de la mémoire de l'app via appUser
      if (appUser != null) {
        await authNotifier.updateCurrentUser(
          appUser.copyWith(
            thixId: officialThixId,
            thixChat: claimed,
            registrationStatus: 'active',
            updatedAt: DateTime.now(),
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        _thixIdGenerated = officialThixId;
        _thixChatC.text = claimed;
        _step = 3;
      });
      _snack(isParrainage ? 'Compte activé par votre parrain !' : 'Compte activé avec succès !');
      
    } catch (e) {
      _snack(_userFacingError(e), isError: true);
    }
  }


  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: _AppColors.background,
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Positioned(
              top: 0, left: 0, right: 0, height: 260,
              child: Container(
                padding: const EdgeInsets.only(top: 60),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_AppColors.primary, _AppColors.primaryLight]),
                ),
                child: Column(
                  children: [
                    Text('THIX ID', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: _AppColors.accentLight, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    const SizedBox(height: 16),
                    _buildStepper(),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              top: 160,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: _AppColors.surface, 
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 24, offset: const Offset(0, 8))],
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400), 
                        switchInCurve: Curves.easeOutCubic, 
                        switchOutCurve: Curves.easeInCubic,
                        child: KeyedSubtree(key: ValueKey(_step), child: _buildStepContent(isLoading)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildMainButton(isLoading),
                    const SizedBox(height: 16),
                    if (_step < 3)
                      TextButton(
                        onPressed: () {
                          if (_step == 2) setState(() => _step = 1);
                          else context.go(AppRoutes.login);
                        },
                        style: TextButton.styleFrom(foregroundColor: _AppColors.textMuted),
                        child: Text(
                          _step == 2 ? '← Revenir à l\'étape 1' : 'Déjà un compte ? Se connecter', 
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)
                        ),
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepper() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StepDot(isActive: true, isDone: _step > 1),
        _StepLine(isActive: _step > 1),
        _StepDot(isActive: _step >= 2, isDone: _step > 2),
        _StepLine(isActive: _step > 2),
        _StepDot(isActive: _step == 3, isDone: _step == 3, isFinal: true),
      ],
    );
  }

  Widget _buildStepContent(bool isLoading) {
    switch (_step) {
      case 1:
        return _Step1Profile(
          nameC: _nameC, dobC: _dobC, country: _country,
          onCountryChanged: (v) => setState(() => _country = v),
          occupationC: _occupationC, onPickDob: _pickDob,
        );
      case 2:
        return _Step2Account(
          emailC: _emailC, phoneC: _phoneC, passwordC: _passwordC, confirmC: _confirmC, 
          otpC: _otpC, thixChatC: _thixChatC, onSendOtp: _sendOtp, onShowQrParrainage: _showQrParrainageDialog,
          isOtpSent: _otpSent, isLoading: isLoading, resendCountdown: _resendCooldown,
        );
      case 3:
        return _Step3Final(
          thixId: _thixIdGenerated, thixChat: _thixChatC.text,
          name: _nameC.text, email: _emailC.text, phone: _phoneC.text,
          dob: _dobC.text, country: _country ?? '', occupation: _occupationC.text,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 110),
      lastDate: DateTime(now.year - 10),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme.copyWith(primary: _AppColors.primary)),
        child: child!,
      ),
    );
    if (picked != null) {
      final v = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() => _dobC.text = v);
    }
  }

  Widget _buildMainButton(bool isLoading) {
    String label;
    VoidCallback? onPressed;
    switch (_step) {
      case 1: label = 'Suivant'; onPressed = _goToStep2; break;
      case 2: label = isLoading ? 'Vérification...' : 'Confirmer l\'inscription'; onPressed = () => _completeRegistration(isParrainage: false); break;
      case 3: label = 'Accéder au Tableau de Bord'; onPressed = () => context.go(AppRoutes.userDashboard); break;
      default: label = ''; onPressed = null;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          elevation: 4,
          shadowColor: _AppColors.primary.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading) ...const [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
              SizedBox(width: 12),
            ],
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 0.5)),
            if (!isLoading && _step < 3) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.arrow_forward_rounded, size: 20)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SOUS-WIDGETS : ÉTAPES & DESIGN
// ============================================================================
class _StepDot extends StatelessWidget {
  final bool isActive;
  final bool isDone;
  final bool isFinal;
  const _StepDot({required this.isActive, required this.isDone, this.isFinal = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: isDone || isActive ? _AppColors.accentLight : Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: isActive ? Colors.white : Colors.transparent, width: 2),
      ),
      child: Center(
        child: Icon(
          isFinal ? Icons.check_rounded : (isDone ? Icons.check_rounded : Icons.circle),
          size: 14, color: isDone || isActive ? _AppColors.primary : Colors.white.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool isActive;
  const _StepLine({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 40, height: 3,
      color: isActive ? _AppColors.accentLight : Colors.white.withValues(alpha: 0.2),
    );
  }
}

class _Step1Profile extends StatelessWidget {
  final TextEditingController nameC, dobC, occupationC;
  final String? country;
  final ValueChanged<String?> onCountryChanged;
  final VoidCallback onPickDob;

  const _Step1Profile({required this.nameC, required this.dobC, required this.occupationC, required this.country, required this.onCountryChanged, required this.onPickDob});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Informations personnelles', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _AppColors.primary)),
        const SizedBox(height: 6),
        const Text('Ces informations permettront de générer votre identité numérique.', style: TextStyle(fontSize: 14, color: _AppColors.textMuted)),
        const SizedBox(height: 24),
        _PremiumField(label: 'Nom complet *', hint: 'Ex : Jean Mukendi', icon: Icons.person_outline_rounded, controller: nameC),
        const SizedBox(height: 16),
        _PremiumField(label: 'Date de naissance *', hint: 'JJ-MM-AAAA', icon: Icons.calendar_today_rounded, controller: dobC, readOnly: true, onTap: onPickDob, trailing: const Icon(Icons.expand_more_rounded, color: _AppColors.textMuted)),
        const SizedBox(height: 16),
        _PremiumDropdown(label: 'Pays *', icon: Icons.public_rounded, value: country, items: const ['République Démocratique du Congo', 'Rwanda', 'Burundi', 'Ouganda', 'Angola', "Côte d'Ivoire", 'Sénégal', 'Cameroun', 'France', 'Belgique', 'Canada', 'États-Unis', 'Autre'], onChanged: onCountryChanged),
        const SizedBox(height: 16),
        _PremiumField(label: 'Occupation (facultatif)', hint: 'Ex : Entrepreneur, Ingénieur...', icon: Icons.work_outline_rounded, controller: occupationC),
      ],
    );
  }
}

class _Step2Account extends StatelessWidget {
  final TextEditingController emailC, phoneC, passwordC, confirmC, otpC, thixChatC;
  final VoidCallback onSendOtp, onShowQrParrainage;
  final bool isOtpSent, isLoading;
  final int resendCountdown;

  const _Step2Account({
    required this.emailC, required this.phoneC, required this.passwordC, required this.confirmC, 
    required this.otpC, required this.thixChatC, required this.onSendOtp, required this.onShowQrParrainage,
    required this.isOtpSent, required this.isLoading, required this.resendCountdown
  });

  @override
  Widget build(BuildContext context) {
    final canResend = !isLoading && resendCountdown == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Sécurité du compte', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _AppColors.primary)),
        const SizedBox(height: 6),
        const Text('Définissez vos identifiants de connexion.', style: TextStyle(fontSize: 14, color: _AppColors.textMuted)),
        const SizedBox(height: 24),
        
        _PremiumField(label: 'Adresse Email *', hint: 'votre@email.com', icon: Icons.email_outlined, controller: emailC, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 16),
        _PremiumField(label: 'Numéro de mobile (Connexion) *', hint: '+243 000 000 000', icon: Icons.phone_android_rounded, controller: phoneC, keyboardType: TextInputType.phone),
        const SizedBox(height: 16),
        
        _PremiumField(label: 'Mot de passe *', hint: 'Min. 8 caractères, 1 chiffre, 1 lettre', icon: Icons.lock_outline_rounded, controller: passwordC, isPassword: true),
        const SizedBox(height: 16),
        _PremiumField(label: 'Confirmer le mot de passe *', hint: 'Répétez le mot de passe', icon: Icons.lock_outline_rounded, controller: confirmC, isPassword: true),
        const SizedBox(height: 24),
        
        const Divider(color: _AppColors.border),
        const SizedBox(height: 16),
        
        const Text('Vérification', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _AppColors.textDark)),
        const SizedBox(height: 16),

        SizedBox(
          height: 50,
          child: OutlinedButton.icon(
            onPressed: canResend ? onSendOtp : null,
            icon: Icon(isOtpSent ? Icons.check_circle_outline_rounded : Icons.send_rounded, size: 20),
            label: Text(!canResend && resendCountdown > 0 ? 'Renvoyer dans ${resendCountdown}s' : (isOtpSent ? 'Code envoyé - Renvoyer' : 'Obtenir le code OTP'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: _AppColors.primary,
              side: BorderSide(color: isOtpSent ? _AppColors.success : _AppColors.primary, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),

        // 🌟 BOUTON PARRAINAGE
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: Divider(color: _AppColors.border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('OU', style: TextStyle(color: _AppColors.textMuted.withValues(alpha: 0.5), fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const Expanded(child: Divider(color: _AppColors.border)),
          ],
        ),
        const SizedBox(height: 16),

        SizedBox(
          height: 50,
          child: OutlinedButton.icon(
            onPressed: onShowQrParrainage,
            icon: const Icon(Icons.qr_code_2_rounded, size: 22),
            label: const Text('Activer via Parrainage (QR)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              foregroundColor: _AppColors.textDark,
              side: const BorderSide(color: _AppColors.border, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        
        if (isOtpSent) ...[
          const SizedBox(height: 24),
          _PremiumField(label: 'Code reçu par email *', hint: '000000', icon: Icons.confirmation_number_outlined, controller: otpC, keyboardType: TextInputType.number),
        ],

        const SizedBox(height: 24),
        _PremiumField(label: 'THIX CHAT (Pseudo public) *', hint: '@pseudo_123', icon: Icons.alternate_email_rounded, controller: thixChatC),
      ],
    );
  }
}

class _Step3Final extends StatelessWidget {
  final String thixId, thixChat, name, email, phone, dob, country, occupation;

  const _Step3Final({
    required this.thixId, required this.thixChat, 
    required this.name, required this.email, required this.phone,
    required this.dob, required this.country, required this.occupation
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: _AppColors.successBg, shape: BoxShape.circle),
            child: const Icon(Icons.verified_rounded, color: _AppColors.success, size: 48),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Félicitations !', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _AppColors.primary)),
        const SizedBox(height: 8),
        Text('Votre compte est actif. Bienvenue sur THIX ID, $name.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: _AppColors.textMuted, height: 1.4)),
        
        const SizedBox(height: 32),
        
        // DIGITAL ID CARD
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_AppColors.primary, _AppColors.primaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: _AppColors.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('CARTE D\'IDENTITÉ THIX', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                  Icon(Icons.contactless_rounded, color: Colors.white.withValues(alpha: 0.8), size: 20),
                ],
              ),
              const SizedBox(height: 24),
              const Text('THIX ID OFFICIEL', style: TextStyle(color: _AppColors.accentLight, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(thixId.isEmpty ? 'Génération...' : thixId, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (thixId.isNotEmpty)
                    IconButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: thixId));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('THIX ID copié !'), backgroundColor: _AppColors.success));
                      },
                      icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    )
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('THIX CHAT', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(thixChat, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 40),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),
        const Text('Résumé de vos informations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _AppColors.textDark)),
        const SizedBox(height: 16),
        
        // SUMMARY TABLE
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _AppColors.border),
          ),
          child: Column(
            children: [
              _SummaryRow(label: 'Nom complet', value: name),
              const Divider(height: 1, color: _AppColors.border),
              _SummaryRow(label: 'Email', value: email),
              const Divider(height: 1, color: _AppColors.border),
              _SummaryRow(label: 'Mobile', value: phone),
              const Divider(height: 1, color: _AppColors.border),
              _SummaryRow(label: 'Date de naissance', value: dob),
              const Divider(height: 1, color: _AppColors.border),
              _SummaryRow(label: 'Pays', value: country),
              if (occupation.isNotEmpty) ...[
                const Divider(height: 1, color: _AppColors.border),
                _SummaryRow(label: 'Occupation', value: occupation),
              ]
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, style: const TextStyle(color: _AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500))),
          Expanded(flex: 3, child: Text(value, textAlign: TextAlign.right, style: const TextStyle(color: _AppColors.textDark, fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

// ============================================================================
// WIDGET : DIALOGUE DE PARRAINAGE SÉCURISÉ (PRODUCTION)
// ============================================================================
class SecureQrParrainageDialog extends StatefulWidget {
  final String email;
  final String phone;
  final String fullName;
  final String? country;
  final String occupation;
  final VoidCallback onSuccess;

  const SecureQrParrainageDialog({
    super.key,
    required this.email,
    required this.phone,
    required this.fullName,
    this.country,
    required this.occupation,
    required this.onSuccess,
  });

  @override
  State<SecureQrParrainageDialog> createState() => _SecureQrParrainageDialogState();
}

class _SecureQrParrainageDialogState extends State<SecureQrParrainageDialog> {
  late Future<String> _tokenFuture;
  StreamSubscription? _statusSubscription;

  @override
  void initState() {
    super.initState();
    _tokenFuture = _generateTokenFromServer();
  }

  Future<String> _generateTokenFromServer() async {
    try {
      final response = await Supabase.instance.client.rpc(
        'generate_qr_activation_token',
        params: {
          'p_email': widget.email,
          'p_phone': widget.phone,
          'p_full_name': widget.fullName,
          'p_country': widget.country ?? '',
          'p_occupation': widget.occupation,
        },
      );

      final token = response.toString();
      
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        _statusSubscription = Supabase.instance.client
            .from('profiles')
            .stream(primaryKey: ['id'])
            .eq('id', userId)
            .listen((data) {
          if (data.isNotEmpty && data.first['account_status'] == 'active') {
            widget.onSuccess();
            if (mounted) Navigator.pop(context);
          }
        });
      }

      return token;
    } catch (e) {
      throw Exception('Erreur de génération sécurisée : $e');
    }
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: FutureBuilder<String>(
          future: _tokenFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SizedBox(
                height: 250,
                child: Center(
                  child: CircularProgressIndicator(color: ThixPolicy.primary),
                ),
              );
            }

            if (snapshot.hasError) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Erreur : ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fermer'),
                  ),
                ],
              );
            }

            final token = snapshot.data!;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.qr_code_scanner_rounded, color: ThixPolicy.primary, size: 40),
                const SizedBox(height: 16),
                Text(
                  'Activation Sécurisée',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ThixPolicy.primary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Faites scanner ce code par un pair accrédité pour valider l\'identité.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 24),
                QrImageView(
                  data: token,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Valide pour 15 minutes',
                  style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Annuler', style: TextStyle(color: ThixPolicy.textMain)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}




