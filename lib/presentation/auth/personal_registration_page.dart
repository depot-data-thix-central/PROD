// lib/presentation/auth/personal_registration_page.dart
//
// THIX HUB — Inscription personnelle (v2 : design épuré + sécurité anti-bot)
// ✅ Design clair et sobre : fond blanc, progression fine, champs à bordure légère
// ✅ Message PERMANENT après envoi du code : vérifier la boîte mail ET les spams
// ✅ Anti-bot / anti-abus : délai minimum humain, champ piège (honeypot),
//    limites d'essais persistées (envoi du code, vérification du code),
//    blocage temporaire avec compte à rebours
// ✅ Mot de passe : jamais modifié par la sanitisation, score zxcvbn >= 3,
//    contrôle des mots de passe compromis (HIBP), effacé de la mémoire à la fin
// ✅ Email jetable refusé, nom validé (lettres uniquement), caractères RTL/contrôle retirés

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zxcvbn/zxcvbn.dart';
import 'package:thix_id/auth/supabase_auth_manager.dart' show AuthErrorCode;
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/presentation/settings/policy_viewer_page.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const int _kMinPasswordLength = 8;
const int _kMaxPasswordLength = 128;
const int _kMaxNameLength = 100;
const int _kMinNameLength = 3;
const int _kMaxEmailLength = 254;
const int _kMaxPhoneLength = 20;
const int _kMaxOccupationLength = 100;
const int _kMaxChatLength = 21; // @ + 20 chars
const int _kMaxOtpLength = 8;
const int _kResendCooldownDuration = 60;
const int _kHibpTimeoutSeconds = 6;
const int _kHibpMaxRetries = 2;
const int _kMinAgeYears = 18;
const int _kMaxAgeYears = 110;
const int _kChatDebounceMs = 600;
const int _kPasswordDebounceMs = 400;
const int _kHibpMinBreaches = 1;
const int _kMinPasswordScore = 3; // zxcvbn 0..4

// Anti-bot
const int _kMinStep1Seconds = 4; // temps minimum avant de quitter l'étape 1
const int _kMinStep2Seconds = 8; // temps minimum avant d'envoyer le code
const int _kMaxSendAttempts = 5; // envois de code par fenêtre
const int _kSendLockSeconds = 900; // 15 min
const int _kMaxOtpFailures = 5; // codes faux par fenêtre
const int _kOtpLockSeconds = 300; // 5 min

const List<String> _kReservedChats = [
  '@admin', '@thix', '@thixhub', '@support', '@root', '@system',
  '@officiel', '@help', '@moderator', '@central',
];

/// Domaines d'email jetables les plus courants (liste de base, à compléter côté serveur).
const Set<String> _kDisposableDomains = {
  'mailinator.com', 'guerrillamail.com', 'guerrillamail.net', '10minutemail.com',
  'tempmail.com', 'temp-mail.org', 'yopmail.com', 'trashmail.com', 'getnada.com',
  'sharklasers.com', 'throwawaymail.com', 'maildrop.cc', 'dispostable.com',
  'fakeinbox.com', 'mintemail.com', 'mohmal.com', 'emailondeck.com', 'tempail.com',
};

// ============================================================================
// i18n : clé l10n d'abord, sinon repli [EN, FR] selon la langue de l'app
// ============================================================================
const Map<String, List<String>> _kRegFb = {
  'reg_otp_notice_title': ['Check your inbox', 'Vérifiez votre boîte mail'],
  'reg_otp_notice_body': [
    'We sent an 8-digit code to {0}. Open your email to find it.',
    'Un code à 8 chiffres a été envoyé à {0}. Ouvrez votre messagerie pour le récupérer.',
  ],
  'reg_otp_notice_spam': [
    'Not there? Check your Spam / Junk folder, and the Promotions tab.',
    'Introuvable ? Regardez dans le dossier Spam / Courrier indésirable et l’onglet Promotions.',
  ],
  'reg_error_too_many_attempts': [
    'Too many attempts. Try again in {0}.',
    'Trop de tentatives. Réessayez dans {0}.',
  ],
  'reg_error_wait_a_moment': ['Please take a moment and try again.', 'Veuillez patienter un instant puis réessayer.'],
  'reg_error_disposable_email': [
    'Temporary email addresses are not accepted.',
    'Les adresses email temporaires ne sont pas acceptées.',
  ],
  'reg_error_password_chars': ['Password contains invalid characters.', 'Le mot de passe contient des caractères invalides.'],
  'reg_error_name_chars': ['Name can only contain letters.', 'Le nom ne peut contenir que des lettres.'],
  'reg_step_of': ['Step {0} of 3', 'Étape {0} sur 3'],
  'reg_minutes_short': ['min', 'min'],
};

String _tx(BuildContext ctx, String key, {List<String>? args}) {
  final l10n = AppLocalizations.of(ctx);
  var out = l10n.t(key);
  if (out.isEmpty || out == key) {
    final fb = _kRegFb[key];
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
  if (seconds >= 60) return '${(seconds / 60).ceil()} ${_tx(ctx, 'reg_minutes_short')}';
  return '$seconds${AppLocalizations.of(ctx).t('reg_seconds_short')}';
}

// ============================================================================
// ANTI-ABUS : compteurs d'essais persistés (survivent au redémarrage de l'app)
// ============================================================================
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

  /// Compte une tentative. Au-delà de [max], bloque pendant [lockSeconds].
  static Future<void> hit(String key, int max, int lockSeconds) async {
    try {
      final p = await SharedPreferences.getInstance();
      final n = (p.getInt('thix_thr_${key}_n') ?? 0) + 1;
      if (n >= max) {
        await p.setInt('thix_thr_${key}_until', DateTime.now().millisecondsSinceEpoch + lockSeconds * 1000);
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

// ============================================================================
// VALIDATORS
// ============================================================================
class _RegValidators {
  _RegValidators._();

  static final RegExp _ctrl = RegExp(r'[\x00-\x1F\x7F]');
  static final RegExp _ctrlKeepTab = RegExp(r'[\x00-\x08\x0B-\x1F\x7F]');
  // Contrôles bidirectionnels (spoofing RTL), zero-width, BOM
  static final RegExp _bidi = RegExp(r'[\u200B\u200E\u200F\u202A-\u202E\u2066-\u2069\uFEFF]');
  static final RegExp _tags = RegExp(r'<[a-zA-Z/!?][^>]*>');
  static final RegExp _jsScheme = RegExp(r'(javascript|vbscript)\s*:', caseSensitive: false);

  /// Sanitise une saisie TEXTE (nom, métier, email…). Ne pas utiliser pour un mot de passe.
  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    var s = input;
    if (s.contains('<')) {
      final doc = html_parser.parse(s);
      s = doc.body?.text ?? s;
    }
    s = s.replaceAll(_tags, '').replaceAll(_jsScheme, '').replaceAll(_ctrlKeepTab, '').replaceAll(_bidi, '').trim();
    if (s.length > maxLength) {
      var end = maxLength;
      final unit = s.codeUnitAt(end - 1);
      if (unit >= 0xD800 && unit <= 0xDBFF) end--;
      s = s.substring(0, end);
    }
    return s;
  }

  /// Mot de passe : on ne le modifie JAMAIS (sinon le mot de passe saisi ≠ celui enregistré).
  static bool isSafePassword(String p) =>
      p.length <= _kMaxPasswordLength && !_ctrl.hasMatch(p) && !_bidi.hasMatch(p);

  static bool isValidEmail(String email) {
    final e = sanitize(email, maxLength: _kMaxEmailLength).toLowerCase();
    if (e.length < 6 || e.contains(' ')) return false;
    return RegExp(r'^[a-z0-9._%+\-]+@[a-z0-9\-]+(\.[a-z0-9\-]+)*\.[a-z]{2,}$').hasMatch(e);
  }

  static bool isDisposableEmail(String email) {
    final at = email.lastIndexOf('@');
    if (at < 0) return false;
    return _kDisposableDomains.contains(email.substring(at + 1).toLowerCase());
  }

  static bool isValidName(String name) =>
      RegExp(r"^[\p{L}\p{M}][\p{L}\p{M}' .\-]{1,}$", unicode: true).hasMatch(name);

  static bool isValidPhone(String phone) {
    if (phone.isEmpty) return true;
    final compact = phone.replaceAll(RegExp(r'[\s.-]'), '');
    return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(compact);
  }

  static bool isValidThixChat(String chat) => RegExp(r'^@[a-z0-9._]{3,20}$').hasMatch(chat);

  static String normalizeChat(String raw) {
    final s = raw.trim().toLowerCase();
    if (s.isEmpty) return '';
    return s.startsWith('@') ? s : '@$s';
  }

  static String mapCountryToCode(String? name) {
    const map = {
      'Afrique du Sud': 'ZA', 'Algérie': 'DZ', 'Angola': 'AO', 'Bénin': 'BJ',
      'Botswana': 'BW', 'Burkina Faso': 'BF', 'Burundi': 'BI', 'Cameroun': 'CM',
      'Cap-Vert': 'CV', 'Comores': 'KM', 'Congo-Brazzaville': 'CG', 'Côte d\'Ivoire': 'CI',
      'Djibouti': 'DJ', 'Égypte': 'EG', 'Érythrée': 'ER', 'Eswatini': 'SZ',
      'Éthiopie': 'ET', 'Gabon': 'GA', 'Gambie': 'GM', 'Ghana': 'GH', 'Guinée': 'GN',
      'Guinée-Bissau': 'GW', 'Guinée équatoriale': 'GQ', 'Kenya': 'KE', 'Lesotho': 'LS',
      'Liberia': 'LR', 'Libye': 'LY', 'Madagascar': 'MG', 'Malawi': 'MW', 'Mali': 'ML',
      'Maroc': 'MA', 'Maurice': 'MU', 'Mauritanie': 'MR', 'Mozambique': 'MZ',
      'Namibie': 'NA', 'Niger': 'NE', 'Nigeria': 'NG', 'Ouganda': 'UG',
      'République centrafricaine': 'CF', 'République démocratique du Congo': 'CD',
      'Rwanda': 'RW', 'Sao Tomé-et-Principe': 'ST', 'Sénégal': 'SN', 'Seychelles': 'SC',
      'Sierra Leone': 'SL', 'Somalie': 'SO', 'Soudan': 'SD', 'Soudan du Sud': 'SS',
      'Tanzanie': 'TZ', 'Tchad': 'TD', 'Togo': 'TG', 'Tunisie': 'TN', 'Zambie': 'ZM', 'Zimbabwe': 'ZW',
    };
    return map[name] ?? 'XX';
  }
}

// ============================================================================
// AUTH ERROR TRANSLATOR (inchangé)
// ============================================================================
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
        final min = 8;
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

  if (msg.contains('configuration serveur')) return l10n.t('reg_error_supabase_config');
  if (msg.contains('already registered') || msg.contains('already exists')) {
    return l10n.t('reg_error_email_exists');
  }
  if (msg.contains('23505') || msg.contains('unique constraint')) {
    if (msg.contains('phone')) return l10n.t('reg_error_phone_exists');
    if (msg.contains('thix_chat')) return l10n.t('reg_error_chat_taken');
    if (msg.contains('thix_id')) return l10n.t('reg_error_thix_id_failed');
    return l10n.t('reg_error_info_used');
  }
  if (msg.contains('invalid login') || msg.contains('invalid credentials')) {
    return l10n.t('reg_error_invalid_credentials');
  }
  if (msg.contains('email_not_verified')) return l10n.t('reg_error_email_not_verified');
  if (msg.contains('invalid_chat') || msg.contains('reserved') || msg.contains('réservé')) {
    return l10n.t('reg_error_chat_reserved');
  }
  if (msg.contains('chat_taken')) return l10n.t('reg_error_chat_taken');
  if (msg.contains('thix_id_failed')) return l10n.t('reg_error_thix_id_failed');
  if (msg.contains('expired')) return l10n.t('reg_error_code_expired');
  if (msg.contains('invalid') && msg.contains('token')) return l10n.t('reg_error_invalid_code');
  if (msg.contains('rate limit') || msg.contains('too many')) return l10n.t('reg_error_rate_limit');
  if (msg.contains('network') || msg.contains('timeout') || msg.contains('unavailable')) {
    return l10n.t('reg_error_network');
  }

  debugPrint('[Registration] ⚠️ Unmapped error: $e');
  return l10n.t('reg_error_generic');
}

// ============================================================================
// PASSWORD POLICY
// ============================================================================
enum PasswordErrorCode { tooShort, tooWeak, pwned, valid }

class PasswordValidationResult {
  final PasswordErrorCode code;
  final int score; // 0-4 zxcvbn
  final String? rawWarning;

  const PasswordValidationResult({required this.code, this.score = 0, this.rawWarning});

  bool get isValid => code == PasswordErrorCode.valid;
}

class PasswordPolicy {
  static const int minLength = _kMinPasswordLength;

  static Future<PasswordValidationResult> validate(
    String password, {
    required String email,
    required String fullName,
    required String phone,
  }) async {
    if (password.length < minLength) {
      return const PasswordValidationResult(code: PasswordErrorCode.tooShort);
    }

    final userInputs = [email, fullName, phone].where((s) => s.isNotEmpty).map((s) => s.toLowerCase()).toList();
    final result = Zxcvbn().evaluate(password, userInputs: userInputs);
    final score = (result.score ?? 0).toInt();

    if (score < _kMinPasswordScore) {
      final warning = result.feedback?.warning ?? '';
      final suggestions = result.feedback?.suggestions?.join(' ') ?? '';
      return PasswordValidationResult(
        code: PasswordErrorCode.tooWeak,
        score: score,
        rawWarning: '$warning $suggestions'.trim(),
      );
    }

    if (await _isPasswordPwned(password)) {
      return PasswordValidationResult(code: PasswordErrorCode.pwned, score: score);
    }
    return PasswordValidationResult(code: PasswordErrorCode.valid, score: score);
  }

  static int evaluateStrength(String password, List<String> userInputs) {
    if (password.isEmpty) return -1;
    final result = Zxcvbn().evaluate(password, userInputs: userInputs);
    return (result.score ?? 0).toInt();
  }

  /// k-anonymity : seuls 5 caractères du hash SHA-1 quittent l'appareil.
  static Future<bool> _isPasswordPwned(String password) async {
    int attempt = 0;
    while (attempt <= _kHibpMaxRetries) {
      try {
        final hash = sha1.convert(utf8.encode(password)).toString().toUpperCase();
        final prefix = hash.substring(0, 5);
        final suffix = hash.substring(5);

        final res = await http
            .get(
              Uri.parse('https://api.pwnedpasswords.com/range/$prefix'),
              headers: const {'User-Agent': 'THIX-HUB-App/1.0', 'Add-Padding': 'true'},
            )
            .timeout(const Duration(seconds: _kHibpTimeoutSeconds));

        if (res.statusCode != 200) return false;

        for (final line in res.body.split('\n')) {
          final parts = line.split(':');
          if (parts.length == 2 && parts[0].trim() == suffix) {
            final count = int.tryParse(parts[1].trim()) ?? 0;
            return count >= _kHibpMinBreaches;
          }
        }
        return false;
      } catch (e) {
        attempt++;
        if (kDebugMode) debugPrint('[PasswordPolicy] HIBP attempt $attempt failed: $e');
        if (attempt > _kHibpMaxRetries) return false;
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
    return false;
  }
}

// ============================================================================
// DESIGN COMPONENTS (épurés)
// ============================================================================
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
    this.helperText,
    this.helperStyle,
    this.onChanged,
    this.inputFormatters,
    this.maxLength,
    this.semanticsLabel,
    this.autofillHints,
    this.textInputAction,
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
              hintStyle: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary.withOpacity(0.7)),
              prefixIcon: Icon(widget.icon, size: 20, color: ThixPolicy.textSecondary),
              suffixIcon: widget.trailing ??
                  (widget.isPassword
                      ? Semantics(
                          button: true,
                          label: _obscured ? l10n.t('common_show_password') : l10n.t('common_hide_password'),
                          child: IconButton(
                            splashRadius: 20,
                            icon: Icon(
                              _obscured ? Icons.visibility_off_rounded : Icons.visibility_rounded,
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
        Text(label, style: ThixPolicy.labelStyle),
        const SizedBox(height: ThixPolicy.s8),
        Semantics(
          label: label,
          child: DropdownButtonFormField<String>(
            value: value,
            isExpanded: true,
            icon: const Icon(Icons.expand_more_rounded, size: 20, color: ThixPolicy.textSecondary),
            style: ThixPolicy.bodyStyle.copyWith(fontWeight: ThixPolicy.medium, color: ThixPolicy.textMain),
            dropdownColor: Colors.white,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 20, color: ThixPolicy.textSecondary),
              filled: true,
              fillColor: Colors.white,
              contentPadding: ThixPolicy.inputPadding,
              border: _border(ThixPolicy.border),
              enabledBorder: _border(ThixPolicy.border),
              focusedBorder: _border(ThixPolicy.primary, 1.6),
            ),
            hint: Text(l10n.t('common_select'), style: ThixPolicy.bodySmallStyle),
            items: items.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
          ),
        ),
      ],
    );
  }
}

/// Bandeau PERMANENT affiché après l'envoi du code : reste visible tant que
/// l'utilisateur est sur l'étape (ne disparaît pas comme un snackbar).
class _OtpNoticeBanner extends StatelessWidget {
  final String email;
  const _OtpNoticeBanner({required this.email});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(ThixPolicy.s16),
        decoration: BoxDecoration(
          color: ThixPolicy.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          border: Border.all(color: ThixPolicy.primary.withOpacity(0.30)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: ThixPolicy.primary.withOpacity(0.12), shape: BoxShape.circle),
              child: const Icon(Icons.mark_email_unread_rounded, size: 20, color: ThixPolicy.primary),
            ),
            const SizedBox(width: ThixPolicy.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _tx(context, 'reg_otp_notice_title'),
                    style: ThixPolicy.bodyStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.primaryDeep),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _tx(context, 'reg_otp_notice_body', args: [email]),
                    style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMain, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.report_gmailerrorred_rounded, size: 16, color: ThixPolicy.warning),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _tx(context, 'reg_otp_notice_spam'),
                          style: ThixPolicy.bodySmallStyle.copyWith(
                            color: ThixPolicy.textMain,
                            fontWeight: ThixPolicy.semiBold,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PAGE PRINCIPALE
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
  // Champ piège : invisible pour un humain, rempli par les robots
  final _honeyC = TextEditingController();

  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;

  String _thixIdGenerated = '';

  String? _passwordError;
  bool _passwordValidating = false;
  int _passwordScore = -1;
  Timer? _passwordDebounce;

  String? _chatError;
  String? _chatSuccess;
  bool _chatValidating = false;
  Timer? _chatDebounce;

  bool _otpSent = false;
  String _otpEmail = ''; // email auquel le code a été envoyé (affiché dans le bandeau)
  bool _emailVerified = false;
  bool _busy = false;
  int _step = 1;

  Timer? _resendTimer;
  int _resendCooldown = 0;

  late DateTime _stepEnteredAt = DateTime.now();

  static const List<String> _countries = [
    'Afrique du Sud', 'Algérie', 'Angola', 'Bénin', 'Botswana', 'Burkina Faso',
    'Burundi', 'Cameroun', 'Cap-Vert', 'Comores', 'Congo-Brazzaville', 'Côte d\'Ivoire',
    'Djibouti', 'Égypte', 'Érythrée', 'Eswatini', 'Éthiopie', 'Gabon', 'Gambie',
    'Ghana', 'Guinée', 'Guinée-Bissau', 'Guinée équatoriale', 'Kenya', 'Lesotho',
    'Liberia', 'Libye', 'Madagascar', 'Malawi', 'Mali', 'Maroc', 'Maurice',
    'Mauritanie', 'Mozambique', 'Namibie', 'Niger', 'Nigeria', 'Ouganda',
    'République centrafricaine', 'République démocratique du Congo', 'Rwanda',
    'Sao Tomé-et-Principe', 'Sénégal', 'Seychelles', 'Sierra Leone', 'Somalie',
    'Soudan', 'Soudan du Sud', 'Tanzanie', 'Tchad', 'Togo', 'Tunisie', 'Zambie', 'Zimbabwe', 'Autre',
  ];

  @override
  void initState() {
    super.initState();
    _step = widget.initialStep ?? 1;
    if (_step == 3) _step = 2;
    _stepEnteredAt = DateTime.now();
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
    _honeyC.dispose();
    _resendTimer?.cancel();
    _passwordDebounce?.cancel();
    _chatDebounce?.cancel();
    super.dispose();
  }

  void _enterStep(int s) {
    setState(() => _step = s);
    _stepEnteredAt = DateTime.now();
  }

  // ── FEEDBACK HELPERS ──────────────────────────────────────────────────────
  void _snack(String message, Color bg, IconData icon, {int seconds = 4}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.onBrand))),
        ]),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: seconds),
      ),
    );
  }

  void _showSuccess(String m) => _snack(m, ThixPolicy.success, Icons.check_circle_rounded);
  void _showInfo(String m) => _snack(m, ThixPolicy.primary, Icons.info_outline_rounded);
  void _showError(String m) {
    HapticFeedback.lightImpact();
    _snack(m, ThixPolicy.danger, Icons.error_outline_rounded);
  }

  // ── ANTI-BOT ──────────────────────────────────────────────────────────────

  /// true = comportement de robot probable (champ piège rempli).
  bool get _looksLikeBot => _honeyC.text.trim().isNotEmpty;

  /// Vérifie qu'une action n'est pas bloquée ; affiche le message sinon.
  Future<bool> _notBlocked(String key) async {
    final s = await _Throttle.blockedSeconds(key);
    if (s > 0 && mounted) {
      _showError(_tx(context, 'reg_error_too_many_attempts', args: [_fmtWait(context, s)]));
      return false;
    }
    return true;
  }

  bool _humanDelayOk(int minSeconds) {
    return DateTime.now().difference(_stepEnteredAt).inSeconds >= minSeconds;
  }

  // ── VALIDATION TEMPS RÉEL ─────────────────────────────────────────────────
  Future<void> _onChatChanged(String value) async {
    final l10n = AppLocalizations.of(context);
    _chatDebounce?.cancel();
    final raw = _RegValidators.sanitize(value.trim().toLowerCase(), maxLength: _kMaxChatLength);

    if (raw.isEmpty) {
      setState(() {
        _chatError = null;
        _chatSuccess = null;
        _chatValidating = false;
      });
      return;
    }

    final chat = _RegValidators.normalizeChat(raw);

    if (!_RegValidators.isValidThixChat(chat)) {
      setState(() {
        _chatError = l10n.t('reg_chat_format_error');
        _chatSuccess = null;
        _chatValidating = false;
      });
      return;
    }

    if (_kReservedChats.contains(chat)) {
      setState(() {
        _chatError = l10n.t('reg_chat_reserved_error');
        _chatSuccess = null;
        _chatValidating = false;
      });
      return;
    }

    setState(() {
      _chatValidating = true;
      _chatError = null;
      _chatSuccess = null;
    });

    _chatDebounce = Timer(const Duration(milliseconds: _kChatDebounceMs), () async {
      try {
        final res = await Supabase.instance.client
            .from('profiles')
            .select('id')
            .ilike('thix_chat', chat)
            .maybeSingle();

        if (!mounted) return;

        if (res != null) {
          setState(() {
            _chatError = l10n.t('reg_chat_taken_error');
            _chatValidating = false;
          });
        } else {
          setState(() {
            _chatSuccess = l10n.t('reg_chat_available');
            _chatValidating = false;
          });
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[Registration] Chat live validation error: $e');
        if (!mounted) return;
        setState(() => _chatValidating = false);
      }
    });
  }

  Future<void> _onPasswordChanged(String value) async {
    final l10n = AppLocalizations.of(context);
    _passwordDebounce?.cancel();
    if (value.isEmpty) {
      setState(() {
        _passwordError = null;
        _passwordScore = -1;
        _passwordValidating = false;
      });
      return;
    }

    if (!_RegValidators.isSafePassword(value)) {
      setState(() {
        _passwordError = _tx(context, 'reg_error_password_chars');
        _passwordScore = -1;
        _passwordValidating = false;
      });
      return;
    }

    setState(() => _passwordValidating = true);

    _passwordDebounce = Timer(const Duration(milliseconds: _kPasswordDebounceMs), () async {
      final email = _RegValidators.sanitize(_emailC.text.trim().toLowerCase(), maxLength: _kMaxEmailLength);
      final name = _RegValidators.sanitize(_nameC.text.trim(), maxLength: _kMaxNameLength);
      final phone = _RegValidators.sanitize(_phoneC.text.trim(), maxLength: _kMaxPhoneLength);

      final result = await PasswordPolicy.validate(value, email: email, fullName: name, phone: phone);
      if (!mounted) return;

      final score = PasswordPolicy.evaluateStrength(value, [email, name.toLowerCase()]);

      String? errorMsg;
      switch (result.code) {
        case PasswordErrorCode.tooShort:
          errorMsg = '${l10n.t('reg_password_too_short')} $_kMinPasswordLength';
          break;
        case PasswordErrorCode.tooWeak:
          errorMsg = l10n.t('reg_password_too_weak');
          break;
        case PasswordErrorCode.pwned:
          errorMsg = l10n.t('reg_password_pwned');
          break;
        case PasswordErrorCode.valid:
          errorMsg = null;
          break;
      }

      setState(() {
        _passwordError = errorMsg;
        _passwordScore = score;
        _passwordValidating = false;
      });
    });
  }

  // ── NAVIGATION ENTRE ÉTAPES ───────────────────────────────────────────────
  Future<void> _goToStep2() async {
    final l10n = AppLocalizations.of(context);
    if (_busy) return;

    if (_looksLikeBot) {
      _showError(_tx(context, 'reg_error_wait_a_moment'));
      return;
    }

    final name = _RegValidators.sanitize(_nameC.text.trim(), maxLength: _kMaxNameLength);
    final dob = _RegValidators.sanitize(_dobC.text.trim(), maxLength: 20);

    if (name.length < _kMinNameLength || name.length > _kMaxNameLength) {
      _showError(l10n.t('reg_error_name_invalid'));
      return;
    }
    if (!_RegValidators.isValidName(name)) {
      _showError(_tx(context, 'reg_error_name_chars'));
      return;
    }
    if (dob.isEmpty) {
      _showError(l10n.t('reg_error_dob_required'));
      return;
    }
    final parsed = DateTime.tryParse(dob);
    if (parsed == null) {
      _showError(l10n.t('reg_error_dob_invalid'));
      return;
    }
    final today = DateTime.now();
    final age = today.year -
        parsed.year -
        ((today.month < parsed.month || (today.month == parsed.month && today.day < parsed.day)) ? 1 : 0);
    if (age < _kMinAgeYears || age > _kMaxAgeYears) {
      _showError(age < _kMinAgeYears ? l10n.t('reg_error_underage') : l10n.t('reg_error_dob_invalid'));
      return;
    }
    if (_country == null) {
      _showError(l10n.t('reg_error_country_required'));
      return;
    }
    if (!_acceptedTerms || !_acceptedPrivacy) {
      _showError(l10n.t('auth_terms_required'));
      return;
    }
    if (!_humanDelayOk(_kMinStep1Seconds)) {
      _showError(_tx(context, 'reg_error_wait_a_moment'));
      return;
    }

    HapticFeedback.selectionClick();
    _enterStep(2);
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendCooldown = _kResendCooldownDuration);
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

  // ── AUTH & OTP ────────────────────────────────────────────────────────────
  Future<bool> _createAuthUser() async {
    final l10n = AppLocalizations.of(context);
    final email = _RegValidators.sanitize(_emailC.text.trim().toLowerCase(), maxLength: _kMaxEmailLength);
    final phone = _RegValidators.sanitize(
      _phoneC.text.trim().replaceAll(RegExp(r'[\s.-]'), ''),
      maxLength: _kMaxPhoneLength,
    );
    // Mot de passe : jamais sanitisé (on le valide, on ne le modifie pas)
    final pass = _passwordC.text;
    final confirm = _confirmC.text;
    final name = _RegValidators.sanitize(_nameC.text.trim(), maxLength: _kMaxNameLength);

    if (!_RegValidators.isValidEmail(email)) {
      _showError(l10n.t('reg_error_email_invalid'));
      return false;
    }
    if (_RegValidators.isDisposableEmail(email)) {
      _showError(_tx(context, 'reg_error_disposable_email'));
      return false;
    }
    if (phone.isNotEmpty && !_RegValidators.isValidPhone(phone)) {
      _showError(l10n.t('reg_error_phone_invalid'));
      return false;
    }
    if (!_RegValidators.isSafePassword(pass)) {
      _showError(_tx(context, 'reg_error_password_chars'));
      return false;
    }

    final passResult = await PasswordPolicy.validate(pass, email: email, fullName: name, phone: phone);
    if (!passResult.isValid) {
      String errorMsg;
      switch (passResult.code) {
        case PasswordErrorCode.tooShort:
          errorMsg = '${l10n.t('reg_password_too_short')} $_kMinPasswordLength';
          break;
        case PasswordErrorCode.tooWeak:
          errorMsg = l10n.t('reg_password_too_weak');
          break;
        case PasswordErrorCode.pwned:
          errorMsg = l10n.t('reg_password_pwned');
          break;
        default:
          errorMsg = l10n.t('reg_error_generic');
      }
      _showError(errorMsg);
      return false;
    }

    if (pass != confirm) {
      _showError(l10n.t('reg_error_passwords_mismatch'));
      return false;
    }

    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      await ref.read(authControllerProvider.notifier).registerPersonal(
            email: email,
            password: pass,
            displayName: name,
            rememberMe: true,
            profileDraft: {
              'full_name': name,
              'date_of_birth': _RegValidators.sanitize(_dobC.text.trim(), maxLength: 20),
              'country_or_origin': _country,
              'occupation': _occupationC.text.trim().isEmpty
                  ? null
                  : _RegValidators.sanitize(_occupationC.text.trim(), maxLength: _kMaxOccupationLength),
              'phone_number': phone.isEmpty ? null : phone,
              'registration_status': 'draft_step2',
              'account_status': 'pending',
              'terms_accepted_at': nowIso,
              'privacy_accepted_at': nowIso,
            },
          );
      return true;
    } catch (e) {
      final message = e.toString().toLowerCase();
      // Signal de succès : OTP envoyé, pas une vraie erreur
      if (message.contains('otpsent') ||
          message.contains('otp_sent') ||
          message.contains('nouveau code') ||
          message.contains('confirm') ||
          message.contains('inscription enregistrée')) {
        return true;
      }
      _showError(_translateAuthError(e, l10n));
      return false;
    }
  }

  Future<void> _sendOtp() async {
    final l10n = AppLocalizations.of(context);
    if (_busy || _resendCooldown > 0) return;

    if (_looksLikeBot) {
      _showError(_tx(context, 'reg_error_wait_a_moment'));
      return;
    }
    if (!_humanDelayOk(_kMinStep2Seconds)) {
      _showError(_tx(context, 'reg_error_wait_a_moment'));
      return;
    }
    if (!await _notBlocked('reg_otp_send')) return;

    HapticFeedback.mediumImpact();
    setState(() => _busy = true);

    try {
      if (await _refreshEmailVerifiedFlag()) {
        try {
          await Supabase.instance.client.rpc('mark_email_verified');
        } catch (_) {}
        if (!mounted) return;
        _showInfo(l10n.t('reg_email_already_verified'));
        setState(() => _otpSent = true);
        return;
      }

      // Chaque tentative d'envoi est comptée (anti-spam d'emails)
      await _Throttle.hit('reg_otp_send', _kMaxSendAttempts, _kSendLockSeconds);

      final success = await _createAuthUser();
      if (!success || !mounted) return;

      setState(() {
        _otpSent = true;
        _otpEmail = _RegValidators.sanitize(_emailC.text.trim().toLowerCase(), maxLength: _kMaxEmailLength);
      });
      _startResendCooldown();
      _showSuccess(l10n.t('reg_otp_sent'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _refreshEmailVerifiedFlag() async {
    try {
      await Supabase.instance.client.auth.refreshSession();
      final res = await Supabase.instance.client.auth.getUser();
      final ok = res.user?.emailConfirmedAt != null;
      _emailVerified = ok;
      return ok;
    } catch (e) {
      final ok = Supabase.instance.client.auth.currentUser?.emailConfirmedAt != null;
      _emailVerified = ok;
      return ok;
    }
  }

  String _desiredChat() {
    final raw = _RegValidators.sanitize(_thixChatC.text.trim().toLowerCase(), maxLength: _kMaxChatLength);
    if (raw.isNotEmpty) {
      final normalized = _RegValidators.normalizeChat(raw);
      if (_RegValidators.isValidThixChat(normalized)) return normalized;
    }

    final name = _RegValidators.sanitize(_nameC.text.trim(), maxLength: _kMaxNameLength);
    final first = name.split(RegExp(r'\s+')).first.toLowerCase();
    final safe = first.replaceAll(RegExp(r'[^a-z0-9._]'), '');
    final base = safe.length >= 3 ? safe.substring(0, safe.length.clamp(0, 12)) : 'user';
    final generated = '@$base${DateTime.now().millisecondsSinceEpoch % 10000}';
    return _RegValidators.isValidThixChat(generated)
        ? generated
        : '@user${DateTime.now().millisecondsSinceEpoch % 100000}';
  }

  Future<void> _verifyAndActivate() async {
    final l10n = AppLocalizations.of(context);
    if (_busy) return;

    if (_looksLikeBot) {
      _showError(_tx(context, 'reg_error_wait_a_moment'));
      return;
    }
    if (_chatError != null) {
      _showError(l10n.t('reg_error_fix_chat'));
      return;
    }

    final chat = _desiredChat();
    if (!_RegValidators.isValidThixChat(chat)) {
      _showError(l10n.t('reg_error_chat_format'));
      return;
    }
    if (!await _notBlocked('reg_otp_verify')) return;

    HapticFeedback.mediumImpact();
    setState(() => _busy = true);

    try {
      final notifier = ref.read(authControllerProvider.notifier);
      bool isVerified = await _refreshEmailVerifiedFlag();

      if (!isVerified) {
        if (!_otpSent) {
          _showError(l10n.t('reg_error_request_otp_first'));
          setState(() => _busy = false);
          return;
        }
        final code = _RegValidators.sanitize(_otpC.text.trim(), maxLength: _kMaxOtpLength);
        if (!RegExp(r'^\d{8}$').hasMatch(code)) {
          _showError(l10n.t('reg_error_otp_format'));
          setState(() => _busy = false);
          return;
        }

        try {
          await notifier.verifyOTP(
            email: _RegValidators.sanitize(_emailC.text.trim().toLowerCase(), maxLength: _kMaxEmailLength),
            token: code,
          );
        } catch (e) {
          // Code faux : on compte l'échec (anti force brute du code à 8 chiffres)
          await _Throttle.hit('reg_otp_verify', _kMaxOtpFailures, _kOtpLockSeconds);
          rethrow;
        }

        try {
          await Supabase.instance.client.rpc('mark_email_verified');
        } catch (_) {}
        try {
          await notifier.refreshCurrentUser();
        } catch (_) {}

        isVerified = await _refreshEmailVerifiedFlag();
        if (!isVerified) {
          _showError(l10n.t('reg_error_email_not_confirmed'));
          setState(() => _busy = false);
          return;
        }
      }

      final result = await Supabase.instance.client.rpc(
        'finalize_registration',
        params: {
          'p_desired_chat': chat,
          'p_country_code': _RegValidators.mapCountryToCode(_country),
        },
      );

      Map<String, dynamic> data;
      if (result is Map<String, dynamic>) {
        data = result;
      } else if (result is Map) {
        data = Map<String, dynamic>.from(result);
      } else {
        throw Exception('Invalid server response');
      }

      final officialThixId = (data['thix_id'] as String?)?.trim() ?? '';
      final claimedChat = (data['thix_chat'] as String?) ?? chat;

      if (officialThixId.isEmpty || officialThixId.toUpperCase().startsWith('THIX-PENDING')) {
        throw Exception('thix_id_failed');
      }

      try {
        await notifier.refreshCurrentUser();
      } catch (_) {}

      if (!mounted) return;

      // Succès : on efface les secrets de la mémoire et les compteurs
      _passwordC.clear();
      _confirmC.clear();
      _otpC.clear();
      await _Throttle.clear('reg_otp_send');
      await _Throttle.clear('reg_otp_verify');

      setState(() {
        _thixIdGenerated = officialThixId;
        _thixChatC.text = claimedChat;
      });
      _enterStep(3);
      _showSuccess(l10n.t('reg_account_activated'));
    } catch (e) {
      if (kDebugMode) debugPrint('[Registration] Activation error: $e');
      if (mounted) _showError(_translateAuthError(e, l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDob() async {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final adult = DateTime(now.year - _kMinAgeYears, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: adult,
      firstDate: DateTime(now.year - _kMaxAgeYears),
      lastDate: adult,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: ThixPolicy.primary),
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

  Future<void> _goBack() async {
    HapticFeedback.selectionClick();
    if (_step > 1) {
      _enterStep(_step - 1);
    } else {
      await ref.read(authControllerProvider.notifier).signOut();
      if (mounted) context.go(AppRoutes.login);
    }
  }

  void _goToDashboard() {
    HapticFeedback.mediumImpact();
    context.go(AppRoutes.userDashboard);
  }

  void _openPolicy(String slug) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PolicyViewerPage(slug: slug)));
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isLoading = ref.watch(authControllerProvider).isLoading || _busy;

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      body: SafeArea(
        child: Stack(
          children: [
            // Champ piège hors écran : ignoré des lecteurs d'écran et du focus clavier
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
                        padding: const EdgeInsets.fromLTRB(ThixPolicy.s20, ThixPolicy.s8, ThixPolicy.s20, ThixPolicy.s24),
                        physics: const BouncingScrollPhysics(),
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(ThixPolicy.s24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(ThixPolicy.rXl),
                                border: Border.all(color: ThixPolicy.border.withOpacity(0.7)),
                                boxShadow: ThixPolicy.shadowSoft(),
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                child: KeyedSubtree(
                                  key: ValueKey(_step),
                                  child: _buildStepContent(isLoading, l10n),
                                ),
                              ),
                            ),
                            const SizedBox(height: ThixPolicy.s20),
                            _buildMainButton(isLoading, l10n),
                            const SizedBox(height: ThixPolicy.s8),
                            if (_step < 3)
                              Semantics(
                                button: true,
                                label: _step == 1 ? l10n.t('reg_change_account') : l10n.t('reg_previous_step'),
                                child: TextButton(
                                  onPressed: isLoading ? null : _goBack,
                                  style: TextButton.styleFrom(foregroundColor: ThixPolicy.textSecondary),
                                  child: Text(
                                    _step == 1 ? l10n.t('reg_change_account') : l10n.t('reg_previous_step'),
                                    style: ThixPolicy.bodyStyle.copyWith(fontWeight: ThixPolicy.semiBold),
                                  ),
                                ),
                              ),
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

  /// En-tête sobre : marque THIX HUB + progression fine en 3 segments.
  Widget _buildTopBar(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(ThixPolicy.s20, ThixPolicy.s20, ThixPolicy.s20, ThixPolicy.s12),
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
                  decoration: const BoxDecoration(color: ThixPolicy.gold, shape: BoxShape.circle),
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
          const SizedBox(height: ThixPolicy.s16),
          Semantics(
            label: _tx(context, 'reg_step_of', args: ['$_step']),
            child: Row(
              children: List.generate(3, (i) {
                final done = i < _step;
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 4,
                    margin: EdgeInsets.only(right: i == 2 ? 0 : 6),
                    decoration: BoxDecoration(
                      color: done ? ThixPolicy.primary : ThixPolicy.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              _tx(context, 'reg_step_of', args: ['$_step']),
              style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(bool isLoading, AppLocalizations l10n) {
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
          acceptedTerms: _acceptedTerms,
          acceptedPrivacy: _acceptedPrivacy,
          onAcceptedTermsChanged: (v) => setState(() => _acceptedTerms = v ?? false),
          onAcceptedPrivacyChanged: (v) => setState(() => _acceptedPrivacy = v ?? false),
          onOpenTerms: () => _openPolicy('terms'),
          onOpenPrivacy: () => _openPolicy('privacy'),
        );
      case 2:
        return _Step2Account(
          emailC: _emailC,
          phoneC: _phoneC,
          passwordC: _passwordC,
          confirmC: _confirmC,
          otpC: _otpC,
          thixChatC: _thixChatC,
          onSendOtp: _sendOtp,
          onPasswordChanged: _onPasswordChanged,
          onChatChanged: _onChatChanged,
          isOtpSent: _otpSent,
          otpEmail: _otpEmail,
          isLoading: isLoading,
          resendCountdown: _resendCooldown,
          passwordError: _passwordError,
          passwordScore: _passwordScore,
          passwordValidating: _passwordValidating,
          chatError: _chatError,
          chatSuccess: _chatSuccess,
          chatValidating: _chatValidating,
        );
      case 3:
        return _Step3Final(
          thixId: _thixIdGenerated,
          thixChat: _thixChatC.text,
          name: _RegValidators.sanitize(_nameC.text.trim(), maxLength: _kMaxNameLength),
          email: _RegValidators.sanitize(_emailC.text.trim(), maxLength: _kMaxEmailLength),
          phone: _RegValidators.sanitize(_phoneC.text.trim(), maxLength: _kMaxPhoneLength),
          dob: _RegValidators.sanitize(_dobC.text.trim(), maxLength: 20),
          country: _country ?? '',
          occupation: _RegValidators.sanitize(_occupationC.text.trim(), maxLength: _kMaxOccupationLength),
          onCopyId: () {
            HapticFeedback.mediumImpact();
            Clipboard.setData(ClipboardData(text: _thixIdGenerated));
            _showSuccess(l10n.t('reg_thix_id_copied'));
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMainButton(bool isLoading, AppLocalizations l10n) {
    String label;
    VoidCallback? onPressed;
    switch (_step) {
      case 1:
        label = l10n.t('reg_next');
        onPressed = _goToStep2;
        break;
      case 2:
        label = isLoading ? l10n.t('reg_activating') : l10n.t('reg_validate_activate');
        onPressed = _verifyAndActivate;
        break;
      case 3:
        label = l10n.t('reg_go_to_dashboard');
        onPressed = _goToDashboard;
        break;
      default:
        label = '';
        onPressed = null;
    }

    final bool step1Blocked = _step == 1 && (!_acceptedTerms || !_acceptedPrivacy);

    return Semantics(
      button: true,
      label: label,
      enabled: !isLoading && !step1Blocked,
      child: SizedBox(
        height: 54,
        child: ElevatedButton(
          onPressed: (isLoading || step1Blocked) ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: ThixPolicy.primary,
            foregroundColor: ThixPolicy.onBrand,
            disabledBackgroundColor: ThixPolicy.primary.withOpacity(0.35),
            elevation: 0,
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
                const SizedBox(width: ThixPolicy.s12),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: ThixPolicy.bodyStyle.copyWith(
                    fontWeight: ThixPolicy.bold,
                    color: ThixPolicy.onBrand,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (!isLoading && _step < 3)
                const Padding(
                  padding: EdgeInsets.only(left: ThixPolicy.s8),
                  child: Icon(Icons.arrow_forward_rounded, size: 20),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SOUS-WIDGETS
// ============================================================================
class _Step1Profile extends StatelessWidget {
  final TextEditingController nameC;
  final TextEditingController dobC;
  final TextEditingController occupationC;
  final String? country;
  final ValueChanged<String?> onCountryChanged;
  final VoidCallback onPickDob;
  final List<String> countries;
  final bool acceptedTerms;
  final bool acceptedPrivacy;
  final ValueChanged<bool?> onAcceptedTermsChanged;
  final ValueChanged<bool?> onAcceptedPrivacyChanged;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  const _Step1Profile({
    required this.nameC,
    required this.dobC,
    required this.occupationC,
    required this.country,
    required this.onCountryChanged,
    required this.onPickDob,
    required this.countries,
    required this.acceptedTerms,
    required this.acceptedPrivacy,
    required this.onAcceptedTermsChanged,
    required this.onAcceptedPrivacyChanged,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.t('reg_step1_title'), style: ThixPolicy.h2Style.copyWith(color: ThixPolicy.primaryDeep)),
        const SizedBox(height: ThixPolicy.s6),
        Text(l10n.t('reg_step1_subtitle'), style: ThixPolicy.bodySmallStyle),
        const SizedBox(height: ThixPolicy.s24),
        _PremiumField(
          label: l10n.t('reg_full_name_label'),
          hint: l10n.t('reg_full_name_hint'),
          icon: Icons.person_outline_rounded,
          controller: nameC,
          maxLength: _kMaxNameLength,
          autofillHints: const [AutofillHints.name],
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: ThixPolicy.s16),
        _PremiumField(
          label: l10n.t('reg_dob_label'),
          hint: 'AAAA-MM-JJ',
          icon: Icons.calendar_today_rounded,
          controller: dobC,
          readOnly: true,
          onTap: onPickDob,
          trailing: const Icon(Icons.expand_more_rounded, color: ThixPolicy.textSecondary),
        ),
        const SizedBox(height: ThixPolicy.s16),
        _PremiumDropdown(
          label: l10n.t('reg_country_label'),
          icon: Icons.public_rounded,
          value: country,
          items: countries,
          onChanged: onCountryChanged,
        ),
        const SizedBox(height: ThixPolicy.s16),
        _PremiumField(
          label: l10n.t('reg_occupation_label'),
          hint: l10n.t('reg_occupation_hint'),
          icon: Icons.work_outline_rounded,
          controller: occupationC,
          maxLength: _kMaxOccupationLength,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: ThixPolicy.s20),
        const Divider(color: ThixPolicy.border, height: 1),
        const SizedBox(height: ThixPolicy.s12),
        _ConsentCheckboxRow(
          value: acceptedTerms,
          onChanged: onAcceptedTermsChanged,
          prefixText: l10n.t('auth_accept_terms'),
          linkText: l10n.t('settings_terms'),
          onLinkTap: onOpenTerms,
          semanticsLabel: l10n.t('settings_terms'),
        ),
        const SizedBox(height: ThixPolicy.s6),
        _ConsentCheckboxRow(
          value: acceptedPrivacy,
          onChanged: onAcceptedPrivacyChanged,
          prefixText: l10n.t('auth_accept_terms'),
          linkText: l10n.t('settings_privacy_policy'),
          onLinkTap: onOpenPrivacy,
          semanticsLabel: l10n.t('settings_privacy_policy'),
        ),
      ],
    );
  }
}

/// Case à cocher + texte + lien. Le lien ouvre la politique sans cocher la case.
class _ConsentCheckboxRow extends StatefulWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final String prefixText;
  final String linkText;
  final VoidCallback onLinkTap;
  final String semanticsLabel;

  const _ConsentCheckboxRow({
    required this.value,
    required this.onChanged,
    required this.prefixText,
    required this.linkText,
    required this.onLinkTap,
    required this.semanticsLabel,
  });

  @override
  State<_ConsentCheckboxRow> createState() => _ConsentCheckboxRowState();
}

class _ConsentCheckboxRowState extends State<_ConsentCheckboxRow> {
  late final TapGestureRecognizer _tap = TapGestureRecognizer()..onTap = widget.onLinkTap;

  @override
  void dispose() {
    _tap.dispose(); // évite la fuite du recognizer
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticsLabel,
      checked: widget.value,
      child: InkWell(
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onChanged(!widget.value);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: widget.value,
                onChanged: widget.onChanged,
                activeColor: ThixPolicy.primary,
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: RichText(
                    text: TextSpan(
                      style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMain),
                      children: [
                        TextSpan(text: '${widget.prefixText} '),
                        TextSpan(
                          text: widget.linkText,
                          style: ThixPolicy.bodySmallStyle.copyWith(
                            color: ThixPolicy.primary,
                            fontWeight: ThixPolicy.semiBold,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: _tap,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step2Account extends StatelessWidget {
  final TextEditingController emailC;
  final TextEditingController phoneC;
  final TextEditingController passwordC;
  final TextEditingController confirmC;
  final TextEditingController otpC;
  final TextEditingController thixChatC;
  final VoidCallback onSendOtp;
  final ValueChanged<String> onPasswordChanged;
  final ValueChanged<String> onChatChanged;
  final bool isOtpSent;
  final String otpEmail;
  final bool isLoading;
  final bool passwordValidating;
  final int resendCountdown;
  final String? passwordError;
  final int passwordScore;
  final String? chatError;
  final String? chatSuccess;
  final bool chatValidating;

  const _Step2Account({
    required this.emailC,
    required this.phoneC,
    required this.passwordC,
    required this.confirmC,
    required this.otpC,
    required this.thixChatC,
    required this.onSendOtp,
    required this.onPasswordChanged,
    required this.onChatChanged,
    required this.isOtpSent,
    required this.otpEmail,
    required this.isLoading,
    required this.resendCountdown,
    required this.passwordError,
    required this.passwordScore,
    required this.passwordValidating,
    required this.chatError,
    required this.chatSuccess,
    required this.chatValidating,
  });

  Color _scoreColor(int score) {
    switch (score) {
      case 0:
      case 1:
        return ThixPolicy.danger;
      case 2:
        return ThixPolicy.warning;
      case 3:
        return Colors.amber.shade700;
      case 4:
        return ThixPolicy.success;
      default:
        return ThixPolicy.border;
    }
  }

  String _scoreLabel(int score, AppLocalizations l10n) {
    switch (score) {
      case 0:
        return l10n.t('reg_strength_very_weak');
      case 1:
        return l10n.t('reg_strength_weak');
      case 2:
        return l10n.t('reg_strength_medium');
      case 3:
        return l10n.t('reg_strength_strong');
      case 4:
        return l10n.t('reg_strength_excellent');
      default:
        return '';
    }
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: ThixPolicy.s20, bottom: ThixPolicy.s12),
        child: Text(text, style: ThixPolicy.h3Style.copyWith(color: ThixPolicy.textMain)),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canResend = !isLoading && resendCountdown == 0;
    final bars = passwordScore < 0 ? 0 : (passwordScore == 0 ? 1 : passwordScore);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.t('reg_step2_title'), style: ThixPolicy.h2Style.copyWith(color: ThixPolicy.primaryDeep)),
        const SizedBox(height: ThixPolicy.s6),
        Text(l10n.t('reg_step2_subtitle'), style: ThixPolicy.bodySmallStyle),
        const SizedBox(height: ThixPolicy.s24),
        _PremiumField(
          label: l10n.t('reg_email_label'),
          hint: l10n.t('reg_email_hint'),
          icon: Icons.email_outlined,
          controller: emailC,
          keyboardType: TextInputType.emailAddress,
          maxLength: _kMaxEmailLength,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: ThixPolicy.s16),
        _PremiumField(
          label: l10n.t('reg_phone_label'),
          hint: l10n.t('reg_phone_hint'),
          icon: Icons.phone_android_rounded,
          controller: phoneC,
          keyboardType: TextInputType.phone,
          maxLength: _kMaxPhoneLength,
          autofillHints: const [AutofillHints.telephoneNumber],
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: ThixPolicy.s16),
        _PremiumField(
          label: l10n.t('reg_password_label'),
          hint: l10n.t('reg_password_hint'),
          icon: Icons.lock_outline_rounded,
          controller: passwordC,
          isPassword: true,
          onChanged: onPasswordChanged,
          errorText: passwordError,
          maxLength: _kMaxPasswordLength,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.next,
          trailing: passwordValidating
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : null,
        ),
        if (passwordScore >= 0 && passwordC.text.isNotEmpty) ...[
          const SizedBox(height: ThixPolicy.s8),
          Row(
            children: List.generate(4, (i) {
              final active = i < bars;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i == 3 ? 0 : 4),
                  decoration: BoxDecoration(
                    color: active ? _scoreColor(passwordScore) : ThixPolicy.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Text(
            '${l10n.t('reg_strength_label')}: ${_scoreLabel(passwordScore, l10n)}',
            style: ThixPolicy.captionStyle.copyWith(color: _scoreColor(passwordScore), fontWeight: ThixPolicy.medium),
          ),
        ],
        const SizedBox(height: ThixPolicy.s16),
        _PremiumField(
          label: l10n.t('reg_confirm_password_label'),
          hint: l10n.t('reg_confirm_password_hint'),
          icon: Icons.lock_outline_rounded,
          controller: confirmC,
          isPassword: true,
          maxLength: _kMaxPasswordLength,
          autofillHints: const [AutofillHints.newPassword],
        ),
        const Padding(
          padding: EdgeInsets.only(top: ThixPolicy.s20),
          child: Divider(color: ThixPolicy.border, height: 1),
        ),
        _sectionTitle(l10n.t('reg_identity_title')),
        _PremiumField(
          label: l10n.t('reg_thix_chat_label'),
          hint: l10n.t('reg_thix_chat_hint'),
          icon: Icons.alternate_email_rounded,
          controller: thixChatC,
          onChanged: onChatChanged,
          errorText: chatError,
          helperText: chatSuccess,
          helperStyle: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.success, fontWeight: ThixPolicy.semiBold),
          maxLength: _kMaxChatLength,
          trailing: chatValidating
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : (chatSuccess != null
                  ? const Icon(Icons.check_circle_rounded, color: ThixPolicy.success, size: 20)
                  : null),
        ),
        const Padding(
          padding: EdgeInsets.only(top: ThixPolicy.s20),
          child: Divider(color: ThixPolicy.border, height: 1),
        ),
        _sectionTitle(l10n.t('reg_verification_title')),
        Semantics(
          button: true,
          label: l10n.t('reg_get_otp'),
          enabled: canResend,
          child: SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: canResend ? onSendOtp : null,
              icon: Icon(isOtpSent ? Icons.check_circle_outline_rounded : Icons.send_rounded, size: 20),
              label: Flexible(
                child: Text(
                  !canResend && resendCountdown > 0
                      ? '${l10n.t('reg_resend_in')} $resendCountdown${l10n.t('reg_seconds_short')}'
                      : (isOtpSent ? l10n.t('reg_code_sent_resend') : l10n.t('reg_get_otp')),
                  overflow: TextOverflow.ellipsis,
                  style: ThixPolicy.bodyStyle.copyWith(fontWeight: ThixPolicy.semiBold),
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: ThixPolicy.primary,
                side: BorderSide(color: isOtpSent ? ThixPolicy.success : ThixPolicy.primary, width: 1.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
              ),
            ),
          ),
        ),
        if (isOtpSent) ...[
          const SizedBox(height: ThixPolicy.s16),
          // ✉️ MESSAGE PERMANENT : reste affiché tant que l'utilisateur est sur cette étape
          _OtpNoticeBanner(email: otpEmail.isEmpty ? emailC.text.trim() : otpEmail),
          const SizedBox(height: ThixPolicy.s16),
          _PremiumField(
            label: l10n.t('reg_otp_label'),
            hint: '00000000',
            icon: Icons.confirmation_number_outlined,
            controller: otpC,
            keyboardType: TextInputType.number,
            maxLength: _kMaxOtpLength,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofillHints: const [AutofillHints.oneTimeCode],
          ),
        ],
      ],
    );
  }
}

class _Step3Final extends StatelessWidget {
  final String thixId;
  final String thixChat;
  final String name;
  final String email;
  final String phone;
  final String dob;
  final String country;
  final String occupation;
  final VoidCallback onCopyId;

  const _Step3Final({
    required this.thixId,
    required this.thixChat,
    required this.name,
    required this.email,
    required this.phone,
    required this.dob,
    required this.country,
    required this.occupation,
    required this.onCopyId,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(ThixPolicy.s16),
            decoration: BoxDecoration(color: ThixPolicy.success.withOpacity(0.12), shape: BoxShape.circle),
            child: const Icon(Icons.verified_rounded, color: ThixPolicy.success, size: 44),
          ),
        ),
        const SizedBox(height: ThixPolicy.s16),
        Text(
          l10n.t('reg_congrats'),
          textAlign: TextAlign.center,
          style: ThixPolicy.h2Style.copyWith(color: ThixPolicy.primaryDeep, fontWeight: ThixPolicy.bold),
        ),
        const SizedBox(height: ThixPolicy.s8),
        Text(
          '${l10n.t('reg_welcome_message')} $name',
          textAlign: TextAlign.center,
          style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary),
        ),
        const SizedBox(height: ThixPolicy.s24),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: RepaintBoundary(
              child: Container(
                padding: const EdgeInsets.all(ThixPolicy.s20),
                decoration: BoxDecoration(
                  gradient: ThixPolicy.brandGradient,
                  borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                  boxShadow: ThixPolicy.shadowCard(),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('reg_id_card_title'),
                      style: ThixPolicy.microStyle.copyWith(
                        color: Colors.white70,
                        fontWeight: ThixPolicy.bold,
                        letterSpacing: 1.0,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: ThixPolicy.s16),
                    Text(
                      l10n.t('reg_official_thix_id'),
                      style: ThixPolicy.microStyle.copyWith(
                        color: ThixPolicy.gold,
                        fontWeight: ThixPolicy.bold,
                        letterSpacing: 1.2,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            thixId.isEmpty ? l10n.t('reg_generating') : thixId,
                            style: ThixPolicy.bodyStyle.copyWith(
                              color: ThixPolicy.onBrand,
                              fontWeight: ThixPolicy.bold,
                              letterSpacing: 0.8,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (thixId.isNotEmpty)
                          Semantics(
                            button: true,
                            label: l10n.t('reg_copy_thix_id'),
                            child: InkWell(
                              onTap: onCopyId,
                              child: const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.copy_rounded, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: ThixPolicy.s16),
                    Text(
                      'THIX CHAT',
                      style: ThixPolicy.microStyle.copyWith(
                        color: Colors.white70,
                        fontWeight: ThixPolicy.bold,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      thixChat,
                      style: ThixPolicy.bodyStyle.copyWith(
                        color: ThixPolicy.onBrand,
                        fontWeight: ThixPolicy.semiBold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: ThixPolicy.s24),
        Text(l10n.t('reg_summary'), style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.textMain)),
        const SizedBox(height: ThixPolicy.s12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s6),
          decoration: BoxDecoration(
            color: ThixPolicy.surfaceSoft,
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
            border: Border.all(color: ThixPolicy.border),
          ),
          child: Column(
            children: [
              _SummaryRow(label: l10n.t('reg_full_name_label'), value: name),
              const Divider(height: 1, color: ThixPolicy.border),
              _SummaryRow(label: l10n.t('reg_email_label'), value: email),
              const Divider(height: 1, color: ThixPolicy.border),
              _SummaryRow(
                label: l10n.t('reg_mobile_label'),
                value: phone.isEmpty ? l10n.t('reg_not_provided') : phone,
              ),
              const Divider(height: 1, color: ThixPolicy.border),
              _SummaryRow(label: l10n.t('reg_dob_label'), value: dob),
              const Divider(height: 1, color: ThixPolicy.border),
              _SummaryRow(label: l10n.t('reg_country_label'), value: country),
              if (occupation.isNotEmpty) ...[
                const Divider(height: 1, color: ThixPolicy.border),
                _SummaryRow(label: l10n.t('reg_occupation_label'), value: occupation),
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
      padding: const EdgeInsets.symmetric(vertical: ThixPolicy.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: ThixPolicy.bodySmallStyle.copyWith(fontWeight: ThixPolicy.medium)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value.isEmpty ? '—' : value,
              textAlign: TextAlign.right,
              style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMain, fontWeight: ThixPolicy.semiBold),
            ),
          ),
        ],
      ),
    );
  }
}
