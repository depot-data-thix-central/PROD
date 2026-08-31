// lib/features/auth/presentation/providers/auth_controller.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/auth/auth_manager.dart';
import 'package:thix_id/auth/supabase_auth_manager.dart' show AuthException;
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/services/profile_service.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kAuthTimeout = Duration(seconds: 30);
const Duration _kLongAuthTimeout = Duration(seconds: 60);
const int _kMaxEmailLength = 254;
const int _kMaxPasswordLength = 128;
const int _kMaxDisplayNameLength = 100;
const int _kMaxIdentifierLength = 100;
const int _kMaxOtpLength = 8;
const int _kMaxTokenLength = 100;
const int _kMaxChatLength = 21;
const int _kMaxCountryCodeLength = 3;
const int _kMaxPhoneLength = 20;

// ============================================================================
// VALIDATORS
// ============================================================================
class _AuthControllerValidators {
  _AuthControllerValidators._();

  /// Sanitize une entrée (XSS + caractères de contrôle)
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
}

// ============================================================================
// STATE
// ============================================================================

/// État immuable du contrôleur d'authentification.
///
/// Contient l'utilisateur courant et le flag d'authentification.
/// Tout changement déclenche une reconstruction des widgets consommateurs.
class AuthControllerState {
  /// Utilisateur courant (null si non authentifié)
  final AppUser? currentUser;

  /// Indicateur de chargement global (sign-in, register, etc.)
  final bool isLoading;

  /// Dernière erreur survenue (pour affichage UI)
  final Object? lastError;

  const AuthControllerState({
    this.currentUser,
    this.isLoading = false,
    this.lastError,
  });

  /// Vrai si un utilisateur est authentifié
  bool get isAuthenticated => currentUser != null;

  AuthControllerState copyWith({
    AppUser? currentUser,
    bool clearUser = false,
    bool? isLoading,
    Object? lastError,
    bool clearError = false,
  }) {
    return AuthControllerState(
      currentUser: clearUser ? null : (currentUser ?? this.currentUser),
      isLoading: isLoading ?? this.isLoading,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}

// ============================================================================
// AUTH CONTROLLER (StateNotifier)
// ============================================================================

/// Contrôleur d'authentification basé sur Riverpod StateNotifier.
///
/// Encapsule [AuthManager] (SupabaseAuthManager) et expose une API
/// réactive aux widgets via [authControllerProvider].
///
/// **Responsabilités** :
/// - Orchestration des opérations d'auth (sign-in, register, OTP, etc.)
/// - Gestion de l'état global utilisateur
/// - Validation et sanitization des inputs
/// - Logging structuré
/// - Gestion des erreurs (propagation de [AuthException])
///
/// **Cycle de vie** : Géré par Riverpod (pas de singleton manuel).
class AuthController extends StateNotifier<AuthControllerState> {
  final AuthManager _auth;
  StreamSubscription<dynamic>? _userSubscription;

  AuthController({AuthManager? auth})
      : _auth = auth ?? SupabaseAuthManager(profiles: ProfileService()),
        super(const AuthControllerState()) {
    _bindUserStream();
    debugPrint('[AuthController] 🚀 Initialized');
  }

  /// Bind sur le flux utilisateur du AuthManager
  void _bindUserStream() {
    // Le AuthManager expose currentUserListenable (ValueNotifier)
    // On s'abonne pour synchroniser l'état StateNotifier
    _userSubscription = null; // Pas de Stream, on utilise addListener ci-dessous

    final listenable = _auth.currentUserListenable;
    listenable.addListener(() {
      if (!mounted) return;
      final user = listenable.value;
      state = state.copyWith(
        currentUser: user,
        clearUser: user == null,
        clearError: true,
      );
      debugPrint('[AuthController] 👤 User state changed: ${user?.id ?? "null"}');
    });
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    // Note : le listener sur currentUserListenable reste actif
    // car le AuthManager est partagé. En production, prévoir un dispose dédié.
    debugPrint('[AuthController] 👋 Disposed');
    super.dispose();
  }

  // ── PUBLIC GETTERS ────────────────────────────────────────────────────────

  /// Utilisateur courant (null si non authentifié)
  AppUser? get currentUser => state.currentUser;

  /// Vrai si un utilisateur est authentifié
  bool get isAuthenticated => state.isAuthenticated;

  /// Vrai si une opération est en cours
  bool get isLoading => state.isLoading;

  // ── INIT ──────────────────────────────────────────────────────────────────

  /// Initialise le AuthManager sous-jacent (à appeler au démarrage de l'app).
  Future<void> init() async {
    debugPrint('[AuthController] ⚙️ Initializing underlying AuthManager');
    try {
      await _auth.init().timeout(_kAuthTimeout);
      debugPrint('[AuthController] ✓ AuthManager initialized');
    } catch (e) {
      debugPrint('[AuthController] ❌ AuthManager init failed: $e');
      rethrow;
    }
  }

  // ── SIGN IN ───────────────────────────────────────────────────────────────

  /// Connecte un utilisateur par email/THIX ID + mot de passe.
  ///
  /// Lance [AuthException] en cas d'échec (à catcher dans l'UI).
  Future<AppUser> signIn({
    required String identifier,
    required String password,
    required bool rememberMe,
  }) async {
    final sanitizedId = _AuthControllerValidators.sanitize(
      identifier,
      maxLength: _kMaxIdentifierLength,
    );
    final sanitizedPassword = _AuthControllerValidators.sanitize(
      password,
      maxLength: _kMaxPasswordLength,
    );

    if (sanitizedId.isEmpty) {
      throw AuthException(AuthErrorCode.identifierRequired);
    }
    if (sanitizedPassword.isEmpty) {
      throw AuthException(AuthErrorCode.passwordRequired);
    }

    debugPrint('[AuthController] 🔐 signIn attempt: ${_obfuscate(sanitizedId)}');

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final user = await _auth
          .signInWithEmailOrThixId(
            identifier: sanitizedId,
            password: sanitizedPassword,
            rememberMe: rememberMe,
          )
          .timeout(_kAuthTimeout);

      state = state.copyWith(currentUser: user, isLoading: false);
      debugPrint('[AuthController] ✓ signIn success: ${user.id}');
      return user;
    } catch (e) {
      debugPrint('[AuthController] ❌ signIn failed: $e');
      if (mounted) state = state.copyWith(isLoading: false, lastError: e);
      rethrow;
    }
  }

  // ── REGISTER PERSONAL ─────────────────────────────────────────────────────

  /// Inscrit un utilisateur personnel.
  Future<AppUser> registerPersonal({
    required String email,
    required String password,
    required String displayName,
    required bool rememberMe,
    Map<String, dynamic>? profileDraft,
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

  // ── REGISTER ENTERPRISE ───────────────────────────────────────────────────

  /// Inscrit un utilisateur entreprise.
  Future<AppUser> registerEnterprise({
    required String email,
    required String password,
    required String displayName,
    required bool rememberMe,
    Map<String, dynamic>? profileDraft,
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

  /// Implémentation commune pour register (DRY).
  Future<AppUser> _register({
    required String email,
    required String password,
    required String displayName,
    required AccountType accountType,
    required bool rememberMe,
    Map<String, dynamic>? profileDraft,
  }) async {
    final sanitizedEmail = _AuthControllerValidators.sanitize(
      email.toLowerCase(),
      maxLength: _kMaxEmailLength,
    );
    final sanitizedPassword = _AuthControllerValidators.sanitize(
      password,
      maxLength: _kMaxPasswordLength,
    );
    final sanitizedDisplayName = _AuthControllerValidators.sanitize(
      displayName,
      maxLength: _kMaxDisplayNameLength,
    );

    if (!_AuthControllerValidators.isValidEmail(sanitizedEmail)) {
      throw AuthException(AuthErrorCode.invalidEmail);
    }
    if (sanitizedPassword.isEmpty) {
      throw AuthException(AuthErrorCode.passwordRequired);
    }

    debugPrint('[AuthController] 📝 register attempt (${accountType.name}): $sanitizedEmail');

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final user = await _auth
          .registerWithEmail(
            email: sanitizedEmail,
            password: sanitizedPassword,
            displayName: sanitizedDisplayName.isEmpty ? 'Utilisateur THIX' : sanitizedDisplayName,
            accountType: accountType,
            rememberMe: rememberMe,
            profileDraft: profileDraft,
          )
          .timeout(_kAuthTimeout);

      state = state.copyWith(currentUser: user, isLoading: false);
      debugPrint('[AuthController] ✓ register success: ${user.id}');
      return user;
    } catch (e) {
      debugPrint('[AuthController] ❌ register failed: $e');
      if (mounted) state = state.copyWith(isLoading: false, lastError: e);
      rethrow;
    }
  }

  // ── PHONE AUTH ────────────────────────────────────────────────────────────

  /// Démarre l'authentification par téléphone (non supporté actuellement).
  Future<PhoneAuthSession> startPhoneAuth({required String phoneNumber}) async {
    final sanitizedPhone = _AuthControllerValidators.sanitize(
      phoneNumber,
      maxLength: _kMaxPhoneLength,
    );
    debugPrint('[AuthController] 📱 startPhoneAuth: ${_obfuscate(sanitizedPhone)}');
    return _auth.startPhoneAuth(phoneNumber: sanitizedPhone);
  }

  /// Confirme un code SMS.
  Future<AppUser> confirmPhoneCode({
    required PhoneAuthSession session,
    required String smsCode,
    String? displayName,
    AccountType accountType = AccountType.personal,
  }) async {
    final sanitizedCode = _AuthControllerValidators.sanitize(
      smsCode,
      maxLength: _kMaxOtpLength,
    );
    final sanitizedName = displayName != null
        ? _AuthControllerValidators.sanitize(displayName, maxLength: _kMaxDisplayNameLength)
        : null;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final user = await _auth
          .confirmPhoneCode(
            session: session,
            smsCode: sanitizedCode,
            displayName: sanitizedName,
            accountType: accountType,
          )
          .timeout(_kAuthTimeout);

      state = state.copyWith(currentUser: user, isLoading: false);
      debugPrint('[AuthController] ✓ confirmPhoneCode success: ${user.id}');
      return user;
    } catch (e) {
      debugPrint('[AuthController] ❌ confirmPhoneCode failed: $e');
      if (mounted) state = state.copyWith(isLoading: false, lastError: e);
      rethrow;
    }
  }

  // ── SIGN OUT ──────────────────────────────────────────────────────────────

  /// Déconnecte l'utilisateur courant.
  Future<void> signOut() async {
    debugPrint('[AuthController] 👋 signOut attempt');
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _auth.signOut().timeout(_kAuthTimeout);
      state = state.copyWith(clearUser: true, isLoading: false, clearError: true);
      debugPrint('[AuthController] ✓ signOut success');
    } catch (e) {
      debugPrint('[AuthController] ❌ signOut failed: $e');
      if (mounted) state = state.copyWith(isLoading: false, lastError: e);
      rethrow;
    }
  }

  // ── UPDATE CURRENT USER ───────────────────────────────────────────────────

  /// Met à jour l'utilisateur courant en base et en mémoire.
  Future<void> updateCurrentUser(AppUser user) async {
    debugPrint('[AuthController] ✏️ updateCurrentUser: ${user.id}');
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _auth.updateCurrentUser(user).timeout(_kAuthTimeout);
      state = state.copyWith(currentUser: user, isLoading: false);
      debugPrint('[AuthController] ✓ updateCurrentUser success');
    } catch (e) {
      debugPrint('[AuthController] ❌ updateCurrentUser failed: $e');
      if (mounted) state = state.copyWith(isLoading: false, lastError: e);
      rethrow;
    }
  }

  // ── VERIFY OTP ────────────────────────────────────────────────────────────

  /// Vérifie un code OTP (email ou SMS).
  Future<void> verifyOTP({required String email, required String token}) async {
    final sanitizedEmail = _AuthControllerValidators.sanitize(
      email.toLowerCase(),
      maxLength: _kMaxEmailLength,
    );
    final sanitizedToken = _AuthControllerValidators.sanitize(
      token,
      maxLength: _kMaxOtpLength,
    );

    if (!_AuthControllerValidators.isValidEmail(sanitizedEmail)) {
      throw AuthException(AuthErrorCode.invalidEmail);
    }
    if (sanitizedToken.isEmpty) {
      throw AuthException(AuthErrorCode.invalidOtp);
    }

    debugPrint('[AuthController] 🔑 verifyOTP: $sanitizedEmail');
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _auth
          .verifyOTP(email: sanitizedEmail, token: sanitizedToken)
          .timeout(_kAuthTimeout);
      state = state.copyWith(isLoading: false);
      debugPrint('[AuthController] ✓ verifyOTP success');
    } catch (e) {
      debugPrint('[AuthController] ❌ verifyOTP failed: $e');
      if (mounted) state = state.copyWith(isLoading: false, lastError: e);
      rethrow;
    }
  }

  // ── MARK EMAIL VERIFIED ───────────────────────────────────────────────────

  /// Marque l'email comme vérifié (RPC serveur).
  Future<void> markEmailVerified() async {
    debugPrint('[AuthController] ✓ markEmailVerified attempt');
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _auth.markEmailVerified().timeout(_kAuthTimeout);
      state = state.copyWith(isLoading: false);
      debugPrint('[AuthController] ✓ markEmailVerified success');
    } catch (e) {
      debugPrint('[AuthController] ❌ markEmailVerified failed: $e');
      if (mounted) state = state.copyWith(isLoading: false, lastError: e);
      rethrow;
    }
  }

  // ── GENERATE QR TOKEN ─────────────────────────────────────────────────────

  /// Génère un token QR de parrainage.
  Future<String> generateQrToken() async {
    debugPrint('[AuthController] 🎫 generateQrToken attempt');
    try {
      final token = await _auth.generateQrToken().timeout(_kAuthTimeout);
      debugPrint('[AuthController] ✓ generateQrToken success');
      return token;
    } catch (e) {
      debugPrint('[AuthController] ❌ generateQrToken failed: $e');
      rethrow;
    }
  }

  // ── FINALIZE REGISTRATION ─────────────────────────────────────────────────

  /// Finalise l'inscription (génération THIX ID + validation chat).
  Future<Map<String, dynamic>> finalizeRegistration({
    required String desiredChat,
    required String countryCode,
  }) async {
    final sanitizedChat = _AuthControllerValidators.sanitize(
      desiredChat,
      maxLength: _kMaxChatLength,
    );
    final sanitizedCountry = _AuthControllerValidators.sanitize(
      countryCode,
      maxLength: _kMaxCountryCodeLength,
    );

    debugPrint('[AuthController] 🏁 finalizeRegistration: chat=$sanitizedChat, country=$sanitizedCountry');
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await _auth
          .finalizeRegistration(
            desiredChat: sanitizedChat,
            countryCode: sanitizedCountry,
          )
          .timeout(_kLongAuthTimeout);

      state = state.copyWith(isLoading: false);
      debugPrint('[AuthController] ✓ finalizeRegistration success');
      return result;
    } catch (e) {
      debugPrint('[AuthController] ❌ finalizeRegistration failed: $e');
      if (mounted) state = state.copyWith(isLoading: false, lastError: e);
      rethrow;
    }
  }

  // ── CONSUME QR TOKEN ──────────────────────────────────────────────────────

  /// Consomme un token QR de parrainage.
  Future<void> consumeQrToken({required String token}) async {
    final sanitizedToken = _AuthControllerValidators.sanitize(
      token,
      maxLength: _kMaxTokenLength,
    );

    debugPrint('[AuthController] 🎟️ consumeQrToken attempt');
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _auth.consumeQrToken(token: sanitizedToken).timeout(_kAuthTimeout);
      state = state.copyWith(isLoading: false);
      debugPrint('[AuthController] ✓ consumeQrToken success');
    } catch (e) {
      debugPrint('[AuthController] ❌ consumeQrToken failed: $e');
      if (mounted) state = state.copyWith(isLoading: false, lastError: e);
      rethrow;
    }
  }

  // ── REFRESH CURRENT USER ──────────────────────────────────────────────────

  /// Rafraîchit l'utilisateur courant depuis le serveur.
  Future<AppUser> refreshCurrentUser() async {
    debugPrint('[AuthController] 🔄 refreshCurrentUser attempt');
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final user = await _auth.refreshCurrentUser().timeout(_kAuthTimeout);
      state = state.copyWith(currentUser: user, isLoading: false);
      debugPrint('[AuthController] ✓ refreshCurrentUser success: ${user.id}');
      return user;
    } catch (e) {
      debugPrint('[AuthController] ❌ refreshCurrentUser failed: $e');
      if (mounted) state = state.copyWith(isLoading: false, lastError: e);
      rethrow;
    }
  }

  // ── RESEND OTP ────────────────────────────────────────────────────────────

  /// Renvoie un code OTP à l'email donné.
  Future<void> resendOTP({required String email}) async {
    final sanitizedEmail = _AuthControllerValidators.sanitize(
      email.toLowerCase(),
      maxLength: _kMaxEmailLength,
    );

    if (!_AuthControllerValidators.isValidEmail(sanitizedEmail)) {
      throw AuthException(AuthErrorCode.invalidEmail);
    }

    debugPrint('[AuthController] 📧 resendOTP: $sanitizedEmail');
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _auth.resendOTP(email: sanitizedEmail).timeout(_kAuthTimeout);
      state = state.copyWith(isLoading: false);
      debugPrint('[AuthController] ✓ resendOTP success');
    } catch (e) {
      debugPrint('[AuthController] ❌ resendOTP failed: $e');
      if (mounted) state = state.copyWith(isLoading: false, lastError: e);
      rethrow;
    }
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────

  /// Obfusque un identifiant pour les logs (sécurité)
  String _obfuscate(String s) {
    if (s.length <= 6) return '${s[0]}***';
    return '${s.substring(0, 3)}...${s.substring(s.length - 3)}';
  }

  /// Efface la dernière erreur stockée
  void clearLastError() {
    state = state.copyWith(clearError: true);
  }
}

// ============================================================================
// PROVIDERS
// ============================================================================

/// Provider pour le AuthManager (injectable pour tests).
final authManagerProvider = Provider<AuthManager>((ref) {
  return SupabaseAuthManager(profiles: ProfileService());
});

/// Provider principal pour l'AuthController.
///
/// Usage dans les widgets :
/// ```dart
/// // Lire l'état (rebuild auto)
/// final authState = ref.watch(authControllerProvider);
/// final user = authState.currentUser;
///
/// // Appeler une action (pas de rebuild)
/// ref.read(authControllerProvider.notifier).signIn(...);
/// ```
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthControllerState>((ref) {
  final auth = ref.watch(authManagerProvider);
  return AuthController(auth: auth);
});

/// Provider raccourci pour l'utilisateur courant uniquement.
///
/// Usage :
/// ```dart
/// final user = ref.watch(currentUserProvider);
/// ```
final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authControllerProvider).currentUser;
});

/// Provider raccourci pour l'état d'authentification.
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authControllerProvider).isAuthenticated;
});
