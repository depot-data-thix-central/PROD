// lib/presentation/chat/chat_screen.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:thix_id/presentation/chat/widgets/image_viewer.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/services/chat/chat_service.dart';
import 'package:thix_id/services/chat/audio_service.dart';
import 'package:thix_id/services/chat/connection_service.dart';
import 'package:thix_id/services/chat/media_saver.dart';
import 'package:thix_id/models/chat/chat_message.dart';
import 'package:thix_id/models/chat/chat_conversation.dart';
import 'package:thix_id/models/chat/user_status.dart';
import 'package:thix_id/models/chat/group_info.dart';
import 'package:thix_id/models/chat/call_status.dart';
import 'package:thix_id/presentation/chat/widgets/chat_message_bubble.dart';
import 'package:thix_id/presentation/chat/encryption_service.dart';
import 'package:thix_id/presentation/chat/call/call_page.dart';
import 'package:thix_id/presentation/chat/call/providers/call_provider.dart';
import 'package:thix_id/presentation/chat/providers/chat_providers.dart';
import 'package:thix_id/presentation/chat/providers/chat_list_provider.dart';

// ✅ Imports pour la certification
import 'package:thix_id/models/certification_tier.dart';
import 'package:thix_id/presentation/certification/widgets/certification_name_badge.dart';
import 'package:thix_id/features/network/presentation/providers/user_profile_providers.dart';

// Messages provider (family)
final chatMessagesProvider = StateNotifierProvider.family<ChatMsgNotifier, List<ChatMessage>, String>((ref, conversationId) {
  return ChatMsgNotifier(ref.read(chatServiceProvider), conversationId);
});

class ChatMsgNotifier extends StateNotifier<List<ChatMessage>> {
  final ChatService svc;
  final String convId;
  int page = 0;
  static const pageSize = 30;
  bool hasMore = true;
  bool loadingMore = false;

  ChatMsgNotifier(this.svc, this.convId) : super([]) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    page = 0;
    final msgs = await svc.getMessages(convId, limit: pageSize, offset: 0);
    hasMore = msgs.length >= pageSize;
    msgs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = msgs;
  }

  Future<void> loadMore() async {
    if (loadingMore || !hasMore) return;
    loadingMore = true;
    page++;
    final msgs = await svc.getMessages(
      convId,
      limit: pageSize,
      offset: page * pageSize,
    );
    hasMore = msgs.length >= pageSize;

    var current = [...state, ...msgs];
    final seen = <String>{};
    current = current.where((m) => seen.add(m.id)).toList();
    current.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = current;
    loadingMore = false;
  }

  void upsertRealtime(List<ChatMessage> updated) {
    if (updated.isEmpty) return;

    var current = [...state];
    var changed = false;

    for (final msg in updated) {
      final idx = current.indexWhere((m) => m.id == msg.id);
      if (idx != -1) {
        current[idx] = msg;
        changed = true;
      } else if (!msg.isDeleted) {
        current.insert(0, msg);
        changed = true;
      }
    }

    if (changed) {
      current.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final seen = <String>{};
      current = current.where((m) => seen.add(m.id)).toList();
      state = current;
    }
  }

  void removeLocal(String id) {
    state = state.where((m) => m.id != id).toList();
  }
}

// ─────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────
class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final ChatConversation conversation;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.conversation,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

// ─────────────────────────────────────────────────────────────
// GROUPEMENT STYLE WHATSAPP : photos consécutives du même expéditeur
// ─────────────────────────────────────────────────────────────
class _ChatListItem {
  final List<ChatMessage> messages;
  _ChatListItem.single(ChatMessage m) : messages = [m];
  _ChatListItem.group(this.messages);
}

List<_ChatListItem> _buildChatDisplayItems(List<ChatMessage> messages) {
  final items = <_ChatListItem>[];
  int i = 0;
  while (i < messages.length) {
    final m = messages[i];
    final isImg = m.mediaType == 'image' && (m.mediaUrl?.isNotEmpty ?? false);

    if (isImg) {
      final group = <ChatMessage>[m];
      int j = i + 1;
      while (j < messages.length) {
        final next = messages[j];
        final sameSender = next.senderId == m.senderId;
        final alsoImg = next.mediaType == 'image' && (next.mediaUrl?.isNotEmpty ?? false);
        final closeInTime = m.createdAt.difference(next.createdAt).inSeconds.abs() < 120;
        if (sameSender && alsoImg && closeInTime) {
          group.add(next);
          j++;
        } else {
          break;
        }
      }
      if (group.length > 1) {
        items.add(_ChatListItem.group(group));
        i = j;
        continue;
      }
    }

    items.add(_ChatListItem.single(m));
    i++;
  }
  return items;
}

// ✅ CORRECTION ICI : Réparation de la déclaration de la classe
class _ChatScreenState extends ConsumerState<ChatScreen> with WidgetsBindingObserver {
  late final ChatService _chatService;
  late final ConnectionService _connectionService;
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  final _inputFocus = FocusNode();

  UserStatus? _otherParticipant;
  List<GroupMember> _groupMembers = [];
  String _replyToId = '';

  bool _isEphemeral = false;
  int? _ephemeralDuration;
  bool _isTyping = false;
  bool _otherUserTyping = false;
  bool _isSending = false;
  bool _isConnectionValid = true;

  final AudioRecorder _audioRecorder = AudioRecorder();
  Timer? _recordTimer;
  int _recordDuration = 0;
  bool _isRecording = false;
  Uint8List? _audioBytes;
  String? _localAudioPath;

  List<PlatformFile> _selectedFiles = [];

  Timer? _typingTimer;
  Timer? _markReadTimer;
  DateTime? _lastConnCheck;
  RealtimeChannel? _typingChannel;
  bool _isAgent = false;
  bool _isInternalNoteMode = false;
  StreamSubscription<List<ChatMessage>>? _messageSub;
  StreamSubscription<List<UserStatus>>? _presenceSub;

  bool _showStickers = false;
  static const List<String> _emojis = [
    '😀','😃','😄','😁','😆','😅','😂','🤣','🥲','🥹',
    '😊','😇','🙂','🙃','😉','😌','😍','🥰','😘','😗',
    '😙','😚','🤩','🥳','🤗','🤔','🤭','🤫','🤥','😏',
    '😒','🙄','😬','😮‍💨','😔','😪','🤤','😴','😷','🤒',
    '🤕','🤢','🤮','🥵','🥶','😵','🤯','🤠','🥸','😎',
    '🤓','🧐','😕','😟','🙁','☹️','😮','😯','😲','😳',
    '🥺','😦','😧','😨','😰','😥','😢','😭','😱','😖',
    '😣','😞','😓','😩','😫','🥱','😤','😡','😠','🤬',
  ];

  static const List<String> _reactions = [
    '👍','👎','👌','🤌','🤏','✌️','🤞','🫰','🤟','🤘',
    '🤙','👈','👉','👆','👇','☝️','✋','🤚','🖐️','🖖',
    '👋','👏','🙌','🫶','💪','🦾','🙏','✍️',
    '❤️','🧡','💛','💚','💙','💜','🖤','🤍','🤎','💔',
    '❣️','💕','💞','💓','💗','💖','💘','💝','💟','❤️‍🔥',
    '🔥','⭐','🌟','✨','💫','💥','💯','🎉','🎊','🏆',
    '🥇','🥈','🥉','🎯','✅','❌','⚡','💡','📌','🔔',
  ];

  static const List<String> _flags = [
    '🏁','🚩','🎌','🏴','🏳️','🏳️‍⚧️','🏴‍☠️',
    '🇦🇫','🇿🇦','🇦🇱','🇩🇿','🇩🇪','🇦🇩','🇦🇴','🇦🇬',
    '🇸🇦','🇦🇷','🇦🇲','🇦🇺','🇦🇹','🇦🇿','🇧🇸','🇧🇭',
    '🇧🇩','🇧🇧','🇧🇪','🇧🇿','🇧🇯','🇧🇹','🇧🇾','🇲🇲',
    '🇧🇴','🇧🇦','🇧🇼','🇧🇷','🇧🇳','🇧🇬','🇧🇫','🇧🇮',
    '🇰🇭','🇨🇲','🇨🇦','🇨🇻','🇨🇱','🇨🇳','🇨🇾','🇨🇴',
    '🇰🇲','🇨🇬','🇨🇩','🇰🇵','🇰🇷','🇨🇷','🇨🇮','🇭🇷',
    '🇨🇺','🇩🇰','🇩🇯','🇩🇲','🇪🇬','🇸🇻','🇦🇪','🇪🇨',
    '🇪🇷','🇪🇸','🇪🇪','🇺🇸','🇪🇹','🇫🇯','🇫🇮','🇫🇷',
    '🇬🇦','🇬🇲','🇬🇪','🇬🇭','🇬🇷','🇬🇩','🇬🇹','🇬🇳',
    '🇬🇶','🇬🇾','🇭🇹','🇭🇳','🇭🇰','🇭🇺','🇮🇳','🇮🇩',
    '🇮🇷','🇮🇶','🇮🇪','🇮🇸','🇮🇱','🇮🇹','🇯🇲','🇯🇵',
    '🇯🇴','🇰🇿','🇰🇪','🇰🇬','🇰🇼','🇱🇦','🇱🇻','🇱🇧',
    '🇱🇷','🇱🇾','🇱🇮','🇱🇹','🇱🇺','🇲🇬','🇲🇾','🇲🇼',
    '🇲🇻','🇲🇱','🇲🇹','🇲🇦','🇲🇺','🇲🇽','🇲🇩','🇲🇨',
    '🇲🇳','🇲🇪','🇲🇿','🇳🇦','🇳🇵','🇳🇮','🇳🇪','🇳🇬',
    '🇳🇴','🇳🇿','🇴🇲','🇺🇬','🇺🇿','🇵🇰','🇵🇸','🇵🇦',
    '🇵🇬','🇵🇾','🇳🇱','🇵🇪','🇵🇭','🇵🇱','🇵🇹','🇶🇦',
    '🇨🇫','🇩🇴','🇷🇴','🇬🇧','🇷🇺','🇷🇼','🇸🇳','🇷🇸',
    '🇸🇨','🇸🇱','🇸🇬','🇸🇰','🇸🇮','🇸🇴','🇸🇩','🇱🇰',
    '🇸🇪','🇨🇭','🇸🇾','🇹🇯','🇹🇼','🇹🇿','🇹🇩','🇨🇿',
    '🇹🇭','🇹🇬','🇹🇴','🇹🇹','🇹🇳','🇹🇷','🇺🇦','🇺🇾',
    '🇻🇪','🇻🇳','🇾🇪','🇿🇲','🇿🇼',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _chatService = ref.read(chatServiceProvider);
    _connectionService = ConnectionService();
    _chatService.startPresenceHeartbeat();

    _inputController.addListener(() {
      setState(() {});
      _onTypingChanged(_inputController.text);
    });

    _checkConnectionSecurity();
    _loadUserRole();
    _getParticipantInfo();
    _markAsRead();
    _subscribeToPresence();
    _subscribeToRealtime();
    _subscribeToTyping();
    _loadGroupMembers();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _checkConnectionSecurity() async {
    if (widget.conversation.isGroup || _isAgent) return;

    final now = DateTime.now();
    if (_lastConnCheck != null && now.difference(_lastConnCheck!).inSeconds < 30) {
      return;
    }
    _lastConnCheck = now;

    final myId = _chatService.currentUserId;
    final otherId = widget.conversation.participantIds.firstWhere((id) => id != myId, orElse: () => '');

    if (otherId.isEmpty) return;

    final isConnected = await _connectionService.checkConnection(myId, otherId);
    if (mounted) {
      setState(() {
        _isConnectionValid = isConnected;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _chatService.startPresenceHeartbeat();
        _checkConnectionSecurity();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _chatService.stopPresenceHeartbeat();
        break;
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(chatMessagesProvider(widget.conversationId).notifier).loadMore();
    }
  }

  Future<void> _loadUserRole() async {
    try {
      final uid = _chatService.currentUserId;
      if (uid.isEmpty) return;
      final row = await Supabase.instance.client
          .from('profiles')
          .select('role, account_type')
          .eq('id', uid)
          .maybeSingle();
      if (row != null && mounted) {
        final role = (row['role'] ?? row['account_type'] ?? '').toString();
        setState(() {
          _isAgent = role == 'agent' || role == 'admin' || role == 'support' || role == 'enterprise';
        });
      }
    } catch (_) {}
  }

  Future<void> _loadGroupMembers() async {
    if (!widget.conversation.isGroup) return;
    try {
      final members = await _chatService.getGroupMembers(widget.conversationId);
      if (mounted) setState(() => _groupMembers = members);
    } catch (e) {
      debugPrint('Error loading group members: $e');
    }
  }

  @override
  void dispose() {
    _chatService.stopPresenceHeartbeat();
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _inputController.dispose();
    _inputFocus.dispose();
    _typingTimer?.cancel();
    _markReadTimer?.cancel();
    _messageSub?.cancel();
    _presenceSub?.cancel();
    _typingChannel?.unsubscribe();
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _markAsRead() async {
    try {
      ref.read(chatListProvider.notifier).markAsRead(widget.conversationId);
    } catch (e) {
      debugPrint('Erreur _markAsRead UI: $e');
    }
  }

  void _scheduleMarkAsRead() {
    _markReadTimer?.cancel();
    _markReadTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) _markAsRead();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    }
  }

  void _subscribeToPresence() {
    if (widget.conversation.isGroup) return;
    final otherId = widget.conversation.participantIds.firstWhere((id) => id != _chatService.currentUserId, orElse: () => '');
    if (otherId.isEmpty) return;

    _presenceSub = _chatService.subscribeToPresence([otherId]).listen((list) {
      if (mounted && list.isNotEmpty) setState(() => _otherParticipant = list.first);
    });
  }

  Future<void> _getParticipantInfo() async {
    if (widget.conversation.isGroup) return;
    final otherId = widget.conversation.participantIds.firstWhere((id) => id != _chatService.currentUserId, orElse: () => '');
    if (otherId.isEmpty) return;
    final p = await _chatService.getUserPresence(otherId);
    if (mounted) setState(() => _otherParticipant = p);
  }

  void _subscribeToRealtime() {
    _messageSub = _chatService.subscribeToMessages(widget.conversationId).listen((updated) {
      ref.read(chatMessagesProvider(widget.conversationId).notifier).upsertRealtime(updated);

      final me = _chatService.currentUserId;

      final idsToDeliver = updated
          .where((m) => m.senderId != me && !m.isDelivered && !m.isDeleted)
          .map((m) => m.id)
          .toList();
      if (idsToDeliver.isNotEmpty) {
        unawaited(
          Supabase.instance.client
              .from('messages')
              .update({'is_delivered': true})
              .inFilter('id', idsToDeliver),
        );
      }

      _scheduleMarkAsRead();
    });
  }

  void _subscribeToTyping() {
    final cur = _chatService.currentUserId;
    if (cur.isEmpty) return;

    _typingChannel = Supabase.instance.client.channel('typing:${widget.conversationId}').onBroadcast(
      event: 'typing',
      callback: (payload) {
        final sid = payload['senderId'] as String?;
        final typing = payload['isTyping'] as bool? ?? false;
        if (sid != null && sid != cur && mounted) setState(() => _otherUserTyping = typing);
      },
    ).subscribe();
  }

  void _sendTypingStatus(bool t) {
    if (!_isConnectionValid) return;
    final cur = _chatService.currentUserId;
    if (cur.isEmpty || _typingChannel == null) return;
    _typingChannel!.sendBroadcastMessage(event: 'typing', payload: {'senderId': cur, 'isTyping': t});
  }

  void _onTypingChanged(String t) {
    if (t.isNotEmpty && !_isTyping) {
      _isTyping = true;
      _sendTypingStatus(true);
    } else if (t.isEmpty && _isTyping) {
      _isTyping = false;
      _sendTypingStatus(false);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        _isTyping = false;
        _sendTypingStatus(false);
      }
    });
  }

  Future<bool> _checkPermissionWithDisclosure(Permission permission, String explanation) async {
    if (kIsWeb) return true;
    var status = await permission.status;
    if (status.isGranted) return true;

    if (!mounted) return false;

    bool? userAgreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: Colors.white.withValues(alpha: 0.9),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withValues(alpha: 0.8))),
          title: Row(
            children: [
              const Icon(Icons.privacy_tip_outlined, color: Colors.black, size: 28),
              const SizedBox(width: 10),
              Text(context.trAuthRequired, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            explanation,
            style: const TextStyle(color: Colors.black87, fontSize: 16, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.trCancel, style: const TextStyle(color: Colors.black54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
                side: const BorderSide(color: Colors.black, width: 1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.trUnderstood, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (userAgreed != true) return false;
    var newStatus = await permission.request();
    return newStatus.isGranted;
  }

  Future<void> _startCall(CallType type) async {
    if (!_isConnectionValid) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.trCallInactive), backgroundColor: ThixPolicy.danger));
      return;
    }

    final hasMic = await _checkPermissionWithDisclosure(Permission.microphone, context.trMicCallDisclosure);
    if (!hasMic) return;

    if (type == CallType.video) {
      final hasCam = await _checkPermissionWithDisclosure(Permission.camera, context.trCamCallDisclosure);
      if (!hasCam) return;
    }

    final myId = _chatService.currentUserId;
    final otherId = widget.conversation.participantIds.firstWhere((id) => id != myId, orElse: () => '');
    if (otherId.isEmpty) return;

    ref.read(callProvider.notifier).start(
      myUserId: myId,
      calleeId: otherId,
      calleeName: widget.conversation.displayName,
      calleeAvatar: widget.conversation.displayAvatar,
      type: type,
    );
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CallPage()));
  }

  Future<void> _startRecording() async {
    if (!_isConnectionValid) return;
    if (_isRecording) return;

    final hasPerm = await _checkPermissionWithDisclosure(Permission.microphone, context.trMicDisclosure);
    if (!hasPerm) return;

    try {
      String recordPath;
      if (kIsWeb) {
        recordPath = 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      } else {
        final dir = await getTemporaryDirectory();
        recordPath = p.join(dir.path, 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a');
      }

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
        path: recordPath,
      );

      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _recordDuration = 0;
        _audioBytes = null;
        _localAudioPath = null;
        _showStickers = false;
      });

      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) setState(() => _recordDuration++);
      });
    } catch (e) {
      debugPrint('Erreur record: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.trRecordingError), backgroundColor: ThixPolicy.danger),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    try {
      final path = await _audioRecorder.stop();
      if (mounted) setState(() => _isRecording = false);
      if (path != null) {
        Uint8List bytes;
        if (kIsWeb) {
          final response = await http.get(Uri.parse(path));
          bytes = response.bodyBytes;
        } else {
          final file = File(path);
          bytes = await file.readAsBytes();
        }
        if (mounted) {
          setState(() {
            _audioBytes = bytes;
            _localAudioPath = path;
          });
        }
      }
    } catch (e) {
      debugPrint('Erreur stop record: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.trRecordingError), backgroundColor: ThixPolicy.danger),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    if (!_isConnectionValid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.trSendInactive),
            backgroundColor: ThixPolicy.danger,
          ),
        );
      }
      return;
    }

    final text = _inputController.text.trim();
    if (text.isEmpty && _selectedFiles.isEmpty && _audioBytes == null) return;
    if (_isSending) return;

    _isTyping = false;
    _sendTypingStatus(false);
    setState(() => _isSending = true);

    try {
      if (_audioBytes != null) {
        final msg = await _chatService.sendAudioMessage(
          conversationId: widget.conversationId,
          audioData: _audioBytes!,
          duration: _recordDuration > 0 ? _recordDuration : 1,
          isEphemeral: _isEphemeral,
          ephemeralDuration: _ephemeralDuration,
          replyToId: _replyToId.isEmpty ? null : _replyToId,
        );
        ref.read(chatMessagesProvider(widget.conversationId).notifier).upsertRealtime([msg]);
      } else if (_selectedFiles.isNotEmpty) {
        final filesToSend = List<PlatformFile>.from(_selectedFiles);
        setState(() => _selectedFiles.clear());

        final imageFiles = <PlatformFile>[];
        final otherFiles = <PlatformFile>[];

        for (final f in filesToSend) {
          final ext = (f.extension ?? '').toLowerCase();
          if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
            imageFiles.add(f);
          } else {
            otherFiles.add(f);
          }
        }

        if (imageFiles.isNotEmpty) {
          final urls = <String>[];
          for (final f in imageFiles) {
            final bytes = f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
            if (bytes == null) continue;
            final ext = f.extension ?? 'jpg';
            final url = await _chatService.uploadFileWithUniqueName(
              'chat-media',
              'messages/${widget.conversationId}',
              Uint8List.fromList(bytes),
              ext,
            );
            if (url != null) urls.add(url);
          }

          if (urls.isNotEmpty) {
            for (var i = 0; i < urls.length; i++) {
              final msg = await _chatService.sendMessage(
                conversationId: widget.conversationId,
                content: text.isNotEmpty && i == 0 ? text : (imageFiles[i].name),
                mediaUrl: urls[i],
                mediaType: 'image',
                mediaName: imageFiles[i].name,
                mediaSize: imageFiles[i].size,
                isEphemeral: _isEphemeral,
                ephemeralDuration: _ephemeralDuration,
                replyToId: i == 0 && _replyToId.isNotEmpty ? _replyToId : null,
              );
              ref.read(chatMessagesProvider(widget.conversationId).notifier).upsertRealtime([msg]);
            }
          }
        }

        for (final f in otherFiles) {
          final bytes = f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
          if (bytes == null) continue;
          final ext = f.extension ?? 'bin';
          final url = await _chatService.uploadFileWithUniqueName(
            'chat-media',
            'messages/${widget.conversationId}',
            Uint8List.fromList(bytes),
            ext,
          );
          if (url != null) {
            final msg = await _chatService.sendMessage(
              conversationId: widget.conversationId,
              content: text.isNotEmpty ? text : f.name,
              mediaUrl: url,
              mediaType: _getMediaType(ext),
              mediaName: f.name,
              mediaSize: f.size,
              isEphemeral: _isEphemeral,
              ephemeralDuration: _ephemeralDuration,
              replyToId: _replyToId.isEmpty ? null : _replyToId,
            );
            ref.read(chatMessagesProvider(widget.conversationId).notifier).upsertRealtime([msg]);
          }
        }
      } else if (text.isNotEmpty) {
        final msg = await _chatService.sendMessage(
          conversationId: widget.conversationId,
          content: text,
          replyToId: _replyToId.isEmpty ? null : _replyToId,
          isEphemeral: _isEphemeral,
          ephemeralDuration: _isEphemeral ? _ephemeralDuration : null,
        );
        ref.read(chatMessagesProvider(widget.conversationId).notifier).upsertRealtime([msg]);
      }

      if (mounted) {
        setState(() {
          _inputController.clear();
          _replyToId = '';
          _audioBytes = null;
          _localAudioPath = null;
          if (_isInternalNoteMode) _isInternalNoteMode = false;
          _isEphemeral = false;
          _ephemeralDuration = null;
        });
      }
      _scrollToBottom();
    } catch (e) {
      debugPrint('❌ _sendMessage: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.trSendError} $e'),
            backgroundColor: ThixPolicy.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showEphemeralTimerDialog() {
    bool showCustomInput = false;
    final customTimeCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.8), width: 1)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 16),
                    Text(context.trEphemeralMessage, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 12),

                    if (!showCustomInput) ...[
                      ...[
                        (context.trDisabled, null),
                        (context.trSeconds10, 10),
                        (context.trMinute1, 60),
                        (context.trHour1, 3600),
                        (context.trHours24, 86400),
                      ].map((e) {
                        final selected = _ephemeralDuration == e.$2;
                        return ListTile(
                          title: Text(e.$1),
                          trailing: selected ? const Icon(Icons.check_circle, color: ThixPolicy.primary) : null,
                          onTap: () {
                            setState(() { _ephemeralDuration = e.$2; _isEphemeral = e.$2 != null; });
                            Navigator.pop(ctx);
                          },
                        );
                      }),
                      ListTile(
                        title: Text(context.trCustomTime, style: const TextStyle(color: ThixPolicy.primary, fontWeight: FontWeight.w600)),
                        leading: const Icon(Icons.timer_outlined, color: ThixPolicy.primary),
                        onTap: () => setModalState(() => showCustomInput = true),
                      ),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: customTimeCtrl, keyboardType: TextInputType.number, autofocus: true,
                                decoration: InputDecoration(labelText: context.trDurationSeconds, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 16)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16)),
                              onPressed: () {
                                final val = int.tryParse(customTimeCtrl.text.trim());
                                if (val != null && val > 0) {
                                  setState(() { _ephemeralDuration = val; _isEphemeral = true; });
                                  Navigator.pop(ctx);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.trInvalidNumber), backgroundColor: ThixPolicy.warning));
                                }
                              },
                              child: Text(context.trValidate, style: const TextStyle(color: Colors.white)),
                            )
                          ],
                        ),
                      ),
                      TextButton(onPressed: () => setModalState(() => showCustomInput = false), child: Text(context.trBack, style: const TextStyle(color: ThixPolicy.textSecondary)))
                    ]
                  ],
                ),
              ),
            );
          }
        ),
      ),
    );
  }

  void _showPasswordProtectDialog() {
    final msgCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: Colors.white.withValues(alpha: 0.9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withValues(alpha: 0.8))),
          title: Text(context.trSecureMessage),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: msgCtrl, decoration: InputDecoration(labelText: context.trMessage), maxLines: 3),
              const SizedBox(height: 12),
              TextField(controller: passCtrl, decoration: InputDecoration(labelText: context.trPassword), obscureText: true),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.trCancel)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary),
              onPressed: () async {
                if (msgCtrl.text.isEmpty || passCtrl.text.isEmpty) return;
                final enc = EncryptionService.encryptMessage(msgCtrl.text, passCtrl.text);
                Navigator.pop(ctx);
                try {
                  final msg = await _chatService.sendMessage(
                        conversationId: widget.conversationId, content: enc, replyToId: _replyToId.isEmpty ? null : _replyToId, isEphemeral: _isEphemeral, ephemeralDuration: _ephemeralDuration,
                      );
                  ref.read(chatMessagesProvider(widget.conversationId).notifier).upsertRealtime([msg]);
                  if (mounted) setState(() => _replyToId = '');
                  _scrollToBottom();
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${context.trError} $e'), backgroundColor: ThixPolicy.danger));
                }
              },
              child: Text(context.trSend, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);
      if (result != null && result.files.isNotEmpty) {
        setState(() => _selectedFiles.addAll(result.files));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${context.trError} $e'), backgroundColor: ThixPolicy.danger));
    }
  }

  void _removeFile(int index) => setState(() => _selectedFiles.removeAt(index));

  String _getMediaType(String ext) {
    const img = {'jpg', 'jpeg', 'png', 'gif', 'webp'};
    const vid = {'mp4', 'mov', 'avi', 'mkv'};
    const aud = {'mp3', 'wav', 'm4a'};
    final e = ext.toLowerCase();
    if (img.contains(e)) return 'image';
    if (vid.contains(e)) return 'video';
    if (aud.contains(e)) return 'audio';
    return 'file';
  }

  void _escalateConversation() {
    context.pushNamed('chatEscalate', pathParameters: {'conversationId': widget.conversationId}, queryParameters: {'agentId': _chatService.currentUserId, 'agentName': 'Agent'});
  }

  void _viewEscalationHistory() {
    context.pushNamed('chatEscalationHistory', pathParameters: {'conversationId': widget.conversationId});
  }

  void _toggleInternalNoteMode() {
    setState(() => _isInternalNoteMode = !_isInternalNoteMode);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isInternalNoteMode ? 'Mode note interne ON' : 'Mode note interne OFF'), backgroundColor: _isInternalNoteMode ? ThixPolicy.warning : ThixPolicy.textSecondary));
  }

  String _getPresenceText(UserStatus status) {
    final lastSeen = status.lastSeenAt.toLocal();
    final diff = DateTime.now().difference(lastSeen);
    if (status.status == 'online' && diff.inMinutes <= 2) return context.trOnline;
    return '${context.trSeenAt} ${_formatLastSeen(lastSeen)}';
  }

  bool get _isOnline {
    if (_otherParticipant == null) return false;
    return _otherParticipant!.status == 'online' && DateTime.now().difference(_otherParticipant!.lastSeenAt.toLocal()).inMinutes <= 2;
  }

  String _formatLastSeen(DateTime localDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(localDate.year, localDate.month, localDate.day);

    if (day == today) return '${context.trAt} ${DateFormat('HH:mm').format(localDate)}';
    if (day == today.subtract(const Duration(days: 1))) return '${context.trYesterdayAt} ${DateFormat('HH:mm').format(localDate)}';
    return '${context.trOn} ${DateFormat('dd/MM/yyyy').format(localDate)}';
  }

  Widget _buildBlurOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 50, sigmaY: 50),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider(widget.conversationId));
    final msgNotifier = ref.watch(chatMessagesProvider(widget.conversationId).notifier);
    final displayItems = _buildChatDisplayItems(messages);
    final currentUid = _chatService.currentUserId;

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Positioned(top: -50, right: -50, child: _buildBlurOrb(ThixPolicy.primary.withValues(alpha: 0.06), 300)),
          Positioned(bottom: 100, left: -100, child: _buildBlurOrb(ThixPolicy.primaryDeep.withValues(alpha: 0.04), 350)),

          Positioned.fill(child: CustomPaint(painter: _ThixChatBackgroundPainter())),

          Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      itemCount: displayItems.length + (msgNotifier.loadingMore ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (i == displayItems.length) {
                          return const Center(child: Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary))));
                        }

                        final item = displayItems[i];

                        if (item.messages.length > 1) {
                          return _ImageGroupBubble(
                            images: item.messages,
                            isOwn: item.messages.first.senderId == currentUid,
                          );
                        }

                        final msg = item.messages.first;
                        final isOwn = msg.senderId == currentUid;

                        if (msg.mediaType == 'call_audio' || msg.mediaType == 'call_video') {
                          return _CallBubble(
                            message: msg,
                            isOwn: isOwn,
                            onCallback: () { _startCall(msg.mediaType == 'call_video' ? CallType.video : CallType.audio); },
                          );
                        }

                        return ChatMessageBubble(
                          message: msg,
                          isOwn: isOwn,
                          onReply: () => setState(() => _replyToId = msg.id),
                          onDelete: () async {
                            if (isOwn) {
                              try {
                                await _chatService.deleteMessage(msg.id);
                                ref
                                    .read(chatMessagesProvider(widget.conversationId).notifier)
                                    .removeLocal(msg.id);
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('${context.trDeleteImpossible} $e'),
                                      backgroundColor: ThixPolicy.danger,
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          onReaction: (r) => _chatService.toggleReaction(msg.id, r),
                          replyToMessage: msg.replyToId != null ? messages.where((m) => m.id == msg.replyToId).firstOrNull : null,
                          isEphemeralActive: msg.isEphemeral,
                          isInternalNote: msg.isInternalNote,
                          isAgentView: _isAgent,
                        );
                      },
                    ),
                    if (_otherUserTyping) Positioned(bottom: 10, left: 16, child: _TypingPill()),
                  ],
                ),
              ),

              if (_replyToId.isNotEmpty) _ReplyBanner(
                text: messages.firstWhere((m) => m.id == _replyToId, orElse: () => messages.first).content,
                onClose: () => setState(() => _replyToId = ''),
              ),

              if (_isConnectionValid)
                _buildInputBar()
              else
                _buildBlockedBanner(),

              if (_showStickers) _buildStickerPicker(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedBanner() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.75),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.8), width: 1)),
          ),
          child: Column(
            children: [
              const Icon(Icons.person_off_rounded, color: ThixPolicy.textSecondary, size: 32),
              const SizedBox(height: 12),
              Text(
                context.trCannotReply,
                style: const TextStyle(color: ThixPolicy.textMain, fontWeight: FontWeight.w700, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                context.trConnectionInterrupted,
                style: const TextStyle(color: ThixPolicy.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            color: Colors.white.withValues(alpha: 0.65),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 1))
            ),
          ),
        ),
      ),
      leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: ThixPolicy.textMain), onPressed: () { _markAsRead(); context.pop(); }),
      titleSpacing: 0,
      title: Row(
        children: [
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
                ),
                child: CircleAvatar(
                  radius: 20, backgroundColor: ThixPolicy.tint,
                  child: widget.conversation.isGroup
                      ? const Icon(Icons.groups_rounded, color: ThixPolicy.textSecondary)
                      : ClipOval(child: Image.network(widget.conversation.displayAvatar ?? 'https://i.pravatar.cc/150?img=11', width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, color: ThixPolicy.textSecondary))),
                ),
              ),
              if (!widget.conversation.isGroup && _isOnline) Positioned(right: 0, bottom: 0, child: Container(width: 12, height: 12, decoration: BoxDecoration(color: ThixPolicy.success, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    CertificationTier? tier;
                    CertificationStatus? status;
                    bool isCertified = false;
                    bool isLegacyVerified = false;

                    if (!widget.conversation.isGroup) {
                      final myId = _chatService.currentUserId;
                      final otherId = widget.conversation.participantIds.firstWhere((id) => id != myId, orElse: () => '');
                      if (otherId.isNotEmpty) {
                        final profileData = ref.watch(userProfileProvider(otherId)).valueOrNull;
                        if (profileData != null) {
                          tier = CertificationTierX.parse(profileData['certification_tier']);
                          status = CertificationStatusX.parse(profileData['certification_status']);
                          isCertified = status == CertificationStatus.approved || status == CertificationStatus.generated;
                          isLegacyVerified = profileData['is_verified'] == true;
                        }
                      }
                    }

                    return Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.conversation.displayName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ThixPolicy.textMain),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis
                          ),
                        ),
                        if (isCertified)
                          CertificationNameBadge(
                            tier: tier,
                            status: status,
                            showLabel: false,
                            iconSize: 15,
                            padding: const EdgeInsets.only(left: 4),
                          )
                        else if (isLegacyVerified)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.verified_rounded, color: Color(0xFFE3B23C), size: 15),
                          ),
                      ],
                    );
                  },
                ),
                if (!widget.conversation.isGroup && _otherParticipant != null)
                  Text(_getPresenceText(_otherParticipant!), style: TextStyle(fontSize: 12, color: _isOnline ? ThixPolicy.success : ThixPolicy.textSecondary, fontWeight: _isOnline ? FontWeight.w600 : FontWeight.w400))
                else if (widget.conversation.isGroup)
                  Text('${_groupMembers.length} ${context.trMembers}', style: const TextStyle(fontSize: 12, color: ThixPolicy.textSecondary)),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(icon: const Icon(Icons.videocam_outlined, color: ThixPolicy.primary, size: 26), onPressed: () => _startCall(CallType.video)),
        IconButton(icon: const Icon(Icons.call_outlined, color: ThixPolicy.primary, size: 24), onPressed: () => _startCall(CallType.audio)),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: ThixPolicy.textMain),
          color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (v) {
            if (v == 'escalate') _escalateConversation();
            else if (v == 'history') _viewEscalationHistory();
            else if (v == 'group') GoRouter.of(context).go('/chat/group/${widget.conversationId}/info');
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'escalate', child: Row(children: [const Icon(Icons.arrow_upward, color: ThixPolicy.warning, size: 20), const SizedBox(width: 10), Text(context.trEscalate)])),
            PopupMenuItem(value: 'history', child: Row(children: [const Icon(Icons.history, color: ThixPolicy.primary, size: 20), const SizedBox(width: 10), Text(context.trHistory)])),
            if (widget.conversation.isGroup) PopupMenuItem(value: 'group', child: Row(children: [const Icon(Icons.info_outline, color: ThixPolicy.textSecondary, size: 20), const SizedBox(width: 10), Text(context.trGroupInfo)])),
          ],
        ),
      ],
    );
  }

  Widget _buildInputBar() {
    final hasTextOrImage = _inputController.text.trim().isNotEmpty || _selectedFiles.isNotEmpty;

    return ClipRRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.8), width: 1.2)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, -2))]
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.5)))),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        _optionButton(Icons.attach_file_rounded, context.trFile, _pickFile),
                        _optionButton(Icons.sentiment_satisfied_alt_rounded, context.trSticker, () { FocusScope.of(context).unfocus(); setState(() => _showStickers = !_showStickers); }, isActive: _showStickers),
                        _optionButton(Icons.timer_outlined, context.trEphemeral, _showEphemeralTimerDialog, isActive: _isEphemeral),
                        _optionButton(Icons.lock_outline_rounded, context.trProtected, _showPasswordProtectDialog),
                        if (_isAgent) _optionButton(Icons.note_alt_outlined, context.trInternalNote, _toggleInternalNoteMode, isActive: _isInternalNoteMode),
                      ],
                    ),
                  ),
                ),

                if (_selectedFiles.isNotEmpty) _FilesPreview(files: _selectedFiles, onRemove: _removeFile),

                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: _localAudioPath != null && !_isRecording
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(color: ThixPolicy.inkDeep, borderRadius: BorderRadius.circular(24)),
                        child: Row(
                          children: [
                            Expanded(child: _ChatWaveformAudioPlayer(audioUrl: _localAudioPath!, isLocal: true)),
                            IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70), onPressed: () => setState(() { _audioBytes = null; _localAudioPath = null; })),
                            CircleAvatar(radius: 16, backgroundColor: ThixPolicy.primary, child: IconButton(icon: _isSending ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send_rounded, color: Colors.white, size: 14), onPressed: _isSending ? null : () => _sendMessage())),
                          ],
                        ),
                      )
                    : _isRecording
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: ThixPolicy.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: ThixPolicy.danger.withValues(alpha: 0.2))
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.mic, color: ThixPolicy.danger), const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${context.trRecording} ${(_recordDuration ~/ 60).toString().padLeft(2, '0')}:${(_recordDuration % 60).toString().padLeft(2, '0')}',
                                  style: const TextStyle(color: ThixPolicy.danger, fontWeight: FontWeight.w800)
                                )
                              ),
                              GestureDetector(onTap: _stopRecording, child: const Icon(Icons.stop_circle_rounded, color: ThixPolicy.danger, size: 30)),
                            ],
                          ),
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1)
                                ),
                                child: TextField(
                                  controller: _inputController, focusNode: _inputFocus, maxLines: 5, minLines: 1, textCapitalization: TextCapitalization.sentences,
                                  onTap: () { if (_showStickers) setState(() => _showStickers = false); },
                                  decoration: InputDecoration(hintText: context.trWriteMessage, hintStyle: const TextStyle(color: ThixPolicy.textSecondary), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            GestureDetector(
                              onTap: () {
                                if (_isSending) return;
                                if (hasTextOrImage) _sendMessage();
                                else _startRecording();
                              },
                              child: CircleAvatar(
                                radius: 22, backgroundColor: hasTextOrImage ? ThixPolicy.primary : ThixPolicy.gold,
                                child: _isSending
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Icon(hasTextOrImage ? Icons.send_rounded : Icons.mic_rounded, color: hasTextOrImage ? Colors.white : ThixPolicy.inkDeep, size: 22),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _optionButton(IconData icon, String label, VoidCallback onTap, {bool isActive = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? ThixPolicy.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? ThixPolicy.primary.withValues(alpha: 0.2) : Colors.transparent)
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isActive ? ThixPolicy.primary : ThixPolicy.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: isActive ? FontWeight.w700 : FontWeight.w600, color: isActive ? ThixPolicy.primary : ThixPolicy.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildStickerPicker() {
    return SizedBox(
      height: 250,
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            TabBar(
              labelColor: ThixPolicy.primary,
              indicatorColor: ThixPolicy.primary,
              tabs: [
                Tab(text: context.trEmojis),
                Tab(text: context.trReactions),
                Tab(text: context.trFlags),
              ]
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildStickerGrid(_emojis),
                  _buildStickerGrid(_reactions),
                  _buildStickerGrid(_flags),
                ]
              )
            )
          ]
        )
      )
    );
  }

  Widget _buildStickerGrid(List<String> items) {
    return GridView.builder(
      padding: const EdgeInsets.all(8), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8, mainAxisSpacing: 8, crossAxisSpacing: 8),
      itemCount: items.length, itemBuilder: (context, index) => InkWell(onTap: () {
        _inputController.text += items[index];
        _inputController.selection = TextSelection.fromPosition(TextPosition(offset: _inputController.text.length));
      }, child: Center(child: Text(items[index], style: const TextStyle(fontSize: 24)))),
    );
  }
}

class _ImageGroupBubble extends StatelessWidget {
  final List<ChatMessage> images;
  final bool isOwn;

  const _ImageGroupBubble({required this.images, required this.isOwn});

  @override
  Widget build(BuildContext context) {
    final urls = images.map((m) => m.mediaUrl!).toList();
    final shown = images.take(4).toList();
    final extra = images.length - shown.length;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(left: isOwn ? 40 : 4, right: isOwn ? 4 : 40),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isOwn ? ThixPolicy.primary : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ThixPolicy.border.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: shown.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 3,
                      crossAxisSpacing: 3,
                      childAspectRatio: 1,
                    ),
                    itemBuilder: (context, idx) {
                      final msg = shown[idx];
                      final showMore = extra > 0 && idx == shown.length - 1;
                      return GestureDetector(
                        onTap: () => showFullscreenImageViewer(
                          context,
                          url: msg.mediaUrl!,
                          gallery: urls,
                          initialIndex: idx,
                          fileName: msg.mediaName ?? 'thix_${msg.id}.jpg',
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              msg.mediaUrl!,
                              fit: BoxFit.cover,
                              loadingBuilder: (_, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  color: ThixPolicy.tint,
                                  child: const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary))),
                                );
                              },
                              errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, color: ThixPolicy.textSecondary)),
                            ),
                            if (showMore)
                              Container(
                                color: Colors.black.withValues(alpha: 0.55),
                                alignment: Alignment.center,
                                child: Text(
                                  '+ $extra',
                                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 6, bottom: 1),
                child: Text(
                  DateFormat('HH:mm').format(images.first.createdAt.toLocal()),
                  style: TextStyle(fontSize: 10, color: isOwn ? Colors.white70 : ThixPolicy.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isOwn;
  final VoidCallback onCallback;

  const _CallBubble({
    required this.message,
    required this.isOwn,
    required this.onCallback,
  });

  @override
  Widget build(BuildContext context) {
    final isVideo = message.mediaType == 'call_video';
    final isMissed = message.content.toLowerCase().contains('manqué') || message.content.toLowerCase().contains('missed');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(left: isOwn ? 50 : 0, right: isOwn ? 0 : 50),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isMissed ? ThixPolicy.danger.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.8)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isMissed ? ThixPolicy.danger.withValues(alpha: 0.1) : ThixPolicy.tint.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                  color: isMissed ? ThixPolicy.danger : ThixPolicy.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: isMissed ? ThixPolicy.danger : ThixPolicy.textMain,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(isOwn ? Icons.call_made_rounded : Icons.call_received_rounded, size: 12, color: ThixPolicy.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('HH:mm').format(message.createdAt.toLocal()),
                        style: const TextStyle(fontSize: 11, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: onCallback,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.refresh_rounded, size: 20, color: ThixPolicy.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))]
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _Dot(), const SizedBox(width: 3), const _Dot(delay: 120), const SizedBox(width: 3), const _Dot(delay: 240), const SizedBox(width: 8),
              Text(context.trTyping, style: const TextStyle(fontSize: 12, color: ThixPolicy.primary, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({this.delay = 0});
  @override State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    if (widget.delay > 0) Future.delayed(Duration(milliseconds: widget.delay), () { if (mounted) _c.forward(); });
    else _c.forward();
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => FadeTransition(opacity: _c, child: Container(width: 5, height: 5, decoration: const BoxDecoration(color: ThixPolicy.primary, shape: BoxShape.circle)));
}

class _ReplyBanner extends StatelessWidget {
  final String text;
  final VoidCallback onClose;
  const _ReplyBanner({required this.text, required this.onClose});
  @override Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.8)))
          ),
          child: Row(
            children: [
              Container(width: 4, height: 36, decoration: BoxDecoration(color: ThixPolicy.primary, borderRadius: BorderRadius.circular(4))), const SizedBox(width: 12),
              Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ThixPolicy.textSecondary, fontSize: 13))),
              IconButton(icon: const Icon(Icons.close_rounded, size: 20, color: ThixPolicy.textSecondary), onPressed: onClose),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilesPreview extends StatelessWidget {
  final List<PlatformFile> files;
  final void Function(int) onRemove;
  const _FilesPreview({required this.files, required this.onRemove});
  @override Widget build(BuildContext context) {
    return Container(
      height: 70, width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal, itemCount: files.length,
        itemBuilder: (ctx, i) {
          final f = files[i];
          final isImg = ['jpg', 'jpeg', 'png', 'webp'].contains(f.extension?.toLowerCase() ?? '');
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 60, margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.8))
                ),
                clipBehavior: Clip.hardEdge,
                child: isImg && f.bytes != null ? Image.memory(f.bytes!, fit: BoxFit.cover) : const Center(child: Icon(Icons.insert_drive_file_rounded, color: ThixPolicy.primary, size: 24)),
              ),
              Positioned(top: -4, right: 4, child: GestureDetector(onTap: () => onRemove(i), child: const CircleAvatar(radius: 10, backgroundColor: Colors.black87, child: Icon(Icons.close, size: 12, color: Colors.white)))),
            ],
          );
        },
      ),
    );
  }
}

class _ChatWaveformAudioPlayer extends StatefulWidget {
  final String audioUrl;
  final bool isLocal;
  const _ChatWaveformAudioPlayer({required this.audioUrl, this.isLocal = false});
  @override State<_ChatWaveformAudioPlayer> createState() => _ChatWaveformAudioPlayerState();
}

class _ChatWaveformAudioPlayerState extends State<_ChatWaveformAudioPlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  final List<double> _wavePattern = [0.4, 0.7, 0.5, 0.9, 0.6, 0.4, 0.8, 1.0, 0.5, 0.3, 0.7, 0.8, 0.4, 0.6];

  @override void initState() {
    super.initState();
    if (widget.isLocal) {
      if (kIsWeb) _audioPlayer.setSourceUrl(widget.audioUrl); else _audioPlayer.setSourceDeviceFile(widget.audioUrl);
    } else {
      _audioPlayer.setSourceUrl(widget.audioUrl);
    }
    _audioPlayer.onPlayerStateChanged.listen((state) { if (mounted) setState(() => _isPlaying = state == PlayerState.playing); });
    _audioPlayer.onDurationChanged.listen((d) { if (mounted) setState(() => _duration = d); });
    _audioPlayer.onPositionChanged.listen((p) { if (mounted) setState(() => _position = p); });
  }

  @override void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) { final m = d.inMinutes.remainder(60).toString().padLeft(2, '0'); final s = d.inSeconds.remainder(60).toString().padLeft(2, '0'); return "$m:$s"; }

  @override Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0 ? _position.inMilliseconds / _duration.inMilliseconds : 0.0;
    return Row(
      children: [
        GestureDetector(
          onTap: () { if (_isPlaying) _audioPlayer.pause(); else _audioPlayer.resume(); },
          child: Container(width: 32, height: 32, decoration: const BoxDecoration(color: ThixPolicy.gold, shape: BoxShape.circle), child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: ThixPolicy.inkDeep, size: 20)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const barWidth = 3.0; const spacing = 2.0;
              final barCount = (constraints.maxWidth / (barWidth + spacing)).floor();
              return GestureDetector(
                onTapDown: (details) { if (_duration.inMilliseconds > 0) _audioPlayer.seek(Duration(milliseconds: (_duration.inMilliseconds * (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0)).round())); },
                child: Container(
                  height: 24, color: Colors.transparent,
                  child: Row(children: List.generate(barCount, (index) {
                    final isPlayed = (index / barCount) <= progress;
                    return Container(width: barWidth, height: 24 * _wavePattern[index % _wavePattern.length], margin: const EdgeInsets.only(right: spacing), decoration: BoxDecoration(color: isPlayed ? ThixPolicy.gold : Colors.white30, borderRadius: BorderRadius.circular(2)));
                  })),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Text(_formatDuration(_duration.inSeconds > 0 && !_isPlaying && _position.inSeconds == 0 ? _duration : _position), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
      ],
    );
  }
}

class _ThixChatBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final textStyle = TextStyle(
      color: const Color(0xFFD3C7B5).withValues(alpha: 0.10),
      fontSize: 18,
      fontWeight: FontWeight.w900,
      letterSpacing: 2.0,
    );
    final textPainter = TextPainter(text: TextSpan(text: 'THIX CHAT', style: textStyle), textDirection: ui.TextDirection.ltr);
    textPainter.layout();

    final double stepX = 180.0;
    final double stepY = 140.0;

    for (double y = -stepY; y < size.height + stepY; y += stepY) {
      for (double x = -stepX; x < size.width + stepX; x += stepX) {
        canvas.save();
        final offsetX = x + ((y / stepY).floor() % 2 == 0 ? 0 : stepX / 2);
        canvas.translate(offsetX, y);
        canvas.rotate(-math.pi / 6);
        textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
        canvas.restore();
      }
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// EXTENSION DE LOCALISATION (i18n PROXY)
// ============================================================================
extension ChatL10n on BuildContext {
  String get trWriteMessage => 'Écrire un message...';
  String get trRecording => 'Enregistrement...';
  String get trCancel => 'Annuler';
  String get trUnderstood => 'Compris';
  String get trAuthRequired => 'Autorisation requise';
  String get trMicDisclosure => 'Pour vous permettre d\'enregistrer et d\'envoyer des notes vocales, THIX ID a besoin d\'accéder à votre microphone.';
  String get trMicCallDisclosure => 'Pour passer un appel, THIX ID a besoin d\'accéder à votre microphone.';
  String get trCamCallDisclosure => 'Pour passer un appel vidéo, THIX ID a besoin d\'accéder à votre caméra.';
  String get trCallInactive => 'Impossible d\'appeler : connexion inactive.';
  String get trSendInactive => 'Connexion inactive — impossible d\'envoyer.';
  String get trRecordingError => 'Impossible de démarrer l\'enregistrement.';
  String get trError => 'Erreur:';
  String get trSendError => 'Envoi impossible:';
  String get trDeleteImpossible => 'Suppression impossible:';
  String get trTyping => 'écrit...';

  String get trCannotReply => 'Vous ne pouvez plus répondre à cette conversation';
  String get trConnectionInterrupted => 'La connexion a été interrompue ou cet utilisateur n\'est plus dans votre réseau.';
  String get trMembers => 'membres';
  String get trOnline => 'En ligne';
  String get trSeenAt => 'Vu';
  String get trAt => 'à';
  String get trYesterdayAt => 'hier à';
  String get trOn => 'le';

  String get trEscalate => 'Escalader';
  String get trHistory => 'Historique';
  String get trGroupInfo => 'Infos groupe';

  String get trFile => 'Fichier';
  String get trSticker => 'Sticker';
  String get trEphemeral => 'Éphémère';
  String get trProtected => 'Protégé';
  String get trInternalNote => 'Note Int.';

  String get trEphemeralMessage => 'Message éphémère';
  String get trDisabled => 'Désactivé';
  String get trSeconds10 => '10 secondes';
  String get trMinute1 => '1 minute';
  String get trHour1 => '1 heure';
  String get trHours24 => '24 heures';
  String get trCustomTime => 'Personnalisé...';
  String get trDurationSeconds => 'Durée en secondes';
  String get trValidate => 'Valider';
  String get trInvalidNumber => 'Nombre invalide.';
  String get trBack => 'Retour';

  String get trSecureMessage => 'Message sécurisé';
  String get trMessage => 'Message';
  String get trPassword => 'Mot de passe';
  String get trSend => 'Envoyer';

  String get trEmojis => 'Émojis';
  String get trReactions => 'Réactions';
  String get trFlags => 'Drapeaux';

  String get trDownload => 'Télécharger';
  String get trShare => 'Partager';
  String get trDownloadOk => 'Téléchargé :';
  String get trDownloadFail => 'Échec du téléchargement';
  String get trFileTooBig => 'Fichier trop volumineux (max 25 Mo) :';
}
