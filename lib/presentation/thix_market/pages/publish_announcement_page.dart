// lib/presentation/thix_market/vendor/publish_announcement_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/shop_provider.dart';
import '../widgets/selling/publish_announcement_form.dart';

class PublishAnnouncementPage extends ConsumerStatefulWidget {
  const PublishAnnouncementPage({super.key});
  @override 
  ConsumerState<PublishAnnouncementPage> createState() => _PublishAnnouncementPageState();
}

class _PublishAnnouncementPageState extends ConsumerState<PublishAnnouncementPage> {
  String? _selectedShopId;
  static const thixRed = Color(0xFFD81E2C);

  @override 
  void initState(){
    super.initState();
    Future.microtask(()=> ref.invalidate(myShopsProvider));
  }

  @override 
  Widget build(BuildContext context){
    final shopsAsync = ref.watch(myShopsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Publier une annonce', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A1D29), fontSize: 18)),
        backgroundColor: Colors.white, 
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.black87), onPressed: ()=> context.pop()),
      ),
      body: shopsAsync.when(
        loading: ()=> const Center(child: CircularProgressIndicator(color: thixRed)),
        error: (e, _) => Center(child: Text('Erreur $e')),
        data: (shops){
          if(shops.isEmpty) return _noShopView();
          if(_selectedShopId == null) _selectedShopId = shops.first['id'].toString();
          
          return Column(
            children: [
              if(shops.length > 1)
                Padding(
                  padding: const EdgeInsets.all(16), 
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButtonFormField<String>(
                        value: _selectedShopId,
                        decoration: const InputDecoration(labelText: 'Sélectionner une boutique', border: InputBorder.none, labelStyle: TextStyle(fontSize: 13)),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: thixRed),
                        items: shops.map<DropdownMenuItem<String>>((shop){
                          return DropdownMenuItem<String>(
                            value: shop['id'].toString(),
                            child: Row(children: [
                              shop['logo_url'] != null 
                                ? ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(shop['logo_url'], width: 28, height: 28, fit: BoxFit.cover, errorBuilder: (a,b,c)=> const Icon(Icons.store, size: 18, color: Colors.grey))) 
                                : const Icon(Icons.store, size: 18, color: Colors.grey),
                              const SizedBox(width: 10),
                              Expanded(child: Text(shop['name'] ?? 'Boutique', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                            ]),
                          );
                        }).toList(),
                        onChanged: (v)=> setState(()=> _selectedShopId = v),
                      )
                    ),
                  )
                ),
              if(_selectedShopId != null)
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: PublishAnnouncementForm(
                      shopId: _selectedShopId!,
                      onSuccess: (response){
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 10), Text('Annonce publiée avec succès !')]), 
                            backgroundColor: Colors.green.shade600,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          )
                        );
                        context.pop();
                      },
                    ),
                  )
                ),
            ]
          );
        },
      ),
    );
  }

  Widget _noShopView(){
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32), 
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, 
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: thixRed.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.storefront_rounded, size: 64, color: thixRed),
            ),
            const SizedBox(height: 24),
            const Text('Aucune boutique', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF10192E)), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Créez une boutique pour pouvoir publier et gérer vos annonces.', style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.5), textAlign: TextAlign.center),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: ()=> context.push('/market/shop/create'), 
              icon: const Icon(Icons.add_rounded, color: Colors.white), 
              label: const Text('Créer ma boutique', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), 
              style: ElevatedButton.styleFrom(
                backgroundColor: thixRed, 
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              )
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: ()=> context.pop(), 
              child: const Text('Annuler', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600))
            ),
          ]
        )
      )
    );
  }
}
