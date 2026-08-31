// lib/features/auth/presentation/providers/auth_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thix_id/auth/auth_controller.dart' as legacy;
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/auth/auth_manager.dart' show PhoneAuthSession;
import 'package:thix_id/models/account_type.dart';

final authControllerProvider = AsyncNotifierProvider<AuthControllerNotifier, AppUser?>(AuthControllerNotifier.new);

class AuthControllerNotifier extends AsyncNotifier<AppUser?> {
  legacy.AuthController get _auth => legacy.AuthController.instance;

  @override
  Future<AppUser?> build() async {
    await _auth.init();
    return _auth.currentUser;
  }

  // ============================================================
  // 🛡️ SÉCURITÉ : Getter d'administration direct (Enterprise Grade)
  // Permet de vérifier si l'utilisateur actuel est admin
  // ============================================================
  bool get isAdmin {
    final user = state.value;
    if (user == null) return false;
    
    // ⚠️ À ADAPTER SELON VOTRE MODÈLE 'AppUser' (ex: user.role == 'admin')
    return user.role == 'admin' || user.role == 'super_admin';
  }

  Future<void> signIn({required String identifier, required String password, required bool rememberMe}) async {
    state = const AsyncLoading();
    try {
      final user = await _auth.signIn(identifier: identifier, password: password, rememberMe: rememberMe);
      state = AsyncData(user);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<AppUser> registerPersonal({required String email, required String password, required String displayName, required bool rememberMe, Map<String, dynamic>? profileDraft}) async {
    state = const AsyncLoading();
    try {
      final user = await _auth.registerPersonal(email: email, password: password, displayName: displayName, rememberMe: rememberMe, profileDraft: profileDraft);
      state = AsyncData(user);
      return user;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<AppUser> registerEnterprise({required String email, required String password, required String displayName, required bool rememberMe, Map<String, dynamic>? profileDraft}) async {
    state = const AsyncLoading();
    try {
      final user = await _auth.registerEnterprise(email: email, password: password, displayName: displayName, rememberMe: rememberMe, profileDraft: profileDraft);
      state = AsyncData(user);
      return user;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<PhoneAuthSession> startPhoneAuth({required String phoneNumber}) => _auth.startPhoneAuth(phoneNumber: phoneNumber);

  Future<AppUser> confirmPhoneCode({required PhoneAuthSession session, required String smsCode, String? displayName, AccountType accountType = AccountType.personal}) async {
    state = const AsyncLoading();
    try {
      final user = await _auth.confirmPhoneCode(session: session, smsCode: smsCode, displayName: displayName, accountType: accountType);
      state = AsyncData(user);
      return user;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> verifyOTP({required String email, required String token}) async {
    await _auth.verifyOTP(email: email, token: token);
    state = AsyncData(_auth.currentUser);
  }

  Future<void> resendOTP({required String email}) async {
    await _auth.resendOTP(email: email);
  }

  Future<void> signOut() async {
    await _auth.signOut();
    state = const AsyncData(null);
  }

  Future<AppUser> refreshCurrentUser() async {
    final user = await _auth.refreshCurrentUser();
    state = AsyncData(user);
    return user;
  }

  Future<void> updateCurrentUser(AppUser user) async {
    await _auth.updateCurrentUser(user);
    state = AsyncData(user);
  }
}
