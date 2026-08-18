// lib/presentation/thix_info/widgets/breaking_news.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../models/news_article.dart';

class BreakingNewsWidget extends StatelessWidget {
  final NewsArticle article;

  const BreakingNewsWidget({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/thix-info/article/${article.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B1B3D), Color(0xFF1A2B4D)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article.imageUrl != null && article.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  article.imageUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 180,
                      color: Colors.grey[800],
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 180,
                    color: Colors.grey[800],
                    child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.flash_on, size: 12, color: Colors.red),
                            SizedBox(width: 4),
                            Text('À LA UNE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getCategoryName(article.category),
                          style: const TextStyle(fontSize: 9, color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    article.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, height: 1.3),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    article.summary ?? '',
                    style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 12, color: Colors.white54),
                      const SizedBox(width: 4),
                      Text(_formatTimeAgo(article.publishedAt), style: TextStyle(fontSize: 10, color: Colors.white54)),
                      const SizedBox(width: 16),
                      Icon(Icons.visibility, size: 12, color: Colors.white54),
                      const SizedBox(width: 4),
                      Text(_formatCount(article.viewsCount), style: TextStyle(fontSize: 10, color: Colors.white54)),
                      const Spacer(),
                      const Row(
                        children: [
                          Text('Lire l\'article', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFD4AF37))),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 12, color: Color(0xFFD4AF37)),
                        ],
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
  }

  String _getCategoryName(String slug) {
    const names = {
      'featured': 'À la une',
      'politique': 'Politique',
      'economie': 'Économie',
      'societe': 'Société',
      'tech': 'Tech',
      'sport': 'Sport',
      'culture': 'Culture',
      'international': 'International',
    };
    return names[slug] ?? slug;
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 1) return 'il y a ${diff.inDays}j';
    if (diff.inHours >= 1) return 'il y a ${diff.inHours}h';
    if (diff.inMinutes >= 1) return 'il y a ${diff.inMinutes}min';
    return 'maintenant';
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }
}
