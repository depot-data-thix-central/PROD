import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/services/network_service.dart';

class ChatScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String? userAvatar;

  const ChatScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.userAvatar,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late NetworkService _networkService;
  final TextEditingController _messageController = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _networkService = NetworkService(Supabase.instance.client);
    _loadMessages();
    _markAsRead();
    _listenForNewMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  void _listenForNewMessages() {
    final supabase = Supabase.instance.client;
    final currentUserId = supabase.auth.currentUser?.id;
    
    if (currentUserId == null) return;
    
    // ✅ Correction : utiliser la table 'messages' (comme NetworkService)
    _channel = supabase
        .channel('messages_${widget.userId}_$currentUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',   // ⬅️ CHANGÉ de 'network_messages' à 'messages'
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: currentUserId,
          ),
          callback: (payload) {
            if (payload.newRecord['sender_id'] == widget.userId) {
              _loadMessages();
            }
          },
        )
        .subscribe();
  }

  Future<void> _loadMessages() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final messages = await _networkService.getMessages(widget.userId);
      if (!mounted) return;
      setState(() => _messages = messages);
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error loading messages: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _markAsRead() async {
    await _networkService.markMessagesAsRead(widget.userId);
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    _messageController.clear();
    setState(() => _isTyping = false);
    
    final tempMessage = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'content': content,
      'is_sent_by_me': true,
      'created_at': DateTime.now(),
      'is_temp': true,
    };
    
    setState(() {
      _messages.add(tempMessage);
    });
    _scrollToBottom();

    try {
      final sent = await _networkService.sendMessage(widget.userId, content);
      if (!mounted) return;
      setState(() {
        final index = _messages.indexWhere((m) => m['id'] == tempMessage['id']);
        if (index != -1) {
          _messages[index] = sent;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final index = _messages.indexWhere((m) => m['id'] == tempMessage['id']);
        if (index != -1) {
          _messages[index]['error'] = true;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de l\'envoi du message'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteMessage(String messageId, bool isMe) async {
    if (!isMe) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le message'),
        content: const Text('Voulez-vous vraiment supprimer ce message ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        final supabase = Supabase.instance.client;
        await supabase
            .from('messages')   // ✅ même table
            .delete()
            .eq('id', messageId);
        
        if (!mounted) return;
        setState(() {
          _messages.removeWhere((m) => m['id'] == messageId);
        });
      } catch (e) {
        debugPrint('Error deleting message: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _onTyping() {
    if (!_isTyping) {
      setState(() => _isTyping = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isTyping = false);
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inMinutes < 1) return 'maintenant';
    if (diff.inHours < 1) return 'il y a ${diff.inMinutes}min';
    if (diff.inDays < 1) return 'il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'il y a ${diff.inDays}j';
    return 'le ${date.day}/${date.month}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: widget.userAvatar != null && widget.userAvatar!.isNotEmpty
                  ? NetworkImage(widget.userAvatar!)
                  : null,
              child: widget.userAvatar == null || widget.userAvatar!.isEmpty
                  ? const Icon(Icons.person, size: 18, color: Colors.grey)
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              widget.userName,
              style: const TextStyle(color: Color(0xFF0B1B3D), fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      if (_isTyping)
                        Padding(
                          padding: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(color: Color(0xFFD4AF37), shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${widget.userName} est en train d\'écrire...',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          reverse: false,
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final isMe = message['is_sent_by_me'] == true;
                            final messageId = message['id'] as String;
                            final content = message['content'] as String;
                            final createdAt = message['created_at'] as DateTime;
                            final hasError = message['error'] == true;
                            
                            return GestureDetector(
                              onLongPress: () => _deleteMessage(messageId, isMe),
                              child: _buildMessageBubble(content, isMe, createdAt, hasError),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String message, bool isMe, DateTime date, bool hasError) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFD4AF37) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message,
              style: TextStyle(
                color: isMe ? const Color(0xFF0B1B3D) : Colors.grey.shade800,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(date),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.black54 : Colors.grey.shade500,
                  ),
                ),
                if (hasError) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.error_outline, size: 14, color: Colors.red),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: () {},
            color: Colors.grey.shade600,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              onChanged: (_) => _onTyping(),
              decoration: InputDecoration(
                hintText: 'Écrivez un message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFD4AF37),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Color(0xFF0B1B3D)),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
