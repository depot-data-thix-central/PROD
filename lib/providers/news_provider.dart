import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 1. L'import Riverpod

import '../services/news_service.dart';
import '../models/news_article.dart';
import '../supabase/supabase_config.dart'; // Importe ton client Supabase (ajuste le chemin si besoin)

// 2. Le lien Riverpod vers ton service (Accès aux données)
final newsServiceProvider = Provider<NewsService>((ref) {
  return NewsService(SupabaseConfig.client);
});

// 3. Le lien Riverpod vers ta classe (Gestion d'état)
final newsProvider = ChangeNotifierProvider<NewsProvider>((ref) {
  final service = ref.read(newsServiceProvider);
  return NewsProvider(service);
});

// ==========================================================
// TA CLASSE ORIGINALE (AUCUNE MODIFICATION DANS LA LOGIQUE)
// ==========================================================
class NewsProvider extends ChangeNotifier {
  final NewsService _newsService;
  List<NewsArticle> _articles=[];
  List<NewsArticle> _videos=[];
  List<NewsArticle> _saved=[];
  bool _isLoading=false;
  String? _error;
  String _currentCategory='featured';

  NewsProvider(this._newsService);

  List<NewsArticle> get articles=>_articles;
  List<NewsArticle> get videos=>_videos;
  List<NewsArticle> get savedArticles=>_saved;
  bool get isLoading=>_isLoading;
  String? get error=>_error;
  String get currentCategory=>_currentCategory;

  NewsArticle? get featuredArticle {
    final f=_articles.where((a)=>a.isFeatured).toList();
    if(f.isNotEmpty) return f.first;
    if(_articles.isNotEmpty) return _articles.first;
    return null;
  }
  List<NewsArticle> get recentArticles => _articles.where((a)=>!a.isFeatured).take(10).toList();

  Future<void> fetchArticles({String? category}) async {
    _isLoading=true; _error=null; notifyListeners();
    try{
      final cat=category??_currentCategory;
      _currentCategory=cat;
      _articles=await _newsService.getArticles(category:cat);
    }catch(e){ _error=e.toString(); debugPrint('❌ fetchArticles $e');}
    finally{ _isLoading=false; notifyListeners(); }
  }

  Future<void> fetchVideos() async { try{ _videos=await _newsService.getVideos(); notifyListeners(); }catch(e){debugPrint('fetchVideos $e');} }
  Future<NewsArticle?> fetchArticleById(String id) async { try{ return await _newsService.getArticleById(id);}catch(e){return null;}}

  // === METHODES MANQUANTES QUI FAISAIENT PLANTER LE BUILD ===
  Future<List<NewsArticle>> fetchArticlesByCategory(String category) async {
    try{ return await _newsService.getArticles(category: category); }catch(e){ return []; }
  }
  Future<List<NewsArticle>> fetchBreakingNews() async {
    try{ return await _newsService.getBreakingNews(); }catch(e){ return []; }
  }
  Future<List<NewsArticle>> searchArticles(String query) async {
    try{ return await _newsService.searchArticles(query); }catch(e){ return []; }
  }
  // ==========================================================

  Future<void> incrementViews(String id) async => await _newsService.incrementViews(id);
  Future<void> toggleLike(String id) async {
    final i=_articles.indexWhere((a)=>a.id==id);
    if(i!=-1){ final a=_articles[i]; if(a.isLiked){ await _newsService.unlikeArticle(id); _articles[i]=a.copyWith(isLiked:false);} else { await _newsService.likeArticle(id); _articles[i]=a.copyWith(isLiked:true);} notifyListeners(); }
  }
  Future<void> saveArticle(String id) async { await _newsService.saveArticle(id); _saved=await _newsService.getSavedArticles(); notifyListeners();}
  Future<void> unsaveArticle(String id) async { await _newsService.unsaveArticle(id); _saved=await _newsService.getSavedArticles(); notifyListeners();}
  Future<void> loadSavedArticles() async { _saved=await _newsService.getSavedArticles(); notifyListeners();}
  Future<List<NewsArticle>> getSavedArticlesList() async => await _newsService.getSavedArticles();
  Future<bool> isArticleSaved(String id) async => (await getSavedArticlesList()).any((a)=>a.id==id);

  Future<NewsArticle?> createArticle({required String title,String? summary,required String content,required String category,String? imageUrl,String? videoUrl,bool isFeatured=false,bool isBreaking=false}) async {
    try{ final a=await _newsService.createArticle(title:title,summary:summary,content:content,category:category,imageUrl:imageUrl,videoUrl:videoUrl,isFeatured:isFeatured,isBreaking:isBreaking); await fetchArticles(); return a; }catch(e){debugPrint('create $e'); return null;}
  }
  Future<void> updateArticle(String id, Map<String,dynamic> d) async { await _newsService.updateArticle(id,d); await fetchArticles(); }
  Future<void> deleteArticle(String id) async { await _newsService.deleteArticle(id); await fetchArticles(); }

  // UPLOAD FIX WEB
  Future<String?> uploadImageBytes(Uint8List bytes, String name) async => await _newsService.uploadImageBytes(bytes,name);
  Future<String?> uploadVideoBytes(Uint8List bytes, String name) async => await _newsService.uploadVideoBytes(bytes,name);
  @Deprecated('Use uploadImageBytes on Web')
  Future<String?> uploadImage(String p) async => null;
  @Deprecated('Use uploadVideoBytes on Web')
  Future<String?> uploadVideo(String p) async => null;

  void setCategory(String c){ if(_currentCategory==c) return; _currentCategory=c; fetchArticles(category:c); }
  void clearError(){ _error=null; notifyListeners(); }
  void refresh(){ fetchArticles(); fetchVideos(); loadSavedArticles(); }
}
