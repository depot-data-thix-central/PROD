// ============================================================
// 📁 lib/presentation/chat/profile/chat_profile_page.dart
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/chat/chat_settings_provider.dart';
import 'edit_chat_profile_page.dart';

class ChatProfilePage extends StatefulWidget {
  final String userId;

  const ChatProfilePage({super.key, required this.userId});

  @override
  State<ChatProfilePage> createState() => _ChatProfilePageState();
}

class _ChatProfilePageState extends State<ChatProfilePage> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = context.read<ChatSettingsProvider>();
    await provider.load(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatSettingsProvider>();
    final user = provider.chatUser;

    if (provider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profil')),
        body: const Center(child: Text('Utilisateur introuvable')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => context.go('/chat/settings'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: user.avatarUrl != null
                  ? NetworkImage(user.avatarUrl!)
                  : null,
              child: user.avatarUrl == null
                  ? Text(
                      user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              user.displayName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            if (user.username != null) ...[
              const SizedBox(height: 4),
              Text(
                '@${user.username}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
            if (user.status != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  user.status!,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditChatProfilePage(user: user),
                  ),
                ).then((_) => _loadData());
              },
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Modifier le profil'),
            ),
          ],
        ),
      ),
    );
  }
}
