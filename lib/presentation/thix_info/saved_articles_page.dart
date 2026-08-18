// lib/presentation/thix_info/saved_articles_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 1. Import de Riverpod
import 'package:go_router/go_router.dart';

import '../../providers/news_provider.dart';
import '../../models/news_article.dart';

// 2. Remplacement par ConsumerStatefulWidget
class SavedArticlesPage extends ConsumerStatefulWidget {
  const SavedArticlesPage({super.key});

  @override
  ConsumerState<SavedArticlesPage> createState() => _SavedArticlesPageState();
}

class _SavedArticlesPageState extends ConsumerState<SavedArticlesPage> {
  List<NewsArticle> _savedArticles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedArticles();
  }

  Future<void> _loadSavedArticles() async {
    // 3. Utilisation de ref.read au lieu de context.read
    final provider = ref.read(newsProvider);
    final articles = await provider.getSavedArticlesList();
    
    if (!mounted) return; // Sécurité Riverpod
    
    setState(() {
      _savedArticles = articles;
      _isLoading = false;
    });
  }

  Future<void> _removeArticle(String articleId) async {
    // Utilisation de ref.read
    final provider = ref.read(newsProvider);
    await provider.unsaveArticle(articleId);
    
    if (!mounted) return; // Sécurité
    
    setState(() {
      _savedArticles.removeWhere((a) => a.id == articleId);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Article retiré des favoris'), duration: Duration(seconds: 1)),
    );
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
        title: const Text(
          'Mes favoris',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savedArticles.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _savedArticles.length,
                  itemBuilder: (context, index) => _buildSavedCard(_savedArticles[index]),
                ),
    );
  }

  Widget _buildSavedCard(NewsArticle article) {
    return GestureDetector(
      onTap: () => context.push('/thix-info/article/${article.id}').then((_) => _loadSavedArticles()),
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
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: 70,
                      height: 70,
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 70,
                    height: 70,
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, size: 30, color: Colors.grey),
                  ),
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(article.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 2),
                  const SizedBox(height: 4),
                  Text(
                    article.summary ?? '',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimeAgo(article.publishedAt),
                    style: TextStyle(fontSize: 9, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.bookmark, color: Color(0xFFD4AF37), size: 20),
              onPressed: () => _removeArticle(article.id),
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
          Icon(Icons.bookmark_border, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Aucun favori', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('Sauvegardez vos articles préférés', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
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
}
