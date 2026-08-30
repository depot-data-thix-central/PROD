// lib/presentation/thix_market/providers/activity_provider.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:html/parser.dart' as html_parser;

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const int _kMaxRetries = 1;
const int _kMaxCommentLength = 1000;
const int _kMaxNameLength = 60;
const int _kMaxProductNameLength = 120;
const double _kMinRating = 1.0;
const double _kMaxRating = 5.0;

// ============================================================================
// VALIDATEURS
// ============================================================================
class _ActivityValidators {
  _ActivityValidators._();

  static bool isValidId(String? id) {
    if (id == null || id.trim().isEmpty) return false;
    return RegExp(r'^[0-9a-fA-F-]{8,}$').hasMatch(id.trim());
  }

  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final t = url.trim();
    if (!t.startsWith('http://') && !t.startsWith('https://')) return null;
    return t.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  static double safeRating(dynamic v) {
    if (v == null) return 0.0;
    final parsed = (v as num?)?.toDouble() ?? 0.0;
    if (parsed.isNaN || parsed.isInfinite) return 0.0;
    return parsed.clamp(_kMinRating, _kMaxRating);
  }

  static int safeInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    final parsed = (v as num?)?.toInt() ?? fallback;
    return parsed < 0 ? fallback : parsed;
  }

  static double safeDouble(dynamic v, {double fallback = 0.0}) {
    if (v == null) return fallback;
    final parsed = (v as num?)?.toDouble() ?? fallback;
    return parsed < 0 || parsed.isNaN || parsed.isInfinite ? fallback : parsed;
  }

  static String friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('permission') || msg.contains('policy')) return 'Accès non autorisé.';
    if (msg.contains('not found')) return 'Ressource introuvable.';
    if (msg.contains('duplicate')) return 'Cette action a déjà été effectuée.';
    return 'Une erreur est survenue. Réessayez.';
  }
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _withRetry<T>(
  Future<T> Function() fn, {
  required String label,
  int maxRetries = _kMaxRetries,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(_kRequestTimeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[ActivityProvider] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[ActivityProvider] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[ActivityProvider] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// MODÈLE TYPÉ : RATING STATS
// ============================================================================
class RatingStats {
  final double average;
  final int total;
  final Map<int, int> distribution; // 1-5 → pourcentage (0-100)

  const RatingStats({
    this.average = 0.0,
    this.total = 0,
    this.distribution = const {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
  });

  Map<String, dynamic> toMap() => {
        'average': average,
        'total': total,
        'distribution': distribution,
      };
}

// ============================================================================
// PROVIDER PRINCIPAL
// ============================================================================
class ActivityProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ------------------------------------------------------------------
  // STATE
  // ------------------------------------------------------------------
  List<Map<String, dynamic>> _purchases = [];
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _ratings = [];
  List<Map<String, dynamic>> _badges = [];
  RatingStats _ratingStats = const RatingStats();

  bool _isLoadingPurchases = false;
  bool _isLoadingSales = false;
  bool _isLoadingRatings = false;
  bool _isLoadingBadges = false;

  String? _lastError;

  // Protection double-tap
  final Set<String> _cancellingOrders = <String>{};
  final Set<String> _submittingReviews = <String>{};

  // ------------------------------------------------------------------
  // GETTERS
  // ------------------------------------------------------------------
  List<Map<String, dynamic>> get purchases => _purchases;
  List<Map<String, dynamic>> get sales => _sales;
  List<Map<String, dynamic>> get ratings => _ratings;
  List<Map<String, dynamic>> get badges => _badges;
  RatingStats get ratingStats => _ratingStats;
  String? get lastError => _lastError;

  bool get isLoadingPurchases => _isLoadingPurchases;
  bool get isLoadingSales => _isLoadingSales;
  bool get isLoadingRatings => _isLoadingRatings;
  bool get isLoadingBadges => _isLoadingBadges;
  bool get isLoadingAny =>
      _isLoadingPurchases || _isLoadingSales || _isLoadingRatings || _isLoadingBadges;

  // ------------------------------------------------------------------
  // LOAD PURCHASES
  // ------------------------------------------------------------------
  Future<void> loadPurchases({bool silent = false}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (!_ActivityValidators.isValidId(userId)) {
      debugPrint('[ActivityProvider] ⚠️ No authenticated user');
      _purchases = [];
      return;
    }

    if (!silent) _isLoadingPurchases = true;
    _lastError = null;
    notifyListeners();

    try {
      final response = await _withRetry(
        () => _supabase
            .from('orders')
            .select('id, status, total, currency, created_at, order_items(quantity, price, product_name, product_image)')
            .eq('user_id', userId!)
            .order('created_at', ascending: false),
        label: 'loadPurchases',
      );

      _purchases = (response as List)
          .map((e) => _normalizeOrder(Map<String, dynamic>.from(e as Map)))
          .toList();

      debugPrint('[ActivityProvider] ✓ Loaded ${_purchases.length} purchases');
    } catch (e) {
      debugPrint('[ActivityProvider] ❌ Load purchases error: $e');
      _lastError = _ActivityValidators.friendlyError(e);
      _purchases = [];
    } finally {
      _isLoadingPurchases = false;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------------
  // LOAD SALES
  // ------------------------------------------------------------------
  Future<void> loadSales({bool silent = false}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (!_ActivityValidators.isValidId(userId)) {
      _sales = [];
      return;
    }

    if (!silent) _isLoadingSales = true;
    _lastError = null;
    notifyListeners();

    try {
      // 1. Récupérer shops de l'utilisateur
      final shopIds = await _withRetry(
        () => _supabase.from('shops').select('id').eq('owner_id', userId!),
        label: 'fetchUserShops',
      );
      final ids = (shopIds as List)
          .map((e) => (e as Map)['id']?.toString())
          .whereType<String>()
          .where(_ActivityValidators.isValidId)
          .toList();

      if (ids.isEmpty) {
        _sales = [];
        debugPrint('[ActivityProvider] ℹ️ No shops owned by user');
        return;
      }

      // 2. Récupérer orders de ces shops
      final response = await _withRetry(
        () => _supabase
            .from('orders')
            .select('id, status, total, currency, created_at, shop_id, user_id, order_items(quantity, price, product_name, product_image)')
            .inFilter('shop_id', ids)
            .order('created_at', ascending: false),
        label: 'loadSales[${ids.length} shops]',
      );

      _sales = (response as List)
          .map((e) => _normalizeOrder(Map<String, dynamic>.from(e as Map)))
          .toList();

      debugPrint('[ActivityProvider] ✓ Loaded ${_sales.length} sales from ${ids.length} shops');
    } catch (e) {
      debugPrint('[ActivityProvider] ❌ Load sales error: $e');
      _lastError = _ActivityValidators.friendlyError(e);
      _sales = [];
    } finally {
      _isLoadingSales = false;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------------
  // LOAD RATINGS
  // ------------------------------------------------------------------
  Future<void> loadRatings({bool silent = false}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (!_ActivityValidators.isValidId(userId)) {
      _ratings = [];
      _ratingStats = const RatingStats();
      return;
    }

    if (!silent) _isLoadingRatings = true;
    _lastError = null;
    notifyListeners();

    try {
      final response = await _withRetry(
        () => _supabase
            .from('reviews')
            .select('id, rating, comment, reply, created_at, user:users(id, name, avatar)')
            .eq('seller_id', userId!)
            .order('created_at', ascending: false),
        label: 'loadRatings',
      );

      _ratings = (response as List).map((rating) {
        final map = Map<String, dynamic>.from(rating as Map);
        final userRaw = map['user'];
        final user = userRaw is Map ? Map<String, dynamic>.from(userRaw) : <String, dynamic>{};

        return {
          ...map,
          'rating': _ActivityValidators.safeRating(map['rating']),
          'comment': _ActivityValidators.sanitize(map['comment']?.toString(), maxLength: _kMaxCommentLength),
          'reply': _ActivityValidators.sanitize(map['reply']?.toString(), maxLength: _kMaxCommentLength),
          'user_name': _ActivityValidators.sanitize(
            user['name']?.toString() ?? 'Client THIX',
            maxLength: _kMaxNameLength,
          ),
          'user_avatar': _ActivityValidators.sanitizeUrl(user['avatar']?.toString()),
        };
      }).toList();

      _ratingStats = _buildRatingStats(_ratings);
      debugPrint('[ActivityProvider] ✓ Loaded ${_ratings.length} ratings (avg=${_ratingStats.average.toStringAsFixed(1)})');
    } catch (e) {
      debugPrint('[ActivityProvider] ❌ Load ratings error: $e');
      _lastError = _ActivityValidators.friendlyError(e);
      _ratings = [];
      _ratingStats = const RatingStats();
    } finally {
      _isLoadingRatings = false;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------------
  // LOAD BADGES
  // ------------------------------------------------------------------
  Future<void> loadBadges() async {
    _isLoadingBadges = true;
    notifyListeners();

    try {
      // TODO : Récupérer depuis la DB (table user_badges)
      // Pour l'instant, badges statiques avec couleurs ThixPolicy
      _badges = [
        {
          'name': 'Vendeur fiable',
          'name_en': 'Trusted Seller',
          'color_start': 0xFFE5592F, // ThixPolicy.primary
          'color_end': 0xFFFF8A65,
          'icon': 'verified',
        },
        {
          'name': 'Livraison rapide',
          'name_en': 'Fast Delivery',
          'color_start': 0xFF2563EB, // ThixPolicy.primary blue
          'color_end': 0xFF60A5FA,
          'icon': 'local_shipping',
        },
      ];
      debugPrint('[ActivityProvider] ✓ Loaded ${_badges.length} badges');
    } catch (e) {
      debugPrint('[ActivityProvider] ⚠️ Load badges error: $e');
      _badges = [];
    } finally {
      _isLoadingBadges = false;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------------
  // LOAD ALL (parallèle)
  // ------------------------------------------------------------------
  Future<void> loadAll() async {
    debugPrint('[ActivityProvider] 🔄 Loading all activity data');
    await Future.wait([
      loadPurchases(silent: true),
      loadSales(silent: true),
      loadRatings(silent: true),
      loadBadges(),
    ]);
    debugPrint('[ActivityProvider] ✓ All activity data loaded');
  }

  // ------------------------------------------------------------------
  // CANCEL ORDER (avec protection double-tap + validation)
  // ------------------------------------------------------------------
  Future<bool> cancelOrder(String orderId) async {
    if (!_ActivityValidators.isValidId(orderId)) {
      debugPrint('[ActivityProvider] ⚠️ Invalid orderId rejected: $orderId');
      _lastError = 'Identifiant de commande invalide';
      notifyListeners();
      return false;
    }

    if (_cancellingOrders.contains(orderId)) {
      debugPrint('[ActivityProvider] ⚠️ Cancel already in progress for $orderId');
      return false;
    }

    _cancellingOrders.add(orderId);
    debugPrint('[ActivityProvider] 🛑 Cancelling order ${orderId.substring(0, 8)}...');

    try {
      await _withRetry(
        () => _supabase.from('orders').update({'status': 'cancelled'}).eq('id', orderId),
        label: 'cancelOrder[$orderId]',
      );

      // Update local state
      for (final list in [_purchases, _sales]) {
        final index = list.indexWhere((order) => order['id'] == orderId);
        if (index != -1) {
          list[index] = {...list[index], 'status': 'cancelled'};
        }
      }

      notifyListeners();
      debugPrint('[ActivityProvider] ✓ Order cancelled: $orderId');
      return true;
    } catch (e) {
      debugPrint('[ActivityProvider] ❌ Cancel order error: $e');
      _lastError = _ActivityValidators.friendlyError(e);
      notifyListeners();
      return false;
    } finally {
      _cancellingOrders.remove(orderId);
    }
  }

  // ------------------------------------------------------------------
  // SUBMIT REVIEW (avec validation + protection double-tap)
  // ------------------------------------------------------------------
  Future<bool> submitReview(String orderId, double rating, String comment) async {
    final userId = _supabase.auth.currentUser?.id;
    if (!_ActivityValidators.isValidId(userId)) {
      _lastError = 'Veuillez vous connecter';
      notifyListeners();
      return false;
    }

    if (!_ActivityValidators.isValidId(orderId)) {
      _lastError = 'Identifiant de commande invalide';
      notifyListeners();
      return false;
    }

    if (rating < _kMinRating || rating > _kMaxRating) {
      _lastError = 'Note invalide (doit être entre 1 et 5)';
      notifyListeners();
      return false;
    }

    final sanitizedComment = _ActivityValidators.sanitize(comment, maxLength: _kMaxCommentLength);
    if (sanitizedComment.isEmpty) {
      _lastError = 'Veuillez entrer un commentaire';
      notifyListeners();
      return false;
    }

    if (_submittingReviews.contains(orderId)) {
      debugPrint('[ActivityProvider] ⚠️ Review already in progress for $orderId');
      return false;
    }

    _submittingReviews.add(orderId);
    debugPrint('[ActivityProvider] ⭐ Submitting review for order ${orderId.substring(0, 8)}... (rating=$rating)');

    try {
      await _withRetry(
        () => _supabase.from('reviews').insert({
          'order_id': orderId,
          'user_id': userId,
          'rating': rating,
          'comment': sanitizedComment,
          'created_at': DateTime.now().toIso8601String(),
        }),
        label: 'submitReview[$orderId]',
      );

      debugPrint('[ActivityProvider] ✓ Review submitted');

      // Recharger ratings pour inclure le nouveau
      await loadRatings(silent: true);
      return true;
    } catch (e) {
      debugPrint('[ActivityProvider] ❌ Submit review error: $e');
      _lastError = _ActivityValidators.friendlyError(e);
      notifyListeners();
      return false;
    } finally {
      _submittingReviews.remove(orderId);
    }
  }

  // ------------------------------------------------------------------
  // CLEAR ERROR
  // ------------------------------------------------------------------
  void clearError() {
    if (_lastError != null) {
      _lastError = null;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------------
  // CLEANUP AU LOGOUT
  // ------------------------------------------------------------------
  void clearOnLogout() {
    debugPrint('[ActivityProvider] 🧹 Clearing activity data on logout');
    _purchases = [];
    _sales = [];
    _ratings = [];
    _badges = [];
    _ratingStats = const RatingStats();
    _lastError = null;
    _cancellingOrders.clear();
    _submittingReviews.clear();
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // HELPERS PRIVÉS
  // ------------------------------------------------------------------
  Map<String, dynamic> _normalizeOrder(Map<String, dynamic> order) {
    final rawItems = order['order_items'];
    final itemsList = rawItems is List ? rawItems : <dynamic>[];

    final items = itemsList.map((item) {
      final map = item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
      return {
        'name': _ActivityValidators.sanitize(
          map['product_name']?.toString() ?? 'Produit',
          maxLength: _kMaxProductNameLength,
        ),
        'image_url': _ActivityValidators.sanitizeUrl(map['product_image']?.toString()),
        'quantity': _ActivityValidators.safeInt(map['quantity'], fallback: 1),
        'price': _ActivityValidators.safeDouble(map['price']),
      };
    }).toList();

    return {
      ...order,
      'items': items,
      'total': _ActivityValidators.safeInt(order['total']),
      'currency': _ActivityValidators.sanitize(order['currency']?.toString(), maxLength: 10),
    };
  }

  RatingStats _buildRatingStats(List<Map<String, dynamic>> ratings) {
    if (ratings.isEmpty) {
      return const RatingStats();
    }

    final distribution = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    double totalRating = 0;

    for (final rating in ratings) {
      final value = _ActivityValidators.safeRating(rating['rating']);
      final rounded = value.round().clamp(1, 5);
      distribution[rounded] = (distribution[rounded] ?? 0) + 1;
      totalRating += value;
    }

    final total = ratings.length;
    final average = total == 0 ? 0.0 : totalRating / total;

    return RatingStats(
      average: average,
      total: total,
      distribution: distribution.map(
        (key, value) => MapEntry(key, total == 0 ? 0 : ((value / total) * 100).round()),
      ),
    );
  }
}
