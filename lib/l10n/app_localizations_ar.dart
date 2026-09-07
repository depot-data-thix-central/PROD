// lib/l10n/app_localizations_ar.dart
import 'app_localizations.dart';

class AppLocalizationsAr extends AppLocalizations {
  // ============================================================================
  // COMMON & UI
  // ============================================================================
  @override String get common_back => 'رجوع';
  @override String get common_close => 'إغلاق';
  @override String get common_cancel => 'إلغاء';
  @override String get common_confirm => 'تأكيد';
  @override String get common_delete => 'حذف';
  @override String get common_add => 'إضافة';
  @override String get common_edit => 'تعديل';
  @override String get common_save => 'حفظ';
  @override String get common_manage => 'إدارة';
  @override String get common_retry => 'إعادة المحاولة';
  @override String get common_refresh => 'تحديث';
  @override String get common_search => 'بحث';
  @override String get common_open => 'فتح';
  @override String get common_share => 'مشاركة';
  @override String get common_copy => 'نسخ';
  @override String get common_copied => 'تم النسخ!';
  @override String get common_download => 'تنزيل';
  @override String get common_upload => 'رفع';
  @override String get common_send => 'إرسال';
  @override String get common_receive => 'استلام';
  @override String get common_accept => 'قبول';
  @override String get common_reject => 'رفض';
  @override String get common_skip => 'تخطي';
  @override String get common_next => 'التالي';
  @override String get common_previous => 'السابق';
  @override String get common_finish => 'إنهاء';
  @override String get common_done => 'تم';
  @override String get common_error => 'خطأ';
  @override String get common_success => 'نجاح';
  @override String get common_loading => 'جاري التحميل…';
  @override String get common_please_wait => 'يرجى الانتظار…';
  @override String get common_today => 'اليوم';
  @override String get common_yesterday => 'أمس';
  @override String get common_tomorrow => 'غداً';
  @override String get common_home => 'الرئيسية';
  @override String get common_chat => 'دردشة';
  @override String get common_map => 'الخريطة';
  @override String get common_profile => 'الملف الشخصي';
  @override String get common_menu => 'القائمة';
  @override String get common_notifications => 'الإشعارات';
  @override String get common_settings => 'الإعدادات';
  @override String get common_help => 'المساعدة';
  @override String get common_about => 'حول';
  @override String get common_logout => 'تسجيل الخروج';
  @override String get common_login => 'تسجيل الدخول';
  @override String get common_signup => 'إنشاء حساب';
  @override String get common_yes => 'نعم';
  @override String get common_no => 'لا';
  @override String get common_or => 'أو';
  @override String get common_and => 'و';
  @override String get common_none => 'لا شيء';
  @override String get common_all => 'الكل';
  @override String get common_unknown => 'غير معروف';
  @override String get common_enabled => 'مُفعّل';
  @override String get common_disabled => 'مُعطّل';
  @override String get common_clear => 'مسح';
  @override String get common_remove => 'إزالة';
  
  @override String common_items(int count) => count == 0 ? 'لا توجد عناصر' : (count == 1 ? 'عنصر 1' : '$count عناصر');
  @override String common_contacts(int count) => count == 0 ? 'لا توجد جهات اتصال' : (count == 1 ? 'جهة اتصال 1' : '$count جهات اتصال');
  @override String common_messages(int count) => count == 0 ? 'لا توجد رسائل' : (count == 1 ? 'رسالة 1' : '$count رسائل');
  @override String common_days(int count) => count == 0 ? '0 يوم' : (count == 1 ? 'يوم 1' : '$count أيام');
  @override String common_hours(int count) => count == 0 ? '0 ساعة' : (count == 1 ? 'ساعة 1' : '$count ساعات');
  @override String common_minutes(int count) => count == 0 ? '0 دقيقة' : (count == 1 ? 'دقيقة 1' : '$count دقائق');

  // ============================================================================
  // AUTH & ONBOARDING (BASIC)
  // ============================================================================
  @override String get auth_login => 'تسجيل الدخول';
  @override String get auth_signup => 'إنشاء حساب';
  @override String get auth_forgot_password => 'هل نسيت كلمة المرور؟';
  @override String get auth_reset_password => 'إعادة تعيين كلمة المرور';
  @override String get auth_email => 'البريد الإلكتروني';
  @override String get auth_phone => 'رقم الهاتف';
  @override String get auth_password => 'كلمة المرور';
  @override String get auth_confirm_password => 'تأكيد كلمة المرور';
  @override String get auth_logout_confirm => 'هل أنت متأكد أنك تريد تسجيل الخروج؟';
  @override String get auth_welcome_back => 'مرحباً بعودتك';
  @override String get auth_welcome => 'مرحباً';
  @override String get auth_no_account => 'ليس لديك حساب بعد؟';
  @override String get auth_has_account => 'لديك حساب بالفعل؟';
  @override String get auth_invalid_email => 'بريد إلكتروني غير صالح';
  @override String get auth_invalid_phone => 'رقم هاتف غير صالح';
  @override String get auth_password_too_short => 'كلمة المرور قصيرة جداً (8 أحرف على الأقل)';
  @override String get auth_passwords_mismatch => 'كلمتا المرور غير متطابقتين';
  @override String get auth_login_success => 'تم تسجيل الدخول بنجاح';
  @override String get auth_signup_success => 'تم إنشاء الحساب بنجاح';
  @override String get auth_session_expired => 'انتهت الجلسة، يرجى تسجيل الدخول مرة أخرى';
  @override String get auth_2fa_title => 'التحقق بخطوتين';
  @override String get auth_2fa_code => 'رمز التحقق';
  @override String get auth_verify_email => 'تحقق من البريد الإلكتروني';
  @override String get auth_verify_phone => 'تحقق من الهاتف';
  @override String get auth_biometric => 'تسجيل الدخول البيومتري';
  @override String get auth_biometric_prompt => 'المصادقة للمتابعة';
  @override String get auth_full_name => 'الاسم الكامل';
  @override String get auth_first_name => 'الاسم الأول';
  @override String get auth_last_name => 'اسم العائلة';
  @override String get auth_birth_date => 'تاريخ الميلاد';
  @override String get auth_gender => 'الجنس';
  @override String get auth_gender_male => 'ذكر';
  @override String get auth_gender_female => 'أنثى';
  @override String get auth_gender_other => 'آخر';
  @override String get auth_accept_terms => 'أوافق على شروط الاستخدام';
  @override String get auth_terms_required => 'يجب عليك قبول الشروط';
  @override String get auth_email_already_used => 'هذا البريد الإلكتروني مستخدم بالفعل';
  @override String get auth_phone_already_used => 'رقم الهاتف هذا مستخدم بالفعل';
  @override String get auth_create_account => 'إنشاء حسابي';
  @override String get auth_already_have_account => 'لدي حساب بالفعل';

  @override String get onboarding_welcome => 'مرحباً بك في THIX';
  @override String get onboarding_step_1_title => 'اتصال';
  @override String get onboarding_step_1_desc => 'أنشئ هويتك الآمنة على THIX';
  @override String get onboarding_step_2_title => 'حماية';
  @override String get onboarding_step_2_desc => 'تفعيل الحماية على مدار الساعة';
  @override String get onboarding_step_3_title => 'إجراء';
  @override String get onboarding_step_3_desc => 'تنبيه فرق الإنقاذ في ثانيتين';
  @override String get onboarding_get_started => 'البدء';
  @override String get onboarding_skip => 'تخطي المقدمة';

  // ============================================================================
  // AUTHENTIFICATION & CONNEXION (ADVANCED / ERRORS)
  // ============================================================================
  @override String get login_title => 'تسجيل الدخول إلى THIX';
  @override String get login_subtitle => 'مرحباً بعودتك';
  @override String get login_identifier_label => 'المُعرّف';
  @override String get login_identifier_hint => 'البريد، الهاتف أو THIX ID';
  @override String get login_password_label => 'كلمة المرور';
  @override String get login_password_hint => 'كلمة المرور الآمنة الخاصة بك';
  @override String get login_remember_me => 'تذكرني';
  @override String get login_forgot_password => 'هل نسيت كلمة المرور؟';
  @override String get login_button => 'تسجيل الدخول';
  @override String get login_verifying => 'جاري التحقق…';
  @override String get login_retry_in => 'أعد المحاولة في';
  @override String get login_seconds_suffix => 'ث';
  @override String get login_biometric => 'أو المتابعة باستخدام';
  @override String get login_face_id => 'Face ID';
  @override String get login_touch_id => 'Touch ID';
  
  @override String get login_error_suspended => 'هذا الحساب موقوف. اتصل بالدعم.';
  @override String get login_error_not_active => 'هذا الحساب غير مفعل.';
  @override String get login_error_no_account => 'لم يتم العثور على حساب بهذه التفاصيل.';
  @override String get login_error_mfa_required => 'التحقق بخطوتين مطلوب.';

  @override String get auth_error_identifier_required => 'المُعرّف مطلوب';
  @override String get auth_error_password_required => 'كلمة المرور مطلوبة';
  @override String get auth_error_thix_id_login_not_available => 'تسجيل الدخول بواسطة THIX ID غير متاح حالياً';
  @override String get auth_error_sign_in_failed => 'فشل تسجيل الدخول. تحقق من بياناتك.';
  @override String get auth_error_email_not_verified => 'يرجى التحقق من بريدك الإلكتروني قبل تسجيل الدخول';
  @override String get auth_error_server_misconfiguration => 'خطأ في تكوين الخادم';
  @override String get auth_error_account_already_exists => 'يوجد حساب بالفعل بهذا المُعرّف';
  @override String get auth_error_account_exists_wrong_password => 'هذا الحساب موجود ولكن كلمة المرور غير صحيحة';
  @override String get auth_error_account_exists_new_otp_sent => 'تم إرسال رمز OTP جديد إلى عنوانك';
  @override String get auth_error_invalid_otp => 'رمز OTP غير صالح أو منتهي الصلاحية';
  @override String get auth_error_otp_expired => 'انتهت صلاحية رمز OTP';
  @override String get auth_error_network => 'خطأ في الاتصال بالشبكة. تحقق من الإنترنت الخاص بك.';
  @override String get auth_error_rate_limit => 'محاولات كثيرة جداً. يرجى الانتظار قليلاً.';
  @override String get auth_error_technical => 'حدث خطأ فني. يرجى المحاولة مرة أخرى.';
  @override String get auth_error_user_mismatch => 'تم اكتشاف عدم تطابق في المستخدم';
  @override String get auth_error_profile_update_failed => 'فشل تحديث الملف الشخصي';
  @override String get auth_error_mark_email_verified_failed => 'فشل التحقق من البريد الإلكتروني';
  @override String get auth_error_qr_token_generation_failed => 'فشل إنشاء رمز الاستجابة السريعة (QR Token)';
  @override String get auth_error_finalize_registration_failed => 'فشل إنهاء التسجيل';
  @override String get auth_error_consume_qr_token_failed => 'فشل استخدام رمز الاستجابة السريعة (QR Token)';
  @override String get auth_error_resend_otp_failed => 'فشل إعادة إرسال رمز OTP';
  @override String get auth_error_phone_auth_not_available => 'المصادقة عبر الهاتف غير متاحة';
  @override String get auth_error_delete_account_not_available => 'حذف الحساب غير متاح حالياً';
  @override String get auth_error_update_email_failed => 'فشل تحديث عنوان البريد الإلكتروني';
  @override String get auth_error_reset_password_failed => 'فشل إعادة تعيين كلمة المرور';
  @override String get auth_error_sign_up_failed => 'فشل إنشاء الحساب';
  @override String get auth_info_otp_sent => 'تم إرسال رمز التحقق';

  // ============================================================================
  // INSCRIPTION PERSONNELLE (PERSONAL REGISTRATION)
  // ============================================================================
  @override String get reg_step1_title => 'ملفك الشخصي';
  @override String get reg_step1_subtitle => 'لنبدأ بالمعلومات الأساسية';
  @override String get reg_full_name_label => 'الاسم الكامل';
  @override String get reg_full_name_hint => 'الاسم الأول واسم العائلة';
  @override String get reg_dob_label => 'تاريخ الميلاد';
  @override String get reg_country_label => 'بلد الإقامة';
  @override String get reg_occupation_label => 'المهنة / النشاط';
  @override String get reg_occupation_hint => 'مثال: مطور، طالب، رائد أعمال';
  @override String get reg_next => 'التالي';

  @override String get reg_step2_title => 'تأمين حسابك';
  @override String get reg_step2_subtitle => 'أنشئ بيانات تسجيل الدخول الخاصة بك';
  @override String get reg_email_label => 'البريد الإلكتروني';
  @override String get reg_email_hint => 'your.email@example.com';
  @override String get reg_phone_label => 'رقم الهاتف';
  @override String get reg_phone_hint => '+1 555 XXX XXXX';
  @override String get reg_password_label => 'كلمة المرور';
  @override String get reg_password_hint => '8 أحرف كحد أدنى';
  @override String get reg_confirm_password_label => 'تأكيد كلمة المرور';
  @override String get reg_confirm_password_hint => 'أعد كتابة كلمة المرور';
  @override String get reg_strength_label => 'قوة كلمة المرور';
  @override String get reg_strength_very_weak => 'ضعيفة جداً';
  @override String get reg_strength_weak => 'ضعيفة';
  @override String get reg_strength_medium => 'متوسطة';
  @override String get reg_strength_strong => 'قوية';
  @override String get reg_strength_excellent => 'ممتازة';

  @override String get reg_identity_title => 'هوية THIX';
  @override String get reg_thix_chat_label => 'اسم مستخدم THIX Chat';
  @override String get reg_thix_chat_hint => 'مثال: ahmed.ali (فريد)';
  
  @override String get reg_verification_title => 'التحقق';
  @override String get reg_get_otp => 'الحصول على رمز التحقق';
  @override String get reg_code_sent_resend => 'إعادة إرسال الرمز';
  @override String get reg_resend_in => 'إعادة الإرسال خلال';
  @override String get reg_seconds_short => 'ث';
  @override String get reg_otp_label => 'رمز التحقق (OTP)';
  @override String get reg_validate_activate => 'تحقق وتفعيل';
  @override String get reg_activating => 'جاري التفعيل…';

  @override String get reg_congrats => 'تهانينا!';
  @override String get reg_welcome_message => 'مرحباً بك في نظام THIX البيئي،';
  @override String get reg_id_card_title => 'بطاقة الهوية الرقمية THIX';
  @override String get reg_official_thix_id => 'المُعرّف الرسمي THIX ID';
  @override String get reg_generating => 'جاري الإنشاء…';
  @override String get reg_copy_thix_id => 'نسخ THIX ID';
  @override String get reg_thix_id_copied => 'تم نسخ THIX ID إلى الحافظة';
  @override String get reg_go_to_dashboard => 'الذهاب إلى لوحة القيادة';
  @override String get reg_summary => 'ملخص التسجيل';
  @override String get reg_mobile_label => 'الهاتف المحمول';
  @override String get reg_not_provided => 'غير متوفر';

  // ============================================================================
  // ACCUEIL & TABLEAU DE BORD (HOME & DASHBOARD)
  // ============================================================================
  @override String get home_search_hint => 'ابحث عن خدمة أو جهة اتصال...';
  @override String get home_greeting => 'مرحباً';
  @override String get home_greeting_time => 'مساء الخير';
  @override String get home_welcome_back => 'مرحباً بعودتك';
  @override String get home_language_kiswahili => 'السواحلية (Kiswahili)';
  @override String get home_banner_default_tag => 'برنامج الشباب';
  @override String get home_banner_default_title => 'اكتشف أحدث الفرص والفعاليات';
  
  @override String get cert_pending => 'شهادة قيد الانتظار';
  @override String get cert_tier_ladder => 'المستوى قيد المراجعة حالياً';
  @override String get cert_view => 'عرض';

  @override String get quick_sona => 'THIX Sona';
  @override String get quick_doc => 'مستنداتي';
  @override String get quick_chat => 'دردشة';
  @override String get quick_sos => 'طوارئ';
  @override String get service_sante => 'صحة THIX';
  @override String get service_market => 'سوق THIX';
  @override String get service_money => 'محفظة THIX';
  @override String get service_reservation => 'حجوزات';
  @override String get service_mon_pays => 'بلدي';
  @override String get service_emploi => 'وظائف';
  @override String get service_formations => 'تدريب';
  @override String get service_opportunites => 'فرص';
  @override String get service_infos => 'أخبار';
  @override String get service_events => 'فعاليات';
  @override String get service_media => 'إعلام THIX';
  @override String get service_vault => 'الخزنة';
  @override String get service_network => 'الشبكة';
  @override String get service_certification => 'الشهادات';

  // ============================================================================
  // CHAT & MESSAGERIE (CHAT & MESSAGING)
  // ============================================================================
  @override String get chatlist_network => 'الشبكة';
  @override String get chatlist_discussions => 'المحادثات';
  @override String get chatlist_create_new => 'إنشاء محادثة جديدة';
  @override String get chatlist_calls => 'المكالمات';
  @override String get chatlist_settings => 'الإعدادات';

  @override String get chat_unknown_user => 'مستخدم غير معروف';
  @override String chat_members(int count) => count == 1 ? 'عضو 1' : '$count أعضاء';
  @override String get chat_video_call => 'مكالمة فيديو';
  @override String get chat_audio_call => 'مكالمة صوتية';
  @override String get chat_escalate => 'تصعيد';
  @override String get chat_history => 'السجل';
  @override String get chat_group_info => 'معلومات المجموعة';
  @override String get chat_file => 'ملف';
  @override String get chat_sticker => 'ملصق';
  @override String get chat_ephemeral => 'رسالة سريعة الزوال';
  @override String get chat_protected => 'مَحمي';
  @override String get chat_internal_note => 'ملاحظة داخلية';
  @override String get chat_send => 'إرسال';
  @override String get chat_recording => 'تسجيل';
  @override String get chat_stop_recording => 'إيقاف';
  @override String get chat_write_message => 'اكتب رسالة...';
  @override String get chat_record_audio => 'تسجيل صوت';
  @override String get chat_emojis => 'رموز تعبيرية';
  @override String get chat_reactions => 'تفاعلات';
  @override String get chat_flags => 'إبلاغات';
  @override String get chat_callback => 'معاودة الاتصال';
  @override String get chat_typing => 'يكتب...';
  @override String get chat_pause => 'إيقاف مؤقت';
  @override String get chat_play => 'تشغيل';

  @override String get conv_status_connected => 'متصل';
  @override String get conv_status_pending => 'قيد الانتظار';
  @override String get conv_status_rejected => 'مرفوض';
  @override String get conv_cannot_self => 'لا يمكنك إضافة نفسك';
  @override String get conv_request_pending => 'طلب الاتصال قيد الانتظار';
  @override String get conv_request_rejected => 'تم رفض طلب الاتصال';
  @override String get conv_request_to => 'إرسال طلب إلى';
  @override String get conv_request_hint => 'أضف رسالة اختيارية لطلب الاتصال الخاص بك.';
  @override String get conv_message_optional => 'رسالة (اختياري)';
  @override String get conv_send_request => 'إرسال الطلب';
  @override String get conv_request_sent => 'تم إرسال الطلب بنجاح';
  @override String get conv_request_exists => 'يوجد طلب بالفعل لهذا المستخدم';
  @override String get conv_select_contact => 'يرجى تحديد جهة اتصال واحدة على الأقل';
  @override String get conv_waiting_connection => 'في انتظار الاتصال لـ';
  @override String get conv_group_rpc_required => 'إنشاء مجموعة يتطلب اتصالاً بالخادم';
  @override String get conv_page_title => 'محادثة جديدة';
  @override String conv_start(int count) => 'بدء ($count)';
  @override String get conv_search_label => 'البحث عن مستخدم';
  @override String get conv_search_hint => 'الاسم، THIX ID أو رقم الهاتف...';
  @override String get conv_group_name_label => 'اسم المجموعة';
  @override String get conv_group_name_hint => 'مثال: فريق مشروع ألفا';

  @override String get requests_page_title => 'طلبات الاتصال';
  @override String get requests_reject_title => 'رفض الطلب';
  @override String get requests_reject_message => 'هل أنت متأكد أنك تريد رفض طلب الاتصال هذا؟ لا يمكن التراجع عن هذا الإجراء.';
  @override String get requests_reject_confirm => 'رفض';
  @override String get requests_rejected => 'تم رفض الطلب';
  @override String get requests_reject_error => 'خطأ أثناء رفض الطلب';
  @override String get requests_accepted => 'تم قبول الطلب بنجاح';
  @override String get requests_accept_error => 'خطأ أثناء قبول الطلب';

  @override String get call_history_title => 'سجل المكالمات';
  @override String get call_missed => 'مكالمة فائتة';
  @override String get call_incoming => 'مكالمة واردة';
  @override String get call_outgoing => 'مكالمة صادرة';
  @override String get call_video => 'مكالمة فيديو';
  @override String get call_audio => 'مكالمة صوتية';

  // ============================================================================
  // RÉSEAU SOCIAL (NETWORK)
  // ============================================================================
  @override String get network_search_title => 'البحث';
  @override String get network_search_hint => 'ابحث عن أشخاص، منشورات، أو مجتمعات…';
  @override String get network_tab_people => 'الأشخاص';
  @override String get network_tab_posts => 'المنشورات';
  @override String get network_tab_communities => 'المجتمعات';
  @override String get network_explore_title => 'استكشف شبكة THIX';
  @override String get network_explore_subtitle => 'ابحث عن أشخاص، منشورات، أو مجتمعات';
  @override String get network_no_results_users => 'لم يتم العثور على مستخدمين';
  @override String get network_no_results_posts => 'لم يتم العثور على منشورات';
  @override String get network_no_results_communities => 'لم يتم العثور على مجتمعات';
  @override String get network_request_sent => 'تم إرسال الطلب إلى';
  @override String get network_request_error => 'خطأ أثناء إرسال الطلب';

  @override String get community_create_title => 'إنشاء مجتمع';
  @override String get community_name_label => 'اسم المجتمع';
  @override String get community_description_label => 'الوصف';
  @override String get community_visibility_label => 'الرؤية';
  @override String get community_public => 'عام';
  @override String get community_private => 'خاص';
  @override String get community_join => 'انضمام';
  @override String get community_leave => 'مغادرة';
  @override String get community_members => 'أعضاء';
  @override String get community_admin => 'مسؤول';

  // ============================================================================
  // PROFIL UTILISATEUR (PROFILE)
  // ============================================================================
  @override String get profile_settings => 'إعدادات الملف الشخصي';
  @override String get profile_edit_bio => 'تعديل السيرة الذاتية';
  @override String get profile_no_bio => 'لا توجد سيرة ذاتية متاحة حالياً.';
  @override String get profile_followers => 'المتابعون';
  @override String get profile_following => 'يتابع';
  @override String get profile_posts => 'المنشورات';
  @override String get profile_follow => 'متابعة';
  @override String get profile_unfollow => 'أتابعه';
  @override String get profile_following_loading => 'جاري التحميل…';
  @override String get profile_message => 'رسالة';
  @override String get profile_block_user => 'حظر هذا المستخدم؟';
  @override String get profile_block_message => 'لن ترى منشوراته بعد الآن ولن يتمكن من التفاعل معك.';
  @override String get profile_block_confirm => 'حظر';
  @override String get profile_blocked_success => 'تم حظر المستخدم';
  @override String get profile_block_error => 'خطأ أثناء الحظر';
  
  @override String get profile_report_user => 'إبلاغ';
  @override String get profile_report_reason => 'السبب';
  @override String get profile_report_details => 'التفاصيل (اختياري)';
  @override String get profile_report_spam => 'رسائل مزعجة (سبام)';
  @override String get profile_report_inappropriate => 'محتوى غير لائق';
  @override String get profile_report_harassment => 'مضايقة';
  @override String get profile_report_impersonation => 'انتحال شخصية';
  @override String get profile_report_other => 'آخر';
  @override String get profile_report_submit => 'إرسال البلاغ';
  @override String get profile_report_success => 'تم إرسال البلاغ';
  @override String get profile_report_duplicate => 'تم الإبلاغ عنه مسبقاً';
  
  @override String get profile_private_gallery => 'المعرض الخاص';
  @override String get profile_private_content_locked => 'هذا المحتوى خاص';
  @override String get profile_add_private_media => 'إضافة إلى المعرض الخاص بي';
  @override String get profile_no_private_media => 'لا توجد وسائط خاصة بعد';
  @override String get profile_upload_processing => 'جاري المعالجة…';
  
  @override String get profile_tab_bio => 'السيرة الذاتية';
  @override String get profile_tab_private_gallery => 'المعرض الخاص';
  @override String get profile_tab_photos => 'صور عامة';
  @override String get profile_tab_videos => 'فيديو';
  @override String get profile_tab_audios => 'صوتيات';
  @override String get profile_no_content => 'لا يوجد محتوى';
  @override String get profile_pinned_post => 'منشور مثبت';
  @override String get profile_view_post => 'عرض المنشور';

  // ============================================================================
  // PARAMÈTRES GÉNÉRAUX & CHAT (SETTINGS)
  // ============================================================================
  @override String get settings_title => 'إعدادات الدردشة';
  @override String get settings_section_appearance => 'المظهر';
  @override String get settings_theme => 'السمة';
  @override String get settings_theme_light => 'فاتح';
  @override String get settings_theme_dark => 'داكن';
  @override String get settings_theme_system => 'الافتراضي للنظام';
  @override String get settings_wallpaper => 'خلفية الشاشة';
  @override String get settings_wallpaper_default => 'الافتراضية';
  @override String get settings_wallpaper_custom => 'مخصصة';
  
  @override String get settings_section_privacy => 'الخصوصية';
  @override String get settings_last_seen => 'آخر ظهور';
  @override String get settings_visibility_everyone => 'الجميع';
  @override String get settings_visibility_contacts => 'جهات اتصالي';
  @override String get settings_visibility_nobody => 'لا أحد';
  @override String get settings_profile_photo => 'صورة الملف الشخصي';
  
  @override String get settings_section_notifications => 'الإشعارات';
  @override String get settings_messages => 'الرسائل';
  @override String get settings_calls => 'المكالمات';
  
  @override String get settings_section_messages => 'البيانات والتخزين';
  @override String get settings_ephemeral => 'الرسائل ذاتية الاختفاء';
  @override String get settings_auto_download => 'التنزيل التلقائي للوسائط';
  @override String get settings_download_wifi => 'شبكة Wi-Fi فقط';
  @override String get settings_download_mobile => 'Wi-Fi والبيانات الخلوية';
  @override String get settings_download_never => 'أبداً';
  
  @override String get settings_section_account => 'الحساب';
  @override String get settings_view_profile => 'عرض ملفي الشخصي';
  @override String get settings_logout => 'تسجيل الخروج';

  @override String get settings_profile_edit => 'تعديل الملف الشخصي';
  @override String get settings_notifications => 'الإشعارات';
  @override String get settings_privacy => 'الخصوصية';
  @override String get settings_security => 'الأمان';
  @override String get settings_language => 'اللغة';
  @override String get settings_help_center => 'مركز المساعدة';
  @override String get settings_about => 'حول THIX';
  @override String get settings_version => 'الإصدار';

  // ============================================================================
  // TRADUCTIONS DE LANGUAGE SHEET
  // ============================================================================
  @override String get settings_choose_language => 'اختر اللغة';
  @override String get settings_system_default => 'لغة النظام';
  @override String get settings_language_change_failed => 'فشل تغيير اللغة';

  // ============================================================================
  // SOS & URGENCE (EMERGENCY)
  // ============================================================================
  @override String get sos_button => 'طوارئ';
  @override String get sos_button_label => 'زر طوارئ SOS';
  @override String get sos_button_hint => 'اضغط مع الاستمرار لمدة ثانيتين للتفعيل';
  @override String get sos_button_tooltip => 'اضغط مع الاستمرار لمدة ثانيتين';
  @override String get sos_trigger_button => 'تفعيل SOS';
  @override String get sos_trigger_timeout => 'انتهت مهلة الطلب. يرجى المحاولة مرة أخرى.';
  @override String get sos_trigger_error => 'فشل في تفعيل SOS';
  @override String get sos_active => 'SOS نَشِط';
  @override String get sos_crisis_room => 'غرفة الأزمات';
  @override String get sos_command_center => 'مركز القيادة';
  @override String get sos_incident => 'حادث';
  @override String get sos_incident_unknown => 'حادث غير معروف';
  @override String get sos_incident_not_found => 'لم يتم العثور على الحادث';
  @override String get sos_circle => 'الدائرة';
  @override String get sos_rescuers => 'المنقذون';
  @override String get sos_rescuer => 'المنقذ';
  @override String get sos_my_rescuers => 'منقذيني';
  @override String get sos_duration => 'المدة';
  @override String get sos_identifier => 'المُعرّف';
  @override String get sos_calling => 'جاري الاتصال…';
  @override String get sos_call => 'اتصال';
  @override String get sos_available => 'متاح';
  @override String get sos_unavailable => 'غير متاح';
  @override String get sos_verified => 'تم التحقق';
  @override String get sos_end => 'إنهاء';
  @override String get sos_end_sos => 'إنهاء SOS';
  @override String get sos_cancel_sos => 'إلغاء SOS';
  @override String get sos_pin_required => 'الرمز السري للأمان مطلوب';
  @override String get sos_cancelled => 'تم إلغاء SOS';
  @override String get sos_resolved => 'تم حل SOS';
  @override String get sos_cancel_failed => 'فشل في الإلغاء';
  @override String get sos_in_progress => 'قيد التقدم';
  @override String get sos_history => 'السجل';
  @override String get sos_my_incidents => 'حوادثي';
  @override String get sos_no_incidents => 'لا توجد حوادث بعد';
  @override String get sos_incidents_appear_here => 'ستظهر طلبات SOS الخاصة بك هنا';
  @override String get sos_history_error => 'فشل تحميل السجل';
  @override String get sos_circle_1 => 'الدائرة 1 – الأولوية';
  @override String get sos_circle_2 => 'الدائرة 2 – ثانوية';
  @override String get sos_circle_3 => 'الدائرة 3 – طوارئ';
  @override String get sos_no_rescuers => 'لا يوجد منقذون';
  @override String get sos_add_first_rescuer => 'أضف جهة اتصال الطوارئ الأولى';
  @override String get sos_add_rescuer => 'إضافة منقذ';
  @override String get sos_add_rescuer_info => 'أدخل معرّف THIX الخاص بالمنقذ. سيتم جلب الاسم والصورة تلقائياً.';
  @override String get sos_thix_id_label => 'مُعرّف THIX';
  @override String get sos_thix_id_hint => 'THIX-XXXX';

  // ============================================================================
  // CERTIFICATION
  // ============================================================================
  @override String get certification_title => 'شهادة THIX';
  @override String get certification_apply => 'طلب شهادة';
  @override String get certification_status => 'الحالة';
  @override String get certification_pending => 'قيد الانتظار';
  @override String get certification_approved => 'تمت الموافقة';
  @override String get certification_rejected => 'مرفوض';
  @override String get certification_tier_bronze => 'برونزي';
  @override String get certification_tier_silver => 'فضي';
  @override String get certification_tier_gold => 'ذهبي';
  @override String get certification_tier_platinum => 'بلاتيني';
  @override String get certification_benefits => 'المزايا';
  @override String get certification_documents => 'المستندات المطلوبة';
  @override String get certification_upload_doc => 'رفع مستند';
  @override String get certification_review_progress => 'قيد المراجعة';
  @override String get certification_verified_account => 'حساب موثق';

  // ============================================================================
  // ÉDUCATION & FORMATION (EDUCATION & TRAINING)
  // ============================================================================
  @override String get edu_nav_home => 'الرئيسية';
  @override String get edu_nav_learning => 'تعليمي';
  @override String get edu_nav_library => 'المكتبة';
  @override String get edu_nav_certs => 'الشهادات';
  @override String get edu_nav_profile => 'الملف الشخصي';
  
  @override String get edu_auth_required => 'سجل الدخول لرؤية دوراتك';
  @override String get edu_login_required => 'سجل الدخول لرؤية دوراتك';
  
  @override String get edu_learning_empty_title => 'لا توجد دورات قيد التقدم';
  @override String get edu_learning_empty_desc => 'سجل في دورة للبدء.';
  @override String get edu_no_courses => 'لا توجد دورات قيد التقدم';
  @override String get edu_enroll_hint => 'سجل في دورة للبدء.';
  @override String get edu_explore_btn => 'استكشف الدورات';
  @override String get edu_completed => 'مكتمل';
  
  @override String get edu_user_avatar => 'الصورة الرمزية للمستخدم';
  @override String get edu_greeting => 'مرحباً،';
  @override String get edu_greeting_subtitle => 'هل أنت مستعد لتطوير مهاراتك؟';
  @override String get edu_ready_to_learn => 'هل أنت مستعد لتطوير مهاراتك؟';
  @override String get edu_learner => 'المتعلم';
  @override String get edu_notifications => 'الإشعارات';
  @override String get edu_search_hint => 'ابحث عن الدورات، الشهادات…';
  @override String get edu_browse => 'تصفح';
  @override String get edu_library => 'المكتبة';
  @override String get edu_certs => 'الشهادات';
  @override String get edu_qa_browse => 'تصفح';
  @override String get edu_instructor => 'المدرب';
  
  @override String get edu_top_formations => 'أفضل الدورات';
  @override String get edu_awaited_formations => 'الأكثر انتظاراً';
  @override String get edu_awaited => 'الأكثر انتظاراً';
  @override String get edu_see_all => 'عرض الكتالوج';
  
  @override String edu_coming_soon(String category) => 'دورات $category جديدة قريباً';
  @override String get edu_coming_soon_cat => 'دورات جديدة قادمة هنا قريباً';
  @override String get edu_locked_course => 'قريباً! (من المتوقع الافتتاح قريباً)';
  @override String get edu_coming_soon_badge => 'الافتتاح قريباً';
  @override String get edu_awaited_badge => 'قريباً';
  @override String get edu_awaited_locked => 'مغلق';
  @override String get edu_awaited_locked_msg => 'قريباً! (من المتوقع الافتتاح قريباً)';
  
  @override String get edu_thix_academy => 'أكاديمية THIX';
  @override String get edu_scheduled_soon => 'مُقرر: قريباً';
  @override String get edu_new_program => 'برنامج جديد';
  @override String get edu_resume_learning => 'استئناف التعلم';
  @override String get edu_resume => 'استئناف التعلم';
  
  @override String get edu_catalog => 'الكتالوج';
  @override String get edu_no_formations_cat => 'لا توجد دورات في هذه الفئة';
  
  @override String get edu_my_library => 'مكتبتي';
  @override String get edu_search_book_hint => 'ابحث بالعنوان أو المؤلف...';
  @override String get edu_library_title => 'مكتبتي';
  @override String get edu_search_library => 'ابحث بالعنوان أو المؤلف…';
  @override String get edu_shelves_empty => 'الرفوف فارغة.';
  @override String get edu_library_empty => 'الرفوف فارغة.';
  @override String get edu_no_result => 'لا توجد نتائج';
  @override String edu_search_no_results(String query) => 'لا توجد نتائج لـ "$query"';
  
  @override String get edu_shelf => 'الرف';
  @override String get edu_books => 'كتب';
  @override String get edu_all => 'الكل';
  @override String edu_shelf_info(String code, int count) => 'الرف $code · $count كتب';
  @override String get edu_free => 'مجاني';
  @override String get edu_deleted_in => 'لن يكون متاحاً بعد';
  @override String edu_expires_in(String countdown) => 'ينتهي في $countdown';
  
  @override String get edu_certifications => 'الشهادات';
  @override String get edu_certs_title => 'الشهادات';
  @override String get edu_no_certs => 'لا توجد شهادات بعد';
  @override String get edu_cert_expert => 'شهادة خبرة';
  @override String get edu_cert_expertise => 'شهادة خبرة';
  @override String edu_cert_issued(String date) => 'صدرت في $date';
  
  @override String get edu_pro_account => 'حساب مهني';
  @override String get edu_profile_title => 'حساب مهني';
  @override String get edu_instructor_space => 'لوحة المدرب';
  @override String get edu_tools => 'الأدوات المؤسسية';
  @override String get edu_institutional_tools => 'الأدوات المؤسسية';
  @override String get edu_free_resources => 'موارد مفتوحة';
  @override String get edu_masterclass => 'دروس متقدمة (Masterclasses)';
  @override String get edu_masterclasses => 'دروس متقدمة (Masterclasses)';
  @override String get edu_network => 'الشبكة والتوجيه';
  @override String get edu_mentorship => 'التواصل والتوجيه';
  @override String get edu_events_agenda => 'أجندة الفعاليات';
  @override String get edu_support => 'الدعم الفني';
  @override String get edu_not_connected => 'غير متصل';

  @override String get training_title => 'التدريب';
  @override String get training_enroll => 'التسجيل';
  @override String get training_my_courses => 'دوراتي';
  @override String get training_certificates => 'شهاداتي';
  @override String get training_progress => 'التقدم';
  @override String get training_lessons => 'الدروس';
  @override String get training_duration => 'المدة';
  @override String get training_level => 'المستوى';
  @override String get training_beginner => 'مبتدئ';
  @override String get training_intermediate => 'متوسط';
  @override String get training_advanced => 'متقدم';
  @override String get training_start_course => 'بدء الدورة';
  @override String get training_continue_course => 'متابعة الدورة';

  // ============================================================================
  // EMPLOIS & RECRUTEMENT (JOBS & RECRUITING)
  // ============================================================================
  @override String get jobs_title => 'الوظائف';
  @override String get jobs_search => 'البحث عن وظائف';
  @override String get jobs_apply => 'تقديم';
  @override String get jobs_saved => 'المحفوظة';
  @override String get jobs_applied => 'الطلبات المُرسلة';
  @override String get jobs_company => 'الشركة';
  @override String get jobs_location => 'الموقع';
  @override String get jobs_salary => 'الراتب';
  @override String get jobs_type => 'النوع';
  @override String get jobs_full_time => 'دوام كامل';
  @override String get jobs_part_time => 'دوام جزئي';
  @override String get jobs_contract => 'عقد';
  @override String get jobs_internship => 'تدريب داخلي';
  @override String get jobs_freelance => 'عمل حر';
  @override String get jobs_remote => 'عن بُعد';
  @override String get jobs_onsite => 'في الموقع';
  @override String get jobs_hybrid => 'هجين';
  @override String get jobs_experience => 'الخبرة';
  @override String get jobs_no_experience => 'للمبتدئين';
  @override String get jobs_junior => 'مبتدئ';
  @override String get jobs_mid => 'متوسط';
  @override String get jobs_senior => 'خبير';
  @override String get jobs_requirements => 'المتطلبات';
  @override String get jobs_responsibilities => 'المسؤوليات';
  @override String get jobs_benefits => 'المزايا';
  @override String get jobs_apply_now => 'قدم الآن';
  @override String get jobs_application_sent => 'تم إرسال الطلب';
  @override String get jobs_no_results => 'لم يتم العثور على وظائف';
  @override String get recruiter_title => 'مسؤول التوظيف';
  @override String get recruiter_post_job => 'نشر وظيفة';
  @override String get recruiter_candidates => 'المرشحون';
  @override String get recruiter_applications => 'الطلبات';
  @override String get recruiter_interviews => 'المقابلات';

  // ============================================================================
  // OPPORTUNITÉS (OPPORTUNITIES)
  // ============================================================================
  @override String get opportunities_title => 'الفرص';
  @override String get opportunities_business => 'أعمال';
  @override String get opportunities_investment => 'استثمار';
  @override String get opportunities_partnership => 'شراكة';
  @override String get opportunities_grant => 'منحة';
  @override String get opportunities_coming_soon => 'قريباً';

  // ============================================================================
  // MARCHÉ & E-COMMERCE (MARKET)
  // ============================================================================
  @override String get market_title => 'سوق THIX';
  @override String get market_categories => 'الفئات';
  @override String get market_products => 'المنتجات';
  @override String get market_services => 'الخدمات';
  @override String get market_add_to_cart => 'إضافة إلى العربة';
  @override String get market_buy_now => 'اشترِ الآن';
  @override String get market_cart => 'العربة';
  @override String get market_checkout => 'الدفع';
  @override String get market_total => 'المجموع';
  @override String get market_delivery => 'التوصيل';
  @override String get market_seller => 'البائع';
  @override String get market_rating => 'التقييم';
  @override String get market_reviews => 'المراجعات';
  @override String get market_in_stock => 'متوفر';
  @override String get market_out_of_stock => 'نفدت الكمية';
  @override String get market_add_to_favorites => 'إضافة إلى المفضلة';
  @override String get market_remove_from_cart => 'إزالة من العربة';

  // ============================================================================
  // PORTEFEUILLE & ARGENT (WALLET & MONEY)
  // ============================================================================
  @override String get money_title => 'محفظة THIX';
  @override String get money_balance => 'الرصيد';
  @override String get money_send => 'إرسال';
  @override String get money_receive => 'استلام';
  @override String get money_history => 'السجل';
  @override String get money_transactions => 'المعاملات';
  @override String get money_top_up => 'شحن الرصيد';
  @override String get money_withdraw => 'سحب';
  @override String get money_transfer => 'تحويل';
  @override String get money_bills => 'الفواتير';
  @override String get money_recipients => 'المستفيدون';
  @override String get money_add_recipient => 'إضافة مستفيد';
  @override String get money_amount => 'المبلغ';
  @override String get money_fee => 'الرسوم';
  @override String get money_reference => 'المرجع';
  @override String get money_confirm_transfer => 'تأكيد التحويل';
  @override String get money_transfer_success => 'تم التحويل بنجاح';
  @override String get money_transfer_failed => 'فشل التحويل';
  @override String get money_insufficient_funds => 'رصيد غير كافٍ';

  // ============================================================================
  // ÉVÉNEMENTS & BILLETS (EVENTS & TICKETS)
  // ============================================================================
  @override String get events_title => 'الفعاليات';
  @override String get events_upcoming => 'القادمة';
  @override String get events_past => 'السابقة';
  
  @override String get event_share_cta => 'احجز مكانك على THIX!';
  @override String get event_sold_out_title => 'بيعت التذاكر';
  @override String get event_sold_out_msg => 'جميع الأماكن محجوزة حالياً. انضم إلى قائمة الانتظار لتلقي إشعار في حال توفر أماكن.';
  @override String get event_join_queue_confirm => 'هل ترغب في الانضمام إلى قائمة الانتظار؟';
  @override String get event_join_queue_btn => 'الانضمام للقائمة';
  
  @override String get event_unfavorite => 'إزالة من المفضلة';
  @override String get event_favorite => 'إضافة إلى المفضلة';
  @override String get event_free => 'مجاني';
  @override String get event_paid => 'مدفوع';
  
  @override String get event_time_label => 'الوقت';
  @override String get event_location_label => 'الموقع';
  @override String get event_address_label => 'العنوان الدقيق';
  @override String get event_organized_by => 'تنظيم';
  
  @override String get event_about_title => 'حول';
  @override String get event_no_description => 'لا يتوفر وصف لهذه الفعالية.';
  @override String get event_tickets_title => 'التذاكر والحجز';
  
  @override String get event_sold_out_short => 'مُباع بالكامل';
  @override String event_remaining_seats(String count) => 'تبقى $count أماكن';
  @override String get event_queue_btn => 'قائمة الانتظار';
  @override String get event_book_btn => 'احجز';
  
  @override String get event_standard_entry => 'دخول عادي';
  @override String get event_all_sold => 'بيعت جميع الأماكن';
  @override String get event_limited_seats => 'أماكن محدودة';
  @override String get event_book_now_btn => 'احجز الآن';
  
  @override String event_numbered_seats(String count) => '$count أماكن مرقمة';
  @override String get event_choose_seats_btn => 'اختر أماكني';
  @override String get event_from_price => 'ابتداءً من';

  @override String get events_my_tickets => 'تذاكري';
  @override String get events_buy_ticket => 'شراء تذكرة';
  @override String get events_ticket_price => 'سعر التذكرة';
  @override String get events_date => 'التاريخ';
  @override String get events_time => 'الوقت';
  @override String get events_venue => 'المكان';
  @override String get events_organizer => 'المنظم';
  @override String get events_attendees => 'الحضور';
  @override String get events_seats_available => 'الأماكن المتاحة';
  @override String get events_sold_out => 'نفدت التذاكر';
  @override String get events_book_now => 'احجز الآن';
  @override String get events_ticket_type => 'نوع التذكرة';
  @override String get ticket_standard => 'عادي';
  @override String get ticket_vip => 'VIP';
  @override String get ticket_gold => 'ذهبي';
  @override String get ticket_family => 'عائلة';
  @override String get ticket_secure_ticket => 'تذكرة آمنة';
  @override String get ticket_not_found => 'التذكرة غير موجودة';
  @override String get ticket_location => 'الموقع';
  @override String get ticket_pin_label => 'رمز PIN';
  @override String get ticket_show_qr => 'عرض QR';
  @override String get ticket_booking_id => 'رقم الحجز';
  @override String get ticket_add_wallet => 'المحفظة';
  @override String get ticket_wallet_coming_soon => 'إضافة المحفظة قريباً';
  @override String get ticket_share => 'مشاركة';
  @override String get ticket_share_text => 'تذكرتي من THIX';
  @override String get ticket_scan_info => 'قدم هذا الرمز (QR) عند المدخل';
  @override String get ticket_security_title => 'الأمان';
  @override String get ticket_enter_pin => 'أدخل رمز PIN الخاص بك';
  @override String get ticket_pin_hint => 'رمز من 4 أرقام';
  @override String get ticket_pin_incorrect => 'رمز PIN غير صحيح';
  @override String get ticket_pin_too_many_attempts => 'محاولات كثيرة جداً';
  @override String get ticket_attempts_remaining => 'المحاولات المتبقية';
  @override String get tickets_ticket => 'التذكرة';
  @override String get tickets_completed => 'المكتملة';
  @override String get tickets_no_tickets => 'لا توجد تذاكر';
  @override String get tickets_no_tickets_desc => 'ستظهر حجوزاتك هنا';
  @override String get tickets_discover => 'اكتشف';
  @override String get tickets_load_error => 'فشل تحميل تذاكرك';
  @override String tickets_quantity(int count) => count == 0 ? 'لا توجد تذاكر' : (count == 1 ? 'تذكرة 1' : '$count تذاكر');

  // ============================================================================
  // RÉSERVATIONS (RESERVATIONS)
  // ============================================================================
  @override String get reservation_title => 'حجوزات';
  @override String get reservation_hotel => 'فندق';
  @override String get reservation_restaurant => 'مطعم';
  @override String get reservation_transport => 'نقل';
  @override String get reservation_check_in => 'تسجيل الدخول';
  @override String get reservation_check_out => 'تسجيل الخروج';
  @override String get reservation_guests => 'الضيوف';
  @override String get reservation_rooms => 'الغرف';
  @override String get reservation_book => 'احجز';
  @override String get reservation_cancel => 'إلغاء';
  @override String get reservation_modify => 'تعديل';
  @override String get reservation_confirm => 'تأكيد الحجز';
  @override String get reservation_my_bookings => 'حجوزاتي';

  // ============================================================================
  // SANTÉ (HEALTH)
  // ============================================================================
  @override String get health_title => 'صحة THIX';
  @override String get health_appointments => 'المواعيد';
  @override String get health_doctors => 'الأطباء';
  @override String get health_hospitals => 'المستشفيات';
  @override String get health_pharmacies => 'الصيدليات';
  @override String get health_emergency => 'طوارئ';
  @override String get health_medical_records => 'السجلات الطبية';
  @override String get health_prescriptions => 'الوصفات الطبية';
  @override String get health_book_appointment => 'حجز موعد';
  @override String get health_appointment_date => 'تاريخ الموعد';
  @override String get health_specialty => 'التخصص';
  @override String get health_consultation => 'استشارة';
  @override String get health_telemedicine => 'تطبيب عن بُعد';
  @override String get health_insurance => 'التأمين';
  @override String get health_symptoms => 'الأعراض';
  @override String get health_find_doctor => 'ابحث عن طبيب';

  // ============================================================================
  // MÉDIA & INFOS (MEDIA & INFO)
  // ============================================================================
  @override String get media_title => 'إعلام THIX';
  @override String get media_news => 'أخبار';
  @override String get media_videos => 'مقاطع فيديو';
  @override String get media_podcasts => 'بودكاست';
  @override String get media_articles => 'مقالات';
  @override String get media_live => 'مباشر';
  @override String get media_categories => 'الفئات';
  @override String get media_bookmarks => 'الإشارات المرجعية';
  @override String get media_share_article => 'مشاركة المقال';
  @override String get media_read_more => 'اقرأ المزيد';
  @override String get media_published_on => 'نُشر في';
  @override String get media_author => 'المؤلف';
  @override String get info_title => 'أخبار';
  @override String get info_local => 'محلي';
  @override String get info_national => 'وطني';
  @override String get info_international => 'دولي';
  @override String get info_sports => 'رياضة';
  @override String get info_culture => 'ثقافة';
  @override String get info_economy => 'اقتصاد';
  @override String get info_politics => 'سياسة';
  @override String get info_technology => 'تكنولوجيا';
  @override String get info_read_full => 'قراءة المقال كاملاً';

  // ============================================================================
  // MON PAYS (MY COUNTRY)
  // ============================================================================
  @override String get mon_pays_title => 'بلدي';
  @override String get mon_pays_regions => 'المناطق';
  @override String get mon_pays_cities => 'المدن';
  @override String get mon_pays_culture => 'ثقافة';
  @override String get mon_pays_history => 'تاريخ';
  @override String get mon_pays_tourism => 'سياحة';
  @override String get mon_pays_discover => 'استكشف';
  @override String get mon_pays_landmarks => 'المعالم';
  @override String get mon_pays_traditions => 'التقاليد';

  // ============================================================================
  // COFFRE-FORT (VAULT)
  // ============================================================================
  @override String get vault_title => 'الخزنة';
  @override String get vault_documents => 'المستندات';
  @override String get vault_photos => 'الصور';
  @override String get vault_videos => 'الفيديو';
  @override String get vault_notes => 'الملاحظات';
  @override String get vault_passwords => 'كلمات المرور';
  @override String get vault_add_document => 'إضافة مستند';
  @override String get vault_upload => 'رفع';
  @override String get vault_encrypted => 'مُشفّر';
  @override String get vault_backup => 'نسخ احتياطي';
  @override String get vault_restore => 'استعادة';
  @override String get vault_share_secure => 'مشاركة آمنة';
  @override String get vault_unlock => 'إلغاء القفل';
  @override String get vault_lock => 'قفل';

  // ============================================================================
  // PAIEMENT (PAYMENT)
  // ============================================================================
  @override String get payment_title => 'الدفع';
  @override String get payment_method => 'طريقة الدفع';
  @override String get payment_card => 'بطاقة ائتمان';
  @override String get payment_mobile_money => 'أموال الجوال (Mobile Money)';
  @override String get payment_bank_transfer => 'تحويل بنكي';
  @override String get payment_cash => 'نقد';
  @override String get payment_confirm => 'تأكيد الدفع';
  @override String get payment_success => 'تم الدفع بنجاح';
  @override String get payment_failed => 'فشل الدفع';
  @override String get payment_processing => 'جاري المعالجة…';
  @override String get payment_receipt => 'إيصال';
  @override String get payment_invoice => 'فاتورة';

  // ============================================================================
  // RECHERCHE (MISSING PERSONS / SEARCH)
  // ============================================================================
  @override String get search_title => 'بحث THIX';
  @override String get search_subtitle => 'أشخاص مفقودون وإشعارات رسمية';
  @override String get search_person_missing => 'شخص مفقود';
  @override String get search_person_wanted => 'إشعار بحث رسمي';
  @override String get search_report_missing => 'الإبلاغ عن مفقود';
  @override String get search_report_found => 'الإبلاغ عن العثور';
  @override String get search_details => 'التفاصيل';
  @override String get search_contact_authorities => 'الاتصال بالسلطات';
  @override String get search_share_alert => 'مشاركة التنبيه';
  @override String get search_last_seen => 'آخر مشاهدة';
  @override String get search_description => 'الوصف';
  @override String get search_age => 'العمر';
  @override String get search_height => 'الطول';
  @override String get search_weight => 'الوزن';
  @override String get search_hair_color => 'لون الشعر';
  @override String get search_eye_color => 'لون العينين';
  @override String get search_distinguishing_marks => 'علامات مميزة';
  @override String get search_clothing => 'الملابس';
  @override String get search_circumstances => 'الظروف';
  @override String get search_case_number => 'رقم القضية';
  @override String get search_reported_by => 'تم الإبلاغ بواسطة';
  @override String get search_official_notice => 'إشعار رسمي';
  @override String get search_community_alert => 'تنبيه مجتمعي';

  // ============================================================================
  // À PROXIMITÉ & ALERTES (NEARBY ALERTS)
  // ============================================================================
  @override String get nearby_alerts_title => 'التنبيهات القريبة';
  @override String get nearby_view_on_map => 'عرض على الخريطة';
  @override String get nearby_map_coming_soon => 'خريطة ملء الشاشة قريباً';
  @override String get nearby_map_disabled => 'الخريطة معطلة (في انتظار مفتاح API)';
  @override String get nearby_active_alerts => 'التنبيهات النشطة';
  @override String get nearby_missing => 'مفقود';
  @override String get nearby_official => 'رسمي';
  @override String get nearby_legend_missing => 'شخص مفقود';
  @override String get nearby_legend_official => 'إشعار رسمي';
  @override String get nearby_legend_report => 'إبلاغ';
  @override String get nearby_location_required => 'تفعيل خدمات الموقع';
  @override String get nearby_location_subtitle => 'شاهد التنبيهات من حولك';

  // ============================================================================
  // ADMINISTRATION
  // ============================================================================
  @override String get admin_title => 'إدارة THIX';
  @override String get admin_dev_open => 'تطوير مفتوح';
  @override String get admin_actions_section => 'الإجراءات';
  
  @override String get admin_events_title => 'الفعاليات';
  @override String get admin_events_create => 'إنشاء';
  @override String get admin_events_search_hint => 'البحث بالعنوان...';
  @override String get admin_events_filter => 'تصفية الفئات';
  @override String get admin_events_empty => 'لم يتم العثور على فعاليات';
  @override String get admin_events_no_permission => 'ليس لديك صلاحية لتنفيذ هذا الإجراء';
  @override String get admin_events_delete_title => 'حذف؟';
  @override String admin_events_delete_desc(String title) => 'هل تريد حذف $title؟ هذا الإجراء لا يمكن التراجع عنه.';

  @override String get admin_limits_purchase_rules => 'قواعد الشراء';
  @override String get admin_limits_max_person => 'الحد الأقصى / شخص (عالمياً)';
  @override String get admin_limits_max_transaction => 'الحد الأقصى / معاملة (للعربة)';
  @override String get admin_limits_require_thix_id => 'التحقق من THIX ID مطلوب';
  @override String get admin_limits_require_thix_id_desc => 'موصى به للفعاليات ذات الطلب المرتفع.';
  @override String get admin_limits_info_title => 'بنية آمنة';
  @override String get admin_limits_info_desc => 'يتم فرض هذه الحدود والتحقق منها مباشرة بواسطة وظائف SQL Edge في الوقت الفعلي لمنع حالات التنافس والاحتيال.';

  @override String get admin_stat_events => 'الفعاليات';
  @override String get admin_stat_bookings => 'الحجوزات';
  @override String get admin_stat_revenue => 'الإيرادات';
  @override String get admin_stat_queue => 'قائمة الانتظار';
  @override String get admin_action_events => 'الفعاليات';
  @override String get admin_action_events_sub => '20 / صفحة';
  @override String get admin_action_create => 'إنشاء';
  @override String get admin_action_create_sub => 'رفع + تحقق';
  @override String get admin_action_seats => 'المقاعد';
  @override String get admin_action_seats_sub => 'دفعة من 200';
  @override String get admin_action_reservations => 'الحجوزات';
  @override String get admin_action_reservations_sub => '50 / صفحة + فلاتر';
  @override String get admin_action_limits => 'مكافحة الاحتيال';
  @override String get admin_action_limits_sub => 'الحدود';
  @override String get admin_action_analytics => 'التحليلات';
  @override String get admin_action_analytics_sub => 'RPC';
  @override String get admin_read_only => 'قراءة فقط';
  @override String get admin_bookings_title => 'الحجوزات • 50/صفحة';
  @override String get admin_bookings_export => 'تصدير الخادم قيد التقدم (مهمة)';
  @override String get admin_bookings_details => 'تفاصيل التذكرة';
  @override String get admin_bookings_event => 'الفعالية';
  @override String get admin_bookings_unknown_event => 'فعالية غير معروفة';
  @override String get admin_bookings_id => 'رقم الحجز';
  @override String get admin_bookings_quantity => 'الكمية';
  @override String get admin_bookings_category => 'الفئة';
  @override String get admin_bookings_amount => 'المبلغ';
  @override String get admin_bookings_pin => 'PIN';
  @override String get admin_bookings_purchase_date => 'تاريخ الشراء';
  @override String get admin_bookings_close => 'إغلاق';
  @override String get admin_bookings_empty => 'لم يتم العثور على حجوزات';
  @override String get admin_bookings_unknown_date => 'تاريخ غير معروف';
  @override String admin_bookings_places(int count) => '$count أماكن';
  @override String get admin_bookings_status_valid => 'صالح';
  @override String get admin_bookings_status_used => 'مستخدم';
  @override String get admin_bookings_status_cancelled => 'ملغى';
  @override String get admin_bookings_status_postponed => 'مؤجل';
  @override String get admin_bookings_status_pending => 'قيد الانتظار';
  @override String admin_queue_title(int count) => 'قائمة الانتظار • وقت فعلي ($count)';
  @override String get admin_queue_realtime_desc => 'التحديث الفعلي نشط • يتحدث تلقائياً عند انضمام المستخدمين';
  @override String get admin_queue_empty => 'القائمة فارغة';
  @override String get admin_queue_event_fallback => 'الفعالية';
  @override String admin_queue_item_meta(String userId, int qty, String status) => 'المستخدم: $userId • $qty أماكن • $status';
  @override String get admin_queue_notify => 'إشعار';
  @override String get admin_queue_notified => 'تم إشعار المستخدم (ينتهي في 10 دقائق)';
  @override String get admin_queue_position => 'المركز';
  @override String get admin_queue_places => 'الأماكن';
  @override String get admin_analytics_title => 'التحليلات • الأداء';
  @override String get admin_analytics_fill_rate => 'نسبة الامتلاء';
  @override String get admin_analytics_avg_cart => 'متوسط السلة';
  @override String get admin_analytics_no_show => 'الغياب';
  @override String get admin_analytics_rev_per_event => 'الإيرادات / الفعالية';
  @override String get admin_analytics_revenue_7d => 'إيرادات 7 أيام';
  @override String get admin_analytics_no_data => 'لا توجد بيانات متاحة';
  @override String get admin_analytics_error => 'فشل تحميل الإحصائيات';
  @override String get admin_event_create => 'إنشاء فعالية';
  @override String get admin_event_edit => 'تعديل الفعالية';
  @override String get admin_event_btn_create => 'إنشاء';
  @override String get admin_event_btn_save => 'حفظ';
  @override String get admin_event_cover => 'صورة الغلاف';
  @override String get admin_event_banner => 'بانر (اللافتة)';
  @override String get admin_event_title => 'العنوان *';
  @override String get admin_event_desc => 'الوصف *';
  @override String get admin_event_category => 'الفئة';
  @override String get admin_event_subcategory => 'الفئة الفرعية';
  @override String get admin_event_datetime => 'التاريخ والوقت';
  @override String get admin_event_start => 'البداية';
  @override String get admin_event_end => 'النهاية (اختياري)';
  @override String get admin_event_add_end => 'إضافة وقت النهاية';
  @override String get admin_event_city => 'المدينة *';
  @override String get admin_event_location => 'الموقع *';
  @override String get admin_event_address => 'العنوان';
  @override String get admin_event_organizer => 'المنظم';
  @override String get admin_event_phone => 'الهاتف';
  @override String get admin_event_email => 'بريد التواصل';
  @override String get admin_event_tiers_title => 'الفئات والسعة';
  @override String get admin_event_add_tier_btn => 'إضافة VVIP, VIP…';
  @override String get admin_event_status => 'الحالة';
  @override String get admin_event_visibility => 'الرؤية';
  @override String get admin_event_cat_concert => 'حفل موسيقي';
  @override String get admin_event_cat_conference => 'مؤتمر';
  @override String get admin_event_cat_sport => 'رياضة';
  @override String get admin_event_cat_festival => 'مهرجان';
  @override String get admin_event_cat_theatre => 'مسرح';
  @override String get admin_event_cat_other => 'آخر';
  @override String get admin_event_status_upcoming => 'قادمة';
  @override String get admin_event_status_ongoing => 'جارية';
  @override String get admin_event_status_completed => 'مكتملة';
  @override String get admin_event_status_cancelled => 'ملغاة';
  @override String get admin_event_vis_default => 'قادمة (الافتراضي)';
  @override String get admin_event_vis_recommended => 'موصى بها';
  @override String get admin_event_vis_featured => 'مميزة';
  @override String get admin_event_dialog_add_tier => 'إضافة فئة';
  @override String get admin_event_dialog_name => 'الاسم (مثال: VVIP)';
  @override String admin_event_dialog_price(String currency) => 'السعر ($currency)';
  @override String get admin_event_dialog_capacity => 'السعة';
  @override String get admin_event_dialog_cancel => 'إلغاء';
  @override String get admin_event_dialog_add => 'إضافة';
  @override String get admin_event_err_readonly => 'قراءة فقط';
  @override String get admin_event_err_min_tier => 'فئة واحدة على الأقل مطلوبة';
  @override String get admin_event_success => 'تم حفظ الفعالية بنجاح';
  @override String get admin_event_err_title_req => 'العنوان مطلوب';
  @override String get admin_event_err_desc_min => 'الحد الأدنى 10 أحرف';
  @override String get admin_event_err_city_req => 'المدينة مطلوبة';
  @override String get admin_event_err_loc_req => 'الموقع مطلوب';
  @override String get admin_seat_page_title => 'خريطة المقاعد والتسعير';
  @override String get admin_seat_target_event => 'الفعالية المستهدفة';
  @override String get admin_seat_select_event => 'اختر فعالية';
  @override String admin_seat_max_limit(int count) => 'الحد الأقصى $count مقاعد';
  @override String admin_seat_generated(int count) => 'تم إنشاء $count مقاعد';
  @override String get admin_seat_load_error => 'فشل تحميل المقاعد';
  @override String get admin_seat_pricing_title => 'التسعير الديناميكي';
  @override String get admin_seat_layout_title => 'التصميم والشكل';
  @override String get admin_seat_rows => 'الصفوف';
  @override String get admin_seat_per_row => 'المقاعد / صف';
  @override String get admin_seat_center_aisle => 'الممر الأوسط';
  @override String get admin_seat_aisle_desc => 'مساحة فارغة في المنتصف';
  @override String get admin_seat_cats_per_row => 'الفئات لكل صف';
  @override String get admin_seat_generating => 'جاري الإنشاء…';
  @override String admin_seat_generate_btn(int count) => 'إنشاء $count مقاعد';
  @override String get admin_seat_preview => 'معاينة التصميم الحالي';
  @override String get admin_seat_no_seats => 'لم يتم إنشاء مقاعد';
  @override String get admin_seat_cat_standard => 'عادي';
  @override String get admin_seat_cat_vip => 'VIP';
  @override String get admin_seat_cat_gold => 'ذهبي';
  @override String get admin_seat_cat_family => 'عائلة';
  @override String get admin_seat_legend_reserved => 'محجوز';
  @override String get admin_seat_legend_sold => 'مباع';
  @override String get seat_map_stage => 'المسرح';

  // ============================================================================
  // ERREURS & VALIDATION (ERRORS & VALIDATION)
  // ============================================================================
  @override String get error_generic => 'حدث خطأ';
  @override String get error_validation => 'بيانات غير صالحة';
  @override String get error_file_too_large => 'الملف كبير جداً';
  @override String get error_unsupported_format => 'التنسيق غير مدعوم';
  @override String get error_permission_denied => 'تم رفض الإذن';
  @override String get error_camera_unavailable => 'الكاميرا غير متاحة';
  @override String get error_microphone_unavailable => 'الميكروفون غير متاح';
  @override String get error_location_unavailable => 'خدمات الموقع غير متاحة';
  @override String get error_network => 'خطأ في الشبكة';
  @override String get error_timeout => 'انتهت مهلة الطلب';
  @override String get error_server => 'خطأ في الخادم';
  @override String get error_not_found => 'غير موجود';

  // ============================================================================
  // TEMPS & DATES RELATIVES (RELATIVE DATES & TIMES)
  // ============================================================================
  @override String get common_just_now => 'الآن';
  @override String get common_in_the_future => 'لاحقاً';
  @override String common_minutes_ago(int count) => count == 1 ? 'منذ دقيقة واحدة' : 'منذ $count دقائق';
  @override String common_hours_ago(int count) => count == 1 ? 'منذ ساعة واحدة' : 'منذ $count ساعات';
  @override String common_days_ago(int count) => count == 1 ? 'منذ يوم واحد' : 'منذ $count أيام';
  @override String common_seconds_ago(int count) => count == 1 ? 'منذ ثانية واحدة' : 'منذ $count ثوانٍ';
  @override String common_weeks_ago(int count) => count == 1 ? 'منذ أسبوع واحد' : 'منذ $count أسابيع';
  @override String common_months_ago(int count) => count == 1 ? 'منذ شهر واحد' : 'منذ $count أشهر';
  @override String common_years_ago(int count) => count == 1 ? 'منذ عام واحد' : 'منذ $count أعوام';
  @override String common_in_minutes(int count) => count == 1 ? 'خلال دقيقة' : 'خلال $count دقائق';
  @override String common_in_hours(int count) => count == 1 ? 'خلال ساعة' : 'خلال $count ساعات';
  @override String common_in_days(int count) => count == 1 ? 'خلال يوم' : 'خلال $count أيام';
}
