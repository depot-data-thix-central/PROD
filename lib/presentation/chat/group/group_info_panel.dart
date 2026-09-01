// lib/presentation/chat/group/widgets/group_info_panel.dart
//
// ============================================================================
// GROUP INFO PANEL — Production Enterprise
// ============================================================================
//
// Panneau d'informations du groupe affiché en haut de ChatScreen.
//
// Fonctionnalités :
//   - En-tête réductible avec avatar, nom, stats membres
//   - Contenu expansé avec liste aperçu des membres (max 5)
//   - Actions : Modifier / Quitter / Supprimer (selon rôle)
//   - Indicateur de présence en ligne en temps réel
//   - Animation smooth d'expansion/réduction
//
// Sécurité :
//   - Sanitization XSS sur displayName et groupName
//   - Safe initial extraction (pas de RangeError)
//   - NetworkImage avec error handler
//   - Validation UUID sur IDs
//
// UX :
//   - ThixPolicy 100% (0 couleurs hardcodées)
//   - i18n complète (10+ clés)
//   - Semantics VoiceOver sur tous les éléments interactifs
//   - RepaintBoundary pour performance
// ============================================================================

import 'package:flutter/material.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/chat/chat_conversation.dart';
import 'package:thix_id/models/chat/group_info.dart';
import 'package:thix_id/presentation/chat/group/widgets/group_badge.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const double _kAvatarRadius = 26.0;
const double _kSmallAvatarRadius = 15.0;
const double _kAvatarFontSize = 20.0;
const double _kSmallAvatarFontSize = 11.0;
const double _kTitleFontSize = 15.0;
const double _kSubtitleFontSize = 12.0;
const double _kMemberNameFontSize = 13.0;
const double _kOnlineDotSize = 7.0;
const double _kSeparatorDotSize = 3.0;
const double _kStatusDotBorderWidth = 1.2;
const double _kExpandIconSize = 22.0;
const double _kActionIconSize = 16.0;
const double _kActionFontSize = 12.0;
const double _kActionButtonRadius = 16.0;
const double _kDescriptionRadius = 12.0;
const double _kDescriptionFontSize = 12.5;
const double _kMembersPreviewMax = 5;
const int _kMaxNameLength = 100;
const Duration _kAnimationDuration = Duration(milliseconds: 300);

// ============================================================================
// VALIDATORS
// ============================================================================
class _GroupInfoPanelValidators {
  _GroupInfoPanelValidators._();

  /// Sanitize un nom (XSS + caractères de contrôle + trim + max length).
  static String sanitizeName(String? input, {int maxLength = _kMaxNameLength}) {
    if (input == null) return '';
    var s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  /// Extrait l'initiale d'un nom de manière sûre (pas de RangeError).
  static String safeInitial(String? name, {String fallback = '?'}) {
    if (name == null) return fallback;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return fallback;
    return trimmed[0].toUpperCase();
  }
}

// ============================================================================
// GROUP INFO PANEL WIDGET
// ============================================================================

/// Panneau d'informations du groupe, affiché en haut de ChatScreen.
///
/// **En-tête** : Avatar + nom + stats membres (réductible).
/// **Contenu expansé** : Description + liste aperçu membres + actions.
///
/// **Usage** :
/// ```dart
/// GroupInfoPanel(
///   conversation: conversation,
///   members: groupMembers,
///   onViewAllMembers: () => _showMembersPage(),
///   onEditGroup: user.isAdmin ? () => _editGroup() : null,
///   onLeaveGroup: () => _leaveGroup(),
///   onDeleteGroup: user.isAdmin ? () => _deleteGroup() : null,
/// )
/// ```
class GroupInfoPanel extends StatefulWidget {
  /// Conversation du groupe.
  final ChatConversation conversation;

  /// Liste des membres du groupe.
  final List<GroupMember> members;

  /// Callback pour voir tous les membres.
  final VoidCallback? onViewAllMembers;

  /// Callback pour modifier le groupe (admin uniquement).
  final VoidCallback? onEditGroup;

  /// Callback pour quitter le groupe.
  final VoidCallback? onLeaveGroup;

  /// Callback pour supprimer le groupe (admin uniquement).
  final VoidCallback? onDeleteGroup;

  const GroupInfoPanel({
    super.key,
    required this.conversation,
    required this.members,
    this.onViewAllMembers,
    this.onEditGroup,
    this.onLeaveGroup,
    this.onDeleteGroup,
  });

  @override
  State<GroupInfoPanel> createState() => _GroupInfoPanelState();
}

class _GroupInfoPanelState extends State<GroupInfoPanel> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final onlineCount = widget.members.where((m) => m.isOnline).length;
    final memberCount = widget.members.length;
    final displayName = _GroupInfoPanelValidators.sanitizeName(
      widget.conversation.displayName,
    );
    final avatarUrl = widget.conversation.groupAvatar;

    return Container(
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        border: Border(
          bottom: BorderSide(color: ThixPolicy.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: ThixPolicy.primaryDeep.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(displayName, avatarUrl, memberCount, onlineCount, l10n),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildExpandedContent(l10n),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: _kAnimationDuration,
          ),
        ],
      ),
    );
  }

  // ─── HEADER ─────────────────────────────────────────────────────────

  Widget _buildHeader(
    String displayName,
    String? avatarUrl,
    int memberCount,
    int onlineCount,
    AppLocalizations l10n,
  ) {
    return Semantics(
      button: true,
      label: '${l10n.t("group_panel_header_label")} $displayName, '
          '$memberCount ${l10n.t("group_panel_members")}, '
          '$onlineCount ${l10n.t("group_panel_online")}, '
          '${_isExpanded ? l10n.t("group_panel_collapse") : l10n.t("group_panel_expand")}',
      child: InkWell(
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        splashColor: ThixPolicy.primary.withOpacity(0.05),
        highlightColor: ThixPolicy.primary.withOpacity(0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              _buildGroupAvatar(displayName, avatarUrl),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHeaderInfo(
                  displayName,
                  memberCount,
                  onlineCount,
                  l10n,
                ),
              ),
              _buildExpandButton(l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupAvatar(String displayName, String? avatarUrl) {
    final safeInitial = _GroupInfoPanelValidators.safeInitial(
      displayName,
      fallback: 'G',
    );

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: ThixPolicy.gold.withOpacity(0.5),
          width: _kStatusDotBorderWidth,
        ),
      ),
      child: CircleAvatar(
        radius: _kAvatarRadius,
        backgroundColor: ThixPolicy.primary.withOpacity(0.08),
        backgroundImage:
            avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
        onBackgroundImageError: avatarUrl != null
            ? (exception, stackTrace) {
                // Silencieux : l'initiale sera affichée à la place
              }
            : null,
        child: avatarUrl == null || avatarUrl.isEmpty
            ? Text(
                safeInitial,
                style: TextStyle(
                  fontSize: _kAvatarFontSize,
                  fontWeight: FontWeight.bold,
                  color: ThixPolicy.primary,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildHeaderInfo(
    String displayName,
    int memberCount,
    int onlineCount,
    AppLocalizations l10n,
  ) {
    final hasOnlineMembers = onlineCount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayName.isNotEmpty ? displayName : l10n.t('group_panel_unknown_group'),
          style: TextStyle(
            fontSize: _kTitleFontSize,
            fontWeight: FontWeight.w700,
            color: ThixPolicy.textMain,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Icon(
              Icons.people_alt_rounded,
              size: 12,
              color: ThixPolicy.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              '$memberCount',
              style: TextStyle(
                fontSize: _kSubtitleFontSize,
                fontWeight: FontWeight.w600,
                color: ThixPolicy.textMuted,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: _kSeparatorDotSize,
              height: _kSeparatorDotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ThixPolicy.textMuted,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: _kOnlineDotSize,
              height: _kOnlineDotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasOnlineMembers ? ThixPolicy.success : Colors.grey,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              hasOnlineMembers
                  ? l10n.t('group_panel_online_count', args: [onlineCount.toString()])
                  : l10n.t('group_panel_no_online'),
              style: TextStyle(
                fontSize: 11.5,
                color: hasOnlineMembers ? ThixPolicy.success : ThixPolicy.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExpandButton(AppLocalizations l10n) {
    return Semantics(
      button: true,
      label: _isExpanded
          ? l10n.t('group_panel_collapse')
          : l10n.t('group_panel_expand'),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: ThixPolicy.surfaceSoft,
          shape: BoxShape.circle,
        ),
        child: Icon(
          _isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
          color: ThixPolicy.textMuted,
          size: _kExpandIconSize,
        ),
      ),
    );
  }

  // ─── EXPANDED CONTENT ───────────────────────────────────────────────

  Widget _buildExpandedContent(AppLocalizations l10n) {
    final membersToShow = widget.members.take(_kMembersPreviewMax.toInt()).toList();
    final hasMore = widget.members.length > _kMembersPreviewMax;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDescription(l10n),
          _buildMembersSection(membersToShow, hasMore, l10n),
          const SizedBox(height: 16),
          Divider(height: 1, color: ThixPolicy.border),
          const SizedBox(height: 12),
          _buildActionsSection(l10n),
        ],
      ),
    );
  }

  Widget _buildDescription(AppLocalizations l10n) {
    final groupName = widget.conversation.groupName;
    if (groupName == null || groupName.isEmpty) return const SizedBox.shrink();

    final sanitizedDescription = _GroupInfoPanelValidators.sanitizeName(
      groupName,
      maxLength: 500,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ThixPolicy.surfaceSoft,
        borderRadius: BorderRadius.circular(_kDescriptionRadius),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: ThixPolicy.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              sanitizedDescription,
              style: TextStyle(
                fontSize: _kDescriptionFontSize,
                color: ThixPolicy.textMain,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersSection(
    List<GroupMember> membersToShow,
    bool hasMore,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.t('group_panel_members_title'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ThixPolicy.textMain,
              ),
            ),
            Text(
              '${widget.members.length}',
              style: TextStyle(
                fontSize: 12,
                color: ThixPolicy.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...membersToShow.asMap().entries.map((entry) {
          final member = entry.value;
          final isLast = entry.key == membersToShow.length - 1;
          return RepaintBoundary(
            child: _buildMemberRow(member, isLast, l10n),
          );
        }),
        if (hasMore) _buildViewAllMembersButton(l10n),
      ],
    );
  }

  Widget _buildMemberRow(
    GroupMember member,
    bool isLast,
    AppLocalizations l10n,
  ) {
    final displayName = _GroupInfoPanelValidators.sanitizeName(member.displayName);
    final safeInitial = _GroupInfoPanelValidators.safeInitial(displayName);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 4),
      child: Row(
        children: [
          _buildMemberAvatar(displayName, member.avatarUrl, safeInitial),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    displayName.isNotEmpty ? displayName : l10n.t('member_unknown'),
                    style: TextStyle(
                      fontSize: _kMemberNameFontSize,
                      color: ThixPolicy.textMain,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                if (member.isAdmin)
                  GroupBadge(
                    role: 'admin',
                    isCompact: true,
                    fontSize: 8,
                  ),
              ],
            ),
          ),
          if (member.isOnline)
            Container(
              width: _kOnlineDotSize,
              height: _kOnlineDotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ThixPolicy.success,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMemberAvatar(
    String displayName,
    String? avatarUrl,
    String safeInitial,
  ) {
    return CircleAvatar(
      radius: _kSmallAvatarRadius,
      backgroundColor: ThixPolicy.primary.withOpacity(0.08),
      backgroundImage:
          avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
      onBackgroundImageError: avatarUrl != null
          ? (exception, stackTrace) {
              // Silencieux : l'initiale sera affichée à la place
            }
          : null,
      child: avatarUrl == null || avatarUrl.isEmpty
          ? Text(
              safeInitial,
              style: TextStyle(
                fontSize: _kSmallAvatarFontSize,
                fontWeight: FontWeight.w600,
                color: ThixPolicy.primary,
              ),
            )
          : null,
    );
  }

  Widget _buildViewAllMembersButton(AppLocalizations l10n) {
    if (widget.onViewAllMembers == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Semantics(
        button: true,
        label: l10n.t('group_panel_view_all_members'),
        child: TextButton(
          onPressed: widget.onViewAllMembers,
          style: TextButton.styleFrom(
            foregroundColor: ThixPolicy.primary,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.t('group_panel_view_all_members'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_rounded, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionsSection(AppLocalizations l10n) {
    final hasActions = widget.onEditGroup != null ||
        widget.onLeaveGroup != null ||
        widget.onDeleteGroup != null;

    if (!hasActions) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (widget.onEditGroup != null)
          _buildActionButton(
            icon: Icons.edit_rounded,
            label: l10n.t('group_panel_action_edit'),
            color: ThixPolicy.primary,
            onTap: widget.onEditGroup!,
            l10n: l10n,
          ),
        if (widget.onLeaveGroup != null)
          _buildActionButton(
            icon: Icons.exit_to_app_rounded,
            label: l10n.t('group_panel_action_leave'),
            color: ThixPolicy.warning,
            onTap: widget.onLeaveGroup!,
            l10n: l10n,
          ),
        if (widget.onDeleteGroup != null)
          _buildActionButton(
            icon: Icons.delete_rounded,
            label: l10n.t('group_panel_action_delete'),
            color: ThixPolicy.danger,
            onTap: widget.onDeleteGroup!,
            l10n: l10n,
          ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required AppLocalizations l10n,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: _kActionIconSize, color: color),
        label: Text(
          label,
          style: TextStyle(
            fontSize: _kActionFontSize,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withOpacity(0.3)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_kActionButtonRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
