import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class ConversationList extends StatefulWidget {
  final Function(Map<String, dynamic>)? onConversationTap;
  final String? currentUserId;

  const ConversationList({
    super.key,
    this.onConversationTap,
    this.currentUserId,
  });

  @override
  State<ConversationList> createState() => _ConversationListState();
}

class _ConversationListState extends State<ConversationList> {
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  String? _searchQuery;
  Stream<List<Map<String, dynamic>>>? _conversationsStream;

  // Cache pour les autres utilisateurs
  final Map<String, Map<String, dynamic>> _userCache = {};

  static const Color navy = Color(0xFF1B2A4A);
  static const Color gold = Color(0xFFC9962C);
  static const Color danger = Color(0xFFE53935);
  static const Color textMuted = Color(0xFF8A8FA3);
  static const Color bgApp = Color(0xFFF6F7FB);

  @override
  void initState() {
    super.initState();
    _setupRealtimeSubscription();
    _loadConversations();
  }

  void _setupRealtimeSubscription() {
    final userId = widget.currentUserId ?? Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    // ✅ Construction de la requête filtrée puis conversion en stream
    final query = Supabase.instance.client
        .from('conversations')
        .select()
        .filter('participant_ids', 'cs', '{${userId}}') // opérateur 'cs' = contains
        .order('last_message_time', ascending: false);

    _conversationsStream = query.stream(primaryKey: ['id']).map((data) => List<Map<String, dynamic>>.from(data));

    _conversationsStream?.listen((conversations) {
      if (mounted) {
        setState(() {
          _conversations = conversations;
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    final userId = widget.currentUserId ?? Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('conversations')
          .select()
          .filter('participant_ids', 'cs', '{${userId}}')
          .order('last_message_time', ascending: false);

      setState(() {
        _conversations = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading conversations: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<Map<String, dynamic>?> _getOtherUser(Map<String, dynamic> conversation) async {
    final userId = widget.currentUserId ?? Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;

    final participants = List<String>.from(conversation['participant_ids'] ?? []);
    final otherId = participants.firstWhere((id) => id != userId, orElse: () => '');
    if (otherId.isEmpty) return null;

    // Vérifier le cache
    if (_userCache.containsKey(otherId)) {
      return _userCache[otherId];
    }

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('id, name, avatar, is_online, last_seen')
          .eq('id', otherId)
          .single();

      final userData = Map<String, dynamic>.from(response);
      _userCache[otherId] = userData; // mettre en cache
      return userData;
    } catch (e) {
      return null;
    }
  }

  Future<void> _markAsRead(String conversationId) async {
    final userId = widget.currentUserId ?? Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await Supabase.instance.client
          .from('conversation_participants')
          .update({'unread_count': 0, 'last_read_at': DateTime.now().toIso8601String()})
          .match({
            'conversation_id': conversationId,
            'user_id': userId,
          });
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null) return '';
    try {
      final date = DateTime.parse(timeStr);
      final now = DateTime.now();
      if (date.day == now.day && date.month == now.month && date.year == now.year) {
        return DateFormat('HH:mm').format(date);
      }
      if (date.year == now.year) {
        return DateFormat('dd/MM').format(date);
      }
      return DateFormat('dd/MM/yy').format(date);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_conversations.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        // Barre de recherche
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Rechercher une conversation...',
              prefixIcon: const Icon(Icons.search, color: textMuted),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(color: gold, width: 2),
              ),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value.toLowerCase());
            },
          ),
        ),

        // Liste
        Expanded(
          child: ListView.builder(
            itemCount: _conversations.length,
            itemBuilder: (context, index) {
              final conv = _conversations[index];
              if (_searchQuery != null && _searchQuery!.isNotEmpty) {
                final title = conv['title']?.toLowerCase() ?? '';
                if (!title.contains(_searchQuery!)) return const SizedBox.shrink();
              }
              return FutureBuilder<Map<String, dynamic>?>(
                future: _getOtherUser(conv),
                builder: (context, snapshot) {
                  final otherUser = snapshot.data;
                  return _buildConversationTile(conv, otherUser);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildConversationTile(Map<String, dynamic> conversation, Map<String, dynamic>? otherUser) {
    final unreadCount = conversation['unread_count'] ?? 0;
    final isUnread = unreadCount > 0;
    final lastMessage = conversation['last_message'];
    final lastMessageTime = conversation['last_message_time'];

    return GestureDetector(
      onTap: () {
        _markAsRead(conversation['id']);
        widget.onConversationTap?.call({
          'conversation_id': conversation['id'],
          'other_user': otherUser,
          'title': conversation['title'] ?? otherUser?['name'] ?? 'Conversation',
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isUnread ? danger.withOpacity(0.05) : Colors.white,
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: otherUser?['avatar'] != null
                      ? CachedNetworkImageProvider(otherUser!['avatar'])
                      : null,
                  child: otherUser?['avatar'] == null
                      ? Icon(Icons.person, size: 28, color: Colors.grey[400])
                      : null,
                ),
                if (otherUser?['is_online'] == true)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // Contenu
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation['title'] ?? otherUser?['name'] ?? 'Conversation',
                          style: TextStyle(
                            fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                            fontSize: 16,
                            color: navy,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatTime(lastMessageTime),
                        style: TextStyle(
                          fontSize: 11,
                          color: textMuted,
                          fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (conversation['is_typing'] == true)
                        const SizedBox(
                          width: 60,
                          child: Text(
                            'Écrit...',
                            style: TextStyle(
                              fontSize: 12,
                              color: gold,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: Text(
                            lastMessage ?? 'Dernier message',
                            style: TextStyle(
                              fontSize: 13,
                              color: isUnread ? navy : textMuted,
                              fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: danger,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'Aucune conversation',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navy),
          ),
          const SizedBox(height: 8),
          Text(
            'Commencez à discuter avec des vendeurs',
            style: TextStyle(color: textMuted),
          ),
        ],
      ),
    );
  }
}
