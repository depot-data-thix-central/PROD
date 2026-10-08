// lib/presentation/auth/personal_registration_page.dart
//
// THIX HUB — Inscription v3 : Google (email détecté et vérifié) au lieu de l'OTP
// Étape 1 : conditions + "Continuer avec Google"
// Étape 2 : nom, date de naissance, pays, THIX Chat, mot de passe → Enregistrer
// Étape 3 : confirmation (THIX ID)
// Sécurité conservée : champ piège, délai humain, blocage temporaire,
// zxcvbn >= 3, contrôle HIBP, mot de passe jamais modifié ni conservé.

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;
import 'package:zxcvbn/zxcvbn.dart';
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
const int _kMaxChatLength = 21; // @ + 20 caractères
const int _kHibpTimeoutSeconds = 6;
const int _kHibpMaxRetries = 2;
const int _kMinAgeYears = 18;
const int _kMaxAgeYears = 110;
const int _kChatDebounceMs = 600;
const int _kPasswordDebounceMs = 400;
const int _kMinPasswordScore = 3; // zxcvbn 0..4

// Anti-bot
const int _kMinStep1Seconds = 3;
const int _kMinStep2Seconds = 6;
const int _kMaxFinalizeAttempts = 6;
const int _kFinalizeLockSeconds = 300;

/// Lien de retour OAuth (scheme "thix" déjà déclaré dans le Manifest).
/// À ajouter dans Supabase → Authentication → URL Configuration → Redirect URLs.
const String _kOAuthRedirect = 'thix://login-callback';

const List<String> _kReservedChats = [
  '@admin', '@thix', '@thixhub', '@support', '@root', '@system',
  '@officiel', '@help', '@moderator', '@central',
];

// ============================================================================
// i18n : clé l10n d'abord, sinon repli [EN, FR]
// ============================================================================
const Map<String, List<String>> _kRegFb = {
  'reg_google_continue': ['Continue with Google', 'Continuer avec Google'],
  'reg_google_hint': [
    'Your email is detected and verified by Google. No code to type.',
    'Votre email est détecté et vérifié par Google. Aucun code à saisir.',
  ],
  'reg_google_waiting': [
    'Finish signing in with Google, then come back to the app.',
    'Terminez la connexion avec Google, puis revenez dans l’application.',
  ],
  'reg_google_failed': [
    'Google sign-in failed. Please try again.',
    'La connexion Google a échoué. Veuillez réessayer.',
  ],
  'reg_email_detected': ['Detected email', 'Email détecté'],
  'reg_save': ['Save', 'Enregistrer'],
  'reg_saving': ['Saving…', 'Enregistrement…'],
  'reg_session_lost': [
    'Your Google session expired. Please sign in again.',
    'Votre session Google a expiré. Reconnectez-vous.',
  ],
  'reg_error_chat_required': ['Choose your THIX Chat.', 'Choisissez votre THIX Chat.'],
  'reg_error_too_many_attempts': [
    'Too many attempts. Try again in {0}.',
    'Trop de tentatives. Réessayez dans {0}.',
  ],
  'reg_error_wait_a_moment': ['Please take a moment and try again.', 'Veuillez patienter un instant puis réessayer.'],
  'reg_error_password_chars': ['Password contains invalid characters.', 'Le mot de passe contient des caractères invalides.'],
  'reg_error_name_chars': ['Name can only contain letters.', 'Le nom ne peut contenir que des lettres.'],
  'reg_step_of': ['Step {0} of 3', 'Étape {0} sur 3'],
  'reg_minutes_short': ['min', 'min'],
  'reg_step1_google_title': ['Create your account', 'Créez votre compte'],
  'reg_step2_save_title': ['Complete your profile', 'Complétez votre profil'],
  'reg_step2_save_subtitle': [
    'Choose your name, THIX Chat and password.',
    'Choisissez votre nom, THIX Chat et mot de passe.',
  ],
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
// ANTI-ABUS : compteurs d'essais persistés
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
  static final RegExp _bidi = RegExp(r'[\u200B\u200E\u200F\u202A-\u202E\u2066-\u2069\uFEFF]');
  static final RegExp _tags = RegExp(r'<[a-zA-Z/!?][^>]*>');
  static final RegExp _jsScheme = RegExp(r'(javascript|vbscript)\s*:', caseSensitive: false);

  /// Sanitise une saisie TEXTE. Ne pas utiliser pour un mot de passe.
  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    var s = input.replaceAll(_tags, '').replaceAll(_jsScheme, '').replaceAll(_ctrlKeepTab, '').replaceAll(_bidi, '').trim();
    if (s.length > maxLength) {
      var end = maxLength;
      final unit = s.codeUnitAt(end - 1);
      if (unit >= 0xD800 && unit <= 0xDBFF) end--;
      s = s.substring(0, end);
    }
    return s;
  }

  /// Mot de passe : jamais modifié.
  static bool isSafePassword(String p) =>
      p.length <= _kMaxPasswordLength && !_ctrl.hasMatch(p) && !_bidi.hasMatch(p);

  static bool isValidName(String name) =>
      RegExp(r"^[\p{L}\p{M}][\p{L}\p{M}' .\-]{1,}$", unicode: true).hasMatch(name);

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
// ERREURS
// ============================================================================
String _translateAuthError(Object e, AppLocalizations l10n) {
  final msg = e.toString().toLowerCase();

  if (msg.contains('configuration serveur')) return l10n.t('reg_error_supabase_config');
  if (msg.contains('23505') || msg.contains('unique constraint')) {
    if (msg.contains('thix_chat')) return l10n.t('reg_error_chat_taken');
    if (msg.contains('thix_id')) return l10n.t('reg_error_thix_id_failed');
    return l10n.t('reg_error_info_used');
  }
  if (msg.contains('invalid_chat') || msg.contains('reserved') || msg.contains('réservé')) {
    return l10n.t('reg_error_chat_reserved');
  }
  if (msg.contains('chat_taken')) return l10n.t('reg_error_chat_taken');
  if (msg.contains('thix_id_failed')) return l10n.t('reg_error_thix_id_failed');
  if (msg.contains('rate limit') || msg.contains('too many')) return l10n.t('reg_error_rate_limit');
  if (msg.contains('network') || msg.contains('timeout') || msg.contains('unavailable') || msg.contains('socket')) {
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
  final int score;

  const PasswordValidationResult({required this.code, this.score = 0});

  bool get isValid => code == PasswordErrorCode.valid;
}

class PasswordPolicy {
  static const int minLength = _kMinPasswordLength;

  static Future<PasswordValidationResult> validate(
    String password, {
    required String email,
    required String fullName,
  }) async {
    if (password.length < minLength) {
      return const PasswordValidationResult(code: PasswordErrorCode.tooShort);
    }

    final userInputs = [email, fullName].where((s) => s.isNotEmpty).map((s) => s.toLowerCase()).toList();
    final result = Zxcvbn().evaluate(password, userInputs: userInputs);
    final score = (result.score ?? 0).toInt();

    if (score < _kMinPasswordScore) {
      return PasswordValidationResult(code: PasswordErrorCode.tooWeak, score: score);
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
            return (int.tryParse(parts[1].trim()) ?? 0) >= 1;
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
// DESIGN COMPONENTS
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
          label: widget.label,
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
              fillColor: widget.readOnly && widget.onTap == null ? ThixPolicy.surfaceSoft : Colors.white,
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
  final _emailC = TextEditingController(); // email Google (lecture seule)
  final _passwordC = TextEditingController();
  final _confirmC = TextEditingController();
  final _thixChatC = TextEditingController();
  final _honeyC = TextEditingController(); // champ piège

  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;
  bool _consentInStep2 = false;

  String _thixIdGenerated = '';

  String? _passwordError;
  bool _passwordValidating = false;
  int _passwordScore = -1;
  Timer? _passwordDebounce;

  String? _chatError;
  String? _chatSuccess;
  bool _chatValidating = false;
  Timer? _chatDebounce;

  bool _googleWaiting = false;
  bool _handlingSession = false;
  bool _busy = false;
  int _step = 1;

  StreamSubscription<AuthState>? _authSub;
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

  SupabaseClient get _sb => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _step = widget.initialStep ?? 1;
    if (_step == 3) _step = 2;
    _stepEnteredAt = DateTime.now();

    // Retour de Google (deep link) → on passe à l'étape 2
    _authSub = _sb.auth.onAuthStateChange.listen((s) {
      if (s.event == AuthChangeEvent.signedIn && s.session != null && _step == 1) {
        unawaited(_handleSignedIn());
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _sb.auth.currentUser != null) {
        unawaited(_handleSignedIn());
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _nameC.dispose();
    _dobC.dispose();
    _emailC.dispose();
    _passwordC.dispose();
    _confirmC.dispose();
    _thixChatC.dispose();
    _honeyC.dispose();
    _passwordDebounce?.cancel();
    _chatDebounce?.cancel();
    super.dispose();
  }

  void _enterStep(int s) {
    setState(() => _step = s);
    _stepEnteredAt = DateTime.now();
  }

  // ── FEEDBACK ──────────────────────────────────────────────────────────────
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
  bool get _looksLikeBot => _honeyC.text.trim().isNotEmpty;

  Future<bool> _notBlocked(String key) async {
    final s = await _Throttle.blockedSeconds(key);
    if (s > 0 && mounted) {
      _showError(_tx(context, 'reg_error_too_many_attempts', args: [_fmtWait(context, s)]));
      return false;
    }
    return true;
  }

  bool _humanDelayOk(int minSeconds) => DateTime.now().difference(_stepEnteredAt).inSeconds >= minSeconds;

  // ── GOOGLE ────────────────────────────────────────────────────────────────
  Future<void> _signInWithGoogle() async {
    if (_busy) return;

    if (_looksLikeBot || !_humanDelayOk(_kMinStep1Seconds)) {
      _showError(_tx(context, 'reg_error_wait_a_moment'));
      return;
    }
    if (!_acceptedTerms || !_acceptedPrivacy) {
      _showError(AppLocalizations.of(context).t('auth_terms_required'));
      return;
    }

    // Déjà connecté avec Google (retour d'une autre session) → on continue
    if (_sb.auth.currentUser != null) {
      await _handleSignedIn();
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    try {
      await _sb.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : _kOAuthRedirect,
        authScreenLaunchMode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
        queryParams: const {'prompt': 'select_account'},
      );
      if (mounted) {
        setState(() => _googleWaiting = true);
        _showInfo(_tx(context, 'reg_google_waiting'));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Registration] Google error: $e');
      if (mounted) _showError(_tx(context, 'reg_google_failed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Session Google disponible : détecte l'email, vérifie que le compte n'est pas
  /// déjà actif, marque le brouillon d'inscription, puis ouvre l'étape 2.
  Future<void> _handleSignedIn() async {
    if (_handlingSession || _step >= 3) return;
    final user = _sb.auth.currentUser;
    if (user == null) return;
    _handlingSession = true;

    try {
      final email = (user.email ?? '').trim().toLowerCase();

      // Étape 2 déjà affichée (reprise) : on remplit seulement l'email
      if (_step == 2) {
        if (mounted) setState(() => _emailC.text = email);
        return;
      }

      // Compte déjà finalisé ? → tableau de bord
      try {
        final p = await _sb.from('profiles').select('thix_id').eq('id', user.id).maybeSingle();
        final thixId = (p?['thix_id'] as String?)?.trim() ?? '';
        if (thixId.isNotEmpty && !thixId.toUpperCase().startsWith('THIX-PENDING')) {
          if (mounted) context.go(AppRoutes.userDashboard);
          return;
        }
      } catch (_) {}

      // Marque l'inscription comme "en cours" (comme l'ancien flux)
      try {
        await _sb.from('profiles').upsert({
          'id': user.id,
          'registration_status': 'draft_step2',
          'account_status': 'pending',
        });
      } catch (e) {
        if (kDebugMode) debugPrint('[Registration] draft upsert: $e');
      }

      if (!mounted) return;

      // Préremplit le nom depuis Google (modifiable)
      final meta = user.userMetadata ?? const <String, dynamic>{};
      final googleName = _RegValidators.sanitize(
        (meta['full_name'] ?? meta['name'] ?? '').toString(),
        maxLength: _kMaxNameLength,
      );

      setState(() {
        _googleWaiting = false;
        _emailC.text = email;
        if (_nameC.text.isEmpty && googleName.isNotEmpty) _nameC.text = googleName;
        _consentInStep2 = !_acceptedTerms || !_acceptedPrivacy;
      });
      _enterStep(2);
    } finally {
      _handlingSession = false;
    }
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
        final myId = _sb.auth.currentUser?.id;
        final res = await _sb.from('profiles').select('id').ilike('thix_chat', chat).maybeSingle();

        if (!mounted) return;

        // Pris par quelqu'un d'autre (pas par moi)
        if (res != null && res['id']?.toString() != myId) {
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
      final email = _emailC.text.trim().toLowerCase();
      final name = _RegValidators.sanitize(_nameC.text.trim(), maxLength: _kMaxNameLength);

      final result = await PasswordPolicy.validate(value, email: email, fullName: name);
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

  // ── ENREGISTRER ───────────────────────────────────────────────────────────
  Future<void> _saveAndActivate() async {
    final l10n = AppLocalizations.of(context);
    if (_busy) return;

    if (_looksLikeBot || !_humanDelayOk(_kMinStep2Seconds)) {
      _showError(_tx(context, 'reg_error_wait_a_moment'));
      return;
    }

    final user = _sb.auth.currentUser;
    if (user == null) {
      _showError(_tx(context, 'reg_session_lost'));
      _enterStep(1);
      return;
    }
    if (user.emailConfirmedAt == null) {
      _showError(l10n.t('reg_error_email_not_confirmed'));
      return;
    }

    final email = (user.email ?? _emailC.text).trim().toLowerCase();
    final name = _RegValidators.sanitize(_nameC.text.trim(), maxLength: _kMaxNameLength);
    final dob = _RegValidators.sanitize(_dobC.text.trim(), maxLength: 20);
    final pass = _passwordC.text; // jamais sanitisé
    final confirm = _confirmC.text;

    // Nom
    if (name.length < _kMinNameLength || name.length > _kMaxNameLength) {
      _showError(l10n.t('reg_error_name_invalid'));
      return;
    }
    if (!_RegValidators.isValidName(name)) {
      _showError(_tx(context, 'reg_error_name_chars'));
      return;
    }

    // Date de naissance (18+)
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

    // Pays
    if (_country == null) {
      _showError(l10n.t('reg_error_country_required'));
      return;
    }

    // THIX Chat
    if (_chatError != null) {
      _showError(l10n.t('reg_error_fix_chat'));
      return;
    }
    final rawChat = _RegValidators.sanitize(_thixChatC.text.trim().toLowerCase(), maxLength: _kMaxChatLength);
    if (rawChat.isEmpty) {
      _showError(_tx(context, 'reg_error_chat_required'));
      return;
    }
    final chat = _RegValidators.normalizeChat(rawChat);
    if (!_RegValidators.isValidThixChat(chat)) {
      _showError(l10n.t('reg_error_chat_format'));
      return;
    }
    if (_kReservedChats.contains(chat)) {
      _showError(l10n.t('reg_chat_reserved_error'));
      return;
    }

    // Mot de passe
    if (!_RegValidators.isSafePassword(pass)) {
      _showError(_tx(context, 'reg_error_password_chars'));
      return;
    }
    final passResult = await PasswordPolicy.validate(pass, email: email, fullName: name);
    if (!mounted) return;
    if (!passResult.isValid) {
      switch (passResult.code) {
        case PasswordErrorCode.tooShort:
          _showError('${l10n.t('reg_password_too_short')} $_kMinPasswordLength');
          break;
        case PasswordErrorCode.tooWeak:
          _showError(l10n.t('reg_password_too_weak'));
          break;
        case PasswordErrorCode.pwned:
          _showError(l10n.t('reg_password_pwned'));
          break;
        default:
          _showError(l10n.t('reg_error_generic'));
      }
      return;
    }
    if (pass != confirm) {
      _showError(l10n.t('reg_error_passwords_mismatch'));
      return;
    }

    // Conditions (cas d'une reprise à l'étape 2)
    if (!_acceptedTerms || !_acceptedPrivacy) {
      _showError(l10n.t('auth_terms_required'));
      return;
    }

    if (!await _notBlocked('reg_finalize')) return;
    await _Throttle.hit('reg_finalize', _kMaxFinalizeAttempts, _kFinalizeLockSeconds);

    HapticFeedback.mediumImpact();
    setState(() => _busy = true);

    try {
      // 1) Mot de passe du compte (permet aussi la connexion email + mot de passe)
      try {
        await _sb.auth.updateUser(UserAttributes(password: pass));
      } on AuthException catch (e) {
        // Nouvelle tentative avec le même mot de passe : pas une vraie erreur
        if (!e.message.toLowerCase().contains('different from the old')) rethrow;
      }

      // 2) Profil
      final nowIso = DateTime.now().toUtc().toIso8601String();
      await _sb.from('profiles').upsert({
        'id': user.id,
        'full_name': name,
        'date_of_birth': dob,
        'country_or_origin': _country,
        'registration_status': 'draft_step2',
        'account_status': 'pending',
        'terms_accepted_at': nowIso,
        'privacy_accepted_at': nowIso,
      });

      // 3) Email déjà vérifié par Google
      try {
        await _sb.rpc('mark_email_verified');
      } catch (_) {}

      // 4) THIX ID + THIX Chat officiels
      final result = await _sb.rpc(
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
        await ref.read(authControllerProvider.notifier).refreshCurrentUser();
      } catch (_) {}

      if (!mounted) return;

      // Succès : secrets effacés, compteurs remis à zéro
      _passwordC.clear();
      _confirmC.clear();
      await _Throttle.clear('reg_finalize');

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
    if (_step == 2) {
      // Retour = changer de compte Google
      setState(() => _busy = true);
      try {
        await ref.read(authControllerProvider.notifier).signOut();
      } catch (_) {}
      if (!mounted) return;
      _passwordC.clear();
      _confirmC.clear();
      setState(() {
        _busy = false;
        _googleWaiting = false;
        _emailC.clear();
      });
      _enterStep(1);
    } else {
      if (_sb.auth.currentUser != null) {
        try {
          await ref.read(authControllerProvider.notifier).signOut();
        } catch (_) {}
      }
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
            // Champ piège hors écran
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
                                  child: _buildStepContent(l10n),
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

  Widget _buildStepContent(AppLocalizations l10n) {
    switch (_step) {
      case 1:
        return _Step1Google(
          waiting: _googleWaiting,
          acceptedTerms: _acceptedTerms,
          acceptedPrivacy: _acceptedPrivacy,
          onAcceptedTermsChanged: (v) => setState(() => _acceptedTerms = v ?? false),
          onAcceptedPrivacyChanged: (v) => setState(() => _acceptedPrivacy = v ?? false),
          onOpenTerms: () => _openPolicy('terms'),
          onOpenPrivacy: () => _openPolicy('privacy'),
        );
      case 2:
        return _Step2Details(
          emailC: _emailC,
          nameC: _nameC,
          dobC: _dobC,
          country: _country,
          countries: _countries,
          onCountryChanged: (v) => setState(() => _country = v),
          onPickDob: _pickDob,
          thixChatC: _thixChatC,
          passwordC: _passwordC,
          confirmC: _confirmC,
          onPasswordChanged: _onPasswordChanged,
          onChatChanged: _onChatChanged,
          passwordError: _passwordError,
          passwordScore: _passwordScore,
          passwordValidating: _passwordValidating,
          chatError: _chatError,
          chatSuccess: _chatSuccess,
          chatValidating: _chatValidating,
          showConsent: _consentInStep2,
          acceptedTerms: _acceptedTerms,
          acceptedPrivacy: _acceptedPrivacy,
          onAcceptedTermsChanged: (v) => setState(() => _acceptedTerms = v ?? false),
          onAcceptedPrivacyChanged: (v) => setState(() => _acceptedPrivacy = v ?? false),
          onOpenTerms: () => _openPolicy('terms'),
          onOpenPrivacy: () => _openPolicy('privacy'),
        );
      case 3:
        return _Step3Final(
          thixId: _thixIdGenerated,
          thixChat: _thixChatC.text,
          name: _RegValidators.sanitize(_nameC.text.trim(), maxLength: _kMaxNameLength),
          email: _emailC.text.trim(),
          dob: _RegValidators.sanitize(_dobC.text.trim(), maxLength: 20),
          country: _country ?? '',
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
    IconData? icon;
    switch (_step) {
      case 1:
        label = _tx(context, 'reg_google_continue');
        onPressed = _signInWithGoogle;
        icon = Icons.account_circle_outlined;
        break;
      case 2:
        label = isLoading ? _tx(context, 'reg_saving') : _tx(context, 'reg_save');
        onPressed = _saveAndActivate;
        icon = Icons.check_rounded;
        break;
      case 3:
        label = l10n.t('reg_go_to_dashboard');
        onPressed = _goToDashboard;
        icon = Icons.arrow_forward_rounded;
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
              ] else if (icon != null && _step != 3) ...[
                Icon(icon, size: 20),
                const SizedBox(width: ThixPolicy.s8),
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
              if (!isLoading && _step == 3)
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
class _Step1Google extends StatelessWidget {
  final bool waiting;
  final bool acceptedTerms;
  final bool acceptedPrivacy;
  final ValueChanged<bool?> onAcceptedTermsChanged;
  final ValueChanged<bool?> onAcceptedPrivacyChanged;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  const _Step1Google({
    required this.waiting,
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
        Text(_tx(context, 'reg_step1_google_title'), style: ThixPolicy.h2Style.copyWith(color: ThixPolicy.primaryDeep)),
        const SizedBox(height: ThixPolicy.s6),
        Text(_tx(context, 'reg_google_hint'), style: ThixPolicy.bodySmallStyle),
        const SizedBox(height: ThixPolicy.s20),
        if (waiting) ...[
          Container(
            padding: const EdgeInsets.all(ThixPolicy.s12),
            decoration: BoxDecoration(
              color: ThixPolicy.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              border: Border.all(color: ThixPolicy.primary.withOpacity(0.30)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: ThixPolicy.s12),
                Expanded(
                  child: Text(
                    _tx(context, 'reg_google_waiting'),
                    style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMain),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ThixPolicy.s16),
        ],
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
    _tap.dispose();
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

class _Step2Details extends StatelessWidget {
  final TextEditingController emailC;
  final TextEditingController nameC;
  final TextEditingController dobC;
  final String? country;
  final List<String> countries;
  final ValueChanged<String?> onCountryChanged;
  final VoidCallback onPickDob;
  final TextEditingController thixChatC;
  final TextEditingController passwordC;
  final TextEditingController confirmC;
  final ValueChanged<String> onPasswordChanged;
  final ValueChanged<String> onChatChanged;
  final String? passwordError;
  final int passwordScore;
  final bool passwordValidating;
  final String? chatError;
  final String? chatSuccess;
  final bool chatValidating;
  final bool showConsent;
  final bool acceptedTerms;
  final bool acceptedPrivacy;
  final ValueChanged<bool?> onAcceptedTermsChanged;
  final ValueChanged<bool?> onAcceptedPrivacyChanged;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  const _Step2Details({
    required this.emailC,
    required this.nameC,
    required this.dobC,
    required this.country,
    required this.countries,
    required this.onCountryChanged,
    required this.onPickDob,
    required this.thixChatC,
    required this.passwordC,
    required this.confirmC,
    required this.onPasswordChanged,
    required this.onChatChanged,
    required this.passwordError,
    required this.passwordScore,
    required this.passwordValidating,
    required this.chatError,
    required this.chatSuccess,
    required this.chatValidating,
    required this.showConsent,
    required this.acceptedTerms,
    required this.acceptedPrivacy,
    required this.onAcceptedTermsChanged,
    required this.onAcceptedPrivacyChanged,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
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
    final bars = passwordScore < 0 ? 0 : (passwordScore == 0 ? 1 : passwordScore);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_tx(context, 'reg_step2_save_title'), style: ThixPolicy.h2Style.copyWith(color: ThixPolicy.primaryDeep)),
        const SizedBox(height: ThixPolicy.s6),
        Text(_tx(context, 'reg_step2_save_subtitle'), style: ThixPolicy.bodySmallStyle),
        const SizedBox(height: ThixPolicy.s24),
        _PremiumField(
          label: _tx(context, 'reg_email_detected'),
          icon: Icons.email_outlined,
          controller: emailC,
          readOnly: true,
          trailing: const Icon(Icons.verified_rounded, color: ThixPolicy.success, size: 20),
        ),
        const SizedBox(height: ThixPolicy.s16),
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
        if (showConsent) ...[
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
      ],
    );
  }
}

class _Step3Final extends StatelessWidget {
  final String thixId;
  final String thixChat;
  final String name;
  final String email;
  final String dob;
  final String country;
  final VoidCallback onCopyId;

  const _Step3Final({
    required this.thixId,
    required this.thixChat,
    required this.name,
    required this.email,
    required this.dob,
    required this.country,
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
              _SummaryRow(label: l10n.t('reg_dob_label'), value: dob),
              const Divider(height: 1, color: ThixPolicy.border),
              _SummaryRow(label: l10n.t('reg_country_label'), value: country),
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
