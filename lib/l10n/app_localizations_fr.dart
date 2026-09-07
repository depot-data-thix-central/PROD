// lib/l10n/app_localizations_fr.dart
import 'dart:ui';
import 'app_localizations.dart';

class AppLocalizationsFr extends AppLocalizations {
  @override Locale get locale => const Locale('fr');

  // ============================================================================
  // COMMON & UI
  // ============================================================================
  @override String get common_back => 'Retour';
  @override String get common_close => 'Fermer';
  @override String get live_ending => 'Fin du direct'; 
  @override String get common_cancel => 'Annuler';
  @override String get common_confirm => 'Confirmer';
  @override String get common_delete => 'Supprimer';
  @override String get common_add => 'Ajouter';
  @override String get common_edit => 'Modifier';
  @override String get common_save => 'Enregistrer';
  @override String get common_manage => 'Gérer';
  @override String get common_retry => 'Réessayer';
  @override String get common_refresh => 'Actualiser';
  @override String get common_search => 'Rechercher';
  @override String get common_open => 'Ouvrir';
  @override String get common_share => 'Partager';
  @override String get common_copy => 'Copier';
  @override String get common_copied => 'Copié !';
  @override String get common_download => 'Télécharger';
  @override String get common_upload => 'Importer';
  @override String get common_send => 'Envoyer';
  @override String get common_receive => 'Recevoir';
  @override String get common_accept => 'Accepter';
  @override String get common_reject => 'Rejeter';
  @override String get common_skip => 'Passer';
  @override String get common_next => 'Suivant';
  @override String get common_previous => 'Précédent';
  @override String get common_finish => 'Terminer';
  @override String get common_done => 'Fait';
  @override String get common_error => 'Erreur';
  @override String get common_success => 'Succès';
  @override String get common_loading => 'Chargement…';
  @override String get common_please_wait => 'Veuillez patienter…';
  @override String get common_today => 'Aujourd\'hui';
  @override String get common_yesterday => 'Hier';
  @override String get common_tomorrow => 'Demain';
  @override String get common_home => 'Accueil';
  @override String get common_chat => 'Chat';
  @override String get common_map => 'Carte';
  @override String get common_profile => 'Profil';
  @override String get common_menu => 'Menu';
  @override String get common_notifications => 'Notifications';
  @override String get common_settings => 'Paramètres';
  @override String get common_help => 'Aide';
  @override String get common_about => 'À propos';
  @override String get common_logout => 'Déconnexion';
  @override String get common_login => 'Connexion';
  @override String get common_signup => 'S\'inscrire';
  @override String get common_yes => 'Oui';
  @override String get common_no => 'Non';
  @override String get common_or => 'ou';
  @override String get common_and => 'et';
  @override String get common_none => 'Aucun';
  @override String get common_all => 'Tout';
  @override String get common_unknown => 'Inconnu';
  @override String get common_enabled => 'Activé';
  @override String get common_disabled => 'Désactivé';
  @override String get common_clear => 'Effacer';
  @override String get common_remove => 'Retirer';
  
  @override String common_items(int count) => count == 0 ? 'Aucun élément' : (count == 1 ? '1 élément' : '$count éléments');
  @override String common_contacts(int count) => count == 0 ? 'Aucun contact' : (count == 1 ? '1 contact' : '$count contacts');
  @override String common_messages(int count) => count == 0 ? 'Aucune message' : (count == 1 ? '1 message' : '$count messages');
  @override String common_days(int count) => count == 0 ? '0 jour' : (count == 1 ? '1 jour' : '$count jours');
  @override String common_hours(int count) => count == 0 ? '0 heure' : (count == 1 ? '1 heure' : '$count heures');
  @override String common_minutes(int count) => count == 0 ? '0 minute' : (count == 1 ? '1 minute' : '$count minutes');

  // ============================================================================
  // AUTH & ONBOARDING (BASIC)
  // ============================================================================
  @override String get auth_login => 'Se connecter';
  @override String get auth_signup => 'S\'inscrire';
  @override String get auth_forgot_password => 'Mot de passe oublié ?';
  @override String get auth_reset_password => 'Réinitialiser le mot de passe';
  @override String get auth_email => 'Adresse e-mail';
  @override String get auth_phone => 'Numéro de téléphone';
  @override String get auth_password => 'Mot de passe';
  @override String get auth_confirm_password => 'Confirmer le mot de passe';
  @override String get auth_logout_confirm => 'Êtes-vous sûr de vouloir vous déconnecter ?';
  @override String get auth_welcome_back => 'Bon retour';
  @override String get auth_welcome => 'Bienvenue';
  @override String get auth_no_account => 'Pas encore de compte ?';
  @override String get auth_has_account => 'Déjà un compte ?';
  @override String get auth_invalid_email => 'Adresse e-mail invalide';
  @override String get auth_invalid_phone => 'Numéro de téléphone invalide';
  @override String get auth_password_too_short => 'Mot de passe trop court (min. 8 caractères)';
  @override String get auth_passwords_mismatch => 'Les mots de passe ne correspondent pas';
  @override String get auth_login_success => 'Connexion réussie';
  @override String get auth_signup_success => 'Compte créé avec succès';
  @override String get auth_session_expired => 'Session expirée, veuillez vous reconnecter';
  @override String get auth_2fa_title => 'Vérification en deux étapes';
  @override String get auth_2fa_code => 'Code de vérification';
  @override String get auth_verify_email => 'Vérifier l\'e-mail';
  @override String get auth_verify_phone => 'Vérifier le téléphone';
  @override String get auth_biometric => 'Connexion biométrique';
  @override String get auth_biometric_prompt => 'Authentifiez-vous pour continuer';
  @override String get auth_full_name => 'Nom complet';
  @override String get auth_first_name => 'Prénom';
  @override String get auth_last_name => 'Nom de famille';
  @override String get auth_birth_date => 'Date de naissance';
  @override String get auth_gender => 'Genre';
  @override String get auth_gender_male => 'Homme';
  @override String get auth_gender_female => 'Femme';
  @override String get auth_gender_other => 'Autre';
  @override String get auth_accept_terms => 'J\'accepte les conditions d\'utilisation';
  @override String get auth_terms_required => 'Vous devez accepter les conditions';
  @override String get auth_email_already_used => 'Cet e-mail est déjà utilisé';
  @override String get auth_phone_already_used => 'Ce numéro est déjà utilisé';
  @override String get auth_create_account => 'Créer mon compte';
  @override String get auth_already_have_account => 'J\'ai déjà un compte';

  @override String get onboarding_welcome => 'Bienvenue sur THIX';
  @override String get onboarding_step_1_title => 'Connexion';
  @override String get onboarding_step_1_desc => 'Créez votre identité sécurisée sur THIX';
  @override String get onboarding_step_2_title => 'Protection';
  @override String get onboarding_step_2_desc => 'Activez une protection 24/7';
  @override String get onboarding_step_3_title => 'Action';
  @override String get onboarding_step_3_desc => 'Alertez les secours en 2 secondes';
  @override String get onboarding_get_started => 'Commencer';
  @override String get onboarding_skip => 'Passer l\'intro';

  // ============================================================================
  // AUTHENTIFICATION & CONNEXION (ADVANCED / ERRORS)
  // ============================================================================
  @override String get login_title => 'Connexion à THIX';
  @override String get login_subtitle => 'Heureux de vous revoir';
  @override String get login_identifier_label => 'Identifiant';
  @override String get login_identifier_hint => 'Email, téléphone ou THIX ID';
  @override String get login_password_label => 'Mot de passe';
  @override String get login_password_hint => 'Votre mot de passe sécurisé';
  @override String get login_remember_me => 'Se souvenir de moi';
  @override String get login_forgot_password => 'Mot de passe oublié ?';
  @override String get login_button => 'Se connecter';
  @override String get login_verifying => 'Vérification…';
  @override String get login_retry_in => 'Réessayer dans';
  @override String get login_seconds_suffix => 's';
  @override String get login_biometric => 'OU CONTINUER AVEC';
  @override String get login_face_id => 'Face ID';
  @override String get login_touch_id => 'Touch ID';
  
  @override String get login_error_suspended => 'Ce compte est suspendu. Contactez le support.';
  @override String get login_error_not_active => 'Ce compte n\'est pas activé.';
  @override String get login_error_no_account => 'Aucun compte trouvé avec ces informations.';
  @override String get login_error_mfa_required => 'L\'authentification à deux facteurs est requise.';

  @override String get auth_error_identifier_required => 'L\'identifiant est requis';
  @override String get auth_error_password_required => 'Le mot de passe est requis';
  @override String get auth_error_thix_id_login_not_available => 'La connexion par THIX ID n\'est pas disponible pour le moment';
  @override String get auth_error_sign_in_failed => 'Échec de la connexion. Vérifiez vos identifiants.';
  @override String get auth_error_email_not_verified => 'Veuillez vérifier votre email avant de vous connecter';
  @override String get auth_error_server_misconfiguration => 'Erreur de configuration du serveur';
  @override String get auth_error_account_already_exists => 'Un compte existe déjà avec cet identifiant';
  @override String get auth_error_account_exists_wrong_password => 'Ce compte existe, mais le mot de passe est incorrect';
  @override String get auth_error_account_exists_new_otp_sent => 'Un nouveau code OTP a été envoyé à votre adresse';
  @override String get auth_error_invalid_otp => 'Code OTP invalide ou expiré';
  @override String get auth_error_otp_expired => 'Le code OTP a expiré';
  @override String get auth_error_network => 'Erreur réseau. Vérifiez votre connexion internet.';
  @override String get auth_error_rate_limit => 'Trop de tentatives. Veuillez patienter un moment.';
  @override String get auth_error_technical => 'Une erreur technique s\'est produite. Veuillez réessayer.';
  @override String get auth_error_user_mismatch => 'Incohérence d\'utilisateur détectée';
  @override String get auth_error_profile_update_failed => 'Échec de la mise à jour du profil';
  @override String get auth_error_mark_email_verified_failed => 'Échec de la vérification de l\'email';
  @override String get auth_error_qr_token_generation_failed => 'Échec de la génération du token QR';
  @override String get auth_error_finalize_registration_failed => 'Échec de la finalisation de l\'inscription';
  @override String get auth_error_consume_qr_token_failed => 'Échec de la consommation du token QR';
  @override String get auth_error_resend_otp_failed => 'Échec du renvoi du code OTP';
  @override String get auth_error_phone_auth_not_available => 'L\'authentification par téléphone n\'est pas disponible';
  @override String get auth_error_delete_account_not_available => 'La suppression de compte n\'est pas disponible pour le moment';
  @override String get auth_error_update_email_failed => 'Échec de la mise à jour de l\'adresse e-mail';
  @override String get auth_error_reset_password_failed => 'Échec de la réinitialisation du mot de passe';
  @override String get auth_error_sign_up_failed => 'Échec de la création du compte';
  @override String get auth_info_otp_sent => 'Un code de vérification a été envoyé';

  // ============================================================================
  // INSCRIPTION PERSONNELLE
  // ============================================================================
  @override String get reg_step1_title => 'Votre profil';
  @override String get reg_step1_subtitle => 'Commençons par les informations de base';
  @override String get reg_full_name_label => 'Nom complet';
  @override String get reg_full_name_hint => 'Prénom et Nom';
  @override String get reg_dob_label => 'Date de naissance';
  @override String get reg_country_label => 'Pays de résidence';
  @override String get reg_occupation_label => 'Profession / Activité';
  @override String get reg_occupation_hint => 'Ex: Développeur, Étudiant, Entrepreneur';
  @override String get reg_next => 'Suivant';

  @override String get reg_step2_title => 'Sécurisez votre compte';
  @override String get reg_step2_subtitle => 'Créez vos identifiants de connexion';
  @override String get reg_email_label => 'Adresse e-mail';
  @override String get reg_email_hint => 'votre.email@exemple.com';
  @override String get reg_phone_label => 'Numéro de téléphone';
  @override String get reg_phone_hint => '+33 6 XX XX XX XX';
  @override String get reg_password_label => 'Mot de passe';
  @override String get reg_password_hint => 'Minimum 8 caractères';
  @override String get reg_confirm_password_label => 'Confirmer le mot de passe';
  @override String get reg_confirm_password_hint => 'Retapez votre mot de passe';
  @override String get reg_strength_label => 'Force du mot de passe';
  @override String get reg_strength_very_weak => 'Très faible';
  @override String get reg_strength_weak => 'Faible';
  @override String get reg_strength_medium => 'Moyen';
  @override String get reg_strength_strong => 'Fort';
  @override String get reg_strength_excellent => 'Excellent';

  @override String get reg_identity_title => 'Identité THIX';
  @override String get reg_thix_chat_label => 'Nom d\'utilisateur THIX Chat';
  @override String get reg_thix_chat_hint => 'Ex: jean.dupont (unique)';
  
  @override String get reg_verification_title => 'Vérification';
  @override String get reg_get_otp => 'Obtenir le code de vérification';
  @override String get reg_code_sent_resend => 'Renvoyer le code';
  @override String get reg_resend_in => 'Renvoyer dans';
  @override String get reg_seconds_short => 's';
  @override String get reg_otp_label => 'Code de Vérification (OTP)';
  @override String get reg_validate_activate => 'Vérifier et Activer';
  @override String get reg_activating => 'Activation en cours…';

  @override String get reg_congrats => 'Félicitations !';
  @override String get reg_welcome_message => 'Bienvenue dans l\'écosystème THIX,';
  @override String get reg_id_card_title => 'CARTE D\'IDENTITÉ NUMÉRIQUE THIX';
  @override String get reg_official_thix_id => 'THIX ID OFFICIEL';
  @override String get reg_generating => 'Génération en cours…';
  @override String get reg_copy_thix_id => 'Copier THIX ID';
  @override String get reg_thix_id_copied => 'THIX ID copié dans le presse-papiers';
  @override String get reg_go_to_dashboard => 'Aller au Tableau de bord';
  @override String get reg_summary => 'Résumé de l\'inscription';
  @override String get reg_mobile_label => 'Mobile';
  @override String get reg_not_provided => 'Non renseigné';

  // ============================================================================
  // ACCUEIL & TABLEAU DE BORD
  // ============================================================================
  @override String get home_search_hint => 'Rechercher un service ou un contact…';
  @override String get home_greeting => 'Bonjour';
  @override String get home_greeting_time => 'Bonsoir';
  @override String get home_welcome_back => 'Bon retour parmi nous';
  @override String get home_language_kiswahili => 'Kiswahili';
  @override String get home_banner_default_tag => 'PROGRAMME JEUNESSE';
  @override String get home_banner_default_title => 'Découvrez les dernières opportunités et événements';
  
  @override String get cert_pending => 'Certification en attente';
  @override String get cert_tier_ladder => 'Niveau actuellement sous examen';
  @override String get cert_view => 'Voir';

  @override String get quick_sona => 'THIX Sona';
  @override String get quick_doc => 'Mes documents';
  @override String get quick_chat => 'Chat';
  @override String get quick_sos => 'Urgence';
  @override String get service_sante => 'THIX Santé';
  @override String get service_market => 'THIX Market';
  @override String get service_money => 'THIX Wallet';
  @override String get service_reservation => 'Réservation';
  @override String get service_mon_pays => 'Mon Pays';
  @override String get service_emploi => 'Emplois';
  @override String get service_formations => 'Formations';
  @override String get service_opportunites => 'Opportunités';
  @override String get service_infos => 'Infos';
  @override String get service_events => 'Événements';
  @override String get service_media => 'THIX Media';
  @override String get service_vault => 'Coffre-fort';
  @override String get service_network => 'Réseau';
  @override String get service_certification => 'Certification';

  // ============================================================================
  // CHAT & MESSAGERIE
  // ============================================================================
  @override String get chatlist_network => 'Réseau';
  @override String get chatlist_discussions => 'Discussions';
  @override String get chatlist_create_new => 'Créer une discussion';
  @override String get chatlist_calls => 'Appels';
  @override String get chatlist_settings => 'Paramètres';

  @override String get chat_unknown_user => 'Utilisateur inconnu';
  @override String chat_members(int count) => count == 1 ? '1 membre' : '$count membres';
  @override String get chat_video_call => 'Appel vidéo';
  @override String get chat_audio_call => 'Appel audio';
  @override String get chat_escalate => 'Escalader';
  @override String get chat_history => 'Historique';
  @override String get chat_group_info => 'Infos du groupe';
  @override String get chat_file => 'Fichier';
  @override String get chat_sticker => 'Autocollant';
  @override String get chat_ephemeral => 'Éphémère';
  @override String get chat_protected => 'Protégé';
  @override String get chat_internal_note => 'Note interne';
  @override String get chat_send => 'Envoyer';
  @override String get chat_recording => 'Enregistrement';
  @override String get chat_stop_recording => 'Arrêter';
  @override String get chat_write_message => 'Écrire un message...';
  @override String get chat_record_audio => 'Enregistrer l\'audio';
  @override String get chat_emojis => 'Émojis';
  @override String get chat_reactions => 'Réactions';
  @override String get chat_flags => 'Signalements';
  @override String get chat_callback => 'Rappeler';
  @override String get chat_typing => 'écrit...';
  @override String get chat_pause => 'Pause';
  @override String get chat_play => 'Lecture';

  @override String get conv_status_connected => 'Connecté';
  @override String get conv_status_pending => 'En attente';
  @override String get conv_status_rejected => 'Rejeté';
  @override String get conv_cannot_self => 'Vous ne pouvez pas vous ajouter vous-même';
  @override String get conv_request_pending => 'Demande de connexion en attente';
  @override String get conv_request_rejected => 'Demande de connexion rejetée';
  @override String get conv_request_to => 'Envoyer une demande à';
  @override String get conv_request_hint => 'Ajoutez un message facultatif à votre demande de connexion.';
  @override String get conv_message_optional => 'Message (facultatif)';
  @override String get conv_send_request => 'Envoyer la demande';
  @override String get conv_request_sent => 'Demande envoyée avec succès';
  @override String get conv_request_exists => 'Une demande existe déjà pour cet utilisateur';
  @override String get conv_select_contact => 'Veuillez sélectionner au moins un contact';
  @override String get conv_waiting_connection => 'En attente de connexion pour';
  @override String get conv_group_rpc_required => 'La création de groupe nécessite un appel serveur';
  @override String get conv_page_title => 'Nouvelle discussion';
  @override String conv_start(int count) => 'Démarrer ($count)';
  @override String get conv_search_label => 'Rechercher un utilisateur';
  @override String get conv_search_hint => 'Nom, THIX ID ou numéro de téléphone...';
  @override String get conv_group_name_label => 'Nom du groupe';
  @override String get conv_group_name_hint => 'Ex: Équipe Projet Alpha';

  @override String get requests_page_title => 'Demandes de Connexion';
  @override String get requests_reject_title => 'Rejeter la demande';
  @override String get requests_reject_message => 'Êtes-vous sûr de vouloir rejeter cette demande de connexion ? Cette action est irréversible.';
  @override String get requests_reject_confirm => 'Rejeter';
  @override String get requests_rejected => 'Demande rejetée';
  @override String get requests_reject_error => 'Erreur lors du rejet de la demande';
  @override String get requests_accepted => 'Demande acceptée avec succès';
  @override String get requests_accept_error => 'Erreur lors de l\'acceptation de la demande';

  @override String get call_history_title => 'Historique des Appels';
  @override String get call_missed => 'Appel manqué';
  @override String get call_incoming => 'Appel entrant';
  @override String get call_outgoing => 'Appel sortant';
  @override String get call_video => 'Appel vidéo';
  @override String get call_audio => 'Appel audio';

  // ============================================================================
  // RÉSEAU SOCIAL
  // ============================================================================
  @override String get network_search_title => 'Rechercher';
  @override String get network_search_hint => 'Recherchez des personnes, publications ou communautés…';
  @override String get network_tab_people => 'Personnes';
  @override String get network_tab_posts => 'Publications';
  @override String get network_tab_communities => 'Communautés';
  @override String get network_explore_title => 'Explorer le Réseau THIX';
  @override String get network_explore_subtitle => 'Recherchez des personnes, des publications ou des communautés';
  @override String get network_no_results_users => 'Aucun utilisateur trouvé';
  @override String get network_no_results_posts => 'Aucune publication trouvée';
  @override String get network_no_results_communities => 'Aucune communauté trouvée';
  @override String get network_request_sent => 'Demande envoyée à';
  @override String get network_request_error => 'Erreur lors de l\'envoi de la demande';

  @override String get community_create_title => 'Créer une communauté';
  @override String get community_name_label => 'Nom de la communauté';
  @override String get community_description_label => 'Description';
  @override String get community_visibility_label => 'Visibilité';
  @override String get community_public => 'Publique';
  @override String get community_private => 'Privée';
  @override String get community_join => 'Rejoindre';
  @override String get community_leave => 'Quitter';
  @override String get community_members => 'membres';
  @override String get community_admin => 'Administrateur';

  // ============================================================================
  // PROFIL UTILISATEUR
  // ============================================================================
  @override String get profile_settings => 'Paramètres du profil';
  @override String get profile_edit_bio => 'Modifier la Bio';
  @override String get profile_no_bio => 'Aucune biographie disponible pour le moment.';
  @override String get profile_followers => 'Abonnés';
  @override String get profile_following => 'Abonnements';
  @override String get profile_posts => 'Publications';
  @override String get profile_follow => 'Suivre';
  @override String get profile_unfollow => 'Abonné(e)';
  @override String get profile_following_loading => 'Chargement…';
  @override String get profile_message => 'Message';
  @override String get profile_block_user => 'Bloquer cet utilisateur ?';
  @override String get profile_block_message => 'Vous ne verrez plus ses publications et il ne pourra plus interagir avec vous.';
  @override String get profile_block_confirm => 'Bloquer';
  @override String get profile_blocked_success => 'Utilisateur bloqué';
  @override String get profile_block_error => 'Erreur lors du blocage';
  
  @override String get profile_report_user => 'Signaler';
  @override String get profile_report_reason => 'Raison';
  @override String get profile_report_details => 'Détails (facultatif)';
  @override String get profile_report_spam => 'Spam';
  @override String get profile_report_inappropriate => 'Contenu inapproprié';
  @override String get profile_report_harassment => 'Harcèlement';
  @override String get profile_report_impersonation => 'Usurpation d\'identité';
  @override String get profile_report_other => 'Autre';
  @override String get profile_report_submit => 'Soumettre le signalement';
  @override String get profile_report_success => 'Signalement envoyé';
  @override String get profile_report_duplicate => 'Déjà signalé';
  
  @override String get profile_private_gallery => 'Galerie privée';
  @override String get profile_private_content_locked => 'Ce contenu est privé';
  @override String get profile_add_private_media => 'Ajouter à ma galerie privée';
  @override String get profile_no_private_media => 'Aucun média privé pour le moment';
  @override String get profile_upload_processing => 'Traitement…';
  
  @override String get profile_tab_bio => 'Bio';
  @override String get profile_tab_private_gallery => 'Galerie Privée';
  @override String get profile_tab_photos => 'Photos Publiques';
  @override String get profile_tab_videos => 'Vidéos';
  @override String get profile_tab_audios => 'Audios';
  @override String get profile_no_content => 'Aucun contenu';
  @override String get profile_pinned_post => 'Publication épinglée';
  @override String get profile_view_post => 'Voir la publication';

  // ============================================================================
  // PARAMÈTRES GÉNÉRAUX & CHAT (SETTINGS)
  // ============================================================================
  @override String get settings_title => 'Paramètres de chat';
  @override String get settings_section_appearance => 'Apparence';
  @override String get settings_theme => 'Thème';
  @override String get settings_theme_light => 'Clair';
  @override String get settings_theme_dark => 'Sombre';
  @override String get settings_theme_system => 'Par défaut du système';
  @override String get settings_wallpaper => 'Fond d\'écran';
  @override String get settings_wallpaper_default => 'Par défaut';
  @override String get settings_wallpaper_custom => 'Personnalisé';
  
  @override String get settings_section_privacy => 'Confidentialité';
  @override String get settings_last_seen => 'Dernière présence';
  @override String get settings_visibility_everyone => 'Tout le monde';
  @override String get settings_visibility_contacts => 'Mes contacts';
  @override String get settings_visibility_nobody => 'Personne';
  @override String get settings_profile_photo => 'Photo de profil';
  
  @override String get settings_section_notifications => 'Notifications';
  @override String get settings_messages => 'Messages';
  @override String get settings_calls => 'Appels';
  
  @override String get settings_section_messages => 'Données et Stockage';
  @override String get settings_ephemeral => 'Messages éphémères';
  @override String get settings_auto_download => 'Téléchargement auto des médias';
  @override String get settings_download_wifi => 'Wi-Fi uniquement';
  @override String get settings_download_mobile => 'Wi-Fi et Données cellulaires';
  @override String get settings_download_never => 'Jamais';
  
  @override String get settings_section_account => 'Compte';
  @override String get settings_view_profile => 'Voir mon profil';
  @override String get settings_logout => 'Se déconnecter';

  @override String get settings_profile_edit => 'Modifier le profil';
  @override String get settings_notifications => 'Notifications';
  @override String get settings_privacy => 'Confidentialité';
  @override String get settings_security => 'Sécurité';
  @override String get settings_language => 'Langue';
  @override String get settings_help_center => 'Centre d\'aide';
  @override String get settings_about => 'À propos de THIX';
  @override String get settings_version => 'Version';

  @override String get settings_choose_language => 'Choisir la langue';
  @override String get settings_system_default => 'Langue du système';
  @override String get settings_language_change_failed => 'Échec du changement de langue';

  // ============================================================================
  // SOS & URGENCE
  // ============================================================================
  @override String get sos_button => 'Urgence';
  @override String get sos_button_label => 'Bouton d\'Urgence SOS';
  @override String get sos_button_hint => 'Maintenez 2 secondes pour activer';
  @override String get sos_button_tooltip => 'Appuyez et maintenez pendant 2 secondes';
  @override String get sos_trigger_button => 'Déclencher SOS';
  @override String get sos_trigger_timeout => 'La requête a expiré. Veuillez réessayer.';
  @override String get sos_trigger_error => 'Échec du déclenchement SOS';
  @override String get sos_active => 'SOS Actif';
  @override String get sos_crisis_room => 'Salle de Crise';
  @override String get sos_command_center => 'Centre de Commandement';
  @override String get sos_incident => 'Incident';
  @override String get sos_incident_unknown => 'Incident inconnu';
  @override String get sos_incident_not_found => 'Incident introuvable';
  @override String get sos_circle => 'Cercle';
  @override String get sos_rescuers => 'Secouristes';
  @override String get sos_rescuer => 'Secouriste';
  @override String get sos_my_rescuers => 'Mes secouristes';
  @override String get sos_duration => 'Durée';
  @override String get sos_identifier => 'Identifiant';
  @override String get sos_calling => 'Appel en cours…';
  @override String get sos_call => 'Appeler';
  @override String get sos_available => 'Disponible';
  @override String get sos_unavailable => 'Indisponible';
  @override String get sos_verified => 'Vérifié';
  @override String get sos_end => 'Terminer';
  @override String get sos_end_sos => 'Terminer SOS';
  @override String get sos_cancel_sos => 'Annuler SOS';
  @override String get sos_pin_required => 'PIN de sécurité requis';
  @override String get sos_cancelled => 'SOS Annulé';
  @override String get sos_resolved => 'SOS Résolu';
  @override String get sos_cancel_failed => 'Échec de l\'annulation';
  @override String get sos_in_progress => 'En cours';
  @override String get sos_history => 'Historique';
  @override String get sos_my_incidents => 'Mes incidents';
  @override String get sos_no_incidents => 'Aucun incident pour le moment';
  @override String get sos_incidents_appear_here => 'Vos demandes SOS apparaîtront ici';
  @override String get sos_history_error => 'Échec du chargement de l\'historique';
  @override String get sos_circle_1 => 'Cercle 1 – Prioritaire';
  @override String get sos_circle_2 => 'Cercle 2 – Secondaire';
  @override String get sos_circle_3 => 'Cercle 3 – Urgence';
  @override String get sos_no_rescuers => 'Aucun secouriste';
  @override String get sos_add_first_rescuer => 'Ajoutez votre premier contact d\'urgence';
  @override String get sos_add_rescuer => 'Ajouter un secouriste';
  @override String get sos_add_rescuer_info => 'Entrez le THIX ID du secouriste. Le nom et la photo seront récupérés automatiquement.';
  @override String get sos_thix_id_label => 'THIX ID';
  @override String get sos_thix_id_hint => 'THIX-XXXX';

  // ============================================================================
  // CERTIFICATION
  // ============================================================================
  @override String get certification_title => 'Certification THIX';
  @override String get certification_apply => 'Demander la certification';
  @override String get certification_status => 'Statut';
  @override String get certification_pending => 'En attente';
  @override String get certification_approved => 'Approuvé';
  @override String get certification_rejected => 'Rejeté';
  @override String get certification_tier_bronze => 'Bronze';
  @override String get certification_tier_silver => 'Argent';
  @override String get certification_tier_gold => 'Or';
  @override String get certification_tier_platinum => 'Platine';
  @override String get certification_benefits => 'Avantages';
  @override String get certification_documents => 'Documents requis';
  @override String get certification_upload_doc => 'Télécharger un document';
  @override String get certification_review_progress => 'En cours d\'examen';
  @override String get certification_verified_account => 'Compte Vérifié';

  // ============================================================================
  // ÉDUCATION & FORMATION
  // ============================================================================
  @override String get edu_nav_home => 'Accueil';
  @override String get edu_nav_learning => 'Apprentissage';
  @override String get edu_nav_library => 'Bibliothèque';
  @override String get edu_nav_certs => 'Certificats';
  @override String get edu_nav_profile => 'Profil';
  
  @override String get edu_auth_required => 'Connectez-vous pour voir vos cours';
  @override String get edu_login_required => 'Connectez-vous pour voir vos cours';
  
  @override String get edu_learning_empty_title => 'Aucun cours en cours';
  @override String get edu_learning_empty_desc => 'Inscrivez-vous à un cours pour commencer.';
  @override String get edu_no_courses => 'Aucun cours en cours';
  @override String get edu_enroll_hint => 'Inscrivez-vous à un cours pour commencer.';
  @override String get edu_explore_btn => 'Explorer les cours';
  @override String get edu_completed => 'Terminé';
  
  @override String get edu_user_avatar => 'Avatar Utilisateur';
  @override String get edu_greeting => 'Bonjour,';
  @override String get edu_greeting_subtitle => 'Prêt à améliorer vos compétences ?';
  @override String get edu_ready_to_learn => 'Prêt à améliorer vos compétences ?';
  @override String get edu_learner => 'Apprenant';
  @override String get edu_notifications => 'Notifications';
  @override String get edu_search_hint => 'Rechercher des cours, certifications…';
  @override String get edu_browse => 'Parcourir';
  @override String get edu_library => 'Bibliothèque';
  @override String get edu_certs => 'Certificats';
  @override String get edu_qa_browse => 'Parcourir';
  @override String get edu_instructor => 'Instructeur';
  
  @override String get edu_top_formations => 'Top Formations';
  @override String get edu_awaited_formations => 'Les Plus Attendues';
  @override String get edu_awaited => 'Les Plus Attendues';
  @override String get edu_see_all => 'Voir le Catalogue';
  
  @override String edu_coming_soon(String category) => 'De nouveaux cours en $category arrivent bientôt';
  @override String get edu_coming_soon_cat => 'De nouveaux cours arrivent bientôt ici';
  @override String get edu_locked_course => 'Bientôt disponible ! (Ouverture prévue prochainement)';
  @override String get edu_coming_soon_badge => 'OUVERTURE PROCHAINE';
  @override String get edu_awaited_badge => 'Bientôt disponible';
  @override String get edu_awaited_locked => 'Verrouillé';
  @override String get edu_awaited_locked_msg => 'Bientôt disponible ! (Ouverture prévue prochainement)';
  
  @override String get edu_thix_academy => 'THIX Academy';
  @override String get edu_scheduled_soon => 'Programmé pour : Bientôt';
  @override String get edu_new_program => 'NOUVEAU PROGRAMME';
  @override String get edu_resume_learning => 'REPRENDRE L\'APPRENTISSAGE';
  @override String get edu_resume => 'Reprendre l\'apprentissage';
  
  @override String get edu_catalog => 'Catalogue';
  @override String get edu_no_formations_cat => 'Aucune formation dans cette catégorie';
  
  @override String get edu_my_library => 'Ma Bibliothèque';
  @override String get edu_search_book_hint => 'Rechercher par titre ou auteur...';
  @override String get edu_library_title => 'Ma bibliothèque';
  @override String get edu_search_library => 'Rechercher par titre ou auteur…';
  @override String get edu_shelves_empty => 'Vos étagères sont vides.';
  @override String get edu_library_empty => 'Vos étagères sont vides.';
  @override String get edu_no_result => 'Aucun résultat';
  @override String edu_search_no_results(String query) => 'Aucun résultat pour "$query"';
  
  @override String get edu_shelf => 'Étagère';
  @override String get edu_books => 'livres';
  @override String get edu_all => 'Tout';
  @override String edu_shelf_info(String code, int count) => 'Étagère $code · $count livres';
  @override String get edu_free => 'Gratuit';
  @override String get edu_deleted_in => 'Ne sera plus accessible dans';
  @override String edu_expires_in(String countdown) => 'Expire dans $countdown';
  
  @override String get edu_certifications => 'Certifications';
  @override String get edu_certs_title => 'Certifications';
  @override String get edu_no_certs => 'Aucune certification pour le moment';
  @override String get edu_cert_expert => 'Certificat d\'Expertise';
  @override String get edu_cert_expertise => 'Certificat d\'Expertise';
  @override String edu_cert_issued(String date) => 'Délivré le $date';
  
  @override String get edu_pro_account => 'Compte Professionnel';
  @override String get edu_profile_title => 'Compte Professionnel';
  @override String get edu_instructor_space => 'Espace Instructeur';
  @override String get edu_tools => 'Outils Institutionnels';
  @override String get edu_institutional_tools => 'Outils Institutionnels';
  @override String get edu_free_resources => 'Ressources Libres';
  @override String get edu_masterclass => 'Masterclass';
  @override String get edu_masterclasses => 'Masterclasses';
  @override String get edu_network => 'Réseau et Mentorat';
  @override String get edu_mentorship => 'Réseautage et Mentorat';
  @override String get edu_events_agenda => 'Agenda d\'Événements';
  @override String get edu_support => 'Support Technique';
  @override String get edu_not_connected => 'Non connecté';

  @override String get training_title => 'Formation';
  @override String get training_enroll => 'S\'inscrire';
  @override String get training_my_courses => 'Mes Cours';
  @override String get training_certificates => 'Mes Certificats';
  @override String get training_progress => 'Progression';
  @override String get training_lessons => 'Leçons';
  @override String get training_duration => 'Durée';
  @override String get training_level => 'Niveau';
  @override String get training_beginner => 'Débutant';
  @override String get training_intermediate => 'Intermédiaire';
  @override String get training_advanced => 'Avancé';
  @override String get training_start_course => 'Commencer le cours';
  @override String get training_continue_course => 'Continuer le cours';

  // ============================================================================
  // EMPLOIS & RECRUTEMENT
  // ============================================================================
  @override String get jobs_title => 'Emplois';
  @override String get jobs_search => 'Rechercher un emploi';
  @override String get jobs_apply => 'Postuler';
  @override String get jobs_saved => 'Enregistrés';
  @override String get jobs_applied => 'Candidatures envoyées';
  @override String get jobs_company => 'Entreprise';
  @override String get jobs_location => 'Lieu';
  @override String get jobs_salary => 'Salaire';
  @override String get jobs_type => 'Type';
  @override String get jobs_full_time => 'Temps plein';
  @override String get jobs_part_time => 'Temps partiel';
  @override String get jobs_contract => 'Contrat';
  @override String get jobs_internship => 'Stage';
  @override String get jobs_freelance => 'Indépendant';
  @override String get jobs_remote => 'Télétravail';
  @override String get jobs_onsite => 'Sur site';
  @override String get jobs_hybrid => 'Hybride';
  @override String get jobs_experience => 'Expérience';
  @override String get jobs_no_experience => 'Débutant';
  @override String get jobs_junior => 'Junior';
  @override String get jobs_mid => 'Intermédiaire';
  @override String get jobs_senior => 'Senior';
  @override String get jobs_requirements => 'Exigences';
  @override String get jobs_responsibilities => 'Responsabilités';
  @override String get jobs_benefits => 'Avantages';
  @override String get jobs_apply_now => 'Postuler maintenant';
  @override String get jobs_application_sent => 'Candidature envoyée';
  @override String get jobs_no_results => 'Aucune offre trouvée';
  @override String get recruiter_title => 'Recruteur';
  @override String get recruiter_post_job => 'Publier une offre';
  @override String get recruiter_candidates => 'Candidats';
  @override String get recruiter_applications => 'Candidatures';
  @override String get recruiter_interviews => 'Entretiens';

  // ============================================================================
  // OPPORTUNITÉS
  // ============================================================================
  @override String get opportunities_title => 'Opportunités';
  @override String get opportunities_business => 'Affaires';
  @override String get opportunities_investment => 'Investissement';
  @override String get opportunities_partnership => 'Partenariat';
  @override String get opportunities_grant => 'Subvention';
  @override String get opportunities_coming_soon => 'Bientôt disponible';

  // ============================================================================
  // MARCHÉ & E-COMMERCE
  // ============================================================================
  @override String get market_title => 'THIX Market';
  @override String get market_categories => 'Catégories';
  @override String get market_products => 'Produits';
  @override String get market_services => 'Services';
  @override String get market_add_to_cart => 'Ajouter au panier';
  @override String get market_buy_now => 'Acheter maintenant';
  @override String get market_cart => 'Panier';
  @override String get market_checkout => 'Paiement';
  @override String get market_total => 'Total';
  @override String get market_delivery => 'Livraison';
  @override String get market_seller => 'Vendeur';
  @override String get market_rating => 'Évaluation';
  @override String get market_reviews => 'Avis';
  @override String get market_in_stock => 'En stock';
  @override String get market_out_of_stock => 'Rupture de stock';
  @override String get market_add_to_favorites => 'Ajouter aux favoris';
  @override String get market_remove_from_cart => 'Retirer du panier';

  // ============================================================================
  // PORTEFEUILLE & ARGENT
  // ============================================================================
  @override String get money_title => 'THIX Wallet';
  @override String get money_balance => 'Solde';
  @override String get money_send => 'Envoyer';
  @override String get money_receive => 'Recevoir';
  @override String get money_history => 'Historique';
  @override String get money_transactions => 'Transactions';
  @override String get money_top_up => 'Recharger';
  @override String get money_withdraw => 'Retirer';
  @override String get money_transfer => 'Transférer';
  @override String get money_bills => 'Factures';
  @override String get money_recipients => 'Bénéficiaires';
  @override String get money_add_recipient => 'Ajouter un bénéficiaire';
  @override String get money_amount => 'Montant';
  @override String get money_fee => 'Frais';
  @override String get money_reference => 'Référence';
  @override String get money_confirm_transfer => 'Confirmer le transfert';
  @override String get money_transfer_success => 'Transfert réussi';
  @override String get money_transfer_failed => 'Échec du transfert';
  @override String get money_insufficient_funds => 'Fonds insuffisants';

  // ============================================================================
  // ÉVÉNEMENTS & BILLETS
  // ============================================================================
  @override String get events_title => 'Événements';
  @override String get events_upcoming => 'À venir';
  @override String get events_past => 'Passés';
  
  @override String get event_share_cta => 'Sécurisez votre place sur THIX !';
  @override String get event_sold_out_title => 'Événement Complet';
  @override String get event_sold_out_msg => 'Toutes les places sont actuellement réservées. Rejoignez la file d\'attente pour être notifié si des places se libèrent.';
  @override String get event_join_queue_confirm => 'Souhaitez-vous rejoindre la liste d\'attente ?';
  @override String get event_join_queue_btn => 'Rejoindre la file d\'attente';
  
  @override String get event_unfavorite => 'Retirer des favoris';
  @override String get event_favorite => 'Ajouter aux favoris';
  @override String get event_free => 'Gratuit';
  @override String get event_paid => 'Payant';
  
  @override String get event_time_label => 'Heure';
  @override String get event_location_label => 'Lieu';
  @override String get event_address_label => 'Adresse exacte';
  @override String get event_organized_by => 'Organisé par';
  
  @override String get event_about_title => 'À propos';
  @override String get event_no_description => 'Aucune description disponible pour cet événement.';
  @override String get event_tickets_title => 'Billets & Réservation';
  
  @override String get event_sold_out_short => 'COMPLET';
  @override String event_remaining_seats(String count) => '$count places restantes';
  @override String get event_queue_btn => 'LISTE D\'ATTENTE';
  @override String get event_book_btn => 'RÉSERVER';
  
  @override String get event_standard_entry => 'Entrée Standard';
  @override String get event_all_sold => 'Toutes les places sont vendues';
  @override String get event_limited_seats => 'Places limitées';
  @override String get event_book_now_btn => 'RÉSERVER MAINTENANT';
  
  @override String event_numbered_seats(String count) => '$count places numérotées';
  @override String get event_choose_seats_btn => 'CHOISIR MES PLACES';
  @override String get event_from_price => 'À partir de';

  @override String get events_my_tickets => 'Mes Billets';
  @override String get events_buy_ticket => 'Acheter un Billet';
  @override String get events_ticket_price => 'Prix du Billet';
  @override String get events_date => 'Date';
  @override String get events_time => 'Heure';
  @override String get events_venue => 'Lieu';
  @override String get events_organizer => 'Organisateur';
  @override String get events_attendees => 'Participants';
  @override String get events_seats_available => 'Places disponibles';
  @override String get events_sold_out => 'Complet';
  @override String get events_book_now => 'Réserver maintenant';
  @override String get events_ticket_type => 'Type de Billet';
  @override String get ticket_standard => 'Standard';
  @override String get ticket_vip => 'VIP';
  @override String get ticket_gold => 'Or';
  @override String get ticket_family => 'Famille';
  @override String get ticket_secure_ticket => 'Billet Sécurisé';
  @override String get ticket_not_found => 'Billet introuvable';
  @override String get ticket_location => 'Lieu';
  @override String get ticket_pin_label => 'Code PIN';
  @override String get ticket_show_qr => 'Afficher QR';
  @override String get ticket_booking_id => 'ID de Réservation';
  @override String get ticket_add_wallet => 'Portefeuille';
  @override String get ticket_wallet_coming_soon => 'Intégration au portefeuille à venir';
  @override String get ticket_share => 'Partager';
  @override String get ticket_share_text => 'Mon Billet THIX';
  @override String get ticket_scan_info => 'Présentez ce code QR à l\'entrée';
  @override String get ticket_security_title => 'Sécurité';
  @override String get ticket_enter_pin => 'Entrez votre code PIN';
  @override String get ticket_pin_hint => 'Code à 4 chiffres';
  @override String get ticket_pin_incorrect => 'Code PIN incorrect';
  @override String get ticket_pin_too_many_attempts => 'Trop de tentatives';
  @override String get ticket_attempts_remaining => 'Tentatives restantes';
  @override String get tickets_ticket => 'Billet';
  @override String get tickets_completed => 'Terminés';
  @override String get tickets_no_tickets => 'Aucun billet';
  @override String get tickets_no_tickets_desc => 'Vos réservations apparaîtront ici';
  @override String get tickets_discover => 'Découvrir';
  @override String get tickets_load_error => 'Échec du chargement de vos billets';
  @override String tickets_quantity(int count) => count == 0 ? 'Aucun billet' : (count == 1 ? '1 billet' : '$count billets');

  // ============================================================================
  // RÉSERVATIONS
  // ============================================================================
  @override String get reservation_title => 'Réservations';
  @override String get reservation_hotel => 'Hôtel';
  @override String get reservation_restaurant => 'Restaurant';
  @override String get reservation_transport => 'Transport';
  @override String get reservation_check_in => 'Arrivée';
  @override String get reservation_check_out => 'Départ';
  @override String get reservation_guests => 'Invités';
  @override String get reservation_rooms => 'Chambres';
  @override String get reservation_book => 'Réserver';
  @override String get reservation_cancel => 'Annuler';
  @override String get reservation_modify => 'Modifier';
  @override String get reservation_confirm => 'Confirmer la réservation';
  @override String get reservation_my_bookings => 'Mes réservations';

  // ============================================================================
  // SANTÉ
  // ============================================================================
  @override String get health_title => 'THIX Santé';
  @override String get health_appointments => 'Rendez-vous';
  @override String get health_doctors => 'Médecins';
  @override String get health_hospitals => 'Hôpitaux';
  @override String get health_pharmacies => 'Pharmacies';
  @override String get health_emergency => 'Urgence';
  @override String get health_medical_records => 'Dossiers médicaux';
  @override String get health_prescriptions => 'Ordonnances';
  @override String get health_book_appointment => 'Prendre rendez-vous';
  @override String get health_appointment_date => 'Date du rendez-vous';
  @override String get health_specialty => 'Spécialité';
  @override String get health_consultation => 'Consultation';
  @override String get health_telemedicine => 'Télémédecine';
  @override String get health_insurance => 'Assurance';
  @override String get health_symptoms => 'Symptômes';
  @override String get health_find_doctor => 'Trouver un médecin';

  // ============================================================================
  // MÉDIA & INFOS
  // ============================================================================
  @override String get media_title => 'THIX Media';
  @override String get media_news => 'Actualités';
  @override String get media_videos => 'Vidéos';
  @override String get media_podcasts => 'Podcasts';
  @override String get media_articles => 'Articles';
  @override String get media_live => 'En direct';
  @override String get media_categories => 'Catégories';
  @override String get media_bookmarks => 'Signets';
  @override String get media_share_article => 'Partager l\'article';
  @override String get media_read_more => 'Lire la suite';
  @override String get media_published_on => 'Publié le';
  @override String get media_author => 'Auteur';
  @override String get info_title => 'Infos';
  @override String get info_local => 'Local';
  @override String get info_national => 'National';
  @override String get info_international => 'International';
  @override String get info_sports => 'Sports';
  @override String get info_culture => 'Culture';
  @override String get info_economy => 'Économie';
  @override String get info_politics => 'Politique';
  @override String get info_technology => 'Technologie';
  @override String get info_read_full => 'Lire l\'article complet';

  // ============================================================================
  // MON PAYS
  // ============================================================================
  @override String get mon_pays_title => 'Mon Pays';
  @override String get mon_pays_regions => 'Régions';
  @override String get mon_pays_cities => 'Villes';
  @override String get mon_pays_culture => 'Culture';
  @override String get mon_pays_history => 'Histoire';
  @override String get mon_pays_tourism => 'Tourisme';
  @override String get mon_pays_discover => 'Découvrir';
  @override String get mon_pays_landmarks => 'Lieux emblématiques';
  @override String get mon_pays_traditions => 'Traditions';

  // ============================================================================
  // COFFRE-FORT
  // ============================================================================
  @override String get vault_title => 'Coffre-fort';
  @override String get vault_documents => 'Documents';
  @override String get vault_photos => 'Photos';
  @override String get vault_videos => 'Vidéos';
  @override String get vault_notes => 'Notes';
  @override String get vault_passwords => 'Mots de passe';
  @override String get vault_add_document => 'Ajouter un document';
  @override String get vault_upload => 'Importer';
  @override String get vault_encrypted => 'Chiffré';
  @override String get vault_backup => 'Sauvegarder';
  @override String get vault_restore => 'Restaurer';
  @override String get vault_share_secure => 'Partage sécurisé';
  @override String get vault_unlock => 'Déverrouiller';
  @override String get vault_lock => 'Verrouiller';

  // ============================================================================
  // PAIEMENT
  // ============================================================================
  @override String get payment_title => 'Paiement';
  @override String get payment_method => 'Mode de paiement';
  @override String get payment_card => 'Carte bancaire';
  @override String get payment_mobile_money => 'Mobile Money';
  @override String get payment_bank_transfer => 'Virement bancaire';
  @override String get payment_cash => 'Espèces';
  @override String get payment_confirm => 'Confirmer le paiement';
  @override String get payment_success => 'Paiement réussi';
  @override String get payment_failed => 'Échec du paiement';
  @override String get payment_processing => 'Traitement en cours…';
  @override String get payment_receipt => 'Reçu';
  @override String get payment_invoice => 'Facture';

  // ============================================================================
  // RECHERCHE (MISSING PERSONS / SEARCH)
  // ============================================================================
  @override String get search_title => 'THIX Recherche';
  @override String get search_subtitle => 'Personnes Disparues et Avis Officiels';
  @override String get search_person_missing => 'Personne Disparue';
  @override String get search_person_wanted => 'Avis de Recherche Officiel';
  @override String get search_report_missing => 'Signaler une disparition';
  @override String get search_report_found => 'Signaler une personne retrouvée';
  @override String get search_details => 'Détails';
  @override String get search_contact_authorities => 'Contacter les autorités';
  @override String get search_share_alert => 'Partager l\'alerte';
  @override String get search_last_seen => 'Vu pour la dernière fois à';
  @override String get search_description => 'Description';
  @override String get search_age => 'Âge';
  @override String get search_height => 'Taille';
  @override String get search_weight => 'Poids';
  @override String get search_hair_color => 'Couleur des cheveux';
  @override String get search_eye_color => 'Couleur des yeux';
  @override String get search_distinguishing_marks => 'Signes distinctifs';
  @override String get search_clothing => 'Vêtements';
  @override String get search_circumstances => 'Circonstances';
  @override String get search_case_number => 'Numéro de dossier';
  @override String get search_reported_by => 'Signalé par';
  @override String get search_official_notice => 'Avis Officiel';
  @override String get search_community_alert => 'Alerte Communautaire';

  // ============================================================================
  // À PROXIMITÉ & ALERTES
  // ============================================================================
  @override String get nearby_alerts_title => 'Alertes à Proximité';
  @override String get nearby_view_on_map => 'Voir sur la carte';
  @override String get nearby_map_coming_soon => 'Carte plein écran bientôt disponible';
  @override String get nearby_map_disabled => 'Carte désactivée (en attente de clé API)';
  @override String get nearby_active_alerts => 'Alertes Actives';
  @override String get nearby_missing => 'Disparu(e)';
  @override String get nearby_official => 'Officiel';
  @override String get nearby_legend_missing => 'Personne Disparue';
  @override String get nearby_legend_official => 'Avis Officiel';
  @override String get nearby_legend_report => 'Signalement';
  @override String get nearby_location_required => 'Activer la localisation';
  @override String get nearby_location_subtitle => 'Voir les alertes autour de vous';

  // ============================================================================
  // ADMINISTRATION
  // ============================================================================
  @override String get admin_title => 'Administration THIX';
  @override String get admin_dev_open => 'Développement Ouvert';
  @override String get admin_actions_section => 'Actions';
  
  @override String get admin_events_title => 'Événements';
  @override String get admin_events_create => 'Créer';
  @override String get admin_events_search_hint => 'Rechercher par titre...';
  @override String get admin_events_filter => 'Filtre de catégorie';
  @override String get admin_events_empty => 'Aucun événement trouvé';
  @override String get admin_events_no_permission => 'Vous n\'avez pas la permission d\'effectuer cette action';
  @override String get admin_events_delete_title => 'Supprimer ?';
  @override String admin_events_delete_desc(String title) => 'Voulez-vous supprimer $title ? Cette action est irréversible.';

  @override String get admin_limits_purchase_rules => 'Règles d\'Achat';
  @override String get admin_limits_max_person => 'Max / personne (global)';
  @override String get admin_limits_max_transaction => 'Max / transaction (panier)';
  @override String get admin_limits_require_thix_id => 'Vérification THIX ID Requise';
  @override String get admin_limits_require_thix_id_desc => 'Recommandé pour les événements à forte demande.';
  @override String get admin_limits_info_title => 'Architecture Sécurisée';
  @override String get admin_limits_info_desc => 'Ces limites sont appliquées et vérifiées directement par les Edge Functions en SQL en temps réel pour prévenir la fraude et les conditions de concurrence.';

  @override String get admin_stat_events => 'Événements';
  @override String get admin_stat_bookings => 'Réservations';
  @override String get admin_stat_revenue => 'Revenus';
  @override String get admin_stat_queue => 'File d\'attente';
  @override String get admin_action_events => 'Événements';
  @override String get admin_action_events_sub => '20 / page';
  @override String get admin_action_create => 'Créer';
  @override String get admin_action_create_sub => 'Upload + Vérifier';
  @override String get admin_action_seats => 'Sièges';
  @override String get admin_action_seats_sub => 'Lot de 200';
  @override String get admin_action_reservations => 'Réservations';
  @override String get admin_action_reservations_sub => '50 / page + Filtres';
  @override String get admin_action_limits => 'Anti-Fraude';
  @override String get admin_action_limits_sub => 'Limites';
  @override String get admin_action_analytics => 'Analytiques';
  @override String get admin_action_analytics_sub => 'RPC';
  @override String get admin_read_only => 'Lecture Seule';
  @override String get admin_bookings_title => 'Réservations • 50/page';
  @override String get admin_bookings_export => 'Exportation serveur en cours (tâche)';
  @override String get admin_bookings_details => 'Détails du Billet';
  @override String get admin_bookings_event => 'Événement';
  @override String get admin_bookings_unknown_event => 'Événement inconnu';
  @override String get admin_bookings_id => 'ID de Réservation';
  @override String get admin_bookings_quantity => 'Quantité';
  @override String get admin_bookings_category => 'Catégorie';
  @override String get admin_bookings_amount => 'Montant';
  @override String get admin_bookings_pin => 'PIN';
  @override String get admin_bookings_purchase_date => 'Date d\'Achat';
  @override String get admin_bookings_close => 'Fermer';
  @override String get admin_bookings_empty => 'Aucune réservation trouvée';
  @override String get admin_bookings_unknown_date => 'Date inconnue';
  @override String admin_bookings_places(int count) => '$count places';
  @override String get admin_bookings_status_valid => 'Valide';
  @override String get admin_bookings_status_used => 'Utilisé';
  @override String get admin_bookings_status_cancelled => 'Annulé';
  @override String get admin_bookings_status_postponed => 'Reporté';
  @override String get admin_bookings_status_pending => 'En attente';
  @override String admin_queue_title(int count) => 'File d\'Attente • Temps Réel ($count)';
  @override String get admin_queue_realtime_desc => 'Temps réel actif • Se met à jour automatiquement quand les utilisateurs rejoignent';
  @override String get admin_queue_empty => 'La file est vide';
  @override String get admin_queue_event_fallback => 'Événement';
  @override String admin_queue_item_meta(String userId, int qty, String status) => 'Utilisateur: $userId • $qty places • $status';
  @override String get admin_queue_notify => 'Notifier';
  @override String get admin_queue_notified => 'Utilisateur notifié (expire dans 10 min)';
  @override String get admin_queue_position => 'Position';
  @override String get admin_queue_places => 'Places';
  @override String get admin_analytics_title => 'Analytiques • Performance';
  @override String get admin_analytics_fill_rate => 'Taux de Remplissage';
  @override String get admin_analytics_avg_cart => 'Panier Moyen';
  @override String get admin_analytics_no_show => 'Taux de No-Show';
  @override String get admin_analytics_rev_per_event => 'Revenu / événement';
  @override String get admin_analytics_revenue_7d => 'Revenus 7 Jours';
  @override String get admin_analytics_no_data => 'Aucune donnée disponible';
  @override String get admin_analytics_error => 'Échec du chargement des statistiques';
  @override String get admin_event_create => 'Créer un Événement';
  @override String get admin_event_edit => 'Modifier l\'Événement';
  @override String get admin_event_btn_create => 'Créer';
  @override String get admin_event_btn_save => 'Enregistrer';
  @override String get admin_event_cover => 'Image de Couverture';
  @override String get admin_event_banner => 'Bannière';
  @override String get admin_event_title => 'Titre *';
  @override String get admin_event_desc => 'Description *';
  @override String get admin_event_category => 'Catégorie';
  @override String get admin_event_subcategory => 'Sous-catégorie';
  @override String get admin_event_datetime => 'Date et Heure';
  @override String get admin_event_start => 'Début';
  @override String get admin_event_end => 'Fin (optionnel)';
  @override String get admin_event_add_end => 'Ajouter une Heure de Fin';
  @override String get admin_event_city => 'Ville *';
  @override String get admin_event_location => 'Lieu *';
  @override String get admin_event_address => 'Adresse';
  @override String get admin_event_organizer => 'Organisateur';
  @override String get admin_event_phone => 'Téléphone';
  @override String get admin_event_email => 'Email de Contact';
  @override String get admin_event_tiers_title => 'Catégories et Capacité';
  @override String get admin_event_add_tier_btn => 'Ajouter VVIP, VIP…';
  @override String get admin_event_status => 'Statut';
  @override String get admin_event_visibility => 'Visibilité';
  @override String get admin_event_cat_concert => 'Concert';
  @override String get admin_event_cat_conference => 'Conférence';
  @override String get admin_event_cat_sport => 'Sport';
  @override String get admin_event_cat_festival => 'Festival';
  @override String get admin_event_cat_theatre => 'Théâtre';
  @override String get admin_event_cat_other => 'Autre';
  @override String get admin_event_status_upcoming => 'À venir';
  @override String get admin_event_status_ongoing => 'En cours';
  @override String get admin_event_status_completed => 'Terminé';
  @override String get admin_event_status_cancelled => 'Annulé';
  @override String get admin_event_vis_default => 'À venir (par défaut)';
  @override String get admin_event_vis_recommended => 'Recommandé';
  @override String get admin_event_vis_featured => 'En vedette';
  @override String get admin_event_dialog_add_tier => 'Ajouter une catégorie';
  @override String get admin_event_dialog_name => 'Nom (ex: VVIP)';
  @override String admin_event_dialog_price(String currency) => 'Prix ($currency)';
  @override String get admin_event_dialog_capacity => 'Capacité';
  @override String get admin_event_dialog_cancel => 'Annuler';
  @override String get admin_event_dialog_add => 'Ajouter';
  @override String get admin_event_err_readonly => 'Lecture Seule';
  @override String get admin_event_err_min_tier => 'Au moins une catégorie est requise';
  @override String get admin_event_success => 'Événement enregistré avec succès';
  @override String get admin_event_err_title_req => 'Le titre est requis';
  @override String get admin_event_err_desc_min => 'Minimum 10 caractères';
  @override String get admin_event_err_city_req => 'La ville est requise';
  @override String get admin_event_err_loc_req => 'Le lieu est requis';
  @override String get admin_seat_page_title => 'Carte des Sièges et Tarification';
  @override String get admin_seat_target_event => 'Événement Cible';
  @override String get admin_seat_select_event => 'Sélectionnez un événement';
  @override String admin_seat_max_limit(int count) => 'Limite maximum $count sièges';
  @override String admin_seat_generated(int count) => '$count sièges générés';
  @override String get admin_seat_load_error => 'Échec du chargement des sièges';
  @override String get admin_seat_pricing_title => 'Tarification Dynamique';
  @override String get admin_seat_layout_title => 'Disposition et Forme';
  @override String get admin_seat_rows => 'Rangées';
  @override String get admin_seat_per_row => 'Sièges / rangée';
  @override String get admin_seat_center_aisle => 'Allée Centrale';
  @override String get admin_seat_aisle_desc => 'Espace vide au milieu';
  @override String get admin_seat_cats_per_row => 'Catégories par rangée';
  @override String get admin_seat_generating => 'Génération en cours…';
  @override String admin_seat_generate_btn(int count) => 'Générer $count sièges';
  @override String get admin_seat_preview => 'Aperçu de la disposition actuelle';
  @override String get admin_seat_no_seats => 'Aucun siège généré';
  @override String get admin_seat_cat_standard => 'Standard';
  @override String get admin_seat_cat_vip => 'VIP';
  @override String get admin_seat_cat_gold => 'Or';
  @override String get admin_seat_cat_family => 'Famille';
  @override String get admin_seat_legend_reserved => 'Réservé';
  @override String get admin_seat_legend_sold => 'Vendu';
  @override String get seat_map_stage => 'Scène';

  // ============================================================================
  // ERREURS & VALIDATION
  // ============================================================================
  @override String get error_generic => 'Une erreur s\'est produite';
  @override String get error_validation => 'Données invalides';
  @override String get error_file_too_large => 'Fichier trop volumineux';
  @override String get error_unsupported_format => 'Format non supporté';
  @override String get error_permission_denied => 'Permission refusée';
  @override String get error_camera_unavailable => 'Caméra indisponible';
  @override String get error_microphone_unavailable => 'Microphone indisponible';
  @override String get error_location_unavailable => 'Services de localisation indisponibles';
  @override String get error_network => 'Erreur réseau';
  @override String get error_timeout => 'La requête a expiré';
  @override String get error_server => 'Erreur serveur';
  @override String get error_not_found => 'Introuvable';

  // ============================================================================
  // TEMPS & DATES RELATIVES
  // ============================================================================
  @override String get common_just_now => 'À l\'instant';
  @override String get common_in_the_future => 'Plus tard';
  @override String common_minutes_ago(int count) => count == 1 ? 'Il y a 1 minute' : 'Il y a $count minutes';
  @override String common_hours_ago(int count) => count == 1 ? 'Il y a 1 heure' : 'Il y a $count heures';
  @override String common_days_ago(int count) => count == 1 ? 'Il y a 1 jour' : 'Il y a $count jours';
  @override String common_seconds_ago(int count) => count == 1 ? 'Il y a 1 seconde' : 'Il y a $count secondes';
  @override String common_weeks_ago(int count) => count == 1 ? 'Il y a 1 semaine' : 'Il y a $count semaines';
  @override String common_months_ago(int count) => count == 1 ? 'Il y a 1 mois' : 'Il y a $count mois';
  @override String common_years_ago(int count) => count == 1 ? 'Il y a 1 an' : 'Il y a $count ans';
  @override String common_in_minutes(int count) => count == 1 ? 'Dans 1 minute' : 'Dans $count minutes';
  @override String common_in_hours(int count) => count == 1 ? 'Dans 1 heure' : 'Dans $count heures';
  @override String common_in_days(int count) => count == 1 ? 'Dans 1 jour' : 'Dans $count jours';

  // ============================================================================
  // THIX MEDIA & IA SOURCES
  // ============================================================================
  @override String get live_go_live => 'Passer au direct';
  @override String get live_title => 'Titre du direct';
  @override String get live_start => 'Commencer le direct';
  @override String get live_end => 'Terminer le direct';
  @override String get live_duration => 'Durée';
  @override String get live_peak_viewers => 'Pic de spectateurs';
  @override String get live_chat_disabled => 'Le chat est désactivé.';
  @override String get live_share => 'Partager';
  @override String get live_report => 'Signaler';
  @override String get live_follow_host => 'Suivre';
  @override String get live_gift_send => 'Envoyer un cadeau';
  @override String get live_quality_auto => 'Auto';
  @override String get live_quality_hd => 'HD';
  @override String get live_quality_sd => 'SD';
  @override String get live_quality_low => 'Basse';

  @override String get insight_source_unverified => 'Source non vérifiée';
  @override String get insight_recommended_actions => 'Actions recommandées';
  @override String get insight_key_findings => 'Principales conclusions';
  @override String get insight_summary => 'Résumé';
  @override String get insight_full_analysis => 'Analyse complète';
  @override String get insight_generated_by => 'Généré par IA';
  @override String get insight_disclaimer => 'Ceci est une analyse générée par IA. Veuillez vérifier les informations.';

  @override String get risk_level_label => 'Niveau de risque';
  @override String get risk_mitigation => 'Mesures d\'atténuation';
  @override String get risk_impact => 'Impact';
  @override String get risk_probability => 'Probabilité';
  @override String get risk_assessment => 'Évaluation des risques';

  @override String get live_leave_btn => 'Quitter le direct';
  @override String get live_chat_empty => 'Aucun message pour le moment.';
  @override String get live_chat_hint => 'Dites quelque chose...';
  @override String get live_like => 'J\'aime';
  @override String get live_send => 'Envoyer';
  @override String get live_viewers => 'spectateurs';
  @override String get live_likes => 'J\'aime';
  @override String get live_leaving => 'Déconnexion en cours...';
  @override String get live_network_quality => 'Qualité réseau';
  @override String get insight_type_market => 'Marché';
  @override String get insight_type_finance => 'Finance';
  @override String get insight_type_strategy => 'Stratégie';
  @override String get insight_type_business => 'Entreprise';
  @override String get insight_type_insight => 'Aperçu';
  @override String get insight_confidence_label => 'Indice de confiance';
  @override String get insight_source_verified => 'Source vérifiée';
  @override String get risk_critical => 'Critique';
  @override String get risk_high => 'Élevé';
  @override String get risk_medium => 'Moyen';
  @override String get risk_low => 'Faible';
  @override String get source_type_official => 'Officiel';
  @override String get source_type_world_bank => 'Banque Mondiale';
  @override String get source_type_government => 'Gouvernement';
  @override String get source_type_default => 'Source Vérifiée';
  @override String get source_aria_label => 'Source de l\'information';
}
