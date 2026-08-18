// lib/presentation/thix_market/supermarket/supermarket_cart.dart
// UI exacte capture droite: My Cart, items stepper, coupon vert, subtotal, checkout

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/supermarket_provider.dart';

class SupermarketCart extends StatelessWidget {
  final String shopId;
  const SupermarketCart({super.key, required this.shopId});

  @override Widget build(BuildContext context){
    final prov=context.watch<SupermarketProvider>();
    final items=prov.cartQty.entries.toList();
    final subtotal=prov.totalPrice/100; // $10.08 comme capture
    const delivery=3.0;
    final total=subtotal+delivery;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, elevation:0, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed:()=> Navigator.pop(context)), title: const Text('My Cart', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)), centerTitle:true, actions:[ IconButton(icon: const Icon(Icons.favorite_border, color: Colors.black54), onPressed:(){})]),
      body: Column(children:[
        Expanded(child: ListView.separated(padding: const EdgeInsets.symmetric(horizontal:16, vertical:12), itemCount: items.length, separatorBuilder:(_,__)=> const Divider(height:24, color: Color(0xFFF0F0F0)), itemBuilder:(_,i){
          final entry=items[i]; final prod=prov.products.firstWhere((e)=>e['id']==entry.key, orElse:()=>{'title':'Fresh Fuji Apples','image_url':'','price':229,'unit':'1 Pieces'});
          return Row(children:[
            ClipRRect(borderRadius: BorderRadius.circular(12), child: CachedNetworkImage(imageUrl: prod['image_url']??'', width:56, height:56, fit:BoxFit.cover, errorWidget:(_,__,___)=> Container(width:56,height:56,color: const Color(0xFFF5F5F5), child: const Icon(Icons.image)))),
            const SizedBox(width:12),
            Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
              Text(prod['title']??'Product', style: const TextStyle(fontWeight:FontWeight.w700, fontSize:13)),
              const SizedBox(height:2),
              Text(prod['unit']??'1 Pieces', style: TextStyle(color: Colors.grey[500], fontSize:11)),
              const SizedBox(height:2),
              Text('\$${((prod['price']??0)/100).toStringAsFixed(2)} /pack', style: const TextStyle(fontWeight:FontWeight.w800, fontSize:12, color: Color(0xFF2E7D32))),
            ])),
            Container(decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(20)), child: Row(children:[
              InkWell(onTap:()=> prov.add(entry.key,-1), child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.remove, size:16, color: Colors.grey))),
              Padding(padding: const EdgeInsets.symmetric(horizontal:6), child: Text('${entry.value}', style: const TextStyle(fontWeight:FontWeight.w800, fontSize:13))),
              InkWell(onTap:()=> prov.add(entry.key,1), child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Color(0xFF4AA85F), shape: BoxShape.circle), child: const Icon(Icons.add, size:14, color: Colors.white))),
            ])),
          ]);
        })),
        // Coupon vert
        Padding(padding: const EdgeInsets.symmetric(horizontal:16), child: Container(height:48, decoration: BoxDecoration(color: const Color(0xFF4AA85F), borderRadius: BorderRadius.circular(12)), child: Row(children:[ const SizedBox(width:12), const Icon(Icons.local_offer, color: Colors.white, size:18), const SizedBox(width:8), const Expanded(child: Text('You Have 3 Coupon', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize:13))), Container(margin: const EdgeInsets.only(right:8), padding: const EdgeInsets.symmetric(horizontal:14,vertical:6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: const Text('Apply', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w800, fontSize:12)))]))),
        const SizedBox(height:16),
        Padding(padding: const EdgeInsets.symmetric(horizontal:16), child: Column(children:[
          Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children:[ Text('Subtotal', style: TextStyle(color: Colors.grey[500], fontSize:13)), Text('\$${subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize:13))]),
          const SizedBox(height:10),
          Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children:[ Text('Delivery', style: TextStyle(color: Colors.grey[500], fontSize:13)), const Text('\$3.00', style: TextStyle(fontWeight: FontWeight.w700, fontSize:13))]),
          const Divider(height:24),
          Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children:[ const Text('Total', style: TextStyle(fontWeight: FontWeight.w900, fontSize:15)), Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize:18, color: Color(0xFF2E7D32)))]),
          const SizedBox(height:16),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(onPressed:(){}, icon: const Icon(Icons.shopping_bag, color: Colors.white, size:18), label: const Text('Checkout Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize:14)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4AA85F), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
          const SizedBox(height:16),
        ])),
      ]),
    );
  }
}
