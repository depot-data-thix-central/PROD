// lib/presentation/thix_weeding/pages/staff/messages/chat_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// CENTRAUX - on utilise que MessageModel + messagesProvider pour refresh list
import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';
class ChatDetailPage extends ConsumerStatefulWidget {
  final String weddingId;
  final String guestIdOrName;
  final String? guestName;
  const ChatDetailPage({super.key, required this.weddingId, required this.guestIdOrName, this.guestName});
  @override
  ConsumerState<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends ConsumerState<ChatDetailPage> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<MessageModel> _messages = [];
  bool _isLoading = true;
  late final RealtimeChannel _channel;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeRealtime();
  }

  // ================= DATA =================

  Future<void> _loadMessages() async {
    final supa = Supabase.instance.client;
    try {
      List<dynamic> res;
      try {
        res = await supa.from('thix_weeding_messages').select().eq('wedding_id', widget.weddingId).or('guest_id.eq.${widget.guestIdOrName},sender_name.eq.${widget.guestIdOrName}').order('created_at', ascending: true);
      } catch (_) {
        res = await supa.from('thix_weeding_messages').select().eq('wedding_id', widget.weddingId).order('created_at', ascending: true);
      }
      _messages = res.map((e) => MessageModel.fromJson(e)).toList();
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _markAsRead();
      _jumpToBottom();
    }
  }

  void _subscribeRealtime() {
    _channel = Supabase.instance.client
        .channel('chat_\( {widget.weddingId}_ \){widget.guestIdOrName}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'thix_weeding_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'wedding_id',
            value: widget.weddingId,
          ),
          callback: (payload) {
            final newMsg = MessageModel.fromJson(payload.newRecord);
            if (newMsg.guestId == widget.guestIdOrName ||
                newMsg.senderName == widget.guestIdOrName ||
                widget.guestIdOrName.length > 20) {
              setState(() => _messages.add(newMsg));
              _jumpToBottom();
            }
          },
        )
        .subscribe();
  }

  Future<void> _markAsRead() async {
    await Supabase.instance.client.from('thix_weeding_messages').update({'is_read': true}).eq('wedding_id', widget.weddingId).eq('is_read', false);
    ref.invalidate(messagesProvider(widget.weddingId));
  }

  Future<void> _send() async {
    if (_inputCtrl.text.trim().isEmpty) return;
    final text = _inputCtrl.text.trim();
    _inputCtrl.clear();

    await Supabase.instance.client.from('thix_weeding_messages').insert({
      'wedding_id': widget.weddingId,
      'guest_id': widget.guestIdOrName.length > 20 ? widget.guestIdOrName : null,
      'sender_name': 'Staff',
      'sender_type': 'staff',
      'content': text,
      'is_read': false,
    });
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent + 200, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  @override
  void dispose() {
    _channel.unsubscribe();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.guestName ?? widget.guestIdOrName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('ID: ${widget.guestIdOrName.substring(0, 8)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ]),
        ),
        body: Column(children: [
          Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator()) : _messages.isEmpty ? const Center(child: Text('Aucun message, commencez la discussion')) : _MessageList(messages: _messages, scrollCtrl: _scrollCtrl)),
          _InputBar(controller: _inputCtrl, onSend: _send),
        ]),
      );
}

// ================= INTERNES =================

class _MessageList extends StatelessWidget {
  final List<MessageModel> messages; final ScrollController scrollCtrl;
  const _MessageList({required this.messages, required this.scrollCtrl});
  @override
  Widget build(BuildContext context) => ListView.builder(
        controller: scrollCtrl,
        padding: const EdgeInsets.all(16),
        itemCount: messages.length,
        itemBuilder: (_, i) {
          final MessageModel m = messages[i];
          final isMe = m.senderType == 'staff';
          return _Bubble(message: m, isMe: isMe);
        },
      );
}

class _Bubble extends StatelessWidget {
  final MessageModel message; final bool isMe;
  const _Bubble({required this.message, required this.isMe});
  @override
  Widget build(BuildContext context) => Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFF0B3B8F) : Colors.white,
            borderRadius: BorderRadius.circular(16).copyWith(bottomRight: isMe ? const Radius.circular(4) : null, bottomLeft: !isMe ? const Radius.circular(4) : null),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(message.content, style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
            const SizedBox(height: 4),
            Text('${message.createdAt.toString().substring(11, 16)} • ${message.id.substring(0, 4)}', style: TextStyle(fontSize: 9, color: isMe ? Colors.white70 : Colors.grey)),
          ]),
        ),
      );
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller; final VoidCallback onSend;
  const _InputBar({required this.controller, required this.onSend});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        color: Colors.white,
        child: Row(children: [
          Expanded(child: TextField(controller: controller, decoration: InputDecoration(hintText: 'Écrire un message...', filled: true, fillColor: const Color(0xFFF1F5F9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)), onSubmitted: (_) => onSend())),
          const SizedBox(width: 8),
          CircleAvatar(backgroundColor: const Color(0xFF0B3B8F), child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: onSend)),
        ]),
      );
}
