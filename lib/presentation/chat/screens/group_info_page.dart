import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/chat/group_service.dart';
import '../../../services/chat/chat_service.dart';
import '../../../models/chat/group_info.dart';
import '../../../models/chat/chat_conversation.dart';
import '../group/group_badge.dart';
import '../group/group_member_list.dart';
import 'group_settings_page.dart';

/// Écran affichant les informations détaillées d'un groupe.
class GroupInfoPage extends StatefulWidget {
  final String groupId;

  const GroupInfoPage({super.key, required this.groupId});

  @override
  State<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends State<GroupInfoPage> {
  late GroupService _groupService;
  late ChatService _chatService;
  GroupInfo? _groupInfo;
  ChatConversation? _conversation;
  bool _isLoading = true;
  String? _currentUserId;

  // Couleurs THIX ID
  static const navyDeep = Color(0xFF0A1F44);
  static const navy = Color(0xFF123B7A);
  static const gold = Color(0xFFE3B23C);
  static const ivory = Color(0xFFF3F5FA);
  static const darkText = Color(0xFF10182B);
  static const mutedText = Color(0xFF6B7690);
  static const danger = Color(0xFFD64545);
  static const success = Color(0xFF1FA971);

  @override
  void initState() {
    super.initState();
    _groupService = GroupService(Supabase.instance.client);
    _chatService = ChatService(Supabase.instance.client);
    _currentUserId = _chatService.currentUserId;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final conv = await _groupService.getGroupInfo(widget.groupId);
      final members = await _getMembers(widget.groupId);
      setState(() {
        _conversation = conv;
        _groupInfo = GroupInfo(
          groupId: widget.groupId,
          name: conv.groupName ?? 'Groupe',
          avatarUrl: conv.groupAvatar,
          members: members,
          adminIds: members.where((m) => m.isAdmin).map((m) => m.userId).toList(),
          isPublic: false,
          createdAt: conv.updatedAt,
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: danger),
      );
    }
  }

  Future<List<GroupMember>> _getMembers(String groupId) async {
    final supabase = Supabase.instance.client;
    final data = await supabase
        .from('conversation_participants')
        .select('''
          user_id,
          role,
          last_read_at,
          profiles!user_id (username, full_name, avatar_url)
        ''')
        .eq('conversation_id', groupId);

    final members = <GroupMember>[];
    for (var p in data as List) {
      final profile = p['profiles'] as Map<String, dynamic>?;
      final userId = p['user_id'] as String;
      final role = p['role'] as String? ?? 'member';
      
      final presence = await supabase
          .from('user_presence')
          .select('status')
          .eq('user_id', userId)
          .maybeSingle();
      final isOnline = presence != null && presence['status'] == 'online';
      
      members.add(GroupMember(
        userId: userId,
        displayName: profile?['full_name'] ?? profile?['username'] ?? 'Utilisateur',
        avatarUrl: profile?['avatar_url'],
        role: role,
        isOnline: isOnline,
        joinedAt: DateTime.parse(p['last_read_at'] ?? DateTime.now().toIso8601String()),
      ));
    }
    return members;
  }

  bool get _isAdmin => _currentUserId != null && _groupInfo?.isAdmin(_currentUserId!) == true;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_conversation == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Groupe introuvable')),
        body: const Center(child: Text('Ce groupe n\'existe pas ou a été supprimé.')),
      );
    }

    final conv = _conversation!;
    final members = _groupInfo?.members ?? [];
    final onlineCount = members.where((m) => m.isOnline).length;
    final isAdmin = _isAdmin;

    return Scaffold(
      backgroundColor: ivory,
      appBar: AppBar(
        backgroundColor: navyDeep,
        elevation: 0,
        title: const Text(
          'Informations du groupe',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.settings_rounded, color: Colors.white),
              onPressed: () => _navigateToSettings(),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête du groupe
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: navy.withOpacity(0.1),
                    backgroundImage: conv.groupAvatar != null
                        ? NetworkImage(conv.groupAvatar!)
                        : null,
                    child: conv.groupAvatar == null
                        ? Text(
                            conv.displayName.isNotEmpty ? conv.displayName[0].toUpperCase() : 'G',
                            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: navy),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    conv.displayName,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: darkText),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$onlineCount en ligne • ${members.length} membres',
                    style: const TextStyle(fontSize: 14, color: mutedText),
                  ),
                  const SizedBox(height: 16),
                  if (isAdmin)
                    ElevatedButton.icon(
                      onPressed: () => _navigateToSettings(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gold,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Gérer le groupe'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Description
            if (conv.groupName != null && conv.groupName != conv.displayName) ...[
              const Text('Description', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: darkText)),
              const SizedBox(height: 6),
              Text(
                conv.groupName!,
                style: const TextStyle(fontSize: 14, color: mutedText),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
            ],

            // Code d'invitation
            if (_groupInfo?.inviteCode != null) ...[
              const Text('Code d\'invitation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: darkText)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _groupInfo!.inviteCode!,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: navy, size: 18),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copié !'), backgroundColor: success),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
            ],

            // Liste des membres
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Membres (${members.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: darkText),
                ),
                if (isAdmin)
                  TextButton.icon(
                    onPressed: () {
                      // Naviguer vers la page d'ajout de membres
                    },
                    icon: const Icon(Icons.add_circle_rounded, size: 18, color: navy),
                    label: const Text('Ajouter', style: TextStyle(color: navy)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            GroupMemberList(
              members: members,
              showOnlineStatus: true,
              showRoles: true,
              onMemberTap: (userId) {
                // Voir le profil du membre
              },
              onMemberLongPress: isAdmin
                  ? (userId) {
                      _showMemberActions(userId);
                    }
                  : null,
            ),
            const SizedBox(height: 24),

            // Actions de groupe
            if (!isAdmin) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showLeaveGroupDialog,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: danger),
                    foregroundColor: danger,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.exit_to_app_rounded),
                  label: const Text('Quitter le groupe'),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showDeleteGroupDialog,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: danger),
                    foregroundColor: danger,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.delete_rounded),
                  label: const Text('Supprimer le groupe'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupSettingsPage(groupId: widget.groupId),
      ),
    ).then((_) => _loadData());
  }

  void _showLeaveGroupDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitter le groupe'),
        content: const Text('Êtes-vous sûr de vouloir quitter ce groupe ? Vous ne pourrez plus y accéder.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _groupService.leaveGroup(widget.groupId);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vous avez quitté le groupe'), backgroundColor: success),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e'), backgroundColor: danger),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: danger),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
  }

  void _showDeleteGroupDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le groupe'),
        content: const Text('Cette action est irréversible. Tous les messages seront perdus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _groupService.deleteGroup(widget.groupId);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Groupe supprimé'), backgroundColor: success),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e'), backgroundColor: danger),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _showMemberActions(String userId) {
    final member = _groupInfo?.getMember(userId);
    if (member == null) return;
    final isAdmin = member.isAdmin;
    final isSelf = userId == _currentUserId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: navy.withOpacity(0.1),
                backgroundImage: member.avatarUrl != null ? NetworkImage(member.avatarUrl!) : null,
                child: member.avatarUrl == null
                    ? Text(member.displayName[0].toUpperCase(), style: const TextStyle(color: navy))
                    : null,
              ),
              title: Text(member.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(isAdmin ? 'Admin' : 'Membre', style: TextStyle(color: isAdmin ? gold : mutedText)),
            ),
            const Divider(),
            if (!isAdmin && !isSelf)
              ListTile(
                leading: const Icon(Icons.star_rounded, color: gold),
                title: const Text('Promouvoir admin'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await _groupService.promoteToAdmin(widget.groupId, userId);
                    await _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Membre promu admin'), backgroundColor: success),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur: $e'), backgroundColor: danger),
                    );
                  }
                },
              ),
            if (isAdmin && !isSelf)
              ListTile(
                leading: const Icon(Icons.star_border_rounded, color: mutedText),
                title: const Text('Rétrograder en membre'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await _groupService.demoteFromAdmin(widget.groupId, userId);
                    await _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Admin rétrogradé'), backgroundColor: success),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur: $e'), backgroundColor: danger),
                    );
                  }
                },
              ),
            if (!isSelf && _isAdmin)
              ListTile(
                leading: const Icon(Icons.remove_circle_outline, color: danger),
                title: const Text('Retirer du groupe', style: TextStyle(color: danger)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmRemoveMember(userId);
                },
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Fermer'),
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmRemoveMember(String userId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirer le membre'),
        content: const Text('Êtes-vous sûr de vouloir retirer ce membre du groupe ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _groupService.removeMember(widget.groupId, userId);
                await _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Membre retiré'), backgroundColor: success),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur: $e'), backgroundColor: danger),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: danger),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
  }
}
