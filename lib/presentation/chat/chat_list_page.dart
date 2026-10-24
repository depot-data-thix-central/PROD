// lib/presentation/chat/chat_list_page.dart
//
// ChatListPage — v4.0 (enterprise)
// ✅ Palette neutre : plus de bleu (gris foncé / blanc), rouge = alertes uniquement
// ✅ Escalades : signe très visible (fond rouge léger, double barre, bande « ESCALADE »)
// ✅ Barre du bas : libellés, point actif, pastilles numérotées (Réseau / Discussions / Appels)
// ✅ Filtres avec compteur + filtre rapide « Escalades »
// ✅ Bandeau « N non lus » + « Tout lire »
// ✅ Double appui sur « Discussions » = retour en haut
// ✅ Tuiles isolées (RepaintBoundary) pour plus de fluidité
// ✅ Conserve : brouillons, appels manqués, verrou + biométrie, bloc-notes, notifications
//
// ⚠️ Dépendance : crypto: ^3.0.3

import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';
import 'package:thix_id/models/chat/chat_conversation.dart';
import 'package:thix_id/models/chat/chat_message.dart';
import 'package:thix_id/presentation/chat/call/call_history_page.dart';
import 'package:thix_id/presentation/chat/providers/chat_list_provider.dart';
import 'package:thix_id/presentation/chat/providers/chat_notification_counters_provider.dart';
import 'package:thix_id/presentation/chat/providers/presence_provider.dart';
import 'package:thix_id/presentation/chat/providers/status_provider.dart';
import 'package:thix_id/presentation/chat/screens/group_create_page.dart';
import 'package:thix_id/presentation/chat/settings/chat_settings_page.dart';
import 'package:thix_id/presentation/chat/widgets/status_story_row.dart';
import 'package:thix_id/services/biometric_service.dart';

import 'chat_screen.dart';
import 'new_conversation_page.dart';
import 'widgets/chat_list_widgets.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const int _kLoadMoreThresholdPx = 300;
const int _kLoadMoreThrottleMs = 500;
const int _kSearchDebounceMs = 300;
const int _kMaxChatNameLength = 80;
const int _kMaxPreviewLength = 140;
const int _kMaxPinned = 3;
const String _kCallsSeenKey = 'thix_chat_calls_seen_at_v1';
// ⚠️ Doit rester identique à _kDraftPrefix de chat_screen.dart
const String _kDraftPrefix = 'thix_chat_draft_v1_';

String _s(BuildContext ctx, String key, {List<String>? args, String? fb}) => clS(ctx, key, args: args, fb: fb);

// ============================================================================
// PAGE
// ============================================================================
class ChatListPage extends ConsumerStatefulWidget {
  const ChatListPage({super.key});

  @override
  ConsumerState<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends ConsumerState<ChatListPage> with WidgetsBindingObserver {
  final _searchCtrl = TextEditingController();
  final _scroll = ScrollController();
  final Map<String, String> _drafts = <String, String>{};
  int _selectedNav = 1;
  bool _onlyEscalations = false;
  DateTime? _lastLoadMore;
  Timer? _searchDebounce;
  DateTime _callsSeenAt = DateTime.fromMillisecondsSinceEpoch(0);

  static const int _filterCount = 6;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    unawaited(_loadDrafts());
    unawaited(_loadCallsSeen());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(notificationCountersProvider.notifier).refresh(immediate: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.removeListener(_onScroll);
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - _kLoadMoreThresholdPx) {
      final now = DateTime.now();
      if (_lastLoadMore != null && now.difference(_lastLoadMore!).inMilliseconds < _kLoadMoreThrottleMs) return;
      _lastLoadMore = now;
      ref.read(chatListProvider.notifier).loadMore();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAllCounters();
      ref.read(notificationCountersProvider.notifier).refresh(immediate: true);
    }
  }

  void _refreshAllCounters() {
    unawaited(ref.read(notificationCountersProvider.notifier).refresh().catchError((e) => debugPrint('[ChatList] ⚠️ Counters: $e')));
    unawaited(ref.read(chatListProvider.notifier).refresh(silent: true).catchError((e) => debugPrint('[ChatList] ⚠️ List: $e')));
    unawaited(ref.read(statusProvider.notifier).refresh().catchError((_) {}));
    unawaited(_loadDrafts());
  }

  void _scrollTop() {
    HapticFeedback.selectionClick();
    if (_scroll.hasClients) _scroll.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
  }

  // ==========================================================================
  // 📞 APPELS MANQUÉS (calcul local)
  // ==========================================================================
  Future<void> _loadCallsSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(_kCallsSeenKey);
      if (ms != null && mounted) setState(() => _callsSeenAt = DateTime.fromMillisecondsSinceEpoch(ms));
    } catch (e) {
      debugPrint('[ChatList] ⚠️ loadCallsSeen: $e');
    }
  }

  Future<void> _markCallsSeen() async {
    final now = DateTime.now();
    if (mounted) setState(() => _callsSeenAt = now);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kCallsSeenKey, now.millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[ChatList] ⚠️ markCallsSeen: $e');
    }
  }

  bool _isMissedIncomingCall(ChatMessage m, String me) {
    final type = '${m.mediaType ?? ''}';
    if (type != 'call_audio' && type != 'call_video') return false;
    if (m.senderId == me) return false;
    return ChatListValidators.isMissedCallText(m.content);
  }

  int _derivedMissedCalls(List<ChatConversation> all, String me) {
    if (me.isEmpty) return 0;
    var n = 0;
    for (final c in all) {
      final m = c.lastMessage;
      if (m == null || !_isMissedIncomingCall(m, me)) continue;
      if (m.createdAt.isAfter(_callsSeenAt)) n++;
    }
    return n;
  }

  Future<void> _loadDrafts() async {
    final uid = ref.read(authControllerProvider).value?.id ?? '';
    if (uid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefix = '$_kDraftPrefix${uid}_';
      final map = <String, String>{};
      for (final k in prefs.getKeys()) {
        if (!k.startsWith(prefix)) continue;
        final v = prefs.getString(k);
        if (v != null && v.trim().isNotEmpty) map[k.substring(prefix.length)] = v;
      }
      if (!mounted) return;
      setState(() {
        _drafts
          ..clear()
          ..addAll(map);
      });
    } catch (e) {
      debugPrint('[ChatList] ⚠️ loadDrafts: $e');
    }
  }

  String _errMsg(Object e) {
    final m = e.toString().toLowerCase();
    if (m.contains('timeout')) return _s(context, 'chatlist_err_timeout');
    if (m.contains('network') || m.contains('socket')) return _s(context, 'chatlist_err_network');
    if (m.contains('permission') || m.contains('policy')) return _s(context, 'chatlist_err_denied');
    return _s(context, 'chatlist_err_generic');
  }

  Future<void> _guard(FutureOr<void> Function() fn) async {
    try {
      await fn();
    } catch (e) {
      debugPrint('[ChatList] ❌ action error: $e');
      _showError(_errMsg(e));
    }
  }

  // ==========================================================================
  // 🔒 VERROU
  // ==========================================================================
  Future<bool> _defineLockPassword() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => const DefinePasswordDialog());
    return ok == true;
  }

  Future<bool> _promptUnlock(ChatConversation conv) async {
    var bio = false;
    try {
      bio = await BiometricService.instance.isAvailable();
    } catch (_) {}
    if (!mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UnlockDialog(name: ChatListValidators.sanitize(conv.displayName, maxLength: 40), bioAvailable: bio),
    );
    return ok == true;
  }

  Future<void> _openConversation(ChatConversation conv) async {
    HapticFeedback.mediumImpact();
    if (conv.isLocked) {
      final unlocked = await _promptUnlock(conv);
      if (!unlocked) {
        _showInfo(_s(context, 'chatlist_locked_denied'));
        return;
      }
    }
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(conversationId: conv.id, conversation: conv)));
    if (!mounted) return;
    _refreshAllCounters();
    unawaited(Future.delayed(const Duration(milliseconds: 350), _loadDrafts));
  }

  Future<void> _openNotebook() async {
    HapticFeedback.selectionClick();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final saved = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => NotebookSheet(prefs: prefs),
      );
      if (saved == true) _showSuccess(_s(context, 'chatlist_notebook_saved'));
    } catch (e) {
      _showError(_errMsg(e));
    }
  }

  // ==========================================================================
  // NAVIGATION
  // ==========================================================================
  void _navigateTo(int idx) {
    HapticFeedback.lightImpact();
    final counters = ref.read(notificationCountersProvider.notifier);
    switch (idx) {
      case 0:
        context.pushNamed('connections').then((_) {
          if (mounted) _refreshAllCounters();
        });
        break;
      case 1:
        setState(() => _selectedNav = idx);
        break;
      case 2:
        counters.clearMissedCalls();
        unawaited(_markCallsSeen());
        Navigator.push(context, MaterialPageRoute(builder: (_) => const CallHistoryPage())).then((_) {
          if (mounted) _refreshAllCounters();
        });
        break;
      case 3:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatSettingsPage())).then((_) {
          if (mounted) _refreshAllCounters();
        });
        break;
    }
  }

  void _goToHomepage() => context.go('/');

  Future<void> _markAllAsRead() async {
    final convs = ref.read(chatListProvider).all.where((c) => c.unreadCount > 0).take(30).toList();
    if (convs.isEmpty) {
      _showInfo(_s(context, 'chatlist_nothing_unread'));
      return;
    }
    await _guard(() async {
      for (final c in convs) {
        await ref.read(chatListProvider.notifier).markAsRead(c.id);
      }
    });
    _showSuccess(_s(context, 'chatlist_all_read'));
  }

  Widget _notifTile(BuildContext ctx, {required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    return Semantics(
      button: true,
      label: title,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s24, vertical: ThixPolicy.s12),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(title, style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 15)),
        subtitle: Padding(padding: const EdgeInsets.only(top: 3), child: Text(subtitle, style: ThixPolicy.bodySmallStyle)),
        trailing: const Icon(Icons.chevron_right_rounded, color: ThixPolicy.textSecondary),
        onTap: onTap,
      ),
    );
  }

  void _openNotifications(int pending, int missedCalls, int newConnections) {
    HapticFeedback.selectionClick();
    final totalUnread = ref.read(chatListProvider).totalUnread;
    final empty = pending == 0 && totalUnread == 0 && missedCalls == 0 && newConnections == 0;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(ThixPolicy.rXl)),
          border: Border(top: BorderSide(color: ThixPolicy.border)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: ThixPolicy.s12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(ThixPolicy.s24, ThixPolicy.s20, ThixPolicy.s24, ThixPolicy.s16),
            child: Row(children: [
              const Icon(Icons.notifications_rounded, color: ThixPolicy.textMain, size: 22),
              const SizedBox(width: ThixPolicy.s12),
              Text(_s(ctx, 'chatlist_notifications'), style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, letterSpacing: -0.3)),
            ]),
          ),
          const Divider(height: 1, color: ThixPolicy.border),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              if (pending > 0)
                _notifTile(ctx, icon: Icons.swap_vert_rounded, color: ThixPolicy.danger, title: _s(ctx, 'chatlist_pending_escalations'), subtitle: _s(ctx, 'chatlist_requires_action'), onTap: () {
                  Navigator.pop(ctx);
                  context.pushNamed('chatEscalationReceived');
                }),
              if (missedCalls > 0)
                _notifTile(ctx, icon: Icons.call_missed_rounded, color: ThixPolicy.danger, title: _s(ctx, 'chatlist_missed_calls', args: ['$missedCalls']), subtitle: _s(ctx, 'chatlist_tap_to_view'), onTap: () {
                  Navigator.pop(ctx);
                  _navigateTo(2);
                }),
              if (newConnections > 0)
                _notifTile(ctx, icon: Icons.people_alt_rounded, color: kInk, title: _s(ctx, 'chatlist_new_connections', args: ['$newConnections']), subtitle: _s(ctx, 'chatlist_tap_to_view'), onTap: () {
                  Navigator.pop(ctx);
                  _navigateTo(0);
                }),
              if (totalUnread > 0)
                _notifTile(ctx, icon: Icons.done_all_rounded, color: kInk, title: _s(ctx, 'chatlist_mark_all_read'), subtitle: '$totalUnread ${_s(ctx, 'chatlist_unread_label')}', onTap: () {
                  Navigator.pop(ctx);
                  _markAllAsRead();
                }),
              if (empty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: Text(_s(ctx, 'chatlist_no_recent'), style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary))),
                ),
            ]),
          ),
          const SizedBox(height: ThixPolicy.s24),
        ]),
      ),
    );
  }

  void _showCreateMenu() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(ThixPolicy.s20, ThixPolicy.s12, ThixPolicy.s20, ThixPolicy.s32 + MediaQuery.of(ctx).padding.bottom),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(ThixPolicy.rXl)),
          border: Border(top: BorderSide(color: ThixPolicy.border)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: ThixPolicy.s24),
          _sheetOpt(Icons.chat_bubble_outline_rounded, _s(ctx, 'chatlist_new_discussion'), _s(ctx, 'chatlist_start_private'),
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewConversationPage()))),
          const SizedBox(height: ThixPolicy.s12),
          _sheetOpt(Icons.group_add_outlined, _s(ctx, 'chatlist_create_group'), _s(ctx, 'chatlist_collaborate_team'),
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupCreatePage()))),
        ]),
      ),
    );
  }

  Widget _sheetOpt(IconData icon, String title, String subtitle, VoidCallback tap) {
    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pop(context);
            HapticFeedback.selectionClick();
            tap();
          },
          borderRadius: BorderRadius.circular(ThixPolicy.rLg),
          child: Container(
            padding: const EdgeInsets.all(ThixPolicy.s16),
            decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, border: Border.all(color: ThixPolicy.border), borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
            child: Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: ThixPolicy.border)),
                child: Icon(icon, size: 24, color: kInk),
              ),
              const SizedBox(width: ThixPolicy.s16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: ThixPolicy.titleStyle.copyWith(fontSize: 15, fontWeight: ThixPolicy.bold, letterSpacing: -0.2)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: ThixPolicy.bodySmallStyle.copyWith(fontSize: 12, fontWeight: ThixPolicy.medium)),
                ]),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: ThixPolicy.textSecondary),
            ]),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // APERÇU
  // ==========================================================================
  ChatListPreview _buildPreview(ChatConversation conv, String me) {
    final ctx = context;
    if (conv.isLocked) return ChatListPreview(_s(ctx, 'chatlist_locked_preview'), icon: Icons.lock_rounded);

    final localDraft = _drafts[conv.id];
    final draftRaw = (localDraft != null && localDraft.trim().isNotEmpty) ? localDraft : conv.draft;
    final draft = ChatListValidators.sanitize(draftRaw, maxLength: 100, singleLine: true);
    if (draft.isNotEmpty) return ChatListPreview(draft, prefix: _s(ctx, 'chatlist_draft_prefix'));

    final m = conv.lastMessage;
    if (m == null) return ChatListPreview(_s(ctx, 'chatlist_new_conversation'));
    if (m.isDeletedForAll || m.isDeleted) return ChatListPreview(_s(ctx, 'chatlist_msg_deleted'), icon: Icons.block, color: ThixPolicy.textMuted);
    if (m.isExpired) return ChatListPreview(_s(ctx, 'chatlist_msg_expired'), icon: Icons.timer_outlined, color: ThixPolicy.textMuted);

    final type = '${m.mediaType ?? ''}';
    final unread = conv.unreadCount > 0;

    if (type == 'system_screenshot') {
      return ChatListPreview(_s(ctx, 'chatlist_screenshot', fb: 'Capture d’écran effectuée'), icon: Icons.screenshot_rounded, color: ThixPolicy.warning);
    }
    if (type == 'call_audio' || type == 'call_video') {
      final video = type == 'call_video';
      if (ChatListValidators.isMissedCallText(m.content)) {
        return ChatListPreview(_s(ctx, video ? 'chatlist_call_missed_video' : 'chatlist_call_missed'), icon: Icons.call_missed_rounded, color: ThixPolicy.danger, strong: unread);
      }
      if (m.senderId == me) return ChatListPreview(_s(ctx, 'chatlist_call_outgoing'), icon: Icons.call_made_rounded, color: ThixPolicy.success);
      return ChatListPreview(_s(ctx, 'chatlist_call_incoming'), icon: Icons.call_received_rounded, color: ThixPolicy.textSecondary);
    }
    if (type == 'image') return ChatListPreview(_s(ctx, 'chatlist_photo'), icon: Icons.photo_camera_rounded);
    if (type == 'video') return ChatListPreview(_s(ctx, 'chatlist_video'), icon: Icons.videocam_rounded);
    if (type == 'audio') return ChatListPreview(_s(ctx, 'chatlist_audio_message'), icon: Icons.mic_rounded);
    if (type == 'sticker') return ChatListPreview(_s(ctx, 'chatlist_sticker'), icon: Icons.emoji_emotions_outlined);

    final raw = m.content;
    if (type == 'file') {
      final name = ChatListValidators.sanitize(m.mediaName ?? raw, maxLength: 60, singleLine: true);
      return ChatListPreview(name.isEmpty ? '—' : name, icon: Icons.insert_drive_file_rounded);
    }
    if (raw.isEmpty) return ChatListPreview(_s(ctx, 'chatlist_new_conversation'));
    if (ChatListValidators.isEncrypted(raw)) return ChatListPreview(_s(ctx, 'chatlist_protected_message'), icon: Icons.lock_rounded);
    if (ChatListValidators.isImageFile(raw)) return ChatListPreview(_s(ctx, 'chatlist_photo'), icon: Icons.photo_camera_rounded);
    if (ChatListValidators.isVideoFile(raw)) return ChatListPreview(_s(ctx, 'chatlist_video'), icon: Icons.videocam_rounded);
    if (ChatListValidators.isAudioFile(raw)) return ChatListPreview(_s(ctx, 'chatlist_audio_message'), icon: Icons.mic_rounded);
    if (raw.contains('PRODUCT_REF')) return ChatListPreview(_s(ctx, 'chatlist_product', fb: 'Produit partagé'), icon: Icons.shopping_bag_outlined);
    return ChatListPreview(ChatListValidators.sanitize(raw, maxLength: _kMaxPreviewLength, singleLine: true));
  }

  bool _isEscalationPending(ChatConversation conv) => conv.isEscalation && (conv.unreadCount > 0 || (conv.escalatedByName?.isNotEmpty ?? false));

  // ==========================================================================
  // MENU CONTEXTUEL
  // ==========================================================================
  void _showContextMenu(ChatConversation conv) {
    HapticFeedback.mediumImpact();
    final notifier = ref.read(chatListProvider.notifier);
    final avatar = ChatListValidators.sanitizeUrl(conv.displayAvatar);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(ThixPolicy.s20, ThixPolicy.s12, ThixPolicy.s20, ThixPolicy.s32 + MediaQuery.of(ctx).padding.bottom),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(ThixPolicy.rXl)),
          border: Border(top: BorderSide(color: ThixPolicy.border)),
        ),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: ThixPolicy.s20),
            Row(children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: ThixPolicy.surfaceSoft,
                backgroundImage: avatar != null ? CachedNetworkImageProvider(avatar) : null,
                child: avatar == null ? Text(ChatListValidators.safeInitial(conv.displayName), style: ThixPolicy.h3Style) : null,
              ),
              const SizedBox(width: ThixPolicy.s12),
              Expanded(
                child: Text(ChatListValidators.sanitize(conv.displayName, maxLength: 40),
                    style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: ThixPolicy.s20),
            const Divider(height: 1),
            const SizedBox(height: ThixPolicy.s8),
            _ctxItem(
              icon: conv.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              label: conv.isPinned ? _s(ctx, 'chatlist_unpin') : _s(ctx, 'chatlist_pin'),
              subtitle: conv.isPinned ? _s(ctx, 'chatlist_unpin_subtitle') : _s(ctx, 'chatlist_pin_subtitle', args: ['$_kMaxPinned']),
              color: ThixPolicy.gold,
              enabled: !conv.isPinned ? ref.read(chatListProvider).canPin : true,
              onTap: () {
                Navigator.pop(ctx);
                _guard(() => notifier.togglePin(conv.id));
              },
            ),
            _ctxItem(
              icon: conv.isArchived ? Icons.unarchive_rounded : Icons.archive_outlined,
              label: conv.isArchived ? _s(ctx, 'chatlist_unarchive') : _s(ctx, 'chatlist_archive'),
              subtitle: conv.isArchived ? _s(ctx, 'chatlist_unarchive_subtitle') : _s(ctx, 'chatlist_archive_subtitle'),
              color: kInk,
              onTap: () {
                Navigator.pop(ctx);
                _guard(() => notifier.toggleArchive(conv.id));
              },
            ),
            _ctxItem(
              icon: conv.isCurrentlyMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              label: conv.isCurrentlyMuted ? _s(ctx, 'chatlist_unmute') : _s(ctx, 'chatlist_mute'),
              subtitle: conv.isCurrentlyMuted ? _s(ctx, 'chatlist_mute_remaining', args: [conv.muteRemainingText]) : _s(ctx, 'chatlist_mute_choose'),
              color: conv.isCurrentlyMuted ? ThixPolicy.success : ThixPolicy.warning,
              onTap: () {
                Navigator.pop(ctx);
                if (conv.isCurrentlyMuted) {
                  _guard(() => notifier.toggleMute(conv.id));
                } else {
                  _showMuteDurationPicker(conv.id);
                }
              },
            ),
            _ctxItem(
              icon: conv.isLocked ? Icons.lock_rounded : Icons.lock_outline_rounded,
              label: conv.isLocked ? _s(ctx, 'chatlist_unlock') : _s(ctx, 'chatlist_lock'),
              subtitle: conv.isLocked ? _s(ctx, 'chatlist_unlock_subtitle') : _s(ctx, 'chatlist_lock_subtitle_pwd'),
              color: ThixPolicy.danger,
              onTap: () async {
                Navigator.pop(ctx);
                if (conv.isLocked) {
                  final ok = await _promptUnlock(conv);
                  if (!ok) {
                    _showInfo(_s(context, 'chatlist_locked_denied'));
                    return;
                  }
                  await _guard(() => notifier.toggleLock(conv.id));
                  return;
                }
                if (!await ChatLockVault.hasPassword()) {
                  final defined = await _defineLockPassword();
                  if (!defined) return;
                }
                if (!mounted) return;
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dctx) => AlertDialog(
                    backgroundColor: ThixPolicy.card,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
                    title: Text(_s(dctx, 'chatlist_lock_confirm_title'), style: ThixPolicy.titleStyle),
                    content: Text(_s(dctx, 'chatlist_lock_confirm_message_pwd'), style: ThixPolicy.bodyStyle),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dctx, false), child: Text(_s(dctx, 'common_cancel'))),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger),
                        onPressed: () => Navigator.pop(dctx, true),
                        child: Text(_s(dctx, 'chatlist_lock'), style: const TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
                await _guard(() => notifier.toggleLock(conv.id));
              },
            ),
            if (conv.unreadCount == 0)
              _ctxItem(
                icon: Icons.mark_unread_chat_alt_rounded,
                label: _s(ctx, 'chatlist_mark_unread'),
                subtitle: _s(ctx, 'chatlist_mark_unread_subtitle'),
                color: kInk,
                onTap: () {
                  Navigator.pop(ctx);
                  _guard(() => notifier.markAsUnread(conv.id));
                },
              ),
            const Divider(height: 1),
            _ctxItem(
              icon: Icons.delete_outline_rounded,
              label: _s(ctx, 'chatlist_delete'),
              subtitle: _s(ctx, 'chatlist_delete_subtitle'),
              color: ThixPolicy.danger,
              onTap: () async {
                Navigator.pop(ctx);
                await _confirmAndDeleteSingle(conv);
              },
            ),
          ]),
        ),
      ),
    );
  }

  Widget _ctxItem({required IconData icon, required String label, required String subtitle, required Color color, required VoidCallback onTap, bool enabled = true}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        child: Opacity(
          opacity: enabled ? 1.0 : 0.4,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: ThixPolicy.s12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: ThixPolicy.titleStyle.copyWith(fontSize: 15, fontWeight: ThixPolicy.bold, color: enabled ? ThixPolicy.textMain : ThixPolicy.textMuted)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: ThixPolicy.captionStyle.copyWith(fontSize: 12, color: ThixPolicy.textSecondary)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _showMuteDurationPicker(String convId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(ThixPolicy.s20, ThixPolicy.s12, ThixPolicy.s20, ThixPolicy.s32 + MediaQuery.of(ctx).padding.bottom),
        decoration: const BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.vertical(top: Radius.circular(ThixPolicy.rXl))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: ThixPolicy.s20),
          Text(_s(ctx, 'chatlist_mute_title'), style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16)),
          const SizedBox(height: ThixPolicy.s20),
          _muteOption(ctx, _s(ctx, 'chatlist_mute_8h'), const Duration(hours: 8), convId),
          _muteOption(ctx, _s(ctx, 'chatlist_mute_1w'), const Duration(days: 7), convId),
          _muteOption(ctx, _s(ctx, 'chatlist_mute_forever'), null, convId),
        ]),
      ),
    );
  }

  Widget _muteOption(BuildContext ctx, String label, Duration? duration, String convId) {
    return ListTile(
      title: Text(label, style: ThixPolicy.titleStyle),
      leading: const Icon(Icons.timer_outlined, color: kInk),
      onTap: () async {
        Navigator.pop(ctx);
        await _guard(() => ref.read(chatListProvider.notifier).toggleMute(convId, duration: duration));
        _showSuccess(_s(context, 'chatlist_muted_success'));
      },
    );
  }

  Future<void> _confirmAndDeleteSingle(ChatConversation conv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Text(_s(ctx, 'chatlist_delete_title'), style: ThixPolicy.titleStyle),
        content: Text(_s(ctx, 'chatlist_delete_message'), style: ThixPolicy.bodyStyle),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_s(ctx, 'common_cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_s(ctx, 'common_delete'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final notifier = ref.read(chatListProvider.notifier);
    await _guard(() async {
      notifier.toggleSelection(conv.id);
      await notifier.bulkDelete();
    });
    _showSuccess(_s(context, 'chatlist_deleted'));
    _refreshAllCounters();
  }

  // ==========================================================================
  // BARRE D'ACTIONS GROUPÉES
  // ==========================================================================
  Widget _buildBulkActionsBar() {
    final state = ref.watch(chatListProvider);
    final notifier = ref.read(chatListProvider.notifier);
    return Positioned(
      bottom: 16 + MediaQuery.of(context).padding.bottom,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: ThixPolicy.border),
            boxShadow: ThixPolicy.shadowSoft(opacity: 0.12),
          ),
          child: Row(children: [
            Expanded(child: Text(_s(context, 'chatlist_selected_count', args: ['${state.selectedIds.length}']), style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold))),
            IconButton(
              icon: const Icon(Icons.archive_outlined),
              tooltip: _s(context, 'chatlist_archive'),
              onPressed: () async {
                await _guard(() => notifier.bulkArchive());
                _showSuccess(_s(context, 'chatlist_bulk_archived'));
              },
            ),
            IconButton(
              icon: const Icon(Icons.done_all_rounded),
              tooltip: _s(context, 'chatlist_mark_read'),
              onPressed: () async {
                await _guard(() => notifier.bulkMarkAsRead());
                _showSuccess(_s(context, 'chatlist_bulk_marked_read'));
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: ThixPolicy.danger),
              tooltip: _s(context, 'chatlist_delete'),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(_s(ctx, 'chatlist_delete_title')),
                    content: Text(_s(ctx, 'chatlist_bulk_delete_confirm', args: ['${state.selectedIds.length}'])),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_s(ctx, 'common_cancel'))),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(_s(ctx, 'common_delete'), style: const TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await _guard(() => notifier.bulkDelete());
                  _showSuccess(_s(context, 'chatlist_bulk_deleted'));
                }
              },
            ),
            IconButton(icon: const Icon(Icons.close_rounded), tooltip: _s(context, 'common_cancel'), onPressed: () => notifier.exitSelectionMode()),
          ]),
        ),
      ),
    );
  }

  // ==========================================================================
  // SNACKBARS
  // ==========================================================================
  void _snack(String message, Color bg, {IconData? icon, Duration? duration}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          if (icon != null) ...[Icon(icon, color: Colors.white, size: 18), const SizedBox(width: 8)],
          Expanded(child: Text(message)),
        ]),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        duration: duration ?? const Duration(milliseconds: 2200),
      ));
  }

  void _showSuccess(String m) => _snack(m, ThixPolicy.success, icon: Icons.check_circle_rounded);
  void _showError(String m) {
    HapticFeedback.lightImpact();
    _snack(m, ThixPolicy.danger, icon: Icons.error_outline_rounded, duration: const Duration(seconds: 3));
  }

  void _showInfo(String m) => _snack(m, kInk, duration: const Duration(seconds: 1));

  void _showUndo(String message, VoidCallback onUndo) {
    if (!mounted) return;
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: kInk,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      action: SnackBarAction(label: _s(context, 'chatlist_undo'), textColor: Colors.white, onPressed: onUndo),
    ));
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    setState(() {});
    _searchDebounce = Timer(const Duration(milliseconds: _kSearchDebounceMs), () {
      if (!mounted) return;
      ref.read(chatListProvider.notifier).search(ChatListValidators.sanitize(v, maxLength: 100, singleLine: true));
    });
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatListProvider);
    final counters = ref.watch(notificationCountersProvider);

    ref.listen<NotificationCounters>(notificationCountersProvider, (previous, next) {
      if (!mounted) return;
      final prev = previous?.newConnections ?? 0;
      final now = next.newConnections;
      if (now > prev && now > 0) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(_s(context, 'chatlist_new_connections', args: ['$now']), style: const TextStyle(fontSize: 14))),
            ]),
            backgroundColor: kInk,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(label: _s(context, 'chatlist_network'), textColor: Colors.white, onPressed: () => _navigateTo(0)),
          ));
      }
    });

    final currentUser = ref.watch(authControllerProvider).value;
    final currentUserName = ChatListValidators.sanitize(currentUser?.displayName ?? '', maxLength: _kMaxChatNameLength);
    final currentUserId = currentUser?.id ?? '';
    final currentUserPhoto = ChatListValidators.sanitizeUrl(currentUser?.photoUrl);
    final onlineUserIds = ref.watch(presenceProvider);

    final missedCalls = math.max(counters.missedCalls, _derivedMissedCalls(state.all, currentUserId));
    final newConnections = counters.newConnections;

    final seen = <String>{};
    final onlineContacts = <ChatConversation>[];
    for (final c in state.filtered) {
      if (c.isGroup || c.isLocked) continue;
      final oid = c.participantIds.firstWhere((id) => id != currentUserId, orElse: () => '');
      if (oid.isNotEmpty && onlineUserIds.onlineUserIds.contains(oid) && seen.add(oid)) onlineContacts.add(c);
    }

    final bellBadge = state.pendingEscalations > 0 || state.totalUnread > 0 || missedCalls > 0 || newConnections > 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (state.isSelectionMode) {
          ref.read(chatListProvider.notifier).exitSelectionMode();
        } else if (_selectedNav != 1) {
          setState(() => _selectedNav = 1);
        } else {
          _goToHomepage();
        }
      },
      child: Scaffold(
        backgroundColor: ThixPolicy.surfaceSoft,
        bottomNavigationBar: state.isSelectionMode
            ? null
            : ChatBottomNav(
                selected: _selectedNav,
                networkBadge: newConnections,
                chatBadge: state.totalUnread,
                callsBadge: missedCalls,
                onTap: _navigateTo,
                onCreate: _showCreateMenu,
                onDoubleTapChats: _scrollTop,
              ),
        body: Stack(children: [
          Positioned(top: -100, right: -50, child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: kInk.withOpacity(0.04)))),
          Positioned(bottom: 100, left: -100, child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: ThixPolicy.gold.withOpacity(0.05)))),
          state.isLoading
              ? const Center(child: CircularProgressIndicator(color: kInk, strokeWidth: 3))
              : RefreshIndicator(
                  color: kInk,
                  backgroundColor: ThixPolicy.card,
                  onRefresh: () async {
                    HapticFeedback.selectionClick();
                    _refreshAllCounters();
                  },
                  child: CustomScrollView(
                    controller: _scroll,
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    slivers: [
                      SliverAppBar(
                        pinned: true,
                        expandedHeight: kToolbarHeight + 20,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        scrolledUnderElevation: 2,
                        flexibleSpace: Container(
                          color: ThixPolicy.surfaceSoft,
                          padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text('THIX Chat', style: ThixPolicy.h1Style.copyWith(fontSize: 24, fontWeight: ThixPolicy.bold, letterSpacing: -0.5)),
                              Row(children: [
                                _iconButtonGlass(
                                  icon: Icons.swap_vert_rounded,
                                  semanticsLabel: _s(context, 'chatlist_escalations'),
                                  badge: state.pendingEscalations > 0,
                                  onTap: () => context.pushNamed('chatEscalationReceived'),
                                ),
                                const SizedBox(width: ThixPolicy.s12),
                                _iconButtonGlass(icon: Icons.menu_book_outlined, semanticsLabel: _s(context, 'chatlist_notebook'), onTap: _openNotebook),
                                const SizedBox(width: ThixPolicy.s12),
                                _iconButtonGlass(
                                  icon: Icons.notifications_none_rounded,
                                  semanticsLabel: _s(context, 'chatlist_notifications'),
                                  badge: bellBadge,
                                  onTap: () => _openNotifications(state.pendingEscalations, missedCalls, newConnections),
                                ),
                              ]),
                            ]),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(ThixPolicy.s20, ThixPolicy.s8, ThixPolicy.s20, ThixPolicy.s12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            StatusStoryRow(currentUserId: currentUserId, currentUserAvatar: currentUserPhoto, currentUserName: currentUserName),
                            if (onlineContacts.isNotEmpty) ...[
                              const SizedBox(height: ThixPolicy.s16),
                              SizedBox(
                                height: 64,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: onlineContacts.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s16),
                                  itemBuilder: (c, i) {
                                    final conv = onlineContacts[i];
                                    final label = ChatListValidators.sanitize(conv.displayName.split(' ').first, maxLength: 20);
                                    return _onlineAvatarNode(
                                      label: label.isEmpty ? '?' : label,
                                      avatarUrl: ChatListValidators.sanitizeUrl(conv.displayAvatar),
                                      onTap: () => _openConversation(conv),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ]),
                        ),
                      ),
                      SliverToBoxAdapter(child: _buildSearchBarGlass()),
                      if (state.pendingEscalations > 0) SliverToBoxAdapter(child: _buildEscalationBanner(state.pendingEscalations)),
                      SliverToBoxAdapter(child: _buildFilters(state.filterIndex, state.totalUnread)),
                      if (state.totalUnread > 0 && state.filterIndex == 0 && !_onlyEscalations)
                        SliverToBoxAdapter(child: _buildUnreadStrip(state.totalUnread)),
                      const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s8)),
                      SliverPadding(
                        padding: const EdgeInsets.only(top: 4),
                        sliver: _chatListSliver(state, currentUserId, currentUserName, onlineUserIds.onlineUserIds),
                      ),
                      if (state.isLoadingMore)
                        const SliverToBoxAdapter(
                          child: Padding(padding: EdgeInsets.symmetric(vertical: 28), child: Center(child: CircularProgressIndicator(color: kInk, strokeWidth: 3))),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 110)),
                    ],
                  ),
                ),
          if (state.isSelectionMode) _buildBulkActionsBar(),
        ]),
      ),
    );
  }

  Widget _iconButtonGlass({required IconData icon, required String semanticsLabel, required VoidCallback onTap, bool badge = false}) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: ThixPolicy.card, shape: BoxShape.circle, border: Border.all(color: ThixPolicy.border), boxShadow: ThixPolicy.shadowSoft(opacity: 0.04)),
          child: Stack(alignment: Alignment.center, children: [
            Icon(icon, size: 20, color: ThixPolicy.textMain),
            if (badge)
              Positioned(
                top: 8,
                right: 8,
                child: Container(width: 8, height: 8, decoration: BoxDecoration(color: ThixPolicy.danger, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5))),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _onlineAvatarNode({required String label, required String? avatarUrl, VoidCallback? onTap}) {
    return Semantics(
      button: true,
      label: '$label (${_s(context, 'chatlist_online')})',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap?.call();
        },
        child: SizedBox(
          width: 52,
          child: Column(children: [
            Stack(children: [
              Container(
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ThixPolicy.card, width: 2), boxShadow: ThixPolicy.shadowSoft(opacity: 0.05)),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: ThixPolicy.surface,
                  backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                  child: avatarUrl == null ? const Icon(Icons.person, color: ThixPolicy.textSecondary, size: 20) : null,
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(width: 12, height: 12, decoration: BoxDecoration(color: ThixPolicy.success, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
              ),
            ]),
            const SizedBox(height: 4),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: ThixPolicy.captionStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain)),
          ]),
        ),
      ),
    );
  }

  Widget _buildSearchBarGlass() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(ThixPolicy.s20, 0, ThixPolicy.s20, ThixPolicy.s16),
      child: Container(
        height: 44,
        decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(ThixPolicy.inputRadius), border: Border.all(color: ThixPolicy.border)),
        child: Semantics(
          label: _s(context, 'chatlist_search_label'),
          textField: true,
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMain, fontWeight: ThixPolicy.medium),
            decoration: InputDecoration(
              hintText: _s(context, 'chatlist_search_hint'),
              hintStyle: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: ThixPolicy.textSecondary),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: ThixPolicy.textSecondary),
                      tooltip: _s(context, 'common_clear'),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _searchDebounce?.cancel();
                        _searchCtrl.clear();
                        setState(() {});
                        ref.read(chatListProvider.notifier).search('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEscalationBanner(int pending) {
    return Semantics(
      button: true,
      label: _s(context, 'chatlist_pending_escalations'),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          context.pushNamed('chatEscalationReceived');
        },
        child: Container(
          margin: const EdgeInsets.fromLTRB(ThixPolicy.s20, 0, ThixPolicy.s20, ThixPolicy.s12),
          padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s12),
          decoration: BoxDecoration(color: ThixPolicy.danger.withOpacity(0.08), borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: ThixPolicy.danger.withOpacity(0.25))),
          child: Row(children: [
            const PulseDot(color: ThixPolicy.danger, size: 10),
            const SizedBox(width: ThixPolicy.s12),
            Expanded(child: Text('$pending ${_s(context, 'chatlist_pending_escalations')}', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.danger, fontWeight: ThixPolicy.bold))),
            const Icon(Icons.arrow_forward_ios_rounded, color: ThixPolicy.danger, size: 12),
          ]),
        ),
      ),
    );
  }

  Widget _buildUnreadStrip(int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(ThixPolicy.s20, ThixPolicy.s12, ThixPolicy.s20, 0),
      child: Row(children: [
        Container(width: 8, height: 8, decoration: const BoxDecoration(color: kInk, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Text('$total ${_s(context, 'chatlist_unread_label')}', style: ThixPolicy.captionStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain)),
        ),
        GestureDetector(
          onTap: _markAllAsRead,
          child: Text(_s(context, 'chatlist_mark_all_read'), style: ThixPolicy.captionStyle.copyWith(fontWeight: ThixPolicy.bold, color: kInk, decoration: TextDecoration.underline)),
        ),
      ]),
    );
  }

  Widget _chip({required String label, required bool selected, required VoidCallback onTap, IconData? icon, Color? accent}) {
    final base = accent ?? kInk;
    return Padding(
      padding: const EdgeInsets.only(right: ThixPolicy.s8),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? base : ThixPolicy.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? base : ThixPolicy.border, width: 1.2),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, size: 14, color: selected ? Colors.white : base), const SizedBox(width: 5)],
              Text(label, style: ThixPolicy.bodySmallStyle.copyWith(fontWeight: selected ? ThixPolicy.bold : ThixPolicy.semiBold, color: selected ? Colors.white : ThixPolicy.textSecondary)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(int selected, int totalUnread) {
    final labels = [
      _s(context, 'chatlist_filter_all'),
      totalUnread > 0 ? '${_s(context, 'chatlist_filter_unread')} ($totalUnread)' : _s(context, 'chatlist_filter_unread'),
      _s(context, 'chatlist_filter_teams'),
      _s(context, 'chatlist_filter_personal'),
      _s(context, 'chatlist_filter_pinned'),
      _s(context, 'chatlist_filter_archived'),
    ];
    return SizedBox(
      height: 34,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < _filterCount; i++)
            _chip(
              label: labels[i],
              selected: selected == i && !_onlyEscalations,
              onTap: () {
                if (_onlyEscalations) setState(() => _onlyEscalations = false);
                ref.read(chatListProvider.notifier).setFilter(i);
              },
            ),
          _chip(
            label: _s(context, 'chatlist_filter_escalations', fb: 'Escalades'),
            icon: Icons.swap_vert_rounded,
            accent: ThixPolicy.danger,
            selected: _onlyEscalations,
            onTap: () => setState(() => _onlyEscalations = !_onlyEscalations),
          ),
        ],
      ),
    );
  }

  Widget _chatListSliver(dynamic state, String currentUserId, String currentUserName, Set<String> onlineUserIds) {
    List<ChatConversation> list = state.filtered;
    if (_onlyEscalations) list = list.where((c) => c.isEscalation).toList();

    if (list.isEmpty) {
      final searching = _searchCtrl.text.trim().isNotEmpty;
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 80),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, shape: BoxShape.circle, border: Border.all(color: ThixPolicy.border)),
              child: Icon(searching ? Icons.search_off_rounded : Icons.chat_bubble_outline_rounded, size: 40, color: ThixPolicy.textSecondary),
            ),
            const SizedBox(height: ThixPolicy.s16),
            Text(
              searching
                  ? _s(context, 'chatlist_no_results')
                  : (_onlyEscalations
                      ? _s(context, 'chatlist_no_escalation', fb: 'Aucune escalade')
                      : (state.filterIndex == ChatFilter.archived ? _s(context, 'chatlist_no_archived') : _s(context, 'chatlist_no_conversation'))),
              style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.textSecondary),
            ),
          ]),
        ),
      );
    }

    final bool selectionMode = state.isSelectionMode as bool;
    final Set selectedIds = state.selectedIds as Set;

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, idx) {
          final conv = list[idx];
          final last = conv.lastMessage;
          final t = last?.createdAt ?? conv.updatedAt;
          final unread = conv.unreadCount > 0;
          final isSelected = selectedIds.contains(conv.id);

          final otherUserId = conv.participantIds.firstWhere((id) => id != currentUserId, orElse: () => '');
          final isOnline = onlineUserIds.contains(otherUserId);

          String chatName = ChatListValidators.sanitize(conv.displayName, maxLength: _kMaxChatNameLength);
          final chatAvatar = ChatListValidators.sanitizeUrl(conv.displayAvatar);
          if (conv.isGroup) {
            if (chatName.isEmpty) chatName = _s(context, 'chatlist_group_thix');
          } else if (chatName.trim() == currentUserName.trim() || chatName.isEmpty) {
            final shortId = otherUserId.length > 4 ? otherUserId.substring(0, 4) : otherUserId;
            chatName = '${_s(context, 'chatlist_contact_thix')} (ID: $shortId)';
          }

          final tile = RepaintBoundary(
            child: ConversationTile(
              conv: conv,
              chatName: chatName,
              chatAvatar: chatAvatar,
              isOnline: isOnline,
              unread: unread,
              isSelected: isSelected,
              escalationPending: _isEscalationPending(conv),
              currentUserId: currentUserId,
              otherUserId: otherUserId,
              lastMessage: last,
              timeText: _fmt(t),
              preview: _buildPreview(conv, currentUserId),
              onTap: () {
                if (selectionMode) {
                  ref.read(chatListProvider.notifier).toggleSelection(conv.id);
                } else {
                  _openConversation(conv);
                }
              },
              onLongPress: () {
                final n = ref.read(chatListProvider.notifier);
                if (!selectionMode) n.enterSelectionMode();
                n.toggleSelection(conv.id);
              },
              onContextMenu: () => _showContextMenu(conv),
            ),
          );

          return Dismissible(
            key: ValueKey('tile_${conv.id}'),
            direction: selectionMode ? DismissDirection.none : DismissDirection.horizontal,
            confirmDismiss: (dir) async {
              HapticFeedback.selectionClick();
              final notifier = ref.read(chatListProvider.notifier);
              if (dir == DismissDirection.endToStart) {
                final wasArchived = conv.isArchived;
                await _guard(() => notifier.toggleArchive(conv.id));
                _showUndo(wasArchived ? _s(context, 'chatlist_unarchived') : _s(context, 'chatlist_archived'), () => _guard(() => notifier.toggleArchive(conv.id)));
              } else if (unread) {
                await _guard(() => notifier.markAsRead(conv.id));
                _showInfo(_s(context, 'chatlist_marked_read'));
              } else {
                await _guard(() => notifier.markAsUnread(conv.id));
                _showInfo(_s(context, 'chatlist_marked_unread'));
              }
              return false;
            },
            background: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 24),
              color: kInk.withOpacity(0.10),
              child: const Icon(Icons.done_all_rounded, color: kInk),
            ),
            secondaryBackground: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              color: ThixPolicy.warning.withOpacity(0.12),
              child: const Icon(Icons.archive_outlined, color: ThixPolicy.warning),
            ),
            child: tile,
          );
        },
        childCount: list.length,
      ),
    );
  }

  String _fmt(DateTime d) {
    final localDate = d.toLocal();
    final now = DateTime.now();
    final day = DateTime(localDate.year, localDate.month, localDate.day);
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return DateFormat('HH:mm').format(localDate);
    if (day == today.subtract(const Duration(days: 1))) return _s(context, 'chatlist_yesterday');
    if (now.difference(localDate).inDays < 7) {
      try {
        return DateFormat('EEEE', Localizations.localeOf(context).languageCode).format(localDate);
      } catch (_) {
        return DateFormat('EEEE', 'fr_FR').format(localDate);
      }
    }
    return DateFormat('dd/MM/yy').format(localDate);
  }
}
