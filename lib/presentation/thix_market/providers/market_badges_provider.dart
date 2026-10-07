// lib/presentation/thix_market/providers/market_badges_provider.dart
// ============================================================================
// MARKET BADGES — compteurs de notifications (barre du haut + barre du bas)
// ----------------------------------------------------------------------------
//  • 4 compteurs : orders, wishlist, shops, alerts
//  • "Vu" mémorisé par utilisateur et par section (SharedPreferences)
//  • markSeen(kind) => compteur à 0 immédiatement
//  • Rafraîchissement : 45 s, retour de page, connexion / déconnexion
//  • Toute requête en erreur renvoie 0 (jamais de crash de l'accueil)
// ============================================================================
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Duration _kPollInterval = Duration(seconds: 45);
const Duration _kQueryTimeout = Duration(seconds: 12);

/// Première ouverture : on ne montre que les 7 derniers jours.
const Duration _kDefaultWindow = Duration(days: 7);

enum MarketBadge { orders, wishlist, shops, alerts }

@immutable
class MarketBadges {
  final int orders;
  final int wishlist;
  final int shops;
  final int alerts;
  final bool hasShop;

  const MarketBadges({
    this.orders = 0,
    this.wishlist = 0,
    this.shops = 0,
    this.alerts = 0,
    this.hasShop = false,
  });

  static const MarketBadges empty = MarketBadges();

  int get total => orders + wishlist + shops + alerts;

  MarketBadges copyWith({
    int? orders,
    int? wishlist,
    int? shops,
    int? alerts,
    bool? hasShop,
  }) {
    return MarketBadges(
      orders: orders ?? this.orders,
      wishlist: wishlist ?? this.wishlist,
      shops: shops ?? this.shops,
      alerts: alerts ?? this.alerts,
      hasShop: hasShop ?? this.hasShop,
    );
  }

  MarketBadges withZero(MarketBadge kind) {
    switch (kind) {
      case MarketBadge.orders:
        return copyWith(orders: 0);
      case MarketBadge.wishlist:
        return copyWith(wishlist: 0);
      case MarketBadge.shops:
        return copyWith(shops: 0);
      case MarketBadge.alerts:
        return copyWith(alerts: 0);
    }
  }

  @override
  bool operator ==(Object other) =>
      other is MarketBadges &&
      other.orders == orders &&
      other.wishlist == wishlist &&
      other.shops == shops &&
      other.alerts == alerts &&
      other.hasShop == hasShop;

  @override
  int get hashCode => Object.hash(orders, wishlist, shops, alerts, hasShop);
}

final marketBadgesProvider =
    NotifierProvider<MarketBadgesNotifier, MarketBadges>(MarketBadgesNotifier.new);

class MarketBadgesNotifier extends Notifier<MarketBadges> {
  Timer? _timer;
  bool _busy = false;
  int _gen = 0; // incrémenté à chaque markSeen : invalide un calcul en cours
  final Map<String, DateTime> _seen = <String, DateTime>{};

  SupabaseClient get _db => Supabase.instance.client;
  String? get _uid => _db.auth.currentUser?.id;

  @override
  MarketBadges build() {
    _timer = Timer.periodic(_kPollInterval, (_) => refresh());
    final sub = _db.auth.onAuthStateChange.listen((_) {
      _seen.clear();
      refresh();
    });
    ref.onDispose(() {
      _timer?.cancel();
      sub.cancel();
    });
    Future.microtask(refresh);
    return MarketBadges.empty;
  }

  // ── "Vu" ────────────────────────────────────────────────────────────────
  String _key(String uid, MarketBadge kind) => 'market_seen_${uid}_${kind.name}';

  DateTime _readSeen(SharedPreferences prefs, String uid, MarketBadge kind) {
    final key = _key(uid, kind);
    final cached = _seen[key];
    if (cached != null) return cached;
    final ms = prefs.getInt(key);
    final value = ms != null
        ? DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true)
        : DateTime.now().toUtc().subtract(_kDefaultWindow);
    _seen[key] = value;
    return value;
  }

  /// À appeler quand l'utilisateur ouvre la section : compteur à 0 tout de suite.
  Future<void> markSeen(MarketBadge kind) async {
    final uid = _uid;
    if (uid == null) return;
    final now = DateTime.now().toUtc();
    _gen++;
    _seen[_key(uid, kind)] = now; // synchrone : aucun rafraîchissement ne le dépasse
    state = state.withZero(kind);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key(uid, kind), now.millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[MarketBadges] ⚠️ markSeen persist error: $e');
    }
  }

  // ── Rafraîchissement ────────────────────────────────────────────────────
  Future<void> refresh() async {
    final uid = _uid;
    if (uid == null) {
      state = MarketBadges.empty;
      return;
    }
    if (_busy) return;
    _busy = true;
    final gen = _gen;

    try {
      final prefs = await SharedPreferences.getInstance();
      final sOrders = _readSeen(prefs, uid, MarketBadge.orders);
      final sWish = _readSeen(prefs, uid, MarketBadge.wishlist);
      final sShops = _readSeen(prefs, uid, MarketBadge.shops);
      final sAlerts = _readSeen(prefs, uid, MarketBadge.alerts);

      final shopIds = await _myShopIds(uid);

      final results = await Future.wait<int>([
        _ordersCount(uid, sOrders),
        _wishlistCount(uid, sWish),
        _shopOrdersCount(shopIds, sShops),
        _alertsCount(uid, sAlerts),
      ]);

      if (gen != _gen) return; // un markSeen est passé pendant le calcul
      state = MarketBadges(
        orders: results[0],
        wishlist: results[1],
        shops: results[2],
        alerts: results[3],
        hasShop: shopIds.isNotEmpty,
      );
    } catch (e) {
      debugPrint('[MarketBadges] ❌ refresh error: $e');
    } finally {
      _busy = false;
    }
  }

  // ── Requêtes ────────────────────────────────────────────────────────────
  String _iso(DateTime d) => d.toUtc().toIso8601String();

  Future<int> _safe(String label, Future<int> Function() fn) async {
    try {
      return await fn().timeout(_kQueryTimeout);
    } catch (e) {
      debugPrint('[MarketBadges] ⚠️ $label: $e');
      return 0;
    }
  }

  Future<List<String>> _myShopIds(String uid) async {
    try {
      final res = await _db
          .from('shops')
          .select('id')
          .eq('owner_id', uid)
          .timeout(_kQueryTimeout);
      return (res as List)
          .map((e) => (e as Map)['id']?.toString())
          .whereType<String>()
          .toList();
    } catch (e) {
      debugPrint('[MarketBadges] ⚠️ shops: $e');
      return <String>[];
    }
  }

  /// Mes achats dont le statut a changé depuis ma dernière visite.
  Future<int> _ordersCount(String uid, DateTime seen) => _safe('orders', () async {
        final res = await _db
            .from('orders')
            .select('id')
            .eq('user_id', uid)
            .neq('status', 'pending')
            .gt('updated_at', _iso(seen))
            .count(CountOption.exact);
        return res.count;
      });

  /// Favoris passés en promo / vente flash depuis ma dernière visite.
  Future<int> _wishlistCount(String uid, DateTime seen) => _safe('wishlist', () async {
        final res = await _db
            .from('wishlist')
            .select('products(id,price,discount_price,is_flash_sale,expires_at,updated_at)')
            .eq('user_id', uid)
            .limit(200);

        var n = 0;
        final now = DateTime.now();
        for (final row in (res as List)) {
          dynamic p = (row as Map)['products'];
          if (p is List) p = p.isEmpty ? null : p.first;
          if (p is! Map) continue;

          final updated = DateTime.tryParse('${p['updated_at']}');
          if (updated == null || !updated.isAfter(seen)) continue;

          final price = num.tryParse('${p['price']}');
          final dp = num.tryParse('${p['discount_price']}');
          final promo = price != null && dp != null && dp > 0 && dp < price;

          final exp = DateTime.tryParse('${p['expires_at']}');
          final flash = p['is_flash_sale'] == true && (exp == null || exp.isAfter(now));

          if (promo || flash) n++;
        }
        return n;
      });

  /// Nouvelles commandes en attente dans mes boutiques.
  Future<int> _shopOrdersCount(List<String> shopIds, DateTime seen) =>
      _safe('shopOrders', () async {
        if (shopIds.isEmpty) return 0;
        final res = await _db
            .from('orders')
            .select('id')
            .inFilter('shop_id', shopIds)
            .eq('status', 'pending')
            .gt('created_at', _iso(seen))
            .count(CountOption.exact);
        return res.count;
      });

  /// Notifications non lues arrivées depuis ma dernière ouverture.
  Future<int> _alertsCount(String uid, DateTime seen) => _safe('alerts', () async {
        final res = await _db
            .from('notifications')
            .select('id')
            .eq('user_id', uid)
            .eq('is_read', false)
            .gt('created_at', _iso(seen))
            .count(CountOption.exact);
        return res.count;
      });
}
