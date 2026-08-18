// lib/presentation/thix_info/widgets/news_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../models/news_article.dart';

class NewsCard extends StatelessWidget {
  final NewsArticle article;
  final bool showCategory;
  final bool isCompact;
  final VoidCallback? onSave;
  final bool isSaved;

  const NewsCard({
    super.key,
    required this.article,
    this.showCategory = true,
    this.isCompact = false,
    this.onSave,
    this.isSaved = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return _buildCompactCard(context);
    }
    return _buildStandardCard(context);
  }

  Widget _buildStandardCard(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/thix-info/article/${article.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article.imageUrl != null && article.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  article.imageUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 180,
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 180,
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showCategory)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getCategoryName(article.category),
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFFD4AF37)),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    article.title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, height: 1.3),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    article.summary ?? '',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(_formatTimeAgo(article.publishedAt), style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                      const SizedBox(width: 12),
                      Icon(Icons.visibility, size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(_formatCount(article.viewsCount), style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                      const Spacer(),
                      if (onSave != null)
                        IconButton(
                          icon: Icon(
                            isSaved ? Icons.bookmark : Icons.bookmark_border,
                            size: 18,
                            color: const Color(0xFFD4AF37),
                          ),
                          onPressed: onSave,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
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

  Widget _buildCompactCard(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/thix-info/article/${article.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)],
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
                  if (showCategory)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getCategoryName(article.category),
                        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: Color(0xFFD4AF37)),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    article.title,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 10, color: Colors.grey[400]),
                      const SizedBox(width: 2),
                      Text(_formatTimeAgo(article.publishedAt), style: TextStyle(fontSize: 9, color: Colors.grey[400])),
                      const SizedBox(width: 8),
                      Icon(Icons.visibility, size: 10, color: Colors.grey[400]),
                      const SizedBox(width: 2),
                      Text(_formatCount(article.viewsCount), style: TextStyle(fontSize: 9, color: Colors.grey[400])),
                    ],
                  ),
                ],
              ),
            ),
            if (onSave != null)
              IconButton(
                icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border, size: 18, color: const Color(0xFFD4AF37)),
                onPressed: onSave,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
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
