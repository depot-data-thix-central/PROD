// lib/presentation/auth/login_page.dart
//
// ============================================================================
// 🔐 LOGIN PAGE — THIX HUB (Enterprise · Design épuré · UX-friendly)
// ============================================================================
// ✅ Design unifié avec personal_registration_page.dart
// ✅ Anti-bot : honeypot hors écran + timing tolérant + rate limit silencieux
// ✅ Rate limiting serveur (check_login_allowed) = source de vérité
// ✅ Throttle local léger : garde-fou anti-burst uniquement (pas de double lock)
// ✅ Sécurité : liste noire, MFA, statuts de compte, journalisation
// ✅ Fail-open sur erreurs réseau (ne bloque jamais l'utilisateur légitime)
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import 'package:thix_id/auth/supabase_auth_manager.dart'
    show AuthException, AuthErrorCode;
import 'package:thix_id/core/security/security_reporter.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/nav.dart';

// ════════════════════════════════════════════════════════════════════════════
// CONSTANTS — UX-first (les protections serveur restent strictes)
// ════════════════════════════════════════════════════════════════════════════
const int _kResetCooldownDuration = 30;   // 45 → 30 s
const int _kMaxEmailLength = 254;
const int _kMinPasswordLength = 8;
const int _kMaxPasswordLength = 128;
const int _kMaxOtpLength = 8;
const int _kMaxIdentifierLength = 100;

// Anti-bot — tolérant, silencieux
const int _kMinFormFillSeconds = 1;       // 2 → 1 s (bots headless collent instantanément)
const int _kMaxSubmissionsPerMinute = 15; // 5 → 15 (tolère les fautes de frappe)

// Garde-fou UI local (en plus du serveur, mais léger)
const int _kUiBurstMaxAttempts = 5;       // 5 tentatives
const int _kUiBurstWindowSeconds = 60;    // en 60 s
const int _kUiBurstPauseSeconds = 10;     // → pause 10 s (pas 15 min !)

// Reset — allégé
const int _kResetMaxAttempts = 5;         // 3 → 5
const int _kResetLockSeconds = 300;       // 10 min → 5 min

// ════════════════════════════════════════════════════════════════════════════
// i18n FALLBACK (défauts [EN, FR])
// ════════════════════════════════════════════════════════════════════════════
const Map<String, List<String>> _kLoginFb = {
  'login_error_too_many_attempts': [
    'Too many attempts. Try again in {0}.',
    'Trop de tentatives. Réessayez dans {0}.',
  ],
  'login_minutes_short': ['min', 'min'],
  'login_error_suspended': [
    'This account is suspended. Contact support.',
    'Ce compte est suspendu. Contactez le support.',
  ],
  'login_error_not_active': [
    'This account is not yet active.',
    'Ce compte n’est pas encore actif.',
  ],
  'login_error_no_account': [
    'No account found with these details.',
    'Aucun compte trouvé avec ces informations.',
  ],
  'login_error_mfa_required': [
    'Two-factor authentication is required.',
    'L’authentification à deux facteurs est requise.',
  ],
  'login_error_locked': [
    'Access temporarily locked for security reasons.',
    'Accès temporairement verrouillé pour raison de sécurité.',
  ],
  'login_error_invalid_credentials': [
    'Incorrect identifier or password.',
    'Identifiant ou mot de passe incorrect.',
  ],
  'login_welcome_back': [
    'Sign in to your account',
    'Connectez-vous à votre compte',
  ],
  'auth_error_password_invalid_chars': [
    'Password contains invalid characters.',
    'Le mot de passe contient des caractères invalides.',
  ],
  'login_error_empty_otp': [
    'Enter the 8-digit code you received by email.',
    'Entrez le code à 8 chiffres reçu par email.',
  ],
};

String _tx(BuildContext ctx, String key, {List<String>? args}) {
  final l10n = AppLocalizations.of(ctx);
  var out = l10n.t(key);
  if (out.isEmpty || out == key) {
    final fb = _kLoginFb[key];
    if (fb == null) return key;
    out = Localizations.localeOf(ctx).languageCode == 'fr' ? fb[1] : fb[0];
  }
  if (args != null) {
    for (var i = 0; i < args.length; i++) {
      out = out.replaceAll('{$i}', args[i]);
    }
  }
  return out;
}

String _fmtWait(BuildContext ctx, int seconds) {
  if (seconds >= 60) {
    return '${(seconds / 60).ceil()} ${_tx(ctx, 'login_minutes_short')}';
  }
  return '$seconds${AppLocalizations.of(ctx).t('login_seconds_suffix')}';
}

// ════════════════════════════════════════════════════════════════════════════
// THROTTLE LOCAL — garde-fou UI uniquement (le serveur décide du vrai lockout)
// ════════════════════════════════════════════════════════════════════════════
class _Throttle {
  _Throttle._();

  static Future<int> blockedSeconds(String key) async {
    try {
      final p = await SharedPreferences.getInstance();
      final until = p.getInt('thix_thr_${key}_until') ?? 0;
      final r = ((until - DateTime.now().millisecondsSinceEpoch) / 1000).ceil();
      if (r <= 0) {
        if (until != 0) await p.remove('thix_thr_${key}_until');
        return 0;
      }
      return r;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> hit(String key, int max, int lockSeconds) async {
    try {
      final p = await SharedPreferences.getInstance();
      final n = (p.getInt('thix_thr_${key}_n') ?? 0) + 1;
      if (n >= max) {
        await p.setInt(
          'thix_thr_${key}_until',
          DateTime.now().millisecondsSinceEpoch + lockSeconds * 1000,
        );
        await p.setInt('thix_thr_${key}_n', 0);
      } else {
        await p.setInt('thix_thr_${key}_n', n);
      }
    } catch (_) {}
  }

  static Future<void> clear(String key) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove('thix_thr_${key}_n');
      await p.remove('thix_thr_${key}_until');
    } catch (_) {}
  }
}

// ════════════════════════════════════════════════════════════════════════════
// VALIDATORS
// ════════════════════════════════════════════════════════════════════════════
class _LoginValidators {
  _LoginValidators._();

  static final RegExp _ctrlKeepTab = RegExp(r'[\x00-\x08\x0B-\x1F\x7F]');
  static final RegExp _bidi = RegExp(
    r'[\u200B\u200E\u200F\u202A-\u202E\u2066-\u2069\uFEFF]',
  );
  static final RegExp _tags = RegExp(r'<[a-zA-Z/!?][^>]*>');
  static final RegExp _jsScheme =
      RegExp(r'(javascript|vbscript)\s*:', caseSensitive: false);
  static final RegExp _onHandler =
      RegExp(r'on\w+\s*=', caseSensitive: false);

  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    var s = input;
    if (s.contains('<')) {
      final doc = html_parser.parse(s);
      s = doc.body?.text ?? s;
    }
    s = s
        .replaceAll(_tags, '')
        .replaceAll(_jsScheme, '')
        .replaceAll(_onHandler, '')
        .replaceAll(_ctrlKeepTab, '')
        .replaceAll(_bidi, '')
        .trim();
    if (s.length > maxLength) {
      var end = maxLength;
      final unit = s.codeUnitAt(end - 1);
      if (unit >= 0xD800 && unit <= 0xDBFF) end--;
      s = s.substring(0, end);
    }
    return s;
  }

  /// Ne jamais modifier le mot de passe (sinon ≠ celui enregistré).
  static bool isSafePassword(String p) =>
      p.length <= _kMaxPasswordLength &&
      !_ctrlKeepTab.hasMatch(p) &&
      !_bidi.hasMatch(p);

  static bool looksLikePhone(String s) =>
      RegExp(r'^\+?[0-9][0-9\s\-]{7,}$').hasMatch(sanitize(s, maxLength: 50));

  static bool looksLikeEmail(String s) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
          .hasMatch(sanitize(s, maxLength: _kMaxEmailLength));

  static bool looksLikeThixId(String s) =>
      RegExp(r'^THIX-[A-Z0-9\-]{6,}$', caseSensitive: false)
          .hasMatch(sanitize(s, maxLength: 64));
}

// ════════════════════════════════════════════════════════════════════════════
// ANTI-BOT ENGINE — silencieux (jamais de snackbar, jamais de double lock)
// ════════════════════════════════════════════════════════════════════════════
class _AntiBotEngine {
  _AntiBotEngine() : _formOpenedAt = DateTime.now();

  final DateTime _formOpenedAt;
  String _honeypot = '';
  final List<DateTime> _submissionAttempts = [];

  void setHoneypot(String v) => _honeypot = v;

  /// true = humain probable. Pas de message, pas de lockout local.
  bool isLikelyHuman() {
    // 1. Honeypot rempli → robot
    if (_honeypot.trim().isNotEmpty) {
      debugPrint('[AntiBot] 🤖 honeypot filled');
      return false;
    }

    // 2. Timing : uniquement sur web (bots headless y sont majoritaires)
    if (kIsWeb) {
      final elapsed = DateTime.now().difference(_formOpenedAt).inSeconds;
      if (elapsed < _kMinFormFillSeconds) {
        debugPrint('[AntiBot] 🤖 too fast ($elapsed s)');
        return false;
      }
    }

    // 3. Burst rate : tolérant (15/min)
    _submissionAttempts.add(DateTime.now());
    _submissionAttempts.removeWhere(
      (t) => DateTime.now().difference(t).inSeconds > 60,
    );
    if (_submissionAttempts.length > _kMaxSubmissionsPerMinute) {
      debugPrint('[AntiBot] 🤖 burst rate hit');
      return false;
    }
    return true;
  }

  /// +1 uniquement (jamais +5 comme avant : c'était un bug).
  void registerFailure() {
    _submissionAttempts.add(DateTime.now());
  }
}

// ════════════════════════════════════════════════════════════════════════════
// AUTH ERROR TRANSLATOR
// ════════════════════════════════════════════════════════════════════════════
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
      case AuthErrorCode.rateLimit:
        return l10n.t('auth_error_rate_limit');
      case AuthErrorCode.networkError:
        return l10n.t('auth_error_network');
      case AuthErrorCode.technicalError:
        return l10n.t('auth_error_technical');
      case AuthErrorCode.sessionExpired:
        return l10n.t('auth_error_session_expired');
      default:
        return l10n.t('auth_error_technical');
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
  if (msg.contains('invalid login') || msg.contains('invalid credentials')) {
    return l10n.t('login_error_invalid_credentials');
  }

  debugPrint('[Login] ⚠️ Unmapped error: $e');
  return l10n.t('auth_error_technical');
}

// ════════════════════════════════════════════════════════════════════════════
// DESIGN — PREMIUM FIELD
// ════════════════════════════════════════════════════════════════════════════
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
  final String? helperText;
  final TextStyle? helperStyle;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final String? semanticsLabel;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  const _PremiumField({
    super.key,
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
    this.helperText,
    this.helperStyle,
    this.onChanged,
    this.inputFormatters,
    this.maxLength,
    this.semanticsLabel,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  State<_PremiumField> createState() => _PremiumFieldState();
}

class _PremiumFieldState extends State<_PremiumField> {
  late bool _obscured = widget.isPassword;

  OutlineInputBorder _border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(ThixPolicy.inputRadius),
        borderSide: BorderSide(color: c, width: w),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: ThixPolicy.labelStyle),
        const SizedBox(height: ThixPolicy.s8),
        Semantics(
          label: widget.semanticsLabel ?? widget.label,
          textField: true,
          child: TextFormField(
            controller: widget.controller,
            obscureText: _obscured,
            keyboardType: widget.keyboardType,
            readOnly: widget.readOnly,
            onTap: widget.onTap,
            onChanged: widget.onChanged,
            onFieldSubmitted: widget.onSubmitted,
            maxLength: widget.maxLength,
            inputFormatters: widget.inputFormatters,
            autofillHints: widget.autofillHints,
            textInputAction: widget.textInputAction,
            enableSuggestions: !widget.isPassword,
            autocorrect: !widget.isPassword,
            style: ThixPolicy.bodyStyle.copyWith(fontWeight: ThixPolicy.medium),
            decoration: InputDecoration(
              counterText: '',
              hintText: widget.hint,
              errorText: widget.errorText,
              errorMaxLines: 3,
              helperText: widget.helperText,
              helperStyle: widget.helperStyle,
              hintStyle: ThixPolicy.bodySmallStyle.copyWith(
                color: ThixPolicy.textSecondary.withOpacity(0.7),
              ),
              prefixIcon: Icon(widget.icon,
                  size: 20, color: ThixPolicy.textSecondary),
              suffixIcon: widget.trailing ??
                  (widget.isPassword
                      ? Semantics(
                          button: true,
                          label: _obscured
                              ? l10n.t('common_show_password')
                              : l10n.t('common_hide_password'),
                          child: IconButton(
                            splashRadius: 20,
                            icon: Icon(
                              _obscured
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              size: 20,
                              color: ThixPolicy.textSecondary,
                            ),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              setState(() => _obscured = !_obscured);
                            },
                          ),
                        )
                      : null),
              filled: true,
              fillColor: Colors.white,
              contentPadding: ThixPolicy.inputPadding,
              border: _border(ThixPolicy.border),
              enabledBorder: _border(ThixPolicy.border),
              focusedBorder: _border(ThixPolicy.primary, 1.6),
              errorBorder: _border(ThixPolicy.danger, 1.4),
              focusedErrorBorder: _border(ThixPolicy.danger, 1.6),
            ),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// LOGIN PAGE
// ════════════════════════════════════════════════════════════════════════════
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _identifierC = TextEditingController();
  final _passwordC = TextEditingController();
  final _honeyC = TextEditingController();
  late final _AntiBotEngine _antiBot = _AntiBotEngine();

  bool _rememberMe = true;
  bool _obscurePassword = true;
  int _lockoutSecondsLeft = 0;
  Timer? _lockoutTimer;

  int _resetCooldown = 0;
  Timer? _resetCooldownTimer;

  bool _isInitialVerifying = true;
  String? _identifierError;
  String? _passwordError;

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
    _honeyC.dispose();
    _lockoutTimer?.cancel();
    _resetCooldownTimer?.cancel();
    super.dispose();
  }

  // ── FEEDBACK ─────────────────────────────────────────────────────
  void _snack(String message, Color bg, IconData icon, {int seconds = 4}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.onBrand),
            ),
          ),
        ]),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: seconds),
      ),
    );
  }

  void _showSuccess(String m) =>
      _snack(m, ThixPolicy.success, Icons.check_circle_rounded);
  void _showInfo(String m) =>
      _snack(m, ThixPolicy.primary, Icons.info_outline_rounded);
  void _showError(String m) {
    HapticFeedback.lightImpact();
    _snack(m, ThixPolicy.danger, Icons.error_outline_rounded);
  }

  // ── LOCKOUT ──────────────────────────────────────────────────────
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

  // ── LOGGING ──────────────────────────────────────────────────────
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
            maxLength: _kMaxIdentifierLength,
          ),
          'failure_reason': failureReason,
          'timestamp': DateTime.now().toIso8601String(),
        },
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[Login] ⚠️ Failed to log attempt: $e');
    }
  }

  // ── RATE LIMITING SERVEUR (source de vérité) ─────────────────────
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
        final seconds = (map['seconds_remaining'] as num?)?.toInt() ?? 30;
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

  // ── SIGN IN ──────────────────────────────────────────────────────
  Future<void> _signIn() async {
    final l10n = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();

    _antiBot.setHoneypot(_honeyC.text);

    // 🤖 Anti-bot silencieux : aucun message, aucun lockout local.
    if (!_antiBot.isLikelyHuman()) {
      debugPrint('[Login] 🤖 dropped (anti-bot)');
      return;
    }

    // 🔒 Garde-fou UI léger : 5 échecs en 60 s → pause 10 s (le serveur décide du vrai lockout).
    final uiPause = await _Throttle.blockedSeconds('login_ui_burst');
    if (uiPause > 0) {
      _showError(_tx(context, 'login_error_too_many_attempts',
          args: [_fmtWait(context, uiPause)]));
      return;
    }

    if (_lockoutSecondsLeft > 0) {
      debugPrint('[Login] ⚠️ Sign in blocked: lockout active');
      return;
    }

    // Reset erreurs inline
    setState(() {
      _identifierError = null;
      _passwordError = null;
    });

    final identifier = _LoginValidators.sanitize(
      _identifierC.text.trim(),
      maxLength: _kMaxIdentifierLength,
    );
    final password = _passwordC.text; // ne jamais sanitiser

    // Validation inline (UX pro)
    if (identifier.isEmpty) {
      setState(() => _identifierError = l10n.t('login_error_empty_fields'));
      return;
    }
    if (password.isEmpty) {
      setState(() => _passwordError = l10n.t('login_error_empty_fields'));
      return;
    }
    if (!_LoginValidators.isSafePassword(password)) {
      setState(
          () => _passwordError = l10n.t('auth_error_password_invalid_chars'));
      return;
    }

    // 🌐 Rate limiting serveur (source de vérité)
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
      if (user == null) throw Exception('user_not_found_after_login');

      // 4. Statut compte
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
      await _Throttle.clear('login_ui_burst');

      final target = user.accountType == AccountType.enterprise
          ? AppRoutes.enterpriseDashboard
          : AppRoutes.userDashboard;

      debugPrint('[Login] ✓ Sign in successful → $target');
      context.go(target);
    } catch (e) {
      if (kDebugMode) debugPrint('[Login] ❌ Sign in error: $e');
      if (!mounted) return;

      final loginIdentifier = _identifierC.text.trim();
      final reason = e is AuthException ? e.code.name : e.toString();

      await _logLoginAttempt(
        identifier: loginIdentifier,
        success: false,
        failureReason: reason,
      );
      SecurityReporter.reportLoginFailure(
        identifier: loginIdentifier,
        reason: reason,
      );

      // Serveur : enregistre l'échec pour le vrai lockout
      await _recordFailedLogin(loginIdentifier.toLowerCase());

      // UI : simple garde-fou anti-burst (5 échecs / 60 s → 10 s de pause)
      await _Throttle.hit(
        'login_ui_burst',
        _kUiBurstMaxAttempts,
        _kUiBurstPauseSeconds,
      );

      _antiBot.registerFailure();
      _showError(_translateAuthError(e, l10n));
    }
  }

  // ── PASSWORD RESET ───────────────────────────────────────────────
  Future<bool> _sendPasswordReset(String email) async {
    final l10n = AppLocalizations.of(context);

    // 🤖 Anti-bot silencieux
    if (!_antiBot.isLikelyHuman()) {
      debugPrint('[Login] 🤖 reset dropped (anti-bot)');
      return false;
    }

    // 🔒 Garde-fou UI léger
    if (!await _notBlocked('reset_send')) return false;
    await _Throttle.hit('reset_send', _kResetMaxAttempts, _kResetLockSeconds);

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
    }
    _startResetCooldown();
    return true;
  }

  Future<bool> _notBlocked(String key) async {
    final s = await _Throttle.blockedSeconds(key);
    if (s > 0 && mounted) {
      _showError(_tx(context, 'login_error_too_many_attempts',
          args: [_fmtWait(context, s)]));
      return false;
    }
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

  // ── BUILD ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading || _isInitialVerifying;

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      body: SafeArea(
        child: Stack(
          children: [
            // 🍯 Honeypot hors écran
            Positioned(
              left: -3000,
              top: 0,
              width: 10,
              height: 10,
              child: ExcludeSemantics(
                child: ExcludeFocus(
                  child: TextField(
                    controller: _honeyC,
                    autofillHints: null,
                    enableSuggestions: false,
                    autocorrect: false,
                    keyboardType: TextInputType.url,
                  ),
                ),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    _buildTopBar(l10n),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          ThixPolicy.s20,
                          ThixPolicy.s8,
                          ThixPolicy.s20,
                          ThixPolicy.s24,
                        ),
                        physics: const BouncingScrollPhysics(),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(ThixPolicy.s24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(ThixPolicy.rXl),
                                border: Border.all(
                                    color: ThixPolicy.border.withOpacity(0.7)),
                                boxShadow: ThixPolicy.shadowSoft(),
                              ),
                              child: _buildFormCard(isLoading, l10n),
                            ),
                            const SizedBox(height: ThixPolicy.s16),
                            _buildSecurityBanner(l10n),
                            const SizedBox(height: ThixPolicy.s20),
                            _buildRegisterRow(l10n),
                            const SizedBox(height: ThixPolicy.s20),
                            _buildLangChips(),
                            const SizedBox(height: ThixPolicy.s24),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ThixPolicy.s20,
        ThixPolicy.s20,
        ThixPolicy.s20,
        ThixPolicy.s12,
      ),
      child: Column(
        children: [
          Semantics(
            header: true,
            label: 'THIX HUB',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: ThixPolicy.gold,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'THIX HUB',
                  style: ThixPolicy.h2Style.copyWith(
                    color: ThixPolicy.primaryDeep,
                    fontWeight: ThixPolicy.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.t('login_subtitle'),
            textAlign: TextAlign.center,
            style: ThixPolicy.captionStyle.copyWith(
              color: ThixPolicy.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(bool isLoading, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.t('login_title'),
          style: ThixPolicy.h2Style.copyWith(
            color: ThixPolicy.primaryDeep,
            fontWeight: ThixPolicy.bold,
          ),
        ),
        const SizedBox(height: ThixPolicy.s6),
        Text(
          _tx(context, 'login_welcome_back'),
          style: ThixPolicy.bodySmallStyle,
        ),
        const SizedBox(height: ThixPolicy.s24),

        // Identifiant (email / téléphone / THIX ID)
        _PremiumField(
          key: const ValueKey('identifier'),
          label: l10n.t('login_identifier_label'),
          hint: l10n.t('login_identifier_hint'),
          icon: Icons.badge_outlined,
          controller: _identifierC,
          keyboardType: TextInputType.emailAddress,
          maxLength: _kMaxIdentifierLength,
          errorText: _identifierError,
          autofillHints: const [AutofillHints.username],
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: ThixPolicy.s16),

        // Mot de passe (une seule fois)
        _PremiumField(
          key: const ValueKey('password'),
          label: l10n.t('login_password_label'),
          hint: l10n.t('login_password_hint'),
          icon: Icons.lock_outline_rounded,
          controller: _passwordC,
          isPassword: true,
          maxLength: _kMaxPasswordLength,
          errorText: _passwordError,
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _signIn(),
        ),
        const SizedBox(height: ThixPolicy.s12),

        // Remember me + forgot password
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
                              : ThixPolicy.border,
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.check_rounded,
                        size: 14,
                        color:
                            _rememberMe ? Colors.white : Colors.transparent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.t('login_remember_me'),
                      style: ThixPolicy.captionStyle.copyWith(
                        color: ThixPolicy.textSecondary,
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
                    fontWeight: ThixPolicy.semiBold,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: ThixPolicy.s24),

        // Bouton principal
        Semantics(
          button: true,
          label: l10n.t('login_button'),
          enabled: !isLoading && _lockoutSecondsLeft == 0,
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed:
                  (isLoading || _lockoutSecondsLeft > 0) ? null : _signIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: ThixPolicy.onBrand,
                disabledBackgroundColor:
                    ThixPolicy.primary.withOpacity(0.35),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
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
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: ThixPolicy.s12),
                  ],
                  Flexible(
                    child: Text(
                      _lockoutSecondsLeft > 0
                          ? '${l10n.t('login_retry_in')} '
                              '$_lockoutSecondsLeft'
                              '${l10n.t('login_seconds_suffix')}'
                          : (isLoading
                              ? l10n.t('login_verifying')
                              : l10n.t('login_button')),
                      overflow: TextOverflow.ellipsis,
                      style: ThixPolicy.bodyStyle.copyWith(
                        fontWeight: ThixPolicy.bold,
                        color: ThixPolicy.onBrand,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  if (!isLoading && _lockoutSecondsLeft == 0) ...[
                    const SizedBox(width: ThixPolicy.s8),
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: ThixPolicy.s20),

        // Biométrie
        Row(
          children: [
            const Expanded(child: Divider(color: ThixPolicy.border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                l10n.t('login_biometric'),
                style: ThixPolicy.microStyle.copyWith(
                  color: ThixPolicy.textMuted,
                  fontWeight: ThixPolicy.bold,
                  fontSize: 10,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const Expanded(child: Divider(color: ThixPolicy.border)),
          ],
        ),
        const SizedBox(height: ThixPolicy.s16),
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
    );
  }

  Widget _buildSecurityBanner(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(ThixPolicy.s16),
      decoration: BoxDecoration(
        color: ThixPolicy.success.withOpacity(0.06),
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: ThixPolicy.success.withOpacity(0.30)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ThixPolicy.success.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: ThixPolicy.success,
              size: 18,
            ),
          ),
          const SizedBox(width: ThixPolicy.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('login_security_title'),
                  style: ThixPolicy.labelStyle.copyWith(
                    color: ThixPolicy.primaryDeep,
                    fontWeight: ThixPolicy.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.t('login_security_subtitle'),
                  style: ThixPolicy.captionStyle.copyWith(
                    color: ThixPolicy.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterRow(AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          l10n.t('login_new_user'),
          style: ThixPolicy.bodySmallStyle.copyWith(
            color: ThixPolicy.textSecondary,
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
              style: ThixPolicy.bodyStyle.copyWith(
                color: ThixPolicy.primary,
                fontWeight: ThixPolicy.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLangChips() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// BIOMETRIC BUTTON
// ════════════════════════════════════════════════════════════════════════════
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
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        child: Container(
          width: 84,
          height: 62,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
            border: Border.all(color: ThixPolicy.border),
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
                  fontWeight: ThixPolicy.semiBold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// LANGUAGE CHIP
// ════════════════════════════════════════════════════════════════════════════
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

// ════════════════════════════════════════════════════════════════════════════
// FORGOT PASSWORD DIALOG
// ════════════════════════════════════════════════════════════════════════════
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
          Expanded(
            child: Text(
              message,
              style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.onBrand),
            ),
          ),
        ]),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        padding: const EdgeInsets.all(ThixPolicy.s24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ThixPolicy.rXl),
          border: Border.all(color: ThixPolicy.border.withOpacity(0.7)),
          boxShadow: ThixPolicy.shadowCard(),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ThixPolicy.primary.withOpacity(0.10),
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
                  const SizedBox(width: ThixPolicy.s12),
                  Expanded(
                    child: Text(
                      _isOtpSent
                          ? l10n.t('login_reset_new_password')
                          : l10n.t('login_forgot_password'),
                      style: ThixPolicy.h3Style.copyWith(
                        color: ThixPolicy.primaryDeep,
                        fontWeight: ThixPolicy.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ThixPolicy.s16),
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
              const SizedBox(height: ThixPolicy.s20),

              if (!_isOtpSent)
                _PremiumField(
                  label: l10n.t('login_email_label'),
                  hint: l10n.t('login_email_hint'),
                  icon: Icons.email_outlined,
                  controller: _emailC,
                  keyboardType: TextInputType.emailAddress,
                  maxLength: _kMaxEmailLength,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.done,
                )
              else ...[
                _PremiumField(
                  label: l10n.t('login_otp_label'),
                  hint: '00000000',
                  icon: Icons.confirmation_number_outlined,
                  controller: _otpC,
                  keyboardType: TextInputType.number,
                  maxLength: _kMaxOtpLength,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  autofillHints: const [AutofillHints.oneTimeCode],
                ),
                const SizedBox(height: ThixPolicy.s16),
                _PremiumField(
                  label: l10n.t('login_new_password_label'),
                  hint: l10n.t('login_password_min_length'),
                  icon: Icons.lock_outline_rounded,
                  controller: _newPasswordC,
                  isPassword: true,
                  maxLength: _kMaxPasswordLength,
                  errorText: _passwordError,
                  autofillHints: const [AutofillHints.newPassword],
                ),
              ],
              const SizedBox(height: ThixPolicy.s24),

              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isSending
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: ThixPolicy.textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        l10n.t('common_cancel'),
                        style: ThixPolicy.bodyStyle.copyWith(
                          fontWeight: ThixPolicy.semiBold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSending ? null : () => _handleSend(l10n),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThixPolicy.primary,
                        foregroundColor: ThixPolicy.onBrand,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
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
                        style: ThixPolicy.bodyStyle.copyWith(
                          fontWeight: ThixPolicy.bold,
                          color: ThixPolicy.onBrand,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSend(AppLocalizations l10n) async {
    if (!_isOtpSent) {
      final email = _LoginValidators.sanitize(
        _emailC.text.trim(),
        maxLength: _kMaxEmailLength,
      );
      if (!_LoginValidators.looksLikeEmail(email)) {
        _showDialogError(l10n.t('auth_error_invalid_email'));
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
      return;
    }

    // Vérification OTP + nouveau mot de passe
    final otp = _LoginValidators.sanitize(
      _otpC.text.trim(),
      maxLength: _kMaxOtpLength,
    );
    final newPass = _newPasswordC.text;

    if (!RegExp(r'^\d{8}$').hasMatch(otp)) {
      _showDialogError(_tx(context, 'login_error_empty_otp'));
      return;
    }
    if (newPass.length < _kMinPasswordLength) {
      HapticFeedback.lightImpact();
      setState(() => _passwordError =
          '${l10n.t('auth_error_password_too_short')} $_kMinPasswordLength');
      return;
    }
    if (!_LoginValidators.isSafePassword(newPass)) {
      setState(
          () => _passwordError = l10n.t('auth_error_password_invalid_chars'));
      return;
    }

    setState(() {
      _isSending = true;
      _passwordError = null;
    });
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
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.t('login_password_updated'),
                  style: ThixPolicy.bodyStyle
                      .copyWith(color: ThixPolicy.onBrand),
                ),
              ),
            ]),
            backgroundColor: ThixPolicy.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      debugPrint('[Login] ❌ Password reset error: $e');
      if (mounted) {
        _showDialogError(_translateAuthError(e, l10n));
        setState(() => _isSending = false);
      }
    }
  }
}
