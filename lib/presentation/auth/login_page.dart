import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/presentation/auth/personal_registration_page.dart'; // Pour PasswordPolicy

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _identifierC = TextEditingController();
  final _passwordC = TextEditingController();
  bool _rememberMe = true;

  int _failedAttempts = 0;
  int _lockoutSecondsLeft = 0;
  Timer? _lockoutTimer;
  static const int _lockoutThreshold = 5;
  static const int _lockoutDuration = 30;

  int _resetCooldown = 0;
  Timer? _resetCooldownTimer;
  static const int _resetCooldownDuration = 45;

  @override
  void dispose() {
    _identifierC.dispose();
    _passwordC.dispose();
    _lockoutTimer?.cancel();
    _resetCooldownTimer?.cancel();
    super.dispose();
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: isError ? ThixPolicy.danger : ThixPolicy.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _userFacingError(Object e) {
    if (kDebugMode) debugPrint('[Login] erreur brute: $e');
    final msg = e.toString().toLowerCase();
    
    if (msg.contains('account_suspended') || msg.contains('suspended')) {
      return 'Votre compte a été suspendu. Contactez le support.';
    }
    if (msg.contains('account_not_active') || msg.contains('not active')) {
      return 'Votre compte n\'est pas encore actif. Finalisez votre inscription.';
    }
    if (msg.contains('aucun compte trouvé')) {
      return 'Aucun compte trouvé avec ce numéro de téléphone.';
    }
    if (msg.contains('mfa_required') || msg.contains('two_fa')) {
      return 'Authentification à deux facteurs requise.';
    }
    if (e is AuthException) {
      if (msg.contains('rate limit') || msg.contains('too many')) {
        return 'Trop de tentatives. Merci de patienter quelques instants.';
      }
      if (msg.contains('network') || msg.contains('connection')) {
        return 'Problème de connexion. Vérifiez votre réseau et réessayez.';
      }
      return 'Identifiant ou mot de passe incorrect.';
    }
    return 'Identifiant ou mot de passe incorrect.';
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    setState(() => _lockoutSecondsLeft = _lockoutDuration);
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_lockoutSecondsLeft <= 1) {
        timer.cancel();
        setState(() {
          _lockoutSecondsLeft = 0;
          _failedAttempts = 0;
        });
      } else {
        setState(() => _lockoutSecondsLeft -= 1);
      }
    });
  }

  // ✅ NOUVEAU : Logger les tentatives de connexion
  Future<void> _logLoginAttempt({
    required String identifier,
    required bool success,
    String? failureReason,
  }) async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;

      await Supabase.instance.client.from('security_events').insert({
        'user_id': uid,
        'type': success ? 'login_success' : 'login_failed',
        'label': success ? 'Connexion réussie' : 'Échec de connexion',
        'metadata': {
          'identifier': identifier,
          'failure_reason': failureReason,
          'timestamp': DateTime.now().toIso8601String(),
        },
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[Login] Failed to log attempt: $e');
    }
  }

  Future<void> _signIn() async {
    if (_lockoutSecondsLeft > 0) return;

    final identifier = _identifierC.text.trim();
    final password = _passwordC.text;
    
    if (identifier.isEmpty || password.isEmpty) {
      _snack('Veuillez saisir votre identifiant et mot de passe.', isError: true);
      return;
    }

    final authNotifier = ref.read(authControllerProvider.notifier);

    try {
      String finalIdentifier = identifier;

      // ✅ CORRECTION : Utiliser RPC serveur pour résolution téléphone→email
      if (_looksLikePhone(identifier) && !identifier.contains('@')) {
        try {
          final response = await Supabase.instance.client.rpc(
            'resolve_phone_to_email',
            params: {'p_phone': identifier},
          );
          if (response is String && response.isNotEmpty) {
            finalIdentifier = response;
          } else {
            throw Exception('Aucun compte trouvé avec ce numéro de téléphone.');
          }
        } catch (e) {
          await _logLoginAttempt(
            identifier: identifier,
            success: false,
            failureReason: 'phone_resolution_failed',
          );
          rethrow;
        }
      }

      // Connexion standard
      await authNotifier.signIn(
        identifier: finalIdentifier,
        password: password,
        rememberMe: _rememberMe,
      );

      if (!mounted) return;
      
      final user = ref.read(authControllerProvider).value;
      if (user == null) {
        throw Exception('Utilisateur non trouvé après connexion.');
      }

      // ✅ CORRECTION CRITIQUE : Vérifier le statut du compte
      final accountStatus = user.registrationStatus?.toLowerCase() ?? '';
      final statusField = user.registrationStatus?.toLowerCase() ?? '';

      
      if (statusField == 'suspended' || accountStatus == 'suspended') {
        await _logLoginAttempt(
          identifier: finalIdentifier,
          success: false,
          failureReason: 'account_suspended',
        );
        throw Exception('Votre compte a été suspendu.');
      }

      if (accountStatus != 'active' && statusField != 'active') {
        await _logLoginAttempt(
          identifier: finalIdentifier,
          success: false,
          failureReason: 'account_not_active',
        );
        // Rediriger vers l'inscription pour finaliser
        context.go('${AppRoutes.personalReg}?step=3');
        _snack('Finalisez votre inscription pour accéder à votre compte.', isError: true);
        return;
      }

      // ✅ CORRECTION : Vérifier MFA si activé
      if (user.twoFaEnabled == true) {
        await _logLoginAttempt(
          identifier: finalIdentifier,
          success: false,
          failureReason: 'mfa_required',
        );
        _snack('L\'authentification à deux facteurs n\'est pas encore supportée.', isError: true);
        // TODO: Implémenter le flux MFA
        return;
      }

      // ✅ Logger le succès
      await _logLoginAttempt(
        identifier: finalIdentifier,
        success: true,
      );

      _failedAttempts = 0;
      final target = user.accountType == AccountType.enterprise
          ? AppRoutes.enterpriseDashboard
          : AppRoutes.userDashboard;
      context.go(target);
      
    } catch (e) {
      debugPrint('Login failed: $e');
      if (!mounted) return;
      
      await _logLoginAttempt(
        identifier: _identifierC.text.trim(),
        success: false,
        failureReason: e.toString(),
      );
      
      _failedAttempts += 1;
      if (_failedAttempts >= _lockoutThreshold) {
        _startLockoutTimer();
        _snack('Trop de tentatives échouées. Réessayez dans ${_lockoutDuration}s.', isError: true);
      } else {
        _snack(_userFacingError(e), isError: true);
      }
    }
  }

  bool _looksLikePhone(String s) => RegExp(r'^\+?[0-9][0-9\s\-]{7,}$').hasMatch(s.trim());
  bool _looksLikeEmail(String s) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s.trim());

  void _startResetCooldown() {
    _resetCooldownTimer?.cancel();
    setState(() => _resetCooldown = _resetCooldownDuration);
    _resetCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_resetCooldown <= 1) { timer.cancel(); setState(() => _resetCooldown = 0); } 
      else { setState(() => _resetCooldown -= 1); }
    });
  }

  Future<bool> _sendPasswordReset(String email) async {
    try { 
      await Supabase.instance.client.auth.resetPasswordForEmail(email); 
      // ✅ Logger la demande de reset
      await _logLoginAttempt(
        identifier: email,
        success: true,
        failureReason: 'password_reset_requested',
      );
    } catch (e) { 
      debugPrint('Password reset failed: $e');
    }
    _startResetCooldown();
    return true;
  }

  void _openForgotPasswordDialog() {
    final prefill = _looksLikeEmail(_identifierC.text) ? _identifierC.text.trim() : '';
    final emailC = TextEditingController(text: prefill);
    final otpC = TextEditingController();
    final newPasswordC = TextEditingController();
    
    bool isSending = false;
    bool isOtpSent = false;
    bool isObscured = true;
    String? passwordError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canSend = !isSending && _resetCooldown == 0;
            
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s24),
              child: Container(
                padding: const EdgeInsets.all(ThixPolicy.s28),
                decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(ThixPolicy.cardRadius)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: ThixPolicy.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: Icon(
                            isOtpSent ? Icons.vpn_key_rounded : Icons.lock_reset_rounded, 
                            color: ThixPolicy.primary
                          ),
                        ),
                        const SizedBox(width: ThixPolicy.s16),
                        Expanded(
                          child: Text(
                            isOtpSent ? 'Nouveau mot de passe' : 'Mot de passe oublié', 
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontSize: 18, color: ThixPolicy.textMain)
                          )
                        ),
                      ],
                    ),
                    const SizedBox(height: ThixPolicy.s16),
                    
                    Text(
                      isOtpSent 
                          ? 'Un code à 6 chiffres a été envoyé à ${emailC.text}. Saisissez-le ci-dessous avec votre nouveau mot de passe.'
                          : 'Entrez l\'email associé à votre compte. Si un compte existe, un code de réinitialisation vous sera envoyé.', 
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ThixPolicy.textSecondary, fontSize: 13, height: 1.4)
                    ),
                    const SizedBox(height: ThixPolicy.s24),
                    
                    if (!isOtpSent) ...[
                      TextFormField(
                        controller: emailC, keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(fontSize: 14, color: ThixPolicy.textMain, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: 'votre@email.com',
                          hintStyle: const TextStyle(color: ThixPolicy.textSecondary),
                          filled: true, fillColor: ThixPolicy.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius), borderSide: const BorderSide(color: ThixPolicy.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius), borderSide: const BorderSide(color: ThixPolicy.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius), borderSide: const BorderSide(color: ThixPolicy.primary, width: 1.5)),
                        ),
                      ),
                    ] 
                    else ...[
                      TextFormField(
                        controller: otpC, keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 14, color: ThixPolicy.textMain, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          labelText: 'Code de vérification (OTP)',
                          hintText: '000000',
                          filled: true, fillColor: ThixPolicy.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius), borderSide: const BorderSide(color: ThixPolicy.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius), borderSide: const BorderSide(color: ThixPolicy.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius), borderSide: const BorderSide(color: ThixPolicy.primary, width: 1.5)),
                        ),
                      ),
                      const SizedBox(height: ThixPolicy.s16),
                      TextFormField(
                        controller: newPasswordC, obscureText: isObscured,
                        style: const TextStyle(fontSize: 14, color: ThixPolicy.textMain, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          labelText: 'Nouveau mot de passe',
                          hintText: 'Min. 8 caractères',
                          errorText: passwordError,
                          filled: true, fillColor: ThixPolicy.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius), borderSide: const BorderSide(color: ThixPolicy.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius), borderSide: const BorderSide(color: ThixPolicy.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius), borderSide: const BorderSide(color: ThixPolicy.primary, width: 1.5)),
                          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius), borderSide: const BorderSide(color: ThixPolicy.danger, width: 1.5)),
                          suffixIcon: IconButton(
                            splashRadius: 20,
                            icon: Icon(isObscured ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: ThixPolicy.textSecondary, size: 20),
                            onPressed: () => setDialogState(() => isObscured = !isObscured),
                          )
                        ),
                      ),
                    ],

                    const SizedBox(height: ThixPolicy.s28),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: isSending ? null : () => Navigator.of(dialogContext).pop(), 
                            child: const Text('Annuler', style: TextStyle(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600))
                          )
                        ),
                        const SizedBox(width: ThixPolicy.s12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSending ? null : () async {
                              if (!isOtpSent) {
                                if (!canSend) return;
                                final email = emailC.text.trim();
                                if (!_looksLikeEmail(email)) { _snack('Email invalide.', isError: true); return; }
                                
                                setDialogState(() => isSending = true);
                                await _sendPasswordReset(email);
                                
                                if (dialogContext.mounted) {
                                  setDialogState(() {
                                    isSending = false;
                                    isOtpSent = true;
                                  });
                                }
                              } else {
                                final otp = otpC.text.trim();
                                final newPass = newPasswordC.text;
                                
                                if (otp.isEmpty) { _snack('Saisissez le code OTP reçu.', isError: true); return; }
                                
                                // ✅ CORRECTION : Valider avec politique NIST
                                final passError = await PasswordPolicy.validate(
                                  newPass,
                                  email: emailC.text.trim(),
                                  fullName: '',
                                  phone: '',
                                );
                                
                                if (passError != null) {
                                  setDialogState(() => passwordError = passError);
                                  return;
                                }
                                
                                setDialogState(() => isSending = true);
                                
                                try {
                                  final res = await Supabase.instance.client.auth.verifyOTP(
                                    email: emailC.text.trim(),
                                    token: otp,
                                    type: OtpType.recovery,
                                  );
                                  
                                  if (res.user != null) {
                                    await Supabase.instance.client.auth.updateUser(
                                      UserAttributes(password: newPass),
                                    );
                                    
                                    // ✅ Logger le succès
                                    await _logLoginAttempt(
                                      identifier: emailC.text.trim(),
                                      success: true,
                                      failureReason: 'password_reset_success',
                                    );
                                    
                                    if (dialogContext.mounted) {
                                      Navigator.of(dialogContext).pop();
                                      _snack('Mot de passe mis à jour ! Vous pouvez vous connecter.');
                                    }
                                  }
                                } catch (e) {
                                  _snack('Code invalide ou expiré.', isError: true);
                                  setDialogState(() => isSending = false);
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ThixPolicy.primary, 
                              foregroundColor: ThixPolicy.onBrand, 
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd))
                            ),
                            child: Text(
                              isSending 
                                  ? 'Patientez...' 
                                  : (isOtpSent 
                                      ? 'Confirmer' 
                                      : (!canSend && _resetCooldown > 0 ? 'Attendre ${_resetCooldown}s' : 'Envoyer')),
                              style: const TextStyle(fontWeight: FontWeight.w600)
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Positioned(
              top: 0, left: 0, right: 0, height: 260,
              child: Container(
                padding: const EdgeInsets.only(top: 60),
                decoration: const BoxDecoration(
                  gradient: ThixPolicy.brandGradient,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/thix_id_logo.png',
                      height: 55,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Text(
                          'THIX CENTRAL',
                          style: TextStyle(
                            color: ThixPolicy.onBrand,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            letterSpacing: 1.0,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            Positioned.fill(
              top: 200,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s24, vertical: 0),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: ThixPolicy.card,
                        borderRadius: BorderRadius.circular(ThixPolicy.rXl),
                        boxShadow: ThixPolicy.shadowCard(),
                      ),
                      padding: const EdgeInsets.all(ThixPolicy.s28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Connexion', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontSize: 20, color: ThixPolicy.textMain)),
                          const SizedBox(height: 6),
                          Text('Accédez à votre espace sécurisé', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ThixPolicy.textSecondary, fontSize: 13)),
                          const SizedBox(height: ThixPolicy.s28),
                          
                          _SecureInput(
                            key: const ValueKey('identifier'), 
                            label: 'Email, Mobile ou THIX ID', 
                            hint: 'Ex: votre@email.com ou +243...', 
                            icon: Icons.badge_outlined, 
                            isPassword: false, 
                            type: TextInputType.text, 
                            controller: _identifierC, 
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: ThixPolicy.s16),
                          _SecureInput(
                            key: const ValueKey('password'), 
                            label: 'Mot de passe', 
                            hint: '••••••••••••', 
                            icon: Icons.lock_outline_rounded, 
                            isPassword: true, 
                            type: TextInputType.text, 
                            controller: _passwordC, 
                            textInputAction: TextInputAction.done,
                          ),
                          
                          const SizedBox(height: ThixPolicy.s12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: isLoading ? null : () => setState(() => _rememberMe = !_rememberMe),
                                child: Row(
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 200), width: 18, height: 18,
                                      decoration: BoxDecoration(color: _rememberMe ? ThixPolicy.primary : ThixPolicy.card, borderRadius: BorderRadius.circular(6), border: Border.all(color: _rememberMe ? ThixPolicy.primary : ThixPolicy.border, width: 1.5)),
                                      alignment: Alignment.center,
                                      child: Icon(Icons.check_rounded, size: 14, color: _rememberMe ? ThixPolicy.onBrand : Colors.transparent),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('Rester connecté', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ThixPolicy.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: _openForgotPasswordDialog,
                                child: Text('Oublié ?', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: ThixPolicy.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: ThixPolicy.s32),
                          
                          ElevatedButton(
                            onPressed: (isLoading || _lockoutSecondsLeft > 0) ? null : _signIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ThixPolicy.primary,
                              foregroundColor: ThixPolicy.onBrand,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 4,
                              shadowColor: ThixPolicy.primary.withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isLoading) ...const [
                                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
                                  SizedBox(width: 12),
                                ],
                                Text(
                                  _lockoutSecondsLeft > 0 ? 'RÉESSAYER DANS ${_lockoutSecondsLeft}S' : (isLoading ? 'VÉRIFICATION…' : 'SE CONNECTER'),
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.5),
                                ),
                                if (_lockoutSecondsLeft == 0 && !isLoading) ...const [
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_rounded, size: 20),
                                ],
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: ThixPolicy.s24),
                          
                          Row(
                            children: [
                              const Expanded(child: Divider(color: ThixPolicy.border)),
                              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('BIOMÉTRIE', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 1.0))),
                              const Expanded(child: Divider(color: ThixPolicy.border)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              _SocialAuth(icon: Icons.face_rounded, label: 'Face ID'),
                              SizedBox(width: 16),
                              _SocialAuth(icon: Icons.fingerprint_rounded, label: 'Touch ID'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: ThixPolicy.s24),
                    
                    Container(
                      padding: const EdgeInsets.all(ThixPolicy.s16),
                      decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: ThixPolicy.success.withValues(alpha: 0.3)), boxShadow: [BoxShadow(color: ThixPolicy.success.withValues(alpha: 0.05), blurRadius: 10)]),
                      child: Row(
                        children: [
                          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: ThixPolicy.success.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.verified_user_rounded, color: ThixPolicy.success, size: 20)),
                          const SizedBox(width: ThixPolicy.s16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Standard de Sécurité Étatique', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: ThixPolicy.textMain, fontWeight: FontWeight.w700, fontSize: 13)),
                                const SizedBox(height: 4),
                                Text('Chiffrement local de bout en bout', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ThixPolicy.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: ThixPolicy.s28),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Nouvel utilisateur ?', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ThixPolicy.textSecondary, fontSize: 14)),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => context.push(AppRoutes.personalReg),
                          child: Text('Créer un compte', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ThixPolicy.primary, fontWeight: FontWeight.w800, fontSize: 14)),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: ThixPolicy.s24),
                    
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(24), border: Border.all(color: ThixPolicy.border)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          _LangChip(label: 'FR', active: true),
                          _LangChip(label: 'EN'),
                          _LangChip(label: 'SW'),
                          _LangChip(label: 'LN'),
                        ],
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
}

class _SecureInput extends StatefulWidget {
  final String label;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final TextInputType type;
  final TextEditingController controller;
  final TextInputAction textInputAction;
  
  const _SecureInput({super.key, required this.label, required this.hint, required this.icon, required this.isPassword, required this.type, required this.controller, required this.textInputAction});
  
  @override
  State<_SecureInput> createState() => _SecureInputState();
}

class _SecureInputState extends State<_SecureInput> {
  late bool _obscured = widget.isPassword;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ThixPolicy.textMain)),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller, 
          obscureText: _obscured, 
          keyboardType: widget.type, 
          textInputAction: widget.textInputAction, 
          style: const TextStyle(fontSize: 14, color: ThixPolicy.textMain, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: widget.hint, 
            hintStyle: const TextStyle(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w400),
            prefixIcon: Icon(widget.icon, size: 20, color: ThixPolicy.textSecondary),
            suffixIcon: widget.isPassword 
                ? IconButton(splashRadius: 20, icon: Icon(_obscured ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20, color: ThixPolicy.textSecondary), onPressed: () => setState(() => _obscured = !_obscured)) 
                : null,
            filled: true,
            fillColor: ThixPolicy.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius), borderSide: const BorderSide(color: ThixPolicy.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius), borderSide: const BorderSide(color: ThixPolicy.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.inputRadius), borderSide: const BorderSide(color: ThixPolicy.primary, width: 1.5)),
          ),
        ),
      ],
    );
  }
}

class _SocialAuth extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SocialAuth({required this.icon, required this.label});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76, height: 60, 
      decoration: BoxDecoration(color: ThixPolicy.surface, borderRadius: BorderRadius.circular(ThixPolicy.rSm), border: Border.all(color: ThixPolicy.border)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, 
        children: [
          Icon(icon, color: ThixPolicy.textMain, size: 22), 
          const SizedBox(height: 4), 
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: ThixPolicy.textSecondary, fontSize: 10, fontWeight: FontWeight.w600))
        ]
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  final String label;
  final bool active;
  const _LangChip({required this.label, this.active = false});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: active ? ThixPolicy.primary : Colors.transparent, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: active ? ThixPolicy.onBrand : ThixPolicy.textSecondary, fontWeight: active ? FontWeight.w700 : FontWeight.w600, fontSize: 11)),
    );
  }
}
