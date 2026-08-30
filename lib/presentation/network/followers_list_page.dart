// lib/presentation/network/followers_list_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/models/certification_tier.dart';
import 'package:thix_id/presentation/certification/widgets/certification_name_badge.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';

// ============================================================================
// CONSTANTES & VALIDATEURS
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 12);
const int _kPageSize = 50;
const Duration _kSearchDebounce = Duration(milliseconds: 300);

class _FollowersValidators {
  _FollowersValidators._();

  static String sanitize(String? input, {int maxLength = 100}) {
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
// PROVIDER
// ============================================================================
class FollowerProfile {
  final String userId;
  final String displayName;
  final String? photoUrl;
  final String? profession;
  final String? certificationTier;
  final String? certificationStatus;
  final bool isVerified;

  const FollowerProfile({
    required this.userId,
    required this.displayName,
    this.photoUrl,
    this.profession,
    this.certificationTier,
    this.certificationStatus,
    this.isVerified = false,
  });

  factory FollowerProfile.fromMap(Map<String, dynamic> map) {
    return FollowerProfile(
      userId: map['id']?.toString() ?? '',
      displayName: map['display_name']?.toString() ?? 'Utilisateur THIX',
      photoUrl: map['photo_url']?.toString() ?? map['avatar_url']?.toString(),
      profession: map['profession']?.toString(),
      certificationTier: map['certification_tier']?.toString(),
      certificationStatus: map['certification_status']?.toString(),
      isVerified: map['is_verified'] == true,
    );
  }
}

class FollowersState {
  final List<FollowerProfile> profiles;
  final bool hasMore;
  final bool isLoading;

  const FollowersState({
    this.profiles = const [],
    this.hasMore = true,
    this.isLoading = false,
  });

  FollowersState copyWith({
    List<FollowerProfile>? profiles,
    bool? hasMore,
    bool? isLoading,
  }) {
    return FollowersState(
      profiles: profiles ?? this.profiles,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class FollowersNotifier extends AutoDisposeFamilyAsyncNotifier<FollowersState, String> {
  int _offset = 0;

  @override
  Future<FollowersState> build(String arg) async {
    _offset = 0;
    return _loadInitial();
  }

  Future<FollowersState> _loadInitial() async {
    debugPrint('[Followers] 📥 Loading initial for ${arg.substring(0, 8)}...');
    try {
      // ÉTAPE 1 : IDs des followers
      final followsRes = await Supabase.instance.client
          .from('follows')
          .select('follower_id')
          .eq('following_id', arg)
          .order('created_at', ascending: false)
          .limit(_kPageSize)
          .timeout(_kRequestTimeout);

      final followerIds = (followsRes as List)
          .map((e) => e['follower_id'].toString())
          .where((id) => id.isNotEmpty)
          .toList();

      if (followerIds.isEmpty) {
        debugPrint('[Followers] ✓ No followers');
        return const FollowersState(hasMore: false);
      }

      // ÉTAPE 2 : Profils
      final profilesRes = await Supabase.instance.client
          .from('profiles')
          .select('id, display_name, photo_url, avatar_url, profession, certification_tier, certification_status, is_verified')
          .inFilter('id', followerIds)
          .timeout(_kRequestTimeout);

      final profiles = (profilesRes as List)
          .map((p) => FollowerProfile.fromMap(p as Map<String, dynamic>))
          .toList();

      _offset = profiles.length;
      debugPrint('[Followers] ✓ Loaded ${profiles.length} profiles');

      return FollowersState(
        profiles: profiles,
        hasMore: profiles.length >= _kPageSize,
      );
    } catch (e) {
      debugPrint('[Followers] ❌ Load error: $e');
      rethrow;
    }
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoading) return;

    state = AsyncData(current.copyWith(isLoading: true));

    try {
      final followsRes = await Supabase.instance.client
          .from('follows')
          .select('follower_id')
          .eq('following_id', arg)
          .order('created_at', ascending: false)
          .range(_offset, _offset + _kPageSize - 1)
          .timeout(_kRequestTimeout);

      final followerIds = (followsRes as List)
          .map((e) => e['follower_id'].toString())
          .where((id) => id.isNotEmpty)
          .toList();

      if (followerIds.isEmpty) {
        state = AsyncData(current.copyWith(hasMore: false, isLoading: false));
        return;
      }

      final profilesRes = await Supabase.instance.client
          .from('profiles')
          .select('id, display_name, photo_url, avatar_url, profession, certification_tier, certification_status, is_verified')
          .inFilter('id', followerIds)
          .timeout(_kRequestTimeout);

      final newProfiles = (profilesRes as List)
          .map((p) => FollowerProfile.fromMap(p as Map<String, dynamic>))
          .toList();

      // Dedup
      final existingIds = current.profiles.map((p) => p.userId).toSet();
      final unique = newProfiles.where((p) => !existingIds.contains(p.userId)).toList();

      _offset += unique.length;

      state = AsyncData(current.copyWith(
        profiles: [...current.profiles, ...unique],
        hasMore: unique.length >= _kPageSize,
        isLoading: false,
      ));

      debugPrint('[Followers] ✓ Loaded ${unique.length} more (total: ${current.profiles.length + unique.length})');
    } catch (e) {
      debugPrint('[Followers] ❌ Load more error: $e');
      state = AsyncData(current.copyWith(isLoading: false));
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadInitial());
  }
}

final followersProvider = AsyncNotifierProvider.autoDispose
    .family<FollowersNotifier, FollowersState, String>(FollowersNotifier.new);

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class FollowersListPage extends ConsumerStatefulWidget {
  final String userId;
  const FollowersListPage({super.key, required this.userId});

  @override
  ConsumerState<FollowersListPage> createState() => _FollowersListPageState();
}

class _FollowersListPageState extends ConsumerState<FollowersListPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    debugPrint('[Followers] 🏷️ Opened for ${widget.userId.substring(0, 8)}...');
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
      ref.read(followersProvider(widget.userId).notifier).loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_kSearchDebounce, () {
      if (mounted) setState(() => _searchQuery = value.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchCtrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(followersProvider(widget.userId));

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: ThixPolicy.textMain, size: 20),
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Abonnés',
          style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold),
        ),
        actions: [
          if (asyncState.valueOrNull != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ThixPolicy.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                  ),
                  child: Text(
                    '${asyncState.valueOrNull!.profiles.length}',
                    style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.primary, fontWeight: ThixPolicy.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: asyncState.when(
              loading: () => _buildSkeleton(),
              error: (e, _) => _buildErrorState(e.toString()),
              data: (state) => _buildBody(state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: ThixPolicy.card,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearchChanged,
        style: ThixPolicy.bodyStyle,
        decoration: InputDecoration(
          hintText: 'Rechercher un abonné...',
          hintStyle: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
          prefixIcon: const Icon(Icons.search_rounded, color: ThixPolicy.primary, size: 20),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, color: ThixPolicy.textSecondary, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: ThixPolicy.surfaceSoft,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.rXl), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildBody(FollowersState state) {
    final filtered = _searchQuery.isEmpty
        ? state.profiles
        : state.profiles.where((p) {
            final name = p.displayName.toLowerCase();
            final prof = (p.profession ?? '').toLowerCase();
            return name.contains(_searchQuery) || prof.contains(_searchQuery);
          }).toList();

    if (state.profiles.isEmpty) {
      return _buildEmptyState();
    }

    if (filtered.isEmpty && _searchQuery.isNotEmpty) {
      return _buildNoResults();
    }

    return RefreshIndicator(
      color: ThixPolicy.primary,
      onRefresh: () => ref.read(followersProvider(widget.userId).notifier).refresh(),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: filtered.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == filtered.length && state.hasMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary)),
            );
          }
          return _FollowerTile(profile: filtered[i]);
        },
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 10,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: 140, color: Colors.grey.shade200),
                  const SizedBox(height: 6),
                  Container(height: 12, width: 100, color: Colors.grey.shade200),
                ],
              ),
            ),
            Container(width: 80, height: 32, color: Colors.grey.shade200),
          ],
        ),
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
            Text('Erreur de chargement', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
            const SizedBox(height: 8),
            Text(
              _FollowersValidators.sanitize(error),
              textAlign: TextAlign.center,
              style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(followersProvider(widget.userId)),
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text('Réessayer'),
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
      onRefresh: () => ref.read(followersProvider(widget.userId).notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
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
                      child: const Icon(Icons.people_outline_rounded, size: 64, color: ThixPolicy.primary),
                    ),
                    const SizedBox(height: 24),
                    Text('Aucun abonné', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
                    const SizedBox(height: 8),
                    Text(
                      'Partagez du contenu pour attirer des abonnés !',
                      textAlign: TextAlign.center,
                      style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.5),
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

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: ThixPolicy.textMuted),
            const SizedBox(height: 12),
            Text('Aucun résultat pour "$_searchQuery"', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TUILE ABONNÉ
// ============================================================================
class _FollowerTile extends ConsumerStatefulWidget {
  final FollowerProfile profile;
  const _FollowerTile({required this.profile});

  @override
  ConsumerState<_FollowerTile> createState() => _FollowerTileState();
}

class _FollowerTileState extends ConsumerState<_FollowerTile> {
  bool? _isFollowingOverride;
  bool _isLoading = false;

  bool get _isFollowing => _isFollowingOverride ?? false;

  Future<void> _toggleFollow() async {
    if (_isLoading) return;

    final currentUserId = ref.read(authControllerProvider).value?.id;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous devez être connecté'), backgroundColor: ThixPolicy.danger),
      );
      return;
    }

    // Ne pas se suivre soi-même
    if (currentUserId == widget.profile.userId) return;

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    final wasFollowing = _isFollowing;

    try {
      // Optimistic UI
      setState(() => _isFollowingOverride = !wasFollowing);

      final supa = Supabase.instance.client;
      if (wasFollowing) {
        await supa
            .from('follows')
            .delete()
            .eq('follower_id', currentUserId)
            .eq('following_id', widget.profile.userId)
            .timeout(_kRequestTimeout);
        debugPrint('[Followers] ✓ Unfollowed ${widget.profile.userId.substring(0, 8)}');
      } else {
        await supa.from('follows').insert({
          'follower_id': currentUserId,
          'following_id': widget.profile.userId,
        }).timeout(_kRequestTimeout);
        debugPrint('[Followers] ✓ Followed ${widget.profile.userId.substring(0, 8)}');
      }
    } catch (e) {
      debugPrint('[Followers] ❌ Toggle follow error: $e');
      if (mounted) {
        setState(() => _isFollowingOverride = wasFollowing); // Rollback
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur réseau'), backgroundColor: ThixPolicy.danger, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final name = _FollowersValidators.sanitize(p.displayName, maxLength: 60);
    final profession = _FollowersValidators.sanitize(p.profession, maxLength: 100);
    final photoUrl = _FollowersValidators.sanitizeUrl(p.photoUrl);

    // Certification
    final tier = CertificationTierX.parse(p.certificationTier);
    final status = CertificationStatusX.parse(p.certificationStatus);
    final isCertified = status == CertificationStatus.approved || status == CertificationStatus.generated;

    final currentUserId = ref.watch(authControllerProvider).value?.id;
    final isMe = currentUserId == p.userId;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: ThixPolicy.border.withOpacity(0.5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          onTap: () {
            HapticFeedback.selectionClick();
            context.push('/network/profile/${p.userId}');
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Avatar
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ThixPolicy.border, width: 1.5),
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: ThixPolicy.surfaceSoft,
                    backgroundImage: photoUrl != null ? CachedNetworkImageProvider(photoUrl) : null,
                    child: photoUrl == null
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: ThixPolicy.titleStyle.copyWith(
                              color: ThixPolicy.textSecondary,
                              fontWeight: ThixPolicy.bold,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),

                // Infos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: ThixPolicy.labelStyle.copyWith(
                                fontWeight: ThixPolicy.bold,
                                color: ThixPolicy.textMain,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCertified)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: CertificationNameBadge(
                                tier: tier,
                                status: status,
                                showLabel: false,
                                iconSize: 14,
                              ),
                            )
                          else if (p.isVerified)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.verified_rounded, color: ThixPolicy.gold, size: 14),
                            ),
                        ],
                      ),
                      if (profession.isNotEmpty)
                        Text(
                          profession,
                          style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),

                // Bouton Follow
                if (!isMe)
                  GestureDetector(
                    onTap: _toggleFollow,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _isFollowing ? ThixPolicy.surfaceSoft : ThixPolicy.primary,
                        borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                        border: _isFollowing ? Border.all(color: ThixPolicy.borderStrong) : null,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.textSecondary),
                            )
                          : Text(
                              _isFollowing ? 'Suivi' : 'Suivre',
                              style: ThixPolicy.labelStyle.copyWith(
                                color: _isFollowing ? ThixPolicy.textMain : Colors.white,
                                fontWeight: ThixPolicy.bold,
                                fontSize: 12,
                              ),
                            ),
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
