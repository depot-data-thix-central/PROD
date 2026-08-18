// lib/presentation/thix_info/breaking_news_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 1. Import de Riverpod
import 'package:go_router/go_router.dart';

import '../../providers/news_provider.dart';
import '../../models/news_article.dart';

// 2. Remplacement par ConsumerStatefulWidget
class BreakingNewsPage extends ConsumerStatefulWidget {
  const BreakingNewsPage({super.key});

  @override
  ConsumerState<BreakingNewsPage> createState() => _BreakingNewsPageState();
}

class _BreakingNewsPageState extends ConsumerState<BreakingNewsPage> {
  List<NewsArticle> _breakingNews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBreakingNews();
  }

  Future<void> _loadBreakingNews() async {
    // 3. Utilisation de ref.read au lieu de context.read
    final provider = ref.read(newsProvider);
    final articles = await provider.fetchBreakingNews();
    
    if (!mounted) return; // 4. Sécurité Riverpod
    
    setState(() {
      _breakingNews = articles;
      _isLoading = false;
    });
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
        title: const Row(
          children: [
            Icon(Icons.flash_on, color: Color(0xFFD4AF37), size: 22),
            SizedBox(width: 6),
            Text('Fil Info', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _breakingNews.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _breakingNews.length,
                  itemBuilder: (context, index) => _buildBreakingCard(_breakingNews[index]),
                ),
    );
  }

  Widget _buildBreakingCard(NewsArticle article) {
    return GestureDetector(
      onTap: () => context.push('/thix-info/article/${article.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: const Border(left: BorderSide(color: Color(0xFFD4AF37), width: 4)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flash_on, size: 12, color: Colors.red),
                      SizedBox(width: 2),
                      Text('EN DIRECT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.red)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(_formatTimeAgo(article.publishedAt), style: TextStyle(fontSize: 9, color: Colors.grey[500])),
              ],
            ),
            const SizedBox(height: 8),
            Text(article.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), maxLines: 3),
            const SizedBox(height: 6),
            Text(article.summary ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[600]), maxLines: 2),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.visibility, size: 12, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(_formatCount(article.viewsCount), style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                const Spacer(),
                const Text('Lire l\'article →', style: TextStyle(fontSize: 11, color: Color(0xFFD4AF37), fontWeight: FontWeight.w500)),
              ],
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
          Icon(Icons.flash_off, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Aucune info en direct', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('Revenez plus tard pour les actualités chaudes', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
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
