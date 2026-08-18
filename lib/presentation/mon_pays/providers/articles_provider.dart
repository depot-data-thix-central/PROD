// lib/presentation/mon_pays/providers/articles_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/article.dart';
import '../services/articles_service.dart';

final articlesServiceProvider = Provider((ref) => ArticlesService());

// Liste publique par type (publiés uniquement)
final articlesProvider = FutureProvider.family<List<Article>, ArticleType?>((ref, type) async {
  final service = ref.watch(articlesServiceProvider);
  return service.getArticles(type: type, publishedOnly: true);
});

// Recherche publique
final searchArticlesProvider = FutureProvider.family<List<Article>, String>((ref, query) async {
  final service = ref.watch(articlesServiceProvider);
  // CORRECTION ICI : Utilisation de getArticles avec le paramètre search
  return service.getArticles(search: query);
});

// Détail d'un article
final articleDetailProvider = FutureProvider.family<Article, String>((ref, id) async {
  final service = ref.watch(articlesServiceProvider);
  return service.getArticleById(id);
});

// ADMIN : tous les articles (publiés + brouillons)
final adminArticlesProvider = StateNotifierProvider<AdminArticlesNotifier, AsyncValue<List<Article>>>((ref) {
  return AdminArticlesNotifier(ref);
});

class AdminArticlesNotifier extends StateNotifier<AsyncValue<List<Article>>> {
  final Ref _ref;

  AdminArticlesNotifier(this._ref) : super(const AsyncValue.loading()) {
    loadArticles();
  }

  Future<void> loadArticles({ArticleType? type, String? search}) async {
    state = const AsyncValue.loading();
    try {
      final service = _ref.read(articlesServiceProvider);
      final list = await service.getArticles(
        type: type,
        publishedOnly: false,
        search: search,
      );
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> createArticle(Article article) async {
    try {
      final service = _ref.read(articlesServiceProvider);
      await service.createArticle(article);
      await loadArticles();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateArticle(Article article) async {
    try {
      final service = _ref.read(articlesServiceProvider);
      await service.updateArticle(article);
      await loadArticles();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteArticle(String id) async {
    try {
      final service = _ref.read(articlesServiceProvider);
      await service.deleteArticle(id);
      await loadArticles();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> publishArticle(String id) async {
    try {
      final service = _ref.read(articlesServiceProvider);
      await service.publishArticle(id);
      await loadArticles();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> unpublishArticle(String id) async {
    try {
      final service = _ref.read(articlesServiceProvider);
      await service.unpublishArticle(id);
      await loadArticles();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
