// lib/presentation/chat/chat_list_page.dart
//
// ChatListPage — v5.3 (enterprise)
// ✅ BLEU au lieu de VERT (couleurs professionnelles)
// ✅ Cartes demandes de connexion compactes (180px)
// ✅ Status style WhatsApp
// ✅ Online contacts repositionnés
//

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
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
import 'package:thix_id/presentation/chat/connections_page.dart';
import 'package:thix_id/presentation/chat/providers/chat_list_provider.dart';
import 'package:thix_id/presentation/chat/providers/chat_notification_counters_provider.dart';
import 'package:thix_id/presentation/chat/providers/presence_provider.dart';
import 'package:thix_id/presentation/chat/providers/status_provider.dart';
import 'package:thix_id/presentation/chat/screens/group_create_page.dart';
import 'package:thix_id/presentation/chat/settings/chat_settings_page.dart';
import 'package:thix_id/presentation/chat/widgets/status_story_row.dart';
import 'package:thix_id/services/biometric_service.dart';
import 'package:thix_id/services/chat/connection_service.dart';

import 'chat_screen.dart';
import 'new_conversation_page.dart';
import 'widgets/chat_list_widgets.dart';

// ════════════════════════════════════════════════════════════════════════════
// DESIGN TOKENS — Ardoise + BLEU (plus professionnel)
// ════════════════════════════════════════════════════════════════════════════
class Ct {
  Ct._();

  // Ardoise (slate) — base neutre
  static const Color ink       = Color(0xFF0F172A); // slate-900
  static const Color inkSoft   = Color(0xFF1E293B); // slate-800
  static const Color slate     = Color(0xFF475569); // slate-600
  static const Color slateLt   = Color(0xFF94A3B8); // slate-400
  static const Color mist      = Color(0xFFE2E8F0); // slate-200

  // Accent BLEU — actions primaires (remplace le vert)
  static const Color accent    = Color(0xFF2563EB); // blue-600
  static const Color accentDp  = Color(0xFF1D4ED8); // blue-700
  static const Color accentSoft= Color(0xFF3B82F6); // blue-500

  // Sémantique
  static const Color danger    = Color(0xFFDC2626);
  static const Color warning   = Color(0xFFD97706);
  static const Color success   = Color(0xFF059669); // gardé pour succès uniquement
  static const Color online    = Color(0xFF22C55E); // gardé pour statut online

  // Rayons
  static const double rSm = 10, rMd = 14, rLg = 20, rXl = 24, rPill = 28;

  // Espacements (base 4)
  static const double s1 = 4, s2 = 8, s3 = 12, s4 = 16, s5 = 24, s6 = 32;

  // Accessibilité : cible tactile minimale
  static const double hitMin = 40;

  static List<BoxShadow> shadow(Color base,
          {double a = 0.05, double blur = 14, double y = 4}) =>
      [BoxShadow(color: base.withValues(alpha: a), blurRadius: blur, offset: Offset(0, y))];

  // Surfaces adaptatives clair / sombre
  static bool isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
  static Color surface(BuildContext c) =>
      isDark(c) ? const Color(0xFF0B1120) : const Color(0xFFF1F5F9);
  static Color card(BuildContext c) => isDark(c) ? const Color(0xFF151E30) : Colors.white;
  static Color textMain(BuildContext c) => isDark(c) ? const Color(0xFFF8FAFC) : ink;
  static Color textSecondary(BuildContext c) => isDark(c) ? slateLt : slate;
  static Color border(BuildContext c) =>
      isDark(c) ? Colors.white.withValues(alpha: 0.09) : mist;
}

// ════════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ════════════════════════════════════════════════════════════════════════════
final _connRequestsProvider = StateProvider<List<ConnectionRequest>>((ref) => []);
final _connRequestsLoadingProvider = StateProvider<bool>((ref) => false);

// ═══════════════════════════════════════════════════════════════════════════
// VERRE DÉPOLI
// ════════════════════════════════════════════════════════════════════════════
class CtGlass extends StatelessWidget {
  final Widget child;
  final double radius;
  final double alpha;
  final double blur;
  final EdgeInsetsGeometry? padding;

  const CtGlass({
    super.key,
    required this.child,
    this.radius = Ct.rLg,
    this.alpha = 0.78,
    this.blur = 14,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Ct.isDark(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (dark ? Ct.inkSoft : Colors.white)
                .withValues(alpha: dark ? math.min(alpha, 0.85) : alpha),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.09)
                  : Colors.white.withValues(alpha: 0.9),
              width: 1,
            ),
            boxShadow: Ct.shadow(Ct.ink, a: dark ? 0.3 : 0.04),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CONSTANTES
// ════════════════════════════════════════════════════════════════════════════
const int _kLoadMoreThresholdPx = 300;
const int _kLoadMoreThrottleMs = 500;
const int _kSearchDebounceMs = 300;
const int _kMaxChatNameLength = 80;
const int _kMaxPreviewLength = 140;
const int _kMaxPinned = 3;
const String _kCallsSeenKey = 'thix_chat_calls_seen_at_v1';
const String _kDraftPrefix = 'thix_chat_draft_v1_';

String _s(BuildContext ctx, String key, {List<String>? args, String? fb}) =>
    clS(ctx, key, args: args, fb: fb);

// ============================================================================
// PAGE
// ============================================================================
class ChatListPage extends ConsumerStatefulWidget {
  const ChatListPage({super.key});

  @override
  ConsumerState<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends ConsumerState<ChatListPage>
    with WidgetsBindingObserver {
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
    unawaited(_loadConnectionRequests());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(notificationCountersProvider.notifier)
          .refresh(immediate: true);
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

  // ==========================================================================
  // 🤝 DEMANDES DE CONNEXION
  // ==========================================================================
  Future<void> _loadConnectionRequests() async {
    try {
      ref.read(_connRequestsLoadingProvider.notifier).state = true;
      await ref.read(connectionsProvider.notifier).loadInitial();
      if (!mounted) return;
      final requests = ref.read(connectionsProvider).received;
      ref.read(_connRequestsProvider.notifier).state = requests;
    } catch (e) {
      debugPrint('[ChatList] ⚠️ connRequests: $e');
    } finally {
      if (mounted) {
        ref.read(_connRequestsLoadingProvider.notifier).state = false;
      }
    }
  }

  Future<void> _respondToRequest(ConnectionRequest req, bool accept) async {
    final id = req.id;
    final name = ChatListValidators.sanitize(
        req.sender?.displayName ?? '', maxLength: 30);
    HapticFeedback.mediumImpact();

    final current = ref.read(_connRequestsProvider);
    ref.read(_connRequestsProvider.notifier).state =
        current.where((r) => r.id != id).toList();

    try {
      final notifier = ref.read(connectionsProvider.notifier);
      bool success = false;

      if (accept) {
        success = await notifier.accept(id);
        if (success) {
          _showSuccess(_s(context, 'chatlist_request_accepted',
              fb: 'Vous êtes maintenant connecté(e) avec $name'));
        } else {
          _showError(_s(context, 'chatlist_request_error', fb: 'Échec de l’acceptation'));
        }
      } else {
        success = await notifier.reject(id);
        if (success) {
          _showInfo(_s(context, 'chatlist_request_declined',
              fb: 'Demande de $name refusée'));
        } else {
          _showError(_s(context, 'chatlist_request_error', fb: 'Échec du refus'));
        }
      }

      unawaited(ref.read(notificationCountersProvider.notifier).refresh());
    } catch (e) {
      debugPrint('[ChatList] ❌ respondToRequest: $e');
      _showError(_errMsg(e));
      unawaited(_loadConnectionRequests());
    }
  }

  // ==========================================================================
  // 🟢 AVATAR CONTACT EN LIGNE (WhatsApp style - plus compact)
  // ==========================================================================
  Widget _onlineAvatarNode({
    required String label,
    required String? avatarUrl,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Container(
                  width: 56, // WhatsApp size
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Ct.accent.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: Ct.surface(context),
                    backgroundImage: avatarUrl != null
                        ? CachedNetworkImageProvider(avatarUrl)
                        : null,
                    child: avatarUrl == null
                        ? Text(
                            ChatListValidators.safeInitial(label),
                            style: ThixPolicy.titleStyle.copyWith(
                              color: Ct.accentDp,
                              fontWeight: ThixPolicy.bold,
                              fontSize: 18,
                            ),
                          )
                        : null,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Ct.online,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Ct.card(context),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 64,
              child: Text(
                label,
                style: ThixPolicy.microStyle.copyWith(
                  color: Ct.textSecondary(context),
                  fontWeight: ThixPolicy.medium,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >
        _scroll.position.maxScrollExtent - _kLoadMoreThresholdPx) {
      final now = DateTime.now();
      if (_lastLoadMore != null &&
          now.difference(_lastLoadMore!).inMilliseconds <
              _kLoadMoreThrottleMs) {
        return;
      }
      _lastLoadMore = now;
      ref.read(chatListProvider.notifier).loadMore();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAllCounters();
      ref
          .read(notificationCountersProvider.notifier)
          .refresh(immediate: true);
    }
  }

  void _refreshAllCounters() {
    unawaited(ref
        .read(notificationCountersProvider.notifier)
        .refresh()
        .catchError(
            (e) => debugPrint('[ChatList] ⚠️ Counters: $e')));
    unawaited(ref
        .read(chatListProvider.notifier)
        .refresh(silent: true)
        .catchError((e) => debugPrint('[ChatList] ⚠️ List: $e')));
    unawaited(ref
        .read(statusProvider.notifier)
        .refresh()
        .catchError((_) {}));
    unawaited(_loadDrafts());
    unawaited(_loadConnectionRequests());
  }

  void _scrollTop() {
    HapticFeedback.selectionClick();
    if (_scroll.hasClients) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut);
    }
  }

  // ==========================================================================
  //  APPELS MANQUÉS
  // ==========================================================================
  Future<void> _loadCallsSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(_kCallsSeenKey);
      if (ms != null && mounted) {
        setState(() =>
            _callsSeenAt = DateTime.fromMillisecondsSinceEpoch(ms));
      }
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
        if (v != null && v.trim().isNotEmpty) {
          map[k.substring(prefix.length)] = v;
        }
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
    if (m.contains('network') || m.contains('socket')) {
      return _s(context, 'chatlist_err_network');
    }
    if (m.contains('permission') || m.contains('policy')) {
      return _s(context, 'chatlist_err_denied');
    }
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
    final ok = await showDialog<bool>(
        context: context, builder: (_) => const DefinePasswordDialog());
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
      builder: (_) => UnlockDialog(
        name: ChatListValidators.sanitize(conv.displayName, maxLength: 40),
        bioAvailable: bio,
      ),
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
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ChatScreen(conversationId: conv.id, conversation: conv),
      ),
    );
    if (!mounted) return;
    _refreshAllCounters();
    unawaited(
        Future.delayed(const Duration(milliseconds: 350), _loadDrafts));
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
      if (saved == true) {
        _showSuccess(_s(context, 'chatlist_notebook_saved'));
      }
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
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CallHistoryPage()),
        ).then((_) {
          if (mounted) _refreshAllCounters();
        });
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChatSettingsPage()),
        ).then((_) {
          if (mounted) _refreshAllCounters();
        });
        break;
    }
  }

  void _goToHomepage() => context.go('/');

  Future<void> _markAllAsRead() async {
    final convs = ref
        .read(chatListProvider)
        .all
        .where((c) => c.unreadCount > 0)
        .take(30)
        .toList();
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

  Widget _notifTile(BuildContext ctx,
      {required IconData icon,
      required Color color,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return Semantics(
      button: true,
      label: title,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: Ct.s5, vertical: Ct.s3),
        leading: Container(
          width: Ct.hitMin + 8,
          height: Ct.hitMin + 8,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(Ct.rMd),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title,
            style: ThixPolicy.titleStyle.copyWith(
                fontWeight: ThixPolicy.bold,
                fontSize: 15,
                color: Ct.textMain(ctx))),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(subtitle,
              style: ThixPolicy.bodySmallStyle
                  .copyWith(color: Ct.textSecondary(ctx))),
        ),
        trailing: Icon(Icons.chevron_right_rounded,
            color: Ct.textSecondary(ctx)),
        onTap: onTap,
      ),
    );
  }

  void _openNotifications(
      int pending, int missedCalls, int newConnections) {
    HapticFeedback.selectionClick();
    final totalUnread = ref.read(chatListProvider).totalUnread;
    final empty = pending == 0 &&
        totalUnread == 0 &&
        missedCalls == 0 &&
        newConnections == 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.62),
        decoration: BoxDecoration(
          color: Ct.card(ctx),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(Ct.rXl)),
          border: Border(top: BorderSide(color: Ct.border(ctx))),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: Ct.s3),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Ct.border(ctx),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Ct.s5, Ct.s4, Ct.s5, Ct.s4),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(Ct.s2),
                decoration: BoxDecoration(
                  color: Ct.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(Ct.rSm),
                ),
                child: const Icon(Icons.notifications_rounded,
                    color: Ct.accentDp, size: 20),
              ),
              const SizedBox(width: Ct.s3),
              Text(_s(ctx, 'chatlist_notifications'),
                  style: ThixPolicy.h3Style.copyWith(
                      fontWeight: ThixPolicy.bold,
                      letterSpacing: -0.3,
                      color: Ct.textMain(ctx),
                  )),
            ]),
          ),
          Divider(height: 1, color: Ct.border(ctx)),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              if (newConnections > 0)
                _notifTile(
                  ctx,
                  icon: Icons.person_add_alt_1_rounded,
                  color: Ct.accent,
                  title: _s(ctx, 'chatlist_new_connections',
                      args: ['$newConnections']),
                  subtitle: _s(ctx, 'chatlist_see_in_list',
                      fb: 'Voir dans la liste des discussions'),
                  onTap: () => Navigator.pop(ctx),
                ),
              if (pending > 0)
                _notifTile(
                  ctx,
                  icon: Icons.swap_vert_rounded,
                  color: Ct.danger,
                  title: _s(ctx, 'chatlist_pending_escalations'),
                  subtitle: _s(ctx, 'chatlist_requires_action'),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.pushNamed('chatEscalationReceived');
                  },
                ),
              if (missedCalls > 0)
                _notifTile(
                  ctx,
                  icon: Icons.call_missed_rounded,
                  color: Ct.danger,
                  title: _s(ctx, 'chatlist_missed_calls',
                      args: ['$missedCalls']),
                  subtitle: _s(ctx, 'chatlist_tap_to_view'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _navigateTo(2);
                  },
                ),
              if (totalUnread > 0)
                _notifTile(
                  ctx,
                  icon: Icons.done_all_rounded,
                  color: Ct.ink,
                  title: _s(ctx, 'chatlist_mark_all_read'),
                  subtitle:
                      '$totalUnread ${_s(ctx, 'chatlist_unread_label')}',
                  onTap: () {
                    Navigator.pop(ctx);
                    _markAllAsRead();
                  },
                ),
              if (empty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text(
                      _s(ctx, 'chatlist_no_recent'),
                      style: ThixPolicy.bodyStyle
                          .copyWith(color: Ct.textSecondary(ctx)),
                    ),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: Ct.s5),
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
        padding: EdgeInsets.fromLTRB(
            Ct.s5,
            Ct.s3,
            Ct.s5,
            Ct.s6 + MediaQuery.of(ctx).padding.bottom),
        decoration: BoxDecoration(
          color: Ct.card(ctx),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(Ct.rXl)),
          border: Border(top: BorderSide(color: Ct.border(ctx))),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Ct.border(ctx),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: Ct.s5),
          _sheetOpt(
            ctx,
            Icons.chat_bubble_outline_rounded,
            _s(ctx, 'chatlist_new_discussion'),
            _s(ctx, 'chatlist_start_private'),
            () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const NewConversationPage()),
            ),
          ),
          const SizedBox(height: Ct.s3),
          _sheetOpt(
            ctx,
            Icons.group_add_outlined,
            _s(ctx, 'chatlist_create_group'),
            _s(ctx, 'chatlist_collaborate_team'),
            () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const GroupCreatePage()),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _sheetOpt(
      BuildContext ctx, IconData icon, String title, String subtitle, VoidCallback tap) {
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
          borderRadius: BorderRadius.circular(Ct.rLg),
          child: Container(
            padding: const EdgeInsets.all(Ct.s4),
            decoration: BoxDecoration(
              color: Ct.surface(ctx),
              border: Border.all(color: Ct.border(ctx)),
              borderRadius: BorderRadius.circular(Ct.rLg),
            ),
            child: Row(children: [
              Container(
                width: Ct.hitMin + 8,
                height: Ct.hitMin + 8,
                decoration: BoxDecoration(
                  color: Ct.card(ctx),
                  borderRadius: BorderRadius.circular(Ct.rMd),
                  border: Border.all(color: Ct.border(ctx)),
                ),
                child: Icon(icon, size: 22, color: Ct.accentDp),
              ),
              const SizedBox(width: Ct.s4),
              Expanded(
                child:
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title,
                      style: ThixPolicy.titleStyle.copyWith(
                          fontSize: 15,
                          fontWeight: ThixPolicy.bold,
                          letterSpacing: -0.2,
                          color: Ct.textMain(ctx),
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: ThixPolicy.bodySmallStyle.copyWith(
                          fontSize: 12,
                          fontWeight: ThixPolicy.medium,
                          color: Ct.textSecondary(ctx),
                      )),
                ]),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: Ct.textSecondary(ctx)),
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
    if (conv.isLocked) {
      return ChatListPreview(_s(ctx, 'chatlist_locked_preview'),
          icon: Icons.lock_rounded);
    }
    final localDraft = _drafts[conv.id];
    final draftRaw = (localDraft != null && localDraft.trim().isNotEmpty)
        ? localDraft
        : conv.draft;
    final draft = ChatListValidators.sanitize(draftRaw,
        maxLength: 100, singleLine: true);
    if (draft.isNotEmpty) {
      return ChatListPreview(draft,
          prefix: _s(ctx, 'chatlist_draft_prefix'));
    }
    final m = conv.lastMessage;
    if (m == null) {
      return ChatListPreview(_s(ctx, 'chatlist_new_conversation'));
    }
    if (m.isDeletedForAll || m.isDeleted) {
      return ChatListPreview(_s(ctx, 'chatlist_msg_deleted'),
          icon: Icons.block, color: Ct.slateLt);
    }
    if (m.isExpired) {
      return ChatListPreview(_s(ctx, 'chatlist_msg_expired'),
          icon: Icons.timer_outlined, color: Ct.slateLt);
    }
    final type = '${m.mediaType ?? ''}';
    final unread = conv.unreadCount > 0;
    if (type == 'system_screenshot') {
      return ChatListPreview(
        _s(ctx, 'chatlist_screenshot', fb: 'Capture d'écran effectuée'),
        icon: Icons.screenshot_rounded,
        color: Ct.warning,
      );
    }
    if (type == 'call_audio' || type == 'call_video') {
      final video = type == 'call_video';
      if (ChatListValidators.isMissedCallText(m.content)) {
        return ChatListPreview(
          _s(ctx,
              video ? 'chatlist_call_missed_video' : 'chatlist_call_missed'),
          icon: Icons.call_missed_rounded,
          color: Ct.danger,
          strong: unread,
        );
      }
      if (m.senderId == me) {
        return ChatListPreview(_s(ctx, 'chatlist_call_outgoing'),
            icon: Icons.call_made_rounded, color: Ct.success);
      }
      return ChatListPreview(_s(ctx, 'chatlist_call_incoming'),
          icon: Icons.call_received_rounded, color: Ct.slate);
    }
    if (type == 'image') {
      return ChatListPreview(_s(ctx, 'chatlist_photo'),
          icon: Icons.photo_camera_rounded);
    }
    if (type == 'video') {
      return ChatListPreview(_s(ctx, 'chatlist_video'),
          icon: Icons.videocam_rounded);
    }
    if (type == 'audio') {
      return ChatListPreview(_s(ctx, 'chatlist_audio_message'),
          icon: Icons.mic_rounded);
    }
    if (type == 'sticker') {
      return ChatListPreview(_s(ctx, 'chatlist_sticker'),
          icon: Icons.emoji_emotions_outlined);
    }
    final raw = m.content;
    if (type == 'file') {
      final name = ChatListValidators.sanitize(m.mediaName ?? raw,
          maxLength: 60, singleLine: true);
      return ChatListPreview(
          name.isEmpty ? '—' : name, icon: Icons.insert_drive_file_rounded);
    }
    if (raw.isEmpty) return ChatListPreview(_s(ctx, 'chatlist_new_conversation'));
    if (ChatListValidators.isEncrypted(raw)) {
      return ChatListPreview(_s(ctx, 'chatlist_protected_message'),
          icon: Icons.lock_rounded);
    }
    if (ChatListValidators.isImageFile(raw)) {
      return ChatListPreview(_s(ctx, 'chatlist_photo'),
          icon: Icons.photo_camera_rounded);
    }
    if (ChatListValidators.isVideoFile(raw)) {
      return ChatListPreview(_s(ctx, 'chatlist_video'),
          icon: Icons.videocam_rounded);
    }
    if (ChatListValidators.isAudioFile(raw)) {
      return ChatListPreview(_s(ctx, 'chatlist_audio_message'),
          icon: Icons.mic_rounded);
    }
    if (raw.contains('PRODUCT_REF')) {
      return ChatListPreview(_s(ctx, 'chatlist_product', fb: 'Produit partagé'),
          icon: Icons.shopping_bag_outlined);
    }
    return ChatListPreview(ChatListValidators.sanitize(raw,
        maxLength: _kMaxPreviewLength, singleLine: true));
  }

  bool _isEscalationPending(ChatConversation conv) =>
      conv.isEscalation &&
      (conv.unreadCount > 0 || (conv.escalatedByName?.isNotEmpty ?? false));

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
        padding: EdgeInsets.fromLTRB(
            Ct.s5,
            Ct.s3,
            Ct.s5,
            Ct.s6 + MediaQuery.of(ctx).padding.bottom),
        decoration: BoxDecoration(
          color: Ct.card(ctx),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(Ct.rXl)),
          border: Border(top: BorderSide(color: Ct.border(ctx))),
        ),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Ct.border(ctx),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: Ct.s4),
            Row(children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Ct.surface(ctx),
                backgroundImage: avatar != null
                    ? CachedNetworkImageProvider(avatar)
                    : null,
                child: avatar == null
                    ? Text(
                        ChatListValidators.safeInitial(conv.displayName),
                        style: ThixPolicy.h3Style
                            .copyWith(color: Ct.accentDp),
                      )
                    : null,
              ),
              const SizedBox(width: Ct.s3),
              Expanded(
                child: Text(
                  ChatListValidators.sanitize(conv.displayName,
                      maxLength: 40),
                  style: ThixPolicy.titleStyle.copyWith(
                      fontWeight: ThixPolicy.bold,
                      fontSize: 16,
                      color: Ct.textMain(ctx),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            const SizedBox(height: Ct.s4),
            Divider(height: 1, color: Ct.border(ctx)),
            const SizedBox(height: Ct.s2),
            _ctxItem(
              ctx,
              icon:
                  conv.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              label: conv.isPinned
                  ? _s(ctx, 'chatlist_unpin')
                  : _s(ctx, 'chatlist_pin'),
              subtitle: conv.isPinned
                  ? _s(ctx, 'chatlist_unpin_subtitle')
                  : _s(ctx, 'chatlist_pin_subtitle', args: ['$_kMaxPinned']),
              color: Ct.accent,
              enabled: !conv.isPinned
                  ? ref.read(chatListProvider).canPin
                  : true,
              onTap: () {
                Navigator.pop(ctx);
                _guard(() => notifier.togglePin(conv.id));
              },
            ),
            _ctxItem(
              ctx,
              icon: conv.isArchived
                  ? Icons.unarchive_rounded
                  : Icons.archive_outlined,
              label: conv.isArchived
                  ? _s(ctx, 'chatlist_unarchive')
                  : _s(ctx, 'chatlist_archive'),
              subtitle: conv.isArchived
                  ? _s(ctx, 'chatlist_unarchive_subtitle')
                  : _s(ctx, 'chatlist_archive_subtitle'),
              color: Ct.ink,
              onTap: () {
                Navigator.pop(ctx);
                _guard(() => notifier.toggleArchive(conv.id));
              },
            ),
            _ctxItem(
              ctx,
              icon: conv.isCurrentlyMuted
                  ? Icons.volume_off_rounded
                  : Icons.volume_up_rounded,
              label: conv.isCurrentlyMuted
                  ? _s(ctx, 'chatlist_unmute')
                  : _s(ctx, 'chatlist_mute'),
              subtitle: conv.isCurrentlyMuted
                  ? _s(ctx, 'chatlist_mute_remaining',
                      args: [conv.muteRemainingText])
                  : _s(ctx, 'chatlist_mute_choose'),
              color: conv.isCurrentlyMuted ? Ct.success : Ct.warning,
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
              ctx,
              icon: conv.isLocked
                  ? Icons.lock_rounded
                  : Icons.lock_outline_rounded,
              label: conv.isLocked
                  ? _s(ctx, 'chatlist_unlock')
                  : _s(ctx, 'chatlist_lock'),
              subtitle: conv.isLocked
                  ? _s(ctx, 'chatlist_unlock_subtitle')
                  : _s(ctx, 'chatlist_lock_subtitle_pwd'),
              color: Ct.danger,
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
                      backgroundColor: Ct.card(dctx),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Ct.rLg)),
                      title: Text(_s(dctx, 'chatlist_lock_confirm_title'),
                          style:
                              ThixPolicy.titleStyle.copyWith(color: Ct.textMain(dctx))),
                      content: Text(
                        _s(dctx, 'chatlist_lock_confirm_message_pwd'),
                        style: ThixPolicy.bodyStyle
                            .copyWith(color: Ct.textSecondary(dctx)),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dctx, false),
                          child: Text(_s(dctx, 'common_cancel')),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Ct.danger),
                          onPressed: () => Navigator.pop(dctx, true),
                          child: Text(_s(dctx, 'chatlist_lock'),
                              style: const TextStyle(color: Colors.white)),
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
                ctx,
                icon: Icons.mark_unread_chat_alt_rounded,
                label: _s(ctx, 'chatlist_mark_unread'),
                subtitle: _s(ctx, 'chatlist_mark_unread_subtitle'),
                color: Ct.ink,
                onTap: () {
                  Navigator.pop(ctx);
                  _guard(() => notifier.markAsUnread(conv.id));
                },
              ),
            Divider(height: 1, color: Ct.border(ctx)),
            _ctxItem(
              ctx,
              icon: Icons.delete_outline_rounded,
              label: _s(ctx, 'chatlist_delete'),
              subtitle: _s(ctx, 'chatlist_delete_subtitle'),
              color: Ct.danger,
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

  Widget _ctxItem(BuildContext ctx,
      {required IconData icon,
      required String label,
      required String subtitle,
      required Color color,
      required VoidCallback onTap,
      bool enabled = true}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(Ct.rMd),
        child: Opacity(
          opacity: enabled ? 1.0 : 0.4,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: Ct.s2),
            child: Row(children: [
              Container(
                width: Ct.hitMin + 4,
                height: Ct.hitMin + 4,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(Ct.rMd),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: Ct.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: ThixPolicy.titleStyle.copyWith(
                            fontSize: 15,
                            fontWeight: ThixPolicy.bold,
                            color: enabled
                                ? Ct.textMain(ctx)
                                : Ct.textSecondary(ctx),
                        )),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: ThixPolicy.captionStyle.copyWith(
                            fontSize: 12,
                            color: Ct.textSecondary(ctx),
                        )),
                  ],
                ),
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
        padding: EdgeInsets.fromLTRB(
            Ct.s5,
            Ct.s3,
            Ct.s5,
            Ct.s6 + MediaQuery.of(ctx).padding.bottom),
        decoration: BoxDecoration(
          color: Ct.card(ctx),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(Ct.rXl)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Ct.border(ctx),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: Ct.s4),
          Text(_s(ctx, 'chatlist_mute_title'),
              style: ThixPolicy.titleStyle.copyWith(
                  fontWeight: ThixPolicy.bold,
                  fontSize: 16,
                  color: Ct.textMain(ctx),
              )),
          const SizedBox(height: Ct.s4),
          _muteOption(ctx, _s(ctx, 'chatlist_mute_8h'),
              const Duration(hours: 8), convId),
          _muteOption(ctx, _s(ctx, 'chatlist_mute_1w'),
              const Duration(days: 7), convId),
          _muteOption(
              ctx, _s(ctx, 'chatlist_mute_forever'), null, convId),
        ]),
      ),
    );
  }

  Widget _muteOption(
      BuildContext ctx, String label, Duration? duration, String convId) {
    return ListTile(
      title: Text(label,
          style: ThixPolicy.titleStyle.copyWith(color: Ct.textMain(ctx))),
      leading: const Icon(Icons.timer_outlined, color: Ct.accentDp),
      onTap: () async {
        Navigator.pop(ctx);
        await _guard(() => ref
            .read(chatListProvider.notifier)
            .toggleMute(convId, duration: duration));
        _showSuccess(_s(context, 'chatlist_muted_success'));
      },
    );
  }

  Future<void> _confirmAndDeleteSingle(ChatConversation conv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Ct.card(ctx),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Ct.rLg)),
        title: Text(_s(ctx, 'chatlist_delete_title'),
            style: ThixPolicy.titleStyle.copyWith(color: Ct.textMain(ctx))),
        content: Text(_s(ctx, 'chatlist_delete_message'),
            style:
                ThixPolicy.bodyStyle.copyWith(color: Ct.textSecondary(ctx))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_s(ctx, 'common_cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Ct.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_s(ctx, 'common_delete'),
                style: const TextStyle(color: Colors.white)),
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
      child: CtGlass(
        radius: 22,
        alpha: 0.96,
        padding: const EdgeInsets.symmetric(horizontal: Ct.s4, vertical: Ct.s2),
        child: Row(children: [
          Expanded(
            child: Text(
              _s(context, 'chatlist_selected_count',
                  args: ['${state.selectedIds.length}']),
              style: ThixPolicy.titleStyle.copyWith(
                  fontWeight: ThixPolicy.bold,
                  color: Ct.textMain(context),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.archive_outlined, color: Ct.ink),
            tooltip: _s(context, 'chatlist_archive'),
            onPressed: () async {
              await _guard(() => notifier.bulkArchive());
              _showSuccess(_s(context, 'chatlist_bulk_archived'));
            },
          ),
          IconButton(
            icon: const Icon(Icons.done_all_rounded, color: Ct.accentDp),
            tooltip: _s(context, 'chatlist_mark_read'),
            onPressed: () async {
              await _guard(() => notifier.bulkMarkAsRead());
              _showSuccess(_s(context, 'chatlist_bulk_marked_read'));
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Ct.danger),
            tooltip: _s(context, 'chatlist_delete'),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: Ct.card(ctx),
                  title: Text(_s(ctx, 'chatlist_delete_title')),
                  content: Text(_s(ctx, 'chatlist_bulk_delete_confirm',
                      args: ['${state.selectedIds.length}'])),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(_s(ctx, 'common_cancel')),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Ct.danger),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(_s(ctx, 'common_delete'),
                          style: const TextStyle(color: Colors.white)),
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
          IconButton(
            icon: Icon(Icons.close_rounded, color: Ct.textSecondary(context)),
            tooltip: _s(context, 'common_cancel'),
            onPressed: () => notifier.exitSelectionMode(),
          ),
        ]),
      ),
    );
  }

  // ==========================================================================
  // SNACKBARS
  // ==========================================================================
  void _snack(String message, Color bg,
      {IconData? icon, Duration? duration}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: Ct.s2),
          ],
          Expanded(child: Text(message)),
        ]),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Ct.rPill)),
        duration: duration ?? const Duration(milliseconds: 2200),
      ));
  }

  void _showSuccess(String m) =>
      _snack(m, Ct.success, icon: Icons.check_circle_rounded);

  void _showError(String m) {
    HapticFeedback.lightImpact();
    _snack(m, Ct.danger,
        icon: Icons.error_outline_rounded,
        duration: const Duration(seconds: 3));
  }

  void _showInfo(String m) =>
      _snack(m, Ct.ink, duration: const Duration(seconds: 1));

  void _showUndo(String message, VoidCallback onUndo) {
    if (!mounted) return;
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Ct.ink,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Ct.rPill)),
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: _s(context, 'chatlist_undo'),
        textColor: Ct.accentSoft,
        onPressed: onUndo,
      ),
    ));
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    setState(() {});
    _searchDebounce =
        Timer(const Duration(milliseconds: _kSearchDebounceMs), () {
      if (!mounted) return;
      ref.read(chatListProvider.notifier).search(
          ChatListValidators.sanitize(v, maxLength: 100, singleLine: true));
    });
  }

  // ==========================================================================
  // 🤝 SECTION DEMANDES DE CONNEXION (COMPACTE)
  // ==========================================================================
  Widget _buildConnectionRequests() {
    final requests = ref.watch(_connRequestsProvider);
    final loading = ref.watch(_connRequestsLoadingProvider);

    if (!loading && requests.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(Ct.s5, Ct.s2, Ct.s5, Ct.s3),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(Ct.s2 - 1),
            decoration: BoxDecoration(
              color: Ct.accent.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_add_alt_1_rounded,
                size: 14, color: Ct.accentDp),
          ),
          const SizedBox(width: Ct.s2),
          Text(
            _s(context, 'chatlist_connection_requests', fb: 'Demandes de connexion'),
            style: ThixPolicy.titleStyle.copyWith(
                fontWeight: ThixPolicy.bold,
                fontSize: 13.5,
                letterSpacing: 0.2,
                color: Ct.textMain(context),
            ),
          ),
          const SizedBox(width: Ct.s2),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: Ct.s2, vertical: 2),
            decoration: BoxDecoration(
              color: Ct.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(Ct.rPill),
            ),
            child: Text(
              '${requests.length}',
              style: ThixPolicy.microStyle.copyWith(
                  fontWeight: ThixPolicy.bold,
                  color: Ct.accentDp,
                  fontSize: 11,
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => context.pushNamed('connections'),
            child: Text(
              _s(context, 'chatlist_see_all', fb: 'Tout voir'),
              style: ThixPolicy.captionStyle.copyWith(
                  fontWeight: ThixPolicy.bold,
                  color: Ct.accentDp,
              ),
            ),
          ),
        ]),
      ),
      SizedBox(
        height: 120, // Réduit de 148 à 120
        child: loading
            ? const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Ct.accent),
                ),
              )
            : ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Ct.s5),
                itemCount: requests.length,
                separatorBuilder: (_, __) => const SizedBox(width: Ct.s3),
                itemBuilder: (c, i) =>
                    _ConnectionRequestCard(
                      request: requests[i],
                      onAccept: () => _respondToRequest(requests[i], true),
                      onDecline: () => _respondToRequest(requests[i], false),
                    ),
              ),
      ),
      const SizedBox(height: Ct.s2),
    ]);
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatListProvider);
    final counters = ref.watch(notificationCountersProvider);

    ref.listen<NotificationCounters>(notificationCountersProvider,
        (previous, next) {
      if (!mounted) return;
      final prev = previous?.newConnections ?? 0;
      final now = next.newConnections;
      if (now > prev && now > 0) {
        HapticFeedback.mediumImpact();
        unawaited(_loadConnectionRequests());
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.person_add_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: Ct.s3),
              Expanded(
                child: Text(
                  _s(context, 'chatlist_new_connections', args: ['$now']),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ]),
            backgroundColor: Ct.ink,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Ct.rPill)),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: _s(context, 'chatlist_network'),
              textColor: Ct.accentSoft,
              onPressed: () => _navigateTo(0),
            ),
          ));
      }
    });

    final currentUser = ref.watch(authControllerProvider).value;
    final currentUserName = ChatListValidators.sanitize(
        currentUser?.displayName ?? '',
        maxLength: _kMaxChatNameLength);
    final currentUserId = currentUser?.id ?? '';
    final currentUserPhoto =
        ChatListValidators.sanitizeUrl(currentUser?.photoUrl);

    final onlineUserIds = ref.watch(presenceProvider);
    final missedCalls = math.max(counters.missedCalls,
        _derivedMissedCalls(state.all, currentUserId));
    final newConnections = counters.newConnections;

    final seen = <String>{};
    final onlineContacts = <ChatConversation>[];
    for (final c in state.filtered) {
      if (c.isGroup || c.isLocked) continue;
      final oid = c.participantIds.firstWhere((id) => id != currentUserId,
          orElse: () => '');
      if (oid.isNotEmpty &&
          onlineUserIds.onlineUserIds.contains(oid) &&
          seen.add(oid)) {
        onlineContacts.add(c);
      }
    }

    final bellBadge = state.pendingEscalations > 0 ||
        state.totalUnread > 0 ||
        missedCalls > 0 ||
        newConnections > 0;

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
        backgroundColor: Ct.surface(context),
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
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Ct.ink.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Ct.accent.withValues(alpha: 0.05),
              ),
            ),
          ),
          state.isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: Ct.ink, strokeWidth: 3))
              : RefreshIndicator(
                  color: Ct.accentDp,
                  backgroundColor: Ct.card(context),
                  onRefresh: () async {
                    HapticFeedback.selectionClick();
                    _refreshAllCounters();
                  },
                  child: CustomScrollView(
                    controller: _scroll,
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                    slivers: [
                      // ── App bar verre ──
                      SliverAppBar(
                        pinned: true,
                        expandedHeight: kToolbarHeight + 20,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        scrolledUnderElevation: 0,
                        flexibleSpace: ClipRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Ct.surface(context)
                                    .withValues(alpha: 0.85),
                                border: Border(
                                  bottom: BorderSide(
                                    color: Ct.border(context),
                                    width: 1,
                                  ),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: Ct.s5),
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 12.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(children: [
                                      Container(
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          gradient:
                                              const LinearGradient(
                                            colors: [
                                              Ct.accent,
                                              Ct.accentDp
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(7),
                                        ),
                                        child: const Icon(
                                          Icons.chat_rounded,
                                          size: 13,
                                          color: Colors.white),
                                      ),
                                      const SizedBox(width: Ct.s2),
                                      Text.rich(
                                        TextSpan(children: [
                                          TextSpan(
                                            text: 'THIX ',
                                            style: TextStyle(
                                              fontSize: 21,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.6,
                                              color: Ct.textMain(context),
                                            ),
                                          ),
                                          TextSpan(
                                            text: 'Chat',
                                            style: TextStyle(
                                              fontSize: 21,
                                              fontWeight: FontWeight.w300,
                                              letterSpacing: 0.6,
                                              color:
                                                  Ct.textSecondary(context),
                                            ),
                                          ),
                                        ]),
                                      ),
                                    ]),
                                    Row(children: [
                                      _AppBarBtn(
                                        icon: Icons.swap_vert_rounded,
                                        semanticsLabel:
                                            _s(context, 'chatlist_escalations'),
                                        badge: state.pendingEscalations > 0,
                                        badgeColor: Ct.danger,
                                        onTap: () => context
                                            .pushNamed('chatEscalationReceived'),
                                      ),
                                      const SizedBox(width: Ct.s2),
                                      _AppBarBtn(
                                        icon: Icons.menu_book_outlined,
                                        semanticsLabel:
                                            _s(context, 'chatlist_notebook'),
                                        onTap: _openNotebook,
                                      ),
                                      const SizedBox(width: Ct.s2),
                                      _AppBarBtn(
                                        icon:
                                            Icons.notifications_none_rounded,
                                        semanticsLabel: _s(
                                            context, 'chatlist_notifications'),
                                        badge: bellBadge,
                                        badgeColor: Ct.danger,
                                        onTap: () => _openNotifications(
                                          state.pendingEscalations,
                                          missedCalls,
                                          newConnections,
                                        ),
                                      ),
                                    ]),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Status WhatsApp style
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                              Ct.s5, Ct.s3, Ct.s5, Ct.s3),
                          child: StatusStoryRow(
                            currentUserId: currentUserId,
                            currentUserAvatar: currentUserPhoto,
                            currentUserName: currentUserName,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(child: _buildSearchBarGlass()),
                      // Personnes en ligne (déplacé après recherche)
                      if (onlineContacts.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                                Ct.s5, Ct.s3, Ct.s5, Ct.s3),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'En ligne',
                                  style: ThixPolicy.titleStyle.copyWith(
                                    color: Ct.textSecondary(context),
                                    fontSize: 13,
                                    fontWeight: ThixPolicy.semiBold,
                                  ),
                                ),
                                const SizedBox(height: Ct.s3),
                                SizedBox(
                                  height: 76,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: onlineContacts.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: Ct.s3),
                                    itemBuilder: (c, i) {
                                      final conv = onlineContacts[i];
                                      final label =
                                          ChatListValidators.sanitize(
                                        conv.displayName.split(' ').first,
                                        maxLength: 20,
                                      );
                                      return _onlineAvatarNode(
                                        label: label.isEmpty ? '?' : label,
                                        avatarUrl: ChatListValidators
                                            .sanitizeUrl(conv.displayAvatar),
                                        onTap: () =>
                                            _openConversation(conv),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // ── 🤝 Demandes de connexion ──
                      SliverToBoxAdapter(child: _buildConnectionRequests()),
                      if (state.pendingEscalations > 0)
                        SliverToBoxAdapter(
                            child: _buildEscalationBanner(
                                state.pendingEscalations)),
                      SliverToBoxAdapter(
                          child:
                              _buildFilters(state.filterIndex, state.totalUnread)),
                      if (state.totalUnread > 0 &&
                          state.filterIndex == 0 &&
                          !_onlyEscalations)
                        SliverToBoxAdapter(
                            child: _buildUnreadStrip(state.totalUnread)),
                      const SliverToBoxAdapter(child: SizedBox(height: Ct.s2)),
                      SliverPadding(
                        padding: const EdgeInsets.only(top: 4),
                        sliver: _chatListSliver(state, currentUserId,
                            currentUserName, onlineUserIds.onlineUserIds),
                      ),
                      if (state.isLoadingMore)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 28),
                            child: Center(
                              child: CircularProgressIndicator(
                                  color: Ct.ink, strokeWidth: 3),
                            ),
                          ),
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

  Widget _buildSearchBarGlass() {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(Ct.s5, 0, Ct.s5, Ct.s4),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Ct.card(context),
          borderRadius: BorderRadius.circular(Ct.rPill),
          border: Border.all(color: Ct.border(context)),
        ),
        child: Semantics(
          label: _s(context, 'chatlist_search_label'),
          textField: true,
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            style: ThixPolicy.bodyStyle.copyWith(
              color: Ct.textMain(context),
              fontWeight: ThixPolicy.medium,
            ),
            decoration: InputDecoration(
              hintText: _s(context, 'chatlist_search_hint'),
              hintStyle: ThixPolicy.bodySmallStyle
                  .copyWith(color: Ct.textSecondary(context)),
              prefixIcon: Icon(Icons.search_rounded,
                  size: 20, color: Ct.textSecondary(context)),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded,
                          size: 18, color: Ct.textSecondary(context)),
                      tooltip: _s(context, 'common_clear'),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _searchDebounce?.cancel();
                        _searchCtrl.clear();
                        setState(() {});
                        ref
                            .read(chatListProvider.notifier)
                            .search('');
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
          margin: const EdgeInsets.fromLTRB(Ct.s5, 0, Ct.s5, Ct.s3),
          padding: const EdgeInsets.symmetric(
              horizontal: Ct.s4, vertical: Ct.s3),
          decoration: BoxDecoration(
            color: Ct.danger.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(Ct.rMd),
            border: Border.all(color: Ct.danger.withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            const _PulseDot(color: Ct.danger, size: 10),
            const SizedBox(width: Ct.s3),
            Expanded(
              child: Text(
                '$pending ${_s(context, 'chatlist_pending_escalations')}',
                style: ThixPolicy.bodyStyle.copyWith(
                    color: Ct.danger,
                    fontWeight: ThixPolicy.bold,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Ct.danger, size: 12),
          ]),
        ),
      ),
    );
  }

  Widget _buildUnreadStrip(int total) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(Ct.s5, Ct.s3, Ct.s5, 0),
      child: Row(children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
              color: Ct.ink, shape: BoxShape.circle),
        ),
        const SizedBox(width: Ct.s2),
        Expanded(
          child: Text(
            '$total ${_s(context, 'chatlist_unread_label')}',
            style: ThixPolicy.captionStyle.copyWith(
                fontWeight: ThixPolicy.bold,
                color: Ct.textMain(context),
            ),
          ),
        ),
        GestureDetector(
          onTap: _markAllAsRead,
          child: Text(
            _s(context, 'chatlist_mark_all_read'),
            style: ThixPolicy.captionStyle.copyWith(
                fontWeight: ThixPolicy.bold,
                color: Ct.accentDp,
                decoration: TextDecoration.underline,
                decorationColor: Ct.accentDp,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _chip(
      {required String label,
      required bool selected,
      required VoidCallback onTap,
      IconData? icon,
      Color? accent}) {
    final base = accent ?? Ct.ink;
    return Padding(
      padding: const EdgeInsets.only(right: Ct.s2),
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
              color: selected ? base : Ct.card(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? base : Ct.border(context),
                width: 1.2,
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 14,
                    color: selected ? Colors.white : base),
                const SizedBox(width: 5),
              ],
              Text(label,
                  style: ThixPolicy.bodySmallStyle.copyWith(
                      fontWeight: selected
                          ? ThixPolicy.bold
                          : ThixPolicy.semiBold,
                      color: selected
                          ? Colors.white
                          : Ct.textSecondary(context),
                  )),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(int selected, int totalUnread) {
    final labels = [
      _s(context, 'chatlist_filter_all'),
      totalUnread > 0
          ? '${_s(context, 'chatlist_filter_unread')} ($totalUnread)'
          : _s(context, 'chatlist_filter_unread'),
      _s(context, 'chatlist_filter_teams'),
      _s(context, 'chatlist_filter_personal'),
      _s(context, 'chatlist_filter_pinned'),
      _s(context, 'chatlist_filter_archived'),
    ];

    return SizedBox(
      height: 34,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: Ct.s5),
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < _filterCount; i++)
            _chip(
              label: labels[i],
              selected: selected == i && !_onlyEscalations,
              onTap: () {
                if (_onlyEscalations) {
                  setState(() => _onlyEscalations = false);
                }
                ref.read(chatListProvider.notifier).setFilter(i);
              },
            ),
          _chip(
            label: _s(context, 'chatlist_filter_escalations',
                fb: 'Escalades'),
            icon: Icons.swap_vert_rounded,
            accent: Ct.danger,
            selected: _onlyEscalations,
            onTap: () =>
                setState(() => _onlyEscalations = !_onlyEscalations),
          ),
        ],
      ),
    );
  }

  Widget _chatListSliver(dynamic state, String currentUserId,
      String currentUserName, Set<String> onlineUserIds) {
    List<ChatConversation> list = state.filtered;
    if (_onlyEscalations) {
      list = list.where((c) => c.isEscalation).toList();
    }

    if (list.isEmpty) {
      final searching = _searchCtrl.text.trim().isNotEmpty;
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 80),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Ct.surface(context),
                shape: BoxShape.circle,
                border: Border.all(color: Ct.border(context)),
              ),
              child: Icon(
                searching
                    ? Icons.search_off_rounded
                    : Icons.chat_bubble_outline_rounded,
                size: 40,
                color: Ct.textSecondary(context),
              ),
            ),
            const SizedBox(height: Ct.s4),
            Text(
              searching
                  ? _s(context, 'chatlist_no_results')
                  : (_onlyEscalations
                      ? _s(context, 'chatlist_no_escalation',
                          fb: 'Aucune escalade')
                      : (state.filterIndex == ChatFilter.archived
                          ? _s(context, 'chatlist_no_archived')
                          : _s(context, 'chatlist_no_conversation'))),
              style: ThixPolicy.titleStyle
                  .copyWith(color: Ct.textSecondary(context)),
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

          final otherUserId = conv.participantIds.firstWhere(
            (id) => id != currentUserId,
            orElse: () => '',
          );
          final isOnline = onlineUserIds.contains(otherUserId);

          String chatName = ChatListValidators.sanitize(
              conv.displayName, maxLength: _kMaxChatNameLength);
          final chatAvatar =
              ChatListValidators.sanitizeUrl(conv.displayAvatar);

          if (conv.isGroup) {
            if (chatName.isEmpty) {
              chatName = _s(context, 'chatlist_group_thix');
            }
          } else if (chatName.trim() == currentUserName.trim() ||
              chatName.isEmpty) {
            final shortId = otherUserId.length > 4
                ? otherUserId.substring(0, 4)
                : otherUserId;
            chatName =
                '${_s(context, 'chatlist_contact_thix')} (ID: $shortId)';
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
                  ref
                      .read(chatListProvider.notifier)
                      .toggleSelection(conv.id);
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
            direction: selectionMode
                ? DismissDirection.none
                : DismissDirection.horizontal,
            confirmDismiss: (dir) async {
              HapticFeedback.selectionClick();
              final notifier = ref.read(chatListProvider.notifier);
              if (dir == DismissDirection.endToStart) {
                final wasArchived = conv.isArchived;
                await _guard(() => notifier.toggleArchive(conv.id));
                _showUndo(
                  wasArchived
                      ? _s(context, 'chatlist_unarchived')
                      : _s(context, 'chatlist_archived'),
                  () => _guard(() => notifier.toggleArchive(conv.id)),
                );
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
              padding: const EdgeInsets.only(left: Ct.s5),
              color: Ct.ink.withValues(alpha: 0.08),
              child: const Icon(Icons.done_all_rounded, color: Ct.ink),
            ),
            secondaryBackground: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: Ct.s5),
              color: Ct.warning.withValues(alpha: 0.12),
              child: const Icon(Icons.archive_outlined, color: Ct.warning),
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
    final day =
        DateTime(localDate.year, localDate.month, localDate.day);
    final today = DateTime(now.year, now.month, now.day);

    if (day == today) return DateFormat('HH:mm').format(localDate);
    if (day == today.subtract(const Duration(days: 1))) {
      return _s(context, 'chatlist_yesterday');
    }
    if (now.difference(localDate).inDays < 7) {
      try {
        return DateFormat('EEEE',
                Localizations.localeOf(context).languageCode)
            .format(localDate);
      } catch (_) {
        return DateFormat('EEEE', 'fr_FR').format(localDate);
      }
    }
    return DateFormat('dd/MM/yy').format(localDate);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// BOUTON D'APP BAR
// ════════════════════════════════════════════════════════════════════════════
class _AppBarBtn extends StatelessWidget {
  final IconData icon;
  final String semanticsLabel;
  final VoidCallback onTap;
  final bool badge;
  final Color badgeColor;

  const _AppBarBtn({
    required this.icon,
    required this.semanticsLabel,
    required this.onTap,
    this.badge = false,
    this.badgeColor = Ct.danger,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Ct.isDark(context);
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          width: Ct.hitMin,
          height: Ct.hitMin,
          decoration: BoxDecoration(
            color: dark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.09)
                  : Ct.mist,
              width: 1,
            ),
            boxShadow: Ct.shadow(Ct.ink, a: 0.04, blur: 6, y: 2),
          ),
          child: Stack(alignment: Alignment.center, children: [
            Icon(icon, size: 19, color: Ct.textMain(context)),
            if (badge)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: dark ? Ct.inkSoft : Colors.white,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CARTE DEMANDE DE CONNEXION (COMPACTE - 180px)
// ════════════════════════════════════════════════════════════════════════════
class _ConnectionRequestCard extends StatelessWidget {
  final ConnectionRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _ConnectionRequestCard({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final sender = request.sender;
    final name = ChatListValidators.sanitize(
        sender?.displayName ?? '',
        maxLength: 18);
    final avatar = ChatListValidators.sanitizeUrl(sender?.avatarUrl);

    return Container(
      width: 180, // Réduit de 228 à 180
      padding: const EdgeInsets.all(Ct.s3),
      decoration: BoxDecoration(
        color: Ct.card(context),
        borderRadius: BorderRadius.circular(Ct.rLg),
        border: Border.all(color: Ct.border(context)),
        boxShadow: Ct.shadow(Ct.ink, a: 0.05, blur: 10, y: 3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + Nom
          Row(children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Ct.accent.withValues(alpha: 0.35), width: 1.5),
              ),
              child: CircleAvatar(
                radius: 18, // Plus petit
                backgroundColor: Ct.surface(context),
                backgroundImage: avatar != null
                    ? CachedNetworkImageProvider(avatar)
                    : null,
                child: avatar == null
                    ? Text(
                        ChatListValidators.safeInitial(name),
                        style: ThixPolicy.titleStyle.copyWith(
                          color: Ct.accentDp,
                          fontSize: 14,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: Ct.s2),
            Expanded(
              child: Text(
                name.isEmpty ? '—' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ThixPolicy.titleStyle.copyWith(
                  fontSize: 12,
                  fontWeight: ThixPolicy.bold,
                  color: Ct.textMain(context),
                ),
              ),
            ),
          ]),
          const Spacer(),
          // Boutons côte à côte
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: onDecline,
                child: Container(
                  height: 28, // Plus petit
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Ct.surface(context),
                    borderRadius: BorderRadius.circular(Ct.rPill),
                    border: Border.all(color: Ct.border(context)),
                  ),
                  child: Text(
                    'Refuser',
                    style: ThixPolicy.bodySmallStyle.copyWith(
                      fontWeight: ThixPolicy.bold,
                      color: Ct.textSecondary(context),
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: GestureDetector(
                onTap: onAccept,
                child: Container(
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Ct.accent, Ct.accentDp],
                    ),
                    borderRadius: BorderRadius.circular(Ct.rPill),
                    boxShadow: Ct.shadow(Ct.accentDp, a: 0.3, blur: 8, y: 2),
                  ),
                  child: Text(
                    'Accepter',
                    style: ThixPolicy.bodySmallStyle.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// POINT PULSANT
// ════════════════════════════════════════════════════════════════════════════
class _PulseDot extends StatefulWidget {
  final Color color;
  final double size;

  const _PulseDot({required this.color, required this.size});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final scale = 1 + 0.25 * math.sin(_c.value * 2 * math.pi);
        return Container(
          width: widget.size * scale,
          height: widget.size * scale,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.4),
                blurRadius: 6,
              ),
            ],
          ),
        );
      },
      child: const SizedBox.shrink(),
    );
  }
}
