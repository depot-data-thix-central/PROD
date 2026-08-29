// lib/presentation/network/community_detail_page.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:timeago/timeago.dart' as timeago;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/models/network_community.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';
import 'package:thix_id/presentation/network/widgets/post_card.dart';
import 'package:thix_id/features/network/presentation/providers/community_detail_provider.dart';

// ============================================================================
// VALIDATEURS
// ============================================================================
class _CommunityValidators {
  _CommunityValidators._();

  static String sanitize(String? input, {int maxLength = 2000}) {
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
// PROVIDER CHAT REALTIME
// ============================================================================
@immutable
class ChatMessage {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String content;
  final DateTime createdAt;
  final String? parentId;
  final bool isEdited;

  const ChatMessage({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.content,
    required this.createdAt,
    this.parentId,
    this.isEdited = false,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> m) {
    final profile = m['profiles'] as Map?;
    return ChatMessage(
      id: m['id'] as String,
      userId: m['user_id'] as String,
      userName: (profile?['display_name'] ?? 'Anonyme').toString(),
      userAvatar: (profile?['avatar_url'] ?? profile?['photo_url'])?.toString(),
      content: (m['content'] ?? '').toString(),
      createdAt: DateTime.parse(m['created_at'].toString()).toLocal(),
      parentId: m['parent_id']?.toString(),
      isEdited: m['is_edited'] == true,
    );
  }
}

class CommunityChatNotifier extends StateNotifier<AsyncValue<List<ChatMessage>>> {
  final String communityId;
  RealtimeChannel? _channel;

  CommunityChatNotifier(this.communityId) : super(const AsyncLoading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Supabase.instance.client
          .from('community_messages')
          .select('*, profiles(display_name, avatar_url, photo_url)')
          .eq('community_id', communityId)
          .order('created_at', ascending: true)
          .limit(50);

      state = AsyncData((res as List).map((e) => ChatMessage.fromMap(e as Map<String, dynamic>)).toList());
      _subscribeRealtime();
    } catch (e) {
      debugPrint('[CommunityChat] Load error: $e');
      state = AsyncError(e, StackTrace.current);
    }
  }

  void _subscribeRealtime() {
    _channel?.unsubscribe();
    _channel = Supabase.instance.client
        .channel('community-$communityId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'community_messages',
          filter: PostgresChangeFilter(type: PostgresFilterType.eq, column: 'community_id', value: communityId),
          callback: (payload) async {
            final newMsg = payload.newRecord;
            // Récupérer le profil si non présent
            final profile = await Supabase.instance.client
                .from('profiles')
                .select('display_name, avatar_url, photo_url')
                .eq('id', newMsg['user_id'])
                .maybeSingle();

            final enriched = {...newMsg, 'profiles': profile};
            final msg = ChatMessage.fromMap(enriched);
            final current = state.valueOrNull ?? [];
            state = AsyncData([...current, msg]);
          },
        )
        .subscribe();
  }

  Future<void> sendMessage(String content) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) throw Exception('Non authentifié');

    final sanitized = _CommunityValidators.sanitize(content, maxLength: 1000);
    if (sanitized.isEmpty) throw Exception('Message vide');

    await Supabase.instance.client.from('community_messages').insert({
      'community_id': communityId,
      'user_id': uid,
      'content': sanitized,
    });
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final communityChatProvider = StateNotifierProvider.autoDispose
    .family<CommunityChatNotifier, AsyncValue<List<ChatMessage>>, String>(
  (ref, communityId) => CommunityChatNotifier(communityId),
);

// ============================================================================
// COMPOSANT PRINCIPAL
// ============================================================================
class CommunityDetailPage extends ConsumerStatefulWidget {
  final String communityId;
  const CommunityDetailPage({super.key, required this.communityId});

  @override
  ConsumerState<CommunityDetailPage> createState() => _CommunityDetailPageState();
}

class _CommunityDetailPageState extends ConsumerState<CommunityDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _postsScroll = ScrollController();
  final ScrollController _chatScroll = ScrollController();
  final TextEditingController _chatCtrl = TextEditingController();
  final TextEditingController _memberSearchCtrl = TextEditingController();
  final FocusNode _chatFocus = FocusNode();

  bool _isJoiningProcess = false;
  String _memberSearchQuery = '';
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) HapticFeedback.selectionClick();
    });
    _postsScroll.addListener(() {
      if (_postsScroll.position.pixels >= _postsScroll.position.maxScrollExtent - 400) {
        ref.read(communityDetailProvider(widget.communityId).notifier).loadMorePosts();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _postsScroll.dispose();
    _chatScroll.dispose();
    _chatCtrl.dispose();
    _memberSearchCtrl.dispose();
    _chatFocus.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(_chatScroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _handleToggleJoin(bool currentlyMember) async {
    if (_isJoiningProcess) return;

    if (currentlyMember) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: ThixPolicy.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
          title: Text('Quitter la communauté ?', style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.danger)),
          content: Text('Vous n\'aurez plus accès aux publications ni au chat.', style: ThixPolicy.bodyStyle),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger, foregroundColor: Colors.white),
              child: const Text('Quitter'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _isJoiningProcess = true);
    HapticFeedback.mediumImpact();

    try {
      await ref.read(communityDetailProvider(widget.communityId).notifier).toggleJoin();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currentlyMember ? 'Vous avez quitté la communauté' : 'Bienvenue dans la communauté !'),
            backgroundColor: currentlyMember ? ThixPolicy.textSecondary : ThixPolicy.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[Community] Toggle join error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur réseau'), backgroundColor: ThixPolicy.danger, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isJoiningProcess = false);
    }
  }

  void _shareCommunity(NetworkCommunity? community) {
    if (community == null) return;
    HapticFeedback.selectionClick();
    Share.share(
      'Rejoins "${community.name}" sur THIX ID !\nhttps://thix.app/community/${community.id}',
      subject: 'Communauté THIX : ${community.name}',
    );
  }

  Future<void> _showCreatePostDialog(CommunityDetailState state) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: ThixPolicy.primary),
            const SizedBox(width: 8),
            Text('Publier dans ${state.community.name}', style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold)),
          ],
        ),
        content: TextField(
          controller: ctrl,
          maxLines: 6,
          maxLength: 2000,
          autofocus: true,
          style: ThixPolicy.bodyStyle,
          decoration: InputDecoration(
            hintText: 'Partagez quelque chose avec la communauté...',
            filled: true,
            fillColor: ThixPolicy.surfaceSoft,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd), borderSide: BorderSide.none),
            counterText: '',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Annuler', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white),
            child: const Text('Publier'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      try {
        await ref.read(communityDetailProvider(widget.communityId).notifier).createPost(_CommunityValidators.sanitize(result));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Publication créée !'), backgroundColor: ThixPolicy.success, behavior: SnackBarBehavior.floating),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur : $e'), backgroundColor: ThixPolicy.danger, behavior: SnackBarBehavior.floating),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(communityDetailProvider(widget.communityId));
    final currentUserId = ref.watch(authControllerProvider).value?.id ?? '';

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          asyncState.valueOrNull?.community.name ?? 'Communauté',
          style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.textMain, fontWeight: ThixPolicy.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: ThixPolicy.textMain, size: 22),
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: ThixPolicy.textMain, size: 22),
            onPressed: () => _shareCommunity(asyncState.valueOrNull?.community),
          ),
          if (asyncState.valueOrNull != null)
            Padding(
              padding: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
              child: ElevatedButton(
                onPressed: _isJoiningProcess ? null : () => _handleToggleJoin(asyncState.valueOrNull!.isMember),
                style: ElevatedButton.styleFrom(
                  backgroundColor: asyncState.valueOrNull!.isMember ? ThixPolicy.card : ThixPolicy.primary,
                  foregroundColor: asyncState.valueOrNull!.isMember ? ThixPolicy.textMain : Colors.white,
                  elevation: 0,
                  side: asyncState.valueOrNull!.isMember ? const BorderSide(color: ThixPolicy.borderStrong) : null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: _isJoiningProcess
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.textSecondary))
                    : Text(
                        asyncState.valueOrNull!.isMember ? 'Quitter' : 'Rejoindre',
                        style: ThixPolicy.labelStyle.copyWith(
                          color: asyncState.valueOrNull!.isMember ? ThixPolicy.textMain : Colors.white,
                          fontWeight: ThixPolicy.bold,
                        ),
                      ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: ThixPolicy.border, width: 1))),
            child: TabBar(
              controller: _tabController,
              labelColor: ThixPolicy.primary,
              unselectedLabelColor: ThixPolicy.textSecondary,
              indicatorColor: ThixPolicy.primary,
              indicatorWeight: 3,
              labelStyle: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold),
              unselectedLabelStyle: ThixPolicy.labelStyle,
              tabs: const [
                Tab(icon: Icon(Icons.info_outline_rounded, size: 18), text: 'À propos'),
                Tab(icon: Icon(Icons.people_rounded, size: 18), text: 'Membres'),
                Tab(icon: Icon(Icons.chat_bubble_outline_rounded, size: 18), text: 'Discussion'),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: asyncState.valueOrNull?.isMember == true
          ? FloatingActionButton(
              onPressed: () => _showCreatePostDialog(asyncState.valueOrNull!),
              backgroundColor: ThixPolicy.primary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add_rounded, size: 28),
            )
          : null,
      body: asyncState.when(
        loading: () => _buildSkeletonState(),
        error: (e, _) => _buildErrorState(e.toString()),
        data: (state) => TabBarView(
          controller: _tabController,
          children: [
            _buildAboutTab(state, currentUserId),
            _buildMembersTab(state.members),
            _buildDiscussionTab(state, currentUserId),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(height: 180, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(ThixPolicy.rMd))),
          const SizedBox(height: 16),
          Container(height: 24, width: 200, color: Colors.grey.shade200),
          const SizedBox(height: 12),
          Container(height: 14, width: double.infinity, color: Colors.grey.shade200),
          const SizedBox(height: 8),
          Container(height: 14, width: double.infinity * 0.7, color: Colors.grey.shade200),
        ],
      ),
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
            Text('Erreur de chargement', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain)),
            const SizedBox(height: 8),
            Text(_CommunityValidators.sanitize(error), textAlign: TextAlign.center, style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(communityDetailProvider(widget.communityId)),
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── TAB À PROPOS ───
  Widget _buildAboutTab(CommunityDetailState state, String currentUserId) {
    final community = state.community;
    final posts = state.posts;
    final name = _CommunityValidators.sanitize(community.name, maxLength: 100);
    final description = _CommunityValidators.sanitize(community.description, maxLength: 1000);
    final bannerUrl = _CommunityValidators.sanitizeUrl(community.bannerUrl);
    final privacy = _CommunityValidators.sanitize(community.privacy ?? 'Public', maxLength: 20);

    return RefreshIndicator(
      color: ThixPolicy.primary,
      backgroundColor: ThixPolicy.card,
      onRefresh: () async => ref.invalidate(communityDetailProvider(widget.communityId)),
      child: SingleChildScrollView(
        controller: _postsScroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bannière
            ClipRRect(
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              child: bannerUrl != null && bannerUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: bannerUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(height: 180, color: ThixPolicy.inkDeep),
                      errorWidget: (_, __, ___) => _buildDefaultBanner(name),
                    )
                  : _buildDefaultBanner(name),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Text(name, style: ThixPolicy.h1Style.copyWith(fontWeight: ThixPolicy.bold)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: ThixPolicy.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                  child: Text(
                    privacy,
                    style: ThixPolicy.captionStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.primary),
                  ),
                ),
              ],
            ),

            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(description, style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.5)),
            ],

            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ThixPolicy.card,
                borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                border: Border.all(color: ThixPolicy.border.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Expanded(child: _buildStatItem('${community.membersCount}', 'Membres', Icons.people_alt_rounded)),
                  Container(width: 1, height: 30, color: ThixPolicy.border, margin: const EdgeInsets.symmetric(horizontal: 24)),
                  Expanded(child: _buildStatItem('${posts.length}', 'Publications', Icons.article_rounded)),
                ],
              ),
            ),

            const SizedBox(height: 32),
            Row(
              children: [
                Text('Dernières publications', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
                const Spacer(),
                if (state.hasMorePosts)
                  Text('${posts.length} posts', style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary)),
              ],
            ),
            const SizedBox(height: 12),

            if (posts.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ThixPolicy.border)),
                        child: const Icon(Icons.feed_outlined, size: 32, color: ThixPolicy.textMuted),
                      ),
                      const SizedBox(height: 12),
                      Text('Aucune publication pour le moment', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary)),
                      if (state.isMember) ...[
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _showCreatePostDialog(state),
                          icon: const Icon(Icons.add_rounded, color: Colors.white),
                          label: const Text('Créer la première publication'),
                          style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else
              Column(
                children: posts
                    .map((post) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: PostCard(
                            post: post,
                            currentProfileId: currentUserId,
                            onLike: () => ref.read(communityDetailProvider(widget.communityId).notifier).toggleLike(post.id),
                            onComment: () => context.push('/network/comments/${post.id}'),
                            onTap: () => context.push('/network/post/${post.id}'),
                            onShare: () => Share.share('Découvrez cette publication sur THIX ID'),
                            onRefresh: () => ref.invalidate(communityDetailProvider(widget.communityId)),
                          ),
                        ))
                    .toList(),
              ),

            if (state.hasMorePosts && posts.isNotEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary))),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultBanner(String name) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [ThixPolicy.inkDeep, ThixPolicy.primary]),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.groups_rounded, size: 56, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 8),
            Text(name, style: ThixPolicy.h2Style.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: ThixPolicy.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
          child: Icon(icon, size: 20, color: ThixPolicy.primary),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
            Text(label, style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary)),
          ],
        ),
      ],
    );
  }

  // ─── TAB MEMBRES ───
  Widget _buildMembersTab(List<Map<String, dynamic>> members) {
    final query = _memberSearchQuery.toLowerCase();
    final filtered = members.where((m) {
      final name = (m['display_name'] ?? '').toString().toLowerCase();
      final title = (m['profession'] ?? '').toString().toLowerCase();
      return name.contains(query) || title.contains(query);
    }).toList();

    return Column(
      children: [
        Container(
          color: ThixPolicy.card,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              TextField(
                controller: _memberSearchCtrl,
                onChanged: (val) => setState(() => _memberSearchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Rechercher un membre...',
                  hintStyle: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded, color: ThixPolicy.textSecondary, size: 20),
                  suffixIcon: _memberSearchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: ThixPolicy.textSecondary, size: 18),
                          onPressed: () {
                            _memberSearchCtrl.clear();
                            setState(() => _memberSearchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: ThixPolicy.surfaceSoft,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.people_rounded, size: 14, color: ThixPolicy.textSecondary),
                  const SizedBox(width: 6),
                  Text('${filtered.length}/${members.length} membre${members.length > 1 ? 's' : ''}', style: ThixPolicy.captionStyle),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: members.isEmpty
              ? _buildEmptyMembers()
              : filtered.isEmpty
                  ? _buildNoResults()
                  : RefreshIndicator(
                      color: ThixPolicy.primary,
                      backgroundColor: ThixPolicy.card,
                      onRefresh: () async => ref.invalidate(communityDetailProvider(widget.communityId)),
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) => _buildMemberTile(filtered[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyMembers() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, shape: BoxShape.circle),
            child: const Icon(Icons.people_outline, size: 48, color: ThixPolicy.textMuted),
          ),
          const SizedBox(height: 12),
          Text('Aucun membre pour le moment', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: ThixPolicy.textMuted),
          const SizedBox(height: 12),
          Text('Aucun résultat pour "$_memberSearchQuery"', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildMemberTile(Map<String, dynamic> member) {
    final name = _CommunityValidators.sanitize(member['display_name']?.toString() ?? 'Utilisateur', maxLength: 100);
    final title = _CommunityValidators.sanitize(member['profession']?.toString() ?? '', maxLength: 100);
    final avatarUrl = _CommunityValidators.sanitizeUrl(member['photo_url']?.toString() ?? member['avatar_url']?.toString());
    final role = (member['role'] ?? 'member').toString().toLowerCase();
    final id = member['id']?.toString() ?? '';

    final isOwner = role == 'owner';
    final isAdmin = role == 'admin';

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/network/profile/$id');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          border: Border.all(color: ThixPolicy.border.withOpacity(0.5)),
          boxShadow: ThixPolicy.shadowSoft(opacity: 0.03),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: ThixPolicy.surfaceSoft,
            backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'U', style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.textSecondary))
                : null,
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(name, style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (isOwner) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: ThixPolicy.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                  child: Text('Owner', style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.gold, fontWeight: ThixPolicy.bold)),
                ),
              ] else if (isAdmin) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: ThixPolicy.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                  child: Text('Admin', style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.primary, fontWeight: ThixPolicy.bold)),
                ),
              ],
            ],
          ),
          subtitle: title.isNotEmpty
              ? Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary))
              : null,
          trailing: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
            child: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: ThixPolicy.textSecondary),
          ),
        ),
      ),
    );
  }

  // ─── TAB DISCUSSION ───
  Widget _buildDiscussionTab(CommunityDetailState state, String currentUserId) {
    if (!state.isMember) {
      return _buildLockedChat();
    }

    final chatAsync = ref.watch(communityChatProvider(widget.communityId));

    // Auto-scroll quand nouveau message
    chatAsync.whenData((msgs) {
      if (msgs.isNotEmpty) _scrollToBottom();
    });

    return Column(
      children: [
        Expanded(child: chatAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: ThixPolicy.primary)),
          error: (e, _) => Center(child: Text('Erreur chat', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.danger))),
          data: (messages) => messages.isEmpty ? _buildEmptyChat() : _buildMessageList(messages, currentUserId),
        )),
        _buildChatInput(state),
      ],
    );
  }

  Widget _buildLockedChat() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, shape: BoxShape.circle, border: Border.all(color: ThixPolicy.border)),
              child: const Icon(Icons.lock_outline_rounded, size: 48, color: ThixPolicy.textMuted),
            ),
            const SizedBox(height: 20),
            Text('Espace privé', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
            const SizedBox(height: 8),
            Text('Rejoignez la communauté pour accéder au chat.', textAlign: TextAlign.center, style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.4)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _handleToggleJoin(false),
              icon: const Icon(Icons.login_rounded, color: Colors.white),
              label: const Text('Rejoindre le groupe'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, shape: BoxShape.circle),
            child: const Icon(Icons.forum_outlined, size: 36, color: ThixPolicy.textMuted),
          ),
          const SizedBox(height: 16),
          Text('Aucun message', style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold)),
          const SizedBox(height: 4),
          Text('Soyez le premier à écrire !', style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildMessageList(List<ChatMessage> messages, String currentUserId) {
    return ListView.builder(
      controller: _chatScroll,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, i) => _buildMessageBubble(messages[i], currentUserId),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, String currentUserId) {
    final isMe = msg.userId == currentUserId;
    final content = _CommunityValidators.sanitize(msg.content);
    final userName = _CommunityValidators.sanitize(msg.userName, maxLength: 50);
    final avatarUrl = _CommunityValidators.sanitizeUrl(msg.userAvatar);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: ThixPolicy.surfaceSoft,
              backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
              child: avatarUrl == null
                  ? Text(userName.isNotEmpty ? userName[0].toUpperCase() : '?', style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary))
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? ThixPolicy.primary : ThixPolicy.card,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(ThixPolicy.rMd),
                  topRight: const Radius.circular(ThixPolicy.rMd),
                  bottomLeft: Radius.circular(isMe ? ThixPolicy.rMd : ThixPolicy.rXs),
                  bottomRight: Radius.circular(isMe ? ThixPolicy.rXs : ThixPolicy.rMd),
                ),
                border: isMe ? null : Border.all(color: ThixPolicy.border.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(userName, style: ThixPolicy.captionStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.primary)),
                    ),
                  Text(
                    content,
                    style: ThixPolicy.bodyStyle.copyWith(color: isMe ? Colors.white : ThixPolicy.textMain, height: 1.4),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(timeago.format(msg.createdAt, locale: 'fr'), style: ThixPolicy.microStyle.copyWith(color: isMe ? Colors.white70 : ThixPolicy.textMuted)),
                      if (msg.isEdited) ...[
                        const SizedBox(width: 4),
                        Text('• modifié', style: ThixPolicy.microStyle.copyWith(color: isMe ? Colors.white70 : ThixPolicy.textMuted, fontStyle: FontStyle.italic)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildChatInput(CommunityDetailState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: ThixPolicy.card, border: Border(top: BorderSide(color: ThixPolicy.border))),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _chatCtrl,
                focusNode: _chatFocus,
                maxLines: 4,
                minLines: 1,
                maxLength: 1000,
                style: ThixPolicy.bodyStyle,
                decoration: InputDecoration(
                  hintText: 'Écrire un message...',
                  hintStyle: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.rXl), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: ThixPolicy.surfaceSoft,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _isSending ? null : () async {
                final text = _chatCtrl.text.trim();
                if (text.isEmpty) return;
                setState(() => _isSending = true);
                try {
                  await ref.read(communityChatProvider(widget.communityId).notifier).sendMessage(text);
                  _chatCtrl.clear();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur : $e'), backgroundColor: ThixPolicy.danger, behavior: SnackBarBehavior.floating),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isSending = false);
                }
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [ThixPolicy.primary, Color(0xFF6366F1)]),
                  shape: BoxShape.circle,
                  boxShadow: ThixPolicy.shadowNode(color: ThixPolicy.primary),
                ),
                child: _isSending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
