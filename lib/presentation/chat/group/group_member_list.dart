// lib/presentation/chat/group/group_member_list.dart
//
// ============================================================================
// GROUP MEMBER LIST — Production Enterprise++
// ============================================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/chat/group_info.dart';
import 'package:thix_id/presentation/chat/group/group_badge.dart';

const double _kAvatarRadius = 22.0;
const double _kAvatarFontSize = 16.0;
const double _kStatusDotSize = 12.0;
const double _kStatusDotBorderWidth = 2.0;
const double _kTitleFontSize = 15.0;
const double _kSubtitleFontSize = 12.0;
const double _kMicroFontSize = 10.0;
const double _kListTileVerticalPadding = 8.0;
const double _kListTileHorizontalPadding = 16.0;
const double _kSectionHeaderPadding = 12.0;
const double _kSectionHeaderFontSize = 11.0;
const int _kMaxDisplayNameLength = 100;

String _tr(AppLocalizations l10n, String key, String fallback) {
  final s = l10n.t(key);
  return s == key ? fallback : s;
}

class _GroupMemberListValidators {
  _GroupMemberListValidators._();

  static String sanitizeName(String? input) {
    if (input == null) return '';
    var s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > _kMaxDisplayNameLength ? s.substring(0, _kMaxDisplayNameLength) : s;
  }

  static String safeInitial(String? name) {
    if (name == null) return '?';
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }

  static bool isValidUuid(String? id) {
    if (id == null || id.isEmpty) return false;
    return RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
            caseSensitive: false)
        .hasMatch(id);
  }

  static String maskPhoneNumber(String phone) {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.length <= 6) return phone;
    final prefix = clean.substring(0, 3);
    final suffix = clean.substring(clean.length - 4);
    return '$prefix *** *** $suffix';
  }
}

class GroupMemberList extends StatefulWidget {
  final List<GroupMember> members;
  final String currentUserId;
  final bool isCurrentUserAgent;
  final bool showOnlineStatus;
  final bool showRoles;
  final bool showStatsHeader;
  final void Function(String userId)? onMemberTap;
  final void Function(String userId)? onMemberLongPress;
  final void Function(String userId)? onPromoteAdmin;
  final void Function(String userId)? onDemoteMember;
  final void Function(String userId)? onRemoveMember;
  final void Function(String userId)? onAddNote;

  const GroupMemberList({
    super.key,
    required this.members,
    required this.currentUserId,
    this.isCurrentUserAgent = false,
    this.showOnlineStatus = true,
    this.showRoles = true,
    this.showStatsHeader = true,
    this.onMemberTap,
    this.onMemberLongPress,
    this.onPromoteAdmin,
    this.onDemoteMember,
    this.onRemoveMember,
    this.onAddNote,
  });

  @override
  State<GroupMemberList> createState() => _GroupMemberListState();
}

class _GroupMemberListState extends State<GroupMemberList> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filteredMembers = _searchQuery.isEmpty
        ? widget.members
        : widget.members.where((m) {
            final name = m.displayName.toLowerCase();
            final phone = (m.phoneNumber ?? '').toLowerCase();
            return name.contains(_searchQuery) || phone.contains(_searchQuery);
          }).toList();

    final admins = filteredMembers.where((m) => m.isAdmin).toList();
    final onlineMembers = filteredMembers.where((m) => !m.isAdmin && m.isOnline).toList();
    final offlineMembers = filteredMembers.where((m) => !m.isAdmin && !m.isOnline).toList();

    admins.sort((a, b) => a.displayName.compareTo(b.displayName));
    onlineMembers.sort((a, b) => a.displayName.compareTo(b.displayName));
    offlineMembers.sort((a, b) => a.displayName.compareTo(b.displayName));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSearchBar(l10n),
        const SizedBox(height: 12),
        if (widget.showStatsHeader) ...[
          _buildStatsHeader(l10n, filteredMembers.length),
          const SizedBox(height: 16),
        ],
        if (admins.isNotEmpty) ...[
          _buildSectionHeader(_tr(l10n, 'member_section_admins', 'ADMINISTRATEURS'), admins.length),
          ...admins.map((m) => _buildMemberTile(m, l10n)),
          const SizedBox(height: 16),
        ],
        if (onlineMembers.isNotEmpty) ...[
          _buildSectionHeader(_tr(l10n, 'member_section_online', 'EN LIGNE'), onlineMembers.length),
          ...onlineMembers.map((m) => _buildMemberTile(m, l10n)),
          const SizedBox(height: 16),
        ],
        if (offlineMembers.isNotEmpty) ...[
          _buildSectionHeader(_tr(l10n, 'member_section_offline', 'HORS LIGNE'), offlineMembers.length),
          ...offlineMembers.map((m) => _buildMemberTile(m, l10n)),
        ],
      ],
    );
  }

  Widget _buildSearchBar(AppLocalizations l10n) {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        HapticFeedback.selectionClick();
        setState(() => _searchQuery = value.toLowerCase());
      },
      decoration: InputDecoration(
        hintText: _tr(l10n, 'member_search_hint', 'Rechercher un membre...'),
        hintStyle: TextStyle(fontSize: 13, color: ThixPolicy.textMuted),
        prefixIcon: Icon(Icons.search_rounded, size: 18, color: ThixPolicy.textMuted),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.close_rounded, size: 16, color: ThixPolicy.textMuted),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                })
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ThixPolicy.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ThixPolicy.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ThixPolicy.primary, width: 1.5)),
      ),
      style: TextStyle(fontSize: 13, color: ThixPolicy.textMain),
    );
  }

  Widget _buildStatsHeader(AppLocalizations l10n, int totalMembers) {
    final onlineCount = widget.members.where((m) => m.isOnline).length;
    final newMembersThisWeek = widget.members.where((m) => m.isNewMember).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ThixPolicy.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ThixPolicy.primary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(Icons.people_alt_rounded, totalMembers.toString(), _tr(l10n, 'member_total', 'Total'), ThixPolicy.primary),
          Container(width: 1, height: 30, color: ThixPolicy.border),
          _buildStatItem(Icons.circle, onlineCount.toString(), _tr(l10n, 'member_online', 'En ligne'), ThixPolicy.success),
          Container(width: 1, height: 30, color: ThixPolicy.border),
          _buildStatItem(Icons.fiber_new_rounded, newMembersThisWeek.toString(), _tr(l10n, 'member_new_week', 'Nouveaux'), ThixPolicy.gold),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Column(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: TextStyle(fontSize: 9, color: ThixPolicy.textMuted, fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _kSectionHeaderPadding),
      child: Row(children: [
        Text(title, style: TextStyle(fontSize: _kSectionHeaderFontSize, fontWeight: FontWeight.w700, color: ThixPolicy.textMuted, letterSpacing: 0.5)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: ThixPolicy.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Text('$count', style: TextStyle(fontSize: 10, color: ThixPolicy.primary, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  Widget _buildMemberTile(GroupMember member, AppLocalizations l10n) {
    final displayName = _GroupMemberListValidators.sanitizeName(member.displayName);
    final safeInitial = _GroupMemberListValidators.safeInitial(displayName);
    final isOnline = member.isOnline;
    final isNewMember = member.isNewMember;
    final statusText = isOnline
        ? l10n.t('member_status_online')
        : _formatLastSeen(member.lastSeenAt, l10n);

    return RepaintBoundary(
      child: Semantics(
        button: widget.onMemberTap != null || widget.onMemberLongPress != null,
        label: '$displayName, ${widget.showRoles ? member.role.displayName : ""}'
            '${widget.showOnlineStatus ? ", $statusText" : ""}',
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            if (widget.onMemberTap != null && _GroupMemberListValidators.isValidUuid(member.userId)) {
              widget.onMemberTap!(member.userId);
            }
          },
          onLongPress: () {
            HapticFeedback.mediumImpact();
            if (widget.onMemberLongPress != null && _GroupMemberListValidators.isValidUuid(member.userId)) {
              widget.onMemberLongPress!(member.userId);
            } else {
              _showMemberActions(member, l10n);
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _kListTileHorizontalPadding, vertical: _kListTileVerticalPadding),
            child: Row(
              children: [
                _buildAvatar(member, displayName, safeInitial, isOnline),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(
                            displayName.isNotEmpty ? displayName : l10n.t('member_unknown'),
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: _kTitleFontSize, color: ThixPolicy.textMain),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (widget.showRoles && member.role != GroupRole.member)
                          GroupBadge(role: member.role, isCompact: true),
                        if (isNewMember) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: ThixPolicy.success.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                            child: Text(_tr(l10n, 'member_new', 'Nouveau'),
                                style: TextStyle(fontSize: 9, color: ThixPolicy.success, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 2),
                      if (widget.showOnlineStatus)
                        Text(statusText,
                            style: TextStyle(fontSize: _kSubtitleFontSize,
                                color: isOnline ? ThixPolicy.success : ThixPolicy.textMuted,
                                fontWeight: FontWeight.w500)),
                      if (member.phoneNumber != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(_GroupMemberListValidators.maskPhoneNumber(member.phoneNumber!),
                              style: TextStyle(fontSize: _kMicroFontSize, color: ThixPolicy.textMuted)),
                        ),
                      if (widget.isCurrentUserAgent && member.internalNote != null)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: ThixPolicy.warning.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: ThixPolicy.warning.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.note_outlined, size: 11, color: ThixPolicy.warning),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(member.internalNote!,
                                    style: TextStyle(fontSize: 10, color: ThixPolicy.warning, fontStyle: FontStyle.italic),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (member.isMuted)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: ThixPolicy.danger.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.volume_off_rounded, size: 14, color: ThixPolicy.danger),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatLastSeen(DateTime? lastSeen, AppLocalizations l10n) {
    if (lastSeen == null) return _tr(l10n, 'member_last_seen_unknown', 'Vu récemment');
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 1) return _tr(l10n, 'member_last_seen_now', 'Vu à l\'instant');
    if (diff.inMinutes < 60) {
      return _tr(l10n, 'member_last_seen_minutes', 'Vu il y a {n} min')
          .replaceAll('{n}', '${diff.inMinutes}');
    }
    if (diff.inHours < 24) {
      return _tr(l10n, 'member_last_seen_hours', 'Vu il y a {n} h')
          .replaceAll('{n}', '${diff.inHours}');
    }
    if (diff.inDays < 7) {
      return _tr(l10n, 'member_last_seen_days', 'Vu il y a {n} j')
          .replaceAll('{n}', '${diff.inDays}');
    }
    return '${lastSeen.day}/${lastSeen.month}/${lastSeen.year}';
  }

  Widget _buildAvatar(GroupMember member, String displayName, String safeInitial, bool isOnline) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ThixPolicy.card, width: 1.5),
            boxShadow: ThixPolicy.shadowSoft(opacity: 0.03),
          ),
          child: CircleAvatar(
            radius: _kAvatarRadius,
            backgroundColor: ThixPolicy.primary.withOpacity(0.1),
            backgroundImage: member.avatarUrl != null && member.avatarUrl!.isNotEmpty
                ? CachedNetworkImageProvider(member.avatarUrl!)
                : null,
            child: member.avatarUrl == null || member.avatarUrl!.isEmpty
                ? Text(safeInitial,
                    style: TextStyle(fontSize: _kAvatarFontSize, fontWeight: FontWeight.w600, color: ThixPolicy.primary))
                : null,
          ),
        ),
        if (widget.showOnlineStatus && isOnline)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: _kStatusDotSize,
              height: _kStatusDotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ThixPolicy.success,
                border: Border.all(color: Colors.white, width: _kStatusDotBorderWidth),
              ),
            ),
          ),
      ],
    );
  }

  void _showMemberActions(GroupMember member, AppLocalizations l10n) {
    final isCurrentUser = member.userId == widget.currentUserId;
    final canManageMembers = widget.onPromoteAdmin != null || widget.onRemoveMember != null;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
                  decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  _buildAvatar(member, member.displayName, _GroupMemberListValidators.safeInitial(member.displayName), member.isOnline),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(member.displayName,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ThixPolicy.textMain)),
                        if (member.phoneNumber != null)
                          Text(_GroupMemberListValidators.maskPhoneNumber(member.phoneNumber!),
                              style: TextStyle(fontSize: 12, color: ThixPolicy.textMuted)),
                        GroupBadge(role: member.role, isCompact: true),
                      ],
                    ),
                  ),
                ]),
              ),
              const Divider(height: 1, color: ThixPolicy.border),
              ListTile(
                leading: Icon(Icons.person_outline, color: ThixPolicy.primary),
                title: Text(_tr(l10n, 'member_view_profile', 'Voir le profil')),
                onTap: () {
                  Navigator.pop(ctx);
                  HapticFeedback.selectionClick();
                  if (widget.onMemberTap != null) widget.onMemberTap!(member.userId);
                },
              ),
              if (!isCurrentUser && widget.isCurrentUserAgent && widget.onAddNote != null)
                ListTile(
                  leading: Icon(Icons.note_add_outlined, color: ThixPolicy.warning),
                  title: Text(_tr(l10n, 'member_add_note', 'Ajouter une note')),
                  onTap: () {
                    Navigator.pop(ctx);
                    HapticFeedback.selectionClick();
                    widget.onAddNote!(member.userId);
                  },
                ),
              if (!isCurrentUser && canManageMembers) ...[
                if (!member.hasPrivileges && widget.onPromoteAdmin != null)
                  ListTile(
                    leading: Icon(Icons.admin_panel_settings_outlined, color: ThixPolicy.gold),
                    title: Text(_tr(l10n, 'member_promote', 'Promouvoir admin')),
                    onTap: () {
                      Navigator.pop(ctx);
                      HapticFeedback.mediumImpact();
                      widget.onPromoteAdmin!(member.userId);
                    },
                  ),
                if (member.isAdmin && !member.isOwner && widget.onDemoteMember != null)
                  ListTile(
                    leading: Icon(Icons.person_remove_outlined, color: ThixPolicy.warning),
                    title: Text(_tr(l10n, 'member_demote', 'Rétrograder')),
                    onTap: () {
                      Navigator.pop(ctx);
                      HapticFeedback.mediumImpact();
                      widget.onDemoteMember!(member.userId);
                    },
                  ),
                if (widget.onRemoveMember != null)
                  ListTile(
                    leading: Icon(Icons.exit_to_app, color: ThixPolicy.danger),
                    title: Text(_tr(l10n, 'member_remove', 'Exclure du groupe'), style: TextStyle(color: ThixPolicy.danger)),
                    onTap: () {
                      Navigator.pop(ctx);
                      HapticFeedback.mediumImpact();
                      widget.onRemoveMember!(member.userId);
                    },
                  ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
