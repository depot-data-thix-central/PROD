// lib/presentation/thix_info/article_detail_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/news_provider.dart';
import '../../models/news_article.dart';

class ArticleDetailPage extends HookConsumerWidget {
  final String articleId;
  const ArticleDetailPage({super.key, required this.articleId});

  static const Color _kGold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsNotifier = ref.read(newsProvider);

    // ─── Future pour charger l'article et son statut de sauvegarde ───
    useMemoized(() {
      newsNotifier.incrementViews(articleId);
    }, [articleId]);

    final articleFuture = useMemoized(() => newsNotifier.fetchArticleById(articleId), [articleId]);
    final articleSnapshot = useFuture(articleFuture);

    final savedFuture = useMemoized(() => newsNotifier.isArticleSaved(articleId), [articleId]);
    final savedSnapshot = useFuture(savedFuture);

    // État local réactif pour le bouton de favori
    final isSavedState = useState<bool>(false);
    
    // Met à jour l'état local dès que le futur de sauvegarde est résolu
    useEffect(() {
      if (savedSnapshot.hasData) {
        isSavedState.value = savedSnapshot.data ?? false;
      }
      return null;
    }, [savedSnapshot.data]);

    if (articleSnapshot.connectionState == ConnectionState.waiting) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: _kGold)),
      );
    }

    if (articleSnapshot.hasError || articleSnapshot.data == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              const Text('Impossible de charger l\'article', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(backgroundColor: _kGold, foregroundColor: Colors.black),
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      );
    }

    final article = articleSnapshot.data!;

    // ─── Actions ─────────────────────────────────────────────────
    Future<void> toggleSave() async {
      if (isSavedState.value) {
        await newsNotifier.unsaveArticle(articleId);
      } else {
        await newsNotifier.saveArticle(articleId);
      }
      isSavedState.value = !isSavedState.value;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isSavedState.value ? 'Article sauvegardé' : 'Retiré des favoris'), 
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    Future<void> shareArticle() async {
      await Share.share('${article.title}\n\n${article.summary ?? ''}\n\nLire plus sur THIX INFO');
    }

    // ─── UI Principale ───────────────────────────────────────────
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => context.canPop() ? context.pop() : context.go('/thix-info'),
        ),
        actions: [
          IconButton(
            icon: Icon(isSavedState.value ? Icons.bookmark : Icons.bookmark_border, color: _kGold),
            onPressed: toggleSave,
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.black87),
            onPressed: shareArticle,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article.imageUrl != null && article.imageUrl!.isNotEmpty)
              Image.network(
                article.imageUrl!,
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 220,
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator(color: _kGold)),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 220,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kGold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      article.category.toUpperCase(),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _kGold, letterSpacing: 0.5),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    article.title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.3, color: Color(0xFF10182B)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd MMM yyyy • HH:mm').format(article.publishedAt),
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.visibility, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        '${article.viewsCount} vues',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    article.content,
                    style: const TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF10182B)),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
