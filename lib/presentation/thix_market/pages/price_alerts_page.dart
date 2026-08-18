// lib/presentation/thix_market/pages/price_alerts_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/market_providers.dart';

class _MarketColors {
  static const red = Color(0xFFD81E2C);
  static const gold = Color(0xFFF0A93B);
  static const lightBg = Color(0xFFF7F7FA);
  static const pureWhite = Color(0xFFFFFFFF);
  static const darkText = Color(0xFF1A1A1A);
  static const mutedText = Color(0xFF8A8A8F);
  static const cardBorder = Color(0xFFF0F0F0);
  static const successGreen = Color(0xFF00B074);
  static const creamBg = Color(0xFFFCEFDA);
}

final priceAlertsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.read(supabaseClientProvider);
  final uid = db.auth.currentUser?.id;
  if (uid == null) return [];

  final res = await db
      .from('price_alerts')
      .select(
          'id, target_price, product_id, created_at, products(title, image_url, price, currency, shop:shops(name))')
      .eq('user_id', uid)
      .order('created_at', ascending: false);

  final list = <Map<String, dynamic>>[];

  for (final alert in (res as List)) {
    final prodRaw = alert['products'];
    Map<String, dynamic> prod = {};
    if (prodRaw is Map) prod = Map<String, dynamic>.from(prodRaw);

    final shopRaw = prod['shop'];
    Map<String, dynamic> shop = {};
    if (shopRaw is Map) shop = Map<String, dynamic>.from(shopRaw);

    list.add({
      'id': alert['id'].toString(),
      'product_id': alert['product_id'].toString(),
      'title': prod['title']?.toString() ?? 'Produit inconnu',
      'image_url': prod['image_url']?.toString() ?? '',
      'shop_name': shop['name']?.toString() ?? 'Boutique',
      'current_price': prod['price'] ?? 0,
      'target_price': alert['target_price'] ?? 0,
      'currency': prod['currency']?.toString() ?? 'FC',
    });
  }

  return list;
});

class PriceAlertsPage extends ConsumerStatefulWidget {
  const PriceAlertsPage({super.key});

  @override
  ConsumerState<PriceAlertsPage> createState() => _PriceAlertsPageState();
}

class _PriceAlertsPageState extends ConsumerState<PriceAlertsPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  bool _searching = false;
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() {
      _query = q.trim();
      _searching = true;
    });

    if (_query.isEmpty) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }

    try {
      final db = ref.read(supabaseClientProvider);
      final res = await db
          .from('products')
          .select(
              'id, title, price, currency, image_url, brand, shop:shops(name)')
          .ilike('title', '%$_query%')
          .limit(25);

      if (mounted) {
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(res);
          _searching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _searching = false;
        });
      }
    }
  }

  Future<void> _createAlert(Map<String, dynamic> product) async {
    final db = ref.read(supabaseClientProvider);
    final uid = db.auth.currentUser?.id;

    if (uid == null) {
      if (mounted) context.push('/login');
      return;
    }

    final currentPrice = (product['price'] as num?)?.toDouble() ?? 0;
    final currency = product['currency']?.toString() ?? 'FC';
    final productId = product['id'].toString();
    final title = product['title']?.toString() ?? 'Produit';
    final imageUrl = product['image_url']?.toString();

    final targetCtrl = TextEditingController(
      text: currentPrice > 0 ? (currentPrice * 0.9).toInt().toString() : '',
    );

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Créer une alerte de prix',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _MarketColors.darkText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _MarketColors.mutedText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Prix actuel : ${currentPrice.toInt()} $currency',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _MarketColors.red,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Prix cible (notification en dessous)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _MarketColors.darkText,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: targetCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                  decoration: InputDecoration(
                    suffixText: currency,
                    filled: true,
                    fillColor: _MarketColors.lightBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _MarketColors.red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Créer l\'alerte',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true) return;

    final target = double.tryParse(targetCtrl.text.trim());
    if (target == null || target <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prix cible invalide'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final existing = await db
          .from('price_alerts')
          .select('id')
          .eq('user_id', uid)
          .eq('product_id', productId)
          .maybeSingle();

      if (existing != null) {
        // Mise à jour d'une alerte existante
        await db.from('price_alerts').update({
          'target_price': target,
          'product_title': title,
          if (imageUrl != null && imageUrl.isNotEmpty) 'product_image': imageUrl,
        }).eq('id', existing['id']);
      } else {
        // Création d'une nouvelle alerte (product_title est obligatoire)
        await db.from('price_alerts').insert({
          'user_id': uid,
          'product_id': productId,
          'product_title': title, // ← CORRIGÉ : plus de null
          'target_price': target,
          if (imageUrl != null && imageUrl.isNotEmpty) 'product_image': imageUrl,
          'is_active': true,
        });
      }

      ref.invalidate(priceAlertsProvider);

      _searchCtrl.clear();
      setState(() {
        _query = '';
        _searchResults = [];
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alerte créée avec succès'),
            backgroundColor: _MarketColors.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteAlert(String id) async {
    try {
      final db = ref.read(supabaseClientProvider);
      await db.from('price_alerts').delete().eq('id', id);
      ref.invalidate(priceAlertsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alerte supprimée'),
            backgroundColor: _MarketColors.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting alert: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncAlerts = ref.watch(priceAlertsProvider);

    return Scaffold(
      backgroundColor: _MarketColors.lightBg,
      appBar: AppBar(
        backgroundColor: _MarketColors.pureWhite,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: _MarketColors.darkText),
        title: const Text(
          'Mes Alertes de Prix',
          style: TextStyle(
            color: _MarketColors.darkText,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _MarketColors.cardBorder, height: 1),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: _MarketColors.pureWhite,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) {
                Future.delayed(const Duration(milliseconds: 350), () {
                  if (_searchCtrl.text == v) _search(v);
                });
              },
              decoration: InputDecoration(
                hintText: 'Rechercher un produit pour créer une alerte...',
                hintStyle: const TextStyle(
                  color: _MarketColors.mutedText,
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _MarketColors.mutedText,
                ),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () {
                          _searchCtrl.clear();
                          _search('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: _MarketColors.lightBg,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _query.isNotEmpty
                ? _buildSearchResults()
                : asyncAlerts.when(
                    loading: () => const Center(
                      child:
                          CircularProgressIndicator(color: _MarketColors.red),
                    ),
                    error: (e, _) => Center(child: Text('Erreur : $e')),
                    data: (alerts) {
                      if (alerts.isEmpty) return _empty();
                      return RefreshIndicator(
                        color: _MarketColors.red,
                        onRefresh: () async {
                          ref.invalidate(priceAlertsProvider);
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: alerts.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (ctx, i) => _alertCard(alerts[i]),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searching) {
      return const Center(
        child: CircularProgressIndicator(color: _MarketColors.red),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          'Aucun produit pour « $_query »',
          style: const TextStyle(color: _MarketColors.mutedText),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final p = _searchResults[i];
        final title = p['title']?.toString() ?? 'Produit';
        final price = p['price'];
        final currency = p['currency']?.toString() ?? 'FC';
        final img = p['image_url']?.toString() ?? '';
        String shopName = 'Boutique';
        if (p['shop'] is Map && p['shop']['name'] != null) {
          shopName = p['shop']['name'].toString();
        }

        return Material(
          color: _MarketColors.pureWhite,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _createAlert(p),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _MarketColors.cardBorder),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 56,
                      height: 56,
                      color: _MarketColors.lightBg,
                      child: img.isEmpty
                          ? const Icon(Icons.image_not_supported_outlined,
                              color: _MarketColors.mutedText)
                          : Image.network(
                              img,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.image_not_supported_outlined),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: _MarketColors.darkText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          shopName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _MarketColors.mutedText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${price ?? 0} $currency',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: _MarketColors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _MarketColors.gold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: _MarketColors.gold,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _empty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_active_outlined,
                size: 64, color: _MarketColors.gold),
            SizedBox(height: 24),
            Text(
              'Aucune alerte de prix',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: _MarketColors.darkText,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Recherchez un produit ci-dessus\net créez une alerte de prix.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: _MarketColors.mutedText,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _alertCard(Map<String, dynamic> alert) {
    double current = 0;
    double target = 0;

    try {
      current = (alert['current_price'] as num).toDouble();
    } catch (_) {
      current = double.tryParse(alert['current_price'].toString()) ?? 0;
    }
    try {
      target = (alert['target_price'] as num).toDouble();
    } catch (_) {
      target = double.tryParse(alert['target_price'].toString()) ?? 0;
    }

    final currency = alert['currency'].toString();
    final reached = current > 0 && current <= target;

    return Dismissible(
      key: Key(alert['id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      onDismissed: (_) => _deleteAlert(alert['id'].toString()),
      child: GestureDetector(
        onTap: () => context.push('/market/product/${alert['product_id']}'),
        child: Container(
          decoration: BoxDecoration(
            color: _MarketColors.pureWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: reached
                  ? _MarketColors.successGreen.withOpacity(0.35)
                  : _MarketColors.cardBorder,
              width: reached ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 80,
                    height: 80,
                    color: _MarketColors.lightBg,
                    child: alert['image_url'].toString().isEmpty
                        ? const Icon(Icons.image_not_supported_outlined,
                            color: _MarketColors.mutedText)
                        : Image.network(
                            alert['image_url'].toString(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.image_not_supported_outlined,
                                color: _MarketColors.mutedText),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert['title'].toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _MarketColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.storefront_rounded,
                              size: 12, color: _MarketColors.mutedText),
                          const SizedBox(width: 4),
                          Text(
                            alert['shop_name'].toString(),
                            style: const TextStyle(
                              fontSize: 11,
                              color: _MarketColors.mutedText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Prix ciblé',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: _MarketColors.mutedText,
                                ),
                              ),
                              Text(
                                '${target.toInt()} $currency',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Prix actuel',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: _MarketColors.mutedText,
                                ),
                              ),
                              Text(
                                '${current.toInt()} $currency',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: reached
                                      ? _MarketColors.successGreen
                                      : _MarketColors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: reached
                              ? _MarketColors.successGreen.withOpacity(0.1)
                              : _MarketColors.gold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              reached
                                  ? Icons.check_circle_outline
                                  : Icons.schedule,
                              size: 14,
                              color: reached
                                  ? _MarketColors.successGreen
                                  : _MarketColors.gold,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              reached
                                  ? 'Objectif atteint !'
                                  : 'En surveillance...',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: reached
                                    ? _MarketColors.successGreen
                                    : _MarketColors.gold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
