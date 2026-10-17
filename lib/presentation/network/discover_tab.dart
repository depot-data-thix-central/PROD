// lib/presentation/network/discover_tab.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';

// ============================================================================
// VALIDATEURS / NETTOYAGE
// ============================================================================
class _DiscoverValidators {
  _DiscoverValidators._();

  static final RegExp _markup = RegExp(r'\{[a-zA-Z]+:[^}]*\}');
  static final RegExp _hex = RegExp(r'^[0-9a-fA-F]{3,8}$');

  /// Retire le balisage {c:#xxxxxx} puis le HTML.
  static String sanitize(String? input, {int maxLength = 200}) {
    if (input == null || input.trim().isEmpty) return '';
    var s = input.replaceAll(_markup, '');
    final doc = html_parser.parse(s);
    s = doc.body?.text ?? s;
    s = s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final t = url.trim();
    if (!t.startsWith('http://') && !t.startsWith('https://')) return null;
    return t.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  /// Un hashtag valide : >= 3 caractères, pas un code couleur, pas que des chiffres.
  static bool isValidTag(String tag) {
    if (tag.length < 3) return false;
    if (RegExp(r'^\d+$').hasMatch(tag)) return false;
    if (_hex.hasMatch(tag) && RegExp(r'\d').hasMatch(tag)) return false;
    return true;
  }
}

// ============================================================================
// HELPERS
// ============================================================================
String _formatCount(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
  return '$count';
}

String? _firstUrl(dynamic v) {
  if (v == null) return null;
  if (v is String) return _DiscoverValidators.sanitizeUrl(v);
  if (v is List) {
    for (final e in v) {
      final u = _DiscoverValidators.sanitizeUrl(e?.toString());
      if (u != null) return u;
    }
  }
  return null;
}

String? _postImage(Map<String, dynamic> p) {
  return _firstUrl(p['media_url']) ?? _firstUrl(p['media_urls']) ?? _firstUrl(p['image_urls']);
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

// ============================================================================
// AVATAR
// ============================================================================
class _Avatar extends StatelessWidget {
  final String? url;
  final String name;
  final double size;
  const _Avatar({required this.url, required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ThixPolicy.primary.withValues(alpha: 0.85), const Color(0xFF6366F1)],
        ),
      ),
      child: Text(
        _initials(name),
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.36),
      ),
    );
    if (url == null) return fallback;
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: CachedNetworkImage(
          imageUrl: url!,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: ThixPolicy.surfaceSoft),
          errorWidget: (_, __, ___) => fallback,
        ),
      ),
    );
  }
}

// ============================================================================
// COMPOSANT PRINCIPAL
// ============================================================================
class DiscoverTab extends StatefulWidget {
  const DiscoverTab({super.key});
  @override
  State<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<DiscoverTab> with SingleTickerProviderStateMixin {
  late TabController _tab;

  List<Map<String, dynamic>> _tags = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _posts = [];
  final Set<String> _following = {};
  final Set<String> _followBusy = {};

  bool _loading = true;
  String? _error;

  final _search = TextEditingController();
  String _query = '';
  Timer? _searchDebounce;

  // Filtre onglet Populaires : all | week | month
  String _popFilter = 'all';

  static const Duration _requestTimeout = Duration(seconds: 12);

  String get _myId => Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() {
      if (_tab.indexIsChanging) HapticFeedback.selectionClick();
    });
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    _search.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────
  // CHARGEMENT (chaque section est indépendante)
  // ──────────────────────────────────────────────────────────────
  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final supa = Supabase.instance.client;
    List<Map<String, dynamic>> posts = [];
    List<Map<String, dynamic>> users = [];
    List<Map<String, dynamic>> tags = [];
    int failures = 0;

    // 1. Publications (sert aux Populaires ET aux Tendances)
    try {
      final res = await supa
          .from('posts_view')
          .select('*')
          .eq('is_public', true)
          .order('likes_count', ascending: false)
          .limit(300)
          .timeout(_requestTimeout);
      posts = (res as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((p) => p['is_hidden'] != true && p['community_id'] == null)
          .toList();
    } catch (e) {
      failures++;
      debugPrint('[Discover] posts error: $e');
    }

    // Hashtags depuis les posts
    final counter = <String, int>{};
    final reg = RegExp(r'#([\p{L}\p{N}_]+)', unicode: true);
    for (final p in posts) {
      final c = _DiscoverValidators.sanitize(p['content']?.toString(), maxLength: 5000);
      final seen = <String>{};
      for (final m in reg.allMatches(c)) {
        final t = m.group(1)!.toLowerCase();
        if (!_DiscoverValidators.isValidTag(t)) continue;
        if (seen.add(t)) counter[t] = (counter[t] ?? 0) + 1;
      }
    }
    final sorted = counter.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    tags = sorted.take(20).map((e) => {'tag': e.key, 'count': e.value}).toList();

    // 2. Personnes
    try {
      final res = await supa
          .from('profiles')
          .select('id, display_name, photo_url, avatar_url, profession, followers_count, created_at, is_verified')
          .order('followers_count', ascending: false, nullsFirst: false)
          .limit(60)
          .timeout(_requestTimeout);
      users = (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('[Discover] profiles fallback: $e');
      try {
        final res = await supa
            .from('profiles')
            .select('id, display_name, avatar_url, profession')
            .limit(60)
            .timeout(_requestTimeout);
        users = (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (e2) {
        failures++;
        debugPrint('[Discover] profiles error: $e2');
      }
    }

    // 3. Mes abonnements (pour le bouton Suivre)
    final following = <String>{};
    if (_myId.isNotEmpty) {
      try {
        final res = await supa
            .from('follows')
            .select('following_id')
            .eq('follower_id', _myId)
            .timeout(_requestTimeout);
        for (final r in (res as List)) {
          following.add('${r['following_id']}');
        }
      } catch (e) {
        debugPrint('[Discover] follows error: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      _posts = posts;
      _users = users;
      _tags = tags;
      _following
        ..clear()
        ..addAll(following);
      _error = failures >= 2 ? 'load_failed' : null;
      _loading = false;
    });
  }

  // ──────────────────────────────────────────────────────────────
  // SUIVRE / NE PLUS SUIVRE
  // ──────────────────────────────────────────────────────────────
  Future<void> _toggleFollow(String userId) async {
    if (_myId.isEmpty || userId.isEmpty || userId == _myId) return;
    if (_followBusy.contains(userId)) return;
    HapticFeedback.selectionClick();

    final wasFollowing = _following.contains(userId);
    setState(() {
      _followBusy.add(userId);
      if (wasFollowing) {
        _following.remove(userId);
      } else {
        _following.add(userId);
      }
    });

    try {
      final supa = Supabase.instance.client;
      if (wasFollowing) {
        await supa
            .from('follows')
            .delete()
            .eq('follower_id', _myId)
            .eq('following_id', userId)
            .timeout(_requestTimeout);
      } else {
        await supa.from('follows').upsert({
          'follower_id': _myId,
          'following_id': userId,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'follower_id,following_id').timeout(_requestTimeout);
      }
    } catch (e) {
      debugPrint('[Discover] follow error: $e');
      if (mounted) {
        setState(() {
          if (wasFollowing) {
            _following.add(userId);
          } else {
            _following.remove(userId);
          }
        });
      }
    } finally {
      if (mounted) setState(() => _followBusy.remove(userId));
    }
  }

  // ──────────────────────────────────────────────────────────────
  // RECHERCHE
  // ──────────────────────────────────────────────────────────────
  void _onSearchSubmitted(String v) {
    final query = v.trim();
    if (query.isEmpty) return;
    HapticFeedback.lightImpact();
    if (query.startsWith('#')) {
      final hashtag = query.replaceAll('#', '').trim();
      context.push('/network/hashtag/$hashtag');
    } else {
      context.push('/network/search?q=${Uri.encodeComponent(query)}');
    }
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = v.trim().toLowerCase().replaceAll('#', ''));
    });
    setState(() {}); // met à jour l'icône "effacer"
  }

  // ──────────────────────────────────────────────────────────────
  // DONNÉES FILTRÉES
  // ──────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _filteredPosts {
    final now = DateTime.now().toUtc();
    Duration? maxAge;
    if (_popFilter == 'week') maxAge = const Duration(days: 7);
    if (_popFilter == 'month') maxAge = const Duration(days: 30);

    final list = _posts.where((p) {
      if (maxAge != null) {
        final d = DateTime.tryParse('${p['created_at']}');
        if (d == null || now.difference(d.toUtc()) > maxAge) return false;
      }
      if (_query.isNotEmpty) {
        final content = _DiscoverValidators.sanitize(p['content']?.toString(), maxLength: 500).toLowerCase();
        final author = (p['author_name'] ?? p['profiles']?['display_name'] ?? '').toString().toLowerCase();
        if (!content.contains(_query) && !author.contains(_query)) return false;
      }
      return true;
    }).toList();

    list.sort((a, b) {
      final la = (a['likes_count'] as num?)?.toInt() ?? 0;
      final lb = (b['likes_count'] as num?)?.toInt() ?? 0;
      return lb.compareTo(la);
    });
    return list.take(40).toList();
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_query.isEmpty) return _users;
    return _users.where((u) {
      final n = (u['display_name'] ?? '').toString().toLowerCase();
      final p = (u['profession'] ?? '').toString().toLowerCase();
      return n.contains(_query) || p.contains(_query);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredTags {
    if (_query.isEmpty) return _tags;
    return _tags.where((t) => '${t['tag']}'.contains(_query)).toList();
  }

  // ──────────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Découvrir',
          style: TextStyle(color: ThixPolicy.textMain, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        bottom: TabBar(
          controller: _tab,
          labelColor: ThixPolicy.primary,
          unselectedLabelColor: ThixPolicy.textSecondary,
          indicatorColor: ThixPolicy.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.local_fire_department_rounded, size: 20), text: 'Populaires'),
            Tab(icon: Icon(Icons.trending_up_rounded, size: 20), text: 'Tendances'),
            Tab(icon: Icon(Icons.people_rounded, size: 20), text: 'Personnes'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _loading
                ? _buildSkeleton()
                : _error != null && _users.isEmpty && _posts.isEmpty
                    ? _buildErrorState()
                    : TabBarView(
                        controller: _tab,
                        children: [_popularTab(), _trendTab(), _peopleTab()],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: TextField(
        controller: _search,
        onSubmitted: _onSearchSubmitted,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Rechercher #hashtag ou personne',
          hintStyle: const TextStyle(color: ThixPolicy.textSecondary, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: ThixPolicy.primary, size: 22),
          suffixIcon: _search.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: ThixPolicy.textSecondary, size: 20),
                  onPressed: () {
                    _search.clear();
                    setState(() => _query = '');
                  },
                )
              : null,
          filled: true,
          fillColor: ThixPolicy.surfaceSoft,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // SKELETONS
  // ──────────────────────────────────────────────────────────────
  Widget _buildSkeleton() {
    return TabBarView(
      controller: _tab,
      children: [
        _skeletonGrid(0.72),
        _skeletonList(),
        _skeletonGrid(0.8),
      ],
    );
  }

  Widget _skeletonGrid(double ratio) {
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: ratio,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(ThixPolicy.rMd)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 10, width: 80, color: Colors.grey.shade200),
                  const SizedBox(height: 6),
                  Container(height: 12, width: double.infinity, color: Colors.grey.shade200),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _skeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 8,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ThixPolicy.danger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 64, color: ThixPolicy.danger),
            ),
            const SizedBox(height: 24),
            const Text(
              'Erreur de chargement',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ThixPolicy.textMain),
            ),
            const SizedBox(height: 8),
            const Text(
              'Impossible de charger les données. Vérifiez votre connexion.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: ThixPolicy.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // ONGLET 1 : POPULAIRES (cartes cliquables)
  // ══════════════════════════════════════════════════════════════
  Widget _popularTab() {
    final posts = _filteredPosts;

    return RefreshIndicator(
      color: ThixPolicy.primary,
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildPopularFilters()),
          if (posts.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(
                icon: Icons.local_fire_department_outlined,
                title: 'Aucune publication',
                subtitle: 'Aucun résultat pour ce filtre.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _postCard(posts[i], i),
                  childCount: posts.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPopularFilters() {
    final filters = {'all': 'Tout', 'week': 'Cette semaine', 'month': 'Ce mois'};
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.entries.map((e) {
            final active = _popFilter == e.key;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  e.value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : ThixPolicy.textSecondary,
                  ),
                ),
                selected: active,
                showCheckmark: false,
                selectedColor: ThixPolicy.textMain,
                backgroundColor: Colors.white,
                side: BorderSide(color: active ? ThixPolicy.textMain : ThixPolicy.border.withValues(alpha: 0.5)),
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  setState(() => _popFilter = e.key);
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _postCard(Map<String, dynamic> p, int index) {
    final img = _postImage(p);
    final content = _DiscoverValidators.sanitize(p['content']?.toString(), maxLength: 160);
    final authorName = _DiscoverValidators.sanitize(
      (p['author_name'] ?? p['profiles']?['display_name'] ?? '').toString(),
      maxLength: 50,
    );
    final authorAvatar = _DiscoverValidators.sanitizeUrl(
      (p['author_avatar'] ?? p['profiles']?['avatar_url'] ?? p['profiles']?['photo_url'])?.toString(),
    );
    final likes = (p['likes_count'] as num?)?.toInt() ?? 0;
    final comments = (p['comments_count'] as num?)?.toInt() ?? 0;
    final postId = p['id']?.toString() ?? '';

    // Fond dégradé avec extrait du texte (sans image ou image en erreur)
    Widget textCover() => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: index.isEven
                  ? [const Color(0xFF3B4A6B), const Color(0xFF1E293B)]
                  : [const Color(0xFF4F46E5), const Color(0xFF312E81)],
            ),
          ),
          child: Text(
            content.isEmpty ? 'Publication' : content,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13, height: 1.3),
          ),
        );

    return GestureDetector(
      onTap: () {
        if (postId.isEmpty) return;
        HapticFeedback.selectionClick();
        context.push('/network/post/$postId');
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          border: Border.all(color: ThixPolicy.border.withValues(alpha: 0.3)),
          boxShadow: ThixPolicy.shadowSoft(),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (img != null)
                    CachedNetworkImage(
                      imageUrl: img,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: ThixPolicy.surfaceSoft),
                      errorWidget: (_, __, ___) => textCover(),
                    )
                  else
                    textCover(),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.favorite, size: 11, color: Colors.redAccent),
                          const SizedBox(width: 3),
                          Text(
                            _formatCount(likes),
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Avatar(url: authorAvatar, name: authorName.isEmpty ? '?' : authorName, size: 20),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            authorName.isEmpty ? 'Membre THIX' : authorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ThixPolicy.textMain),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Text(
                        content,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: ThixPolicy.textSecondary, height: 1.3),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded, size: 12, color: ThixPolicy.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          _formatCount(comments),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ThixPolicy.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // ONGLET 2 : TENDANCES (cartes classées)
  // ══════════════════════════════════════════════════════════════
  Widget _trendTab() {
    final tags = _filteredTags;
    return RefreshIndicator(
      color: ThixPolicy.primary,
      onRefresh: _load,
      child: tags.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: 400,
                  child: _buildEmptyState(
                    icon: Icons.tag_rounded,
                    title: 'Aucune tendance',
                    subtitle: 'Les hashtags populaires apparaîtront ici.',
                  ),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: tags.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12, top: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [ThixPolicy.primary, Color(0xFF6366F1)]),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.trending_up_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Hashtags tendances',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: ThixPolicy.textMain),
                        ),
                      ],
                    ),
                  );
                }
                final rank = i;
                final t = tags[i - 1];
                final tag = _DiscoverValidators.sanitize(t['tag']?.toString(), maxLength: 50);
                final count = t['count'] as int? ?? 0;
                final top = rank <= 3;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                    border: Border.all(color: ThixPolicy.border.withValues(alpha: 0.3)),
                    boxShadow: ThixPolicy.shadowSoft(),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context.push('/network/hashtag/$tag');
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: top ? ThixPolicy.primary : ThixPolicy.surfaceSoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$rank',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: top ? Colors.white : ThixPolicy.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '#$tag',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: ThixPolicy.textMain),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_formatCount(count)} publication${count > 1 ? 's' : ''}',
                                    style: const TextStyle(fontSize: 12, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: ThixPolicy.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // ONGLET 3 : PERSONNES (grille de cartes + nouveaux membres)
  // ══════════════════════════════════════════════════════════════
  List<Map<String, dynamic>> get _newMembers {
    final list = _users.where((u) => u['created_at'] != null && '${u['id']}' != _myId).toList();
    list.sort((a, b) => '${b['created_at']}'.compareTo('${a['created_at']}'));
    return list.take(10).toList();
  }

  Widget _peopleTab() {
    final users = _filteredUsers;
    final newMembers = _query.isEmpty ? _newMembers : <Map<String, dynamic>>[];

    return RefreshIndicator(
      color: ThixPolicy.primary,
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (newMembers.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                child: Row(
                  children: [
                    const Icon(Icons.fiber_new_rounded, color: ThixPolicy.primary, size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'Nouveaux membres',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: ThixPolicy.textMain),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: newMembers.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (_, i) {
                    final u = newMembers[i];
                    final name = _DiscoverValidators.sanitize(u['display_name']?.toString() ?? 'Membre', maxLength: 40);
                    final avatar = _DiscoverValidators.sanitizeUrl(
                      (u['photo_url'] ?? u['avatar_url'])?.toString(),
                    );
                    final id = u['id']?.toString() ?? '';
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context.push('/network/profile/$id');
                      },
                      child: SizedBox(
                        width: 64,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: ThixPolicy.primary, width: 2),
                              ),
                              child: _Avatar(url: avatar, name: name, size: 52),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              name.split(' ').first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ThixPolicy.textMain),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
              child: Row(
                children: [
                  const Icon(Icons.people_alt_rounded, color: ThixPolicy.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    _query.isEmpty ? 'Membres THIX' : 'Résultats (${users.length})',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: ThixPolicy.textMain),
                  ),
                ],
              ),
            ),
          ),
          if (users.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(
                icon: Icons.people_outline_rounded,
                title: 'Aucune personne',
                subtitle: 'Les membres THIX apparaîtront ici.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.78,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _personCard(users[i]),
                  childCount: users.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _personCard(Map<String, dynamic> u) {
    final userId = u['id']?.toString() ?? '';
    final name = _DiscoverValidators.sanitize(u['display_name']?.toString() ?? 'Utilisateur', maxLength: 60);
    final profession = _DiscoverValidators.sanitize(
      (u['profession']?.toString().trim().isNotEmpty ?? false) ? u['profession'].toString() : 'Membre THIX',
      maxLength: 60,
    );
    final avatar = _DiscoverValidators.sanitizeUrl((u['photo_url'] ?? u['avatar_url'])?.toString());
    final followers = (u['followers_count'] as num?)?.toInt();
    final verified = u['is_verified'] == true;
    final isMe = userId == _myId;
    final isFollowing = _following.contains(userId);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/network/profile/$userId');
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ThixPolicy.rLg),
          border: Border.all(color: ThixPolicy.border.withValues(alpha: 0.3)),
          boxShadow: ThixPolicy.shadowSoft(),
        ),
        child: Column(
          children: [
            _Avatar(url: avatar, name: name, size: 68),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: ThixPolicy.textMain),
                  ),
                ),
                if (verified) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.verified_rounded, size: 15, color: ThixPolicy.primary),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              profession,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            if (followers != null)
              Text(
                '${_formatCount(followers)} abonné${followers > 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 11, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600),
              ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 34,
              child: isMe
                  ? OutlinedButton(
                      onPressed: () => context.push('/network/profile/$userId'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ThixPolicy.textMain,
                        side: BorderSide(color: ThixPolicy.border.withValues(alpha: 0.6)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
                      ),
                      child: const Text('Mon profil', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    )
                  : isFollowing
                      ? OutlinedButton(
                          onPressed: () => _toggleFollow(userId),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ThixPolicy.textMain,
                            side: BorderSide(color: ThixPolicy.border.withValues(alpha: 0.6)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
                          ),
                          child: const Text('Suivi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        )
                      : ElevatedButton(
                          onPressed: () => _toggleFollow(userId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ThixPolicy.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
                          ),
                          child: const Text('Suivre', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // ÉTAT VIDE
  // ──────────────────────────────────────────────────────────────
  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ThixPolicy.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 56, color: ThixPolicy.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ThixPolicy.textMain),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: ThixPolicy.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Actualiser'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ThixPolicy.primary,
                side: const BorderSide(color: ThixPolicy.primary),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
