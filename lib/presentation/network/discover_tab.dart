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
// VALIDATEURS
// ============================================================================
class _DiscoverValidators {
  _DiscoverValidators._();

  static String sanitize(String? input, {int maxLength = 200}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var sanitized = doc.body?.text ?? input;
    sanitized = sanitized
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
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
// HELPERS
// ============================================================================
String _formatCount(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
  return '$count';
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
  List<Map<String, dynamic>> _tags = [], _users = [], _posts = [];
  bool _loading = true;
  String? _error;
  final _search = TextEditingController();
  Timer? _searchDebounce;

  static const Duration _requestTimeout = Duration(seconds: 10);

  // Fallback hashtags
  final List<Map<String, dynamic>> _defaultTags = [
    {'tag': 'THIXCentral', 'count': 120},
    {'tag': 'Innovation', 'count': 85},
    {'tag': 'Technologie', 'count': 64},
    {'tag': 'Entrepreneuriat', 'count': 52},
    {'tag': 'Education', 'count': 41},
    {'tag': 'Networking', 'count': 30},
    {'tag': 'Business', 'count': 28},
    {'tag': 'Digital', 'count': 25},
  ];

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

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final supa = Supabase.instance.client;

      // 1. Hashtags Tendances (depuis posts_view)
      final rawPosts = await supa
          .from('posts_view')
          .select('content')
          .eq('is_public', true)
          .limit(200)
          .timeout(_requestTimeout);

      final Map<String, int> counter = {};
      final reg = RegExp(r'#(\w+)');
      for (final r in (rawPosts as List)) {
        final c = (r['content'] ?? '') as String;
        for (final m in reg.allMatches(c)) {
          final t = m.group(1)!.toLowerCase();
          counter[t] = (counter[t] ?? 0) + 1;
        }
      }
      final sortedTags = counter.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

      // 2. Personnes (Utilisateurs)
      List users = [];
      try {
        users = await supa
            .from('profiles')
            .select('id, display_name, photo_url, avatar_url, profession, followers_count')
            .order('followers_count', ascending: false)
            .limit(20)
            .timeout(_requestTimeout);
      } catch (e) {
        debugPrint('[Discover] Fallback profiles query: $e');
        users = await supa
            .from('profiles')
            .select('id, display_name, photo_url, avatar_url, profession')
            .limit(20)
            .timeout(_requestTimeout);
      }

      // 3. Publications Populaires (depuis posts_view)
      final pop = await supa
          .from('posts_view')
          .select('id, content, media_url, likes_count, created_at, profiles(display_name, avatar_url, photo_url)')
          .eq('is_public', true)
          .order('likes_count', ascending: false)
          .limit(20)
          .timeout(_requestTimeout);

      if (!mounted) return;

      setState(() {
        final fetchedTags = sortedTags.map((e) => {'tag': e.key, 'count': e.value}).toList();
        _tags = fetchedTags.isEmpty ? _defaultTags : fetchedTags.take(15).toList();
        _users = (users as List).cast<Map<String, dynamic>>();
        _posts = (pop as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      debugPrint('[Discover] Load error: $e');
      if (mounted) {
        setState(() {
          _tags = _defaultTags;
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

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
            Tab(icon: Icon(Icons.trending_up_rounded, size: 20), text: 'Tendances'),
            Tab(icon: Icon(Icons.people_rounded, size: 20), text: 'Personnes'),
            Tab(icon: Icon(Icons.local_fire_department_rounded, size: 20), text: 'Populaires'),
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
                        children: [_trendTab(), _peopleTab(), _popularTab()],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _search,
        onSubmitted: _onSearchSubmitted,
        onChanged: (v) {
          _searchDebounce?.cancel();
          _searchDebounce = Timer(const Duration(milliseconds: 500), () {
            if (v.trim().length >= 3) {
              // Auto-search après 500ms
            }
          });
        },
        decoration: InputDecoration(
          hintText: 'Rechercher #hashtag ou personne',
          hintStyle: const TextStyle(color: ThixPolicy.textSecondary, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: ThixPolicy.primary, size: 22),
          suffixIcon: _search.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: ThixPolicy.textSecondary, size: 20),
                  onPressed: () {
                    _search.clear();
                    setState(() {});
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

  Widget _buildSkeleton() {
    return TabBarView(
      controller: _tab,
      children: [
        _buildSkeletonTrend(),
        _buildSkeletonPeople(),
        _buildSkeletonPopular(),
      ],
    );
  }

  Widget _buildSkeletonTrend() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(height: 20, width: 150, color: Colors.grey.shade200),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(
            10,
            (i) => Container(
              width: 100 + (i % 3) * 20,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonPeople() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 10,
      itemBuilder: (_, i) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
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
            Container(width: 70, height: 32, color: Colors.grey.shade200),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonPopular() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.78,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: 6,
      itemBuilder: (_, i) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 110,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(ThixPolicy.rMd)),
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
                color: ThixPolicy.danger.withOpacity(0.1),
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
            Text(
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

  Widget _trendTab() {
    return RefreshIndicator(
      color: ThixPolicy.primary,
      onRefresh: _load,
      child: _tags.isEmpty
          ? _buildEmptyState(
              icon: Icons.tag_rounded,
              title: 'Aucune tendance',
              subtitle: 'Les hashtags populaires apparaîtront ici.',
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [ThixPolicy.primary, Color(0xFF6366F1)],
                        ),
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
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tags.map((t) {
                    final tag = _DiscoverValidators.sanitize(t['tag']?.toString(), maxLength: 50);
                    final count = t['count'] as int? ?? 0;
                    return ActionChip(
                      backgroundColor: Colors.white,
                      side: BorderSide(color: ThixPolicy.border.withOpacity(0.5)),
                      elevation: 1,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      label: Text(
                        '#$tag • ${_formatCount(count)}',
                        style: const TextStyle(
                          color: ThixPolicy.textMain,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        context.push('/network/hashtag/$tag');
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
    );
  }

  Widget _peopleTab() {
    return RefreshIndicator(
      color: ThixPolicy.primary,
      onRefresh: _load,
      child: _users.isEmpty
          ? _buildEmptyState(
              icon: Icons.people_outline_rounded,
              title: 'Aucune personne',
              subtitle: 'Les membres THIX apparaîtront ici.',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _users.length,
              itemBuilder: (_, i) {
                final u = _users[i];
                final avatar = _DiscoverValidators.sanitizeUrl(
                  u['photo_url']?.toString() ?? u['avatar_url']?.toString(),
                );
                final name = _DiscoverValidators.sanitize(u['display_name']?.toString() ?? 'Utilisateur', maxLength: 100);
                final profession = _DiscoverValidators.sanitize(u['profession']?.toString() ?? 'Membre THIX', maxLength: 100);
                final userId = u['id']?.toString() ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                    border: Border.all(color: ThixPolicy.border.withOpacity(0.3)),
                    boxShadow: ThixPolicy.shadowSoft(),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context.push('/network/profile/$userId');
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 50,
                                height: 50,
                                color: ThixPolicy.surfaceSoft,
                                child: avatar != null
                                    ? CachedNetworkImage(
                                        imageUrl: avatar,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Container(color: ThixPolicy.surfaceSoft),
                                        errorWidget: (_, __, ___) => const Icon(Icons.person, color: ThixPolicy.textSecondary),
                                      )
                                    : const Icon(Icons.person, color: ThixPolicy.textSecondary),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: ThixPolicy.textMain),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    profession,
                                    style: const TextStyle(fontSize: 12, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                context.push('/network/profile/$userId');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ThixPolicy.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
                              ),
                              child: const Text('Voir', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
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

  Widget _popularTab() {
    return RefreshIndicator(
      color: ThixPolicy.primary,
      onRefresh: _load,
      child: _posts.isEmpty
          ? _buildEmptyState(
              icon: Icons.local_fire_department_outlined,
              title: 'Aucune publication populaire',
              subtitle: 'Les posts les plus likés apparaîtront ici.',
            )
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.78,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _posts.length,
              itemBuilder: (_, i) {
                final p = _posts[i];
                final img = _DiscoverValidators.sanitizeUrl(p['media_url']?.toString());
                final content = _DiscoverValidators.sanitize(p['content']?.toString() ?? '', maxLength: 200);
                final authorName = _DiscoverValidators.sanitize(
                  p['profiles']?['display_name']?.toString() ?? '',
                  maxLength: 50,
                );
                final likesCount = (p['likes_count'] as num?)?.toInt() ?? 0;
                final postId = p['id']?.toString() ?? '';

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    context.push('/network/post/$postId');
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                      border: Border.all(color: ThixPolicy.border.withOpacity(0.3)),
                      boxShadow: ThixPolicy.shadowSoft(),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (img != null)
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(ThixPolicy.rMd)),
                            child: CachedNetworkImage(
                              imageUrl: img,
                              height: 110,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                height: 110,
                                color: ThixPolicy.surfaceSoft,
                                child: const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary),
                                  ),
                                ),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                height: 110,
                                color: ThixPolicy.surfaceSoft,
                                child: const Icon(Icons.image, color: ThixPolicy.textMuted),
                              ),
                            ),
                          )
                        else
                          Container(
                            height: 110,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [ThixPolicy.primary.withOpacity(0.2), ThixPolicy.primary.withOpacity(0.1)],
                              ),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(ThixPolicy.rMd)),
                            ),
                            child: const Center(child: Icon(Icons.article_rounded, size: 40, color: ThixPolicy.primary)),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (authorName.isNotEmpty)
                                Text(
                                  authorName,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ThixPolicy.textMain),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (authorName.isNotEmpty) const SizedBox(height: 4),
                              if (content.isNotEmpty)
                                Text(
                                  content,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: ThixPolicy.textSecondary, height: 1.3),
                                ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.favorite, size: 12, color: Colors.red),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatCount(likesCount),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ThixPolicy.textSecondary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

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
                color: ThixPolicy.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: ThixPolicy.primary),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ThixPolicy.textMain),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: ThixPolicy.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 24),
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
