// lib/presentation/auth/login_page.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/presentation/auth/personal_registration_page.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const int _kLockoutThreshold = 5;
const int _kLockoutDuration = 30;
const int _kResetCooldownDuration = 45;
const int _kMaxEmailLength = 254;
const int _kMaxPasswordLength = 128;
const int _kMaxOtpLength = 6;
const int _kMaxIdentifierLength = 100;

// ============================================================================
// VALIDATORS
// ============================================================================
class _LoginValidators {
  _LoginValidators._();

  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static bool looksLikePhone(String s) {
    return RegExp(r'^\+?[0-9][0-9\s\-]{7,}$').hasMatch(sanitize(s, maxLength: 50));
  }

  static bool looksLikeEmail(String s) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(sanitize(s, maxLength: _kMaxEmailLength));
  }

  static String userFacingError(Object e, AppLocalizations l10n) {
    final msg = e.toString().toLowerCase();

    if (msg.contains('account_suspended') || msg.contains('suspended')) {
      return l10n.t('login_error_suspended');
    }
    if (msg.contains('account_not_active') || msg.contains('not active')) {
      return l10n.t('login_error_not_active');
    }
    if (msg.contains('aucun compte trouvé') || msg.contains('phone_resolution_failed')) {
      return l10n.t('login_error_no_account');
    }
    if (msg.contains('mfa_required') || msg.contains('two_fa')) {
      return l10n.t('login_error_mfa_required');
    }
    if (e is AuthException) {
      if (msg.contains('rate limit') || msg.contains('too many')) {
        return l10n.t('login_error_rate_limit');
      }
      if (msg.contains('network') || msg.contains('connection')) {
        return l10n.t('login_error_network');
      }
    }
    return l10n.t('login_error_invalid_credentials');
  }
}

// ============================================================================
// LOGIN PAGE
// ============================================================================

/// Page de connexion utilisateur.
///
/// Fonctionnalités :
/// - Connexion par email, téléphone ou THIX ID
/// - Protection anti-bruteforce (lockout après 5 tentatives)
/// - Récupération de mot de passe avec OTP
/// - Vérification statut compte (suspended, not active)
/// - Support biométrie (Face ID, Touch ID)
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

  int _resetCooldown = 0;
  Timer? _resetCooldownTimer;

  @override
  void dispose() {
    _identifierC.dispose();
    _passwordC.dispose();
    _lockoutTimer?.cancel();
    _resetCooldownTimer?.cancel();
    debugPrint('[Login] 👋 Page disposed');
    super.dispose();
  }

  // ── FEEDBACK HELPERS ──────────────────────────────────────────────────────

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w500))),
        ]),
        backgroundColor: ThixPolicy.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w500))),
        ]),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w500))),
        ]),
        backgroundColor: ThixPolicy.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ── LOCKOUT TIMER ─────────────────────────────────────────────────────────

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    setState(() => _lockoutSecondsLeft = _kLockoutDuration);
    debugPrint('[Login] 🔒 Lockout started: ${_kLockoutDuration}s');

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
        debugPrint('[Login] ✓ Lockout ended');
      } else {
        setState(() => _lockoutSecondsLeft -= 1);
      }
    });
  }

  // ── RESET COOLDOWN TIMER ──────────────────────────────────────────────────

  void _startResetCooldown() {
    _resetCooldownTimer?.cancel();
    setState(() => _resetCooldown = _kResetCooldownDuration);
    debugPrint('[Login] ⏱️ Reset cooldown started: ${_kResetCooldownDuration}s');

    _resetCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resetCooldown <= 1) {
        timer.cancel();
        setState(() => _resetCooldown = 0);
        debugPrint('[Login] ✓ Reset cooldown ended');
      } else {
        setState(() => _resetCooldown -= 1);
      }
    });
  }

  // ── LOGGING ───────────────────────────────────────────────────────────────

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
          'identifier': _LoginValidators.sanitize(identifier, maxLength: _kMaxIdentifierLength),
          'failure_reason': failureReason,
          'timestamp': DateTime.now().toIso8601String(),
        },
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[Login] ⚠️ Failed to log attempt: $e');
    }
  }

  // ── SIGN IN ───────────────────────────────────────────────────────────────

  Future<void> _signIn() async {
    final l10n = AppLocalizations.of(context);

    if (_lockoutSecondsLeft > 0) {
      debugPrint('[Login] ⚠️ Sign in blocked: lockout active');
      return;
    }

    final identifier = _LoginValidators.sanitize(_identifierC.text.trim(), maxLength: _kMaxIdentifierLength);
    final password = _LoginValidators.sanitize(_passwordC.text, maxLength: _kMaxPasswordLength);

    if (identifier.isEmpty || password.isEmpty) {
      _showError(l10n.t('login_error_empty_fields'));
      return;
    }

    HapticFeedback.mediumImpact();
    debugPrint('[Login] 🔐 Sign in attempt for: ${identifier.substring(0, identifier.length > 20 ? 20 : identifier.length)}...');

    final authNotifier = ref.read(authControllerProvider.notifier);

    try {
      String finalIdentifier = identifier;

      // Résolution téléphone → email via RPC
      if (_LoginValidators.looksLikePhone(identifier) && !identifier.contains('@')) {
        try {
          final response = await Supabase.instance.client.rpc(
            'resolve_phone_to_email',
            params: {'p_phone': identifier},
          );
          if (response is String && response.isNotEmpty) {
            finalIdentifier = response;
            debugPrint('[Login] ✓ Phone resolved to email');
          } else {
            throw Exception('phone_resolution_failed');
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
        throw Exception('user_not_found_after_login');
      }

      // Vérification statut compte
      final accountStatus = user.registrationStatus?.toLowerCase() ?? '';

      if (accountStatus == 'suspended') {
        await _logLoginAttempt(
          identifier: finalIdentifier,
          success: false,
          failureReason: 'account_suspended',
        );
        throw Exception('account_suspended');
      }

      if (accountStatus != 'active') {
        await _logLoginAttempt(
          identifier: finalIdentifier,
          success: false,
          failureReason: 'account_not_active',
        );
        context.go('${AppRoutes.personalReg}?step=3');
        _showError(l10n.t('login_error_finalize_registration'));
        return;
      }

      // Vérification MFA
      if (user.twoFaEnabled == true) {
        await _logLoginAttempt(
          identifier: finalIdentifier,
          success: false,
          failureReason: 'mfa_required',
        );
        _showError(l10n.t('login_error_mfa_not_supported'));
        return;
      }

      // Succès
      await _logLoginAttempt(
        identifier: finalIdentifier,
        success: true,
      );

      _failedAttempts = 0;
      final target = user.accountType == AccountType.enterprise
          ? AppRoutes.enterpriseDashboard
          : AppRoutes.userDashboard;

      debugPrint('[Login] ✓ Sign in successful, redirecting to: $target');
      context.go(target);
    } catch (e) {
      if (kDebugMode) debugPrint('[Login] ❌ Sign in error: $e');
      if (!mounted) return;

      await _logLoginAttempt(
        identifier: _identifierC.text.trim(),
        success: false,
        failureReason: e.toString(),
      );

      _failedAttempts += 1;
      if (_failedAttempts >= _kLockoutThreshold) {
        _startLockoutTimer();
        _showError(l10n.t('login_error_too_many_attempts', args: ['$_kLockoutDuration']));
      } else {
        _showError(_LoginValidators.userFacingError(e, l10n));
      }
    }
  }

  // ── PASSWORD RESET ────────────────────────────────────────────────────────

  Future<bool> _sendPasswordReset(String email) async {
    final l10n = AppLocalizations.of(context);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      await _logLoginAttempt(
        identifier: email,
        success: true,
        failureReason: 'password_reset_requested',
      );
      debugPrint('[Login] ✓ Password reset email sent to: $email');
      _showInfo(l10n.t('login_reset_email_sent'));
    } catch (e) {
      debugPrint('[Login] ❌ Password reset failed: $e');
      _showError(l10n.t('login_reset_email_failed'));
    }
    _startResetCooldown();
    return true;
  }

  void _openForgotPasswordDialog() {
    HapticFeedback.selectionClick();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _ForgotPasswordDialog(
        prefillEmail: _LoginValidators.looksLikeEmail(_identifierC.text) ? _identifierC.text.trim() : '',
        onSendReset: _sendPasswordReset,
        resetCooldown: _resetCooldown,
        logAttempt: _logLoginAttempt,
      ),
    );
  }

  // ── BIOMETRIC AUTH ────────────────────────────────────────────────────────

  void _handleBiometric(String type) {
    final l10n = AppLocalizations.of(context);
    HapticFeedback.mediumImpact();
    debugPrint('[Login] 🔓 Biometric auth requested: $type');
    _showInfo(l10n.t('login_biometric_not_supported'));
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            // ── Header avec gradient ──
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 260,
              child: RepaintBoundary(
                child: Container(
                  padding: const EdgeInsets.only(top: 60),
                  decoration: const BoxDecoration(gradient: ThixPolicy.brandGradient),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/thix_id_logo.png',
                        height: 55,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) {
                          return Semantics(
                            label: 'THIX CENTRAL',
                            child: const Text(
                              'THIX CENTRAL',
                              style: TextStyle(
                                color: ThixPolicy.onBrand,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                                letterSpacing: 1.0,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Contenu principal ──
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
                          Text(
                            l10n.t('login_title'),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                  color: ThixPolicy.textMain,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.t('login_subtitle'),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: ThixPolicy.textSecondary,
                                  fontSize: 13,
                                ),
                          ),
                          const SizedBox(height: ThixPolicy.s28),

                          // ── Champ identifiant ──
                          Semantics(
                            label: l10n.t('login_identifier_label'),
                            textField: true,
                            child: _SecureInput(
                              key: const ValueKey('identifier'),
                              label: l10n.t('login_identifier_label'),
                              hint: l10n.t('login_identifier_hint'),
                              icon: Icons.badge_outlined,
                              isPassword: false,
                              type: TextInputType.text,
                              controller: _identifierC,
                              textInputAction: TextInputAction.next,
                              maxLength: _kMaxIdentifierLength,
                            ),
                          ),
                          const SizedBox(height: ThixPolicy.s16),

                          // ── Champ mot de passe ──
                          Semantics(
                            label: l10n.t('login_password_label'),
                            textField: true,
                            child: _SecureInput(
                              key: const ValueKey('password'),
                              label: l10n.t('login_password_label'),
                              hint: l10n.t('login_password_hint'),
                              icon: Icons.lock_outline_rounded,
                              isPassword: true,
                              type: TextInputType.text,
                              controller: _passwordC,
                              textInputAction: TextInputAction.done,
                              maxLength: _kMaxPasswordLength,
                              onSubmitted: (_) => _signIn(),
                            ),
                          ),

                          const SizedBox(height: ThixPolicy.s12),

                          // ── Rester connecté + Mot de passe oublié ──
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Semantics(
                                button: true,
                                label: l10n.t('login_remember_me'),
                                checked: _rememberMe,
                                child: GestureDetector(
                                  onTap: isLoading
                                      ? null
                                      : () {
                                          HapticFeedback.selectionClick();
                                          setState(() => _rememberMe = !_rememberMe);
                                        },
                                  child: Row(
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        width: 18,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          color: _rememberMe ? ThixPolicy.primary : ThixPolicy.card,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: _rememberMe ? ThixPolicy.primary : ThixPolicy.border,
                                            width: 1.5,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Icon(
                                          Icons.check_rounded,
                                          size: 14,
                                          color: _rememberMe ? ThixPolicy.onBrand : Colors.transparent,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        l10n.t('login_remember_me'),
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: ThixPolicy.textSecondary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Semantics(
                                button: true,
                                label: l10n.t('login_forgot_password'),
                                child: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    _openForgotPasswordDialog();
                                  },
                                  child: Text(
                                    l10n.t('login_forgot_password'),
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                          color: ThixPolicy.primary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: ThixPolicy.s32),

                          // ── Bouton connexion ──
                          Semantics(
                            button: true,
                            label: l10n.t('login_button'),
                            enabled: !isLoading && _lockoutSecondsLeft == 0,
                            child: ElevatedButton(
                              onPressed: (isLoading || _lockoutSecondsLeft > 0) ? null : _signIn,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ThixPolicy.primary,
                                foregroundColor: ThixPolicy.onBrand,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                elevation: 4,
                                shadowColor: ThixPolicy.primary.withOpacity(0.4),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (isLoading) ...[
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  Text(
                                    _lockoutSecondsLeft > 0
                                        ? l10n.t('login_retry_in', args: ['$_lockoutSecondsLeft'])
                                        : (isLoading ? l10n.t('login_verifying') : l10n.t('login_button')),
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.5),
                                  ),
                                  if (_lockoutSecondsLeft == 0 && !isLoading) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_forward_rounded, size: 20),
                                  ],
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: ThixPolicy.s24),

                          // ── Séparateur biométrie ──
                          Row(
                            children: [
                              const Expanded(child: Divider(color: ThixPolicy.border)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  l10n.t('login_biometric'),
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: ThixPolicy.textSecondary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 10,
                                        letterSpacing: 1.0,
                                      ),
                                ),
                              ),
                              const Expanded(child: Divider(color: ThixPolicy.border)),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // ── Boutons biométrie ──
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Semantics(
                                button: true,
                                label: 'Face ID',
                                child: _SocialAuth(
                                  icon: Icons.face_rounded,
                                  label: 'Face ID',
                                  onTap: () => _handleBiometric('face_id'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Semantics(
                                button: true,
                                label: 'Touch ID',
                                child: _SocialAuth(
                                  icon: Icons.fingerprint_rounded,
                                  label: 'Touch ID',
                                  onTap: () => _handleBiometric('touch_id'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: ThixPolicy.s24),

                    // ── Bannière sécurité ──
                    RepaintBoundary(
                      child: Container(
                        padding: const EdgeInsets.all(ThixPolicy.s16),
                        decoration: BoxDecoration(
                          color: ThixPolicy.card,
                          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                          border: Border.all(color: ThixPolicy.success.withOpacity(0.3)),
                          boxShadow: [
                            BoxShadow(
                              color: ThixPolicy.success.withOpacity(0.05),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: ThixPolicy.success.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.verified_user_rounded, color: ThixPolicy.success, size: 20),
                            ),
                            const SizedBox(width: ThixPolicy.s16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.t('login_security_title'),
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                          color: ThixPolicy.textMain,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    l10n.t('login_security_subtitle'),
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: ThixPolicy.textSecondary,
                                          fontSize: 12,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: ThixPolicy.s28),

                    // ── Lien inscription ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          l10n.t('login_new_user'),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: ThixPolicy.textSecondary,
                                fontSize: 14,
                              ),
                        ),
                        const SizedBox(width: 6),
                        Semantics(
                          button: true,
                          label: l10n.t('login_create_account'),
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              context.push(AppRoutes.personalReg);
                            },
                            child: Text(
                              l10n.t('login_create_account'),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: ThixPolicy.primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: ThixPolicy.s24),

                    // ── Sélecteur langue ──
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: ThixPolicy.card,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: ThixPolicy.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _LangChip(label: 'FR', active: true, onTap: () {}),
                          _LangChip(label: 'EN', onTap: () {}),
                          _LangChip(label: 'SW', onTap: () {}),
                          _LangChip(label: 'LN', onTap: () {}),
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

// ============================================================================
// SECURE INPUT
// ============================================================================

class _SecureInput extends StatefulWidget {
  final String label;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final TextInputType type;
  final TextEditingController controller;
  final TextInputAction textInputAction;
  final int? maxLength;
  final ValueChanged<String>? onSubmitted;

  const _SecureInput({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.isPassword,
    required this.type,
    required this.controller,
    required this.textInputAction,
    this.maxLength,
    this.onSubmitted,
  });

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
        Text(
          widget.label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ThixPolicy.textMain),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscured,
          keyboardType: widget.type,
          textInputAction: widget.textInputAction,
          maxLength: widget.maxLength,
          onSubmitted: widget.onSubmitted,
          style: const TextStyle(fontSize: 14, color: ThixPolicy.textMain, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            counterText: '',
            hintText: widget.hint,
            hintStyle: const TextStyle(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w400),
            prefixIcon: Icon(widget.icon, size: 20, color: ThixPolicy.textSecondary),
            suffixIcon: widget.isPassword
                ? Semantics(
                    button: true,
                    label: _obscured ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
                    child: IconButton(
                      splashRadius: 20,
                      icon: Icon(
                        _obscured ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        size: 20,
                        color: ThixPolicy.textSecondary,
                      ),
                      onPressed: () => setState(() => _obscured = !_obscured),
                    ),
                  )
                : null,
            filled: true,
            fillColor: ThixPolicy.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ThixPolicy.inputRadius),
              borderSide: const BorderSide(color: ThixPolicy.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ThixPolicy.inputRadius),
              borderSide: const BorderSide(color: ThixPolicy.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ThixPolicy.inputRadius),
              borderSide: const BorderSide(color: ThixPolicy.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// SOCIAL AUTH BUTTON
// ============================================================================

class _SocialAuth extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SocialAuth({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ThixPolicy.rSm),
      child: Container(
        width: 76,
        height: 60,
        decoration: BoxDecoration(
          color: ThixPolicy.surface,
          borderRadius: BorderRadius.circular(ThixPolicy.rSm),
          border: Border.all(color: ThixPolicy.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: ThixPolicy.textMain, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: ThixPolicy.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// LANGUAGE CHIP
// ============================================================================

class _LangChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _LangChip({required this.label, this.active = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: 'Langue: $label',
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: active ? ThixPolicy.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: active ? ThixPolicy.onBrand : ThixPolicy.textSecondary,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 11,
                ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// FORGOT PASSWORD DIALOG
// ============================================================================

class _ForgotPasswordDialog extends StatefulWidget {
  final String prefillEmail;
  final Future<bool> Function(String) onSendReset;
  final int resetCooldown;
  final Future<void> Function({required String identifier, required bool success, String? failureReason}) logAttempt;

  const _ForgotPasswordDialog({
    required this.prefillEmail,
    required this.onSendReset,
    required this.resetCooldown,
    required this.logAttempt,
  });

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _emailC;
  final _otpC = TextEditingController();
  final _newPasswordC = TextEditingController();

  bool _isSending = false;
  bool _isOtpSent = false;
  bool _isObscured = true;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _emailC = TextEditingController(text: widget.prefillEmail);
  }

  @override
  void dispose() {
    _emailC.dispose();
    _otpC.dispose();
    _newPasswordC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canSend = !_isSending && widget.resetCooldown == 0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s24),
      child: Container(
        padding: const EdgeInsets.all(ThixPolicy.s28),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(ThixPolicy.cardRadius),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ThixPolicy.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isOtpSent ? Icons.vpn_key_rounded : Icons.lock_reset_rounded,
                    color: ThixPolicy.primary,
                  ),
                ),
                const SizedBox(width: ThixPolicy.s16),
                Expanded(
                  child: Text(
                    _isOtpSent ? l10n.t('login_reset_new_password') : l10n.t('login_forgot_password'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: ThixPolicy.textMain,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ThixPolicy.s16),

            Text(
              _isOtpSent
                  ? l10n.t('login_reset_otp_sent', args: [_emailC.text])
                  : l10n.t('login_reset_instructions'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ThixPolicy.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: ThixPolicy.s24),

            if (!_isOtpSent)
              Semantics(
                label: l10n.t('login_email_label'),
                textField: true,
                child: TextFormField(
                  controller: _emailC,
                  keyboardType: TextInputType.emailAddress,
                  maxLength: _kMaxEmailLength,
                  style: const TextStyle(fontSize: 14, color: ThixPolicy.textMain, fontWeight: FontWeight.w500),
                  decoration: _buildInputDecoration(
                    hintText: l10n.t('login_email_hint'),
                  ),
                ),
              )
            else ...[
              Semantics(
                label: l10n.t('login_otp_label'),
                textField: true,
                child: TextFormField(
                  controller: _otpC,
                  keyboardType: TextInputType.number,
                  maxLength: _kMaxOtpLength,
                  style: const TextStyle(fontSize: 14, color: ThixPolicy.textMain, fontWeight: FontWeight.w500),
                  decoration: _buildInputDecoration(
                    labelText: l10n.t('login_otp_label'),
                    hintText: '000000',
                  ),
                ),
              ),
              const SizedBox(height: ThixPolicy.s16),
              Semantics(
                label: l10n.t('login_new_password_label'),
                textField: true,
                child: TextFormField(
                  controller: _newPasswordC,
                  obscureText: _isObscured,
                  maxLength: _kMaxPasswordLength,
                  style: const TextStyle(fontSize: 14, color: ThixPolicy.textMain, fontWeight: FontWeight.w500),
                  decoration: _buildInputDecoration(
                    labelText: l10n.t('login_new_password_label'),
                    hintText: l10n.t('login_password_min_length'),
                    errorText: _passwordError,
                    suffixIcon: IconButton(
                      splashRadius: 20,
                      icon: Icon(
                        _isObscured ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: ThixPolicy.textSecondary,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _isObscured = !_isObscured),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: ThixPolicy.s28),

            Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: l10n.t('common_cancel'),
                    child: TextButton(
                      onPressed: _isSending ? null : () => Navigator.of(context).pop(),
                      child: Text(
                        l10n.t('common_cancel'),
                        style: const TextStyle(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: ThixPolicy.s12),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: _isOtpSent ? l10n.t('login_confirm') : l10n.t('login_send'),
                    enabled: !_isSending,
                    child: ElevatedButton(
                      onPressed: _isSending
                          ? null
                          : () async {
                              if (!_isOtpSent) {
                                if (!canSend) return;
                                final email = _LoginValidators.sanitize(_emailC.text.trim(), maxLength: _kMaxEmailLength);
                                if (!_LoginValidators.looksLikeEmail(email)) {
                                  HapticFeedback.lightImpact();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(l10n.t('login_error_invalid_email')),
                                      backgroundColor: ThixPolicy.danger,
                                    ),
                                  );
                                  return;
                                }

                                setState(() => _isSending = true);
                                HapticFeedback.mediumImpact();
                                await widget.onSendReset(email);

                                if (mounted) {
                                  setState(() {
                                    _isSending = false;
                                    _isOtpSent = true;
                                  });
                                }
                              } else {
                                final otp = _LoginValidators.sanitize(_otpC.text.trim(), maxLength: _kMaxOtpLength);
                                final newPass = _LoginValidators.sanitize(_newPasswordC.text, maxLength: _kMaxPasswordLength);

                                if (otp.isEmpty) {
                                  HapticFeedback.lightImpact();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(l10n.t('login_error_empty_otp')),
                                      backgroundColor: ThixPolicy.danger,
                                    ),
                                  );
                                  return;
                                }

                                // Validation politique NIST
                                final passError = await PasswordPolicy.validate(
                                  newPass,
                                  email: _emailC.text.trim(),
                                  fullName: '',
                                  phone: '',
                                );

                                if (passError != null) {
                                  HapticFeedback.lightImpact();
                                  setState(() => _passwordError = passError);
                                  return;
                                }

                                setState(() => _isSending = true);
                                HapticFeedback.mediumImpact();

                                try {
                                  final res = await Supabase.instance.client.auth.verifyOTP(
                                    email: _emailC.text.trim(),
                                    token: otp,
                                    type: OtpType.recovery,
                                  );

                                  if (res.user != null) {
                                    await Supabase.instance.client.auth.updateUser(
                                      UserAttributes(password: newPass),
                                    );

                                    await widget.logAttempt(
                                      identifier: _emailC.text.trim(),
                                      success: true,
                                      failureReason: 'password_reset_success',
                                    );

                                    if (mounted) {
                                      Navigator.of(context).pop();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Row(children: [
                                            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text(l10n.t('login_password_updated'))),
                                          ]),
                                          backgroundColor: ThixPolicy.success,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  debugPrint('[Login] ❌ Password reset error: $e');
                                  if (mounted) {
                                    HapticFeedback.lightImpact();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(l10n.t('login_error_invalid_otp')),
                                        backgroundColor: ThixPolicy.danger,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    setState(() => _isSending = false);
                                  }
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThixPolicy.primary,
                        foregroundColor: ThixPolicy.onBrand,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
                      ),
                      child: Text(
                        _isSending
                            ? l10n.t('login_please_wait')
                            : (_isOtpSent
                                ? l10n.t('login_confirm')
                                : (!canSend && widget.resetCooldown > 0
                                    ? l10n.t('login_wait_seconds', args: ['${widget.resetCooldown}'])
                                    : l10n.t('login_send'))),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    String? labelText,
    String? hintText,
    String? errorText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      errorText: errorText,
      counterText: '',
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: ThixPolicy.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ThixPolicy.inputRadius),
        borderSide: const BorderSide(color: ThixPolicy.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ThixPolicy.inputRadius),
        borderSide: const BorderSide(color: ThixPolicy.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ThixPolicy.inputRadius),
        borderSide: const BorderSide(color: ThixPolicy.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ThixPolicy.inputRadius),
        borderSide: const BorderSide(color: ThixPolicy.danger, width: 1.5),
      ),
    );
  }
}
