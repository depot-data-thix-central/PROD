// lib/presentation/network/search_network_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:timeago/timeago.dart' as timeago;

import 'package:thix_id/models/network_community.dart';
import 'package:thix_id/models/certification_tier.dart';
import 'package:thix_id/presentation/certification/widgets/certification_name_badge.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

// ============================================================================
// VALIDATEURS
// ============================================================================
class _SearchValidators {
  _SearchValidators._();

  static const Duration requestTimeout = Duration(seconds: 10);

  static String sanitize(String? input, {int maxLength = 500}) {
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
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return null;
    }
    return trimmed.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }
}

// ============================================================================
// COMPOSANT PRINCIPAL
// ============================================================================
class SearchNetworkPage extends ConsumerStatefulWidget {
  const SearchNetworkPage({super.key});
  @override
  ConsumerState<SearchNetworkPage> createState() => _SearchNetworkPageState();
}

class _SearchNetworkPageState extends ConsumerState<SearchNetworkPage> with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  String _query = '';
  bool _loading = false;

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _posts = [];
  List<NetworkCommunity> _communities = [];

  Set<String> _pending = {};
  Set<String> _connected = {};

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() {
      if (_tab.indexIsChanging) HapticFeedback.selectionClick();
    });
    _loadConnections();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    _tab.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadConnections() async {
    final supa = Supabase.instance.client;
    final uid = supa.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final results = await Future.wait([
        supa.from('connection_requests').select('receiver_id').eq('sender_id', uid).eq('status', 'pending'),
        supa.from('connections').select('connection_id').eq('user_id', uid).eq('status', 'accepted'),
      ]).timeout(_SearchValidators.requestTimeout);

      if (!mounted) return;
      setState(() {
        _pending = (results[0] as List).map((e) => e['receiver_id'] as String).toSet();
        _connected = (results[1] as List).map((e) => e['connection_id'] as String).toSet();
      });
    } catch (e) {
      debugPrint('[Search] Load connections error: $e');
    }
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _search);
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) {
      if (mounted) {
        setState(() {
          _query = '';
          _users = [];
          _posts = [];
          _communities = [];
          _loading = false;
        });
      }
      return;
    }

    setState(() {
      _query = q;
      _loading = true;
    });

    final supa = Supabase.instance.client;

    try {
      final res = await Future.wait([
        supa.from('profiles').select().ilike('display_name', '%$q%').limit(20).timeout(_SearchValidators.requestTimeout),
        supa.from('posts_view').select().ilike('content', '%$q%').eq('is_public', true).order('created_at', ascending: false).limit(20).timeout(_SearchValidators.requestTimeout),
        supa.from('communities').select().ilike('name', '%$q%').limit(20).timeout(_SearchValidators.requestTimeout),
      ]);

      if (!mounted) return;
      if (_searchCtrl.text.trim() != q) return;

      setState(() {
        _users = (res[0] as List).cast<Map<String, dynamic>>();
        _posts = (res[1] as List).cast<Map<String, dynamic>>();
        _communities = (res[2] as List).map((e) => NetworkCommunity.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('[Search] Search error: $e');
      if (mounted && _searchCtrl.text.trim() == q) {
        setState(() {
          _loading = false;
          _users = [];
          _posts = [];
          _communities = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erreur de recherche'),
            backgroundColor: ThixPolicy.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _sendReq(String uid, String name) async {
    HapticFeedback.mediumImpact();
    setState(() => _pending.add(uid));
    try {
      await Supabase.instance.client
          .from('connection_requests')
          .insert({'sender_id': Supabase.instance.client.auth.currentUser!.id, 'receiver_id': uid, 'status': 'pending'})
          .timeout(_SearchValidators.requestTimeout);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Demande envoyée à $name'),
              ],
            ),
            backgroundColor: ThixPolicy.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[Search] Send request error: $e');
      if (mounted) {
        setState(() => _pending.remove(uid));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'envoi'), backgroundColor: ThixPolicy.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        title: Text('Recherche', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
        iconTheme: const IconThemeData(color: ThixPolicy.textMain),
        bottom: TabBar(
          controller: _tab,
          labelColor: ThixPolicy.primary,
          unselectedLabelColor: ThixPolicy.textSecondary,
          indicatorColor: ThixPolicy.primary,
          indicatorWeight: 3,
          labelStyle: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold),
          tabs: const [
            Tab(icon: Icon(Icons.people_rounded, size: 20), text: 'Personnes'),
            Tab(icon: Icon(Icons.article_rounded, size: 20), text: 'Publications'),
            Tab(icon: Icon(Icons.groups_rounded, size: 20), text: 'Communautés'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _loading
                ? _buildSkeleton()
                : _query.isEmpty
                    ? _buildEmptyState()
                    : TabBarView(
                        controller: _tab,
                        children: [_usersTab(), _postsTab(), _commsTab()],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: ThixPolicy.card,
      child: TextField(
        controller: _searchCtrl,
        focusNode: _focusNode,
        onChanged: _onChanged,
        onSubmitted: (_) => _search(),
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Rechercher...',
          hintStyle: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
          prefixIcon: const Icon(Icons.search_rounded, color: ThixPolicy.primary, size: 22),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, color: ThixPolicy.textSecondary, size: 20),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {
                      _query = '';
                      _users = [];
                      _posts = [];
                      _communities = [];
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.rXl), borderSide: BorderSide.none),
          filled: true,
          fillColor: ThixPolicy.surfaceSoft,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return TabBarView(
      controller: _tab,
      children: [_buildSkeletonUsers(), _buildSkeletonPosts(), _buildSkeletonCommunities()],
    );
  }

  Widget _buildSkeletonUsers() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: 120, color: Colors.grey.shade200),
                  const SizedBox(height: 8),
                  Container(height: 12, width: 80, color: Colors.grey.shade200),
                ],
              ),
            ),
            Container(width: 80, height: 32, color: Colors.grey.shade200),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonPosts() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(child: Container(height: 14, color: Colors.grey.shade200)),
              ],
            ),
            const SizedBox(height: 12),
            Container(height: 14, width: double.infinity, color: Colors.grey.shade200),
            const SizedBox(height: 8),
            Container(height: 14, width: 200, color: Colors.grey.shade200),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonCommunities() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: 150, color: Colors.grey.shade200),
                  const SizedBox(height: 8),
                  Container(height: 12, width: 80, color: Colors.grey.shade200),
                ],
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
              decoration: BoxDecoration(
                color: ThixPolicy.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_rounded, size: 64, color: ThixPolicy.primary),
            ),
            const SizedBox(height: 24),
            Text('Explorez le réseau THIX', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
            const SizedBox(height: 8),
            Text(
              'Recherchez des personnes, publications ou communautés',
              textAlign: TextAlign.center,
              style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  // ─── USERS TAB ───
  Widget _usersTab() {
    return _users.isEmpty
        ? _buildNoResults(icon: Icons.people_outline_rounded, title: 'Aucun utilisateur trouvé')
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _users.length,
            itemBuilder: (_, i) => _userTile(_users[i]),
          );
  }

  Widget _userTile(Map<String, dynamic> u) {
    final avatar = _SearchValidators.sanitizeUrl(u['avatar_url']?.toString() ?? u['photo_url']?.toString());
    final name = _SearchValidators.sanitize(u['display_name']?.toString() ?? 'Utilisateur', maxLength: 100);
    final title = _SearchValidators.sanitize(u['profession']?.toString() ?? '', maxLength: 100);
    final id = u['id']?.toString() ?? '';

    CertificationTier? tier;
    CertificationStatus? status;
    bool isCertified = false;
    bool isLegacyVerified = u['is_verified'] == true;

    if (u['certification_tier'] != null) {
      tier = CertificationTierX.parse(u['certification_tier']);
      status = CertificationStatusX.parse(u['certification_status']);
      isCertified = status == CertificationStatus.approved || status == CertificationStatus.generated;
    }

    final isMe = id == Supabase.instance.client.auth.currentUser?.id;
    final pending = _pending.contains(id);
    final connected = _connected.contains(id);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/network/profile/$id');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          border: Border.all(color: ThixPolicy.border.withOpacity(0.3)),
          boxShadow: ThixPolicy.shadowSoft(opacity: 0.03),
        ),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ThixPolicy.border, width: 1.5),
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: ThixPolicy.surfaceSoft,
                child: ClipOval(
                  child: avatar != null
                      ? CachedNetworkImage(
                          imageUrl: avatar,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: ThixPolicy.surfaceSoft),
                          errorWidget: (_, __, ___) => const Icon(Icons.person, color: ThixPolicy.textMuted),
                        )
                      : const Icon(Icons.person, color: ThixPolicy.textMuted),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
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
                  if (title.isNotEmpty)
                    Text(
                      title,
                      style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (!isMe)
              connected
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: ThixPolicy.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                        border: Border.all(color: ThixPolicy.success.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_rounded, size: 14, color: ThixPolicy.success),
                          const SizedBox(width: 4),
                          Text('Connecté', style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.success, fontWeight: ThixPolicy.semiBold)),
                        ],
                      ),
                    )
                  : pending
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: ThixPolicy.border),
                            borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                          ),
                          child: Text('En attente', style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary)),
                        )
                      : ElevatedButton(
                          onPressed: () => _sendReq(id, name),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ThixPolicy.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
                          ),
                          child: Text('Se connecter', style: ThixPolicy.captionStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold)),
                        ),
          ],
        ),
      ),
    );
  }

  // ─── POSTS TAB ───
  Widget _postsTab() {
    return _posts.isEmpty
        ? _buildNoResults(icon: Icons.article_outlined, title: 'Aucune publication trouvée')
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _posts.length,
            itemBuilder: (_, i) => _postTile(_posts[i]),
          );
  }

  Widget _postTile(Map<String, dynamic> p) {
    final content = _SearchValidators.sanitize(p['content']?.toString() ?? '', maxLength: 300);
    final authorName = _SearchValidators.sanitize(p['author_name']?.toString() ?? '', maxLength: 100);
    final authorAvatar = _SearchValidators.sanitizeUrl(p['author_avatar']?.toString());
    final postId = p['id']?.toString() ?? '';
    final likesCount = (p['likes_count'] as num?)?.toInt() ?? 0;
    final commentsCount = (p['comments_count'] as num?)?.toInt() ?? 0;

    DateTime? createdAt;
    try {
      final createdAtStr = p['created_at']?.toString();
      if (createdAtStr != null && createdAtStr.isNotEmpty) {
        createdAt = DateTime.parse(createdAtStr);
      }
    } catch (e) {
      debugPrint('[Search] Parse date error: $e');
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/network/post/$postId');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          border: Border.all(color: ThixPolicy.border.withOpacity(0.3)),
          boxShadow: ThixPolicy.shadowSoft(opacity: 0.03),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: ThixPolicy.surfaceSoft,
                  child: ClipOval(
                    child: authorAvatar != null
                        ? CachedNetworkImage(
                            imageUrl: authorAvatar,
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Icon(Icons.person, size: 18, color: ThixPolicy.textMuted),
                          )
                        : const Icon(Icons.person, size: 18, color: ThixPolicy.textMuted),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(authorName, style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (createdAt != null)
                        Text(timeago.format(createdAt, locale: 'fr'), style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (content.isNotEmpty)
              Text(
                content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: ThixPolicy.bodyStyle.copyWith(height: 1.4),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Row(
                  children: [
                    const Icon(Icons.favorite_border_rounded, size: 14, color: ThixPolicy.textSecondary),
                    const SizedBox(width: 4),
                    Text('$likesCount', style: ThixPolicy.captionStyle.copyWith(fontWeight: ThixPolicy.semiBold)),
                  ],
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: ThixPolicy.textSecondary),
                    const SizedBox(width: 4),
                    Text('$commentsCount', style: ThixPolicy.captionStyle.copyWith(fontWeight: ThixPolicy.semiBold)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── COMMUNITIES TAB ───
  Widget _commsTab() {
    return _communities.isEmpty
        ? _buildNoResults(icon: Icons.groups_outlined, title: 'Aucune communauté trouvée')
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _communities.length,
            itemBuilder: (_, i) => _commTile(_communities[i]),
          );
  }

  Widget _commTile(NetworkCommunity c) {
    final coverUrl = _SearchValidators.sanitizeUrl(c.coverUrl);
    final name = _SearchValidators.sanitize(c.name, maxLength: 100);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/network/community/${c.id}');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          border: Border.all(color: ThixPolicy.border.withOpacity(0.3)),
          boxShadow: ThixPolicy.shadowSoft(opacity: 0.03),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: coverUrl == null
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [ThixPolicy.primary, Color(0xFF6366F1)],
                      )
                    : null,
                borderRadius: BorderRadius.circular(ThixPolicy.rSm),
              ),
              child: coverUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                      child: CachedNetworkImage(
                        imageUrl: coverUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const Icon(Icons.groups_rounded, color: Colors.white, size: 24),
                      ),
                    )
                  : const Icon(Icons.groups_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '${c.membersCount} membres',
                    style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, fontWeight: ThixPolicy.semiBold),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: ThixPolicy.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(ThixPolicy.rSm),
              ),
              child: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: ThixPolicy.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults({required IconData icon, required String title}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ThixPolicy.surfaceSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: ThixPolicy.textMuted),
            ),
            const SizedBox(height: 16),
            Text(title, style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary)),
            const SizedBox(height: 8),
            Text('Essayez avec d\'autres mots-clés', style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted)),
          ],
        ),
      ),
    );
  }
}
