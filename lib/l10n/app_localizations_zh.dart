// lib/l10n/app_localizations_zh.dart
import 'dart:ui';
import 'app_localizations.dart';
  @override Locale get locale => const Locale('zh');

class AppLocalizationsZh extends AppLocalizations {
  // ============================================================================
  // COMMON & UI (COMMUN & UI)
  // ============================================================================
  @override String get common_back => '返回';
  @override String get common_close => '关闭';
  @override String get common_cancel => '取消';
  @override String get common_confirm => '确认';
  @override String get common_delete => '删除';
  @override String get common_add => '添加';
  @override String get common_edit => '编辑';
  @override String get common_save => '保存';
  @override String get common_manage => '管理';
  @override String get common_retry => '重试';
  @override String get common_refresh => '刷新';
  @override String get common_search => '搜索';
  @override String get common_open => '打开';
  @override String get common_share => '分享';
  @override String get common_copy => '复制';
  @override String get common_copied => '已复制！';
  @override String get common_download => '下载';
  @override String get common_upload => '上传';
  @override String get common_send => '发送';
  @override String get common_receive => '接收';
  @override String get common_accept => '接受';
  @override String get common_reject => '拒绝';
  @override String get common_skip => '跳过';
  @override String get common_next => '下一步';
  @override String get common_previous => '上一步';
  @override String get common_finish => '完成';
  @override String get common_done => '完成';
  @override String get common_error => '错误';
  @override String get common_success => '成功';
  @override String get common_loading => '加载中…';
  @override String get common_please_wait => '请稍候…';
  @override String get common_today => '今天';
  @override String get common_yesterday => '昨天';
  @override String get common_tomorrow => '明天';
  @override String get common_home => '首页';
  @override String get common_chat => '聊天';
  @override String get common_map => '地图';
  @override String get common_profile => '我的';
  @override String get common_menu => '菜单';
  @override String get common_notifications => '通知';
  @override String get common_settings => '设置';
  @override String get common_help => '帮助';
  @override String get common_about => '关于';
  @override String get common_logout => '登出';
  @override String get common_login => '登录';
  @override String get common_signup => '注册';
  @override String get common_yes => '是';
  @override String get common_no => '否';
  @override String get common_or => '或';
  @override String get common_and => '和';
  @override String get common_none => '无';
  @override String get common_all => '全部';
  @override String get common_unknown => '未知';
  @override String get common_enabled => '已启用';
  @override String get common_disabled => '已禁用';
  @override String get common_clear => '清除';
  @override String get common_remove => '移除';
  
  @override String common_items(int count) => count == 0 ? '无项目' : (count == 1 ? '1 个项目' : '$count 个项目');
  @override String common_contacts(int count) => count == 0 ? '无联系人' : (count == 1 ? '1 个联系人' : '$count 个联系人');
  @override String common_messages(int count) => count == 0 ? '无消息' : (count == 1 ? '1 条消息' : '$count 条消息');
  @override String common_days(int count) => count == 0 ? '0 天' : (count == 1 ? '1 天' : '$count 天');
  @override String common_hours(int count) => count == 0 ? '0 小时' : (count == 1 ? '1 小时' : '$count 小时');
  @override String common_minutes(int count) => count == 0 ? '0 分钟' : (count == 1 ? '1 分钟' : '$count 分钟');

  // ============================================================================
  // AUTH & ONBOARDING (BASIC)
  // ============================================================================
  @override String get auth_login => '登录';
  @override String get auth_signup => '注册';
  @override String get auth_forgot_password => '忘记密码？';
  @override String get auth_reset_password => '重置密码';
  @override String get auth_email => '电子邮件';
  @override String get auth_phone => '手机号码';
  @override String get auth_password => '密码';
  @override String get auth_confirm_password => '确认密码';
  @override String get auth_logout_confirm => '您确定要登出吗？';
  @override String get auth_welcome_back => '欢迎回来';
  @override String get auth_welcome => '欢迎';
  @override String get auth_no_account => '还没有账号？';
  @override String get auth_has_account => '已有账号？';
  @override String get auth_invalid_email => '无效的电子邮件';
  @override String get auth_invalid_phone => '无效的手机号码';
  @override String get auth_password_too_short => '密码太短（最少 8 个字符）';
  @override String get auth_passwords_mismatch => '两次输入的密码不一致';
  @override String get auth_login_success => '登录成功';
  @override String get auth_signup_success => '账号创建成功';
  @override String get auth_session_expired => '会话已过期，请重新登录';
  @override String get auth_2fa_title => '两步验证';
  @override String get auth_2fa_code => '验证码';
  @override String get auth_verify_email => '验证电子邮件';
  @override String get auth_verify_phone => '验证手机号码';
  @override String get auth_biometric => '生物识别登录';
  @override String get auth_biometric_prompt => '请进行身份验证以继续';
  @override String get auth_full_name => '全名';
  @override String get auth_first_name => '名字';
  @override String get auth_last_name => '姓氏';
  @override String get auth_birth_date => '出生日期';
  @override String get auth_gender => '性别';
  @override String get auth_gender_male => '男';
  @override String get auth_gender_female => '女';
  @override String get auth_gender_other => '其他';
  @override String get auth_accept_terms => '我同意使用条款';
  @override String get auth_terms_required => '您必须同意使用条款';
  @override String get auth_email_already_used => '该电子邮件已被使用';
  @override String get auth_phone_already_used => '该手机号码已被使用';
  @override String get auth_create_account => '创建账号';
  @override String get auth_already_have_account => '我已有账号';

  @override String get onboarding_welcome => '欢迎使用 THIX';
  @override String get onboarding_step_1_title => '连接';
  @override String get onboarding_step_1_desc => '创建您的安全 THIX 身份';
  @override String get onboarding_step_2_title => '保护';
  @override String get onboarding_step_2_desc => '启用 24/7 全天候保护';
  @override String get onboarding_step_3_title => '行动';
  @override String get onboarding_step_3_desc => '在 2 秒内发出紧急警报';
  @override String get onboarding_get_started => '开始使用';
  @override String get onboarding_skip => '跳过介绍';

  // ============================================================================
  // AUTHENTIFICATION & CONNEXION (ADVANCED / ERRORS)
  // ============================================================================
  @override String get login_title => '登录 THIX';
  @override String get login_subtitle => '欢迎回来';
  @override String get login_identifier_label => '登录名';
  @override String get login_identifier_hint => '电子邮件、手机或 THIX ID';
  @override String get login_password_label => '密码';
  @override String get login_password_hint => '您的安全密码';
  @override String get login_remember_me => '记住我';
  @override String get login_forgot_password => '忘记密码？';
  @override String get login_button => '登录';
  @override String get login_verifying => '验证中…';
  @override String get login_retry_in => '重试，还剩';
  @override String get login_seconds_suffix => '秒';
  @override String get login_biometric => '或使用以下方式继续';
  @override String get login_face_id => 'Face ID';
  @override String get login_touch_id => 'Touch ID';
  
  @override String get login_error_suspended => '此账号已被封禁。请联系客服。';
  @override String get login_error_not_active => '此账号未激活。';
  @override String get login_error_no_account => '未找到与此信息匹配的账号。';
  @override String get login_error_mfa_required => '需要两步验证。';

  @override String get auth_error_identifier_required => '登录名必填';
  @override String get auth_error_password_required => '密码必填';
  @override String get auth_error_thix_id_login_not_available => '暂不支持通过 THIX ID 登录';
  @override String get auth_error_sign_in_failed => '登录失败，请检查您的凭据。';
  @override String get auth_error_email_not_verified => '登录前请先验证您的电子邮件地址';
  @override String get auth_error_server_misconfiguration => '服务器配置错误';
  @override String get auth_error_account_already_exists => '该标识符已被注册';
  @override String get auth_error_account_exists_wrong_password => '该账号存在，但密码不正确';
  @override String get auth_error_account_exists_new_otp_sent => '新的验证码 (OTP) 已发送至您的地址';
  @override String get auth_error_invalid_otp => '验证码无效或已过期';
  @override String get auth_error_otp_expired => '验证码已过期';
  @override String get auth_error_network => '网络连接错误，请检查您的网络。';
  @override String get auth_error_rate_limit => '尝试次数过多，请稍后再试。';
  @override String get auth_error_technical => '发生技术错误，请重试。';
  @override String get auth_error_user_mismatch => '检测到用户不匹配';
  @override String get auth_error_profile_update_failed => '更新个人资料失败';
  @override String get auth_error_mark_email_verified_failed => '验证电子邮件失败';
  @override String get auth_error_qr_token_generation_failed => '生成二维码令牌失败';
  @override String get auth_error_finalize_registration_failed => '完成注册失败';
  @override String get auth_error_consume_qr_token_failed => '使用二维码令牌失败';
  @override String get auth_error_resend_otp_failed => '重新发送验证码失败';
  @override String get auth_error_phone_auth_not_available => '暂不支持手机验证';
  @override String get auth_error_delete_account_not_available => '暂不支持删除账号';
  @override String get auth_error_update_email_failed => '更新电子邮件地址失败';
  @override String get auth_error_reset_password_failed => '重置密码失败';
  @override String get auth_error_sign_up_failed => '创建账号失败';
  @override String get auth_info_otp_sent => '验证码已发送';

  // ============================================================================
  // INSCRIPTION PERSONNELLE (PERSONAL REGISTRATION)
  // ============================================================================
  @override String get reg_step1_title => '您的个人资料';
  @override String get reg_step1_subtitle => '让我们从基本信息开始';
  @override String get reg_full_name_label => '全名';
  @override String get reg_full_name_hint => '名字和姓氏';
  @override String get reg_dob_label => '出生日期';
  @override String get reg_country_label => '居住国家/地区';
  @override String get reg_occupation_label => '职业 / 活动';
  @override String get reg_occupation_hint => '例如：开发者、学生、企业家';
  @override String get reg_next => '下一步';

  @override String get reg_step2_title => '保护您的账号';
  @override String get reg_step2_subtitle => '创建您的登录凭据';
  @override String get reg_email_label => '电子邮件地址';
  @override String get reg_email_hint => 'your.email@example.com';
  @override String get reg_phone_label => '手机号码';
  @override String get reg_phone_hint => '+86 138 XXXX XXXX';
  @override String get reg_password_label => '密码';
  @override String get reg_password_hint => '最少 8 个字符';
  @override String get reg_confirm_password_label => '确认密码';
  @override String get reg_confirm_password_hint => '再次输入您的密码';
  @override String get reg_strength_label => '密码强度';
  @override String get reg_strength_very_weak => '非常弱';
  @override String get reg_strength_weak => '弱';
  @override String get reg_strength_medium => '中等';
  @override String get reg_strength_strong => '强';
  @override String get reg_strength_excellent => '极强';

  @override String get reg_identity_title => 'THIX 身份';
  @override String get reg_thix_chat_label => 'THIX 聊天用户名';
  @override String get reg_thix_chat_hint => '例如：zhang.san (唯一)';
  
  @override String get reg_verification_title => '验证';
  @override String get reg_get_otp => '获取验证码';
  @override String get reg_code_sent_resend => '重新发送验证码';
  @override String get reg_resend_in => '重新发送，还剩';
  @override String get reg_seconds_short => '秒';
  @override String get reg_otp_label => '验证码 (OTP)';
  @override String get reg_validate_activate => '验证并激活';
  @override String get reg_activating => '激活中…';

  @override String get reg_congrats => '恭喜！';
  @override String get reg_welcome_message => '欢迎加入 THIX 生态系统，';
  @override String get reg_id_card_title => 'THIX 数字身份证';
  @override String get reg_official_thix_id => '官方 THIX ID';
  @override String get reg_generating => '生成中…';
  @override String get reg_copy_thix_id => '复制 THIX ID';
  @override String get reg_thix_id_copied => 'THIX ID 已复制到剪贴板';
  @override String get reg_go_to_dashboard => '前往控制台';
  @override String get reg_summary => '注册摘要';
  @override String get reg_mobile_label => '手机';
  @override String get reg_not_provided => '未提供';

  // ============================================================================
  // ACCUEIL & TABLEAU DE BORD (HOME & DASHBOARD)
  // ============================================================================
  @override String get home_search_hint => '搜索服务或联系人…';
  @override String get home_greeting => '你好';
  @override String get home_greeting_time => '晚上好';
  @override String get home_welcome_back => '欢迎回来';
  @override String get home_language_kiswahili => '斯瓦希里语';
  @override String get home_banner_default_tag => '青年项目';
  @override String get home_banner_default_title => '探索最新机会与活动';
  
  @override String get cert_pending => '认证待处理';
  @override String get cert_tier_ladder => '当前级别正在审核中';
  @override String get cert_view => '查看';

  @override String get quick_sona => 'THIX Sona';
  @override String get quick_doc => '我的文档';
  @override String get quick_chat => '聊天';
  @override String get quick_sos => '紧急情况';
  @override String get service_sante => 'THIX 健康';
  @override String get service_market => 'THIX 市场';
  @override String get service_money => 'THIX 钱包';
  @override String get service_reservation => '预订';
  @override String get service_mon_pays => '我的国家';
  @override String get service_emploi => '招聘';
  @override String get service_formations => '培训';
  @override String get service_opportunites => '机会';
  @override String get service_infos => '新闻';
  @override String get service_events => '活动';
  @override String get service_media => 'THIX 媒体';
  @override String get service_vault => '保险库';
  @override String get service_network => '网络';
  @override String get service_certification => '认证';

    @override String get live_go_live => '开始直播';
  @override String get live_title => '直播标题';
  @override String get live_start => '开始';
  @override String get live_end => '结束直播';
  @override String get live_duration => '时长';
  @override String get live_peak_viewers => '最高观看人数';
  @override String get live_chat_disabled => '聊天已禁用。';
  @override String get live_share => '分享';
  @override String get live_report => '举报';
  @override String get live_follow_host => '关注';
  @override String get live_gift_send => '送礼';
  @override String get live_quality_auto => '自动';
  @override String get live_quality_hd => '高清';
  @override String get live_quality_sd => '标清';
  @override String get live_quality_low => '流畅';

  @override String get insight_source_unverified => '未经验证的来源';
  @override String get insight_recommended_actions => '推荐操作';
  @override String get insight_key_findings => '主要发现';
  @override String get insight_summary => '摘要';
  @override String get insight_full_analysis => '完整分析';
  @override String get insight_generated_by => '人工智能生成';
  @override String get insight_disclaimer => '这是由人工智能生成的分析，请核实信息。';

  @override String get risk_level_label => '风险级别';
  @override String get risk_mitigation => '缓解措施';
  @override String get risk_impact => '影响';
  @override String get risk_probability => '概率';
  @override String get risk_assessment => '风险评估';


  // ============================================================================
  // CHAT & MESSAGERIE (CHAT & MESSAGING)
  // ============================================================================
  @override String get chatlist_network => '网络';
  @override String get chatlist_discussions => '聊天';
  @override String get chatlist_create_new => '创建新聊天';
  @override String get chatlist_calls => '通话';
  @override String get chatlist_settings => '设置';

  @override String get chat_unknown_user => '未知用户';
  @override String chat_members(int count) => count == 1 ? '1 名成员' : '$count 名成员';
  @override String get chat_video_call => '视频通话';
  @override String get chat_audio_call => '语音通话';
  @override String get chat_escalate => '升级处理';
  @override String get chat_history => '历史记录';
  @override String get chat_group_info => '群组信息';
  @override String get chat_file => '文件';
  @override String get chat_sticker => '贴纸';
  @override String get chat_ephemeral => '阅后即焚';
  @override String get chat_protected => '受保护';
  @override String get chat_internal_note => '内部备注';
  @override String get chat_send => '发送';
  @override String get chat_recording => '录音中';
  @override String get chat_stop_recording => '停止';
  @override String get chat_write_message => '输入消息...';
  @override String get chat_record_audio => '录制音频';
  @override String get chat_emojis => '表情符号';
  @override String get chat_reactions => '回应';
  @override String get chat_flags => '标记';
  @override String get chat_callback => '回拨';
  @override String get chat_typing => '正在输入...';
  @override String get chat_pause => '暂停';
  @override String get chat_play => '播放';

  @override String get conv_status_connected => '已连接';
  @override String get conv_status_pending => '待处理';
  @override String get conv_status_rejected => '已拒绝';
  @override String get conv_cannot_self => '您不能添加自己';
  @override String get conv_request_pending => '连接请求待处理中';
  @override String get conv_request_rejected => '连接请求已拒绝';
  @override String get conv_request_to => '发送请求给';
  @override String get conv_request_hint => '为您的连接请求添加可选消息。';
  @override String get conv_message_optional => '消息（可选）';
  @override String get conv_send_request => '发送请求';
  @override String get conv_request_sent => '请求已成功发送';
  @override String get conv_request_exists => '已向该用户发送过请求';
  @override String get conv_select_contact => '请至少选择一个联系人';
  @override String get conv_waiting_connection => '等待连接：';
  @override String get conv_group_rpc_required => '创建群组需要服务器请求';
  @override String get conv_page_title => '新聊天';
  @override String conv_start(int count) => '开始 ($count)';
  @override String get conv_search_label => '搜索用户';
  @override String get conv_search_hint => '姓名、THIX ID 或手机号...';
  @override String get conv_group_name_label => '群组名称';
  @override String get conv_group_name_hint => '例如：Alpha 项目团队';

  @override String get requests_page_title => '连接请求';
  @override String get requests_reject_title => '拒绝请求';
  @override String get requests_reject_message => '您确定要拒绝此连接请求吗？此操作无法撤销。';
  @override String get requests_reject_confirm => '拒绝';
  @override String get requests_rejected => '请求已拒绝';
  @override String get requests_reject_error => '拒绝请求时出错';
  @override String get requests_accepted => '请求已成功接受';
  @override String get requests_accept_error => '接受请求时出错';

  @override String get call_history_title => '通话记录';
  @override String get call_missed => '未接来电';
  @override String get call_incoming => '呼入电话';
  @override String get call_outgoing => '呼出电话';
  @override String get call_video => '视频通话';
  @override String get call_audio => '语音通话';

  // ============================================================================
  // RÉSEAU SOCIAL (NETWORK)
  // ============================================================================
  @override String get network_search_title => '搜索';
  @override String get network_search_hint => '搜索用户、帖子或社区…';
  @override String get network_tab_people => '用户';
  @override String get network_tab_posts => '帖子';
  @override String get network_tab_communities => '社区';
  @override String get network_explore_title => '探索 THIX 网络';
  @override String get network_explore_subtitle => '搜索用户、帖子或社区';
  @override String get network_no_results_users => '未找到用户';
  @override String get network_no_results_posts => '未找到帖子';
  @override String get network_no_results_communities => '未找到社区';
  @override String get network_request_sent => '已将请求发送给';
  @override String get network_request_error => '发送请求时出错';

  @override String get community_create_title => '创建社区';
  @override String get community_name_label => '社区名称';
  @override String get community_description_label => '描述';
  @override String get community_visibility_label => '可见性';
  @override String get community_public => '公开';
  @override String get community_private => '私密';
  @override String get community_join => '加入';
  @override String get community_leave => '退出';
  @override String get community_members => '名成员';
  @override String get community_admin => '管理员';

  // ============================================================================
  // PROFIL UTILISATEUR (PROFILE)
  // ============================================================================
  @override String get profile_settings => '个人资料设置';
  @override String get profile_edit_bio => '编辑简介';
  @override String get profile_no_bio => '暂无个人简介。';
  @override String get profile_followers => '粉丝';
  @override String get profile_following => '关注';
  @override String get profile_posts => '帖子';
  @override String get profile_follow => '关注';
  @override String get profile_unfollow => '已关注';
  @override String get profile_following_loading => '加载中…';
  @override String get profile_message => '发送消息';
  @override String get profile_block_user => '屏蔽此用户？';
  @override String get profile_block_message => '您将不再看到他们的帖子，他们也无法与您互动。';
  @override String get profile_block_confirm => '屏蔽';
  @override String get profile_blocked_success => '用户已屏蔽';
  @override String get profile_block_error => '屏蔽用户时出错';
  
  @override String get profile_report_user => '举报';
  @override String get profile_report_reason => '原因';
  @override String get profile_report_details => '详细信息（可选）';
  @override String get profile_report_spam => '垃圾信息';
  @override String get profile_report_inappropriate => '不当内容';
  @override String get profile_report_harassment => '骚扰';
  @override String get profile_report_impersonation => '冒充他人';
  @override String get profile_report_other => '其他';
  @override String get profile_report_submit => '提交举报';
  @override String get profile_report_success => '举报已提交';
  @override String get profile_report_duplicate => '已举报过此内容';
  
  @override String get profile_private_gallery => '私密相册';
  @override String get profile_private_content_locked => '此内容为私密内容';
  @override String get profile_add_private_media => '添加到我的私密相册';
  @override String get profile_no_private_media => '暂无私密媒体文件';
  @override String get profile_upload_processing => '处理中…';
  
  @override String get profile_tab_bio => '简介';
  @override String get profile_tab_private_gallery => '私密相册';
  @override String get profile_tab_photos => '公开照片';
  @override String get profile_tab_videos => '视频';
  @override String get profile_tab_audios => '音频';
  @override String get profile_no_content => '暂无内容';
  @override String get profile_pinned_post => '置顶帖子';
  @override String get profile_view_post => '查看帖子';

  // ============================================================================
  // PARAMÈTRES GÉNÉRAUX & CHAT (SETTINGS)
  // ============================================================================
  @override String get settings_title => '聊天设置';
  @override String get settings_section_appearance => '外观';
  @override String get settings_theme => '主题';
  @override String get settings_theme_light => '浅色';
  @override String get settings_theme_dark => '深色';
  @override String get settings_theme_system => '系统默认';
  @override String get settings_wallpaper => '聊天背景';
  @override String get settings_wallpaper_default => '默认';
  @override String get settings_wallpaper_custom => '自定义';
  
  @override String get settings_section_privacy => '隐私';
  @override String get settings_last_seen => '最后上线时间';
  @override String get settings_visibility_everyone => '所有人';
  @override String get settings_visibility_contacts => '我的联系人';
  @override String get settings_visibility_nobody => '无人';
  @override String get settings_profile_photo => '头像';
  
  @override String get settings_section_notifications => '通知';
  @override String get settings_messages => '消息';
  @override String get settings_calls => '通话';
  
  @override String get settings_section_messages => '数据和存储';
  @override String get settings_ephemeral => '阅后即焚消息';
  @override String get settings_auto_download => '媒体自动下载';
  @override String get settings_download_wifi => '仅 Wi-Fi';
  @override String get settings_download_mobile => 'Wi-Fi 和 蜂窝网络';
  @override String get settings_download_never => '从不';
  
  @override String get settings_section_account => '账号';
  @override String get settings_view_profile => '查看我的个人资料';
  @override String get settings_logout => '登出';

  @override String get settings_profile_edit => '编辑个人资料';
  @override String get settings_notifications => '通知设置';
  @override String get settings_privacy => '隐私设置';
  @override String get settings_security => '安全';
  @override String get settings_language => '语言';
  @override String get settings_help_center => '帮助中心';
  @override String get settings_about => '关于 THIX';
  @override String get settings_version => '版本';

  // ============================================================================
  // TRADUCTIONS DE LANGUAGE SHEET
  // ============================================================================
  @override String get settings_choose_language => '选择语言';
  @override String get settings_system_default => '系统默认';
  @override String get settings_language_change_failed => '切换语言失败';

  // ============================================================================
  // SOS & URGENCE (EMERGENCY)
  // ============================================================================
  @override String get sos_button => '紧急情况';
  @override String get sos_button_label => 'SOS 紧急按钮';
  @override String get sos_button_hint => '长按 2 秒以激活';
  @override String get sos_button_tooltip => '按住 2 秒钟';
  @override String get sos_trigger_button => '触发 SOS';
  @override String get sos_trigger_timeout => '请求超时，请重试。';
  @override String get sos_trigger_error => '触发 SOS 失败';
  @override String get sos_active => 'SOS 已激活';
  @override String get sos_crisis_room => '危机指挥室';
  @override String get sos_command_center => '指挥中心';
  @override String get sos_incident => '事件';
  @override String get sos_incident_unknown => '未知事件';
  @override String get sos_incident_not_found => '未找到事件';
  @override String get sos_circle => '圈子';
  @override String get sos_rescuers => '救援人员';
  @override String get sos_rescuer => '救援人员';
  @override String get sos_my_rescuers => '我的救援人员';
  @override String get sos_duration => '持续时间';
  @override String get sos_identifier => '标识符';
  @override String get sos_calling => '呼叫中…';
  @override String get sos_call => '呼叫';
  @override String get sos_available => '有空';
  @override String get sos_unavailable => '忙碌';
  @override String get sos_verified => '已验证';
  @override String get sos_end => '结束';
  @override String get sos_end_sos => '结束 SOS';
  @override String get sos_cancel_sos => '取消 SOS';
  @override String get sos_pin_required => '需要安全 PIN 码';
  @override String get sos_cancelled => 'SOS 已取消';
  @override String get sos_resolved => 'SOS 已解决';
  @override String get sos_cancel_failed => '取消失败';
  @override String get sos_in_progress => '进行中';
  @override String get sos_history => '历史记录';
  @override String get sos_my_incidents => '我的事件';
  @override String get sos_no_incidents => '暂无事件';
  @override String get sos_incidents_appear_here => '您的 SOS 请求将显示在此处';
  @override String get sos_history_error => '加载历史记录失败';
  @override String get sos_circle_1 => '圈子 1 – 最优先';
  @override String get sos_circle_2 => '圈子 2 – 次优先';
  @override String get sos_circle_3 => '圈子 3 – 紧急中心';
  @override String get sos_no_rescuers => '无救援人员';
  @override String get sos_add_first_rescuer => '添加您的首个紧急联系人';
  @override String get sos_add_rescuer => '添加救援人员';
  @override String get sos_add_rescuer_info => '输入救援人员的 THIX ID。系统将自动获取姓名和照片。';
  @override String get sos_thix_id_label => 'THIX ID';
  @override String get sos_thix_id_hint => 'THIX-XXXX';

  // ============================================================================
  // CERTIFICATION
  // ============================================================================
  @override String get certification_title => 'THIX 认证';
  @override String get certification_apply => '申请认证';
  @override String get certification_status => '状态';
  @override String get certification_pending => '待处理';
  @override String get certification_approved => '已批准';
  @override String get certification_rejected => '已拒绝';
  @override String get certification_tier_bronze => '青铜';
  @override String get certification_tier_silver => '白银';
  @override String get certification_tier_gold => '黄金';
  @override String get certification_tier_platinum => '铂金';
  @override String get certification_benefits => '专属权益';
  @override String get certification_documents => '所需文件';
  @override String get certification_upload_doc => '上传文件';
  @override String get certification_review_progress => '审核中';
  @override String get certification_verified_account => '已认证账号';

  // ============================================================================
  // ÉDUCATION & FORMATION (EDUCATION & TRAINING)
  // ============================================================================
  @override String get edu_nav_home => '首页';
  @override String get edu_nav_learning => '我的学习';
  @override String get edu_nav_library => '图书馆';
  @override String get edu_nav_certs => '证书';
  @override String get edu_nav_profile => '个人资料';
  
  @override String get edu_auth_required => '登录后查看您的课程';
  @override String get edu_login_required => '登录后查看您的课程';
  
  @override String get edu_learning_empty_title => '暂无进行中的课程';
  @override String get edu_learning_empty_desc => '报名参加课程即可开始。';
  @override String get edu_no_courses => '暂无进行中的课程';
  @override String get edu_enroll_hint => '报名参加课程即可开始。';
  @override String get edu_explore_btn => '探索课程';
  @override String get edu_completed => '已完成';
  
  @override String get edu_user_avatar => '用户头像';
  @override String get edu_greeting => '你好，';
  @override String get edu_greeting_subtitle => '准备好提升您的技能了吗？';
  @override String get edu_ready_to_learn => '准备好提升您的技能了吗？';
  @override String get edu_learner => '学员';
  @override String get edu_notifications => '通知';
  @override String get edu_search_hint => '搜索课程、认证…';
  @override String get edu_browse => '浏览';
  @override String get edu_library => '图书馆';
  @override String get edu_certs => '证书';
  @override String get edu_qa_browse => '浏览';
  @override String get edu_instructor => '讲师';
  
  @override String get edu_top_formations => '精选课程';
  @override String get edu_awaited_formations => '最受期待';
  @override String get edu_awaited => '最受期待';
  @override String get edu_see_all => '查看目录';
  
  @override String edu_coming_soon(String category) => '新的 $category 课程即将推出';
  @override String get edu_coming_soon_cat => '此处即将推出新课程';
  @override String get edu_locked_course => '即将推出！ (预计很快开放)';
  @override String get edu_coming_soon_badge => '即将开放';
  @override String get edu_awaited_badge => '即将推出';
  @override String get edu_awaited_locked => '已锁定';
  @override String get edu_awaited_locked_msg => '即将推出！ (预计很快开放)';
  
  @override String get edu_thix_academy => 'THIX 学院';
  @override String get edu_scheduled_soon => '预计时间：即将推出';
  @override String get edu_new_program => '新项目';
  @override String get edu_resume_learning => '继续学习';
  @override String get edu_resume => '继续学习';
  
  @override String get edu_catalog => '课程目录';
  @override String get edu_no_formations_cat => '此分类下暂无课程';
  
  @override String get edu_my_library => '我的图书馆';
  @override String get edu_search_book_hint => '按书名或作者搜索...';
  @override String get edu_library_title => '我的图书馆';
  @override String get edu_search_library => '按书名或作者搜索…';
  @override String get edu_shelves_empty => '您的书架空空如也。';
  @override String get edu_library_empty => '您的书架空空如也。';
  @override String get edu_no_result => '没有结果';
  @override String edu_search_no_results(String query) => '找不到关于 "$query" 的结果';
  
  @override String get edu_shelf => '书架';
  @override String get edu_books => '本书';
  @override String get edu_all => '全部';
  @override String edu_shelf_info(String code, int count) => '书架 $code · $count 本书';
  @override String get edu_free => '免费';
  @override String get edu_deleted_in => '即将下架，剩余';
  @override String edu_expires_in(String countdown) => '$countdown 后过期';
  
  @override String get edu_certifications => '我的证书';
  @override String get edu_certs_title => '认证';
  @override String get edu_no_certs => '暂无证书';
  @override String get edu_cert_expert => '专业技能证书';
  @override String get edu_cert_expertise => '专业技能证书';
  @override String edu_cert_issued(String date) => '颁发日期：$date';
  
  @override String get edu_pro_account => '专业账号';
  @override String get edu_profile_title => '专业账号';
  @override String get edu_instructor_space => '讲师控制台';
  @override String get edu_tools => '机构工具';
  @override String get edu_institutional_tools => '机构工具';
  @override String get edu_free_resources => '开放资源';
  @override String get edu_masterclass => '大师课';
  @override String get edu_masterclasses => '大师课';
  @override String get edu_network => '网络与指导';
  @override String get edu_mentorship => '社交与辅导';
  @override String get edu_events_agenda => '活动日程';
  @override String get edu_support => '技术支持';
  @override String get edu_not_connected => '未登录';

  @override String get training_title => '培训';
  @override String get training_enroll => '报名';
  @override String get training_my_courses => '我的课程';
  @override String get training_certificates => '我的证书';
  @override String get training_progress => '学习进度';
  @override String get training_lessons => '课时';
  @override String get training_duration => '时长';
  @override String get training_level => '级别';
  @override String get training_beginner => '初级';
  @override String get training_intermediate => '中级';
  @override String get training_advanced => '高级';
  @override String get training_start_course => '开始课程';
  @override String get training_continue_course => '继续课程';

  // ============================================================================
  // EMPLOIS & RECRUTEMENT (JOBS & RECRUITING)
  // ============================================================================
  @override String get jobs_title => '招聘';
  @override String get jobs_search => '搜索职位';
  @override String get jobs_apply => '申请';
  @override String get jobs_saved => '已保存';
  @override String get jobs_applied => '已申请';
  @override String get jobs_company => '公司';
  @override String get jobs_location => '地点';
  @override String get jobs_salary => '薪资';
  @override String get jobs_type => '类型';
  @override String get jobs_full_time => '全职';
  @override String get jobs_part_time => '兼职';
  @override String get jobs_contract => '合同工';
  @override String get jobs_internship => '实习';
  @override String get jobs_freelance => '自由职业';
  @override String get jobs_remote => '远程办公';
  @override String get jobs_onsite => '现场办公';
  @override String get jobs_hybrid => '混合办公';
  @override String get jobs_experience => '经验';
  @override String get jobs_no_experience => '接受应届生';
  @override String get jobs_junior => '初级';
  @override String get jobs_mid => '中级';
  @override String get jobs_senior => '资深';
  @override String get jobs_requirements => '要求';
  @override String get jobs_responsibilities => '岗位职责';
  @override String get jobs_benefits => '福利待遇';
  @override String get jobs_apply_now => '立即申请';
  @override String get jobs_application_sent => '申请已发送';
  @override String get jobs_no_results => '未找到相关职位';
  @override String get recruiter_title => '招聘方';
  @override String get recruiter_post_job => '发布职位';
  @override String get recruiter_candidates => '候选人';
  @override String get recruiter_applications => '申请记录';
  @override String get recruiter_interviews => '面试安排';

  // ============================================================================
  // OPPORTUNITÉS (OPPORTUNITIES)
  // ============================================================================
  @override String get opportunities_title => '机会';
  @override String get opportunities_business => '商业合作';
  @override String get opportunities_investment => '投资机会';
  @override String get opportunities_partnership => '合作伙伴';
  @override String get opportunities_grant => '资金补助';
  @override String get opportunities_coming_soon => '敬请期待';

  // ============================================================================
  // MARCHÉ & E-COMMERCE (MARKET)
  // ============================================================================
  @override String get market_title => 'THIX 市场';
  @override String get market_categories => '分类';
  @override String get market_products => '产品';
  @override String get market_services => '服务';
  @override String get market_add_to_cart => '加入购物车';
  @override String get market_buy_now => '立即购买';
  @override String get market_cart => '购物车';
  @override String get market_checkout => '结账';
  @override String get market_total => '总计';
  @override String get market_delivery => '配送方式';
  @override String get market_seller => '卖家';
  @override String get market_rating => '评分';
  @override String get market_reviews => '评价';
  @override String get market_in_stock => '有货';
  @override String get market_out_of_stock => '缺货';
  @override String get market_add_to_favorites => '加入收藏';
  @override String get market_remove_from_cart => '移出购物车';

  // ============================================================================
  // PORTEFEUILLE & ARGENT (WALLET & MONEY)
  // ============================================================================
  @override String get money_title => 'THIX 钱包';
  @override String get money_balance => '余额';
  @override String get money_send => '发送';
  @override String get money_receive => '接收';
  @override String get money_history => '历史记录';
  @override String get money_transactions => '交易记录';
  @override String get money_top_up => '充值';
  @override String get money_withdraw => '提现';
  @override String get money_transfer => '转账';
  @override String get money_bills => '账单';
  @override String get money_recipients => '收款人';
  @override String get money_add_recipient => '添加收款人';
  @override String get money_amount => '金额';
  @override String get money_fee => '手续费';
  @override String get money_reference => '交易附言';
  @override String get money_confirm_transfer => '确认转账';
  @override String get money_transfer_success => '转账成功';
  @override String get money_transfer_failed => '转账失败';
  @override String get money_insufficient_funds => '余额不足';

  // ============================================================================
  // ÉVÉNEMENTS & BILLETS (EVENTS & TICKETS)
  // ============================================================================
  @override String get events_title => '活动';
  @override String get events_upcoming => '即将举办';
  @override String get events_past => '往期活动';
  
  @override String get event_share_cta => '在 THIX 上预订您的名额！';
  @override String get event_sold_out_title => '门票已售罄';
  @override String get event_sold_out_msg => '目前所有名额均已订满。请加入候补名单，如有空位我们将通知您。';
  @override String get event_join_queue_confirm => '您希望加入候补名单吗？';
  @override String get event_join_queue_btn => '加入候补名单';
  
  @override String get event_unfavorite => '取消收藏';
  @override String get event_favorite => '加入收藏';
  @override String get event_free => '免费';
  @override String get event_paid => '付费';
  
  @override String get event_time_label => '时间';
  @override String get event_location_label => '地点';
  @override String get event_address_label => '详细地址';
  @override String get event_organized_by => '主办方';
  
  @override String get event_about_title => '关于活动';
  @override String get event_no_description => '此活动暂无相关描述。';
  @override String get event_tickets_title => '门票与预订';
  
  @override String get event_sold_out_short => '已售罄';
  @override String event_remaining_seats(String count) => '仅剩 $count 个名额';
  @override String get event_queue_btn => '候补名单';
  @override String get event_book_btn => '预订';
  
  @override String get event_standard_entry => '标准门票';
  @override String get event_all_sold => '所有席位已售出';
  @override String get event_limited_seats => '名额有限';
  @override String get event_book_now_btn => '立即预订';
  
  @override String event_numbered_seats(String count) => '$count 个编号座位';
  @override String get event_choose_seats_btn => '选择座位';
  @override String get event_from_price => '起价';

  @override String get events_my_tickets => '我的门票';
  @override String get events_buy_ticket => '购买门票';
  @override String get events_ticket_price => '票价';
  @override String get events_date => '日期';
  @override String get events_time => '时间';
  @override String get events_venue => '场馆';
  @override String get events_organizer => '组织者';
  @override String get events_attendees => '参与者';
  @override String get events_seats_available => '可选座位';
  @override String get events_sold_out => '售罄';
  @override String get events_book_now => '立即预订';
  @override String get events_ticket_type => '门票类型';
  @override String get ticket_standard => '标准票';
  @override String get ticket_vip => 'VIP 票';
  @override String get ticket_gold => '黄金票';
  @override String get ticket_family => '家庭票';
  @override String get ticket_secure_ticket => '安全门票';
  @override String get ticket_not_found => '找不到门票';
  @override String get ticket_location => '地点';
  @override String get ticket_pin_label => 'PIN 码';
  @override String get ticket_show_qr => '显示二维码';
  @override String get ticket_booking_id => '预订 ID';
  @override String get ticket_add_wallet => '添加到钱包';
  @override String get ticket_wallet_coming_soon => '电子钱包集成即将推出';
  @override String get ticket_share => '分享';
  @override String get ticket_share_text => '我的 THIX 门票';
  @override String get ticket_scan_info => '请在入口处出示此二维码';
  @override String get ticket_security_title => '安全验证';
  @override String get ticket_enter_pin => '输入您的 PIN 码';
  @override String get ticket_pin_hint => '4 位数字密码';
  @override String get ticket_pin_incorrect => 'PIN 码不正确';
  @override String get ticket_pin_too_many_attempts => '尝试次数过多';
  @override String get ticket_attempts_remaining => '剩余尝试次数';
  @override String get tickets_ticket => '门票';
  @override String get tickets_completed => '已完成';
  @override String get tickets_no_tickets => '暂无门票';
  @override String get tickets_no_tickets_desc => '您的预订将显示在此处';
  @override String get tickets_discover => '发现活动';
  @override String get tickets_load_error => '加载门票失败';
  @override String tickets_quantity(int count) => count == 0 ? '无门票' : '$count 张门票';

  // ============================================================================
  // RÉSERVATIONS (RESERVATIONS)
  // ============================================================================
  @override String get reservation_title => '预订';
  @override String get reservation_hotel => '酒店';
  @override String get reservation_restaurant => '餐厅';
  @override String get reservation_transport => '交通';
  @override String get reservation_check_in => '入住时间';
  @override String get reservation_check_out => '退房时间';
  @override String get reservation_guests => '房客';
  @override String get reservation_rooms => '房间';
  @override String get reservation_book => '预订';
  @override String get reservation_cancel => '取消';
  @override String get reservation_modify => '修改';
  @override String get reservation_confirm => '确认预订';
  @override String get reservation_my_bookings => '我的预订';

  // ============================================================================
  // SANTÉ (HEALTH)
  // ============================================================================
  @override String get health_title => 'THIX 健康';
  @override String get health_appointments => '预约挂号';
  @override String get health_doctors => '医生';
  @override String get health_hospitals => '医院';
  @override String get health_pharmacies => '药房';
  @override String get health_emergency => '急救';
  @override String get health_medical_records => '医疗记录';
  @override String get health_prescriptions => '处方记录';
  @override String get health_book_appointment => '预约医生';
  @override String get health_appointment_date => '预约日期';
  @override String get health_specialty => '科室专长';
  @override String get health_consultation => '在线问诊';
  @override String get health_telemedicine => '远程医疗';
  @override String get health_insurance => '健康保险';
  @override String get health_symptoms => '症状描述';
  @override String get health_find_doctor => '查找医生';

  // ============================================================================
  // MÉDIA & INFOS (MEDIA & INFO)
  // ============================================================================
  @override String get media_title => 'THIX 媒体';
  @override String get media_news => '新闻动态';
  @override String get media_videos => '视频';
  @override String get media_podcasts => '播客';
  @override String get media_articles => '文章';
  @override String get media_live => '直播';
  @override String get media_categories => '分类';
  @override String get media_bookmarks => '我的书签';
  @override String get media_share_article => '分享文章';
  @override String get media_read_more => '阅读全文';
  @override String get media_published_on => '发布于';
  @override String get media_author => '作者';
  @override String get info_title => '资讯';
  @override String get info_local => '本地新闻';
  @override String get info_national => '国内新闻';
  @override String get info_international => '国际新闻';
  @override String get info_sports => '体育';
  @override String get info_culture => '文化';
  @override String get info_economy => '财经';
  @override String get info_politics => '政治';
  @override String get info_technology => '科技';
  @override String get info_read_full => '阅读完整报道';

  // ============================================================================
  // MON PAYS (MY COUNTRY)
  // ============================================================================
  @override String get mon_pays_title => '我的国家';
  @override String get mon_pays_regions => '大区';
  @override String get mon_pays_cities => '城市';
  @override String get mon_pays_culture => '文化习俗';
  @override String get mon_pays_history => '历史渊源';
  @override String get mon_pays_tourism => '旅游观光';
  @override String get mon_pays_discover => '探索发现';
  @override String get mon_pays_landmarks => '地标建筑';
  @override String get mon_pays_traditions => '传统节日';

  // ============================================================================
  // COFFRE-FORT (VAULT)
  // ============================================================================
  @override String get vault_title => '保险库';
  @override String get vault_documents => '文档';
  @override String get vault_photos => '照片';
  @override String get vault_videos => '视频';
  @override String get vault_notes => '备忘录';
  @override String get vault_passwords => '密码本';
  @override String get vault_add_document => '添加文档';
  @override String get vault_upload => '上传文件';
  @override String get vault_encrypted => '端到端加密';
  @override String get vault_backup => '云端备份';
  @override String get vault_restore => '恢复数据';
  @override String get vault_share_secure => '安全分享';
  @override String get vault_unlock => '解锁保险库';
  @override String get vault_lock => '锁定保险库';

  // ============================================================================
  // PAIEMENT (PAYMENT)
  // ============================================================================
  @override String get payment_title => '支付中心';
  @override String get payment_method => '支付方式';
  @override String get payment_card => '银行卡 / 信用卡';
  @override String get payment_mobile_money => '移动支付 (Mobile Money)';
  @override String get payment_bank_transfer => '银行转账';
  @override String get payment_cash => '现金支付';
  @override String get payment_confirm => '确认支付';
  @override String get payment_success => '支付成功';
  @override String get payment_failed => '支付失败';
  @override String get payment_processing => '处理中…';
  @override String get payment_receipt => '电子收据';
  @override String get payment_invoice => '账单发票';

  // ============================================================================
  // RECHERCHE (MISSING PERSONS / SEARCH)
  // ============================================================================
  @override String get search_title => 'THIX 寻人';
  @override String get search_subtitle => '失踪人员及官方公告';
  @override String get search_person_missing => '失踪人员';
  @override String get search_person_wanted => '官方通缉令';
  @override String get search_report_missing => '报告失踪人员';
  @override String get search_report_found => '报告已找到人员';
  @override String get search_details => '详细信息';
  @override String get search_contact_authorities => '联系警方';
  @override String get search_share_alert => '分享警报';
  @override String get search_last_seen => '最后出现地点';
  @override String get search_description => '外貌特征描述';
  @override String get search_age => '年龄';
  @override String get search_height => '身高';
  @override String get search_weight => '体重';
  @override String get search_hair_color => '头发颜色';
  @override String get search_eye_color => '眼睛颜色';
  @override String get search_distinguishing_marks => '显著特征';
  @override String get search_clothing => '衣着描述';
  @override String get search_circumstances => '失踪情况';
  @override String get search_case_number => '案件编号';
  @override String get search_reported_by => '报案人';
  @override String get search_official_notice => '官方通告';
  @override String get search_community_alert => '社区预警';

  // ============================================================================
  // À PROXIMITÉ & ALERTES (NEARBY ALERTS)
  // ============================================================================
  @override String get nearby_alerts_title => '附近警报';
  @override String get nearby_view_on_map => '在地图上查看';
  @override String get nearby_map_coming_soon => '全屏地图即将推出';
  @override String get nearby_map_disabled => '地图已禁用（等待 API 密钥）';
  @override String get nearby_active_alerts => '当前活跃警报';
  @override String get nearby_missing => '失踪';
  @override String get nearby_official => '官方';
  @override String get nearby_legend_missing => '失踪人员';
  @override String get nearby_legend_official => '官方通告';
  @override String get nearby_legend_report => '举报/报告';
  @override String get nearby_location_required => '启用定位服务';
  @override String get nearby_location_subtitle => '查看您周围的紧急警报';

  // ============================================================================
  // ADMINISTRATION
  // ============================================================================
  @override String get admin_title => 'THIX 管理中心';
  @override String get admin_dev_open => '开放开发';
  @override String get admin_actions_section => '操作';
  
  @override String get admin_events_title => '活动管理';
  @override String get admin_events_create => '创建活动';
  @override String get admin_events_search_hint => '按标题搜索...';
  @override String get admin_events_filter => '分类筛选';
  @override String get admin_events_empty => '未找到任何活动';
  @override String get admin_events_no_permission => '您没有权限执行此操作';
  @override String get admin_events_delete_title => '确认删除？';
  @override String admin_events_delete_desc(String title) => '您确定要删除 $title 吗？此操作不可逆。';

  @override String get admin_limits_purchase_rules => '购票规则';
  @override String get admin_limits_max_person => '单人限购（全局）';
  @override String get admin_limits_max_transaction => '单笔订单限购（购物车）';
  @override String get admin_limits_require_thix_id => '需要 THIX ID 实名验证';
  @override String get admin_limits_require_thix_id_desc => '强烈建议高需求/热门活动开启此选项。';
  @override String get admin_limits_info_title => '安全防刷票架构';
  @override String get admin_limits_info_desc => '此限制由 SQL Edge Functions 在数据库底层实时校验，防止并发刷单（黄牛）及恶意竞争。';

  @override String get admin_stat_events => '总活动数';
  @override String get admin_stat_bookings => '总订单数';
  @override String get admin_stat_revenue => '总营业额';
  @override String get admin_stat_queue => '排队人数';
  @override String get admin_action_events => '活动列表';
  @override String get admin_action_events_sub => '20 条 / 页';
  @override String get admin_action_create => '发布';
  @override String get admin_action_create_sub => '上传 + 审核';
  @override String get admin_action_seats => '座位管理';
  @override String get admin_action_seats_sub => '批量处理 (200)';
  @override String get admin_action_reservations => '订单管理';
  @override String get admin_action_reservations_sub => '50 条 / 页 + 高级筛选';
  @override String get admin_action_limits => '风控中心';
  @override String get admin_action_limits_sub => '限购与安全';
  @override String get admin_action_analytics => '数据罗盘';
  @override String get admin_action_analytics_sub => 'RPC 分析';
  @override String get admin_read_only => '只读模式';
  @override String get admin_bookings_title => '订单列表 • 50/页';
  @override String get admin_bookings_export => '服务器正在导出数据... (后台任务)';
  @override String get admin_bookings_details => '门票详情';
  @override String get admin_bookings_event => '所属活动';
  @override String get admin_bookings_unknown_event => '未知活动';
  @override String get admin_bookings_id => '订单编号';
  @override String get admin_bookings_quantity => '购票数量';
  @override String get admin_bookings_category => '门票种类';
  @override String get admin_bookings_amount => '订单金额';
  @override String get admin_bookings_pin => '验票 PIN 码';
  @override String get admin_bookings_purchase_date => '下单时间';
  @override String get admin_bookings_close => '关闭';
  @override String get admin_bookings_empty => '未找到符合条件的订单';
  @override String get admin_bookings_unknown_date => '未知日期';
  @override String admin_bookings_places(int count) => '$count 个名额';
  @override String get admin_bookings_status_valid => '有效 (未验票)';
  @override String get admin_bookings_status_used => '已核销 (已使用)';
  @override String get admin_bookings_status_cancelled => '已取消';
  @override String get admin_bookings_status_postponed => '已延期';
  @override String get admin_bookings_status_pending => '待付款';
  @override String admin_queue_title(int count) => '排队等候区 • 实时同步 ($count 人)';
  @override String get admin_queue_realtime_desc => '系统实时同步中 • 新用户加入时列表会自动刷新';
  @override String get admin_queue_empty => '当前暂无排队用户';
  @override String get admin_queue_event_fallback => '未知活动';
  @override String admin_queue_item_meta(String userId, int qty, String status) => '用户标识: $userId • 需求量: $qty 张 • 状态: $status';
  @override String get admin_queue_notify => '发送放票通知';
  @override String get admin_queue_notified => '已通知该用户 (购票资格保留 10 分钟)';
  @override String get admin_queue_position => '当前排位';
  @override String get admin_queue_places => '需求票数';
  @override String get admin_analytics_title => '数据罗盘 • 核心指标';
  @override String get admin_analytics_fill_rate => '平均上座率';
  @override String get admin_analytics_avg_cart => '客单价 (每单金额)';
  @override String get admin_analytics_no_show => '爽约率 (未核销)';
  @override String get admin_analytics_rev_per_event => '单场平均营收';
  @override String get admin_analytics_revenue_7d => '近 7 天总流水';
  @override String get admin_analytics_no_data => '暂无统计数据';
  @override String get admin_analytics_error => '加载统计数据失败，请重试';
  @override String get admin_event_create => '发布新活动';
  @override String get admin_event_edit => '编辑活动信息';
  @override String get admin_event_btn_create => '确认发布';
  @override String get admin_event_btn_save => '保存修改';
  @override String get admin_event_cover => '活动封面图';
  @override String get admin_event_banner => '顶部宣传横幅';
  @override String get admin_event_title => '活动名称 *';
  @override String get admin_event_desc => '活动详情介绍 *';
  @override String get admin_event_category => '主分类';
  @override String get admin_event_subcategory => '子分类';
  @override String get admin_event_datetime => '举办时间';
  @override String get admin_event_start => '开始时间';
  @override String get admin_event_end => '结束时间 (选填)';
  @override String get admin_event_add_end => '添加结束时间';
  @override String get admin_event_city => '所在城市 *';
  @override String get admin_event_location => '场馆名称 *';
  @override String get admin_event_address => '详细地址';
  @override String get admin_event_organizer => '主办方名称';
  @override String get admin_event_phone => '客服电话';
  @override String get admin_event_email => '客服邮箱';
  @override String get admin_event_tiers_title => '票务及库存管理';
  @override String get admin_event_add_tier_btn => '添加票种 (如 早鸟票、VIP)';
  @override String get admin_event_status => '售票状态';
  @override String get admin_event_visibility => '展示设置';
  @override String get admin_event_cat_concert => '演唱会/音乐会';
  @override String get admin_event_cat_conference => '展览/会议';
  @override String get admin_event_cat_sport => '体育赛事';
  @override String get admin_event_cat_festival => '节庆/嘉年华';
  @override String get admin_event_cat_theatre => '话剧/舞台剧';
  @override String get admin_event_cat_other => '其他活动';
  @override String get admin_event_status_upcoming => '即将开售';
  @override String get admin_event_status_ongoing => '热卖中';
  @override String get admin_event_status_completed => '已结束';
  @override String get admin_event_status_cancelled => '已取消';
  @override String get admin_event_vis_default => '默认展示 (常规)';
  @override String get admin_event_vis_recommended => '编辑推荐';
  @override String get admin_event_vis_featured => '首页轮播推荐';
  @override String get admin_event_dialog_add_tier => '新增门票种类';
  @override String get admin_event_dialog_name => '票种名称 (例如: VIP 票)';
  @override String admin_event_dialog_price(String currency) => '单价 ($currency)';
  @override String get admin_event_dialog_capacity => '总库存 (张)';
  @override String get admin_event_dialog_cancel => '取消';
  @override String get admin_event_dialog_add => '确认添加';
  @override String get admin_event_err_readonly => '当前处于只读模式，无法修改';
  @override String get admin_event_err_min_tier => '请至少添加一种门票类型';
  @override String get admin_event_success => '活动信息已成功保存';
  @override String get admin_event_err_title_req => '活动名称为必填项';
  @override String get admin_event_err_desc_min => '活动介绍不能少于 10 个字符';
  @override String get admin_event_err_city_req => '所在城市为必填项';
  @override String get admin_event_err_loc_req => '场馆名称为必填项';
  @override String get admin_seat_page_title => '座位图可视化引擎';
  @override String get admin_seat_target_event => '关联活动';
  @override String get admin_seat_select_event => '请选择需要排座的活动';
  @override String admin_seat_max_limit(int count) => '该场馆最大容量限制: $count 座';
  @override String admin_seat_generated(int count) => '已成功生成 $count 个物理座位';
  @override String get admin_seat_load_error => '座位数据加载失败，请检查网络设置';
  @override String get admin_seat_pricing_title => '基于算法的动态定价';
  @override String get admin_seat_layout_title => '座位区矩阵配置';
  @override String get admin_seat_rows => '总排数';
  @override String get admin_seat_per_row => '每排座位数';
  @override String get admin_seat_center_aisle => '开启中央过道';
  @override String get admin_seat_aisle_desc => '在座位矩阵中间预留消防及通行空间';
  @override String get admin_seat_cats_per_row => '每排对应的门票等级配置';
  @override String get admin_seat_generating => '正在通过引擎生成座位矩阵…';
  @override String admin_seat_generate_btn(int count) => '确认生成 $count 个座位';
  @override String get admin_seat_preview => '实时座位布局预览';
  @override String get admin_seat_no_seats => '当前活动暂未生成物理座位图';
  @override String get admin_seat_cat_standard => '普通区 (Standard)';
  @override String get admin_seat_cat_vip => '贵宾区 (VIP)';
  @override String get admin_seat_cat_gold => '内场黄金区 (Gold)';
  @override String get admin_seat_cat_family => '家庭套票区 (Family)';
  @override String get admin_seat_legend_reserved => '已被锁定 (锁单中)';
  @override String get admin_seat_legend_sold => '已售出';
  @override String get seat_map_stage => '舞台区域 / 核心展示区';

  // ============================================================================
  // ERREURS & VALIDATION (ERRORS & VALIDATION)
  // ============================================================================
  @override String get error_generic => '发生了一个错误';
  @override String get error_validation => '无效的数据';
  @override String get error_file_too_large => '文件过大';
  @override String get error_unsupported_format => '不支持的格式';
  @override String get error_permission_denied => '权限被拒绝';
  @override String get error_camera_unavailable => '无法访问摄像头';
  @override String get error_microphone_unavailable => '无法访问麦克风';
  @override String get error_location_unavailable => '定位服务不可用';
  @override String get error_network => '网络连接错误';
  @override String get error_timeout => '请求超时';
  @override String get error_server => '服务器错误';
  @override String get error_not_found => '未找到';

  // ============================================================================
  // TEMPS & DATES RELATIVES (RELATIVE DATES & TIMES)
  // ============================================================================
  @override String get common_just_now => '刚刚';
  @override String get common_in_the_future => '稍后';
  @override String common_minutes_ago(int count) => count == 1 ? '1 分钟前' : '$count 分钟前';
  @override String common_hours_ago(int count) => count == 1 ? '1 小时前' : '$count 小时前';
  @override String common_days_ago(int count) => count == 1 ? '1 天前' : '$count 天前';
  @override String common_seconds_ago(int count) => count == 1 ? '1 秒前' : '$count 秒前';
  @override String common_weeks_ago(int count) => count == 1 ? '1 周前' : '$count 周前';
  @override String common_months_ago(int count) => count == 1 ? '1 个月前' : '$count 个月前';
  @override String common_years_ago(int count) => count == 1 ? '1 年前' : '$count 年前';
  @override String common_in_minutes(int count) => count == 1 ? '1 分钟后' : '$count 分钟后';
  @override String common_in_hours(int count) => count == 1 ? '1 小时后' : '$count 小时后';
  @override String common_in_days(int count) => count == 1 ? '1 天后' : '$count 天后';

  // ============================================================================
  // THIX MEDIA & IA SOURCES
  // ============================================================================
  @override String get live_send => '发送';
  @override String get live_ending => '结束直播...';
  @override String get live_network_quality => '网络质量';
  @override String get source_type_official => '官方';
  @override String get source_type_world_bank => '世界银行';
  @override String get source_type_government => '政府';
  @override String get source_type_default => '已验证来源';
  @override String get source_aria_label => '信息来源';
    // ============================================================================
  // THIX MEDIA & IA SOURCES
  // ============================================================================
  @override String get live_go_live => '开始直播';
  @override String get live_title => '直播标题';
  @override String get live_start => '开始';
  @override String get live_end => '结束直播';
  @override String get live_duration => '时长';
  @override String get live_peak_viewers => '最高观看人数';
  @override String get live_chat_disabled => '聊天已禁用。';
  @override String get live_share => '分享';
  @override String get live_report => '举报';
  @override String get live_follow_host => '关注';
  @override String get live_gift_send => '送礼';
  @override String get live_quality_auto => '自动';
  @override String get live_quality_hd => '高清';
  @override String get live_quality_sd => '标清';
  @override String get live_quality_low => '流畅';

  @override String get insight_source_unverified => '未经验证的来源';
  @override String get insight_recommended_actions => '推荐操作';
  @override String get insight_key_findings => '主要发现';
  @override String get insight_summary => '摘要';
  @override String get insight_full_analysis => '完整分析';
  @override String get insight_generated_by => '人工智能生成';
  @override String get insight_disclaimer => '这是由人工智能生成的分析，请核实信息。';

  @override String get risk_level_label => '风险级别';
  @override String get risk_mitigation => '缓解措施';
  @override String get risk_impact => '影响';
  @override String get risk_probability => '概率';
  @override String get risk_assessment => '风险评估';

  @override String get live_leave_btn => '离开直播';
  @override String get live_chat_empty => '暂无消息。';
  @override String get live_chat_hint => '说点什么...';
  @override String get live_like => '赞';
  @override String get live_send => '发送';
  @override String get live_viewers => '名观众';
  @override String get live_likes => '个赞';
  @override String get live_leaving => '正在离开...';
  @override String get live_network_quality => '网络质量';
  
  @override String get insight_type_market => '市场';
  @override String get insight_type_finance => '财务';
  @override String get insight_type_strategy => '战略';
  @override String get insight_type_business => '商业';
  @override String get insight_type_insight => '洞察';
  @override String get insight_confidence_label => '置信度';
  @override String get insight_source_verified => '已验证来源';
  
  @override String get risk_critical => '极高风险';
  @override String get risk_high => '高风险';
  @override String get risk_medium => '中风险';
  @override String get risk_low => '低风险';
  
  @override String get source_type_official => '官方';
  @override String get source_type_world_bank => '世界银行';
  @override String get source_type_government => '政府';
  @override String get source_type_default => '已验证来源';
  @override String get source_aria_label => '信息来源';

}
