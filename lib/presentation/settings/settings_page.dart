import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/l10n/locale_controller.dart';
import 'package:thix_id/l10n/i18n_service.dart';
import 'package:thix_id/presentation/common/notifications_sheet.dart';
import '../../theme.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/models/app_user.dart';

class SettingsGroup extends StatelessWidget {
  final String title;
  final Widget child;

  const SettingsGroup({
    super.key,
    required this.title,
    required this.child,
  });

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

  const SettingsItem({
    super.key,
    required this.icon,
    required this.label,
    this.sublabel = "",
    this.hasSublabel = false,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
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
            child: Icon(icon, color: context.theme.colorScheme.primary, size: 22),
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
    );
  }
}

class LangChip extends StatelessWidget {
  final String flag;
  final String name;
  final bool selected;

  const LangChip({
    super.key,
    required this.flag,
    required this.name,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: selected ? context.theme.colorScheme.primary : context.theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: selected ? Colors.transparent : context.theme.dividerColor,
        ),
      ),
      child: Row(
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
    );
  }
}

class _LocaleChip extends StatelessWidget {
  final String flag;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const _LocaleChip({required this.flag, required this.name, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? context.theme.colorScheme.primary : context.theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: selected ? Colors.transparent : context.theme.dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(flag, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: AppSpacing.xs),
            Text(
              name,
              style: context.textStyles.labelLarge?.copyWith(color: selected ? Colors.white : context.theme.colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

String _flagForLanguageCode(String languageCode) {
  switch (languageCode) {
    case 'fr':
      return '🇫🇷';
    case 'en':
      return '🇬🇧';
    case 'sw':
      return '🇰🇪';
    case 'ln':
      return '🇨🇩';
    case 'ar':
      return '🇸🇦';
    default:
      return '🌐';
  }
}

String _nameForLanguageCode(String code) {
  switch (code) {
    case 'fr': return 'Français';
    case 'en': return 'English';
    case 'es': return 'Español';
    case 'pt': return 'Português';
    case 'sw': return 'Kiswahili';
    case 'ln': return 'Lingála';
    case 'kg': return 'Kikongo';
    case 'lu': return 'Tshiluba';
    case 'ar': return 'العربية';
    default: return code.toUpperCase();
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localeCtrl = context.watch<LocaleController>();
    final selected = localeCtrl.locale;
    return Scaffold(
      backgroundColor: context.theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_rounded, color: context.theme.colorScheme.onSurface, size: 24),
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
                      context.i18n.t('settings_title'),
                      style: context.textStyles.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.theme.colorScheme.onSurface,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.help_outline_rounded, color: context.theme.colorScheme.primary, size: 24),
                      onPressed: () => NotificationsSheet.show(context),
                    ),
                  ],
                ),
              ),
              SettingsGroup(
                title: context.i18n.t('settings_language_group'),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.i18n.t('settings_choose_ui_language'),
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
                              name: context.i18n.t('system_default'),
                              selected: selected == null,
                              onTap: () => localeCtrl.setSystem(),
                            ),
                            const SizedBox(width: 10),
                            ...LocaleController.supportedLocales.expand((l) {
                              return [
                                _LocaleChip(
                                  flag: _flagForLanguageCode(l.languageCode),
                                  name: _nameForLanguageCode(l.languageCode),
                                  selected: selected?.languageCode == l.languageCode,
                                  onTap: () => localeCtrl.setLocale(l),
                                ),
                                const SizedBox(width: 10),
                              ];
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SettingsGroup(
                title: context.i18n.t('settings_appearance_group'),
                child: Column(
                  children: [
                    SettingsItem(
                      icon: Icons.dark_mode_rounded,
                      label: context.i18n.t('settings_dark_mode'),
                      sublabel: context.i18n.t('settings_dark_mode_sub'),
                      hasSublabel: true,
                      trailing: Switch(
                        value: true,
                        onChanged: (val) {},
                        activeColor: LightModeColors.accent,
                      ),
                    ),
                    Divider(color: context.theme.dividerColor, indent: 56, height: 1),
                    SettingsItem(
                      icon: Icons.contrast_rounded,
                      label: context.i18n.t('settings_high_contrast'),
                      sublabel: context.i18n.t('settings_high_contrast_sub'),
                      hasSublabel: true,
                      trailing: Switch(
                        value: false,
                        onChanged: (val) {},
                        activeColor: LightModeColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
              SettingsGroup(
                title: context.i18n.t('settings_security_group'),
                child: Column(
                  children: [
                    SettingsItem(
                      icon: Icons.fingerprint_rounded,
                      label: context.i18n.t('settings_biometrics'),
                      sublabel: context.i18n.t('settings_biometrics_sub'),
                      hasSublabel: true,
                      trailing: Switch(
                        value: true,
                        onChanged: (val) {},
                        activeColor: LightModeColors.accent,
                      ),
                    ),
                    Divider(color: context.theme.dividerColor, indent: 56, height: 1),
                    SettingsItem(
                      icon: Icons.face_rounded,
                      label: context.i18n.t('settings_face_id'),
                      sublabel: context.i18n.t('settings_face_id_sub'),
                      hasSublabel: true,
                      trailing: Switch(
                        value: false,
                        onChanged: (val) {},
                        activeColor: LightModeColors.accent,
                      ),
                    ),
                    Divider(color: context.theme.dividerColor, indent: 56, height: 1),
                    SettingsItem(
                      icon: Icons.vpn_key_rounded,
                      label: context.i18n.t('settings_change_password'),
                      trailing: const Icon(Icons.chevron_right_rounded, color: LightModeColors.hint),
                    ),
                    Divider(color: context.theme.dividerColor, indent: 56, height: 1),
                    SettingsItem(
                      icon: Icons.security_rounded,
                      label: context.i18n.t('settings_2fa'),
                      sublabel: context.i18n.t('settings_2fa_sub'),
                      hasSublabel: true,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: LightModeColors.success,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          context.i18n.t('settings_active'),
                          style: context.textStyles.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SettingsGroup(
                title: context.i18n.t('settings_account_group'),
                child: Column(
                  children: [
                    SettingsItem(
                      icon: Icons.shield_rounded,
                      label: context.i18n.t('settings_data_privacy'),
                      trailing: const Icon(Icons.open_in_new_rounded, color: LightModeColors.hint, size: 18),
                    ),
                    Divider(color: context.theme.dividerColor, indent: 56, height: 1),
                    SettingsItem(
                      icon: Icons.history_rounded,
                      label: context.i18n.t('settings_activity_log'),
                      trailing: const Icon(Icons.chevron_right_rounded, color: LightModeColors.hint),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await context.read<AuthController>().signOut();
                    if (!context.mounted) return;
                    context.go(AppRoutes.login);
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(context.i18n.t('settings_sign_out')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: LightModeColors.error,
                    side: const BorderSide(color: LightModeColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "THIX ID v2.4.0-PRO",
                    style: context.textStyles.labelSmall?.copyWith(color: LightModeColors.hint),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    context.i18n.t('settings_tagline'),
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
