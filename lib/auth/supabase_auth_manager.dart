// lib/auth/supabase_auth_manager.dart
//
// v3 :
//  ✅ FIX OFFLINE — _selectProfileRow lève sur erreur réseau (plus de retour null
//     qui confondait "profil absent" et "DNS mort" → plus de création de profil fantôme)
//  ✅ FIX OFFLINE — _hydrateUser ne réécrit JAMAIS registration_status/thix_id en offline
//     (garde le fallback / snapshot au lieu de forcer draft_step2)
//  ✅ FIX ID — _ensureProfileRow passe ignoreDuplicates: true → ON CONFLICT DO NOTHING
//     (un ensure ne peut plus écraser un THIX ID / registration_status existant)
//  ✅ FIX ID — finalizeRegistration() court-circuitée si déjà active/completed
//     (plus de régénération du THIX ID après une perte de réseau)
//  ✅ FIX SESSION — snapshot local (SessionSnapshot) sauvegardé après chaque hydratation
//     réussie, restauré au démarrage si pas de session Supabase → l'utilisateur
//     reste "connecté" après redémarrage offline.
//
// v2 (conservé) :
//  ✅ la déconnexion NON volontaire (signedOut déclenché par Supabase quand le
//     renouvellement du jeton échoue) ne supprime plus le token push
//  ✅ le token push n'est retiré que par signOut() (déconnexion volontaire)
//  ✅ un renouvellement de jeton (tokenRefreshed) ne relance plus l'hydratation
//  ✅ chaque évènement d'authentification est journalisé : [Auth] 🔔 event=...

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import 'package:supabase_flutter/supabase_flutter.dart' as sup show AuthException;

import 'package:thix_id/auth/auth_manager.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/models/thix_profile.dart';
import 'package:thix_id/services/profile_service.dart';
import 'package:thix_id/services/push_notification_service.dart';
import 'package:thix_id/services/session_snapshot.dart'; // ✅ FIX SESSION
import 'package:thix_id/services/supabase_safe_write.dart';
import 'package:thix_id/supabase/supabase_config.dart';
import 'package:thix_id/models/account_type.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kLongRequestTimeout = Duration(seconds: 30);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const Duration _kPushUnregisterTimeout = Duration(seconds: 8);
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

String _maskId(String s) =>
    s.length <= 8 ? '***' : '${s.substring(0, 4)}...${s.substring(s.length - 3)}';

// ============================================================================
// AUTH ERROR CODES (découplage UI/Service)
// ============================================================================

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

class AuthException implements Exception {
  final AuthErrorCode code;
  final Map<String, dynamic>? data;
  final String? rawMessage;

  AuthException(this.code, {this.data, this.rawMessage});

  @override
  String toString() => 'AuthException(code: $code, data: $data)';
}

// ============================================================================
// VALIDATORS
// ============================================================================
class _AuthValidators {
  _AuthValidators._();

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
      rethrow;
    } catch (e) {
      attempt++;
      final msg = e.toString().toLowerCase();
      final isNetwork = msg.contains('socket') ||
          msg.contains('network') ||
          msg.contains('connection reset') ||
          msg.contains('authretryable') ||
          msg.contains('failed host lookup');

      if (isNetwork || attempt > maxRetries) {
        debugPrint('[Auth] ❌ $label network/final error: $e');
        throw AuthException(AuthErrorCode.networkError, rawMessage: e.toString());
      }
      debugPrint('[Auth] ⚠️ $label error — retry $attempt/$maxRetries: $e');
      await Future.delayed(_kRetryDelay);
    }
  }
}

/// ✅ FIX OFFLINE — détection centralisée des erreurs réseau (utilisée dans
/// _selectProfileRowStrict pour ne plus confondre "profil absent" et "DNS mort").
bool _isNetworkError(Object e) {
  final msg = e.toString().toLowerCase();
  return msg.contains('socket') ||
      msg.contains('network') ||
      msg.contains('connection reset') ||
      msg.contains('connection refused') ||
      msg.contains('failed host lookup') ||
      msg.contains('authretryablefetchexception') ||
      msg.contains('handshakeexception') ||
      msg.contains('unreachable');
}

// ============================================================================
// SUPABASE AUTH MANAGER
// ============================================================================

class SupabaseAuthManager implements AuthManager {
  final SupabaseClient _client;
  final ProfileService _profiles;
  final ValueNotifier<AppUser?> _currentUser = ValueNotifier<AppUser?>(null);

  StreamSubscription<AuthState>? _sub;
  StreamSubscription<ThixProfile?>? _profileSub;

  bool _initialized = false;
  bool _isBindingProfile = false;
  String? _pushUserId;

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

  void _registerPushIfNeeded(String uid) {
    if (_pushUserId == uid) return;
    _pushUserId = uid;
    unawaited(PushNotificationService.instance.onSignedIn(userId: uid));
  }

  @override
  Future<void> init() async {
    if (_initialized) {
      debugPrint('[Auth] ⚠️ init() déjà appelé → skip');
      return;
    }
    _initialized = true;

    debugPrint('[Auth] 🚀 Initializing auth manager');

    await _sub?.cancel();
    _sub = null;

    try {
      _sub = _client.auth.onAuthStateChange.listen(
        (state) async {
          try {
            final event = state.event;
            final user = state.session?.user;
            debugPrint('[Auth] 🔔 event=${event.name} '
                'user=${user == null ? 'none' : _maskId(user.id)}');

            if (user == null) {
              if (event == AuthChangeEvent.signedOut && _pushUserId != null) {
                debugPrint('[Auth] ⚠️ signedOut reçu : session perdue ou '
                    'déconnexion (token push conservé)');
              }
              // ✅ FIX SESSION — NE PAS effacer le snapshot sur déconnexion
              // non-volontaire. Seul signOut() (volontaire) le fait.
              await _cleanupSession(clearSnapshot: false);
              return;
            }

            if (event == AuthChangeEvent.tokenRefreshed &&
                _currentUser.value?.id == user.id) {
              return;
            }

            try {
              final hydrated = await _hydrateUser(user);
              _currentUser.value = hydrated;
              _bindProfileSync(user.id);
              // ✅ FIX SESSION — persister l'état authentifié réussi
              unawaited(SessionSnapshot.save(hydrated));
              debugPrint('[Auth] ✓ User hydrated: ${_maskId(user.id)}');
            } catch (e) {
              debugPrint('[Auth] ⚠️ Hydrate failed, keeping session alive: $e');
              // ✅ FIX OFFLINE — préférer le snapshot au fallback vide si disponible
              final cached = SessionSnapshot.load();
              if (cached != null && cached.id == user.id) {
                _currentUser.value ??= cached;
              } else {
                _currentUser.value ??= _buildFallbackUser(user);
              }
            }
            _registerPushIfNeeded(user.id);
          } catch (e) {
            debugPrint('[Auth] ❌ Auth state error (swallowed): $e');
          }
        },
        onError: (e, st) {
          debugPrint('[Auth] ⚠️ onAuthStateChange error (ignored): $e');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('[Auth] ❌ Failed to attach onAuthStateChange: $e');
    }

    // Hydratation initiale
    final s = _client.auth.currentSession;
    final u = s?.user;
    if (u == null) {
      debugPrint('[Auth] ℹ️ Aucune session Supabase au démarrage');
      // ✅ FIX SESSION — tenter de restaurer depuis le snapshot local
      final cached = SessionSnapshot.load();
      if (cached != null) {
        debugPrint('[Auth] 📦 Session restaurée depuis snapshot: ${_maskId(cached.id)}');
        _currentUser.value = cached;
        _pushUserId = cached.id;
        return;
      }
      await _cleanupSession(clearSnapshot: false);
      return;
    }

    _pushUserId = u.id;

    try {
      final hydrated = await _hydrateUser(u);
      _currentUser.value = hydrated;
      _bindProfileSync(u.id);
      // ✅ FIX SESSION
      unawaited(SessionSnapshot.save(hydrated));
      debugPrint('[Auth] ✓ Initial user hydrated: ${_maskId(u.id)}');
    } catch (e) {
      debugPrint('[Auth] ⚠️ Initial hydration failed (likely offline): $e');
      // ✅ FIX SESSION — snapshot en priorité, fallback sinon
      final cached = SessionSnapshot.load();
      if (cached != null && cached.id == u.id) {
        _currentUser.value = cached;
      } else {
        _currentUser.value ??= _buildFallbackUser(u);
      }
    }
  }

  AppUser _buildFallbackUser(User user) {
    return AppUser(
      id: user.id,
      thixId: '',
      thixChat: '',
      thixScore: null,
      email: user.email ?? '',
      phone: user.phone,
      displayName: user.userMetadata?['full_name']?.toString() ??
          user.email ??
          _kDefaultDisplayName,
      accountType: AccountType.personal,
      photoUrl: user.userMetadata?['avatar_url']?.toString(),
      bio: null,
      countryOrOrigin: null,
      education: const [],
      experience: const [],
      skills: const [],
      enrollments: const [],
      languages: const [],
      biometricsEnabled: true,
      twoFaEnabled: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// ✅ FIX SESSION — [clearSnapshot] n'est vrai QUE pour une déconnexion
  /// volontaire. Une déconnexion non-volontaire (jeton refusé par Supabase
  /// après perte de réseau prolongée) conserve le snapshot pour qu'on
  /// puisse restaurer l'état de l'utilisateur au retour du réseau.
  Future<void> _cleanupSession({bool clearSnapshot = false}) async {
    debugPrint('[Auth] 👋 Cleaning up local session state '
        '(clearSnapshot=$clearSnapshot)');
    await _profileSub?.cancel();
    _profileSub = null;
    _currentUser.value = null;
    if (clearSnapshot) {
      unawaited(SessionSnapshot.clear());
    }
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
    if (_isBindingProfile) return;
    _isBindingProfile = true;

    unawaited(() async {
      try {
        await _profileSub?.cancel();
        _profileSub = null;

        _profileSub = _profiles.streamMyProfile(uid).listen(
          (p) {
            if (p == null) return;
            final cur = _currentUser.value;
            if (cur == null || cur.id != uid) return;

            final incomingThixId = p.thixId.trim();
            final resolvedThixId =
                (!_isPendingThixId(incomingThixId)) ? incomingThixId : cur.thixId;

            final merged = cur.copyWith(
              thixId: resolvedThixId,
              thixChat: (p.thixChat ?? '').trim().isEmpty
                  ? cur.thixChat
                  : (p.thixChat ?? '').trim(),
              displayName: p.displayName.trim().isEmpty
                  ? cur.displayName
                  : p.displayName.trim(),
              photoUrl: (p.photoUrl ?? '').trim().isEmpty
                  ? cur.photoUrl
                  : p.photoUrl,
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
              emergencyContactName:
                  p.emergencyContactName ?? cur.emergencyContactName,
              emergencyContactPhone:
                  p.emergencyContactPhone ?? cur.emergencyContactPhone,
              emergencyContactRelation:
                  p.emergencyContactRelation ?? cur.emergencyContactRelation,
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
            // ✅ FIX SESSION — mettre à jour le snapshot après sync
            unawaited(SessionSnapshot.save(merged));
            debugPrint('[Auth] ✓ Profile synced for ${_maskId(uid)}');
          },
          onError: (e, st) {
            debugPrint('[Auth] ❌ Profile sync stream failed uid=${_maskId(uid)} err=$e');
          },
          cancelOnError: false,
        );
      } catch (e) {
        debugPrint('[Auth] ⚠️ _bindProfileSync error: $e');
      } finally {
        _isBindingProfile = false;
      }
    }());
  }

  // ==========================================================================
  // HYDRATATION
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

    // ✅ FIX OFFLINE — _selectProfileRowStrict lève sur erreur réseau
    // au lieu de retourner null (qui confondait "absent" et "hors-ligne").
    Map<String, dynamic>? row;
    try {
      row = await _selectProfileRowStrict(uid);
    } on AuthException catch (e) {
      if (e.code == AuthErrorCode.networkError) {
        debugPrint('[Auth] ⚠️ Profile select offline — NO write, using fallback');
        // ✅ CRITIQUE : on ne crée PAS de profil en offline. On préfère le
        // snapshot existant ou un fallback minimal.
        final cached = SessionSnapshot.load();
        if (cached != null && cached.id == uid) return cached;
        return _buildFallbackUser(user);
      }
      rethrow;
    }

    if (row == null) {
      // Vrai profil absent → création légitime (nouvel utilisateur)
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

      // ✅ FIX ID — ignoreDuplicates: true (ON CONFLICT DO NOTHING)
      await _ensureProfileRow(user: base, ignoreIfPresent: true);
      await _profiles.ensureProfileExists(user: base);

      // Tenter de relire; si offline ici, on retourne base sans insister.
      try {
        final fresh = await _selectProfileRowStrict(uid);
        if (fresh != null) {
          return _appUserFromProfileRow(uid: uid, email: email, row: fresh, phone: user.phone);
        }
      } on AuthException catch (e) {
        if (e.code == AuthErrorCode.networkError) {
          debugPrint('[Auth] ⚠️ Re-read after creation offline, returning base');
        } else {
          rethrow;
        }
      }
      return base;
    }

    var appUser = _appUserFromProfileRow(uid: uid, email: email, row: row, phone: user.phone);

    // Backfill si données manquantes (mais PAS en offline → catch explicite)
    final metaFullName = s('display_name') ?? s('full_name');
    final needsBackfill = appUser.displayName.trim().isEmpty ||
        (appUser.displayName == _kDefaultDisplayName && metaFullName != null && metaFullName.isNotEmpty);

    if (needsBackfill) {
      debugPrint('[Auth] 🔄 Backfilling profile for ${_maskId(uid)}');
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
        // ✅ FIX ID — ne pas écraser les champs protégés (thix_id, registration_status)
        await _ensureProfileRow(user: backfillUser, ignoreIfPresent: true);
        try {
          final fresh = await _selectProfileRowStrict(uid);
          if (fresh != null) {
            appUser = _appUserFromProfileRow(uid: uid, email: email, row: fresh, phone: user.phone);
          } else {
            appUser = backfillUser;
          }
        } on AuthException catch (e) {
          if (e.code == AuthErrorCode.networkError) {
            debugPrint('[Auth] ⚠️ Backfill re-read offline, using backfillUser');
            appUser = backfillUser;
          } else {
            rethrow;
          }
        }
        debugPrint('[Auth] ✓ Profile backfilled for ${_maskId(uid)}');
      } catch (e) {
        debugPrint('[Auth] ❌ Backfill profile failed uid=${_maskId(uid)} err=$e');
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

  /// ✅ FIX OFFLINE — version stricte : lève AuthException(networkError) si
  /// problème réseau au lieu de retourner null. Cela permet à _hydrateUser de
  /// distinguer "profil absent" (null) de "DNS mort" (exception) et de ne
  /// JAMAIS créer/écraser un profil en offline.
  Future<Map<String, dynamic>?> _selectProfileRowStrict(String uid) async {
    try {
      final row = await _authRetry(
        () => _client.from('profiles').select('*').eq('id', uid).maybeSingle(),
        label: 'selectProfileRow[${_maskId(uid)}]',
      );
      if (row != null) return (row as Map).cast<String, dynamic>();
      return null; // vrai profil absent
    } catch (e) {
      if (_isNetworkError(e)) {
        debugPrint('[Auth] ⚠️ Profiles select OFFLINE uid=${_maskId(uid)}: $e');
        throw AuthException(AuthErrorCode.networkError, rawMessage: e.toString());
      }
      debugPrint('[Auth] ❌ Profiles select failed uid=${_maskId(uid)} err=$e');
      rethrow;
    }
  }

  /// ✅ FIX ID — [ignoreIfPresent] = true passe `ignoreDuplicates: true` à
  /// l'upsert Supabase (ON CONFLICT DO NOTHING) et **n'écrit PAS** les champs
  /// protégés (thix_id, registration_status) pour ne pas écraser les valeurs
  /// existantes lors d'un ensure.
  Future<void> _ensureProfileRow({
    required AppUser user,
    bool ignoreIfPresent = false,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();

    String? san(String? v, {int max = 500}) =>
        v == null ? null : _AuthValidators.sanitize(v, maxLength: max);

    final payload = <String, dynamic>{
      'id': user.id,
      // ✅ FIX ID — en mode "ensure" (ignoreIfPresent), on n'écrit PAS thix_id
      // ni registration_status. Ces champs sont gérés par les RPC serveur
      // (finalize_registration, thix_activate_account_after_payment).
      if (!ignoreIfPresent && !_isPendingThixId(user.thixId)) 'thix_id': user.thixId,
      if (user.thixChat.trim().isNotEmpty) 'thix_chat': san(user.thixChat, max: _kMaxChatLength),
      'display_name': san(user.displayName, max: _kMaxDisplayNameLength) ?? _kDefaultDisplayName,
      if (user.bio?.isNotEmpty == true) 'bio': san(user.bio, max: 500),
      if (user.profession?.isNotEmpty == true) 'profession': san(user.profession, max: 100),
      if (user.occupation?.isNotEmpty == true) 'occupation': san(user.occupation, max: 100),
      if (user.photoUrl?.isNotEmpty == true) 'avatar_url': san(user.photoUrl, max: 500),
      if (user.countryOrOrigin?.isNotEmpty == true) 'country_or_origin': san(user.countryOrOrigin, max: 100),
      if (user.contactPhone?.isNotEmpty == true) 'contact_phone': san(user.contactPhone, max: 20),
      if (user.maritalStatus?.isNotEmpty == true) 'marital_status': san(user.maritalStatus, max: 50),
      if (user.gender?.isNotEmpty == true) 'gender': san(user.gender, max: 20),
      if (user.dateOfBirth?.isNotEmpty == true) 'date_of_birth': san(user.dateOfBirth, max: 20),
      if (user.placeOfBirth?.isNotEmpty == true) 'place_of_birth': san(user.placeOfBirth, max: 100),
      if (user.nationality?.isNotEmpty == true) 'nationality': san(user.nationality, max: 100),
      if (user.address?.isNotEmpty == true) 'address': san(user.address, max: 500),
      if (user.fatherName?.isNotEmpty == true) 'father_name': san(user.fatherName, max: 100),
      if (user.motherName?.isNotEmpty == true) 'mother_name': san(user.motherName, max: 100),
      if (user.emergencyContactName?.isNotEmpty == true) 'emergency_contact_name': san(user.emergencyContactName, max: 100),
      if (user.emergencyContactPhone?.isNotEmpty == true) 'emergency_contact_phone': san(user.emergencyContactPhone, max: 20),
      if (user.emergencyContactRelation?.isNotEmpty == true) 'emergency_contact_relation': san(user.emergencyContactRelation, max: 50),
      if (user.languages.isNotEmpty)
        'languages': user.languages.map((l) => _AuthValidators.sanitize(l, maxLength: 50)).where((l) => l.isNotEmpty).toList(),
      if (!ignoreIfPresent) 'registration_status': user.registrationStatus ?? 'draft_step2',
      'updated_at': now,
    };

    try {
      if (ignoreIfPresent) {
        // ✅ FIX ID — bypass SupabaseSafeWrite pour passer ignoreDuplicates
        await _authRetry(
          () => _client.from('profiles').upsert(
            payload,
            onConflict: 'id',
            ignoreDuplicates: true, // ON CONFLICT DO NOTHING
          ),
          label: 'ensureProfileRow-soft[${_maskId(user.id)}]',
        );
      } else {
        await _authRetry(
          () => SupabaseSafeWrite.upsert(
            client: _client,
            table: 'profiles',
            payload: payload,
            criticalColumns: SupabaseSafeWrite.profilesCriticalColumns,
            onUnknownColumn: () async {
              try {
                await _client.functions.invoke('pgrst_schema_reload', body: const {});
              } catch (e) {
                debugPrint('[Auth] ⚠️ Schema reload invoke failed err=$e');
              }
            },
          ),
          label: 'ensureProfileRow[${_maskId(user.id)}]',
        );
      }
    } catch (e) {
      debugPrint('[Auth] ❌ Profiles upsert failed uid=${_maskId(user.id)} err=$e');
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
      _registerPushIfNeeded(user.id);
      // ✅ FIX SESSION
      unawaited(SessionSnapshot.save(hydrated));
      debugPrint('[Auth] ✓ Sign in successful: ${_maskId(user.id)}');
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

      if (session == null) {
        throw AuthException(AuthErrorCode.otpSent);
      }

      if (user.emailConfirmedAt != null) {
        try {
          await _client.auth.signOut();
        } catch (_) {}
        throw AuthException(AuthErrorCode.serverMisconfiguration);
      }

      try {
        await _client.auth.signOut();
      } catch (_) {}
      throw AuthException(AuthErrorCode.otpSent);
    } on sup.AuthException catch (e) {
      final mapped = _mapSupabaseAuthError(e, context: 'register');
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
        _registerPushIfNeeded(user.id);
        // ✅ FIX SESSION
        unawaited(SessionSnapshot.save(appUser));
        return appUser;
      }
      throw AuthException(AuthErrorCode.accountAlreadyExists);
    } on sup.AuthException catch (loginErr) {
      final msg = loginErr.message.toLowerCase();
      if (msg.contains('invalid login') || msg.contains('invalid credentials')) {
        throw AuthException(AuthErrorCode.accountExistsWrongPassword);
      }
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

      final appUser = await _hydrateUser(res.user!);
      _currentUser.value = appUser;
      _bindProfileSync(res.user!.id);
      _registerPushIfNeeded(res.user!.id);
      // ✅ FIX SESSION
      unawaited(SessionSnapshot.save(appUser));
      debugPrint('[Auth] ✓ OTP verified and user hydrated: ${_maskId(res.user!.id)}');
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

  /// ✅ FIX ID — idempotente côté client. Si l'utilisateur a déjà finalisé
  /// son inscription (registration_status active/completed ET thixId non
  /// pending), on retourne les valeurs connues SANS appeler la RPC serveur.
  /// Cela empêche la régénération d'un nouveau THIX ID après une perte de
  /// réseau qui avait fait rater la lecture précédente.
  @override
  Future<Map<String, dynamic>> finalizeRegistration({
    required String desiredChat,
    required String countryCode,
  }) async {
    final sanitizedChat = _AuthValidators.sanitize(desiredChat, maxLength: _kMaxChatLength);
    final sanitizedCountry = _AuthValidators.sanitize(countryCode, maxLength: _kMaxCountryCodeLength);

    // ✅ FIX ID — court-circuit si déjà finalisé
    final cur = _currentUser.value;
    final regStatus = (cur?.registrationStatus ?? '').toLowerCase();
    final alreadyDone = (regStatus == 'active' || regStatus == 'completed') &&
        cur != null &&
        !_isPendingThixId(cur.thixId) &&
        cur.thixId.trim().isNotEmpty &&
        (cur.thixChat.trim().isNotEmpty || sanitizedChat.isEmpty);

    if (alreadyDone) {
      debugPrint('[Auth] ℹ️ finalizeRegistration skipped (already done): '
          'thixId=${cur!.thixId}, chat=${cur.thixChat}, status=$regStatus');
      return {
        'thix_id': cur.thixId,
        'thix_chat': cur.thixChat,
        'registration_status': cur.registrationStatus ?? 'active',
      };
    }

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
      Map<String, dynamic> map;
      if (result is Map<String, dynamic>) {
        map = result;
      } else if (result is Map) {
        map = Map<String, dynamic>.from(result);
      } else {
        throw Exception('Invalid server response');
      }

      // ✅ FIX SESSION — mettre à jour le snapshot avec les nouvelles valeurs
      if (cur != null) {
        final updated = cur.copyWith(
          thixId: (map['thix_id'] ?? cur.thixId).toString(),
          thixChat: (map['thix_chat'] ?? cur.thixChat).toString(),
          registrationStatus: (map['registration_status'] ?? 'active').toString(),
        );
        _currentUser.value = updated;
        unawaited(SessionSnapshot.save(updated));
      }

      debugPrint('[Auth] ✓ Registration finalized');
      return map;
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
    // ✅ FIX SESSION
    unawaited(SessionSnapshot.save(hydrated));
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

  /// Déconnexion VOLONTAIRE — SEUL endroit où on efface le snapshot.
  @override
  Future<void> signOut() async {
    debugPrint('[Auth] 👋 Signing out (volontaire)');

    try {
      await PushNotificationService.instance
          .onSignedOut()
          .timeout(_kPushUnregisterTimeout);
    } catch (e) {
      debugPrint('[Auth] ⚠️ Push unregister avant déconnexion: $e');
    }
    _pushUserId = null;

    await _client.auth.signOut();
    // ✅ FIX SESSION — seul signOut volontaire efface le snapshot
    await _cleanupSession(clearSnapshot: true);
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
      debugPrint('[Auth] ✓ Current user updated: ${_maskId(user.id)}');
    } catch (e) {
      debugPrint('[Auth] ❌ UpdateCurrentUser failed uid=${_maskId(user.id)} err=$e');
      throw AuthException(AuthErrorCode.profileUpdateFailed);
    }
    _currentUser.value = safeUser;
    _bindProfileSync(user.id);
    // ✅ FIX SESSION
    unawaited(SessionSnapshot.save(safeUser));
  }

  // ==========================================================================
  // ERROR MAPPING
  // ==========================================================================

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
    _initialized = false;
    _sub?.cancel();
    _sub = null;
    _profileSub?.cancel();
    _profileSub = null;
    _currentUser.dispose();
  }
}
