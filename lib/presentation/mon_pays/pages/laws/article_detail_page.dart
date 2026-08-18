// lib/presentation/mon_pays/pages/laws/article_detail_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';       // 👈 INDISPENSABLE pour useState
import 'package:hooks_riverpod/hooks_riverpod.dart';   // 👈 INDISPENSABLE pour HookConsumerWidget et WidgetRef
import '../../models/article.dart';
import '../../providers/articles_provider.dart';

class ArticleDetailPage extends HookConsumerWidget {   // 👈 Utilisation de HookConsumerWidget
  final String articleId;

  const ArticleDetailPage({required this.articleId, super.key});

  static const Color navyDeep = Color(0xFF0A1F44);
  static const Color navy = Color(0xFF123B7A);
  static const Color primaryBlue = Color(0xFF2D6CDF);
  static const Color gold = Color(0xFFE3B23C);
  static const Color ivory = Color(0xFFF6F7FB);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color darkText = Color(0xFF10182B);
  static const Color mutedText = Color(0xFF6B7690);
  static const Color success = Color(0xFF1FA971);
  static const Color danger = Color(0xFFD64545);
  static const Color hairline = Color(0xFFE7EAF3);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articleAsync = ref.watch(articleDetailProvider(articleId));

    // HOOKS : Gestion de l'état des langues pour chaque section indépendamment
    final selectedLangContent = useState<String>('FR');
    final selectedLangExplanation = useState<String>('FR');

    return Scaffold(
      backgroundColor: ivory,
      appBar: _buildAppBar(),
      body: articleAsync.when(
        loading: () => _buildLoadingState(),
        error: (error, stack) => _buildErrorState(context, ref, error),
        data: (article) => _buildContent(
          context, 
          article, 
          selectedLangContent, 
          selectedLangExplanation,
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: navyDeep,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [navyDeep, navy],
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: gold.withOpacity(0.5)),
            ),
            child: const Icon(Icons.article_rounded, size: 15, color: gold),
          ),
          const SizedBox(width: 10),
          const Text('Article', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: primaryBlue),
          SizedBox(height: 16),
          Text(
            "Chargement de l'article…",
            style: TextStyle(color: mutedText, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
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
              'Erreur : ${error.toString()}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: mutedText, fontSize: 12.5, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 18),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => ref.invalidate(articleDetailProvider(articleId)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [navyDeep, navy]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, size: 16, color: gold),
                  SizedBox(width: 8),
                  Text('Réessayer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, 
    Article article,
    ValueNotifier<String> contentLang,
    ValueNotifier<String> expLang,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [navyDeep, navy],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: navyDeep.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 8))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article.title,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white, height: 1.3),
                ),
                if (article.chapter != null || article.articleNumber != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (article.chapter != null)
                        _headerBadge(Icons.menu_book_rounded, 'Chapitre ${article.chapter}'),
                      if (article.articleNumber != null)
                        _headerBadge(Icons.tag_rounded, 'Article ${article.articleNumber}'),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: pureWhite,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: hairline),
              boxShadow: [BoxShadow(color: navyDeep.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 18,
                          decoration: BoxDecoration(color: primaryBlue, borderRadius: BorderRadius.circular(3)),
                        ),
                        const SizedBox(width: 8),
                        const Text('Détail', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: darkText)),
                      ],
                    ),
                    _buildLanguageSelector(contentLang),
                  ],
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _getLocalizedText(article.content, contentLang.value, 'ce contenu', article),
                    key: ValueKey<String>(contentLang.value),
                    style: const TextStyle(fontSize: 14.5, height: 1.65, color: darkText, fontWeight: FontWeight.w400),
                  ),
                ),
              ],
            ),
          ),

          if (article.explanation != null && article.explanation!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: gold.withOpacity(0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: gold.withOpacity(0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: navyDeep, borderRadius: BorderRadius.circular(9)),
                            child: const Icon(Icons.lightbulb_outline_rounded, size: 15, color: gold),
                          ),
                          const SizedBox(width: 9),
                          const Text('Explication', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: navyDeep)),
                        ],
                      ),
                      _buildLanguageSelector(expLang, isGoldTheme: true),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _getLocalizedText(article.explanation!, expLang.value, 'cette explication', article),
                      key: ValueKey<String>('exp_${expLang.value}'),
                      style: const TextStyle(fontSize: 14.0, height: 1.6, color: darkText, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: pureWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: hairline),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: (article.isPublished ? success : gold).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        article.isPublished ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                        color: article.isPublished ? success : gold,
                        size: 13,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        article.isPublished ? 'Publié' : 'Brouillon',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: article.isPublished ? success : const Color(0xFFB8860B),
                        ),
                      ),
                    ],
                  ),
                ),
                if (article.publishedAt != null) ...[
                  const SizedBox(width: 10),
                  const Icon(Icons.calendar_today_rounded, size: 13, color: mutedText),
                  const SizedBox(width: 6),
                  Text(
                    'Publié le ${_formatDate(article.publishedAt!)}',
                    style: const TextStyle(fontSize: 11, color: mutedText, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector(ValueNotifier<String> selectedLang, {bool isGoldTheme = false}) {
    final activeBgColor = isGoldTheme ? navyDeep : primaryBlue;
    final activeTextColor = isGoldTheme ? gold : pureWhite;
    final inactiveBgColor = isGoldTheme ? gold.withOpacity(0.2) : hairline;

    return Container(
      decoration: BoxDecoration(
        color: inactiveBgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['FR', 'LN', 'SW'].map((lang) {
          final isSelected = selectedLang.value == lang;
          return GestureDetector(
            onTap: () => selectedLang.value = lang,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? activeBgColor : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                lang,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: isSelected ? activeTextColor : (isGoldTheme ? navyDeep : mutedText),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _headerBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: gold),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _getLocalizedText(String originalFr, String lang, String sectionName, Article article) {
    if (lang == 'FR') return originalFr;
    if (lang == 'LN') {
      return 'Traduction en Lingala pour $sectionName en cours de préparation par l\'administration...';
    }
    if (lang == 'SW') {
      return 'Traduction en Swahili pour $sectionName en cours de préparation par l\'administration...';
    }
    return originalFr;
  }
}
