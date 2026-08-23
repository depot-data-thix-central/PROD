// lib/presentation/thix_info/article_detail_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

// ✅ POLICY THIX APPLIQUÉE
import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../../providers/news_provider.dart';
import '../../models/news_article.dart';

class ArticleDetailPage extends HookConsumerWidget {
  final String articleId;
  const ArticleDetailPage({super.key, required this.articleId});

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

    // ─── ÉTAT : CHARGEMENT ───────────────────────────────────────
    if (articleSnapshot.connectionState == ConnectionState.waiting) {
      return const Scaffold(
        backgroundColor: ThixPolicy.inkDeep,
        body: Center(child: CircularProgressIndicator(color: ThixPolicy.gold)),
      );
    }

    // ─── ÉTAT : ERREUR ───────────────────────────────────────────
    if (articleSnapshot.hasError || articleSnapshot.data == null) {
      return Scaffold(
        backgroundColor: ThixPolicy.inkDeep,
        appBar: AppBar(
          backgroundColor: Colors.transparent, 
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => context.canPop() ? context.pop() : context.go('/thix-info'),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: ThixPolicy.danger.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.error_outline_rounded, size: 48, color: ThixPolicy.danger),
              ),
              const SizedBox(height: 20),
              Text('Impossible de charger l\'article', style: ThixPolicy.h3Style.copyWith(color: Colors.white)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd))),
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      );
    }

    final article = articleSnapshot.data!;

    // ─── ACTIONS ─────────────────────────────────────────────────
    Future<void> toggleSave() async {
      HapticFeedback.lightImpact();
      if (isSavedState.value) {
        await newsNotifier.unsaveArticle(articleId);
      } else {
        await newsNotifier.saveArticle(articleId);
      }
      isSavedState.value = !isSavedState.value;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ThixPolicy.card,
            content: Text(
              isSavedState.value ? 'Article sauvegardé' : 'Retiré des favoris', 
              style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMain, fontWeight: ThixPolicy.bold)
            ), 
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
          ),
        );
      }
    }

    Future<void> shareArticle() async {
      HapticFeedback.selectionClick();
      await Share.share('${article.title}\n\n${article.summary ?? ''}\n\nLire plus sur THIX INFO');
    }

    // ─── UI PRINCIPALE (IMMERSIVE LECTURE) ───────────────────────
    return Scaffold(
      backgroundColor: ThixPolicy.inkDeep,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. EN-TÊTE IMMERSIF (IMAGE + BOUTONS GLASS)
          SliverAppBar(
            backgroundColor: ThixPolicy.inkDeep,
            expandedHeight: 340.0,
            pinned: true,
            stretch: true,
            elevation: 0,
            leading: _buildGlassIconButton(
              icon: Icons.arrow_back_rounded, 
              onTap: () => context.canPop() ? context.pop() : context.go('/thix-info')
            ),
            actions: [
              _buildGlassIconButton(
                icon: isSavedState.value ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: isSavedState.value ? ThixPolicy.gold : Colors.white,
                onTap: toggleSave,
              ),
              const SizedBox(width: 8),
              _buildGlassIconButton(
                icon: Icons.share_outlined,
                onTap: shareArticle,
              ),
              const SizedBox(width: 16),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: article.imageUrl != null && article.imageUrl!.isNotEmpty
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          article.imageUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(color: ThixPolicy.surfaceStrong, child: const Center(child: CircularProgressIndicator(color: ThixPolicy.primary)));
                          },
                          errorBuilder: (context, error, stackTrace) => Container(color: ThixPolicy.surfaceStrong, child: const Icon(Icons.broken_image, size: 40, color: Colors.white24)),
                        ),
                        // Dégradé pour fondre l'image dans le fond de l'article
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [ThixPolicy.inkDeep, ThixPolicy.inkDeep.withOpacity(0.1), Colors.black54],
                              stops: const [0.0, 0.4, 1.0],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      color: ThixPolicy.primary.withOpacity(0.2),
                      child: const Center(child: Icon(Icons.article_rounded, size: 60, color: Colors.white24)),
                    ),
            ),
          ),
          
          // 2. CORPS DE L'ARTICLE
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s24, vertical: ThixPolicy.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Catégorie Premium
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s12, vertical: ThixPolicy.s6),
                    decoration: BoxDecoration(
                      color: ThixPolicy.gold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(ThixPolicy.rXs),
                      border: Border.all(color: ThixPolicy.gold.withOpacity(0.3)),
                    ),
                    child: Text(
                      article.category.toUpperCase(),
                      style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.gold, fontWeight: ThixPolicy.bold, letterSpacing: 1.0),
                    ),
                  ),
                  const SizedBox(height: ThixPolicy.s20),
                  
                  // Titre
                  Text(
                    article.title,
                    style: ThixPolicy.h1Style.copyWith(color: Colors.white, height: 1.25, letterSpacing: -0.5, fontSize: 26),
                  ),
                  const SizedBox(height: ThixPolicy.s20),
                  
                  // Méta Données (Date / Vues)
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 16, color: Colors.white54),
                      const SizedBox(width: ThixPolicy.s6),
                      Text(
                        DateFormat('dd MMM yyyy • HH:mm').format(article.publishedAt),
                        style: ThixPolicy.labelStyle.copyWith(color: Colors.white54),
                      ),
                      const SizedBox(width: ThixPolicy.s24),
                      const Icon(Icons.visibility_rounded, size: 16, color: Colors.white54),
                      const SizedBox(width: ThixPolicy.s6),
                      Text(
                        '${article.viewsCount} vues',
                        style: ThixPolicy.labelStyle.copyWith(color: Colors.white54),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: ThixPolicy.s32),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: ThixPolicy.s32),
                  
                  // Résumé (si existant)
                  if (article.summary != null && article.summary!.isNotEmpty) ...[
                    Text(
                      article.summary!,
                      style: ThixPolicy.h3Style.copyWith(color: Colors.white, height: 1.5, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: ThixPolicy.s24),
                  ],

                  // Contenu texte (Aéré pour une lecture agréable)
                  Text(
                    article.content,
                    style: ThixPolicy.bodyStyle.copyWith(
                      color: Colors.white.withOpacity(0.85), 
                      fontSize: 16,
                      height: 1.8, // Ligne aérée pour le confort de lecture
                    ),
                  ),
                  
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Composant local pour les boutons flottants sur l'image
  Widget _buildGlassIconButton({required IconData icon, required VoidCallback onTap, Color color = Colors.white}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ThixPolicy.rFull),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}
