import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/models/media_content.dart';
import 'package:thix_id/nav.dart' show AppRoutes;

import 'providers/thix_media_providers.dart';
import 'utils/media_constants.dart';
import 'widgets/media_poster_card.dart';
import 'widgets/media_detail_page.dart';
import 'widgets/fil_feed_view.dart';
import 'admin/thix_media_admin_page.dart';
import 'create_post_page.dart';
import 'user_profile_page.dart';

class ThixMediaPage extends ConsumerStatefulWidget {
  const ThixMediaPage({super.key});
  @override
  ConsumerState<ThixMediaPage> createState() => _ThixMediaPageState();
}

class _ThixMediaPageState extends ConsumerState<ThixMediaPage> with AutomaticKeepAliveClientMixin<ThixMediaPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  String _selectedCategory = 'Tous';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedCategoryProvider.notifier).state = 'Tous';
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    AnalyticsBatcher.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 600) {
      ref.read(thixMediaListProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(searchQueryProvider.notifier).state = v;
    });
  }

  void _openDetail(MediaContent item) {
    AnalyticsBatcher.register(item.id);
    final catalog = ref.read(thixMediaListProvider).valueOrNull ?? [];
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MediaDetailPage(item: item, catalog: catalog)),
    );
  }

  List<String> _categories(List<MediaContent> catalog) {
    final types = catalog.map((e) => e.type).where((t) => t.isNotEmpty).toSet().toList();
    return ['Tous', 'Fil', ...types];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final asyncMedia = ref.watch(thixMediaListProvider);
    final isAdmin = ref.watch(isMediaAdminProvider).valueOrNull ?? false;
    final hasQuery = _searchController.text.trim().isNotEmpty;
    final showSearchOverlay = _searchFocusNode.hasFocus && hasQuery;

    return Scaffold(
      backgroundColor: MediaColors.navyDeep,
      body: asyncMedia.when(
        loading: () => const Center(child: CircularProgressIndicator(color: MediaColors.whiteAccent)),
        error: (e, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: MediaColors.danger, size: 48),
                const SizedBox(height: 16),
                Text(
                  e.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.read(thixMediaListProvider.notifier).refresh(),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
        data: (catalog) {
          return Stack(
            children: [
              _buildMainContent(catalog),
              if (showSearchOverlay) _buildSearchOverlay(catalog),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMainContent(List<MediaContent> catalog) {
    final isAdmin = ref.watch(isMediaAdminProvider).valueOrNull ?? false;

    if (_selectedCategory == 'Fil') {
      return Stack(
        children: [
          FilFeedView(catalog: catalog, onOpenDetail: _openDetail),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(child: _buildTransparentHeader(isAdmin)),
          ),
        ],
      );
    }

    final filteredCatalog = _selectedCategory == 'Tous'
        ? catalog
        : catalog.where((e) => e.type == _selectedCategory).toList();

    final seriesRail = catalog.where((e) => e.episodesUrls.isNotEmpty).toList();

    return RefreshIndicator(
      color: MediaColors.navyDeep,
      backgroundColor: MediaColors.whiteAccent,
      onRefresh: () => ref.read(thixMediaListProvider.notifier).refresh(),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          _buildSliverHeader(isAdmin),
          if (catalog.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(60),
                child: Center(child: Text('Aucun contenu', style: TextStyle(color: Colors.white54))),
              ),
            )
          else ...[
            SliverToBoxAdapter(child: _buildHero(catalog)),
            SliverToBoxAdapter(child: _buildCategoryChips(catalog)),
            if (seriesRail.isNotEmpty) SliverToBoxAdapter(child: _buildSeriesRail(seriesRail)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(
                  _selectedCategory == 'Tous' ? 'Catalogue' : _selectedCategory,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.68,
                ),
                delegate: SliverChildBuilderDelegate(
                  (c, i) => MediaPosterCard(
                    item: filteredCatalog[i],
                    onTap: () => _openDetail(filteredCatalog[i]),
                  ),
                  childCount: filteredCatalog.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSliverHeader(bool isAdmin) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 70,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: MediaColors.navyDeep.withOpacity(0.85),
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
            ),
          ),
        ),
      ),
      title: Row(
        children: const [
          Icon(Icons.play_circle_filled_rounded, color: Colors.white, size: 26),
          SizedBox(width: 8),
          Text('TDIA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 19, letterSpacing: 0.5)),
        ],
      ),
      actions: [
        if (isAdmin)
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ThixMediaAdminPage())),
            icon: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 20),
          ),
        IconButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostPage())),
          icon: const Icon(Icons.add_box_outlined, color: Colors.white, size: 22),
        ),
        IconButton(
          onPressed: () {
            final currentUid = Supabase.instance.client.auth.currentUser?.id;
            if (currentUid != null) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfilePage(userId: currentUid)));
            }
          },
          icon: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 6),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: _onSearchChanged,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        cursorColor: Colors.white,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          hintText: 'Découvrir des vidéos, séries, créateurs…',
                          hintStyle: TextStyle(color: Colors.white54, fontSize: 13.5),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (hasQuery)
                      GestureDetector(
                        onTap: () {
                          _searchFocusNode.unfocus();
                          _searchController.clear();
                          ref.read(searchQueryProvider.notifier).state = "";
                        },
                        child: const Icon(Icons.close_rounded, color: Colors.white70, size: 16),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransparentHeader(bool isAdmin) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.play_circle_filled_rounded, color: Colors.white, size: 26),
          const SizedBox(width: 8),
          const Text('TDIA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 19, letterSpacing: 0.5)),
          const Spacer(),
          if (isAdmin)
            IconButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ThixMediaAdminPage())),
              icon: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 22),
            ),
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostPage())),
            icon: const Icon(Icons.add_box_outlined, color: Colors.white, size: 24),
          ),
          IconButton(
            onPressed: () {
              final currentUid = Supabase.instance.client.auth.currentUser?.id;
              if (currentUid != null) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfilePage(userId: currentUid)));
              }
            },
            icon: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(List<MediaContent> catalog) {
    final featured = catalog.take(6).toList();
    if (featured.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 180,
      child: PageView.builder(
        controller: PageController(viewportFraction: 0.92),
        itemCount: featured.length,
        itemBuilder: (c, i) {
          final item = featured[i];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: GestureDetector(
              onTap: () => _openDetail(item),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildHeroImage(item.coverUrl),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, MediaColors.navyDeep.withOpacity(0.95)],
                          stops: const [0.35, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      top: 14,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.9)),
                            child: const Text(
                              'À LA UNE',
                              style: TextStyle(color: MediaColors.navyDeep, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                            ),
                          ),
                          if (item.isPaid) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(20)),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lock_rounded, size: 11, color: ThixPolicy.gold),
                                  SizedBox(width: 3),
                                  Text('Premium', style: TextStyle(color: ThixPolicy.gold, fontSize: 10, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                formatMediaNumber(item.viewCount),
                                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
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
        },
      ),
    );
  }

  Widget _buildHeroImage(String url) {
    if (url.trim().isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [MediaColors.cardLight, MediaColors.card],
          ),
        ),
      );
    }
    return CachedNetworkImage(imageUrl: url, fit: BoxFit.cover);
  }

  Widget _buildCategoryChips(List<MediaContent> catalog) {
    final cats = _categories(catalog);
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (c, i) {
          final cat = cats[i];
          final sel = _selectedCategory == cat;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedCategory = cat);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: sel ? Colors.white : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: sel ? Colors.white : Colors.white.withOpacity(0.2)),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  color: sel ? MediaColors.navyDeep : Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSeriesRail(List<MediaContent> series) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.video_library_rounded, size: 16, color: Colors.white),
                SizedBox(width: 8),
                Text('Séries', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: series.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (c, i) => SizedBox(
                width: 128,
                child: MediaPosterCard(
                  item: series[i],
                  onTap: () => _openDetail(series[i]),
                  compact: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchOverlay(List<MediaContent> catalog) {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    final searchResults = hasQuery
        ? catalog.where((e) => e.title.toLowerCase().contains(_searchController.text.toLowerCase())).toList()
        : <MediaContent>[];

    return Positioned.fill(
      child: GestureDetector(
        onTap: () {
          _searchFocusNode.unfocus();
          setState(() {});
        },
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            color: MediaColors.navyDeep.withOpacity(0.85),
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + 130,
              left: 16,
              right: 16,
            ),
            child: searchResults.isEmpty
                ? const Center(
                    child: Text(
                      'Aucun résultat. Essayez un autre terme.',
                      style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  )
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.7,
                    ),
                    itemCount: searchResults.length,
                    itemBuilder: (context, i) {
                      final item = searchResults[i];
                      return GestureDetector(
                        onTap: () {
                          _searchFocusNode.unfocus();
                          _searchController.clear();
                          ref.read(searchQueryProvider.notifier).state = "";
                          _openDetail(item);
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _buildHeroImage(item.coverUrl),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [Colors.black.withOpacity(0.9), Colors.transparent],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 6,
                                right: 6,
                                bottom: 6,
                                child: Text(
                                  item.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  bool get hasQuery => _searchController.text.trim().isNotEmpty;
}
