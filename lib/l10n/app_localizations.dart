// lib/l10n/app_localizations.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Importez toutes vos futures langues ici
import 'app_localizations_fr.dart';
import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_sw.dart';
import 'app_localizations_ar.dart';
import 'app_localizations_zh.dart';

abstract class AppLocalizations {
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  // ============================================================================
  // COMMUN & UI
  // ============================================================================
  String get common_back;
  String get common_close;
  String get common_cancel;
  String get common_confirm;
  String get common_delete;
  String get common_add;
  String get common_edit;
  String get common_save;
  String get common_manage;
  String get common_retry;
  String get common_refresh;
  String get common_search;
  String get common_open;
  String get common_share;
  String get common_copy;
  String get common_copied;
  String get common_download;
  String get common_upload;
  String get common_send;
  String get common_receive;
  String get common_accept;
  String get common_reject;
  String get common_skip;
  String get common_next;
  String get common_previous;
  String get common_finish;
  String get common_done;
  String get common_error;
  String get common_success;
  String get common_loading;
  String get common_please_wait;
  String get common_today;
  String get common_yesterday;
  String get common_tomorrow;
  String get common_home;
  String get common_chat;
  String get common_map;
  String get common_profile;
  String get common_menu;
  String get common_notifications;
  String get common_settings;
  String get common_help;
  String get common_about;
  String get common_logout;
  String get common_login;
  String get common_signup;
  String get common_yes;
  String get common_no;
  String get common_or;
  String get common_and;
  String get common_none;
  String get common_all;
  String get common_unknown;
  String get common_enabled;
  String get common_disabled;
  String get common_clear;
  String get common_remove;
  
  String common_items(int count);
  String common_contacts(int count);
  String common_messages(int count);
  String common_days(int count);
  String common_hours(int count);
  String common_minutes(int count);

  // ============================================================================
  // AUTH & ONBOARDING (BASIC)
  // ============================================================================
  String get auth_login;
  String get auth_signup;
  String get auth_forgot_password;
  String get auth_reset_password;
  String get auth_email;
  String get auth_phone;
  String get auth_password;
  String get auth_confirm_password;
  String get auth_logout_confirm;
  String get auth_welcome_back;
  String get auth_welcome;
  String get auth_no_account;
  String get auth_has_account;
  String get auth_invalid_email;
  String get auth_invalid_phone;
  String get auth_password_too_short;
  String get auth_passwords_mismatch;
  String get auth_login_success;
  String get auth_signup_success;
  String get auth_session_expired;
  String get auth_2fa_title;
  String get auth_2fa_code;
  String get auth_verify_email;
  String get auth_verify_phone;
  String get auth_biometric;
  String get auth_biometric_prompt;
  String get auth_full_name;
  String get auth_first_name;
  String get auth_last_name;
  String get auth_birth_date;
  String get auth_gender;
  String get auth_gender_male;
  String get auth_gender_female;
  String get auth_gender_other;
  String get auth_accept_terms;
  String get auth_terms_required;
  String get auth_email_already_used;
  String get auth_phone_already_used;
  String get auth_create_account;
  String get auth_already_have_account;

  String get onboarding_welcome;
  String get onboarding_step_1_title;
  String get onboarding_step_1_desc;
  String get onboarding_step_2_title;
  String get onboarding_step_2_desc;
  String get onboarding_step_3_title;
  String get onboarding_step_3_desc;
  String get onboarding_get_started;
  String get onboarding_skip;

  // ============================================================================
  // AUTHENTIFICATION & CONNEXION (ADVANCED / ERRORS)
  // ============================================================================
  String get login_title;
  String get login_subtitle;
  String get login_identifier_label;
  String get login_identifier_hint;
  String get login_password_label;
  String get login_password_hint;
  String get login_remember_me;
  String get login_forgot_password;
  String get login_button;
  String get login_verifying;
  String get login_retry_in;
  String get login_seconds_suffix;
  String get login_biometric;
  String get login_face_id;
  String get login_touch_id;
  
  String get login_error_suspended;
  String get login_error_not_active;
  String get login_error_no_account;
  String get login_error_mfa_required;

  String get auth_error_identifier_required;
  String get auth_error_password_required;
  String get auth_error_thix_id_login_not_available;
  String get auth_error_sign_in_failed;
  String get auth_error_email_not_verified;
  String get auth_error_server_misconfiguration;
  String get auth_error_account_already_exists;
  String get auth_error_account_exists_wrong_password;
  String get auth_error_account_exists_new_otp_sent;
  String get auth_error_invalid_otp;
  String get auth_error_otp_expired;
  String get auth_error_network;
  String get auth_error_rate_limit;
  String get auth_error_technical;
  String get auth_error_user_mismatch;
  String get auth_error_profile_update_failed;
  String get auth_error_mark_email_verified_failed;
  String get auth_error_qr_token_generation_failed;
  String get auth_error_finalize_registration_failed;
  String get auth_error_consume_qr_token_failed;
  String get auth_error_resend_otp_failed;
  String get auth_error_phone_auth_not_available;
  String get auth_error_delete_account_not_available;
  String get auth_error_update_email_failed;
  String get auth_error_reset_password_failed;
  String get auth_error_sign_up_failed;
  String get auth_info_otp_sent;

  // ============================================================================
  // INSCRIPTION PERSONNELLE
  // ============================================================================
  String get reg_step1_title;
  String get reg_step1_subtitle;
  String get reg_full_name_label;
  String get reg_full_name_hint;
  String get reg_dob_label;
  String get reg_country_label;
  String get reg_occupation_label;
  String get reg_occupation_hint;
  String get reg_next;

  String get reg_step2_title;
  String get reg_step2_subtitle;
  String get reg_email_label;
  String get reg_email_hint;
  String get reg_phone_label;
  String get reg_phone_hint;
  String get reg_password_label;
  String get reg_password_hint;
  String get reg_confirm_password_label;
  String get reg_confirm_password_hint;
  String get reg_strength_label;
  String get reg_strength_very_weak;
  String get reg_strength_weak;
  String get reg_strength_medium;
  String get reg_strength_strong;
  String get reg_strength_excellent;

  String get reg_identity_title;
  String get reg_thix_chat_label;
  String get reg_thix_chat_hint;
  
  String get reg_verification_title;
  String get reg_get_otp;
  String get reg_code_sent_resend;
  String get reg_resend_in;
  String get reg_seconds_short;
  String get reg_otp_label;
  String get reg_validate_activate;
  String get reg_activating;

  String get reg_congrats;
  String get reg_welcome_message;
  String get reg_id_card_title;
  String get reg_official_thix_id;
  String get reg_generating;
  String get reg_copy_thix_id;
  String get reg_thix_id_copied;
  String get reg_go_to_dashboard;
  String get reg_summary;
  String get reg_mobile_label;
  String get reg_not_provided;

  // ============================================================================
  // ACCUEIL & TABLEAU DE BORD
  // ============================================================================
  String get home_search_hint;
  String get home_greeting;
  String get home_greeting_time;
  String get home_welcome_back;
  String get home_language_kiswahili;
  String get home_banner_default_tag;
  String get home_banner_default_title;
  
  String get cert_pending;
  String get cert_tier_ladder;
  String get cert_view;

  String get quick_sona;
  String get quick_doc;
  String get quick_chat;
  String get quick_sos;
  String get service_sante;
  String get service_market;
  String get service_money;
  String get service_reservation;
  String get service_mon_pays;
  String get service_emploi;
  String get service_formations;
  String get service_opportunites;
  String get service_infos;
  String get service_events;
  String get service_media;
  String get service_vault;
  String get service_network;
  String get service_certification;

  // ============================================================================
  // CHAT & MESSAGERIE
  // ============================================================================
  String get chatlist_network;
  String get chatlist_discussions;
  String get chatlist_create_new;
  String get chatlist_calls;
  String get chatlist_settings;

  String get chat_unknown_user;
  String chat_members(int count);
  String get chat_video_call;
  String get chat_audio_call;
  String get chat_escalate;
  String get chat_history;
  String get chat_group_info;
  String get chat_file;
  String get chat_sticker;
  String get chat_ephemeral;
  String get chat_protected;
  String get chat_internal_note;
  String get chat_send;
  String get chat_recording;
  String get chat_stop_recording;
  String get chat_write_message;
  String get chat_record_audio;
  String get chat_emojis;
  String get chat_reactions;
  String get chat_flags;
  String get chat_callback;
  String get chat_typing;
  String get chat_pause;
  String get chat_play;

  String get conv_status_connected;
  String get conv_status_pending;
  String get conv_status_rejected;
  String get conv_cannot_self;
  String get conv_request_pending;
  String get conv_request_rejected;
  String get conv_request_to;
  String get conv_request_hint;
  String get conv_message_optional;
  String get conv_send_request;
  String get conv_request_sent;
  String get conv_request_exists;
  String get conv_select_contact;
  String get conv_waiting_connection;
  String get conv_group_rpc_required;
  String get conv_page_title;
  String conv_start(int count);
  String get conv_search_label;
  String get conv_search_hint;
  String get conv_group_name_label;
  String get conv_group_name_hint;

  String get requests_page_title;
  String get requests_reject_title;
  String get requests_reject_message;
  String get requests_reject_confirm;
  String get requests_rejected;
  String get requests_reject_error;
  String get requests_accepted;
  String get requests_accept_error;

  String get call_history_title;
  String get call_missed;
  String get call_incoming;
  String get call_outgoing;
  String get call_video;
  String get call_audio;

  // ============================================================================
  // RÉSEAU SOCIAL
  // ============================================================================
  String get network_search_title;
  String get network_search_hint;
  String get network_tab_people;
  String get network_tab_posts;
  String get network_tab_communities;
  String get network_explore_title;
  String get network_explore_subtitle;
  String get network_no_results_users;
  String get network_no_results_posts;
  String get network_no_results_communities;
  String get network_request_sent;
  String get network_request_error;

  String get community_create_title;
  String get community_name_label;
  String get community_description_label;
  String get community_visibility_label;
  String get community_public;
  String get community_private;
  String get community_join;
  String get community_leave;
  String get community_members;
  String get community_admin;

  // ============================================================================
  // PROFIL UTILISATEUR
  // ============================================================================
  String get profile_settings;
  String get profile_edit_bio;
  String get profile_no_bio;
  String get profile_followers;
  String get profile_following;
  String get profile_posts;
  String get profile_follow;
  String get profile_unfollow;
  String get profile_following_loading;
  String get profile_message;
  String get profile_block_user;
  String get profile_block_message;
  String get profile_block_confirm;
  String get profile_blocked_success;
  String get profile_block_error;
  
  String get profile_report_user;
  String get profile_report_reason;
  String get profile_report_details;
  String get profile_report_spam;
  String get profile_report_inappropriate;
  String get profile_report_harassment;
  String get profile_report_impersonation;
  String get profile_report_other;
  String get profile_report_submit;
  String get profile_report_success;
  String get profile_report_duplicate;
  
  String get profile_private_gallery;
  String get profile_private_content_locked;
  String get profile_add_private_media;
  String get profile_no_private_media;
  String get profile_upload_processing;
  
  String get profile_tab_bio;
  String get profile_tab_private_gallery;
  String get profile_tab_photos;
  String get profile_tab_videos;
  String get profile_tab_audios;
  String get profile_no_content;
  String get profile_pinned_post;
  String get profile_view_post;

  // ============================================================================
  // PARAMÈTRES GÉNÉRAUX & CHAT (SETTINGS)
  // ============================================================================
  String get settings_title;
  String get settings_section_appearance;
  String get settings_theme;
  String get settings_theme_light;
  String get settings_theme_dark;
  String get settings_theme_system;
  String get settings_wallpaper;
  String get settings_wallpaper_default;
  String get settings_wallpaper_custom;
  
  String get settings_section_privacy;
  String get settings_last_seen;
  String get settings_visibility_everyone;
  String get settings_visibility_contacts;
  String get settings_visibility_nobody;
  String get settings_profile_photo;
  
  String get settings_section_notifications;
  String get settings_messages;
  String get settings_calls;
  
  String get settings_section_messages;
  String get settings_ephemeral;
  String get settings_auto_download;
  String get settings_download_wifi;
  String get settings_download_mobile;
  String get settings_download_never;
  
  String get settings_section_account;
  String get settings_view_profile;
  String get settings_logout;

  String get settings_profile_edit;
  String get settings_notifications;
  String get settings_privacy;
  String get settings_security;
  String get settings_language;
  String get settings_help_center;
  String get settings_about;
  String get settings_version;

  // ============================================================================
  // TRADUCTIONS DE LANGUAGE SHEET
  // ============================================================================
  String get settings_choose_language;
  String get settings_system_default;
  String get settings_language_change_failed;

  // ============================================================================
  // SOS & URGENCE
  // ============================================================================
  String get sos_button;
  String get sos_button_label;
  String get sos_button_hint;
  String get sos_button_tooltip;
  String get sos_trigger_button;
  String get sos_trigger_timeout;
  String get sos_trigger_error;
  String get sos_active;
  String get sos_crisis_room;
  String get sos_command_center;
  String get sos_incident;
  String get sos_incident_unknown;
  String get sos_incident_not_found;
  String get sos_circle;
  String get sos_rescuers;
  String get sos_rescuer;
  String get sos_my_rescuers;
  String get sos_duration;
  String get sos_identifier;
  String get sos_calling;
  String get sos_call;
  String get sos_available;
  String get sos_unavailable;
  String get sos_verified;
  String get sos_end;
  String get sos_end_sos;
  String get sos_cancel_sos;
  String get sos_pin_required;
  String get sos_cancelled;
  String get sos_resolved;
  String get sos_cancel_failed;
  String get sos_in_progress;
  String get sos_history;
  String get sos_my_incidents;
  String get sos_no_incidents;
  String get sos_incidents_appear_here;
  String get sos_history_error;
  String get sos_circle_1;
  String get sos_circle_2;
  String get sos_circle_3;
  String get sos_no_rescuers;
  String get sos_add_first_rescuer;
  String get sos_add_rescuer;
  String get sos_add_rescuer_info;
  String get sos_thix_id_label;
  String get sos_thix_id_hint;

  // ============================================================================
  // CERTIFICATION
  // ============================================================================
  String get certification_title;
  String get certification_apply;
  String get certification_status;
  String get certification_pending;
  String get certification_approved;
  String get certification_rejected;
  String get certification_tier_bronze;
  String get certification_tier_silver;
  String get certification_tier_gold;
  String get certification_tier_platinum;
  String get certification_benefits;
  String get certification_documents;
  String get certification_upload_doc;
  String get certification_review_progress;
  String get certification_verified_account;

  // ============================================================================
  // ÉDUCATION & FORMATION
  // ============================================================================
  String get edu_nav_home;
  String get edu_nav_learning;
  String get edu_nav_library;
  String get edu_nav_certs;
  String get edu_nav_profile;
  
  String get edu_auth_required;
  String get edu_login_required;
  
  String get edu_learning_empty_title;
  String get edu_learning_empty_desc;
  String get edu_no_courses;
  String get edu_enroll_hint;
  String get edu_explore_btn;
  String get edu_completed;
  
  String get edu_user_avatar;
  String get edu_greeting;
  String get edu_greeting_subtitle;
  String get edu_ready_to_learn;
  String get edu_learner;
  String get edu_notifications;
  String get edu_search_hint;
  String get edu_browse;
  String get edu_library;
  String get edu_certs;
  String get edu_qa_browse;
  String get edu_instructor;
  
  String get edu_top_formations;
  String get edu_awaited_formations;
  String get edu_awaited;
  String get edu_see_all;
  
  String edu_coming_soon(String category);
  String get edu_coming_soon_cat;
  String get edu_locked_course;
  String get edu_coming_soon_badge;
  String get edu_awaited_badge;
  String get edu_awaited_locked;
  String get edu_awaited_locked_msg;
  
  String get edu_thix_academy;
  String get edu_scheduled_soon;
  String get edu_new_program;
  String get edu_resume_learning;
  String get edu_resume;
  
  String get edu_catalog;
  String get edu_no_formations_cat;
  
  String get edu_my_library;
  String get edu_search_book_hint;
  String get edu_library_title;
  String get edu_search_library;
  String get edu_shelves_empty;
  String get edu_library_empty;
  String get edu_no_result;
  String edu_search_no_results(String query);
  
  String get edu_shelf;
  String get edu_books;
  String get edu_all;
  String edu_shelf_info(String code, int count);
  String get edu_free;
  String get edu_deleted_in;
  String edu_expires_in(String countdown);
  
  String get edu_certifications;
  String get edu_certs_title;
  String get edu_no_certs;
  String get edu_cert_expert;
  String get edu_cert_expertise;
  String edu_cert_issued(String date);
  
  String get edu_pro_account;
  String get edu_profile_title;
  String get edu_instructor_space;
  String get edu_tools;
  String get edu_institutional_tools;
  String get edu_free_resources;
  String get edu_masterclass;
  String get edu_masterclasses;
  String get edu_network;
  String get edu_mentorship;
  String get edu_events_agenda;
  String get edu_support;
  String get edu_not_connected;

  String get training_title;
  String get training_enroll;
  String get training_my_courses;
  String get training_certificates;
  String get training_progress;
  String get training_lessons;
  String get training_duration;
  String get training_level;
  String get training_beginner;
  String get training_intermediate;
  String get training_advanced;
  String get training_start_course;
  String get training_continue_course;

  // ============================================================================
  // EMPLOIS & RECRUTEMENT
  // ============================================================================
  String get jobs_title;
  String get jobs_search;
  String get jobs_apply;
  String get jobs_saved;
  String get jobs_applied;
  String get jobs_company;
  String get jobs_location;
  String get jobs_salary;
  String get jobs_type;
  String get jobs_full_time;
  String get jobs_part_time;
  String get jobs_contract;
  String get jobs_internship;
  String get jobs_freelance;
  String get jobs_remote;
  String get jobs_onsite;
  String get jobs_hybrid;
  String get jobs_experience;
  String get jobs_no_experience;
  String get jobs_junior;
  String get jobs_mid;
  String get jobs_senior;
  String get jobs_requirements;
  String get jobs_responsibilities;
  String get jobs_benefits;
  String get jobs_apply_now;
  String get jobs_application_sent;
  String get jobs_no_results;
  String get recruiter_title;
  String get recruiter_post_job;
  String get recruiter_candidates;
  String get recruiter_applications;
  String get recruiter_interviews;

  // ============================================================================
  // OPPORTUNITÉS
  // ============================================================================
  String get opportunities_title;
  String get opportunities_business;
  String get opportunities_investment;
  String get opportunities_partnership;
  String get opportunities_grant;
  String get opportunities_coming_soon;

  // ============================================================================
  // MARCHÉ & E-COMMERCE
  // ============================================================================
  String get market_title;
  String get market_categories;
  String get market_products;
  String get market_services;
  String get market_add_to_cart;
  String get market_buy_now;
  String get market_cart;
  String get market_checkout;
  String get market_total;
  String get market_delivery;
  String get market_seller;
  String get market_rating;
  String get market_reviews;
  String get market_in_stock;
  String get market_out_of_stock;
  String get market_add_to_favorites;
  String get market_remove_from_cart;

  // ============================================================================
  // PORTEFEUILLE & ARGENT
  // ============================================================================
  String get money_title;
  String get money_balance;
  String get money_send;
  String get money_receive;
  String get money_history;
  String get money_transactions;
  String get money_top_up;
  String get money_withdraw;
  String get money_transfer;
  String get money_bills;
  String get money_recipients;
  String get money_add_recipient;
  String get money_amount;
  String get money_fee;
  String get money_reference;
  String get money_confirm_transfer;
  String get money_transfer_success;
  String get money_transfer_failed;
  String get money_insufficient_funds;

  // ============================================================================
  // ÉVÉNEMENTS & BILLETS
  // ============================================================================
  String get events_title;
  String get events_upcoming;
  String get events_past;
  
  String get event_share_cta;
  String get event_sold_out_title;
  String get event_sold_out_msg;
  String get event_join_queue_confirm;
  String get event_join_queue_btn;
  
  String get event_unfavorite;
  String get event_favorite;
  String get event_free;
  String get event_paid;
  
  String get event_time_label;
  String get event_location_label;
  String get event_address_label;
  String get event_organized_by;
  
  String get event_about_title;
  String get event_no_description;
  String get event_tickets_title;
  
  String get event_sold_out_short;
  String event_remaining_seats(String count);
  String get event_queue_btn;
  String get event_book_btn;
  
  String get event_standard_entry;
  String get event_all_sold;
  String get event_limited_seats;
  String get event_book_now_btn;
  
  String event_numbered_seats(String count);
  String get event_choose_seats_btn;
  String get event_from_price;

  String get events_my_tickets;
  String get events_buy_ticket;
  String get events_ticket_price;
  String get events_date;
  String get events_time;
  String get events_venue;
  String get events_organizer;
  String get events_attendees;
  String get events_seats_available;
  String get events_sold_out;
  String get events_book_now;
  String get events_ticket_type;
  String get ticket_standard;
  String get ticket_vip;
  String get ticket_gold;
  String get ticket_family;
  String get ticket_secure_ticket;
  String get ticket_not_found;
  String get ticket_location;
  String get ticket_pin_label;
  String get ticket_show_qr;
  String get ticket_booking_id;
  String get ticket_add_wallet;
  String get ticket_wallet_coming_soon;
  String get ticket_share;
  String get ticket_share_text;
  String get ticket_scan_info;
  String get ticket_security_title;
  String get ticket_enter_pin;
  String get ticket_pin_hint;
  String get ticket_pin_incorrect;
  String get ticket_pin_too_many_attempts;
  String get ticket_attempts_remaining;
  String get tickets_ticket;
  String get tickets_completed;
  String get tickets_no_tickets;
  String get tickets_no_tickets_desc;
  String get tickets_discover;
  String get tickets_load_error;
  String tickets_quantity(int count);

  // ============================================================================
  // RÉSERVATIONS
  // ============================================================================
  String get reservation_title;
  String get reservation_hotel;
  String get reservation_restaurant;
  String get reservation_transport;
  String get reservation_check_in;
  String get reservation_check_out;
  String get reservation_guests;
  String get reservation_rooms;
  String get reservation_book;
  String get reservation_cancel;
  String get reservation_modify;
  String get reservation_confirm;
  String get reservation_my_bookings;

  // ============================================================================
  // SANTÉ
  // ============================================================================
  String get health_title;
  String get health_appointments;
  String get health_doctors;
  String get health_hospitals;
  String get health_pharmacies;
  String get health_emergency;
  String get health_medical_records;
  String get health_prescriptions;
  String get health_book_appointment;
  String get health_appointment_date;
  String get health_specialty;
  String get health_consultation;
  String get health_telemedicine;
  String get health_insurance;
  String get health_symptoms;
  String get health_find_doctor;

  // ============================================================================
  // MÉDIA & INFOS
  // ============================================================================
  String get media_title;
  String get media_news;
  String get media_videos;
  String get media_podcasts;
  String get media_articles;
  String get media_live;
  String get media_categories;
  String get media_bookmarks;
  String get media_share_article;
  String get media_read_more;
  String get media_published_on;
  String get media_author;
  String get info_title;
  String get info_local;
  String get info_national;
  String get info_international;
  String get info_sports;
  String get info_culture;
  String get info_economy;
  String get info_politics;
  String get info_technology;
  String get info_read_full;

  // ============================================================================
  // MON PAYS
  // ============================================================================
  String get mon_pays_title;
  String get mon_pays_regions;
  String get mon_pays_cities;
  String get mon_pays_culture;
  String get mon_pays_history;
  String get mon_pays_tourism;
  String get mon_pays_discover;
  String get mon_pays_landmarks;
  String get mon_pays_traditions;

  // ============================================================================
  // COFFRE-FORT
  // ============================================================================
  String get vault_title;
  String get vault_documents;
  String get vault_photos;
  String get vault_videos;
  String get vault_notes;
  String get vault_passwords;
  String get vault_add_document;
  String get vault_upload;
  String get vault_encrypted;
  String get vault_backup;
  String get vault_restore;
  String get vault_share_secure;
  String get vault_unlock;
  String get vault_lock;

  // ============================================================================
  // PAIEMENT
  // ============================================================================
  String get payment_title;
  String get payment_method;
  String get payment_card;
  String get payment_mobile_money;
  String get payment_bank_transfer;
  String get payment_cash;
  String get payment_confirm;
  String get payment_success;
  String get payment_failed;
  String get payment_processing;
  String get payment_receipt;
  String get payment_invoice;

  // ============================================================================
  // RECHERCHE (MISSING PERSONS / SEARCH)
  // ============================================================================
  String get search_title;
  String get search_subtitle;
  String get search_person_missing;
  String get search_person_wanted;
  String get search_report_missing;
  String get search_report_found;
  String get search_details;
  String get search_contact_authorities;
  String get search_share_alert;
  String get search_last_seen;
  String get search_description;
  String get search_age;
  String get search_height;
  String get search_weight;
  String get search_hair_color;
  String get search_eye_color;
  String get search_distinguishing_marks;
  String get search_clothing;
  String get search_circumstances;
  String get search_case_number;
  String get search_reported_by;
  String get search_official_notice;
  String get search_community_alert;

  // ============================================================================
  // À PROXIMITÉ & ALERTES
  // ============================================================================
  String get nearby_alerts_title;
  String get nearby_view_on_map;
  String get nearby_map_coming_soon;
  String get nearby_map_disabled;
  String get nearby_active_alerts;
  String get nearby_missing;
  String get nearby_official;
  String get nearby_legend_missing;
  String get nearby_legend_official;
  String get nearby_legend_report;
  String get nearby_location_required;
  String get nearby_location_subtitle;

  // ============================================================================
  // ADMINISTRATION
  // ============================================================================
  String get admin_title;
  String get admin_dev_open;
  String get admin_actions_section;
  
  String get admin_events_title;
  String get admin_events_create;
  String get admin_events_search_hint;
  String get admin_events_filter;
  String get admin_events_empty;
  String get admin_events_no_permission;
  String get admin_events_delete_title;
  String admin_events_delete_desc(String title);

  String get admin_limits_purchase_rules;
  String get admin_limits_max_person;
  String get admin_limits_max_transaction;
  String get admin_limits_require_thix_id;
  String get admin_limits_require_thix_id_desc;
  String get admin_limits_info_title;
  String get admin_limits_info_desc;

  String get admin_stat_events;
  String get admin_stat_bookings;
  String get admin_stat_revenue;
  String get admin_stat_queue;
  String get admin_action_events;
  String get admin_action_events_sub;
  String get admin_action_create;
  String get admin_action_create_sub;
  String get admin_action_seats;
  String get admin_action_seats_sub;
  String get admin_action_reservations;
  String get admin_action_reservations_sub;
  String get admin_action_limits;
  String get admin_action_limits_sub;
  String get admin_action_analytics;
  String get admin_action_analytics_sub;
  String get admin_read_only;
  String get admin_bookings_title;
  String get admin_bookings_export;
  String get admin_bookings_details;
  String get admin_bookings_event;
  String get admin_bookings_unknown_event;
  String get admin_bookings_id;
  String get admin_bookings_quantity;
  String get admin_bookings_category;
  String get admin_bookings_amount;
  String get admin_bookings_pin;
  String get admin_bookings_purchase_date;
  String get admin_bookings_close;
  String get admin_bookings_empty;
  String get admin_bookings_unknown_date;
  String admin_bookings_places(int count);
  String get admin_bookings_status_valid;
  String get admin_bookings_status_used;
  String get admin_bookings_status_cancelled;
  String get admin_bookings_status_postponed;
  String get admin_bookings_status_pending;
  String admin_queue_title(int count);
  String get admin_queue_realtime_desc;
  String get admin_queue_empty;
  String get admin_queue_event_fallback;
  String admin_queue_item_meta(String userId, int qty, String status);
  String get admin_queue_notify;
  String get admin_queue_notified;
  String get admin_queue_position;
  String get admin_queue_places;
  String get admin_analytics_title;
  String get admin_analytics_fill_rate;
  String get admin_analytics_avg_cart;
  String get admin_analytics_no_show;
  String get admin_analytics_rev_per_event;
  String get admin_analytics_revenue_7d;
  String get admin_analytics_no_data;
  String get admin_analytics_error;
  String get admin_event_create;
  String get admin_event_edit;
  String get admin_event_btn_create;
  String get admin_event_btn_save;
  String get admin_event_cover;
  String get admin_event_banner;
  String get admin_event_title;
  String get admin_event_desc;
  String get admin_event_category;
  String get admin_event_subcategory;
  String get admin_event_datetime;
  String get admin_event_start;
  String get admin_event_end;
  String get admin_event_add_end;
  String get admin_event_city;
  String get admin_event_location;
  String get admin_event_address;
  String get admin_event_organizer;
  String get admin_event_phone;
  String get admin_event_email;
  String get admin_event_tiers_title;
  String get admin_event_add_tier_btn;
  String get admin_event_status;
  String get admin_event_visibility;
  String get admin_event_cat_concert;
  String get admin_event_cat_conference;
  String get admin_event_cat_sport;
  String get admin_event_cat_festival;
  String get admin_event_cat_theatre;
  String get admin_event_cat_other;
  String get admin_event_status_upcoming;
  String get admin_event_status_ongoing;
  String get admin_event_status_completed;
  String get admin_event_status_cancelled;
  String get admin_event_vis_default;
  String get admin_event_vis_recommended;
  String get admin_event_vis_featured;
  String get admin_event_dialog_add_tier;
  String get admin_event_dialog_name;
  String admin_event_dialog_price(String currency);
  String get admin_event_dialog_capacity;
  String get admin_event_dialog_cancel;
  String get admin_event_dialog_add;
  String get admin_event_err_readonly;
  String get admin_event_err_min_tier;
  String get admin_event_success;
  String get admin_event_err_title_req;
  String get admin_event_err_desc_min;
  String get admin_event_err_city_req;
  String get admin_event_err_loc_req;
  String get admin_seat_page_title;
  String get admin_seat_target_event;
  String get admin_seat_select_event;
  String admin_seat_max_limit(int count);
  String admin_seat_generated(int count);
  String get admin_seat_load_error;
  String get admin_seat_pricing_title;
  String get admin_seat_layout_title;
  String get admin_seat_rows;
  String get admin_seat_per_row;
  String get admin_seat_center_aisle;
  String get admin_seat_aisle_desc;
  String get admin_seat_cats_per_row;
  String get admin_seat_generating;
  String admin_seat_generate_btn(int count);
  String get admin_seat_preview;
  String get admin_seat_no_seats;
  String get admin_seat_cat_standard;
  String get admin_seat_cat_vip;
  String get admin_seat_cat_gold;
  String get admin_seat_cat_family;
  String get admin_seat_legend_reserved;
  String get admin_seat_legend_sold;
  String get seat_map_stage;

  // ============================================================================
  // ERREURS & VALIDATION
  // ============================================================================
  String get error_generic;
  String get error_validation;
  String get error_file_too_large;
  String get error_unsupported_format;
  String get error_permission_denied;
  String get error_camera_unavailable;
  String get error_microphone_unavailable;
  String get error_location_unavailable;
  String get error_network;
  String get error_timeout;
  String get error_server;
  String get error_not_found;

  // ============================================================================
  // TEMPS & DATES RELATIVES
  // ============================================================================
  String get common_just_now;
  String get common_in_the_future;
  String common_minutes_ago(int count);
  String common_hours_ago(int count);
  String common_days_ago(int count);
  String common_seconds_ago(int count);
  String common_weeks_ago(int count);
  String common_months_ago(int count);
  String common_years_ago(int count);
  String common_in_minutes(int count);
  String common_in_hours(int count);
  String common_in_days(int count);
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  // On liste ici les 6 codes de langues que vous supportez
  @override
  bool isSupported(Locale locale) {
    return ['fr', 'en', 'pt', 'sw', 'ar', 'zh'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    // Le "Cerveau" : Si le téléphone est en anglais, on charge la classe English, etc.
    switch (locale.languageCode) {
      case 'en':
        return SynchronousFuture<AppLocalizations>(AppLocalizationsEn());
      case 'pt':
        return SynchronousFuture<AppLocalizations>(AppLocalizationsPt());
      case 'sw':
        return SynchronousFuture<AppLocalizations>(AppLocalizationsSw());
      case 'ar':
        return SynchronousFuture<AppLocalizations>(AppLocalizationsAr());
      case 'zh':
        return SynchronousFuture<AppLocalizations>(AppLocalizationsZh());
      case 'fr':
      default:
        // Le français est la langue par défaut si on ne trouve pas
        return SynchronousFuture<AppLocalizations>(AppLocalizationsFr());
    }
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
