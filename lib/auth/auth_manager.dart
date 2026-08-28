import 'package:flutter/foundation.dart';
import 'package:thix_id/models/app_user.dart';

/// ============================================================================
/// THIX ID — Gestionnaire d'authentification abstrait (v2 sécurisée)
/// ============================================================================
abstract class AuthManager {
  /// Utilisateur courant (ValueNotifier pour Riverpod/ChangeNotifier).
  ValueListenable<AppUser?> get currentUserListenable;

  /// Utilisateur courant (lecture directe).
  AppUser? get currentUser;

  /// Initialise le gestionnaire (écoute des changements d'état d'auth).
  Future<void> init();

  // ==========================================================================
  // AUTHENTIFICATION CLASSIQUE
  // ==========================================================================

  /// Connexion par email (ou THIX ID — mais ici uniquement email).
  Future<AppUser> signInWithEmailOrThixId({
    required String identifier,
    required String password,
    required bool rememberMe,
  });

  /// Inscription par email (profil personnel ou entreprise).
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

  /// Vérification cryptographique du code OTP envoyé par email.
  /// ⚠️ Doit TOUJOURS valider le code côté serveur (pas de bypass client).
  Future<void> verifyOTP({
    required String email,
    required String token,
  });

  /// Marque le compte comme `email_verified` côté serveur (RPC).
  /// À appeler immédiatement après verifyOTP() réussi.
  Future<void> markEmailVerified();

  /// Force la récupération et l'hydratation de l'utilisateur depuis la session actuelle.
  /// Indispensable après des opérations asynchrones comme verifyOTP.
  Future<AppUser> refreshCurrentUser();

  /// Renvoie un code OTP par email (avec throttling serveur).
  Future<void> resendOTP({required String email});

  // ==========================================================================
  // PARRAINAGE QR — FLUX SÉCURISÉ
  // ==========================================================================

  /// Génère un nonce opaque pour le QR de parrainage.
  /// ⚠️ Prérequis : email vérifié (account_status = 'email_verified').
  /// Retourne le nonce à encoder dans le QR (jamais stocké en clair côté serveur).
  Future<String> generateQrToken();

  /// Consomme un token QR scanné (appelé par le parrain accrédité).
  /// ⚠️ Prérequis : parrain `is_accredited_sponsor = true`.
  /// Le filleul passe à `account_status = 'sponsored'` (pas encore actif).
  Future<void> consumeQrToken({required String token});

  /// Finalise l'inscription de manière atomique :
  ///   - Valide le THIX CHAT (réservé + anti-squatting)
  ///   - Génère le THIX ID officiel (via RPC serveur)
  ///   - Passe le compte à `account_status = 'active'`
  /// Retourne { thix_id, thix_chat, parrainage }.
  Future<Map<String, dynamic>> finalizeRegistration({
    required String desiredChat,
    required String countryCode,
  });

  // ==========================================================================
  // AUTHENTIFICATION TÉLÉPHONE (PLACEHOLDER)
  // ==========================================================================

  /// Démarrage de l'authentification par téléphone (non implémenté en v2).
  Future<PhoneAuthSession> startPhoneAuth({required String phoneNumber});

  /// Confirmation du code téléphone (non implémenté en v2).
  Future<AppUser> confirmPhoneCode({
    required PhoneAuthSession session,
    required String smsCode,
    String? displayName,
    AccountType accountType = AccountType.personal,
  });

  // ==========================================================================
  // GESTION DE COMPTE
  // ==========================================================================

  /// Déconnexion (supprime la session et les tokens de refresh).
  Future<void> signOut();

  /// Suppression complète du compte (RGPD Article 17).
  /// ⚠️ Doit supprimer en cascade : profil, tokens, logs, wallet, etc.
  Future<void> deleteAccount();

  /// Mise à jour de l'email (nécessite re-vérification OTP).
  Future<void> updateEmail(String newEmail);

  /// Demande de réinitialisation du mot de passe (email avec lien).
  Future<void> requestPasswordReset(String email);

  /// Met à jour le profil utilisateur courant.
  /// ⚠️ Les colonnes sensibles (thix_id, registration_status, account_status)
  ///    sont gelées et ne peuvent pas être modifiées via cette méthode.
  Future<void> updateCurrentUser(AppUser user);
}

/// Session téléphone (placeholder pour compatibilité future).
class PhoneAuthSession {}
