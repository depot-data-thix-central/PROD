// lib/features/auth/presentation/providers/auth_controller.dart
//
// v2 :
//  ✅ FIX OFFLINE — isAuthenticated considère le snapshot Hive comme session valide
//  ✅ FIX SESSION — signOut() efface le snapshot (seul endroit volontaire)
//
// v1 : Legacy ChangeNotifier + AsyncNotifier Riverpod.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/auth/auth_manager.dart' show AuthManager, PhoneAuthSession, ProfileDraft;
import 'package:thix_id/auth/supabase_auth_manager.dart' show SupabaseAuthManager, AuthException, AuthErrorCode;
import 'package:thix_id/auth/auth_manager.dart';
import 'package:thix_id/auth/supabase_auth_manager.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/models/account_type.dart';
import 'package:thix_id/services/profile_service.dart';
import 'package:thix_id/services/session_snapshot.dart'; // ✅ NOUVEAU
import 'package:thix_id/supabase/supabase_config.dart';     // ✅ NOUVEAU

import 'package:thix_id/data/offline/chat_offline_cache.dart';

// ============================================================================
// PARTIE 1 : Legacy ChangeNotifier (utilisé par main.dart et app_router)
// ============================================================================

/// Contrôleur legacy basé sur ChangeNotifier.
class AuthController extends ChangeNotifier {
  static AuthController? _instance;
  static AuthController get instance => _instance ??= AuthController();

  final AuthManager _auth;

  AuthController({AuthManager? auth})
      : _auth = auth ?? SupabaseAuthManager(profiles: ProfileService()) {
    _instance ??= this;
    _auth.currentUserListenable.addListener(notifyListeners);
  }

  AppUser? get currentUser => _auth.currentUser;

  // ✅ FIX OFFLINE — considère le snapshot Hive comme session valide.
  //
  // Avant : si Supabase perdait la session (jeton refresh refusé après perte
  // de réseau prolongée), isAuthenticated retournait false → le router
  // redirigeait vers /login → l'utilisateur était forcé de se réinscrire.
  //
  // Maintenant : si on a un snapshot Hive récent, on considère l'utilisateur
  // comme "en attente de reconnexion" plutôt que "déconnecté". Le router
  // affichera /no-connection au lieu de /login.
  bool get isAuthenticated {
    if (currentUser != null) return true;
    if (SupabaseConfig.isInitialized &&
        Supabase.instance.client.auth.currentSession != null) {
      return true;
    }
    // ✅ Snapshot Hive = session "souvenue"
    return SessionSnapshot.load() != null;
  }

  Future<void> init() => _auth.init();

  Future<AppUser> signIn({
    required String identifier,
    required String password,
    required bool rememberMe,
  }) async {
    final u = await _auth.signInWithEmailOrThixId(
      identifier: identifier,
      password: password,
      rememberMe: rememberMe,
    );
    notifyListeners();
    return u;
  }

  Future<AppUser> registerPersonal({
    required String email,
    required String password,
    required String displayName,
    required bool rememberMe,
    ProfileDraft? profileDraft,
  }) async {
    final u = await _auth.registerPersonal(
      email: email,
      password: password,
      displayName: displayName,
      rememberMe: rememberMe,
      profileDraft: profileDraft,
    );
    notifyListeners();
    return u;
  }

  Future<AppUser> registerEnterprise({
    required String email,
    required String password,
    required String displayName,
    required bool rememberMe,
    ProfileDraft? profileDraft,
  }) async {
    final u = await _auth.registerWithEmail(
      email: email,
      password: password,
      displayName: displayName,
      accountType: AccountType.enterprise,
      rememberMe: rememberMe,
      profileDraft: profileDraft,
    );
    notifyListeners();
    return u;
  }

  Future<PhoneAuthSession> startPhoneAuth({required String phoneNumber}) {
    return _auth.startPhoneAuth(phoneNumber: phoneNumber);
  }

  Future<AppUser> confirmPhoneCode({
    required PhoneAuthSession session,
    required String smsCode,
    String? displayName,
    AccountType accountType = AccountType.personal,
  }) async {
    final u = await _auth.confirmPhoneCode(
      session: session,
      smsCode: smsCode,
      displayName: displayName,
      accountType: accountType,
    );
    notifyListeners();
    return u;
  }

  // ✅ FIX SESSION — efface le snapshot Hive en plus du cache chat.
  //
  // C'est le SEUL endroit où le snapshot est effacé. Une déconnexion
  // non-volontaire (jeton refresh refusé par Supabase) ne passe PAS par
  // cette méthode → le snapshot est préservé pour pouvoir restaurer
  // l'état de l'utilisateur au retour du réseau.
  Future<void> signOut() async {
    debugPrint('[AuthController] 👋 signOut() volontaire');

    try {
      await ChatOfflineCache.instance.clear();
    } catch (e) {
      debugPrint('[Auth] offline cache clear: $e');
    }

    // ✅ NOUVEAU : effacer le snapshot Hive
    try {
      await SessionSnapshot.clear();
    } catch (e) {
      debugPrint('[Auth] snapshot clear: $e');
    }

    await _auth.signOut();
    notifyListeners();
  }

  Future<void> updateCurrentUser(AppUser user) async {
    await _auth.updateCurrentUser(user);
    notifyListeners();
  }

  Future<void> verifyOTP({required String email, required String token}) async {
    await _auth.verifyOTP(email: email, token: token);
    notifyListeners();
  }

  Future<void> markEmailVerified() async {
    await _auth.markEmailVerified();
    notifyListeners();
  }

  Future<String> generateQrToken() async {
    return await _auth.generateQrToken();
  }

  Future<Map<String, dynamic>> finalizeRegistration({
    required String desiredChat,
    required String countryCode,
  }) async {
    final result = await _auth.finalizeRegistration(
      desiredChat: desiredChat,
      countryCode: countryCode,
    );
    notifyListeners();
    return result;
  }

  Future<void> consumeQrToken({required String token}) async {
    await _auth.consumeQrToken(token: token);
    notifyListeners();
  }

  Future<AppUser> refreshCurrentUser() async {
    final user = await _auth.refreshCurrentUser();
    notifyListeners();
    return user;
  }

  Future<void> resendOTP({required String email}) async {
    await _auth.resendOTP(email: email);
    notifyListeners();
  }
}

// ============================================================================
// PARTIE 2 : AsyncNotifier Riverpod
// ============================================================================

final authControllerProvider =
    AsyncNotifierProvider<AuthControllerNotifier, AppUser?>(
  AuthControllerNotifier.new,
);

class AuthControllerNotifier extends AsyncNotifier<AppUser?> {
  AuthController get _auth => AuthController.instance;

  @override
  Future<AppUser?> build() async {
    debugPrint('[AuthControllerNotifier] 🚀 Building');
    try {
      await _auth.init();
      return _auth.currentUser;
    } catch (e, st) {
      debugPrint('[AuthControllerNotifier] ❌ Init failed: $e');
      return Future.error(e, st);
    }
  }

  AppUser? get currentUser => _auth.currentUser;

  bool get isAdmin {
    final user = state.value;
    if (user == null) return false;
    return user.role == 'admin' || user.role == 'super_admin';
  }

  Future<void> signIn({
    required String identifier,
    required String password,
    required bool rememberMe,
  }) async {
    state = const AsyncLoading();
    try {
      final user = await _auth.signIn(
        identifier: identifier,
        password: password,
        rememberMe: rememberMe,
      );
      state = AsyncData(user);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<AppUser> registerPersonal({
    required String email,
    required String password,
    required String displayName,
    required bool rememberMe,
    Map<String, dynamic>? profileDraft,
  }) async {
    state = const AsyncLoading();
    try {
      final draft = profileDraft != null ? ProfileDraft.fromMap(profileDraft) : null;
      final user = await _auth.registerPersonal(
        email: email,
        password: password,
        displayName: displayName,
        rememberMe: rememberMe,
        profileDraft: draft,
      );
      state = AsyncData(user);
      return user;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<AppUser> registerEnterprise({
    required String email,
    required String password,
    required String displayName,
    required bool rememberMe,
    Map<String, dynamic>? profileDraft,
  }) async {
    state = const AsyncLoading();
    try {
      final draft = profileDraft != null ? ProfileDraft.fromMap(profileDraft) : null;
      final user = await _auth.registerEnterprise(
        email: email,
        password: password,
        displayName: displayName,
        rememberMe: rememberMe,
        profileDraft: draft,
      );
      state = AsyncData(user);
      return user;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<PhoneAuthSession> startPhoneAuth({required String phoneNumber}) {
    return _auth.startPhoneAuth(phoneNumber: phoneNumber);
  }

  Future<AppUser> confirmPhoneCode({
    required PhoneAuthSession session,
    required String smsCode,
    String? displayName,
    AccountType accountType = AccountType.personal,
  }) async {
    state = const AsyncLoading();
    try {
      final user = await _auth.confirmPhoneCode(
        session: session,
        smsCode: smsCode,
        displayName: displayName,
        accountType: accountType,
      );
      state = AsyncData(user);
      return user;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> verifyOTP({required String email, required String token}) async {
    state = const AsyncLoading();
    try {
      await _auth.verifyOTP(email: email, token: token);
      state = AsyncData(_auth.currentUser);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> resendOTP({required String email}) async {
    try {
      await _auth.resendOTP(email: email);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> markEmailVerified() async {
    try {
      await _auth.markEmailVerified();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<String> generateQrToken() {
    return _auth.generateQrToken();
  }

  Future<Map<String, dynamic>> finalizeRegistration({
    required String desiredChat,
    required String countryCode,
  }) async {
    state = const AsyncLoading();
    try {
      final result = await _auth.finalizeRegistration(
        desiredChat: desiredChat,
        countryCode: countryCode,
      );
      state = AsyncData(_auth.currentUser);
      return result;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> consumeQrToken({required String token}) async {
    try {
      await _auth.consumeQrToken(token: token);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<AppUser> refreshCurrentUser() async {
    final user = await _auth.refreshCurrentUser();
    state = AsyncData(user);
    return user;
  }

  Future<void> updateCurrentUser(AppUser user) async {
    state = const AsyncLoading();
    try {
      await _auth.updateCurrentUser(user);
      state = AsyncData(user);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  // Note : cette méthode délègue à AuthController.signOut() (Partie 1),
  // qui efface déjà le snapshot Hive. Aucune modification nécessaire ici.
  Future<void> signOut() async {
    state = const AsyncLoading();
    try {
      await _auth.signOut(); // ← appelle AuthController.signOut() corrigé
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
