import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../services/chat/group_service.dart';
import '../../../services/chat/chat_service.dart';
import '../../../models/chat/group_info.dart';
import '../../../models/chat/chat_conversation.dart';
import '../../../models/chat/chat_participant.dart';

/// Écran de création de groupe : nom, description, sélection des membres.
class GroupCreatePage extends StatefulWidget {
  const GroupCreatePage({super.key});

  @override
  State<GroupCreatePage> createState() => _GroupCreatePageState();
}

class _GroupCreatePageState extends State<GroupCreatePage> {
  late GroupService _groupService;
  late ChatService _chatService;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _contacts = [];
  List<String> _selectedUserIds = [];
  bool _isLoading = true;
  bool _isCreating = false;

  // Couleurs THIX ID
  static const navyDeep = Color(0xFF0A1F44);
  static const navy = Color(0xFF123B7A);
  static const gold = Color(0xFFE3B23C);
  static const ivory = Color(0xFFF3F5FA);
  static const darkText = Color(0xFF10182B);
  static const mutedText = Color(0xFF6B7690);

  @override
  void initState() {
    super.initState();
    _groupService = GroupService(Supabase.instance.client);
    _chatService = ChatService(Supabase.instance.client);
    _loadContacts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    try {
      final uid = _chatService.currentUserId;
      // Récupérer les contacts depuis conversation_participants
      final supabase = Supabase.instance.client;
      final data = await supabase
          .from('conversation_participants')
          .select('''
            user_id,
            profiles!user_id (id, username, full_name, avatar_url)
          ''')
          .neq('user_id', uid);

      final Map<String, Map<String, dynamic>> uniqueContacts = {};
      for (var p in data as List) {
        final profile = p['profiles'] as Map<String, dynamic>?;
        if (profile != null) {
          final id = profile['id'] as String;
          if (!uniqueContacts.containsKey(id)) {
            uniqueContacts[id] = {
              'id': id,
              'username': profile['username'] ?? 'Inconnu',
              'full_name': profile['full_name'],
              'avatar_url': profile['avatar_url'],
            };
          }
        }
      }
      setState(() {
        _contacts = uniqueContacts.values.toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur chargement contacts: $e'), backgroundColor: Colors.red),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredContacts {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) return _contacts;
    return _contacts.where((c) {
      final name = (c['full_name'] ?? c['username'] ?? '').toLowerCase();
      return name.contains(query);
    }).toList();
  }

  void _toggleSelection(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un nom de groupe')),
      );
      return;
    }
    if (_selectedUserIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez au moins 2 membres')),
      );
      return;
    }

    setState(() => _isCreating = true);
    try {
      final conv = await _groupService.createGroup(
        name: name,
        description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
        memberIds: _selectedUserIds,
        isPublic: false,
      );
      setState(() => _isCreating = false);
      // Retourner à la liste des chats
      Navigator.pop(context, conv);
    } catch (e) {
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ivory,
      appBar: AppBar(
        backgroundColor: navyDeep,
        title: const Text('Nouveau groupe', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _isCreating
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : TextButton(
                    onPressed: (_selectedUserIds.length >= 2) ? _createGroup : null,
                    style: TextButton.styleFrom(foregroundColor: Colors.white, disabledForegroundColor: Colors.grey),
                    child: const Text('Créer', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom du groupe
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom du groupe *',
                      hintText: 'Ex: Équipe Projet',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Description
                  TextField(
                    controller: _descController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optionnel)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),
                  // Sélection des membres
                  const Text(
                    'Ajouter des membres',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: darkText),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Rechercher un contact...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_selectedUserIds.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(
                        spacing: 6,
                        children: _selectedUserIds.map((id) {
                          final contact = _contacts.firstWhere((c) => c['id'] == id);
                          final name = contact['full_name'] ?? contact['username'] ?? 'Inconnu';
                          return Chip(
                            label: Text(name),
                            onDeleted: () => _toggleSelection(id),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            backgroundColor: gold.withOpacity(0.2),
                            avatar: CircleAvatar(
                              radius: 12,
                              backgroundColor: navy,
                              backgroundImage: contact['avatar_url'] != null
                                  ? NetworkImage(contact['avatar_url'])
                                  : null,
                              child: contact['avatar_url'] == null
                                  ? Text(name[0].toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white))
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredContacts.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final contact = _filteredContacts[index];
                      final userId = contact['id'] as String;
                      final isSelected = _selectedUserIds.contains(userId);
                      final name = contact['full_name'] ?? contact['username'] ?? 'Inconnu';
                      final avatar = contact['avatar_url'];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: navy.withOpacity(0.1),
                          backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                          child: avatar == null
                              ? Text(name[0].toUpperCase(), style: const TextStyle(color: navy))
                              : null,
                        ),
                        title: Text(name),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: gold)
                            : null,
                        onTap: () => _toggleSelection(userId),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
