// lib/presentation/mon_pays/services/articles_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/article.dart';

class ArticlesService {
  final SupabaseClient _client = Supabase.instance.client;

  // Récupérer les articles (publics ou admin)
  Future<List<Article>> getArticles({
    ArticleType? type,
    bool? publishedOnly = true,
    String? search,
  }) async {
    try {
      var query = _client.from('articles').select('*');
      
      if (publishedOnly == true) {
        query = query.eq('is_published', true);
      }
      
      if (type != null) {
        query = query.eq('type', type.toString().split('.').last);
      }
      
      if (search != null && search.trim().isNotEmpty) {
        query = query.or('title.ilike.%$search%,content.ilike.%$search%');
      }
      
      final response = await query.order('type').order('article_number', ascending: true);
      return response.map((json) => Article.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Erreur lors du chargement des articles: $e');
    }
  }

  Future<Article> getArticleById(String id) async {
    try {
      final response = await _client
          .from('articles')
          .select('*')
          .eq('id', id)
          .single();
      return Article.fromJson(response);
    } catch (e) {
      throw Exception('Erreur lors du chargement de l\'article: $e');
    }
  }

  Future<Article> createArticle(Article article) async {
    try {
      // 1. On récupère les données
      final articleData = article.toJson();
      
      // 2. CORRECTION : On supprime l'ID s'il est vide pour laisser Supabase le générer
      if (articleData['id'] == null || articleData['id'] == '') {
        articleData.remove('id');
      }

      // 3. On insère les données nettoyées
      final response = await _client
          .from('articles')
          .insert(articleData)
          .select()
          .single();
      return Article.fromJson(response);
    } catch (e) {
      throw Exception('Erreur lors de la création: $e');
    }
  }

  Future<Article> updateArticle(Article article) async {
    try {
      final response = await _client
          .from('articles')
          .update(article.toJson())
          .eq('id', article.id)
          .select()
          .single();
      return Article.fromJson(response);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour: $e');
    }
  }

  Future<void> deleteArticle(String id) async {
    try {
      await _client.from('articles').delete().eq('id', id);
    } catch (e) {
      throw Exception('Erreur lors de la suppression: $e');
    }
  }

  Future<void> publishArticle(String id) async {
    try {
      await _client
          .from('articles')
          .update({
            'is_published': true,
            'published_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
    } catch (e) {
      throw Exception('Erreur lors de la publication: $e');
    }
  }

  Future<void> unpublishArticle(String id) async {
    try {
      await _client
          .from('articles')
          .update({
            'is_published': false,
            'published_at': null,
          })
          .eq('id', id);
    } catch (e) {
      throw Exception('Erreur lors du dépublication: $e');
    }
  }
}
