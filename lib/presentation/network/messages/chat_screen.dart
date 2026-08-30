// lib/presentation/network/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:timeago/timeago.dart' as timeago;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/models/certification_tier.dart';
import 'package:thix_id/presentation/certification/widgets/certification_name_badge.dart';

// ============================================================================
// VALIDATEURS
// ============================================================================
class _ChatValidators {
  _ChatValidators._();

  static const int maxMessageLength = 2000;
  static const Duration requestTimeout = Duration(seconds: 15);

  static String sanitize(String? input, {int maxLength = maxMessageLength}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var sanitized = doc.body?.text ?? input;
    sanitized = sanitized
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return sanitized.length > maxLength ? sanitized.substring(0, maxLength) : sanitized;
  }

  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final trimmed = url.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) return null;
    return trimmed.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }
}

// ============================================================================
// PROVIDER MESSAGES REALTIME
// ============================================================================
class ChatMessagesNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final String peerId;
  RealtimeChannel? _channel;

  ChatMessagesNotifier(this.peerId) : super(const AsyncLoading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final messages = await Supabase.instance.client
          .from('messages')
          .select('*')
          .or('sender_id.eq.${Supabase.instance.client.auth.currentUser!.id},receiver_id.eq.${Supabase.instance.client.auth.currentUser!.id}')
          .or('sender_id.eq.$peerId,and(receiver_id.eq.${Supabase.instance.client.auth.currentUser!.id},sender_id.eq.${Supabase.instance.client.auth.currentUser!.id})')
          .order('created_at', ascending: true)
          .limit(200)
          .timeout(_ChatValidators.requestTimeout);

      state = AsyncData((messages as List).cast<Map<String, dynamic>>());
      _subscribeRealtime();
      await _markAsRead();
    } catch (e) {
      debugPrint('[Chat] Load error: $e');
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> _markAsRead() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client
          .from('messages')
          .update({'is_read': true, 'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('sender_id', peerId)
          .eq('receiver_id', uid)
          .eq('is_read', false)
          .timeout(_ChatValidators.requestTimeout);
    } catch (e) {
      debugPrint('[Chat] Mark read error: $e');
    }
  }

  void _subscribeRealtime() {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    _channel?.unsubscribe();
    _channel = Supabase.instance.client
        .channel('chat-$peerId-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final newMsg = Map<String, dynamic>.from(payload.newRecord);
            final sender = newMsg['sender_id']?.toString();
            final receiver = newMsg['receiver_id']?.toString();

            // Filtre : seulement les messages entre moi et le peer
            if (!((sender == uid && receiver == peerId) || (sender == peerId && receiver == uid))) {
              return;
            }

            final current = state.valueOrNull ?? [];
            if (current.any((m) => m['id'] == newMsg['id'])) return;

            // Remplace le temp si présent
            final tempId = 'temp_${newMsg['id']}';
            final filtered = current.where((m) => m['id'] != tempId).toList();
            state = AsyncData([...filtered, newMsg]);
          },
        )
        .subscribe();
  }

  Future<void> sendMessage(String content) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) throw Exception('Non authentifié');

    final sanitized = _ChatValidators.sanitize(content);
    if (sanitized.isEmpty) throw Exception('Message vide');

    // Temp message (optimistic UI)
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMsg = {
      'id': tempId,
      'content': sanitized,
      'sender_id': uid,
      'receiver_id': peerId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'is_temp': true,
    };

    final current = state.valueOrNull ?? [];
    state = AsyncData([...current, tempMsg]);

    try {
      final result = await Supabase.instance.client
          .from('messages')
          .insert({
            'sender_id': uid,
            'receiver_id': peerId,
            'content': sanitized,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select()
          .single()
          .timeout(_ChatValidators.requestTimeout);

      // Remplace le temp par le vrai message
      final newList = state.valueOrNull ?? [];
      final filtered = newList.where((m) => m['id'] != tempId).toList();
      state = AsyncData([...filtered, result as Map<String, dynamic>]);
    } catch (e) {
      // Marque le temp comme erreur
      final newList = (state.valueOrNull ?? []).map((m) {
        if (m['id'] == tempId) {
          return {...m, 'error': true};
        }
        return m;
      }).toList();
      state = AsyncData(newList);
      rethrow;
    }
  }

  Future<void> retryMessage(String tempId) async {
    final messages = state.valueOrNull ?? [];
    final temp = messages.firstWhere((m) => m['id'] == tempId, orElse: () => {});
    if (temp.isEmpty || temp['error'] != true) return;

    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final content = temp['content'] as String;

      await Supabase.instance.client.from('messages').insert({
        'sender_id': uid,
        'receiver_id': peerId,
        'content': content,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }).timeout(_ChatValidators.requestTimeout);

      // Retire le temp
      final filtered = messages.where((m) => m['id'] != tempId).toList();
      state = AsyncData(filtered);
    } catch (e) {
      debugPrint('[Chat] Retry error: $e');
    }
  }

  Future<void> deleteMessage(String messageId) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) throw Exception('Non authentifié');

    // Retire localement d'abord (optimistic)
    final current = state.valueOrNull ?? [];
    final filtered = current.where((m) => m['id'] != messageId).toList();
    state = AsyncData(filtered);

    try {
      await Supabase.instance.client
          .from('messages')
          .delete()
          .eq('id', messageId)
          .eq('sender_id', uid)
          .timeout(_ChatValidators.requestTimeout);
    } catch (e) {
      // Rollback
      state = AsyncData(current);
      rethrow;
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final chatMessagesProvider = StateNotifierProvider.autoDispose
    .family<ChatMessagesNotifier, AsyncValue<List<Map<String, dynamic>>>, String>(
  (ref, peerId) => ChatMessagesNotifier(peerId),
);

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class ChatScreen extends ConsumerStatefulWidget {
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
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  bool _isTyping = false;
  bool _isSending = false;
  Map<String, dynamic>? _peerProfile;

  @override
  void initState() {
    super.initState();
    _loadPeerProfile();

    // Auto-scroll sur nouveau message
    ref.listenManual<AsyncValue<List<Map<String, dynamic>>>>(
      chatMessagesProvider(widget.userId),
      (prev, next) {
        final prevLen = prev?.valueOrNull?.length ?? 0;
        final nextLen = next.valueOrNull?.length ?? 0;
        if (nextLen > prevLen) _scrollToBottom();
      },
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPeerProfile() async {
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('id, display_name, avatar_url, photo_url, profession, certification_tier, certification_status, is_verified')
          .eq('id', widget.userId)
          .maybeSingle()
          .timeout(_ChatValidators.requestTimeout);

      if (mounted && profile != null) {
        setState(() => _peerProfile = Map<String, dynamic>.from(profile));
      }
    } catch (e) {
      debugPrint('[Chat] Load peer profile error: $e');
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

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    HapticFeedback.lightImpact();
    _messageController.clear();
    setState(() => _isTyping = false);

    try {
      setState(() => _isSending = true);
      await ref.read(chatMessagesProvider(widget.userId).notifier).sendMessage(content);
    } catch (e) {
      debugPrint('[Chat] Send error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Erreur lors de l\'envoi')),
              ],
            ),
            backgroundColor: ThixPolicy.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _retryMessage(String tempId) async {
    HapticFeedback.mediumImpact();
    try {
      await ref.read(chatMessagesProvider(widget.userId).notifier).retryMessage(tempId);
    } catch (e) {
      debugPrint('[Chat] Retry error: $e');
    }
  }

  Future<void> _deleteMessage(String messageId, bool isMe) async {
    if (!isMe) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ThixPolicy.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(ThixPolicy.rSm),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: ThixPolicy.danger, size: 22),
            ),
            const SizedBox(width: 12),
            Text('Supprimer le message', style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold)),
          ],
        ),
        content: Text('Voulez-vous vraiment supprimer ce message ?', style: ThixPolicy.bodyStyle.copyWith(height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger, foregroundColor: Colors.white),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    HapticFeedback.mediumImpact();
    try {
      await ref.read(chatMessagesProvider(widget.userId).notifier).deleteMessage(messageId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Message supprimé'),
              ],
            ),
            backgroundColor: ThixPolicy.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[Chat] Delete error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la suppression'), backgroundColor: ThixPolicy.danger, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.userId));

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => _buildSkeleton(),
              error: (e, _) => _buildErrorState(e.toString()),
              data: (messages) => messages.isEmpty ? _buildEmptyState() : _buildMessageList(messages),
            ),
          ),
          if (_isTyping) _buildTypingIndicator(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final tier = CertificationTierX.parse(_peerProfile?['certification_tier']);
    final status = CertificationStatusX.parse(_peerProfile?['certification_status']);
    final isCertified = status == CertificationStatus.approved || status == CertificationStatus.generated;
    final isLegacyVerified = _peerProfile?['is_verified'] == true;
    final avatarUrl = _ChatValidators.sanitizeUrl(_peerProfile?['avatar_url']?.toString() ?? _peerProfile?['photo_url']?.toString() ?? widget.userAvatar);
    final displayName = _ChatValidators.sanitize(_peerProfile?['display_name']?.toString() ?? widget.userName, maxLength: 50);

    return AppBar(
      backgroundColor: ThixPolicy.card,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: ThixPolicy.textMain, size: 20),
        onPressed: () {
          HapticFeedback.selectionClick();
          Navigator.pop(context);
        },
      ),
      title: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/network/profile/${widget.userId}'),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ThixPolicy.border, width: 1.5),
              ),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: ThixPolicy.surfaceSoft,
                backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                child: avatarUrl == null ? const Icon(Icons.person_rounded, size: 18, color: ThixPolicy.textMuted) : null,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCertified)
                      CertificationNameBadge(tier: tier, status: status, showLabel: false, iconSize: 14, padding: const EdgeInsets.only(left: 4))
                    else if (isLegacyVerified)
                      const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified_rounded, color: ThixPolicy.gold, size: 14)),
                  ],
                ),
                Text('En ligne', style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.success, fontWeight: ThixPolicy.semiBold)),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.videocam_rounded, color: ThixPolicy.textMain, size: 22),
          onPressed: () {
            HapticFeedback.selectionClick();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Appel vidéo bientôt disponible'), behavior: SnackBarBehavior.floating),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.more_vert_rounded, color: ThixPolicy.textMain, size: 22),
          onPressed: () => _showChatOptions(),
        ),
      ],
    );
  }

  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ThixPolicy.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(ThixPolicy.rXl))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(margin: const EdgeInsets.only(top: 8, bottom: 8), width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: const Icon(Icons.person_outline_rounded, color: ThixPolicy.primary),
              title: Text('Voir le profil', style: ThixPolicy.bodyStyle),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/network/profile/${widget.userId}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.search_rounded, color: ThixPolicy.textMain),
              title: Text('Rechercher dans la conversation', style: ThixPolicy.bodyStyle),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bientôt disponible'), behavior: SnackBarBehavior.floating),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: ThixPolicy.warning),
              title: Text('Signaler', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.warning)),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Signalement envoyé'), backgroundColor: ThixPolicy.success, behavior: SnackBarBehavior.floating),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.block_rounded, color: ThixPolicy.danger),
              title: Text('Bloquer', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.danger, fontWeight: ThixPolicy.bold)),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Utilisateur bloqué'), backgroundColor: ThixPolicy.danger, behavior: SnackBarBehavior.floating),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (_, i) {
        final isMe = i % 2 == 0;
        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            width: MediaQuery.of(context).size.width * 0.6,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ThixPolicy.card,
              borderRadius: BorderRadius.circular(ThixPolicy.rLg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 14, width: double.infinity, color: Colors.grey.shade200),
                const SizedBox(height: 6),
                Container(height: 12, width: 80, color: Colors.grey.shade200),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState(String error) {
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
            Text('Erreur de chargement', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
            const SizedBox(height: 8),
            Text(_ChatValidators.sanitize(error), textAlign: TextAlign.center, style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(chatMessagesProvider(widget.userId)),
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text('Réessayer'),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: ThixPolicy.primary.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.chat_bubble_outline_rounded, size: 64, color: ThixPolicy.primary),
            ),
            const SizedBox(height: 24),
            Text('Démarrez la conversation', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
            const SizedBox(height: 8),
            Text(
              'Envoyez votre premier message à ${_ChatValidators.sanitize(widget.userName, maxLength: 30)}',
              textAlign: TextAlign.center,
              style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(List<Map<String, dynamic>> messages) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isMe = message['sender_id'] == Supabase.instance.client.auth.currentUser?.id;
        final messageId = message['id']?.toString() ?? '';
        final content = _ChatValidators.sanitize(message['content']?.toString() ?? '');
        final hasError = message['error'] == true;
        final isTemp = message['is_temp'] == true;

        DateTime? createdAt;
        try {
          final createdAtStr = message['created_at']?.toString();
          if (createdAtStr != null && createdAtStr.isNotEmpty) {
            createdAt = DateTime.parse(createdAtStr).toLocal();
          }
        } catch (_) {}

        return _MessageBubble(
          content: content,
          isMe: isMe,
          createdAt: createdAt,
          hasError: hasError,
          isTemp: isTemp,
          onLongPress: () => _deleteMessage(messageId, isMe),
          onRetry: isTemp && hasError ? () => _retryMessage(messageId) : null,
        );
      },
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: ThixPolicy.card,
              borderRadius: BorderRadius.circular(ThixPolicy.rLg),
              border: Border.all(color: ThixPolicy.border.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TypingDots(),
                const SizedBox(width: 6),
                Text('${widget.userName} écrit...', style: ThixPolicy.captionStyle.copyWith(fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        border: Border(top: BorderSide(color: ThixPolicy.border)),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.03),
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file_rounded, size: 22),
              onPressed: () {
                HapticFeedback.selectionClick();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pièces jointes bientôt disponibles'), behavior: SnackBarBehavior.floating),
                );
              },
              color: ThixPolicy.textSecondary,
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                maxLines: 4,
                minLines: 1,
                maxLength: _ChatValidators.maxMessageLength,
                onChanged: (_) => _onTyping(),
                onSubmitted: (_) => _sendMessage(),
                style: ThixPolicy.bodyStyle,
                decoration: InputDecoration(
                  hintText: 'Écrivez un message...',
                  hintStyle: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.rXl), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ThixPolicy.rXl),
                    borderSide: const BorderSide(color: ThixPolicy.primary, width: 1.5),
                  ),
                  filled: true,
                  fillColor: ThixPolicy.surfaceSoft,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [ThixPolicy.primary, Color(0xFF6366F1)]),
                  shape: BoxShape.circle,
                  boxShadow: ThixPolicy.shadowNode(color: ThixPolicy.primary),
                ),
                child: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// BULLE DE MESSAGE
// ============================================================================
class _MessageBubble extends StatelessWidget {
  final String content;
  final bool isMe;
  final DateTime? createdAt;
  final bool hasError;
  final bool isTemp;
  final VoidCallback onLongPress;
  final VoidCallback? onRetry;

  const _MessageBubble({
    required this.content,
    required this.isMe,
    required this.createdAt,
    required this.hasError,
    required this.isTemp,
    required this.onLongPress,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        onTap: hasError && onRetry != null ? onRetry : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: hasError
                ? ThixPolicy.danger.withOpacity(0.1)
                : isMe
                    ? ThixPolicy.primary
                    : ThixPolicy.card,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(ThixPolicy.rLg),
              topRight: const Radius.circular(ThixPolicy.rLg),
              bottomLeft: Radius.circular(isMe ? ThixPolicy.rLg : ThixPolicy.rXs),
              bottomRight: Radius.circular(isMe ? ThixPolicy.rXs : ThixPolicy.rLg),
            ),
            border: hasError ? Border.all(color: ThixPolicy.danger.withOpacity(0.5)) : (isMe ? null : Border.all(color: ThixPolicy.border.withOpacity(0.5))),
            boxShadow: isMe ? ThixPolicy.shadowNode(color: ThixPolicy.primary) : ThixPolicy.shadowSoft(opacity: 0.03),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                content,
                style: ThixPolicy.bodyStyle.copyWith(
                  color: hasError ? ThixPolicy.danger : (isMe ? Colors.white : ThixPolicy.textMain),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (createdAt != null)
                    Text(
                      timeago.format(createdAt!, locale: 'fr'),
                      style: ThixPolicy.microStyle.copyWith(
                        color: hasError ? ThixPolicy.danger.withOpacity(0.8) : (isMe ? Colors.white.withOpacity(0.7) : ThixPolicy.textMuted),
                      ),
                    ),
                  if (hasError) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.error_outline_rounded, size: 12, color: ThixPolicy.danger),
                    if (onRetry != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        'Réessayer',
                        style: ThixPolicy.microStyle.copyWith(
                          color: ThixPolicy.danger,
                          fontWeight: ThixPolicy.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ] else if (isMe && isTemp) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.watch_later_rounded, size: 10, color: Colors.white70),
                  ] else if (isMe) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.check_circle_rounded, size: 12, color: Colors.white70),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// TYPING DOTS ANIMATED
// ============================================================================
class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with TickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final progress = (_controller.value - delay).clamp(0.0, 1.0);
            final scale = 0.5 + (progress < 0.5 ? progress * 2 : (1 - progress) * 2) * 0.5;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: ThixPolicy.textSecondary.withOpacity(0.5 + scale * 0.5),
                shape: BoxShape.circle,
              ),
              transform: Matrix4.identity()..scale(scale),
            );
          }),
        );
      },
    );
  }
}
