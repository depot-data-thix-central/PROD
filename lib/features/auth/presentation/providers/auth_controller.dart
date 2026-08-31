import 'package:flutter/foundation.dart';
import 'package:thix_id/auth/auth_manager.dart';
import 'package:thix_id/auth/supabase_auth_manager.dart'; // Restaure SupabaseAuthManager et AuthErrorCode
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/models/account_type.dart';
import 'package:thix_id/services/profile_service.dart';

// Le ChangeNotifier permet à main.dart et app_router de fonctionner correctement
class AuthController extends ChangeNotifier {
  static AuthController? _instance;
  static AuthController get instance => _instance ??= AuthController();

  final AuthManager _auth;

  AuthController({AuthManager? auth}) : _auth = auth ?? SupabaseAuthManager(profiles: ProfileService()) {
    _instance ??= this;
    _auth.currentUserListenable.addListener(notifyListeners);
  }

  AppUser? get currentUser => _auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  Future<void> init() => _auth.init();

  Future<AppUser> signIn({required String identifier, required String password, required bool rememberMe}) async {
    final u = await _auth.signInWithEmailOrThixId(identifier: identifier, password: password, rememberMe: rememberMe);
    notifyListeners();
    return u;
  }

  // Utilisation de ProfileDraft? au lieu de Map
  Future<AppUser> registerPersonal({required String email, required String password, required String displayName, required bool rememberMe, ProfileDraft? profileDraft}) async {
    final u = await _auth.registerPersonal(email: email, password: password, displayName: displayName, rememberMe: rememberMe, profileDraft: profileDraft);
    notifyListeners();
    return u;
  }

  // Utilisation de ProfileDraft? au lieu de Map
  Future<AppUser> registerEnterprise({required String email, required String password, required String displayName, required bool rememberMe, ProfileDraft? profileDraft}) async {
    final u = await _auth.registerWithEmail(email: email, password: password, displayName: displayName, accountType: AccountType.enterprise, rememberMe: rememberMe, profileDraft: profileDraft);
    notifyListeners();
    return u;
  }

  Future<PhoneAuthSession> startPhoneAuth({required String phoneNumber}) => _auth.startPhoneAuth(phoneNumber: phoneNumber);
  
  Future<AppUser> confirmPhoneCode({required PhoneAuthSession session, required String smsCode, String? displayName, AccountType accountType = AccountType.personal}) async {
    final u = await _auth.confirmPhoneCode(session: session, smsCode: smsCode, displayName: displayName, accountType: accountType);
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

  Future<Map<String, dynamic>> finalizeRegistration({required String desiredChat, required String countryCode}) async {
    final result = await _auth.finalizeRegistration(desiredChat: desiredChat, countryCode: countryCode);
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
