import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zxcvbn/zxcvbn.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/theme.dart';

// ============================================================================
// POLITIQUE MOT DE PASSE
// ============================================================================
class PasswordPolicy {
  static const minLength = 12;

  static Future<String?> validate(
    String password, {
    required String email,
    required String fullName,
    required String phone,
  }) async {
    if (password.length < minLength) {
      return 'Le mot de passe doit contenir au moins $minLength caractères.';
    }

    final zxcvbn = Zxcvbn();
    final userInputs = [email, fullName, phone]
        .where((s) => s.isNotEmpty)
        .map((s) => s.toLowerCase())
        .toList();
    final result = zxcvbn.evaluate(password, userInputs: userInputs);
    if ((result.score ?? 0) < 3) {
      final warning = result.feedback?.warning ?? '';
      final suggestions = result.feedback?.suggestions.join(' ') ?? '';
      return 'Mot de passe trop faible. $warning $suggestions'.trim();
    }

    final pwned = await _isPasswordPwned(password);
    if (pwned) {
      return 'Ce mot de passe apparaît dans une fuite connue. Choisissez-en un autre.';
    }
    return null;
  }

  /// HIBP k-anonymity : seul le préfixe SHA-1 part.
  /// Fail-open si le réseau est down (on n'bloque pas l'inscription).
  static Future<bool> _isPasswordPwned(String password) async {
    try {
      final hash = sha1.convert(utf8.encode(password)).toString().toUpperCase();
      final prefix = hash.substring(0, 5);
      final suffix = hash.substring(5);
      final res = await http
          .get(
            Uri.parse('https://api.pwnedpasswords.com/range/$prefix'),
            headers: {
              'User-Agent': 'THIX-ID-App/1.0',
              'Add-Padding': 'true',
            },
          )
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return false;
      for (final line in res.body.split('\n')) {
        final parts = line.split(':');
        if (parts.length == 2 && parts[0].trim() == suffix) {
          final count = int.tryParse(parts[1].trim()) ?? 0;
          return count >= 5;
        }
      }
      return false;
    } catch (e) {
      debugPrint('[PasswordPolicy] HIBP unavailable: $e');
      return false;
    }
  }
}

// ============================================================================
// DESIGN
// ============================================================================
class _AppColors {
  static const Color primary = Color(0xFF0A3D62);
  static const Color primaryLight = Color(0xFF1A5A8C);
  static const Color accentLight = Color(0xFFF9C74F);
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color textDark = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color success = Color(0xFF10B981);
  static const Color successBg = Color(0xFFD1FAE5);
  static const Color danger = Color(0xFFDC2626);
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
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;

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
    this.errorText,
    this.onChanged,
    this.inputFormatters,
    this.maxLength,
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
        Text(
          widget.label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _AppColors.textDark),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscured,
          keyboardType: widget.keyboardType,
          readOnly: widget.readOnly,
          onTap: widget.onTap,
          onChanged: widget.onChanged,
          maxLength: widget.maxLength,
          inputFormatters: widget.inputFormatters,
          style: const TextStyle(fontSize: 14, color: _AppColors.textDark, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            counterText: '',
            hintText: widget.hint,
            errorText: widget.errorText,
            hintStyle: const TextStyle(color: _AppColors.textMuted, fontWeight: FontWeight.w400),
            prefixIcon: Icon(widget.icon, size: 20, color: _AppColors.textMuted),
            suffixIcon: widget.trailing ??
                (widget.isPassword
                    ? IconButton(
                        splashRadius: 20,
                        icon: Icon(
                          _obscured ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          size: 20,
                          color: _AppColors.textMuted,
                        ),
                        onPressed: () => setState(() => _obscured = !_obscured),
                      )
                    : null),
            filled: true,
            fillColor: _AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _AppColors.primary, width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _AppColors.danger, width: 1.5)),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _AppColors.danger, width: 1.5)),
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
// PAGE
// Étape 1 profil → 2 email/mdp/OTP → 3 chat + QR optionnel + activer → 4 carte
// ============================================================================
class PersonalRegistrationPage extends ConsumerStatefulWidget {
  final int? initialStep;
  const PersonalRegistrationPage({super.key, this.initialStep});

  @override
  ConsumerState<PersonalRegistrationPage> createState() => _PersonalRegistrationPageState();
}

class _PersonalRegistrationPageState extends ConsumerState<PersonalRegistrationPage> {
  final _nameC = TextEditingController();
  final _dobC = TextEditingController();
  String? _country;
  final _occupationC = TextEditingController();
  final _emailC = TextEditingController();
  final _phoneC = TextEditingController();
  final _passwordC = TextEditingController();
  final _confirmC = TextEditingController();
  final _otpC = TextEditingController();
  final _thixChatC = TextEditingController();

  String _thixIdGenerated = '';
  String? _passwordError;
  bool _passwordValidating = false;
  int _passwordScore = -1;

  bool _otpSent = false;
  bool _emailVerified = false;
  bool _sponsored = false;
  bool _busy = false;
  int _step = 1;

  Timer? _resendTimer;
  int _resendCooldown = 0;
  static const int _resendCooldownDuration = 60;
  Timer? _passwordDebounce;

  static const _countries = [
    'République Démocratique du Congo',
    'Rwanda',
    'Burundi',
    'Ouganda',
    'Angola',
    "Côte d'Ivoire",
    'Sénégal',
    'Cameroun',
    'France',
    'Belgique',
    'Canada',
    'États-Unis',
    'Autre',
  ];

  @override
  void initState() {
    super.initState();
    _step = widget.initialStep ?? 1;
  }

  @override
  void dispose() {
    _nameC.dispose();
    _dobC.dispose();
    _occupationC.dispose();
    _emailC.dispose();
    _phoneC.dispose();
    _passwordC.dispose();
    _confirmC.dispose();
    _otpC.dispose();
    _thixChatC.dispose();
    _resendTimer?.cancel();
    _passwordDebounce?.cancel();
    super.dispose();
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: isError ? _AppColors.danger : _AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _userFacingError(Object e) {
    debugPrint('[PersonalRegistration] $e');
    final msg = e.toString().toLowerCase();
    if (msg.contains('already registered') || msg.contains('already exists')) {
      return 'Un compte existe déjà avec cet email.';
    }
    if (msg.contains('invalid login') || msg.contains('invalid credentials')) {
      return 'Email ou mot de passe incorrect.';
    }
    if (msg.contains('email_not_verified')) return 'Validez d'abord le code reçu par email.';
    if (msg.contains('invalid_status')) return 'Cette étape n'est pas encore disponible.';
    if (msg.contains('invalid_chat') || msg.contains('reserved') || msg.contains('réservé')) {
      return 'Ce THIX CHAT est invalide ou réservé.';
    }
    if (msg.contains('chat_taken') || msg.contains('23505')) {
      return 'Ce THIX CHAT est déjà pris.';
    }
    if (msg.contains('expired')) return 'Le code ou le QR a expiré. Recommencez.';
    if (msg.contains('invalid') && msg.contains('token')) return 'Code invalide.';
    if (msg.contains('rate limit') || msg.contains('too many')) {
      return 'Trop de tentatives. Patientez quelques instants.';
    }
    if (msg.contains('not_authenticated') || msg.contains('session')) {
      return 'Session expirée. Reprenez la vérification email.';
    }
    if (msg.contains('network') || msg.contains('timeout') || msg.contains('unavailable')) {
      return 'Erreur de connexion. Vérifiez votre réseau.';
    }
    return 'Une erreur est survenue. Réessayez dans quelques instants.';
  }

  bool _isValidEmail(String email) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(email);

  bool _isValidPhone(String phone) {
    final compact = phone.replaceAll(RegExp(r'[\s.-]'), '');
    return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(compact);
  }

  bool _isValidThixChat(String chat) =>
      RegExp(r'^@[a-z0-9._]{3,20}$').hasMatch(chat);

  String _mapCountryToCode(String? name) {
    const map = {
      'République Démocratique du Congo': 'CD',
      'Rwanda': 'RW',
      'Burundi': 'BI',
      'Ouganda': 'UG',
      'Angola': 'AO',
      "Côte d'Ivoire": 'CI',
      'Sénégal': 'SN',
      'Cameroun': 'CM',
      'France': 'FR',
      'Belgique': 'BE',
      'Canada': 'CA',
      'États-Unis': 'US',
    };
    return map[name] ?? 'XX';
  }

  Future<void> _onPasswordChanged(String value) async {
    _passwordDebounce?.cancel();
    if (value.isEmpty) {
      setState(() {
        _passwordError = null;
        _passwordScore = -1;
        _passwordValidating = false;
      });
      return;
    }
    setState(() => _passwordValidating = true);
    _passwordDebounce = Timer(const Duration(milliseconds: 400), () async {
      final error = await PasswordPolicy.validate(
        value,
        email: _emailC.text.trim().toLowerCase(),
        fullName: _nameC.text.trim(),
        phone: _phoneC.text.trim(),
      );
      if (!mounted) return;
      final result = Zxcvbn().evaluate(value, userInputs: [
        _emailC.text.trim().toLowerCase(),
        _nameC.text.trim().toLowerCase(),
      ]);
      setState(() {
        _passwordError = error;
        _passwordScore = result.score ?? 0;
        _passwordValidating = false;
      });
    });
  }

  Future<void> _goToStep2() async {
    if (_busy) return;
    final name = _nameC.text.trim();
    final dob = _dobC.text.trim();
    if (name.length < 3 || name.length > 100) {
      return _snack('Nom invalide (3 à 100 caractères).', isError: true);
    }
    if (dob.isEmpty) return _snack('Date de naissance requise.', isError: true);
    final parsed = DateTime.tryParse(dob);
    if (parsed == null) return _snack('Date de naissance invalide.', isError: true);
    final today = DateTime.now();
    final age = today.year - parsed.year - ((today.month < parsed.month || (today.month == parsed.month && today.day < parsed.day)) ? 1 : 0);
    if (age < 18) return _snack('Vous devez avoir au moins 18 ans.', isError: true);
    if (_country == null) return _snack('Veuillez choisir votre pays.', isError: true);
    setState(() => _step = 2);
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendCooldown = _resendCooldownDuration);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
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
    final phone = _phoneC.text.trim().replaceAll(RegExp(r'[\s.-]'), '');
    final pass = _passwordC.text;
    final confirm = _confirmC.text;

    if (!_isValidEmail(email)) {
      _snack('Email invalide.', isError: true);
      return false;
    }
    if (!_isValidPhone(phone)) {
      _snack('Numéro international requis (ex. +243…).', isError: true);
      return false;
    }
    final passIssue = await PasswordPolicy.validate(
      pass,
      email: email,
      fullName: _nameC.text.trim(),
      phone: phone,
    );
    if (passIssue != null) {
      _snack(passIssue, isError: true);
      return false;
    }
    if (pass != confirm) {
      _snack('Les mots de passe ne correspondent pas.', isError: true);
      return false;
    }

    try {
      await ref.read(authControllerProvider.notifier).registerPersonal(
            email: email,
            password: pass,
            displayName: _nameC.text.trim(),
            rememberMe: true,
            profileDraft: {
              'full_name': _nameC.text.trim(),
              'date_of_birth': _dobC.text.trim(),
              'country_or_origin': _country,
              'occupation': _occupationC.text.trim(),
              'phone_number': phone,
              'registration_status': 'draft_step2',
              'account_status': 'pending',
            },
          );
      return true;
    } catch (e) {
      final message = e.toString().toLowerCase();
      if (message.contains('already registered') || message.contains('already exists')) {
        _snack(_userFacingError(e), isError: true);
        return false;
      }
      if (message.contains('confirm') || message.contains('inscription enregistrée')) {
        return true;
      }
      _snack(_userFacingError(e), isError: true);
      return false;
    }
  }

  Future<void> _sendOtp() async {
    if (_busy || _resendCooldown > 0) return;
    setState(() => _busy = true);
    try {
      final success = await _createAuthUser();
      if (!success || !mounted) return;
      setState(() => _otpSent = true);
      _startResendCooldown();
      _snack('Un code à 6 chiffres a été envoyé à votre email.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _refreshEmailVerifiedFlag() async {
    try {
      final res = await Supabase.instance.client.auth.getUser();
      final ok = res.user?.emailConfirmedAt != null;
      _emailVerified = ok;
      return ok;
    } catch (_) {
      final ok = Supabase.instance.client.auth.currentUser?.emailConfirmedAt != null;
      _emailVerified = ok;
      return ok;
    }
  }

  /// Étape 2 : vérifie l'OTP UNIQUEMENT. N'active pas le compte.
  Future<void> _verifyEmailOnly() async {
    if (_busy) return;
    if (!_otpSent) {
      _snack('Demandez d'abord le code email.', isError: true);
      return;
    }
    final code = _otpC.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _snack('Saisissez le code à 6 chiffres.', isError: true);
      return;
    }

    setState(() => _busy = true);
    try {
      final notifier = ref.read(authControllerProvider.notifier);
      await notifier.verifyOTP(
        email: _emailC.text.trim().toLowerCase(),
        token: code,
      );
      try {
        await Supabase.instance.client.rpc('mark_email_verified');
      } catch (e) {
        debugPrint('[mark_email_verified] $e');
      }
      try {
        await notifier.refreshCurrentUser();
      } catch (_) {}

      final ok = await _refreshEmailVerifiedFlag();
      if (!ok) {
        _snack('Email non confirmé. Vérifiez le code.', isError: true);
        return;
      }
      if (!mounted) return;
      setState(() => _step = 3);
      _snack('Email vérifié. Choisissez votre identifiant public.');
    } catch (e) {
      _snack(_userFacingError(e), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showQrParrainageDialog() async {
    if (_busy) return;
    if (!await _refreshEmailVerifiedFlag()) {
      _snack('Validez d'abord le code email.', isError: true);
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SecureQrParrainageDialog(
        onSponsored: () {
          if (!mounted) return;
          setState(() => _sponsored = true);
          _snack('Parrainage reçu. Vous pouvez activer votre THIX ID.');
        },
      ),
    );
  }

  // ✅ CORRECTION 1 : Interpolation Dart standard (pas d'échappement Markdown)
  String _desiredChat() {
    final raw = _thixChatC.text.trim().toLowerCase();
    if (raw.isNotEmpty) return raw.startsWith('@') ? raw : '@$raw';
    final first = _nameC.text.trim().split(RegExp(r'\s+')).first.toLowerCase();
    final safe = first.replaceAll(RegExp(r'[^a-z0-9._]'), '');
    final base = safe.length >= 3 ? safe.substring(0, safe.length.clamp(0, 12)) : 'user';
    return '@${base}${DateTime.now().millisecondsSinceEpoch % 10000}';
  }

  /// Étape 3 : activation atomique serveur.
  Future<void> _finalize() async {
    if (_busy) return;
    if (!await _refreshEmailVerifiedFlag()) {
      _snack('Email non vérifié.', isError: true);
      return;
    }
    final chat = _desiredChat();
    if (!_isValidThixChat(chat)) {
      _snack('THIX CHAT invalide (@, 3–20 caractères a-z 0-9 . _).', isError: true);
      return;
    }

    setState(() => _busy = true);
    try {
      final result = await Supabase.instance.client.rpc(
        'finalize_registration',
        params: {
          'p_desired_chat': chat,
          'p_country_code': _mapCountryToCode(_country),
        },
      );

      Map<String, dynamic> data;
      if (result is Map<String, dynamic>) {
        data = result;
      } else if (result is Map) {
        data = Map<String, dynamic>.from(result);
      } else {
        throw Exception('Réponse serveur invalide.');
      }

      final officialThixId = (data['thix_id'] as String?)?.trim() ?? '';
      final claimedChat = (data['thix_chat'] as String?) ?? chat;
      if (officialThixId.isEmpty || officialThixId.toUpperCase().startsWith('THIX-PENDING')) {
        throw Exception('thix_id_failed');
      }

      try {
        await ref.read(authControllerProvider.notifier).refreshCurrentUser();
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _thixIdGenerated = officialThixId;
        _thixChatC.text = claimedChat;
        _step = 4;
      });
      final viaParrain = data['parrainage'] == true || _sponsored;
      _snack(viaParrain ? 'Compte activé avec parrainage.' : 'Compte activé avec succès.');
    } catch (e) {
      _snack(_userFacingError(e), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ✅ CORRECTION 2 : Interpolation Dart standard (pas d'échappement Markdown)
  Future<void> _pickDob() async {
    final now = DateTime.now();
    final adult = DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: adult,
      firstDate: DateTime(now.year - 110),
      lastDate: adult,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: _AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _dobC.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider).isLoading || _busy;

    return Scaffold(
      backgroundColor: _AppColors.background,
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 260,
              child: Container(
                padding: const EdgeInsets.only(top: 60),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_AppColors.primary, _AppColors.primaryLight],
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'THIX ID',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: _AppColors.accentLight,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                    ),
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
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: KeyedSubtree(
                          key: ValueKey(_step),
                          child: _buildStepContent(isLoading),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildMainButton(isLoading),
                    const SizedBox(height: 16),
                    if (_step < 4)
                      TextButton(
                        onPressed: isLoading
                            ? null
                            : () {
                                if (_step > 1) {
                                  setState(() => _step -= 1);
                                } else {
                                  context.go(AppRoutes.login);
                                }
                              },
                        style: TextButton.styleFrom(foregroundColor: _AppColors.textMuted),
                        child: Text(
                          _step == 1 ? 'Déjà un compte ? Se connecter' : '← Étape précédente',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
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
        _StepDot(isActive: _step >= 3, isDone: _step > 3),
        _StepLine(isActive: _step > 3),
        _StepDot(isActive: _step == 4, isDone: _step == 4, isFinal: true),
      ],
    );
  }

  Widget _buildStepContent(bool isLoading) {
    switch (_step) {
      case 1:
        return _Step1Profile(
          nameC: _nameC,
          dobC: _dobC,
          country: _country,
          onCountryChanged: (v) => setState(() => _country = v),
          occupationC: _occupationC,
          onPickDob: _pickDob,
          countries: _countries,
        );
      case 2:
        return _Step2Account(
          emailC: _emailC,
          phoneC: _phoneC,
          passwordC: _passwordC,
          confirmC: _confirmC,
          otpC: _otpC,
          onSendOtp: _sendOtp,
          onPasswordChanged: _onPasswordChanged,
          isOtpSent: _otpSent,
          isLoading: isLoading,
          resendCountdown: _resendCooldown,
          passwordError: _passwordError,
          passwordScore: _passwordScore,
          passwordValidating: _passwordValidating,
        );
      case 3:
        return _Step3Activate(
          thixChatC: _thixChatC,
          emailVerified: _emailVerified,
          sponsored: _sponsored,
          onShowQr: _showQrParrainageDialog,
        );
      case 4:
        return _Step4Final(
          thixId: _thixIdGenerated,
          thixChat: _thixChatC.text,
          name: _nameC.text,
          email: _emailC.text,
          phone: _phoneC.text,
          dob: _dobC.text,
          country: _country ?? '',
          occupation: _occupationC.text,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMainButton(bool isLoading) {
    String label;
    VoidCallback? onPressed;
    switch (_step) {
      case 1:
        label = 'Suivant';
        onPressed = _goToStep2;
        break;
      case 2:
        label = isLoading ? 'Vérification…' : 'Valider l'email';
        onPressed = _verifyEmailOnly;
        break;
      case 3:
        label = isLoading ? 'Activation…' : 'Activer mon THIX ID';
        onPressed = _finalize;
        break;
      case 4:
        label = 'Accéder au Tableau de Bord';
        onPressed = () => context.go(AppRoutes.userDashboard);
        break;
      default:
        label = '';
        onPressed = null;
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
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
            ],
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 0.5)),
            if (!isLoading && _step < 4)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.arrow_forward_rounded, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SOUS-WIDGETS
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
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: isDone || isActive ? _AppColors.accentLight : Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: isActive ? Colors.white : Colors.transparent, width: 2),
      ),
      child: Center(
        child: Icon(
          isFinal || isDone ? Icons.check_rounded : Icons.circle,
          size: 12,
          color: isDone || isActive ? _AppColors.primary : Colors.white.withValues(alpha: 0.5),
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
      width: 28,
      height: 3,
      color: isActive ? _AppColors.accentLight : Colors.white.withValues(alpha: 0.2),
    );
  }
}

class _Step1Profile extends StatelessWidget {
  final TextEditingController nameC, dobC, occupationC;
  final String? country;
  final ValueChanged<String?> onCountryChanged;
  final VoidCallback onPickDob;
  final List<String> countries;

  const _Step1Profile({
    required this.nameC,
    required this.dobC,
    required this.occupationC,
    required this.country,
    required this.onCountryChanged,
    required this.onPickDob,
    required this.countries,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Informations personnelles', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _AppColors.primary)),
        const SizedBox(height: 6),
        const Text(
          'Ces informations serviront à votre identité numérique. Réservé aux 18 ans et plus.',
          style: TextStyle(fontSize: 14, color: _AppColors.textMuted),
        ),
        const SizedBox(height: 24),
        _PremiumField(label: 'Nom complet *', hint: 'Ex : Jean Mukendi', icon: Icons.person_outline_rounded, controller: nameC),
        const SizedBox(height: 16),
        _PremiumField(
          label: 'Date de naissance *',
          hint: 'AAAA-MM-JJ',
          icon: Icons.calendar_today_rounded,
          controller: dobC,
          readOnly: true,
          onTap: onPickDob,
          trailing: const Icon(Icons.expand_more_rounded, color: _AppColors.textMuted),
        ),
        const SizedBox(height: 16),
        _PremiumDropdown(
          label: 'Pays *',
          icon: Icons.public_rounded,
          value: country,
          items: countries,
          onChanged: onCountryChanged,
        ),
        const SizedBox(height: 16),
        _PremiumField(
          label: 'Occupation (facultatif)',
          hint: 'Ex : Entrepreneur, Ingénieur…',
          icon: Icons.work_outline_rounded,
          controller: occupationC,
        ),
      ],
    );
  }
}

class _Step2Account extends StatelessWidget {
  final TextEditingController emailC, phoneC, passwordC, confirmC, otpC;
  final VoidCallback onSendOtp;
  final ValueChanged<String> onPasswordChanged;
  final bool isOtpSent, isLoading, passwordValidating;
  final int resendCountdown;
  final String? passwordError;
  final int passwordScore;

  const _Step2Account({
    required this.emailC,
    required this.phoneC,
    required this.passwordC,
    required this.confirmC,
    required this.otpC,
    required this.onSendOtp,
    required this.onPasswordChanged,
    required this.isOtpSent,
    required this.isLoading,
    required this.resendCountdown,
    required this.passwordError,
    required this.passwordScore,
    required this.passwordValidating,
  });

  Color _scoreColor(int score) {
    switch (score) {
      case 0:
      case 1:
        return _AppColors.danger;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.amber.shade700;
      case 4:
        return _AppColors.success;
      default:
        return _AppColors.border;
    }
  }

  String _scoreLabel(int score) {
    switch (score) {
      case 0:
        return 'Très faible';
      case 1:
        return 'Faible';
      case 2:
        return 'Moyen';
      case 3:
        return 'Fort';
      case 4:
        return 'Excellent';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final canResend = !isLoading && resendCountdown == 0;
    final bars = passwordScore < 0 ? 0 : (passwordScore == 0 ? 1 : passwordScore);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Sécurité du compte', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _AppColors.primary)),
        const SizedBox(height: 6),
        const Text('L'activation du THIX ID n'est possible qu'après validation de cet email.', style: TextStyle(fontSize: 14, color: _AppColors.textMuted)),
        const SizedBox(height: 24),
        _PremiumField(label: 'Adresse email *', hint: 'votre@email.com', icon: Icons.email_outlined, controller: emailC, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 16),
        _PremiumField(
          label: 'Numéro mobile international *',
          hint: '+243 000 000 000',
          icon: Icons.phone_android_rounded,
          controller: phoneC,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        _PremiumField(
          label: 'Mot de passe *',
          hint: 'Min. 12 caractères',
          icon: Icons.lock_outline_rounded,
          controller: passwordC,
          isPassword: true,
          onChanged: onPasswordChanged,
          errorText: passwordError,
          trailing: passwordValidating
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : null,
        ),
        if (passwordScore >= 0 && passwordC.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: List.generate(4, (i) {
              final active = i < bars;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i == 3 ? 0 : 4),
                  decoration: BoxDecoration(
                    color: active ? _scoreColor(passwordScore) : _AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Text(
            'Force : ${_scoreLabel(passwordScore)}',
            style: TextStyle(fontSize: 12, color: _scoreColor(passwordScore), fontWeight: FontWeight.w500),
          ),
        ],
        const SizedBox(height: 16),
        _PremiumField(
          label: 'Confirmer le mot de passe *',
          hint: 'Répétez le mot de passe',
          icon: Icons.lock_outline_rounded,
          controller: confirmC,
          isPassword: true,
        ),
        const SizedBox(height: 24),
        const Divider(color: _AppColors.border),
        const SizedBox(height: 16),
        const Text('Vérification email', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _AppColors.textDark)),
        const SizedBox(height: 16),
        SizedBox(
          height: 50,
          child: OutlinedButton.icon(
            onPressed: canResend ? onSendOtp : null,
            icon: Icon(isOtpSent ? Icons.check_circle_outline_rounded : Icons.send_rounded, size: 20),
            label: Text(
              !canResend && resendCountdown > 0
                  ? 'Renvoyer dans ${resendCountdown}s'
                  : (isOtpSent ? 'Code envoyé — Renvoyer' : 'Obtenir le code OTP'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _AppColors.primary,
              side: BorderSide(color: isOtpSent ? _AppColors.success : _AppColors.primary, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        if (isOtpSent) ...[
          const SizedBox(height: 24),
          _PremiumField(
            label: 'Code reçu par email *',
            hint: '000000',
            icon: Icons.confirmation_number_outlined,
            controller: otpC,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ],
      ],
    );
  }
}

class _Step3Activate extends StatelessWidget {
  final TextEditingController thixChatC;
  final bool emailVerified;
  final bool sponsored;
  final VoidCallback onShowQr;

  const _Step3Activate({
    required this.thixChatC,
    required this.emailVerified,
    required this.sponsored,
    required this.onShowQr,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Activation', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _AppColors.primary)),
        const SizedBox(height: 6),
        const Text(
          'Choisissez votre identifiant public. Le parrainage est optionnel et ne remplace pas l'email.',
          style: TextStyle(fontSize: 14, color: _AppColors.textMuted),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: emailVerified ? _AppColors.successBg : const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            emailVerified ? 'Email vérifié' : 'Email non vérifié',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: emailVerified ? _AppColors.success : const Color(0xFF92400E),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _PremiumField(
          label: 'THIX CHAT (pseudo public) *',
          hint: '@pseudo_123',
          icon: Icons.alternate_email_rounded,
          controller: thixChatC,
        ),
        const SizedBox(height: 24),
        const Text('Parrainage (optionnel)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _AppColors.textDark)),
        const SizedBox(height: 8),
        Text(
          sponsored
              ? 'Un parrain accrédité a validé votre demande. Vous pouvez activer.'
              : 'Un pair accrédité peut scanner votre QR. Vous activez ensuite vous-même.',
          style: const TextStyle(fontSize: 13, color: _AppColors.textMuted),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 50,
          child: OutlinedButton.icon(
            onPressed: onShowQr,
            icon: Icon(sponsored ? Icons.verified_rounded : Icons.qr_code_2_rounded, size: 22),
            label: Text(
              sponsored ? 'Parrainage reçu' : 'Afficher mon QR de parrainage',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _AppColors.textDark,
              side: BorderSide(color: sponsored ? _AppColors.success : _AppColors.border, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}

class _Step4Final extends StatelessWidget {
  final String thixId, thixChat, name, email, phone, dob, country, occupation;
  const _Step4Final({
    required this.thixId,
    required this.thixChat,
    required this.name,
    required this.email,
    required this.phone,
    required this.dob,
    required this.country,
    required this.occupation,
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
        Text(
          'Votre compte est actif. Bienvenue sur THIX ID, $name.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: _AppColors.textMuted, height: 1.4),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_AppColors.primary, _AppColors.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: _AppColors.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CARTE D'IDENTITÉ THIX', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
              const SizedBox(height: 24),
              const Text('THIX ID OFFICIEL', style: TextStyle(color: _AppColors.accentLight, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      thixId.isEmpty ? 'Génération…' : thixId,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (thixId.isNotEmpty)
                    IconButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: thixId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('THIX ID copié !'), backgroundColor: _AppColors.success),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('THIX CHAT', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(thixChat, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Text('Résumé', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _AppColors.textDark)),
        const SizedBox(height: 16),
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
              ],
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
          Expanded(
            flex: 3,
            child: Text(value, textAlign: TextAlign.right, style: const TextStyle(color: _AppColors.textDark, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// QR — nonce serveur uniquement, écoute status == sponsored (pas active)
// ============================================================================
class SecureQrParrainageDialog extends StatefulWidget {
  final VoidCallback onSponsored;
  const SecureQrParrainageDialog({super.key, required this.onSponsored});

  @override
  State<SecureQrParrainageDialog> createState() => _SecureQrParrainageDialogState();
}

class _SecureQrParrainageDialogState extends State<SecureQrParrainageDialog> {
  late final Future<String> _tokenFuture;
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _tokenFuture = _issue();
  }

  Future<String> _issue() async {
    final raw = await Supabase.instance.client.rpc('generate_qr_activation_token');
    final token = raw.toString();
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) {
      _sub = Supabase.instance.client
          .from('profiles')
          .stream(primaryKey: ['id'])
          .eq('id', uid)
          .listen((rows) {
        if (_done || rows.isEmpty) return;
        if (rows.first['account_status'] == 'sponsored') {
          _done = true;
          widget.onSponsored();
          if (mounted) Navigator.pop(context);
        }
      });
    }
    return token;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: FutureBuilder<String>(
          future: _tokenFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator(color: _AppColors.primary)),
              );
            }
            if (snapshot.hasError) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, color: _AppColors.danger, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Impossible de générer le QR. Vérifiez que votre email est confirmé.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
                ],
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.qr_code_scanner_rounded, color: ThixPolicy.primary, size: 40),
                const SizedBox(height: 16),
                Text(
                  'QR de parrainage',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ThixPolicy.primary),
                ),
                const SizedBox(height: 8),
                const Text(
                  'À faire scanner uniquement par un pair accrédité. Ne photographiez pas ce code.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: _AppColors.textMuted),
                ),
                const SizedBox(height: 24),
                QrImageView(data: snapshot.data!, version: QrVersions.auto, size: 200, backgroundColor: Colors.white),
                const SizedBox(height: 16),
                const Text('Valide 15 minutes', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fermer'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
