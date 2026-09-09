// lib/presentation/settings/settings_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/l10n/locale_controller.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/presentation/common/notifications_sheet.dart';
import '../../theme.dart';
import 'admin_policy_manager_page.dart';
import 'policy_viewer_page.dart';

// ============================================================================
// WIDGETS DE BASE (conservés + Semantics)
// ============================================================================
class SettingsGroup extends StatelessWidget {
  final String title;
  final Widget child;
  const SettingsGroup({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 4),
            child: Text(
              title,
              style: context.textStyles.labelLarge?.copyWith(
                color: LightModeColors.secondaryText,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: context.theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: context.theme.dividerColor),
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ],
      ),
    );
  }
}

class SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final bool hasSublabel;
  final Widget trailing;
  final VoidCallback? onTap;
  final Color? iconColor;

  const SettingsItem({
    super.key,
    required this.icon,
    required this.label,
    this.sublabel = "",
    this.hasSublabel = false,
    required this.trailing,
    this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                alignment: Alignment.center,
                child: Icon(icon,
                    color: iconColor ?? context.theme.colorScheme.primary,
                    size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: context.textStyles.bodyLarge?.copyWith(
                        color: context.theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (hasSublabel) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        sublabel,
                        style: context.textStyles.bodySmall?.copyWith(
                          color: LightModeColors.secondaryText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _LocaleChip extends StatelessWidget {
  final String flag;
  final String name;
  final bool selected;
  final VoidCallback onTap;
  const _LocaleChip({
    required this.flag,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected
                ? context.theme.colorScheme.primary
                : context.theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
                color: selected ? Colors.transparent : context.theme.dividerColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(flag, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: AppSpacing.xs),
              Text(
                name,
                style: context.textStyles.labelLarge?.copyWith(
                  color: selected ? Colors.white : context.theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _flagForLanguageCode(String c) => switch (c) {
      'fr' => '🇫🇷',
      'en' => '🇬🇧',
      'sw' => '🇰🇪',
      'pt' => '🇵🇹',
      'zh' => '🇨🇳',
      'ar' => '🇸🇦',
      _ => '🌐',
    };

String _nameForLanguageCode(String c) => switch (c) {
      'fr' => 'Français',
      'en' => 'English',
      'sw' => 'Kiswahili',
      'pt' => 'Português',
      'zh' => '中文',
      'ar' => 'العربية',
      _ => c.toUpperCase(),
    };

// ============================================================================
// PAGE
// ============================================================================
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _sb = Supabase.instance.client;

  bool _isAdmin = false;
  bool _busy = false;

  // Préférences persistées (profiles.preferences)
  bool _darkMode = true;
  bool _highContrast = false;
  bool _notifPush = true;
  bool _notifEmail = true;
  bool _notifSos = true;
  bool _biometrics = true;
  bool _faceId = false;
  bool _twoFA = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ── Chargement profil + rôle admin + préférences ─────────────
  Future<void> _loadProfile() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final row = await _sb
          .from('profiles')
          .select('role, preferences')
          .eq('id', uid)
          .maybeSingle();
      if (!mounted) return;
      final role = row?['role'] as String?;
      final prefs = (row?['preferences'] as Map?)?.cast<String, dynamic>() ?? {};
      setState(() {
        _isAdmin = role == 'admin' || role == 'superadmin';
        _darkMode = prefs['darkMode'] ?? true;
        _highContrast = prefs['highContrast'] ?? false;
        _notifPush = prefs['notifPush'] ?? true;
        _notifEmail = prefs['notifEmail'] ?? true;
        _notifSos = prefs['notifSos'] ?? true;
        _biometrics = prefs['biometrics'] ?? true;
        _faceId = prefs['faceId'] ?? false;
        _twoFA = prefs['twoFA'] ?? false;
      });
    } catch (e) {
      debugPrint('[Settings] loadProfile: $e');
    }
  }

  Future<void> _savePrefs() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _sb.from('profiles').update({
        'preferences': {
          'darkMode': _darkMode,
          'highContrast': _highContrast,
          'notifPush': _notifPush,
          'notifEmail': _notifEmail,
          'notifSos': _notifSos,
          'biometrics': _biometrics,
          'faceId': _faceId,
          'twoFA': _twoFA,
        },
      }).eq('id', uid);
    } catch (e) {
      debugPrint('[Settings] savePrefs: $e');
    }
  }

  void _setPref(void Function() mutate) {
    setState(mutate);
    _savePrefs();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? LightModeColors.error : LightModeColors.success,
    ));
  }

  // ── Dialog mot de passe (+ mot-clé tapé optionnel) ───────────
  Future<String?> _askPassword({
    required String title,
    required String message,
    String? keyword,
  }) async {
    final l10n = AppLocalizations.of(context);
    final pwCtrl = TextEditingController();
    final kwCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: context.textStyles.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: pwCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.t('settings_password_current'),
                border: const OutlineInputBorder(),
              ),
            ),
            if (keyword != null) ...[
              const SizedBox(height: 12),
              Text(l10n.t('settings_delete_type_hint'),
                  style: context.textStyles.bodySmall),
              const SizedBox(height: 6),
              TextField(
                controller: kwCtrl,
                decoration: InputDecoration(
                  labelText: keyword,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.t('common_cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (keyword != null && kwCtrl.text.trim() != keyword) {
                Navigator.pop(ctx, false);
                _snack(l10n.t('settings_delete_keyword'), error: true);
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: Text(l10n.t('common_confirm')),
          ),
        ],
      ),
    );
    if (ok != true) return null;
    return pwCtrl.text;
  }

  // ── Changement mot de passe ──────────────────────────────────
  Future<void> _changePassword() async {
    final l10n = AppLocalizations.of(context);
    final current = await _askPassword(
      title: l10n.t('settings_change_password'),
      message: l10n.t('settings_password_current'),
    );
    if (current == null) return;

    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('settings_password_new')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: newCtrl,
              obscureText: true,
              decoration: InputDecoration(
                  labelText: l10n.t('settings_password_new'),
                  border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              decoration: InputDecoration(
                  labelText: l10n.t('settings_password_confirm'),
                  border: const OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.t('common_cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.t('common_confirm'))),
        ],
      ),
    );
    if (ok != true) return;
    if (newCtrl.text.length < 8 || newCtrl.text != confirmCtrl.text) {
      _snack(l10n.t('auth_passwords_mismatch'), error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final email = _sb.auth.currentUser?.email;
      if (email == null) throw Exception('no session');
      await _sb.auth.signInWithPassword(email: email, password: current);
      await _sb.auth.updateUser(UserAttributes(password: newCtrl.text));
      _snack(l10n.t('settings_password_changed'));
    } catch (e) {
      _snack(l10n.t('settings_reauth_failed'), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Désactivation (réversible) ───────────────────────────────
  Future<void> _deactivateAccount() async {
    final l10n = AppLocalizations.of(context);
    final pw = await _askPassword(
      title: l10n.t('settings_deactivate_title'),
      message: l10n.t('settings_deactivate_msg'),
    );
    if (pw == null) return;
    setState(() => _busy = true);
    try {
      await _sb.rpc('deactivate_my_account', params: {'password': pw});
      await _sb.auth.signOut();
      if (mounted) context.go(AppRoutes.login);
    } catch (e) {
      _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Suppression (irréversible) ───────────────────────────────
  Future<void> _deleteAccount() async {
    final l10n = AppLocalizations.of(context);
    final pw = await _askPassword(
      title: l10n.t('settings_delete_title'),
      message: l10n.t('settings_delete_msg'),
      keyword: l10n.t('settings_delete_keyword'),
    );
    if (pw == null) return;
    setState(() => _busy = true);
    try {
      await _sb.rpc('delete_my_account', params: {'password': pw});
      await _sb.auth.signOut();
      if (mounted) context.go(AppRoutes.login);
    } catch (e) {
      _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Export RGPD ──────────────────────────────────────────────
  Future<void> _exportData() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final data = await _sb.rpc('export_my_data');
      await Share.share(
        jsonEncode(data),
        subject: 'THIX ID — ${l10n.t('settings_data_export')}',
      );
      _snack(l10n.t('settings_data_export_done'));
    } catch (e) {
      _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOutAll() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await _sb.auth.signOut(scope: SignOutScope.global);
      _snack(l10n.t('settings_sign_out_all_done'));
      if (mounted) context.go(AppRoutes.login);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Switch helper ────────────────────────────────────────────
  Widget _switch(bool value, ValueChanged<bool> onChanged) => Switch(
        value: value,
        onChanged: (v) => _setPref(() => onChanged(v)),
        activeColor: LightModeColors.accent,
      );

  @override
  Widget build(BuildContext context) {
    final localeCtrl = context.watch<LocaleController>();
    final selected = localeCtrl.locale;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: context.theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: _busy
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header ──
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_back_rounded,
                                color: context.theme.colorScheme.onSurface,
                                size: 24),
                            onPressed: () {
                              final auth = context.read<AuthController>();
                              if (auth.isAuthenticated) {
                                final t = auth.currentUser?.accountType;
                                context.go(t == null
                                    ? AppRoutes.home
                                    : t == AccountType.enterprise
                                        ? AppRoutes.enterpriseDashboard
                                        : AppRoutes.userDashboard);
                                return;
                              }
                              context.go(AppRoutes.home);
                            },
                          ),
                          Text(
                            l10n.t('settings_title'),
                            style: context.textStyles.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: context.theme.colorScheme.onSurface,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.help_outline_rounded,
                                color: context.theme.colorScheme.primary,
                                size: 24),
                            onPressed: () => NotificationsSheet.show(context),
                          ),
                        ],
                      ),
                    ),

                    // ── COMPTE ──
                    SettingsGroup(
                      title: l10n.t('settings_account_group'),
                      child: Column(
                        children: [
                          SettingsItem(
                            icon: Icons.person_rounded,
                            label: l10n.t('settings_edit_profile'),
                            trailing: const Icon(Icons.chevron_right_rounded,
                                color: LightModeColors.hint),
                            onTap: () => context.push('/profile/edit'),
                          ),
                          Divider(color: context.theme.dividerColor, indent: 56, height: 1),
                          SettingsItem(
                            icon: Icons.devices_rounded,
                            label: l10n.t('settings_active_sessions'),
                            trailing: const Icon(Icons.chevron_right_rounded,
                                color: LightModeColors.hint),
                            onTap: _signOutAll,
                          ),
                          Divider(color: context.theme.dividerColor, indent: 56, height: 1),
                          SettingsItem(
                            icon: Icons.pause_circle_outline_rounded,
                            label: l10n.t('settings_deactivate'),
                            sublabel: l10n.t('settings_deactivate_sub'),
                            hasSublabel: true,
                            iconColor: Colors.orange,
                            trailing: const Icon(Icons.chevron_right_rounded,
                                color: LightModeColors.hint),
                            onTap: _deactivateAccount,
                          ),
                          Divider(color: context.theme.dividerColor, indent: 56, height: 1),
                          SettingsItem(
                            icon: Icons.delete_forever_rounded,
                            label: l10n.t('settings_delete_account'),
                            sublabel: l10n.t('settings_delete_sub'),
                            hasSublabel: true,
                            iconColor: LightModeColors.error,
                            trailing: const Icon(Icons.chevron_right_rounded,
                                color: LightModeColors.hint),
                            onTap: _deleteAccount,
                          ),
                        ],
                      ),
                    ),

                    // ── LANGUE ──
                    SettingsGroup(
                      title: l10n.t('settings_language_group'),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.t('settings_choose_ui_language'),
                              style: context.textStyles.bodySmall?.copyWith(
                                color: LightModeColors.secondaryText,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _LocaleChip(
                                    flag: '🌐',
                                    name: l10n.t('system_default'),
                                    selected: selected == null,
                                    onTap: () => localeCtrl.setSystem(),
                                  ),
                                  const SizedBox(width: 10),
                                  ...LocaleController.supportedLocales.expand((l) => [
                                        _LocaleChip(
                                          flag: _flagForLanguageCode(l.languageCode),
                                          name: _nameForLanguageCode(l.languageCode),
                                          selected: selected?.languageCode ==
                                              l.languageCode,
                                          onTap: () => localeCtrl.setLocale(l),
                                        ),
                                        const SizedBox(width: 10),
                                      ]),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── APPARENCE ──
                    SettingsGroup(
                      title: l10n.t('settings_appearance_group'),
                      child: Column(
                        children: [
                          SettingsItem(
                            icon: Icons.dark_mode_rounded,
                            label: l10n.t('settings_dark_mode'),
                            sublabel: l10n.t('settings_dark_mode_sub'),
                            hasSublabel: true,
                            trailing: _switch(_darkMode, (v) => _darkMode = v),
                          ),
                          Divider(color: context.theme.dividerColor, indent: 56, height: 1),
                          SettingsItem(
                            icon: Icons.contrast_rounded,
                            label: l10n.t('settings_high_contrast'),
                            sublabel: l10n.t('settings_high_contrast_sub'),
                            hasSublabel: true,
                            trailing: _switch(_highContrast, (v) => _highContrast = v),
                          ),
                        ],
                      ),
                    ),

                    // ── NOTIFICATIONS ──
                    SettingsGroup(
                      title: l10n.t('settings_notifications'),
                      child: Column(
                        children: [
                          SettingsItem(
                            icon: Icons.notifications_active_rounded,
                            label: l10n.t('settings_notif_push'),
                            trailing: _switch(_notifPush, (v) => _notifPush = v),
                          ),
                          Divider(color: context.theme.dividerColor, indent: 56, height: 1),
                          SettingsItem(
                            icon: Icons.mail_outline_rounded,
                            label: l10n.t('settings_notif_email'),
                            trailing: _switch(_notifEmail, (v) => _notifEmail = v),
                          ),
                          Divider(color: context.theme.dividerColor, indent: 56, height: 1),
                          SettingsItem(
                            icon: Icons.sos_rounded,
                            label: l10n.t('settings_notif_sos'),
                            iconColor: LightModeColors.error,
                            trailing: _switch(_notifSos, (v) => _notifSos = v),
                          ),
                        ],
                      ),
                    ),

                    // ── SÉCURITÉ ──
                    SettingsGroup(
                      title: l10n.t('settings_security_group'),
                      child: Column(
                        children: [
                          SettingsItem(
                            icon: Icons.vpn_key_rounded,
                            label: l10n.t('settings_change_password'),
                            trailing: const Icon(Icons.chevron_right_rounded,
                                color: LightModeColors.hint),
                            onTap: _changePassword,
                          ),
                          Divider(color: context.theme.dividerColor, indent: 56, height: 1),
                          SettingsItem(
                            icon: Icons.security_rounded,
                            label: l10n.t('settings_2fa'),
                            sublabel: l10n.t('settings_2fa_sub'),
                            hasSublabel: true,
                            trailing: _switch(_twoFA, (v) => _twoFA = v),
                          ),
                          Divider(color: context.theme.dividerColor, indent: 56, height: 1),
                          SettingsItem(
                            icon: Icons.fingerprint_rounded,
                            label: l10n.t('settings_biometrics'),
                            sublabel: l10n.t('settings_biometrics_sub'),
                            hasSublabel: true,
                            trailing: _switch(_biometrics, (v) => _biometrics = v),
                          ),
                          Divider(color: context.theme.dividerColor, indent: 56, height: 1),
                          SettingsItem(
                            icon: Icons.face_rounded,
                            label: l10n.t('settings_face_id'),
                            sublabel: l10n.t('settings_face_id_sub'),
                            hasSublabel: true,
                            trailing: _switch(_faceId, (v) => _faceId = v),
                          ),
                        ],
                      ),
                    ),

                    // ── CONFIDENTIALITÉ & POLITIQUES ──
                    SettingsGroup(
                      title: l10n.t('settings_privacy'),
                      child: Column(
                        children: [
                          SettingsItem(
                            icon: Icons.description_rounded,
                            label: l10n.t('settings_terms'),
                            trailing: const Icon(Icons.chevron_right_rounded,
                                color: LightModeColors.hint),
                            onTap: () => context.push('/settings/policy/terms'),
                          ),
                          Divider(color: context.theme.dividerColor, indent: 56, height: 1),
                          SettingsItem(
                            icon: Icons.privacy_tip_rounded,
                            label: l10n.t('settings_privacy_policy'),
                            trailing: const Icon(Icons.chevron_right_rounded,
                                color: LightModeColors.hint),
                            onTap: () => context.push('/settings/policy/privacy'),
                          ),
                          Divider(color: context.theme.dividerColor, indent: 56, height: 1),
                          SettingsItem(
                            icon: Icons.download_rounded,
                            label: l10n.t('settings_data_export'),
                            trailing: const Icon(Icons.chevron_right_rounded,
                                color: LightModeColors.hint),
                            onTap: _exportData,
                          ),
                          Divider(color: context.theme.dividerColor, indent: 56, height: 1),
                          SettingsItem(
                            icon: Icons.history_rounded,
                            label: l10n.t('settings_activity_log'),
                            trailing: const Icon(Icons.chevron_right_rounded,
                                color: LightModeColors.hint),
                            onTap: () => context.push('/settings/activity'),
                          ),
                        ],
                      ),
                    ),

                    // ── ZONE ADMIN (visible uniquement admin) ──
                    if (_isAdmin)
                      SettingsGroup(
                        title: l10n.t('settings_section_admin'),
                        child: Column(
                          children: [
                            SettingsItem(
                              icon: Icons.admin_panel_settings_rounded,
                              label: l10n.t('settings_admin_policies'),
                              sublabel: l10n.t('settings_admin_only'),
                              hasSublabel: true,
                              iconColor: LightModeColors.accent,
                              trailing: const Icon(Icons.chevron_right_rounded,
                                  color: LightModeColors.hint),
                              onTap: () => context.push('/settings/admin/policies'),
                            ),
                            Divider(color: context.theme.dividerColor, indent: 56, height: 1),
                            SettingsItem(
                              icon: Icons.dashboard_customize_rounded,
                              label: l10n.t('settings_admin_dashboard'),
                              iconColor: LightModeColors.accent,
                              trailing: const Icon(Icons.chevron_right_rounded,
                                  color: LightModeColors.hint),
                              onTap: () => context.push('/admin'),
                            ),
                          ],
                        ),
                      ),

                    // ── DÉCONNEXION ──
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await context.read<AuthController>().signOut();
                          if (!context.mounted) return;
                          context.go(AppRoutes.login);
                        },
                        icon: const Icon(Icons.logout_rounded),
                        label: Text(l10n.t('settings_sign_out')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: LightModeColors.error,
                          side: const BorderSide(color: LightModeColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),

                    // ── Footer ─
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "THIX ID v2.4.0-PRO",
                          style: context.textStyles.labelSmall
                              ?.copyWith(color: LightModeColors.hint),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          l10n.t('settings_tagline'),
                          style: context.textStyles.labelSmall?.copyWith(
                            color: LightModeColors.secondaryText,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

extension ThemeHelper on BuildContext {
  ThemeData get theme => Theme.of(this);
}
