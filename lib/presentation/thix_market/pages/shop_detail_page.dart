// lib/presentation/market/shop_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/shop_provider.dart';

class ShopDetailPage extends ConsumerStatefulWidget {
  final String shopId;
  const ShopDetailPage({super.key, required this.shopId});
  @override ConsumerState<ShopDetailPage> createState() => _ShopDetailPageState();
}

class _ShopDetailPageState extends ConsumerState<ShopDetailPage> {
  static const navy = Color(0xFF1B2A4A);
  static const navyDeep = Color(0xFF10192E);
  static const gold = Color(0xFFC9962C);
  static const bgApp = Color(0xFFF6F7FB);
  static const textMuted = Color(0xFF8A8FA3);
  static const textDark = Color(0xFF1A1D29);
  static const danger = Color(0xFFE53935);

  @override void initState(){
    super.initState();
    Future.microtask(()=> ref.read(currentShopProvider.notifier).load(widget.shopId));
  }

  @override Widget build(BuildContext context){
    final async = ref.watch(currentShopProvider);
    if(async.isLoading){
      return const Scaffold(backgroundColor: bgApp, body: Center(child: CircularProgressIndicator(color: gold)));
    }
    if(async.hasError){
      return Scaffold(backgroundColor: bgApp, appBar: AppBar(title: const Text('Boutique')), body: Center(child: Text('Erreur ${async.error}')));
    }
    final shop = async.value;
    if(shop==null){
      return Scaffold(backgroundColor: bgApp, appBar: AppBar(title: const Text('Boutique'), backgroundColor: Colors.white), body: const Center(child: Text('Boutique introuvable')));
    }

    final products = shop['products'] is List? List<Map<String,dynamic>>.from(shop['products']) : <Map<String,dynamic>>[];
    final isVerified = shop['is_verified']==true;
    final isLive = shop['is_live']==true || shop['live_status']=='live';
    final isFollowed = shop['is_followed']==true;
    final logo = shop['logo_url'] as String?;
    final description = shop['description'] as String?;
    final city = shop['city'] as String?;
    final followers = (shop['followers'] as num?)?.toInt()?? 0;

    Widget liveBadge(){
      if(!isLive) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: danger, borderRadius: BorderRadius.circular(6)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.fiber_manual_record, size: 8, color: Colors.white),
          SizedBox(width: 4),
          Text('EN DIRECT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ]),
      );
    }

    Widget descWidget(){
      if(description==null || description.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(description, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: textMuted, fontSize: 13, height: 1.4)),
      );
    }

    Widget cityWidget(){
      if(city==null) return const SizedBox.shrink();
      return Row(children: [
        const Icon(Icons.location_on_rounded, size: 14, color: textMuted),
        const SizedBox(width: 4),
        Text(city, style: const TextStyle(color: textMuted, fontSize: 13)),
      ]);
    }

    return Scaffold(
      backgroundColor: bgApp,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(shop['name']?? 'Boutique', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: textDark)),
        actions: [
          IconButton(icon: Icon(isFollowed? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isFollowed? danger : textMuted), onPressed: ()=> ref.read(currentShopProvider.notifier).toggleFollow(shop['id'])),
          IconButton(icon: const Icon(Icons.share_rounded, color: textMuted), onPressed: (){}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: isLive? Border.all(color: danger.withOpacity(0.4), width: 1.4) : null, boxShadow: [BoxShadow(color: navy.withOpacity(0.05), blurRadius: 16, offset: const Offset(0,6))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              liveBadge(),
              Row(children: [
                Container(
                  width: 70, height: 70,
                  decoration: BoxDecoration(color: bgApp, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
                  child: logo==null || logo.isEmpty? const Icon(Icons.store_rounded, size: 32, color: textMuted) : ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(logo, fit: BoxFit.cover, errorBuilder: (a,b,c)=> const Icon(Icons.store_rounded))),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(shop['name']?? 'Boutique', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: textDark))),
                    isVerified? const Icon(Icons.verified_rounded, size: 18, color: navy) : const SizedBox.shrink(),
                  ]),
                  const SizedBox(height: 4),
                  cityWidget(),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.shopping_bag_outlined, size: 14, color: textMuted),
                    const SizedBox(width: 4),
                    Text('${products.length} produits', style: const TextStyle(color: textMuted, fontSize: 12)),
                    const SizedBox(width: 12),
                    const Icon(Icons.favorite_rounded, size: 14, color: textMuted),
                    const SizedBox(width: 4),
                    Text('$followers', style: const TextStyle(color: textMuted, fontSize: 12)),
                  ]),
                ])),
              ]),
              descWidget(),
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            const Text('Produits', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: textDark)),
            const Spacer(),
            TextButton(onPressed: ()=> context.push('/market/search?shop=${shop['id']}'), child: const Text('Voir tout', style: TextStyle(color: gold, fontSize: 12, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 8),
          products.isEmpty? Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('Aucun produit', style: TextStyle(color: textMuted)))) :
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.72),
            itemCount: products.length > 6? 6 : products.length,
            itemBuilder: (c,i){
              final p = products[i];
              final img = p['image_url'] as String?;
              final price = (p['price'] as num?)?.toDouble()?? 0;
              
              // Gestion dynamique de la devise (USD ou FC)
              final currency = p['currency'] ?? 'FC';
              final symbol = currency == 'USD' ? '\$' : 'FC';

              return InkWell(
                onTap: ()=> context.push('/market/product/${p['id']}'),
                child: Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: navy.withOpacity(0.05), blurRadius: 10)]),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(14)), child: img==null? Container(color: bgApp, child: const Center(child: Icon(Icons.image))) : Image.network(img, width: double.infinity, fit: BoxFit.cover, errorBuilder: (a,b,c)=> Container(color: bgApp, child: const Icon(Icons.image))))),
                    Padding(padding: const EdgeInsets.all(8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p['title']??'', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textDark)),
                      const SizedBox(height: 2),
                      Text('${price.toInt()} $symbol', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: navy)),
                    ])),
                  ]),
                ),
              );
            },
          ),
        ]),
      ),
    );
  }
}
