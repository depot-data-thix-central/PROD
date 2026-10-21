// lib/presentation/thix_market/providers/live_provider.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LiveProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Les lives THIX Market sont isolés de THIX PRO par cette valeur
  static const String _kSource = 'market';

  List<Map<String, dynamic>> _liveSessions = [];
  List<Map<String, dynamic>> _auctions = [];
  List<Map<String, dynamic>> _myLives = [];
  bool _isLoading = false;
  bool _isLoadingAuctions = false;
  bool _isLoadingMyLives = false;

  List<Map<String, dynamic>> get liveSessions => _liveSessions;
  List<Map<String, dynamic>> get auctions => _auctions;
  List<Map<String, dynamic>> get myLives => _myLives;
  bool get isLoading => _isLoading;
  bool get isLoadingAuctions => _isLoadingAuctions;
  bool get isLoadingMyLives => _isLoadingMyLives;

  /// Aligne les colonnes DB sur les clés lues par live_page.dart
  Map<String, dynamic> _normalizeLive(Map<String, dynamic> row) {
    final shop = row['shop'] is Map
        ? Map<String, dynamic>.from(row['shop'] as Map)
        : const <String, dynamic>{};
    return {
      ...row,
      'viewers': row['viewers'] ?? row['viewer_count'] ?? 0,
      'shop_name': row['shop_name'] ?? shop['name'],
      'shop_avatar': row['shop_avatar'] ?? shop['logo_url'],
    };
  }

  Future<void> loadLiveSessions() async {
    _setLoading(true);
    try {
      final response = await _supabase
          .from('live_sessions')
          .select('*, shop:shops(name, logo_url)')
          .eq('status', 'live')
          .eq('source', _kSource)
          .order('viewer_count', ascending: false);
      _liveSessions = List<Map<String, dynamic>>.from(response)
          .map(_normalizeLive)
          .toList();
    } catch (e) {
      debugPrint('Error loading live sessions: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadAuctions() async {
    _setLoadingAuctions(true);
    try {
      final response = await _supabase
          .from('auctions')
          .select('*, product:products(title, image_url)')
          .eq('status', 'active')
          .gt('end_time', DateTime.now().toIso8601String())
          .order('end_time', ascending: true);
      _auctions = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading auctions: $e');
    } finally {
      _setLoadingAuctions(false);
    }
  }

  Future<void> loadMyLives() async {
    final shopId = await _getUserShopId();
    if (shopId == null) return;

    _setLoadingMyLives(true);
    try {
      final response = await _supabase
          .from('live_sessions')
          .select()
          .eq('shop_id', shopId)
          .eq('source', _kSource)
          .order('created_at', ascending: false);
      _myLives = List<Map<String, dynamic>>.from(response)
          .map(_normalizeLive)
          .toList();
    } catch (e) {
      debugPrint('Error loading my lives: $e');
    } finally {
      _setLoadingMyLives(false);
    }
  }

  Future<String?> _getUserShopId() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final response = await _supabase
          .from('shops')
          .select('id')
          .eq('owner_id', userId)
          .eq('status', 'active')
          .maybeSingle();
      return response?['id'];
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> createLive(Map<String, dynamic> liveData) async {
    final shopId = await _getUserShopId();
    if (shopId == null) throw Exception('No active shop found');

    final userId = _supabase.auth.currentUser?.id;

    try {
      final response = await _supabase
          .from('live_sessions')
          .insert({
            ...liveData,
            'shop_id': shopId,
            'host_id': userId,
            'source': _kSource,
            'status': 'scheduled',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      return response;
    } catch (e) {
      debugPrint('Error creating live: $e');
      rethrow;
    }
  }

  Future<void> joinLive(String liveId) async {
    try {
      await _supabase.rpc('increment_live_viewers', params: {'live_id': liveId});
    } catch (e) {
      debugPrint('Error joining live: $e');
    }
  }

  Future<void> placeBid(String auctionId, double amount) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Login required');

    try {
      await _supabase.from('auction_bids').insert({
        'auction_id': auctionId,
        'user_id': userId,
        'amount': amount,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error placing bid: $e');
      rethrow;
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setLoadingAuctions(bool loading) {
    _isLoadingAuctions = loading;
    notifyListeners();
  }

  void _setLoadingMyLives(bool loading) {
    _isLoadingMyLives = loading;
    notifyListeners();
  }
}
