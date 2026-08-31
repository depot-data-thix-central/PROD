// lib/presentation/home/dashboard_ui.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:share_plus/share_plus.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/presentation/common/notifications_sheet.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const double _kTopBarHeight = 220.0;
const double _kProfileCardTopMargin = 88.0;
const int _kMaxDisplayNameLength = 60;
const int _kMaxBioLength = 200;
const int _kMaxThixIdLength = 50;

// ============================================================================
// VALIDATORS
// ============================================================================
class _UiValidators {
  _UiValidators._();

  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static bool isPendingThixId(String? id) {
    if (id == null) return true;
    final v = id.trim().toUpperCase();
    return v.isEmpty ||
        v == 'THIX-PENDING' ||
        v == 'THIX-000000' ||
        v.startsWith('THIX-PENDING-');
  }

  static bool isVerifiedUser(dynamic user) {
    final status = (user.registrationStatus ?? '').toString().toLowerCase();
    final thixId = (user.thixId ?? '').toString();
    return status == 'paid' ||
        status == 'verified' ||
        status == 'active' ||
        !_UiValidators.isPendingThixId(thixId);
  }

  static String buildPublicProfileUrl(String thixId) {
    if (thixId.trim().isEmpty) return '';
    final encoded = Uri.encodeComponent(thixId.trim());
    return '${AppRoutes.publicProfile}?thixId=$encoded';
  }

  static String buildShareUrl(String thixId) {
    if (thixId.trim().isEmpty) return '';
    final encoded = Uri.encodeComponent(thixId.trim());
    return 'https://thix.app/public-profile?thixId=$encoded';
  }
}

// ============================================================================
// BACKGROUND
// ============================================================================
class DashboardBackground extends StatelessWidget {
  const DashboardBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(color: ThixPolicy.surfaceSoft);
  }
}

// ============================================================================
// TOP BAR
// ============================================================================
class DashboardTopBar extends StatelessWidget {
  final dynamic user;
  final int score;
  final VoidCallback onBack;
  final VoidCallback onOpenSettings;
  final VoidCallback onEditProfile;
  final VoidCallback onDownloadCv;
  final VoidCallback onShareProfile;
  final Future<void> Function() onLogout;

  const DashboardTopBar({
    super.key,
    required this.user,
    required this.score,
    required this.onBack,
    required this.onOpenSettings,
    required this.onLogout,
    required this.onEditProfile,
    required this.onDownloadCv,
    required this.onShareProfile,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final verified = _UiValidators.isVerifiedUser(user);
    final photoUrl = _UiValidators.sanitize(
      (user.photoUrl ?? '').toString(),
      maxLength: 300,
    );
    final displayName = _UiValidators.sanitize(
      (user.displayName ?? l10n.t('dashboard_user_default')).toString(),
      maxLength: _kMaxDisplayNameLength,
    );
    final thixId = _UiValidators.sanitize(
      (user.thixId ?? '').toString(),
      maxLength: _kMaxThixIdLength,
    );
    final bio = _UiValidators.sanitize(
      (user.bio ?? '').toString(),
      maxLength: _kMaxBioLength,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1. En-tête gradient
        Container(
          height: _kTopBarHeight,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [ThixPolicy.primary, ThixPolicy.primaryDeep],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
          ),
        ),

        // 2. Boutons navigation
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                _TopIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  semanticsLabel: l10n.t('common_back'),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onBack();
                  },
                ),
                const Spacer(),
                Semantics(
                  header: true,
                  child: Text(
                    l10n.t('dashboard_title'),
                    style: ThixPolicy.labelStyle.copyWith(
                      color: Colors.white,
                      fontWeight: ThixPolicy.bold,
                      letterSpacing: 0.5,
                      fontSize: 14,
                    ),
                  ),
                ),
                const Spacer(),
                _TopIconButton(
                  icon: Icons.notifications_rounded,
                  semanticsLabel: l10n.t('dashboard_notifications'),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    NotificationsSheet.show(context);
                  },
                ),
                const SizedBox(width: 6),
                _TopIconButton(
                  icon: Icons.settings_rounded,
                  semanticsLabel: l10n.t('dashboard_settings'),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onOpenSettings();
                  },
                ),
                const SizedBox(width: 6),
                _TopIconButton(
                  icon: Icons.logout_rounded,
                  semanticsLabel: l10n.t('common_logout'),
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    await onLogout();
                  },
                ),
              ],
            ),
          ),
        ),

        // 3. Carte profil
        Container(
          margin: const EdgeInsets.only(
            top: _kProfileCardTopMargin,
            left: 14,
            right: 14,
            bottom: 12,
          ),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(18),
            boxShadow: ThixPolicy.shadowSoft(opacity: 0.08),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileAvatar(photoUrl: photoUrl, verified: verified),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName.isEmpty ? '—' : displayName,
                          style: ThixPolicy.labelStyle.copyWith(
                            fontWeight: ThixPolicy.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'THIX ID: ${thixId.isEmpty ? '—' : thixId}',
                                style: ThixPolicy.captionStyle.copyWith(
                                  fontSize: 11,
                                  color: ThixPolicy.textMuted,
                                  fontWeight: ThixPolicy.semiBold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _VerificationBadge(verified: verified),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          bio.isEmpty
                              ? l10n.t('dashboard_bio_empty')
                              : bio,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: ThixPolicy.captionStyle.copyWith(
                            color: ThixPolicy.textMain,
                            fontSize: 11.5,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: ThixPolicy.border.withOpacity(0.6)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _HeaderActionButton(
                      icon: Icons.edit_rounded,
                      label: l10n.t('common_edit'),
                      onTap: onEditProfile,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _HeaderActionButton(
                      icon: Icons.download_rounded,
                      label: l10n.t('dashboard_cv_doc'),
                      onTap: onDownloadCv,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _HeaderActionButton(
                      icon: Icons.ios_share_rounded,
                      label: l10n.t('common_share'),
                      onTap: onShareProfile,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String photoUrl;
  final bool verified;

  const _ProfileAvatar({required this.photoUrl, required this.verified});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(2.5),
          decoration: const BoxDecoration(
            color: ThixPolicy.primary,
            shape: BoxShape.circle,
          ),
          child: CircleAvatar(
            radius: 32,
            backgroundColor: ThixPolicy.surfaceSoft,
            backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
            child: photoUrl.isEmpty
                ? const Icon(Icons.person, size: 32, color: ThixPolicy.textMuted)
                : null,
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: verified ? ThixPolicy.success : ThixPolicy.warning,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            alignment: Alignment.center,
            child: Icon(
              verified ? Icons.check_rounded : Icons.hourglass_bottom_rounded,
              color: Colors.white,
              size: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _VerificationBadge extends StatelessWidget {
  final bool verified;

  const _VerificationBadge({required this.verified});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: ThixPolicy.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? Icons.verified_rounded : Icons.pending_rounded,
            size: 11,
            color: ThixPolicy.primary,
          ),
          const SizedBox(width: 3),
          Text(
            verified ? l10n.t('status_verified') : l10n.t('status_pending'),
            style: ThixPolicy.captionStyle.copyWith(
              color: ThixPolicy.primary,
              fontWeight: ThixPolicy.bold,
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final String semanticsLabel;
  final VoidCallback onTap;

  const _TopIconButton({
    required this.icon,
    required this.semanticsLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: Icon(icon, color: Colors.white, size: 16),
          onPressed: onTap,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HeaderActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: OutlinedButton.icon(
        onPressed: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        icon: Icon(icon, size: 14, color: ThixPolicy.primaryDeep),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: ThixPolicy.captionStyle.copyWith(
            color: ThixPolicy.primaryDeep,
            fontWeight: ThixPolicy.bold,
            fontSize: 10.5,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          side: BorderSide(color: ThixPolicy.primary.withOpacity(0.2)),
          backgroundColor: ThixPolicy.primary.withOpacity(0.04),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

// ============================================================================
// TABS HEADER
// ============================================================================
class DashboardTabsHeader extends StatelessWidget {
  const DashboardTabsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ThixPolicy.border.withOpacity(0.6)),
      ),
      child: TabBar(
        isScrollable: true,
        labelColor: Colors.white,
        unselectedLabelColor: ThixPolicy.textMuted,
        indicator: BoxDecoration(
          color: ThixPolicy.primary,
          borderRadius: BorderRadius.circular(24),
        ),
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        indicatorSize: TabBarIndicatorSize.tab,
        tabAlignment: TabAlignment.start,
        padding: const EdgeInsets.all(3),
        tabs: [
          Tab(text: l10n.t('tab_profile'), height: 36),
          Tab(text: l10n.t('tab_documents'), height: 36),
          Tab(text: l10n.t('tab_experiences'), height: 36),
          Tab(text: l10n.t('tab_formations'), height: 36),
          Tab(text: l10n.t('tab_cv'), height: 36),
          Tab(text: l10n.t('tab_payments'), height: 36),
          Tab(text: l10n.t('tab_security'), height: 36),
        ],
      ),
    );
  }
}

// ============================================================================
// CHAT FAB
// ============================================================================
class ChatFab extends StatelessWidget {
  final VoidCallback? onTap;

  const ChatFab({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Semantics(
      button: true,
      label: l10n.t('dashboard_chat'),
      child: GestureDetector(
        onTap: () {
          if (onTap == null) {
            debugPrint('[DashboardUI] ⚠️ ChatFab tapped but no handler provided');
            return;
          }
          HapticFeedback.mediumImpact();
          onTap!();
        },
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ThixPolicy.card,
            boxShadow: ThixPolicy.shadowSoft(opacity: 0.12),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.forum_rounded, size: 24, color: ThixPolicy.primary),
        ),
      ),
    );
  }
}

// ============================================================================
// SECTION HEADER
// ============================================================================
class SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String actionLabel;
  final bool showAction;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.actionLabel = 'Action',
    this.showAction = false,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: ThixPolicy.titleStyle.copyWith(
                    fontWeight: ThixPolicy.bold,
                    fontSize: 15,
                    color: ThixPolicy.primaryDeep,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: ThixPolicy.captionStyle.copyWith(
                    fontSize: 11,
                    color: ThixPolicy.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (showAction && onAction != null)
            Semantics(
              button: true,
              label: actionLabel,
              child: TextButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onAction!();
                },
                child: Text(
                  actionLabel,
                  style: ThixPolicy.captionStyle.copyWith(
                    color: ThixPolicy.primary,
                    fontWeight: ThixPolicy.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// STATS
// ============================================================================
class DashboardProfileStat extends StatelessWidget {
  final String label;
  final String value;

  const DashboardProfileStat({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: ThixPolicy.titleStyle.copyWith(
              fontWeight: ThixPolicy.bold,
              fontSize: 16,
              color: ThixPolicy.primaryDeep,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: ThixPolicy.captionStyle.copyWith(
              fontSize: 10.5,
              color: ThixPolicy.textMuted,
              fontWeight: ThixPolicy.semiBold,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// DASHBOARD CARD
// ============================================================================
class DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const DashboardCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: ThixPolicy.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: ThixPolicy.primary, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: ThixPolicy.labelStyle.copyWith(
                        fontWeight: ThixPolicy.bold,
                        fontSize: 13.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: ThixPolicy.captionStyle.copyWith(
                        color: ThixPolicy.textMuted,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: ThixPolicy.border.withOpacity(0.6)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ============================================================================
// STATUS CHIP
// ============================================================================
class StatusChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color textColor;

  const StatusChip({
    super.key,
    required this.label,
    required this.bg,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w800,
          fontSize: 9.5,
        ),
      ),
    );
  }
}

// ============================================================================
// DOC ROW
// ============================================================================
class DocRow extends StatelessWidget {
  final String name;
  final String date;
  final String status;
  final Color statusBg;
  final Color statusText;

  const DocRow({
    super.key,
    required this.name,
    required this.date,
    required this.status,
    required this.statusBg,
    required this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    final safeName = _UiValidators.sanitize(name, maxLength: 60);
    final safeDate = _UiValidators.sanitize(date, maxLength: 40);
    final safeStatus = _UiValidators.sanitize(status, maxLength: 20);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: ThixPolicy.surfaceSoft,
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.insert_drive_file_rounded,
              color: ThixPolicy.textMuted,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  safeName.isEmpty ? '—' : safeName,
                  style: ThixPolicy.captionStyle.copyWith(
                    fontWeight: ThixPolicy.semiBold,
                    fontSize: 12.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  safeDate.isEmpty ? '—' : safeDate,
                  style: ThixPolicy.captionStyle.copyWith(
                    color: ThixPolicy.textMuted,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          StatusChip(label: safeStatus.isEmpty ? '—' : safeStatus, bg: statusBg, textColor: statusText),
        ],
      ),
    );
  }
}

// ============================================================================
// NETWORK ITEM
// ============================================================================
class NetworkItem extends StatelessWidget {
  final String name;
  final String role;
  final String avatarDesc;

  const NetworkItem({
    super.key,
    required this.name,
    required this.role,
    required this.avatarDesc,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final safeName = _UiValidators.sanitize(name, maxLength: 60);
    final safeRole = _UiValidators.sanitize(role, maxLength: 60);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: ThixPolicy.surfaceSoft,
            child: const Icon(Icons.person, color: ThixPolicy.textMuted, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  safeName.isEmpty ? '—' : safeName,
                  style: ThixPolicy.captionStyle.copyWith(
                    fontWeight: ThixPolicy.semiBold,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  safeRole.isEmpty ? '—' : safeRole,
                  style: ThixPolicy.captionStyle.copyWith(
                    color: ThixPolicy.textMuted,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: ThixPolicy.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              l10n.t('status_connected'),
              style: ThixPolicy.captionStyle.copyWith(
                color: ThixPolicy.success,
                fontWeight: ThixPolicy.bold,
                fontSize: 9.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// INFO ROW
// ============================================================================
class DashboardInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const DashboardInfoRow({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final safeLabel = _UiValidators.sanitize(label, maxLength: 40);
    final safeValue = _UiValidators.sanitize(value, maxLength: 200);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              safeLabel,
              style: ThixPolicy.captionStyle.copyWith(
                color: ThixPolicy.textMuted,
                fontWeight: ThixPolicy.semiBold,
                fontSize: 11.5,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              safeValue.isEmpty ? '—' : safeValue,
              style: ThixPolicy.captionStyle.copyWith(
                fontWeight: ThixPolicy.semiBold,
                fontSize: 12.5,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TAB SCAFFOLD
// ============================================================================
class TabScaffold extends StatelessWidget {
  final List<Widget> children;

  const TabScaffold({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

// ============================================================================
// SHARE PROFILE SHEET
// ============================================================================
class ShareProfileSheet {
  static Future<void> show(BuildContext context, dynamic profile) async {
    final l10n = AppLocalizations.of(context);
    final thixId = _UiValidators.sanitize(
      (profile.thixId ?? '').toString(),
      maxLength: _kMaxThixIdLength,
    );

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(sheetCtx).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.t('dashboard_share_title'),
                  style: ThixPolicy.titleStyle.copyWith(
                    fontWeight: ThixPolicy.bold,
                    fontSize: 16,
                    color: ThixPolicy.primaryDeep,
                  ),
                ),
                Semantics(
                  button: true,
                  label: l10n.t('common_close'),
                  child: IconButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      sheetCtx.pop();
                    },
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Voir profil public
            Semantics(
              button: true,
              label: l10n.t('dashboard_view_public'),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ThixPolicy.surfaceSoft,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Icons.remove_red_eye_rounded,
                    color: ThixPolicy.primary,
                    size: 18,
                  ),
                ),
                title: Text(
                  l10n.t('dashboard_view_public'),
                  style: ThixPolicy.labelStyle.copyWith(
                    fontWeight: ThixPolicy.bold,
                    fontSize: 13.5,
                  ),
                ),
                subtitle: Text(
                  l10n.t('dashboard_view_public_sub'),
                  style: ThixPolicy.captionStyle.copyWith(fontSize: 11),
                ),
                onTap: () {
                  if (!sheetCtx.mounted) return;
                  HapticFeedback.selectionClick();
                  sheetCtx.pop();
                  final url = _UiValidators.buildPublicProfileUrl(thixId);
                  if (url.isNotEmpty && context.mounted) {
                    debugPrint('[DashboardUI] 🌐 Navigate public profile: $url');
                    context.push(url);
                  }
                },
              ),
            ),

            // Partager lien
            Semantics(
              button: true,
              label: l10n.t('dashboard_share_link'),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ThixPolicy.surfaceSoft,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Icons.ios_share_rounded,
                    color: ThixPolicy.primary,
                    size: 18,
                  ),
                ),
                title: Text(
                  l10n.t('dashboard_share_link'),
                  style: ThixPolicy.labelStyle.copyWith(
                    fontWeight: ThixPolicy.bold,
                    fontSize: 13.5,
                  ),
                ),
                subtitle: Text(
                  l10n.t('dashboard_share_link_sub'),
                  style: ThixPolicy.captionStyle.copyWith(fontSize: 11),
                ),
                onTap: () async {
                  if (!sheetCtx.mounted) return;
                  HapticFeedback.mediumImpact();
                  sheetCtx.pop();

                  final shareUrl = _UiValidators.buildShareUrl(thixId);
                  final text = shareUrl.isEmpty
                      ? '${l10n.t('dashboard_share_text_prefix')}: $thixId'
                      : '${l10n.t('dashboard_share_text_prefix')}: $thixId\n$shareUrl';

                  try {
                    await Share.share(text);
                    debugPrint('[DashboardUI] ✓ Profile shared');
                  } catch (e) {
                    debugPrint('[DashboardUI] ❌ Share failed: $e');
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
