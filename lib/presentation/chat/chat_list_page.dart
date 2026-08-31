// lib/presentation/chat/chat_list_page.dart
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';
import 'package:thix_id/features/network/presentation/providers/user_profile_providers.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/certification_tier.dart';
import 'package:thix_id/models/chat/chat_conversation.dart';
import 'package:thix_id/models/chat/chat_message.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/presentation/certification/widgets/certification_name_badge.dart';
import 'package:thix_id/presentation/chat/call/call_history_page.dart';
import 'package:thix_id/presentation/chat/providers/chat_list_provider.dart';
import 'package:thix_id/presentation/chat/providers/chat_notification_counters_provider.dart';
import 'package:thix_id/presentation/chat/providers/presence_provider.dart';
import 'package:thix_id/presentation/chat/providers/status_provider.dart';
import 'package:thix_id/presentation/chat/screens/group_create_page.dart';
import 'package:thix_id/presentation/chat/settings/chat_settings_page.dart';
import 'package:thix_id/presentation/chat/widgets/status_story_row.dart';

import 'chat_screen.dart';
import 'new_conversation_page.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const int _kMaxRetries = 1;
const int _kLoadMoreThresholdPx = 300;
const int _kLoadMoreThrottleMs = 500;
const int _kMaxChatNameLength = 80;
const int _kMaxPreviewLength = 140;
const int _kMaxAgentNameLength = 60;

// ============================================================================
// VALIDATORS
// ============================================================================
class _ListValidators {
  _ListValidators._();

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
    return 'Une erreur est survenue. Réessayez.';
  }

  static String safeInitial(String? name) {
    final s = sanitize(name, maxLength: 10);
    if (s.isEmpty) return '?';
    return s[0].toUpperCase();
  }

  /// Détecte si un message est chiffré (préfixe ENCv1 ou base64 long)
  static bool isEncrypted(String? raw) {
    if (raw == null || raw.isEmpty) return false;
    final t = raw.trim();
    if (t.startsWith('ENCv1:') || t.startsWith('🔒')) return true;
    if (t.length > 20 &&
        !t.contains(' ') &&
        RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(t.replaceFirst(RegExp(r'^ENCv1:'), ''))) {
      return true;
    }
    return false;
  }

  static bool isImageFile(String? name) {
    if (name == null) return false;
    final l = name.toLowerCase();
    return l.endsWith('.jpg') || l.endsWith('.jpeg') || l.endsWith('.png') ||
        l.endsWith('.gif') || l.endsWith('.webp');
  }

  static bool isVideoFile(String? name) {
    if (name == null) return false;
    final l = name.toLowerCase();
    return l.endsWith('.mp4') || l.endsWith('.mov') || l.endsWith('.avi');
  }

  static bool isAudioFile(String? name) {
    if (name == null) return false;
    final l = name.toLowerCase();
    return l.endsWith('.mp3') || l.endsWith('.wav') || l.endsWith('.m4a') ||
        name.contains('Message audio (');
  }
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _listRetry<T>(
  Future<T> Function() fn, {
  required String label,
  int maxRetries = _kMaxRetries,
  Duration timeout = _kRequestTimeout,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(timeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[ChatList] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[ChatList] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[ChatList] ❌ $label error: $e');
      rethrow;
    }
  }
}

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
  int _selectedNav = 1;
  DateTime? _lastLoadMore;

  static const List<String> _filterKeys = ['all', 'unread', 'teams', 'personal'];

  @override
  void initState() {
    super.initState();
    debugPrint('[ChatList] 🚀 Page opened');
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    debugPrint('[ChatList] 👋 Page disposed');
    WidgetsBinding.instance.removeObserver(this);
    _scroll.removeListener(_onScroll);
    _searchCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - _kLoadMoreThresholdPx) {
      final now = DateTime.now();
      if (_lastLoadMore != null && now.difference(_lastLoadMore!).inMilliseconds < _kLoadMoreThrottleMs) {
        return;
      }
      _lastLoadMore = now;
      ref.read(chatListProvider.notifier).loadMore();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[ChatList] 🔄 App resumed — refreshing counters');
      _refreshAllCounters();
    }
  }

  /// Rafraîchit TOUS les compteurs en parallèle
  void _refreshAllCounters() {
    unawaited(ref.read(notificationCountersProvider.notifier).refresh().catchError(
          (e) => debugPrint('[ChatList] ⚠️ Counters refresh error: $e'),
        ));
    unawaited(ref.read(chatListProvider.notifier).refresh(silent: true).catchError(
          (e) => debugPrint('[ChatList] ⚠️ List refresh error: $e'),
        ));
    unawaited(ref.read(statusProvider.notifier).refresh().catchError(
          (_) {},
        ));
  }

  /// Ouvre une conversation et refresh les compteurs au retour
  Future<void> _openConversation(ChatConversation conv) async {
    HapticFeedback.mediumImpact();
    debugPrint('[ChatList] 💬 Opening conversation: ${conv.id}');

    // Marquer comme lu AVANT d'ouvrir (compteur retombe immédiatement)
    await ref.read(chatListProvider.notifier).markAsRead(conv.id);

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conv.id,
          conversation: conv,
        ),
      ),
    );

    // Au retour : refresh silencieux des compteurs et de la liste
    if (mounted) {
      debugPrint('[ChatList] 🔄 Returned from conversation — refreshing counters');
      _refreshAllCounters();
    }
  }

  /// Navigation vers les sections avec gestion des compteurs
  void _navigateTo(int idx) {
    HapticFeedback.lightImpact();
    final countersNotifier = ref.read(notificationCountersProvider.notifier);

    switch (idx) {
      case 0:
        countersNotifier.clearNewConnections();
        debugPrint('[ChatList] 🌐 Navigate to connections (cleared newConnections)');
        context.pushNamed('connections').then((_) {
          if (mounted) _refreshAllCounters();
        });
        break;
      case 1:
        setState(() => _selectedNav = idx);
        break;
      case 2:
        countersNotifier.clearMissedCalls();
        debugPrint('[ChatList] 📞 Navigate to call history (cleared missedCalls)');
        Navigator.push(context, MaterialPageRoute(builder: (_) => const CallHistoryPage())).then((_) {
          if (mounted) _refreshAllCounters();
        });
        break;
      case 3:
        debugPrint('[ChatList] ⚙️ Navigate to settings');
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatSettingsPage())).then((_) {
          if (mounted) _refreshAllCounters();
        });
        break;
    }
  }

  /// Gestion du retour Android
  Future<bool> _onWillPop() async {
    if (_selectedNav != 1) {
      setState(() => _selectedNav = 1);
      return false;
    }
    context.go('/');
    return false;
  }

  void _openNotifications(int pending) {
    HapticFeedback.selectionClick();
    final l10n = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.55),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(ThixPolicy.rXl)),
          border: Border(top: BorderSide(color: ThixPolicy.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: ThixPolicy.s12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(ThixPolicy.s24, ThixPolicy.s20, ThixPolicy.s24, ThixPolicy.s16),
              child: Row(
                children: [
                  const Icon(Icons.notifications_rounded, color: ThixPolicy.textMain, size: 22),
                  const SizedBox(width: ThixPolicy.s12),
                  Text(
                    l10n.t('chatlist_notifications'),
                    style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, letterSpacing: -0.3),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: ThixPolicy.border),
            Flexible(
              child: pending > 0
                  ? Semantics(
                      button: true,
                      label: l10n.t('chatlist_pending_escalations'),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s24, vertical: ThixPolicy.s12),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: ThixPolicy.danger.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                          ),
                          child: const Icon(Icons.swap_vert_rounded, color: ThixPolicy.danger, size: 24),
                        ),
                        title: Text(
                          l10n.t('chatlist_pending_escalations'),
                          style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 15),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(l10n.t('chatlist_requires_action'), style: ThixPolicy.bodySmallStyle),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded, color: ThixPolicy.textSecondary),
                        onTap: () {
                          Navigator.pop(ctx);
                          context.pushNamed('chatEscalationReceived');
                        },
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Text(
                          l10n.t('chatlist_no_recent'),
                          style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: ThixPolicy.s24),
          ],
        ),
      ),
    );
  }

  void _showCreateMenu() {
    HapticFeedback.mediumImpact();
    final l10n = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(
          ThixPolicy.s20,
          ThixPolicy.s12,
          ThixPolicy.s20,
          ThixPolicy.s32 + MediaQuery.of(ctx).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(ThixPolicy.rXl)),
          border: Border(top: BorderSide(color: ThixPolicy.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: ThixPolicy.s24),
            _sheetOpt(
              l10n,
              Icons.chat_bubble_outline_rounded,
              l10n.t('chatlist_new_discussion'),
              l10n.t('chatlist_start_private'),
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewConversationPage())),
            ),
            const SizedBox(height: ThixPolicy.s12),
            _sheetOpt(
              l10n,
              Icons.group_add_outlined,
              l10n.t('chatlist_create_group'),
              l10n.t('chatlist_collaborate_team'),
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupCreatePage())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetOpt(
    AppLocalizations l10n,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback tap,
  ) {
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
            decoration: BoxDecoration(
              color: ThixPolicy.surfaceSoft,
              border: Border.all(color: ThixPolicy.border),
              borderRadius: BorderRadius.circular(ThixPolicy.rLg),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: ThixPolicy.card,
                    borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                    border: Border.all(color: ThixPolicy.border),
                  ),
                  child: Icon(icon, size: 24, color: ThixPolicy.primaryDeep),
                ),
                const SizedBox(width: ThixPolicy.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: ThixPolicy.titleStyle.copyWith(
                          fontSize: 15,
                          fontWeight: ThixPolicy.bold,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: ThixPolicy.bodySmallStyle.copyWith(
                          fontSize: 12,
                          fontWeight: ThixPolicy.medium,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: ThixPolicy.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatPreview(String? raw, AppLocalizations l10n) {
    if (raw == null || raw.isEmpty) return l10n.t('chatlist_new_conversation');
    if (_ListValidators.isEncrypted(raw)) return '🔒 ${l10n.t('chatlist_protected_message')}';
    if (_ListValidators.isImageFile(raw)) return '📷 ${l10n.t('chatlist_photo')}';
    if (_ListValidators.isVideoFile(raw)) return '🎥 ${l10n.t('chatlist_video')}';
    if (_ListValidators.isAudioFile(raw)) return '🎤 ${l10n.t('chatlist_audio_message')}';
    return _ListValidators.sanitize(raw, maxLength: _kMaxPreviewLength);
  }

  Widget _buildReadReceipt(ChatMessage? msg, String currentUserId) {
    if (msg == null || msg.senderId != currentUserId) return const SizedBox.shrink();
    return ListMessageStatusLights(
      isDelivered: msg.isDelivered,
      isRead: msg.isRead,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(chatListProvider);
    final counters = ref.watch(notificationCountersProvider);
    final notifier = ref.read(chatListProvider.notifier);

    final currentUser = ref.watch(authControllerProvider).value;
    final currentUserName = _ListValidators.sanitize(currentUser?.displayName ?? '', maxLength: _kMaxChatNameLength);
    final currentUserId = currentUser?.id ?? '';
    final currentUserPhoto = _ListValidators.sanitizeUrl(currentUser?.photoUrl);

    final onlineUserIds = ref.watch(presenceProvider);

    final seenUserIds = <String>{};
    final onlineContacts = <ChatConversation>[];

    for (final c in state.filtered) {
      if (c.isGroup) continue;
      final otherUserId = c.participantIds.firstWhere((id) => id != currentUserId, orElse: () => '');
      if (otherUserId.isNotEmpty && onlineUserIds.contains(otherUserId)) {
        if (seenUserIds.add(otherUserId)) {
          onlineContacts.add(c);
        }
      }
    }

    return PopScope(
      canPop: _selectedNav == 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedNav != 1) {
          setState(() => _selectedNav = 1);
        } else if (!didPop) {
          context.go('/');
        }
      },
      child: Scaffold(
        backgroundColor: ThixPolicy.surfaceSoft,
        body: Stack(
          children: [
            // Orbs décoratifs (sans BackdropFilter)
            Positioned(
              top: -100,
              right: -50,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ThixPolicy.primary.withOpacity(0.08),
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
                  color: ThixPolicy.primaryDeep.withOpacity(0.05),
                ),
              ),
            ),

            state.isLoading
                ? const Center(child: CircularProgressIndicator(color: ThixPolicy.primary, strokeWidth: 3))
                : RefreshIndicator(
                    color: ThixPolicy.primary,
                    backgroundColor: ThixPolicy.card,
                    onRefresh: () async {
                      HapticFeedback.selectionClick();
                      debugPrint('[ChatList] 🔄 Manual refresh');
                      _refreshAllCounters();
                    },
                    child: RepaintBoundary(
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
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'THIX Chat',
                                      style: ThixPolicy.h1Style.copyWith(
                                        fontSize: 24,
                                        fontWeight: ThixPolicy.bold,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        _iconButtonGlass(
                                          l10n,
                                          icon: Icons.swap_vert_rounded,
                                          semanticsLabel: l10n.t('chatlist_escalations'),
                                          badge: state.pendingEscalations > 0,
                                          onTap: () {
                                            HapticFeedback.selectionClick();
                                            context.pushNamed('chatEscalationReceived');
                                          },
                                        ),
                                        const SizedBox(width: ThixPolicy.s12),
                                        _iconButtonGlass(
                                          l10n,
                                          icon: Icons.notifications_none_rounded,
                                          semanticsLabel: l10n.t('chatlist_notifications'),
                                          badge: state.pendingEscalations > 0,
                                          onTap: () => _openNotifications(state.pendingEscalations),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(ThixPolicy.s20, ThixPolicy.s8, ThixPolicy.s20, ThixPolicy.s12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  StatusStoryRow(
                                    currentUserId: currentUserId,
                                    currentUserAvatar: currentUserPhoto,
                                    currentUserName: currentUserName,
                                  ),
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
                                          final safeLabel = _ListValidators.sanitize(
                                            conv.displayName.split(' ').first,
                                            maxLength: 20,
                                          );
                                          final safeAvatar = _ListValidators.sanitizeUrl(conv.displayAvatar);
                                          return _onlineAvatarNode(
                                            l10n: l10n,
                                            label: safeLabel.isEmpty ? '?' : safeLabel,
                                            avatarUrl: safeAvatar,
                                            isOnline: true,
                                            onTap: () => _openConversation(conv),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),

                          SliverToBoxAdapter(child: _buildSearchBarGlass(l10n)),

                          if (state.pendingEscalations > 0)
                            SliverToBoxAdapter(child: _buildEscalationBanner(state.pendingEscalations, l10n)),

                          SliverToBoxAdapter(child: _buildFilters(state.filterIndex, l10n)),

                          const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s16)),

                          SliverToBoxAdapter(
                            child: Container(
                              decoration: BoxDecoration(
                                color: ThixPolicy.card,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(ThixPolicy.rXl)),
                                border: Border(
                                  top: BorderSide(color: ThixPolicy.border),
                                  left: BorderSide(color: ThixPolicy.border.withOpacity(0.5)),
                                  right: BorderSide(color: ThixPolicy.border.withOpacity(0.5)),
                                ),
                                boxShadow: ThixPolicy.shadowSoft(opacity: 0.02),
                              ),
                              child: _chatList(state.filtered, currentUserId, currentUserName, onlineUserIds, l10n),
                            ),
                          ),

                          if (state.isLoadingMore)
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 28),
                                child: Center(child: CircularProgressIndicator(color: ThixPolicy.primary, strokeWidth: 3)),
                              ),
                            ),

                          const SliverToBoxAdapter(child: SizedBox(height: 140)),
                        ],
                      ),
                    ),
                  ),

            _buildGlassBottomNav(l10n, state.totalUnread, counters),
          ],
        ),
      ),
    );
  }

  Widget _iconButtonGlass({
    required AppLocalizations l10n,
    required IconData icon,
    required String semanticsLabel,
    required VoidCallback onTap,
    bool badge = false,
  }) {
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
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            shape: BoxShape.circle,
            border: Border.all(color: ThixPolicy.border),
            boxShadow: ThixPolicy.shadowSoft(opacity: 0.04),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 20, color: ThixPolicy.textMain),
              if (badge)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: ThixPolicy.danger,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _onlineAvatarNode({
    required AppLocalizations l10n,
    required String label,
    required String? avatarUrl,
    required bool isOnline,
    VoidCallback? onTap,
  }) {
    return Semantics(
      button: true,
      label: '$label${isOnline ? " (${l10n.t('chatlist_online')})" : ""}',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap?.call();
        },
        child: SizedBox(
          width: 52,
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: ThixPolicy.card, width: 2),
                      boxShadow: ThixPolicy.shadowSoft(opacity: 0.05),
                    ),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: ThixPolicy.surface,
                      backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                      child: avatarUrl == null
                          ? const Icon(Icons.person, color: ThixPolicy.primaryDeep, size: 20)
                          : null,
                    ),
                  ),
                  if (isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: ThixPolicy.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label.isEmpty ? '?' : label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ThixPolicy.captionStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBarGlass(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(ThixPolicy.s20, 0, ThixPolicy.s20, ThixPolicy.s16),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(ThixPolicy.inputRadius),
          border: Border.all(color: ThixPolicy.border),
        ),
        child: Semantics(
          label: l10n.t('chatlist_search_label'),
          textField: true,
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => ref.read(chatListProvider.notifier).search(v),
            textInputAction: TextInputAction.search,
            style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMain, fontWeight: ThixPolicy.medium),
            decoration: InputDecoration(
              hintText: l10n.t('chatlist_search_hint'),
              hintStyle: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: ThixPolicy.textSecondary),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? Semantics(
                      button: true,
                      label: l10n.t('common_clear'),
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: ThixPolicy.textSecondary),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _searchCtrl.clear();
                          ref.read(chatListProvider.notifier).search('');
                        },
                      ),
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

  Widget _buildEscalationBanner(int pending, AppLocalizations l10n) {
    return Semantics(
      button: true,
      label: l10n.t('chatlist_pending_escalations'),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          context.pushNamed('chatEscalationReceived');
        },
        child: Container(
          margin: const EdgeInsets.fromLTRB(ThixPolicy.s20, 0, ThixPolicy.s20, ThixPolicy.s16),
          padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s12),
          decoration: BoxDecoration(
            color: ThixPolicy.danger.withOpacity(0.08),
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
            border: Border.all(color: ThixPolicy.danger.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: ThixPolicy.danger, size: 18),
              const SizedBox(width: ThixPolicy.s12),
              Expanded(
                child: Text(
                  '$pending ${l10n.t('chatlist_pending_escalations')}',
                  style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.danger, fontWeight: ThixPolicy.bold),
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: ThixPolicy.danger, size: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(int selected, AppLocalizations l10n) {
    final filterLabels = [
      l10n.t('chatlist_filter_all'),
      l10n.t('chatlist_filter_unread'),
      l10n.t('chatlist_filter_teams'),
      l10n.t('chatlist_filter_personal'),
    ];

    return SizedBox(
      height: 34,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
        scrollDirection: Axis.horizontal,
        itemCount: _filterKeys.length,
        itemBuilder: (ctx, i) {
          final sel = selected == i;
          return Padding(
            padding: const EdgeInsets.only(right: ThixPolicy.s8),
            child: Semantics(
              button: true,
              selected: sel,
              label: filterLabels[i],
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(chatListProvider.notifier).setFilter(i);
                },
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: sel ? ThixPolicy.primary : ThixPolicy.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel ? ThixPolicy.primary : ThixPolicy.border,
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    filterLabels[i],
                    style: ThixPolicy.bodySmallStyle.copyWith(
                      fontWeight: sel ? ThixPolicy.bold : ThixPolicy.semiBold,
                      color: sel ? Colors.white : ThixPolicy.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _chatList(
    List<ChatConversation> list,
    String currentUserId,
    String currentUserName,
    Set<String> onlineUserIds,
    AppLocalizations l10n,
  ) {
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ThixPolicy.surfaceSoft,
                shape: BoxShape.circle,
                border: Border.all(color: ThixPolicy.border),
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded, size: 40, color: ThixPolicy.primaryDeep),
            ),
            const SizedBox(height: ThixPolicy.s16),
            Text(
              l10n.t('chatlist_no_conversation'),
              style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: list.length,
      itemBuilder: (ctx, idx) {
        final conv = list[idx];
        final last = conv.lastMessage;
        final t = last?.createdAt ?? conv.updatedAt;
        final unread = conv.unreadCount > 0;

        final otherUserId = conv.participantIds.firstWhere((id) => id != currentUserId, orElse: () => '');
        final isOnline = onlineUserIds.contains(otherUserId);

        String chatName = _ListValidators.sanitize(conv.displayName, maxLength: _kMaxChatNameLength);
        final chatAvatar = _ListValidators.sanitizeUrl(conv.displayAvatar);

        if (conv.isGroup) {
          if (chatName.isEmpty) chatName = l10n.t('chatlist_group_thix');
        } else {
          if (chatName.trim() == currentUserName.trim() || chatName.isEmpty) {
            final shortId = otherUserId.length > 4 ? otherUserId.substring(0, 4) : otherUserId;
            chatName = '${l10n.t('chatlist_contact_thix')} (ID: $shortId)';
          }
        }

        return Dismissible(
          key: ValueKey(conv.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            color: ThixPolicy.danger.withOpacity(0.9),
            child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
          ),
          confirmDismiss: (direction) async {
            HapticFeedback.lightImpact();
            return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: ThixPolicy.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                  side: BorderSide(color: ThixPolicy.border),
                ),
                title: Text(l10n.t('chatlist_delete_title'), style: ThixPolicy.titleStyle),
                content: Text(l10n.t('chatlist_delete_message'), style: ThixPolicy.bodyStyle),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(l10n.t('common_cancel'), style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger, elevation: 0),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(l10n.t('common_delete'), style: ThixPolicy.labelStyle.copyWith(color: Colors.white)),
                  ),
                ],
              ),
            );
          },
          onDismissed: (direction) async {
            debugPrint('[ChatList] 🗑️ Deleting conversation: ${conv.id}');
            try {
              await _listRetry(
                () => Supabase.instance.client
                    .from('conversation_participants')
                    .delete()
                    .eq('conversation_id', conv.id)
                    .eq('user_id', currentUserId),
                label: 'deleteConversation',
              );
              ref.read(chatListProvider.notifier).refresh(silent: true);
              _refreshAllCounters();
              if (mounted) _showSuccess(l10n.t('chatlist_deleted'));
              debugPrint('[ChatList] ✓ Conversation deleted');
            } catch (e) {
              debugPrint('[ChatList] ❌ Delete error: $e');
              if (mounted) _showError(_ListValidators.friendlyError(e));
            }
          },
          child: _ConversationTile(
            conv: conv,
            chatName: chatName,
            chatAvatar: chatAvatar,
            isOnline: isOnline,
            unread: unread,
            currentUserId: currentUserId,
            otherUserId: otherUserId,
            lastMessage: last,
            timeText: _fmt(t, l10n),
            previewText: _formatPreview(last?.content, l10n),
            l10n: l10n,
            onTap: () => _openConversation(conv),
          ),
        );
      },
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildGlassBottomNav(AppLocalizations l10n, int unread, NotificationCounters counters) {
    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          height: 64,
          width: MediaQuery.of(context).size.width * 0.90,
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: ThixPolicy.border),
            boxShadow: ThixPolicy.shadowSoft(opacity: 0.08),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _navItem(
                l10n,
                Icons.people_alt_outlined,
                Icons.people_alt,
                l10n.t('chatlist_network'),
                0,
                counters.newConnections,
              ),
              _navItem(
                l10n,
                Icons.chat_bubble_outline_rounded,
                Icons.chat_bubble_rounded,
                l10n.t('chatlist_discussions'),
                1,
                unread,
              ),
              Semantics(
                button: true,
                label: l10n.t('chatlist_create_new'),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _showCreateMenu();
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: ThixPolicy.brandGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: ThixPolicy.primary.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
                  ),
                ),
              ),
              _navItem(
                l10n,
                Icons.call_outlined,
                Icons.call,
                l10n.t('chatlist_calls'),
                2,
                counters.missedCalls,
              ),
              _navItem(
                l10n,
                Icons.settings_outlined,
                Icons.settings,
                l10n.t('chatlist_settings'),
                3,
                0,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    AppLocalizations l10n,
    IconData iconOutlined,
    IconData iconFilled,
    String label,
    int idx,
    int badge,
  ) {
    final isSelected = _selectedNav == idx;
    return Semantics(
      button: true,
      label: label,
      selected: isSelected,
      child: InkWell(
        onTap: () => _navigateTo(idx),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                isSelected ? iconFilled : iconOutlined,
                color: isSelected ? ThixPolicy.primary : ThixPolicy.textSecondary.withOpacity(0.8),
                size: 24,
              ),
              if (badge > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: ThixPolicy.danger,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime d, AppLocalizations l10n) {
    final localDate = d.toLocal();
    final now = DateTime.now();
    final day = DateTime(localDate.year, localDate.month, localDate.day);
    final today = DateTime(now.year, now.month, now.day);

    if (day == today) return DateFormat('HH:mm').format(localDate);
    if (day == today.subtract(const Duration(days: 1))) return l10n.t('chatlist_yesterday');
    if (now.difference(localDate).inDays < 7) {
      try {
        return DateFormat('EEEE', l10n.localeName).format(localDate);
      } catch (_) {
        return DateFormat('EEEE', 'fr_FR').format(localDate);
      }
    }
    return DateFormat('dd/MM/yy').format(localDate);
  }
}

// ============================================================================
// CONVERSATION TILE (composant extrait)
// ============================================================================
class _ConversationTile extends StatelessWidget {
  final ChatConversation conv;
  final String chatName;
  final String? chatAvatar;
  final bool isOnline;
  final bool unread;
  final String currentUserId;
  final String otherUserId;
  final ChatMessage? lastMessage;
  final String timeText;
  final String previewText;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conv,
    required this.chatName,
    required this.chatAvatar,
    required this.isOnline,
    required this.unread,
    required this.currentUserId,
    required this.otherUserId,
    required this.lastMessage,
    required this.timeText,
    required this.previewText,
    required this.l10n,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$chatName. ${unread ? "${conv.unreadCount} non lu. " : ""}$previewText',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20, vertical: 12),
            child: Row(
              children: [
                if (conv.isEscalation)
                  _EscalationAvatars(
                    clientName: _ListValidators.sanitize(conv.clientName ?? chatName, maxLength: 40),
                    clientAvatar: _ListValidators.sanitizeUrl(conv.clientAvatar ?? chatAvatar),
                    agentName: _ListValidators.sanitize(conv.agentName ?? l10n.t('chatlist_agent'), maxLength: 40),
                    agentAvatar: _ListValidators.sanitizeUrl(conv.agentAvatar),
                  )
                else
                  Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: ThixPolicy.card, width: 1.5),
                          boxShadow: ThixPolicy.shadowSoft(opacity: 0.03),
                        ),
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: ThixPolicy.surface,
                          backgroundImage: chatAvatar != null ? CachedNetworkImageProvider(chatAvatar) : null,
                          child: chatAvatar == null
                              ? Text(
                                  _ListValidators.safeInitial(chatName),
                                  style: ThixPolicy.h3Style.copyWith(color: ThixPolicy.textSecondary),
                                )
                              : null,
                        ),
                      ),
                      if (!conv.isGroup && isOnline)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: ThixPolicy.success,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(width: ThixPolicy.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Consumer(
                              builder: (context, ref, _) {
                                CertificationTier? tier;
                                CertificationStatus? status;
                                bool isCertified = false;
                                bool isLegacyVerified = false;

                                if (!conv.isGroup && !conv.isEscalation && otherUserId.isNotEmpty) {
                                  final profileData = ref.watch(userProfileProvider(otherUserId)).valueOrNull;
                                  if (profileData != null) {
                                    tier = CertificationTierX.parse(profileData['certification_tier']);
                                    status = CertificationStatusX.parse(profileData['certification_status']);
                                    isCertified = status == CertificationStatus.approved || status == CertificationStatus.generated;
                                    isLegacyVerified = profileData['is_verified'] == true;
                                  }
                                }

                                return Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        chatName.isEmpty ? l10n.t('chatlist_unknown') : chatName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: ThixPolicy.titleStyle.copyWith(
                                          fontSize: 15,
                                          fontWeight: unread ? ThixPolicy.bold : ThixPolicy.semiBold,
                                          color: ThixPolicy.textMain,
                                        ),
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
                                        child: Icon(Icons.verified_rounded, color: ThixPolicy.gold, size: 15),
                                      ),
                                    if (conv.isEscalation) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: ThixPolicy.danger.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: ThixPolicy.danger.withOpacity(0.4)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.swap_vert_rounded, size: 11, color: ThixPolicy.danger),
                                            const SizedBox(width: 3),
                                            Text(
                                              l10n.t('chatlist_escalated'),
                                              style: ThixPolicy.microStyle.copyWith(
                                                fontWeight: ThixPolicy.bold,
                                                color: ThixPolicy.danger,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ] else if (conv.isGroup) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.groups_rounded, size: 14, color: ThixPolicy.textSecondary),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeText,
                            style: ThixPolicy.captionStyle.copyWith(
                              fontWeight: unread ? ThixPolicy.bold : ThixPolicy.medium,
                              color: unread ? ThixPolicy.primary : ThixPolicy.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      if (conv.isEscalation && (conv.escalatedByName?.isNotEmpty ?? false)) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${l10n.t('chatlist_agent_label')}: ${_ListValidators.sanitize(conv.agentName ?? '', maxLength: 60)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ThixPolicy.captionStyle,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          ListMessageStatusLights.fromMessage(lastMessage, currentUserId),
                          Expanded(
                            child: Text(
                              previewText.isEmpty ? '—' : previewText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ThixPolicy.bodySmallStyle.copyWith(
                                fontWeight: unread ? ThixPolicy.semiBold : ThixPolicy.regular,
                                color: unread ? ThixPolicy.textMain : ThixPolicy.textSecondary,
                              ),
                            ),
                          ),
                          if (unread)
                            Container(
                              margin: const EdgeInsets.only(left: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: ThixPolicy.primary,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: ThixPolicy.primary.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${conv.unreadCount}',
                                style: ThixPolicy.microStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold),
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
        ),
      ),
    );
  }
}

// ============================================================================
// MESSAGE STATUS LIGHTS
// ============================================================================
class ListMessageStatusLights extends StatelessWidget {
  final bool isDelivered;
  final bool isRead;

  const ListMessageStatusLights({
    super.key,
    this.isDelivered = false,
    this.isRead = false,
  });

  /// Factory qui vérifie si le message est de l'utilisateur courant
  factory ListMessageStatusLights.fromMessage(ChatMessage? msg, String currentUserId) {
    if (msg == null || msg.senderId != currentUserId) {
      return const ListMessageStatusLights(isDelivered: false, isRead: false);
    }
    return ListMessageStatusLights(isDelivered: msg.isDelivered, isRead: msg.isRead);
  }

  @override
  Widget build(BuildContext context) {
    if (!isDelivered && !isRead) return const SizedBox.shrink();

    final activeColor = isRead ? ThixPolicy.danger : (isDelivered ? ThixPolicy.warning : ThixPolicy.success);

    return Container(
      width: 9,
      height: 18,
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: ThixPolicy.inkDeep.withOpacity(0.8),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _dot(ThixPolicy.danger, activeColor == ThixPolicy.danger),
          _dot(ThixPolicy.warning, activeColor == ThixPolicy.warning),
          _dot(ThixPolicy.success, activeColor == ThixPolicy.success),
        ],
      ),
    );
  }

  Widget _dot(Color base, bool active) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? base : base.withOpacity(0.22),
      ),
    );
  }
}

// ============================================================================
// ESCALATION AVATARS
// ============================================================================
class _EscalationAvatars extends StatelessWidget {
  final String clientName;
  final String? clientAvatar;
  final String agentName;
  final String? agentAvatar;

  const _EscalationAvatars({
    required this.clientName,
    this.clientAvatar,
    required this.agentName,
    this.agentAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: 0, top: 2, child: _miniAvatar(clientAvatar, clientName, ThixPolicy.primary)),
          Positioned(left: 20, top: 2, child: _miniAvatar(agentAvatar, agentName, ThixPolicy.danger)),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: ThixPolicy.danger,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const Icon(Icons.swap_vert_rounded, size: 10, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniAvatar(String? url, String name, Color fallback) {
    final safeName = _ListValidators.sanitize(name, maxLength: 30);
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.9), width: 2),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.05),
      ),
      child: CircleAvatar(
        radius: 15,
        backgroundColor: fallback.withOpacity(0.15),
        backgroundImage: url != null ? CachedNetworkImageProvider(url) : null,
        child: url == null
            ? Text(
                _ListValidators.safeInitial(safeName),
                style: ThixPolicy.labelStyle.copyWith(color: fallback),
              )
            : null,
      ),
    );
  }
}
