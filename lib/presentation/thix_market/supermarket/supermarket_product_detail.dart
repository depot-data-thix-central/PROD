// lib/presentation/thix_market/supermarket/supermarket_product_detail.dart
// UI exacte capture gauche: Product Details, image pommes, prix, Description, Recommendation, Add to Cart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/supermarket_provider.dart';

class SupermarketProductDetail extends StatelessWidget {
  final Map<String,dynamic> product;
  const SupermarketProductDetail({super.key, required this.product});

  @override Widget build(BuildContext context){
    final prov=context.watch<SupermarketProvider>();
    final qty=prov.cartQty[product['id']]??2; // comme capture 2
    final price=(product['price']??229) as int; // 2.29

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, elevation:0, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed:()=> Navigator.pop(context)), title: const Text('Product Details', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize:16)), centerTitle:true, actions:[IconButton(icon: const Icon(Icons.share_outlined, color: Colors.black87, size:20), onPressed:(){})]),
      body: SingleChildScrollView(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
        // Image produit
        Center(child: Padding(padding: const EdgeInsets.symmetric(vertical:12), child: ClipRRect(borderRadius: BorderRadius.circular(16), child: CachedNetworkImage(imageUrl: product['image_url']??'https://images.unsplash.com/photo-1568702846914-96b305d2aa34?w=400', height:220, width:260, fit:BoxFit.cover)))),
        Padding(padding: const EdgeInsets.symmetric(horizontal:16), child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
          Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children:[ Expanded(child: Text(product['title']??'Fresh Fuji Apples', style: const TextStyle(fontWeight:FontWeight.w900, fontSize:18))), Icon(Icons.favorite, color: Colors.red[400], size:20)]),
          const SizedBox(height:4),
          Row(children:[ const Icon(Icons.star, size:14, color: Colors.orange), const SizedBox(width:4), Text('${product['rating']??'4.8'} reviews', style: TextStyle(color: Colors.grey[600], fontSize:12))]),
          const SizedBox(height:12),
          Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children:[
            Text('\$${(price/100).toStringAsFixed(2)} /pack', style: const TextStyle(fontWeight:FontWeight.w900, fontSize:16)),
            Container(decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(20)), child: Row(children:[
              InkWell(onTap:()=> prov.add(product['id'],-1), child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.remove, size:16))),
              Padding(padding: const EdgeInsets.symmetric(horizontal:8), child: Text('$qty', style: const TextStyle(fontWeight:FontWeight.w800))),
              InkWell(onTap:()=> prov.add(product['id'],1), child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Color(0xFF4AA85F), shape: BoxShape.circle), child: const Icon(Icons.add, size:14, color: Colors.white))),
            ])),
          ]),
          const SizedBox(height:18),
          const Text('Description', style: TextStyle(fontWeight:FontWeight.w800, fontSize:14)),
          const SizedBox(height:6),
          Text(product['description']??'Fuji apples are a popular apple variety prized for their exceptional sweetness, firm crisp texture, and beautiful rosy red skin. Originally developed in Japan and now grown in the United States, Read more...', style: TextStyle(color: Colors.grey[600], fontSize:12, height:1.4)),
          const SizedBox(height:18),
          Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children:[ const Text('Recommendation', style: TextStyle(fontWeight:FontWeight.w800, fontSize:14)), Text('See all', style: TextStyle(color: Colors.grey[500], fontSize:12))]),
          const SizedBox(height:10),
          // Recommendation card comme capture
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFF9FBF9), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFEFF3EF))), child: Row(children:[
            ClipRRect(borderRadius: BorderRadius.circular(10), child: CachedNetworkImage(imageUrl:'https://images.unsplash.com/photo-1576045057995-568f588f82fb?w=200', width:56, height:56, fit:BoxFit.cover)),
            const SizedBox(width:10),
            Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[ const Text('Organic Spinach', style: TextStyle(fontWeight:FontWeight.w700, fontSize:13)), const Text('\$2.50 /bunch', style: TextStyle(fontWeight:FontWeight.w800, fontSize:12, color: Color(0xFF2E7D32))), Text('1 Bunch', style: TextStyle(color: Colors.grey[500], fontSize:11))])),
            Stack(children:[ Container(padding: const EdgeInsets.symmetric(horizontal:8,vertical:2), decoration: BoxDecoration(color: const Color(0xFFD6F5DB), borderRadius: BorderRadius.circular(6)), child: const Text('10%', style: TextStyle(fontSize:10,fontWeight:FontWeight.w800,color: Color(0xFF2E7D32)))), Positioned(right:0, bottom:-6, child: Container(width:22,height:22, decoration: const BoxDecoration(color: Color(0xFF4AA85F), shape: BoxShape.circle), child: const Icon(Icons.add, size:14, color: Colors.white)))]),
          ])),
          const SizedBox(height:100),
        ])),
      ])),
      bottomSheet: Container(padding: const EdgeInsets.fromLTRB(16,10,16,20), decoration: const BoxDecoration(color: Colors.white, boxShadow:[BoxShadow(color: Color(0x14000000), blurRadius:10, offset: Offset(0,-2))]), child: Row(children:[
        Column(crossAxisAlignment:CrossAxisAlignment.start, children:[ Text('Price total', style: TextStyle(color: Colors.grey[500], fontSize:11)), Row(children:[ Text('\$4.58', style: const TextStyle(fontWeight:FontWeight.w900, fontSize:18)), const SizedBox(width:6), Text('Discount 10%', style: TextStyle(color: Colors.grey[500], fontSize:10, decoration: TextDecoration.lineThrough))])]),
        const Spacer(),
        ElevatedButton.icon(onPressed:(){ context.read<SupermarketProvider>().add(product['id'],1); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajouté au panier'))); }, icon: const Icon(Icons.shopping_bag_outlined, size:18, color: Colors.white), label: const Text('Add to Cart', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), padding: const EdgeInsets.symmetric(horizontal:22, vertical:12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)))),
      ])),
    );
  }
}
