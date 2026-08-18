import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/news_article.dart';

class NewsService {
  final SupabaseClient _supabase;
  NewsService(this._supabase);
  String get currentUserId => _supabase.auth.currentUser?.id ?? '';

  Future<List<NewsArticle>> getArticles({String? category,int limit=50,bool onlyPublished=true}) async {
    try {
      final response = await _supabase.from('news_articles').select('*').order('published_at',ascending:false);
      List<dynamic> results = response as List;
      if(onlyPublished) results = results.where((e)=>e['is_published']==true).toList();
      if(category!=null && category.isNotEmpty && category!='all' && category!='featured'){ results = results.where((e)=>e['category']==category).toList(); }
      if(category=='featured'){ results = results.where((e)=>e['is_featured']==true).toList(); }
      results = results.take(limit).toList();
      return results.map((e)=>NewsArticle.fromJson(e)).toList();
    } catch(e){ debugPrint('❌ getArticles $e'); return []; }
  }

  Future<NewsArticle?> getArticleById(String id) async {
    try{ final r=await _supabase.from('news_articles').select('*').eq('id',id).maybeSingle(); if(r==null) return null; return NewsArticle.fromJson(r); }catch(e){return null;}
  }
  Future<List<NewsArticle>> getBreakingNews() async { try{ final r=await _supabase.from('news_articles').select('*').eq('is_breaking',true).eq('is_published',true).order('published_at',ascending:false).limit(20); return (r as List).map((e)=>NewsArticle.fromJson(e)).toList(); }catch(e){return [];} }
  Future<List<NewsArticle>> getVideos() async { try{ final r=await _supabase.from('news_articles').select('*').eq('is_published',true).not('video_url','is',null).order('published_at',ascending:false).limit(20); return (r as List).map((e)=>NewsArticle.fromJson(e)).toList(); }catch(e){return [];} }
  Future<List<NewsArticle>> searchArticles(String q) async { try{ final r=await _supabase.from('news_articles').select('*').eq('is_published',true).or('title.ilike.%$q%,content.ilike.%$q%').limit(50); return (r as List).map((e)=>NewsArticle.fromJson(e)).toList(); }catch(e){return [];} }

  Future<void> incrementViews(String id) async { try{ final a=await _supabase.from('news_articles').select('views_count').eq('id',id).maybeSingle(); if(a==null) return; await _supabase.from('news_articles').update({'views_count':(a['views_count']??0)+1}).eq('id',id);}catch(_){} }
  Future<bool> _isLiked(String id) async { if(currentUserId.isEmpty) return false; try{ final r=await _supabase.from('news_likes').select('id').eq('article_id',id).eq('user_id',currentUserId).maybeSingle(); return r!=null;}catch(_){return false;}}
  Future<void> likeArticle(String id) async { if(currentUserId.isEmpty) return; if(!await _isLiked(id)){ await _supabase.from('news_likes').insert({'article_id':id,'user_id':currentUserId}); } }
  Future<void> unlikeArticle(String id) async { await _supabase.from('news_likes').delete().eq('article_id',id).eq('user_id',currentUserId); }
  Future<bool> _isSaved(String id) async { if(currentUserId.isEmpty) return false; try{ final r=await _supabase.from('news_saved').select('id').eq('article_id',id).eq('user_id',currentUserId).maybeSingle(); return r!=null;}catch(_){return false;}}
  Future<void> saveArticle(String id) async { if(currentUserId.isEmpty) return; if(!await _isSaved(id)){ await _supabase.from('news_saved').insert({'article_id':id,'user_id':currentUserId,'saved_at':DateTime.now().toIso8601String()}); } }
  Future<void> unsaveArticle(String id) async { await _supabase.from('news_saved').delete().eq('article_id',id).eq('user_id',currentUserId); }
  Future<List<NewsArticle>> getSavedArticles() async { if(currentUserId.isEmpty) return []; try{ final r=await _supabase.from('news_saved').select('article:article_id(*)').eq('user_id',currentUserId); return (r as List).map((e)=>NewsArticle.fromJson({...e['article'],'is_saved':true})).toList(); }catch(e){return [];} }

  Future<NewsArticle> createArticle({required String title,String? summary,required String content,required String category,String? imageUrl,String? videoUrl,bool isFeatured=false,bool isBreaking=false,DateTime? publishedAt}) async {
    final now=DateTime.now().toIso8601String();
    final res=await _supabase.from('news_articles').insert({'title':title,'summary':summary,'content':content,'category':category,'image_url':imageUrl,'video_url':videoUrl,'is_featured':isFeatured,'is_breaking':isBreaking,'is_published':true,'published_at':(publishedAt??DateTime.now()).toIso8601String(),'created_at':now,'updated_at':now,'created_by':currentUserId.isEmpty?null:currentUserId,'views_count':0}).select().single();
    return NewsArticle.fromJson(res);
  }
  Future<void> updateArticle(String id, Map<String,dynamic> d) async { await _supabase.from('news_articles').update({...d,'updated_at':DateTime.now().toIso8601String()}).eq('id',id); }
  Future<void> deleteArticle(String id) async { await _supabase.from('news_articles').delete().eq('id',id); }

  // ===== FIX WEB: UPLOAD EN BYTES =====
  Future<String?> uploadImageBytes(Uint8List bytes, String fileName) async {
    try{
      final path='images/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      await _supabase.storage.from('news').uploadBinary(path, bytes, fileOptions: const FileOptions(upsert:true, contentType:'image/jpeg'));
      return _supabase.storage.from('news').getPublicUrl(path);
    }catch(e){ debugPrint('uploadImageBytes $e'); return null; }
  }
  Future<String?> uploadVideoBytes(Uint8List bytes, String fileName) async {
    try{
      final path='videos/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      await _supabase.storage.from('news').uploadBinary(path, bytes, fileOptions: const FileOptions(upsert:true, contentType:'video/mp4'));
      return _supabase.storage.from('news').getPublicUrl(path);
    }catch(e){ debugPrint('uploadVideoBytes $e'); return null; }
  }
  // Anciennes méthodes gardées pour compat mobile mais ne plus utiliser sur web
  Future<String?> uploadImage(String p) async => null;
  Future<String?> uploadVideo(String p) async => null;
}
