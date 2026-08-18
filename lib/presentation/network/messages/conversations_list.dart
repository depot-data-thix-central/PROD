// lib/presentation/network/messages/conversations_list.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/network_service.dart';
import '../../../auth/auth_controller.dart';
import 'chat_screen.dart';

class ConversationsList extends StatefulWidget {
  const ConversationsList({super.key});

  @override
  State<ConversationsList> createState() => _ConversationsListState();
}

class _ConversationsListState extends State<ConversationsList> {
  List<Conversation> _conversations = [];
  bool _isLoading = true;
  late NetworkService _networkService;

  @override
  void initState() {
    super.initState();
    _networkService = NetworkService(Supabase.instance.client);
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    try {
      final convs = await _networkService.getConversations();
      setState(() {
        _conversations = convs;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading conversations: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) => _buildConversationTile(_conversations[index]),
                ),
    );
  }

  Widget _buildConversationTile(Conversation conversation) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: conversation.otherUserAvatar != null && conversation.otherUserAvatar!.isNotEmpty
            ? NetworkImage(conversation.otherUserAvatar!)
            : null,
        child: conversation.otherUserAvatar == null || conversation.otherUserAvatar!.isEmpty
            ? const Icon(Icons.person, size: 24)
            : null,
      ),
      title: Text(
        conversation.otherUserName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        conversation.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: conversation.unreadCount > 0 ? Colors.black : Colors.grey,
          fontWeight: conversation.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _formatTime(conversation.lastMessageAt),
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          if (conversation.unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${conversation.unreadCount}',
                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      onTap: () {
        context.push('/network/chat/${conversation.otherUserId}', extra: conversation.otherUserName);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'Aucune conversation',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Envoyez un message à quelqu\'un pour commencer',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays > 0) {
      return DateFormat('dd/MM').format(date);
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}min';
    } else {
      return 'maintenant';
    }
  }
}
