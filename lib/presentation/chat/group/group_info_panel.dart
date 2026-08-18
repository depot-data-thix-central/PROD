import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/chat/group_info.dart';
import '../../../models/chat/chat_conversation.dart';
import 'group_member_list.dart';
import 'group_badge.dart';

/// Panneau des informations du groupe, affiché en haut de ChatScreen pour les groupes.
class GroupInfoPanel extends StatefulWidget {
  final ChatConversation conversation;
  final List<GroupMember> members;
  final VoidCallback? onViewAllMembers;
  final VoidCallback? onEditGroup;
  final VoidCallback? onLeaveGroup;
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

  // Couleurs THIX ID
  static const navyDeep = Color(0xFF0A1F44);
  static const navy = Color(0xFF123B7A);
  static const gold = Color(0xFFE3B23C);
  static const ivory = Color(0xFFF3F5FA);
  static const pureWhite = Color(0xFFFFFFFF);
  static const darkText = Color(0xFF10182B);
  static const mutedText = Color(0xFF6B7690);
  static const success = Color(0xFF1FA971);
  static const danger = Color(0xFFD64545);
  static const hairline = Color(0xFFE7EAF3);

  @override
  Widget build(BuildContext context) {
    final onlineCount = widget.members.where((m) => m.isOnline).length;
    final memberCount = widget.members.length;
    final displayName = widget.conversation.displayName;
    final avatarUrl = widget.conversation.groupAvatar;

    return Container(
      decoration: BoxDecoration(
        color: pureWhite,
        border: Border(
          bottom: BorderSide(color: hairline, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: navyDeep.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // En-tête du groupe (réductible)
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            splashColor: navy.withOpacity(0.05),
            highlightColor: navy.withOpacity(0.03),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  // Avatar du groupe
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: gold.withOpacity(0.5), width: 1.2),
                    ),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: navy.withOpacity(0.08),
                      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null
                          ? Text(
                              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'G',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: navy,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Infos principales
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: darkText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            // Nombre de membres
                            Icon(
                              Icons.people_alt_rounded,
                              size: 12,
                              color: mutedText,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$memberCount',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: mutedText,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Séparateur
                            Container(
                              width: 3,
                              height: 3,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: mutedText,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Indicateur de présence en ligne
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: onlineCount > 0 ? success : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              onlineCount > 0 ? '$onlineCount en ligne' : 'Aucun en ligne',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: onlineCount > 0 ? success : mutedText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Bouton expansion
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: ivory,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: mutedText,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Contenu expansé avec animation
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildExpandedContent(),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent() {
    final membersToShow = widget.members.take(5).toList();
    final hasMore = widget.members.length > 5;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description du groupe (si disponible)
          if (widget.conversation.groupName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: ivory,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: hairline),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: mutedText,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.conversation.groupName!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: darkText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Liste des membres (aperçu)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Membres',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: darkText,
                ),
              ),
              Text(
                '${widget.members.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: mutedText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...membersToShow.asMap().entries.map((entry) {
            final member = entry.value;
            final isLast = entry.key == membersToShow.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: navy.withOpacity(0.08),
                    backgroundImage: member.avatarUrl != null
                        ? NetworkImage(member.avatarUrl!)
                        : null,
                    child: member.avatarUrl == null
                        ? Text(
                            member.displayName.isNotEmpty
                                ? member.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: navy,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            member.displayName,
                            style: const TextStyle(
                              fontSize: 13,
                              color: darkText,
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
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: success,
                      ),
                    ),
                ],
              ),
            );
          }),

          if (hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton(
                onPressed: widget.onViewAllMembers,
                style: TextButton.styleFrom(
                  foregroundColor: navy,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Voir tous les membres',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 14),
                  ],
                ),
              ),
            ),

          const Divider(height: 20, color: hairline),

          // Actions du groupe
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (widget.onEditGroup != null)
                _buildActionButton(
                  icon: Icons.edit_rounded,
                  label: 'Modifier',
                  color: navy,
                  onTap: widget.onEditGroup!,
                ),
              if (widget.onLeaveGroup != null)
                _buildActionButton(
                  icon: Icons.exit_to_app_rounded,
                  label: 'Quitter',
                  color: Colors.orange,
                  onTap: widget.onLeaveGroup!,
                ),
              if (widget.onDeleteGroup != null)
                _buildActionButton(
                  icon: Icons.delete_rounded,
                  label: 'Supprimer',
                  color: danger,
                  onTap: widget.onDeleteGroup!,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withOpacity(0.3)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
