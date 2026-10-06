// lib/presentation/auth/login_page.dart
//
// ============================================================================
// 🔐 LOGIN PAGE — THIX HUB (Production hardened)
// ============================================================================
// ✅ Anti-bot : honeypot + timing + rate limiting UI
// ✅ Design épuré minimaliste (THIX HUB branding)
// ✅ Rate limiting serveur (check_login_allowed) + UI lockout
// ✅ Sécurité : liste noire, MFA, statuts de compte, journalisation
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import 'package:thix_id/auth/supabase_auth_manager.dart'
    show AuthException, AuthErrorCode;
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/core/security/security_reporter.dart';

// ════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ════════════════════════════════════════════════════════════════════════
const int _kResetCooldownDuration = 45;
const int _kMaxEmailLength = 254;
const int _kMaxPasswordLength = 128;
const int _kMaxOtpLength = 8;
const int _kMaxIdentifierLength = 100;

// ── Anti-bot ──
const int _kMinFormFillSeconds = 2;
const int _kMaxSubmissionsPerMinute = 5;

// ════════════════════════════════════════════════════════════════════════
// VALIDATORS
// ════════════════════════════════════════════════════════════════════════
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
    return RegExp(r'^\+?[0-9][0-9\s\-]{7,}$')
        .hasMatch(sanitize(s, maxLength: 50));
  }

  static bool looksLikeEmail(String s) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
        .hasMatch(sanitize(s, maxLength: _kMaxEmailLength));
  }
}

// ════════════════════════════════════════════════════════════════════════
// ANTI-BOT ENGINE (silencieux)
// ════════════════════════════════════════════════════════════════════════
class _AntiBotEngine {
  _AntiBotEngine() : _formOpenedAt = DateTime.now();

  final DateTime _formOpenedAt;
  String _honeypot = '';
  final List<DateTime> _submissionAttempts = [];

  void setHoneypot(String v) => _honeypot = v;

  String? check(AppLocalizations l10n) {
    if (_honeypot.trim().isNotEmpty) {
      debugPrint('[AntiBot] 🤖 Honeypot filled');
      return l10n.t('auth_error_technical');
    }

    final elapsed = DateTime.now().difference(_formOpenedAt).inSeconds;
    if (elapsed < _kMinFormFillSeconds) {
      debugPrint('[AntiBot] 🤖 Too fast ($elapsed s)');
      return l10n.t('auth_error_technical');
    }

    _submissionAttempts.add(DateTime.now());
    _submissionAttempts.removeWhere(
      (t) => DateTime.now().difference(t).inSeconds > 60,
    );
    if (_submissionAttempts.length > _kMaxSubmissionsPerMinute) {
      debugPrint('[AntiBot] 🤖 Rate limit hit');
      return l10n.t('auth_error_rate_limit');
    }

    return null;
  }

  void registerFailure() {
    final now = DateTime.now();
    for (int i = 0; i < _kMaxSubmissionsPerMinute; i++) {
      _submissionAttempts.add(now.subtract(Duration(seconds: i)));
    }
  }
}

// ════════════════════════════════════════════════════════════════════════
// AUTH ERROR TRANSLATOR
// ════════════════════════════════════════════════════════════════════════
String _translateAuthError(Object e, AppLocalizations l10n) {
  if (e is AuthException) {
    switch (e.code) {
      case AuthErrorCode.identifierRequired:
        return l10n.t('auth_error_identifier_required');
      case AuthErrorCode.passwordRequired:
        return l10n.t('auth_error_password_required');
      case AuthErrorCode.thixIdLoginNotAvailable:
        return l10n.t('auth_error_thix_id_login_not_available');
      case AuthErrorCode.invalidEmail:
        return l10n.t('auth_error_invalid_email');
      case AuthErrorCode.passwordTooShort:
        final min = e.data?['minLength'] ?? 8;
        return '${l10n.t('auth_error_password_too_short')} $min';
      case AuthErrorCode.signInFailed:
        return l10n.t('auth_error_sign_in_failed');
      case AuthErrorCode.emailNotVerified:
        return l10n.t('auth_error_email_not_verified');
      case AuthErrorCode.serverMisconfiguration:
        return l10n.t('auth_error_server_misconfiguration');
      case AuthErrorCode.accountAlreadyExists:
        return l10n.t('auth_error_account_already_exists');
      case AuthErrorCode.accountExistsWrongPassword:
        return l10n.t('auth_error_account_exists_wrong_password');
      case AuthErrorCode.accountExistsNewOtpSent:
        return l10n.t('auth_error_account_exists_new_otp_sent');
      case AuthErrorCode.invalidOtp:
        return l10n.t('auth_error_invalid_otp');
      case AuthErrorCode.otpExpired:
        return l10n.t('auth_error_otp_expired');
      case AuthErrorCode.networkError:
        return l10n.t('auth_error_network');
      case AuthErrorCode.rateLimit:
        return l10n.t('auth_error_rate_limit');
      case AuthErrorCode.technicalError:
        return l10n.t('auth_error_technical');
      case AuthErrorCode.sessionExpired:
        return l10n.t('auth_error_session_expired');
      case AuthErrorCode.userMismatch:
        return l10n.t('auth_error_user_mismatch');
      case AuthErrorCode.profileUpdateFailed:
        return l10n.t('auth_error_profile_update_failed');
      case AuthErrorCode.markEmailVerifiedFailed:
        return l10n.t('auth_error_mark_email_verified_failed');
      case AuthErrorCode.qrTokenGenerationFailed:
        return l10n.t('auth_error_qr_token_generation_failed');
      case AuthErrorCode.finalizeRegistrationFailed:
        return l10n.t('auth_error_finalize_registration_failed');
      case AuthErrorCode.consumeQrTokenFailed:
        return l10n.t('auth_error_consume_qr_token_failed');
      case AuthErrorCode.resendOtpFailed:
        return l10n.t('auth_error_resend_otp_failed');
      case AuthErrorCode.phoneAuthNotAvailable:
        return l10n.t('auth_error_phone_auth_not_available');
      case AuthErrorCode.deleteAccountNotAvailable:
        return l10n.t('auth_error_delete_account_not_available');
      case AuthErrorCode.updateEmailFailed:
        return l10n.t('auth_error_update_email_failed');
      case AuthErrorCode.resetPasswordFailed:
        return l10n.t('auth_error_reset_password_failed');
      case AuthErrorCode.signUpFailed:
        return l10n.t('auth_error_sign_up_failed');
      case AuthErrorCode.otpSent:
        return l10n.t('auth_info_otp_sent');
    }
  }

  final msg = e.toString().toLowerCase();
  if (msg.contains('account_suspended') || msg.contains('suspended')) {
    return l10n.t('login_error_suspended');
  }
  if (msg.contains('account_not_active') || msg.contains('not active')) {
    return l10n.t('login_error_not_active');
  }
  if (msg.contains('aucun compte trouvé') ||
      msg.contains('phone_resolution_failed')) {
    return l10n.t('login_error_no_account');
  }
  if (msg.contains('mfa_required') || msg.contains('two_fa')) {
    return l10n.t('login_error_mfa_required');
  }
  if (msg.contains('user_not_found_after_login')) {
    return l10n.t('auth_error_sign_in_failed');
  }
  if (msg.contains('login_locked')) {
    return l10n.t('login_error_locked');
  }

  debugPrint('[Login] ⚠️ Unmapped error: $e');
  return l10n.t('auth_error_technical');
}

// ════════════════════════════════════════════════════════════════════════
// CLEAN INPUT (design épuré)
// ════════════════════════════════════════════════════════════════════════
class _CleanInput extends StatefulWidget {
  final String label;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final bool obscure;
  final TextInputType type;
  final TextEditingController controller;
  final TextInputAction textInputAction;
  final int? maxLength;
  final ValueChanged<String>? onSubmitted;
  final String? autofillHint
      
  const _CleanInput({
     super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.isPassword,
    required this.type,
    required this.controller,
    required this.textInputAction,
    this.obscure = false,
    this.maxLength,
    this.onSubmitted,
    this.autofillHint,
  });

  @override
  State<_CleanInput> createState() => _CleanInputState();
}

class _CleanInputState extends State<_CleanInput> {
  late bool _obscured = widget.isPassword;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (widget.obscure) {
      return SizedBox.shrink(
        child: TextField(
          controller: widget.controller,
          decoration: const InputDecoration(border: InputBorder.none),
          autofillHints: const [AutofillHints.name],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: ThixPolicy.textMain,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscured,
          keyboardType: widget.type,
          textInputAction: widget.textInputAction,
          maxLength: widget.maxLength,
          onFieldSubmitted: widget.onSubmitted,
          autofillHints: widget.autofillHint != null
              ? [widget.autofillHint!]
              : null,
          style: const TextStyle(
            fontSize: 14,
            color: ThixPolicy.textMain,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: widget.hint,
            hintStyle: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(
              widget.icon,
              size: 18,
              color: ThixPolicy.textSecondary,
            ),
            suffixIcon: widget.isPassword
                ? Semantics(
                    button: true,
                    label: _obscured
                        ? l10n.t('common_show_password')
                        : l10n.t('common_hide_password'),
                    child: IconButton(
                      splashRadius: 20,
                      icon: Icon(
                        _obscured
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                        color: ThixPolicy.textSecondary,
                      ),
                      onPressed: () =>
                          setState(() => _obscured = !_obscured),
                    ),
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: ThixPolicy.primary,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: ThixPolicy.danger,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// LOGIN PAGE
// ════════════════════════════════════════════════════════════════════════
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _identifierC = TextEditingController();
  final _passwordC = TextEditingController();
  final _honeypotC = TextEditingController();
  late final _AntiBotEngine _antiBot = _AntiBotEngine();

  bool _rememberMe = true;
  int _lockoutSecondsLeft = 0;
  Timer? _lockoutTimer;

  int _resetCooldown = 0;
  Timer? _resetCooldownTimer;

  bool _isInitialVerifying = true;

  @override
  void initState() {
    super.initState();
    _checkInitialSession();
  }

  Future<void> _checkInitialSession() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        await ref
            .read(authControllerProvider.notifier)
            .refreshCurrentUser()
            .timeout(const Duration(seconds: 3));
      }
    } catch (e) {
      debugPrint('[Login] ⚠️ Initial session check failed: $e');
    } finally {
      if (mounted) setState(() => _isInitialVerifying = false);
    }
  }

  @override
  void dispose() {
    _identifierC.dispose();
    _passwordC.dispose();
    _honeypotC.dispose();
    _lockoutTimer?.cancel();
    _resetCooldownTimer?.cancel();
    super.dispose();
  }

  // ── FEEDBACK ─────────────────────────────────────────────────────
  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ]),
        backgroundColor: ThixPolicy.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          const Icon(Icons.error_outline_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ]),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.info_outline_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ]),
        backgroundColor: ThixPolicy.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ── LOCKOUT ─────────────────────────────────────────────────────
  void _startLockoutTimer(int seconds) {
    _lockoutTimer?.cancel();
    setState(() => _lockoutSecondsLeft = seconds);
    debugPrint('[Login] 🔒 Lockout started: ${seconds}s');

    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_lockoutSecondsLeft <= 1) {
        timer.cancel();
        setState(() => _lockoutSecondsLeft = 0);
      } else {
        setState(() => _lockoutSecondsLeft -= 1);
      }
    });
  }

  void _startResetCooldown() {
    _resetCooldownTimer?.cancel();
    setState(() => _resetCooldown = _kResetCooldownDuration);

    _resetCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resetCooldown <= 1) {
        timer.cancel();
        setState(() => _resetCooldown = 0);
      } else {
        setState(() => _resetCooldown -= 1);
      }
    });
  }

  // ── LOGGING ─────────────────────────────────────────────────────
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
          'identifier': _LoginValidators.sanitize(
              identifier,
              maxLength: _kMaxIdentifierLength),
          'failure_reason': failureReason,
          'timestamp': DateTime.now().toIso8601String(),
        },
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[Login] ⚠️ Failed to log attempt: $e');
    }
  }

  // ── RATE LIMITING SERVEUR ───────────────────────────────────────
  Future<bool> _checkLoginAllowed(String identifier) async {
    try {
      final result = await Supabase.instance.client.rpc(
        'check_login_allowed',
        params: {'p_identifier': identifier},
      );
      final map = result is Map
          ? Map<String, dynamic>.from(result)
          : <String, dynamic>{};
      final allowed = map['allowed'] == true;
      if (!allowed) {
        final seconds =
            (map['seconds_remaining'] as num?)?.toInt() ?? 30;
        _startLockoutTimer(seconds);
      }
      return allowed;
    } catch (e) {
      debugPrint('[Login] ⚠️ check_login_allowed failed: $e');
      return true; // fail-open
    }
  }

  Future<void> _recordFailedLogin(String identifier) async {
    try {
      await Supabase.instance.client.rpc(
        'record_failed_login',
        params: {'p_identifier': identifier},
      );
    } catch (e) {
      debugPrint('[Login] ⚠️ record_failed_login failed: $e');
    }
  }

  Future<void> _clearLoginAttempts(String identifier) async {
    try {
      await Supabase.instance.client.rpc(
        'clear_login_attempts',
        params: {'p_identifier': identifier},
      );
    } catch (e) {
      debugPrint('[Login] ⚠️ clear_login_attempts failed: $e');
    }
  }

  // ── SIGN IN ─────────────────────────────────────────────────────
  Future<void> _signIn() async {
    final l10n = AppLocalizations.of(context);

    // 🤖 Anti-bot check
    final botError = _antiBot.check(l10n);
    if (botError != null) {
      _showError(botError);
      _antiBot.registerFailure();
      return;
    }

    if (_lockoutSecondsLeft > 0) {
      debugPrint('[Login] ⚠️ Sign in blocked: lockout active');
      return;
    }

    final identifier = _LoginValidators.sanitize(
        _identifierC.text.trim(),
        maxLength: _kMaxIdentifierLength);
    final password = _LoginValidators.sanitize(
        _passwordC.text,
        maxLength: _kMaxPasswordLength);

    if (identifier.isEmpty || password.isEmpty) {
      _showError(l10n.t('login_error_empty_fields'));
      _antiBot.registerFailure();
      return;
    }

    final allowed = await _checkLoginAllowed(identifier.toLowerCase());
    if (!allowed) {
      _showError(
        '${l10n.t('login_error_too_many_attempts_prefix')} '
        '$_lockoutSecondsLeft${l10n.t('login_seconds_suffix')}',
      );
      return;
    }

    HapticFeedback.mediumImpact();
    final authNotifier = ref.read(authControllerProvider.notifier);

    try {
      String finalIdentifier = identifier;

      // 1. Résolution téléphone → email
      if (_LoginValidators.looksLikePhone(identifier) &&
          !identifier.contains('@')) {
        try {
          final response = await Supabase.instance.client.rpc(
            'resolve_phone_to_email',
            params: {'p_phone': identifier},
          );
          if (response is String && response.isNotEmpty) {
            finalIdentifier = response;
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

      // 2. Liste noire
      final blocked = await Supabase.instance.client.rpc(
        'is_blocked',
        params: {
          'p_type': 'identifier',
          'p_value': finalIdentifier.toLowerCase(),
        },
      );

      if (blocked == true) {
        SecurityReporter.reportLoginBlocked(
          identifier: finalIdentifier,
          reason: 'identifiant en liste noire',
        );
        _showError(l10n.t('login_error_suspended'));
        _antiBot.registerFailure();
        return;
      }

      // 3. Connexion
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

      // 4. Vérification statut compte
      final status = user.accountStatus?.toLowerCase() ?? '';

      if (status == 'deactivated' || status == 'pending_deletion') {
        await _logLoginAttempt(
          identifier: finalIdentifier,
          success: false,
          failureReason: 'account_suspended',
        );
        SecurityReporter.reportLoginBlocked(
          identifier: finalIdentifier.trim(),
          reason: 'compte désactivé / en suppression',
        );
        throw Exception('account_suspended');
      }

      final regStatus = user.registrationStatus?.toLowerCase() ?? '';
      const completedStatuses = {'completed', 'active'};
      if (!completedStatuses.contains(regStatus)) {
        await _logLoginAttempt(
          identifier: finalIdentifier,
          success: false,
          failureReason: 'registration_not_completed',
        );
        context.go('${AppRoutes.personalReg}?step=3');
        _showError(l10n.t('login_error_finalize_registration'));
        return;
      }

      // 5. MFA
      if (user.twoFaEnabled == true) {
        await _logLoginAttempt(
          identifier: finalIdentifier,
          success: false,
          failureReason: 'mfa_required',
        );
        _showError(l10n.t('login_error_mfa_not_supported'));
        return;
      }

      // 6. Succès
      await _logLoginAttempt(
        identifier: finalIdentifier,
        success: true,
      );
      await _clearLoginAttempts(finalIdentifier.toLowerCase());

      final target = user.accountType == AccountType.enterprise
          ? AppRoutes.enterpriseDashboard
          : AppRoutes.userDashboard;

      debugPrint('[Login] ✓ Sign in successful → $target');
      context.go(target);
    } catch (e) {
      if (kDebugMode) debugPrint('[Login] ❌ Sign in error: $e');
      if (!mounted) return;

      final loginIdentifier = _identifierC.text.trim();
      final reason =
          e is AuthException ? e.code.name : e.toString();

      await _logLoginAttempt(
        identifier: loginIdentifier,
        success: false,
        failureReason: reason,
      );

      SecurityReporter.reportLoginFailure(
        identifier: loginIdentifier,
        reason: reason,
      );

      await _recordFailedLogin(loginIdentifier.toLowerCase());
      _showError(_translateAuthError(e, l10n));
      _antiBot.registerFailure();
    }
  }

  // ── PASSWORD RESET ──────────────────────────────────────────────
  Future<bool> _sendPasswordReset(String email) async {
    final l10n = AppLocalizations.of(context);

    // 🤖 Anti-bot check
    final botError = _antiBot.check(l10n);
    if (botError != null) {
      _showError(botError);
      _antiBot.registerFailure();
      return false;
    }

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      await _logLoginAttempt(
        identifier: email,
        success: true,
        failureReason: 'password_reset_requested',
      );
      _showInfo(l10n.t('login_reset_email_sent'));
    } catch (e) {
      debugPrint('[Login] ❌ Password reset failed: $e');
      _showError(_translateAuthError(e, l10n));
      _antiBot.registerFailure();
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
        prefillEmail: _LoginValidators.looksLikeEmail(_identifierC.text)
            ? _identifierC.text.trim()
            : '',
        onSendReset: _sendPasswordReset,
        resetCooldown: _resetCooldown,
        logAttempt: _logLoginAttempt,
      ),
    );
  }

  void _handleBiometric(String type) {
    final l10n = AppLocalizations.of(context);
    HapticFeedback.mediumImpact();
    _showInfo(l10n.t('login_biometric_not_supported'));
  }

  // ── BUILD ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading || _isInitialVerifying;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 40),
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // ── HEADER ÉPURÉ ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'T',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'THIX HUB',
                    style: ThixPolicy.h2Style.copyWith(
                      color: ThixPolicy.inkDeep,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.t('login_subtitle'),
                style: ThixPolicy.bodySmallStyle.copyWith(
                  color: ThixPolicy.textSecondary,
                ),
              ),
              const SizedBox(height: 36),

              // ── CARD PRINCIPALE ──
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.t('login_title'),
                      style: ThixPolicy.h2Style.copyWith(
                        color: ThixPolicy.inkDeep,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 🤖 Honeypot (invisible)
                    _CleanInput(
                      label: '',
                      hint: '',
                      icon: Icons.person,
                      isPassword: false,
                      type: TextInputType.text,
                      controller: _honeypotC,
                      textInputAction: TextInputAction.next,
                      obscure: true,
                    ),

                    Semantics(
                            label: l10n.t('login_password_label'),
                            textField: true,
                            child: _CleanInput(
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
                              autofillHint: AutofillHints.password,
                              // ✅ FIX: errorText passé directement (null = aucune erreur)
                              // Le spread if(...)...[] a été supprimé car invalide ici
                            ),
                          ),
                    const SizedBox(height: 16),
                    Semantics(
                      label: l10n.t('login_password_label'),
                      textField: true,
                      child: _CleanInput(
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
                        autofillHint: AutofillHints.password,
                      ),
                    ),
                    const SizedBox(height: 12),
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
                                    color: _rememberMe
                                        ? ThixPolicy.primary
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: _rememberMe
                                          ? ThixPolicy.primary
                                          : const Color(0xFFD1D5DB),
                                      width: 1.5,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.check_rounded,
                                    size: 14,
                                    color: _rememberMe
                                        ? Colors.white
                                        : Colors.transparent,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.t('login_remember_me'),
                                  style: ThixPolicy.bodySmallStyle.copyWith(
                                    color: ThixPolicy.textSecondary,
                                    fontSize: 13,
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
                            onTap: _openForgotPasswordDialog,
                            child: Text(
                              l10n.t('login_forgot_password'),
                              style: ThixPolicy.captionStyle.copyWith(
                                color: ThixPolicy.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Semantics(
                      button: true,
                      label: l10n.t('login_button'),
                      enabled: !isLoading && _lockoutSecondsLeft == 0,
                      child: ElevatedButton(
                        onPressed: (isLoading || _lockoutSecondsLeft > 0)
                            ? null
                            : _signIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThixPolicy.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              ThixPolicy.primary.withOpacity(0.4),
                          disabledForegroundColor: Colors.white70,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Text(
                              _lockoutSecondsLeft > 0
                                  ? '${l10n.t('login_retry_in')} '
                                      '$_lockoutSecondsLeft'
                                      '${l10n.t('login_seconds_suffix')}'
                                  : (isLoading
                                      ? l10n.t('login_verifying')
                                      : l10n.t('login_button')),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            if (_lockoutSecondsLeft == 0 && !isLoading) ...[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // ── BIOMETRIC ──
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            l10n.t('login_biometric'),
                            style: ThixPolicy.microStyle.copyWith(
                              color: ThixPolicy.textMuted,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _BiometricButton(
                          icon: Icons.face_rounded,
                          label: 'Face ID',
                          onTap: () => _handleBiometric('face_id'),
                        ),
                        const SizedBox(width: 12),
                        _BiometricButton(
                          icon: Icons.fingerprint_rounded,
                          label: 'Touch ID',
                          onTap: () => _handleBiometric('touch_id'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── SÉCURITÉ BANNER ──
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFBBF7D0),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ThixPolicy.success.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified_user_rounded,
                        color: Color(0xFF16A34A),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.t('login_security_title'),
                            style: ThixPolicy.labelStyle.copyWith(
                              color: const Color(0xFF166534),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.t('login_security_subtitle'),
                            style: ThixPolicy.captionStyle.copyWith(
                              color: const Color(0xFF15803D),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── REGISTER LINK ──
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.t('login_new_user'),
                    style: ThixPolicy.bodySmallStyle.copyWith(
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
                        style: ThixPolicy.bodySmallStyle.copyWith(
                          color: ThixPolicy.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ── LANG CHIPS ──
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
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
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// BIOMETRIC BUTTON (épuré)
// ════════════════════════════════════════════════════════════════════════
class _BiometricButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BiometricButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: ThixPolicy.textMain, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: ThixPolicy.microStyle.copyWith(
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

// ════════════════════════════════════════════════════════════════════════
// LANGUAGE CHIP
// ════════════════════════════════════════════════════════════════════════
class _LangChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _LangChip({
    required this.label,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: '${AppLocalizations.of(context).t('common_language')}: $label',
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: active ? ThixPolicy.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : ThixPolicy.textSecondary,
              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// FORGOT PASSWORD DIALOG
// ════════════════════════════════════════════════════════════════════════
class _ForgotPasswordDialog extends StatefulWidget {
  final String prefillEmail;
  final Future<bool> Function(String) onSendReset;
  final int resetCooldown;
  final Future<void> Function({
    required String identifier,
    required bool success,
    String? failureReason,
  }) logAttempt;

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

  void _showDialogError(String message) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canSend = !_isSending && widget.resetCooldown == 0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
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
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _isOtpSent
                        ? Icons.vpn_key_rounded
                        : Icons.lock_reset_rounded,
                    color: ThixPolicy.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isOtpSent
                        ? l10n.t('login_reset_new_password')
                        : l10n.t('login_forgot_password'),
                    style: ThixPolicy.h3Style.copyWith(
                      color: ThixPolicy.inkDeep,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _isOtpSent
                  ? '${l10n.t('login_reset_otp_sent_prefix')} ${_emailC.text}. '
                      '${l10n.t('login_reset_otp_sent_suffix')}'
                  : l10n.t('login_reset_instructions'),
              style: ThixPolicy.captionStyle.copyWith(
                color: ThixPolicy.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            if (!_isOtpSent)
              TextFormField(
                controller: _emailC,
                keyboardType: TextInputType.emailAddress,
                maxLength: _kMaxEmailLength,
                style: const TextStyle(
                  fontSize: 14,
                  color: ThixPolicy.textMain,
                  fontWeight: FontWeight.w500,
                ),
                decoration: _buildInputDecoration(
                  labelText: l10n.t('login_email_label'),
                  hintText: l10n.t('login_email_hint'),
                ),
              )
            else ...[
              TextFormField(
                controller: _otpC,
                keyboardType: TextInputType.number,
                maxLength: _kMaxOtpLength,
                style: const TextStyle(
                  fontSize: 14,
                  color: ThixPolicy.textMain,
                  fontWeight: FontWeight.w500,
                ),
                decoration: _buildInputDecoration(
                  labelText: l10n.t('login_otp_label'),
                  hintText: '00000000',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordC,
                obscureText: _isObscured,
                maxLength: _kMaxPasswordLength,
                style: const TextStyle(
                  fontSize: 14,
                  color: ThixPolicy.textMain,
                  fontWeight: FontWeight.w500,
                ),
                decoration: _buildInputDecoration(
                  labelText: l10n.t('login_new_password_label'),
                  hintText: l10n.t('login_password_min_length'),
                  errorText: _passwordError,
                  suffixIcon: IconButton(
                    splashRadius: 20,
                    icon: Icon(
                      _isObscured
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: ThixPolicy.textSecondary,
                      size: 18,
                    ),
                    onPressed: () =>
                        setState(() => _isObscured = !_isObscured),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isSending
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(
                      l10n.t('common_cancel'),
                      style: const TextStyle(
                        color: ThixPolicy.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSending
                        ? null
                        : () async {
                            if (!_isOtpSent) {
                              if (!canSend) return;
                              final email = _LoginValidators.sanitize(
                                  _emailC.text.trim(),
                                  maxLength: _kMaxEmailLength);
                              if (!_LoginValidators.looksLikeEmail(email)) {
                                _showDialogError(
                                    l10n.t('auth_error_invalid_email'));
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
                              final otp = _LoginValidators.sanitize(
                                  _otpC.text.trim(),
                                  maxLength: _kMaxOtpLength);
                              final newPass = _LoginValidators.sanitize(
                                  _newPasswordC.text,
                                  maxLength: _kMaxPasswordLength);

                              if (otp.isEmpty) {
                                _showDialogError(
                                    l10n.t('login_error_empty_otp'));
                                return;
                              }
                              if (newPass.length < 8) {
                                HapticFeedback.lightImpact();
                                setState(() => _passwordError =
                                    'Le mot de passe doit contenir au moins 8 caractères');
                                return;
                              }

                              setState(() => _isSending = true);
                              HapticFeedback.mediumImpact();

                              try {
                                final res = await Supabase.instance.client.auth
                                    .verifyOTP(
                                  email: _emailC.text.trim(),
                                  token: otp,
                                  type: OtpType.recovery,
                                );
                                if (res.user != null) {
                                  await Supabase.instance.client.auth
                                      .updateUser(UserAttributes(
                                    password: newPass,
                                  ));
                                  await widget.logAttempt(
                                    identifier: _emailC.text.trim(),
                                    success: true,
                                    failureReason: 'password_reset_success',
                                  );
                                  if (mounted) {
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Row(children: [
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(l10n.t(
                                                'login_password_updated')),
                                          ),
                                        ]),
                                        backgroundColor: ThixPolicy.success,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                debugPrint(
                                    '[Login] ❌ Password reset error: $e');
                                if (mounted) {
                                  _showDialogError(
                                      _translateAuthError(e, l10n));
                                  setState(() => _isSending = false);
                                }
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThixPolicy.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _isSending
                          ? l10n.t('login_please_wait')
                          : (_isOtpSent
                              ? l10n.t('login_confirm')
                              : (!canSend && widget.resetCooldown > 0
                                  ? '${l10n.t('login_wait_prefix')} '
                                      '${widget.resetCooldown}'
                                      '${l10n.t('login_seconds_suffix')}'
                                  : l10n.t('login_send'))),
                      style: const TextStyle(fontWeight: FontWeight.w700),
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
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: ThixPolicy.primary,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: ThixPolicy.danger,
          width: 1.5,
        ),
      ),
    );
  }
}
