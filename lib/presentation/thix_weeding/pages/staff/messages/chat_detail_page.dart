// lib/presentation/thix_weeding/pages/staff/messages/chat_detail_page.dart
// ============================================================================
// THIX WEDDING — CHAT STAFF ↔ INVITÉ (PRODUCTION v2)
// ✅ Photos (jusqu'à 4 par message), visionneuse plein écran
// ✅ Types : Message / Info perso (à cet invité) / Annonce à tous (publiée)
// ✅ Corrige : canal realtime, « lu » limité à cette discussion, crash substring
// ✅ Verre dépoli
// ============================================================================
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// CENTRAUX
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';
import 'package:thix_id/presentation/thix_weeding/widgets/thix_glass.dart';

import 'message_media.dart';

class _C {
  static const blue = Color(0xFF0B3B8F);
  static const blue2 = Color(0xFF1E5BC6);
  static const rose = Color(0xFFE31C4E);
  static const green = Color(0xFF059669);
  static const ink = Color(0xFF111827);
  static const ink2 = Color(0xFF6B7280);
}

class ChatDetailPage extends ConsumerStatefulWidget {
  final String weddingId;
  final String guestIdOrName;
  final String? guestName;
  const ChatDetailPage({super.key, required this.weddingId, required this.guestIdOrName, this.guestName});
  @override
  ConsumerState<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends ConsumerState<ChatDetailPage> {
  final _supa = Supabase.instance.client;
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _sending = false;
  RealtimeChannel? _channel;

  String _type = 'chat'; // chat | info | announcement
  String _tag = 'INFO';
  final List<PickedPhoto> _pending = [];

  bool get _isGuestId => RegExp(r'^[0-9a-fA-F-]{32,36}$').hasMatch(widget.guestIdOrName);
  String get _title => widget.guestName ?? widget.guestIdOrName;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeRealtime();
  }

  // ================= DATA =================

  bool _matches(Map<String, dynamic> m) => _isGuestId
      ? '${m['guest_id']}' == widget.guestIdOrName
      : '${m['sender_name']}' == widget.guestIdOrName;

  Future<void> _loadMessages() async {
    try {
      final base = _supa.from('thix_weeding_messages').select().eq('wedding_id', widget.weddingId);
      final res = await (_isGuestId
              ? base.eq('guest_id', widget.guestIdOrName)
              : base.eq('sender_name', widget.guestIdOrName))
          .order('created_at', ascending: true);
      _messages = (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      _toast('Chargement : $e', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _markAsRead();
      _jumpToBottom();
    }
  }

  void _subscribeRealtime() {
    _channel = _supa
        .channel('chat_${widget.weddingId}_${widget.guestIdOrName}')
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
            final rec = Map<String, dynamic>.from(payload.newRecord);
            if (!_matches(rec)) return;
            if (_messages.any((m) => '${m['id']}' == '${rec['id']}')) return;
            if (!mounted) return;
            setState(() => _messages.add(rec));
            _jumpToBottom();
            if (rec['sender_type'] == 'guest') _markAsRead();
          },
        )
        .subscribe();
  }

  Future<void> _markAsRead() async {
    try {
      final q = _supa
          .from('thix_weeding_messages')
          .update({'is_read': true})
          .eq('wedding_id', widget.weddingId)
          .eq('sender_type', 'guest')
          .eq('is_read', false);
      await (_isGuestId ? q.eq('guest_id', widget.guestIdOrName) : q.eq('sender_name', widget.guestIdOrName));
      ref.invalidate(messagesProvider(widget.weddingId));
    } catch (_) {}
  }

  Future<void> _addPhotos() async {
    try {
      final p = await pickPhotos(max: kMaxMessagePhotos - _pending.length);
      if (p.isNotEmpty) setState(() => _pending.addAll(p));
    } catch (e) {
      _toast('Galerie inaccessible : $e', error: true);
    }
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if ((text.isEmpty && _pending.isEmpty) || _sending) return;
    setState(() => _sending = true);
    try {
      final urls = _pending.isEmpty ? <String>[] : await uploadPhotos(widget.weddingId, _pending);
      final isAnn = _type == 'announcement';
      final isInfo = _type == 'info';
      final row = <String, dynamic>{
        'wedding_id': widget.weddingId,
        'guest_id': (!isAnn && _isGuestId) ? widget.guestIdOrName : null,
        'sender_name': 'Staff',
        'sender_type': 'staff',
        'message_type': (isInfo && !_isGuestId) ? 'chat' : _type,
        'tag': (isInfo || isAnn) ? _tag : null,
        'content': text.isNotEmpty ? text : '📷 Photo',
        'image_urls': urls,
        'is_published': isAnn,
        'is_read': isAnn,
      };
      await _supa.from('thix_weeding_messages').insert(row);
      _inputCtrl.clear();
      setState(() {
        _pending.clear();
        if (isAnn) _type = 'chat';
      });
      if (isAnn) {
        _toast('Annonce publiée pour tous les invités ✓');
      }
      // pas d'attente du realtime : on recharge si c'est un message de cette discussion
      if (!isAnn) await _loadMessages();
    } catch (e) {
      _toast('Envoi impossible : $e', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _toast(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(m),
        backgroundColor: error ? _C.rose : _C.green,
        behavior: SnackBarBehavior.floating,
      ));
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    if (_channel != null) _supa.removeChannel(_channel!);
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final shortId = widget.guestIdOrName.substring(0, math.min(8, widget.guestIdOrName.length));
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: const ThixGlassBar(),
        elevation: 0,
        foregroundColor: _C.ink,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
          Text(_isGuestId ? 'Invité · ID $shortId' : 'Discussion', style: GoogleFonts.inter(fontSize: 10, color: _C.ink2)),
        ]),
      ),
      body: ThixGlassBackdrop(
        child: Column(children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Text('Aucun message, commencez la discussion',
                            style: GoogleFonts.inter(color: _C.ink2)))
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _Bubble(message: _messages[i]),
                      ),
          ),
          _inputArea(),
        ]),
      ),
    );
  }

  Widget _inputArea() {
    final announce = _type == 'announcement';
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
        child: ThixGlass(
          radius: 24,
          opacity: 0.7,
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _typeChip('chat', 'Message', Icons.chat_bubble_outline_rounded),
                  const SizedBox(width: 6),
                  if (_isGuestId) ...[
                    _typeChip('info', 'Info perso', Icons.info_outline_rounded),
                    const SizedBox(width: 6),
                  ],
                  _typeChip('announcement', 'Annonce à tous', Icons.campaign_outlined),
                ]),
              ),
              if (_type != 'chat') ...[
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: kInfoTags
                        .map((t) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(t, style: const TextStyle(fontSize: 10.5)),
                                selected: _tag == t,
                                selectedColor: tagColor(t).withOpacity(0.2),
                                visualDensity: VisualDensity.compact,
                                onSelected: (_) => setState(() => _tag = t),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
              if (announce)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Sera visible sur l\'accueil de TOUS les invités.',
                      style: GoogleFonts.inter(fontSize: 11, color: _C.rose, fontWeight: FontWeight.w700)),
                ),
              if (_pending.isNotEmpty) ...[
                const SizedBox(height: 8),
                PickedPhotoStrip(photos: _pending, onRemove: (i) => setState(() => _pending.removeAt(i))),
              ],
              const SizedBox(height: 6),
              Row(children: [
                IconButton(
                  tooltip: 'Photos',
                  onPressed: _sending || _pending.length >= kMaxMessagePhotos ? null : _addPhotos,
                  icon: const Icon(Icons.add_photo_alternate_outlined, color: _C.blue),
                ),
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: announce ? 'Écrire l\'annonce…' : 'Écrire un message…',
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.7),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                CircleAvatar(
                  backgroundColor: announce ? _C.rose : _C.blue,
                  child: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : IconButton(
                          icon: Icon(announce ? Icons.campaign_rounded : Icons.send_rounded, color: Colors.white, size: 20),
                          onPressed: _send,
                        ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeChip(String v, String label, IconData icon) {
    final sel = _type == v;
    return GestureDetector(
      onTap: () => setState(() => _type = v),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? (v == 'announcement' ? _C.rose : _C.blue) : Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: sel ? Colors.white : _C.ink),
          const SizedBox(width: 5),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w800, color: sel ? Colors.white : _C.ink)),
        ]),
      ),
    );
  }
}

// ================= INTERNES =================

class _Bubble extends StatelessWidget {
  final Map<String, dynamic> message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isMe = message['sender_type'] == 'staff';
    final imgs = parseImageUrls(message['image_urls']);
    final type = '${message['message_type'] ?? 'chat'}';
    final tag = message['tag'] as String?;
    final content = '${message['content'] ?? ''}';
    final showText = !(content == '📷 Photo' && imgs.isNotEmpty);
    final d = DateTime.tryParse('${message['created_at']}')?.toLocal();
    final time = d == null
        ? ''
        : '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final maxW = MediaQuery.of(context).size.width * 0.74;

    final badge = type == 'invitation'
        ? 'INVITATION'
        : type == 'info'
            ? 'INFO PERSO${tag != null ? ' · $tag' : ''}'
            : null;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        constraints: BoxConstraints(maxWidth: maxW),
        decoration: BoxDecoration(
          gradient: isMe
              ? const LinearGradient(colors: [_C.blue, _C.blue2], begin: Alignment.topLeft, end: Alignment.bottomRight)
              : null,
          color: isMe ? null : Colors.white.withOpacity(0.85),
          border: isMe ? null : Border.all(color: Colors.white),
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomRight: isMe ? const Radius.circular(4) : null,
            bottomLeft: !isMe ? const Radius.circular(4) : null,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (badge != null)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: (isMe ? Colors.white : _C.rose).withOpacity(isMe ? 0.22 : 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(badge,
                  style: TextStyle(
                      fontSize: 8.5, fontWeight: FontWeight.w900, color: isMe ? Colors.white : _C.rose)),
            ),
          if (imgs.isNotEmpty) ...[
            SizedBox(width: maxW - 24, child: MessageImages(urls: imgs)),
            if (showText) const SizedBox(height: 6),
          ],
          if (showText)
            Text(content,
                style: GoogleFonts.inter(fontSize: 13.5, height: 1.35, color: isMe ? Colors.white : Colors.black87)),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(time, style: TextStyle(fontSize: 9.5, color: isMe ? Colors.white70 : Colors.grey)),
            if (isMe) ...[
              const SizedBox(width: 4),
              Icon(
                message['is_read'] == true ? Icons.done_all_rounded : Icons.done_rounded,
                size: 13,
                color: message['is_read'] == true ? const Color(0xFF7CF5B0) : Colors.white70,
              ),
            ],
          ]),
        ]),
      ),
    );
  }
}
