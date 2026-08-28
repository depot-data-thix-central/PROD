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
import 'package:thix_id/services/thix_id_service.dart';
import 'package:thix_id/supabase/supabase_config.dart';

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

  @override
  Future<void> init() async {
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
      } catch (e, st) {
        debugPrint('SupabaseAuthManager: auth state hydrate failed err=$e\n$st');
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
    } catch (e, st) {
      debugPrint('SupabaseAuthManager: initial hydration failed err=$e\n$st');
    }
  }

  Future<void> _cleanupSession() async {
    await _profileSub?.cancel();
    _profileSub = null;
    _currentUser.value = null;
    unawaited(PushNotificationService.instance.onSignedOut());
  }

  bool _isPendingThixId(String? id) {
    if (id == null) return true;
    final v = id.trim().toUpperCase();
    return v.isEmpty ||
        v == 'THIX-PENDING' ||
        v == 'THIX-000000' ||
        v.startsWith('THIX-PENDING-');
  }

  void _bindProfileSync(String uid) {
    unawaited(_profileSub?.cancel());

    _profileSub = _profiles.streamMyProfile(uid).listen(
      (p) {
        if (p == null) return;
        final cur = _currentUser.value;
        if (cur == null || cur.id != uid) return;

        final incomingThixId = p.thixId.trim();
        final resolvedThixId = (!_isPendingThixId(incomingThixId))
            ? incomingThixId
            : cur.thixId;

        final merged = cur.copyWith(
          thixId: resolvedThixId,
          thixChat: (p.thixChat ?? '').trim().isEmpty
              ? cur.thixChat
              : (p.thixChat ?? '').trim(),
          displayName: p.displayName.trim().isEmpty
              ? cur.displayName
              : p.displayName.trim(),
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
      },
      onError: (e, st) {
        debugPrint('SupabaseAuthManager: profile sync stream failed uid=$uid err=$e\n$st');
      },
    );
  }

  Future<AppUser> _hydrateUser(User user) async {
    final uid = user.id;
    final email = (user.email ?? '').toLowerCase();
    final meta = (user.userMetadata ?? const <String, dynamic>{});

    final row = await _selectProfileRow(uid);
    if (row == null) {
      String? s(String k) {
        final v = meta[k];
        if (v == null) return null;
        final t = v.toString().trim();
        return t.isEmpty ? null : t;
      }

      List<String> strList(String k) {
        final v = meta[k];
        if (v is List) {
          return v.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false);
        }
        return const <String>[];
      }

      final realThixId = ThixIdService.generate();
      final tempThixChat = '@user_${uid.substring(0, 5).toLowerCase()}${DateTime.now().millisecondsSinceEpoch % 1000}';

      final base = AppUser(
        id: uid,
        thixId: realThixId,
        thixChat: tempThixChat,
        thixScore: null,
        email: email,
        phone: user.phone,
        displayName: (s('display_name') ?? 'Utilisateur THIX'),
        accountType: _accountTypeFromMeta(meta),
        photoUrl: null,
        bio: s('bio'),
        countryOrOrigin: s('country_or_origin') ?? s('countryOrOrigin'),
        contactPhone: s('contact_phone') ?? s('contactPhone'),
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
      return base;
    }

    var appUser = _appUserFromProfileRow(uid: uid, email: email, row: row, phone: user.phone);

    if (_isPendingThixId(appUser.thixId)) {
      try {
        final realId = ThixIdService.generate();
        await _client.from('profiles').update({
          'thix_id': realId,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', uid);

        appUser = appUser.copyWith(thixId: realId, updatedAt: DateTime.now());
        debugPrint('SupabaseAuthManager: PENDING remplacé par $realId pour uid=$uid');
      } catch (e) {
        debugPrint('SupabaseAuthManager: échec remplacement PENDING uid=$uid err=$e');
      }
    }

    return appUser;
  }

  AccountType _accountTypeFromMeta(Map<String, dynamic>? meta) {
    final raw = (meta?['account_type'] ?? meta?['accountType'] ?? '').toString().trim().toLowerCase();
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
    final accountType = AccountType.values.firstWhere((e) => e.name == accountTypeRaw, orElse: () => AccountType.personal);

    List<String> strList(Object? v) => (v is List) ? v.whereType<String>().toList(growable: false) : const <String>[];
    List<Map<String, dynamic>> mapList(Object? v) => (v is List) ? v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false) : const <Map<String, dynamic>>[];

    final rawThixId = (row['thix_id'] ?? row['thixId'] ?? row['thix_uid'] ?? '').toString().trim();

    return AppUser(
      id: uid,
      thixId: rawThixId.isEmpty ? '' : rawThixId,
      thixChat: (row['thix_chat'] ?? row['thixChat'] ?? '').toString(),
      thixScore: (row['thix_score'] as num?)?.toInt(),
      email: email,
      phone: phone,
      displayName: (row['display_name'] ?? row['displayName'] ?? 'Utilisateur THIX').toString(),
      accountType: accountType,
      photoUrl: (row['avatar_url'] ?? row['photo_url'])?.toString(),
      bio: row['bio']?.toString(),
      countryOrOrigin: (row['country_or_origin'] ?? row['countryOrOrigin'])?.toString(),
      contactPhone: (row['contact_phone'] ?? row['contactPhone'])?.toString(),
      maritalStatus: (row['marital_status'] ?? row['maritalStatus'])?.toString(),
      gender: row['gender']?.toString(),
      occupation: (row['occupation'] ?? row['occupation_title'])?.toString(),
      profession: (row['profession'] ?? row['job_title'])?.toString(),
      dateOfBirth: (row['date_of_birth'] ?? row['dateOfBirth'])?.toString(),
      placeOfBirth: (row['place_of_birth'] ?? row['placeOfBirth'])?.toString(),
      nationality: row['nationality']?.toString(),
      address: row['address']?.toString(),
      fatherName: (row['father_name'] ?? row['fatherName'])?.toString(),
      motherName: (row['mother_name'] ?? row['motherName'])?.toString(),
      emergencyContactName: (row['emergency_contact_name'] ?? row['emergencyContactName'])?.toString(),
      emergencyContactPhone: (row['emergency_contact_phone'] ?? row['emergencyContactPhone'])?.toString(),
      emergencyContactRelation: (row['emergency_contact_relation'] ?? row['emergencyContactRelation'])?.toString(),
      registrationStatus: (row['registration_status'] ?? row['registrationStatus'])?.toString(),
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
      final row = await _client.from('profiles').select('*').eq('id', uid).maybeSingle();
      if (row != null) return (row as Map).cast<String, dynamic>();
    } catch (e) {
      debugPrint('SupabaseAuthManager: profiles select by id failed uid=$uid err=$e');
    }
    return null;
  }

  Future<void> _ensureProfileRow({required AppUser user}) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'id': user.id,
      'thix_id': user.thixId,
      'thix_chat': user.thixChat,
      'bio': user.bio,
      'profession': user.profession,
      'occupation': user.occupation,
      'display_name': user.displayName,
      'avatar_url': user.photoUrl,
      'country_or_origin': user.countryOrOrigin,
      'contact_phone': user.contactPhone,
      'marital_status': user.maritalStatus,
      'gender': user.gender,
      'date_of_birth': user.dateOfBirth,
      'place_of_birth': user.placeOfBirth,
      'nationality': user.nationality,
      'address': user.address,
      'father_name': user.fatherName,
      'mother_name': user.motherName,
      'emergency_contact_name': user.emergencyContactName,
      'emergency_contact_phone': user.emergencyContactPhone,
      'emergency_contact_relation': user.emergencyContactRelation,
      'languages': user.languages,
      'registration_status': user.registrationStatus,
      'created_at': now,
      'updated_at': now,
    };

    try {
      await SupabaseSafeWrite.upsert(
        client: _client,
        table: 'profiles',
        payload: payload,
        onUnknownColumn: () async {
          try {
            await _client.functions.invoke('pgrst_schema_reload', body: const {});
          } catch (e) {
            debugPrint('SupabaseAuthManager: schema reload invoke failed err=$e');
            rethrow;
          }
        },
      );
    } catch (e) {
      debugPrint('SupabaseAuthManager: profiles upsert failed uid=${user.id} err=$e');
      rethrow;
    }
  }

  bool _isValidEmail(String email) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

  @override
  Future<AppUser> signInWithEmailOrThixId({
    required String identifier,
    required String password,
    required bool rememberMe,
  }) async {
    final id = identifier.trim();
    if (id.isEmpty) throw AuthException('Identifiant requis.');
    if (password.isEmpty) throw AuthException('Mot de passe requis.');

    if (!id.contains('@')) {
      throw AuthException('Connexion via THIX ID non disponible. Utilisez votre email.');
    }

    try {
      final res = await _client.auth.signInWithPassword(email: id.toLowerCase(), password: password);
      final user = res.user;
      if (user == null) throw AuthException('Connexion échouée.');

      final hydrated = await _hydrateUser(user);
      _currentUser.value = hydrated;
      _bindProfileSync(user.id);
      return hydrated;
    } on sup.AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      debugPrint('SupabaseAuthManager: signIn crash err=$e');
      throw AuthException('Erreur technique (Base de données). Veuillez réessayer.');
    }
  }

  @override
  Future<AppUser> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
    required AccountType accountType,
    required bool rememberMe,
    Map<String, dynamic>? profileDraft,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (!_isValidEmail(normalizedEmail)) {
      throw AuthException('Email invalide.');
    }
    // ⚠️ Validation minimale ici. La validation NIST complète est dans PersonalRegistrationPage.
    if (password.trim().length < 8) {
      throw AuthException('Le mot de passe doit contenir au moins 8 caractères.');
    }

    try {
      final userMeta = <String, dynamic>{
        'display_name': displayName.trim().isEmpty ? 'Utilisateur THIX' : displayName.trim(),
        'account_type': accountType.name,
        ...?profileDraft,
      };

      final res = await _client.auth.signUp(email: normalizedEmail, password: password, data: userMeta);

      final session = res.session;
      final user = res.user;

      if (user == null || session == null) {
        throw AuthException('Inscription enregistrée. Confirmez votre email pour continuer.');
      }

      final appUser = await _hydrateUser(user);
      _currentUser.value = appUser;
      _bindProfileSync(user.id);
      return appUser;
    } on sup.AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      debugPrint('SupabaseAuthManager: register crash err=$e');
      throw AuthException('Erreur Base/Code : $e');
    }
  }

  @override
  Future<AppUser> registerPersonal({
    required String email,
    required String password,
    required String displayName,
    required bool rememberMe,
    Map<String, dynamic>? profileDraft,
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

  @override
  Future<void> verifyOTP({required String email, required String token}) async {
    try {
      // ⭐ SUPPRIMÉ : Le contournement needsVerification = false
      // L'OTP doit TOUJOURS être validé cryptographiquement par Supabase
      final res = await _client.auth.verifyOTP(
        email: email.trim().toLowerCase(),
        token: token.trim(),
        type: OtpType.signup,
      );

      if (res.session == null && res.user == null) {
        throw AuthException('Le code saisi est invalide ou a expiré. Demandez un nouveau code.');
      }

      await refreshCurrentUser();
    } on AuthException {
      rethrow;
    } on sup.AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('expired') || msg.contains('invalid') || msg.contains('otp') || msg.contains('token')) {
        throw AuthException('Le code saisi est invalide ou a expiré. Demandez un nouveau code.');
      }
      throw AuthException(e.message);
    } catch (e) {
      debugPrint('SupabaseAuthManager: verifyOTP failed err=$e');
      throw AuthException(e.toString());
    }
  }

  // ⭐ NOUVEAU : Appelle la RPC mark_email_verified
  @override
  Future<void> markEmailVerified() async {
    try {
      await _client.rpc('mark_email_verified');
    } catch (e) {
      debugPrint('SupabaseAuthManager: markEmailVerified failed err=$e');
      throw AuthException('Impossible de marquer l\'email comme vérifié.');
    }
  }

  // ⭐ NOUVEAU : Génère un token QR pour parrainage
  @override
  Future<String> generateQrToken() async {
    try {
      final result = await _client.rpc('generate_qr_activation_token');
      return result.toString();
    } catch (e) {
      debugPrint('SupabaseAuthManager: generateQrToken failed err=$e');
      throw AuthException('Impossible de générer le QR de parrainage.');
    }
  }

  // ⭐ NOUVEAU : Finalise l'inscription (THIX ID + THIX CHAT + activation)
  @override
  Future<Map<String, dynamic>> finalizeRegistration({
    required String desiredChat,
    required String countryCode,
  }) async {
    try {
      final result = await _client.rpc(
        'finalize_registration',
        params: {
          'p_desired_chat': desiredChat,
          'p_country_code': countryCode,
        },
      );

      if (result is Map<String, dynamic>) {
        return result;
      } else if (result is Map) {
        return Map<String, dynamic>.from(result);
      } else {
        throw Exception('Réponse serveur invalide.');
      }
    } catch (e) {
      debugPrint('SupabaseAuthManager: finalizeRegistration failed err=$e');
      throw AuthException('Impossible de finaliser l\'inscription.');
    }
  }

  // ⭐ NOUVEAU : Consomme un token QR (côté parrain)
  @override
  Future<void> consumeQrToken({required String token}) async {
    try {
      await _client.rpc('consume_qr_activation_token', params: {'p_token': token});
    } catch (e) {
      debugPrint('SupabaseAuthManager: consumeQrToken failed err=$e');
      throw AuthException('Impossible de valider le parrainage.');
    }
  }

  @override
  Future<AppUser> refreshCurrentUser() async {
    final session = _client.auth.currentSession;
    if (session == null) {
      throw AuthException("La vérification a réussi mais aucune session n'a été créée.");
    }

    final hydrated = await _hydrateUser(session.user);
    _currentUser.value = hydrated;
    _bindProfileSync(session.user.id);
    return hydrated;
  }

  @override
  Future<void> resendOTP({required String email}) async {
    try {
      await _client.auth.resend(type: OtpType.signup, email: email.trim().toLowerCase());
    } on sup.AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      debugPrint('SupabaseAuthManager: resendOTP failed err=$e');
      throw AuthException(e.toString());
    }
  }

  @override
  Future<PhoneAuthSession> startPhoneAuth({required String phoneNumber}) {
    throw AuthException('Connexion téléphone indisponible dans cette version.');
  }

  @override
  Future<AppUser> confirmPhoneCode({
    required PhoneAuthSession session,
    required String smsCode,
    String? displayName,
    AccountType accountType = AccountType.personal,
  }) {
    throw AuthException('Connexion téléphone indisponible dans cette version.');
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
    await _cleanupSession();
  }

  @override
  Future<void> deleteAccount() async {
    // TODO: Implémenter une RPC serveur pour supprimer le compte (RGPD)
    throw AuthException('Suppression du compte indisponible (nécessite une fonction serveur sécurisée).');
  }

  @override
  Future<void> updateEmail(String newEmail) async {
    final normalized = newEmail.trim().toLowerCase();
    if (!_isValidEmail(normalized)) throw AuthException('Email invalide.');
    try {
      await _client.auth.updateUser(UserAttributes(email: normalized));
    } catch (e) {
      throw AuthException('Impossible de mettre à jour l\'email.');
    }
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    final normalized = email.trim().toLowerCase();
    if (!_isValidEmail(normalized)) throw AuthException('Email invalide.');
    try {
      await _client.auth.resetPasswordForEmail(normalized);
    } catch (e) {
      throw AuthException('Impossible d\'envoyer la demande de réinitialisation.');
    }
  }

  @override
  Future<void> updateCurrentUser(AppUser user) async {
    final current = currentUser;
    if (current == null) throw AuthException('Session expirée.');
    if (current.id != user.id) {
      throw AuthException('Utilisateur courant différent.');
    }

    // ⭐ FILTRAGE : Supprimer les colonnes sensibles avant l'upsert
    final safeUser = user.copyWith(
      registrationStatus: current.registrationStatus, // Ne pas permettre le changement
      thixId: current.thixId, // Ne pas permettre le changement
      thixScore: current.thixScore, // Ne pas permettre le changement
    );

    try {
      await _ensureProfileRow(user: safeUser);
      await _profiles.ensureProfileExists(user: safeUser);
    } catch (e) {
      debugPrint('SupabaseAuthManager: updateCurrentUser failed uid=${user.id} err=$e');
      throw AuthException('Erreur lors de la mise à jour du profil.');
    }
    _currentUser.value = safeUser;
    _bindProfileSync(user.id);
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => 'AuthException: $message';
}
