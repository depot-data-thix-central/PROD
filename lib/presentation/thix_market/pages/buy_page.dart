import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/product_provider.dart';
import '../widgets/products/product_card.dart';

class BuyPage extends ConsumerStatefulWidget {
  const BuyPage({super.key});
  @override ConsumerState<BuyPage> createState() => _BuyPageState();
}

class _BuyPageState extends ConsumerState<BuyPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategory = 'all';
  final ScrollController _scrollController = ScrollController();

  static const Color navyDeep = Color(0xFF0A1F44);
  static const Color navy = Color(0xFF123B7A);
  static const Color gold = Color(0xFFE3B23C);
  static const Color ivory = Color(0xFFF6F7FB);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color darkText = Color(0xFF10182B);
  static const Color mutedText = Color(0xFF6B7690);
  static const Color danger = Color(0xFFD64545);
  static const Color hairline = Color(0xFFE7EAF3);

  final List<Map<String, dynamic>> categories = [
    {'id': 'all', 'name': 'Tous', 'icon': Icons.apps_rounded},
    {'id': 'fashion', 'name': 'Mode', 'icon': Icons.checkroom_rounded},
    {'id': 'electronics', 'name': 'Électronique', 'icon': Icons.phone_android_rounded},
    {'id': 'home', 'name': 'Maison', 'icon': Icons.chair_rounded},
    {'id': 'services', 'name': 'Services', 'icon': Icons.build_rounded},
    {'id': 'vehicles', 'name': 'Véhicules', 'icon': Icons.directions_car_rounded},
    {'id': 'realestate', 'name': 'Immobilier', 'icon': Icons.house_rounded},
  ];

  @override void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _onScroll() {
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 600) {
      ref.read(productProvider.notifier).load();
    }
  }

  @override void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      ref.read(productProvider.notifier).load(category: _selectedCategory, refresh: true),
      ref.read(favoritesProvider.notifier).build(),
      ref.read(wishlistProvider.notifier).build(),
    ]);
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ivory,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [_buildInstitutionalAppBar()],
        body: TabBarView(
          controller: _tabController,
          children: [_buildExploreTab(), _buildFavoritesTab(), _buildWishlistTab()],
        ),
      ),
    );
  }

  Widget _buildInstitutionalAppBar() {
    return SliverAppBar(
      pinned: true,
      floating: true,
      elevation: 0,
      backgroundColor: navyDeep,
      surfaceTintColor: navyDeep,
      toolbarHeight: 60,
      expandedHeight: 60,
      automaticallyImplyLeading: false,
      flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [navyDeep, navy]))),
      title: Row(children: [
        Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: gold.withValues(alpha: 0.5))), child: const Icon(Icons.shopping_bag_rounded, size: 16, color: gold)),
        const SizedBox(width: 10),
        const Text('Acheter', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
      ]),
      actions: [
        _appBarIconButton(Icons.compare_arrows_rounded, () => context.push('/market/compare')),
        _appBarIconButton(Icons.notifications_active_rounded, () => context.push('/market/price-alerts')),
        _appBarIconButton(Icons.refresh_rounded, _loadData),
        const SizedBox(width: 6),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(16)),
          child: TabBar(
            controller: _tabController,
            tabs: const [Tab(text: 'Explorer'), Tab(text: 'Favoris'), Tab(text: 'Wishlist')],
            indicator: BoxDecoration(color: gold, borderRadius: BorderRadius.circular(12)),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: navyDeep,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
            dividerColor: Colors.transparent,
          ),
        ),
      ),
    );
  }

  Widget _appBarIconButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(11), border: Border.all(color: Colors.white.withValues(alpha: 0.18))),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }

  Widget _buildExploreTab() {
    final async = ref.watch(productProvider);
    return Column(children: [
      const SizedBox(height: 10),
      SizedBox(
        height: 86,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          itemCount: categories.length,
          itemBuilder: (_, index) {
            final category = categories[index];
            final isSelected = _selectedCategory == category['id'];
            return GestureDetector(
              onTap: () {
                setState(() => _selectedCategory = category['id']);
                ref.read(productProvider.notifier).load(category: category['id'], refresh: true);
              },
              child: Container(
                width: 68,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected? navyDeep : pureWhite,
                      shape: BoxShape.circle,
                      border: Border.all(color: isSelected? navyDeep : hairline, width: isSelected? 0 : 1),
                      boxShadow: [BoxShadow(color: isSelected? navyDeep.withValues(alpha: 0.25) : navyDeep.withValues(alpha: 0.04), blurRadius: isSelected? 14 : 8, offset: const Offset(0, 4))],
                    ),
                    child: Icon(category['icon'] as IconData, color: isSelected? gold : mutedText, size: 21),
                  ),
                  const SizedBox(height: 5),
                  Text(category['name'], style: TextStyle(fontSize: 9.5, fontWeight: isSelected? FontWeight.w800 : FontWeight.w500, color: isSelected? navy : mutedText)),
                ]),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 6),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(children: [
          _buildQuickFilterChip('Prix', Icons.attach_money_rounded),
          const SizedBox(width: 8),
          _buildQuickFilterChip('Distance', Icons.location_on_rounded),
          const SizedBox(width: 8),
          _buildQuickFilterChip('Note', Icons.star_rounded),
          const Spacer(),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _showAdvancedFilters,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [navyDeep, navy]), borderRadius: BorderRadius.circular(20)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.tune_rounded, size: 13, color: gold), SizedBox(width: 5), Text('Filtres', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11.5))]),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 4),
      Expanded(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF123B7A))),
          error: (e, _) => Center(child: Text('Erreur $e')),
          data: (state) {
            if (state.items.isEmpty) return _buildEmptyState('Aucun produit trouvé');
            return RefreshIndicator(
              color: navy,
              onRefresh: _loadData,
              child: GridView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.7, crossAxisSpacing: 12, mainAxisSpacing: 12),
                itemCount: state.items.length + (state.hasMore? 1 : 0),
                itemBuilder: (_, index) {
                  if (index >= state.items.length) return const Center(child: CircularProgressIndicator(color: navy));
                  final product = state.items[index];
                  return ProductCard(
                    product: product,
                    onTap: (_) => context.push('/market/product/${product['id']}'),
                    onFavoriteTap: (id) => ref.read(favoritesProvider.notifier).toggle(id),
                  );
                },
              ),
            );
          },
        ),
      ),
    ]);
  }

  Widget _buildQuickFilterChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: pureWhite, borderRadius: BorderRadius.circular(20), border: Border.all(color: hairline)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 13, color: navy), const SizedBox(width: 5), Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: darkText))]),
    );
  }

  Widget _buildFavoritesTab() {
    final async = ref.watch(favoritesProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator(color: navy)),
      error: (e, _) => Center(child: Text('Erreur $e')),
      data: (list) {
        if (list.isEmpty) return _buildEmptyStateWithAction('Aucun favori', 'Ajoutez des produits à vos favoris', Icons.favorite_border_rounded, () => _tabController.animateTo(0));
        return GridView.builder(
          padding: const EdgeInsets.all(14),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.7, crossAxisSpacing: 12, mainAxisSpacing: 12),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final product = list[i];
            return ProductCard(product: product, isFavorite: true, onTap: (_) => context.push('/market/product/${product['id']}'), onFavoriteTap: (id) => ref.read(favoritesProvider.notifier).toggle(id));
          },
        );
      },
    );
  }

  Widget _buildWishlistTab() {
    final async = ref.watch(wishlistProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator(color: navy)),
      error: (e, _) => Center(child: Text('Erreur $e')),
      data: (list) {
        if (list.isEmpty) return _buildEmptyStateWithAction('Wishlist vide', 'Créez une liste de souhaits partageable', Icons.share_rounded, _createWishlist);
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (_, index) {
            final item = list[index];
            final prod = item['products'] as Map<String, dynamic>?;
            final String? img = (prod?['image_url'] as String?)?? (item['image_url'] as String?);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: pureWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: hairline), boxShadow: [BoxShadow(color: navyDeep.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))]),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: img == null
                     ? Container(width: 52, height: 52, color: ivory, child: const Icon(Icons.image_rounded, size: 22, color: mutedText))
                      : Image.network(img, width: 52, height: 52, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 52, height: 52, color: ivory, child: const Icon(Icons.broken_image_outlined))),
                ),
                title: Text(prod?['title']?? item['name']?? 'Produit', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: darkText)),
                subtitle: Text('${(prod?['price'] as num?)?.toInt()?? (item['price'] as num?)?.toInt()?? 0} FCFA', style: const TextStyle(color: navy, fontWeight: FontWeight.w800, fontSize: 12.5)),
                trailing: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => ref.read(wishlistProvider.notifier).remove(item['id']),
                  child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: danger.withValues(alpha: 0.08), shape: BoxShape.circle), child: const Icon(Icons.delete_outline_rounded, size: 17, color: danger)),
                ),
                onTap: () => context.push('/market/product/${item['product_id']?? prod?['id']}'),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 84, height: 84, decoration: const BoxDecoration(color: ivory, shape: BoxShape.circle), child: const Icon(Icons.shopping_bag_outlined, size: 38, color: mutedText)), const SizedBox(height: 16), Text(message, style: const TextStyle(fontSize: 15, color: mutedText, fontWeight: FontWeight.w600))]));
  }

  Widget _buildEmptyStateWithAction(String title, String subtitle, IconData icon, VoidCallback onAction) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 90, height: 90, decoration: BoxDecoration(color: navyDeep.withValues(alpha: 0.06), shape: BoxShape.circle, border: Border.all(color: gold.withValues(alpha: 0.4), width: 1.4)), child: Icon(icon, size: 38, color: navy)),
          const SizedBox(height: 18),
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: darkText)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: mutedText, fontSize: 13, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
          const SizedBox(height: 22),
          InkWell(borderRadius: BorderRadius.circular(24), onTap: onAction, child: Container(padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13), decoration: BoxDecoration(gradient: const LinearGradient(colors: [navyDeep, navy]), borderRadius: BorderRadius.circular(24)), child: Text(title == 'Wishlist vide'? 'Créer ma wishlist' : 'Explorer', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)))),
        ]),
      ),
    );
  }

  void _showAdvancedFilters() {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const AdvancedFiltersSheet());
  }

  void _createWishlist() {
    showDialog(context: context, builder: (_) => const CreateWishlistDialog());
  }
}

class AdvancedFiltersSheet extends StatelessWidget {
  const AdvancedFiltersSheet({super.key});
  static const Color navyDeep = Color(0xFF0A1F44);
  static const Color navy = Color(0xFF123B7A);
  static const Color gold = Color(0xFFE3B23C);
  static const Color ivory = Color(0xFFF6F7FB);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color darkText = Color(0xFF10182B);
  static const Color hairline = Color(0xFFE7EAF3);

  @override Widget build(BuildContext context) {
    const priceRange = RangeValues(0, 1000000);
    return Container(
      decoration: const BoxDecoration(color: pureWhite, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.all(22),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: hairline, borderRadius: BorderRadius.circular(4)))),
        Row(children: [Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: ivory, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.tune_rounded, size: 17, color: navy)), const SizedBox(width: 10), const Text('Filtres avancés', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: darkText))]),
        const SizedBox(height: 20),
        const Text('Prix (FCFA)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: darkText)),
        SliderTheme(data: SliderThemeData(activeTrackColor: navy, inactiveTrackColor: hairline, thumbColor: gold, overlayColor: gold.withValues(alpha: 0.15)), child: RangeSlider(values: priceRange, min: 0, max: 1000000, divisions: 10, onChanged: (_) {})),
        const SizedBox(height: 14),
        const Text('Catégories', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: darkText)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: ['Mode', 'Électronique', 'Maison', 'Services', 'Véhicules'].map((cat) => Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8), decoration: BoxDecoration(color: ivory, borderRadius: BorderRadius.circular(20), border: Border.all(color: hairline)), child: Text(cat, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: darkText)))).toList()),
        const SizedBox(height: 22),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(side: const BorderSide(color: navy, width: 1.6), foregroundColor: navy, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: const Text('Réinitialiser', style: TextStyle(fontWeight: FontWeight.w700)))),
          const SizedBox(width: 12),
          Expanded(child: Container(decoration: BoxDecoration(gradient: const LinearGradient(colors: [navyDeep, navy]), borderRadius: BorderRadius.circular(14)), child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: const Text('Appliquer', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white))))),
        ]),
      ]),
    );
  }
}

class CreateWishlistDialog extends StatelessWidget {
  const CreateWishlistDialog({super.key});
  static const Color navyDeep = Color(0xFF0A1F44);
  static const Color navy = Color(0xFF123B7A);
  static const Color gold = Color(0xFFE3B23C);
  static const Color darkText = Color(0xFF10182B);
  static const Color mutedText = Color(0xFF6B7690);
  static const Color hairline = Color(0xFFE7EAF3);

  @override Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: navyDeep, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.favorite_rounded, size: 16, color: gold)), const SizedBox(width: 10), const Text('Créer une wishlist', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: darkText))]),
          const SizedBox(height: 18),
          TextField(decoration: InputDecoration(labelText: 'Nom de la liste', hintText: 'Ex: Cadeaux Noël', labelStyle: const TextStyle(color: mutedText), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: hairline)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: navy, width: 1.6)))),
          const SizedBox(height: 12),
          TextField(decoration: InputDecoration(labelText: 'Description (optionnel)', labelStyle: const TextStyle(color: mutedText), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: hairline)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: navy, width: 1.6))), maxLines: 2),
          const SizedBox(height: 8),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Liste publique', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: darkText)), value: true, activeColor: navy, activeTrackColor: gold.withValues(alpha: 0.4), onChanged: (_) {}),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler', style: TextStyle(color: mutedText, fontWeight: FontWeight.w700))),
            const SizedBox(width: 8),
            Container(decoration: BoxDecoration(gradient: const LinearGradient(colors: [navyDeep, navy]), borderRadius: BorderRadius.circular(12)), child: ElevatedButton(onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wishlist créée avec succès'))); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Créer', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)))),
          ]),
        ]),
      ),
    );
  }
}
