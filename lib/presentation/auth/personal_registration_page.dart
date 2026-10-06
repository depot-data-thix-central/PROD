// lib/presentation/auth/personal_registration_page.dart
//
// ============================================================================
// 🔐 PERSONAL REGISTRATION — THIX HUB (Production hardened)
// ============================================================================
// ✅ Anti-bot : honeypot + timing + rate limiting + fingerprinting
// ✅ Design épuré minimaliste (THIX HUB branding)
// ✅ Message OTP permanent (vérifier mail + spam)
// ✅ Sécurité renforcée sur toutes les entrées
// ============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zxcvbn/zxcvbn.dart';
import 'package:thix_id/auth/supabase_auth_manager.dart' show AuthErrorCode;
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/presentation/settings/policy_viewer_page.dart';
import 'package:flutter/gestures.dart';

// ════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ════════════════════════════════════════════════════════════════════════
const int _kMinPasswordLength = 8;
const int _kMaxPasswordLength = 128;
const int _kMaxNameLength = 100;
const int _kMinNameLength = 3;
const int _kMaxEmailLength = 254;
const int _kMaxPhoneLength = 20;
const int _kMaxOccupationLength = 100;
const int _kMaxChatLength = 21;
const int _kMinChatLength = 3;
const int _kMaxOtpLength = 8;
const int _kResendCooldownDuration = 60;
const int _kHibpTimeoutSeconds = 6;
const int _kHibpMaxRetries = 2;
const int _kMinAgeYears = 18;
const int _kMaxAgeYears = 110;
const int _kChatDebounceMs = 600;
const int _kPasswordDebounceMs = 400;
const int _kHibpMinBreaches = 5;

// ── Sécurité anti-bot ──
const int _kMinFormFillSeconds = 3;       // Soumission trop rapide = bot
const int _kMaxSubmissionsPerMinute = 3;  // Rate limit UI
const int _kCooldownOnFailureSeconds = 5; // Cooldown après échec

const List<String> _kReservedChats = [
  '@admin', '@thix', '@support', '@root', '@system',
  '@officiel', '@help', '@moderator', '@central',
];

// ════════════════════════════════════════════════════════════════════════
// VALIDATORS
// ════════════════════════════════════════════════════════════════════════
class _RegValidators {
  _RegValidators._();

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

  static bool isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$')
        .hasMatch(sanitize(email, maxLength: _kMaxEmailLength));
  }

  static bool isValidPhone(String phone) {
    if (phone.isEmpty) return true;
    final compact = phone.replaceAll(RegExp(r'[\s.-]'), '');
    return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(compact);
  }

  static bool isValidThixChat(String chat) {
    return RegExp(r'^@[a-z0-9._]{3,20}$').hasMatch(chat);
  }

  static String normalizeChat(String raw) {
    final s = raw.trim().toLowerCase();
    if (s.isEmpty) return '';
    return s.startsWith('@') ? s : '@$s';
  }

  static String mapCountryToCode(String? name) {
    const map = {
      'Afrique du Sud': 'ZA', 'Algérie': 'DZ', 'Angola': 'AO', 'Bénin': 'BJ',
      'Botswana': 'BW', 'Burkina Faso': 'BF', 'Burundi': 'BI', 'Cameroun': 'CM',
      'Cap-Vert': 'CV', 'Comores': 'KM', 'Congo-Brazzaville': 'CG',
      'Côte d\'Ivoire': 'CI', 'Djibouti': 'DJ', 'Égypte': 'EG',
      'Érythrée': 'ER', 'Eswatini': 'SZ', 'Éthiopie': 'ET', 'Gabon': 'GA',
      'Gambie': 'GM', 'Ghana': 'GH', 'Guinée': 'GN', 'Guinée-Bissau': 'GW',
      'Guinée équatoriale': 'GQ', 'Kenya': 'KE', 'Lesotho': 'LS',
      'Liberia': 'LR', 'Libye': 'LY', 'Madagascar': 'MG', 'Malawi': 'MW',
      'Mali': 'ML', 'Maroc': 'MA', 'Maurice': 'MU', 'Mauritanie': 'MR',
      'Mozambique': 'MZ', 'Namibie': 'NA', 'Niger': 'NE', 'Nigeria': 'NG',
      'Ouganda': 'UG', 'République centrafricaine': 'CF',
      'République démocratique du Congo': 'CD', 'Rwanda': 'RW',
      'Sao Tomé-et-Principe': 'ST', 'Sénégal': 'SN', 'Seychelles': 'SC',
      'Sierra Leone': 'SL', 'Somalie': 'SO', 'Soudan': 'SD',
      'Soudan du Sud': 'SS', 'Tanzanie': 'TZ', 'Tchad': 'TD', 'Togo': 'TG',
      'Tunisie': 'TN', 'Zambie': 'ZM', 'Zimbabwe': 'ZW',
    };
    return map[name] ?? 'XX';
  }
}

// ════════════════════════════════════════════════════════════════════════
// ANTI-BOT ENGINE
// ════════════════════════════════════════════════════════════════════════

/// Moteur de détection anti-bot (honeypot, timing, rate limiting).
/// Silencieux : ne jamais révéler au bot qu'il est détecté.
class _AntiBotEngine {
  _AntiBotEngine() : _formOpenedAt = DateTime.now();

  final DateTime _formOpenedAt;
  String _honeypot = '';
  final List<DateTime> _submissionAttempts = [];

  /// Champ honeypot (caché visuellement, rempli par les bots).
  void setHoneypot(String v) => _honeypot = v;

  /// Vérifie tous les signaux anti-bot.
  /// Retourne null si OK, sinon un message d'erreur générique.
  String? check(AppLocalizations l10n) {
    // 1. Honeypot rempli → bot
    if (_honeypot.trim().isNotEmpty) {
      debugPrint('[AntiBot] 🤖 Honeypot filled');
      return l10n.t('reg_error_generic');
    }

    // 2. Soumission trop rapide (< 3s) → bot
    final elapsed = DateTime.now().difference(_formOpenedAt).inSeconds;
    if (elapsed < _kMinFormFillSeconds) {
      debugPrint('[AntiBot] 🤖 Too fast ($elapsed s)');
      return l10n.t('reg_error_generic');
    }

    // 3. Rate limit (> 3 tentatives/min)
    _submissionAttempts.add(DateTime.now());
    _submissionAttempts.removeWhere(
      (t) => DateTime.now().difference(t).inSeconds > 60,
    );
    if (_submissionAttempts.length > _kMaxSubmissionsPerMinute) {
      debugPrint('[AntiBot] 🤖 Rate limit hit');
      return l10n.t('reg_error_rate_limit');
    }

    return null;
  }

  /// Enregistre un échec pour refroidir
  void registerFailure() {
    // On ajoute plusieurs entrées fictives pour déclencher le rate limit
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
        return '${l10n.t('auth_error_password_too_short')} $_kMinPasswordLength';
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
  if (msg.contains('configuration serveur')) {
    return l10n.t('reg_error_supabase_config');
  }
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
  if (msg.contains('email_not_verified')) {
    return l10n.t('reg_error_email_not_verified');
  }
  if (msg.contains('invalid_chat') ||
      msg.contains('reserved') ||
      msg.contains('réservé')) {
    return l10n.t('reg_error_chat_reserved');
  }
  if (msg.contains('chat_taken')) return l10n.t('reg_error_chat_taken');
  if (msg.contains('thix_id_failed')) return l10n.t('reg_error_thix_id_failed');
  if (msg.contains('expired')) return l10n.t('reg_error_code_expired');
  if (msg.contains('invalid') && msg.contains('token')) {
    return l10n.t('reg_error_invalid_code');
  }
  if (msg.contains('rate limit') || msg.contains('too many')) {
    return l10n.t('reg_error_rate_limit');
  }
  if (msg.contains('network') ||
      msg.contains('timeout') ||
      msg.contains('unavailable')) {
    return l10n.t('reg_error_network');
  }

  debugPrint('[Registration] ⚠️ Unmapped error: $e');
  return l10n.t('reg_error_generic');
}

// ════════════════════════════════════════════════════════════════════════
// PASSWORD POLICY
// ════════════════════════════════════════════════════════════════════════
enum PasswordErrorCode { tooShort, tooWeak, pwned, valid }

class PasswordValidationResult {
  final PasswordErrorCode code;
  final int score;
  final String? rawWarning;
  const PasswordValidationResult({
    required this.code,
    this.score = 0,
    this.rawWarning,
  });
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
    final zxcvbn = Zxcvbn();
    final userInputs = [email, fullName, phone]
        .where((s) => s.isNotEmpty)
        .map((s) => s.toLowerCase())
        .toList();
    final result = zxcvbn.evaluate(password, userInputs: userInputs);
    final score = (result.score ?? 0).toInt();

    if (score < 2) {
      final warning = result.feedback?.warning ?? '';
      final suggestions = result.feedback?.suggestions?.join(' ') ?? '';
      return PasswordValidationResult(
        code: PasswordErrorCode.tooWeak,
        score: score,
        rawWarning: '$warning $suggestions'.trim(),
      );
    }

    final pwned = await _isPasswordPwned(password);
    if (pwned) {
      return PasswordValidationResult(
        code: PasswordErrorCode.pwned,
        score: score,
      );
    }
    return PasswordValidationResult(code: PasswordErrorCode.valid, score: score);
  }

  static int evaluateStrength(String password, List<String> userInputs) {
    if (password.isEmpty) return -1;
    final result = Zxcvbn().evaluate(password, userInputs: userInputs);
    return (result.score ?? 0).toInt();
  }

  static Future<bool> _isPasswordPwned(String password) async {
    int attempt = 0;
    while (attempt <= _kHibpMaxRetries) {
      try {
        final hash =
            sha1.convert(utf8.encode(password)).toString().toUpperCase();
        final prefix = hash.substring(0, 5);
        final suffix = hash.substring(5);
        final res = await http
            .get(
              Uri.parse('https://api.pwnedpasswords.com/range/$prefix'),
              headers: const {
                'User-Agent': 'THIX-HUB-App/1.0',
                'Add-Padding': 'true',
              },
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
        debugPrint('[PasswordPolicy] ⚠️ HIBP attempt $attempt failed: $e');
        if (attempt > _kHibpMaxRetries) return false;
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
    return false;
  }
}

// ════════════════════════════════════════════════════════════════════════
// DESIGN — Composants épurés
// ════════════════════════════════════════════════════════════════════════

/// Champ de saisie épuré avec label flottant.
class _CleanField extends StatefulWidget {
  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final bool isPassword;
  final TextInputType keyboardType;
  final bool readOnly;
  final bool obscure; // pour honeypot (invisible)
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? errorText;
  final String? helperText;
  final TextStyle? helperStyle;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final String? semanticsLabel;
  final AutofillHints? autofillHint;

  const _CleanField({
    required this.label,
    this.hint = '',
    required this.icon,
    required this.controller,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.readOnly = false,
    this.obscure = false,
    this.onTap,
    this.trailing,
    this.errorText,
    this.helperText,
    this.helperStyle,
    this.onChanged,
    this.inputFormatters,
    this.maxLength,
    this.semanticsLabel,
    this.autofillHint,
  });

  @override
  State<_CleanField> createState() => _CleanFieldState();
}

class _CleanFieldState extends State<_CleanField> {
  late bool _obscured = widget.isPassword;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Champ honeypot : invisible (hauteur 0, pas dans Semantics)
    if (widget.obscure) {
      return SizedBox.shrink(
        child: TextField(
          controller: widget.controller,
          onChanged: widget.onChanged,
          decoration: const InputDecoration(border: InputBorder.none),
          autofillHints: const [AutofillHints.name], // leurre
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: ThixPolicy.labelStyle.copyWith(
            color: ThixPolicy.textMain,
            fontWeight: ThixPolicy.medium,
          ),
        ),
        const SizedBox(height: 8),
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
            autofillHints: widget.autofillHint != null
                ? [widget.autofillHint
                : null,
            style: ThixPolicy.bodyStyle.copyWith(
              fontWeight: ThixPolicy.medium,
              color: ThixPolicy.textMain,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: widget.hint,
              errorText: widget.errorText,
              helperText: widget.helperText,
              helperStyle: widget.helperStyle,
              hintStyle: ThixPolicy.bodySmallStyle.copyWith(
                color: ThixPolicy.textMuted,
              ),
              prefixIcon: Icon(
                widget.icon,
                size: 18,
                color: ThixPolicy.textSecondary,
              ),
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
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 18,
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFE5E7EB),
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFE5E7EB),
                  width: 1,
                ),
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
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: ThixPolicy.danger,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Dropdown épuré
class _CleanDropdown extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final String? semanticsLabel;

  const _CleanDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: ThixPolicy.labelStyle.copyWith(
            color: ThixPolicy.textMain,
            fontWeight: ThixPolicy.medium,
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: semanticsLabel ?? label,
          child: DropdownButtonFormField<String>(
            value: value,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: ThixPolicy.textSecondary,
            ),
            style: ThixPolicy.bodyStyle.copyWith(
              fontWeight: ThixPolicy.medium,
              color: ThixPolicy.textMain,
            ),
            dropdownColor: Colors.white,
            isExpanded: true,
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                size: 18,
                color: ThixPolicy.textSecondary,
              ),
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
            ),
            hint: Text(
              l10n.t('common_select'),
              style: ThixPolicy.bodySmallStyle.copyWith(
                color: ThixPolicy.textMuted,
              ),
            ),
            items: items
                .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
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

// ════════════════════════════════════════════════════════════════════════
// BANNIÈRE OTP PERSISTANTE
// ════════════════════════════════════════════════════════════════════════

/// Bannière permanente affichée après envoi de l'OTP.
/// Indique à l'utilisateur de vérifier ses emails + spam.
class _OtpInfoBanner extends StatelessWidget {
  final String email;

  const _OtpInfoBanner({required this.email});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF), // bleu très pâle
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.mail_outline_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('reg_otp_sent_to_email'),
                  style: ThixPolicy.labelStyle.copyWith(
                    color: const Color(0xFF1E40AF),
                    fontWeight: ThixPolicy.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: ThixPolicy.captionStyle.copyWith(
                    color: const Color(0xFF1E40AF),
                    fontWeight: ThixPolicy.semiBold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.t('reg_otp_check_spam_hint'),
                  style: ThixPolicy.captionStyle.copyWith(
                    color: const Color(0xFF1E3A8A),
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
}

// ════════════════════════════════════════════════════════════════════════
// PAGE PRINCIPALE
// ════════════════════════════════════════════════════════════════════════
class PersonalRegistrationPage extends ConsumerStatefulWidget {
  final int? initialStep;
  const PersonalRegistrationPage({super.key, this.initialStep});

  @override
  ConsumerState<PersonalRegistrationPage> createState() =>
      _PersonalRegistrationPageState();
}

class _PersonalRegistrationPageState
    extends ConsumerState<PersonalRegistrationPage> {
  // ── Contrôleurs ──
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

  // 🤖 Honeypot (champ caché anti-bot)
  final _honeypotC = TextEditingController();
  late final _AntiBotEngine _antiBot = _AntiBotEngine();

  // ── Consentements ──
  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;

  String _thixIdGenerated = '';

  // ── Password ──
  String? _passwordError;
  bool _passwordValidating = false;
  int _passwordScore = -1;
  Timer? _passwordDebounce;

  // ── Chat ──
  String? _chatError;
  String? _chatSuccess;
  bool _chatValidating = false;
  Timer? _chatDebounce;

  // ── OTP ──
  bool _otpSent = false;
  bool _emailVerified = false;
  bool _busy = false;
  int _step = 1;

  Timer? _resendTimer;
  int _resendCooldown = 0;

  static const List<String> _countries = [
    'Afrique du Sud', 'Algérie', 'Angola', 'Bénin', 'Botswana',
    'Burkina Faso', 'Burundi', 'Cameroun', 'Cap-Vert', 'Comores',
    'Congo-Brazzaville', 'Côte d\'Ivoire', 'Djibouti', 'Égypte',
    'Érythrée', 'Eswatini', 'Éthiopie', 'Gabon', 'Gambie', 'Ghana',
    'Guinée', 'Guinée-Bissau', 'Guinée équatoriale', 'Kenya', 'Lesotho',
    'Liberia', 'Libye', 'Madagascar', 'Malawi', 'Mali', 'Maroc',
    'Maurice', 'Mauritanie', 'Mozambique', 'Namibie', 'Niger',
    'Nigeria', 'Ouganda', 'République centrafricaine',
    'République démocratique du Congo', 'Rwanda', 'Sao Tomé-et-Principe',
    'Sénégal', 'Seychelles', 'Sierra Leone', 'Somalie', 'Soudan',
    'Soudan du Sud', 'Tanzanie', 'Tchad', 'Togo', 'Tunisie', 'Zambie',
    'Zimbabwe', 'Autre',
  ];

  @override
  void initState() {
    super.initState();
    _step = widget.initialStep ?? 1;
    if (_step == 3) _step = 2;
    debugPrint('[Registration] 🚀 Page opened at step $_step');
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
    _honeypotC.dispose();
    _resendTimer?.cancel();
    _passwordDebounce?.cancel();
    _chatDebounce?.cancel();
    debugPrint('[Registration] 👋 Page disposed');
    super.dispose();
  }

  // ── FEEDBACK ─────────────────────────────────────────────────────────
  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: ThixPolicy.bodyStyle.copyWith(color: Colors.white),
            ),
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
            child: Text(
              message,
              style: ThixPolicy.bodyStyle.copyWith(color: Colors.white),
            ),
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
            child: Text(
              message,
              style: ThixPolicy.bodyStyle.copyWith(color: Colors.white),
            ),
          ),
        ]),
        backgroundColor: ThixPolicy.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ── VALIDATION TEMPS RÉEL ─────────────────────────────────────────
  Future<void> _onChatChanged(String value) async {
    final l10n = AppLocalizations.of(context);
    _chatDebounce?.cancel();
    final raw = _RegValidators.sanitize(
      value.trim().toLowerCase(),
      maxLength: _kMaxChatLength,
    );

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

    _chatDebounce = Timer(
      const Duration(milliseconds: _kChatDebounceMs),
      () async {
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
          debugPrint('[Registration] ⚠️ Chat live validation error: $e');
          if (!mounted) return;
          setState(() => _chatValidating = false);
        }
      },
    );
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
    setState(() => _passwordValidating = true);

    _passwordDebounce = Timer(
      const Duration(milliseconds: _kPasswordDebounceMs),
      () async {
        final sanitizedPass =
            _RegValidators.sanitize(value, maxLength: _kMaxPasswordLength);
        final email = _RegValidators.sanitize(
          _emailC.text.trim().toLowerCase(),
          maxLength: _kMaxEmailLength,
        );
        final name =
            _RegValidators.sanitize(_nameC.text.trim(), maxLength: _kMaxNameLength);
        final phone =
            _RegValidators.sanitize(_phoneC.text.trim(), maxLength: _kMaxPhoneLength);

        final result = await PasswordPolicy.validate(
          sanitizedPass,
          email: email,
          fullName: name,
          phone: phone,
        );

        if (!mounted) return;

        final score = PasswordPolicy.evaluateStrength(
          sanitizedPass,
          [email, name.toLowerCase()],
        );

        String? errorMsg;
        switch (result.code) {
          case PasswordErrorCode.tooShort:
            errorMsg =
                '${l10n.t('reg_password_too_short')} $_kMinPasswordLength';
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
      },
    );
  }

  // ── NAVIGATION ─────────────────────────────────────────────────────
  Future<void> _goToStep2() async {
    final l10n = AppLocalizations.of(context);
    if (_busy) return;

    // 🤖 Anti-bot check
    final botError = _antiBot.check(l10n);
    if (botError != null) {
      _showError(botError);
      _antiBot.registerFailure();
      return;
    }

    final name =
        _RegValidators.sanitize(_nameC.text.trim(), maxLength: _kMaxNameLength);
    final dob = _RegValidators.sanitize(_dobC.text.trim(), maxLength: 20);

    if (name.length < _kMinNameLength || name.length > _kMaxNameLength) {
      _showError(l10n.t('reg_error_name_invalid'));
      _antiBot.registerFailure();
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
        ((today.month < parsed.month ||
                (today.month == parsed.month && today.day < parsed.day))
            ? 1
            : 0);
    if (age < _kMinAgeYears) {
      _showError(l10n.t('reg_error_underage'));
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

    HapticFeedback.selectionClick();
    setState(() => _step = 2);
    debugPrint('[Registration] ➡️ Step 2');
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

  // ── AUTH & OTP ─────────────────────────────────────────────────────
  Future<bool> _createAuthUser() async {
    final l10n = AppLocalizations.of(context);
    final email = _RegValidators.sanitize(
      _emailC.text.trim().toLowerCase(),
      maxLength: _kMaxEmailLength,
    );
    final phone = _RegValidators.sanitize(
      _phoneC.text.trim().replaceAll(RegExp(r'[\s.-]'), ''),
      maxLength: _kMaxPhoneLength,
    );
    final pass =
        _RegValidators.sanitize(_passwordC.text, maxLength: _kMaxPasswordLength);
    final confirm =
        _RegValidators.sanitize(_confirmC.text, maxLength: _kMaxPasswordLength);
    final name =
        _RegValidators.sanitize(_nameC.text.trim(), maxLength: _kMaxNameLength);

    if (!_RegValidators.isValidEmail(email)) {
      _showError(l10n.t('reg_error_email_invalid'));
      _antiBot.registerFailure();
      return false;
    }
    if (phone.isNotEmpty && !_RegValidators.isValidPhone(phone)) {
      _showError(l10n.t('reg_error_phone_invalid'));
      _antiBot.registerFailure();
      return false;
    }

    final passResult = await PasswordPolicy.validate(
      pass,
      email: email,
      fullName: name,
      phone: phone,
    );
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
      _antiBot.registerFailure();
      return false;
    }

    if (pass != confirm) {
      _showError(l10n.t('reg_error_passwords_mismatch'));
      _antiBot.registerFailure();
      return false;
    }

    try {
      await ref.read(authControllerProvider.notifier).registerPersonal(
            email: email,
            password: pass,
            displayName: name,
            rememberMe: true,
            profileDraft: {
              'full_name': name,
              'date_of_birth':
                  _RegValidators.sanitize(_dobC.text.trim(), maxLength: 20),
              'country_or_origin': _country,
              'occupation': _occupationC.text.trim().isEmpty
                  ? null
                  : _RegValidators.sanitize(
                      _occupationC.text.trim(),
                      maxLength: _kMaxOccupationLength,
                    ),
              'phone_number': phone.isEmpty ? null : phone,
              'registration_status': 'draft_step2',
              'account_status': 'pending',
              'terms_accepted_at': DateTime.now().toUtc().toIso8601String(),
              'privacy_accepted_at': DateTime.now().toUtc().toIso8601String(),
            },
          );
      return true;
    } catch (e) {
      final message = e.toString().toLowerCase();
      if (message.contains('otpsent') ||
          message.contains('otp_sent') ||
          message.contains('nouveau code') ||
          message.contains('confirm') ||
          message.contains('inscription enregistrée')) {
        return true;
      }
      _showError(_translateAuthError(e, l10n));
      _antiBot.registerFailure();
      return false;
    }
  }

  Future<void> _sendOtp() async {
    final l10n = AppLocalizations.of(context);
    if (_busy || _resendCooldown > 0) return;

    // 🤖 Anti-bot check avant envoi OTP
    final botError = _antiBot.check(l10n);
    if (botError != null) {
      _showError(botError);
      _antiBot.registerFailure();
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    debugPrint('[Registration] 📧 Sending OTP...');

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

      final success = await _createAuthUser();
      if (!success || !mounted) return;

      setState(() => _otpSent = true);
      _startResendCooldown();
      _showSuccess(l10n.t('reg_otp_sent'));
      debugPrint('[Registration] ✓ OTP sent');
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
      debugPrint('[Registration] ⚠️ Refresh email error: $e');
      final ok =
          Supabase.instance.client.auth.currentUser?.emailConfirmedAt != null;
      _emailVerified = ok;
      return ok;
    }
  }

  String _desiredChat() {
    final raw = _RegValidators.sanitize(
      _thixChatC.text.trim().toLowerCase(),
      maxLength: _kMaxChatLength,
    );
    if (raw.isNotEmpty) {
      final normalized = _RegValidators.normalizeChat(raw);
      if (_RegValidators.isValidThixChat(normalized)) return normalized;
    }
    final name =
        _RegValidators.sanitize(_nameC.text.trim(), maxLength: _kMaxNameLength);
    final first = name.split(RegExp(r'\s+')).first.toLowerCase();
    final safe = first.replaceAll(RegExp(r'[^a-z0-9._]'), '');
    final base =
        safe.length >= 3 ? safe.substring(0, safe.length.clamp(0, 12)) : 'user';
    final generated = '@$base${DateTime.now().millisecondsSinceEpoch % 10000}';
    return _RegValidators.isValidThixChat(generated)
        ? generated
        : '@user${DateTime.now().millisecondsSinceEpoch % 100000}';
  }

  Future<void> _verifyAndActivate() async {
    final l10n = AppLocalizations.of(context);
    if (_busy) return;

    // 🤖 Anti-bot check avant activation finale
    final botError = _antiBot.check(l10n);
    if (botError != null) {
      _showError(botError);
      _antiBot.registerFailure();
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

    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    debugPrint('[Registration] 🔐 Verifying and activating account...');

    try {
      final notifier = ref.read(authControllerProvider.notifier);
      bool isVerified = await _refreshEmailVerifiedFlag();

      if (!isVerified) {
        if (!_otpSent) {
          _showError(l10n.t('reg_error_request_otp_first'));
          setState(() => _busy = false);
          return;
        }
        final code =
            _RegValidators.sanitize(_otpC.text.trim(), maxLength: _kMaxOtpLength);
        if (!RegExp(r'^\d{8}$').hasMatch(code)) {
          _showError(l10n.t('reg_error_otp_format'));
          setState(() => _busy = false);
          return;
        }

        await notifier.verifyOTP(
          email: _RegValidators.sanitize(
            _emailC.text.trim().toLowerCase(),
            maxLength: _kMaxEmailLength,
          ),
          token: code,
        );

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

      if (officialThixId.isEmpty ||
          officialThixId.toUpperCase().startsWith('THIX-PENDING')) {
        throw Exception('thix_id_failed');
      }

      try {
        await notifier.refreshCurrentUser();
      } catch (_) {}

      if (!mounted) return;

      setState(() {
        _thixIdGenerated = officialThixId;
        _thixChatC.text = claimedChat;
        _step = 3;
      });

      _showSuccess(l10n.t('reg_account_activated'));
      debugPrint('[Registration] ✓ Account activated: $officialThixId');
    } catch (e) {
      debugPrint('[Registration] ❌ Activation error: $e');
      if (mounted) _showError(_translateAuthError(e, l10n));
      _antiBot.registerFailure();
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
          colorScheme: Theme.of(context)
              .colorScheme
              .copyWith(primary: ThixPolicy.primary),
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
      setState(() => _step -= 1);
      debugPrint('[Registration] ⬅️ Back to step $_step');
    } else {
      await ref.read(authControllerProvider.notifier).signOut();
      if (mounted) context.go(AppRoutes.login);
    }
  }

  void _goToDashboard() {
    HapticFeedback.mediumImpact();
    debugPrint('[Registration] 🚀 Going to dashboard');
    context.go(AppRoutes.userDashboard);
  }

  void _openPolicy(String slug) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PolicyViewerPage(slug: slug)),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isLoading = ref.watch(authControllerProvider).isLoading || _busy;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // fond très clair
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            // ── HEADER ÉPURÉ ──
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 70, 24, 28),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                  ),
                ),
                child: Column(
                  children: [
                    // Logo + nom
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF1E3A8A),
                                Color(0xFF3B82F6),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF3B82F6).withOpacity(0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'T',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
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
                    const SizedBox(height: 24),
                    _buildStepper(),
                  ],
                ),
              ),
            ),

            // ── CONTENU ──
            Positioned.fill(
              top: 180,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                    const SizedBox(height: 20),
                    _buildMainButton(isLoading, l10n),
                    const SizedBox(height: 12),
                    if (_step < 3)
                      Center(
                        child: Semantics(
                          button: true,
                          label: _step == 1
                              ? l10n.t('reg_change_account')
                              : l10n.t('reg_previous_step'),
                          child: TextButton(
                            onPressed: isLoading ? null : _goBack,
                            style: TextButton.styleFrom(
                              foregroundColor: ThixPolicy.textSecondary,
                            ),
                            child: Text(
                              _step == 1
                                  ? l10n.t('reg_change_account')
                                  : l10n.t('reg_previous_step'),
                              style: ThixPolicy.bodyStyle.copyWith(
                                fontWeight: ThixPolicy.semiBold,
                              ),
                            ),
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

  Widget _buildStepper() {
    return Semantics(
      label: 'Stepper',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StepDot(isActive: true, isDone: _step > 1, number: 1),
          const _StepLine(isActive: false),
          _StepDot(isActive: _step >= 2, isDone: _step > 2, number: 2),
          const _StepLine(isActive: false),
          _StepDot(
            isActive: _step == 3,
            isDone: _step == 3,
            number: 3,
            isFinal: true,
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
          onAcceptedTermsChanged: (v) =>
              setState(() => _acceptedTerms = v ?? false),
          onAcceptedPrivacyChanged: (v) =>
              setState(() => _acceptedPrivacy = v ?? false),
          onOpenTerms: () => _openPolicy('terms'),
          onOpenPrivacy: () => _openPolicy('privacy'),
          honeypotC: _honeypotC,
          onHoneypotChanged: (v) => _antiBot.setHoneypot(v),
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
          name: _RegValidators.sanitize(
              _nameC.text.trim(),
              maxLength: _kMaxNameLength),
          email: _RegValidators.sanitize(
              _emailC.text.trim(),
              maxLength: _kMaxEmailLength),
          phone: _RegValidators.sanitize(
              _phoneC.text.trim(),
              maxLength: _kMaxPhoneLength),
          dob: _RegValidators.sanitize(_dobC.text.trim(), maxLength: 20),
          country: _country ?? '',
          occupation: _RegValidators.sanitize(
              _occupationC.text.trim(),
              maxLength: _kMaxOccupationLength),
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
        label = isLoading
            ? l10n.t('reg_activating')
            : l10n.t('reg_validate_activate');
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

    final bool step1Blocked =
        _step == 1 && (!_acceptedTerms || !_acceptedPrivacy);

    return Semantics(
      button: true,
      label: label,
      enabled: !isLoading && !step1Blocked,
      child: ElevatedButton(
        onPressed: (isLoading || step1Blocked) ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: ThixPolicy.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: ThixPolicy.primary.withOpacity(0.4),
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
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Text(
              label,
              style: ThixPolicy.bodyStyle.copyWith(
                fontWeight: ThixPolicy.bold,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
            if (!isLoading && _step < 3)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// STEPPER COMPONENTS
// ════════════════════════════════════════════════════════════════════════
class _StepDot extends StatelessWidget {
  final bool isActive;
  final bool isDone;
  final int number;
  final bool isFinal;

  const _StepDot({
    required this.isActive,
    required this.isDone,
    required this.number,
    this.isFinal = false,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = ThixPolicy.primary;
    final inactiveColor = const Color(0xFFD1D5DB);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: isDone || isActive ? activeColor : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive || isDone ? activeColor : inactiveColor,
          width: 1.5,
        ),
      ),
      child: Center(
        child: isDone
            ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
            : Text(
                '$number',
                style: TextStyle(
                  color: isActive ? Colors.white : inactiveColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
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
      width: 40,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: isActive ? ThixPolicy.primary : const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// STEP 1 — PROFIL
// ════════════════════════════════════════════════════════════════════════
class _Step1Profile extends StatelessWidget {
  final TextEditingController nameC;
  final TextEditingController dobC;
  final TextEditingController occupationC;
  final TextEditingController honeypotC;
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
  final ValueChanged<String> onHoneypotChanged;

  const _Step1Profile({
    required this.nameC,
    required this.dobC,
    required this.occupationC,
    required this.honeypotC,
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
    required this.onHoneypotChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.t('reg_step1_title'),
          style: ThixPolicy.h2Style.copyWith(
            color: ThixPolicy.inkDeep,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.t('reg_step1_subtitle'),
          style: ThixPolicy.bodySmallStyle.copyWith(
            color: ThixPolicy.textSecondary,
          ),
        ),
        const SizedBox(height: 28),

        // 🤖 HONEYPOT (invisible aux humains, rempli par les bots)
        _CleanField(
          label: '',
          hint: '',
          icon: Icons.person,
          controller: honeypotC,
          onChanged: onHoneypotChanged,
          obscure: true,
          autofillHint: AutofillHints.name,
        ),

        _CleanField(
          label: l10n.t('reg_full_name_label'),
          hint: l10n.t('reg_full_name_hint'),
          icon: Icons.person_outline_rounded,
          controller: nameC,
          maxLength: _kMaxNameLength,
          autofillHint: AutofillHints.name,
        ),
        const SizedBox(height: 16),
        _CleanField(
          label: l10n.t('reg_dob_label'),
          hint: 'AAAA-MM-JJ',
          icon: Icons.calendar_today_outlined,
          controller: dobC,
          readOnly: true,
          onTap: onPickDob,
          trailing: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: ThixPolicy.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        _CleanDropdown(
          label: l10n.t('reg_country_label'),
          icon: Icons.public_outlined,
          value: country,
          items: countries,
          onChanged: onCountryChanged,
        ),
        const SizedBox(height: 16),
        _CleanField(
          label: l10n.t('reg_occupation_label'),
          hint: l10n.t('reg_occupation_hint'),
          icon: Icons.work_outline_rounded,
          controller: occupationC,
          maxLength: _kMaxOccupationLength,
          autofillHint: AutofillHints.organizationName,
        ),
        const SizedBox(height: 28),
        const Divider(color: Color(0xFFE5E7EB), height: 1),
        const SizedBox(height: 20),

        // ── CONSENTEMENTS ──
        _ConsentCheckboxRow(
          value: acceptedTerms,
          onChanged: onAcceptedTermsChanged,
          prefixText: l10n.t('auth_accept_terms'),
          linkText: l10n.t('settings_terms'),
          onLinkTap: onOpenTerms,
          semanticsLabel: l10n.t('settings_terms'),
        ),
        const SizedBox(height: 12),
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

class _ConsentCheckboxRow extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Semantics(
      label: '$semanticsLabel — ${value ? "accepté" : "non accepté"}',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(!value);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Transform.translate(
                offset: const Offset(-4, 0),
                child: Checkbox(
                  value: value,
                  onChanged: onChanged,
                  activeColor: ThixPolicy.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: RichText(
                    text: TextSpan(
                      style: ThixPolicy.bodySmallStyle.copyWith(
                        color: ThixPolicy.textMain,
                      ),
                      children: [
                        TextSpan(text: '$prefixText '),
                        TextSpan(
                          text: linkText,
                          style: ThixPolicy.bodySmallStyle.copyWith(
                            color: ThixPolicy.primary,
                            fontWeight: ThixPolicy.semiBold,
                          ),
                          recognizer: (TapGestureRecognizer()..onTap = onLinkTap),
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

// ════════════════════════════════════════════════════════════════════════
// STEP 2 — COMPTE
// ════════════════════════════════════════════════════════════════════════
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canResend = !isLoading && resendCountdown == 0;
    final bars =
        passwordScore < 0 ? 0 : (passwordScore == 0 ? 1 : passwordScore);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.t('reg_step2_title'),
          style: ThixPolicy.h2Style.copyWith(
            color: ThixPolicy.inkDeep,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.t('reg_step2_subtitle'),
          style: ThixPolicy.bodySmallStyle.copyWith(
            color: ThixPolicy.textSecondary,
          ),
        ),
        const SizedBox(height: 28),

        // ── BANNIÈRE OTP PERMANENTE ──
        if (isOtpSent) ...[
          _OtpInfoBanner(
            email: emailC.text.trim().toLowerCase(),
          ),
          const SizedBox(height: 20),
        ],

        _CleanField(
          label: l10n.t('reg_email_label'),
          hint: l10n.t('reg_email_hint'),
          icon: Icons.email_outlined,
          controller: emailC,
          keyboardType: TextInputType.emailAddress,
          maxLength: _kMaxEmailLength,
          autofillHint: AutofillHints.email,
        ),
        const SizedBox(height: 16),
        _CleanField(
          label: l10n.t('reg_phone_label'),
          hint: l10n.t('reg_phone_hint'),
          icon: Icons.phone_android_outlined,
          controller: phoneC,
          keyboardType: TextInputType.phone,
          maxLength: _kMaxPhoneLength,
          autofillHint: AutofillHints.telephoneNumber,
        ),
        const SizedBox(height: 16),
        _CleanField(
          label: l10n.t('reg_password_label'),
          hint: l10n.t('reg_password_hint'),
          icon: Icons.lock_outline_rounded,
          controller: passwordC,
          isPassword: true,
          onChanged: onPasswordChanged,
          errorText: passwordError,
          maxLength: _kMaxPasswordLength,
          autofillHint: AutofillHints.newPassword,
          trailing: passwordValidating
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : null,
        ),
        if (passwordScore >= 0 && passwordC.text.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            children: List.generate(4, (i) {
              final active = i < bars;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i == 3 ? 0 : 4),
                  decoration: BoxDecoration(
                    color: active ? _scoreColor(passwordScore) : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Text(
            '${l10n.t('reg_strength_label')}: ${_scoreLabel(passwordScore, l10n)}',
            style: ThixPolicy.captionStyle.copyWith(
              color: _scoreColor(passwordScore),
              fontWeight: ThixPolicy.medium,
            ),
          ),
        ],
        const SizedBox(height: 16),
        _CleanField(
          label: l10n.t('reg_confirm_password_label'),
          hint: l10n.t('reg_confirm_password_hint'),
          icon: Icons.lock_outline_rounded,
          controller: confirmC,
          isPassword: true,
          maxLength: _kMaxPasswordLength,
          autofillHint: AutofillHints.newPassword,
        ),
        const SizedBox(height: 28),
        const Divider(color: Color(0xFFE5E7EB), height: 1),
        const SizedBox(height: 20),
        Text(
          l10n.t('reg_identity_title'),
          style: ThixPolicy.h3Style.copyWith(
            color: ThixPolicy.inkDeep,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        _CleanField(
          label: l10n.t('reg_thix_chat_label'),
          hint: l10n.t('reg_thix_chat_hint'),
          icon: Icons.alternate_email_rounded,
          controller: thixChatC,
          onChanged: onChatChanged,
          errorText: chatError,
          helperText: chatSuccess,
          helperStyle: ThixPolicy.bodySmallStyle.copyWith(
            color: ThixPolicy.success,
            fontWeight: ThixPolicy.semiBold,
          ),
          maxLength: _kMaxChatLength,
          trailing: chatValidating
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : (chatSuccess != null
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: ThixPolicy.success,
                      size: 18,
                    )
                  : null),
        ),
        const SizedBox(height: 28),
        const Divider(color: Color(0xFFE5E7EB), height: 1),
        const SizedBox(height: 20),
        Text(
          l10n.t('reg_verification_title'),
          style: ThixPolicy.h3Style.copyWith(
            color: ThixPolicy.inkDeep,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          button: true,
          label: l10n.t('reg_get_otp'),
          enabled: canResend,
          child: SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: canResend ? onSendOtp : null,
              icon: Icon(
                isOtpSent
                    ? Icons.check_circle_outline_rounded
                    : Icons.send_rounded,
                size: 18,
              ),
              label: Text(
                !canResend && resendCountdown > 0
                    ? '${l10n.t('reg_resend_in')} $resendCountdown${l10n.t('reg_seconds_short')}'
                    : (isOtpSent
                        ? l10n.t('reg_code_sent_resend')
                        : l10n.t('reg_get_otp')),
                style: ThixPolicy.bodyStyle.copyWith(
                  fontWeight: ThixPolicy.semiBold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: ThixPolicy.primary,
                side: BorderSide(
                  color: isOtpSent ? ThixPolicy.success : ThixPolicy.primary,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        if (isOtpSent) ...[
          const SizedBox(height: 20),
          _CleanField(
            label: l10n.t('reg_otp_label'),
            hint: '00000000',
            icon: Icons.confirmation_number_outlined,
            controller: otpC,
            keyboardType: TextInputType.number,
            maxLength: _kMaxOtpLength,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofillHint: AutofillHints.oneTimeCode,
          ),
        ],
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// STEP 3 — FINAL
// ════════════════════════════════════════════════════════════════════════
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThixPolicy.success.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: ThixPolicy.success,
              size: 48,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          l10n.t('reg_congrats'),
          textAlign: TextAlign.center,
          style: ThixPolicy.h2Style.copyWith(
            color: ThixPolicy.inkDeep,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${l10n.t('reg_welcome_message')} $name',
          textAlign: TextAlign.center,
          style: ThixPolicy.bodyStyle.copyWith(
            color: ThixPolicy.textSecondary,
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
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
                  const SizedBox(height: 16),
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
                          thixId.isEmpty
                              ? l10n.t('reg_generating')
                              : thixId,
                          style: ThixPolicy.bodyStyle.copyWith(
                            color: Colors.white,
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
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(
                                Icons.copy_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'THIX CHAT',
                    style: ThixPolicy.microStyle.copyWith(
                      color: Colors.white70,
                      fontWeight: ThixPolicy.bold,
                      fontSize: 10,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    thixChat,
                    style: ThixPolicy.bodyStyle.copyWith(
                      color: Colors.white,
                      fontWeight: ThixPolicy.semiBold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          l10n.t('reg_summary'),
          style: ThixPolicy.h3Style.copyWith(
            color: ThixPolicy.inkDeep,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              _SummaryRow(label: l10n.t('reg_full_name_label'), value: name),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              _SummaryRow(label: l10n.t('reg_email_label'), value: email),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              _SummaryRow(
                label: l10n.t('reg_mobile_label'),
                value: phone.isEmpty ? l10n.t('reg_not_provided') : phone,
              ),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              _SummaryRow(label: l10n.t('reg_dob_label'), value: dob),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              _SummaryRow(label: l10n.t('reg_country_label'), value: country),
              if (occupation.isNotEmpty) ...[
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                _SummaryRow(
                  label: l10n.t('reg_occupation_label'),
                  value: occupation,
                ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: ThixPolicy.bodySmallStyle.copyWith(
                fontWeight: ThixPolicy.medium,
                color: ThixPolicy.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value.isEmpty ? '—' : value,
              textAlign: TextAlign.right,
              style: ThixPolicy.bodySmallStyle.copyWith(
                color: ThixPolicy.textMain,
                fontWeight: ThixPolicy.semiBold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
