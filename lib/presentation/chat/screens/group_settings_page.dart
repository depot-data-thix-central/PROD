import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/chat/group_service.dart';
import '../../../services/chat/chat_service.dart';
import '../../../models/chat/group_info.dart';
import 'group_info_page.dart';

/// Écran de paramètres du groupe (admin uniquement).
/// Permet de modifier le nom, la description, l'avatar, les membres et l'invitation.
class GroupSettingsPage extends StatefulWidget {
  final String groupId;

  const GroupSettingsPage({super.key, required this.groupId});

  @override
  State<GroupSettingsPage> createState() => _GroupSettingsPageState();
}

class _GroupSettingsPageState extends State<GroupSettingsPage> {
  late GroupService _groupService;
  late ChatService _chatService;
  GroupInfo? _groupInfo;
  bool _isLoading = true;
  bool _isSaving = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  String? _inviteCode;
  String? _currentUserId;
  bool _isAdmin = false;

  // Couleurs THIX ID
  static const navyDeep = Color(0xFF0A1F44);
  static const navy = Color(0xFF123B7A);
  static const gold = Color(0xFFE3B23C);
  static const ivory = Color(0xFFF3F5FA);
  static const darkText = Color(0xFF10182B);
  static const mutedText = Color(0xFF6B7690);
  static const danger = Color(0xFFD64545);
  static const success = Color(0xFF1FA971);
  static const hairline = Color(0xFFE7EAF3);

  @override
  void initState() {
    super.initState();
    _groupService = GroupService(Supabase.instance.client);
    _chatService = ChatService(Supabase.instance.client);
    _currentUserId = _chatService.currentUserId;
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final conv = await _groupService.getGroupInfo(widget.groupId);
      final supabase = Supabase.instance.client;
      final info = await supabase
          .from('group_info')
          .select('*')
          .eq('group_id', widget.groupId)
          .maybeSingle();

      // Vérifier si l'utilisateur est admin
      final participants = await supabase
          .from('conversation_participants')
          .select('role')
          .eq('conversation_id', widget.groupId)
          .eq('user_id', _currentUserId ?? '')
          .maybeSingle();
      _isAdmin = participants != null && participants['role'] == 'admin';

      setState(() {
        _groupInfo = GroupInfo(
          groupId: widget.groupId,
          name: conv.groupName ?? '',
          avatarUrl: conv.groupAvatar,
          members: [],
          adminIds: [],
          isPublic: info?['is_public'] ?? false,
          inviteCode: info?['invite_code'],
          createdAt: conv.updatedAt,
        );
        _nameController.text = conv.groupName ?? '';
        _descController.text = info?['description'] ?? '';
        _inviteCode = info?['invite_code'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Erreur: $e', danger);
    }
  }

  Future<void> _saveChanges() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnackBar('Le nom ne peut pas être vide', danger);
      return;
    }

    if (!_isAdmin) {
      _showSnackBar('Vous n\'êtes pas administrateur', danger);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _groupService.updateGroupInfo(
        groupId: widget.groupId,
        name: name,
        description: _descController.text.trim().isNotEmpty
            ? _descController.text.trim()
            : null,
        isPublic: _groupInfo?.isPublic,
      );
      setState(() => _isSaving = false);
      _showSnackBar('Modifications enregistrées', success);
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnackBar('Erreur: $e', danger);
    }
  }

  Future<void> _regenerateInviteCode() async {
    if (!_isAdmin) {
      _showSnackBar('Vous n\'êtes pas administrateur', danger);
      return;
    }
    try {
      final newCode = await _groupService.regenerateInviteCode(widget.groupId);
      setState(() => _inviteCode = newCode);
      _showSnackBar('Code d\'invitation régénéré', success);
    } catch (e) {
      _showSnackBar('Erreur: $e', danger);
    }
  }

  void _navigateToGroupInfo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupInfoPage(groupId: widget.groupId),
      ),
    );
  }

  void _showDeleteGroupDialog() {
    if (!_isAdmin) {
      _showSnackBar('Vous n\'êtes pas administrateur', danger);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Supprimer le groupe',
          style: TextStyle(color: danger, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Cette action est irréversible. Tous les messages seront perdus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: mutedText)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _groupService.deleteGroup(widget.groupId);
                if (mounted) {
                  Navigator.pop(context, true);
                  _showSnackBar('Groupe supprimé', success);
                }
              } catch (e) {
                if (mounted) {
                  _showSnackBar('Erreur: $e', danger);
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

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAdmin) {
      return Scaffold(
        backgroundColor: ivory,
        appBar: AppBar(
          backgroundColor: navyDeep,
          title: const Text(
            'Paramètres du groupe',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded, size: 48, color: mutedText),
              const SizedBox(height: 16),
              const Text(
                'Accès restreint aux administrateurs',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: darkText),
              ),
              const SizedBox(height: 8),
              Text(
                'Seul un administrateur peut modifier les paramètres',
                style: TextStyle(fontSize: 13, color: mutedText),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ivory,
      appBar: AppBar(
        backgroundColor: navyDeep,
        elevation: 0,
        title: const Text(
          'Paramètres du groupe',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _saveChanges,
                  child: const Text(
                    'Enregistrer',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Center(
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: navy.withOpacity(0.1),
                        backgroundImage: _groupInfo?.avatarUrl != null
                            ? NetworkImage(_groupInfo!.avatarUrl!)
                            : null,
                        child: _groupInfo?.avatarUrl == null
                            ? Icon(
                                Icons.group_rounded,
                                size: 50,
                                color: navy.withOpacity(0.5),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: gold,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      // Changer l'avatar (à implémenter)
                      _showSnackBar('Fonctionnalité à venir', mutedText);
                    },
                    child: const Text(
                      'Changer l\'avatar',
                      style: TextStyle(color: navy, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 32, color: hairline),

            // Nom du groupe
            const Text(
              'Nom du groupe',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: darkText),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Entrez le nom du groupe',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: hairline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: navy),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            const Text(
              'Description',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: darkText),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Entrez une description du groupe',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: hairline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: navy),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 24),

            // Code d'invitation
            const Text(
              'Code d\'invitation',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: darkText),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: hairline),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _inviteCode ?? 'Non généré',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: navy, size: 20),
                    onPressed: () {
                      _showSnackBar('Code copié !', success);
                    },
                    tooltip: 'Copier le code',
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: gold, size: 20),
                    onPressed: _regenerateInviteCode,
                    tooltip: 'Régénérer le code',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Gestion des membres
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _navigateToGroupInfo,
                icon: const Icon(Icons.people_rounded, size: 18),
                label: const Text('Gérer les membres'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: navy),
                  foregroundColor: navy,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Paramètres supplémentaires
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: hairline),
              ),
              child: SwitchListTile(
                title: const Text(
                  'Groupe public',
                  style: TextStyle(fontWeight: FontWeight.w600, color: darkText),
                ),
                subtitle: const Text(
                  'Tout le monde peut rejoindre avec le code',
                  style: TextStyle(fontSize: 12, color: mutedText),
                ),
                value: _groupInfo?.isPublic ?? false,
                onChanged: (value) {
                  setState(() {
                    _groupInfo = _groupInfo?.copyWith(isPublic: value);
                  });
                },
                activeColor: gold,
                activeTrackColor: gold.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 32),

            // Zone de danger
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: danger.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: danger.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Zone de danger',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: danger,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ces actions sont irréversibles. Soyez prudent.',
                    style: TextStyle(fontSize: 12, color: mutedText),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _showDeleteGroupDialog,
                      icon: const Icon(Icons.delete_rounded, size: 18),
                      label: const Text('Supprimer le groupe'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: danger),
                        foregroundColor: danger,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
