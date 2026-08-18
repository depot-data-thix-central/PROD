// lib/presentation/thix_info/category_articles_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:go_router/go_router.dart';

import '../../providers/news_provider.dart';
import '../../models/news_article.dart';

class CategoryArticlesPage extends ConsumerStatefulWidget {
  final String category;
  const CategoryArticlesPage({super.key, required this.category});

  @override
  ConsumerState<CategoryArticlesPage> createState() => _CategoryArticlesPageState();
}

class _CategoryArticlesPageState extends ConsumerState<CategoryArticlesPage> {
  List<NewsArticle> _articles = [];
  bool _isLoading = true;

  final Map<String, String> _categoryNames = {
    'featured': 'À la une',
    'politique': 'Politique',
    'economie': 'Économie',
    'societe': 'Société',
    'tech': 'Tech',
    'sport': 'Sport',
    'culture': 'Culture',
    'international': 'International',
  };

  @override
  void initState() {
    super.initState();
    _loadArticles();
  }

  Future<void> _loadArticles() async {
    // Utilisation de ref.read
    final provider = ref.read(newsProvider);
    final articles = await provider.fetchArticlesByCategory(widget.category);
    if (mounted) {
      setState(() {
        _articles = articles;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _categoryNames[widget.category] ?? widget.category,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _articles.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _articles.length,
                  itemBuilder: (context, index) => _buildArticleCard(_articles[index]),
                ),
    );
  }

  Widget _buildArticleCard(NewsArticle article) {
    return GestureDetector(
      onTap: () => context.push('/thix-info/article/${article.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4)],
        ),
        child: Row(
          children: [
            if (article.imageUrl != null && article.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  article.imageUrl!,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, size: 30, color: Colors.grey),
                  ),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(article.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 2),
                  const SizedBox(height: 6),
                  Text(
                    article.summary ?? '',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 10, color: Colors.grey[400]),
                      const SizedBox(width: 2),
                      Text(_formatTimeAgo(article.publishedAt), style: TextStyle(fontSize: 9, color: Colors.grey[400])),
                      const SizedBox(width: 12),
                      Icon(Icons.visibility, size: 10, color: Colors.grey[400]),
                      const SizedBox(width: 2),
                      Text(_formatCount(article.viewsCount), style: TextStyle(fontSize: 9, color: Colors.grey[400])),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Aucun article dans cette catégorie', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 1) return 'il y a ${diff.inDays}j';
    if (diff.inHours >= 1) return 'il y a ${diff.inHours}h';
    return 'il y a ${diff.inMinutes}min';
  }

  String _formatCount(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }
}
