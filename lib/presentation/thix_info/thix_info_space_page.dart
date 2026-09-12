// lib/presentation/thix_info/thix_info_space_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

import '../../models/news_article.dart';
import '../../providers/news_provider.dart';
import '../../providers/downloads_provider.dart';
import '../../services/thix_downloader.dart';
import 'thix_info_home.dart'; // GlassBox

// ============================================================================
// CONFIGURATION DES ESPACES
// ============================================================================
class _SpaceConfig {
  final String slug;
  final String name;
  final String dbCategory;
  final IconData icon;
  final Color color;
  final String tagline;
  final String emptyMessage;
  final String heroTitle;

  const _SpaceConfig({
    required this.slug,
    required this.name,
    required this.dbCategory,
    required this.icon,
    required this.color,
    required this.tagline,
    required this.emptyMessage,
    required this.heroTitle,
  });

  static _SpaceConfig fromSlug(String slug) {
    switch (slug) {
      case 'podcast':
        return const _SpaceConfig(
          slug: 'podcast',
          name: 'Podcasts & Audio',
          dbCategory: 'Podcast',
          icon: Icons.headphones_rounded,
          color: Color(0xFF6366F1),
          tagline: 'Écoutez, téléchargez, emportez',
          emptyMessage: 'Aucun podcast publié pour le moment',
          heroTitle: 'Conversations & reportages audio',
        );
      case 'decouverte':
        return const _SpaceConfig(
          slug: 'decouverte',
          name: 'Découverte',
          dbCategory: 'Découverte',
          icon: Icons.explore_rounded,
          color: Color(0xFF10B981),
          tagline: 'Explorer le monde, autrement',
          emptyMessage: 'Aucun contenu Découverte publié',
          heroTitle: 'Voyage au cœur des cultures',
        );
      case 'magazine':
      default:
        return const _SpaceConfig(
          slug: 'magazine',
          name: 'Magazine',
          dbCategory: 'Magazine',
          icon: Icons.auto_stories_rounded,
          color: Color(0xFFD4AF37),
          tagline: 'Lectures pro & longs formats',
          emptyMessage: 'Aucun article Magazine publié',
          heroTitle: 'Grands dossiers & analyses',
        );
    }
  }
}

// ============================================================================
// PAGE DE L'ESPACE
// ============================================================================
class ThixInfoSpacePage extends ConsumerStatefulWidget {
  final String space;

  const ThixInfoSpacePage({super.key, required this.space});

  @override
  ConsumerState<ThixInfoSpacePage> createState() => _ThixInfoSpacePageState();
}

class _ThixInfoSpacePageState extends ConsumerState<ThixInfoSpacePage> {
  late final _SpaceConfig _config;
  List<NewsArticle> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _config = _SpaceConfig.fromSlug(widget.space);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list =
          await ref.read(newsProvider).fetchArticlesByCategory(_config.dbCategory);
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThixPolicy.inkDeep,
      body: Stack(
        children: [
          // ─── BACKGROUND GLOW ───
          Positioned(
            top: -150,
            right: -150,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _config.color.withOpacity(0.15),
                boxShadow: [
                  BoxShadow(
                    color: _config.color.withOpacity(0.25),
                    blurRadius: 120,
                    spreadRadius: 60,
                  ),
                ],
              ),
            ),
          ),

          CustomScrollView(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              _buildAppBar(),
              _buildHero(),

              // ─── STATS ───
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      ThixPolicy.s16, ThixPolicy.s24, ThixPolicy.s16, ThixPolicy.s8),
                  child: _buildStats(),
                ),
              ),

              // ─── FILTRES RAPIDES (par sous-catégorie si dispo) ───
              if (!_loading && _items.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: ThixPolicy.s16, vertical: ThixPolicy.s12),
                    child: Text('CONTENUS (${_items.length})',
                        style: ThixPolicy.labelStyle.copyWith(
                            color: Colors.white54,
                            fontWeight: ThixPolicy.bold,
                            letterSpacing: 1.5)),
                  ),
                ),

              // ─── CORPS ───
              if (_loading)
                const SliverFillRemaining(
                    child: Center(
                        child: CircularProgressIndicator(color: Colors.white)))
              else if (_error != null)
                SliverFillRemaining(
                    child: Center(
                        child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off_rounded,
                        size: 48, color: Colors.white38),
                    const SizedBox(height: ThixPolicy.s12),
                    Text('Erreur de chargement',
                        style: ThixPolicy.titleStyle
                            .copyWith(color: Colors.white70)),
                    const SizedBox(height: ThixPolicy.s8),
                    ElevatedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Réessayer'),
                    ),
                  ],
                )))
              else if (_items.isEmpty)
                SliverFillRemaining(child: _buildEmpty())
              else
                _buildContent(),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // APP BAR AVEC HERO VISUEL
  // ═══════════════════════════════════════════════════════════════
  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      expandedHeight: 180,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        onPressed: () => context.pop(),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
          onPressed: _load,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _config.color.withOpacity(0.4),
                ThixPolicy.inkDeep,
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _config.color.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: _config.color.withOpacity(0.5), width: 2),
                  ),
                  child: Icon(_config.icon, color: Colors.white, size: 36),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HERO : TITRE + TAGLINE
  // ═══════════════════════════════════════════════════════════════
  Widget _buildHero() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            ThixPolicy.s16, ThixPolicy.s20, ThixPolicy.s16, ThixPolicy.s8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_config.name,
                style: ThixPolicy.h1Style.copyWith(
                    color: Colors.white,
                    fontWeight: ThixPolicy.bold,
                    letterSpacing: -0.5)),
            const SizedBox(height: ThixPolicy.s6),
            Text(_config.heroTitle,
                style: ThixPolicy.h3Style.copyWith(color: Colors.white70)),
            const SizedBox(height: ThixPolicy.s12),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: ThixPolicy.s12, vertical: ThixPolicy.s6),
              decoration: BoxDecoration(
                color: _config.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(ThixPolicy.rXl),
                border:
                    Border.all(color: _config.color.withOpacity(0.4), width: 1),
              ),
              child: Text(_config.tagline,
                  style: ThixPolicy.labelStyle.copyWith(
                      color: _config.color, fontWeight: ThixPolicy.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STATS (nombre, vues cumulées)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildStats() {
    final totalViews = _items.fold<int>(0, (s, a) => s + a.viewsCount);
    return GlassBox(
      padding: const EdgeInsets.all(ThixPolicy.s16),
      borderRadius: ThixPolicy.rMd,
      child: Row(
        children: [
          _statCell(
            '${_items.length}',
            'contenus',
            _config.icon,
          ),
          Container(width: 1, height: 40, color: Colors.white12),
          _statCell(
            _formatNumber(totalViews),
            'vues totales',
            Icons.remove_red_eye_rounded,
          ),
          Container(width: 1, height: 40, color: Colors.white12),
          _statCell(
            _config.slug == 'podcast'
                ? '${_items.where((a) => a.videoUrl != null).length}'
                : '${_items.where((a) => a.imageUrl != null).length}',
            _config.slug == 'podcast' ? 'avec média' : 'avec image',
            Icons.image_rounded,
          ),
        ],
      ),
    );
  }

  Widget _statCell(String value, String label, IconData icon) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: _config.color),
          const SizedBox(width: ThixPolicy.s8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: ThixPolicy.titleStyle.copyWith(
                      color: Colors.white, fontWeight: ThixPolicy.bold)),
              Text(label,
                  style: ThixPolicy.microStyle
                      .copyWith(color: Colors.white54, letterSpacing: 0.5)),
            ],
          ),
        ],
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  // ═══════════════════════════════════════════════════════════════
  // EMPTY STATE
  // ═══════════════════════════════════════════════════════════════
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _config.color.withOpacity(0.1),
              shape: BoxShape.circle,
              border:
                  Border.all(color: _config.color.withOpacity(0.3), width: 2),
            ),
            child: Icon(_config.icon, size: 48, color: _config.color),
          ),
          const SizedBox(height: ThixPolicy.s20),
          Text(_config.emptyMessage,
              textAlign: TextAlign.center,
              style: ThixPolicy.titleStyle.copyWith(color: Colors.white70)),
          const SizedBox(height: ThixPolicy.s8),
          Text(
              'Publiez depuis THIX Admin avec la catégorie « ${_config.dbCategory} »',
              textAlign: TextAlign.center,
              style:
                  ThixPolicy.bodySmallStyle.copyWith(color: Colors.white38)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // CONTENU (layout adapté au type d'espace)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildContent() {
    switch (_config.slug) {
      case 'podcast':
        return _buildPodcastList();
      case 'decouverte':
        return _buildDecouverteGrid();
      case 'magazine':
      default:
        return _buildMagazineList();
    }
  }

  // ─── MAGAZINE : liste verticale style presse ───
  Widget _buildMagazineList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) => _magazineCard(_items[i]),
        childCount: _items.length,
      ),
    );
  }

  Widget _magazineCard(NewsArticle a) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          ThixPolicy.s16, 0, ThixPolicy.s16, ThixPolicy.s16),
      child: GestureDetector(
        onTap: () => context.push('/thix-info/article/${a.id}'),
        child: GlassBox(
          padding: EdgeInsets.zero,
          borderRadius: ThixPolicy.rLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Couverture
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(ThixPolicy.rLg)),
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      a.imageUrl != null
                          ? Image.network(a.imageUrl!, fit: BoxFit.cover)
                          : Container(color: Colors.white.withOpacity(0.08)),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.7),
                                Colors.transparent,
                              ]),
                        ),
                      ),
                      // Badge LECTURE PRO
                      Positioned(
                        top: ThixPolicy.s12,
                        left: ThixPolicy.s12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('LECTURE PRO',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2)),
                        ),
                      ),
                      // Durée de lecture
                      Positioned(
                        bottom: ThixPolicy.s12,
                        right: ThixPolicy.s12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.auto_stories_rounded,
                                  size: 12, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                  '${(a.content.length / 1500).ceil()} min de lecture',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Contenu
              Padding(
                padding: const EdgeInsets.all(ThixPolicy.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ThixPolicy.titleStyle.copyWith(
                            color: Colors.white,
                            fontWeight: ThixPolicy.bold,
                            height: 1.2)),
                    const SizedBox(height: ThixPolicy.s8),
                    Text(a.summary ?? '',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: ThixPolicy.bodySmallStyle.copyWith(
                            color: Colors.white60, height: 1.5)),
                    const SizedBox(height: ThixPolicy.s12),
                    Row(
                      children: [
                        Icon(Icons.remove_red_eye_rounded,
                            size: 13, color: Colors.white38),
                        const SizedBox(width: 4),
                        Text('${a.viewsCount} vues',
                            style: ThixPolicy.microStyle
                                .copyWith(color: Colors.white38)),
                        const Spacer(),
                        Text(_timeAgo(a.publishedAt),
                            style: ThixPolicy.microStyle
                                .copyWith(color: Colors.white38)),
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

  // ─── PODCAST : liste horizontale avec téléchargement ───
  Widget _buildPodcastList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) => _podcastRow(_items[i]),
        childCount: _items.length,
      ),
    );
  }

  Widget _podcastRow(NewsArticle a) {
    final dl = ref.watch(downloadsProvider);
    final downloading = dl.isDownloading(a.id);
    final downloaded = dl.isDownloaded(a.id);
    final currentItem = dl.findById(a.id);
    final hasMedia = (a.videoUrl?.isNotEmpty ?? false);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          ThixPolicy.s16, 0, ThixPolicy.s16, ThixPolicy.s12),
      child: GestureDetector(
        onTap: () => context.push('/thix-info/article/${a.id}'),
        child: GlassBox(
          padding: const EdgeInsets.all(ThixPolicy.s12),
          borderRadius: ThixPolicy.rMd,
          child: Row(
            children: [
              // Pochette carrée
              ClipRRect(
                borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      a.imageUrl != null
                          ? Image.network(a.imageUrl!, fit: BoxFit.cover)
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    _config.color.withOpacity(0.6),
                                    _config.color.withOpacity(0.9),
                                  ],
                                ),
                              ),
                              child: const Center(
                                  child: Icon(Icons.graphic_eq_rounded,
                                      size: 32, color: Colors.white70)),
                            ),
                      // Bouton PLAY central
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: ThixPolicy.s12),
              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ThixPolicy.bodyStyle.copyWith(
                            color: Colors.white,
                            fontWeight: ThixPolicy.bold,
                            height: 1.2)),
                    const SizedBox(height: ThixPolicy.s6),
                    Row(
                      children: [
                        Icon(Icons.graphic_eq_rounded,
                            size: 12, color: Colors.white38),
                        const SizedBox(width: 4),
                        Text('${a.viewsCount} écoutes',
                            style: ThixPolicy.microStyle
                                .copyWith(color: Colors.white38)),
                        const SizedBox(width: ThixPolicy.s10),
                        Icon(Icons.schedule_rounded,
                            size: 12, color: Colors.white38),
                        const SizedBox(width: 4),
                        Text(_timeAgo(a.publishedAt),
                            style: ThixPolicy.microStyle
                                .copyWith(color: Colors.white38)),
                      ],
                    ),
                    if (downloading && currentItem != null) ...[
                      const SizedBox(height: ThixPolicy.s8),
                      LinearProgressIndicator(
                        value: currentItem.progress,
                        backgroundColor: Colors.white12,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      const SizedBox(height: ThixPolicy.s4),
                      Text(currentItem.progressLabel,
                          style: ThixPolicy.microStyle
                              .copyWith(color: Colors.white54)),
                    ],
                  ],
                ),
              ),
              // Bouton téléchargement
              if (hasMedia) ...[
                const SizedBox(width: ThixPolicy.s8),
                _downloadButton(a, downloading, downloaded, currentItem),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _downloadButton(NewsArticle a, bool downloading, bool downloaded,
      DownloadItem? currentItem) {
    if (downloading && currentItem != null) {
      return SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                value: currentItem.progress,
                strokeWidth: 3,
                backgroundColor: Colors.black45,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            Text('${(currentItem.progress * 100).toInt()}%',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900)),
          ],
        ),
      );
    }
    if (downloaded) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded,
            color: Color(0xFF10B981), size: 22),
      );
    }
    return GestureDetector(
      onTap: () => ref.read(downloadsProvider).downloadArticle(a),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _config.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: _config.color.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: const Icon(Icons.download_rounded,
            color: Colors.white, size: 20),
      ),
    );
  }

  // ─── DÉCOUVERTE : grille 2 colonnes immersive ───
  Widget _buildDecouverteGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, i) => _decouverteCard(_items[i]),
          childCount: _items.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: ThixPolicy.s12,
          mainAxisSpacing: ThixPolicy.s12,
          childAspectRatio: 0.75,
        ),
      ),
    );
  }

  Widget _decouverteCard(NewsArticle a) {
    return GestureDetector(
      onTap: () => context.push('/thix-info/article/${a.id}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        child: Stack(
          fit: StackFit.expand,
          children: [
            a.imageUrl != null
                ? Image.network(a.imageUrl!, fit: BoxFit.cover)
                : Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _config.color.withOpacity(0.4),
                            const Color(0xFF065F46).withOpacity(0.9),
                          ]),
                    ),
                    child: Center(
                        child: Icon(Icons.explore_rounded,
                            size: 48, color: Colors.white54)),
                  ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.85),
                      Colors.black.withOpacity(0.2),
                      Colors.transparent,
                    ]),
              ),
            ),
            Positioned(
              bottom: ThixPolicy.s12,
              left: ThixPolicy.s12,
              right: ThixPolicy.s12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.explore_rounded,
                      size: 18, color: _config.color),
                  const SizedBox(height: ThixPolicy.s6),
                  Text(a.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: ThixPolicy.bodySmallStyle.copyWith(
                          color: Colors.white,
                          fontWeight: ThixPolicy.bold,
                          height: 1.25)),
                  const SizedBox(height: ThixPolicy.s6),
                  Row(
                    children: [
                      Icon(Icons.remove_red_eye_rounded,
                          size: 12, color: Colors.white60),
                      const SizedBox(width: 4),
                      Text('${a.viewsCount}',
                          style: ThixPolicy.microStyle
                              .copyWith(color: Colors.white60)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════
  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
    if (diff.inDays < 30) return 'Il y a ${(diff.inDays / 7).floor()} sem';
    return 'Il y a ${(diff.inDays / 30).floor()} mois';
  }
}
