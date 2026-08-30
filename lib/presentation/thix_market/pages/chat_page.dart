// lib/presentation/thix_market/pages/chat_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const int _kMaxMessageLength = 2000;

// ============================================================================
// VALIDATEURS
// ============================================================================
class _ChatValidators {
  _ChatValidators._();

  static bool isValidId(String? id) {
    if (id == null || id.trim().isEmpty) return false;
    return RegExp(r'^[0-9a-fA-F-]{8,}$').hasMatch(id.trim());
  }

  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final t = url.trim();
    if (!t.startsWith('http://') && !t.startsWith('https://')) return null;
    return t.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  static String friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('permission') || msg.contains('policy')) return 'Accès non autorisé.';
    if (msg.contains('not found')) return 'Ressource introuvable.';
    if (msg.contains('duplicate')) return 'Cette ressource existe déjà.';
    return 'Une erreur est survenue. Réessayez.';
  }
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _withRetry<T>(
  Future<T> Function() fn, {
  required String label,
  int maxRetries = 1,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(_kRequestTimeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[Chat] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[Chat] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[Chat] ❌ $label error: $e');
      rethrow;
    }
  }
}

DateTime? _parseDate(String? s) {
  if (s == null || s.isEmpty) return null;
  try {
    return DateTime.parse(s);
  } catch (_) {
    return null;
  }
}

// ============================================================================
// MODÈLES TYPÉS
// ============================================================================
class ChatUser {
  final String id;
  final String name;
  final String? avatarUrl;

  const ChatUser({required this.id, required this.name, this.avatarUrl});

  String get initials => name
      .split(' ')
      .take(2)
      .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
      .join('');

  factory ChatUser.fromMap(Map<String, dynamic> map) {
    return ChatUser(
      id: map['id']?.toString() ?? '',
      name: _ChatValidators.sanitize(map['name']?.toString() ?? 'Utilisateur', maxLength: 60),
      avatarUrl: _ChatValidators.sanitizeUrl(map['avatar']?.toString()),
    );
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String? receiverId;
  final String text;
  final String? imageUrl;
  final DateTime createdAt;
  final bool isRead;

  const ChatMessage({
    required this.id,
    required this.senderId,
    this.receiverId,
    required this.text,
    this.imageUrl,
    required this.createdAt,
    this.isRead = false,
  });

  bool isOwn(String? currentUserId) => senderId == currentUserId;

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id']?.toString() ?? '',
      senderId: map['sender_id']?.toString() ?? '',
      receiverId: map['receiver_id']?.toString(),
      text: _ChatValidators.sanitize(map['message']?.toString() ?? '', maxLength: _kMaxMessageLength),
      imageUrl: _ChatValidators.sanitizeUrl(map['image_url']?.toString()),
      createdAt: _parseDate(map['created_at']?.toString()) ?? DateTime.now(),
      isRead: map['is_read'] == true,
    );
  }
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
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

  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isInitializing = true;
  bool _isSending = false;
  String? _error;
  String? _otherUserId;
  ChatUser? _otherUser;
  String? _currentUserId;
  String? _conversationId;
  bool _hasText = false;

  StreamSubscription<List<Map<String, dynamic>>>? _messagesSubscription;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _messageController.addListener(_onTextChanged);

    final convValid = _ChatValidators.isValidId(widget.conversationId);
    final shopValid = widget.shopId == null || _ChatValidators.isValidId(widget.shopId);
    debugPrint('[Chat] 💬 Page opened (conv=${widget.conversationId.substring(0, widget.conversationId.length > 8 ? 8 : widget.conversationId.length)}, shop=${widget.shopId?.substring(0, (widget.shopId?.length ?? 0) > 8 ? 8 : (widget.shopId?.length ?? 0))})');

    if (!convValid && !shopValid) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleInvalidIds());
    } else {
      _initializeChat();
    }
  }

  void _handleInvalidIds() {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    _showError('Identifiants invalides');
    context.pop();
  }

  void _onTextChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (hasText != _hasText && mounted) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  void dispose() {
    // IMPORTANT : annuler le stream pour éviter les fuites mémoire
    _messagesSubscription?.cancel();
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    debugPrint('[Chat] 👋 Page disposed');
    super.dispose();
  }

  // ============================================================
  // INITIALIZATION
  // ============================================================
  Future<void> _initializeChat() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Cas 1 : conversation existante
      if (_ChatValidators.isValidId(widget.conversationId)) {
        _conversationId = widget.conversationId;
        await _loadConversationDetails();
        await _fetchMessages();
        _subscribeToMessages();
        _markAsRead();
        debugPrint('[Chat] ✓ Loaded existing conversation');
      }
      // Cas 2 : shopId fourni
      else if (widget.shopId != null && _ChatValidators.isValidId(widget.shopId)) {
        await _initializeFromShop();
      }
      // Cas 3 : aucun ID valide
      else {
        setState(() => _error = 'Aucune conversation ou vendeur spécifié');
      }
    } catch (e) {
      final friendly = _ChatValidators.friendlyError(e);
      debugPrint('[Chat] ❌ Init error: $friendly');
      if (mounted) setState(() => _error = friendly);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _initializeFromShop() async {
    final shopResponse = await _withRetry(
      () => Supabase.instance.client.from('shops').select('owner_id').eq('id', widget.shopId!).single(),
      label: 'fetchShopOwner',
    );

    final sellerId = shopResponse['owner_id']?.toString();
    if (sellerId == null || !_ChatValidators.isValidId(sellerId)) {
      throw Exception('Vendeur introuvable');
    }
    _otherUserId = sellerId;

    // Recherche conversation existante
    // Note: contains sur array JSONB — syntaxe Supabase correcte
    final existingConv = await _withRetry(
      () => Supabase.instance.client
          .from('conversations')
          .select('id, participant_ids')
          .contains('participant_ids', [_currentUserId, sellerId])
          .maybeSingle(),
      label: 'findExistingConversation',
    );

    if (existingConv != null) {
      _conversationId = existingConv['id']?.toString();
      await _loadConversationDetails();
      await _fetchMessages();
      _subscribeToMessages();
      _markAsRead();
      debugPrint('[Chat] ✓ Reused existing conversation');
    } else {
      await _createNewConversation(sellerId);
    }
  }

  Future<void> _createNewConversation(String sellerId) async {
    final newConv = await _withRetry(
      () => Supabase.instance.client
          .from('conversations')
          .insert({
            'participant_ids': [_currentUserId, sellerId],
            'title': _ChatValidators.sanitize(widget.title ?? 'Discussion', maxLength: 100),
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single(),
      label: 'createConversation',
    );

    _conversationId = newConv['id']?.toString();

    // Insertion participants
    await _withRetry(
      () => Supabase.instance.client.from('conversation_participants').insert([
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
      ]),
      label: 'createParticipants',
    );

    // Récupération info vendeur
    final userResponse = await _withRetry(
      () => Supabase.instance.client.from('users').select('id, name, avatar').eq('id', sellerId).single(),
      label: 'fetchSellerInfo',
    );
    _otherUser = ChatUser.fromMap(userResponse);
    _messages = [];
    _subscribeToMessages();
    debugPrint('[Chat] ➕ Created new conversation');
  }

  // ============================================================
  // DATA LOADING
  // ============================================================
  Future<void> _loadConversationDetails() async {
    if (_conversationId == null) return;

    try {
      final response = await _withRetry(
        () => Supabase.instance.client
            .from('conversations')
            .select('participant_ids, title')
            .eq('id', _conversationId!)
            .single(),
        label: 'loadConversation',
      );

      final participants = List<String>.from(response['participant_ids'] ?? []);
      _otherUserId = participants.firstWhere(
        (id) => id != _currentUserId,
        orElse: () => '',
      );

      if (_ChatValidators.isValidId(_otherUserId)) {
        final userResponse = await _withRetry(
          () => Supabase.instance.client.from('users').select('id, name, avatar').eq('id', _otherUserId!).single(),
          label: 'loadOtherUser',
        );
        _otherUser = ChatUser.fromMap(userResponse);
      }
    } catch (e) {
      debugPrint('[Chat] ⚠️ Load conversation details error: $e');
    }
  }

  Future<void> _fetchMessages() async {
    if (_conversationId == null) return;
    setState(() => _isLoading = true);

    try {
      final response = await _withRetry(
        () => Supabase.instance.client
            .from('messages')
            .select('*')
            .eq('conversation_id', _conversationId!)
            .order('created_at', ascending: true),
        label: 'fetchMessages',
      );

      final list = (response as List)
          .map((m) => ChatMessage.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList();

      if (mounted) {
        setState(() {
          _messages = list;
          _isLoading = false;
        });
        _scrollToBottom();
      }
      debugPrint('[Chat] ✓ Loaded ${list.length} messages');
    } catch (e) {
      debugPrint('[Chat] ❌ Fetch messages error: $e');
      if (mounted) setState(() => _error = _ChatValidators.friendlyError(e));
    }
  }

  void _subscribeToMessages() {
    if (_conversationId == null) return;

    _messagesSubscription?.cancel();
    _messagesSubscription = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', _conversationId!)
        .order('created_at', ascending: true)
        .listen(
      (data) {
        if (!mounted) return;
        final newMessages = data.map((m) => ChatMessage.fromMap(Map<String, dynamic>.from(m))).toList();
        setState(() => _messages = newMessages);
        _scrollToBottom();
        _markAsRead();
      },
      onError: (e) {
        debugPrint('[Chat] ⚠️ Realtime stream error: $e');
      },
    );
    debugPrint('[Chat] 📡 Realtime subscription active');
  }

  Future<void> _markAsRead() async {
    if (_conversationId == null || _currentUserId == null) return;
    try {
      await _withRetry(
        () => Supabase.instance.client
            .from('conversation_participants')
            .update({'unread_count': 0, 'last_read_at': DateTime.now().toIso8601String()})
            .match({'conversation_id': _conversationId!, 'user_id': _currentUserId!}),
        label: 'markAsRead',
      );
    } catch (e) {
      debugPrint('[Chat] ⚠️ Mark as read error: $e');
    }
  }

  // ============================================================
  // ACTIONS
  // ============================================================
  Future<void> _sendMessage() async {
    if (_isSending) return;

    final text = _ChatValidators.sanitize(_messageController.text.trim(), maxLength: _kMaxMessageLength);
    if (text.isEmpty) {
      HapticFeedback.lightImpact();
      return;
    }

    if (_currentUserId == null) {
      HapticFeedback.lightImpact();
      context.push('/login');
      return;
    }

    if (_conversationId == null) {
      _showError('Conversation non initialisée');
      return;
    }

    setState(() => _isSending = true);
    HapticFeedback.selectionClick();

    try {
      await _withRetry(
        () => Supabase.instance.client.from('messages').insert({
          'conversation_id': _conversationId,
          'sender_id': _currentUserId,
          'receiver_id': _otherUserId,
          'message': text,
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        }),
        label: 'sendMessage',
      );

      await _withRetry(
        () => Supabase.instance.client
            .from('conversations')
            .update({
              'last_message': text,
              'last_message_time': DateTime.now().toIso8601String(),
            })
            .eq('id', _conversationId!),
        label: 'updateLastMessage',
      );

      _messageController.clear();
      _focusNode.unfocus();
      debugPrint('[Chat] ✉️ Message sent');
    } catch (e) {
      debugPrint('[Chat] ❌ Send error: $e');
      if (mounted) _showError('Erreur lors de l\'envoi');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _showMoreOptions() async {
    HapticFeedback.selectionClick();
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: ThixPolicy.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ChatOptionsSheet(otherUser: _otherUser),
    );

    if (result == null || !mounted) return;

    switch (result) {
      case 'profile':
        if (_otherUser != null) {
          context.push('/user/${_otherUser!.id}');
        }
        break;
      case 'block':
        _showInfo('Fonctionnalité en développement');
        break;
      case 'report':
        _showInfo('Signalement envoyé');
        break;
      case 'clear':
        _confirmClearHistory();
        break;
    }
  }

  Future<void> _confirmClearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Text('Effacer l\'historique ?', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
        content: Text(
          'Cela supprimera tous les messages de cette conversation. Cette action est irréversible.',
          style: ThixPolicy.bodyStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger, foregroundColor: Colors.white),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      _showInfo('Fonctionnalité en développement');
    }
  }

  void _openImage(String imageUrl) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ImageViewerPage(imageUrl: imageUrl),
      ),
    );
  }

  // ============================================================
  // HELPERS UI
  // ============================================================
  String _formatSmartTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return DateFormat('HH:mm').format(date);
    } else if (dateOnly == yesterday) {
      return 'Hier ${DateFormat('HH:mm').format(date)}';
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('EEE HH:mm', 'fr_FR').format(date);
    } else {
      return DateFormat('dd/MM/yy HH:mm').format(date);
    }
  }

  String _formatShortTime(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    if (_isLoading && _messages.isEmpty) {
      return Scaffold(
        backgroundColor: ThixPolicy.surfaceSoft,
        appBar: _buildAppBar(),
        body: const _SkeletonChat(),
      );
    }

    if (_error != null && _messages.isEmpty) {
      return Scaffold(
        backgroundColor: ThixPolicy.surfaceSoft,
        appBar: _buildAppBar(),
        body: _ErrorState(message: _error!, onRetry: _initializeChat),
      );
    }

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const _EmptyState()
                : _buildMessagesList(),
          ),
          _MessageInput(
            controller: _messageController,
            focusNode: _focusNode,
            hasText: _hasText,
            isSending: _isSending,
            onSend: _sendMessage,
            onAttach: () => _showInfo('Pièces jointes en développement'),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final avatarUrl = _ChatValidators.sanitizeUrl(widget.avatar) ?? _otherUser?.avatarUrl;
    final title = widget.title ?? _otherUser?.name ?? 'Discussion';

    return AppBar(
      backgroundColor: ThixPolicy.card,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: ThixPolicy.textMain),
        tooltip: 'Retour',
        onPressed: () {
          HapticFeedback.selectionClick();
          context.pop();
        },
      ),
      title: Semantics(
        button: _otherUser != null,
        label: 'Discussion avec $title',
        child: GestureDetector(
          onTap: _otherUser != null ? () => context.push('/user/${_otherUser!.id}') : null,
          child: Row(
            children: [
              _ChatAvatar(url: avatarUrl, name: title, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: ThixPolicy.labelStyle.copyWith(
                        color: ThixPolicy.textMain,
                        fontWeight: ThixPolicy.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_otherUser != null)
                      Text(
                        'En ligne',
                        style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.success, fontSize: 11),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Semantics(
          button: true,
          label: 'Options de discussion',
          child: IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: ThixPolicy.textMain),
            tooltip: 'Options',
            onPressed: _showMoreOptions,
          ),
        ),
      ],
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final previous = index > 0 ? _messages[index - 1] : null;
        final next = index < _messages.length - 1 ? _messages[index + 1] : null;

        final isFirst = previous == null || previous.senderId != message.senderId ||
            message.createdAt.difference(previous.createdAt).inMinutes > 5;
        final isLast = next == null || next.senderId != message.senderId ||
            next.createdAt.difference(message.createdAt).inMinutes > 5;

        // Séparateur de jour
        final showDateSeparator = previous == null ||
            !_isSameDay(previous.createdAt, message.createdAt);

        return Column(
          children: [
            if (showDateSeparator) _DateSeparator(date: message.createdAt),
            _MessageBubble(
              message: message,
              isOwn: message.isOwn(_currentUserId),
              isFirst: isFirst,
              isLast: isLast,
              otherUser: _otherUser,
              formatTime: _formatShortTime,
              onImageTap: message.imageUrl != null ? () => _openImage(message.imageUrl!) : null,
            ),
          ],
        );
      },
    );
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }
}

// ============================================================================
// COMPOSANTS RÉUTILISABLES
// ============================================================================

class _ChatAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final double size;

  const _ChatAvatar({required this.url, required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [ThixPolicy.primary, ThixPolicy.primary.withOpacity(0.7)],
          ),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: ThixPolicy.labelStyle.copyWith(
              color: Colors.white,
              fontWeight: ThixPolicy.bold,
              fontSize: size / 2.5,
            ),
          ),
        ),
      );
    }
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: size,
          height: size,
          color: ThixPolicy.surfaceSoft,
          child: const Center(
            child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          width: size,
          height: size,
          color: ThixPolicy.surfaceSoft,
          child: Icon(Icons.person_rounded, size: size / 2, color: ThixPolicy.textMuted),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isOwn;
  final bool isFirst;
  final bool isLast;
  final ChatUser? otherUser;
  final String Function(DateTime) formatTime;
  final VoidCallback? onImageTap;

  const _MessageBubble({
    required this.message,
    required this.isOwn,
    required this.isFirst,
    required this.isLast,
    required this.otherUser,
    required this.formatTime,
    this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasText = message.text.isNotEmpty;
    final hasImage = message.imageUrl != null;
    final showAvatar = !isOwn && isLast;

    return Semantics(
      label: '${isOwn ? "Vous" : (otherUser?.name ?? "Autre")}, ${formatTime(message.createdAt)}: ${message.text}',
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          top: isFirst ? 8 : 2,
          bottom: isLast ? 4 : 2,
        ),
        child: Row(
          mainAxisAlignment: isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isOwn && showAvatar)
              _ChatAvatar(url: otherUser?.avatarUrl, name: otherUser?.name ?? 'U', size: 28)
            else if (!isOwn)
              const SizedBox(width: 28),
            if (!isOwn) const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: hasImage ? 6 : 12,
                  vertical: hasImage ? 6 : 8,
                ),
                decoration: BoxDecoration(
                  color: isOwn ? ThixPolicy.primary : ThixPolicy.card,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isOwn ? 16 : (isLast ? 4 : 16)),
                    bottomRight: Radius.circular(isOwn ? (isLast ? 4 : 16) : 16),
                  ),
                  border: isOwn ? null : Border.all(color: ThixPolicy.border.withOpacity(0.6)),
                  boxShadow: ThixPolicy.shadowSoft(opacity: 0.04),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasImage)
                      GestureDetector(
                        onTap: onImageTap,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: message.imageUrl!,
                            height: 150,
                            width: 200,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              height: 150,
                              width: 200,
                              color: ThixPolicy.surfaceSoft,
                              child: const Center(
                                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              height: 150,
                              width: 200,
                              color: ThixPolicy.surfaceSoft,
                              child: const Icon(Icons.broken_image_outlined, color: ThixPolicy.textMuted),
                            ),
                          ),
                        ),
                      ),
                    if (hasImage && hasText) const SizedBox(height: 8),
                    if (hasText)
                      Text(
                        message.text,
                        style: ThixPolicy.bodySmallStyle.copyWith(
                          color: isOwn ? Colors.white : ThixPolicy.textMain,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatTime(message.createdAt),
                          style: ThixPolicy.microStyle.copyWith(
                            fontSize: 10,
                            color: isOwn ? Colors.white70 : ThixPolicy.textMuted,
                          ),
                        ),
                        if (isOwn) ...[
                          const SizedBox(width: 4),
                          Icon(
                            message.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                            size: 12,
                            color: message.isRead ? Colors.lightBlueAccent : Colors.white70,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (isOwn) const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _MessageInput extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasText;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  const _MessageInput({
    required this.controller,
    required this.focusNode,
    required this.hasText,
    required this.isSending,
    required this.onSend,
    required this.onAttach,
  });

  @override
  State<_MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<_MessageInput> {
  @override
  Widget build(BuildContext context) {
    final canSend = widget.hasText && !widget.isSending;

    return Container(
      padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, -2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Semantics(
            button: true,
            label: 'Joindre un fichier',
            child: IconButton(
              icon: const Icon(Icons.attach_file_rounded, color: ThixPolicy.textMuted),
              tooltip: 'Joindre',
              onPressed: widget.isSending ? null : widget.onAttach,
            ),
          ),
          Expanded(
            child: Semantics(
              label: 'Champ de message',
              child: Container(
                decoration: BoxDecoration(
                  color: ThixPolicy.surfaceSoft,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  maxLength: _kMaxMessageLength,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMain),
                  decoration: InputDecoration(
                    hintText: 'Écrire un message...',
                    hintStyle: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    counterText: '',
                  ),
                  onSubmitted: (_) => canSend ? widget.onSend() : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: canSend ? 'Envoyer le message' : 'Champ vide',
            enabled: canSend,
            child: GestureDetector(
              onTap: canSend ? widget.onSend : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: canSend ? ThixPolicy.primary : ThixPolicy.border,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: widget.isSending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(
                          Icons.send_rounded,
                          color: canSend ? Colors.white : ThixPolicy.textMuted,
                          size: 18,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    String label;
    if (dateOnly == today) {
      label = 'Aujourd\'hui';
    } else if (dateOnly == yesterday) {
      label = 'Hier';
    } else if (now.difference(date).inDays < 7) {
      label = DateFormat('EEEE', 'fr_FR').format(date);
    } else {
      label = DateFormat('dd MMMM yyyy', 'fr_FR').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: ThixPolicy.border.withOpacity(0.5))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: ThixPolicy.captionStyle.copyWith(
                color: ThixPolicy.textMuted,
                fontSize: 11,
                fontWeight: ThixPolicy.semiBold,
              ),
            ),
          ),
          Expanded(child: Divider(color: ThixPolicy.border.withOpacity(0.5))),
        ],
      ),
    );
  }
}

class _ChatOptionsSheet extends StatelessWidget {
  final ChatUser? otherUser;
  const _ChatOptionsSheet({required this.otherUser});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, top: 12, left: 20, right: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text('Options', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain)),
          const SizedBox(height: 16),
          _OptionTile(
            icon: Icons.person_outline_rounded,
            label: 'Voir le profil',
            onTap: () => Navigator.pop(context, 'profile'),
            enabled: otherUser != null,
          ),
          _OptionTile(
            icon: Icons.block_rounded,
            label: 'Bloquer',
            onTap: () => Navigator.pop(context, 'block'),
            color: ThixPolicy.danger,
          ),
          _OptionTile(
            icon: Icons.flag_outlined,
            label: 'Signaler',
            onTap: () => Navigator.pop(context, 'report'),
            color: ThixPolicy.warning,
          ),
          _OptionTile(
            icon: Icons.delete_sweep_rounded,
            label: 'Effacer l\'historique',
            onTap: () => Navigator.pop(context, 'clear'),
            color: ThixPolicy.danger,
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool enabled;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final finalColor = color ?? ThixPolicy.textMain;
    return Semantics(
      button: true,
      label: label,
      enabled: enabled,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: enabled ? finalColor : ThixPolicy.textDisabled),
        title: Text(
          label,
          style: ThixPolicy.labelStyle.copyWith(
            color: enabled ? finalColor : ThixPolicy.textDisabled,
            fontWeight: ThixPolicy.semiBold,
          ),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: enabled ? ThixPolicy.textMuted : ThixPolicy.textDisabled),
        onTap: enabled ? () {
          HapticFeedback.selectionClick();
          onTap();
        } : null,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: ThixPolicy.primary.withOpacity(0.05), shape: BoxShape.circle),
            child: const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: ThixPolicy.textMuted),
          ),
          const SizedBox(height: 12),
          Text('Aucun message', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain)),
          const SizedBox(height: 4),
          Text('Soyez le premier à envoyer un message', style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: ThixPolicy.danger.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded, size: 56, color: ThixPolicy.danger),
            ),
            const SizedBox(height: 20),
            Text('Erreur de chargement', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain)),
            const SizedBox(height: 8),
            Text(message, style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                onRetry();
              },
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text('Réessayer', style: TextStyle(fontWeight: ThixPolicy.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonChat extends StatelessWidget {
  const _SkeletonChat();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 6,
      itemBuilder: (_, i) => Align(
        alignment: i % 2 == 0 ? Alignment.centerLeft : Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          width: MediaQuery.of(context).size.width * 0.6,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 12, color: Colors.grey.shade300),
              const SizedBox(height: 6),
              Container(height: 10, width: 80, color: Colors.grey.shade300),
            ],
          ),
        ),
      ),
    );
  }
}

// Viewer pour images en plein écran
class _ImageViewerPage extends StatelessWidget {
  final String imageUrl;
  const _ImageViewerPage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white, size: 64),
          ),
        ),
      ),
    );
  }
}
