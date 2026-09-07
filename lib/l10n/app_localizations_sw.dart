// lib/l10n/app_localizations_sw.dart
import 'app_localizations.dart';

class AppLocalizationsSw extends AppLocalizations {
  // ============================================================================
  // COMMON & UI
  // ============================================================================
  @override String get common_back => 'Rudi';
  @override String get common_close => 'Funga';
  @override String get common_cancel => 'Ghairi';
  @override String get common_confirm => 'Thibitisha';
  @override String get common_delete => 'Futa';
  @override String get common_add => 'Ongeza';
  @override String get common_edit => 'Hariri';
  @override String get common_save => 'Hifadhi';
  @override String get common_manage => 'Dhibiti';
  @override String get common_retry => 'Jaribu tena';
  @override String get common_refresh => 'Onyesha upya';
  @override String get common_search => 'Tafuta';
  @override String get common_open => 'Fungua';
  @override String get common_share => 'Shiriki';
  @override String get common_copy => 'Nakili';
  @override String get common_copied => 'Imenakiliwa!';
  @override String get common_download => 'Pakua';
  @override String get common_upload => 'Pakia';
  @override String get common_send => 'Tuma';
  @override String get common_receive => 'Pokea';
  @override String get common_accept => 'Kubali';
  @override String get common_reject => 'Kataa';
  @override String get common_skip => 'Ruka';
  @override String get common_next => 'Inayofuata';
  @override String get common_previous => 'Iliyotangulia';
  @override String get common_finish => 'Maliza';
  @override String get common_done => 'Imekamilika';
  @override String get common_error => 'Hitilafu';
  @override String get common_success => 'Mafanikio';
  @override String get common_loading => 'Inapakia…';
  @override String get common_please_wait => 'Tafadhali subiri…';
  @override String get common_today => 'Leo';
  @override String get common_yesterday => 'Jana';
  @override String get common_tomorrow => 'Kesho';
  @override String get common_home => 'Mwanzo';
  @override String get common_chat => 'Soga';
  @override String get common_map => 'Ramani';
  @override String get common_profile => 'Wasifu';
  @override String get common_menu => 'Menyu';
  @override String get common_notifications => 'Arifa';
  @override String get common_settings => 'Mipangilio';
  @override String get common_help => 'Msaada';
  @override String get common_about => 'Kuhusu';
  @override String get common_logout => 'Ondoka';
  @override String get common_login => 'Ingia';
  @override String get common_signup => 'Jisajili';
  @override String get common_yes => 'Ndiyo';
  @override String get common_no => 'Hapana';
  @override String get common_or => 'au';
  @override String get common_and => 'na';
  @override String get common_none => 'Hakuna';
  @override String get common_all => 'Yote';
  @override String get common_unknown => 'Haujulikani';
  @override String get common_enabled => 'Imewashwa';
  @override String get common_disabled => 'Imezimwa';
  @override String get common_clear => 'Futa';
  @override String get common_remove => 'Ondoa';
  
  @override String common_items(int count) => count == 0 ? 'Hakuna vipengee' : (count == 1 ? 'Kipengee 1' : 'Vipengee $count');
  @override String common_contacts(int count) => count == 0 ? 'Hakuna anwani' : (count == 1 ? 'Anwani 1' : 'Anwani $count');
  @override String common_messages(int count) => count == 0 ? 'Hakuna ujumbe' : (count == 1 ? 'Ujumbe 1' : 'Ujumbe $count');
  @override String common_days(int count) => count == 0 ? 'Siku 0' : (count == 1 ? 'Siku 1' : 'Siku $count');
  @override String common_hours(int count) => count == 0 ? 'Saa 0' : (count == 1 ? 'Saa 1' : 'Saa $count');
  @override String common_minutes(int count) => count == 0 ? 'Dakika 0' : (count == 1 ? 'Dakika 1' : 'Dakika $count');

  // ============================================================================
  // AUTH & ONBOARDING (BASIC)
  // ============================================================================
  @override String get auth_login => 'Ingia';
  @override String get auth_signup => 'Jisajili';
  @override String get auth_forgot_password => 'Umesahau nenosiri?';
  @override String get auth_reset_password => 'Weka upya nenosiri';
  @override String get auth_email => 'Barua pepe';
  @override String get auth_phone => 'Nambari ya simu';
  @override String get auth_password => 'Nenosiri';
  @override String get auth_confirm_password => 'Thibitisha nenosiri';
  @override String get auth_logout_confirm => 'Una uhakika unataka kuondoka?';
  @override String get auth_welcome_back => 'Karibu tena';
  @override String get auth_welcome => 'Karibu';
  @override String get auth_no_account => 'Huna akaunti bado?';
  @override String get auth_has_account => 'Tayari una akaunti?';
  @override String get auth_invalid_email => 'Barua pepe batili';
  @override String get auth_invalid_phone => 'Nambari ya simu batili';
  @override String get auth_password_too_short => 'Nenosiri ni fupi mno (angalau herufi 8)';
  @override String get auth_passwords_mismatch => 'Manenosiri hayalingani';
  @override String get auth_login_success => 'Umeingia kikamilifu';
  @override String get auth_signup_success => 'Akaunti imeundwa kikamilifu';
  @override String get auth_session_expired => 'Muda wa kipindi umeisha, tafadhali ingia tena';
  @override String get auth_2fa_title => 'Uthibitishaji wa hatua mbili';
  @override String get auth_2fa_code => 'Msimbo wa uthibitishaji';
  @override String get auth_verify_email => 'Thibitisha barua pepe';
  @override String get auth_verify_phone => 'Thibitisha simu';
  @override String get auth_biometric => 'Kuingia kwa biometriska';
  @override String get auth_biometric_prompt => 'Thibitisha ili uendelee';
  @override String get auth_full_name => 'Jina kamili';
  @override String get auth_first_name => 'Jina la kwanza';
  @override String get auth_last_name => 'Jina la mwisho';
  @override String get auth_birth_date => 'Tarehe ya kuzaliwa';
  @override String get auth_gender => 'Jinsia';
  @override String get auth_gender_male => 'Mwanamume';
  @override String get auth_gender_female => 'Mwanamke';
  @override String get auth_gender_other => 'Mengine';
  @override String get auth_accept_terms => 'Ninakubali Masharti ya Matumizi';
  @override String get auth_terms_required => 'Lazima ukubali masharti';
  @override String get auth_email_already_used => 'Barua pepe hii tayari inatumika';
  @override String get auth_phone_already_used => 'Nambari hii ya simu tayari inatumika';
  @override String get auth_create_account => 'Unda akaunti yangu';
  @override String get auth_already_have_account => 'Nina akaunti tayari';

  @override String get onboarding_welcome => 'Karibu THIX';
  @override String get onboarding_step_1_title => 'Unganisha';
  @override String get onboarding_step_1_desc => 'Unda utambulisho wako salama wa THIX';
  @override String get onboarding_step_2_title => 'Ulinzi';
  @override String get onboarding_step_2_desc => 'Wezesha ulinzi wa 24/7';
  @override String get onboarding_step_3_title => 'Hatua';
  @override String get onboarding_step_3_desc => 'Wajulishe waokoaji wako kwa sekunde 2';
  @override String get onboarding_get_started => 'Anza';
  @override String get onboarding_skip => 'Ruka utangulizi';

  // ============================================================================
  // AUTHENTIFICATION & CONNEXION (ADVANCED / ERRORS)
  // ============================================================================
  @override String get login_title => 'Ingia kwenye THIX';
  @override String get login_subtitle => 'Karibu tena';
  @override String get login_identifier_label => 'Kitambulisho';
  @override String get login_identifier_hint => 'Barua pepe, simu au ID ya THIX';
  @override String get login_password_label => 'Nenosiri';
  @override String get login_password_hint => 'Nenosiri lako salama';
  @override String get login_remember_me => 'Nikumbuke';
  @override String get login_forgot_password => 'Umesahau nenosiri?';
  @override String get login_button => 'Ingia';
  @override String get login_verifying => 'Inathibitisha…';
  @override String get login_retry_in => 'Jaribu tena baada ya';
  @override String get login_seconds_suffix => 's';
  @override String get login_biometric => 'AU ENDELEA NA';
  @override String get login_face_id => 'Face ID';
  @override String get login_touch_id => 'Touch ID';
  
  @override String get login_error_suspended => 'Akaunti hii imesitishwa. Wasiliana na usaidizi.';
  @override String get login_error_not_active => 'Akaunti hii haijawezeshwa.';
  @override String get login_error_no_account => 'Hakuna akaunti iliyopatikana kwa maelezo haya.';
  @override String get login_error_mfa_required => 'Uthibitishaji wa hatua mbili unahitajika.';

  @override String get auth_error_identifier_required => 'Kitambulisho kinahitajika';
  @override String get auth_error_password_required => 'Nenosiri linahitajika';
  @override String get auth_error_thix_id_login_not_available => 'Kuingia kwa ID ya THIX hakupatikani kwa sasa';
  @override String get auth_error_sign_in_failed => 'Kuingia kumeshindwa. Angalia vitambulisho vyako.';
  @override String get auth_error_email_not_verified => 'Tafadhali thibitisha barua pepe yako kabla ya kuingia';
  @override String get auth_error_server_misconfiguration => 'Hitilafu ya usanidi wa seva';
  @override String get auth_error_account_already_exists => 'Akaunti yenye kitambulisho hiki tayari ipo';
  @override String get auth_error_account_exists_wrong_password => 'Akaunti hii ipo lakini nenosiri si sahihi';
  @override String get auth_error_account_exists_new_otp_sent => 'Msimbo mpya wa OTP umetumwa kwa anwani yako';
  @override String get auth_error_invalid_otp => 'Msimbo wa OTP ni batili au umeisha muda wake';
  @override String get auth_error_otp_expired => 'Msimbo wa OTP umeisha muda wake';
  @override String get auth_error_network => 'Hitilafu ya mtandao. Angalia intaneti yako.';
  @override String get auth_error_rate_limit => 'Majaribio mengi mno. Tafadhali subiri kidogo.';
  @override String get auth_error_technical => 'Hitilafu ya kiufundi imetokea. Tafadhali jaribu tena.';
  @override String get auth_error_user_mismatch => 'Tofauti ya mtumiaji imegunduliwa';
  @override String get auth_error_profile_update_failed => 'Imeshindwa kusasisha wasifu';
  @override String get auth_error_mark_email_verified_failed => 'Imeshindwa kuthibitisha barua pepe';
  @override String get auth_error_qr_token_generation_failed => 'Imeshindwa kutengeneza ishara ya QR';
  @override String get auth_error_finalize_registration_failed => 'Imeshindwa kukamilisha usajili';
  @override String get auth_error_consume_qr_token_failed => 'Imeshindwa kutumia ishara ya QR';
  @override String get auth_error_resend_otp_failed => 'Imeshindwa kutuma tena msimbo wa OTP';
  @override String get auth_error_phone_auth_not_available => 'Uthibitishaji kwa simu haupatikani';
  @override String get auth_error_delete_account_not_available => 'Kufuta akaunti hakupatikani kwa sasa';
  @override String get auth_error_update_email_failed => 'Imeshindwa kusasisha anwani ya barua pepe';
  @override String get auth_error_reset_password_failed => 'Imeshindwa kuweka upya nenosiri';
  @override String get auth_error_sign_up_failed => 'Imeshindwa kuunda akaunti';
  @override String get auth_info_otp_sent => 'Msimbo wa uthibitishaji umetumwa';

  // ============================================================================
  // INSCRIPTION PERSONNELLE (PERSONAL REGISTRATION)
  // ============================================================================
  @override String get reg_step1_title => 'Wasifu wako';
  @override String get reg_step1_subtitle => 'Tuanze na taarifa za msingi';
  @override String get reg_full_name_label => 'Jina kamili';
  @override String get reg_full_name_hint => 'Jina la Kwanza na Mwisho';
  @override String get reg_dob_label => 'Tarehe ya kuzaliwa';
  @override String get reg_country_label => 'Nchi ya makazi';
  @override String get reg_occupation_label => 'Kazi / Shughuli';
  @override String get reg_occupation_hint => 'Mf: Msanidi, Mwanafunzi, Mjasiriamali';
  @override String get reg_next => 'Inayofuata';

  @override String get reg_step2_title => 'Linda akaunti yako';
  @override String get reg_step2_subtitle => 'Unda vitambulisho vyako vya kuingia';
  @override String get reg_email_label => 'Barua pepe';
  @override String get reg_email_hint => 'barua.pepe@mfano.com';
  @override String get reg_phone_label => 'Nambari ya simu';
  @override String get reg_phone_hint => '+255 7XX XXX XXX';
  @override String get reg_password_label => 'Nenosiri';
  @override String get reg_password_hint => 'Angalau herufi 8';
  @override String get reg_confirm_password_label => 'Thibitisha nenosiri';
  @override String get reg_confirm_password_hint => 'Andika tena nenosiri lako';
  @override String get reg_strength_label => 'Nguvu ya nenosiri';
  @override String get reg_strength_very_weak => 'Dhaifu sana';
  @override String get reg_strength_weak => 'Dhaifu';
  @override String get reg_strength_medium => 'Wastani';
  @override String get reg_strength_strong => 'Imara';
  @override String get reg_strength_excellent => 'Bora';

  @override String get reg_identity_title => 'Utambulisho wa THIX';
  @override String get reg_thix_chat_label => 'Jina la mtumiaji wa THIX Chat';
  @override String get reg_thix_chat_hint => 'Mf: juma.j (la kipekee)';
  
  @override String get reg_verification_title => 'Uthibitishaji';
  @override String get reg_get_otp => 'Pata msimbo wa uthibitishaji';
  @override String get reg_code_sent_resend => 'Tuma tena msimbo';
  @override String get reg_resend_in => 'Tuma tena baada ya';
  @override String get reg_seconds_short => 's';
  @override String get reg_otp_label => 'Msimbo wa Uthibitishaji (OTP)';
  @override String get reg_validate_activate => 'Thibitisha na Wezesha';
  @override String get reg_activating => 'Inawezesha…';

  @override String get reg_congrats => 'Hongera!';
  @override String get reg_welcome_message => 'Karibu kwenye mfumo wa THIX,';
  @override String get reg_id_card_title => 'KADI YA UTAMBULISHO WA KIDIJITALI THIX';
  @override String get reg_official_thix_id => 'ID RASMI YA THIX';
  @override String get reg_generating => 'Inatengeneza…';
  @override String get reg_copy_thix_id => 'Nakili ID ya THIX';
  @override String get reg_thix_id_copied => 'ID ya THIX imenakiliwa kwenye ubao';
  @override String get reg_go_to_dashboard => 'Nenda kwenye Dashibodi';
  @override String get reg_summary => 'Muhtasari wa Usajili';
  @override String get reg_mobile_label => 'Simu ya mkononi';
  @override String get reg_not_provided => 'Haijatolewa';

  // ============================================================================
  // ACCUEIL & TABLEAU DE BORD (HOME & DASHBOARD)
  // ============================================================================
  @override String get home_search_hint => 'Tafuta huduma au anwani…';
  @override String get home_greeting => 'Habari';
  @override String get home_greeting_time => 'Habari ya jioni';
  @override String get home_welcome_back => 'Karibu tena';
  @override String get home_language_kiswahili => 'Kiswahili';
  @override String get home_banner_default_tag => 'PROGRAMU YA VIJANA';
  @override String get home_banner_default_title => 'Gundua fursa na matukio ya hivi punde';
  
  @override String get cert_pending => 'Udhibitisho unasubiriwa';
  @override String get cert_tier_ladder => 'Kiwango kinachunguzwa kwa sasa';
  @override String get cert_view => 'Angalia';

  @override String get quick_sona => 'THIX Sona';
  @override String get quick_doc => 'Nyaraka zangu';
  @override String get quick_chat => 'Soga';
  @override String get quick_sos => 'Dharura';
  @override String get service_sante => 'Afya ya THIX';
  @override String get service_market => 'Soko la THIX';
  @override String get service_money => 'Mkoba wa THIX';
  @override String get service_reservation => 'Uhifadhi';
  @override String get service_mon_pays => 'Nchi Yangu';
  @override String get service_emploi => 'Kazi';
  @override String get service_formations => 'Mafunzo';
  @override String get service_opportunites => 'Fursa';
  @override String get service_infos => 'Habari';
  @override String get service_events => 'Matukio';
  @override String get service_media => 'Vyombo vya habari';
  @override String get service_vault => 'Kasha';
  @override String get service_network => 'Mtandao';
  @override String get service_certification => 'Udhibitisho';

  // ============================================================================
  // CHAT & MESSAGERIE (CHAT & MESSAGING)
  // ============================================================================
  @override String get chatlist_network => 'Mtandao';
  @override String get chatlist_discussions => 'Soga';
  @override String get chatlist_create_new => 'Unda soga mpya';
  @override String get chatlist_calls => 'Simu';
  @override String get chatlist_settings => 'Mipangilio';

  @override String get chat_unknown_user => 'Mtumiaji asiyejulikana';
  @override String chat_members(int count) => count == 1 ? 'Mwanachama 1' : 'Wanachama $count';
  @override String get chat_video_call => 'Simu ya video';
  @override String get chat_audio_call => 'Simu ya sauti';
  @override String get chat_escalate => 'Kuinua';
  @override String get chat_history => 'Historia';
  @override String get chat_group_info => 'Maelezo ya kikundi';
  @override String get chat_file => 'Faili';
  @override String get chat_sticker => 'Kibandiko';
  @override String get chat_ephemeral => 'Muda mfupi';
  @override String get chat_protected => 'Imelindwa';
  @override String get chat_internal_note => 'Ujumbe wa ndani';
  @override String get chat_send => 'Tuma';
  @override String get chat_recording => 'Inarekodi';
  @override String get chat_stop_recording => 'Simamisha';
  @override String get chat_write_message => 'Andika ujumbe...';
  @override String get chat_record_audio => 'Rekodi sauti';
  @override String get chat_emojis => 'Emoji';
  @override String get chat_reactions => 'Miitikio';
  @override String get chat_flags => 'Bendera';
  @override String get chat_callback => 'Piga tena';
  @override String get chat_typing => 'anaandika...';
  @override String get chat_pause => 'Sitisha';
  @override String get chat_play => 'Cheza';

  @override String get conv_status_connected => 'Imeunganishwa';
  @override String get conv_status_pending => 'Inasubiriwa';
  @override String get conv_status_rejected => 'Imekataliwa';
  @override String get conv_cannot_self => 'Huwezi kujiongeza mwenyewe';
  @override String get conv_request_pending => 'Ombi la muunganisho linasubiriwa';
  @override String get conv_request_rejected => 'Ombi la muunganisho limekataliwa';
  @override String get conv_request_to => 'Tuma ombi kwa';
  @override String get conv_request_hint => 'Ongeza ujumbe wa hiari kwa ombi lako la muunganisho.';
  @override String get conv_message_optional => 'Ujumbe (hiari)';
  @override String get conv_send_request => 'Tuma ombi';
  @override String get conv_request_sent => 'Ombi limetumwa kikamilifu';
  @override String get conv_request_exists => 'Ombi tayari lipo kwa mtumiaji huyu';
  @override String get conv_select_contact => 'Tafadhali chagua angalau anwani moja';
  @override String get conv_waiting_connection => 'Inasubiri muunganisho kwa';
  @override String get conv_group_rpc_required => 'Kuunda kikundi kunahitaji wito wa seva';
  @override String get conv_page_title => 'Soga mpya';
  @override String conv_start(int count) => 'Anza ($count)';
  @override String get conv_search_label => 'Tafuta mtumiaji';
  @override String get conv_search_hint => 'Jina, ID ya THIX au nambari ya simu...';
  @override String get conv_group_name_label => 'Jina la kikundi';
  @override String get conv_group_name_hint => 'Mf: Timu ya Mradi wa Alpha';

  @override String get requests_page_title => 'Maombi ya Muunganisho';
  @override String get requests_reject_title => 'Kataa ombi';
  @override String get requests_reject_message => 'Una uhakika unataka kukataa ombi hili la muunganisho? Hatua hii haiwezi kutenduliwa.';
  @override String get requests_reject_confirm => 'Kataa';
  @override String get requests_rejected => 'Ombi limekataliwa';
  @override String get requests_reject_error => 'Hitilafu katika kukataa ombi';
  @override String get requests_accepted => 'Ombi limekubaliwa kikamilifu';
  @override String get requests_accept_error => 'Hitilafu katika kukubali ombi';

  @override String get call_history_title => 'Historia ya Simu';
  @override String get call_missed => 'Simu iliyokosa';
  @override String get call_incoming => 'Simu inayoingia';
  @override String get call_outgoing => 'Simu inayotoka';
  @override String get call_video => 'Simu ya video';
  @override String get call_audio => 'Simu ya sauti';

  // ============================================================================
  // RÉSEAU SOCIAL (NETWORK)
  // ============================================================================
  @override String get network_search_title => 'Tafuta';
  @override String get network_search_hint => 'Tafuta watu, machapisho, au jumuiya…';
  @override String get network_tab_people => 'Watu';
  @override String get network_tab_posts => 'Machapisho';
  @override String get network_tab_communities => 'Jumuiya';
  @override String get network_explore_title => 'Gundua Mtandao wa THIX';
  @override String get network_explore_subtitle => 'Tafuta watu, machapisho, au jumuiya';
  @override String get network_no_results_users => 'Hakuna watumiaji waliopatikana';
  @override String get network_no_results_posts => 'Hakuna machapisho yaliyopatikana';
  @override String get network_no_results_communities => 'Hakuna jumuiya zilizopatikana';
  @override String get network_request_sent => 'Ombi limetumwa kwa';
  @override String get network_request_error => 'Hitilafu katika kutuma ombi';

  @override String get community_create_title => 'Unda jumuiya';
  @override String get community_name_label => 'Jina la jumuiya';
  @override String get community_description_label => 'Maelezo';
  @override String get community_visibility_label => 'Mwonekano';
  @override String get community_public => 'Umma';
  @override String get community_private => 'Binafsi';
  @override String get community_join => 'Jiunge';
  @override String get community_leave => 'Ondoka';
  @override String get community_members => 'wanachama';
  @override String get community_admin => 'Msimamizi';

  // ============================================================================
  // PROFIL UTILISATEUR (PROFILE)
  // ============================================================================
  @override String get profile_settings => 'Mipangilio ya wasifu';
  @override String get profile_edit_bio => 'Hariri Bio';
  @override String get profile_no_bio => 'Hakuna wasifu unaopatikana kwa sasa.';
  @override String get profile_followers => 'Wafuasi';
  @override String get profile_following => 'Wanaofuatwa';
  @override String get profile_posts => 'Machapisho';
  @override String get profile_follow => 'Fuata';
  @override String get profile_unfollow => 'Unafuata';
  @override String get profile_following_loading => 'Inapakia…';
  @override String get profile_message => 'Ujumbe';
  @override String get profile_block_user => 'Mzuie mtumiaji huyu?';
  @override String get profile_block_message => 'Hutaona tena machapisho yao na hawataweza kuwasiliana nawe.';
  @override String get profile_block_confirm => 'Zuia';
  @override String get profile_blocked_success => 'Mtumiaji amezuiwa';
  @override String get profile_block_error => 'Hitilafu katika kuzuia mtumiaji';
  
  @override String get profile_report_user => 'Ripoti';
  @override String get profile_report_reason => 'Sababu';
  @override String get profile_report_details => 'Maelezo (hiari)';
  @override String get profile_report_spam => 'Spam';
  @override String get profile_report_inappropriate => 'Maudhui yasiyofaa';
  @override String get profile_report_harassment => 'Unyanyasaji';
  @override String get profile_report_impersonation => 'Kujifanya mwingine';
  @override String get profile_report_other => 'Mengine';
  @override String get profile_report_submit => 'Wasilisha ripoti';
  @override String get profile_report_success => 'Ripoti imewasilishwa';
  @override String get profile_report_duplicate => 'Tayari imeripotiwa';
  
  @override String get profile_private_gallery => 'Matunzio binafsi';
  @override String get profile_private_content_locked => 'Maudhui haya ni ya binafsi';
  @override String get profile_add_private_media => 'Ongeza kwenye matunzio binafsi';
  @override String get profile_no_private_media => 'Hakuna vyombo vya habari vya binafsi bado';
  @override String get profile_upload_processing => 'Inachakata…';
  
  @override String get profile_tab_bio => 'Bio';
  @override String get profile_tab_private_gallery => 'Matunzio binafsi';
  @override String get profile_tab_photos => 'Picha za Umma';
  @override String get profile_tab_videos => 'Video';
  @override String get profile_tab_audios => 'Sauti';
  @override String get profile_no_content => 'Hakuna maudhui';
  @override String get profile_pinned_post => 'Chapisho lililobandikwa';
  @override String get profile_view_post => 'Angalia chapisho';

  // ============================================================================
  // PARAMÈTRES GÉNÉRAUX & CHAT (SETTINGS)
  // ============================================================================
  @override String get settings_title => 'Mipangilio ya soga';
  @override String get settings_section_appearance => 'Mwonekano';
  @override String get settings_theme => 'Mandhari';
  @override String get settings_theme_light => 'Mwangaza';
  @override String get settings_theme_dark => 'Giza';
  @override String get settings_theme_system => 'Mfumo chaguo-msingi';
  @override String get settings_wallpaper => 'Picha ya mandharinyuma';
  @override String get settings_wallpaper_default => 'Chaguo-msingi';
  @override String get settings_wallpaper_custom => 'Maalum';
  
  @override String get settings_section_privacy => 'Faragha';
  @override String get settings_last_seen => 'Ilionekana mwisho';
  @override String get settings_visibility_everyone => 'Kila mtu';
  @override String get settings_visibility_contacts => 'Anwani zangu';
  @override String get settings_visibility_nobody => 'Hakuna mtu';
  @override String get settings_profile_photo => 'Picha ya wasifu';
  
  @override String get settings_section_notifications => 'Arifa';
  @override String get settings_messages => 'Ujumbe';
  @override String get settings_calls => 'Simu';
  
  @override String get settings_section_messages => 'Data na Hifadhi';
  @override String get settings_ephemeral => 'Ujumbe unaopotea';
  @override String get settings_auto_download => 'Kupakua media kiotomatiki';
  @override String get settings_download_wifi => 'Wi-Fi pekee';
  @override String get settings_download_mobile => 'Wi-Fi na Data ya Simu';
  @override String get settings_download_never => 'Kamwe';
  
  @override String get settings_section_account => 'Akaunti';
  @override String get settings_view_profile => 'Angalia wasifu wangu';
  @override String get settings_logout => 'Ondoka';

  @override String get settings_profile_edit => 'Hariri wasifu';
  @override String get settings_notifications => 'Arifa';
  @override String get settings_privacy => 'Faragha';
  @override String get settings_security => 'Usalama';
  @override String get settings_language => 'Lugha';
  @override String get settings_help_center => 'Kituo cha Msaada';
  @override String get settings_about => 'Kuhusu THIX';
  @override String get settings_version => 'Toleo';

  // ============================================================================
  // TRADUCTIONS DE LANGUAGE SHEET
  // ============================================================================
  @override String get settings_choose_language => 'Chagua Lugha';
  @override String get settings_system_default => 'Lugha ya mfumo';
  @override String get settings_language_change_failed => 'Imeshindwa kubadilisha lugha';

  // ============================================================================
  // SOS & URGENCE (EMERGENCY)
  // ============================================================================
  @override String get sos_button => 'Dharura';
  @override String get sos_button_label => 'Kitufe cha Dharura cha SOS';
  @override String get sos_button_hint => 'Shikilia kwa sekunde 2 ili kuwasha';
  @override String get sos_button_tooltip => 'Bonyeza na ushikilie kwa sekunde 2';
  @override String get sos_trigger_button => 'Washa SOS';
  @override String get sos_trigger_timeout => 'Ombi limechelewa. Tafadhali jaribu tena.';
  @override String get sos_trigger_error => 'Imeshindwa kuwasha SOS';
  @override String get sos_active => 'SOS Ipo Hai';
  @override String get sos_crisis_room => 'Chumba cha Mgogoro';
  @override String get sos_command_center => 'Kituo cha Amri';
  @override String get sos_incident => 'Tukio';
  @override String get sos_incident_unknown => 'Tukio lisilojulikana';
  @override String get sos_incident_not_found => 'Tukio halijapatikana';
  @override String get sos_circle => 'Mzunguko';
  @override String get sos_rescuers => 'Waokoaji';
  @override String get sos_rescuer => 'Mwokoaji';
  @override String get sos_my_rescuers => 'Waokoaji wangu';
  @override String get sos_duration => 'Muda';
  @override String get sos_identifier => 'Kitambulisho';
  @override String get sos_calling => 'Inapiga…';
  @override String get sos_call => 'Piga Simu';
  @override String get sos_available => 'Inapatikana';
  @override String get sos_unavailable => 'Haipatikani';
  @override String get sos_verified => 'Imethibitishwa';
  @override String get sos_end => 'Maliza';
  @override String get sos_end_sos => 'Maliza SOS';
  @override String get sos_cancel_sos => 'Ghairi SOS';
  @override String get sos_pin_required => 'PIN ya Usalama inahitajika';
  @override String get sos_cancelled => 'SOS Imeghairiwa';
  @override String get sos_resolved => 'SOS Imetatuliwa';
  @override String get sos_cancel_failed => 'Imeshindwa kughairi';
  @override String get sos_in_progress => 'Inaendelea';
  @override String get sos_history => 'Historia';
  @override String get sos_my_incidents => 'Matukio yangu';
  @override String get sos_no_incidents => 'Hakuna matukio bado';
  @override String get sos_incidents_appear_here => 'Maombi yako ya SOS yataonekana hapa';
  @override String get sos_history_error => 'Imeshindwa kupakia historia';
  @override String get sos_circle_1 => 'Mzunguko 1 – Kipaumbele';
  @override String get sos_circle_2 => 'Mzunguko 2 – Sekondari';
  @override String get sos_circle_3 => 'Mzunguko 3 – Dharura';
  @override String get sos_no_rescuers => 'Hakuna waokoaji';
  @override String get sos_add_first_rescuer => 'Ongeza mwasiliani wako wa kwanza wa dharura';
  @override String get sos_add_rescuer => 'Ongeza mwokoaji';
  @override String get sos_add_rescuer_info => 'Weka ID ya THIX ya mwokoaji. Jina na picha zitaletwa kiotomatiki.';
  @override String get sos_thix_id_label => 'ID ya THIX';
  @override String get sos_thix_id_hint => 'THIX-XXXX';

  // ============================================================================
  // CERTIFICATION
  // ============================================================================
  @override String get certification_title => 'Udhibitisho wa THIX';
  @override String get certification_apply => 'Omba udhibitisho';
  @override String get certification_status => 'Hali';
  @override String get certification_pending => 'Inasubiriwa';
  @override String get certification_approved => 'Imeidhinishwa';
  @override String get certification_rejected => 'Imekataliwa';
  @override String get certification_tier_bronze => 'Shaba';
  @override String get certification_tier_silver => 'Fedha';
  @override String get certification_tier_gold => 'Dhahabu';
  @override String get certification_tier_platinum => 'Platinamu';
  @override String get certification_benefits => 'Faida';
  @override String get certification_documents => 'Nyaraka zinazohitajika';
  @override String get certification_upload_doc => 'Pakia waraka';
  @override String get certification_review_progress => 'Inachunguzwa';
  @override String get certification_verified_account => 'Akaunti Iliyothibitishwa';

  // ============================================================================
  // ÉDUCATION & FORMATION (EDUCATION & TRAINING)
  // ============================================================================
  @override String get edu_nav_home => 'Mwanzo';
  @override String get edu_nav_learning => 'Mafunzo Yangu';
  @override String get edu_nav_library => 'Maktaba';
  @override String get edu_nav_certs => 'Vyeti';
  @override String get edu_nav_profile => 'Wasifu';
  
  @override String get edu_auth_required => 'Ingia ili kuona kozi zako';
  @override String get edu_login_required => 'Ingia ili kuona kozi zako';
  
  @override String get edu_learning_empty_title => 'Hakuna kozi inayoendelea';
  @override String get edu_learning_empty_desc => 'Jiandikishe katika kozi ili kuanza.';
  @override String get edu_no_courses => 'Hakuna kozi inayoendelea';
  @override String get edu_enroll_hint => 'Jiandikishe katika kozi ili kuanza.';
  @override String get edu_explore_btn => 'Gundua kozi';
  @override String get edu_completed => 'Imekamilika';
  
  @override String get edu_user_avatar => 'Picha ya Mtumiaji';
  @override String get edu_greeting => 'Habari,';
  @override String get edu_greeting_subtitle => 'Uko tayari kuboresha ujuzi wako?';
  @override String get edu_ready_to_learn => 'Uko tayari kuboresha ujuzi wako?';
  @override String get edu_learner => 'Mwanafunzi';
  @override String get edu_notifications => 'Arifa';
  @override String get edu_search_hint => 'Tafuta kozi, vyeti…';
  @override String get edu_browse => 'Vinjari';
  @override String get edu_library => 'Maktaba';
  @override String get edu_certs => 'Vyeti';
  @override String get edu_qa_browse => 'Vinjari';
  @override String get edu_instructor => 'Mwalimu';
  
  @override String get edu_top_formations => 'Kozi Bora';
  @override String get edu_awaited_formations => 'Zinazosubiriwa Zaidi';
  @override String get edu_awaited => 'Zinazosubiriwa Zaidi';
  @override String get edu_see_all => 'Angalia Katalogi';
  
  @override String edu_coming_soon(String category) => 'Kozi mpya za $category zinakuja hivi karibuni';
  @override String get edu_coming_soon_cat => 'Kozi mpya zinakuja hapa hivi karibuni';
  @override String get edu_locked_course => 'Inakuja hivi karibuni! (Kufunguliwa kunatarajiwa hivi karibuni)';
  @override String get edu_coming_soon_badge => 'INAFUNGULIWA HIVI KARIBUNI';
  @override String get edu_awaited_badge => 'Inakuja Hivi Karibuni';
  @override String get edu_awaited_locked => 'Imefungwa';
  @override String get edu_awaited_locked_msg => 'Inakuja hivi karibuni! (Kufunguliwa kunatarajiwa hivi karibuni)';
  
  @override String get edu_thix_academy => 'Chuo cha THIX';
  @override String get edu_scheduled_soon => 'Imepangwa kwa: Hivi karibuni';
  @override String get edu_new_program => 'PROGRAMU MPYA';
  @override String get edu_resume_learning => 'ENDELEA KUJIFUNZA';
  @override String get edu_resume => 'Endelea kujifunza';
  
  @override String get edu_catalog => 'Katalogi';
  @override String get edu_no_formations_cat => 'Hakuna kozi katika kitengo hiki';
  
  @override String get edu_my_library => 'Maktaba Yangu';
  @override String get edu_search_book_hint => 'Tafuta kwa kichwa au mwandishi...';
  @override String get edu_library_title => 'Maktaba yangu';
  @override String get edu_search_library => 'Tafuta kwa kichwa au mwandishi…';
  @override String get edu_shelves_empty => 'Rafu zako ni tupu.';
  @override String get edu_library_empty => 'Rafu zako ni tupu.';
  @override String get edu_no_result => 'Hakuna matokeo';
  @override String edu_search_no_results(String query) => 'Hakuna matokeo kwa "$query"';
  
  @override String get edu_shelf => 'Rafu';
  @override String get edu_books => 'vitabu';
  @override String get edu_all => 'Yote';
  @override String edu_shelf_info(String code, int count) => 'Rafu $code · Vitabu $count';
  @override String get edu_free => 'Bure';
  @override String get edu_deleted_in => 'Haitapatikana ndani ya';
  @override String edu_expires_in(String countdown) => 'Itaisha ndani ya $countdown';
  
  @override String get edu_certifications => 'Vyeti';
  @override String get edu_certs_title => 'Vyeti';
  @override String get edu_no_certs => 'Hakuna vyeti bado';
  @override String get edu_cert_expert => 'Cheti cha Utaalamu';
  @override String get edu_cert_expertise => 'Cheti cha Utaalamu';
  @override String edu_cert_issued(String date) => 'Kimetolewa mnamo $date';
  
  @override String get edu_pro_account => 'Akaunti ya Kitaalam';
  @override String get edu_profile_title => 'Akaunti ya Kitaalam';
  @override String get edu_instructor_space => 'Nafasi ya Mwalimu';
  @override String get edu_tools => 'Zana za Taasisi';
  @override String get edu_institutional_tools => 'Zana za Taasisi';
  @override String get edu_free_resources => 'Rasilimali Wazi';
  @override String get edu_masterclass => 'Madarasa ya Uzamili';
  @override String get edu_masterclasses => 'Madarasa ya Uzamili';
  @override String get edu_network => 'Mtandao na Ushauri';
  @override String get edu_mentorship => 'Mtandao na Ushauri';
  @override String get edu_events_agenda => 'Ajenda ya Matukio';
  @override String get edu_support => 'Msaada wa Kiufundi';
  @override String get edu_not_connected => 'Haujaunganishwa';

  @override String get training_title => 'Mafunzo';
  @override String get training_enroll => 'Jiandikishe';
  @override String get training_my_courses => 'Kozi Zangu';
  @override String get training_certificates => 'Vyeti Vyangu';
  @override String get training_progress => 'Maendeleo';
  @override String get training_lessons => 'Masomo';
  @override String get training_duration => 'Muda';
  @override String get training_level => 'Kiwango';
  @override String get training_beginner => 'Anayeanza';
  @override String get training_intermediate => 'Wastani';
  @override String get training_advanced => 'Mtaalam';
  @override String get training_start_course => 'Anza Kozi';
  @override String get training_continue_course => 'Endelea Kozi';

  // ============================================================================
  // EMPLOIS & RECRUTEMENT (JOBS & RECRUITING)
  // ============================================================================
  @override String get jobs_title => 'Kazi';
  @override String get jobs_search => 'Tafuta Kazi';
  @override String get jobs_apply => 'Tuma maombi';
  @override String get jobs_saved => 'Zilizohifadhiwa';
  @override String get jobs_applied => 'Maombi yaliyotumwa';
  @override String get jobs_company => 'Kampuni';
  @override String get jobs_location => 'Eneo';
  @override String get jobs_salary => 'Mshahara';
  @override String get jobs_type => 'Aina';
  @override String get jobs_full_time => 'Muda wote';
  @override String get jobs_part_time => 'Muda wa ziada';
  @override String get jobs_contract => 'Mkataba';
  @override String get jobs_internship => 'Mafunzo kwa vitendo';
  @override String get jobs_freelance => 'Kazi huru';
  @override String get jobs_remote => 'Kazi ya mbali';
  @override String get jobs_onsite => 'Eneo la kazi';
  @override String get jobs_hybrid => 'Mseto';
  @override String get jobs_experience => 'Uzoefu';
  @override String get jobs_no_experience => 'Anayeanza';
  @override String get jobs_junior => 'Mdogo';
  @override String get jobs_mid => 'Kati';
  @override String get jobs_senior => 'Mwandamizi';
  @override String get jobs_requirements => 'Mahitaji';
  @override String get jobs_responsibilities => 'Majukumu';
  @override String get jobs_benefits => 'Faida';
  @override String get jobs_apply_now => 'Tuma maombi sasa';
  @override String get jobs_application_sent => 'Maombi yametumwa';
  @override String get jobs_no_results => 'Hakuna kazi zilizopatikana';
  @override String get recruiter_title => 'Mwajiri';
  @override String get recruiter_post_job => 'Chapisha kazi';
  @override String get recruiter_candidates => 'Wagombea';
  @override String get recruiter_applications => 'Maombi';
  @override String get recruiter_interviews => 'Mahojiano';

  // ============================================================================
  // OPPORTUNITÉS (OPPORTUNITIES)
  // ============================================================================
  @override String get opportunities_title => 'Fursa';
  @override String get opportunities_business => 'Biashara';
  @override String get opportunities_investment => 'Uwekezaji';
  @override String get opportunities_partnership => 'Ubia';
  @override String get opportunities_grant => 'Ruzuku';
  @override String get opportunities_coming_soon => 'Inakuja hivi karibuni';

  // ============================================================================
  // MARCHÉ & E-COMMERCE (MARKET)
  // ============================================================================
  @override String get market_title => 'Soko la THIX';
  @override String get market_categories => 'Makundi';
  @override String get market_products => 'Bidhaa';
  @override String get market_services => 'Huduma';
  @override String get market_add_to_cart => 'Ongeza kwenye rukwama';
  @override String get market_buy_now => 'Nunua sasa';
  @override String get market_cart => 'Rukwama';
  @override String get market_checkout => 'Malipo';
  @override String get market_total => 'Jumla';
  @override String get market_delivery => 'Uletaji';
  @override String get market_seller => 'Muuzaji';
  @override String get market_rating => 'Ukadiriaji';
  @override String get market_reviews => 'Mapitio';
  @override String get market_in_stock => 'Ipo kwenye hisa';
  @override String get market_out_of_stock => 'Imeisha';
  @override String get market_add_to_favorites => 'Ongeza kwenye vipendwa';
  @override String get market_remove_from_cart => 'Ondoa kwenye rukwama';

  // ============================================================================
  // PORTEFEUILLE & ARGENT (WALLET & MONEY)
  // ============================================================================
  @override String get money_title => 'Mkoba wa THIX';
  @override String get money_balance => 'Salio';
  @override String get money_send => 'Tuma';
  @override String get money_receive => 'Pokea';
  @override String get money_history => 'Historia';
  @override String get money_transactions => 'Miamala';
  @override String get money_top_up => 'Weka Pesa';
  @override String get money_withdraw => 'Toa Pesa';
  @override String get money_transfer => 'Uhamisho';
  @override String get money_bills => 'Bili';
  @override String get money_recipients => 'Wapokeaji';
  @override String get money_add_recipient => 'Ongeza mpokeaji';
  @override String get money_amount => 'Kiasi';
  @override String get money_fee => 'Ada';
  @override String get money_reference => 'Kumbukumbu';
  @override String get money_confirm_transfer => 'Thibitisha Uhamisho';
  @override String get money_transfer_success => 'Uhamisho Umefaulu';
  @override String get money_transfer_failed => 'Uhamisho Umeshindwa';
  @override String get money_insufficient_funds => 'Salio halitoshi';

  // ============================================================================
  // ÉVÉNEMENTS & BILLETS (EVENTS & TICKETS)
  // ============================================================================
  @override String get events_title => 'Matukio';
  @override String get events_upcoming => 'Yajayo';
  @override String get events_past => 'Yaliyopita';
  
  @override String get event_share_cta => 'Weka nafasi yako kwenye THIX!';
  @override String get event_sold_out_title => 'Tukio limejaa';
  @override String get event_sold_out_msg => 'Nafasi zote zimewekwa kwa sasa. Jiunge na foleni ili kujulishwa ikiwa nafasi zitapatikana.';
  @override String get event_join_queue_confirm => 'Ungependa kujiunga na orodha ya kusubiri?';
  @override String get event_join_queue_btn => 'Jiunge na foleni';
  
  @override String get event_unfavorite => 'Ondoa kwenye vipendwa';
  @override String get event_favorite => 'Ongeza kwenye vipendwa';
  @override String get event_free => 'Bure';
  @override String get event_paid => 'Ya kulipwa';
  
  @override String get event_time_label => 'Saa';
  @override String get event_location_label => 'Eneo';
  @override String get event_address_label => 'Anwani halisi';
  @override String get event_organized_by => 'Imeandaliwa na';
  
  @override String get event_about_title => 'Kuhusu';
  @override String get event_no_description => 'Hakuna maelezo yanayopatikana kwa tukio hili.';
  @override String get event_tickets_title => 'Tiketi na Uhifadhi';
  
  @override String get event_sold_out_short => 'IMEJAA';
  @override String event_remaining_seats(String count) => 'Nafasi $count zimesalia';
  @override String get event_queue_btn => 'ORODHA YA KUSUBIRI';
  @override String get event_book_btn => 'HIFADHI';
  
  @override String get event_standard_entry => 'Kuingia kwa Kawaida';
  @override String get event_all_sold => 'Nafasi zote zimeuzwa';
  @override String get event_limited_seats => 'Nafasi chache';
  @override String get event_book_now_btn => 'HIFADHI SASA';
  
  @override String event_numbered_seats(String count) => 'Nafasi $count zenye nambari';
  @override String get event_choose_seats_btn => 'CHAGUA NAFASI ZANGU';
  @override String get event_from_price => 'Kuanzia';

  @override String get events_my_tickets => 'Tiketi Zangu';
  @override String get events_buy_ticket => 'Nunua Tiketi';
  @override String get events_ticket_price => 'Bei ya Tiketi';
  @override String get events_date => 'Tarehe';
  @override String get events_time => 'Saa';
  @override String get events_venue => 'Ukumbi';
  @override String get events_organizer => 'Mwandaji';
  @override String get events_attendees => 'Wanaohudhuria';
  @override String get events_seats_available => 'Nafasi zinazopatikana';
  @override String get events_sold_out => 'Imejaa';
  @override String get events_book_now => 'Hifadhi Sasa';
  @override String get events_ticket_type => 'Aina ya Tiketi';
  @override String get ticket_standard => 'Kawaida';
  @override String get ticket_vip => 'VIP';
  @override String get ticket_gold => 'Dhahabu';
  @override String get ticket_family => 'Familia';
  @override String get ticket_secure_ticket => 'Tiketi Salama';
  @override String get ticket_not_found => 'Tiketi haijapatikana';
  @override String get ticket_location => 'Eneo';
  @override String get ticket_pin_label => 'Msimbo wa PIN';
  @override String get ticket_show_qr => 'Onyesha QR';
  @override String get ticket_booking_id => 'Kitambulisho cha Uhifadhi';
  @override String get ticket_add_wallet => 'Mkoba';
  @override String get ticket_wallet_coming_soon => 'Ujumuishaji wa mkoba unakuja hivi karibuni';
  @override String get ticket_share => 'Shiriki';
  @override String get ticket_share_text => 'Tiketi yangu ya THIX';
  @override String get ticket_scan_info => 'Onyesha msimbo huu wa QR mlangoni';
  @override String get ticket_security_title => 'Usalama';
  @override String get ticket_enter_pin => 'Weka PIN yako';
  @override String get ticket_pin_hint => 'Msimbo wa nambari 4';
  @override String get ticket_pin_incorrect => 'PIN si sahihi';
  @override String get ticket_pin_too_many_attempts => 'Majaribio mengi mno';
  @override String get ticket_attempts_remaining => 'Majaribio yaliyosalia';
  @override String get tickets_ticket => 'Tiketi';
  @override String get tickets_completed => 'Zilizokamilika';
  @override String get tickets_no_tickets => 'Hakuna tiketi';
  @override String get tickets_no_tickets_desc => 'Uhifadhi wako utaonekana hapa';
  @override String get tickets_discover => 'Gundua';
  @override String get tickets_load_error => 'Imeshindwa kupakia tiketi zako';
  @override String tickets_quantity(int count) => count == 0 ? 'Hakuna tiketi' : (count == 1 ? 'Tiketi 1' : 'Tiketi $count');

  // ============================================================================
  // RÉSERVATIONS (RESERVATIONS)
  // ============================================================================
  @override String get reservation_title => 'Uhifadhi';
  @override String get reservation_hotel => 'Hoteli';
  @override String get reservation_restaurant => 'Mkahawa';
  @override String get reservation_transport => 'Usafiri';
  @override String get reservation_check_in => 'Kuingia';
  @override String get reservation_check_out => 'Kutoka';
  @override String get reservation_guests => 'Wageni';
  @override String get reservation_rooms => 'Vyumba';
  @override String get reservation_book => 'Hifadhi';
  @override String get reservation_cancel => 'Ghairi';
  @override String get reservation_modify => 'Rekebisha';
  @override String get reservation_confirm => 'Thibitisha Uhifadhi';
  @override String get reservation_my_bookings => 'Uhifadhi Wangu';

  // ============================================================================
  // SANTÉ (HEALTH)
  // ============================================================================
  @override String get health_title => 'Afya ya THIX';
  @override String get health_appointments => 'Uteuzi';
  @override String get health_doctors => 'Madaktari';
  @override String get health_hospitals => 'Hospitali';
  @override String get health_pharmacies => 'Maduka ya dawa';
  @override String get health_emergency => 'Dharura';
  @override String get health_medical_records => 'Rekodi za Matibabu';
  @override String get health_prescriptions => 'Maagizo ya Daktari';
  @override String get health_book_appointment => 'Weka Uteuzi';
  @override String get health_appointment_date => 'Tarehe ya Uteuzi';
  @override String get health_specialty => 'Umaalumu';
  @override String get health_consultation => 'Ushauri';
  @override String get health_telemedicine => 'Tiba mtandao';
  @override String get health_insurance => 'Bima';
  @override String get health_symptoms => 'Dalili';
  @override String get health_find_doctor => 'Tafuta Daktari';

  // ============================================================================
  // MÉDIA & INFOS (MEDIA & INFO)
  // ============================================================================
  @override String get media_title => 'Vyombo vya habari vya THIX';
  @override String get media_news => 'Habari';
  @override String get media_videos => 'Video';
  @override String get media_podcasts => 'Podcast';
  @override String get media_articles => 'Makala';
  @override String get media_live => 'Mubashara';
  @override String get media_categories => 'Makundi';
  @override String get media_bookmarks => 'Alamisho';
  @override String get media_share_article => 'Shiriki Makala';
  @override String get media_read_more => 'Soma Zaidi';
  @override String get media_published_on => 'Imechapishwa mnamo';
  @override String get media_author => 'Mwandishi';
  @override String get info_title => 'Habari';
  @override String get info_local => 'Ndani';
  @override String get info_national => 'Kitaifa';
  @override String get info_international => 'Kimataifa';
  @override String get info_sports => 'Michezo';
  @override String get info_culture => 'Utamaduni';
  @override String get info_economy => 'Uchumi';
  @override String get info_politics => 'Siasa';
  @override String get info_technology => 'Teknolojia';
  @override String get info_read_full => 'Soma Makala Kamili';

  // ============================================================================
  // MON PAYS (MY COUNTRY)
  // ============================================================================
  @override String get mon_pays_title => 'Nchi Yangu';
  @override String get mon_pays_regions => 'Mikoa';
  @override String get mon_pays_cities => 'Miji';
  @override String get mon_pays_culture => 'Utamaduni';
  @override String get mon_pays_history => 'Historia';
  @override String get mon_pays_tourism => 'Utalii';
  @override String get mon_pays_discover => 'Gundua';
  @override String get mon_pays_landmarks => 'Maeneo muhimu';
  @override String get mon_pays_traditions => 'Mila';

  // ============================================================================
  // COFFRE-FORT (VAULT)
  // ============================================================================
  @override String get vault_title => 'Kasha';
  @override String get vault_documents => 'Nyaraka';
  @override String get vault_photos => 'Picha';
  @override String get vault_videos => 'Video';
  @override String get vault_notes => 'Vidokezo';
  @override String get vault_passwords => 'Manenosiri';
  @override String get vault_add_document => 'Ongeza Waraka';
  @override String get vault_upload => 'Pakia';
  @override String get vault_encrypted => 'Imesimbwa';
  @override String get vault_backup => 'Hifadhi nakala';
  @override String get vault_restore => 'Rejesha';
  @override String get vault_share_secure => 'Ushirikishwaji Salama';
  @override String get vault_unlock => 'Fungua';
  @override String get vault_lock => 'Funga';

  // ============================================================================
  // PAIEMENT (PAYMENT)
  // ============================================================================
  @override String get payment_title => 'Malipo';
  @override String get payment_method => 'Njia ya Malipo';
  @override String get payment_card => 'Kadi ya Benki';
  @override String get payment_mobile_money => 'Pesa ya Simu';
  @override String get payment_bank_transfer => 'Uhamisho wa Benki';
  @override String get payment_cash => 'Fedha taslimu';
  @override String get payment_confirm => 'Thibitisha Malipo';
  @override String get payment_success => 'Malipo Yamefaulu';
  @override String get payment_failed => 'Malipo Yameshindwa';
  @override String get payment_processing => 'Inachakata…';
  @override String get payment_receipt => 'Stakabadhi';
  @override String get payment_invoice => 'Ankara';

  // ============================================================================
  // RECHERCHE (MISSING PERSONS / SEARCH)
  // ============================================================================
  @override String get search_title => 'Utafutaji wa THIX';
  @override String get search_subtitle => 'Watu Waliopotea na Arifa Rasmi';
  @override String get search_person_missing => 'Mtu Aliyepotea';
  @override String get search_person_wanted => 'Arifa Rasmi ya Utafutaji';
  @override String get search_report_missing => 'Ripoti Kupotea';
  @override String get search_report_found => 'Ripoti Kupatikana';
  @override String get search_details => 'Maelezo';
  @override String get search_contact_authorities => 'Wasiliana na Mamlaka';
  @override String get search_share_alert => 'Shiriki Arifa';
  @override String get search_last_seen => 'Ilionekana mwisho';
  @override String get search_description => 'Maelezo';
  @override String get search_age => 'Umri';
  @override String get search_height => 'Urefu';
  @override String get search_weight => 'Uzito';
  @override String get search_hair_color => 'Rangi ya nywele';
  @override String get search_eye_color => 'Rangi ya macho';
  @override String get search_distinguishing_marks => 'Alama tofautishi';
  @override String get search_clothing => 'Mavazi';
  @override String get search_circumstances => 'Mazingira';
  @override String get search_case_number => 'Nambari ya Kesi';
  @override String get search_reported_by => 'Imeripotiwa na';
  @override String get search_official_notice => 'Arifa Rasmi';
  @override String get search_community_alert => 'Arifa ya Jamii';

  // ============================================================================
  // À PROXIMITÉ & ALERTES (NEARBY ALERTS)
  // ============================================================================
  @override String get nearby_alerts_title => 'Arifa za Karibu';
  @override String get nearby_view_on_map => 'Angalia kwenye Ramani';
  @override String get nearby_map_coming_soon => 'Ramani kamili inakuja hivi karibuni';
  @override String get nearby_map_disabled => 'Ramani imezimwa (inasubiri API key)';
  @override String get nearby_active_alerts => 'Arifa Zinazofanya Kazi';
  @override String get nearby_missing => 'Alipotea';
  @override String get nearby_official => 'Rasmi';
  @override String get nearby_legend_missing => 'Mtu Aliyepotea';
  @override String get nearby_legend_official => 'Arifa Rasmi';
  @override String get nearby_legend_report => 'Ripoti';
  @override String get nearby_location_required => 'Wezesha Huduma za Mahali';
  @override String get nearby_location_subtitle => 'Tazama arifa zinazokuzunguka';

  // ============================================================================
  // ADMINISTRATION
  // ============================================================================
  @override String get admin_title => 'Utawala wa THIX';
  @override String get admin_dev_open => 'Maendeleo ya Wazi';
  @override String get admin_actions_section => 'Hatua';
  
  @override String get admin_events_title => 'Matukio';
  @override String get admin_events_create => 'Unda';
  @override String get admin_events_search_hint => 'Tafuta kwa kichwa...';
  @override String get admin_events_filter => 'Kichujio cha kategoria';
  @override String get admin_events_empty => 'Hakuna matukio yaliyopatikana';
  @override String get admin_events_no_permission => 'Huna ruhusa ya kufanya kitendo hiki';
  @override String get admin_events_delete_title => 'Futa?';
  @override String admin_events_delete_desc(String title) => 'Je, unataka kufuta $title? Kitendo hiki hakiwezi kutenduliwa.';

  @override String get admin_limits_purchase_rules => 'Sheria za Ununuzi';
  @override String get admin_limits_max_person => 'Kiwango cha juu / mtu (dunia nzima)';
  @override String get admin_limits_max_transaction => 'Kiwango cha juu / muamala (rukwama)';
  @override String get admin_limits_require_thix_id => 'Uthibitishaji wa ID ya THIX Unahitajika';
  @override String get admin_limits_require_thix_id_desc => 'Inapendekezwa kwa matukio yenye mahitaji makubwa.';
  @override String get admin_limits_info_title => 'Usanifu Salama';
  @override String get admin_limits_info_desc => 'Mipaka hii inatekelezwa na kuthibitishwa moja kwa moja na Edge Functions za SQL kwa wakati halisi ili kuzuia hali ya ushindani na udanganyifu.';

  @override String get admin_stat_events => 'Matukio';
  @override String get admin_stat_bookings => 'Uhifadhi';
  @override String get admin_stat_revenue => 'Mapato';
  @override String get admin_stat_queue => 'Foleni';
  @override String get admin_action_events => 'Matukio';
  @override String get admin_action_events_sub => '20 / ukurasa';
  @override String get admin_action_create => 'Unda';
  @override String get admin_action_create_sub => 'Pakia + Thibitisha';
  @override String get admin_action_seats => 'Viti';
  @override String get admin_action_seats_sub => 'Kundi la 200';
  @override String get admin_action_reservations => 'Uhifadhi';
  @override String get admin_action_reservations_sub => '50 / ukurasa + Vichujio';
  @override String get admin_action_limits => 'Kupinga Udanganyifu';
  @override String get admin_action_limits_sub => 'Mipaka';
  @override String get admin_action_analytics => 'Takwimu';
  @override String get admin_action_analytics_sub => 'RPC';
  @override String get admin_read_only => 'Kusoma Tu';
  @override String get admin_bookings_title => 'Uhifadhi • 50/ukurasa';
  @override String get admin_bookings_export => 'Usafirishaji wa seva unaendelea (kazi)';
  @override String get admin_bookings_details => 'Maelezo ya Tiketi';
  @override String get admin_bookings_event => 'Tukio';
  @override String get admin_bookings_unknown_event => 'Tukio lisilojulikana';
  @override String get admin_bookings_id => 'ID ya Uhifadhi';
  @override String get admin_bookings_quantity => 'Kiasi';
  @override String get admin_bookings_category => 'Kategoria';
  @override String get admin_bookings_amount => 'Kiasi cha pesa';
  @override String get admin_bookings_pin => 'PIN';
  @override String get admin_bookings_purchase_date => 'Tarehe ya Kununua';
  @override String get admin_bookings_close => 'Funga';
  @override String get admin_bookings_empty => 'Hakuna uhifadhi uliopatikana';
  @override String get admin_bookings_unknown_date => 'Tarehe isiyojulikana';
  @override String admin_bookings_places(int count) => 'Nafasi $count';
  @override String get admin_bookings_status_valid => 'Halali';
  @override String get admin_bookings_status_used => 'Imetumika';
  @override String get admin_bookings_status_cancelled => 'Imeghairiwa';
  @override String get admin_bookings_status_postponed => 'Imeahirishwa';
  @override String get admin_bookings_status_pending => 'Inasubiriwa';
  @override String admin_queue_title(int count) => 'Foleni ya Kusubiri • Wakati halisi ($count)';
  @override String get admin_queue_realtime_desc => 'Wakati halisi upo hai • Inajisasisha mtumiaji anapojiunga';
  @override String get admin_queue_empty => 'Foleni ni tupu';
  @override String get admin_queue_event_fallback => 'Tukio';
  @override String admin_queue_item_meta(String userId, int qty, String status) => 'Mtumiaji: $userId • Nafasi $qty • $status';
  @override String get admin_queue_notify => 'Taarifu';
  @override String get admin_queue_notified => 'Mtumiaji ametaarifiwa (itaisha ndani ya dakika 10)';
  @override String get admin_queue_position => 'Nafasi';
  @override String get admin_queue_places => 'Nafasi';
  @override String get admin_analytics_title => 'Takwimu • Utendaji';
  @override String get admin_analytics_fill_rate => 'Kiwango cha Ujazo';
  @override String get admin_analytics_avg_cart => 'Wastani wa Rukwama';
  @override String get admin_analytics_no_show => 'Hajafika';
  @override String get admin_analytics_rev_per_event => 'Mapato / tukio';
  @override String get admin_analytics_revenue_7d => 'Mapato ya Siku 7';
  @override String get admin_analytics_no_data => 'Hakuna data inapatikana';
  @override String get admin_analytics_error => 'Imeshindwa kupakia takwimu';
  @override String get admin_event_create => 'Unda Tukio';
  @override String get admin_event_edit => 'Hariri Tukio';
  @override String get admin_event_btn_create => 'Unda';
  @override String get admin_event_btn_save => 'Hifadhi';
  @override String get admin_event_cover => 'Picha ya Jalada';
  @override String get admin_event_banner => 'Bango';
  @override String get admin_event_title => 'Kichwa *';
  @override String get admin_event_desc => 'Maelezo *';
  @override String get admin_event_category => 'Kategoria';
  @override String get admin_event_subcategory => 'Kategoria ndogo';
  @override String get admin_event_datetime => 'Tarehe na Saa';
  @override String get admin_event_start => 'Mwanzo';
  @override String get admin_event_end => 'Mwisho (hiari)';
  @override String get admin_event_add_end => 'Ongeza Saa ya Mwisho';
  @override String get admin_event_city => 'Mji *';
  @override String get admin_event_location => 'Eneo *';
  @override String get admin_event_address => 'Anwani';
  @override String get admin_event_organizer => 'Mwandaji';
  @override String get admin_event_phone => 'Simu';
  @override String get admin_event_email => 'Barua pepe ya Mawasiliano';
  @override String get admin_event_tiers_title => 'Viwango na Uwezo';
  @override String get admin_event_add_tier_btn => 'Ongeza VVIP, VIP…';
  @override String get admin_event_status => 'Hali';
  @override String get admin_event_visibility => 'Mwonekano';
  @override String get admin_event_cat_concert => 'Tamasha';
  @override String get admin_event_cat_conference => 'Mkutano';
  @override String get admin_event_cat_sport => 'Michezo';
  @override String get admin_event_cat_festival => 'Tamasha la Sanaa';
  @override String get admin_event_cat_theatre => 'Ukumbi wa michezo';
  @override String get admin_event_cat_other => 'Mengine';
  @override String get admin_event_status_upcoming => 'Inayokuja';
  @override String get admin_event_status_ongoing => 'Inayoendelea';
  @override String get admin_event_status_completed => 'Imekamilika';
  @override String get admin_event_status_cancelled => 'Imeghairiwa';
  @override String get admin_event_vis_default => 'Inayokuja (chaguo-msingi)';
  @override String get admin_event_vis_recommended => 'Inapendekezwa';
  @override String get admin_event_vis_featured => 'Imeangaziwa';
  @override String get admin_event_dialog_add_tier => 'Ongeza kiwango';
  @override String get admin_event_dialog_name => 'Jina (mfano: VVIP)';
  @override String admin_event_dialog_price(String currency) => 'Bei ($currency)';
  @override String get admin_event_dialog_capacity => 'Uwezo';
  @override String get admin_event_dialog_cancel => 'Ghairi';
  @override String get admin_event_dialog_add => 'Ongeza';
  @override String get admin_event_err_readonly => 'Kusoma Tu';
  @override String get admin_event_err_min_tier => 'Kiwango kimoja angalau kinahitajika';
  @override String get admin_event_success => 'Tukio limehifadhiwa kikamilifu';
  @override String get admin_event_err_title_req => 'Kichwa kinahitajika';
  @override String get admin_event_err_desc_min => 'Angalau herufi 10';
  @override String get admin_event_err_city_req => 'Mji unahitajika';
  @override String get admin_event_err_loc_req => 'Eneo linahitajika';
  @override String get admin_seat_page_title => 'Ramani ya Viti na Bei';
  @override String get admin_seat_target_event => 'Tukio Lengwa';
  @override String get admin_seat_select_event => 'Chagua tukio';
  @override String admin_seat_max_limit(int count) => 'Kiwango cha juu viti $count';
  @override String admin_seat_generated(int count) => 'Viti $count vimetengenezwa';
  @override String get admin_seat_load_error => 'Imeshindwa kupakia viti';
  @override String get admin_seat_pricing_title => 'Bei Inayobadilika';
  @override String get admin_seat_layout_title => 'Muundo na Umbo';
  @override String get admin_seat_rows => 'Safu';
  @override String get admin_seat_per_row => 'Viti / safu';
  @override String get admin_seat_center_aisle => 'Njia ya Kati';
  @override String get admin_seat_aisle_desc => 'Nafasi tupu katikati';
  @override String get admin_seat_cats_per_row => 'Kategoria kwa kila safu';
  @override String get admin_seat_generating => 'Inatengeneza…';
  @override String admin_seat_generate_btn(int count) => 'Tengeneza viti $count';
  @override String get admin_seat_preview => 'Muonekano wa sasa wa mpangilio';
  @override String get admin_seat_no_seats => 'Hakuna viti vilivyotengenezwa';
  @override String get admin_seat_cat_standard => 'Kawaida';
  @override String get admin_seat_cat_vip => 'VIP';
  @override String get admin_seat_cat_gold => 'Dhahabu';
  @override String get admin_seat_cat_family => 'Familia';
  @override String get admin_seat_legend_reserved => 'Imehifadhiwa';
  @override String get admin_seat_legend_sold => 'Imeuzwa';
  @override String get seat_map_stage => 'Jukwaa';

  // ============================================================================
  // ERREURS & VALIDATION (ERRORS & VALIDATION)
  // ============================================================================
  @override String get error_generic => 'Hitilafu imetokea';
  @override String get error_validation => 'Data batili';
  @override String get error_file_too_large => 'Faili ni kubwa mno';
  @override String get error_unsupported_format => 'Muundo hauhimiliwi';
  @override String get error_permission_denied => 'Ruhusa imekataliwa';
  @override String get error_camera_unavailable => 'Kamera haipatikani';
  @override String get error_microphone_unavailable => 'Mikrofoni haipatikani';
  @override String get error_location_unavailable => 'Huduma za mahali hazipatikani';
  @override String get error_network => 'Hitilafu ya mtandao';
  @override String get error_timeout => 'Muda wa ombi umeisha';
  @override String get error_server => 'Hitilafu ya seva';
  @override String get error_not_found => 'Haikupatikana';

  // ============================================================================
  // TEMPS & DATES RELATIVES (RELATIVE DATES & TIMES)
  // ============================================================================
  @override String get common_just_now => 'Sasa hivi';
  @override String get common_in_the_future => 'Baadaye';
  @override String common_minutes_ago(int count) => count == 1 ? 'Dakika 1 iliyopita' : 'Dakika $count zilizopita';
  @override String common_hours_ago(int count) => count == 1 ? 'Saa 1 iliyopita' : 'Saa $count zilizopita';
  @override String common_days_ago(int count) => count == 1 ? 'Siku 1 iliyopita' : 'Siku $count zilizopita';
  @override String common_seconds_ago(int count) => count == 1 ? 'Sekunde 1 iliyopita' : 'Sekunde $count zilizopita';
  @override String common_weeks_ago(int count) => count == 1 ? 'Wiki 1 iliyopita' : 'Wiki $count zilizopita';
  @override String common_months_ago(int count) => count == 1 ? 'Mwezi 1 uliopita' : 'Miezi $count iliyopita';
  @override String common_years_ago(int count) => count == 1 ? 'Mwaka 1 uliopita' : 'Miaka $count iliyopita';
  @override String common_in_minutes(int count) => count == 1 ? 'Baada ya dakika 1' : 'Baada ya dakika $count';
  @override String common_in_hours(int count) => count == 1 ? 'Baada ya saa 1' : 'Baada ya saa $count';
  @override String common_in_days(int count) => count == 1 ? 'Baada ya siku 1' : 'Baada ya siku $count';
}
