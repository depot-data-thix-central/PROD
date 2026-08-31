// lib/auth/supabase_auth_manager.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import 'package:supabase_flutter/supabase_flutter.dart' as sup show AuthException;

import 'package:thix_id/auth/auth_manager.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/models/thix_profile.dart';
import 'package:thix_id/services/profile_service.dart';
import 'package:thix_id/services/push_notification_service.dart';
import 'package:thix_id/services/supabase_safe_write.dart';
import 'package:thix_id/supabase/supabase_config.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kLongRequestTimeout = Duration(seconds: 30);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const int _kMaxRetries = 1;
const int _kMinPasswordLength = 8;
const int _kMaxEmailLength = 254;
const int _kMaxPasswordLength = 128;
const int _kMaxDisplayNameLength = 100;
const int _kMaxTokenLength = 100;
const int _kMaxChatLength = 21;
const int _kMaxCountryCodeLength = 3;

const String _kDefaultDisplayName = 'Utilisateur THIX';
const String _kPendingThixId = 'THIX-PENDING';

const List<String> _kPendingThixIdPrefixes = [
  'THIX-PENDING',
  'THIX-000000',
  'THIX-PENDING-',
  'THIX-CD-FALLBACK',
  'THIX-0',
];

// ============================================================================
// AUTH ERROR CODES (découplage UI/Service)
// ============================================================================

/// Codes d'erreur authentification.
/// L'UI se charge de traduire chaque code via i18n.
enum AuthErrorCode {
  identifierRequired,
  passwordRequired,
  thixIdLoginNotAvailable,
  invalidEmail,
  passwordTooShort,
  signUpFailed,
  otpSent,
  emailNotVerified,
  serverMisconfiguration,
  signInFailed,
  accountAlreadyExists,
  accountExistsWrongPassword,
  accountExistsNewOtpSent,
  invalidOtp,
  otpExpired,
  networkError,
  rateLimit,
  technicalError,
  sessionExpired,
  userMismatch,
  profileUpdateFailed,
  markEmailVerifiedFailed,
  qrTokenGenerationFailed,
  finalizeRegistrationFailed,
  consumeQrTokenFailed,
  resendOtpFailed,
  phoneAuthNotAvailable,
  deleteAccountNotAvailable,
  updateEmailFailed,
  resetPasswordFailed,
}

/// Exception d'authentification avec code découplé de l'UI.
class AuthException implements Exception {
  final AuthErrorCode code;
  final Map<String, dynamic>? data; // Données additionnelles pour i18n
  final String? rawMessage; // Message brut pour debug uniquement

  AuthException(this.code, {this.data, this.rawMessage});

  @override
  String toString() => 'AuthException(code: $code, data: $data)';
}

// ============================================================================
// VALIDATORS
// ============================================================================
class _AuthValidators {
  _AuthValidators._();

  /// Sanitize une entrée utilisateur (XSS + caractères de contrôle)
  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    var s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static bool isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  static String normalizeEmail(String email) {
    return sanitize(email, maxLength: _kMaxEmailLength).toLowerCase();
  }

  static bool isValidPassword(String password) {
    return password.length >= _kMinPasswordLength && password.length <= _kMaxPasswordLength;
  }
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _authRetry<T>(
  Future<T> Function() fn, {
  required String label,
  int maxRetries = _kMaxRetries,
  Duration timeout = _kRequestTimeout,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(timeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[Auth] ❌ $label: timeout after $attempt attempts');
        throw AuthException(AuthErrorCode.networkError, rawMessage: 'timeout');
      }
      debugPrint('[Auth] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } on sup.AuthException {
      rethrow; // Pas de retry sur erreurs auth (credentials invalides, etc.)
    } catch (e) {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[Auth] ❌ $label error after $attempt attempts: $e');
        rethrow;
      }
      debugPrint('[Auth] ⚠️ $label error — retry $attempt/$maxRetries: $e');
      await Future.delayed(_kRetryDelay);
    }
  }
}

// ============================================================================
// SUPABASE AUTH MANAGER
// ============================================================================

/// Implémentation Supabase de AuthManager.
///
/// Architecture :
/// - signUp sans session (Confirm email ON) → NE connecte PAS, lève AuthException(otpSent)
/// - signUp avec session + email confirmé (Confirm email OFF) → signOut + erreur configuration
/// - verifyOTP : hydratation SEULEMENT après vérification réussie
/// - THIX ID officiel jamais généré avant confirmation email + choix pays
/// - Backfill profil si données manquantes
class SupabaseAuthManager implements AuthManager {
  final SupabaseClient _client;
  final ProfileService _profiles;
  final ValueNotifier<AppUser?> _currentUser = ValueNotifier<AppUser?>(null);

  StreamSubscription<AuthState>? _sub;
  StreamSubscription<ThixProfile?>? _profileSub;

  SupabaseAuthManager({SupabaseClient? client, ProfileService? profiles})
      : _client = client ?? SupabaseConfig.client,
        _profiles = profiles ?? ProfileService();

  @override
  ValueListenable<AppUser?> get currentUserListenable => _currentUser;

  @override
  AppUser? get currentUser => _currentUser.value;

  // ==========================================================================
  // INITIALISATION ET GESTION DE SESSION
  // ==========================================================================

  @override
  Future<void> init() async {
    debugPrint('[Auth] 🚀 Initializing auth manager');
    await _sub?.cancel();

    _sub = _client.auth.onAuthStateChange.listen((state) async {
      try {
        final user = state.session?.user;
        if (user == null) {
          await _cleanupSession();
          return;
        }
        final hydrated = await _hydrateUser(user);
        _currentUser.value = hydrated;
        _bindProfileSync(user.id);
        unawaited(PushNotificationService.instance.onSignedIn(userId: user.id));
        debugPrint('[Auth] ✓ User hydrated: ${user.id}');
      } catch (e) {
        debugPrint('[Auth] ❌ Auth state hydrate failed: $e');
        await _cleanupSession();
      }
    });

    final s = _client.auth.currentSession;
    final u = s?.user;
    if (u == null) {
      await _cleanupSession();
      return;
    }
    try {
      final hydrated = await _hydrateUser(u);
      _currentUser.value = hydrated;
      _bindProfileSync(u.id);
      debugPrint('[Auth] ✓ Initial user hydrated: ${u.id}');
    } catch (e) {
      debugPrint('[Auth] ❌ Initial hydration failed: $e');
    }
  }

  Future<void> _cleanupSession() async {
    debugPrint('[Auth] 👋 Cleaning up session');
    await _profileSub?.cancel();
    _profileSub = null;
    _currentUser.value = null;
    unawaited(PushNotificationService.instance.onSignedOut());
  }

  // ==========================================================================
  // SYNCHRONISATION PROFIL
  // ==========================================================================

  bool _isPendingThixId(String? id) {
    if (id == null) return true;
    final v = id.trim().toUpperCase();
    if (v.isEmpty) return true;
    for (final prefix in _kPendingThixIdPrefixes) {
      if (v == prefix || v.startsWith('$prefix-')) return true;
    }
    return false;
  }

  void _bindProfileSync(String uid) {
    unawaited(_profileSub?.cancel());

    _profileSub = _profiles.streamMyProfile(uid).listen(
      (p) {
        if (p == null) return;
        final cur = _currentUser.value;
        if (cur == null || cur.id != uid) return;

        final incomingThixId = p.thixId.trim();
        final resolvedThixId = (!_isPendingThixId(incomingThixId)) ? incomingThixId : cur.thixId;

        final merged = cur.copyWith(
          thixId: resolvedThixId,
          thixChat: (p.thixChat ?? '').trim().isEmpty ? cur.thixChat : (p.thixChat ?? '').trim(),
          displayName: p.displayName.trim().isEmpty ? cur.displayName : p.displayName.trim(),
          photoUrl: (p.photoUrl ?? '').trim().isEmpty ? cur.photoUrl : p.photoUrl,
          bio: p.bio ?? cur.bio,
          occupation: p.occupation ?? cur.occupation,
          profession: p.profession ?? cur.profession,
          countryOrOrigin: p.countryOrOrigin ?? cur.countryOrOrigin,
          contactPhone: p.contactPhone ?? cur.contactPhone,
          maritalStatus: p.maritalStatus ?? cur.maritalStatus,
          gender: p.gender ?? cur.gender,
          dateOfBirth: p.dateOfBirth ?? cur.dateOfBirth,
          placeOfBirth: p.placeOfBirth ?? cur.placeOfBirth,
          nationality: p.nationality ?? cur.nationality,
          address: p.address ?? cur.address,
          fatherName: p.fatherName ?? cur.fatherName,
          motherName: p.motherName ?? cur.motherName,
          emergencyContactName: p.emergencyContactName ?? cur.emergencyContactName,
          emergencyContactPhone: p.emergencyContactPhone ?? cur.emergencyContactPhone,
          emergencyContactRelation: p.emergencyContactRelation ?? cur.emergencyContactRelation,
          languages: p.languages,
          education: p.education,
          experience: p.experience,
          skills: p.skills,
          updatedAt: p.updatedAt,
        );

        final unchanged = merged.displayName == cur.displayName &&
            merged.photoUrl == cur.photoUrl &&
            merged.bio == cur.bio &&
            merged.countryOrOrigin == cur.countryOrOrigin &&
            merged.occupation == cur.occupation &&
            merged.profession == cur.profession &&
            merged.thixChat == cur.thixChat &&
            merged.thixId == cur.thixId &&
            merged.contactPhone == cur.contactPhone &&
            merged.maritalStatus == cur.maritalStatus &&
            merged.gender == cur.gender &&
            merged.dateOfBirth == cur.dateOfBirth &&
            listEquals(merged.languages, cur.languages) &&
            merged.updatedAt == cur.updatedAt;

        if (unchanged) return;
        _currentUser.value = merged;
        debugPrint('[Auth] ✓ Profile synced for $uid');
      },
      onError: (e, st) {
        debugPrint('[Auth] ❌ Profile sync stream failed uid=$uid err=$e');
      },
    );
  }

  // ==========================================================================
  // HYDRATATION — THIX-PENDING tant que non confirmé / non finalisé
  // ==========================================================================

  Future<AppUser> _hydrateUser(User user) async {
    final uid = user.id;
    final email = _AuthValidators.sanitize(user.email?.toLowerCase() ?? '', maxLength: _kMaxEmailLength);
    final meta = (user.userMetadata ?? const <String, dynamic>{});

    String? s(String k) {
      final v = meta[k];
      if (v == null) return null;
      final t = _AuthValidators.sanitize(v.toString(), maxLength: 200);
      return t.isEmpty ? null : t;
    }

    List<String> strList(String k) {
      final v = meta[k];
      if (v is List) {
        return v
            .whereType<String>()
            .map((e) => _AuthValidators.sanitize(e, maxLength: 50))
            .where((e) => e.isNotEmpty)
            .toList(growable: false);
      }
      return const <String>[];
    }

    final row = await _selectProfileRow(uid);
    if (row == null) {
      final base = AppUser(
        id: uid,
        thixId: _kPendingThixId,
        thixChat: '',
        thixScore: null,
        email: email,
        phone: user.phone,
        photoUrl: null,
        displayName: s('display_name') ?? s('full_name') ?? _kDefaultDisplayName,
        accountType: _accountTypeFromMeta(meta),
        bio: s('bio'),
        countryOrOrigin: s('country_or_origin') ?? s('countryOrOrigin'),
        contactPhone: s('phone_number') ?? s('contact_phone') ?? s('contactPhone'),
        maritalStatus: s('marital_status') ?? s('maritalStatus'),
        gender: s('gender'),
        occupation: s('occupation'),
        profession: s('profession'),
        dateOfBirth: s('date_of_birth') ?? s('dateOfBirth'),
        placeOfBirth: s('place_of_birth') ?? s('placeOfBirth'),
        nationality: s('nationality'),
        address: s('address'),
        fatherName: s('father_name') ?? s('fatherName'),
        motherName: s('mother_name') ?? s('motherName'),
        emergencyContactName: s('emergency_contact_name') ?? s('emergencyContactName'),
        emergencyContactPhone: s('emergency_contact_phone') ?? s('emergencyContactPhone'),
        emergencyContactRelation: s('emergency_contact_relation') ?? s('emergencyContactRelation'),
        education: const [],
        experience: const [],
        skills: const [],
        enrollments: const [],
        languages: strList('languages'),
        biometricsEnabled: true,
        twoFaEnabled: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _ensureProfileRow(user: base);
      await _profiles.ensureProfileExists(user: base);

      final fresh = await _selectProfileRow(uid);
      if (fresh != null) {
        return _appUserFromProfileRow(uid: uid, email: email, row: fresh, phone: user.phone);
      }
      return base;
    }

    var appUser = _appUserFromProfileRow(uid: uid, email: email, row: row, phone: user.phone);

    // Backfill si données manquantes
    final metaFullName = s('display_name') ?? s('full_name');
    final needsBackfill = appUser.displayName.trim().isEmpty ||
        (appUser.displayName == _kDefaultDisplayName && metaFullName != null && metaFullName.isNotEmpty);

    if (needsBackfill) {
      debugPrint('[Auth] 🔄 Backfilling profile for $uid');
      final backfillUser = appUser.copyWith(
        displayName: metaFullName ?? appUser.displayName,
        countryOrOrigin: appUser.countryOrOrigin ?? s('country_or_origin') ?? s('countryOrOrigin'),
        contactPhone: appUser.contactPhone ?? s('phone_number') ?? s('contact_phone') ?? s('contactPhone'),
        maritalStatus: appUser.maritalStatus ?? s('marital_status') ?? s('maritalStatus'),
        gender: appUser.gender ?? s('gender'),
        occupation: appUser.occupation ?? s('occupation'),
        profession: appUser.profession ?? s('profession'),
        dateOfBirth: appUser.dateOfBirth ?? s('date_of_birth') ?? s('dateOfBirth'),
        placeOfBirth: appUser.placeOfBirth ?? s('place_of_birth') ?? s('placeOfBirth'),
        nationality: appUser.nationality ?? s('nationality'),
        address: appUser.address ?? s('address'),
        fatherName: appUser.fatherName ?? s('father_name') ?? s('fatherName'),
        motherName: appUser.motherName ?? s('mother_name') ?? s('motherName'),
        emergencyContactName: appUser.emergencyContactName ?? s('emergency_contact_name') ?? s('emergencyContactName'),
        emergencyContactPhone: appUser.emergencyContactPhone ?? s('emergency_contact_phone') ?? s('emergencyContactPhone'),
        emergencyContactRelation: appUser.emergencyContactRelation ?? s('emergency_contact_relation') ?? s('emergencyContactRelation'),
        languages: appUser.languages.isNotEmpty ? appUser.languages : strList('languages'),
      );

      try {
        await _ensureProfileRow(user: backfillUser);
        final fresh = await _selectProfileRow(uid);
        if (fresh != null) {
          appUser = _appUserFromProfileRow(uid: uid, email: email, row: fresh, phone: user.phone);
        } else {
          appUser = backfillUser;
        }
        debugPrint('[Auth] ✓ Profile backfilled for $uid');
      } catch (e) {
        debugPrint('[Auth] ❌ Backfill profile failed uid=$uid err=$e');
        appUser = backfillUser;
      }
    }

    return appUser;
  }

  AccountType _accountTypeFromMeta(Map<String, dynamic>? meta) {
    final raw = _AuthValidators.sanitize(
      (meta?['account_type'] ?? meta?['accountType'] ?? '').toString(),
      maxLength: 20,
    ).toLowerCase();
    if (raw == AccountType.enterprise.name) return AccountType.enterprise;
    return AccountType.personal;
  }

  AppUser _appUserFromProfileRow({
    required String uid,
    required String email,
    required String? phone,
    required Map<String, dynamic> row,
  }) {
    DateTime dt(Object? v) {
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    final createdAt = dt(row['created_at'] ?? row['createdAt']);
    final updatedAt = dt(row['updated_at'] ?? row['updatedAt']);
    final accountTypeRaw = (row['account_type'] ?? row['accountType'] ?? AccountType.personal.name).toString();
    final accountType = AccountType.values.firstWhere(
      (e) => e.name == accountTypeRaw,
      orElse: () => AccountType.personal,
    );

    List<String> strList(Object? v) => (v is List) ? v.whereType<String>().toList(growable: false) : const <String>[];
    List<Map<String, dynamic>> mapList(Object? v) => (v is List)
        ? v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false)
        : const <Map<String, dynamic>>[];

    final rawThixId = _AuthValidators.sanitize(
      (row['thix_id'] ?? row['thixId'] ?? row['thix_uid'] ?? '').toString(),
      maxLength: 50,
    );

    return AppUser(
      id: uid,
      thixId: rawThixId.isEmpty ? '' : rawThixId,
      thixChat: _AuthValidators.sanitize((row['thix_chat'] ?? row['thixChat'] ?? '').toString(), maxLength: _kMaxChatLength),
      thixScore: (row['thix_score'] as num?)?.toInt(),
      email: email,
      phone: phone,
      displayName: _AuthValidators.sanitize((row['display_name'] ?? row['displayName'] ?? _kDefaultDisplayName).toString(), maxLength: _kMaxDisplayNameLength),
      accountType: accountType,
      photoUrl: _AuthValidators.sanitize((row['avatar_url'] ?? row['photo_url'])?.toString(), maxLength: 500),
      bio: _AuthValidators.sanitize(row['bio']?.toString(), maxLength: 500),
      countryOrOrigin: _AuthValidators.sanitize((row['country_or_origin'] ?? row['countryOrOrigin'])?.toString(), maxLength: 100),
      contactPhone: _AuthValidators.sanitize((row['contact_phone'] ?? row['contactPhone'])?.toString(), maxLength: 20),
      maritalStatus: _AuthValidators.sanitize((row['marital_status'] ?? row['maritalStatus'])?.toString(), maxLength: 50),
      gender: _AuthValidators.sanitize(row['gender']?.toString(), maxLength: 20),
      occupation: _AuthValidators.sanitize((row['occupation'] ?? row['occupation_title'])?.toString(), maxLength: 100),
      profession: _AuthValidators.sanitize((row['profession'] ?? row['job_title'])?.toString(), maxLength: 100),
      dateOfBirth: _AuthValidators.sanitize((row['date_of_birth'] ?? row['dateOfBirth'])?.toString(), maxLength: 20),
      placeOfBirth: _AuthValidators.sanitize((row['place_of_birth'] ?? row['placeOfBirth'])?.toString(), maxLength: 100),
      nationality: _AuthValidators.sanitize(row['nationality']?.toString(), maxLength: 100),
      address: _AuthValidators.sanitize(row['address']?.toString(), maxLength: 500),
      fatherName: _AuthValidators.sanitize((row['father_name'] ?? row['fatherName'])?.toString(), maxLength: 100),
      motherName: _AuthValidators.sanitize((row['mother_name'] ?? row['motherName'])?.toString(), maxLength: 100),
      emergencyContactName: _AuthValidators.sanitize((row['emergency_contact_name'] ?? row['emergencyContactName'])?.toString(), maxLength: 100),
      emergencyContactPhone: _AuthValidators.sanitize((row['emergency_contact_phone'] ?? row['emergencyContactPhone'])?.toString(), maxLength: 20),
      emergencyContactRelation: _AuthValidators.sanitize((row['emergency_contact_relation'] ?? row['emergencyContactRelation'])?.toString(), maxLength: 50),
      registrationStatus: _AuthValidators.sanitize((row['registration_status'] ?? row['registrationStatus'])?.toString(), maxLength: 50),
      education: mapList(row['education']),
      experience: mapList(row['experience']),
      skills: mapList(row['skills']),
      enrollments: mapList(row['enrollments']),
      languages: strList(row['languages']),
      biometricsEnabled: (row['biometrics_enabled'] as bool?) ?? true,
      twoFaEnabled: (row['two_fa_enabled'] as bool?) ?? false,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Future<Map<String, dynamic>?> _selectProfileRow(String uid) async {
    try {
      final row = await _authRetry(
        () => _client.from('profiles').select('*').eq('id', uid).maybeSingle(),
        label: 'selectProfileRow[$uid]',
      );
      if (row != null) return (row as Map).cast<String, dynamic>();
    } catch (e) {
      debugPrint('[Auth] ❌ Profiles select by id failed uid=$uid err=$e');
    }
    return null;
  }

  Future<void> _ensureProfileRow({required AppUser user}) async {
    final now = DateTime.now().toUtc().toIso8601String();

    final payload = <String, dynamic>{
      'id': user.id,
      if (!_isPendingThixId(user.thixId)) 'thix_id': user.thixId,
      if (user.thixChat.trim().isNotEmpty) 'thix_chat': user.thixChat,
      'display_name': user.displayName,
      if (user.bio?.isNotEmpty == true) 'bio': user.bio,
      if (user.profession?.isNotEmpty == true) 'profession': user.profession,
      if (user.occupation?.isNotEmpty == true) 'occupation': user.occupation,
      if (user.photoUrl?.isNotEmpty == true) 'avatar_url': user.photoUrl,
      if (user.countryOrOrigin?.isNotEmpty == true) 'country_or_origin': user.countryOrOrigin,
      if (user.contactPhone?.isNotEmpty == true) 'contact_phone': user.contactPhone,
      if (user.maritalStatus?.isNotEmpty == true) 'marital_status': user.maritalStatus,
      if (user.gender?.isNotEmpty == true) 'gender': user.gender,
      if (user.dateOfBirth?.isNotEmpty == true) 'date_of_birth': user.dateOfBirth,
      if (user.placeOfBirth?.isNotEmpty == true) 'place_of_birth': user.placeOfBirth,
      if (user.nationality?.isNotEmpty == true) 'nationality': user.nationality,
      if (user.address?.isNotEmpty == true) 'address': user.address,
      if (user.fatherName?.isNotEmpty == true) 'father_name': user.fatherName,
      if (user.motherName?.isNotEmpty == true) 'mother_name': user.motherName,
      if (user.emergencyContactName?.isNotEmpty == true) 'emergency_contact_name': user.emergencyContactName,
      if (user.emergencyContactPhone?.isNotEmpty == true) 'emergency_contact_phone': user.emergencyContactPhone,
      if (user.emergencyContactRelation?.isNotEmpty == true) 'emergency_contact_relation': user.emergencyContactRelation,
      if (user.languages.isNotEmpty) 'languages': user.languages,
      'registration_status': user.registrationStatus ?? 'draft_step2',
      'updated_at': now,
    };

    try {
      await _authRetry(
        () => SupabaseSafeWrite.upsert(
          client: _client,
          table: 'profiles',
          payload: payload,
          onUnknownColumn: () async {
            try {
              await _client.functions.invoke('pgrst_schema_reload', body: const {});
            } catch (e) {
              debugPrint('[Auth] ⚠️ Schema reload invoke failed err=$e');
            }
          },
        ),
        label: 'ensureProfileRow[${user.id}]',
      );
    } catch (e) {
      debugPrint('[Auth] ❌ Profiles upsert failed uid=${user.id} err=$e');
    }
  }

  // ==========================================================================
  // CONNEXION
  // ==========================================================================

  @override
  Future<AppUser> signInWithEmailOrThixId({
    required String identifier,
    required String password,
    required bool rememberMe,
  }) async {
    final id = _AuthValidators.sanitize(identifier.trim(), maxLength: _kMaxEmailLength);
    if (id.isEmpty) {
      throw AuthException(AuthErrorCode.identifierRequired);
    }

    final sanitizedPassword = _AuthValidators.sanitize(password, maxLength: _kMaxPasswordLength);
    if (sanitizedPassword.isEmpty) {
      throw AuthException(AuthErrorCode.passwordRequired);
    }

    if (!id.contains('@')) {
      throw AuthException(AuthErrorCode.thixIdLoginNotAvailable);
    }

    debugPrint('[Auth] 🔐 Sign in attempt for: ${id.substring(0, id.length > 20 ? 20 : id.length)}...');

    try {
      final res = await _authRetry(
        () => _client.auth.signInWithPassword(email: id.toLowerCase(), password: sanitizedPassword),
        label: 'signInWithEmail',
      );
      final user = res.user;
      if (user == null) {
        throw AuthException(AuthErrorCode.signInFailed);
      }

      // Compte non confirmé → bloquer et renvoyer code
      if (user.emailConfirmedAt == null) {
        try {
          await _client.auth.resend(type: OtpType.signup, email: id.toLowerCase());
        } catch (_) {}
        await _client.auth.signOut();
        throw AuthException(AuthErrorCode.emailNotVerified);
      }

      final hydrated = await _hydrateUser(user);
      _currentUser.value = hydrated;
      _bindProfileSync(user.id);
      debugPrint('[Auth] ✓ Sign in successful: ${user.id}');
      return hydrated;
    } on sup.AuthException catch (e) {
      throw _mapSupabaseAuthError(e, context: 'signIn');
    } catch (e) {
      if (e is AuthException) rethrow;
      debugPrint('[Auth] ❌ SignIn crash err=$e');
      throw AuthException(AuthErrorCode.technicalError);
    }
  }

  // ==========================================================================
  // INSCRIPTION
  // ==========================================================================

  @override
  Future<AppUser> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
    required AccountType accountType,
    required bool rememberMe,
    ProfileDraft? profileDraft,
  }) async {
    final normalizedEmail = _AuthValidators.normalizeEmail(email);
    if (!_AuthValidators.isValidEmail(normalizedEmail)) {
      throw AuthException(AuthErrorCode.invalidEmail);
    }

    final sanitizedPassword = _AuthValidators.sanitize(password, maxLength: _kMaxPasswordLength);
    if (!_AuthValidators.isValidPassword(sanitizedPassword)) {
      throw AuthException(AuthErrorCode.passwordTooShort, data: {'minLength': _kMinPasswordLength});
    }

    final sanitizedDisplayName = _AuthValidators.sanitize(displayName, maxLength: _kMaxDisplayNameLength);

    debugPrint('[Auth] 🚀 Register attempt for: $normalizedEmail');

    try {
      final userMeta = <String, dynamic>{
        'display_name': sanitizedDisplayName.isEmpty ? _kDefaultDisplayName : sanitizedDisplayName,
        'account_type': accountType.name,
        // Si ProfileDraft utilise .toJson() ou .toMap()
        if (profileDraft != null) ...profileDraft.toMap(),
      };

      final res = await _authRetry(
        () => _client.auth.signUp(email: normalizedEmail, password: sanitizedPassword, data: userMeta),
        label: 'signUp',
      );
      final session = res.session;
      final user = res.user;

      if (user == null) {
        throw AuthException(AuthErrorCode.signUpFailed);
      }

      // CAS NOMINAL (Confirm email ON) : pas de session, OTP envoyé
      if (session == null) {
        throw AuthException(AuthErrorCode.otpSent);
      }

      // MISCONFIGURATION (Confirm email OFF) : session + email confirmé immédiats
      if (user.emailConfirmedAt != null) {
        try {
          await _client.auth.signOut();
        } catch (_) {}
        throw AuthException(AuthErrorCode.serverMisconfiguration);
      }

      // Cas rare : session ouverte mais email non confirmé
      try {
        await _client.auth.signOut();
      } catch (_) {}
      throw AuthException(AuthErrorCode.otpSent);
    } on sup.AuthException catch (e) {
      final mapped = _mapSupabaseAuthError(e, context: 'register');
      
      // Gestion spéciale "already registered"
      if (mapped.code == AuthErrorCode.accountAlreadyExists) {
        return _handleExistingAccount(normalizedEmail, sanitizedPassword);
      }
      
      throw mapped;
    } catch (e) {
      if (e is AuthException) rethrow;
      debugPrint('[Auth] ❌ Register crash err=$e');
      throw AuthException(AuthErrorCode.technicalError);
    }
  }

  Future<AppUser> _handleExistingAccount(String email, String password) async {
    try {
      final res = await _client.auth.signInWithPassword(email: email, password: password);
      final user = res.user;

      // Compte existant mais jamais vérifié → renvoyer OTP
      if (user != null && user.emailConfirmedAt == null) {
        try {
          await _client.auth.resend(type: OtpType.signup, email: email);
        } catch (_) {}
        await _client.auth.signOut();
        throw AuthException(AuthErrorCode.accountExistsNewOtpSent);
      }

      if (user != null) {
        final appUser = await _hydrateUser(user);
        _currentUser.value = appUser;
        _bindProfileSync(user.id);
        return appUser;
      }
      throw AuthException(AuthErrorCode.accountAlreadyExists);
    } on sup.AuthException catch (loginErr) {
      final msg = loginErr.message.toLowerCase();
      if (msg.contains('invalid login') || msg.contains('invalid credentials')) {
        throw AuthException(AuthErrorCode.accountExistsWrongPassword);
      }
      // "Email not confirmed" → renvoi du code
      try {
        await _client.auth.resend(type: OtpType.signup, email: email);
      } catch (_) {}
      throw AuthException(AuthErrorCode.accountExistsNewOtpSent);
    }
  }

  @override
  Future<AppUser> registerPersonal({
    required String email,
    required String password,
    required String displayName,
    required bool rememberMe,
    ProfileDraft? profileDraft,
  }) {
    return registerWithEmail(
      email: email,
      password: password,
      displayName: displayName,
      accountType: AccountType.personal,
      rememberMe: rememberMe,
      profileDraft: profileDraft,
    );
  }

  // ==========================================================================
  // VERIFY OTP
  // ==========================================================================

  @override
  Future<void> verifyOTP({required String email, required String token}) async {
    final normalizedEmail = _AuthValidators.normalizeEmail(email);
    final sanitizedToken = _AuthValidators.sanitize(token.trim(), maxLength: _kMaxTokenLength);

    debugPrint('[Auth] 🔑 Verifying OTP for: $normalizedEmail');

    try {
      final res = await _authRetry(
        () => _client.auth.verifyOTP(
          email: normalizedEmail,
          token: sanitizedToken,
          type: OtpType.signup,
        ),
        label: 'verifyOTP',
      );

      if (res.session == null || res.user == null) {
        throw AuthException(AuthErrorCode.invalidOtp);
      }

      // Vérification réussie : hydrater et connecter
      final appUser = await _hydrateUser(res.user!);
      _currentUser.value = appUser;
      _bindProfileSync(res.user!.id);
      unawaited(PushNotificationService.instance.onSignedIn(userId: res.user!.id));
      debugPrint('[Auth] ✓ OTP verified and user hydrated: ${res.user!.id}');
    } on AuthException {
      rethrow;
    } on sup.AuthException catch (e) {
      throw _mapSupabaseAuthError(e, context: 'verifyOTP');
    } catch (e) {
      debugPrint('[Auth] ❌ VerifyOTP failed err=$e');
      throw AuthException(AuthErrorCode.technicalError);
    }
  }

  @override
  Future<void> markEmailVerified() async {
    try {
      await _authRetry(
        () => _client.rpc('mark_email_verified'),
        label: 'markEmailVerified',
      );
      debugPrint('[Auth] ✓ Email marked as verified');
    } catch (e) {
      debugPrint('[Auth] ❌ MarkEmailVerified failed err=$e');
      throw AuthException(AuthErrorCode.markEmailVerifiedFailed);
    }
  }

  @override
  Future<String> generateQrToken() async {
    try {
      final result = await _authRetry(
        () => _client.rpc('generate_qr_activation_token'),
        label: 'generateQrToken',
      );
      return _AuthValidators.sanitize(result.toString(), maxLength: _kMaxTokenLength);
    } catch (e) {
      debugPrint('[Auth] ❌ GenerateQrToken failed err=$e');
      throw AuthException(AuthErrorCode.qrTokenGenerationFailed);
    }
  }

  @override
  Future<Map<String, dynamic>> finalizeRegistration({
    required String desiredChat,
    required String countryCode,
  }) async {
    final sanitizedChat = _AuthValidators.sanitize(desiredChat, maxLength: _kMaxChatLength);
    final sanitizedCountry = _AuthValidators.sanitize(countryCode, maxLength: _kMaxCountryCodeLength);

    debugPrint('[Auth] 🏁 Finalizing registration: chat=$sanitizedChat, country=$sanitizedCountry');

    try {
      final result = await _authRetry(
        () => _client.rpc(
          'finalize_registration',
          params: {'p_desired_chat': sanitizedChat, 'p_country_code': sanitizedCountry},
        ),
        label: 'finalizeRegistration',
        timeout: _kLongRequestTimeout,
      );
      if (result is Map<String, dynamic>) {
        debugPrint('[Auth] ✓ Registration finalized');
        return result;
      }
      if (result is Map) {
        debugPrint('[Auth] ✓ Registration finalized');
        return Map<String, dynamic>.from(result);
      }
      throw Exception('Invalid server response');
    } catch (e) {
      debugPrint('[Auth] ❌ FinalizeRegistration failed err=$e');
      throw AuthException(AuthErrorCode.finalizeRegistrationFailed);
    }
  }

  @override
  Future<void> consumeQrToken({required String token}) async {
    final sanitizedToken = _AuthValidators.sanitize(token, maxLength: _kMaxTokenLength);
    try {
      await _authRetry(
        () => _client.rpc('consume_qr_activation_token', params: {'p_token': sanitizedToken}),
        label: 'consumeQrToken',
      );
      debugPrint('[Auth] ✓ QR token consumed');
    } catch (e) {
      debugPrint('[Auth] ❌ ConsumeQrToken failed err=$e');
      throw AuthException(AuthErrorCode.consumeQrTokenFailed);
    }
  }

  @override
  Future<AppUser> refreshCurrentUser() async {
    final session = _client.auth.currentSession;
    if (session == null) {
      final current = _currentUser.value;
      if (current != null) return current;
      throw AuthException(AuthErrorCode.sessionExpired);
    }
    final hydrated = await _hydrateUser(session.user);
    _currentUser.value = hydrated;
    _bindProfileSync(session.user.id);
    return hydrated;
  }

  @override
  Future<void> resendOTP({required String email}) async {
    final normalizedEmail = _AuthValidators.normalizeEmail(email);
    try {
      await _authRetry(
        () => _client.auth.resend(type: OtpType.signup, email: normalizedEmail),
        label: 'resendOTP',
      );
      debugPrint('[Auth] ✓ OTP resent to: $normalizedEmail');
    } on sup.AuthException catch (e) {
      throw _mapSupabaseAuthError(e, context: 'resendOTP');
    } catch (e) {
      debugPrint('[Auth] ❌ ResendOTP failed err=$e');
      throw AuthException(AuthErrorCode.resendOtpFailed);
    }
  }

  @override
  Future<PhoneAuthSession> startPhoneAuth({required String phoneNumber}) {
    throw AuthException(AuthErrorCode.phoneAuthNotAvailable);
  }

  @override
  Future<AppUser> confirmPhoneCode({
    required PhoneAuthSession session,
    required String smsCode,
    String? displayName,
    AccountType accountType = AccountType.personal,
  }) {
    throw AuthException(AuthErrorCode.phoneAuthNotAvailable);
  }

  @override
  Future<void> signOut() async {
    debugPrint('[Auth] 👋 Signing out');
    await _client.auth.signOut();
    await _cleanupSession();
  }

  @override
  Future<void> deleteAccount() {
    throw AuthException(AuthErrorCode.deleteAccountNotAvailable);
  }

  @override
  Future<void> updateEmail(String newEmail) async {
    final normalized = _AuthValidators.normalizeEmail(newEmail);
    if (!_AuthValidators.isValidEmail(normalized)) {
      throw AuthException(AuthErrorCode.invalidEmail);
    }
    try {
      await _authRetry(
        () => _client.auth.updateUser(UserAttributes(email: normalized)),
        label: 'updateEmail',
      );
      debugPrint('[Auth] ✓ Email updated to: $normalized');
    } catch (e) {
      debugPrint('[Auth] ❌ UpdateEmail failed err=$e');
      throw AuthException(AuthErrorCode.updateEmailFailed);
    }
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    final normalized = _AuthValidators.normalizeEmail(email);
    if (!_AuthValidators.isValidEmail(normalized)) {
      throw AuthException(AuthErrorCode.invalidEmail);
    }
    try {
      await _authRetry(
        () => _client.auth.resetPasswordForEmail(normalized),
        label: 'requestPasswordReset',
      );
      debugPrint('[Auth] ✓ Password reset requested for: $normalized');
    } catch (e) {
      debugPrint('[Auth] ❌ RequestPasswordReset failed err=$e');
      throw AuthException(AuthErrorCode.resetPasswordFailed);
    }
  }

  @override
  Future<void> updateCurrentUser(AppUser user) async {
    final current = currentUser;
    if (current == null) {
      throw AuthException(AuthErrorCode.sessionExpired);
    }
    if (current.id != user.id) {
      throw AuthException(AuthErrorCode.userMismatch);
    }

    final safeUser = user.copyWith(
      thixId: current.thixId,
      thixScore: current.thixScore,
      registrationStatus: current.registrationStatus,
    );

    try {
      await _ensureProfileRow(user: safeUser);
      await _profiles.ensureProfileExists(user: safeUser);
      debugPrint('[Auth] ✓ Current user updated: ${user.id}');
    } catch (e) {
      debugPrint('[Auth] ❌ UpdateCurrentUser failed uid=${user.id} err=$e');
      throw AuthException(AuthErrorCode.profileUpdateFailed);
    }
    _currentUser.value = safeUser;
    _bindProfileSync(user.id);
  }

  // ==========================================================================
  // ERROR MAPPING
  // ==========================================================================

  /// Mappe les erreurs Supabase vers des AuthErrorCode user-friendly
  AuthException _mapSupabaseAuthError(sup.AuthException e, {required String context}) {
    final msg = e.message.toLowerCase();

    if (msg.contains('invalid login') || msg.contains('invalid credentials')) {
      return AuthException(AuthErrorCode.signInFailed, rawMessage: e.message);
    }
    if (msg.contains('already registered') || msg.contains('already exists') || msg.contains('déjà')) {
      return AuthException(AuthErrorCode.accountAlreadyExists, rawMessage: e.message);
    }
    if (msg.contains('expired') || msg.contains('invalid') || msg.contains('otp') || msg.contains('token')) {
      return AuthException(AuthErrorCode.invalidOtp, rawMessage: e.message);
    }
    if (msg.contains('rate limit') || msg.contains('too many')) {
      return AuthException(AuthErrorCode.rateLimit, rawMessage: e.message);
    }
    if (msg.contains('network') || msg.contains('timeout') || msg.contains('unavailable')) {
      return AuthException(AuthErrorCode.networkError, rawMessage: e.message);
    }

    debugPrint('[Auth] ⚠️ Unmapped Supabase error in $context: ${e.message}');
    return AuthException(AuthErrorCode.technicalError, rawMessage: e.message);
  }

  // ==========================================================================
  // DISPOSE
  // ==========================================================================
  
  @override
  void dispose() {
    debugPrint('[Auth] 🧹 Disposing AuthManager');
    _sub?.cancel();
    _profileSub?.cancel();
    _currentUser.dispose();
  }
}
