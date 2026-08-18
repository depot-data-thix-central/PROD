// lib/presentation/mon_pays/pages/laws/article_type_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/article.dart';
import '../../providers/articles_provider.dart';
import 'article_detail_page.dart';

class ArticleTypePage extends ConsumerStatefulWidget {
  final ArticleType type;
  final String title;

  const ArticleTypePage({required this.type, required this.title, super.key});

  @override
  ConsumerState<ArticleTypePage> createState() => _ArticleTypePageState();
}

class _ArticleTypePageState extends ConsumerState<ArticleTypePage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // ============================================================
  // CHARTE THIX ID — Design Institutionnel Premium (Navy / Bleu / Or)
  // ============================================================
  static const Color navyDeep = Color(0xFF0A1F44);
  static const Color navy = Color(0xFF123B7A);
  static const Color primaryBlue = Color(0xFF2D6CDF);
  static const Color gold = Color(0xFFE3B23C);
  static const Color ivory = Color(0xFFF6F7FB);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color darkText = Color(0xFF10182B);
  static const Color mutedText = Color(0xFF6B7690);
  static const Color danger = Color(0xFFD64545);
  static const Color hairline = Color(0xFFE7EAF3);

  @override
  Widget build(BuildContext context) {
    final articlesAsync = ref.watch(articlesProvider(widget.type));

    return Scaffold(
      backgroundColor: ivory,
      appBar: _buildAppBar(),
      body: articlesAsync.when(
        loading: () => _buildLoadingState(),
        error: (err, stack) => _buildErrorState(err),
        data: (articles) {
          List<Article> filtered = articles;
          if (_searchQuery.isNotEmpty) {
            filtered = articles.where((a) =>
              a.title.toLowerCase().contains(_searchQuery) ||
              a.content.toLowerCase().contains(_searchQuery) ||
              (a.articleNumber?.toLowerCase().contains(_searchQuery) ?? false) ||
              (a.explanation?.toLowerCase().contains(_searchQuery) ?? false)
            ).toList();
          }
          if (filtered.isEmpty) {
            return _buildEmptyState();
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final article = filtered[i];
              return _buildArticleCard(article);
            },
          );
        },
      ),
    );
  }

  // ============================================================
  // APP BAR — dégradé navy + barre de recherche intégrée
  // ============================================================
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: navyDeep,
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [navyDeep, navy],
          ),
        ),
      ),
      title: Text(
        widget.title,
        style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: Colors.white),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
          child: Container(
            decoration: BoxDecoration(
              color: pureWhite,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: navyDeep.withOpacity(0.18), blurRadius: 12, offset: const Offset(0, 5))],
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 13, color: darkText, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Rechercher un article…',
                hintStyle: const TextStyle(color: mutedText, fontSize: 12.5, fontWeight: FontWeight.w500),
                prefixIcon: const Icon(Icons.search_rounded, color: navy, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18, color: mutedText),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ÉTAT CHARGEMENT
  // ============================================================
  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: primaryBlue),
          SizedBox(height: 16),
          Text('Chargement des articles…', style: TextStyle(color: mutedText, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ============================================================
  // ÉTAT ERREUR
  // ============================================================
  Widget _buildErrorState(Object err) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: danger.withOpacity(0.08), shape: BoxShape.circle),
            child: const Icon(Icons.error_outline_rounded, color: danger, size: 42),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Erreur : $err',
              textAlign: TextAlign.center,
              style: const TextStyle(color: mutedText, fontSize: 12.5, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ÉTAT VIDE
  // ============================================================
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(color: ivory, shape: BoxShape.circle),
            child: const Icon(Icons.search_off_rounded, size: 36, color: mutedText),
          ),
          const SizedBox(height: 16),
          const Text('Aucun article trouvé', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: darkText)),
          const SizedBox(height: 6),
          const Text(
            'Essayez un autre mot-clé',
            style: TextStyle(fontSize: 12, color: mutedText, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CARTE ARTICLE — institutionnelle, icône navy/or
  // ============================================================
  Widget _buildArticleCard(Article article) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ArticleDetailPage(articleId: article.id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: pureWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: hairline),
          boxShadow: [BoxShadow(color: navyDeep.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: navyDeep, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.article_rounded, color: gold, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.articleNumber != null
                        ? 'Article ${article.articleNumber} - ${article.title}'
                        : article.title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: darkText),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (article.chapter != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: ivory, borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        'Chapitre ${article.chapter}',
                        style: const TextStyle(fontSize: 10, color: navy, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: ivory, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: navy),
            ),
          ],
        ),
      ),
    );
  }
}
