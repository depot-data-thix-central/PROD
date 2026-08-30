// lib/presentation/network/communities_list_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/models/network_community.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';

// ============================================================================
// VALIDATEURS
// ============================================================================
class _CommunitiesValidators {
  _CommunitiesValidators._();

  static const Duration requestTimeout = Duration(seconds: 12);

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
// PROVIDERS
// ============================================================================
final myCommunitiesProvider = FutureProvider.autoDispose<List<NetworkCommunity>>((ref) async {
  return ref.read(networkServiceProvider).getMyCommunities().timeout(_CommunitiesValidators.requestTimeout);
});

final suggestedCommunitiesProvider = FutureProvider.autoDispose<List<NetworkCommunity>>((ref) async {
  return ref.read(networkServiceProvider).getSuggestedCommunities().timeout(_CommunitiesValidators.requestTimeout);
});

final allCommunitiesProvider =
    AsyncNotifierProvider<AllCommunitiesNotifier, List<NetworkCommunity>>(AllCommunitiesNotifier.new);

class AllCommunitiesNotifier extends AsyncNotifier<List<NetworkCommunity>> {
  static const int _limit = 20;
  int _offset = 0;
  bool _hasMoreFlag = true;

  bool get hasMore => _hasMoreFlag;

  @override
  Future<List<NetworkCommunity>> build() async {
    _offset = 0;
    _hasMoreFlag = true;
    final list = await ref
        .read(networkServiceProvider)
        .getAllCommunities(limit: _limit, offset: 0)
        .timeout(_CommunitiesValidators.requestTimeout);
    _offset = list.length;
    _hasMoreFlag = list.length >= _limit;
    return list;
  }

  Future<void> loadMore() async {
    if (!_hasMoreFlag || state.isLoading) return;
    final current = state.valueOrNull ?? [];

    try {
      // ✅ FIX : charger UNIQUEMENT les nouveaux (pas tout depuis le début)
      final more = await ref
          .read(networkServiceProvider)
          .getAllCommunities(limit: _limit, offset: _offset)
          .timeout(_CommunitiesValidators.requestTimeout);

      if (more.isEmpty) {
        _hasMoreFlag = false;
        return;
      }

      // Dedup par ID
      final existingIds = current.map((e) => e.id).toSet();
      final filtered = more.where((e) => !existingIds.contains(e.id)).toList();

      _offset += filtered.length;
      if (filtered.isEmpty) _hasMoreFlag = false;

      state = AsyncData([...current, ...filtered]);
      debugPrint('[Communities] Loaded ${filtered.length} more (offset=$_offset)');
    } catch (e) {
      debugPrint('[Communities] Load more error: $e');
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class CommunitiesListPage extends ConsumerStatefulWidget {
  const CommunitiesListPage({super.key});
  @override
  ConsumerState<CommunitiesListPage> createState() => _CommunitiesListPageState();
}

class _CommunitiesListPageState extends ConsumerState<CommunitiesListPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _domainFilter = '';

  final ScrollController _allScroll = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  bool _showSearch = false;

  static const List<String> _domains = [
    '', 'media', 'market', 'learning', 'jobs', 'info',
    'opportunity', 'events', 'network', 'health', 'money',
    'gov', 'reservation',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) HapticFeedback.selectionClick();
    });
    _allScroll.addListener(() {
      if (_allScroll.position.pixels >= _allScroll.position.maxScrollExtent - 400) {
        ref.read(allCommunitiesProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _allScroll.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<NetworkCommunity> _filter(List<NetworkCommunity> list) {
    var filtered = list;

    // Filtre texte
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((c) {
        final name = c.name.toLowerCase();
        final desc = (c.description ?? '').toLowerCase();
        return name.contains(q) || desc.contains(q);
      }).toList();
    }

    // Filtre domaine
    if (_domainFilter.isNotEmpty) {
      filtered = filtered.where((c) {
        final domain = (c.domain ?? '').toLowerCase();
        return domain == _domainFilter;
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final myAsync = ref.watch(myCommunitiesProvider);
    final suggAsync = ref.watch(suggestedCommunitiesProvider);
    final allAsync = ref.watch(allCommunitiesProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Communautés',
          style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showSearch ? Icons.search_off_rounded : Icons.search_rounded,
              color: _showSearch ? ThixPolicy.primary : ThixPolicy.textMain,
            ),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchCtrl.clear();
                  _searchQuery = '';
                } else {
                  _searchFocus.requestFocus();
                }
              });
              HapticFeedback.selectionClick();
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, color: ThixPolicy.textMain),
            onPressed: () {
              HapticFeedback.selectionClick();
              context.push('/network/community/create');
            },
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_showSearch ? 108 : 48),
          child: Column(
            children: [
              // Barre de recherche inline
              if (_showSearch) _buildSearchBar(),
              Container(
                decoration: BoxDecoration(
                  color: ThixPolicy.card,
                  border: Border(bottom: BorderSide(color: ThixPolicy.border, width: 1)),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: ThixPolicy.primary,
                  unselectedLabelColor: ThixPolicy.textSecondary,
                  indicatorColor: ThixPolicy.primary,
                  indicatorWeight: 3,
                  labelStyle: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold),
                  unselectedLabelStyle: ThixPolicy.labelStyle,
                  tabs: const [
                    Tab(icon: Icon(Icons.bookmark_rounded, size: 18), text: 'Mes communautés'),
                    Tab(icon: Icon(Icons.star_rounded, size: 18), text: 'Suggestions'),
                    Tab(icon: Icon(Icons.explore_rounded, size: 18), text: 'Toutes'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          myAsync.when(
            loading: () => _buildSkeleton(),
            error: (e, _) => _buildErrorState(e.toString(), () => ref.invalidate(myCommunitiesProvider)),
            data: (list) => _buildList(
              _filter(list),
              emptyIcon: Icons.bookmark_outline_rounded,
              emptyTitle: 'Aucune communauté',
              emptySubtitle: 'Rejoignez des communautés pour les voir ici',
              emptyCtaLabel: 'Explorer',
              emptyCta: () => _tabController.animateTo(2),
              onRefresh: () async => ref.invalidate(myCommunitiesProvider),
            ),
          ),
          suggAsync.when(
            loading: () => _buildSkeleton(),
            error: (e, _) => _buildErrorState(e.toString(), () => ref.invalidate(suggestedCommunitiesProvider)),
            data: (list) => _buildList(
              _filter(list),
              emptyIcon: Icons.star_outline_rounded,
              emptyTitle: 'Aucune suggestion',
              emptySubtitle: 'Suivez des personnes pour recevoir des suggestions personnalisées',
              onRefresh: () async => ref.invalidate(suggestedCommunitiesProvider),
            ),
          ),
          allAsync.when(
            loading: () => _buildSkeleton(),
            error: (e, _) => _buildErrorState(
              e.toString(),
              () => ref.read(allCommunitiesProvider.notifier).refresh(),
            ),
            data: (list) => _buildList(
              _filter(list),
              emptyIcon: Icons.explore_outlined,
              emptyTitle: 'Aucune communauté',
              emptySubtitle: 'Soyez le premier à en créer une !',
              emptyCtaLabel: 'Créer',
              emptyCta: () => context.push('/network/community/create'),
              controller: _allScroll,
              showLoadMore: ref.read(allCommunitiesProvider.notifier).hasMore,
              onRefresh: () => ref.read(allCommunitiesProvider.notifier).refresh(),
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
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
            decoration: InputDecoration(
              hintText: 'Rechercher une communauté...',
              hintStyle: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
              prefixIcon: const Icon(Icons.search_rounded, color: ThixPolicy.primary, size: 22),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, color: ThixPolicy.textSecondary, size: 20),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.rXl), borderSide: BorderSide.none),
              filled: true,
              fillColor: ThixPolicy.surfaceSoft,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _domains.map((d) {
                final isSelected = _domainFilter == d;
                final label = d.isEmpty ? 'Tous' : d[0].toUpperCase() + d.substring(1);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (v) {
                      setState(() => _domainFilter = v ? d : '');
                      HapticFeedback.selectionClick();
                    },
                    selectedColor: ThixPolicy.primary,
                    backgroundColor: ThixPolicy.surfaceSoft,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : ThixPolicy.textSecondary,
                      fontWeight: isSelected ? ThixPolicy.bold : ThixPolicy.medium,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(ThixPolicy.rLg)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 16, width: 200, color: Colors.grey.shade200),
                  const SizedBox(height: 8),
                  Container(height: 12, width: double.infinity, color: Colors.grey.shade200),
                  const SizedBox(height: 6),
                  Container(height: 12, width: 150, color: Colors.grey.shade200),
                  const SizedBox(height: 16),
                  Container(height: 32, width: 100, color: Colors.grey.shade200),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error, VoidCallback onRetry) {
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
            Text('Erreur de chargement', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
            const SizedBox(height: 8),
            Text(
              _CommunitiesValidators.sanitize(error),
              textAlign: TextAlign.center,
              style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
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

  Widget _buildList(
    List<NetworkCommunity> communities, {
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptySubtitle,
    String? emptyCtaLabel,
    VoidCallback? emptyCta,
    ScrollController? controller,
    bool showLoadMore = false,
    Future<void> Function()? onRefresh,
  }) {
    if (communities.isEmpty) {
      return _buildEmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        subtitle: emptySubtitle,
        ctaLabel: emptyCtaLabel,
        cta: emptyCta,
      );
    }

    return RefreshIndicator(
      color: ThixPolicy.primary,
      backgroundColor: ThixPolicy.card,
      onRefresh: () async {
        HapticFeedback.mediumImpact();
        if (onRefresh != null) await onRefresh();
      },
      child: ListView.builder(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: communities.length + (showLoadMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == communities.length && showLoadMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary)),
            );
          }
          return _CommunityCard(community: communities[i]);
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? ctaLabel,
    VoidCallback? cta,
  }) {
    return RefreshIndicator(
      color: ThixPolicy.primary,
      onRefresh: () async {},
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
                      child: Icon(icon, size: 64, color: ThixPolicy.primary),
                    ),
                    const SizedBox(height: 24),
                    Text(title, style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.5),
                    ),
                    if (ctaLabel != null && cta != null) ...[
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          cta();
                        },
                        icon: const Icon(Icons.add_rounded, color: Colors.white),
                        label: Text(ctaLabel),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThixPolicy.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CARTE DE COMMUNAUTÉ (Premium)
// ============================================================================
class _CommunityCard extends ConsumerStatefulWidget {
  final NetworkCommunity community;
  const _CommunityCard({required this.community});

  @override
  ConsumerState<_CommunityCard> createState() => _CommunityCardState();
}

class _CommunityCardState extends ConsumerState<_CommunityCard> {
  bool _isJoining = false;
  bool? _isMemberOverride;

  bool get _isMember => _isMemberOverride ?? widget.community.isMember;

  Future<void> _toggleJoin() async {
    if (_isJoining) return;
    setState(() => _isJoining = true);

    HapticFeedback.mediumImpact();

    try {
      final supa = Supabase.instance.client;
      final uid = supa.auth.currentUser?.id;
      if (uid == null) throw Exception('Non authentifié');

      final wasMember = _isMember;

      // Optimistic UI
      setState(() => _isMemberOverride = !wasMember);

      if (wasMember) {
        await supa
            .from('community_members')
            .delete()
            .eq('community_id', widget.community.id)
            .eq('user_id', uid)
            .timeout(_CommunitiesValidators.requestTimeout);
      } else {
        await supa
            .from('community_members')
            .insert({
              'community_id': widget.community.id,
              'user_id': uid,
              'role': 'member',
              'joined_at': DateTime.now().toUtc().toIso8601String(),
            })
            .timeout(_CommunitiesValidators.requestTimeout);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(wasMember ? 'Vous avez quitté la communauté' : 'Bienvenue !'),
          backgroundColor: wasMember ? ThixPolicy.textSecondary : ThixPolicy.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
        ),
      );
    } catch (e) {
      debugPrint('[Communities] Toggle join error: $e');
      if (mounted) {
        setState(() => _isMemberOverride = null); // Rollback
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur réseau'), backgroundColor: ThixPolicy.danger, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.community;
    final bannerUrl = _CommunitiesValidators.sanitizeUrl(c.bannerUrl ?? c.logoUrl);
    final name = _CommunitiesValidators.sanitize(c.name, maxLength: 100);
    final description = _CommunitiesValidators.sanitize(c.description, maxLength: 200);
    final domain = (c.domain ?? '').toLowerCase();
    final privacy = _CommunitiesValidators.sanitize(c.privacy ?? 'Public', maxLength: 20);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        border: Border.all(color: ThixPolicy.border.withOpacity(0.5)),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.04),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            context.push('/network/community/${c.id}');
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner
              Stack(
                children: [
                  bannerUrl != null
                      ? CachedNetworkImage(
                          imageUrl: bannerUrl,
                          height: 100,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(height: 100, color: ThixPolicy.inkDeep),
                          errorWidget: (_, __, ___) => _buildDefaultBanner(name),
                        )
                      : _buildDefaultBanner(name),
                  // Badges en haut à droite
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (privacy.toLowerCase() == 'private')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.lock_rounded, size: 12, color: Colors.white),
                                const SizedBox(width: 4),
                                Text('Privé', style: ThixPolicy.microStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold)),
                              ],
                            ),
                          ),
                        if (domain.isNotEmpty) ...[
                          if (privacy.toLowerCase() == 'private') const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: ThixPolicy.domainColor(domain),
                              borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                            ),
                            child: Text(
                              domain[0].toUpperCase() + domain.substring(1),
                              style: ThixPolicy.microStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.4),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.people_alt_rounded, size: 16, color: ThixPolicy.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          '${c.membersCount ?? 0} membre${(c.membersCount ?? 0) != 1 ? 's' : ''}',
                          style: ThixPolicy.captionStyle.copyWith(fontWeight: ThixPolicy.semiBold),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: _isJoining ? null : _toggleJoin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isMember ? ThixPolicy.surface : ThixPolicy.primary,
                            foregroundColor: _isMember ? ThixPolicy.textMain : Colors.white,
                            elevation: 0,
                            side: _isMember ? BorderSide(color: ThixPolicy.borderStrong) : null,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                            minimumSize: const Size(100, 36),
                          ),
                          child: _isJoining
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.textSecondary),
                                )
                              : Text(
                                  _isMember ? 'Quitter' : 'Rejoindre',
                                  style: ThixPolicy.labelStyle.copyWith(
                                    color: _isMember ? ThixPolicy.textMain : Colors.white,
                                    fontWeight: ThixPolicy.bold,
                                    fontSize: 12,
                                  ),
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
    );
  }

  Widget _buildDefaultBanner(String name) {
    return Container(
      height: 100,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ThixPolicy.inkDeep, ThixPolicy.primary],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.groups_rounded, size: 32, color: Colors.white.withOpacity(0.4)),
            const SizedBox(height: 4),
            Text(
              name,
              style: ThixPolicy.titleStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
