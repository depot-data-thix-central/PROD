// lib/l10n/app_localizations_en.dart
import 'dart:ui';
import 'app_localizations.dart';

class AppLocalizationsEn extends AppLocalizations {
  @override Locale get locale => const Locale('en');

  // ============================================================================
  // COMMON & UI
  // ============================================================================
  @override String get common_back => 'Back';
  @override String get common_close => 'Close';
  @override String get common_cancel => 'Cancel';
  @override String get common_confirm => 'Confirm';
  @override String get common_delete => 'Delete';
  @override String get common_add => 'Add';
  @override String get common_edit => 'Edit';
  @override String get common_save => 'Save';
  @override String get common_manage => 'Manage';
  @override String get common_retry => 'Retry';
  @override String get common_refresh => 'Refresh';
  @override String get common_search => 'Search';
  @override String get common_open => 'Open';
  @override String get common_share => 'Share';
  @override String get common_copy => 'Copy';
  @override String get common_copied => 'Copied!';
  @override String get common_download => 'Download';
  @override String get common_upload => 'Upload';
  @override String get common_send => 'Send';
  @override String get common_receive => 'Receive';
  @override String get common_accept => 'Accept';
  @override String get common_reject => 'Reject';
  @override String get common_skip => 'Skip';
  @override String get common_next => 'Next';
  @override String get common_previous => 'Previous';
  @override String get common_finish => 'Finish';
  @override String get common_done => 'Done';
  @override String get common_error => 'Error';
  @override String get common_success => 'Success';
  @override String get common_loading => 'Loading...';
  @override String get common_please_wait => 'Please wait...';
  @override String get common_today => 'Today';
  @override String get common_yesterday => 'Yesterday';
  @override String get common_tomorrow => 'Tomorrow';
  @override String get common_home => 'Home';
  @override String get common_chat => 'Chat';
  @override String get common_map => 'Map';
  @override String get common_profile => 'Profile';
  @override String get common_menu => 'Menu';
  @override String get common_notifications => 'Notifications';
  @override String get common_settings => 'Settings';
  @override String get common_help => 'Help';
  @override String get common_about => 'About';
  @override String get common_logout => 'Logout';
  @override String get common_login => 'Login';
  @override String get common_signup => 'Sign Up';
  @override String get common_yes => 'Yes';
  @override String get common_no => 'No';
  @override String get common_or => 'or';
  @override String get common_and => 'and';
  @override String get common_none => 'None';
  @override String get common_all => 'All';
  @override String get common_unknown => 'Unknown';
  @override String get common_enabled => 'Enabled';
  @override String get common_disabled => 'Disabled';
  @override String get common_clear => 'Clear';
  @override String get common_remove => 'Remove';
  
  @override String common_items(int count) => count == 1 ? '1 item' : '$count items';
  @override String common_contacts(int count) => count == 1 ? '1 contact' : '$count contacts';
  @override String common_messages(int count) => count == 1 ? '1 message' : '$count messages';
  @override String common_days(int count) => count == 1 ? '1 day' : '$count days';
  @override String common_hours(int count) => count == 1 ? '1 hour' : '$count hours';
  @override String common_minutes(int count) => count == 1 ? '1 minute' : '$count minutes';

  // ============================================================================
  // AUTH & ONBOARDING (BASIC)
  // ============================================================================
  @override String get auth_login => 'Login';
  @override String get auth_signup => 'Sign Up';
  @override String get auth_forgot_password => 'Forgot password?';
  @override String get auth_reset_password => 'Reset password';
  @override String get auth_email => 'Email Address';
  @override String get auth_phone => 'Phone Number';
  @override String get auth_password => 'Password';
  @override String get auth_confirm_password => 'Confirm password';
  @override String get auth_logout_confirm => 'Are you sure you want to log out?';
  @override String get auth_welcome_back => 'Welcome back';
  @override String get auth_welcome => 'Welcome';
  @override String get auth_no_account => 'Don\'t have an account?';
  @override String get auth_has_account => 'Already have an account?';
  @override String get auth_invalid_email => 'Invalid email address';
  @override String get auth_invalid_phone => 'Invalid phone number';
  @override String get auth_password_too_short => 'Password is too short (min. 8 characters)';
  @override String get auth_passwords_mismatch => 'Passwords do not match';
  @override String get auth_login_success => 'Successfully logged in';
  @override String get auth_signup_success => 'Account created successfully';
  @override String get auth_session_expired => 'Session expired, please log in again';
  @override String get auth_2fa_title => 'Two-Factor Authentication';
  @override String get auth_2fa_code => 'Verification code';
  @override String get auth_verify_email => 'Verify email';
  @override String get auth_verify_phone => 'Verify phone';
  @override String get auth_biometric => 'Biometric login';
  @override String get auth_biometric_prompt => 'Authenticate to continue';
  @override String get auth_full_name => 'Full Name';
  @override String get auth_first_name => 'First Name';
  @override String get auth_last_name => 'Last Name';
  @override String get auth_birth_date => 'Date of Birth';
  @override String get auth_gender => 'Gender';
  @override String get auth_gender_male => 'Male';
  @override String get auth_gender_female => 'Female';
  @override String get auth_gender_other => 'Other';
  @override String get auth_accept_terms => 'I agree to the Terms of Use';
  @override String get auth_terms_required => 'You must agree to the terms';
  @override String get auth_email_already_used => 'This email is already in use';
  @override String get auth_phone_already_used => 'This phone number is already in use';
  @override String get auth_create_account => 'Create my account';
  @override String get auth_already_have_account => 'I already have an account';

  @override String get onboarding_welcome => 'Welcome to THIX';
  @override String get onboarding_step_1_title => 'Connect';
  @override String get onboarding_step_1_desc => 'Create your secure THIX identity';
  @override String get onboarding_step_2_title => 'Protect';
  @override String get onboarding_step_2_desc => 'Enable 24/7 protection';
  @override String get onboarding_step_3_title => 'Act';
  @override String get onboarding_step_3_desc => 'Alert emergency services in 2 seconds';
  @override String get onboarding_get_started => 'Get Started';
  @override String get onboarding_skip => 'Skip intro';

  // ============================================================================
  // AUTHENTIFICATION & CONNEXION (ADVANCED / ERRORS)
  // ============================================================================
  @override String get login_title => 'Login to THIX';
  @override String get login_subtitle => 'Welcome back';
  @override String get login_identifier_label => 'Identifier';
  @override String get login_identifier_hint => 'Email, phone or THIX ID';
  @override String get login_password_label => 'Password';
  @override String get login_password_hint => 'Your secure password';
  @override String get login_remember_me => 'Remember me';
  @override String get login_forgot_password => 'Forgot password?';
  @override String get login_button => 'Login';
  @override String get login_verifying => 'Verifying...';
  @override String get login_retry_in => 'Retry in';
  @override String get login_seconds_suffix => 's';
  @override String get login_biometric => 'OR CONTINUE WITH';
  @override String get login_face_id => 'Face ID';
  @override String get login_touch_id => 'Touch ID';
  
  @override String get login_error_suspended => 'This account is suspended. Contact support.';
  @override String get login_error_not_active => 'This account is not active.';
  @override String get login_error_no_account => 'No account found with these details.';
  @override String get login_error_mfa_required => 'Two-factor authentication is required.';

  @override String get auth_error_identifier_required => 'Identifier is required';
  @override String get auth_error_password_required => 'Password is required';
  @override String get auth_error_thix_id_login_not_available => 'Login via THIX ID is not available at the moment';
  @override String get auth_error_sign_in_failed => 'Login failed. Please check your credentials.';
  @override String get auth_error_email_not_verified => 'Please verify your email before logging in';
  @override String get auth_error_server_misconfiguration => 'Server configuration error';
  @override String get auth_error_account_already_exists => 'An account already exists with this identifier';
  @override String get auth_error_account_exists_wrong_password => 'Account exists, but password is incorrect';
  @override String get auth_error_account_exists_new_otp_sent => 'A new OTP code has been sent to your address';
  @override String get auth_error_invalid_otp => 'Invalid or expired OTP code';
  @override String get auth_error_otp_expired => 'OTP code has expired';
  @override String get auth_error_network => 'Network error. Please check your internet connection.';
  @override String get auth_error_rate_limit => 'Too many attempts. Please try again later.';
  @override String get auth_error_technical => 'A technical error occurred. Please try again.';
  @override String get auth_error_user_mismatch => 'User mismatch detected';
  @override String get auth_error_profile_update_failed => 'Failed to update profile';
  @override String get auth_error_mark_email_verified_failed => 'Failed to verify email';
  @override String get auth_error_qr_token_generation_failed => 'Failed to generate QR token';
  @override String get auth_error_finalize_registration_failed => 'Failed to finalize registration';
  @override String get auth_error_consume_qr_token_failed => 'Failed to consume QR token';
  @override String get auth_error_resend_otp_failed => 'Failed to resend OTP code';
  @override String get auth_error_phone_auth_not_available => 'Phone authentication is not available';
  @override String get auth_error_delete_account_not_available => 'Account deletion is not available at the moment';
  @override String get auth_error_update_email_failed => 'Failed to update email address';
  @override String get auth_error_reset_password_failed => 'Failed to reset password';
  @override String get auth_error_sign_up_failed => 'Failed to create account';
  @override String get auth_info_otp_sent => 'A verification code has been sent';

  // ============================================================================
  // INSCRIPTION PERSONNELLE
  // ============================================================================
  @override String get reg_step1_title => 'Your profile';
  @override String get reg_step1_subtitle => 'Let\'s start with the basics';
  @override String get reg_full_name_label => 'Full Name';
  @override String get reg_full_name_hint => 'First and Last Name';
  @override String get reg_dob_label => 'Date of Birth';
  @override String get reg_country_label => 'Country of Residence';
  @override String get reg_occupation_label => 'Occupation / Activity';
  @override String get reg_occupation_hint => 'E.g., Developer, Student, Entrepreneur';
  @override String get reg_next => 'Next';

  @override String get reg_step2_title => 'Secure your account';
  @override String get reg_step2_subtitle => 'Create your login credentials';
  @override String get reg_email_label => 'Email Address';
  @override String get reg_email_hint => 'your.email@example.com';
  @override String get reg_phone_label => 'Phone Number';
  @override String get reg_phone_hint => '+1 555 XXX XXXX';
  @override String get reg_password_label => 'Password';
  @override String get reg_password_hint => 'Minimum 8 characters';
  @override String get reg_confirm_password_label => 'Confirm Password';
  @override String get reg_confirm_password_hint => 'Retype your password';
  @override String get reg_strength_label => 'Password strength';
  @override String get reg_strength_very_weak => 'Very weak';
  @override String get reg_strength_weak => 'Weak';
  @override String get reg_strength_medium => 'Medium';
  @override String get reg_strength_strong => 'Strong';
  @override String get reg_strength_excellent => 'Excellent';

  @override String get reg_identity_title => 'THIX Identity';
  @override String get reg_thix_chat_label => 'THIX Chat Username';
  @override String get reg_thix_chat_hint => 'E.g., john.doe (unique)';
  
  @override String get reg_verification_title => 'Verification';
  @override String get reg_get_otp => 'Get verification code';
  @override String get reg_code_sent_resend => 'Resend code';
  @override String get reg_resend_in => 'Resend in';
  @override String get reg_seconds_short => 's';
  @override String get reg_otp_label => 'Verification Code (OTP)';
  @override String get reg_validate_activate => 'Verify & Activate';
  @override String get reg_activating => 'Activating...';

  @override String get reg_congrats => 'Congratulations!';
  @override String get reg_welcome_message => 'Welcome to the THIX ecosystem,';
  @override String get reg_id_card_title => 'THIX DIGITAL IDENTITY CARD';
  @override String get reg_official_thix_id => 'OFFICIAL THIX ID';
  @override String get reg_generating => 'Generating...';
  @override String get reg_copy_thix_id => 'Copy THIX ID';
  @override String get reg_thix_id_copied => 'THIX ID copied to clipboard';
  @override String get reg_go_to_dashboard => 'Go to Dashboard';
  @override String get reg_summary => 'Registration Summary';
  @override String get reg_mobile_label => 'Mobile';
  @override String get reg_not_provided => 'Not provided';

  // ============================================================================
  // ACCUEIL & TABLEAU DE BORD
  // ============================================================================
  @override String get home_search_hint => 'Search for a service or contact...';
  @override String get home_greeting => 'Hello';
  @override String get home_greeting_time => 'Good evening';
  @override String get home_welcome_back => 'Welcome back';
  @override String get home_language_kiswahili => 'Kiswahili';
  @override String get home_banner_default_tag => 'YOUTH PROGRAM';
  @override String get home_banner_default_title => 'Discover the latest opportunities and events';
  
  @override String get cert_pending => 'Certification pending';
  @override String get cert_tier_ladder => 'Tier currently under review';
  @override String get cert_view => 'View';

  @override String get quick_sona => 'THIX Sona';
  @override String get quick_doc => 'My documents';
  @override String get quick_chat => 'Chat';
  @override String get quick_sos => 'Emergency';
  @override String get service_sante => 'THIX Health';
  @override String get service_market => 'THIX Market';
  @override String get service_money => 'THIX Wallet';
  @override String get service_reservation => 'Reservation';
  @override String get service_mon_pays => 'My Country';
  @override String get service_emploi => 'Jobs';
  @override String get service_formations => 'Training';
  @override String get service_opportunites => 'Opportunities';
  @override String get service_infos => 'News';
  @override String get service_events => 'Events';
  @override String get service_media => 'THIX Media';
  @override String get service_vault => 'Vault';
  @override String get service_network => 'Network';
  @override String get service_certification => 'Certification';

  // ============================================================================
  // CHAT & MESSAGERIE
  // ============================================================================
  @override String get chatlist_network => 'Network';
  @override String get chatlist_discussions => 'Chats';
  @override String get chatlist_create_new => 'Create new chat';
  @override String get chatlist_calls => 'Calls';
  @override String get chatlist_settings => 'Settings';

  @override String get chat_unknown_user => 'Unknown User';
  @override String chat_members(int count) => count == 1 ? '1 member' : '$count members';
  @override String get chat_video_call => 'Video call';
  @override String get chat_audio_call => 'Audio call';
  @override String get chat_escalate => 'Escalate';
  @override String get chat_history => 'History';
  @override String get chat_group_info => 'Group info';
  @override String get chat_file => 'File';
  @override String get chat_sticker => 'Sticker';
  @override String get chat_ephemeral => 'Ephemeral';
  @override String get chat_protected => 'Protected';
  @override String get chat_internal_note => 'Internal note';
  @override String get chat_send => 'Send';
  @override String get chat_recording => 'Recording';
  @override String get chat_stop_recording => 'Stop';
  @override String get chat_write_message => 'Write a message...';
  @override String get chat_record_audio => 'Record audio';
  @override String get chat_emojis => 'Emojis';
  @override String get chat_reactions => 'Reactions';
  @override String get chat_flags => 'Flags';
  @override String get chat_callback => 'Call back';
  @override String get chat_typing => 'typing...';
  @override String get chat_pause => 'Pause';
  @override String get chat_play => 'Play';

  @override String get conv_status_connected => 'Connected';
  @override String get conv_status_pending => 'Pending';
  @override String get conv_status_rejected => 'Rejected';
  @override String get conv_cannot_self => 'You cannot add yourself';
  @override String get conv_request_pending => 'Connection request pending';
  @override String get conv_request_rejected => 'Connection request rejected';
  @override String get conv_request_to => 'Send request to';
  @override String get conv_request_hint => 'Add an optional message to your connection request.';
  @override String get conv_message_optional => 'Message (optional)';
  @override String get conv_send_request => 'Send request';
  @override String get conv_request_sent => 'Request sent successfully';
  @override String get conv_request_exists => 'A request already exists for this user';
  @override String get conv_select_contact => 'Please select at least one contact';
  @override String get conv_waiting_connection => 'Waiting for connection to';
  @override String get conv_group_rpc_required => 'Group creation requires a server call';
  @override String get conv_page_title => 'New chat';
  @override String conv_start(int count) => 'Start ($count)';
  @override String get conv_search_label => 'Search user';
  @override String get conv_search_hint => 'Name, THIX ID, or phone number...';
  @override String get conv_group_name_label => 'Group name';
  @override String get conv_group_name_hint => 'E.g., Project Alpha Team';

  @override String get requests_page_title => 'Connection Requests';
  @override String get requests_reject_title => 'Reject request';
  @override String get requests_reject_message => 'Are you sure you want to reject this connection request? This action cannot be undone.';
  @override String get requests_reject_confirm => 'Reject';
  @override String get requests_rejected => 'Request rejected';
  @override String get requests_reject_error => 'Error rejecting request';
  @override String get requests_accepted => 'Request accepted successfully';
  @override String get requests_accept_error => 'Error accepting request';

  @override String get call_history_title => 'Call History';
  @override String get call_missed => 'Missed call';
  @override String get call_incoming => 'Incoming call';
  @override String get call_outgoing => 'Outgoing call';
  @override String get call_video => 'Video call';
  @override String get call_audio => 'Audio call';

  // ============================================================================
  // RÉSEAU SOCIAL
  // ============================================================================
  @override String get network_search_title => 'Search';
  @override String get network_search_hint => 'Search people, posts, or communities...';
  @override String get network_tab_people => 'People';
  @override String get network_tab_posts => 'Posts';
  @override String get network_tab_communities => 'Communities';
  @override String get network_explore_title => 'Explore the THIX Network';
  @override String get network_explore_subtitle => 'Find people, posts, or communities';
  @override String get network_no_results_users => 'No users found';
  @override String get network_no_results_posts => 'No posts found';
  @override String get network_no_results_communities => 'No communities found';
  @override String get network_request_sent => 'Request sent to';
  @override String get network_request_error => 'Error sending request';

  @override String get community_create_title => 'Create a community';
  @override String get community_name_label => 'Community name';
  @override String get community_description_label => 'Description';
  @override String get community_visibility_label => 'Visibility';
  @override String get community_public => 'Public';
  @override String get community_private => 'Private';
  @override String get community_join => 'Join';
  @override String get community_leave => 'Leave';
  @override String get community_members => 'members';
  @override String get community_admin => 'Admin';

  // ============================================================================
  // PROFIL UTILISATEUR
  // ============================================================================
  @override String get profile_settings => 'Profile settings';
  @override String get profile_edit_bio => 'Edit Bio';
  @override String get profile_no_bio => 'No bio available at the moment.';
  @override String get profile_followers => 'Followers';
  @override String get profile_following => 'Following';
  @override String get profile_posts => 'Posts';
  @override String get profile_follow => 'Follow';
  @override String get profile_unfollow => 'Following';
  @override String get profile_following_loading => 'Loading...';
  @override String get profile_message => 'Message';
  @override String get profile_block_user => 'Block this user?';
  @override String get profile_block_message => 'You will no longer see their posts and they will not be able to interact with you.';
  @override String get profile_block_confirm => 'Block';
  @override String get profile_blocked_success => 'User blocked';
  @override String get profile_block_error => 'Error blocking user';
  
  @override String get profile_report_user => 'Report';
  @override String get profile_report_reason => 'Reason';
  @override String get profile_report_details => 'Details (optional)';
  @override String get profile_report_spam => 'Spam';
  @override String get profile_report_inappropriate => 'Inappropriate content';
  @override String get profile_report_harassment => 'Harassment';
  @override String get profile_report_impersonation => 'Impersonation';
  @override String get profile_report_other => 'Other';
  @override String get profile_report_submit => 'Submit report';
  @override String get profile_report_success => 'Report submitted';
  @override String get profile_report_duplicate => 'Already reported';
  
  @override String get profile_private_gallery => 'Private Gallery';
  @override String get profile_private_content_locked => 'This content is private';
  @override String get profile_add_private_media => 'Add to my private gallery';
  @override String get profile_no_private_media => 'No private media yet';
  @override String get profile_upload_processing => 'Processing...';
  
  @override String get profile_tab_bio => 'Bio';
  @override String get profile_tab_private_gallery => 'Private Gallery';
  @override String get profile_tab_photos => 'Public Photos';
  @override String get profile_tab_videos => 'Videos';
  @override String get profile_tab_audios => 'Audios';
  @override String get profile_no_content => 'No content';
  @override String get profile_pinned_post => 'Pinned Post';
  @override String get profile_view_post => 'View post';

  // ============================================================================
  // PARAMÈTRES GÉNÉRAUX & CHAT (SETTINGS)
  // ============================================================================
  @override String get settings_title => 'Chat settings';
  @override String get settings_section_appearance => 'Appearance';
  @override String get settings_theme => 'Theme';
  @override String get settings_theme_light => 'Light';
  @override String get settings_theme_dark => 'Dark';
  @override String get settings_theme_system => 'System default';
  @override String get settings_wallpaper => 'Wallpaper';
  @override String get settings_wallpaper_default => 'Default';
  @override String get settings_wallpaper_custom => 'Custom';
  
  @override String get settings_section_privacy => 'Privacy';
  @override String get settings_last_seen => 'Last seen';
  @override String get settings_visibility_everyone => 'Everyone';
  @override String get settings_visibility_contacts => 'My contacts';
  @override String get settings_visibility_nobody => 'Nobody';
  @override String get settings_profile_photo => 'Profile photo';
  
  @override String get settings_section_notifications => 'Notifications';
  @override String get settings_messages => 'Messages';
  @override String get settings_calls => 'Calls';
  
  @override String get settings_section_messages => 'Data and Storage';
  @override String get settings_ephemeral => 'Ephemeral messages';
  @override String get settings_auto_download => 'Auto-download media';
  @override String get settings_download_wifi => 'Wi-Fi only';
  @override String get settings_download_mobile => 'Wi-Fi and Cellular';
  @override String get settings_download_never => 'Never';
  
  @override String get settings_section_account => 'Account';
  @override String get settings_view_profile => 'View my profile';
  @override String get settings_logout => 'Log out';

  @override String get settings_profile_edit => 'Edit profile';
  @override String get settings_notifications => 'Notifications';
  @override String get settings_privacy => 'Privacy';
  @override String get settings_security => 'Security';
  @override String get settings_language => 'Language';
  @override String get settings_help_center => 'Help Center';
  @override String get settings_about => 'About THIX';
  @override String get settings_version => 'Version';

  @override String get settings_choose_language => 'Choose Language';
  @override String get settings_system_default => 'System Default';
  @override String get settings_language_change_failed => 'Failed to change language';

  // ============================================================================
  // SOS & URGENCE
  // ============================================================================
  @override String get sos_button => 'Emergency';
  @override String get sos_button_label => 'SOS Emergency Button';
  @override String get sos_button_hint => 'Hold for 2 seconds to activate';
  @override String get sos_button_tooltip => 'Press and hold for 2 seconds';
  @override String get sos_trigger_button => 'Trigger SOS';
  @override String get sos_trigger_timeout => 'Request timed out. Please try again.';
  @override String get sos_trigger_error => 'Failed to trigger SOS';
  @override String get sos_active => 'SOS Active';
  @override String get sos_crisis_room => 'Crisis Room';
  @override String get sos_command_center => 'Command Center';
  @override String get sos_incident => 'Incident';
  @override String get sos_incident_unknown => 'Unknown incident';
  @override String get sos_incident_not_found => 'Incident not found';
  @override String get sos_circle => 'Circle';
  @override String get sos_rescuers => 'Rescuers';
  @override String get sos_rescuer => 'Rescuer';
  @override String get sos_my_rescuers => 'My rescuers';
  @override String get sos_duration => 'Duration';
  @override String get sos_identifier => 'Identifier';
  @override String get sos_calling => 'Calling...';
  @override String get sos_call => 'Call';
  @override String get sos_available => 'Available';
  @override String get sos_unavailable => 'Unavailable';
  @override String get sos_verified => 'Verified';
  @override String get sos_end => 'End';
  @override String get sos_end_sos => 'End SOS';
  @override String get sos_cancel_sos => 'Cancel SOS';
  @override String get sos_pin_required => 'Security PIN required';
  @override String get sos_cancelled => 'SOS Cancelled';
  @override String get sos_resolved => 'SOS Resolved';
  @override String get sos_cancel_failed => 'Failed to cancel';
  @override String get sos_in_progress => 'In progress';
  @override String get sos_history => 'History';
  @override String get sos_my_incidents => 'My incidents';
  @override String get sos_no_incidents => 'No incidents yet';
  @override String get sos_incidents_appear_here => 'Your SOS requests will appear here';
  @override String get sos_history_error => 'Failed to load history';
  @override String get sos_circle_1 => 'Circle 1 – Priority';
  @override String get sos_circle_2 => 'Circle 2 – Secondary';
  @override String get sos_circle_3 => 'Circle 3 – Emergency';
  @override String get sos_no_rescuers => 'No rescuers';
  @override String get sos_add_first_rescuer => 'Add your first emergency contact';
  @override String get sos_add_rescuer => 'Add rescuer';
  @override String get sos_add_rescuer_info => 'Enter the rescuer\'s THIX ID. Name and photo will be fetched automatically.';
  @override String get sos_thix_id_label => 'THIX ID';
  @override String get sos_thix_id_hint => 'THIX-XXXX';

  // ============================================================================
  // CERTIFICATION
  // ============================================================================
  @override String get certification_title => 'THIX Certification';
  @override String get certification_apply => 'Apply for certification';
  @override String get certification_status => 'Status';
  @override String get certification_pending => 'Pending';
  @override String get certification_approved => 'Approved';
  @override String get certification_rejected => 'Rejected';
  @override String get certification_tier_bronze => 'Bronze';
  @override String get certification_tier_silver => 'Silver';
  @override String get certification_tier_gold => 'Gold';
  @override String get certification_tier_platinum => 'Platinum';
  @override String get certification_benefits => 'Benefits';
  @override String get certification_documents => 'Required documents';
  @override String get certification_upload_doc => 'Upload document';
  @override String get certification_review_progress => 'Under review';
  @override String get certification_verified_account => 'Verified Account';

  // ============================================================================
  // ÉDUCATION & FORMATION
  // ============================================================================
  @override String get edu_nav_home => 'Home';
  @override String get edu_nav_learning => 'My Learning';
  @override String get edu_nav_library => 'Library';
  @override String get edu_nav_certs => 'Certificates';
  @override String get edu_nav_profile => 'Profile';
  
  @override String get edu_auth_required => 'Log in to view your courses';
  @override String get edu_login_required => 'Log in to view your courses';
  
  @override String get edu_learning_empty_title => 'No courses in progress';
  @override String get edu_learning_empty_desc => 'Enroll in a course to get started.';
  @override String get edu_no_courses => 'No courses in progress';
  @override String get edu_enroll_hint => 'Enroll in a course to get started.';
  @override String get edu_explore_btn => 'Explore courses';
  @override String get edu_completed => 'Completed';
  
  @override String get edu_user_avatar => 'User Avatar';
  @override String get edu_greeting => 'Hello,';
  @override String get edu_greeting_subtitle => 'Ready to improve your skills?';
  @override String get edu_ready_to_learn => 'Ready to improve your skills?';
  @override String get edu_learner => 'Learner';
  @override String get edu_notifications => 'Notifications';
  @override String get edu_search_hint => 'Search courses, certifications...';
  @override String get edu_browse => 'Browse';
  @override String get edu_library => 'Library';
  @override String get edu_certs => 'Certificates';
  @override String get edu_qa_browse => 'Browse';
  @override String get edu_instructor => 'Instructor';
  
  @override String get edu_top_formations => 'Top Courses';
  @override String get edu_awaited_formations => 'Most Anticipated';
  @override String get edu_awaited => 'Most Anticipated';
  @override String get edu_see_all => 'See Catalog';
  
  @override String edu_coming_soon(String category) => 'New $category courses coming soon';
  @override String get edu_coming_soon_cat => 'New courses coming here soon';
  @override String get edu_locked_course => 'Coming soon! (Opening expected shortly)';
  @override String get edu_coming_soon_badge => 'OPENING SOON';
  @override String get edu_awaited_badge => 'Coming Soon';
  @override String get edu_awaited_locked => 'Locked';
  @override String get edu_awaited_locked_msg => 'Coming soon! (Opening expected shortly)';
  
  @override String get edu_thix_academy => 'THIX Academy';
  @override String get edu_scheduled_soon => 'Scheduled for: Soon';
  @override String get edu_new_program => 'NEW PROGRAM';
  @override String get edu_resume_learning => 'RESUME LEARNING';
  @override String get edu_resume => 'Resume learning';
  
  @override String get edu_catalog => 'Catalog';
  @override String get edu_no_formations_cat => 'No courses in this category';
  
  @override String get edu_my_library => 'My Library';
  @override String get edu_search_book_hint => 'Search by title or author...';
  @override String get edu_library_title => 'My library';
  @override String get edu_search_library => 'Search by title or author...';
  @override String get edu_shelves_empty => 'Your shelves are empty.';
  @override String get edu_library_empty => 'Your shelves are empty.';
  @override String get edu_no_result => 'No results';
  @override String edu_search_no_results(String query) => 'No results for "$query"';
  
  @override String get edu_shelf => 'Shelf';
  @override String get edu_books => 'books';
  @override String get edu_all => 'All';
  @override String edu_shelf_info(String code, int count) => 'Shelf $code · $count books';
  @override String get edu_free => 'Free';
  @override String get edu_deleted_in => 'Will be removed in';
  @override String edu_expires_in(String countdown) => 'Expires in $countdown';
  
  @override String get edu_certifications => 'Certifications';
  @override String get edu_certs_title => 'Certifications';
  @override String get edu_no_certs => 'No certifications yet';
  @override String get edu_cert_expert => 'Expertise Certificate';
  @override String get edu_cert_expertise => 'Expertise Certificate';
  @override String edu_cert_issued(String date) => 'Issued on $date';
  
  @override String get edu_pro_account => 'Professional Account';
  @override String get edu_profile_title => 'Professional Account';
  @override String get edu_instructor_space => 'Instructor Dashboard';
  @override String get edu_tools => 'Institutional Tools';
  @override String get edu_institutional_tools => 'Institutional Tools';
  @override String get edu_free_resources => 'Open Resources';
  @override String get edu_masterclass => 'Masterclass';
  @override String get edu_masterclasses => 'Masterclasses';
  @override String get edu_network => 'Network & Mentorship';
  @override String get edu_mentorship => 'Networking & Mentorship';
  @override String get edu_events_agenda => 'Events Agenda';
  @override String get edu_support => 'Technical Support';
  @override String get edu_not_connected => 'Not connected';

  @override String get training_title => 'Training';
  @override String get training_enroll => 'Enroll';
  @override String get training_my_courses => 'My Courses';
  @override String get training_certificates => 'My Certificates';
  @override String get training_progress => 'Progress';
  @override String get training_lessons => 'Lessons';
  @override String get training_duration => 'Duration';
  @override String get training_level => 'Level';
  @override String get training_beginner => 'Beginner';
  @override String get training_intermediate => 'Intermediate';
  @override String get training_advanced => 'Advanced';
  @override String get training_start_course => 'Start Course';
  @override String get training_continue_course => 'Continue Course';

  // ============================================================================
  // EMPLOIS & RECRUTEMENT
  // ============================================================================
  @override String get jobs_title => 'Jobs';
  @override String get jobs_search => 'Search Jobs';
  @override String get jobs_apply => 'Apply';
  @override String get jobs_saved => 'Saved';
  @override String get jobs_applied => 'Applications Sent';
  @override String get jobs_company => 'Company';
  @override String get jobs_location => 'Location';
  @override String get jobs_salary => 'Salary';
  @override String get jobs_type => 'Type';
  @override String get jobs_full_time => 'Full-time';
  @override String get jobs_part_time => 'Part-time';
  @override String get jobs_contract => 'Contract';
  @override String get jobs_internship => 'Internship';
  @override String get jobs_freelance => 'Freelance';
  @override String get jobs_remote => 'Remote';
  @override String get jobs_onsite => 'On-site';
  @override String get jobs_hybrid => 'Hybrid';
  @override String get jobs_experience => 'Experience';
  @override String get jobs_no_experience => 'Entry Level';
  @override String get jobs_junior => 'Junior';
  @override String get jobs_mid => 'Mid-level';
  @override String get jobs_senior => 'Senior';
  @override String get jobs_requirements => 'Requirements';
  @override String get jobs_responsibilities => 'Responsibilities';
  @override String get jobs_benefits => 'Benefits';
  @override String get jobs_apply_now => 'Apply Now';
  @override String get jobs_application_sent => 'Application Sent';
  @override String get jobs_no_results => 'No jobs found';
  @override String get recruiter_title => 'Recruiter';
  @override String get recruiter_post_job => 'Post a Job';
  @override String get recruiter_candidates => 'Candidates';
  @override String get recruiter_applications => 'Applications';
  @override String get recruiter_interviews => 'Interviews';

  // ============================================================================
  // OPPORTUNITÉS
  // ============================================================================
  @override String get opportunities_title => 'Opportunities';
  @override String get opportunities_business => 'Business';
  @override String get opportunities_investment => 'Investment';
  @override String get opportunities_partnership => 'Partnership';
  @override String get opportunities_grant => 'Grant';
  @override String get opportunities_coming_soon => 'Coming Soon';

  // ============================================================================
  // MARCHÉ & E-COMMERCE
  // ============================================================================
  @override String get market_title => 'THIX Market';
  @override String get market_categories => 'Categories';
  @override String get market_products => 'Products';
  @override String get market_services => 'Services';
  @override String get market_add_to_cart => 'Add to Cart';
  @override String get market_buy_now => 'Buy Now';
  @override String get market_cart => 'Cart';
  @override String get market_checkout => 'Checkout';
  @override String get market_total => 'Total';
  @override String get market_delivery => 'Delivery';
  @override String get market_seller => 'Seller';
  @override String get market_rating => 'Rating';
  @override String get market_reviews => 'Reviews';
  @override String get market_in_stock => 'In Stock';
  @override String get market_out_of_stock => 'Out of Stock';
  @override String get market_add_to_favorites => 'Add to Favorites';
  @override String get market_remove_from_cart => 'Remove from Cart';

  // ============================================================================
  // PORTEFEUILLE & ARGENT
  // ============================================================================
  @override String get money_title => 'THIX Wallet';
  @override String get money_balance => 'Balance';
  @override String get money_send => 'Send';
  @override String get money_receive => 'Receive';
  @override String get money_history => 'History';
  @override String get money_transactions => 'Transactions';
  @override String get money_top_up => 'Top Up';
  @override String get money_withdraw => 'Withdraw';
  @override String get money_transfer => 'Transfer';
  @override String get money_bills => 'Bills';
  @override String get money_recipients => 'Recipients';
  @override String get money_add_recipient => 'Add a recipient';
  @override String get money_amount => 'Amount';
  @override String get money_fee => 'Fee';
  @override String get money_reference => 'Reference';
  @override String get money_confirm_transfer => 'Confirm Transfer';
  @override String get money_transfer_success => 'Transfer Successful';
  @override String get money_transfer_failed => 'Transfer Failed';
  @override String get money_insufficient_funds => 'Insufficient funds';

  // ============================================================================
  // ÉVÉNEMENTS & BILLETS
  // ============================================================================
  @override String get events_title => 'Events';
  @override String get events_upcoming => 'Upcoming';
  @override String get events_past => 'Past';
  
  @override String get event_share_cta => 'Secure your spot on THIX!';
  @override String get event_sold_out_title => 'Event Sold Out';
  @override String get event_sold_out_msg => 'All spots are currently booked. Join the waitlist to be notified if spots become available.';
  @override String get event_join_queue_confirm => 'Would you like to join the waitlist?';
  @override String get event_join_queue_btn => 'Join Waitlist';
  
  @override String get event_unfavorite => 'Remove from favorites';
  @override String get event_favorite => 'Add to favorites';
  @override String get event_free => 'Free';
  @override String get event_paid => 'Paid';
  
  @override String get event_time_label => 'Time';
  @override String get event_location_label => 'Location';
  @override String get event_address_label => 'Exact Address';
  @override String get event_organized_by => 'Organized by';
  
  @override String get event_about_title => 'About';
  @override String get event_no_description => 'No description available for this event.';
  @override String get event_tickets_title => 'Tickets & Booking';
  
  @override String get event_sold_out_short => 'SOLD OUT';
  @override String event_remaining_seats(String count) => '$count spots remaining';
  @override String get event_queue_btn => 'WAITLIST';
  @override String get event_book_btn => 'BOOK';
  
  @override String get event_standard_entry => 'Standard Entry';
  @override String get event_all_sold => 'All seats are sold out';
  @override String get event_limited_seats => 'Limited spots';
  @override String get event_book_now_btn => 'BOOK NOW';
  
  @override String event_numbered_seats(String count) => '$count numbered seats';
  @override String get event_choose_seats_btn => 'CHOOSE MY SEATS';
  @override String get event_from_price => 'From';

  @override String get events_my_tickets => 'My Tickets';
  @override String get events_buy_ticket => 'Buy a Ticket';
  @override String get events_ticket_price => 'Ticket Price';
  @override String get events_date => 'Date';
  @override String get events_time => 'Time';
  @override String get events_venue => 'Venue';
  @override String get events_organizer => 'Organizer';
  @override String get events_attendees => 'Attendees';
  @override String get events_seats_available => 'Available Seats';
  @override String get events_sold_out => 'Sold Out';
  @override String get events_book_now => 'Book Now';
  @override String get events_ticket_type => 'Ticket Type';
  @override String get ticket_standard => 'Standard';
  @override String get ticket_vip => 'VIP';
  @override String get ticket_gold => 'Gold';
  @override String get ticket_family => 'Family';
  @override String get ticket_secure_ticket => 'Secure Ticket';
  @override String get ticket_not_found => 'Ticket not found';
  @override String get ticket_location => 'Location';
  @override String get ticket_pin_label => 'PIN Code';
  @override String get ticket_show_qr => 'Show QR';
  @override String get ticket_booking_id => 'Booking ID';
  @override String get ticket_add_wallet => 'Wallet';
  @override String get ticket_wallet_coming_soon => 'Wallet integration coming soon';
  @override String get ticket_share => 'Share';
  @override String get ticket_share_text => 'My THIX Ticket';
  @override String get ticket_scan_info => 'Present this QR code at the entrance';
  @override String get ticket_security_title => 'Security';
  @override String get ticket_enter_pin => 'Enter your PIN';
  @override String get ticket_pin_hint => '4-digit code';
  @override String get ticket_pin_incorrect => 'Incorrect PIN';
  @override String get ticket_pin_too_many_attempts => 'Too many attempts';
  @override String get ticket_attempts_remaining => 'Attempts remaining';
  @override String get tickets_ticket => 'Ticket';
  @override String get tickets_completed => 'Completed';
  @override String get tickets_no_tickets => 'No tickets';
  @override String get tickets_no_tickets_desc => 'Your bookings will appear here';
  @override String get tickets_discover => 'Discover Events';
  @override String get tickets_load_error => 'Failed to load your tickets';
  @override String tickets_quantity(int count) => count == 0 ? 'No tickets' : (count == 1 ? '1 ticket' : '$count tickets');

  // ============================================================================
  // RÉSERVATIONS
  // ============================================================================
  @override String get reservation_title => 'Reservations';
  @override String get reservation_hotel => 'Hotel';
  @override String get reservation_restaurant => 'Restaurant';
  @override String get reservation_transport => 'Transport';
  @override String get reservation_check_in => 'Check-in';
  @override String get reservation_check_out => 'Check-out';
  @override String get reservation_guests => 'Guests';
  @override String get reservation_rooms => 'Rooms';
  @override String get reservation_book => 'Book';
  @override String get reservation_cancel => 'Cancel';
  @override String get reservation_modify => 'Modify';
  @override String get reservation_confirm => 'Confirm Reservation';
  @override String get reservation_my_bookings => 'My Bookings';

  // ============================================================================
  // SANTÉ
  // ============================================================================
  @override String get health_title => 'THIX Health';
  @override String get health_appointments => 'Appointments';
  @override String get health_doctors => 'Doctors';
  @override String get health_hospitals => 'Hospitals';
  @override String get health_pharmacies => 'Pharmacies';
  @override String get health_emergency => 'Emergency';
  @override String get health_medical_records => 'Medical Records';
  @override String get health_prescriptions => 'Prescriptions';
  @override String get health_book_appointment => 'Book Appointment';
  @override String get health_appointment_date => 'Appointment Date';
  @override String get health_specialty => 'Specialty';
  @override String get health_consultation => 'Consultation';
  @override String get health_telemedicine => 'Telemedicine';
  @override String get health_insurance => 'Insurance';
  @override String get health_symptoms => 'Symptoms';
  @override String get health_find_doctor => 'Find a Doctor';

  // ============================================================================
  // MÉDIA & INFOS
  // ============================================================================
  @override String get media_title => 'THIX Media';
  @override String get media_news => 'News';
  @override String get media_videos => 'Videos';
  @override String get media_podcasts => 'Podcasts';
  @override String get media_articles => 'Articles';
  @override String get media_live => 'Live';
  @override String get media_categories => 'Categories';
  @override String get media_bookmarks => 'Bookmarks';
  @override String get media_share_article => 'Share Article';
  @override String get media_read_more => 'Read More';
  @override String get media_published_on => 'Published on';
  @override String get media_author => 'Author';
  @override String get info_title => 'News';
  @override String get info_local => 'Local';
  @override String get info_national => 'National';
  @override String get info_international => 'International';
  @override String get info_sports => 'Sports';
  @override String get info_culture => 'Culture';
  @override String get info_economy => 'Economy';
  @override String get info_politics => 'Politics';
  @override String get info_technology => 'Technology';
  @override String get info_read_full => 'Read Full Article';

  // ============================================================================
  // MON PAYS
  // ============================================================================
  @override String get mon_pays_title => 'My Country';
  @override String get mon_pays_regions => 'Regions';
  @override String get mon_pays_cities => 'Cities';
  @override String get mon_pays_culture => 'Culture';
  @override String get mon_pays_history => 'History';
  @override String get mon_pays_tourism => 'Tourism';
  @override String get mon_pays_discover => 'Discover';
  @override String get mon_pays_landmarks => 'Landmarks';
  @override String get mon_pays_traditions => 'Traditions';

  // ============================================================================
  // COFFRE-FORT
  // ============================================================================
  @override String get vault_title => 'Vault';
  @override String get vault_documents => 'Documents';
  @override String get vault_photos => 'Photos';
  @override String get vault_videos => 'Videos';
  @override String get vault_notes => 'Notes';
  @override String get vault_passwords => 'Passwords';
  @override String get vault_add_document => 'Add Document';
  @override String get vault_upload => 'Upload';
  @override String get vault_encrypted => 'Encrypted';
  @override String get vault_backup => 'Backup';
  @override String get vault_restore => 'Restore';
  @override String get vault_share_secure => 'Secure Share';
  @override String get vault_unlock => 'Unlock';
  @override String get vault_lock => 'Lock';

  // ============================================================================
  // PAIEMENT
  // ============================================================================
  @override String get payment_title => 'Payment';
  @override String get payment_method => 'Payment Method';
  @override String get payment_card => 'Credit/Debit Card';
  @override String get payment_mobile_money => 'Mobile Money';
  @override String get payment_bank_transfer => 'Bank Transfer';
  @override String get payment_cash => 'Cash';
  @override String get payment_confirm => 'Confirm Payment';
  @override String get payment_success => 'Payment Successful';
  @override String get payment_failed => 'Payment Failed';
  @override String get payment_processing => 'Processing...';
  @override String get payment_receipt => 'Receipt';
  @override String get payment_invoice => 'Invoice';

  // ============================================================================
  // RECHERCHE (MISSING PERSONS / SEARCH)
  // ============================================================================
  @override String get search_title => 'THIX Search';
  @override String get search_subtitle => 'Missing Persons and Official Notices';
  @override String get search_person_missing => 'Missing Person';
  @override String get search_person_wanted => 'Official Wanted Notice';
  @override String get search_report_missing => 'Report Missing Person';
  @override String get search_report_found => 'Report Person Found';
  @override String get search_details => 'Details';
  @override String get search_contact_authorities => 'Contact Authorities';
  @override String get search_share_alert => 'Share Alert';
  @override String get search_last_seen => 'Last seen at';
  @override String get search_description => 'Description';
  @override String get search_age => 'Age';
  @override String get search_height => 'Height';
  @override String get search_weight => 'Weight';
  @override String get search_hair_color => 'Hair Color';
  @override String get search_eye_color => 'Eye Color';
  @override String get search_distinguishing_marks => 'Distinguishing Marks';
  @override String get search_clothing => 'Clothing';
  @override String get search_circumstances => 'Circumstances';
  @override String get search_case_number => 'Case Number';
  @override String get search_reported_by => 'Reported by';
  @override String get search_official_notice => 'Official Notice';
  @override String get search_community_alert => 'Community Alert';

  // ============================================================================
  // À PROXIMITÉ & ALERTES
  // ============================================================================
  @override String get nearby_alerts_title => 'Nearby Alerts';
  @override String get nearby_view_on_map => 'View on Map';
  @override String get nearby_map_coming_soon => 'Full screen map coming soon';
  @override String get nearby_map_disabled => 'Map disabled (pending API key)';
  @override String get nearby_active_alerts => 'Active Alerts';
  @override String get nearby_missing => 'Missing';
  @override String get nearby_official => 'Official';
  @override String get nearby_legend_missing => 'Missing Person';
  @override String get nearby_legend_official => 'Official Notice';
  @override String get nearby_legend_report => 'Report';
  @override String get nearby_location_required => 'Enable Location Services';
  @override String get nearby_location_subtitle => 'See alerts around you';

  // ============================================================================
  // ADMINISTRATION
  // ============================================================================
  @override String get admin_title => 'THIX Administration';
  @override String get admin_dev_open => 'Open Development';
  @override String get admin_actions_section => 'Actions';
  
  @override String get admin_events_title => 'Events';
  @override String get admin_events_create => 'Create';
  @override String get admin_events_search_hint => 'Search by title...';
  @override String get admin_events_filter => 'Category filter';
  @override String get admin_events_empty => 'No events found';
  @override String get admin_events_no_permission => 'You do not have permission to perform this action';
  @override String get admin_events_delete_title => 'Delete?';
  @override String admin_events_delete_desc(String title) => 'Are you sure you want to delete $title? This action cannot be undone.';

  @override String get admin_limits_purchase_rules => 'Purchase Rules';
  @override String get admin_limits_max_person => 'Max / person (global)';
  @override String get admin_limits_max_transaction => 'Max / transaction (cart)';
  @override String get admin_limits_require_thix_id => 'THIX ID Verification Required';
  @override String get admin_limits_require_thix_id_desc => 'Recommended for high demand events.';
  @override String get admin_limits_info_title => 'Secure Architecture';
  @override String get admin_limits_info_desc => 'These limits are enforced and verified directly by SQL Edge Functions in real-time to prevent race conditions and fraud.';

  @override String get admin_stat_events => 'Events';
  @override String get admin_stat_bookings => 'Bookings';
  @override String get admin_stat_revenue => 'Revenue';
  @override String get admin_stat_queue => 'Queue';
  @override String get admin_action_events => 'Events';
  @override String get admin_action_events_sub => '20 / page';
  @override String get admin_action_create => 'Create';
  @override String get admin_action_create_sub => 'Upload + Verify';
  @override String get admin_action_seats => 'Seats';
  @override String get admin_action_seats_sub => 'Batch of 200';
  @override String get admin_action_reservations => 'Reservations';
  @override String get admin_action_reservations_sub => '50 / page + Filters';
  @override String get admin_action_limits => 'Anti-Fraud';
  @override String get admin_action_limits_sub => 'Limits';
  @override String get admin_action_analytics => 'Analytics';
  @override String get admin_action_analytics_sub => 'RPC';
  @override String get admin_read_only => 'Read Only';
  @override String get admin_bookings_title => 'Bookings • 50/page';
  @override String get admin_bookings_export => 'Server export in progress (job)';
  @override String get admin_bookings_details => 'Ticket Details';
  @override String get admin_bookings_event => 'Event';
  @override String get admin_bookings_unknown_event => 'Unknown event';
  @override String get admin_bookings_id => 'Booking ID';
  @override String get admin_bookings_quantity => 'Quantity';
  @override String get admin_bookings_category => 'Category';
  @override String get admin_bookings_amount => 'Amount';
  @override String get admin_bookings_pin => 'PIN';
  @override String get admin_bookings_purchase_date => 'Purchase Date';
  @override String get admin_bookings_close => 'Close';
  @override String get admin_bookings_empty => 'No bookings found';
  @override String get admin_bookings_unknown_date => 'Unknown date';
  @override String admin_bookings_places(int count) => '$count places';
  @override String get admin_bookings_status_valid => 'Valid';
  @override String get admin_bookings_status_used => 'Used';
  @override String get admin_bookings_status_cancelled => 'Cancelled';
  @override String get admin_bookings_status_postponed => 'Postponed';
  @override String get admin_bookings_status_pending => 'Pending';
  @override String admin_queue_title(int count) => 'Waiting Queue • Real-time ($count)';
  @override String get admin_queue_realtime_desc => 'Real-time active • Updates automatically when users join';
  @override String get admin_queue_empty => 'Queue is empty';
  @override String get admin_queue_event_fallback => 'Event';
  @override String admin_queue_item_meta(String userId, int qty, String status) => 'User: $userId • $qty places • $status';
  @override String get admin_queue_notify => 'Notify';
  @override String get admin_queue_notified => 'User notified (expires in 10 mins)';
  @override String get admin_queue_position => 'Position';
  @override String get admin_queue_places => 'Places';
  @override String get admin_analytics_title => 'Analytics • Performance';
  @override String get admin_analytics_fill_rate => 'Fill Rate';
  @override String get admin_analytics_avg_cart => 'Average Cart';
  @override String get admin_analytics_no_show => 'No-Show Rate';
  @override String get admin_analytics_rev_per_event => 'Revenue / event';
  @override String get admin_analytics_revenue_7d => '7-Day Revenue';
  @override String get admin_analytics_no_data => 'No data available';
  @override String get admin_analytics_error => 'Failed to load statistics';
  @override String get admin_event_create => 'Create Event';
  @override String get admin_event_edit => 'Edit Event';
  @override String get admin_event_btn_create => 'Create';
  @override String get admin_event_btn_save => 'Save';
  @override String get admin_event_cover => 'Cover Image';
  @override String get admin_event_banner => 'Banner';
  @override String get admin_event_title => 'Title *';
  @override String get admin_event_desc => 'Description *';
  @override String get admin_event_category => 'Category';
  @override String get admin_event_subcategory => 'Subcategory';
  @override String get admin_event_datetime => 'Date and Time';
  @override String get admin_event_start => 'Start';
  @override String get admin_event_end => 'End (optional)';
  @override String get admin_event_add_end => 'Add End Time';
  @override String get admin_event_city => 'City *';
  @override String get admin_event_location => 'Venue *';
  @override String get admin_event_address => 'Address';
  @override String get admin_event_organizer => 'Organizer';
  @override String get admin_event_phone => 'Phone';
  @override String get admin_event_email => 'Contact Email';
  @override String get admin_event_tiers_title => 'Tiers and Capacity';
  @override String get admin_event_add_tier_btn => 'Add VVIP, VIP...';
  @override String get admin_event_status => 'Status';
  @override String get admin_event_visibility => 'Visibility';
  @override String get admin_event_cat_concert => 'Concert';
  @override String get admin_event_cat_conference => 'Conference';
  @override String get admin_event_cat_sport => 'Sport';
  @override String get admin_event_cat_festival => 'Festival';
  @override String get admin_event_cat_theatre => 'Theatre';
  @override String get admin_event_cat_other => 'Other';
  @override String get admin_event_status_upcoming => 'Upcoming';
  @override String get admin_event_status_ongoing => 'Ongoing';
  @override String get admin_event_status_completed => 'Completed';
  @override String get admin_event_status_cancelled => 'Cancelled';
  @override String get admin_event_vis_default => 'Upcoming (default)';
  @override String get admin_event_vis_recommended => 'Recommended';
  @override String get admin_event_vis_featured => 'Featured';
  @override String get admin_event_dialog_add_tier => 'Add Tier';
  @override String get admin_event_dialog_name => 'Name (e.g., VVIP)';
  @override String admin_event_dialog_price(String currency) => 'Price ($currency)';
  @override String get admin_event_dialog_capacity => 'Capacity';
  @override String get admin_event_dialog_cancel => 'Cancel';
  @override String get admin_event_dialog_add => 'Add';
  @override String get admin_event_err_readonly => 'Read Only';
  @override String get admin_event_err_min_tier => 'At least one tier is required';
  @override String get admin_event_success => 'Event saved successfully';
  @override String get admin_event_err_title_req => 'Title is required';
  @override String get admin_event_err_desc_min => 'Minimum 10 characters';
  @override String get admin_event_err_city_req => 'City is required';
  @override String get admin_event_err_loc_req => 'Venue is required';
  @override String get admin_seat_page_title => 'Seat Map & Pricing';
  @override String get admin_seat_target_event => 'Target Event';
  @override String get admin_seat_select_event => 'Select an event';
  @override String admin_seat_max_limit(int count) => 'Maximum limit $count seats';
  @override String admin_seat_generated(int count) => '$count seats generated';
  @override String get admin_seat_load_error => 'Failed to load seats';
  @override String get admin_seat_pricing_title => 'Dynamic Pricing';
  @override String get admin_seat_layout_title => 'Layout and Shape';
  @override String get admin_seat_rows => 'Rows';
  @override String get admin_seat_per_row => 'Seats / row';
  @override String get admin_seat_center_aisle => 'Center Aisle';
  @override String get admin_seat_aisle_desc => 'Empty space in the middle';
  @override String get admin_seat_cats_per_row => 'Categories per row';
  @override String get admin_seat_generating => 'Generating...';
  @override String admin_seat_generate_btn(int count) => 'Generate $count seats';
  @override String get admin_seat_preview => 'Current layout preview';
  @override String get admin_seat_no_seats => 'No seats generated';
  @override String get admin_seat_cat_standard => 'Standard';
  @override String get admin_seat_cat_vip => 'VIP';
  @override String get admin_seat_cat_gold => 'Gold';
  @override String get admin_seat_cat_family => 'Family';
  @override String get admin_seat_legend_reserved => 'Reserved';
  @override String get admin_seat_legend_sold => 'Sold';
  @override String get seat_map_stage => 'Stage';

  // ============================================================================
  // ERREURS & VALIDATION
  // ============================================================================
  @override String get error_generic => 'An error occurred';
  @override String get error_validation => 'Invalid data';
  @override String get error_file_too_large => 'File too large';
  @override String get error_unsupported_format => 'Unsupported format';
  @override String get error_permission_denied => 'Permission denied';
  @override String get error_camera_unavailable => 'Camera unavailable';
  @override String get error_microphone_unavailable => 'Microphone unavailable';
  @override String get error_location_unavailable => 'Location services unavailable';
  @override String get error_network => 'Network error';
  @override String get error_timeout => 'Request timed out';
  @override String get error_server => 'Server error';
  @override String get error_not_found => 'Not found';

  // ============================================================================
  // TEMPS & DATES RELATIVES
  // ============================================================================
  @override String get common_just_now => 'Just now';
  @override String get common_in_the_future => 'Later';
  @override String common_minutes_ago(int count) => count == 1 ? '1 minute ago' : '$count minutes ago';
  @override String common_hours_ago(int count) => count == 1 ? '1 hour ago' : '$count hours ago';
  @override String common_days_ago(int count) => count == 1 ? '1 day ago' : '$count days ago';
  @override String common_seconds_ago(int count) => count == 1 ? '1 second ago' : '$count seconds ago';
  @override String common_weeks_ago(int count) => count == 1 ? '1 week ago' : '$count weeks ago';
  @override String common_months_ago(int count) => count == 1 ? '1 month ago' : '$count months ago';
  @override String common_years_ago(int count) => count == 1 ? '1 year ago' : '$count years ago';
  @override String common_in_minutes(int count) => count == 1 ? 'In 1 minute' : 'In $count minutes';
  @override String common_in_hours(int count) => count == 1 ? 'In 1 hour' : 'In $count hours';
  @override String common_in_days(int count) => count == 1 ? 'In 1 day' : 'In $count days';

  // ============================================================================
  // THIX MEDIA & IA SOURCES
  // ============================================================================
  @override String get live_go_live => 'Go Live';
  @override String get live_title => 'Live Title';
  @override String get live_start => 'Start Live';
  @override String get live_end => 'End Live';
  @override String get live_duration => 'Duration';
  @override String get live_peak_viewers => 'Peak Viewers';
  @override String get live_chat_disabled => 'Chat is disabled.';
  @override String get live_share => 'Share';
  @override String get live_report => 'Report';
  @override String get live_follow_host => 'Follow';
  @override String get live_gift_send => 'Send Gift';
  @override String get live_quality_auto => 'Auto';
  @override String get live_quality_hd => 'HD';
  @override String get live_quality_sd => 'SD';
  @override String get live_quality_low => 'Low';

  @override String get insight_source_unverified => 'Unverified Source';
  @override String get insight_recommended_actions => 'Recommended Actions';
  @override String get insight_key_findings => 'Key Findings';
  @override String get insight_summary => 'Summary';
  @override String get insight_full_analysis => 'Full Analysis';
  @override String get insight_generated_by => 'AI Generated';
  @override String get insight_disclaimer => 'This is an AI-generated analysis. Please verify information independently.';

  @override String get risk_level_label => 'Risk Level';
  @override String get risk_mitigation => 'Mitigation';
  @override String get risk_impact => 'Impact';
  @override String get risk_probability => 'Probability';
  @override String get risk_assessment => 'Risk Assessment';

  @override String get live_leave_btn => 'Leave Live';
  @override String get live_chat_empty => 'No messages yet.';
  @override String get live_chat_hint => 'Say something...';
  @override String get live_like => 'Like';
  @override String get live_send => 'Send';
  @override String get live_viewers => 'viewers';
  @override String get live_likes => 'likes';
  @override String get live_leaving => 'Leaving...';
  @override String get live_network_quality => 'Network Quality';
  @override String get insight_type_market => 'Market';
  @override String get insight_type_finance => 'Finance';
  @override String get insight_type_strategy => 'Strategy';
  @override String get insight_type_business => 'Business';
  @override String get insight_type_insight => 'Insight';
  @override String get insight_confidence_label => 'Confidence Score';
  @override String get insight_source_verified => 'Verified Source';
  @override String get risk_critical => 'Critical';
  @override String get risk_high => 'High';
  @override String get risk_medium => 'Medium';
  @override String get risk_low => 'Low';
  @override String get source_type_official => 'Official';
  @override String get source_type_world_bank => 'World Bank';
  @override String get source_type_government => 'Government';
  @override String get source_type_default => 'Verified Source';
  @override String get source_aria_label => 'Information Source';
}
