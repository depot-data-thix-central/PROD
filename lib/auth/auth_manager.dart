// lib/auth/auth_manager.dart
import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';

import 'package:thix_id/auth/supabase_auth_manager.dart' show AuthException, AuthErrorCode;
import 'package:thix_id/models/app_user.dart';

// ============================================================================
// DATA CLASSES
// ============================================================================

/// Données de brouillon de profil pour l'inscription.
///
/// Utilisé pour passer les informations collectées lors des étapes
/// d'inscription avant la création définitive du compte.
@immutable
class ProfileDraft {
  /// Nom complet de l'utilisateur
  final String? fullName;

  /// Date de naissance (format ISO 8601 : YYYY-MM-DD)
  final String? dateOfBirth;

  /// Pays ou origine (code ISO 3166-1 alpha-2 ou nom)
  final String? countryOrOrigin;

  /// Occupation professionnelle
  final String? occupation;

  /// Numéro de téléphone (format E.164 : +243...)
  final String? phoneNumber;

  /// Statut d'inscription (ex: 'draft_step2')
  final String? registrationStatus;

  /// Statut du compte (ex: 'pending', 'email_verified')
  final String? accountStatus;

  const ProfileDraft({
    this.fullName,
    this.dateOfBirth,
    this.countryOrOrigin,
    this.occupation,
    this.phoneNumber,
    this.registrationStatus,
    this.accountStatus,
  });

  /// Convertit en Map pour envoi au serveur.
  Map<String, dynamic> toMap() {
    return {
      if (fullName != null) 'full_name': fullName,
      if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
      if (countryOrOrigin != null) 'country_or_origin': countryOrOrigin,
      if (occupation != null) 'occupation': occupation,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      if (registrationStatus != null) 'registration_status': registrationStatus,
      if (accountStatus != null) 'account_status': accountStatus,
    };
  }

  /// Crée depuis une Map (pour désérialisation).
  factory ProfileDraft.fromMap(Map<String, dynamic> map) {
    return ProfileDraft(
      fullName: map['full_name'] as String?,
      dateOfBirth: map['date_of_birth'] as String?,
      countryOrOrigin: map['country_or_origin'] as String?,
      occupation: map['occupation'] as String?,
      phoneNumber: map['phone_number'] as String?,
      registrationStatus: map['registration_status'] as String?,
      accountStatus: map['account_status'] as String?,
    );
  }

  ProfileDraft copyWith({
    String? fullName,
    String? dateOfBirth,
    String? countryOrOrigin,
    String? occupation,
    String? phoneNumber,
    String? registrationStatus,
    String? accountStatus,
  }) {
    return ProfileDraft(
      fullName: fullName ?? this.fullName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      countryOrOrigin: countryOrOrigin ?? this.countryOrOrigin,
      occupation: occupation ?? this.occupation,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      registrationStatus: registrationStatus ?? this.registrationStatus,
      accountStatus: accountStatus ?? this.accountStatus,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileDraft &&
          runtimeType == other.runtimeType &&
          fullName == other.fullName &&
          dateOfBirth == other.dateOfBirth &&
          countryOrOrigin == other.countryOrOrigin &&
          occupation == other.occupation &&
          phoneNumber == other.phoneNumber &&
          registrationStatus == other.registrationStatus &&
          accountStatus == other.accountStatus;

  @override
  int get hashCode => Object.hash(
        fullName,
        dateOfBirth,
        countryOrOrigin,
        occupation,
        phoneNumber,
        registrationStatus,
        accountStatus,
      );
}

/// Session d'authentification par téléphone.
///
/// Contient les informations nécessaires pour compléter le flux SMS.
@immutable
class PhoneAuthSession {
  /// Identifiant unique de la session (côté serveur)
  final String sessionId;

  /// Numéro de téléphone normalisé (E.164)
  final String phoneNumber;

  /// Timestamp de création de la session
  final DateTime createdAt;

  /// Durée de validité du code SMS (en secondes)
  final int codeValiditySeconds;

  /// Indique si un code a déjà été envoyé
  final bool codeSent;

  const PhoneAuthSession({
    required this.sessionId,
    required this.phoneNumber,
    required this.createdAt,
    this.codeValiditySeconds = 300, // 5 minutes par défaut
    this.codeSent = false,
  });

  /// Vrai si le code est encore valide
  bool get isCodeValid {
    final elapsed = DateTime.now().difference(createdAt).inSeconds;
    return elapsed < codeValiditySeconds;
  }

  PhoneAuthSession copyWith({
    String? sessionId,
    String? phoneNumber,
    DateTime? createdAt,
    int? codeValiditySeconds,
    bool? codeSent,
  }) {
    return PhoneAuthSession(
      sessionId: sessionId ?? this.sessionId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      createdAt: createdAt ?? this.createdAt,
      codeValiditySeconds: codeValiditySeconds ?? this.codeValiditySeconds,
      codeSent: codeSent ?? this.codeSent,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhoneAuthSession &&
          runtimeType == other.runtimeType &&
          sessionId == other.sessionId;

  @override
  int get hashCode => sessionId.hashCode;
}

/// Résultat de la finalisation d'inscription.
@immutable
class FinalizeRegistrationResult {
  /// THIX ID officiel généré
  final String thixId;

  /// THIX CHAT validé
  final String thixChat;

  /// Informations de parrainage (si applicable)
  final Map<String, dynamic>? sponsorship;

  const FinalizeRegistrationResult({
    required this.thixId,
    required this.thixChat,
    this.sponsorship,
  });

  factory FinalizeRegistrationResult.fromMap(Map<String, dynamic> map) {
    return FinalizeRegistrationResult(
      thixId: map['thix_id'] as String? ?? '',
      thixChat: map['thix_chat'] as String? ?? '',
      sponsorship: map['sponsorship'] as Map<String, dynamic>?,
    );
  }
}

// ============================================================================
// AUTH MANAGER (INTERFACE ABSTRAITE)
// ============================================================================

/// Gestionnaire d'authentification abstrait.
///
/// Définit le contrat entre l'UI et l'implémentation concrète (Supabase, Firebase, etc.).
///
/// **Responsabilités** :
/// - Gestion du cycle de vie utilisateur (inscription, connexion, déconnexion)
/// - Vérification OTP (email, téléphone)
/// - Gestion du parrainage QR
/// - Finalisation d'inscription (génération THIX ID)
/// - Mise à jour du profil
///
/// **Erreurs** :
/// Toutes les méthodes lèvent [AuthException] avec un code [AuthErrorCode]
/// en cas d'échec. L'UI doit catcher cette exception et traduire le code
/// en message utilisateur via `_translateAuthError()`.
///
/// **Timeouts** :
/// - Opérations standards : 30 secondes
/// - Opérations lourdes (finalizeRegistration) : 60 secondes
///
/// **Thread-safety** :
/// Toutes les méthodes sont safe pour appel concurrent. L'état interne
/// est protégé par des verrous ou des opérations atomiques.
///
/// **Exemple d'usage** :
/// ```dart
/// final authManager = SupabaseAuthManager();
/// await authManager.init();
///
/// try {
///   final user = await authManager.signInWithEmailOrThixId(
///     identifier: 'user@example.com',
///     password: 'password123',
///     rememberMe: true,
///   );
///   print('Connecté : ${user.displayName}');
/// } on AuthException catch (e) {
///   print('Erreur : ${e.code}');
/// }
/// ```
@sealed
abstract class AuthManager {
  // ==========================================================================
  // ÉTAT
  // ==========================================================================

  /// Utilisateur courant (ValueNotifier pour Riverpod/ChangeNotifier).
  ///
  /// Émet une notification à chaque changement d'état (connexion, déconnexion,
  /// mise à jour profil).
  ValueListenable<AppUser?> get currentUserListenable;

  /// Utilisateur courant (lecture directe, sans notification).
  AppUser? get currentUser;

  // ==========================================================================
  // CYCLE DE VIE
  // ==========================================================================

  /// Initialise le gestionnaire (écoute des changements d'état d'auth).
  ///
  /// **Doit être appelé une seule fois** au démarrage de l'application.
  ///
  /// **Side effects** :
  /// - Abonne aux changements d'état Supabase
  /// - Hydrate l'utilisateur courant si session existante
  /// - Démarre la synchronisation du profil
  ///
  /// **Erreurs possibles** :
  /// - [AuthErrorCode.networkError] : problème de connexion
  /// - [AuthErrorCode.technicalError] : erreur interne
  Future<void> init();

  /// Libère les ressources (listeners, subscriptions).
  ///
  /// **Doit être appelé** lors de la fermeture de l'application ou
  /// lors du hot-reload en développement.
  ///
  /// Après appel, le AuthManager ne doit plus être utilisé.
  void dispose();

  // ==========================================================================
  // AUTHENTIFICATION CLASSIQUE
  // ==========================================================================

  /// Connexion par email (ou THIX ID — mais ici uniquement email).
  ///
  /// **Préconditions** :
  /// - `identifier` non vide (email validé)
  /// - `password` non vide
  ///
  /// **Postconditions** :
  /// - Si succès : `currentUser` mis à jour, session créée
  /// - Si échec : exception levée, état inchangé
  ///
  /// **Erreurs possibles** :
  /// - [AuthErrorCode.identifierRequired] : identifiant vide
  /// - [AuthErrorCode.passwordRequired] : mot de passe vide
  /// - [AuthErrorCode.invalidEmail] : format email invalide
  /// - [AuthErrorCode.signInFailed] : credentials incorrects
  /// - [AuthErrorCode.emailNotVerified] : email non vérifié (OTP renvoyé)
  /// - [AuthErrorCode.accountAlreadyExists] : compte déjà existant (conflit)
  /// - [AuthErrorCode.networkError] : problème réseau
  /// - [AuthErrorCode.rateLimit] : trop de tentatives
  ///
  /// **Timeout** : 30 secondes
  Future<AppUser> signInWithEmailOrThixId({
    required String identifier,
    required String password,
    required bool rememberMe,
  });

  /// Inscription par email (profil personnel ou entreprise).
  ///
  /// **Préconditions** :
  /// - `email` format valide
  /// - `password` >= 8 caractères
  /// - `displayName` non vide
  ///
  /// **Postconditions** :
  /// - Si succès : email OTP envoyé, pas de session créée (Confirm email ON)
  /// - Si échec : exception levée
  ///
  /// **Erreurs possibles** :
  /// - [AuthErrorCode.invalidEmail] : format email invalide
  /// - [AuthErrorCode.passwordTooShort] : mot de passe trop court
  /// - [AuthErrorCode.accountAlreadyExists] : email déjà utilisé
  /// - [AuthErrorCode.signUpFailed] : erreur serveur
  /// - [AuthErrorCode.otpSent] : succès (OTP envoyé, pas une vraie erreur)
  /// - [AuthErrorCode.serverMisconfiguration] : Confirm email OFF (erreur config)
  ///
  /// **Timeout** : 30 secondes
  Future<AppUser> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
    required AccountType accountType,
    required bool rememberMe,
    ProfileDraft? profileDraft,
  });

  /// Inscription simplifiée pour un compte personnel.
  ///
  /// Équivalent à `registerWithEmail(accountType: AccountType.personal)`.
  Future<AppUser> registerPersonal({
    required String email,
    required String password,
    required String displayName,
    required bool rememberMe,
    ProfileDraft? profileDraft,
  });

  /// Vérification cryptographique du code OTP envoyé par email.
  ///
  /// **⚠️ SÉCURITÉ** : Doit TOUJOURS valider le code côté serveur
  /// (pas de bypass client, pas de validation locale).
  ///
  /// **Préconditions** :
  /// - `email` format valide
  /// - `token` non vide (6 ou 8 chiffres selon config)
  ///
  /// **Postconditions** :
  /// - Si succès : session créée, `currentUser` hydraté
  /// - Si échec : exception levée, pas de session
  ///
  /// **Erreurs possibles** :
  /// - [AuthErrorCode.invalidEmail] : format email invalide
  /// - [AuthErrorCode.invalidOtp] : code incorrect
  /// - [AuthErrorCode.otpExpired] : code expiré
  /// - [AuthErrorCode.networkError] : problème réseau
  ///
  /// **Timeout** : 30 secondes
  Future<void> verifyOTP({
    required String email,
    required String token,
  });

  /// Marque le compte comme `email_verified` côté serveur (RPC).
  ///
  /// **À appeler immédiatement après** `verifyOTP()` réussi.
  ///
  /// **Préconditions** :
  /// - Session active (utilisateur connecté)
  ///
  /// **Erreurs possibles** :
  /// - [AuthErrorCode.sessionExpired] : pas de session active
  /// - [AuthErrorCode.markEmailVerifiedFailed] : échec RPC
  ///
  /// **Timeout** : 30 secondes
  Future<void> markEmailVerified();

  /// Force la récupération et l'hydratation de l'utilisateur depuis la session actuelle.
  ///
  /// **Indispensable après** des opérations asynchrones comme `verifyOTP`,
  /// `finalizeRegistration`, ou après un changement de profil côté serveur.
  ///
  /// **Erreurs possibles** :
  /// - [AuthErrorCode.sessionExpired] : pas de session active
  /// - [AuthErrorCode.networkError] : problème réseau
  ///
  /// **Timeout** : 30 secondes
  Future<AppUser> refreshCurrentUser();

  /// Renvoie un code OTP par email (avec throttling serveur).
  ///
  /// **Préconditions** :
  /// - `email` format valide
  ///
  /// **Erreurs possibles** :
  /// - [AuthErrorCode.invalidEmail] : format email invalide
  /// - [AuthErrorCode.rateLimit] : trop de demandes (throttling)
  /// - [AuthErrorCode.resendOtpFailed] : échec envoi
  ///
  /// **Timeout** : 30 secondes
  Future<void> resendOTP({required String email});

  // ==========================================================================
  // PARRAINAGE QR — FLUX SÉCURISÉ
  // ==========================================================================

  /// Génère un nonce opaque pour le QR de parrainage.
  ///
  /// **⚠️ SÉCURITÉ** : Le nonce retourné ne doit JAMAIS être stocké en clair
  /// côté serveur. Il est encodé dans le QR et consommé une seule fois.
  ///
  /// **Préconditions** :
  /// - Session active
  /// - Email vérifié (`account_status = 'email_verified'` ou `'active'`)
  ///
  /// **Retourne** : Le nonce à encoder dans le QR (format opaque, max 100 chars).
  ///
  /// **Erreurs possibles** :
  /// - [AuthErrorCode.sessionExpired] : pas de session active
  /// - [AuthErrorCode.emailNotVerified] : email non vérifié
  /// - [AuthErrorCode.qrTokenGenerationFailed] : échec RPC
  ///
  /// **Timeout** : 30 secondes
  Future<String> generateQrToken();

  /// Consomme un token QR scanné (appelé par le parrain accrédité).
  ///
  /// **⚠️ SÉCURITÉ** :
  /// - Prérequis : parrain `is_accredited_sponsor = true`
  /// - Le filleul passe à `account_status = 'sponsored'` (pas encore actif)
  /// - Le token est invalidé après consommation (one-time use)
  ///
  /// **Préconditions** :
  /// - Session active (parrain connecté)
  /// - `token` non vide (format valide)
  ///
  /// **Erreurs possibles** :
  /// - [AuthErrorCode.sessionExpired] : pas de session active
  /// - [AuthErrorCode.consumeQrTokenFailed] : token invalide ou déjà consommé
  /// - [AuthErrorCode.technicalError] : erreur interne
  ///
  /// **Timeout** : 30 secondes
  Future<void> consumeQrToken({required String token});

  /// Finalise l'inscription de manière atomique.
  ///
  /// **Opérations effectuées** :
  /// 1. Valide le THIX CHAT (réservé + anti-squatting)
  /// 2. Génère le THIX ID officiel (via RPC serveur)
  /// 3. Passe le compte à `account_status = 'active'`
  ///
  /// **Retourne** : [FinalizeRegistrationResult] avec `thix_id`, `thix_chat`, `sponsorship`.
  ///
  /// **Préconditions** :
  /// - Session active
  /// - Email vérifié
  /// - `desiredChat` format valide (@handle, 3-20 chars)
  /// - `countryCode` code ISO valide (2-3 lettres)
  ///
  /// **Erreurs possibles** :
  /// - [AuthErrorCode.sessionExpired] : pas de session active
  /// - [AuthErrorCode.emailNotVerified] : email non vérifié
  /// - [AuthErrorCode.finalizeRegistrationFailed] : échec RPC
  /// - Erreurs business : chat_taken, chat_reserved, thix_id_failed
  ///
  /// **Timeout** : 60 secondes (opération lourde)
  Future<Map<String, dynamic>> finalizeRegistration({
    required String desiredChat,
    required String countryCode,
  });

  // ==========================================================================
  // AUTHENTIFICATION TÉLÉPHONE (PLACEHOLDER)
  // ==========================================================================

  /// Démarrage de l'authentification par téléphone.
  ///
  /// **⚠️ NON IMPLÉMENTÉ en v2** : Lève [AuthErrorCode.phoneAuthNotAvailable].
  ///
  /// **Flow prévu** :
  /// 1. Envoi SMS avec code 6 chiffres
  /// 2. Retourne [PhoneAuthSession] avec `sessionId`
  /// 3. Appel `confirmPhoneCode()` avec le code reçu
  Future<PhoneAuthSession> startPhoneAuth({required String phoneNumber});

  /// Confirmation du code téléphone.
  ///
  /// **⚠️ NON IMPLÉMENTÉ en v2** : Lève [AuthErrorCode.phoneAuthNotAvailable].
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
  ///
  /// **Side effects** :
  /// - Supprime session locale
  /// - Invalide tokens refresh côté serveur
  /// - `currentUser` mis à null
  /// - Notifications push désabonnées
  ///
  /// **Erreurs possibles** :
  /// - [AuthErrorCode.networkError] : problème réseau (session locale quand même supprimée)
  ///
  /// **Timeout** : 30 secondes
  Future<void> signOut();

  /// Suppression complète du compte (RGPD Article 17 — Droit à l'oubli).
  ///
  /// **⚠️ SÉCURITÉ** : Doit supprimer en cascade :
  /// - Profil utilisateur
  /// - Tokens d'authentification
  /// - Logs d'activité
  /// - Wallet et transactions
  /// - Messages et médias
  /// - Parrainages (anonymisation)
  ///
  /// **⚠️ NON IMPLÉMENTÉ en v2** : Lève [AuthErrorCode.deleteAccountNotAvailable].
  /// Nécessite une fonction serveur sécurisée avec confirmation email.
  Future<void> deleteAccount();

  /// Mise à jour de l'email (nécessite re-vérification OTP).
  ///
  /// **Flow** :
  /// 1. Envoi email de confirmation à l'ancienne adresse
  /// 2. Envoi email de confirmation à la nouvelle adresse
  /// 3. Attente des deux confirmations
  /// 4. Mise à jour effective
  ///
  /// **Préconditions** :
  /// - Session active
  /// - `newEmail` format valide
  ///
  /// **Erreurs possibles** :
  /// - [AuthErrorCode.sessionExpired] : pas de session active
  /// - [AuthErrorCode.invalidEmail] : format invalide
  /// - [AuthErrorCode.accountAlreadyExists] : email déjà utilisé
  /// - [AuthErrorCode.updateEmailFailed] : échec mise à jour
  ///
  /// **Timeout** : 30 secondes
  Future<void> updateEmail(String newEmail);

  /// Demande de réinitialisation du mot de passe (email avec lien).
  ///
  /// **Préconditions** :
  /// - `email` format valide
  ///
  /// **Side effects** :
  /// - Envoi email avec lien de réinitialisation
  /// - Pas de création de session
  ///
  /// **Erreurs possibles** :
  /// - [AuthErrorCode.invalidEmail] : format invalide
  /// - [AuthErrorCode.resetPasswordFailed] : échec envoi
  ///
  /// **Timeout** : 30 secondes
  Future<void> requestPasswordReset(String email);

  /// Met à jour le profil utilisateur courant.
  ///
  /// **⚠️ SÉCURITÉ** : Les colonnes sensibles sont gelées et ne peuvent pas
  /// être modifiées via cette méthode :
  /// - `thix_id` (généré par serveur)
  /// - `registration_status` (géré par workflow)
  /// - `account_status` (géré par workflow)
  /// - `thix_score` (calculé par serveur)
  ///
  /// **Préconditions** :
  /// - Session active
  /// - `user.id` == `currentUser.id`
  ///
  /// **Erreurs possibles** :
  /// - [AuthErrorCode.sessionExpired] : pas de session active
  /// - [AuthErrorCode.userMismatch] : `user.id` != `currentUser.id`
  /// - [AuthErrorCode.profileUpdateFailed] : échec mise à jour
  ///
  /// **Timeout** : 30 secondes
  Future<void> updateCurrentUser(AppUser user);
}
