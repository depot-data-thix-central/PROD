// lib/l10n/app_localizations_sw.dart
import 'dart:ui';
import 'app_localizations.dart';

class AppLocalizationsSw extends AppLocalizations {
  @override
  Locale get locale => const Locale('sw');

  // ============================================================================
  // COMMON & UI (JUMLA NA UI)
  // ============================================================================
  @override String get common_back => 'Rudi';
  @override String get common_close => 'Funga';
  @override String get common_cancel => 'Ghairi';
  @override String get common_confirm => 'Thibitisha';
  @override String get common_delete => 'Futa';
  @override String get common_add => 'Ongeza';
  @override String get common_edit => 'Hariri';
  @override String get common_save => 'Hifadhi';
  @override String get common_manage => 'Simamia';
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
  @override String get common_next => 'Ifuatayo';
  @override String get common_previous => 'Iliyotangulia';
  @override String get common_finish => 'Maliza';
  @override String get common_done => 'Imekamilika';
  @override String get common_error => 'Hitilafu';
  @override String get common_success => 'Imefanikiwa';
  @override String get common_loading => 'Inapakia…';
  @override String get common_please_wait => 'Tafadhali subiri…';
  @override String get common_today => 'Leo';
  @override String get common_yesterday => 'Jana';
  @override String get common_tomorrow => 'Kesho';
  @override String get common_home => 'Mwanzo';
  @override String get common_chat => 'Gumzo';
  @override String get common_map => 'Ramani';
  @override String get common_profile => 'Wasifu';
  @override String get common_menu => 'Menyu';
  @override String get common_notifications => 'Arifa';
  @override String get common_settings => 'Mipangilio';
  @override String get common_help => 'Msaada';
  @override String get common_about => 'Kuhusu';
  @override String get common_logout => 'Toka';
  @override String get common_login => 'Ingia';
  @override String get common_signup => 'Jisajili';
  @override String get common_yes => 'Ndiyo';
  @override String get common_no => 'Hapana';
  @override String get common_or => 'au';
  @override String get common_and => 'na';
  @override String get common_none => 'Hakuna';
  @override String get common_all => 'Zote';
  @override String get common_unknown => 'Haijulikani';
  @override String get common_enabled => 'Imewashwa';
  @override String get common_disabled => 'Imezimwa';
  @override String get common_clear => 'Futa';
  @override String get common_remove => 'Ondoa';

  @override
  String common_items(int count) => count == 0 ? 'Hakuna vipengele' : (count == 1 ? 'Kipengele 1' : 'Vipengele $count');
  @override
  String common_contacts(int count) => count == 0 ? 'Hakuna anwani' : (count == 1 ? 'Anwani 1' : 'Anwani $count');
  @override
  String common_messages(int count) => count == 0 ? 'Hakuna ujumbe' : (count == 1 ? 'Ujumbe 1' : 'Ujumbe $count');
  @override
  String common_days(int count) => count == 0 ? 'Siku 0' : (count == 1 ? 'Siku 1' : 'Siku $count');
  @override
  String common_hours(int count) => count == 0 ? 'Saa 0' : (count == 1 ? 'Saa 1' : 'Saa $count');
  @override
  String common_minutes(int count) => count == 0 ? 'Dakika 0' : (count == 1 ? 'Dakika 1' : 'Dakika $count');

  // ============================================================================
  // THIX MEDIA & IA SOURCES (VYANZO VYA THIX MEDIA NA IA)
  // ============================================================================
  @override String get live_send => 'Tuma';
  @override String get live_ending => 'Inamaliza mubashara...';
  @override String get live_network_quality => 'Ubora wa mtandao';
  @override String get source_type_official => 'Rasmi';
  @override String get source_type_world_bank => 'Benki ya Dunia';
  @override String get source_type_government => 'Serikali';
  @override String get source_type_default => 'Chanzo Kilichothibitishwa';
  @override String get source_aria_label => 'Chanzo cha Taarifa';

  // ============================================================================
  // AUTH & ONBOARDING (UTHIBITISHAJI NA MAELEKEZO)
  // ============================================================================
  @override String get auth_login => 'Ingia';
  @override String get auth_signup => 'Jisajili';
  @override String get auth_forgot_password => 'Umesahau nenosiri?';
  @override String get auth_reset_password => 'Weka upya nenosiri';
  @override String get auth_email => 'Barua pepe';
  @override String get auth_phone => 'Nambari ya simu';
  @override String get auth_password => 'Nenosiri';
  @override String get auth_confirm_password => 'Thibitisha nenosiri';
  @override String get auth_logout_confirm => 'Una uhakika unataka kutoka?';
  @override String get auth_welcome_back => 'Karibu tena';
  @override String get auth_welcome => 'Karibu';
  @override String get auth_no_account => 'Huna akaunti bado?';
  @override String get auth_has_account => 'Tayari una akaunti?';
  @override String get auth_invalid_email => 'Barua pepe si sahihi';
  @override String get auth_invalid_phone => 'Nambari ya simu si sahihi';
  @override String get auth_password_too_short => 'Nenosiri ni fupi sana (herufi 8 kwa kiwango cha chini)';
  @override String get auth_passwords_mismatch => 'Manenosiri hayalingani';
  @override String get auth_login_success => 'Umeingia kwa mafanikio';
  @override String get auth_signup_success => 'Akaunti imeundwa kwa mafanikio';
  @override String get auth_session_expired => 'Kipindi kimeisha, tafadhali ingia tena';
  @override String get auth_2fa_title => 'Uthibitishaji wa hatua mbili';
  @override String get auth_2fa_code => 'Nambari ya uthibitishaji';
  @override String get auth_verify_email => 'Thibitisha barua pepe';
  @override String get auth_verify_phone => 'Thibitisha simu';
  @override String get auth_biometric => 'Ingia kwa bayometriki';
  @override String get auth_biometric_prompt => 'Jithibitishe ili kuendelea';
  @override String get auth_full_name => 'Jina kamili';
  @override String get auth_first_name => 'Jina la kwanza';
  @override String get auth_last_name => 'Jina la ukoo';
  @override String get auth_birth_date => 'Tarehe ya kuzaliwa';
  @override String get auth_gender => 'Jinsia';
  @override String get auth_gender_male => 'Mwanaume';
  @override String get auth_gender_female => 'Mwanamke';
  @override String get auth_gender_other => 'Nyingine';
  @override String get auth_accept_terms => 'Nakubali masharti ya matumizi';
  @override String get auth_terms_required => 'Lazima ukubali masharti';
  @override String get auth_email_already_used => 'Barua pepe hii tayari inatumika';
  @override String get auth_phone_already_used => 'Nambari hii tayari inatumika';
  @override String get auth_create_account => 'Unda akaunti yangu';
  @override String get auth_already_have_account => 'Tayari nina akaunti';

  @override String get onboarding_welcome => 'Karibu kwenye THIX';
  @override String get onboarding_step_1_title => 'Muunganisho';
  @override String get onboarding_step_1_desc => 'Unda utambulisho wako salama wa THIX';
  @override String get onboarding_step_2_title => 'Ulinzi';
  @override String get onboarding_step_2_desc => 'Washa ulinzi wa saa 24/7';
  @override String get onboarding_step_3_title => 'Hatua';
  @override String get onboarding_step_3_desc => 'Taarifa waokozi wako ndani ya sekunde 2';
  @override String get onboarding_get_started => 'Anza';
  @override String get onboarding_skip => 'Ruka utangulizi';

  // ============================================================================
  // LOGIN ERRORS (MAKOSA YA KUINGIA)
  // ============================================================================
  @override String get login_title => 'Ingia kwenye THIX';
  @override String get login_subtitle => 'Karibu tena';
  @override String get login_identifier_label => 'Kitambulisho';
  @override String get login_identifier_hint => 'Barua pepe, simu au THIX ID';
  @override String get login_password_label => 'Nenosiri';
  @override String get login_password_hint => 'Nenosiri lako salama';
  @override String get login_remember_me => 'Nikumbuke';
  @override String get login_forgot_password => 'Umesahau nenosiri?';
  @override String get login_button => 'Ingia';
  @override String get login_verifying => 'Inathibitisha…';
  @override String get login_retry_in => 'Jaribu tena ndani ya';
  @override String get login_seconds_suffix => 's';
  @override String get login_biometric => 'AU ENDELEA NA';
  @override String get login_face_id => 'Face ID';
  @override String get login_touch_id => 'Touch ID';

  @override String get login_error_suspended => 'Akaunti hii imesimamishwa. Wasiliana na msaada.';
  @override String get login_error_not_active => 'Akaunti hii haijawashwa.';
  @override String get login_error_no_account => 'Hakuna akaunti iliyopatikana na taarifa hizi.';
  @override String get login_error_mfa_required => 'Uthibitishaji wa hatua mbili unahitajika.';

  @override String get auth_error_identifier_required => 'Kitambulisho kinahitajika';
  @override String get auth_error_password_required => 'Nenosiri linahitajika';
  @override String get auth_error_thix_id_login_not_available => 'Kuingia kwa THIX ID hakupatikani kwa sasa';
  @override String get auth_error_sign_in_failed => 'Kuingia kumeshindikana. Angalia vitambulisho vyako.';
  @override String get auth_error_email_not_verified => 'Tafadhali thibitisha barua pepe yako kabla ya kuingia';
  @override String get auth_error_server_misconfiguration => 'Hitilafu ya usanidi wa seva';
  @override String get auth_error_account_already_exists => 'Akaunti yenye kitambulisho hiki tayari ipo';
  @override String get auth_error_account_exists_wrong_password => 'Akaunti hii ipo lakini nenosiri si sahihi';
  @override String get auth_error_account_exists_new_otp_sent => 'Nambari mpya ya OTP imetumwa kwa anwani yako';
  @override String get auth_error_invalid_otp => 'Nambari ya OTP si sahihi au imeisha muda';
  @override String get auth_error_otp_expired => 'Nambari ya OTP imeisha muda';
  @override String get auth_error_network => 'Hitilafu ya muunganisho wa mtandao. Angalia intaneti yako.';
  @override String get auth_error_rate_limit => 'Majaribio mengi mno. Tafadhali subiri kidogo.';
  @override String get auth_error_technical => 'Hitilafu ya kiufundi imetokea. Tafadhali jaribu tena.';
  @override String get auth_error_user_mismatch => 'Kutolingana kwa mtumiaji kumegunduliwa';
  @override String get auth_error_profile_update_failed => 'Imeshindikana kusasisha wasifu';
  @override String get auth_error_mark_email_verified_failed => 'Imeshindikana kuthibitisha barua pepe';
  @override String get auth_error_qr_token_generation_failed => 'Imeshindikana kutengeneza tokeni ya QR';
  @override String get auth_error_finalize_registration_failed => 'Imeshindikana kukamilisha usajili';
  @override String get auth_error_consume_qr_token_failed => 'Imeshindikana kutumia tokeni ya QR';
  @override String get auth_error_resend_otp_failed => 'Imeshindikana kutuma tena OTP';
  @override String get auth_error_phone_auth_not_available => 'Uthibitishaji wa simu haupatikani';
  @override String get auth_error_delete_account_not_available => 'Kufuta akaunti hakupatikani kwa sasa';
  @override String get auth_error_update_email_failed => 'Imeshindikana kusasisha barua pepe';
  @override String get auth_error_reset_password_failed => 'Imeshindikana kuweka upya nenosiri';
  @override String get auth_error_sign_up_failed => 'Imeshindikana kuunda akaunti';
  @override String get auth_info_otp_sent => 'Nambari ya uthibitishaji imetumwa';

  // ============================================================================
  // REGISTRATION (USAJILI)
  // ============================================================================
  @override String get reg_step1_title => 'Wasifu wako';
  @override String get reg_step1_subtitle => 'Tuanze na taarifa za msingi';
  @override String get reg_full_name_label => 'Jina kamili';
  @override String get reg_full_name_hint => 'Jina na Ukoo';
  @override String get reg_dob_label => 'Tarehe ya kuzaliwa';
  @override String get reg_country_label => 'Nchi ya makazi';
  @override String get reg_occupation_label => 'Kazi / Shughuli';
  @override String get reg_occupation_hint => 'Mf: Mprogramu, Mwanafunzi, Mjasiriamali';
  @override String get reg_next => 'Ifuatayo';

  @override String get reg_step2_title => 'Linda akaunti yako';
  @override String get reg_step2_subtitle => 'Unda vitambulisho vyako vya kuingia';
  @override String get reg_email_label => 'Anwani ya barua pepe';
  @override String get reg_email_hint => 'barua.yako@mfano.com';
  @override String get reg_phone_label => 'Nambari ya simu';
  @override String get reg_phone_hint => '+255 7XX XXX XXX';
  @override String get reg_password_label => 'Nenosiri';
  @override String get reg_password_hint => 'Kiwango cha chini herufi 8';
  @override String get reg_confirm_password_label => 'Thibitisha nenosiri';
  @override String get reg_confirm_password_hint => 'Andika tena nenosiri lako';
  @override String get reg_strength_label => 'Nguvu ya nenosiri';
  @override String get reg_strength_very_weak => 'Dhaifu sana';
  @override String get reg_strength_weak => 'Dhaifu';
  @override String get reg_strength_medium => 'Wastani';
  @override String get reg_strength_strong => 'Imara';
  @override String get reg_strength_excellent => 'Bora';

  @override String get reg_identity_title => 'Utambulisho wa THIX';
  @override String get reg_thix_chat_label => 'Jina la mtumiaji la THIX Chat';
  @override String get reg_thix_chat_hint => 'Mf: juma.hassan (pekee)';

  @override String get reg_verification_title => 'Uthibitishaji';
  @override String get reg_get_otp => 'Pata nambari ya uthibitishaji';
  @override String get reg_code_sent_resend => 'Tuma tena nambari';
  @override String get reg_resend_in => 'Tuma tena ndani ya';
  @override String get reg_seconds_short => 's';
  @override String get reg_otp_label => 'Nambari ya uthibitishaji (OTP)';
  @override String get reg_validate_activate => 'Thibitisha na washa';
  @override String get reg_activating => 'Inawasha…';

  @override String get reg_congrats => 'Hongera!';
  @override String get reg_welcome_message => 'Karibu kwenye mfumo wa THIX,';
  @override String get reg_id_card_title => 'KADI YA UTAMBULISHO WA KIDIJITALI YA THIX';
  @override String get reg_official_thix_id => 'THIX ID RASMI';
  @override String get reg_generating => 'Inatengeneza…';
  @override String get reg_copy_thix_id => 'Nakili THIX ID';
  @override String get reg_thix_id_copied => 'THIX ID imenakiliwa kwenye ubao wa kunakili';
  @override String get reg_go_to_dashboard => 'Nenda kwenye dashibodi';
  @override String get reg_summary => 'Muhtasari wa usajili';
  @override String get reg_mobile_label => 'Simu ya mkononi';
  @override String get reg_not_provided => 'Haijajazwa';

  // ============================================================================
  // HOME & DASHBOARD (MWANZO NA DASHIBODI)
  // ============================================================================
  @override String get home_search_hint => 'Tafuta huduma au anwani…';
  @override String get home_greeting => 'Habari';
  @override String get home_greeting_time => 'Habari za jioni';
  @override String get home_welcome_back => 'Karibu tena';
  @override String get home_language_kiswahili => 'Kiswahili';
  @override String get home_banner_default_tag => 'MPANGO WA VIJANA';
  @override String get home_banner_default_title => 'Gundua fursa na matukio mapya';

  @override String get cert_pending => 'Uthibitisho unasubiri';
  @override String get cert_tier_ladder => 'Kiwango cha sasa kinakaguliwa';
  @override String get cert_view => 'Tazama';

  @override String get quick_sona => 'THIX Sona';
  @override String get quick_doc => 'Nyaraka zangu';
  @override String get quick_chat => 'Gumzo';
  @override String get quick_sos => 'Dharura';
  @override String get service_sante => 'THIX Afya';
  @override String get service_market => 'THIX Soko';
  @override String get service_money => 'THIX Pochi';
  @override String get service_reservation => 'Uhifadhi';
  @override String get service_mon_pays => 'Nchi Yangu';
  @override String get service_emploi => 'Ajira';
  @override String get service_formations => 'Mafunzo';
  @override String get service_opportunites => 'Fursa';
  @override String get service_infos => 'Habari';
  @override String get service_events => 'Matukio';
  @override String get service_media => 'THIX Media';
  @override String get service_vault => 'Hazina';
  @override String get service_network => 'Mtandao';
  @override String get service_certification => 'Uthibitisho';

  // ============================================================================
  // CHAT (GUMZO)
  // ============================================================================
  @override String get chatlist_network => 'Mtandao';
  @override String get chatlist_discussions => 'Majadiliano';
  @override String get chatlist_create_new => 'Unda majadiliano mapya';
  @override String get chatlist_calls => 'Simu';
  @override String get chatlist_settings => 'Mipangilio';

  @override String get chat_unknown_user => 'Mtumiaji asiyejulikana';
  @override
  String chat_members(int count) => count == 1 ? 'Mwanachama 1' : 'Wanachama $count';
  @override String get chat_video_call => 'Simu ya video';
  @override String get chat_audio_call => 'Simu ya sauti';
  @override String get chat_escalate => 'Pandisha';
  @override String get chat_history => 'Historia';
  @override String get chat_group_info => 'Taarifa za kikundi';
  @override String get chat_file => 'Faili';
  @override String get chat_sticker => 'Stika';
  @override String get chat_ephemeral => 'Ya muda mfupi';
  @override String get chat_protected => 'Imelindwa';
  @override String get chat_internal_note => 'Kumbuka ya ndani';
  @override String get chat_send => 'Tuma';
  @override String get chat_recording => 'Inarekodi';
  @override String get chat_stop_recording => 'Simamisha';
  @override String get chat_write_message => 'Andika ujumbe...';
  @override String get chat_record_audio => 'Rekodi sauti';
  @override String get chat_emojis => 'Emoji';
  @override String get chat_reactions => 'Mitikio';
  @override String get chat_flags => 'Bendera';
  @override String get chat_callback => 'Piga simu tena';
  @override String get chat_typing => 'anaandika...';
  @override String get chat_pause => 'Simamisha';
  @override String get chat_play => 'Cheza';

  @override String get conv_status_connected => 'Ameunganishwa';
  @override String get conv_status_pending => 'Inasubiri';
  @override String get conv_status_rejected => 'Imekataliwa';
  @override String get conv_cannot_self => 'Huwezi kujiongeza mwenyewe';
  @override String get conv_request_pending => 'Ombi la muunganisho linasubiri';
  @override String get conv_request_rejected => 'Ombi la muunganisho limekataliwa';
  @override String get conv_request_to => 'Tuma ombi kwa';
  @override String get conv_request_hint => 'Ongeza ujumbe wa hiari kwenye ombi lako la muunganisho.';
  @override String get conv_message_optional => 'Ujumbe (hiari)';
  @override String get conv_send_request => 'Tuma ombi';
  @override String get conv_request_sent => 'Ombi limetumwa kwa mafanikio';
  @override String get conv_request_exists => 'Tayari kuna ombi kwa mtumiaji huyu';
  @override String get conv_select_contact => 'Tafadhali chagua angalau anwani moja';
  @override String get conv_waiting_connection => 'Inasubiri muunganisho kwa';
  @override String get conv_group_rpc_required => 'Kuunda kikundi kunahitaji mwito wa seva';
  @override String get conv_page_title => 'Majadiliano mapya';
  @override
  String conv_start(int count) => 'Anza ($count)';
  @override String get conv_search_label => 'Tafuta mtumiaji';
  @override String get conv_search_hint => 'Jina, THIX ID au nambari ya simu...';
  @override String get conv_group_name_label => 'Jina la kikundi';
  @override String get conv_group_name_hint => 'Mf: Timu ya Mradi Alpha';

  @override String get requests_page_title => 'Maombi ya muunganisho';
  @override String get requests_reject_title => 'Kataa ombi';
  @override String get requests_reject_message => 'Una uhakika unataka kukataa ombi hili la muunganisho? Kitendo hiki hakiwezi kurudishwa.';
  @override String get requests_reject_confirm => 'Kataa';
  @override String get requests_rejected => 'Ombi limekataliwa';
  @override String get requests_reject_error => 'Hitilafu wakati wa kukataa ombi';
  @override String get requests_accepted => 'Ombi limekubaliwa kwa mafanikio';
  @override String get requests_accept_error => 'Hitilafu wakati wa kukubali ombi';

  @override String get call_history_title => 'Historia ya simu';
  @override String get call_missed => 'Simu isiyojibiwa';
  @override String get call_incoming => 'Simu inayoingia';
  @override String get call_outgoing => 'Simu inayotoka';
  @override String get call_video => 'Simu ya video';
  @override String get call_audio => 'Simu ya sauti';

  // ============================================================================
  // NETWORK (MTANDAO)
  // ============================================================================
  @override String get network_search_title => 'Tafuta';
  @override String get network_search_hint => 'Tafuta watu, machapisho au jamii…';
  @override String get network_tab_people => 'Watu';
  @override String get network_tab_posts => 'Machapisho';
  @override String get network_tab_communities => 'Jamii';
  @override String get network_explore_title => 'Chunguza mtandao wa THIX';
  @override String get network_explore_subtitle => 'Tafuta watu, machapisho au jamii';
  @override String get network_no_results_users => 'Hakuna watumiaji waliopatikana';
  @override String get network_no_results_posts => 'Hakuna machapisho yaliyopatikana';
  @override String get network_no_results_communities => 'Hakuna jamii zilizopatikana';
  @override String get network_request_sent => 'Ombi limetumwa kwa';
  @override String get network_request_error => 'Hitilafu wakati wa kutuma ombi';

  @override String get community_create_title => 'Unda jamii';
  @override String get community_name_label => 'Jina la jamii';
  @override String get community_description_label => 'Maelezo';
  @override String get community_visibility_label => 'Uonekano';
  @override String get community_public => 'Ya umma';
  @override String get community_private => 'Ya kibinafsi';
  @override String get community_join => 'Jiunge';
  @override String get community_leave => 'Ondoka';
  @override String get community_members => 'wanachama';
  @override String get community_admin => 'Msimamizi';

  // ============================================================================
  // PROFILE (WASIFU)
  // ============================================================================
  @override String get profile_settings => 'Mipangilio ya wasifu';
  @override String get profile_edit_bio => 'Hariri wasifu';
  @override String get profile_no_bio => 'Hakuna wasifu kwa sasa.';
  @override String get profile_followers => 'Wafuasi';
  @override String get profile_following => 'Anafuata';
  @override String get profile_posts => 'Machapisho';
  @override String get profile_follow => 'Fuata';
  @override String get profile_unfollow => 'Anafuata';
  @override String get profile_following_loading => 'Inapakia…';
  @override String get profile_message => 'Ujumbe';
  @override String get profile_block_user => 'Zuia mtumiaji huyu?';
  @override String get profile_block_message => 'Hutaona tena machapisho yake na hataweza kuingiliana nawe.';
  @override String get profile_block_confirm => 'Zuia';
  @override String get profile_blocked_success => 'Mtumiaji amezuiwa';
  @override String get profile_block_error => 'Hitilafu wakati wa kuzuia mtumiaji';

  @override String get profile_report_user => 'Ripoti';
  @override String get profile_report_reason => 'Sababu';
  @override String get profile_report_details => 'Maelezo (hiari)';
  @override String get profile_report_spam => 'Taka';
  @override String get profile_report_inappropriate => 'Maudhui yasiyofaa';
  @override String get profile_report_harassment => 'Unyanyasaji';
  @override String get profile_report_impersonation => 'Kuiga utambulisho';
  @override String get profile_report_other => 'Nyingine';
  @override String get profile_report_submit => 'Tuma ripoti';
  @override String get profile_report_success => 'Ripoti imetumwa';
  @override String get profile_report_duplicate => 'Tayari imeripotiwa';

  @override String get profile_private_gallery => 'Matunzio ya kibinafsi';
  @override String get profile_private_content_locked => 'Maudhui haya ni ya kibinafsi';
  @override String get profile_add_private_media => 'Ongeza kwenye matunzio yangu ya kibinafsi';
  @override String get profile_no_private_media => 'Hakuna media ya kibinafsi kwa sasa';
  @override String get profile_upload_processing => 'Inachakata…';

  @override String get profile_tab_bio => 'Wasifu';
  @override String get profile_tab_private_gallery => 'Matunzio ya kibinafsi';
  @override String get profile_tab_photos => 'Picha za umma';
  @override String get profile_tab_videos => 'Video';
  @override String get profile_tab_audios => 'Sauti';
  @override String get profile_no_content => 'Hakuna maudhui';
  @override String get profile_pinned_post => 'Chapisho lililobandikwa';
  @override String get profile_view_post => 'Tazama chapisho';

  // ============================================================================
  // SETTINGS (MIPANGILIO)
  // ============================================================================
  @override String get settings_title => 'Mipangilio ya gumzo';
  @override String get settings_section_appearance => 'Muonekano';
  @override String get settings_theme => 'Mandhari';
  @override String get settings_theme_light => 'Mwanga';
  @override String get settings_theme_dark => 'Giza';
  @override String get settings_theme_system => 'Mfumo';
  @override String get settings_wallpaper => 'Mandharinyuma';
  @override String get settings_wallpaper_default => 'Chaguo-msingi';
  @override String get settings_wallpaper_custom => 'Maalum';

  @override String get settings_section_privacy => 'Faragha';
  @override String get settings_last_seen => 'Mara ya mwisho kuonekana';
  @override String get settings_visibility_everyone => 'Kila mtu';
  @override String get settings_visibility_contacts => 'Anwani zangu';
  @override String get settings_visibility_nobody => 'Hakuna mtu';
  @override String get settings_profile_photo => 'Picha ya wasifu';

  @override String get settings_section_notifications => 'Arifa';
  @override String get settings_messages => 'Ujumbe';
  @override String get settings_calls => 'Simu';

  @override String get settings_section_messages => 'Ujumbe na data';
  @override String get settings_ephemeral => 'Ujumbe wa muda mfupi';
  @override String get settings_auto_download => 'Upakuaji wa otomatiki wa media';
  @override String get settings_download_wifi => 'Wi-Fi pekee';
  @override String get settings_download_mobile => 'Wi-Fi na data ya simu';
  @override String get settings_download_never => 'Kamwe';

  @override String get settings_section_account => 'Akaunti';
  @override String get settings_view_profile => 'Tazama wasifu wangu';
  @override String get settings_logout => 'Toka';

  @override String get settings_profile_edit => 'Hariri wasifu';
  @override String get settings_notifications => 'Arifa';
  @override String get settings_privacy => 'Faragha';
  @override String get settings_security => 'Usalama';
  @override String get settings_language => 'Lugha';
  @override String get settings_help_center => 'Kituo cha msaada';
  @override String get settings_about => 'Kuhusu THIX';
  @override String get settings_version => 'Toleo';

  @override String get settings_choose_language => 'Chagua lugha';
  @override String get settings_system_default => 'Chaguo-msingi la mfumo';
  @override String get settings_language_change_failed => 'Imeshindikana kubadilisha lugha';

  // ============================================================================
  // SOS (DHARURA)
  // ============================================================================
  @override String get sos_button => 'Dharura';
  @override String get sos_button_label => 'Kitufe cha dharura cha SOS';
  @override String get sos_button_hint => 'Bonyeza kwa sekunde 2 ili kuwasha';
  @override String get sos_button_tooltip => 'Shikilia kwa sekunde 2';
  @override String get sos_trigger_button => 'Washa SOS';
  @override String get sos_trigger_timeout => 'Muda umeisha. Tafadhali jaribu tena.';
  @override String get sos_trigger_error => 'Imeshindikana kuwasha SOS';
  @override String get sos_active => 'SOS Inatumika';
  @override String get sos_crisis_room => 'Chumba cha mgogoro';
  @override String get sos_command_center => 'Kituo cha amri';
  @override String get sos_incident => 'Tukio';
  @override String get sos_incident_unknown => 'Tukio lisilojulikana';
  @override String get sos_incident_not_found => 'Tukio halikupatikana';
  @override String get sos_circle => 'Duara';
  @override String get sos_rescuers => 'Waokozi';
  @override String get sos_rescuer => 'Mwokoz';
  @override String get sos_my_rescuers => 'Waokozi wangu';
  @override String get sos_duration => 'Muda';
  @override String get sos_identifier => 'Kitambulisho';
  @override String get sos_calling => 'Inapiga simu…';
  @override String get sos_call => 'Piga simu';
  @override String get sos_available => 'Yupo';
  @override String get sos_unavailable => 'Hayupo';
  @override String get sos_verified => 'Amethibitishwa';
  @override String get sos_end => 'Maliza';
  @override String get sos_end_sos => 'Maliza SOS';
  @override String get sos_cancel_sos => 'Ghairi SOS';
  @override String get sos_pin_required => 'PIN ya usalama inahitajika';
  @override String get sos_cancelled => 'SOS imeghairiwa';
  @override String get sos_resolved => 'SOS imetatuliwa';
  @override String get sos_cancel_failed => 'Imeshindikana kughairi';
  @override String get sos_in_progress => 'Inaendelea';
  @override String get sos_history => 'Historia';
  @override String get sos_my_incidents => 'Matukio yangu';
  @override String get sos_no_incidents => 'Hakuna matukio bado';
  @override String get sos_incidents_appear_here => 'Maombi yako ya SOS yataonekana hapa';
  @override String get sos_history_error => 'Imeshindikana kupakia historia';
  @override String get sos_circle_1 => 'Duara 1 – Kipaumbele';
  @override String get sos_circle_2 => 'Duara 2 – Sekondari';
  @override String get sos_circle_3 => 'Duara 3 – Dharura';
  @override String get sos_no_rescuers => 'Hakuna waokozi';
  @override String get sos_add_first_rescuer => 'Ongeza anwani yako ya kwanza ya dharura';
  @override String get sos_add_rescuer => 'Ongeza mwokoz';
  @override String get sos_add_rescuer_info => 'Andika THIX ID ya mwokoz. Jina na picha zitapatikana kiotomatiki.';
  @override String get sos_thix_id_label => 'THIX ID';
  @override String get sos_thix_id_hint => 'THIX-XXXX';

  // ============================================================================
  // CERTIFICATION (UTHIBITISHO)
  // ============================================================================
  @override String get certification_title => 'Uthibitisho wa THIX';
  @override String get certification_apply => 'Omba uthibitisho';
  @override String get certification_status => 'Hali';
  @override String get certification_pending => 'Inasubiri';
  @override String get certification_approved => 'Imeidhinishwa';
  @override String get certification_rejected => 'Imekataliwa';
  @override String get certification_tier_bronze => 'Shaba';
  @override String get certification_tier_silver => 'Fedha';
  @override String get certification_tier_gold => 'Dhahabu';
  @override String get certification_tier_platinum => 'Platinamu';
  @override String get certification_benefits => 'Faida';
  @override String get certification_documents => 'Nyaraka zinazohitajika';
  @override String get certification_upload_doc => 'Pakia nyaraka';
  @override String get certification_review_progress => 'Inakaguliwa';
  @override String get certification_verified_account => 'Akaunti iliyothibitishwa';

  // ============================================================================
  // EDUCATION (ELIMU)
  // ============================================================================
  @override String get edu_nav_home => 'Mwanzo';
  @override String get edu_nav_learning => 'Mafunzo yangu';
  @override String get edu_nav_library => 'Maktaba';
  @override String get edu_nav_certs => 'Vyeti';
  @override String get edu_nav_profile => 'Wasifu';

  @override String get edu_auth_required => 'Ingia ili kuona kozi zako';
  @override String get edu_login_required => 'Ingia ili kuona kozi zako';

  @override String get edu_learning_empty_title => 'Hakuna kozi zinazoendelea';
  @override String get edu_learning_empty_desc => 'Jiandikishe kwenye kozi ili kuanza.';
  @override String get edu_no_courses => 'Hakuna kozi zinazoendelea';
  @override String get edu_enroll_hint => 'Jiandikishe kwenye kozi ili kuanza.';
  @override String get edu_explore_btn => 'Chunguza kozi';
  @override String get edu_completed => 'Imekamilika';

  @override String get edu_user_avatar => 'Picha ya mtumiaji';
  @override String get edu_greeting => 'Habari,';
  @override String get edu_greeting_subtitle => 'Uko tayari kuboresha ujuzi wako?';
  @override String get edu_ready_to_learn => 'Uko tayari kuendeleza ujuzi wako?';
  @override String get edu_learner => 'Mwanafunzi';
  @override String get edu_notifications => 'Arifa';
  @override String get edu_search_hint => 'Tafuta kozi, vyeti…';
  @override String get edu_browse => 'Vinjari';
  @override String get edu_library => 'Maktaba';
  @override String get edu_certs => 'Vyeti';
  @override String get edu_qa_browse => 'Vinjari';
  @override String get edu_instructor => 'Mwalimu';

  @override String get edu_top_formations => 'Kozi bora';
  @override String get edu_awaited_formations => 'Zinazosubiriwa zaidi';
  @override String get edu_awaited => 'Zinazosubiriwa zaidi';
  @override String get edu_see_all => 'Tazama orodha';

  @override
  String edu_coming_soon(String category) => 'Kozi mpya za $category zinakuja hivi karibuni';
  @override String get edu_coming_soon_cat => 'Kozi mpya zinakuja hapa hivi karibuni';
  @override String get edu_locked_course => 'Inakuja hivi karibuni! (Kufunguliwa kutarajiwa hivi karibuni)';
  @override String get edu_coming_soon_badge => 'INAFUNGULIWA HIVI KARIBUNI';
  @override String get edu_awaited_badge => 'Inakuja hivi karibuni';
  @override String get edu_awaited_locked => 'Imefungwa';
  @override String get edu_awaited_locked_msg => 'Inakuja hivi karibuni! (Kufunguliwa kutarajiwa hivi karibuni)';

  @override String get edu_thix_academy => 'Chuo cha THIX';
  @override String get edu_scheduled_soon => 'Imepangwa: Hivi karibuni';
  @override String get edu_new_program => 'MPANGO MPYA';
  @override String get edu_resume_learning => 'ENDELEA NA MAFUNZO';
  @override String get edu_resume => 'Endelea na mafunzo';

  @override String get edu_catalog => 'Orodha';
  @override String get edu_no_formations_cat => 'Hakuna kozi katika kategoria hii';

  @override String get edu_my_library => 'Maktaba Yangu';
  @override String get edu_search_book_hint => 'Tafuta kwa kichwa au mwandishi...';
  @override String get edu_library_title => 'Maktaba yangu';
  @override String get edu_search_library => 'Tafuta kwa kichwa au mwandishi…';
  @override String get edu_shelves_empty => 'Rafu zako ni tupu.';
  @override String get edu_library_empty => 'Rafu zako ni tupu.';
  @override String get edu_no_result => 'Hakuna matokeo';
  @override
  String edu_search_no_results(String query) => 'Hakuna matokeo ya "$query"';

  @override String get edu_shelf => 'Rafu';
  @override String get edu_books => 'vitabu';
  @override String get edu_all => 'Zote';
  @override
  String edu_shelf_info(String code, int count) => 'Rafu $code · Vitabu $count';
  @override String get edu_free => 'Bure';
  @override String get edu_deleted_in => 'Imefutwa ndani ya';
  @override
  String edu_expires_in(String countdown) => 'Inaisha ndani ya $countdown';

  @override String get edu_certifications => 'Vyeti';
  @override String get edu_certs_title => 'Vyeti';
  @override String get edu_no_certs => 'Hakuna vyeti bado';
  @override String get edu_cert_expert => 'Cheti cha Utaalamu';
  @override String get edu_cert_expertise => 'Cheti cha utaalamu';
  @override
  String edu_cert_issued(String date) => 'Imetolewa tarehe $date';

  @override String get edu_pro_account => 'Akaunti ya Kitaalamu';
  @override String get edu_profile_title => 'Akaunti ya kitaalamu';
  @override String get edu_instructor_space => 'Eneo la Mwalimu';
  @override String get edu_tools => 'Zana za Taasisi';
  @override String get edu_institutional_tools => 'Zana za taasisi';
  @override String get edu_free_resources => 'Rasilimali huria';
  @override String get edu_masterclass => 'Masterclasses';
  @override String get edu_masterclasses => 'Masterclasses';
  @override String get edu_network => 'Mtandao na Ushauri';
  @override String get edu_mentorship => 'Mitandao na ushauri';
  @override String get edu_events_agenda => 'Ratiba ya matukio';
  @override String get edu_support => 'Msaada wa Kiufundi';
  @override String get edu_not_connected => 'Hujaunganishwa';

  @override String get training_title => 'Mafunzo';
  @override String get training_enroll => 'Jiandikishe';
  @override String get training_my_courses => 'Kozi zangu';
  @override String get training_certificates => 'Vyeti vyangu';
  @override String get training_progress => 'Maendeleo';
  @override String get training_lessons => 'Masomo';
  @override String get training_duration => 'Muda';
  @override String get training_level => 'Kiwango';
  @override String get training_beginner => 'Mwanzo';
  @override String get training_intermediate => 'Kati';
  @override String get training_advanced => 'Juu';
  @override String get training_start_course => 'Anza kozi';
  @override String get training_continue_course => 'Endelea na kozi';

  // ============================================================================
  // JOBS (AJIRA)
  // ============================================================================
  @override String get jobs_title => 'Ajira';
  @override String get jobs_search => 'Tafuta kazi';
  @override String get jobs_apply => 'Omba';
  @override String get jobs_saved => 'Zilizohifadhiwa';
  @override String get jobs_applied => 'Maombi yaliyotumwa';
  @override String get jobs_company => 'Kampuni';
  @override String get jobs_location => 'Mahali';
  @override String get jobs_salary => 'Mshahara';
  @override String get jobs_type => 'Aina';
  @override String get jobs_full_time => 'Muda wote';
  @override String get jobs_part_time => 'Muda mfupi';
  @override String get jobs_contract => 'Mkataba';
  @override String get jobs_internship => 'Mafunzo kazini';
  @override String get jobs_freelance => 'Freelance';
  @override String get jobs_remote => 'Kazi ya mbali';
  @override String get jobs_onsite => 'Kazini';
  @override String get jobs_hybrid => 'Mseto';
  @override String get jobs_experience => 'Uzoefu';
  @override String get jobs_no_experience => 'Hakuna uzoefu';
  @override String get jobs_junior => 'Mwanzo';
  @override String get jobs_mid => 'Kati';
  @override String get jobs_senior => 'Mkuu';
  @override String get jobs_requirements => 'Mahitaji';
  @override String get jobs_responsibilities => 'Majukumu';
  @override String get jobs_benefits => 'Faida';
  @override String get jobs_apply_now => 'Omba sasa';
  @override String get jobs_application_sent => 'Ombi limetumwa';
  @override String get jobs_no_results => 'Hakuna ajira zilizopatikana';
  @override String get recruiter_title => 'Mwajiri';
  @override String get recruiter_post_job => 'Chapisha nafasi';
  @override String get recruiter_candidates => 'Wagombea';
  @override String get recruiter_applications => 'Maombi';
  @override String get recruiter_interviews => 'Mahojiano';

  // ============================================================================
  // OPPORTUNITIES (FURASA)
  // ============================================================================
  @override String get opportunities_title => 'Fursa';
  @override String get opportunities_business => 'Biashara';
  @override String get opportunities_investment => 'Uwekezaji';
  @override String get opportunities_partnership => 'Ushirikiano';
  @override String get opportunities_grant => 'Ruzuku';
  @override String get opportunities_coming_soon => 'Inakuja hivi karibuni';

  // ============================================================================
  // MARKET (SOKO)
  // ============================================================================
  @override String get market_title => 'Soko la THIX';
  @override String get market_categories => 'Kategoria';
  @override String get market_products => 'Bidhaa';
  @override String get market_services => 'Huduma';
  @override String get market_add_to_cart => 'Ongeza kwenye kapu';
  @override String get market_buy_now => 'Nunua sasa';
  @override String get market_cart => 'Kapu';
  @override String get market_checkout => 'Maliza ununuzi';
  @override String get market_total => 'Jumla';
  @override String get market_delivery => 'Usafirishaji';
  @override String get market_seller => 'Muuzaji';
  @override String get market_rating => 'Ukadiriaji';
  @override String get market_reviews => 'Maoni';
  @override String get market_in_stock => 'Ipo stokini';
  @override String get market_out_of_stock => 'Imeisha stokini';
  @override String get market_add_to_favorites => 'Ongeza kwenye vipendwa';
  @override String get market_remove_from_cart => 'Ondoa kwenye kapu';

  // ============================================================================
  // MONEY (FEDHA)
  // ============================================================================
  @override String get money_title => 'Pochi ya THIX';
  @override String get money_balance => 'Salio';
  @override String get money_send => 'Tuma';
  @override String get money_receive => 'Pokea';
  @override String get money_history => 'Historia';
  @override String get money_transactions => 'Shughuli';
  @override String get money_top_up => 'Jaza';
  @override String get money_withdraw => 'Toa';
  @override String get money_transfer => 'Hamisha';
  @override String get money_bills => 'Bili';
  @override String get money_recipients => 'Wapokeaji';
  @override String get money_add_recipient => 'Ongeza mpokeaji';
  @override String get money_amount => 'Kiasi';
  @override String get money_fee => 'Ada';
  @override String get money_reference => 'Kumbukumbu';
  @override String get money_confirm_transfer => 'Thibitisha uhamisho';
  @override String get money_transfer_success => 'Uhamisho umefanikiwa';
  @override String get money_transfer_failed => 'Uhamisho umeshindikana';
  @override String get money_insufficient_funds => 'Salio halitoshi';

  // ============================================================================
  // EVENTS (MATUKIO)
  // ============================================================================
  @override String get events_title => 'Matukio';
  @override String get events_upcoming => 'Yajayo';
  @override String get events_past => 'Yaliyopita';

  @override String get event_share_cta => 'Hifadhi nafasi yako kwenye THIX!';
  @override String get event_sold_out_title => 'Tukio Limeisha';
  @override String get event_sold_out_msg => 'Nafasi zote zimehifadhiwa. Jiunge kwenye orodha ya kusubiri ili kuarifiwa.';
  @override String get event_join_queue_confirm => 'Unataka kujiunga kwenye orodha ya kusubiri?';
  @override String get event_join_queue_btn => 'Jiunge kwenye orodha';

  @override String get event_unfavorite => 'Ondoa kwenye vipendwa';
  @override String get event_favorite => 'Ongeza kwenye vipendwa';
  @override String get event_free => 'Bure';
  @override String get event_paid => 'Inalipwa';

  @override String get event_time_label => 'Saa';
  @override String get event_location_label => 'Mahali';
  @override String get event_address_label => 'Anwani kamili';
  @override String get event_organized_by => 'Imeandaliwa na';

  @override String get event_about_title => 'Kuhusu';
  @override String get event_no_description => 'Hakuna maelezo yanayopatikana kwa tukio hili.';
  @override String get event_tickets_title => 'Vitikari na Uhifadhi';

  @override String get event_sold_out_short => 'IMEISHA';
  @override
  String event_remaining_seats(String count) => 'Nafasi $count zilizobaki';
  @override String get event_queue_btn => 'ORODHA YA KUSUBIRI';
  @override String get event_book_btn => 'HIFADHI';

  @override String get event_standard_entry => 'Kuingia Kawaida';
  @override String get event_all_sold => 'Viti vyote vimeuzwa';
  @override String get event_limited_seats => 'Nafasi chache';
  @override String get event_book_now_btn => 'HIFADHI SASA';

  @override
  String event_numbered_seats(String count) => 'Viti $count vyenye nambari';
  @override String get event_choose_seats_btn => 'CHAGUA VITI VYANGU';
  @override String get event_from_price => 'Kuanzia';

  @override String get events_my_tickets => 'Vitikari vyangu';
  @override String get events_buy_ticket => 'Nunua kitikiti';
  @override String get events_ticket_price => 'Bei ya kitikiti';
  @override String get events_date => 'Tarehe';
  @override String get events_time => 'Saa';
  @override String get events_venue => 'Mahali';
  @override String get events_organizer => 'Muandaaji';
  @override String get events_attendees => 'Washiriki';
  @override String get events_seats_available => 'Nafasi zinazopatikana';
  @override String get events_sold_out => 'Imeisha';
  @override String get events_book_now => 'Hifadhi sasa';
  @override String get events_ticket_type => 'Aina ya kitikiti';
  @override String get ticket_standard => 'Kawaida';
  @override String get ticket_vip => 'VIP';
  @override String get ticket_gold => 'Dhahabu';
  @override String get ticket_family => 'Familia';
  @override String get ticket_secure_ticket => 'Kitikiti salama';
  @override String get ticket_not_found => 'Kitikiti hakikupatikana';
  @override String get ticket_location => 'Mahali';
  @override String get ticket_pin_label => 'Nambari ya PIN';
  @override String get ticket_show_qr => 'Onyesha QR';
  @override String get ticket_booking_id => 'ID ya uhifadhi';
  @override String get ticket_add_wallet => 'Pochi';
  @override String get ticket_wallet_coming_soon => 'Muunganisho wa pochi unakuja hivi karibuni';
  @override String get ticket_share => 'Shiriki';
  @override String get ticket_share_text => 'Kitikiti changu cha THIX';
  @override String get ticket_scan_info => 'Onyesha nambari hii ya QR kwenye mlango';
  @override String get ticket_security_title => 'Usalama';
  @override String get ticket_enter_pin => 'Andika PIN yako';
  @override String get ticket_pin_hint => 'Nambari ya tarakimu 4';
  @override String get ticket_pin_incorrect => 'Nambari si sahihi';
  @override String get ticket_pin_too_many_attempts => 'Majaribio mengi mno';
  @override String get ticket_attempts_remaining => 'Majaribio yaliyobaki';
  @override String get tickets_ticket => 'Kitikiti';
  @override String get tickets_completed => 'Imekamilika';
  @override String get tickets_no_tickets => 'Hakuna vitikiti';
  @override String get tickets_no_tickets_desc => 'Uhifadhi wako utaonekana hapa';
  @override String get tickets_discover => 'Gundua';
  @override String get tickets_load_error => 'Imeshindikana kupakia vitikiti vyako';
  @override
  String tickets_quantity(int count) => count == 0 ? 'Hakuna vitikiti' : (count == 1 ? 'Kitikiti 1' : 'Vitiki $count');

  // ============================================================================
  // RESERVATION (UHIFADHI)
  // ============================================================================
  @override String get reservation_title => 'Uhifadhi';
  @override String get reservation_hotel => 'Hoteli';
  @override String get reservation_restaurant => 'Mgahawa';
  @override String get reservation_transport => 'Usafiri';
  @override String get reservation_check_in => 'Kuingia';
  @override String get reservation_check_out => 'Kutoka';
  @override String get reservation_guests => 'Wageni';
  @override String get reservation_rooms => 'Vyumba';
  @override String get reservation_book => 'Hifadhi';
  @override String get reservation_cancel => 'Ghairi';
  @override String get reservation_modify => 'Badilisha';
  @override String get reservation_confirm => 'Thibitisha uhifadhi';
  @override String get reservation_my_bookings => 'Uhifadhi wangu';

  // ============================================================================
  // HEALTH (AFYA)
  // ============================================================================
  @override String get health_title => 'THIX Afya';
  @override String get health_appointments => 'Miadi';
  @override String get health_doctors => 'Madaktari';
  @override String get health_hospitals => 'Hospitali';
  @override String get health_pharmacies => 'Famasia';
  @override String get health_emergency => 'Dharura';
  @override String get health_medical_records => 'Rekodi za matibabu';
  @override String get health_prescriptions => 'Maagizo ya dawa';
  @override String get health_book_appointment => 'Weka miadi';
  @override String get health_appointment_date => 'Tarehe ya miadi';
  @override String get health_specialty => 'Utaalamu';
  @override String get health_consultation => 'Ushauri';
  @override String get health_telemedicine => 'Tiba ya mbali';
  @override String get health_insurance => 'Bima';
  @override String get health_symptoms => 'Dalili';
  @override String get health_find_doctor => 'Tafuta daktari';

  // ============================================================================
  // MEDIA (MEDIA)
  // ============================================================================
  @override String get media_title => 'THIX Media';
  @override String get media_news => 'Habari';
  @override String get media_videos => 'Video';
  @override String get media_podcasts => 'Podcasts';
  @override String get media_articles => 'Makala';
  @override String get media_live => 'Moja kwa moja';
  @override String get media_categories => 'Kategoria';
  @override String get media_bookmarks => 'Alamisho';
  @override String get media_share_article => 'Shiriki makala';
  @override String get media_read_more => 'Soma zaidi';
  @override String get media_published_on => 'Imechapishwa tarehe';
  @override String get media_author => 'Mwandishi';
  @override String get info_title => 'Taarifa';
  @override String get info_local => 'Mitaa';
  @override String get info_national => 'Kitaifa';
  @override String get info_international => 'Kimataifa';
  @override String get info_sports => 'Michezo';
  @override String get info_culture => 'Utamaduni';
  @override String get info_economy => 'Uchumi';
  @override String get info_politics => 'Siasa';
  @override String get info_technology => 'Teknolojia';
  @override String get info_read_full => 'Soma makala kamili';

  // ============================================================================
  // MON PAYS (NCHI YANGU)
  // ============================================================================
  @override String get mon_pays_title => 'Nchi Yangu';
  @override String get mon_pays_regions => 'Mikoa';
  @override String get mon_pays_cities => 'Miji';
  @override String get mon_pays_culture => 'Utamaduni';
  @override String get mon_pays_history => 'Historia';
  @override String get mon_pays_tourism => 'Utalii';
  @override String get mon_pays_discover => 'Gundua';
  @override String get mon_pays_landmarks => 'Vivutio';
  @override String get mon_pays_traditions => 'Tamaduni';

  // ============================================================================
  // VAULT (HAZINA)
  // ============================================================================
  @override String get vault_title => 'Hazina';
  @override String get vault_documents => 'Nyaraka';
  @override String get vault_photos => 'Picha';
  @override String get vault_videos => 'Video';
  @override String get vault_notes => 'Maelezo';
  @override String get vault_passwords => 'Manenosiri';
  @override String get vault_add_document => 'Ongeza nyaraka';
  @override String get vault_upload => 'Pakia';
  @override String get vault_encrypted => 'Imesimbwa kwa njia fiche';
  @override String get vault_backup => 'Hifadhi nakala';
  @override String get vault_restore => 'Rejesha';
  @override String get vault_share_secure => 'Kushiriki salama';
  @override String get vault_unlock => 'Fungua';
  @override String get vault_lock => 'Funga';

  // ============================================================================
  // PAYMENT (MALIPO)
  // ============================================================================
  @override String get payment_title => 'Malipo';
  @override String get payment_method => 'Njia ya malipo';
  @override String get payment_card => 'Kadi ya benki';
  @override String get payment_mobile_money => 'Mobile Money';
  @override String get payment_bank_transfer => 'Uhamisho wa benki';
  @override String get payment_cash => 'Taslimu';
  @override String get payment_confirm => 'Thibitisha malipo';
  @override String get payment_success => 'Malipo yamefanikiwa';
  @override String get payment_failed => 'Malipo yameshindikana';
  @override String get payment_processing => 'Inachakata…';
  @override String get payment_receipt => 'Risiti';
  @override String get payment_invoice => 'Ankara';

  // ============================================================================
  // SEARCH (UTAFUTAJI)
  // ============================================================================
  @override String get search_title => 'THIX Utafutaji';
  @override String get search_subtitle => 'Watu waliopotea na wanaotafutwa';
  @override String get search_person_missing => 'Mtu aliyepotea';
  @override String get search_person_wanted => 'Anayetafutwa rasmi';
  @override String get search_report_missing => 'Ripoti kupotea';
  @override String get search_report_found => 'Ripoti amepatikana';
  @override String get search_details => 'Maelezo';
  @override String get search_contact_authorities => 'Wasiliana na mamlaka';
  @override String get search_share_alert => 'Shiriki tahadhari';
  @override String get search_last_seen => 'Mara ya mwisho kuonekana';
  @override String get search_description => 'Maelezo';
  @override String get search_age => 'Umri';
  @override String get search_height => 'Urefu';
  @override String get search_weight => 'Uzito';
  @override String get search_hair_color => 'Rangi ya nywele';
  @override String get search_eye_color => 'Rangi ya macho';
  @override String get search_distinguishing_marks => 'Alama maalum';
  @override String get search_clothing => 'Mavazi';
  @override String get search_circumstances => 'Hali';
  @override String get search_case_number => 'Nambari ya kesi';
  @override String get search_reported_by => 'Imeripotiwa na';
  @override String get search_official_notice => 'Taarifa rasmi';
  @override String get search_community_alert => 'Tahadhari ya jamii';

  // ============================================================================
  // NEARBY (KARIBU)
  // ============================================================================
  @override String get nearby_alerts_title => 'Tahadhari za karibu';
  @override String get nearby_view_on_map => 'Tazama kwenye ramani';
  @override String get nearby_map_coming_soon => 'Ramani ya skrini nzima inakuja hivi karibuni';
  @override String get nearby_map_disabled => 'Ramani imezimwa (inasubiri ufunguo wa API)';
  @override String get nearby_active_alerts => 'Tahadhari zinazotumika';
  @override String get nearby_missing => 'Amepea';
  @override String get nearby_official => 'Rasmi';
  @override String get nearby_legend_missing => 'Amepea';
  @override String get nearby_legend_official => 'Taarifa rasmi';
  @override String get nearby_legend_report => 'Ripoti';
  @override String get nearby_location_required => 'Washa mahali';
  @override String get nearby_location_subtitle => 'Tazama tahadhari zinazokuzunguka';

  // ============================================================================
  // ADMIN (USIMAMIZI)
  // ============================================================================
  @override String get admin_title => 'Usimamizi wa THIX';
  @override String get admin_dev_open => 'Maendeleo yamefunguliwa';
  @override String get admin_actions_section => 'Vitendo';

  @override String get admin_events_title => 'Matukio';
  @override String get admin_events_create => 'Unda';
  @override String get admin_events_search_hint => 'Tafuta kwa kichwa...';
  @override String get admin_events_filter => 'Kichujio cha kategoria';
  @override String get admin_events_empty => 'Hakuna matukio yaliyopatikana';
  @override String get admin_events_no_permission => 'Huna ruhusa ya kutekeleza kitendo hiki';
  @override String get admin_events_delete_title => 'Futa?';
  @override
  String admin_events_delete_desc(String title) => 'Unataka kufuta $title? Kitendo hiki hakiwezi kurudishwa.';

  @override String get admin_limits_purchase_rules => 'Sheria za ununuzi';
  @override String get admin_limits_max_person => 'Kiwango cha juu / mtu (jumla)';
  @override String get admin_limits_max_transaction => 'Kiwango cha juu / shughuli (kapu)';
  @override String get admin_limits_require_thix_id => 'Uthibitishaji wa THIX ID unahitajika';
  @override String get admin_limits_require_thix_id_desc => 'Inapendekezwa kwa matukio yenye mahitaji makubwa.';
  @override String get admin_limits_info_title => 'Usanidi Salama';
  @override String get admin_limits_info_desc => 'Mipaka hii inatumika na kuthibitishwa moja kwa moja na kazi za SQL (Edge Functions) kwa wakati halisi kuzuia hali yoyote ya mbio (ula wa rushwa).';

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
  @override String get admin_action_limits => 'Kuzuia ulaghai';
  @override String get admin_action_limits_sub => 'Mipaka';
  @override String get admin_action_analytics => 'Uchambuzi';
  @override String get admin_action_analytics_sub => 'RPC';
  @override String get admin_read_only => 'Kusoma pekee';
  @override String get admin_bookings_title => 'Uhifadhi • 50/ukurasa';
  @override String get admin_bookings_export => 'Usafirishaji wa seva unaendelea (kazi)';
  @override String get admin_bookings_details => 'Maelezo ya kitikiti';
  @override String get admin_bookings_event => 'Tukio';
  @override String get admin_bookings_unknown_event => 'Tukio lisilojulikana';
  @override String get admin_bookings_id => 'ID ya uhifadhi';
  @override String get admin_bookings_quantity => 'Idadi';
  @override String get admin_bookings_category => 'Kategoria';
  @override String get admin_bookings_amount => 'Kiasi';
  @override String get admin_bookings_pin => 'PIN';
  @override String get admin_bookings_purchase_date => 'Tarehe ya ununuzi';
  @override String get admin_bookings_close => 'Funga';
  @override String get admin_bookings_empty => 'Hakuna uhifadhi';
  @override String get admin_bookings_unknown_date => 'Tarehe isiyojulikana';
  @override
  String admin_bookings_places(int count) => 'Nafasi $count';
  @override String get admin_bookings_status_valid => 'Sahihi';
  @override String get admin_bookings_status_used => 'Imetumika';
  @override String get admin_bookings_status_cancelled => 'Imeghairiwa';
  @override String get admin_bookings_status_postponed => 'Imeahirishwa';
  @override String get admin_bookings_status_pending => 'Inasubiri';
  @override
  String admin_queue_title(int count) => 'Foleni • Wakati halisi ($count)';
  @override String get admin_queue_realtime_desc => 'Wakati halisi unatumika • Onyesha upya kiotomatiki watumiaji wanapoingia';
  @override String get admin_queue_empty => 'Hakuna kusubiri';
  @override String get admin_queue_event_fallback => 'Tukio';
  @override
  String admin_queue_item_meta(String userId, int qty, String status) => 'Mtumiaji: $userId • Nafasi $qty • $status';
  @override String get admin_queue_notify => 'Arifu';
  @override String get admin_queue_notified => 'Mtumiaji amearifiwa (inaisha ndani ya dakika 10)';
  @override String get admin_queue_position => 'Nafasi';
  @override String get admin_queue_places => 'Nafasi';
  @override String get admin_analytics_title => 'Uchambuzi • Utendaji';
  @override String get admin_analytics_fill_rate => 'Kiwango cha kujaza';
  @override String get admin_analytics_avg_cart => 'Kapu ya wastani';
  @override String get admin_analytics_no_show => 'Hakuhudhuria';
  @override String get admin_analytics_rev_per_event => 'Mapato / tukio';
  @override String get admin_analytics_revenue_7d => 'Mapato ya siku 7';
  @override String get admin_analytics_no_data => 'Hakuna data';
  @override String get admin_analytics_error => 'Imeshindikana kupakia takwimu';
  @override String get admin_event_create => 'Unda tukio';
  @override String get admin_event_edit => 'Hariri tukio';
  @override String get admin_event_btn_create => 'Unda';
  @override String get admin_event_btn_save => 'Hifadhi';
  @override String get admin_event_cover => 'Jalada';
  @override String get admin_event_banner => 'Bango';
  @override String get admin_event_title => 'Kichwa *';
  @override String get admin_event_desc => 'Maelezo *';
  @override String get admin_event_category => 'Kategoria';
  @override String get admin_event_subcategory => 'Kategoria ndogo';
  @override String get admin_event_datetime => 'Tarehe na saa';
  @override String get admin_event_start => 'Kuanza';
  @override String get admin_event_end => 'Kuisha (hiari)';
  @override String get admin_event_add_end => 'Ongeza';
  @override String get admin_event_city => 'Mji *';
  @override String get admin_event_location => 'Mahali *';
  @override String get admin_event_address => 'Anwani';
  @override String get admin_event_organizer => 'Muandaaji';
  @override String get admin_event_phone => 'Simu';
  @override String get admin_event_email => 'Barua pepe ya mawasiliano';
  @override String get admin_event_tiers_title => 'Vipindi na uwezo';
  @override String get admin_event_add_tier_btn => 'Ongeza VVIP, VIP…';
  @override String get admin_event_status => 'Hali';
  @override String get admin_event_visibility => 'Uonekano';
  @override String get admin_event_cat_concert => 'Tamasha';
  @override String get admin_event_cat_conference => 'Mkutano';
  @override String get admin_event_cat_sport => 'Michezo';
  @override String get admin_event_cat_festival => 'Sherehe';
  @override String get admin_event_cat_theatre => 'Ukumbi wa michezo';
  @override String get admin_event_cat_other => 'Nyingine';
  @override String get admin_event_status_upcoming => 'Inakuja';
  @override String get admin_event_status_ongoing => 'Inaendelea';
  @override String get admin_event_status_completed => 'Imekamilika';
  @override String get admin_event_status_cancelled => 'Imeghairiwa';
  @override String get admin_event_vis_default => 'Inakuja (chaguo-msingi)';
  @override String get admin_event_vis_recommended => 'Imependekezwa';
  @override String get admin_event_vis_featured => 'Iliyoangaziwa';
  @override String get admin_event_dialog_add_tier => 'Ongeza kipindi';
  @override String get admin_event_dialog_name => 'Jina (mf: VVIP)';
  @override
  String admin_event_dialog_price(String currency) => 'Bei ($currency)';
  @override String get admin_event_dialog_capacity => 'Uwezo';
  @override String get admin_event_dialog_cancel => 'Ghairi';
  @override String get admin_event_dialog_add => 'Ongeza';
  @override String get admin_event_err_readonly => 'Kusoma pekee';
  @override String get admin_event_err_min_tier => 'Angalau kipindi kimoja kinahitajika';
  @override String get admin_event_success => 'Tukio limehifadhiwa';
  @override String get admin_event_err_title_req => 'Kichwa kinahitajika';
  @override String get admin_event_err_desc_min => 'Kiwango cha chini herufi 10';
  @override String get admin_event_err_city_req => 'Mji unahitajika';
  @override String get admin_event_err_loc_req => 'Mahali panahitajika';
  @override String get admin_seat_page_title => 'Ramani ya viti na bei';
  @override String get admin_seat_target_event => 'Tukio lengwa';
  @override String get admin_seat_select_event => 'Chagua tukio';
  @override
  String admin_seat_max_limit(int count) => 'Kiwango cha juu cha viti $count';
  @override
  String admin_seat_generated(int count) => 'Viti $count vimetengenezwa';
  @override String get admin_seat_load_error => 'Imeshindikana kupakia viti';
  @override String get admin_seat_pricing_title => 'Bei inayobadilika';
  @override String get admin_seat_layout_title => 'Umbo na mpangilio';
  @override String get admin_seat_rows => 'Safu';
  @override String get admin_seat_per_row => 'Viti / safu';
  @override String get admin_seat_center_aisle => 'Njia ya katikati';
  @override String get admin_seat_aisle_desc => 'Nafasi tupu katikati';
  @override String get admin_seat_cats_per_row => 'Kategoria kwa safu';
  @override String get admin_seat_generating => 'Inatengeneza…';
  @override
  String admin_seat_generate_btn(int count) => 'Tengeneza viti $count';
  @override String get admin_seat_preview => 'Onyesha la ramani ya sasa';
  @override String get admin_seat_no_seats => 'Hakuna viti vilivyotengenezwa';
  @override String get admin_seat_cat_standard => 'Kawaida';
  @override String get admin_seat_cat_vip => 'VIP';
  @override String get admin_seat_cat_gold => 'Dhahabu';
  @override String get admin_seat_cat_family => 'Familia';
  @override String get admin_seat_legend_reserved => 'Imehifadhiwa';
  @override String get admin_seat_legend_sold => 'Imeuzwa';
  @override String get seat_map_stage => 'Jukwaa';

  // ============================================================================
  // ERRORS (MAKOSA)
  // ============================================================================
  @override String get error_generic => 'Hitilafu imetokea';
  @override String get error_validation => 'Data si sahihi';
  @override String get error_file_too_large => 'Faili ni kubwa mno';
  @override String get error_unsupported_format => 'Muundo hauungwi mkono';
  @override String get error_permission_denied => 'Ruhusa imekataliwa';
  @override String get error_camera_unavailable => 'Kamera haipatikani';
  @override String get error_microphone_unavailable => 'Maikrofoni haipatikani';
  @override String get error_location_unavailable => 'Mahali hapatikani';
  @override String get error_network => 'Hitilafu ya mtandao';
  @override String get error_timeout => 'Muda umeisha';
  @override String get error_server => 'Hitilafu ya seva';
  @override String get error_not_found => 'Haikupatikana';

  // ============================================================================
  // TIME (MUDA)
  // ============================================================================
  @override String get common_just_now => 'Sasa hivi';
  @override String get common_in_the_future => 'Baadaye';
  @override
  String common_minutes_ago(int count) => count == 1 ? 'Dakika 1 iliyopita' : 'Dakika $count zilizopita';
  @override
  String common_hours_ago(int count) => count == 1 ? 'Saa 1 iliyopita' : 'Saa $count zilizopita';
  @override
  String common_days_ago(int count) => count == 1 ? 'Siku 1 iliyopita' : 'Siku $count zilizopita';
  @override
  String common_seconds_ago(int count) => count == 1 ? 'Sekunde 1 iliyopita' : 'Sekunde $count zilizopita';
  @override
  String common_weeks_ago(int count) => count == 1 ? 'Wiki 1 iliyopita' : 'Wiki $count zilizopita';
  @override
  String common_months_ago(int count) => count == 1 ? 'Mwezi 1 uliopita' : 'Miezi $count iliyopita';
  @override
  String common_years_ago(int count) => count == 1 ? 'Mwaka 1 uliopita' : 'Miaka $count iliyopita';
  @override
  String common_in_minutes(int count) => count == 1 ? 'Ndani ya dakika 1' : 'Ndani ya dakika $count';
  @override
  String common_in_hours(int count) => count == 1 ? 'Ndani ya saa 1' : 'Ndani ya saa $count';
  @override
  String common_in_days(int count) => count == 1 ? 'Ndani ya siku 1' : 'Ndani ya siku $count';

  // ============================================================================
  // LIVE & IA (MUBASHARA NA IA)
  // ============================================================================
  @override String get live_leave_btn => 'Ondoka kwenye mubashara';
  @override String get live_chat_empty => 'Kuwa wa kwanza kutoa maoni!';
  @override String get live_chat_hint => 'Tuma ujumbe…';
  @override String get live_like => 'Penda';
  @override String get live_leaving => 'Umeondoka kwenye mubashara';
  @override String get live_viewers => 'watazamaji';
  @override String get live_likes => 'mapendo';
  @override String get live_go_live => 'Nenda Mubashara';
  @override String get live_title => 'Kichwa cha Mubashara';
  @override String get live_start => 'Anza';
  @override String get live_end => 'Maliza';
  @override String get live_duration => 'Muda';
  @override String get live_peak_viewers => 'Kilele cha Watazamaji';
  @override String get live_chat_disabled => 'Soga imezimwa.';
  @override String get live_share => 'Shiriki';
  @override String get live_report => 'Ripoti';
  @override String get live_follow_host => 'Fuata';
  @override String get live_gift_send => 'Tuma Zawadi';
  @override String get live_quality_auto => 'Otomatiki';
  @override String get live_quality_hd => 'HD';
  @override String get live_quality_sd => 'SD';
  @override String get live_quality_low => 'Chini';

  @override String get insight_type_market => 'Soko';
  @override String get insight_type_finance => 'Fedha';
  @override String get insight_type_strategy => 'Mkakati';
  @override String get insight_type_business => 'Biashara';
  @override String get insight_type_insight => 'Ufahamu';
  @override String get insight_confidence_label => 'Kiwango cha imani';
  @override String get insight_source_verified => 'Chanzo kilichothibitishwa';
  @override String get insight_source_unverified => 'Chanzo Hakijathibitishwa';
  @override String get insight_recommended_actions => 'Vitendo Vinavyopendekezwa';
  @override String get insight_key_findings => 'Matokeo Makuu';
  @override String get insight_summary => 'Muhtasari';
  @override String get insight_full_analysis => 'Uchambuzi Kamili';
  @override String get insight_generated_by => 'Imetengenezwa na IA';
  @override String get insight_disclaimer => 'Huu ni uchambuzi uliotengenezwa na IA. Tafadhali thibitisha taarifa.';

  @override String get risk_critical => 'Hatari Kubwa';
  @override String get risk_high => 'Hatari';
  @override String get risk_medium => 'Wastani';
  @override String get risk_low => 'Chini';
  @override String get risk_level_label => 'Kiwango cha Hatari';
  @override String get risk_mitigation => 'Kupunguza Hatari';
  @override String get risk_impact => 'Athari';
  @override String get risk_probability => 'Uwezekano';
  @override String get risk_assessment => 'Tathmini ya Hatari';
}
