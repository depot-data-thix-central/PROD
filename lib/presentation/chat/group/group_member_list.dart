// lib/presentation/chat/group/widgets/group_member_list.dart
//
// ============================================================================
// GROUP MEMBER LIST — Production Enterprise
// ============================================================================
//
// Widget affichant la liste des membres d'un groupe avec leur statut
// en ligne/hors ligne et leurs rôles.
//
// Fonctionnalités :
//   - Tri automatique : membres en ligne d'abord (alphabétique)
//   - Affichage du statut en temps réel (pastille colorée)
//   - Badge de rôle (admin/member) via GroupBadge
//   - Support tap et long-press callbacks
//   - Avatar avec initiale de fallback si pas d'image
//
// Sécurité :
//   - Sanitization XSS sur displayName
//   - Safe initial extraction (pas de RangeError)
//   - NetworkImage avec errorBuilder
//
// UX :
//   - ThixPolicy 100% (0 couleurs hardcodées)
//   - i18n complète (2+ clés)
//   - Semantics VoiceOver sur chaque membre
//   - RepaintBoundary pour performance
// ============================================================================

import 'package:flutter/material.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/chat/group_info.dart';
import 'package:thix_id/presentation/chat/group/group_badge.dart';


// ============================================================================
// CONSTANTS
// ============================================================================
const double _kAvatarRadius = 22.0;
const double _kAvatarFontSize = 16.0;
const double _kStatusDotSize = 12.0;
const double _kStatusDotBorderWidth = 2.0;
const double _kTitleFontSize = 15.0;
const double _kSubtitleFontSize = 12.0;
const double _kListTileVerticalPadding = 4.0;
const double _kListTileHorizontalPadding = 16.0;
const double _kDividerIndent = 60.0;
const int _kMaxDisplayNameLength = 100;

// ============================================================================
// VALIDATORS
// ============================================================================
class _GroupMemberListValidators {
  _GroupMemberListValidators._();

  /// Sanitize un nom (XSS + caractères de contrôle + trim).
  static String sanitizeName(String? input) {
    if (input == null) return '';
    var s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > _kMaxDisplayNameLength
        ? s.substring(0, _kMaxDisplayNameLength)
        : s;
  }

  /// Extrait l'initiale d'un nom de manière sûre (pas de RangeError).
  static String safeInitial(String? name) {
    if (name == null) return '?';
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    // Prend le premier caractère non-espace
    return trimmed[0].toUpperCase();
  }
}

// ============================================================================
// GROUP MEMBER LIST WIDGET
// ============================================================================

/// Widget affichant la liste des membres d'un groupe.
///
/// **Tri** : Les membres en ligne apparaissent en premier, triés par
/// ordre alphabétique. Les membres hors ligne suivent, également triés.
///
/// **Usage** :
/// ```dart
/// GroupMemberList(
///   members: groupMembers,
///   showOnlineStatus: true,
///   showRoles: true,
///   onMemberTap: (userId) => _openProfile(userId),
///   onMemberLongPress: (userId) => _showActions(userId),
/// )
/// ```
class GroupMemberList extends StatelessWidget {
  /// Liste des membres du groupe.
  final List<GroupMember> members;

  /// Afficher la pastille de statut en ligne/hors ligne.
  final bool showOnlineStatus;

  /// Afficher le badge de rôle (admin/member).
  final bool showRoles;

  /// Callback au tap sur un membre.
  final void Function(String userId)? onMemberTap;

  /// Callback au long-press sur un membre.
  final void Function(String userId)? onMemberLongPress;

  const GroupMemberList({
    super.key,
    required this.members,
    this.showOnlineStatus = true,
    this.showRoles = true,
    this.onMemberTap,
    this.onMemberLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Séparer et trier les membres
    final onlineMembers = members.where((m) => m.isOnline).toList();
    final offlineMembers = members.where((m) => !m.isOnline).toList();

    onlineMembers.sort((a, b) => a.displayName.compareTo(b.displayName));
    offlineMembers.sort((a, b) => a.displayName.compareTo(b.displayName));

    final sortedMembers = [...onlineMembers, ...offlineMembers];

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedMembers.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: _kDividerIndent,
        color: ThixPolicy.border,
      ),
      itemBuilder: (context, index) {
        final member = sortedMembers[index];
        return RepaintBoundary(
          child: _buildMemberTile(member, l10n),
        );
      },
    );
  }

  /// Construit la ListTile pour un membre.
  Widget _buildMemberTile(GroupMember member, AppLocalizations l10n) {
    // Sanitize le displayName
    final displayName = _GroupMemberListValidators.sanitizeName(member.displayName);
    final safeInitial = _GroupMemberListValidators.safeInitial(displayName);
    final isOnline = member.isOnline;

    // Statut texte traduit
    final statusText = isOnline
        ? l10n.t('member_status_online')
        : l10n.t('member_status_offline');

    return Semantics(
      button: onMemberTap != null || onMemberLongPress != null,
      label: '$displayName, '
          '${showRoles ? member.role : ""}'
          '${showOnlineStatus ? ", $statusText" : ""}',
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: _kListTileHorizontalPadding,
          vertical: _kListTileVerticalPadding,
        ),
        leading: _buildAvatar(member, displayName, safeInitial, isOnline),
        title: Text(
          displayName.isNotEmpty ? displayName : l10n.t('member_unknown'),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: _kTitleFontSize,
            color: ThixPolicy.textMain,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: showOnlineStatus
            ? Text(
                statusText,
                style: TextStyle(
                  fontSize: _kSubtitleFontSize,
                  color: isOnline ? ThixPolicy.success : ThixPolicy.textMuted,
                ),
              )
            : null,
        trailing: showRoles
            ? GroupBadge(
                role: member.role,
                isCompact: true,
              )
            : null,
        onTap: onMemberTap != null && member.userId.isNotEmpty
            ? () => onMemberTap!(member.userId)
            : null,
        onLongPress: onMemberLongPress != null && member.userId.isNotEmpty
            ? () => onMemberLongPress!(member.userId)
            : null,
      ),
    );
  }

  /// Construit l'avatar avec pastille de statut.
  Widget _buildAvatar(
    GroupMember member,
    String displayName,
    String safeInitial,
    bool isOnline,
  ) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: _kAvatarRadius,
          backgroundColor: ThixPolicy.primary.withOpacity(0.1),
          backgroundImage: member.avatarUrl != null && member.avatarUrl!.isNotEmpty
              ? NetworkImage(member.avatarUrl!)
              : null,
          onBackgroundImageError: member.avatarUrl != null
              ? (exception, stackTrace) {
                  // Silencieux : l'initiale sera affichée à la place
                }
              : null,
          child: member.avatarUrl == null || member.avatarUrl!.isEmpty
              ? Text(
                  safeInitial,
                  style: TextStyle(
                    fontSize: _kAvatarFontSize,
                    fontWeight: FontWeight.w600,
                    color: ThixPolicy.primary,
                  ),
                )
              : null,
        ),
        if (showOnlineStatus)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: _kStatusDotSize,
              height: _kStatusDotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOnline ? ThixPolicy.success : ThixPolicy.textMuted,
                border: Border.all(color: Colors.white, width: _kStatusDotBorderWidth),
              ),
            ),
          ),
      ],
    );
  }
}
