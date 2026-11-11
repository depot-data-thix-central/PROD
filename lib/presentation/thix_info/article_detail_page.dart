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

// ── Tokens clair (identiques à la Homepage) ──
const Color _kBg = Color(0xFFF6F7F9);
const Color _kCard = Colors.white;
const Color _kInk = Color(0xFF0F172A);
const Color _kMuted = Color(0xFF64748B);
const Color _kGold = Color(0xFFFFC107);
const Color _kGoldDark = Color(0xFFD4AF37);
const Color _kBorder = Color(0xFFE2E8F0);

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
        backgroundColor: _kBg, // ✅ Fond clair
        body: Center(child: CircularProgressIndicator(color: _kGoldDark)), // ✅ Loader doré
      );
    }

    // ─── ÉTAT : ERREUR ───────────────────────────────────────────
    if (articleSnapshot.hasError || articleSnapshot.data == null) {
      return Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent, 
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: _kInk), // ✅ Icône sombre
            onPressed: () => context.canPop() ? context.pop() : context.go('/thix-info'),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
              ),
              const SizedBox(height: 20),
              Text('Impossible de charger l\'article', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kInk)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGold, 
                  foregroundColor: _kInk, 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd))
                ),
                child: const Text('Retour', style: TextStyle(fontWeight: FontWeight.bold)),
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
            backgroundColor: _kInk, // ✅ Snackbar sombre sur fond clair
            content: Text(
              isSavedState.value ? 'Article sauvegardé' : 'Retiré des favoris', 
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
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

    // ─── UI PRINCIPALE (IMMERSIVE LECTURE CLAIRE) ───────────────────────
    return Scaffold(
      backgroundColor: _kBg, // ✅ Fond clair global
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. EN-TÊTE IMMERSIF (IMAGE + BOUTONS GLASS)
          SliverAppBar(
            backgroundColor: _kBg, // ✅ Fond clair
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
                color: isSavedState.value ? _kGold : Colors.white,
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
                            return Container(color: _kBorder, child: const Center(child: CircularProgressIndicator(color: _kGoldDark)));
                          },
                          errorBuilder: (context, error, stackTrace) => Container(color: _kBorder, child: const Icon(Icons.broken_image, size: 40, color: _kMuted)),
                        ),
                        // ✅ Dégradé adapté pour fondre l'image dans le fond CLAIR (gris/blanc)
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                _kBg, // Se fond dans le fond de la page
                                _kBg.withOpacity(0.1), 
                                Colors.black54 // Garde le haut de l'image lisible pour les boutons
                              ],
                              stops: const [0.0, 0.4, 1.0],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      color: _kGold.withOpacity(0.2),
                      child: const Center(child: Icon(Icons.article_rounded, size: 60, color: _kGoldDark)),
                    ),
            ),
          ),
          
          // 2. CORPS DE L'ARTICLE
          SliverToBoxAdapter(
            child: Container(
              color: _kBg, // ✅ Assure la continuité du fond clair
              padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s24, vertical: ThixPolicy.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Catégorie Premium (Badge Doré clair)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s12, vertical: ThixPolicy.s6),
                    decoration: BoxDecoration(
                      color: _kGold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(ThixPolicy.rXs),
                      border: Border.all(color: _kGold.withOpacity(0.4)),
                    ),
                    child: Text(
                      article.category.toUpperCase(),
                      style: ThixPolicy.microStyle.copyWith(color: _kGoldDark, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                    ),
                  ),
                  const SizedBox(height: ThixPolicy.s20),
                  
                  // Titre (Sombre)
                  Text(
                    article.title,
                    style: ThixPolicy.h1Style.copyWith(color: _kInk, height: 1.25, letterSpacing: -0.5, fontSize: 26),
                  ),
                  const SizedBox(height: ThixPolicy.s20),
                  
                  // Méta Données (Date / Vues) (Gris)
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 16, color: _kMuted),
                      const SizedBox(width: ThixPolicy.s6),
                      Text(
                        DateFormat('dd MMM yyyy • HH:mm').format(article.publishedAt),
                        style: ThixPolicy.labelStyle.copyWith(color: _kMuted, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: ThixPolicy.s24),
                      const Icon(Icons.visibility_rounded, size: 16, color: _kMuted),
                      const SizedBox(width: ThixPolicy.s6),
                      Text(
                        '${article.viewsCount} vues',
                        style: ThixPolicy.labelStyle.copyWith(color: _kMuted, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: ThixPolicy.s32),
                  const Divider(color: _kBorder, height: 1), // ✅ Ligne de séparation claire
                  const SizedBox(height: ThixPolicy.s32),
                  
                  // Résumé (Si existant)
                  if (article.summary != null && article.summary!.isNotEmpty) ...[
                    Text(
                      article.summary!,
                      style: ThixPolicy.h3Style.copyWith(color: _kInk, height: 1.5, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: ThixPolicy.s24),
                  ],

                  // Contenu texte (Lecture confortable sur fond clair)
                  Text(
                    article.content,
                    style: ThixPolicy.bodyStyle.copyWith(
                      color: _kInk.withOpacity(0.85), 
                      fontSize: 16,
                      height: 1.8, // Ligne aérée
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
  // ✅ On garde un fond noir translucide (Glass) car les boutons sont sur l'image, 
  // ce qui garantit leur lisibilité peu importe la couleur de la photo.
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
                color: Colors.black.withOpacity(0.4), // Légèrement plus sombre pour le contraste
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}
