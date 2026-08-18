// lib/presentation/mon_pays/providers/news_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ Nouvel import corrigé
import '../models/news_article.dart';

class NewsService {
  final SupabaseClient _client = Supabase.instance.client;

  // Récupérer les articles
  Future<List<NewsArticle>> fetchNews() async {
    final response = await _client
        .from('news_articles')
        .select()
        .order('published_at', ascending: false);

    return (response as List<dynamic>)
        .map((e) => NewsArticle.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Sauvegarder (Créer ou Mettre à jour)
  Future<void> saveNews(NewsArticle article) async {
    final data = article.toJson();
    
    if (article.id.isEmpty) {
      // Création (on retire l'ID vide pour que Supabase génère un UUID)
      data.remove('id');
      await _client.from('news_articles').insert(data);
    } else {
      // Mise à jour
      await _client.from('news_articles').update(data).eq('id', article.id);
    }
  }

  // Supprimer
  Future<void> deleteNews(String id) async {
    await _client.from('news_articles').delete().eq('id', id);
  }
}

final newsServiceProvider = Provider<NewsService>((ref) => NewsService());

final newsProvider = FutureProvider<List<NewsArticle>>((ref) async {
  final service = ref.read(newsServiceProvider);
  return await service.fetchNews();
});
