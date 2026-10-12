// lib/presentation/network/widgets/create_post_l10n.dart
// Adaptateur : expose les textes de CreatePostPage via le système l10n.t('clé')
// du projet. Chaque clé "cp_*" a un repli français : rien ne s'affiche en clé brute.
import 'package:thix_id/l10n/app_localizations.dart';

extension CreatePostL10n on AppLocalizations {
  String _s(String key, String fallback, [Map<String, String> params = const {}]) {
    var v = '';
    try {
      v = t(key, args: params.values.toList());
    } catch (_) {
      v = '';
    }
    if (v.isEmpty || v == key) v = fallback;
    params.forEach((k, val) => v = v.replaceAll('{$k}', val));
    return v;
  }

  // ── Titres / segments / actions ──
  String get cpTitlePost => _s('cp_title_post', 'Créer une publication');
  String get cpTitlePoll => _s('cp_title_poll', 'Créer un sondage');
  String get cpTitleChallenge => _s('cp_title_challenge', 'Créer un challenge');
  String get cpPublish => _s('cp_publish', 'Publier');
  String get cpSegPost => _s('cp_seg_post', 'Publication');
  String get cpSegPoll => _s('cp_seg_poll', 'Sondage');
  String get cpSegChallenge => _s('cp_seg_challenge', 'Challenge');
  String get cpHintPost =>
      _s('cp_hint_post', 'Quoi de neuf ? Utilisez @ pour mentionner, # pour un hashtag...');
  String get cpHintPoll => _s('cp_hint_poll', 'Posez votre question...');
  String get cpHintChallenge => _s('cp_hint_challenge', 'Titre du challenge...');
  String get cpDefaultAuthor => _s('cp_default_author', 'Moi');
  String get cpVisibility => _s('cp_visibility', 'Visibilité');
  String get cpPublic => _s('cp_public', 'Public');
  String get cpContactsOnly => _s('cp_contacts_only', 'Contacts uniquement');
  String get cpContacts => _s('cp_contacts', 'Contacts');
  String get cpBold => _s('cp_bold', 'Gras');
  String get cpItalic => _s('cp_italic', 'Italique');
  String get cpParagraph => _s('cp_paragraph', 'Saut de paragraphe');
  String get cpPhotos => _s('cp_photos', 'Photos');
  String get cpVideos => _s('cp_videos', 'Vidéos');
  String get cpCamera => _s('cp_camera', 'Caméra');
  String get cpAudio => _s('cp_audio', 'Audio');
  String get cpSuccess => _s('cp_success', 'Publication réussie');

  // ── Étiquettes spéciales ──
  String get cpTagsTitle => _s('cp_tags_title', 'Étiquette spéciale');
  String get cpTagUrgent => _s('cp_tag_urgent', 'Urgent');
  String get cpTagFlash => _s('cp_tag_flash', 'Flash');
  String get cpTagImportant => _s('cp_tag_important', 'Important');
  String get cpTagBreaking => _s('cp_tag_breaking', 'Dernière minute');
  String get cpTagHot => _s('cp_tag_hot', 'Brûlant');
  String get cpTagAlert => _s('cp_tag_alert', 'Alerte');
  String get cpTagAnnouncement => _s('cp_tag_announcement', 'Annonce');
  String get cpTagExclusive => _s('cp_tag_exclusive', 'Exclusif');
  String get cpTagReminder => _s('cp_tag_reminder', 'Rappel');
  String get cpTagEvent => _s('cp_tag_event', 'Événement');

  // ── Fermeture / brouillon ──
  String get cpDiscardTitle => _s('cp_discard_title', 'Quitter la création ?');
  String get cpDiscardBody =>
      _s('cp_discard_body', "Votre publication n'est pas envoyée. Voulez-vous enregistrer un brouillon ?");
  String get cpDiscardKeep => _s('cp_discard_keep', 'Continuer');
  String get cpDiscardDelete => _s('cp_discard_delete', 'Supprimer');
  String get cpDiscardSave => _s('cp_discard_save', 'Enregistrer');
  String get cpDraftRestored => _s('cp_draft_restored', 'Brouillon restauré');

  // ── Dialogues tiers / quotas / permissions ──
  String get cpLockedTitle => _s('cp_locked_title', 'Fonctionnalité bloquée');
  String cpLockedBody(String feature, String tier) => _s(
        'cp_locked_body',
        '{feature} est réservée aux comptes {tier} et supérieurs.\n\nMettez à niveau votre compte pour débloquer de nouveaux outils pour votre communauté.',
        {'feature': feature, 'tier': tier},
      );
  String get cpLater => _s('cp_later', 'Plus tard');
  String get cpSeeOffers => _s('cp_see_offers', 'Voir les offres');
  String get cpQuotaTitle => _s('cp_quota_title', 'Quota journalier atteint');
  String cpQuotaBody(int limit) => _s(
        'cp_quota_body',
        'Vous avez atteint votre quota de {limit} publications vocales par jour.\n\nVotre quota sera réinitialisé dans 24h, ou vous pouvez mettre à niveau votre abonnement pour publier sans limite.',
        {'limit': '$limit'},
      );
  String get cpUnderstood => _s('cp_understood', 'Compris');
  String get cpUpgrade => _s('cp_upgrade', 'Mettre à niveau');
  String get cpPermRequiredTitle => _s('cp_perm_required_title', 'Permission requise');
  String get cpPermDeniedBody => _s('cp_perm_denied_body',
      "Vous avez précédemment refusé cette permission. Veuillez l'activer dans les paramètres de l'application.");
  String get cpCancel => _s('cp_cancel', 'Annuler');
  String get cpOpenSettings => _s('cp_open_settings', 'Ouvrir les paramètres');
  String get cpAuthTitle => _s('cp_auth_title', 'Autorisation requise');
  String get cpMicRationale => _s('cp_mic_rationale',
      "Pour vous permettre d'enregistrer et de partager un message vocal dans votre publication, THIX ID a besoin d'accéder à votre microphone.");
  String get cpCameraRationale => _s('cp_camera_rationale',
      "Pour vous permettre de prendre une photo directement depuis l'application et l'ajouter à votre publication, THIX ID a besoin d'accéder à votre caméra.");

  // ── Fonctionnalités / niveaux ──
  String get cpFeatFormatting => _s('cp_feat_formatting', 'Le formatage du texte');
  String get cpFeatTextColors => _s('cp_feat_text_colors', 'Les couleurs de texte');
  String get cpFeatMorePhotos => _s('cp_feat_more_photos', 'Ajouter plus de photos');
  String get cpFeatVideos => _s('cp_feat_videos', 'La publication de vidéos');
  String get cpFeatPolls => _s('cp_feat_polls', 'Les sondages');
  String get cpFeatChallenges => _s('cp_feat_challenges', 'Les challenges');
  String get cpFeatBgColors => _s('cp_feat_bg_colors', 'Les fonds colorés');
  String get cpTierStandard => _s('cp_tier_standard', 'Standard');
  String get cpTierPremium => _s('cp_tier_premium', 'Premium');

  // ── Erreurs ──
  String get cpErrEmpty => _s('cp_err_empty', 'Ajoutez du texte, un média ou un audio');
  String get cpErrPollQuestion => _s('cp_err_poll_question', 'Saisissez la question du sondage');
  String get cpErrChallengeFields =>
      _s('cp_err_challenge_fields', 'Titre, description et date de fin obligatoires');
  String get cpErrChallengeDatePast =>
      _s('cp_err_challenge_date_past', 'La date de fin doit être dans le futur');
  String get cpErrPollMin => _s('cp_err_poll_min', 'Au moins 2 options requises');
  String cpErrPollOptionLong(int max) =>
      _s('cp_err_poll_option_long', 'Options trop longues (max {max} caractères)', {'max': '$max'});
  String get cpErrPollDuplicate =>
      _s('cp_err_poll_duplicate', 'Les options du sondage doivent être différentes');
  String get cpErrMicDenied => _s('cp_err_mic_denied', 'Permission microphone refusée.');
  String get cpErrRecordStart => _s('cp_err_record_start', "Impossible de démarrer l'enregistrement.");
  String get cpErrRecordFail => _s('cp_err_record_fail', "Erreur lors de l'enregistrement.");
  String cpErrAudioTooBig(int max) =>
      _s('cp_err_audio_too_big', 'Audio trop volumineux (max {max} Mo)', {'max': '$max'});
  String cpErrFileTooBig(String name, int max) => _s(
      'cp_err_file_too_big', '{name} : trop volumineux (max {max} Mo)', {'name': name, 'max': '$max'});
  String cpErrFileFormat(String name) =>
      _s('cp_err_file_format', '{name} : format non supporté', {'name': name});
  String get cpErrFileTooSmall => _s('cp_err_file_too_small', 'Fichier trop petit');
  String get cpErrFileUnrecognized =>
      _s('cp_err_file_unrecognized', 'Format de fichier non reconnu');
  String cpErrPhotoTooBig(int max) =>
      _s('cp_err_photo_too_big', 'Photo trop volumineuse (max {max} Mo)', {'max': '$max'});
  String get cpErrNotAuth => _s('cp_err_not_auth', 'Non authentifié');
  String get cpErrUploadAudio => _s('cp_err_upload_audio', "Échec de l'envoi de l'audio");
  String get cpErrUploadImage => _s('cp_err_upload_image', "Échec de l'envoi de l'image");
  String get cpErrUploadVideo => _s('cp_err_upload_video', "Échec de l'envoi de la vidéo");
  String cpErrGeneric(String message) =>
      _s('cp_err_generic', 'Erreur : {message}', {'message': message});

  // ── Audio / envoi ──
  String cpRecording(String time) => _s('cp_recording', 'Enregistrement... {time}', {'time': time});
  String cpMaxDuration(int seconds) =>
      _s('cp_max_duration', 'Durée maximale atteinte ({seconds} s)', {'seconds': '$seconds'});
  String cpUploading(int done, int total) =>
      _s('cp_uploading', 'Envoi {done}/{total}…', {'done': '$done', 'total': '$total'});

  // ── Sondage ──
  String get cpPollOptions => _s('cp_poll_options', 'Options de réponse');
  String cpPollOption(int n) => _s('cp_poll_option', 'Option {n}', {'n': '$n'});
  String get cpPollAddOption => _s('cp_poll_add_option', 'Ajouter une option');
  String get cpPollMultiple => _s('cp_poll_multiple', 'Autoriser plusieurs choix');
  String get cpPollDuration => _s('cp_poll_duration', 'Durée du sondage');
  String get cpPollOneWeek => _s('cp_poll_one_week', '1 semaine');
  String cpPollDays(int count) => count == 1
      ? _s('cp_poll_day_one', '{count} jour', {'count': '$count'})
      : _s('cp_poll_day_many', '{count} jours', {'count': '$count'});
  String get cpDragToReorder => _s('cp_drag_to_reorder', 'Glisser pour réorganiser');

  // ── Challenge ──
  String get cpChDesc => _s('cp_ch_desc', 'Description du challenge');
  String get cpChDescHint =>
      _s('cp_ch_desc_hint', 'Expliquez les règles et comment participer...');
  String get cpChReward => _s('cp_ch_reward', 'Récompense (optionnel)');
  String get cpChMax => _s('cp_ch_max', 'Participants max (optionnel)');
  String get cpChPickDate => _s('cp_ch_pick_date', "Choisir la date et l'heure de fin");
  String cpChEnds(String date, String time) =>
      _s('cp_ch_ends', 'Fin : {date} à {time}', {'date': date, 'time': time});

  // ── Suggestions # ──
  String cpHashtagPosts(int count) => count == 1
      ? _s('cp_hashtag_post_one', '{count} publication', {'count': '$count'})
      : _s('cp_hashtag_post_many', '{count} publications', {'count': '$count'});
}
