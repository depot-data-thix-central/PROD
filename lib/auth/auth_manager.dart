import 'package:flutter/foundation.dart';
import 'package:thix_id/models/app_user.dart';

/// Gestionnaire d'authentification abstrait.
abstract class AuthManager {
  /// Utilisateur courant (ValueNotifier).
  ValueListenable<AppUser?> get currentUserListenable;

  /// Utilisateur courant (lecture directe).
  AppUser? get currentUser;

  /// Initialise le gestionnaire (écoute des changements d'état).
  Future<void> init();

  /// Connexion par email (ou THIX ID – ici seulement email).
  Future<AppUser> signInWithEmailOrThixId({
    required String identifier,
    required String password,
    required bool rememberMe,
  });

  /// Inscription par email (profil personnel).
  Future<AppUser> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
    required AccountType accountType,
    required bool rememberMe,
    Map<String, dynamic>? profileDraft,
  });

  /// Inscription simplifiée pour un compte personnel.
  Future<AppUser> registerPersonal({
    required String email,
    required String password,
    required String displayName,
    required bool rememberMe,
    Map<String, dynamic>? profileDraft,
  });

  /// Vérification du code OTP envoyé par email.
  Future<void> verifyOTP({
    required String email,
    required String token,
  });

  /// Force la récupération et l'hydratation de l'utilisateur depuis la session actuelle.
  /// Indispensable après des opérations asynchrones comme verifyOTP.
  Future<AppUser> refreshCurrentUser();

  /// Renvoie un code OTP par email.
  Future<void> resendOTP({required String email});

  /// Démarrage de l'authentification par téléphone (non implémenté).
  Future<PhoneAuthSession> startPhoneAuth({required String phoneNumber});

  /// Confirmation du code téléphone (non implémenté).
  Future<AppUser> confirmPhoneCode({
    required PhoneAuthSession session,
    required String smsCode,
    String? displayName,
    AccountType accountType = AccountType.personal,
  });

  /// Déconnexion.
  Future<void> signOut();

  /// Suppression du compte (non implémenté).
  Future<void> deleteAccount();

  /// Mise à jour de l'email.
  Future<void> updateEmail(String newEmail);

  /// Demande de réinitialisation du mot de passe.
  Future<void> requestPasswordReset(String email);

  /// Met à jour l'utilisateur courant (profil).
  Future<void> updateCurrentUser(AppUser user);
}

/// Session téléphone (placeholder).
class PhoneAuthSession {}
