import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../providers/shop_provider.dart';

class ShopsPage extends ConsumerWidget {
  const ShopsPage({super.key});
  static const navy = Color(0xFF1B2A4A);
  static const gold = Color(0xFFC9962C);
  static const bgApp = Color(0xFFF6F7FB);
  static const textMuted = Color(0xFF8A8FA3);

  @override Widget build(BuildContext context, WidgetRef ref){
    final my = ref.watch(myShopsProvider);
    final followed = ref.watch(followedShopsProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bgApp,
        appBar: AppBar(
          title: const Text('Mes Boutiques', style: TextStyle(fontWeight: FontWeight.w800)),
          backgroundColor: Colors.white,
          bottom: const TabBar(tabs: [Tab(text: 'Mes boutiques'), Tab(text: 'Suivies')], labelColor: navy, indicatorColor: gold),
          actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: (){ ref.invalidate(myShopsProvider); ref.invalidate(followedShopsProvider); })],
        ),
        body: TabBarView(children: [
          my.when(
            loading: ()=> const Center(child: CircularProgressIndicator(color: gold)),
            error: (e,_ )=> Center(child: Text('Erreur $e')),
            data: (list){
              if(list.isEmpty){
                return Center(child: ElevatedButton(onPressed: ()=> context.push('/market/shop/create'), style: ElevatedButton.styleFrom(backgroundColor: gold), child: const Text('Créer ma boutique')));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (c,i){
                  final s = list[i];
                  final rating = (s['rating'] as num?)?.toDouble()?? 0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: navy.withOpacity(0.05), blurRadius: 12)]),
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: bgApp, backgroundImage: s['logo_url']!=null? NetworkImage(s['logo_url']) : null, child: s['logo_url']==null? const Icon(Icons.store, color: textMuted) : null),
                      title: Text(s['name']?? 'Boutique', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        RatingBar.builder(initialRating: rating, itemCount: 5, itemSize: 12, ignoreGestures: true, itemBuilder: (a,b)=> const Icon(Icons.star_rounded, color: gold), onRatingUpdate: (v){}),
                        Text('${s['city']?? ''} • ${s['followers']?? 0} abonnés', style: const TextStyle(fontSize: 11, color: textMuted)),
                      ]),
                      onTap: ()=> context.push('/market/shop/${s['id']}'),
                    ),
                  );
                },
              );
            },
          ),
          followed.when(
            loading: ()=> const Center(child: CircularProgressIndicator(color: gold)),
            error: (e,_ )=> Center(child: Text('Erreur $e')),
            data: (list){
              if(list.isEmpty) return const Center(child: Text('Aucune boutique suivie'));
              return ListView.builder(padding: const EdgeInsets.all(12), itemCount: list.length, itemBuilder: (c,i){
                final s = list[i];
                return Card(child: ListTile(title: Text(s['name']?? 'Boutique'), onTap: ()=> context.push('/market/shop/${s['id']}')));
              });
            },
          ),
        ]),
      ),
    );
  }
}
