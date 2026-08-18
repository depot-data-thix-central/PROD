import 'package:flutter/material.dart';
import '../../../models/chat/group_info.dart';
import 'group_badge.dart';

/// Widget affichant la liste des membres d'un groupe avec leur statut.
class GroupMemberList extends StatelessWidget {
  final List<GroupMember> members;
  final bool showOnlineStatus;
  final bool showRoles;
  final void Function(String userId)? onMemberTap;
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
    // Séparer les membres en ligne et hors ligne
    final onlineMembers = members.where((m) => m.isOnline).toList();
    final offlineMembers = members.where((m) => !m.isOnline).toList();

    // Trier les membres en ligne par ordre alphabétique
    onlineMembers.sort((a, b) => a.displayName.compareTo(b.displayName));
    offlineMembers.sort((a, b) => a.displayName.compareTo(b.displayName));

    final sortedMembers = [...onlineMembers, ...offlineMembers];

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedMembers.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 60),
      itemBuilder: (context, index) {
        final member = sortedMembers[index];
        final isOnline = member.isOnline;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFF0A1F44).withOpacity(0.1),
                backgroundImage: member.avatarUrl != null
                    ? NetworkImage(member.avatarUrl!)
                    : null,
                child: member.avatarUrl == null
                    ? Text(
                        member.displayName.isNotEmpty
                            ? member.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0A1F44),
                        ),
                      )
                    : null,
              ),
              if (showOnlineStatus)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOnline ? const Color(0xFF1FA971) : Colors.grey[400],
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            member.displayName,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: Color(0xFF10182B),
            ),
          ),
          subtitle: showOnlineStatus
              ? Text(
                  isOnline ? 'En ligne' : 'Hors ligne',
                  style: TextStyle(
                    fontSize: 12,
                    color: isOnline ? const Color(0xFF1FA971) : const Color(0xFF6B7690),
                  ),
                )
              : null,
          trailing: showRoles
              ? GroupBadge(
                  role: member.role,
                  isCompact: true,
                )
              : null,
          onTap: onMemberTap != null ? () => onMemberTap!(member.userId) : null,
          onLongPress: onMemberLongPress != null
              ? () => onMemberLongPress!(member.userId)
              : null,
        );
      },
    );
  }
}
