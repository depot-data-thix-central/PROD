import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/market_colors.dart';
import '../providers/market_providers.dart';
import '../providers/product_provider.dart';

class WishlistPage extends ConsumerStatefulWidget {
  const WishlistPage({super.key});
  @override ConsumerState<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends ConsumerState<WishlistPage> {

  Future<void> _remove(String wishlistId) async {
    try{
      final db = ref.read(supabaseClientProvider);
      await db.from('wishlist').delete().eq('id', wishlistId);
      ref.invalidate(favoritesProvider);
      // CORRECTION : Remplacement de MarketColors.successGreen par Colors.green
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produit retiré des favoris'), backgroundColor: Colors.green));
    }catch(e){ debugPrint('remove fav $e'); }
  }

  Future<void> _addToCart(String productId) async {
    final db = ref.read(supabaseClientProvider);
    final uid = db.auth.currentUser?.id;
    if(uid==null){ context.push('/login'); return; }
    try{
      final existing = await db.from('cart').select().match({'user_id': uid, 'product_id': productId}).maybeSingle();
      if(existing!=null){
        await db.from('cart').update({'quantity': (existing['quantity'] as int)+1}).eq('id', existing['id']);
      } else {
        await db.from('cart').insert({'user_id': uid, 'product_id': productId, 'quantity': 1});
      }
      // CORRECTION : Remplacement de MarketColors.successGreen par Colors.green
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajouté au panier !'), backgroundColor: Colors.green));
    }catch(e){ debugPrint('addCart $e'); }
  }

  @override Widget build(BuildContext context) {
    final favAsync = ref.watch(favoritesProvider);

    return Scaffold(
      backgroundColor: MarketColors.lightBg,
      appBar: AppBar(
        backgroundColor: MarketColors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: MarketColors.darkText),
        title: const Text('Mes Favoris', style: TextStyle(color: MarketColors.darkText, fontWeight: FontWeight.w900, fontSize: 18)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: MarketColors.cardBorder, height: 1)),
      ),
      body: favAsync.when(
        loading: ()=> const Center(child: CircularProgressIndicator(color: MarketColors.red)),
        error: (e,_ )=> Center(child: Text('Erreur $e')),
        data: (items){
          if(items.isEmpty) return _empty();
          return RefreshIndicator(
            color: MarketColors.red,
            onRefresh: () async => ref.invalidate(favoritesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_,__)=> const SizedBox(height: 12),
              itemBuilder: (_, i)=> _card(items[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _empty(){
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(padding: const EdgeInsets.all(24), decoration: const BoxDecoration(color: MarketColors.creamBg, shape: BoxShape.circle), child: const Icon(Icons.favorite_border_rounded, size: 64, color: MarketColors.red)),
          const SizedBox(height: 24),
          const Text('Votre liste est vide', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: MarketColors.darkText)),
          const SizedBox(height: 8),
          const Text('Vous n\'avez pas encore ajouté de produits à vos favoris. Explorez le marché.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: MarketColors.mutedText, height: 1.4)),
          const SizedBox(height: 32),
          ElevatedButton(onPressed: ()=> context.canPop() ? context.pop() : context.push('/market'), style: ElevatedButton.styleFrom(backgroundColor: MarketColors.red, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), elevation: 0), child: const Text('Explorer le marché', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
        ]),
      ),
    );
  }

  Widget _card(Map<String, dynamic> raw) {
    // raw peut venir de favoritesProvider (produit direct) ou wishlist join
    final product = raw['products']!=null? Map<String,dynamic>.from(raw['products']) : raw;
    final wishlistId = raw['wishlist_id']?? raw['id'];
    final productId = (product['id']?? raw['product_id']).toString();
    final price = (product['price'] as num?)?.toDouble()?? 0;
    final currency = (product['currency']?? 'FC').toString();
    final stock = int.tryParse(product['stock'].toString())?? 0;
    final isAvailable = stock>0;
    final img = product['image_url'] as String?;

    return Dismissible(
      key: Key(wishlistId.toString()),
      direction: DismissDirection.endToStart,
      background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.delete_outline, color: Colors.red)),
      onDismissed: (_)=> _remove(wishlistId.toString()),
      child: GestureDetector(
        onTap: ()=> context.push('/market/product/$productId'),
        child: Container(
          decoration: BoxDecoration(color: MarketColors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: MarketColors.cardBorder), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 80,height: 80,color: MarketColors.lightBg,
                  child: img==null || img.isEmpty
                    ? const Icon(Icons.image_not_supported_outlined, color: MarketColors.mutedText)
                    : Image.network(img, fit: BoxFit.cover, errorBuilder: (_,__,___)=> const Icon(Icons.broken_image_outlined)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(product['title']?? 'Produit', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: MarketColors.darkText, height: 1.2)),
                const SizedBox(height: 6),
                Text('${price.toInt()} $currency', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: MarketColors.red)),
                const SizedBox(height: 6),
                // CORRECTION : Remplacement de MarketColors.successGreen par Colors.green
                Text(isAvailable? 'En stock' : 'Rupture de stock', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isAvailable? Colors.green : MarketColors.mutedText)),
              ])),
              if(isAvailable)
                IconButton(onPressed: ()=> _addToCart(productId), icon: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: MarketColors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.shopping_cart_outlined, color: MarketColors.red, size: 20))),
            ]),
          ),
        ),
      ),
    );
  }
}
