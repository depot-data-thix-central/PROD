// lib/presentation/mon_pays/pages/news/news_detail_page.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../../models/news_article.dart';

class NewsDetailPage extends StatelessWidget {
  final NewsArticle article;

  const NewsDetailPage({super.key, required this.article});

  // Couleurs institutionnelles
  static const Color instBlue = Color(0xFF0A1F44);
  static const Color instYellow = Color(0xFFFFD100);

  @override
  Widget build(BuildContext context) {
    final dateStr = article.publishedAt != null 
        ? DateFormat('dd MMMM yyyy', 'fr_FR').format(article.publishedAt!) 
        : '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: instBlue),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: Container(color: instYellow, height: 4),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE DE COUVERTURE
            if (article.coverImageUrl != null && article.coverImageUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: article.coverImageUrl!,
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(height: 250, color: Colors.grey.shade200),
                errorWidget: (context, url, error) => Container(height: 250, color: Colors.grey.shade200),
              ),
              
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // CATÉGORIE & DATE
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: instBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          article.category.toUpperCase(),
                          style: const TextStyle(color: instBlue, fontWeight: FontWeight.bold, fontSize: 10),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // TITRE
                  Text(
                    article.title,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: instBlue, height: 1.3),
                  ),
                  const SizedBox(height: 16),
                  
                  // RÉSUMÉ (Si existant)
                  if (article.summary != null && article.summary!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.only(left: 12),
                      decoration: const BoxDecoration(
                        border: Border(left: BorderSide(color: instYellow, width: 4)),
                      ),
                      child: Text(
                        article.summary!,
                        style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey.shade700, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // CONTENU
                  Text(
                    article.content,
                    style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.6),
                  ),
                  const SizedBox(height: 40),

                  // AUTEUR
                  if (article.author != null && article.author!.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.edit_note, color: Colors.grey, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Publié par : ${article.author}',
                          style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
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
}
