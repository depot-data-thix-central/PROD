// lib/l10n/app_localizations_ar.dart
import 'dart:ui';
import 'app_localizations.dart';

class AppLocalizationsAr extends AppLocalizations {
  @override
  Locale get locale => const Locale('ar');

  // ============================================================================
  // COMMON & UI (عام وواجهة المستخدم)
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
  @override String get common_loading => 'جارٍ التحميل…';
  @override String get common_please_wait => 'يرجى الانتظار…';
  @override String get common_today => 'اليوم';
  @override String get common_yesterday => 'أمس';
  @override String get common_tomorrow => 'غداً';
  @override String get common_home => 'الرئيسية';
  @override String get common_chat => 'دردشة';
  @override String get common_map => 'خريطة';
  @override String get common_profile => 'الملف الشخصي';
  @override String get common_menu => 'القائمة';
  @override String get common_notifications => 'الإشعارات';
  @override String get common_settings => 'الإعدادات';
  @override String get common_help => 'مساعدة';
  @override String get common_about => 'حول';
  @override String get common_logout => 'تسجيل الخروج';
  @override String get common_login => 'تسجيل الدخول';
  @override String get common_signup => 'إنشاء حساب';
  @override String get common_yes => 'نعم';
  @override String get common_no => 'لا';
  @override String get common_or => 'أو';
  @override String get common_and => 'و';
  @override String get common_none => 'لا يوجد';
  @override String get common_all => 'الكل';
  @override String get common_unknown => 'غير معروف';
  @override String get common_enabled => 'مفعل';
  @override String get common_disabled => 'معطل';
  @override String get common_clear => 'مسح';
  @override String get common_remove => 'إزالة';

  @override
  String common_items(int count) => count == 0 ? 'لا توجد عناصر' : (count == 1 ? 'عنصر واحد' : '$count عناصر');
  @override
  String common_contacts(int count) => count == 0 ? 'لا توجد جهات اتصال' : (count == 1 ? 'جهة اتصال واحدة' : '$count جهات اتصال');
  @override
  String common_messages(int count) => count == 0 ? 'لا توجد رسائل' : (count == 1 ? 'رسالة واحدة' : '$count رسائل');
  @override
  String common_days(int count) => count == 0 ? '0 يوم' : (count == 1 ? 'يوم واحد' : '$count أيام');
  @override
  String common_hours(int count) => count == 0 ? '0 ساعة' : (count == 1 ? 'ساعة واحدة' : '$count ساعات');
  @override
  String common_minutes(int count) => count == 0 ? '0 دقيقة' : (count == 1 ? 'دقيقة واحدة' : '$count دقائق');

  // ============================================================================
  // THIX MEDIA & IA SOURCES (مصادر THIX MEDIA والذكاء الاصطناعي)
  // ============================================================================
  @override String get live_send => 'إرسال';
  @override String get live_ending => 'إنهاء البث المباشر...';
  @override String get live_network_quality => 'جودة الشبكة';
  @override String get source_type_official => 'رسمي';
  @override String get source_type_world_bank => 'البنك الدولي';
  @override String get source_type_government => 'حكومة';
  @override String get source_type_default => 'مصدر موثوق';
  @override String get source_aria_label => 'مصدر المعلومات';

  // ============================================================================
  // AUTH & ONBOARDING (المصادقة والإعداد الأولي)
  // ============================================================================
  @override String get auth_login => 'تسجيل الدخول';
  @override String get auth_signup => 'إنشاء حساب';
  @override String get auth_forgot_password => 'نسيت كلمة المرور؟';
  @override String get auth_reset_password => 'إعادة تعيين كلمة المرور';
  @override String get auth_email => 'البريد الإلكتروني';
  @override String get auth_phone => 'رقم الهاتف';
  @override String get auth_password => 'كلمة المرور';
  @override String get auth_confirm_password => 'تأكيد كلمة المرور';
  @override String get auth_logout_confirm => 'هل تريد حقاً تسجيل الخروج؟';
  @override String get auth_welcome_back => 'مرحباً بعودتك';
  @override String get auth_welcome => 'مرحباً';
  @override String get auth_no_account => 'ليس لديك حساب بعد؟';
  @override String get auth_has_account => 'لديك حساب بالفعل؟';
  @override String get auth_invalid_email => 'عنوان البريد الإلكتروني غير صالح';
  @override String get auth_invalid_phone => 'رقم الهاتف غير صالح';
  @override String get auth_password_too_short => 'كلمة المرور قصيرة جداً (8 أحرف كحد أدنى)';
  @override String get auth_passwords_mismatch => 'كلمات المرور غير متطابقة';
  @override String get auth_login_success => 'تم تسجيل الدخول بنجاح';
  @override String get auth_signup_success => 'تم إنشاء الحساب بنجاح';
  @override String get auth_session_expired => 'انتهت الجلسة، يرجى تسجيل الدخول مرة أخرى';
  @override String get auth_2fa_title => 'التحقق بخطوتين';
  @override String get auth_2fa_code => 'رمز التحقق';
  @override String get auth_verify_email => 'التحقق من البريد الإلكتروني';
  @override String get auth_verify_phone => 'التحقق من الهاتف';
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
  @override String get auth_phone_already_used => 'هذا الرقم مستخدم بالفعل';
  @override String get auth_create_account => 'إنشاء حسابي';
  @override String get auth_already_have_account => 'لدي حساب بالفعل';

  @override String get onboarding_welcome => 'مرحباً بك في THIX';
  @override String get onboarding_step_1_title => 'اتصال';
  @override String get onboarding_step_1_desc => 'أنشئ هوية THIX الآمنة الخاصة بك';
  @override String get onboarding_step_2_title => 'حماية';
  @override String get onboarding_step_2_desc => 'فعّل الحماية على مدار الساعة';
  @override String get onboarding_step_3_title => 'عمل';
  @override String get onboarding_step_3_desc => 'نبّه المنقذين في ثانيتين';
  @override String get onboarding_get_started => 'ابدأ';
  @override String get onboarding_skip => 'تخطي المقدمة';

  // ============================================================================
  // LOGIN ERRORS (أخطاء تسجيل الدخول)
  // ============================================================================
  @override String get login_title => 'تسجيل الدخول إلى THIX';
  @override String get login_subtitle => 'مرحباً بعودتك';
  @override String get login_identifier_label => 'المعرف';
  @override String get login_identifier_hint => 'البريد الإلكتروني أو الهاتف أو THIX ID';
  @override String get login_password_label => 'كلمة المرور';
  @override String get login_password_hint => 'كلمة المرور الآمنة الخاصة بك';
  @override String get login_remember_me => 'تذكرني';
  @override String get login_forgot_password => 'نسيت كلمة المرور؟';
  @override String get login_button => 'تسجيل الدخول';
  @override String get login_verifying => 'جارٍ التحقق…';
  @override String get login_retry_in => 'أعد المحاولة خلال';
  @override String get login_seconds_suffix => 'ث';
  @override String get login_biometric => 'أو تابع باستخدام';
  @override String get login_face_id => 'Face ID';
  @override String get login_touch_id => 'Touch ID';

  @override String get login_error_suspended => 'هذا الحساب موقوف. اتصل بالدعم.';
  @override String get login_error_not_active => 'هذا الحساب غير نشط.';
  @override String get login_error_no_account => 'لم يتم العثور على حساب بهذه المعلومات.';
  @override String get login_error_mfa_required => 'التحقق بخطوتين مطلوب.';

  @override String get auth_error_identifier_required => 'المعرف مطلوب';
  @override String get auth_error_password_required => 'كلمة المرور مطلوبة';
  @override String get auth_error_thix_id_login_not_available => 'تسجيل الدخول عبر THIX ID غير متاح حالياً';
  @override String get auth_error_sign_in_failed => 'فشل تسجيل الدخول. تحقق من بيانات الاعتماد.';
  @override String get auth_error_email_not_verified => 'يرجى التحقق من بريدك الإلكتروني قبل تسجيل الدخول';
  @override String get auth_error_server_misconfiguration => 'خطأ في تكوين الخادم';
  @override String get auth_error_account_already_exists => 'يوجد حساب بهذا المعرف بالفعل';
  @override String get auth_error_account_exists_wrong_password => 'هذا الحساب موجود لكن كلمة المرور غير صحيحة';
  @override String get auth_error_account_exists_new_otp_sent => 'تم إرسال رمز OTP جديد إلى عنوانك';
  @override String get auth_error_invalid_otp => 'رمز OTP غير صالح أو منتهي الصلاحية';
  @override String get auth_error_otp_expired => 'انتهت صلاحية رمز OTP';
  @override String get auth_error_network => 'خطأ في اتصال الشبكة. تحقق من الإنترنت.';
  @override String get auth_error_rate_limit => 'محاولات كثيرة جداً. يرجى الانتظار قليلاً.';
  @override String get auth_error_technical => 'حدث خطأ تقني. يرجى المحاولة مرة أخرى.';
  @override String get auth_error_user_mismatch => 'تم اكتشاف عدم تطابق المستخدم';
  @override String get auth_error_profile_update_failed => 'فشل تحديث الملف الشخصي';
  @override String get auth_error_mark_email_verified_failed => 'فشل التحقق من البريد الإلكتروني';
  @override String get auth_error_qr_token_generation_failed => 'فشل إنشاء رمز QR';
  @override String get auth_error_finalize_registration_failed => 'فشل إتمام التسجيل';
  @override String get auth_error_consume_qr_token_failed => 'فشل استهلاك رمز QR';
  @override String get auth_error_resend_otp_failed => 'فشل إعادة إرسال OTP';
  @override String get auth_error_phone_auth_not_available => 'المصادقة عبر الهاتف غير متاحة';
  @override String get auth_error_delete_account_not_available => 'حذف الحساب غير متاح حالياً';
  @override String get auth_error_update_email_failed => 'فشل تحديث البريد الإلكتروني';
  @override String get auth_error_reset_password_failed => 'فشل إعادة تعيين كلمة المرور';
  @override String get auth_error_sign_up_failed => 'فشل إنشاء الحساب';
  @override String get auth_info_otp_sent => 'تم إرسال رمز التحقق';

  // ============================================================================
  // REGISTRATION (التسجيل)
  // ============================================================================
  @override String get reg_step1_title => 'ملفك الشخصي';
  @override String get reg_step1_subtitle => 'لنبدأ بالمعلومات الأساسية';
  @override String get reg_full_name_label => 'الاسم الكامل';
  @override String get reg_full_name_hint => 'الاسم واللقب';
  @override String get reg_dob_label => 'تاريخ الميلاد';
  @override String get reg_country_label => 'بلد الإقامة';
  @override String get reg_occupation_label => 'المهنة / النشاط';
  @override String get reg_occupation_hint => 'مثال: مطور، طالب، رائد أعمال';
  @override String get reg_next => 'التالي';

  @override String get reg_step2_title => 'أمّن حسابك';
  @override String get reg_step2_subtitle => 'أنشئ بيانات تسجيل الدخول الخاصة بك';
  @override String get reg_email_label => 'عنوان البريد الإلكتروني';
  @override String get reg_email_hint => 'your.email@example.com';
  @override String get reg_phone_label => 'رقم الهاتف';
  @override String get reg_phone_hint => '+966 5X XXX XXXX';
  @override String get reg_password_label => 'كلمة المرور';
  @override String get reg_password_hint => '8 أحرف كحد أدنى';
  @override String get reg_confirm_password_label => 'تأكيد كلمة المرور';
  @override String get reg_confirm_password_hint => 'أعد إدخال كلمة المرور';
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
  @override String get reg_validate_activate => 'تحقق وفعّل';
  @override String get reg_activating => 'جارٍ التفعيل…';

  @override String get reg_congrats => 'مبروك!';
  @override String get reg_welcome_message => 'مرحباً بك في نظام THIX،';
  @override String get reg_id_card_title => 'بطاقة الهوية الرقمية THIX';
  @override String get reg_official_thix_id => 'THIX ID الرسمي';
  @override String get reg_generating => 'جارٍ الإنشاء…';
  @override String get reg_copy_thix_id => 'نسخ THIX ID';
  @override String get reg_thix_id_copied => 'تم نسخ THIX ID إلى الحافظة';
  @override String get reg_go_to_dashboard => 'الانتقال إلى لوحة التحكم';
  @override String get reg_summary => 'ملخص التسجيل';
  @override String get reg_mobile_label => 'الهاتف المحمول';
  @override String get reg_not_provided => 'غير مقدم';

  // ============================================================================
  // HOME & DASHBOARD (الرئيسية ولوحة التحكم)
  // ============================================================================
  @override String get home_search_hint => 'ابحث عن خدمة أو جهة اتصال…';
  @override String get home_greeting => 'مرحباً';
  @override String get home_greeting_time => 'مساء الخير';
  @override String get home_welcome_back => 'مرحباً بعودتك';
  @override String get home_language_kiswahili => 'السواحيلية';
  @override String get home_banner_default_tag => 'برنامج الشباب';
  @override String get home_banner_default_title => 'اكتشف أحدث الفرص والفعاليات';

  @override String get cert_pending => 'الشهادة قيد المعالجة';
  @override String get cert_tier_ladder => 'المستوى الحالي قيد المراجعة';
  @override String get cert_view => 'عرض';

  @override String get quick_sona => 'THIX Sona';
  @override String get quick_doc => 'مستنداتي';
  @override String get quick_chat => 'دردشة';
  @override String get quick_sos => 'طوارئ';
  @override String get service_sante => 'THIX صحة';
  @override String get service_market => 'THIX سوق';
  @override String get service_money => 'THIX محفظة';
  @override String get service_reservation => 'الحجوزات';
  @override String get service_mon_pays => 'بلدي';
  @override String get service_emploi => 'وظائف';
  @override String get service_formations => 'تدريب';
  @override String get service_opportunites => 'فرص';
  @override String get service_infos => 'أخبار';
  @override String get service_events => 'فعاليات';
  @override String get service_media => 'THIX ميديا';
  @override String get service_vault => 'خزنة';
  @override String get service_network => 'شبكة';
  @override String get service_certification => 'شهادة';

  // ============================================================================
  // CHAT (الدردشة)
  // ============================================================================
  @override String get chatlist_network => 'الشبكة';
  @override String get chatlist_discussions => 'المحادثات';
  @override String get chatlist_create_new => 'إنشاء محادثة جديدة';
  @override String get chatlist_calls => 'المكالمات';
  @override String get chatlist_settings => 'الإعدادات';

  @override String get chat_unknown_user => 'مستخدم غير معروف';
  @override
  String chat_members(int count) => count == 1 ? 'عضو واحد' : '$count أعضاء';
  @override String get chat_video_call => 'مكالمة فيديو';
  @override String get chat_audio_call => 'مكالمة صوتية';
  @override String get chat_escalate => 'تصعيد';
  @override String get chat_history => 'السجل';
  @override String get chat_group_info => 'معلومات المجموعة';
  @override String get chat_file => 'ملف';
  @override String get chat_sticker => 'ملصق';
  @override String get chat_ephemeral => 'زائل';
  @override String get chat_protected => 'محمي';
  @override String get chat_internal_note => 'ملاحظة داخلية';
  @override String get chat_send => 'إرسال';
  @override String get chat_recording => 'جارٍ التسجيل';
  @override String get chat_stop_recording => 'إيقاف';
  @override String get chat_write_message => 'اكتب رسالة...';
  @override String get chat_record_audio => 'تسجيل صوت';
  @override String get chat_emojis => 'رموز تعبيرية';
  @override String get chat_reactions => 'تفاعلات';
  @override String get chat_flags => 'أعلام';
  @override String get chat_callback => 'إعادة الاتصال';
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
  @override String get conv_request_hint => 'أضف رسالة اختيارية إلى طلب الاتصال الخاص بك.';
  @override String get conv_message_optional => 'رسالة (اختياري)';
  @override String get conv_send_request => 'إرسال الطلب';
  @override String get conv_request_sent => 'تم إرسال الطلب بنجاح';
  @override String get conv_request_exists => 'يوجد طلب بالفعل لهذا المستخدم';
  @override String get conv_select_contact => 'يرجى اختيار جهة اتصال واحدة على الأقل';
  @override String get conv_waiting_connection => 'بانتظار الاتصال لـ';
  @override String get conv_group_rpc_required => 'إنشاء مجموعة يتطلب استدعاء الخادم';
  @override String get conv_page_title => 'محادثة جديدة';
  @override
  String conv_start(int count) => 'بدء ($count)';
  @override String get conv_search_label => 'البحث عن مستخدم';
  @override String get conv_search_hint => 'الاسم أو THIX ID أو رقم الهاتف...';
  @override String get conv_group_name_label => 'اسم المجموعة';
  @override String get conv_group_name_hint => 'مثال: فريق مشروع ألفا';

  @override String get requests_page_title => 'طلبات الاتصال';
  @override String get requests_reject_title => 'رفض الطلب';
  @override String get requests_reject_message => 'هل أنت متأكد من رفض طلب الاتصال هذا؟ هذا الإجراء لا رجعة فيه.';
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
  // NETWORK (الشبكة)
  // ============================================================================
  @override String get network_search_title => 'بحث';
  @override String get network_search_hint => 'ابحث عن أشخاص أو منشورات أو مجتمعات…';
  @override String get network_tab_people => 'أشخاص';
  @override String get network_tab_posts => 'منشورات';
  @override String get network_tab_communities => 'مجتمعات';
  @override String get network_explore_title => 'استكشف شبكة THIX';
  @override String get network_explore_subtitle => 'ابحث عن أشخاص أو منشورات أو مجتمعات';
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
  @override String get community_admin => 'مشرف';

  // ============================================================================
  // PROFILE (الملف الشخصي)
  // ============================================================================
  @override String get profile_settings => 'إعدادات الملف الشخصي';
  @override String get profile_edit_bio => 'تعديل النبذة';
  @override String get profile_no_bio => 'لا توجد نبذة متاحة حالياً.';
  @override String get profile_followers => 'متابعون';
  @override String get profile_following => 'يتابع';
  @override String get profile_posts => 'منشورات';
  @override String get profile_follow => 'متابعة';
  @override String get profile_unfollow => 'يتابع';
  @override String get profile_following_loading => 'جارٍ التحميل…';
  @override String get profile_message => 'رسالة';
  @override String get profile_block_user => 'حظر هذا المستخدم؟';
  @override String get profile_block_message => 'لن ترى منشوراته بعد الآن ولن يتمكن من التفاعل معك.';
  @override String get profile_block_confirm => 'حظر';
  @override String get profile_blocked_success => 'تم حظر المستخدم';
  @override String get profile_block_error => 'خطأ أثناء حظر المستخدم';

  @override String get profile_report_user => 'إبلاغ';
  @override String get profile_report_reason => 'السبب';
  @override String get profile_report_details => 'التفاصيل (اختياري)';
  @override String get profile_report_spam => 'رسائل مزعجة';
  @override String get profile_report_inappropriate => 'محتوى غير لائق';
  @override String get profile_report_harassment => 'تحرش';
  @override String get profile_report_impersonation => 'انتحال شخصية';
  @override String get profile_report_other => 'آخر';
  @override String get profile_report_submit => 'إرسال البلاغ';
  @override String get profile_report_success => 'تم إرسال البلاغ';
  @override String get profile_report_duplicate => 'تم الإبلاغ بالفعل';

  @override String get profile_private_gallery => 'معرض خاص';
  @override String get profile_private_content_locked => 'هذا المحتوى خاص';
  @override String get profile_add_private_media => 'إضافة إلى معرضي الخاص';
  @override String get profile_no_private_media => 'لا توجد وسائط خاصة حالياً';
  @override String get profile_upload_processing => 'جارٍ المعالجة…';

  @override String get profile_tab_bio => 'نبذة';
  @override String get profile_tab_private_gallery => 'معرض خاص';
  @override String get profile_tab_photos => 'صور عامة';
  @override String get profile_tab_videos => 'فيديوهات';
  @override String get profile_tab_audios => 'صوتيات';
  @override String get profile_no_content => 'لا يوجد محتوى';
  @override String get profile_pinned_post => 'منشور مثبت';
  @override String get profile_view_post => 'عرض المنشور';

  // ============================================================================
  // SETTINGS (الإعدادات)
  // ============================================================================
  @override String get settings_title => 'إعدادات الدردشة';
  @override String get settings_section_appearance => 'المظهر';
  @override String get settings_theme => 'السمة';
  @override String get settings_theme_light => 'فاتح';
  @override String get settings_theme_dark => 'داكن';
  @override String get settings_theme_system => 'النظام';
  @override String get settings_wallpaper => 'الخلفية';
  @override String get settings_wallpaper_default => 'افتراضي';
  @override String get settings_wallpaper_custom => 'مخصص';

  @override String get settings_section_privacy => 'الخصوصية';
  @override String get settings_last_seen => 'آخر ظهور';
  @override String get settings_visibility_everyone => 'الجميع';
  @override String get settings_visibility_contacts => 'جهات اتصالي';
  @override String get settings_visibility_nobody => 'لا أحد';
  @override String get settings_profile_photo => 'صورة الملف الشخصي';

  @override String get settings_section_notifications => 'الإشعارات';
  @override String get settings_messages => 'الرسائل';
  @override String get settings_calls => 'المكالمات';

  @override String get settings_section_messages => 'الرسائل والبيانات';
  @override String get settings_ephemeral => 'رسائل زائلة';
  @override String get settings_auto_download => 'تنزيل الوسائط تلقائياً';
  @override String get settings_download_wifi => 'Wi-Fi فقط';
  @override String get settings_download_mobile => 'Wi-Fi وبيانات الجوال';
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

  @override String get settings_choose_language => 'اختر اللغة';
  @override String get settings_system_default => 'افتراضي النظام';
  @override String get settings_language_change_failed => 'فشل تغيير اللغة';

  // ============================================================================
  // SOS (الطوارئ)
  // ============================================================================
  @override String get sos_button => 'طوارئ';
  @override String get sos_button_label => 'زر الطوارئ SOS';
  @override String get sos_button_hint => 'اضغط لمدة ثانيتين للتفعيل';
  @override String get sos_button_tooltip => 'اضغط مع الاستمرار ثانيتين';
  @override String get sos_trigger_button => 'تفعيل SOS';
  @override String get sos_trigger_timeout => 'انتهت المهلة. يرجى إعادة المحاولة.';
  @override String get sos_trigger_error => 'فشل في تفعيل SOS';
  @override String get sos_active => 'SOS نشط';
  @override String get sos_crisis_room => 'غرفة الأزمات';
  @override String get sos_command_center => 'مركز القيادة';
  @override String get sos_incident => 'حادث';
  @override String get sos_incident_unknown => 'حادث غير معروف';
  @override String get sos_incident_not_found => 'لم يتم العثور على الحادث';
  @override String get sos_circle => 'دائرة';
  @override String get sos_rescuers => 'منقذون';
  @override String get sos_rescuer => 'منقذ';
  @override String get sos_my_rescuers => 'المنقذون الخاصون بي';
  @override String get sos_duration => 'المدة';
  @override String get sos_identifier => 'المعرف';
  @override String get sos_calling => 'جاري الاتصال…';
  @override String get sos_call => 'اتصال';
  @override String get sos_available => 'متاح';
  @override String get sos_unavailable => 'غير متاح';
  @override String get sos_verified => 'موثق';
  @override String get sos_end => 'إنهاء';
  @override String get sos_end_sos => 'إنهاء SOS';
  @override String get sos_cancel_sos => 'إلغاء SOS';
  @override String get sos_pin_required => 'رمز الأمان مطلوب';
  @override String get sos_cancelled => 'تم إلغاء SOS';
  @override String get sos_resolved => 'تم حل SOS';
  @override String get sos_cancel_failed => 'فشل الإلغاء';
  @override String get sos_in_progress => 'قيد التنفيذ';
  @override String get sos_history => 'السجل';
  @override String get sos_my_incidents => 'الحوادث الخاصة بي';
  @override String get sos_no_incidents => 'لا توجد حوادث بعد';
  @override String get sos_incidents_appear_here => 'ستظهر طلبات SOS الخاصة بك هنا';
  @override String get sos_history_error => 'لا يمكن تحميل السجل';
  @override String get sos_circle_1 => 'الدائرة 1 – الأولوية';
  @override String get sos_circle_2 => 'الدائرة 2 – الثانوية';
  @override String get sos_circle_3 => 'الدائرة 3 – الطوارئ';
  @override String get sos_no_rescuers => 'لا يوجد منقذون';
  @override String get sos_add_first_rescuer => 'أضف جهة الاتصال الأولى للإنقاذ';
  @override String get sos_add_rescuer => 'إضافة منقذ';
  @override String get sos_add_rescuer_info => 'أدخل معرف THIX للمنقذ. سيتم جلب الاسم والصورة تلقائياً.';
  @override String get sos_thix_id_label => 'THIX ID';
  @override String get sos_thix_id_hint => 'THIX-XXXX';

  // ============================================================================
  // CERTIFICATION (الشهادة)
  // ============================================================================
  @override String get certification_title => 'شهادة THIX';
  @override String get certification_apply => 'طلب شهادة';
  @override String get certification_status => 'الحالة';
  @override String get certification_pending => 'قيد المعالجة';
  @override String get certification_approved => 'معتمدة';
  @override String get certification_rejected => 'مرفوضة';
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
  // EDUCATION (التعليم)
  // ============================================================================
  @override String get edu_nav_home => 'الرئيسية';
  @override String get edu_nav_learning => 'تعليمي';
  @override String get edu_nav_library => 'المكتبة';
  @override String get edu_nav_certs => 'الشهادات';
  @override String get edu_nav_profile => 'الملف الشخصي';

  @override String get edu_auth_required => 'سجل الدخول لعرض دوراتك';
  @override String get edu_login_required => 'سجل الدخول لعرض دوراتك';

  @override String get edu_learning_empty_title => 'لا توجد دورات جارية';
  @override String get edu_learning_empty_desc => 'سجل في دورة للبدء.';
  @override String get edu_no_courses => 'لا توجد دورات جارية';
  @override String get edu_enroll_hint => 'سجل في دورة للبدء.';
  @override String get edu_explore_btn => 'استكشف الدورات';
  @override String get edu_completed => 'مكتمل';

  @override String get edu_user_avatar => 'صورة المستخدم';
  @override String get edu_greeting => 'مرحباً،';
  @override String get edu_greeting_subtitle => 'هل أنت مستعد لتحسين مهاراتك؟';
  @override String get edu_ready_to_learn => 'هل أنت مستعد لتطوير مهاراتك؟';
  @override String get edu_learner => 'متعلم';
  @override String get edu_notifications => 'الإشعارات';
  @override String get edu_search_hint => 'ابحث عن دورات، شهادات…';
  @override String get edu_browse => 'تصفح';
  @override String get edu_library => 'المكتبة';
  @override String get edu_certs => 'الشهادات';
  @override String get edu_qa_browse => 'تصفح';
  @override String get edu_instructor => 'مدرب';

  @override String get edu_top_formations => 'أفضل الدورات';
  @override String get edu_awaited_formations => 'الأكثر انتظاراً';
  @override String get edu_awaited => 'الأكثر انتظاراً';
  @override String get edu_see_all => 'عرض الكتالوج';

  @override
  String edu_coming_soon(String category) => 'دورات جديدة في $category قريباً';
  @override String get edu_coming_soon_cat => 'دورات جديدة قريباً هنا';
  @override String get edu_locked_course => 'قريباً! (الفتح متوقع قريباً)';
  @override String get edu_coming_soon_badge => 'يفتح قريباً';
  @override String get edu_awaited_badge => 'قريباً';
  @override String get edu_awaited_locked => 'مقفل';
  @override String get edu_awaited_locked_msg => 'قريباً! (الفتح متوقع قريباً)';

  @override String get edu_thix_academy => 'أكاديمية THIX';
  @override String get edu_scheduled_soon => 'مقرر: قريباً';
  @override String get edu_new_program => 'برنامج جديد';
  @override String get edu_resume_learning => 'استئناف التعلم';
  @override String get edu_resume => 'استئناف التعلم';

  @override String get edu_catalog => 'الكتالوج';
  @override String get edu_no_formations_cat => 'لا توجد دورات في هذه الفئة';

  @override String get edu_my_library => 'مكتبتي';
  @override String get edu_search_book_hint => 'ابحث بالعنوان أو المؤلف...';
  @override String get edu_library_title => 'مكتبتي';
  @override String get edu_search_library => 'ابحث بالعنوان أو المؤلف…';
  @override String get edu_shelves_empty => 'رفوفك فارغة.';
  @override String get edu_library_empty => 'رفوفك فارغة.';
  @override String get edu_no_result => 'لا توجد نتائج';
  @override
  String edu_search_no_results(String query) => 'لا توجد نتائج لـ "$query"';

  @override String get edu_shelf => 'رف';
  @override String get edu_books => 'كتب';
  @override String get edu_all => 'الكل';
  @override
  String edu_shelf_info(String code, int count) => 'رف $code · $count كتب';
  @override String get edu_free => 'مجاني';
  @override String get edu_deleted_in => 'سيُحذف خلال';
  @override
  String edu_expires_in(String countdown) => 'تنتهي الصلاحية خلال $countdown';

  @override String get edu_certifications => 'الشهادات';
  @override String get edu_certs_title => 'الشهادات';
  @override String get edu_no_certs => 'لا توجد شهادات بعد';
  @override String get edu_cert_expert => 'شهادة خبرة';
  @override String get edu_cert_expertise => 'شهادة خبرة';
  @override
  String edu_cert_issued(String date) => 'صدرت في $date';

  @override String get edu_pro_account => 'حساب احترافي';
  @override String get edu_profile_title => 'حساب احترافي';
  @override String get edu_instructor_space => 'مساحة المدرب';
  @override String get edu_tools => 'أدوات مؤسسية';
  @override String get edu_institutional_tools => 'أدوات مؤسسية';
  @override String get edu_free_resources => 'موارد مفتوحة';
  @override String get edu_masterclass => 'دورات متقدمة';
  @override String get edu_masterclasses => 'دورات متقدمة';
  @override String get edu_network => 'شبكة وإرشاد';
  @override String get edu_mentorship => 'تواصل وإرشاد';
  @override String get edu_events_agenda => 'جدول الفعاليات';
  @override String get edu_support => 'الدعم الفني';
  @override String get edu_not_connected => 'غير متصل';

  @override String get training_title => 'تدريب';
  @override String get training_enroll => 'تسجيل';
  @override String get training_my_courses => 'دوراتي';
  @override String get training_certificates => 'شهاداتي';
  @override String get training_progress => 'التقدم';
  @override String get training_lessons => 'دروس';
  @override String get training_duration => 'المدة';
  @override String get training_level => 'المستوى';
  @override String get training_beginner => 'مبتدئ';
  @override String get training_intermediate => 'متوسط';
  @override String get training_advanced => 'متقدم';
  @override String get training_start_course => 'بدء الدورة';
  @override String get training_continue_course => 'متابعة الدورة';

  // ============================================================================
  // JOBS (الوظائف)
  // ============================================================================
  @override String get jobs_title => 'وظائف';
  @override String get jobs_search => 'ابحث عن وظيفة';
  @override String get jobs_apply => 'تقديم';
  @override String get jobs_saved => 'محفوظة';
  @override String get jobs_applied => 'طلبات مقدمة';
  @override String get jobs_company => 'شركة';
  @override String get jobs_location => 'الموقع';
  @override String get jobs_salary => 'الراتب';
  @override String get jobs_type => 'النوع';
  @override String get jobs_full_time => 'دوام كامل';
  @override String get jobs_part_time => 'دوام جزئي';
  @override String get jobs_contract => 'عقد';
  @override String get jobs_internship => 'تدريب';
  @override String get jobs_freelance => 'عمل حر';
  @override String get jobs_remote => 'عن بُعد';
  @override String get jobs_onsite => 'في الموقع';
  @override String get jobs_hybrid => 'هجين';
  @override String get jobs_experience => 'الخبرة';
  @override String get jobs_no_experience => 'بدون خبرة';
  @override String get jobs_junior => 'مبتدئ';
  @override String get jobs_mid => 'متوسط';
  @override String get jobs_senior => 'خبير';
  @override String get jobs_requirements => 'المتطلبات';
  @override String get jobs_responsibilities => 'المسؤوليات';
  @override String get jobs_benefits => 'المزايا';
  @override String get jobs_apply_now => 'قدم الآن';
  @override String get jobs_application_sent => 'تم إرسال الطلب';
  @override String get jobs_no_results => 'لم يتم العثور على وظائف';
  @override String get recruiter_title => 'مسؤول توظيف';
  @override String get recruiter_post_job => 'نشر وظيفة';
  @override String get recruiter_candidates => 'مرشحون';
  @override String get recruiter_applications => 'طلبات';
  @override String get recruiter_interviews => 'مقابلات';

  // ============================================================================
  // OPPORTUNITIES (الفرص)
  // ============================================================================
  @override String get opportunities_title => 'فرص';
  @override String get opportunities_business => 'أعمال';
  @override String get opportunities_investment => 'استثمار';
  @override String get opportunities_partnership => 'شراكة';
  @override String get opportunities_grant => 'منحة';
  @override String get opportunities_coming_soon => 'قريباً';

  // ============================================================================
  // MARKET (السوق)
  // ============================================================================
  @override String get market_title => 'سوق THIX';
  @override String get market_categories => 'الفئات';
  @override String get market_products => 'منتجات';
  @override String get market_services => 'خدمات';
  @override String get market_add_to_cart => 'أضف إلى السلة';
  @override String get market_buy_now => 'اشترِ الآن';
  @override String get market_cart => 'السلة';
  @override String get market_checkout => 'إتمام الشراء';
  @override String get market_total => 'الإجمالي';
  @override String get market_delivery => 'التوصيل';
  @override String get market_seller => 'البائع';
  @override String get market_rating => 'التقييم';
  @override String get market_reviews => 'المراجعات';
  @override String get market_in_stock => 'متوفر';
  @override String get market_out_of_stock => 'غير متوفر';
  @override String get market_add_to_favorites => 'أضف إلى المفضلة';
  @override String get market_remove_from_cart => 'إزالة من السلة';

  // ============================================================================
  // MONEY (المال)
  // ============================================================================
  @override String get money_title => 'محفظة THIX';
  @override String get money_balance => 'الرصيد';
  @override String get money_send => 'إرسال';
  @override String get money_receive => 'استلام';
  @override String get money_history => 'السجل';
  @override String get money_transactions => 'المعاملات';
  @override String get money_top_up => 'شحن';
  @override String get money_withdraw => 'سحب';
  @override String get money_transfer => 'تحويل';
  @override String get money_bills => 'فواتير';
  @override String get money_recipients => 'المستفيدون';
  @override String get money_add_recipient => 'إضافة مستفيد';
  @override String get money_amount => 'المبلغ';
  @override String get money_fee => 'الرسوم';
  @override String get money_reference => 'المرجع';
  @override String get money_confirm_transfer => 'تأكيد التحويل';
  @override String get money_transfer_success => 'تم التحويل بنجاح';
  @override String get money_transfer_failed => 'فشل التحويل';
  @override String get money_insufficient_funds => 'الرصيد غير كافٍ';

  // ============================================================================
  // EVENTS (الفعاليات)
  // ============================================================================
  @override String get events_title => 'فعاليات';
  @override String get events_upcoming => 'قادمة';
  @override String get events_past => 'سابقة';

  @override String get event_share_cta => 'احجز مكانك على THIX!';
  @override String get event_sold_out_title => 'الفعالية مكتملة';
  @override String get event_sold_out_msg => 'جميع الأماكن محجوزة حالياً. انضم إلى قائمة الانتظار ليتم إشعارك.';
  @override String get event_join_queue_confirm => 'هل تريد الانضمام إلى قائمة الانتظار؟';
  @override String get event_join_queue_btn => 'انضم إلى القائمة';

  @override String get event_unfavorite => 'إزالة من المفضلة';
  @override String get event_favorite => 'أضف إلى المفضلة';
  @override String get event_free => 'مجاني';
  @override String get event_paid => 'مدفوع';

  @override String get event_time_label => 'الوقت';
  @override String get event_location_label => 'الموقع';
  @override String get event_address_label => 'العنوان الدقيق';
  @override String get event_organized_by => 'منظم بواسطة';

  @override String get event_about_title => 'حول';
  @override String get event_no_description => 'لا يوجد وصف متاح لهذه الفعالية.';
  @override String get event_tickets_title => 'التذاكر والحجز';

  @override String get event_sold_out_short => 'مكتمل';
  @override
  String event_remaining_seats(String count) => '$count مقاعد متبقية';
  @override String get event_queue_btn => 'قائمة الانتظار';
  @override String get event_book_btn => 'حجز';

  @override String get event_standard_entry => 'دخول عادي';
  @override String get event_all_sold => 'جميع المقاعد مباعة';
  @override String get event_limited_seats => 'مقاعد محدودة';
  @override String get event_book_now_btn => 'احجز الآن';

  @override
  String event_numbered_seats(String count) => '$count مقاعد مرقمة';
  @override String get event_choose_seats_btn => 'اختر مقاعدي';
  @override String get event_from_price => 'يبدأ من';

  @override String get events_my_tickets => 'تذاكري';
  @override String get events_buy_ticket => 'شراء تذكرة';
  @override String get events_ticket_price => 'سعر التذكرة';
  @override String get events_date => 'التاريخ';
  @override String get events_time => 'الوقت';
  @override String get events_venue => 'المكان';
  @override String get events_organizer => 'المنظم';
  @override String get events_attendees => 'الحضور';
  @override String get events_seats_available => 'مقاعد متاحة';
  @override String get events_sold_out => 'مكتمل';
  @override String get events_book_now => 'احجز الآن';
  @override String get events_ticket_type => 'نوع التذكرة';
  @override String get ticket_standard => 'عادي';
  @override String get ticket_vip => 'VIP';
  @override String get ticket_gold => 'ذهبي';
  @override String get ticket_family => 'عائلي';
  @override String get ticket_secure_ticket => 'تذكرة آمنة';
  @override String get ticket_not_found => 'لم يتم العثور على التذكرة';
  @override String get ticket_location => 'الموقع';
  @override String get ticket_pin_label => 'رمز PIN';
  @override String get ticket_show_qr => 'عرض QR';
  @override String get ticket_booking_id => 'معرّف الحجز';
  @override String get ticket_add_wallet => 'المحفظة';
  @override String get ticket_wallet_coming_soon => 'تكامل المحفظة قريباً';
  @override String get ticket_share => 'مشاركة';
  @override String get ticket_share_text => 'تذكرتي THIX';
  @override String get ticket_scan_info => 'اعرض رمز QR هذا عند المدخل';
  @override String get ticket_security_title => 'الأمان';
  @override String get ticket_enter_pin => 'أدخل PIN الخاص بك';
  @override String get ticket_pin_hint => 'رمز من 4 أرقام';
  @override String get ticket_pin_incorrect => 'الرمز غير صحيح';
  @override String get ticket_pin_too_many_attempts => 'محاولات كثيرة جداً';
  @override String get ticket_attempts_remaining => 'المحاولات المتبقية';
  @override String get tickets_ticket => 'تذكرة';
  @override String get tickets_completed => 'مكتملة';
  @override String get tickets_no_tickets => 'لا توجد تذاكر';
  @override String get tickets_no_tickets_desc => 'ستظهر حجوزاتك هنا';
  @override String get tickets_discover => 'اكتشف';
  @override String get tickets_load_error => 'تعذر تحميل تذاكرك';
  @override
  String tickets_quantity(int count) => count == 0 ? 'لا توجد تذاكر' : (count == 1 ? 'تذكرة واحدة' : '$count تذاكر');

  // ============================================================================
  // RESERVATION (الحجز)
  // ============================================================================
  @override String get reservation_title => 'الحجوزات';
  @override String get reservation_hotel => 'فندق';
  @override String get reservation_restaurant => 'مطعم';
  @override String get reservation_transport => 'نقل';
  @override String get reservation_check_in => 'تسجيل الوصول';
  @override String get reservation_check_out => 'تسجيل المغادرة';
  @override String get reservation_guests => 'ضيوف';
  @override String get reservation_rooms => 'غرف';
  @override String get reservation_book => 'حجز';
  @override String get reservation_cancel => 'إلغاء';
  @override String get reservation_modify => 'تعديل';
  @override String get reservation_confirm => 'تأكيد الحجز';
  @override String get reservation_my_bookings => 'حجوزاتي';

  // ============================================================================
  // HEALTH (الصحة)
  // ============================================================================
  @override String get health_title => 'THIX صحة';
  @override String get health_appointments => 'مواعيد';
  @override String get health_doctors => 'أطباء';
  @override String get health_hospitals => 'مستشفيات';
  @override String get health_pharmacies => 'صيدليات';
  @override String get health_emergency => 'طوارئ';
  @override String get health_medical_records => 'السجلات الطبية';
  @override String get health_prescriptions => 'الوصفات الطبية';
  @override String get health_book_appointment => 'حجز موعد';
  @override String get health_appointment_date => 'تاريخ الموعد';
  @override String get health_specialty => 'التخصص';
  @override String get health_consultation => 'استشارة';
  @override String get health_telemedicine => 'طب عن بُعد';
  @override String get health_insurance => 'تأمين';
  @override String get health_symptoms => 'الأعراض';
  @override String get health_find_doctor => 'ابحث عن طبيب';

  // ============================================================================
  // MEDIA (الإعلام)
  // ============================================================================
  @override String get media_title => 'THIX ميديا';
  @override String get media_news => 'أخبار';
  @override String get media_videos => 'فيديوهات';
  @override String get media_podcasts => 'بودكاست';
  @override String get media_articles => 'مقالات';
  @override String get media_live => 'مباشر';
  @override String get media_categories => 'الفئات';
  @override String get media_bookmarks => 'الإشارات المرجعية';
  @override String get media_share_article => 'مشاركة المقال';
  @override String get media_read_more => 'اقرأ المزيد';
  @override String get media_published_on => 'نُشر في';
  @override String get media_author => 'المؤلف';
  @override String get info_title => 'معلومات';
  @override String get info_local => 'محلي';
  @override String get info_national => 'وطني';
  @override String get info_international => 'دولي';
  @override String get info_sports => 'رياضة';
  @override String get info_culture => 'ثقافة';
  @override String get info_economy => 'اقتصاد';
  @override String get info_politics => 'سياسة';
  @override String get info_technology => 'تكنولوجيا';
  @override String get info_read_full => 'اقرأ المقال كاملاً';

  // ============================================================================
  // MON PAYS (بلدي)
  // ============================================================================
  @override String get mon_pays_title => 'بلدي';
  @override String get mon_pays_regions => 'المناطق';
  @override String get mon_pays_cities => 'المدن';
  @override String get mon_pays_culture => 'الثقافة';
  @override String get mon_pays_history => 'التاريخ';
  @override String get mon_pays_tourism => 'السياحة';
  @override String get mon_pays_discover => 'اكتشف';
  @override String get mon_pays_landmarks => 'المعالم';
  @override String get mon_pays_traditions => 'التقاليد';

  // ============================================================================
  // VAULT (الخزنة)
  // ============================================================================
  @override String get vault_title => 'الخزنة';
  @override String get vault_documents => 'مستندات';
  @override String get vault_photos => 'صور';
  @override String get vault_videos => 'فيديوهات';
  @override String get vault_notes => 'ملاحظات';
  @override String get vault_passwords => 'كلمات المرور';
  @override String get vault_add_document => 'إضافة مستند';
  @override String get vault_upload => 'رفع';
  @override String get vault_encrypted => 'مشفر';
  @override String get vault_backup => 'نسخ احتياطي';
  @override String get vault_restore => 'استعادة';
  @override String get vault_share_secure => 'مشاركة آمنة';
  @override String get vault_unlock => 'فتح';
  @override String get vault_lock => 'قفل';

  // ============================================================================
  // PAYMENT (الدفع)
  // ============================================================================
  @override String get payment_title => 'الدفع';
  @override String get payment_method => 'طريقة الدفع';
  @override String get payment_card => 'بطاقة بنكية';
  @override String get payment_mobile_money => 'Mobile Money';
  @override String get payment_bank_transfer => 'تحويل بنكي';
  @override String get payment_cash => 'نقداً';
  @override String get payment_confirm => 'تأكيد الدفع';
  @override String get payment_success => 'تم الدفع بنجاح';
  @override String get payment_failed => 'فشل الدفع';
  @override String get payment_processing => 'جارٍ المعالجة…';
  @override String get payment_receipt => 'إيصال';
  @override String get payment_invoice => 'فاتورة';

  // ============================================================================
  // SEARCH (البحث)
  // ============================================================================
  @override String get search_title => 'بحث THIX';
  @override String get search_subtitle => 'مفقودون ومطلوبون';
  @override String get search_person_missing => 'شخص مفقود';
  @override String get search_person_wanted => 'مطلوب رسمياً';
  @override String get search_report_missing => 'الإبلاغ عن فقدان';
  @override String get search_report_found => 'الإبلاغ عن العثور';
  @override String get search_details => 'التفاصيل';
  @override String get search_contact_authorities => 'اتصل بالسلطات';
  @override String get search_share_alert => 'مشاركة التنبيه';
  @override String get search_last_seen => 'آخر ظهور';
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
  @override String get search_reported_by => 'أبلغ بواسطة';
  @override String get search_official_notice => 'إشعار رسمي';
  @override String get search_community_alert => 'تنبيه مجتمعي';

  // ============================================================================
  // NEARBY (القريب)
  // ============================================================================
  @override String get nearby_alerts_title => 'تنبيهات قريبة';
  @override String get nearby_view_on_map => 'عرض على الخريطة';
  @override String get nearby_map_coming_soon => 'خريطة بملء الشاشة قريباً';
  @override String get nearby_map_disabled => 'الخريطة معطلة (بانتظار مفتاح API)';
  @override String get nearby_active_alerts => 'تنبيهات نشطة';
  @override String get nearby_missing => 'مفقود';
  @override String get nearby_official => 'رسمي';
  @override String get nearby_legend_missing => 'مفقود';
  @override String get nearby_legend_official => 'إشعار رسمي';
  @override String get nearby_legend_report => 'بلاغ';
  @override String get nearby_location_required => 'تفعيل الموقع';
  @override String get nearby_location_subtitle => 'عرض التنبيهات من حولك';

  // ============================================================================
  // ADMIN (الإدارة)
  // ============================================================================
  @override String get admin_title => 'إدارة THIX';
  @override String get admin_dev_open => 'التطوير مفتوح';
  @override String get admin_actions_section => 'الإجراءات';

  @override String get admin_events_title => 'الفعاليات';
  @override String get admin_events_create => 'إنشاء';
  @override String get admin_events_search_hint => 'ابحث بالعنوان...';
  @override String get admin_events_filter => 'تصفية الفئة';
  @override String get admin_events_empty => 'لم يتم العثور على فعاليات';
  @override String get admin_events_no_permission => 'ليس لديك إذن لتنفيذ هذا الإجراء';
  @override String get admin_events_delete_title => 'حذف؟';
  @override
  String admin_events_delete_desc(String title) => 'هل تريد حذف $title؟ هذا الإجراء لا رجعة فيه.';

  @override String get admin_limits_purchase_rules => 'قواعد الشراء';
  @override String get admin_limits_max_person => 'الحد الأقصى / شخص (عام)';
  @override String get admin_limits_max_transaction => 'الحد الأقصى / معاملة (سلة)';
  @override String get admin_limits_require_thix_id => 'التحقق من THIX ID مطلوب';
  @override String get admin_limits_require_thix_id_desc => 'موصى به للفعاليات عالية الطلب.';
  @override String get admin_limits_info_title => 'بنية آمنة';
  @override String get admin_limits_info_desc => 'يتم تطبيق هذه الحدود والتحقق منها مباشرة بواسطة دوال SQL (Edge Functions) في الوقت الفعلي لمنع أي حالة سباق (احتيال).';

  @override String get admin_stat_events => 'الفعاليات';
  @override String get admin_stat_bookings => 'الحجوزات';
  @override String get admin_stat_revenue => 'الإيرادات';
  @override String get admin_stat_queue => 'قائمة الانتظار';
  @override String get admin_action_events => 'الفعاليات';
  @override String get admin_action_events_sub => '20 / صفحة';
  @override String get admin_action_create => 'إنشاء';
  @override String get admin_action_create_sub => 'رفع + تحقق';
  @override String get admin_action_seats => 'المقاعد';
  @override String get admin_action_seats_sub => 'دفعة 200';
  @override String get admin_action_reservations => 'الحجوزات';
  @override String get admin_action_reservations_sub => '50 / صفحة + فلاتر';
  @override String get admin_action_limits => 'مكافحة الاحتيال';
  @override String get admin_action_limits_sub => 'الحدود';
  @override String get admin_action_analytics => 'التحليلات';
  @override String get admin_action_analytics_sub => 'RPC';
  @override String get admin_read_only => 'قراءة فقط';
  @override String get admin_bookings_title => 'الحجوزات • 50/صفحة';
  @override String get admin_bookings_export => 'تصدير الخادم جارٍ (مهمة)';
  @override String get admin_bookings_details => 'تفاصيل التذكرة';
  @override String get admin_bookings_event => 'الفعالية';
  @override String get admin_bookings_unknown_event => 'فعالية غير معروفة';
  @override String get admin_bookings_id => 'معرّف الحجز';
  @override String get admin_bookings_quantity => 'الكمية';
  @override String get admin_bookings_category => 'الفئة';
  @override String get admin_bookings_amount => 'المبلغ';
  @override String get admin_bookings_pin => 'PIN';
  @override String get admin_bookings_purchase_date => 'تاريخ الشراء';
  @override String get admin_bookings_close => 'إغلاق';
  @override String get admin_bookings_empty => 'لا توجد حجوزات';
  @override String get admin_bookings_unknown_date => 'تاريخ غير معروف';
  @override
  String admin_bookings_places(int count) => '$count مقاعد';
  @override String get admin_bookings_status_valid => 'صالح';
  @override String get admin_bookings_status_used => 'مستخدم';
  @override String get admin_bookings_status_cancelled => 'ملغى';
  @override String get admin_bookings_status_postponed => 'مؤجل';
  @override String get admin_bookings_status_pending => 'قيد الانتظار';
  @override
  String admin_queue_title(int count) => 'قائمة الانتظار • الوقت الفعلي ($count)';
  @override String get admin_queue_realtime_desc => 'الوقت الفعلي نشط • تحديث تلقائي عند انضمام المستخدمين';
  @override String get admin_queue_empty => 'لا يوجد انتظار';
  @override String get admin_queue_event_fallback => 'فعالية';
  @override
  String admin_queue_item_meta(String userId, int qty, String status) => 'المستخدم: $userId • $qty مقاعد • $status';
  @override String get admin_queue_notify => 'إشعار';
  @override String get admin_queue_notified => 'تم إشعار المستخدم (تنتهي الصلاحية خلال 10 دقائق)';
  @override String get admin_queue_position => 'الموضع';
  @override String get admin_queue_places => 'المقاعد';
  @override String get admin_analytics_title => 'التحليلات • الأداء';
  @override String get admin_analytics_fill_rate => 'معدل الامتلاء';
  @override String get admin_analytics_avg_cart => 'متوسط السلة';
  @override String get admin_analytics_no_show => 'لم يحضر';
  @override String get admin_analytics_rev_per_event => 'الإيرادات / فعالية';
  @override String get admin_analytics_revenue_7d => 'إيرادات 7 أيام';
  @override String get admin_analytics_no_data => 'لا توجد بيانات';
  @override String get admin_analytics_error => 'تعذر تحميل الإحصائيات';
  @override String get admin_event_create => 'إنشاء فعالية';
  @override String get admin_event_edit => 'تعديل الفعالية';
  @override String get admin_event_btn_create => 'إنشاء';
  @override String get admin_event_btn_save => 'حفظ';
  @override String get admin_event_cover => 'الغلاف';
  @override String get admin_event_banner => 'لافتة';
  @override String get admin_event_title => 'العنوان *';
  @override String get admin_event_desc => 'الوصف *';
  @override String get admin_event_category => 'الفئة';
  @override String get admin_event_subcategory => 'الفئة الفرعية';
  @override String get admin_event_datetime => 'التاريخ والوقت';
  @override String get admin_event_start => 'البداية';
  @override String get admin_event_end => 'النهاية (اختياري)';
  @override String get admin_event_add_end => 'إضافة';
  @override String get admin_event_city => 'المدينة *';
  @override String get admin_event_location => 'المكان *';
  @override String get admin_event_address => 'العنوان';
  @override String get admin_event_organizer => 'المنظم';
  @override String get admin_event_phone => 'الهاتف';
  @override String get admin_event_email => 'البريد الإلكتروني للتواصل';
  @override String get admin_event_tiers_title => 'الفئات والسعة';
  @override String get admin_event_add_tier_btn => 'إضافة VVIP، VIP…';
  @override String get admin_event_status => 'الحالة';
  @override String get admin_event_visibility => 'الرؤية';
  @override String get admin_event_cat_concert => 'حفلة';
  @override String get admin_event_cat_conference => 'مؤتمر';
  @override String get admin_event_cat_sport => 'رياضة';
  @override String get admin_event_cat_festival => 'مهرجان';
  @override String get admin_event_cat_theatre => 'مسرح';
  @override String get admin_event_cat_other => 'آخر';
  @override String get admin_event_status_upcoming => 'قادمة';
  @override String get admin_event_status_ongoing => 'جارية';
  @override String get admin_event_status_completed => 'مكتملة';
  @override String get admin_event_status_cancelled => 'ملغاة';
  @override String get admin_event_vis_default => 'قادمة (افتراضي)';
  @override String get admin_event_vis_recommended => 'موصى بها';
  @override String get admin_event_vis_featured => 'مميزة';
  @override String get admin_event_dialog_add_tier => 'إضافة فئة';
  @override String get admin_event_dialog_name => 'الاسم (مثال: VVIP)';
  @override
  String admin_event_dialog_price(String currency) => 'السعر ($currency)';
  @override String get admin_event_dialog_capacity => 'السعة';
  @override String get admin_event_dialog_cancel => 'إلغاء';
  @override String get admin_event_dialog_add => 'إضافة';
  @override String get admin_event_err_readonly => 'قراءة فقط';
  @override String get admin_event_err_min_tier => 'مطلوب فئة واحدة على الأقل';
  @override String get admin_event_success => 'تم حفظ الفعالية';
  @override String get admin_event_err_title_req => 'العنوان مطلوب';
  @override String get admin_event_err_desc_min => '10 أحرف كحد أدنى';
  @override String get admin_event_err_city_req => 'المدينة مطلوبة';
  @override String get admin_event_err_loc_req => 'المكان مطلوب';
  @override String get admin_seat_page_title => 'خريطة المقاعد والأسعار';
  @override String get admin_seat_target_event => 'الفعالية المستهدفة';
  @override String get admin_seat_select_event => 'اختر فعالية';
  @override
  String admin_seat_max_limit(int count) => 'الحد الأقصى $count مقاعد';
  @override
  String admin_seat_generated(int count) => 'تم إنشاء $count مقاعد';
  @override String get admin_seat_load_error => 'تعذر تحميل المقاعد';
  @override String get admin_seat_pricing_title => 'تسعير ديناميكي';
  @override String get admin_seat_layout_title => 'الشكل والتخطيط';
  @override String get admin_seat_rows => 'الصفوف';
  @override String get admin_seat_per_row => 'مقاعد / صف';
  @override String get admin_seat_center_aisle => 'ممر مركزي';
  @override String get admin_seat_aisle_desc => 'مساحة فارغة في الوسط';
  @override String get admin_seat_cats_per_row => 'الفئات لكل صف';
  @override String get admin_seat_generating => 'جارٍ الإنشاء…';
  @override
  String admin_seat_generate_btn(int count) => 'إنشاء $count مقاعد';
  @override String get admin_seat_preview => 'معاينة الخريطة الحالية';
  @override String get admin_seat_no_seats => 'لم يتم إنشاء مقاعد';
  @override String get admin_seat_cat_standard => 'عادي';
  @override String get admin_seat_cat_vip => 'VIP';
  @override String get admin_seat_cat_gold => 'ذهبي';
  @override String get admin_seat_cat_family => 'عائلي';
  @override String get admin_seat_legend_reserved => 'محجوز';
  @override String get admin_seat_legend_sold => 'مباع';
  @override String get seat_map_stage => 'المسرح';

  // ============================================================================
  // ERRORS (الأخطاء)
  // ============================================================================
  @override String get error_generic => 'حدث خطأ';
  @override String get error_validation => 'بيانات غير صالحة';
  @override String get error_file_too_large => 'الملف كبير جداً';
  @override String get error_unsupported_format => 'تنسيق غير مدعوم';
  @override String get error_permission_denied => 'تم رفض الإذن';
  @override String get error_camera_unavailable => 'الكاميرا غير متاحة';
  @override String get error_microphone_unavailable => 'الميكروفون غير متاح';
  @override String get error_location_unavailable => 'الموقع غير متاح';
  @override String get error_network => 'خطأ في الشبكة';
  @override String get error_timeout => 'انتهت المهلة';
  @override String get error_server => 'خطأ في الخادم';
  @override String get error_not_found => 'غير موجود';

  // ============================================================================
  // TIME (الوقت)
  // ============================================================================
  @override String get common_just_now => 'الآن';
  @override String get common_in_the_future => 'لاحقاً';
  @override
  String common_minutes_ago(int count) => count == 1 ? 'قبل دقيقة واحدة' : 'قبل $count دقائق';
  @override
  String common_hours_ago(int count) => count == 1 ? 'قبل ساعة واحدة' : 'قبل $count ساعات';
  @override
  String common_days_ago(int count) => count == 1 ? 'قبل يوم واحد' : 'قبل $count أيام';
  @override
  String common_seconds_ago(int count) => count == 1 ? 'قبل ثانية واحدة' : 'قبل $count ثوانٍ';
  @override
  String common_weeks_ago(int count) => count == 1 ? 'قبل أسبوع واحد' : 'قبل $count أسابيع';
  @override
  String common_months_ago(int count) => count == 1 ? 'قبل شهر واحد' : 'قبل $count أشهر';
  @override
  String common_years_ago(int count) => count == 1 ? 'قبل سنة واحدة' : 'قبل $count سنوات';
  @override
  String common_in_minutes(int count) => count == 1 ? 'خلال دقيقة واحدة' : 'خلال $count دقائق';
  @override
  String common_in_hours(int count) => count == 1 ? 'خلال ساعة واحدة' : 'خلال $count ساعات';
  @override
  String common_in_days(int count) => count == 1 ? 'خلال يوم واحد' : 'خلال $count أيام';

  // ============================================================================
  // LIVE & IA (البث المباشر والذكاء الاصطناعي)
  // ============================================================================
  @override String get live_leave_btn => 'مغادرة البث المباشر';
  @override String get live_chat_empty => 'كن أول من يعلق!';
  @override String get live_chat_hint => 'أرسل رسالة…';
  @override String get live_like => 'إعجاب';
  @override String get live_leaving => 'لقد غادرت البث المباشر';
  @override String get live_viewers => 'مشاهدون';
  @override String get live_likes => 'إعجابات';
  @override String get live_go_live => 'بدء البث';
  @override String get live_title => 'عنوان البث';
  @override String get live_start => 'بدء';
  @override String get live_end => 'إنهاء';
  @override String get live_duration => 'المدة';
  @override String get live_peak_viewers => 'ذروة المشاهدين';
  @override String get live_chat_disabled => 'الدردشة معطلة.';
  @override String get live_share => 'مشاركة';
  @override String get live_report => 'إبلاغ';
  @override String get live_follow_host => 'متابعة';
  @override String get live_gift_send => 'إرسال هدية';
  @override String get live_quality_auto => 'تلقائي';
  @override String get live_quality_hd => 'HD';
  @override String get live_quality_sd => 'SD';
  @override String get live_quality_low => 'منخفضة';

  @override String get insight_type_market => 'سوق';
  @override String get insight_type_finance => 'مالية';
  @override String get insight_type_strategy => 'استراتيجية';
  @override String get insight_type_business => 'أعمال';
  @override String get insight_type_insight => 'رؤية';
  @override String get insight_confidence_label => 'مستوى الثقة';
  @override String get insight_source_verified => 'مصدر موثوق';
  @override String get insight_source_unverified => 'مصدر غير موثوق';
  @override String get insight_recommended_actions => 'الإجراءات الموصى بها';
  @override String get insight_key_findings => 'النتائج الرئيسية';
  @override String get insight_summary => 'الملخص';
  @override String get insight_full_analysis => 'التحليل الكامل';
  @override String get insight_generated_by => 'تم إنشاؤه بواسطة الذكاء الاصطناعي';
  @override String get insight_disclaimer => 'هذا تحليل تم إنشاؤه بواسطة الذكاء الاصطناعي. يرجى التحقق من المعلومات.';

  @override String get risk_critical => 'حرج';
  @override String get risk_high => 'مرتفع';
  @override String get risk_medium => 'متوسط';
  @override String get risk_low => 'منخفض';
  @override String get risk_level_label => 'مستوى الخطر';
  @override String get risk_mitigation => 'التخفيف من المخاطر';
  @override String get risk_impact => 'الأثر';
  @override String get risk_probability => 'الاحتمالية';
  @override String get risk_assessment => 'تقييم المخاطر';
}
