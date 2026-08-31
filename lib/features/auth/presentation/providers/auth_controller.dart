// lib/auth/auth_controller_provider.dart
//
// ⚠️ ATTENTION : Ce fichier est un wrapper de compatibilité.
// L'API principale est dans lib/auth/auth_controller.dart (StateNotifier).
// Préférez utiliser directement authControllerProvider.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/auth/auth_controller.dart' show AuthController, AuthControllerState;
import 'package:thix_id/auth/auth_manager.dart' show PhoneAuthSession, ProfileDraft;
import 'package:thix_id/models/account_type.dart';
import 'package:thix_id/models/app_user.dart';

// ============================================================================
// PROVIDERS
// ============================================================================

/// ⚠️ Provider legacy de compatibilité.
///
/// **Préférez** `authControllerProvider` (StateNotifier) pour un usage moderne.
///
/// Ce provider expose l'API sous forme d'[AsyncNotifier] pour compatibilité
/// avec du code ancien utilisant `AsyncValue<AppUser?>`.
///
/// **Usage** :
/// ```dart
/// final authAsync = ref.watch(legacyAuthControllerProvider);
/// authAsync.when(
///   data: (user) => Text(user?.displayName ?? 'Guest'),
///   loading: () => CircularProgressIndicator(),
///   error: (e, _) => Text('Error: $e'),
/// );
/// ```
@Deprecated('Use authControllerProvider (StateNotifier) instead')
final legacyAuthControllerProvider =
    AsyncNotifierProvider<LegacyAuthControllerNotifier, AppUser?>(
  LegacyAuthControllerNotifier.new,
);

// ============================================================================
// CONVENIENCE PROVIDERS (à utiliser directement)
// ============================================================================

/// Indique si l'utilisateur courant est un administrateur.
///
/// Retourne `true` si `user.role == 'admin'`.
///
/// Usage :
/// ```dart
/// if (ref.watch(isAdminProvider)) {
///   // Afficher les fonctionnalités admin
/// }
/// ```
final isAdminProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.role == 'admin';
});

/// Indique si l'utilisateur courant est au moins modérateur.
///
/// Retourne `true` si l'utilisateur est `admin` ou `moderateur`.
///
/// Usage :
/// ```dart
/// if (ref.watch(isModeratorOrHigherProvider)) {
///   // Fonctionnalités de modération
/// }
/// ```
final isModeratorOrHigherProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  final role = user?.role;
  return role == 'admin' || role == 'moderateur';
});

/// Indique si l'utilisateur a un THIX ID réel (pas THIX-PENDING).
final hasRealThixIdProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.hasRealThixId ?? false;
});

/// Indique si l'utilisateur a un trial actif.
final hasActiveTrialProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.hasActiveTrial ?? false;
});

/// Indique si l'utilisateur a activé la 2FA.
final hasTwoFaEnabledProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.twoFaEnabled ?? false;
});

// ============================================================================
// ASYNC NOTIFIER (LEGACY COMPATIBILITY)
// ============================================================================

/// Notifier legacy utilisant AsyncNotifier pour compatibilité.
///
/// **⚠️ Déprécié** : Préférez le `AuthController` (StateNotifier) directement.
@Deprecated('Use AuthController StateNotifier instead')
class LegacyAuthControllerNotifier extends AsyncNotifier<AppUser?> {
  /// Référence vers le AuthController refactorisé (StateNotifier).
  AuthController get _controller => ref.read(authControllerProvider.notifier);

  /// État courant du AuthController.
  AuthControllerState get _state => ref.read(authControllerProvider);

  @override
  Future<AppUser?> build() async {
    debugPrint('[LegacyAuthNotifier] 🚀 Building');

    // Écoute les changements du StateNotifier pour synchroniser AsyncValue
    ref.listen<AuthControllerState>(
      authControllerProvider,
      (prev, next) {
        debugPrint('[LegacyAuthNotifier] 👤 State changed: ${next.currentUser?.id ?? "null"}');
        if (next.lastError != null && prev?.lastError != next.lastError) {
          state = AsyncError(next.lastError!, StackTrace.current);
        } else {
          state = AsyncData(next.currentUser);
        }
      },
    );

    try {
      await _controller.init();
      return _state.currentUser;
    } catch (e, st) {
      debugPrint('[LegacyAuthNotifier] ❌ Init failed: $e');
      return Future.error(e, st);
    }
  }

  // ── GETTERS ────────────────────────────────────────────────────────────

  /// Utilisateur courant (lecture directe, sans rechargement).
  AppUser? get currentUser => _state.currentUser;

  /// Vrai si l'utilisateur courant est administrateur.
  ///
  /// Basé sur le champ `registrationStatus` ou `occupation` dans AppUser.
  bool get isAdmin => _state.currentUser?.role == 'admin';

  /// Vrai si l'utilisateur courant est modérateur ou admin.
  bool get isModeratorOrHigher {
    final role = _state.currentUser?.role;
    return role == 'admin' || role == 'moderateur';
  }

  /// Vrai si l'utilisateur a un THIX ID réel.
  bool get hasRealThixId => _state.currentUser?.hasRealThixId ?? false;

  /// Vrai si l'utilisateur a un trial actif.
  bool get hasActiveTrial => _state.currentUser?.hasActiveTrial ?? false;

  // ── SIGN IN ────────────────────────────────────────────────────────────

  /// Connecte un utilisateur par email/THIX ID + mot de passe.
  ///
  /// Lance [AuthException] en cas d'échec.
  Future<void> signIn({
    required String identifier,
    required String password,
    required bool rememberMe,
  }) async {
    state = const AsyncLoading();
    debugPrint('[LegacyAuthNotifier] 🔐 signIn attempt');

    try {
      final user = await _controller.signIn(
        identifier: identifier,
        password: password,
        rememberMe: rememberMe,
      );
      state = AsyncData(user);
      debugPrint('[LegacyAuthNotifier] ✓ signIn success');
    } catch (e, st) {
      debugPrint('[LegacyAuthNotifier] ❌ signIn failed: $e');
      state = AsyncError(e, st);
      rethrow;
    }
  }

  // ── REGISTER ───────────────────────────────────────────────────────────

  /// Inscrit un utilisateur (personnel ou entreprise).
  ///
  /// Méthode privée factorisée (DRY).
  Future<AppUser> _register({
    required String email,
    required String password,
    required String displayName,
    required AccountType accountType,
    required bool rememberMe,
    ProfileDraft? profileDraft,
  }) async {
    state = const AsyncLoading();
    debugPrint('[LegacyAuthNotifier] 📝 register attempt (${accountType.name})');

    try {
      final user = accountType == AccountType.enterprise
          ? await _controller.registerEnterprise(
              email: email,
              password: password,
              displayName: displayName,
              rememberMe: rememberMe,
              profileDraft: profileDraft?.toMap(),
            )
          : await _controller.registerPersonal(
              email: email,
              password: password,
              displayName: displayName,
              rememberMe: rememberMe,
              profileDraft: profileDraft?.toMap(),
            );

      state = AsyncData(user);
      debugPrint('[LegacyAuthNotifier] ✓ register success: ${user.id}');
      return user;
    } catch (e, st) {
      debugPrint('[LegacyAuthNotifier] ❌ register failed: $e');
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Inscrit un utilisateur personnel.
  Future<AppUser> registerPersonal({
    required String email,
    required String password,
    required String displayName,
    required bool rememberMe,
    ProfileDraft? profileDraft,
  }) {
    return _register(
      email: email,
      password: password,
      displayName: displayName,
      accountType: AccountType.personal,
      rememberMe: rememberMe,
      profileDraft: profileDraft,
    );
  }

  /// Inscrit un utilisateur entreprise.
  Future<AppUser> registerEnterprise({
    required String email,
    required String password,
    required String displayName,
    required bool rememberMe,
    ProfileDraft? profileDraft,
  }) {
    return _register(
      email: email,
      password: password,
      displayName: displayName,
      accountType: AccountType.enterprise,
      rememberMe: rememberMe,
      profileDraft: profileDraft,
    );
  }

  // ── PHONE AUTH ─────────────────────────────────────────────────────────

  /// Démarre l'authentification par téléphone (non supporté en v2).
  Future<PhoneAuthSession> startPhoneAuth({required String phoneNumber}) {
    debugPrint('[LegacyAuthNotifier] 📱 startPhoneAuth');
    return _controller.startPhoneAuth(phoneNumber: phoneNumber);
  }

  /// Confirme un code SMS.
  Future<AppUser> confirmPhoneCode({
    required PhoneAuthSession session,
    required String smsCode,
    String? displayName,
    AccountType accountType = AccountType.personal,
  }) async {
    state = const AsyncLoading();
    debugPrint('[LegacyAuthNotifier] 📱 confirmPhoneCode');

    try {
      final user = await _controller.confirmPhoneCode(
        session: session,
        smsCode: smsCode,
        displayName: displayName,
        accountType: accountType,
      );
      state = AsyncData(user);
      debugPrint('[LegacyAuthNotifier] ✓ confirmPhoneCode success');
      return user;
    } catch (e, st) {
      debugPrint('[LegacyAuthNotifier] ❌ confirmPhoneCode failed: $e');
      state = AsyncError(e, st);
      rethrow;
    }
  }

  // ── OTP ────────────────────────────────────────────────────────────────

  /// Vérifie un code OTP email.
  Future<void> verifyOTP({required String email, required String token}) async {
    state = const AsyncLoading();
    debugPrint('[LegacyAuthNotifier] 🔑 verifyOTP');

    try {
      await _controller.verifyOTP(email: email, token: token);
      state = AsyncData(_controller.currentUser);
      debugPrint('[LegacyAuthNotifier] ✓ verifyOTP success');
    } catch (e, st) {
      debugPrint('[LegacyAuthNotifier] ❌ verifyOTP failed: $e');
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Renvoie un code OTP par email.
  Future<void> resendOTP({required String email}) async {
    state = const AsyncLoading();
    debugPrint('[LegacyAuthNotifier] 📧 resendOTP');

    try {
      await _controller.resendOTP(email: email);
      state = AsyncData(_controller.currentUser);
      debugPrint('[LegacyAuthNotifier] ✓ resendOTP success');
    } catch (e, st) {
      debugPrint('[LegacyAuthNotifier] ❌ resendOTP failed: $e');
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Marque l'email comme vérifié (RPC serveur).
  Future<void> markEmailVerified() async {
    debugPrint('[LegacyAuthNotifier] ✓ markEmailVerified');

    try {
      await _controller.markEmailVerified();
    } catch (e, st) {
      debugPrint('[LegacyAuthNotifier] ❌ markEmailVerified failed: $e');
      rethrow;
    }
  }

  // ── QR TOKEN ───────────────────────────────────────────────────────────

  /// Génère un token QR de parrainage.
  Future<String> generateQrToken() {
    debugPrint('[LegacyAuthNotifier] 🎫 generateQrToken');
    return _controller.generateQrToken();
  }

  /// Consomme un token QR de parrainage.
  Future<void> consumeQrToken({required String token}) async {
    debugPrint('[LegacyAuthNotifier] 🎟️ consumeQrToken');

    try {
      await _controller.consumeQrToken(token: token);
    } catch (e, st) {
      debugPrint('[LegacyAuthNotifier] ❌ consumeQrToken failed: $e');
      rethrow;
    }
  }

  /// Finalise l'inscription (génération THIX ID + validation chat).
  Future<Map<String, dynamic>> finalizeRegistration({
    required String desiredChat,
    required String countryCode,
  }) async {
    state = const AsyncLoading();
    debugPrint('[LegacyAuthNotifier] 🏁 finalizeRegistration');

    try {
      final result = await _controller.finalizeRegistration(
        desiredChat: desiredChat,
        countryCode: countryCode,
      );
      state = AsyncData(_controller.currentUser);
      debugPrint('[LegacyAuthNotifier] ✓ finalizeRegistration success');
      return result;
    } catch (e, st) {
      debugPrint('[LegacyAuthNotifier] ❌ finalizeRegistration failed: $e');
      state = AsyncError(e, st);
      rethrow;
    }
  }

  // ── SESSION MANAGEMENT ─────────────────────────────────────────────────

  /// Déconnecte l'utilisateur courant.
  Future<void> signOut() async {
    state = const AsyncLoading();
    debugPrint('[LegacyAuthNotifier] 👋 signOut');

    try {
      await _controller.signOut();
      state = const AsyncData(null);
      debugPrint('[LegacyAuthNotifier] ✓ signOut success');
    } catch (e, st) {
      debugPrint('[LegacyAuthNotifier] ❌ signOut failed: $e');
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Rafraîchit l'utilisateur courant depuis le serveur.
  Future<AppUser> refreshCurrentUser() async {
    debugPrint('[LegacyAuthNotifier] 🔄 refreshCurrentUser');

    try {
      final user = await _controller.refreshCurrentUser();
      state = AsyncData(user);
      debugPrint('[LegacyAuthNotifier] ✓ refreshCurrentUser success');
      return user;
    } catch (e, st) {
      debugPrint('[LegacyAuthNotifier] ❌ refreshCurrentUser failed: $e');
      rethrow;
    }
  }

  /// Met à jour le profil utilisateur courant.
  Future<void> updateCurrentUser(AppUser user) async {
    state = const AsyncLoading();
    debugPrint('[LegacyAuthNotifier] ✏️ updateCurrentUser');

    try {
      await _controller.updateCurrentUser(user);
      state = AsyncData(user);
      debugPrint('[LegacyAuthNotifier] ✓ updateCurrentUser success');
    } catch (e, st) {
      debugPrint('[LegacyAuthNotifier] ❌ updateCurrentUser failed: $e');
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

// ============================================================================
// BACKWARD COMPATIBILITY ALIAS
// ============================================================================

/// Alias pour compatibilité avec l'ancien code qui utilisait `authControllerProvider`
/// comme AsyncNotifier.
///
/// ⚠️ **Déprécié** : Migrez vers `authControllerProvider` (StateNotifier).
@Deprecated('Use authControllerProvider directly')
final authControllerLegacyProvider = legacyAuthControllerProvider;
