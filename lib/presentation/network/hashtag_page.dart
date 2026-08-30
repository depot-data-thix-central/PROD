// lib/presentation/network/hashtag_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/models/network_post.dart';
import 'package:thix_id/presentation/network/widgets/post_card.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';

// ============================================================================
// CONSTANTES & VALIDATEURS
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 12);
const int _kMaxTagLength = 50;
const int _kPostLimit = 50;

class _HashtagValidators {
  _HashtagValidators._();

  /// Un hashtag valide : lettres, chiffres, underscores, 1-50 caractères.
  /// Rejette tout caractère dangereux (SQL injection, XSS, path traversal).
  static final RegExp _validTagRegex = RegExp(r'^[a-zA-Z0-9_]{1,50}$');

  static bool isValidTag(String? tag) {
    if (tag == null || tag.isEmpty) return false;
    return _validTagRegex.hasMatch(tag);
  }

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
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) return null;
    return trimmed.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }
}

// ============================================================================
// ÉTAT DU FOLLOW
// ============================================================================
class HashtagFollowState {
  final bool isFollowing;
  final bool isLoading;
  const HashtagFollowState({this.isFollowing = false, this.isLoading = false});

  HashtagFollowState copyWith({bool? isFollowing, bool? isLoading}) {
    return HashtagFollowState(
      isFollowing: isFollowing ?? this.isFollowing,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class HashtagFollowNotifier extends StateNotifier<HashtagFollowState> {
  final String tag;
  HashtagFollowNotifier(this.tag) : super(const HashtagFollowState()) {
    _check();
  }

  Future<void> _check() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final r = await Supabase.instance.client
          .from('hashtag_follows')
          .select('hashtag')
          .eq('user_id', uid)
          .eq('hashtag', tag)
          .maybeSingle()
          .timeout(_kRequestTimeout);
      state = state.copyWith(isFollowing: r != null);
    } catch (e) {
      debugPrint('[Hashtag] ⚠️ Check follow error: $e');
    }
  }

  Future<void> toggle() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null || state.isLoading) return;

    final wasFollowing = state.isFollowing;
    HapticFeedback.mediumImpact();
    state = state.copyWith(isLoading: true, isFollowing: !wasFollowing);

    try {
      if (wasFollowing) {
        await Supabase.instance.client
            .from('hashtag_follows')
            .delete()
            .eq('user_id', uid)
            .eq('hashtag', tag)
            .timeout(_kRequestTimeout);
        debugPrint('[Hashtag] ✓ Unfollowed #$tag');
      } else {
        await Supabase.instance.client
            .from('hashtag_follows')
            .insert({'user_id': uid, 'hashtag': tag})
            .timeout(_kRequestTimeout);
        debugPrint('[Hashtag] ✓ Followed #$tag');
      }
    } catch (e) {
      debugPrint('[Hashtag] ❌ Toggle error: $e');
      state = state.copyWith(isFollowing: wasFollowing); // Rollback
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}

final hashtagFollowProvider = StateNotifierProvider.autoDispose
    .family<HashtagFollowNotifier, HashtagFollowState, String>(
  (ref, tag) => HashtagFollowNotifier(tag),
);

// ============================================================================
// SORT OPTIONS
// ============================================================================
enum _HashtagSort { recent, popular }

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class HashtagPage extends ConsumerStatefulWidget {
  final String tag;
  const HashtagPage({super.key, required this.tag});

  @override
  ConsumerState<HashtagPage> createState() => _HashtagPageState();
}

class _HashtagPageState extends ConsumerState<HashtagPage> {
  List<NetworkPost> _posts = [];
  bool _loading = true;
  _HashtagSort _sort = _HashtagSort.recent;
  bool _isValidTag = true;

  @override
  void initState() {
    super.initState();
    _isValidTag = _HashtagValidators.isValidTag(widget.tag);
    debugPrint('[Hashtag] 🏷️ Opened #${widget.tag} (valid=$_isValidTag)');
    if (_isValidTag) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final safeTag = widget.tag;
      debugPrint('[Hashtag] 📥 Loading posts (sort=${_sort.name})');

      final query = Supabase.instance.client
          .from('posts_view')
          .select('*')
          .eq('is_public', true)
          .ilike('content', '%#$safeTag%')
          .limit(_kPostLimit);

      final res = _sort == _HashtagSort.popular
          ? await query.order('likes_count', ascending: false).timeout(_kRequestTimeout)
          : await query.order('created_at', ascending: false).timeout(_kRequestTimeout);

      final posts = (res as List).map((e) => _mapPost(e as Map<String, dynamic>)).toList();

      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
      });
      debugPrint('[Hashtag] ✓ Loaded ${posts.length} posts');
    } catch (e) {
      debugPrint('[Hashtag] ❌ Load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  NetworkPost _mapPost(Map<String, dynamic> row) {
    return NetworkPost.fromJson({
      ...row,
      'author_name': row['author_name'] ?? 'Utilisateur THIX',
      'author_avatar': row['author_avatar'],
      'media_urls': _extractMediaUrls(row),
    });
  }

  List<String> _extractMediaUrls(Map<String, dynamic> row) {
    if (row['media_urls'] != null) return List<String>.from(row['media_urls'] as List);
    if (row['media_url'] != null && row['media_url'].toString().isNotEmpty) return [row['media_url'].toString()];
    if (row['image_urls'] != null) return List<String>.from(row['image_urls'] as List);
    if (row['image_url'] != null && row['image_url'].toString().isNotEmpty) return [row['image_url'].toString()];
    return [];
  }

  void _setSort(_HashtagSort s) {
    if (_sort == s) return;
    HapticFeedback.selectionClick();
    setState(() => _sort = s);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authControllerProvider).value?.id ?? '';
    final safeTag = _HashtagValidators.sanitize(widget.tag, maxLength: _kMaxTagLength);
    final followState = _isValidTag ? ref.watch(hashtagFollowProvider(widget.tag)) : null;

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      body: NestedScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(safeTag, followState),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverFilterBar(
              sort: _sort,
              onSortChanged: _setSort,
              postCount: _posts.length,
            ),
          ),
        ],
        body: _buildBody(currentUserId),
      ),
    );
  }

  Widget _buildSliverAppBar(String safeTag, HashtagFollowState? followState) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: ThixPolicy.inkDeep,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () {
          HapticFeedback.selectionClick();
          Navigator.pop(context);
        },
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [ThixPolicy.primary, ThixPolicy.inkDeep],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Overlay pattern
              Opacity(
                opacity: 0.08,
                child: CustomPaint(
                  painter: _HashPatternPainter(),
                  child: const SizedBox.expand(),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: const Icon(Icons.tag_rounded, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '#$safeTag',
                                  style: ThixPolicy.h1Style.copyWith(
                                    color: Colors.white,
                                    fontWeight: ThixPolicy.bold,
                                    fontSize: 28,
                                    letterSpacing: -0.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isValidTag
                                      ? '${_posts.length} publication${_posts.length > 1 ? 's' : ''}'
                                      : 'Hashtag invalide',
                                  style: ThixPolicy.captionStyle.copyWith(color: Colors.white70),
                                ),
                              ],
                            ),
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
      ),
      actions: [
        if (_isValidTag && followState != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: _buildFollowButton(followState),
          ),
      ],
    );
  }

  Widget _buildFollowButton(HashtagFollowState state) {
    final isFollowing = state.isFollowing;

    return GestureDetector(
      onTap: state.isLoading
          ? null
          : () => ref.read(hashtagFollowProvider(widget.tag).notifier).toggle(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isFollowing ? Colors.white.withOpacity(0.15) : ThixPolicy.gold,
          borderRadius: BorderRadius.circular(ThixPolicy.rFull),
          border: isFollowing ? Border.all(color: Colors.white.withOpacity(0.3)) : null,
        ),
        child: state.isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isFollowing ? Icons.check_rounded : Icons.add_rounded,
                    color: isFollowing ? Colors.white : ThixPolicy.inkDeep,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isFollowing ? 'Suivi' : 'Suivre',
                    style: ThixPolicy.labelStyle.copyWith(
                      color: isFollowing ? Colors.white : ThixPolicy.inkDeep,
                      fontWeight: ThixPolicy.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildBody(String currentUserId) {
    if (!_isValidTag) {
      return _buildInvalidTagState();
    }
    if (_loading) return _buildSkeleton();
    if (_posts.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      color: ThixPolicy.primary,
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
        itemCount: _posts.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PostCard(
            post: _posts[i],
            currentProfileId: currentUserId,
            onTap: () {
              HapticFeedback.selectionClick();
              context.push('/network/post/${_posts[i].id}');
            },
            onRefresh: _load,
          ),
        ),
      ),
    );
  }

  Widget _buildInvalidTagState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ThixPolicy.danger.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 56, color: ThixPolicy.danger),
            ),
            const SizedBox(height: 20),
            Text('Hashtag invalide', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
            const SizedBox(height: 8),
            Text(
              'Ce hashtag contient des caractères non autorisés.\nSeuls les lettres, chiffres et underscores sont acceptés.',
              textAlign: TextAlign.center,
              style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              label: const Text('Retour'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      color: ThixPolicy.primary,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Center(
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
                      child: const Icon(Icons.tag_rounded, size: 64, color: ThixPolicy.primary),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Aucune publication',
                      style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Personne n\'a encore utilisé #${_HashtagValidators.sanitize(widget.tag, maxLength: 30)}.\nSoyez le premier à publier !',
                      textAlign: TextAlign.center,
                      style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => context.go('/network/compose'),
                      icon: const Icon(Icons.edit_rounded, color: Colors.white),
                      label: const Text('Créer une publication'),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 14, width: 120, color: Colors.grey.shade200),
                      const SizedBox(height: 6),
                      Container(height: 10, width: 80, color: Colors.grey.shade200),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(height: 14, width: double.infinity, color: Colors.grey.shade200),
            const SizedBox(height: 6),
            Container(height: 14, width: double.infinity * 0.7, color: Colors.grey.shade200),
            const SizedBox(height: 12),
            Container(height: 180, width: double.infinity, color: Colors.grey.shade200, decoration: BoxDecoration(borderRadius: BorderRadius.circular(ThixPolicy.rMd))),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// BARRE DE FILTRES (PINNED)
// ============================================================================
class _SliverFilterBar extends SliverPersistentHeaderDelegate {
  final _HashtagSort sort;
  final void Function(_HashtagSort) onSortChanged;
  final int postCount;

  _SliverFilterBar({required this.sort, required this.onSortChanged, required this.postCount});

  @override
  double get maxExtent => 56;

  @override
  double get minExtent => 56;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: ThixPolicy.card,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _SortChip(
                    label: 'Récent',
                    icon: Icons.schedule_rounded,
                    selected: sort == _HashtagSort.recent,
                    onTap: () => onSortChanged(_HashtagSort.recent),
                  ),
                  const SizedBox(width: 8),
                  _SortChip(
                    label: 'Populaire',
                    icon: Icons.trending_up_rounded,
                    selected: sort == _HashtagSort.popular,
                    onTap: () => onSortChanged(_HashtagSort.popular),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: ThixPolicy.surfaceSoft,
              borderRadius: BorderRadius.circular(ThixPolicy.rFull),
            ),
            child: Text(
              '$postCount',
              style: ThixPolicy.captionStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SliverFilterBar oldDelegate) =>
      oldDelegate.sort != sort || oldDelegate.postCount != postCount;
}

class _SortChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? ThixPolicy.primary : ThixPolicy.surfaceSoft,
          borderRadius: BorderRadius.circular(ThixPolicy.rFull),
          border: Border.all(
            color: selected ? ThixPolicy.primary : ThixPolicy.border.withOpacity(0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? Colors.white : ThixPolicy.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: ThixPolicy.captionStyle.copyWith(
                color: selected ? Colors.white : ThixPolicy.textMain,
                fontWeight: ThixPolicy.semiBold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PATTERN PEINTRE (décoration du header)
// ============================================================================
class _HashPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (double x = 0; x < size.width; x += 40) {
      for (double y = 0; y < size.height; y += 40) {
        canvas.drawCircle(Offset(x, y), 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
