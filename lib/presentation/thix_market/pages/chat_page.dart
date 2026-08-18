// lib/presentation/thix_market/pages/chat_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ChatPage extends StatefulWidget {
  final String conversationId;
  final String? shopId;
  final String? title;
  final String? avatar;

  const ChatPage({
    super.key,
    required this.conversationId,
    this.shopId,
    this.title,
    this.avatar,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  String? _error;
  String? _otherUserId;
  Map<String, dynamic>? _otherUser;
  String? _currentUserId;
  bool _isSending = false;
  String? _conversationId;

  static const Color primaryBlue = Color(0xFF1A73E8);
  static const Color bgLight = Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _initializeChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    setState(() => _isLoading = true);

    if (widget.conversationId.isNotEmpty) {
      _conversationId = widget.conversationId;
      await _loadConversationDetails();
      await _fetchMessages();
      _subscribeToMessages();
      _markAsRead();
      setState(() => _isLoading = false);
      return;
    }

    if (widget.shopId != null && widget.shopId!.isNotEmpty) {
      try {
        final shopResponse = await Supabase.instance.client
            .from('shops')
            .select('owner_id')
            .eq('id', widget.shopId!)
            .single();
        final sellerId = shopResponse['owner_id'] as String?;
        if (sellerId == null) {
          throw Exception('Vendeur introuvable');
        }
        _otherUserId = sellerId;

        final existingConv = await Supabase.instance.client
            .from('conversations')
            .select('id, participant_ids')
            .contains('participant_ids', [_currentUserId, sellerId])
            .maybeSingle();

        if (existingConv != null) {
          _conversationId = existingConv['id'];
          await _loadConversationDetails();
          await _fetchMessages();
          _subscribeToMessages();
          _markAsRead();
        } else {
          final newConv = await Supabase.instance.client
              .from('conversations')
              .insert({
                'participant_ids': [_currentUserId, sellerId],
                'title': widget.title ?? 'Discussion',
                'created_at': DateTime.now().toIso8601String(),
              })
              .select()
              .single();
          _conversationId = newConv['id'];

          await Supabase.instance.client
              .from('conversation_participants')
              .insert([
                {
                  'conversation_id': _conversationId,
                  'user_id': _currentUserId,
                  'unread_count': 0,
                  'joined_at': DateTime.now().toIso8601String(),
                },
                {
                  'conversation_id': _conversationId,
                  'user_id': sellerId,
                  'unread_count': 0,
                  'joined_at': DateTime.now().toIso8601String(),
                },
              ]);

          final userResponse = await Supabase.instance.client
              .from('users')
              .select('name, avatar')
              .eq('id', sellerId)
              .single();
          _otherUser = userResponse;

          _messages = [];
          _subscribeToMessages();
        }
        setState(() => _isLoading = false);
      } catch (e) {
        setState(() {
          _error = 'Erreur lors de l\'initialisation du chat';
          _isLoading = false;
        });
        debugPrint('Error initializing chat: $e');
      }
    } else {
      setState(() {
        _error = 'Aucune conversation ou vendeur spécifié';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadConversationDetails() async {
    if (_conversationId == null) return;
    try {
      final response = await Supabase.instance.client
          .from('conversations')
          .select('participant_ids, title')
          .eq('id', _conversationId!)
          .single();

      final participants = List<String>.from(response['participant_ids'] ?? []);
      _otherUserId = participants.firstWhere(
        (id) => id != _currentUserId,
        orElse: () => '',
      );

      if (_otherUserId != null && _otherUserId!.isNotEmpty) {
        final userResponse = await Supabase.instance.client
            .from('users')
            .select('name, avatar')
            .eq('id', _otherUserId!)
            .single();
        _otherUser = userResponse;
      }
    } catch (e) {
      debugPrint('Error loading conversation details: $e');
    }
  }

  Future<void> _fetchMessages() async {
    if (_conversationId == null) return;
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('messages')
          .select('*')
          .eq('conversation_id', _conversationId!)
          .order('created_at', ascending: true);

      setState(() {
        _messages = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      setState(() {
        _error = 'Impossible de charger les messages';
        _isLoading = false;
      });
    }
  }

  void _subscribeToMessages() {
    if (_conversationId == null) return;
    Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', _conversationId!)
        .order('created_at', ascending: true)
        .listen((data) {
      if (mounted) {
        final newMessages = List<Map<String, dynamic>>.from(data);
        setState(() {
          _messages = newMessages;
        });
        _scrollToBottom();
        _markAsRead();
      }
    });
  }

  Future<void> _markAsRead() async {
    if (_conversationId == null) return;
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      await Supabase.instance.client
          .from('conversation_participants')
          .update({
            'unread_count': 0,
            'last_read_at': DateTime.now().toIso8601String(),
          })
          .match({
            'conversation_id': _conversationId!,
            'user_id': userId,
          });
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending || _conversationId == null) return;

    final userId = _currentUserId;
    if (userId == null) {
      _showLoginRequired();
      return;
    }

    setState(() => _isSending = true);

    try {
      await Supabase.instance.client.from('messages').insert({
        'conversation_id': _conversationId,
        'sender_id': userId,
        'receiver_id': _otherUserId,
        'message': text,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      await Supabase.instance.client
          .from('conversations')
          .update({
            'last_message': text,
            'last_message_time': DateTime.now().toIso8601String(),
          })
          .eq('id', _conversationId!);

      _messageController.clear();
      _focusNode.unfocus();
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'envoi du message')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
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

  void _showLoginRequired() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Veuillez vous connecter')),
    );
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('HH:mm').format(date);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMe = (id) => id == _currentUserId;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title ?? 'Chat'),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title ?? 'Chat'),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: _buildErrorState(),
      );
    }

    final avatarUrl = widget.avatar ?? _otherUser?['avatar'];

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: avatarUrl != null && avatarUrl.toString().isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null || avatarUrl.toString().isEmpty
                  ? const Icon(Icons.person, size: 18)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.title ?? _otherUser?['name'] ?? 'Discussion',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isOwn = isMe(message['sender_id']);
                      final isFirst = index == 0 ||
                          _messages[index - 1]['sender_id'] !=
                              message['sender_id'];
                      final isLast = index == _messages.length - 1 ||
                          _messages[index + 1]['sender_id'] !=
                              message['sender_id'];

                      return _buildMessageBubble(
                        message,
                        isOwn,
                        isFirst,
                        isLast,
                      );
                    },
                  ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isOwn, bool isFirst, bool isLast) {
    final text = message['message'] ?? '';
    final time = _formatTime(message['created_at']);
    final imageUrl = message['image_url'] as String?;
    final avatarUrl = widget.avatar ?? _otherUser?['avatar'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        mainAxisAlignment: isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isOwn && isFirst)
            CircleAvatar(
              radius: 14,
              backgroundImage: avatarUrl != null && avatarUrl.toString().isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null || avatarUrl.toString().isEmpty
                  ? const Icon(Icons.person, size: 14)
                  : null,
            ),
          if (!isOwn && isFirst) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isOwn ? primaryBlue : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isOwn ? 16 : 4),
                  bottomRight: Radius.circular(isOwn ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    GestureDetector(
                      onTap: () {},
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl,
                          height: 150,
                          width: 200,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 150,
                              width: 200,
                              color: Colors.grey[200],
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => Container(
                            height: 150,
                            width: 200,
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                    ),
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    const SizedBox(height: 8),
                  if (text.isNotEmpty)
                    Text(
                      text,
                      style: TextStyle(
                        color: isOwn ? Colors.white : Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 10,
                      color: isOwn ? Colors.white70 : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isOwn && isFirst) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file, color: Colors.grey),
            onPressed: () {},
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                decoration: const InputDecoration(
                  hintText: 'Écrire un message...',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: CircleAvatar(
              backgroundColor: _messageController.text.trim().isEmpty
                  ? Colors.grey[300]
                  : primaryBlue,
              child: IconButton(
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 18),
                onPressed: _messageController.text.trim().isEmpty || _isSending
                    ? null
                    : _sendMessage,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _initializeChat(),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
            ),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'Aucun message',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            'Soyez le premier à envoyer un message',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
