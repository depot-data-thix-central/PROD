// lib/features/auth/presentation/providers/auth_controller.dart
// lib/features/auth/presentation/providers/auth_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thix_id/auth/auth_manager.dart' show AuthManager, PhoneAuthSession, ProfileDraft;
import 'package:thix_id/auth/supabase_auth_manager.dart' show SupabaseAuthManager, AuthException, AuthErrorCode;
import 'package:thix_id/auth/auth_manager.dart';
import 'package:thix_id/auth/supabase_auth_manager.dart'; // ✅ Import complet (pas show)
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/models/account_type.dart';
import 'package:thix_id/services/profile_service.dart';

// Le reste du fichier reste IDENTIQUE
// ============================================================================
// PARTIE 1 : Legacy ChangeNotifier (utilisé par main.dart et app_router)
// ============================================================================

/// Contrôleur legacy basé sur ChangeNotifier.
///
/// Utilisé par :
/// - `main.dart` (via `ChangeNotifierProvider.value`)
/// - `app_router.dart` (via `refreshListenable`)
///
/// ⚠️ Ne pas supprimer : `main.dart` attend un `ChangeNotifier`.
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
  bool get isAuthenticated => currentUser != null;

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

  Future<void> signOut() async {
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
// PARTIE 2 : AsyncNotifier Riverpod (utilisé par tous les écrans modernes)
// ============================================================================

/// Provider principal Riverpod — API AsyncValue.
///
/// Usage dans les widgets (ConsumerStatefulWidget, ConsumerWidget) :
/// ```dart
/// // Lire l'état (AsyncValue<AppUser?>)
/// final authAsync = ref.watch(authControllerProvider);
/// final user = authAsync.valueOrNull;
///
/// // Actions
/// await ref.read(authControllerProvider.notifier).signIn(...);
/// await ref.read(authControllerProvider.notifier).signOut();
/// ```
final authControllerProvider =
    AsyncNotifierProvider<AuthControllerNotifier, AppUser?>(
  AuthControllerNotifier.new,
);

/// Notifier Async qui wrappe le legacy [AuthController] singleton.
///
/// Cette classe permet aux widgets modernes d'utiliser l'API `ref.watch`
/// tout en s'appuyant sur le singleton legacy (nécessaire pour `main.dart`).
class AuthControllerNotifier extends AsyncNotifier<AppUser?> {
  /// Accès au singleton legacy.
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

  // ── GETTERS ────────────────────────────────────────────────────────────

  /// Utilisateur courant (lecture directe, sans AsyncValue).
  AppUser? get currentUser => _auth.currentUser;

  /// Vrai si l'utilisateur courant est administrateur.
  bool get isAdmin {
    final user = state.value;
    if (user == null) return false;
    return user.role == 'admin' || user.role == 'super_admin';
  }

  // ── AUTH ACTIONS ───────────────────────────────────────────────────────

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
      // Convertir Map vers ProfileDraft si besoin
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

  Future<void> signOut() async {
    state = const AsyncLoading();
    try {
      await _auth.signOut();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
