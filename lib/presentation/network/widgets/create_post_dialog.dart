// lib/presentation/network/widgets/create_post_dialog.dart
// ============================================================================
// CRÉATION DE POST — PLEIN ÉCRAN (enterprise) v7
// • 🎬 Vidéos : limite 50 Mo, TOUS les formats vidéo acceptés
// • 👥 Tag @ : dès que l'on tape « @ », les suggestions de personnes
//     s'affichent directement (mes connexions d'abord), puis filtrage en direct
// • 🏷️ 10 badges premium (URGENT battant, FLASH, IMPORTANT...) encadrés en tête
// • 🌍 100% localisé FR / EN / SW / AR — traductions intégrées (clés cp_*)
// • ¶ Paragraphes conservés (\n\n) — sanitize corrigé
// • Suggestions @/# • Sondages • Challenges • Tiers/quotas • Rollback
// • ➕ Brouillon anti-perte, compteur anneau, emojis rapides,
//   taille médias (Mo), compte à rebours challenge + autofocus
// ============================================================================
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:record/record.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:cached_network_image/cached_network_image.dart';

import 'package:thix_id/models/network_post.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/features/network/presentation/providers/feed_provider.dart';
import 'package:thix_id/presentation/certification/certification_tiers_page.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

// ============================================================================
// 🌍 TRADUCTIONS INTÉGRÉES : FR / EN / SW / AR
// Placeholders : {0}, {1}...  |  Pluriel : clé_one / clé_other
// ============================================================================
const Map<String, Map<String, String>> _kCp = {
  // ───────────────────────────── FRANÇAIS ─────────────────────────────
  'fr': {
    'common_cancel': "Annuler",
    'cp_me': "Moi",
    'cp_unit_mb': "Mo",
    'cp_draft_restored': "Brouillon restauré",
    'cp_draft_title': "Enregistrer le brouillon ?",
    'cp_draft_body': "Votre publication n'a pas été envoyée. Voulez-vous conserver ce brouillon ?",
    'cp_draft_discard': "Supprimer",
    'cp_draft_keep': "Conserver",
    'cp_upg_title': "Fonctionnalité réservée",
    'cp_upg_body': "{0} est disponible à partir de l'offre {1}. Passez à une offre supérieure pour en profiter.",
    'cp_upg_later': "Plus tard",
    'cp_upg_see': "Voir les offres",
    'cp_quota_title': "Quota atteint",
    'cp_quota_body': "Vous avez atteint la limite de {0} publications audio par jour. Passez à une offre supérieure pour continuer.",
    'cp_quota_ok': "OK",
    'cp_quota_upg': "Améliorer",
    'cp_perm_title': "Autorisation requise",
    'cp_perm_denied': "L'autorisation a été refusée définitivement. Activez-la dans les paramètres de l'application.",
    'cp_perm_open': "Ouvrir les paramètres",
    'cp_perm_mic': "THIX ID a besoin du microphone pour enregistrer votre message vocal.",
    'cp_perm_cam': "THIX ID a besoin de la caméra pour prendre une photo.",
    'cp_feat_format': "La mise en forme du texte",
    'cp_feat_colors': "Les couleurs de texte",
    'cp_feat_photos': "L'ajout de plus de photos",
    'cp_feat_video': "La publication de vidéos",
    'cp_feat_poll': "Les sondages",
    'cp_feat_challenge': "Les challenges",
    'cp_feat_bg': "Les fonds colorés",
    'cp_tier_standard': "Standard",
    'cp_tier_premium': "Premium",
    'cp_err_mic': "Accès au microphone refusé.",
    'cp_err_record_start': "Impossible de démarrer l'enregistrement.",
    'cp_err_record': "Erreur lors de l'enregistrement.",
    'cp_rec_max': "Durée maximale atteinte ({0} s)",
    'cp_err_audio_size': "Audio trop volumineux (max {0} Mo)",
    'cp_err_size': "{0} est trop volumineux (max {1} Mo)",
    'cp_err_img_fmt': "{0} : format d'image non supporté",
    'cp_err_vid_fmt': "{0} : format vidéo non supporté",
    'cp_err_small': "Fichier trop petit ou invalide",
    'cp_err_mime': "Type de fichier non autorisé",
    'cp_err_photo_size': "Photo trop volumineuse (max {0} Mo)",
    'cp_err_empty': "Écrivez quelque chose ou ajoutez un média.",
    'cp_err_poll_q': "Saisissez la question du sondage.",
    'cp_err_ch': "Renseignez le titre, la description et la date de fin du challenge.",
    'cp_err_poll_min': "Un sondage nécessite au moins 2 options.",
    'cp_err_poll_len': "Chaque option est limitée à {0} caractères.",
    'cp_err_auth': "Session expirée. Veuillez vous reconnecter.",
    'cp_err_publish': "Échec de la publication : {0}",
    'cp_err_up_audio': "Échec de l'envoi de l'audio : {0}",
    'cp_err_up_image': "Échec de l'envoi de l'image : {0}",
    'cp_err_up_video': "Échec de l'envoi de la vidéo : {0}",
    'cp_ok_publish': "Publication réussie !",
    'cp_tab_post': "Publication",
    'cp_tab_poll': "Sondage",
    'cp_tab_challenge': "Challenge",
    'cp_title_post': "Nouvelle publication",
    'cp_title_poll': "Nouveau sondage",
    'cp_title_challenge': "Nouveau challenge",
    'cp_publish': "Publier",
    'cp_bold': "Gras",
    'cp_italic': "Italique",
    'cp_badges': "Badges",
    'cp_badge_urgent': "URGENT",
    'cp_badge_flash': "FLASH",
    'cp_badge_important': "IMPORTANT",
    'cp_badge_info': "INFO",
    'cp_badge_new': "NOUVEAU",
    'cp_badge_alert': "ALERTE",
    'cp_badge_official': "OFFICIEL",
    'cp_badge_event': "ÉVÉNEMENT",
    'cp_badge_promo': "PROMO",
    'cp_badge_reminder': "RAPPEL",
    'cp_posts_one': "{0} publication",
    'cp_posts_other': "{0} publications",
    'cp_visibility': "Visibilité",
    'cp_public': "Public",
    'cp_contacts': "Mes contacts",
    'cp_contacts_short': "Contacts",
    'cp_hint_post': "Quoi de neuf ? Partagez avec votre réseau… (@ pour mentionner, # pour un hashtag)",
    'cp_hint_poll': "Posez votre question…",
    'cp_hint_challenge': "Titre du challenge…",
    'cp_poll_options': "Options",
    'cp_poll_option': "Option {0}",
    'cp_poll_add': "Ajouter une option",
    'cp_poll_multiple': "Autoriser plusieurs choix",
    'cp_poll_duration': "Durée du sondage",
    'cp_poll_week': "1 semaine",
    'cp_poll_day': "{0} jour",
    'cp_poll_days': "{0} jours",
    'cp_ch_desc': "Description du challenge",
    'cp_ch_desc_hint': "Expliquez les règles et l'objectif…",
    'cp_ch_reward': "Récompense (optionnel)",
    'cp_ch_max': "Nombre max de participants (optionnel)",
    'cp_ch_pick': "Choisir la date de fin",
    'cp_ch_end': "Fin : {0} à {1}",
    'cp_ch_countdown': "Se termine dans {0} jour(s)",
    'cp_recording': "Enregistrement… {0}",
    'cp_photos': "Photos",
    'cp_videos': "Vidéos",
    'cp_camera': "Caméra",
    'cp_audio': "Audio",
  },

  // ───────────────────────────── ENGLISH ─────────────────────────────
  'en': {
    'common_cancel': "Cancel",
    'cp_me': "Me",
    'cp_unit_mb': "MB",
    'cp_draft_restored': "Draft restored",
    'cp_draft_title': "Save draft?",
    'cp_draft_body': "Your post has not been published. Do you want to keep this draft?",
    'cp_draft_discard': "Discard",
    'cp_draft_keep': "Keep",
    'cp_upg_title': "Premium feature",
    'cp_upg_body': "{0} is available from the {1} plan. Upgrade to unlock it.",
    'cp_upg_later': "Later",
    'cp_upg_see': "See plans",
    'cp_quota_title': "Quota reached",
    'cp_quota_body': "You've reached the limit of {0} audio posts per day. Upgrade your plan to continue.",
    'cp_quota_ok': "OK",
    'cp_quota_upg': "Upgrade",
    'cp_perm_title': "Permission required",
    'cp_perm_denied': "Permission was permanently denied. Enable it in the app settings.",
    'cp_perm_open': "Open settings",
    'cp_perm_mic': "THIX ID needs the microphone to record your voice message.",
    'cp_perm_cam': "THIX ID needs the camera to take a photo.",
    'cp_feat_format': "Text formatting",
    'cp_feat_colors': "Text colors",
    'cp_feat_photos': "Adding more photos",
    'cp_feat_video': "Posting videos",
    'cp_feat_poll': "Polls",
    'cp_feat_challenge': "Challenges",
    'cp_feat_bg': "Colored backgrounds",
    'cp_tier_standard': "Standard",
    'cp_tier_premium': "Premium",
    'cp_err_mic': "Microphone access denied.",
    'cp_err_record_start': "Unable to start recording.",
    'cp_err_record': "Recording error.",
    'cp_rec_max': "Maximum duration reached ({0} s)",
    'cp_err_audio_size': "Audio too large (max {0} MB)",
    'cp_err_size': "{0} is too large (max {1} MB)",
    'cp_err_img_fmt': "{0}: unsupported image format",
    'cp_err_vid_fmt': "{0}: unsupported video format",
    'cp_err_small': "File too small or invalid",
    'cp_err_mime': "File type not allowed",
    'cp_err_photo_size': "Photo too large (max {0} MB)",
    'cp_err_empty': "Write something or add media.",
    'cp_err_poll_q': "Enter the poll question.",
    'cp_err_ch': "Fill in the title, description and end date of the challenge.",
    'cp_err_poll_min': "A poll needs at least 2 options.",
    'cp_err_poll_len': "Each option is limited to {0} characters.",
    'cp_err_auth': "Session expired. Please sign in again.",
    'cp_err_publish': "Publishing failed: {0}",
    'cp_err_up_audio': "Audio upload failed: {0}",
    'cp_err_up_image': "Image upload failed: {0}",
    'cp_err_up_video': "Video upload failed: {0}",
    'cp_ok_publish': "Posted successfully!",
    'cp_tab_post': "Post",
    'cp_tab_poll': "Poll",
    'cp_tab_challenge': "Challenge",
    'cp_title_post': "New post",
    'cp_title_poll': "New poll",
    'cp_title_challenge': "New challenge",
    'cp_publish': "Post",
    'cp_bold': "Bold",
    'cp_italic': "Italic",
    'cp_badges': "Badges",
    'cp_badge_urgent': "URGENT",
    'cp_badge_flash': "FLASH",
    'cp_badge_important': "IMPORTANT",
    'cp_badge_info': "INFO",
    'cp_badge_new': "NEW",
    'cp_badge_alert': "ALERT",
    'cp_badge_official': "OFFICIAL",
    'cp_badge_event': "EVENT",
    'cp_badge_promo': "PROMO",
    'cp_badge_reminder': "REMINDER",
    'cp_posts_one': "{0} post",
    'cp_posts_other': "{0} posts",
    'cp_visibility': "Visibility",
    'cp_public': "Public",
    'cp_contacts': "My contacts",
    'cp_contacts_short': "Contacts",
    'cp_hint_post': "What's new? Share with your network… (@ to mention, # for a hashtag)",
    'cp_hint_poll': "Ask your question…",
    'cp_hint_challenge': "Challenge title…",
    'cp_poll_options': "Options",
    'cp_poll_option': "Option {0}",
    'cp_poll_add': "Add an option",
    'cp_poll_multiple': "Allow multiple choices",
    'cp_poll_duration': "Poll duration",
    'cp_poll_week': "1 week",
    'cp_poll_day': "{0} day",
    'cp_poll_days': "{0} days",
    'cp_ch_desc': "Challenge description",
    'cp_ch_desc_hint': "Explain the rules and the goal…",
    'cp_ch_reward': "Reward (optional)",
    'cp_ch_max': "Max participants (optional)",
    'cp_ch_pick': "Pick the end date",
    'cp_ch_end': "Ends: {0} at {1}",
    'cp_ch_countdown': "Ends in {0} day(s)",
    'cp_recording': "Recording… {0}",
    'cp_photos': "Photos",
    'cp_videos': "Videos",
    'cp_camera': "Camera",
    'cp_audio': "Audio",
  },

  // ───────────────────────────── KISWAHILI ─────────────────────────────
  'sw': {
    'common_cancel': "Ghairi",
    'cp_me': "Mimi",
    'cp_unit_mb': "MB",
    'cp_draft_restored': "Rasimu imerejeshwa",
    'cp_draft_title': "Hifadhi rasimu?",
    'cp_draft_body': "Chapisho lako halijatumwa. Je, unataka kuhifadhi rasimu hii?",
    'cp_draft_discard': "Futa",
    'cp_draft_keep': "Hifadhi",
    'cp_upg_title': "Huduma maalum",
    'cp_upg_body': "{0} inapatikana kuanzia mpango wa {1}. Boresha mpango wako ili uitumie.",
    'cp_upg_later': "Baadaye",
    'cp_upg_see': "Tazama mipango",
    'cp_quota_title': "Kikomo kimefikiwa",
    'cp_quota_body': "Umefikia kikomo cha machapisho {0} ya sauti kwa siku. Boresha mpango wako ili kuendelea.",
    'cp_quota_ok': "Sawa",
    'cp_quota_upg': "Boresha",
    'cp_perm_title': "Ruhusa inahitajika",
    'cp_perm_denied': "Ruhusa imekataliwa moja kwa moja. Iwashe kwenye mipangilio ya programu.",
    'cp_perm_open': "Fungua mipangilio",
    'cp_perm_mic': "THIX ID inahitaji maikrofoni ili kurekodi ujumbe wako wa sauti.",
    'cp_perm_cam': "THIX ID inahitaji kamera ili kupiga picha.",
    'cp_feat_format': "Mpangilio wa maandishi",
    'cp_feat_colors': "Rangi za maandishi",
    'cp_feat_photos': "Kuongeza picha zaidi",
    'cp_feat_video': "Kuchapisha video",
    'cp_feat_poll': "Kura za maoni",
    'cp_feat_challenge': "Changamoto",
    'cp_feat_bg': "Mandharinyuma za rangi",
    'cp_tier_standard': "Standard",
    'cp_tier_premium': "Premium",
    'cp_err_mic': "Ufikiaji wa maikrofoni umekataliwa.",
    'cp_err_record_start': "Imeshindikana kuanza kurekodi.",
    'cp_err_record': "Hitilafu wakati wa kurekodi.",
    'cp_rec_max': "Muda wa juu umefikiwa (sekunde {0})",
    'cp_err_audio_size': "Sauti ni kubwa mno (kiwango cha juu {0} MB)",
    'cp_err_size': "{0} ni kubwa mno (kiwango cha juu {1} MB)",
    'cp_err_img_fmt': "{0}: aina ya picha haikubaliki",
    'cp_err_vid_fmt': "{0}: aina ya video haikubaliki",
    'cp_err_small': "Faili ni ndogo mno au si sahihi",
    'cp_err_mime': "Aina ya faili hairuhusiwi",
    'cp_err_photo_size': "Picha ni kubwa mno (kiwango cha juu {0} MB)",
    'cp_err_empty': "Andika kitu au ongeza faili ya media.",
    'cp_err_poll_q': "Andika swali la kura ya maoni.",
    'cp_err_ch': "Jaza kichwa, maelezo na tarehe ya mwisho ya changamoto.",
    'cp_err_poll_min': "Kura ya maoni inahitaji angalau chaguo 2.",
    'cp_err_poll_len': "Kila chaguo lina kikomo cha herufi {0}.",
    'cp_err_auth': "Kipindi kimeisha. Tafadhali ingia tena.",
    'cp_err_publish': "Imeshindikana kuchapisha: {0}",
    'cp_err_up_audio': "Imeshindikana kupakia sauti: {0}",
    'cp_err_up_image': "Imeshindikana kupakia picha: {0}",
    'cp_err_up_video': "Imeshindikana kupakia video: {0}",
    'cp_ok_publish': "Imechapishwa kwa mafanikio!",
    'cp_tab_post': "Chapisho",
    'cp_tab_poll': "Kura",
    'cp_tab_challenge': "Changamoto",
    'cp_title_post': "Chapisho jipya",
    'cp_title_poll': "Kura mpya ya maoni",
    'cp_title_challenge': "Changamoto mpya",
    'cp_publish': "Chapisha",
    'cp_bold': "Herufi nzito",
    'cp_italic': "Herufi pinde",
    'cp_badges': "Beji",
    'cp_badge_urgent': "DHARURA",
    'cp_badge_flash': "FLASH",
    'cp_badge_important': "MUHIMU",
    'cp_badge_info': "TAARIFA",
    'cp_badge_new': "MPYA",
    'cp_badge_alert': "TAHADHARI",
    'cp_badge_official': "RASMI",
    'cp_badge_event': "TUKIO",
    'cp_badge_promo': "OFA",
    'cp_badge_reminder': "KUMBUSHO",
    'cp_posts_one': "Chapisho {0}",
    'cp_posts_other': "Machapisho {0}",
    'cp_visibility': "Mwonekano",
    'cp_public': "Hadharani",
    'cp_contacts': "Watu wangu",
    'cp_contacts_short': "Watu wangu",
    'cp_hint_post': "Habari gani? Shiriki na mtandao wako… (@ kumtaja mtu, # kwa hashtag)",
    'cp_hint_poll': "Uliza swali lako…",
    'cp_hint_challenge': "Kichwa cha changamoto…",
    'cp_poll_options': "Chaguo",
    'cp_poll_option': "Chaguo {0}",
    'cp_poll_add': "Ongeza chaguo",
    'cp_poll_multiple': "Ruhusu chaguo nyingi",
    'cp_poll_duration': "Muda wa kura",
    'cp_poll_week': "Wiki 1",
    'cp_poll_day': "Siku {0}",
    'cp_poll_days': "Siku {0}",
    'cp_ch_desc': "Maelezo ya changamoto",
    'cp_ch_desc_hint': "Eleza sheria na lengo…",
    'cp_ch_reward': "Zawadi (si lazima)",
    'cp_ch_max': "Idadi ya juu ya washiriki (si lazima)",
    'cp_ch_pick': "Chagua tarehe ya mwisho",
    'cp_ch_end': "Mwisho: {0} saa {1}",
    'cp_ch_countdown': "Inaisha baada ya siku {0}",
    'cp_recording': "Inarekodi… {0}",
    'cp_photos': "Picha",
    'cp_videos': "Video",
    'cp_camera': "Kamera",
    'cp_audio': "Sauti",
  },

  // ───────────────────────────── العربية ─────────────────────────────
  'ar': {
    'common_cancel': "إلغاء",
    'cp_me': "أنا",
    'cp_unit_mb': "م.ب",
    'cp_draft_restored': "تمت استعادة المسودة",
    'cp_draft_title': "حفظ المسودة؟",
    'cp_draft_body': "لم يتم نشر منشورك. هل تريد الاحتفاظ بهذه المسودة؟",
    'cp_draft_discard': "حذف",
    'cp_draft_keep': "احتفاظ",
    'cp_upg_title': "ميزة حصرية",
    'cp_upg_body': "{0} متاحة ابتداءً من باقة {1}. قم بترقية باقتك للاستفادة منها.",
    'cp_upg_later': "لاحقًا",
    'cp_upg_see': "عرض الباقات",
    'cp_quota_title': "تم بلوغ الحد الأقصى",
    'cp_quota_body': "لقد بلغت الحد الأقصى وهو {0} منشورات صوتية في اليوم. قم بترقية باقتك للمتابعة.",
    'cp_quota_ok': "موافق",
    'cp_quota_upg': "ترقية",
    'cp_perm_title': "إذن مطلوب",
    'cp_perm_denied': "تم رفض الإذن نهائيًا. فعّله من إعدادات التطبيق.",
    'cp_perm_open': "فتح الإعدادات",
    'cp_perm_mic': "يحتاج THIX ID إلى الميكروفون لتسجيل رسالتك الصوتية.",
    'cp_perm_cam': "يحتاج THIX ID إلى الكاميرا لالتقاط صورة.",
    'cp_feat_format': "تنسيق النص",
    'cp_feat_colors': "ألوان النص",
    'cp_feat_photos': "إضافة المزيد من الصور",
    'cp_feat_video': "نشر الفيديو",
    'cp_feat_poll': "الاستطلاعات",
    'cp_feat_challenge': "التحديات",
    'cp_feat_bg': "الخلفيات الملونة",
    'cp_tier_standard': "ستاندرد",
    'cp_tier_premium': "بريميوم",
    'cp_err_mic': "تم رفض الوصول إلى الميكروفون.",
    'cp_err_record_start': "تعذر بدء التسجيل.",
    'cp_err_record': "حدث خطأ أثناء التسجيل.",
    'cp_rec_max': "تم بلوغ المدة القصوى ({0} ثانية)",
    'cp_err_audio_size': "حجم الصوت كبير جدًا (الحد الأقصى {0} م.ب)",
    'cp_err_size': "{0} كبير جدًا (الحد الأقصى {1} م.ب)",
    'cp_err_img_fmt': "{0}: صيغة الصورة غير مدعومة",
    'cp_err_vid_fmt': "{0}: صيغة الفيديو غير مدعومة",
    'cp_err_small': "الملف صغير جدًا أو غير صالح",
    'cp_err_mime': "نوع الملف غير مسموح به",
    'cp_err_photo_size': "حجم الصورة كبير جدًا (الحد الأقصى {0} م.ب)",
    'cp_err_empty': "اكتب شيئًا أو أضف وسائط.",
    'cp_err_poll_q': "أدخل سؤال الاستطلاع.",
    'cp_err_ch': "أدخل عنوان التحدي ووصفه وتاريخ انتهائه.",
    'cp_err_poll_min': "يتطلب الاستطلاع خيارين على الأقل.",
    'cp_err_poll_len': "كل خيار محدود بـ {0} حرفًا.",
    'cp_err_auth': "انتهت الجلسة. يرجى تسجيل الدخول مرة أخرى.",
    'cp_err_publish': "فشل النشر: {0}",
    'cp_err_up_audio': "فشل رفع الصوت: {0}",
    'cp_err_up_image': "فشل رفع الصورة: {0}",
    'cp_err_up_video': "فشل رفع الفيديو: {0}",
    'cp_ok_publish': "تم النشر بنجاح!",
    'cp_tab_post': "منشور",
    'cp_tab_poll': "استطلاع",
    'cp_tab_challenge': "تحدٍّ",
    'cp_title_post': "منشور جديد",
    'cp_title_poll': "استطلاع جديد",
    'cp_title_challenge': "تحدٍّ جديد",
    'cp_publish': "نشر",
    'cp_bold': "عريض",
    'cp_italic': "مائل",
    'cp_badges': "الشارات",
    'cp_badge_urgent': "عاجل",
    'cp_badge_flash': "فلاش",
    'cp_badge_important': "مهم",
    'cp_badge_info': "معلومة",
    'cp_badge_new': "جديد",
    'cp_badge_alert': "تنبيه",
    'cp_badge_official': "رسمي",
    'cp_badge_event': "حدث",
    'cp_badge_promo': "عرض",
    'cp_badge_reminder': "تذكير",
    'cp_posts_one': "{0} منشور",
    'cp_posts_other': "{0} منشورات",
    'cp_visibility': "الظهور",
    'cp_public': "عام",
    'cp_contacts': "جهات اتصالي",
    'cp_contacts_short': "جهات الاتصال",
    'cp_hint_post': "ما الجديد؟ شارك مع شبكتك… (@ للإشارة، # للوسم)",
    'cp_hint_poll': "اطرح سؤالك…",
    'cp_hint_challenge': "عنوان التحدي…",
    'cp_poll_options': "الخيارات",
    'cp_poll_option': "الخيار {0}",
    'cp_poll_add': "إضافة خيار",
    'cp_poll_multiple': "السماح بعدة اختيارات",
    'cp_poll_duration': "مدة الاستطلاع",
    'cp_poll_week': "أسبوع واحد",
    'cp_poll_day': "{0} يوم",
    'cp_poll_days': "{0} أيام",
    'cp_ch_desc': "وصف التحدي",
    'cp_ch_desc_hint': "اشرح القواعد والهدف…",
    'cp_ch_reward': "المكافأة (اختياري)",
    'cp_ch_max': "الحد الأقصى للمشاركين (اختياري)",
    'cp_ch_pick': "اختر تاريخ الانتهاء",
    'cp_ch_end': "ينتهي: {0} عند {1}",
    'cp_ch_countdown': "ينتهي بعد {0} يوم",
    'cp_recording': "جارٍ التسجيل… {0}",
    'cp_photos': "الصور",
    'cp_videos': "الفيديو",
    'cp_camera': "الكاميرا",
    'cp_audio': "الصوت",
  },
};

// ============================================================================
// VALIDATIONS CENTRALISÉES
// ============================================================================
class _PostValidators {
  _PostValidators._();

  /// ✅ CORRECTIF PARAGRAPHES : conserve \n, normalise \n\n
  static String sanitizeText(String? input, {int maxLength = 5000}) {
    if (input == null || input.trim().isEmpty) return '';
    final document = html_parser.parse(input);
    var sanitized = document.body?.text ?? input;
    sanitized = sanitized
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x09\x0B-\x1F\x7F]'), '')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    return sanitized.length > maxLength ? sanitized.substring(0, maxLength) : sanitized;
  }

  static bool validateFileSize(int bytes, {int maxSizeMB = 50}) =>
      bytes <= maxSizeMB * 1024 * 1024;

  static bool validateFileExtension(String filename, Set<String> allowed) {
    final ext = filename.split('.').last.toLowerCase();
    return allowed.contains(ext);
  }

  static String? validateMime(Uint8List bytes) {
    if (bytes.length < 12) return 'cp_err_small';
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return null;
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return null;
    if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) return null;
    if (bytes.length >= 8 && bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) return null;
    if (bytes[0] == 0xFF && bytes[1] == 0xFB) return null;
    return 'cp_err_mime';
  }

  static List<String> extractHashtags(String text) {
    final matches = RegExp(r'#([A-Za-z0-9_]{2,30})').allMatches(text);
    final tags = <String>{};
    for (final m in matches) {
      tags.add(m.group(1)!.toLowerCase());
    }
    return tags.toList();
  }
}

// ============================================================================
// COMPRESSION
// ============================================================================
Future<Uint8List> _compressImageBytes(Uint8List bytes) async {
  if (kIsWeb) return bytes;
  try {
    return await compute((Uint8List input) async {
      return await FlutterImageCompress.compressWithList(input, minHeight: 1080, minWidth: 1080, quality: 85);
    }, bytes);
  } catch (e) {
    debugPrint('[Compression] Error: $e');
    return bytes;
  }
}

class _MediaItem {
  final Uint8List bytes;
  final String name;
  final bool isVideo;
  const _MediaItem(this.bytes, this.name, {this.isVideo = false});
}

// ============================================================================
// 🏷️ BADGES SPÉCIAUX PREMIUM (10)
// ============================================================================
class _PostBadge {
  final String key;
  final String labelKey;
  final IconData icon;
  final Color color;
  final bool pulse;
  const _PostBadge(this.key, this.labelKey, this.icon, this.color, {this.pulse = false});
}

const List<_PostBadge> kPostBadges = [
  _PostBadge('urgent', 'cp_badge_urgent', Icons.priority_high_rounded, Color(0xFFE53935), pulse: true),
  _PostBadge('flash', 'cp_badge_flash', Icons.bolt_rounded, Color(0xFFF57C00)),
  _PostBadge('important', 'cp_badge_important', Icons.error_outline_rounded, Color(0xFFF9A825)),
  _PostBadge('info', 'cp_badge_info', Icons.info_outline_rounded, Color(0xFF1E88E5)),
  _PostBadge('new', 'cp_badge_new', Icons.fiber_new_rounded, Color(0xFF43A047)),
  _PostBadge('alert', 'cp_badge_alert', Icons.warning_amber_rounded, Color(0xFFD84315)),
  _PostBadge('official', 'cp_badge_official', Icons.verified_rounded, ThixPolicy.gold),
  _PostBadge('event', 'cp_badge_event', Icons.celebration_rounded, Color(0xFF8E24AA)),
  _PostBadge('promo', 'cp_badge_promo', Icons.local_offer_rounded, Color(0xFF00897B)),
  _PostBadge('reminder', 'cp_badge_reminder', Icons.alarm_rounded, Color(0xFF3949AB)),
];

// ============================================================================
// SUGGESTIONS : TOKEN ACTIF (@ ou #)
// ============================================================================
enum _TokenType { mention, hashtag }

class _ActiveToken {
  final _TokenType type;
  final String query;
  final int start;
  final int end;
  const _ActiveToken({required this.type, required this.query, required this.start, required this.end});
}

class _HashtagSuggestion {
  final String tag;
  final int count;
  const _HashtagSuggestion(this.tag, this.count);
}

// ============================================================================
// POINT D'ENTRÉE
// ============================================================================
class CreatePostDialog {
  static Future<NetworkPost?> show(
    BuildContext context, {
    String? communityId,
    VoidCallback? onPostCreated,
  }) {
    return Navigator.of(context).push<NetworkPost>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CreatePostPage(
          communityId: communityId,
          onPostCreated: onPostCreated,
        ),
      ),
    );
  }
}

// ============================================================================
// PAGE PLEIN ÉCRAN
// ============================================================================
class CreatePostPage extends ConsumerStatefulWidget {
  final String? communityId;
  final VoidCallback? onPostCreated;
  const CreatePostPage({super.key, this.communityId, this.onPostCreated});

  @override
  ConsumerState<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends ConsumerState<CreatePostPage> with TickerProviderStateMixin {
  final _contentController = TextEditingController();
  final _contentFocusNode = FocusNode();

  final List<TextEditingController> _pollOptionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  int _pollDurationDays = 1;
  bool _pollMultiple = false;

  final _challengeDescController = TextEditingController();
  final _challengeRewardController = TextEditingController();
  final _challengeMaxController = TextEditingController();
  DateTime? _challengeEndDate;

  int _postTypeMode = 0;

  Color _selectedBgColor = Colors.transparent;
  final List<Color> _bgColors = const [
    Colors.transparent,
    Color(0xFF00A4FF),
    ThixPolicy.danger,
    ThixPolicy.success,
    ThixPolicy.gold,
    Color(0xFF8B5CF6),
    ThixPolicy.textMain,
  ];

  final List<_MediaItem> _images = [];
  final List<_MediaItem> _videos = [];
  bool _isUploading = false;
  String? _errorMessage;

  final AudioRecorder _audioRecorder = AudioRecorder();
  Timer? _recordTimer;
  int _recordDuration = 0;
  bool _isRecording = false;
  Uint8List? _audioBytes;
  String? _localAudioPath;

  _ActiveToken? _token;
  List<Map<String, dynamic>> _mentionSuggestions = [];
  List<_HashtagSuggestion> _hashtagSuggestions = [];
  bool _showSuggestions = false;
  bool _loadingSuggestions = false;
  Timer? _suggestDebounce;
  final Set<String> _mentionedIds = {};

  /// ✅ Suggestions @ par défaut (affichées dès que l'on tape « @ »)
  List<Map<String, dynamic>>? _defaultMentions;

  String? _authorName;
  String? _authorAvatar;
  bool _isPublic = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  final List<Color> _textColors = const [
    ThixPolicy.textMain,
    ThixPolicy.primary,
    ThixPolicy.gold,
    ThixPolicy.danger,
    ThixPolicy.success,
  ];

  static const int _maxCharsForBgColor = 150;
  int _previousTextLength = 0;

  _PostBadge? _selectedBadge;

  static String? _draftText;
  static String? _draftBadgeKey;

  static const List<String> _quickEmojis = ['😀','😂','🙏','👍','❤️','🔥','😊','😢','😡','👏','💪','🤝','✅','⚠️','📌','🎉'];

  bool _isLoadingLimits = true;
  String _userTier = 'gratuit';
  int _audioPostsToday = 0;

  // ──────────────────────────────────────────────────────────────────────
  // 🌍 LOCALISATION : langue système → FR/EN/SW/AR (repli FR → AppLocalizations)
  // ──────────────────────────────────────────────────────────────────────
  AppLocalizations get _loc => AppLocalizations.of(context);

  String get _lang {
    final code = Localizations.localeOf(context).languageCode.toLowerCase();
    return _kCp.containsKey(code) ? code : 'fr';
  }

  String _t(String key, {List<String> args = const []}) {
    var s = _kCp[_lang]?[key] ?? _kCp['fr']?[key];
    if (s == null) {
      try {
        return _loc.t(key, args: args);
      } catch (_) {
        return key;
      }
    }
    for (var i = 0; i < args.length; i++) {
      s = s!.replaceAll('{$i}', args[i]);
    }
    return s!;
  }

  String _plural(String key, int count) {
    final suffix = (_lang == 'en' || _lang == 'sw') ? (count == 1 ? 'one' : 'other') : (count <= 1 ? 'one' : 'other');
    return _t('${key}_$suffix', args: ['$count']);
  }

  String get _displayName => _authorName ?? _t('cp_me');

  bool get _isFree => _userTier == 'gratuit' || _userTier == 'none';
  bool get _isStandard => _userTier == 'standard';
  bool get _isPremium => _userTier == 'premium';
  bool get _isEnterprise => _userTier == 'entreprise' || _userTier == 'enterprise';
  bool get _isOfficial => _userTier == 'officiel' || _userTier == 'official';

  bool get _canFormatText => !_isFree;
  bool get _canPostVideo => !_isFree;
  bool get _canCreatePoll => _isPremium || _isEnterprise || _isOfficial;
  bool get _canCreateChallenge => _isPremium || _isEnterprise || _isOfficial;
  bool get _hasWidePollOptions => _isEnterprise || _isOfficial;

  int get _maxTextLength => _isFree ? 280 : 5000;
  int get _maxPhotos => _isFree ? 1 : (_isStandard ? 4 : 10);
  int get _maxAudioDuration => _isFree ? 30 : (_isStandard ? 60 : 120);
  bool get _hasAudioDailyQuota => _isFree;
  static const int _freeAudioDailyLimit = 3;

  static const int _maxImageSizeMB = 10;

  /// ✅ Vidéos : 50 Mo max, tous formats acceptés (plus de liste d'extensions)
  static const int _maxVideoSizeMB = 50;
  static const int _maxAudioSizeMB = 20;
  static const Set<String> _allowedImageExts = {'jpg', 'jpeg', 'png', 'webp', 'heic'};
  static const Set<String> _allowedAudioExts = {'m4a', 'mp3', 'wav', 'aac'};
  static const int _maxPollOptionLength = 100;
  static const Duration _uploadTimeout = Duration(seconds: 30);

  /// ✅ 50 Mo en 30 s était trop court → 5 minutes pour les vidéos
  static const Duration _videoUploadTimeout = Duration(minutes: 5);
  static const Duration _suggestTimeout = Duration(seconds: 8);

  @override
  void initState() {
    super.initState();
    _loadUserLimits();
    _contentController.addListener(_onContentChanged);
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 240));
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeOut);
    _animationController.forward();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 850));
    _pulseAnim = Tween<double>(begin: 1.0, end: 0.90)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_pulseController);
    _pulseController.repeat(reverse: true);

    if (_draftText != null && _draftText!.trim().isNotEmpty) {
      _contentController.text = _draftText!;
      _previousTextLength = _contentController.text.length;
      for (final b in kPostBadges) {
        if (b.key == _draftBadgeKey) _selectedBadge = b;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('cp_draft_restored'))));
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _contentFocusNode.requestFocus();
    });

    // Précharge les suggestions @ pour qu'elles apparaissent instantanément
    _loadDefaultMentions();
  }

  Future<void> _loadUserLimits() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('certification_tier, display_name, full_name, avatar_url')
          .eq('id', uid)
          .maybeSingle();

      final tier = (profile?['certification_tier']?.toString().toLowerCase()) ?? 'gratuit';
      final name = profile?['display_name']?.toString() ?? profile?['full_name']?.toString();
      final avatar = profile?['avatar_url']?.toString();

      final startOfDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).toIso8601String();
      final audioCountRes = await Supabase.instance.client
          .from('posts')
          .select('id')
          .eq('user_id', uid)
          .eq('post_type', 'audio')
          .gte('created_at', startOfDay);

      if (mounted) {
        setState(() {
          _userTier = tier;
          _audioPostsToday = (audioCountRes as List).length;
          if (name != null && name.isNotEmpty) _authorName = name;
          _authorAvatar = avatar;
          _isLoadingLimits = false;
        });
      }
    } catch (e) {
      debugPrint('[LoadLimits] Error: $e');
      if (mounted) setState(() => _isLoadingLimits = false);
    }
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _suggestDebounce?.cancel();
    _audioRecorder.dispose();
    _contentController.removeListener(_onContentChanged);
    _contentController.dispose();
    _contentFocusNode.dispose();
    _challengeDescController.dispose();
    _challengeRewardController.dispose();
    _challengeMaxController.dispose();
    for (final c in _pollOptionControllers) {
      c.dispose();
    }
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  bool get _hasBgColor => _selectedBgColor != Colors.transparent;
  bool get _canHaveBgColor => _postTypeMode == 0 &&
      _images.isEmpty &&
      _videos.isEmpty &&
      _audioBytes == null &&
      _contentController.text.length <= _maxCharsForBgColor;

  String _colorToHex(Color c) {
    final v = c.toARGB32();
    return '#${v.toRadixString(16).substring(2).toUpperCase()}';
  }

  void _clearDraft() {
    _draftText = null;
    _draftBadgeKey = null;
  }

  Future<bool> _attemptClose() async {
    if (_isUploading || _isRecording) return false;
    final hasContent = _contentController.text.trim().isNotEmpty ||
        _images.isNotEmpty || _videos.isNotEmpty || _audioBytes != null;
    if (!hasContent) {
      _clearDraft();
      return true;
    }
    _draftText = _contentController.text;
    _draftBadgeKey = _selectedBadge?.key;
    final keep = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Text(_t('cp_draft_title'), style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold)),
        content: Text(_t('cp_draft_body'), style: ThixPolicy.bodyStyle.copyWith(height: 1.4)),
        actions: [
          TextButton(
            onPressed: () {
              _clearDraft();
              Navigator.pop(ctx, true);
            },
            child: Text(_t('cp_draft_discard'), style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.danger)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm))),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t('cp_draft_keep'), style: ThixPolicy.labelStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold)),
          ),
        ],
      ),
    );
    return keep == true;
  }

  void _onContentChanged() {
    final text = _contentController.text;
    final currentLength = text.length;
    _draftText = text;

    if (_isFree && currentLength > 280) {
      _contentController.text = text.substring(0, 280);
      _contentController.selection = TextSelection.collapsed(offset: 280);
      HapticFeedback.lightImpact();
      return;
    }

    if ((_previousTextLength <= _maxCharsForBgColor && currentLength > _maxCharsForBgColor) ||
        (_previousTextLength > _maxCharsForBgColor && currentLength <= _maxCharsForBgColor)) {
      setState(() {
        if (currentLength > _maxCharsForBgColor && _hasBgColor) _selectedBgColor = Colors.transparent;
      });
    }
    _previousTextLength = currentLength;

    _updateToken();
    if (mounted) setState(() {});
  }

  /// ✅ Détecte @ / # (lettres accentuées incluses) juste avant le curseur.
  /// Dès que l'on tape « @ » seul, le token mention a une requête vide
  /// → les suggestions par défaut s'affichent immédiatement.
  void _updateToken() {
    final text = _contentController.text;
    final sel = _contentController.selection;
    final cursor = sel.isValid ? math.min(math.max(sel.baseOffset, 0), text.length) : text.length;
    final before = text.substring(0, cursor);

    final match = RegExp(r'(?<![\p{L}\p{N}_])([@#])([\p{L}\p{N}_\.]{0,30})$', unicode: true).firstMatch(before);
    if (match == null) {
      _closeSuggestions();
      return;
    }

    final raw = match.group(0)!;
    final type = match.group(1) == '@' ? _TokenType.mention : _TokenType.hashtag;
    final query = match.group(2) ?? '';
    final start = cursor - raw.length;

    _token = _ActiveToken(type: type, query: query, start: start, end: cursor);
    _fetchSuggestionsDebounced();
  }

  void _closeSuggestions() {
    if (_showSuggestions || _loadingSuggestions) {
      _showSuggestions = false;
      _loadingSuggestions = false;
      _token = null;
    }
  }

  void _fetchSuggestionsDebounced() {
    _suggestDebounce?.cancel();
    final token = _token;
    if (token == null) return;

    setState(() => _loadingSuggestions = true);

    // « @ » seul → affichage immédiat (aucun délai)
    final instant = token.type == _TokenType.mention && token.query.isEmpty;

    _suggestDebounce = Timer(instant ? Duration.zero : const Duration(milliseconds: 250), () async {
      if (!mounted || _token != token) return;
      try {
        if (token.type == _TokenType.mention) {
          final List<Map<String, dynamic>> users = token.query.isEmpty
              ? await _loadDefaultMentions()
              : await ref.read(networkServiceProvider).searchUsers(token.query).timeout(_suggestTimeout);
          final myId = Supabase.instance.client.auth.currentUser?.id;
          final filtered = users.where((u) => u['id']?.toString() != myId).toList();
          if (!mounted || _token != token) return;
          setState(() {
            _mentionSuggestions = filtered.take(8).toList();
            _hashtagSuggestions = [];
            _showSuggestions = _mentionSuggestions.isNotEmpty;
            _loadingSuggestions = false;
          });
        } else {
          final tags = await _searchHashtags(token.query);
          if (!mounted || _token != token) return;
          setState(() {
            _hashtagSuggestions = tags.take(6).toList();
            _mentionSuggestions = [];
            _showSuggestions = _hashtagSuggestions.isNotEmpty;
            _loadingSuggestions = false;
          });
        }
      } catch (e) {
        debugPrint('[Suggestions] Error: $e');
        if (mounted) setState(() => _loadingSuggestions = false);
      }
    });
  }

  /// ✅ Personnes proposées quand on tape « @ » : mes connexions d'abord,
  /// complétées par d'autres profils si besoin. Mis en cache.
  Future<List<Map<String, dynamic>>> _loadDefaultMentions() async {
    if (_defaultMentions != null) return _defaultMentions!;
    final db = Supabase.instance.client;
    final myId = db.auth.currentUser?.id;
    const cols = 'id, display_name, full_name, avatar_url, thix_chat';
    final list = <Map<String, dynamic>>[];
    final seen = <String?>{};

    try {
      final ids = await ref.read(networkServiceProvider).getMyConnectionIds().timeout(_suggestTimeout);
      final idList = ids.where((i) => i != myId).take(30).toList();
      if (idList.isNotEmpty) {
        final res = await db.from('profiles').select(cols).inFilter('id', idList).limit(8).timeout(_suggestTimeout);
        for (final row in res as List) {
          final m = Map<String, dynamic>.from(row as Map);
          if (seen.add(m['id']?.toString())) list.add(m);
        }
      }
    } catch (e) {
      debugPrint('[Mentions] connections error: $e');
    }

    if (list.length < 8) {
      try {
        var q = db.from('profiles').select(cols);
        if (myId != null) q = q.neq('id', myId);
        final res = await q.limit(8).timeout(_suggestTimeout);
        for (final row in res as List) {
          final m = Map<String, dynamic>.from(row as Map);
          if (seen.add(m['id']?.toString())) list.add(m);
          if (list.length >= 8) break;
        }
      } catch (e) {
        debugPrint('[Mentions] profiles error: $e');
      }
    }

    if (list.isNotEmpty) _defaultMentions = list;
    return list;
  }

  Future<List<_HashtagSuggestion>> _searchHashtags(String q) async {
    final db = Supabase.instance.client;
    final results = <String, int>{};

    try {
      final res = await db.from('post_hashtags').select('*').limit(200).timeout(_suggestTimeout);
      for (final row in res as List) {
        final m = Map<String, dynamic>.from(row as Map);
        final tag = (m['tag'] ?? m['hashtag'] ?? m['name'])?.toString().toLowerCase();
        if (tag == null) continue;
        if (q.isEmpty || tag.startsWith(q.toLowerCase())) {
          final rawCount = m['count'] ?? m['posts_count'] ?? m['usage_count'];
          final int count = (rawCount is num)
              ? rawCount.toInt()
              : (int.tryParse(rawCount?.toString() ?? '') ?? 1);
          results[tag] = (results[tag] ?? 0) + count;
        }
      }
      if (results.isNotEmpty) {
        final list = results.entries.map((e) => _HashtagSuggestion(e.key, e.value)).toList()
          ..sort((a, b) => b.count.compareTo(a.count));
        return list;
      }
    } catch (e) {
      debugPrint('[Hashtags] table error: $e');
    }

    try {
      final res = await db
          .from('posts')
          .select('content')
          .order('created_at', ascending: false)
          .limit(150)
          .timeout(_suggestTimeout);
      final pattern = RegExp(r'#([A-Za-z0-9_]{2,30})');
      for (final row in res as List) {
        final content = (row as Map)['content']?.toString() ?? '';
        for (final m in pattern.allMatches(content)) {
          final tag = m.group(1)!.toLowerCase();
          if (q.isEmpty || tag.startsWith(q.toLowerCase())) {
            results[tag] = (results[tag] ?? 0) + 1;
          }
        }
      }
    } catch (e) {
      debugPrint('[Hashtags] fallback error: $e');
    }

    final list = results.entries.map((e) => _HashtagSuggestion(e.key, e.value)).toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    return list;
  }

  /// Handle de mention sans espaces (ex. « landry_yumba »), compatible avec
  /// la détection @mention du PostCard.
  String _handleOf(Map<String, dynamic> u) {
    final raw = (u['thix_chat'] ?? u['username'] ?? '').toString().replaceAll('@', '').trim();
    final base = raw.isNotEmpty ? raw : (u['display_name'] ?? u['full_name'] ?? '').toString().trim();
    return base
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^\p{L}\p{N}_]', unicode: true), '');
  }

  Future<void> _applyMention(Map<String, dynamic> user) async {
    final token = _token;
    if (token == null) return;

    final id = user['id']?.toString();
    if (id != null) _mentionedIds.add(id);

    var data = user;
    if ((user['thix_chat'] ?? '').toString().isEmpty && id != null) {
      try {
        final r = await Supabase.instance.client
            .from('profiles')
            .select('thix_chat')
            .eq('id', id)
            .maybeSingle()
            .timeout(const Duration(seconds: 3));
        if (r != null) data = {...user, 'thix_chat': r['thix_chat']};
      } catch (_) {}
    }

    if (!mounted || _token != token) return;
    final handle = _handleOf(data);
    if (handle.isEmpty) return;

    _replaceToken('@$handle ');
    HapticFeedback.selectionClick();
  }

  void _applyHashtag(_HashtagSuggestion tag) {
    final replacement = '#${tag.tag} ';
    _replaceToken(replacement);
    HapticFeedback.selectionClick();
  }

  void _replaceToken(String replacement) {
    final token = _token;
    if (token == null) return;
    final text = _contentController.text;
    final newText = text.replaceRange(token.start, token.end, replacement);
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: token.start + replacement.length),
    );
    setState(() {
      _showSuggestions = false;
      _loadingSuggestions = false;
      _token = null;
      _mentionSuggestions = [];
      _hashtagSuggestions = [];
    });
    _contentFocusNode.requestFocus();
  }

  void _insertEmoji(String emoji) {
    final text = _contentController.text;
    final sel = _contentController.selection;
    final start = sel.isValid ? sel.start.clamp(0, text.length) : text.length;
    final end = sel.isValid ? sel.end.clamp(0, text.length) : text.length;
    final newText = text.replaceRange(start, end, emoji);
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
    _contentFocusNode.requestFocus();
  }

  void _showUpgradeDialog(String featureName, String requiredTier) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Row(
          children: [
            const Icon(Icons.workspace_premium_rounded, color: ThixPolicy.gold, size: 28),
            const SizedBox(width: 8),
            Flexible(child: Text(_t('cp_upg_title'), style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold))),
          ],
        ),
        content: Text(
          _t('cp_upg_body', args: [featureName, requiredTier]),
          style: ThixPolicy.bodyStyle.copyWith(height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_t('cp_upg_later'), style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.gold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm))),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CertificationTiersPage()));
            },
            child: Text(_t('cp_upg_see'), style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textMain, fontWeight: ThixPolicy.bold)),
          ),
        ],
      ),
    );
  }

  void _showAudioLimitDialog() {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Text(_t('cp_quota_title'), style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.danger, fontWeight: ThixPolicy.bold)),
        content: Text(
          _t('cp_quota_body', args: ['$_freeAudioDailyLimit']),
          style: ThixPolicy.bodyStyle.copyWith(height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_t('cp_quota_ok'), style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.gold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm))),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CertificationTiersPage()));
            },
            child: Text(_t('cp_quota_upg'), style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textMain, fontWeight: ThixPolicy.bold)),
          ),
        ],
      ),
    );
  }

  Future<bool> _checkPermissionWithDisclosure(Permission permission, String explanation) async {
    if (kIsWeb) return true;
    var status = await permission.status;
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      if (!mounted) return false;
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: ThixPolicy.card,
          title: Text(_t('cp_perm_title'), style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold)),
          content: Text(_t('cp_perm_denied'), style: ThixPolicy.bodyStyle.copyWith(height: 1.4)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_t('common_cancel'))),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_t('cp_perm_open'))),
          ],
        ),
      );
      if (openSettings == true) await openAppSettings();
      return false;
    }

    if (!mounted) return false;

    bool? userAgreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        surfaceTintColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Row(
          children: [
            const Icon(Icons.privacy_tip_outlined, color: ThixPolicy.textMain, size: 28),
            const SizedBox(width: 10),
            Flexible(child: Text(_t('cp_perm_title'), style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold))),
          ],
        ),
        content: Text(explanation, style: ThixPolicy.bodyStyle.copyWith(height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: Text(_t('common_cancel'), style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.card,
              foregroundColor: ThixPolicy.textMain,
              elevation: 0,
              side: const BorderSide(color: ThixPolicy.textMain, width: 1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(_t('cp_quota_ok'), style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold)),
          ),
        ],
      ),
    );

    if (userAgreed != true) return false;
    var newStatus = await permission.request();
    return newStatus.isGranted;
  }

  void _wrapSelection(String prefix, String suffix) {
    if (!_canFormatText) {
      _showUpgradeDialog(_t('cp_feat_format'), _t('cp_tier_standard'));
      return;
    }
    final text = _contentController.text;
    final sel = _contentController.selection;
    if (!sel.isValid) {
      final newText = '$text$prefix$suffix';
      _contentController.value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: newText.length - suffix.length));
    } else {
      final selected = text.substring(sel.start, sel.end);
      final newText = text.replaceRange(sel.start, sel.end, '$prefix$selected$suffix');
      _contentController.value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: sel.start + prefix.length + selected.length + suffix.length));
    }
    _contentFocusNode.requestFocus();
  }

  void _applyBold() => _wrapSelection('**', '**');
  void _applyItalic() => _wrapSelection('*', '*');
  void _applyColor(Color color) {
    if (!_canFormatText) {
      _showUpgradeDialog(_t('cp_feat_colors'), _t('cp_tier_standard'));
      return;
    }
    _wrapSelection('{c:${_colorToHex(color)}}', '{c}');
  }

  void _resetBgColorIfMediaAdded() {
    if (_hasBgColor) setState(() => _selectedBgColor = Colors.transparent);
  }

  Future<void> _startRecording() async {
    if (_isUploading || _isRecording) return;
    if (_hasAudioDailyQuota && _audioPostsToday >= _freeAudioDailyLimit) {
      _showAudioLimitDialog();
      return;
    }

    final hasPerm = await _checkPermissionWithDisclosure(
      Permission.microphone,
      _t('cp_perm_mic'),
    );
    if (!hasPerm) {
      if (mounted) setState(() => _errorMessage = _t('cp_err_mic'));
      return;
    }

    try {
      String recordPath = kIsWeb
          ? 'post_audio_${DateTime.now().millisecondsSinceEpoch}.m4a'
          : p.join((await getTemporaryDirectory()).path, 'post_audio_${DateTime.now().millisecondsSinceEpoch}.m4a');
      await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000), path: recordPath);

      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _recordDuration = 0;
        _audioBytes = null;
        _localAudioPath = null;
        _resetBgColorIfMediaAdded();
      });

      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => _recordDuration++);
        if (_recordDuration >= _maxAudioDuration) {
          _stopRecording();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('cp_rec_max', args: ['$_maxAudioDuration']))));
        }
      });
    } catch (e) {
      debugPrint('[Record] Start error: $e');
      if (mounted) setState(() => _errorMessage = _t('cp_err_record_start'));
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    try {
      final path = await _audioRecorder.stop();
      if (mounted) setState(() => _isRecording = false);
      if (path != null) {
        final bytes = await XFile(path).readAsBytes();
        if (!_PostValidators.validateFileSize(bytes.length, maxSizeMB: _maxAudioSizeMB)) {
          if (mounted) setState(() => _errorMessage = _t('cp_err_audio_size', args: ['$_maxAudioSizeMB']));
          return;
        }
        if (mounted) {
          setState(() {
            _audioBytes = bytes;
            _localAudioPath = path;
          });
        }
      }
    } catch (e) {
      debugPrint('[Record] Stop error: $e');
      if (mounted) setState(() => _errorMessage = _t('cp_err_record'));
    }
  }

  Future<void> _pickImages() async {
    if (_isUploading) return;
    if (_images.length >= _maxPhotos) {
      _showUpgradeDialog(_t('cp_feat_photos'), _isFree ? _t('cp_tier_standard') : _t('cp_tier_premium'));
      return;
    }
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true, withData: true);
    if (result != null && mounted) {
      setState(() {
        _resetBgColorIfMediaAdded();
        for (final f in result.files) {
          if (_images.length >= _maxPhotos) break;
          if (f.bytes == null) continue;
          if (!_PostValidators.validateFileSize(f.bytes!.length, maxSizeMB: _maxImageSizeMB)) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('cp_err_size', args: [f.name, '$_maxImageSizeMB'])), backgroundColor: ThixPolicy.danger));
            continue;
          }
          if (!_PostValidators.validateFileExtension(f.name, _allowedImageExts)) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('cp_err_img_fmt', args: [f.name])), backgroundColor: ThixPolicy.danger));
            continue;
          }
          final mimeKey = _PostValidators.validateMime(f.bytes!);
          if (mimeKey != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${f.name}: ${_t(mimeKey)}'), backgroundColor: ThixPolicy.danger));
            continue;
          }
          _images.add(_MediaItem(f.bytes!, f.name));
        }
      });
    }
  }

  /// ✅ Vidéos : tous les formats (le sélecteur FileType.video ne propose que
  /// des vidéos), limite 50 Mo. Plus de liste d'extensions.
  Future<void> _pickVideos() async {
    if (_isUploading) return;
    if (!_canPostVideo) {
      _showUpgradeDialog(_t('cp_feat_video'), _t('cp_tier_standard'));
      return;
    }
    final result = await FilePicker.platform.pickFiles(type: FileType.video, allowMultiple: true, withData: true);
    if (result != null && mounted) {
      setState(() {
        _resetBgColorIfMediaAdded();
        for (final f in result.files) {
          final bytes = f.bytes;
          if (bytes == null || bytes.isEmpty) continue;
          if (!_PostValidators.validateFileSize(bytes.length, maxSizeMB: _maxVideoSizeMB)) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('cp_err_size', args: [f.name, '$_maxVideoSizeMB'])), backgroundColor: ThixPolicy.danger));
            continue;
          }
          _videos.add(_MediaItem(bytes, f.name, isVideo: true));
        }
      });
    }
  }

  Future<void> _pickCamera() async {
    if (_isUploading) return;
    if (_images.length >= _maxPhotos) {
      _showUpgradeDialog(_t('cp_feat_photos'), _isFree ? _t('cp_tier_standard') : _t('cp_tier_premium'));
      return;
    }
    final hasPerm = await _checkPermissionWithDisclosure(
      Permission.camera,
      _t('cp_perm_cam'),
    );
    if (!hasPerm) return;
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        if (!_PostValidators.validateFileSize(bytes.length, maxSizeMB: _maxImageSizeMB)) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('cp_err_photo_size', args: ['$_maxImageSizeMB'])), backgroundColor: ThixPolicy.danger));
          return;
        }
        if (mounted) {
          setState(() {
            _resetBgColorIfMediaAdded();
            _images.add(_MediaItem(bytes, photo.name));
          });
        }
      }
    } catch (e) {
      debugPrint("[Camera] Error: $e");
    }
  }

  void _removeMedia(int index, bool isVideo) {
    setState(() {
      if (isVideo) {
        _videos.removeAt(index);
      } else {
        _images.removeAt(index);
      }
    });
  }

  // ════════════════════════════════════════════════════════════════════════
  // PUBLICATION — postBadge inclus, vidéos : timeout 5 min + extension libre
  // ════════════════════════════════════════════════════════════════════════
  Future<void> _publishPost() async {
    if (_isUploading || _isRecording) return;

    final textContent = _contentController.text.trim();
    setState(() => _errorMessage = null);

    if (_postTypeMode == 0 && textContent.isEmpty && _images.isEmpty && _videos.isEmpty && _audioBytes == null) {
      setState(() => _errorMessage = _t('cp_err_empty'));
      return;
    }
    if (_postTypeMode == 1 && textContent.isEmpty) {
      setState(() => _errorMessage = _t('cp_err_poll_q'));
      return;
    }
    if (_postTypeMode == 2 && (textContent.isEmpty || _challengeEndDate == null || _challengeDescController.text.trim().isEmpty)) {
      setState(() => _errorMessage = _t('cp_err_ch'));
      return;
    }

    if (_postTypeMode == 1) {
      final options = _pollOptionControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
      if (options.length < 2) {
        setState(() => _errorMessage = _t('cp_err_poll_min'));
        return;
      }
      for (final opt in options) {
        if (opt.length > _maxPollOptionLength) {
          setState(() => _errorMessage = _t('cp_err_poll_len', args: ['$_maxPollOptionLength']));
          return;
        }
      }
    }

    setState(() => _isUploading = true);

    final uploadedUrls = <String>[];
    final ns = ref.read(networkServiceProvider);

    try {
      if (_audioBytes != null) {
        try {
          final url = await ns.uploadAudioBytes(_audioBytes!).timeout(_uploadTimeout);
          if (url != null && url.isNotEmpty) uploadedUrls.add(url);
        } catch (e) {
          debugPrint('[Upload] Audio error: $e');
          throw Exception(_t('cp_err_up_audio', args: ['$e']));
        }
      }

      for (final item in _images) {
        try {
          final compressed = await _compressImageBytes(item.bytes);
          final url = await ns.uploadImageBytes(compressed, fileExtension: item.name.split('.').last, bucket: 'post_images').timeout(_uploadTimeout);
          if (url != null && url.isNotEmpty) uploadedUrls.add(url);
        } catch (e) {
          debugPrint('[Upload] Image error: $e');
          throw Exception(_t('cp_err_up_image', args: ['$e']));
        }
      }

      for (final item in _videos) {
        try {
          // Extension libre : n'importe quel format vidéo (repli mp4 si absente)
          final ext = item.name.contains('.') ? item.name.split('.').last.toLowerCase() : 'mp4';
          final url = await ns.uploadImageBytes(item.bytes, fileExtension: ext, bucket: 'videos').timeout(_videoUploadTimeout);
          if (url != null && url.isNotEmpty) uploadedUrls.add(url);
        } catch (e) {
          debugPrint('[Upload] Video error: $e');
          throw Exception(_t('cp_err_up_video', args: ['$e']));
        }
      }

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception(_t('cp_err_auth'));

      String authorName = _displayName;
      String? authorAvatar = _authorAvatar;
      String? authorTitle;
      try {
        final pr = await Supabase.instance.client.from('profiles').select('display_name, avatar_url, profession').eq('id', user.id).maybeSingle();
        if (pr != null) {
          authorName = pr['display_name']?.toString() ?? authorName;
          authorAvatar = pr['avatar_url']?.toString();
          authorTitle = pr['profession']?.toString();
        }
      } catch (e) {
        debugPrint('[Profile] Fetch error: $e');
      }

      final sanitizedContent = _PostValidators.sanitizeText(textContent, maxLength: _maxTextLength);
      final sanitizedChallengeDesc = _PostValidators.sanitizeText(_challengeDescController.text, maxLength: 2000);
      final sanitizedReward = _PostValidators.sanitizeText(_challengeRewardController.text, maxLength: 500);
      final hashtags = _PostValidators.extractHashtags(sanitizedContent);

      final payload = <String, dynamic>{
        'user_id': user.id,
        'content': sanitizedContent,
        'is_public': _isPublic,
        'image_urls': uploadedUrls.where((u) => u.contains('post_images')).toList(),
        'video_urls': uploadedUrls.where((u) => u.contains('videos')).toList(),
        'media_urls': uploadedUrls,
        'media_url': uploadedUrls.isNotEmpty ? uploadedUrls.first : null,
        'community_id': widget.communityId,
        'post_type': 'standard',
        if (_selectedBadge != null) 'post_badge': _selectedBadge!.key,
        if (hashtags.isNotEmpty) 'hashtags': hashtags,
        if (_mentionedIds.isNotEmpty) 'mentioned_user_ids': _mentionedIds.toList(),
        if (_audioBytes != null) 'audio_duration_seconds': _recordDuration,
      };

      if (_postTypeMode == 0 && _audioBytes != null && _images.isEmpty && _videos.isEmpty) payload['post_type'] = 'audio';
      if (_canHaveBgColor && _hasBgColor) payload['bg_color'] = _colorToHex(_selectedBgColor);

      if (_postTypeMode == 1) {
        final options = _pollOptionControllers.map((c) => _PostValidators.sanitizeText(c.text.trim(), maxLength: _maxPollOptionLength)).where((t) => t.isNotEmpty).toList();
        payload['post_type'] = 'poll';
        payload['poll_data'] = {
          'options': options.map((o) => {'text': o, 'votes': []}).toList(),
          'end_date': DateTime.now().add(Duration(days: _pollDurationDays)).toIso8601String(),
          'allow_multiple': _pollMultiple,
        };
      } else if (_postTypeMode == 2) {
        final maxP = int.tryParse(_challengeMaxController.text.trim());
        payload['post_type'] = 'challenge';
        payload['challenge_data'] = {
          'description': sanitizedChallengeDesc,
          'reward': sanitizedReward,
          'end_date': _challengeEndDate?.toIso8601String(),
          'participants_count': 0,
          'participants': [],
          if (maxP != null && maxP > 0) 'max_participants': maxP,
        };
      }

      final inserted = await Supabase.instance.client.from('posts').insert(payload).select().single();
      final postId = inserted['id']?.toString() ?? '';

      final newPost = NetworkPost(
        id: postId,
        userId: user.id,
        authorName: authorName,
        authorAvatar: authorAvatar,
        authorTitle: authorTitle,
        content: sanitizedContent,
        bgColor: payload['bg_color'] as String?,
        postBadge: _selectedBadge?.key,
        mediaUrls: uploadedUrls,
        postType: PostType.values.asNameMap()[payload['post_type'] as String?] ?? PostType.standard,
        pollData: payload['poll_data'] as Map<String, dynamic>?,
        challengeData: payload['challenge_data'] as Map<String, dynamic>?,
        createdAt: DateTime.now(),
        likesCount: 0,
        commentsCount: 0,
        repostsCount: 0,
        isLiked: false,
        isSaved: false,
        isReposted: false,
        isPublic: _isPublic,
      );

      try {
        ref.read(feedProvider.notifier).addPostOnTop(newPost);
      } catch (e) {
        debugPrint('[Feed] Add post error: $e');
        ref.invalidate(feedProvider);
      }
      widget.onPostCreated?.call();
      _clearDraft();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('cp_ok_publish')), backgroundColor: ThixPolicy.success));
      Navigator.pop(context, newPost);
    } catch (e) {
      debugPrint('[Publish] Error: $e');

      if (uploadedUrls.isNotEmpty) {
        for (final url in uploadedUrls) {
          try {
            final uri = Uri.parse(url);
            final path = uri.path.replaceFirst('/storage/v1/object/public/', '');
            final bucket = path.split('/').first;
            final filePath = path.replaceFirst('$bucket/', '');
            await Supabase.instance.client.storage.from(bucket).remove([filePath]);
          } catch (cleanupError) {
            debugPrint('[Cleanup] Error: $cleanupError');
          }
        }
      }

      if (mounted) {
        setState(() {
          _errorMessage = _t('cp_err_publish', args: [e.toString().replaceFirst('Exception: ', '').split('\n').first]);
          _isUploading = false;
        });
      }
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // UI HELPERS
  // ════════════════════════════════════════════════════════════════════════
  Widget _segmentedType() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
      child: Row(
        children: [
          _segItem(_t('cp_tab_post'), 0, Icons.article_rounded),
          _segItem(_t('cp_tab_poll'), 1, Icons.poll_rounded),
          _segItem(_t('cp_tab_challenge'), 2, Icons.emoji_events_rounded),
        ],
      ),
    );
  }

  Widget _segItem(String label, int mode, IconData icon) {
    final sel = _postTypeMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () {
          if (mode == 1 && !_canCreatePoll) {
            _showUpgradeDialog(_t('cp_feat_poll'), _t('cp_tier_premium'));
            return;
          }
          if (mode == 2 && !_canCreateChallenge) {
            _showUpgradeDialog(_t('cp_feat_challenge'), _t('cp_tier_premium'));
            return;
          }
          setState(() => _postTypeMode = mode);
        },
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? ThixPolicy.card : Colors.transparent,
            borderRadius: BorderRadius.circular(ThixPolicy.rSm),
            boxShadow: sel ? ThixPolicy.shadowSoft(opacity: 0.08) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: sel ? ThixPolicy.primary : ThixPolicy.textMuted),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: ThixPolicy.labelStyle.copyWith(fontWeight: sel ? ThixPolicy.bold : ThixPolicy.medium, color: sel ? ThixPolicy.primary : ThixPolicy.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formatBtn({required Widget child, required VoidCallback onTap, required String tooltip}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ThixPolicy.rXs),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(ThixPolicy.rXs), border: Border.all(color: ThixPolicy.border)),
          child: child,
        ),
      ),
    );
  }

  Widget _mediaBtn(IconData icon, VoidCallback onTap, Color color, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: (_isUploading || _isRecording) ? null : onTap,
        borderRadius: BorderRadius.circular(ThixPolicy.rXl),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: ThixPolicy.card, shape: BoxShape.circle, border: Border.all(color: color.withOpacity(0.28), width: 1.3)),
          child: Icon(icon, size: 19, color: color),
        ),
      ),
    );
  }

  Widget _badgeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.local_offer_outlined, size: 14, color: ThixPolicy.textMuted),
            const SizedBox(width: 6),
            Text(_t('cp_badges'), style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted, fontWeight: ThixPolicy.semiBold)),
          ],
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final b in kPostBadges)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedBadge = (_selectedBadge?.key == b.key) ? null : b;
                        _draftBadgeKey = _selectedBadge?.key;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: _selectedBadge?.key == b.key ? b.color.withOpacity(0.14) : ThixPolicy.card,
                        borderRadius: BorderRadius.circular(ThixPolicy.rXl),
                        border: Border.all(
                          color: _selectedBadge?.key == b.key ? b.color : b.color.withOpacity(0.35),
                          width: _selectedBadge?.key == b.key ? 1.8 : 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(b.icon, size: 13, color: b.color),
                          const SizedBox(width: 5),
                          Text(
                            _t(b.labelKey),
                            style: ThixPolicy.labelStyle.copyWith(color: b.color, fontWeight: FontWeight.w900, letterSpacing: 0.5, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _badgePreviewChip(_PostBadge b) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: b.color,
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
        border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.4),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(b.icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            _t(b.labelKey),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.9),
          ),
        ],
      ),
    );
    return b.pulse ? ScaleTransition(scale: _pulseAnim, child: chip) : chip;
  }

  Widget _counterRing(int len, int max) {
    final frac = (len / max).clamp(0.0, 1.0);
    final color = len >= max ? ThixPolicy.danger : (frac > 0.85 ? ThixPolicy.gold : ThixPolicy.primary);
    return SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(value: frac, strokeWidth: 2.4, backgroundColor: ThixPolicy.border, color: color),
    );
  }

  /// ✅ Panneau de suggestions : s'ouvre dès « @ » (spinner pendant le chargement)
  Widget _suggestionPanel() {
    if (_token == null || !(_showSuggestions || _loadingSuggestions)) return const SizedBox.shrink();

    final isMention = _token!.type == _TokenType.mention;
    final isEmpty = isMention ? _mentionSuggestions.isEmpty : _hashtagSuggestions.isEmpty;

    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        constraints: const BoxConstraints(maxHeight: 280),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          border: Border.all(color: ThixPolicy.border),
          boxShadow: ThixPolicy.shadowSoft(opacity: 0.08),
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          children: [
            if (_loadingSuggestions && isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary))),
              ),
            if (isMention)
              for (final u in _mentionSuggestions)
                ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: ThixPolicy.surfaceSoft,
                    backgroundImage: (u['avatar_url']?.toString() ?? '').isNotEmpty ? NetworkImage(u['avatar_url'].toString()) : null,
                    child: (u['avatar_url']?.toString() ?? '').isEmpty ? const Icon(Icons.person, size: 18, color: ThixPolicy.textMuted) : null,
                  ),
                  title: Text(
                    u['display_name']?.toString() ?? u['full_name']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.semiBold),
                  ),
                  subtitle: Text('@${_handleOf(u)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted)),
                  onTap: () => _applyMention(u),
                ),
            if (!isMention)
              for (final h in _hashtagSuggestions)
                ListTile(
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: ThixPolicy.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.tag_rounded, size: 16, color: ThixPolicy.primary),
                  ),
                  title: Text('#${h.tag}', style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.semiBold)),
                  subtitle: Text(_plural('cp_posts', h.count), style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted)),
                  onTap: () => _applyHashtag(h),
                ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final textLen = _contentController.text.length;
    final hasBg = _canHaveBgColor && _hasBgColor;
    final mbUnit = _t('cp_unit_mb');

    return WillPopScope(
      onWillPop: _attemptClose,
      child: Scaffold(
        backgroundColor: ThixPolicy.surfaceSoft,
        appBar: AppBar(
          backgroundColor: ThixPolicy.card,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: ThixPolicy.textMain),
            onPressed: _isUploading
                ? null
                : () async {
                    if (await _attemptClose() && mounted) Navigator.pop(context);
                  },
          ),
          title: Text(
            _postTypeMode == 1 ? _t('cp_title_poll') : _postTypeMode == 2 ? _t('cp_title_challenge') : _t('cp_title_post'),
            style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, fontSize: 17, color: ThixPolicy.textMain),
          ),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: TextButton(
                onPressed: (_isUploading || _isRecording) ? null : _publishPost,
                style: TextButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rXl)),
                ),
                child: _isUploading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_t('cp_publish'), style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
        body: _isLoadingLimits
            ? const Center(child: CircularProgressIndicator(color: ThixPolicy.primary))
            : FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: ThixPolicy.surfaceSoft,
                                  backgroundImage: (_authorAvatar ?? '').isNotEmpty ? CachedNetworkImageProvider(_authorAvatar!) : null,
                                  child: (_authorAvatar ?? '').isEmpty ? const Icon(Icons.person, color: ThixPolicy.textMuted) : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_displayName, style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold)),
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: ThixPolicy.gold.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                                        child: Text(_userTier.toUpperCase(), style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: ThixPolicy.gold, letterSpacing: 0.6)),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<bool>(
                                  tooltip: _t('cp_visibility'),
                                  onSelected: (v) => setState(() => _isPublic = v),
                                  itemBuilder: (_) => [
                                    PopupMenuItem(value: true, child: Row(children: [const Icon(Icons.public_rounded, size: 18), const SizedBox(width: 8), Text(_t('cp_public'))])),
                                    PopupMenuItem(value: false, child: Row(children: [const Icon(Icons.group_rounded, size: 18), const SizedBox(width: 8), Text(_t('cp_contacts'))])),
                                  ],
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(ThixPolicy.rSm), border: Border.all(color: ThixPolicy.border)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(_isPublic ? Icons.public_rounded : Icons.group_rounded, size: 15, color: ThixPolicy.textSecondary),
                                        const SizedBox(width: 6),
                                        Text(_isPublic ? _t('cp_public') : _t('cp_contacts_short'), style: ThixPolicy.captionStyle.copyWith(fontWeight: ThixPolicy.bold)),
                                        const Icon(Icons.arrow_drop_down_rounded, size: 18, color: ThixPolicy.textMuted),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            _segmentedType(),
                            const SizedBox(height: 14),

                            if (_postTypeMode != 2) ...[
                              _badgeSelector(),
                              const SizedBox(height: 12),
                            ],

                            if (_errorMessage != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(color: ThixPolicy.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(ThixPolicy.rSm), border: Border.all(color: ThixPolicy.danger.withOpacity(0.15))),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded, size: 16, color: ThixPolicy.danger),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(_errorMessage!, style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.danger))),
                                  ],
                                ),
                              ),

                            if (_postTypeMode != 2 && !_hasBgColor) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
                                child: Row(
                                  children: [
                                    _formatBtn(child: Text('B', style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold)), onTap: _applyBold, tooltip: _t('cp_bold')),
                                    const SizedBox(width: 8),
                                    _formatBtn(child: Text('I', style: ThixPolicy.labelStyle.copyWith(fontStyle: FontStyle.italic, fontWeight: ThixPolicy.bold)), onTap: _applyItalic, tooltip: _t('cp_italic')),
                                    Container(width: 1, height: 18, color: ThixPolicy.border, margin: const EdgeInsets.symmetric(horizontal: 10)),
                                    for (final color in _textColors)
                                      Padding(
                                        padding: const EdgeInsetsDirectional.only(end: 7),
                                        child: GestureDetector(
                                          onTap: () => _applyColor(color),
                                          child: Container(width: 18, height: 18, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: ThixPolicy.card, width: 2))),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: hasBg ? _selectedBgColor : ThixPolicy.card,
                                borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                                border: Border.all(color: hasBg ? Colors.transparent : ThixPolicy.border),
                              ),
                              padding: hasBg ? const EdgeInsets.symmetric(horizontal: 20, vertical: 40) : const EdgeInsets.all(15),
                              alignment: hasBg ? Alignment.center : AlignmentDirectional.topStart,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: hasBg ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                                children: [
                                  if (_selectedBadge != null) ...[
                                    _badgePreviewChip(_selectedBadge!),
                                    const SizedBox(height: 12),
                                  ],
                                  TextField(
                                    controller: _contentController,
                                    focusNode: _contentFocusNode,
                                    maxLength: _isFree ? 280 : null,
                                    minLines: _postTypeMode == 2 ? 2 : (hasBg ? null : 6),
                                    maxLines: hasBg ? null : 14,
                                    textAlign: hasBg ? TextAlign.center : TextAlign.start,
                                    style: ThixPolicy.bodyStyle.copyWith(
                                      color: hasBg ? Colors.white : ThixPolicy.textMain,
                                      fontSize: hasBg ? 22 : 15,
                                      fontWeight: hasBg ? ThixPolicy.bold : ThixPolicy.regular,
                                      height: 1.45,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: _postTypeMode == 1 ? _t('cp_hint_poll') : _postTypeMode == 2 ? _t('cp_hint_challenge') : _t('cp_hint_post'),
                                      hintStyle: ThixPolicy.bodyStyle.copyWith(color: hasBg ? Colors.white70 : ThixPolicy.textSecondary),
                                      border: InputBorder.none,
                                      isCollapsed: true,
                                      counterText: "",
                                      fillColor: Colors.transparent,
                                      filled: true,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            _suggestionPanel(),

                            if (_postTypeMode != 2)
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.only(top: 10),
                                child: Row(
                                  children: [
                                    for (final e in _quickEmojis)
                                      Padding(
                                        padding: const EdgeInsetsDirectional.only(end: 10),
                                        child: GestureDetector(onTap: () => _insertEmoji(e), child: Text(e, style: const TextStyle(fontSize: 20))),
                                      ),
                                  ],
                                ),
                              ),

                            if (_isFree && _postTypeMode == 0)
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    '$textLen / 280',
                                    style: ThixPolicy.captionStyle.copyWith(fontWeight: ThixPolicy.bold, color: textLen >= 280 ? ThixPolicy.danger : ThixPolicy.textSecondary),
                                  ),
                                ),
                              ),

                            if (_isRecording)
                              Container(
                                margin: const EdgeInsets.only(top: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(color: ThixPolicy.danger.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: ThixPolicy.danger.withOpacity(0.2))),
                                child: Row(
                                  children: [
                                    const Icon(Icons.mic, color: ThixPolicy.danger, size: 20),
                                    const SizedBox(width: 12),
                                    Text(
                                      _t('cp_recording', args: ['${_recordDuration ~/ 60}:${(_recordDuration % 60).toString().padLeft(2, '0')}']),
                                      style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.danger, fontWeight: ThixPolicy.bold),
                                    ),
                                    const Spacer(),
                                    GestureDetector(onTap: _stopRecording, child: const Icon(Icons.stop_circle_rounded, color: ThixPolicy.danger, size: 30)),
                                  ],
                                ),
                              )
                            else if (_localAudioPath != null)
                              Container(
                                margin: const EdgeInsets.only(top: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: ThixPolicy.border)),
                                child: Row(
                                  children: [
                                    Expanded(child: _InlineAudioPlayer(audioPath: _localAudioPath!)),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: ThixPolicy.textSecondary, size: 20),
                                      onPressed: () => setState(() {
                                        _audioBytes = null;
                                        _localAudioPath = null;
                                      }),
                                    ),
                                  ],
                                ),
                              ),

                            if (_canHaveBgColor)
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.only(top: 12),
                                child: Row(
                                  children: _bgColors.map((c) {
                                    final sel = _selectedBgColor == c;
                                    return GestureDetector(
                                      onTap: () {
                                        if (!_canFormatText && c != Colors.transparent) {
                                          _showUpgradeDialog(_t('cp_feat_bg'), _t('cp_tier_standard'));
                                          return;
                                        }
                                        setState(() => _selectedBgColor = c);
                                      },
                                      child: Container(
                                        margin: const EdgeInsetsDirectional.only(end: 9),
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: sel ? ThixPolicy.textMain : ThixPolicy.borderStrong, width: sel ? 2.2 : 1.3)),
                                        child: c == Colors.transparent ? const Icon(Icons.format_color_reset_rounded, size: 15, color: Colors.black45) : null,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),

                            if (_postTypeMode == 1) ...[
                              const SizedBox(height: 16),
                              Text(_t('cp_poll_options'), style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold)),
                              const SizedBox(height: 8),
                              ..._pollOptionControllers.asMap().entries.map((e) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: e.value,
                                          maxLength: _maxPollOptionLength,
                                          style: ThixPolicy.bodyStyle.copyWith(fontSize: 13.5),
                                          decoration: InputDecoration(
                                            hintText: _t('cp_poll_option', args: ['${e.key + 1}']),
                                            filled: true,
                                            fillColor: ThixPolicy.card,
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm), borderSide: BorderSide.none),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                            counterText: '',
                                          ),
                                        ),
                                      ),
                                      if (e.key > 1)
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, color: ThixPolicy.danger, size: 20),
                                          onPressed: () {
                                            setState(() {
                                              _pollOptionControllers[e.key].dispose();
                                              _pollOptionControllers.removeAt(e.key);
                                            });
                                          },
                                        ),
                                    ],
                                  ),
                                );
                              }),
                              if (_pollOptionControllers.length < (_hasWidePollOptions ? 8 : 4))
                                TextButton.icon(
                                  onPressed: () => setState(() => _pollOptionControllers.add(TextEditingController())),
                                  icon: const Icon(Icons.add_circle_outline, size: 17),
                                  label: Text(_t('cp_poll_add'), style: ThixPolicy.labelStyle),
                                ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(ThixPolicy.rSm), border: Border.all(color: ThixPolicy.border)),
                                child: SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(_t('cp_poll_multiple'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                  value: _pollMultiple,
                                  activeColor: ThixPolicy.primary,
                                  onChanged: (v) => setState(() => _pollMultiple = v),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(_t('cp_poll_duration'), style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  for (final d in const [1, 3, 7]) ...[
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsetsDirectional.only(end: 8),
                                        child: InkWell(
                                          onTap: () => setState(() => _pollDurationDays = d),
                                          borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            decoration: BoxDecoration(
                                              color: _pollDurationDays == d ? ThixPolicy.primary : ThixPolicy.card,
                                              borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                                              border: Border.all(color: _pollDurationDays == d ? ThixPolicy.primary : ThixPolicy.border),
                                            ),
                                            child: Text(
                                              d == 7 ? _t('cp_poll_week') : _t(d == 1 ? 'cp_poll_day' : 'cp_poll_days', args: ['$d']),
                                              textAlign: TextAlign.center,
                                              style: ThixPolicy.labelStyle.copyWith(color: _pollDurationDays == d ? Colors.white : ThixPolicy.textMain, fontWeight: ThixPolicy.semiBold),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],

                            if (_postTypeMode == 2) ...[
                              const SizedBox(height: 16),
                              Text(_t('cp_ch_desc'), style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _challengeDescController,
                                minLines: 3,
                                maxLines: 5,
                                maxLength: 2000,
                                style: ThixPolicy.bodyStyle.copyWith(fontSize: 13.5),
                                decoration: InputDecoration(
                                  hintText: _t('cp_ch_desc_hint'),
                                  filled: true,
                                  fillColor: ThixPolicy.card,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.all(14),
                                  counterText: '',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _challengeRewardController,
                                maxLength: 500,
                                style: ThixPolicy.bodyStyle.copyWith(fontSize: 13.5),
                                decoration: InputDecoration(
                                  hintText: _t('cp_ch_reward'),
                                  filled: true,
                                  fillColor: ThixPolicy.card,
                                  prefixIcon: const Icon(Icons.card_giftcard_rounded, size: 18, color: ThixPolicy.gold),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                  counterText: '',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _challengeMaxController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                maxLength: 6,
                                style: ThixPolicy.bodyStyle.copyWith(fontSize: 13.5),
                                decoration: InputDecoration(
                                  hintText: _t('cp_ch_max'),
                                  filled: true,
                                  fillColor: ThixPolicy.card,
                                  prefixIcon: const Icon(Icons.groups_rounded, size: 18, color: ThixPolicy.primary),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                  counterText: '',
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextButton.icon(
                                style: TextButton.styleFrom(backgroundColor: ThixPolicy.card, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm))),
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _challengeEndDate ?? DateTime.now().add(const Duration(days: 7)),
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(const Duration(days: 365)),
                                  );
                                  if (picked != null) {
                                    final time = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.fromDateTime(_challengeEndDate ?? DateTime.now().add(const Duration(days: 7, hours: 12))),
                                    );
                                    setState(() {
                                      _challengeEndDate = DateTime(picked.year, picked.month, picked.day, time?.hour ?? 23, time?.minute ?? 59);
                                    });
                                  }
                                },
                                icon: const Icon(Icons.calendar_today_rounded, size: 15, color: ThixPolicy.primary),
                                label: Text(
                                  _challengeEndDate == null
                                      ? _t('cp_ch_pick')
                                      : _t('cp_ch_end', args: [
                                          '${_challengeEndDate!.day}/${_challengeEndDate!.month}/${_challengeEndDate!.year}',
                                          '${_challengeEndDate!.hour.toString().padLeft(2, '0')}:${_challengeEndDate!.minute.toString().padLeft(2, '0')}'
                                        ]),
                                  style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.primary, fontWeight: ThixPolicy.semiBold),
                                ),
                              ),
                              if (_challengeEndDate != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    _t('cp_ch_countdown', args: ['${_challengeEndDate!.difference(DateTime.now()).inDays}']),
                                    style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.gold, fontWeight: ThixPolicy.bold),
                                  ),
                                ),
                            ],

                            if (_images.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (int i = 0; i < _images.length; i++)
                                      Stack(
                                        children: [
                                          ClipRRect(borderRadius: BorderRadius.circular(ThixPolicy.rSm), child: Image.memory(_images[i].bytes, width: 92, height: 92, fit: BoxFit.cover)),
                                          Positioned(
                                            left: 4,
                                            bottom: 4,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                                              child: Text('${(_images[i].bytes.length / 1048576).toStringAsFixed(1)} $mbUnit', style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w700)),
                                            ),
                                          ),
                                          Positioned(
                                            top: 4,
                                            right: 4,
                                            child: GestureDetector(
                                              onTap: () => _removeMedia(i, false),
                                              child: Container(padding: const EdgeInsets.all(3), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, size: 13, color: Colors.white)),
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            if (_videos.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (int i = 0; i < _videos.length; i++)
                                      Stack(
                                        children: [
                                          Container(width: 92, height: 92, decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(ThixPolicy.rSm)), child: const Center(child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30))),
                                          Positioned(
                                            left: 4,
                                            bottom: 4,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                                              child: Text('${(_videos[i].bytes.length / 1048576).toStringAsFixed(1)} $mbUnit', style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w700)),
                                            ),
                                          ),
                                          Positioned(
                                            top: 4,
                                            right: 4,
                                            child: GestureDetector(
                                              onTap: () => _removeMedia(i, true),
                                              child: Container(padding: const EdgeInsets.all(3), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, size: 13, color: Colors.white)),
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      decoration: BoxDecoration(color: ThixPolicy.card, border: Border(top: BorderSide(color: ThixPolicy.border.withOpacity(0.6)))),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                _mediaBtn(Icons.photo_rounded, _pickImages, ThixPolicy.success, _t('cp_photos')),
                                _mediaBtn(Icons.videocam_rounded, _pickVideos, ThixPolicy.danger, _t('cp_videos')),
                                _mediaBtn(Icons.photo_camera_rounded, _pickCamera, ThixPolicy.primary, _t('cp_camera')),
                                _mediaBtn(_isRecording ? Icons.stop_circle_rounded : Icons.mic_rounded, _isRecording ? _stopRecording : _startRecording, ThixPolicy.gold, _t('cp_audio')),
                                const Spacer(),
                                _counterRing(textLen, _maxTextLength),
                                const SizedBox(width: 6),
                                Text('$textLen/${_isFree ? 280 : _maxTextLength}', style: ThixPolicy.captionStyle.copyWith(fontWeight: ThixPolicy.bold, color: textLen >= (_isFree ? 280 : _maxTextLength) ? ThixPolicy.danger : ThixPolicy.textMuted)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: (_isUploading || _isRecording) ? null : _publishPost,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ThixPolicy.primary,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: ThixPolicy.surfaceStrong,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rXl)),
                                  elevation: 0,
                                ),
                                child: _isUploading
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : Text(_t('cp_publish'), style: ThixPolicy.buttonText),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ============================================================================
// LECTEUR AUDIO INLINE
// ============================================================================
class _InlineAudioPlayer extends StatefulWidget {
  final String audioPath;
  const _InlineAudioPlayer({required this.audioPath});
  @override
  State<_InlineAudioPlayer> createState() => _InlineAudioPlayerState();
}

class _InlineAudioPlayerState extends State<_InlineAudioPlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      if (kIsWeb) {
        await _player.setSourceUrl(widget.audioPath);
      } else {
        await _player.setSourceDeviceFile(widget.audioPath);
      }
      _player.onPlayerStateChanged.listen((state) {
        if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
      });
      _player.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      });
      _player.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
      });
    } catch (e) {
      debugPrint('[AudioPlayer] Init error: $e');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            if (_isPlaying) {
              _player.pause();
            } else {
              _player.resume();
            }
          },
          child: Container(width: 32, height: 32, decoration: const BoxDecoration(color: ThixPolicy.primary, shape: BoxShape.circle), child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 20)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SliderTheme(
            data: const SliderThemeData(trackHeight: 2, thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6), activeTrackColor: ThixPolicy.primary, inactiveTrackColor: ThixPolicy.border, thumbColor: ThixPolicy.primary),
            child: Slider(
              min: 0,
              max: _duration.inMilliseconds.toDouble() > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
              value: _position.inMilliseconds.toDouble().clamp(0.0, _duration.inMilliseconds.toDouble() > 0 ? _duration.inMilliseconds.toDouble() : 1.0),
              onChanged: (val) => _player.seek(Duration(milliseconds: val.toInt())),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(_formatDuration(_duration.inSeconds > 0 && !_isPlaying && _position.inSeconds == 0 ? _duration : _position), style: ThixPolicy.captionStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain)),
      ],
    );
  }
}
