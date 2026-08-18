// lib/presentation/thix_market/pages/product_comparator_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/market_providers.dart';
import '../cart/cart_provider.dart';

// ============================================================
// CHARTE GRAPHIQUE
// ============================================================
class _MarketColors {
  static const red = Color(0xFFD81E2C);
  static const gold = Color(0xFFF0A93B);
  static const lightBg = Color(0xFFF7F7FA);
  static const pureWhite = Color(0xFFFFFFFF);
  static const darkText = Color(0xFF1A1A1A);
  static const mutedText = Color(0xFF8A8A8F);
  static const cardBorder = Color(0xFFF0F0F0);
  static const creamBg = Color(0xFFFCEFDA);
}

// ============================================================
// STATE : IDs sélectionnés pour la comparaison
// ============================================================
class ComparatorNotifier extends StateNotifier<List<String>> {
  ComparatorNotifier() : super([]);

  static const maxItems = 4;

  void add(String id) {
    if (state.contains(id)) return;
    if (state.length >= maxItems) return;
    state = [...state, id];
  }

  void remove(String id) {
    state = state.where((e) => e != id).toList();
  }

  void toggle(String id) {
    if (state.contains(id)) {
      remove(id);
    } else {
      add(id);
    }
  }

  void clear() => state = [];

  bool contains(String id) => state.contains(id);
}

final comparatorIdsProvider =
    StateNotifierProvider<ComparatorNotifier, List<String>>((ref) {
  return ComparatorNotifier();
});

// Produits déjà sélectionnés (détails)
final comparatorSelectedProductsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final ids = ref.watch(comparatorIdsProvider);
  if (ids.isEmpty) return [];

  final db = ref.read(supabaseClientProvider);
  final res = await db
      .from('products')
      .select('*, shop:shops(name)')
      .inFilter('id', ids);

  // Garder l'ordre de sélection
  final list = List<Map<String, dynamic>>.from(res);
  list.sort((a, b) =>
      ids.indexOf(a['id'].toString()).compareTo(ids.indexOf(b['id'].toString())));
  return list;
});

// ============================================================
// PAGE
// ============================================================
class ProductComparatorPage extends ConsumerStatefulWidget {
  const ProductComparatorPage({super.key});

  @override
  ConsumerState<ProductComparatorPage> createState() =>
      _ProductComparatorPageState();
}

class _ProductComparatorPageState extends ConsumerState<ProductComparatorPage> {
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
          .select('id, title, price, currency, image_url, brand, rating, condition, stock, shop:shops(name)')
          .ilike('title', '%$_query%')
          .limit(30);

      if (mounted) {
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(res);
          _searching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _searching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIds = ref.watch(comparatorIdsProvider);
    final selectedAsync = ref.watch(comparatorSelectedProductsProvider);

    return Scaffold(
      backgroundColor: _MarketColors.lightBg,
      appBar: AppBar(
        backgroundColor: _MarketColors.pureWhite,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: _MarketColors.darkText),
        title: const Text(
          'Comparateur B2B',
          style: TextStyle(
            color: _MarketColors.darkText,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        actions: [
          if (selectedIds.isNotEmpty)
            TextButton(
              onPressed: () =>
                  ref.read(comparatorIdsProvider.notifier).clear(),
              child: const Text(
                'Vider',
                style: TextStyle(color: _MarketColors.red),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _MarketColors.cardBorder, height: 1),
        ),
      ),
      body: Column(
        children: [
          // ========== BARRE DE RECHERCHE ==========
          Container(
            color: _MarketColors.pureWhite,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) {
                // Debounce simple
                Future.delayed(const Duration(milliseconds: 350), () {
                  if (_searchCtrl.text == v) _search(v);
                });
              },
              decoration: InputDecoration(
                hintText: 'Rechercher un produit à comparer...',
                hintStyle: const TextStyle(color: _MarketColors.mutedText, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: _MarketColors.mutedText),
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Compteur sélection
          if (selectedIds.isNotEmpty)
            Container(
              width: double.infinity,
              color: _MarketColors.creamBg,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '${selectedIds.length}/4 produit(s) sélectionné(s)',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _MarketColors.darkText,
                  fontSize: 13,
                ),
              ),
            ),

          // ========== CONTENU ==========
          Expanded(
            child: _query.isNotEmpty
                ? _buildSearchResults(selectedIds)
                : selectedAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: _MarketColors.red),
                    ),
                    error: (e, _) => Center(child: Text('Erreur : $e')),
                    data: (products) {
                      if (products.length < 2) {
                        return _buildEmptyOrHint(products, selectedIds);
                      }
                      return _buildComparisonTable(products);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // RÉSULTATS DE RECHERCHE
  // ----------------------------------------------------------
  Widget _buildSearchResults(List<String> selectedIds) {
    if (_searching) {
      return const Center(
        child: CircularProgressIndicator(color: _MarketColors.red),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          'Aucun produit trouvé pour « $_query »',
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
        final id = p['id'].toString();
        final selected = selectedIds.contains(id);
        final title = p['title']?.toString() ?? 'Produit';
        final price = p['price'];
        final currency = p['currency']?.toString() ?? 'FC';
        final img = p['image_url']?.toString() ?? '';
        final brand = p['brand']?.toString();

        return Material(
          color: _MarketColors.pureWhite,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              final notifier = ref.read(comparatorIdsProvider.notifier);
              if (selected) {
                notifier.remove(id);
              } else {
                if (selectedIds.length >= ComparatorNotifier.maxItems) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Maximum 4 produits'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                notifier.add(id);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? _MarketColors.red : _MarketColors.cardBorder,
                  width: selected ? 2 : 1,
                ),
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
                          : Image.network(img, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.image_not_supported_outlined)),
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
                        if (brand != null && brand.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            brand,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _MarketColors.mutedText,
                            ),
                          ),
                        ],
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
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? _MarketColors.red : Colors.transparent,
                      border: Border.all(
                        color: selected ? _MarketColors.red : Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ----------------------------------------------------------
  // EMPTY / HINT
  // ----------------------------------------------------------
  Widget _buildEmptyOrHint(
    List<Map<String, dynamic>> selectedProducts,
    List<String> selectedIds,
  ) {
    final hasOne = selectedProducts.length == 1;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: _MarketColors.creamBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.compare_arrows_rounded,
                size: 64,
                color: _MarketColors.gold,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              hasOne ? 'Ajoutez un autre produit' : 'Comparateur',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: _MarketColors.darkText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasOne
                  ? 'Il vous faut au moins 2 produits pour comparer.'
                  : 'Recherchez des produits ci-dessus\net sélectionnez-en jusqu\'à 4 pour comparer.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: _MarketColors.mutedText,
                height: 1.4,
              ),
            ),
            if (selectedProducts.isNotEmpty) ...[
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: selectedProducts.map((p) {
                  final id = p['id'].toString();
                  return Chip(
                    label: Text(
                      p['title']?.toString() ?? 'Produit',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () =>
                        ref.read(comparatorIdsProvider.notifier).remove(id),
                    backgroundColor: _MarketColors.creamBg,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // TABLEAU DE COMPARAISON
  // ----------------------------------------------------------
  Widget _buildComparisonTable(List<Map<String, dynamic>> products) {
    final features = [
      {'label': 'Prix', 'key': 'price'},
      {'label': 'Marque', 'key': 'brand'},
      {'label': 'Évaluation', 'key': 'rating'},
      {'label': 'État', 'key': 'condition'},
      {'label': 'Stock', 'key': 'stock'},
      {'label': 'Boutique', 'key': 'shop'},
    ];

    return SingleChildScrollView(
      child: Column(
        children: [
          // Headers produits
          Container(
            color: _MarketColors.pureWhite,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 80),
                ...products.map((p) => Expanded(child: _productHeader(p))),
              ],
            ),
          ),
          const Divider(height: 1, color: _MarketColors.cardBorder),
          ...features.map((f) => _featureRow(f, products)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _productHeader(Map<String, dynamic> product) {
    final img = product['image_url']?.toString() ?? '';
    final title = product['title']?.toString() ?? 'Produit';
    final id = product['id'].toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  height: 90,
                  color: _MarketColors.lightBg,
                  child: img.isEmpty
                      ? const Icon(Icons.image_not_supported_outlined)
                      : Image.network(
                          img,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.image_not_supported_outlined),
                        ),
                ),
              ),
              GestureDetector(
                onTap: () =>
                    ref.read(comparatorIdsProvider.notifier).remove(id),
                child: Container(
                  margin: const EdgeInsets.all(4),
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 14, color: _MarketColors.red),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 32,
            child: ElevatedButton(
              onPressed: () async {
                final db = ref.read(supabaseClientProvider);
                final uid = db.auth.currentUser?.id;
                if (uid == null) {
                  context.push('/login');
                  return;
                }
                try {
                  await db.from('cart').insert({
                    'user_id': uid,
                    'product_id': id,
                    'quantity': 1,
                  });
                  ref.invalidate(cartProvider);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ajouté au panier'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('$e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _MarketColors.red,
                padding: EdgeInsets.zero,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Icon(Icons.shopping_cart_checkout_rounded,
                  color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureRow(
    Map<String, String> feature,
    List<Map<String, dynamic>> products,
  ) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _MarketColors.cardBorder)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                feature['label']!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _MarketColors.mutedText,
                ),
              ),
            ),
          ),
          ...products.map((p) {
            final key = feature['key']!;
            String val = '-';

            if (key == 'shop') {
              final shop = p['shop'];
              if (shop is Map && shop['name'] != null) {
                val = shop['name'].toString();
              }
            } else if (p[key] != null) {
              val = p[key].toString();
            }

            if (key == 'price') {
              val = '${p[key] ?? 0} ${p['currency'] ?? 'FC'}';
            }
            if (key == 'rating' && p[key] != null) {
              val = '⭐ $val';
            }

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  val,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        key == 'price' ? FontWeight.w900 : FontWeight.w600,
                    color: key == 'price'
                        ? _MarketColors.red
                        : _MarketColors.darkText,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
