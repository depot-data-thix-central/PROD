// lib/presentation/chat/chat_list_page.dart
import 'dart:async';
import 'dart:ui';
import 'package:thix_id/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../../models/chat/chat_message.dart';
import '../../models/chat/chat_conversation.dart';
import 'providers/chat_list_provider.dart';
import 'providers/presence_provider.dart';
import 'providers/notification_counters_provider.dart'; // ✅ NOUVEAU
import 'chat_screen.dart';
import 'new_conversation_page.dart';
import 'package:thix_id/presentation/chat/screens/group_create_page.dart';
import 'settings/chat_settings_page.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';
import 'package:thix_id/presentation/chat/call/call_history_page.dart';
import 'package:thix_id/presentation/chat/widgets/status_story_row.dart';
import 'package:thix_id/presentation/chat/providers/status_provider.dart';

// ✅ Imports pour la certification
import 'package:thix_id/models/certification_tier.dart';
import 'package:thix_id/presentation/certification/widgets/certification_name_badge.dart';
import 'package:thix_id/features/network/presentation/providers/user_profile_providers.dart';

class ChatListPage extends ConsumerStatefulWidget {
  const ChatListPage({super.key});

  @override
  ConsumerState<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends ConsumerState<ChatListPage> with WidgetsBindingObserver {
  final _searchCtrl = TextEditingController();
  final _scroll = ScrollController();

  int _selectedNav = 1;

  List<String> _getFilters(BuildContext context) => ['Toutes', 'Non lues', 'Équipes', 'Personnelles'];
  String _getTranslated(String key) => key;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        ref.read(chatListProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ✅ NOUVEAU : Rafraîchir les compteurs au retour dans l'app
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(notificationCountersProvider.notifier).refresh();
    }
  }

  Future<void> _openConversation(ChatConversation conv) async {
    ref.read(chatListProvider.notifier).markAsRead(conv.id);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conv.id,
          conversation: conv,
        ),
      ),
    );

    ref.read(chatListProvider.notifier).refresh(silent: true);
  }

  // ✅ NOUVEAU : Navigation avec nettoyage des compteurs
  void _navigateTo(int idx) {
    HapticFeedback.lightImpact();
    
    if (idx == 0) {
      ref.read(notificationCountersProvider.notifier).clearNewConnections();
      context.pushNamed('connections');
    } else if (idx == 1) {
      setState(() => _selectedNav = idx);
    } else if (idx == 2) {
      ref.read(notificationCountersProvider.notifier).clearMissedCalls();
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CallHistoryPage()));
    } else if (idx == 3) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatSettingsPage()));
    }
  }

  // ✅ NOUVEAU : Gestion du retour Android
  Future<bool> _onWillPop() async {
    if (_selectedNav != 1) {
      setState(() => _selectedNav = 1);
      return false;
    }
    // Retourne à la homepage au lieu de quitter
    context.go('/');
    return false;
  }

  void _openNotifications(int pending) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.55),
          decoration: BoxDecoration(
            color: ThixPolicy.card.withValues(alpha: 0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(ThixPolicy.rXl)),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: ThixPolicy.s12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(ThixPolicy.s24, ThixPolicy.s20, ThixPolicy.s24, ThixPolicy.s16),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_rounded, color: ThixPolicy.textMain, size: 22),
                    const SizedBox(width: ThixPolicy.s12),
                    Text(_getTranslated('Notifications'), style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, letterSpacing: -0.3)),
                  ],
                ),
              ),
              const Divider(height: 1, color: ThixPolicy.border),
              Flexible(
                child: pending > 0
                    ? ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s24, vertical: ThixPolicy.s12),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: ThixPolicy.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                          ),
                          child: const Icon(Icons.swap_vert_rounded, color: ThixPolicy.danger, size: 24),
                        ),
                        title: Text(_getTranslated('Escalade(s) en attente'), style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 15)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(_getTranslated('Nécessite une action de votre part'), style: ThixPolicy.bodySmallStyle),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded, color: ThixPolicy.textSecondary),
                        onTap: () {
                          Navigator.pop(ctx);
                          context.pushNamed('chatEscalationReceived');
                        },
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Center(child: Text(_getTranslated('Aucune notification récente'), style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary))),
                      ),
              ),
              const SizedBox(height: ThixPolicy.s24),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(ThixPolicy.s20, ThixPolicy.s12, ThixPolicy.s20, ThixPolicy.s32),
          decoration: BoxDecoration(
            color: ThixPolicy.card.withValues(alpha: 0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(ThixPolicy.rXl)),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: ThixPolicy.s24),
              _sheetOpt(
                Icons.chat_bubble_outline_rounded,
                _getTranslated('Nouvelle discussion'),
                _getTranslated('Démarrer une conversation privée'),
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewConversationPage())),
              ),
              const SizedBox(height: ThixPolicy.s12),
              _sheetOpt(
                Icons.group_add_outlined,
                _getTranslated('Créer un groupe'),
                _getTranslated('Collaborer en équipe'),
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupCreatePage())),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetOpt(IconData icon, String title, String subtitle, VoidCallback tap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          tap();
        },
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        child: Container(
          padding: const EdgeInsets.all(ThixPolicy.s16),
          decoration: BoxDecoration(
            color: ThixPolicy.surface.withValues(alpha: 0.6),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(ThixPolicy.rLg),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: ThixPolicy.card.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                  border: Border.all(color: ThixPolicy.border.withValues(alpha: 0.5)),
                ),
                child: Icon(icon, size: 24, color: ThixPolicy.primaryDeep),
              ),
              const SizedBox(width: ThixPolicy.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: ThixPolicy.titleStyle.copyWith(fontSize: 15, fontWeight: ThixPolicy.bold, letterSpacing: -0.2)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: ThixPolicy.bodySmallStyle.copyWith(fontSize: 12, fontWeight: ThixPolicy.medium)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: ThixPolicy.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPreview(String? raw) {
    if (raw == null || raw.isEmpty) return _getTranslated('Nouvelle conversation');
    if (raw.startsWith('ENCv1:') ||
        raw.startsWith('🔒') ||
        (raw.length > 20 &&
            !raw.contains(' ') &&
            RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(raw.replaceFirst(RegExp(r'^ENCv1:'), '')))) {
      return '🔒 ' + _getTranslated('Message protégé');
    }
    final lower = raw.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') || lower.endsWith('.gif') || lower.endsWith('.webp')) {
      return '📷 ' + _getTranslated('Photo');
    }
    if (lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.avi')) {
      return '🎥 ' + _getTranslated('Vidéo');
    }
    if (lower.endsWith('.mp3') || lower.endsWith('.wav') || lower.endsWith('.m4a') || raw.contains('Message audio (')) {
      return '🎤 ' + _getTranslated('Message audio');
    }
    return raw;
  }

  Widget _buildReadReceipt(ChatMessage? msg, String currentUserId) {
    if (msg == null || msg.senderId != currentUserId) {
      return const SizedBox.shrink();
    }
    return ListMessageStatusLights(
      isDelivered: msg.isDelivered,
      isRead: msg.isRead,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatListProvider);
    final counters = ref.watch(notificationCountersProvider); // ✅ NOUVEAU
    final notifier = ref.read(chatListProvider.notifier);

    final currentUser = ref.watch(authControllerProvider).value;
    final currentUserName = currentUser?.displayName ?? '';
    final currentUserId = currentUser?.id ?? '';
    final currentUserPhoto = currentUser?.photoUrl;

    final onlineUserIds = ref.watch(presenceProvider);

    final seenUserIds = <String>{};
    final onlineContacts = <ChatConversation>[];

    for (final c in state.filtered) {
      if (c.isGroup) continue;
      final otherUserId = c.participantIds.firstWhere(
        (id) => id != currentUserId,
        orElse: () => '',
      );
      if (otherUserId.isNotEmpty && onlineUserIds.contains(otherUserId)) {
        if (seenUserIds.add(otherUserId)) {
          onlineContacts.add(c);
        }
      }
    }

    return WillPopScope( // ✅ NOUVEAU : Gestion du retour Android
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: ThixPolicy.surfaceSoft,
        body: Stack(
          children: [
            Positioned(
              top: -100, right: -50,
              child: _buildBlurOrb(ThixPolicy.primary.withValues(alpha: 0.08), 250),
            ),
            Positioned(
              bottom: 100, left: -100,
              child: _buildBlurOrb(ThixPolicy.primaryDeep.withValues(alpha: 0.05), 300),
            ),
            
            state.isLoading
                ? const Center(child: CircularProgressIndicator(color: ThixPolicy.primary, strokeWidth: 3))
                : RefreshIndicator(
                    color: ThixPolicy.primary,
                    backgroundColor: ThixPolicy.card,
                    onRefresh: () async {
                      await notifier.refresh(silent: true);
                      await ref.read(notificationCountersProvider.notifier).refresh(); // ✅ NOUVEAU
                      try {
                        ref.read(statusProvider.notifier).refresh();
                      } catch (_) {}
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
                          flexibleSpace: ClipRRect(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                              child: Container(
                                color: ThixPolicy.surfaceSoft.withValues(alpha: 0.7),
                                padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('THIX Chat', style: ThixPolicy.h1Style.copyWith(fontSize: 24, fontWeight: ThixPolicy.bold, letterSpacing: -0.5)),
                                      Row(
                                        children: [
                                          _iconButtonGlass(icon: Icons.swap_vert_rounded, badge: state.pendingEscalations > 0, onTap: () => context.pushNamed('chatEscalationReceived')),
                                          const SizedBox(width: ThixPolicy.s12),
                                          _iconButtonGlass(icon: Icons.notifications_none_rounded, badge: state.pendingEscalations > 0, onTap: () => _openNotifications(state.pendingEscalations)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
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
                                        return _onlineAvatarNode(
                                          label: conv.displayName.split(' ').first,
                                          avatarUrl: conv.displayAvatar,
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

                        SliverToBoxAdapter(child: _buildSearchBarGlass()),

                        if (state.pendingEscalations > 0)
                          SliverToBoxAdapter(child: _buildEscalationBanner(state.pendingEscalations)),

                        SliverToBoxAdapter(child: _buildFilters(state.filterIndex)),

                        const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s16)),

                        SliverToBoxAdapter(
                          child: Container(
                            decoration: BoxDecoration(
                              color: ThixPolicy.card.withValues(alpha: 0.6),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(ThixPolicy.rXl)),
                              border: Border(
                                top: BorderSide(color: Colors.white.withValues(alpha: 0.6), width: 1),
                                left: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 1),
                                right: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 1),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 10,
                                  spreadRadius: 0,
                                  offset: const Offset(0, -5),
                                ),
                              ]
                            ),
                            child: _chatList(state.filtered, currentUserId, currentUserName, onlineUserIds),
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

            // ✅ MODIFIÉ : Passe les compteurs à la bottom nav
            _buildGlassBottomNav(state.totalUnread, counters),
          ],
        ),
      ),
    );
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
        filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _iconButtonGlass({required IconData icon, required VoidCallback onTap, bool badge = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          shape: BoxShape.circle, 
          border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))
          ]
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 20, color: ThixPolicy.textMain),
            if (badge)
              Positioned(
                top: 8, right: 8,
                child: Container(width: 8, height: 8, decoration: BoxDecoration(color: ThixPolicy.danger, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5))),
              ),
          ],
        ),
      ),
    );
  }

  Widget _onlineAvatarNode({required String label, required String? avatarUrl, required bool isOnline, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 52,
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: CircleAvatar(
                    radius: 20, backgroundColor: ThixPolicy.surface,
                    backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
                    child: (avatarUrl == null || avatarUrl.isEmpty) ? const Icon(Icons.person, color: ThixPolicy.primaryDeep, size: 20) : null,
                  ),
                ),
                if (isOnline)
                  Positioned(
                    right: 0, bottom: 0,
                    child: Container(width: 12, height: 12, decoration: BoxDecoration(color: ThixPolicy.success, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: ThixPolicy.captionStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBarGlass() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(ThixPolicy.s20, 0, ThixPolicy.s20, ThixPolicy.s16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ThixPolicy.inputRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(ThixPolicy.inputRadius), 
              border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.2),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => ref.read(chatListProvider.notifier).search(v),
              style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMain, fontWeight: ThixPolicy.medium),
              decoration: InputDecoration(
                hintText: _getTranslated('Rechercher un message, un contact...'),
                hintStyle: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: ThixPolicy.textSecondary),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.close_rounded, size: 18, color: ThixPolicy.textSecondary), onPressed: () { _searchCtrl.clear(); ref.read(chatListProvider.notifier).search(''); })
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEscalationBanner(int pending) {
    return GestureDetector(
      onTap: () => context.pushNamed('chatEscalationReceived'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(ThixPolicy.s20, 0, ThixPolicy.s20, ThixPolicy.s16),
        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s12),
        decoration: BoxDecoration(
          color: ThixPolicy.danger.withValues(alpha: 0.08), 
          borderRadius: BorderRadius.circular(ThixPolicy.rMd), 
          border: Border.all(color: ThixPolicy.danger.withValues(alpha: 0.2))
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: ThixPolicy.danger, size: 18),
            const SizedBox(width: ThixPolicy.s12),
            Expanded(child: Text('$pending ${_getTranslated('escalade(s) en attente')}', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.danger, fontWeight: ThixPolicy.bold))),
            const Icon(Icons.arrow_forward_ios_rounded, color: ThixPolicy.danger, size: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(int selected) {
    final tabs = _getFilters(context);
    return SizedBox(
      height: 34,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        itemBuilder: (ctx, i) {
          final sel = selected == i;
          return Padding(
            padding: const EdgeInsets.only(right: ThixPolicy.s8),
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
                  color: sel ? ThixPolicy.textMain : Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? ThixPolicy.textMain : Colors.white.withValues(alpha: 0.8), width: 1.2),
                  boxShadow: sel ? [] : [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))
                  ],
                ),
                child: Text(
                  tabs[i],
                  style: ThixPolicy.bodySmallStyle.copyWith(
                    fontWeight: sel ? ThixPolicy.bold : ThixPolicy.semiBold, 
                    color: sel ? Colors.white : ThixPolicy.textSecondary
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _chatList(List<ChatConversation> list, String currentUserId, String currentUserName, Set<String> onlineUserIds) {
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20), 
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), shape: BoxShape.circle, border: Border.all(color: Colors.white)), 
              child: const Icon(Icons.chat_bubble_outline_rounded, size: 40, color: ThixPolicy.primaryDeep)
            ),
            const SizedBox(height: ThixPolicy.s16),
            Text(_getTranslated('Aucune conversation'), style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.textSecondary)),
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

        String chatName = conv.displayName;
        String? chatAvatar = conv.displayAvatar;

        if (conv.isGroup) {
          if (chatName.isEmpty) chatName = 'Groupe THIX';
        } else {
          if (chatName.trim() == currentUserName.trim() || chatName.isEmpty) {
            chatName = 'Contact THIX (ID: ${otherUserId.length > 4 ? otherUserId.substring(0, 4) : ''})';
          }
        }

        return Dismissible(
          key: ValueKey(conv.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            color: ThixPolicy.danger.withValues(alpha: 0.9),
            child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
          ),
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
              context: context,
              builder: (ctx) => BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: AlertDialog(
                  backgroundColor: ThixPolicy.card.withValues(alpha: 0.9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg), side: BorderSide(color: Colors.white.withValues(alpha: 0.5))),
                  title: Text(_getTranslated('Supprimer la discussion'), style: ThixPolicy.titleStyle),
                  content: Text(_getTranslated('Êtes-vous sûr de vouloir supprimer cette conversation ? Cette action est irréversible pour vous.'), style: ThixPolicy.bodyStyle),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false), 
                      child: Text(_getTranslated('Annuler'), style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary))
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger, elevation: 0),
                      onPressed: () => Navigator.pop(ctx, true), 
                      child: Text(_getTranslated('Supprimer'), style: ThixPolicy.labelStyle.copyWith(color: Colors.white))
                    ),
                  ],
                ),
              ),
            );
          },
          onDismissed: (direction) async {
            try {
              await Supabase.instance.client
                  .from('conversation_participants')
                  .delete()
                  .eq('conversation_id', conv.id)
                  .eq('user_id', currentUserId);
                  
              ref.read(chatListProvider.notifier).refresh(silent: true);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_getTranslated('Conversation supprimée'))));
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_getTranslated('Erreur lors de la suppression')), backgroundColor: ThixPolicy.danger));
            }
          },
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openConversation(conv),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20, vertical: 12),
                child: Row(
                  children: [
                    if (conv.isEscalation)
                      _EscalationAvatars(
                        clientName: conv.clientName ?? chatName,
                        clientAvatar: conv.clientAvatar ?? chatAvatar,
                        agentName: conv.agentName ?? 'Agent',
                        agentAvatar: conv.agentAvatar,
                      )
                    else
                      Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.5),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
                            ),
                            child: CircleAvatar(
                              radius: 26,
                              backgroundColor: ThixPolicy.surface,
                              backgroundImage: chatAvatar != null && chatAvatar.isNotEmpty
                                  ? CachedNetworkImageProvider(chatAvatar)
                                  : null,
                              child: (chatAvatar == null || chatAvatar.isEmpty)
                                  ? Text(
                                      chatName.isNotEmpty ? chatName[0].toUpperCase() : '?',
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
                                            chatName,
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
                                              color: ThixPolicy.danger.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: ThixPolicy.danger.withValues(alpha: 0.4),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.swap_vert_rounded, size: 11, color: ThixPolicy.danger),
                                                const SizedBox(width: 3),
                                                Text(
                                                  _getTranslated('Escaladé'),
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
                                  }
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _fmt(t),
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
                              'Agent : ${conv.agentName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ThixPolicy.captionStyle,
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _buildReadReceipt(last, currentUserId),
                              Expanded(
                                child: Text(
                                  _formatPreview(last?.content),
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
                                    boxShadow: [BoxShadow(color: ThixPolicy.primary.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))],
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
      },
    );
  }

  // ✅ MODIFIÉ : Accepte les compteurs et les affiche sur chaque icône
  Widget _buildGlassBottomNav(int unread, NotificationCounters counters) {
    return Positioned(
      bottom: 24, left: 0, right: 0,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              height: 64,
              width: MediaQuery.of(context).size.width * 0.90, 
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.2),
                boxShadow: [
                  BoxShadow(color: ThixPolicy.inkDeep.withValues(alpha: 0.08), blurRadius: 30, offset: const Offset(0, 10))
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _navItem(Icons.people_alt_outlined, Icons.people_alt, _getTranslated('Réseau'), 0, counters.newConnections),
                  _navItem(Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, _getTranslated('Discussions'), 1, unread),
                  GestureDetector(
                    onTap: () { _showCreateMenu(); },
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        gradient: ThixPolicy.brandGradient, 
                        shape: BoxShape.circle, 
                        boxShadow: [BoxShadow(color: ThixPolicy.primary.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3))]
                      ),
                      child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                  _navItem(Icons.call_outlined, Icons.call, _getTranslated('Appels'), 2, counters.missedCalls),
                  _navItem(Icons.settings_outlined, Icons.settings, _getTranslated('Réglages'), 3, 0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ MODIFIÉ : Utilise _navigateTo et affiche le compteur sur chaque icône
  Widget _navItem(IconData iconOutlined, IconData iconFilled, String label, int idx, int badge) {
    final isSelected = _selectedNav == idx;
    return InkWell(
      onTap: () => _navigateTo(idx), // ✅ Utilise la nouvelle méthode
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(isSelected ? iconFilled : iconOutlined, color: isSelected ? ThixPolicy.primary : ThixPolicy.textSecondary.withValues(alpha: 0.8), size: 24),
            // ✅ Badge compteur pour toutes les sections
            if (badge > 0)
              Positioned(
                right: -2, top: -2, 
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
    );
  }

  String _fmt(DateTime d) {
    final localDate = d.toLocal(); 
    final now = DateTime.now();
    final day = DateTime(localDate.year, localDate.month, localDate.day);
    final today = DateTime(now.year, now.month, now.day);
    
    if (day == today) {
      return DateFormat('HH:mm').format(localDate);
    }
    if (day == today.subtract(const Duration(days: 1))) {
      return _getTranslated('Hier');
    }
    if (now.difference(localDate).inDays < 7) {
      return DateFormat('EEEE', 'fr_FR').format(localDate);
    }
    return DateFormat('dd/MM/yy').format(localDate);
  }
}

class ListMessageStatusLights extends StatelessWidget {
  final bool isDelivered;
  final bool isRead;

  const ListMessageStatusLights({
    super.key,
    this.isDelivered = false,
    this.isRead = false,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isRead ? ThixPolicy.danger : (isDelivered ? ThixPolicy.warning : ThixPolicy.success);

    return Container(
      width: 9,
      height: 18,
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: ThixPolicy.inkDeep.withValues(alpha: 0.8),
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
          Positioned(
            left: 0,
            top: 2,
            child: _miniAvatar(clientAvatar, clientName, ThixPolicy.primary),
          ),
          Positioned(
            left: 20,
            top: 2,
            child: _miniAvatar(agentAvatar, agentName, ThixPolicy.danger),
          ),
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
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: CircleAvatar(
        radius: 15,
        backgroundColor: fallback.withOpacity(0.15),
        backgroundImage: (url != null && url.isNotEmpty)
            ? CachedNetworkImageProvider(url)
            : null,
        child: (url == null || url.isEmpty)
            ? Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: ThixPolicy.labelStyle.copyWith(color: fallback),
              )
            : null,
      ),
    );
  }
}
