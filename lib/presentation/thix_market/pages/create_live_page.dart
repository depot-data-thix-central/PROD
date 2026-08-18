import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/shop_provider.dart';
import '../widgets/live/create_live_form.dart';

class CreateLivePage extends ConsumerStatefulWidget {
  const CreateLivePage({super.key});
  @override ConsumerState<CreateLivePage> createState() => _CreateLivePageState();
}

class _CreateLivePageState extends ConsumerState<CreateLivePage> {
  String? _selectedShopId;

  @override void initState(){
    super.initState();
    Future.microtask(() => ref.invalidate(myShopsProvider));
  }

  @override Widget build(BuildContext context){
    final shopsAsync = ref.watch(myShopsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Créer un live', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: Colors.white, elevation: 0, centerTitle: true,
      ),
      body: shopsAsync.when(
        loading: ()=> const Center(child: CircularProgressIndicator(color: Color(0xFF1A73E8))),
        error: (e,_ )=> Center(child: Text('Erreur $e')),
        data: (shops){
          if(shops.isEmpty){
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.storefront, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Vous n\'avez pas encore de boutique', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Créez une boutique pour pouvoir créer un live', style: TextStyle(color: Colors.grey.shade600), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: ()=> context.push('/market/shop/create'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12)),
                child: const Text('Créer une boutique', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ]));
          }
          // Auto-select first if null
          if(_selectedShopId==null){
            _selectedShopId = shops.first['id'].toString();
          }
          return Column(children: [
            if(shops.length>1)
              Padding(padding: const EdgeInsets.all(16), child: DropdownButtonFormField<String>(
                value: _selectedShopId,
                decoration: InputDecoration(labelText: 'Sélectionner une boutique', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
                items: shops.map<DropdownMenuItem<String>>((shop){
                  return DropdownMenuItem<String>(value: shop['id'].toString(), child: Text(shop['name']?? 'Boutique'));
                }).toList(),
                onChanged: (v)=> setState(()=> _selectedShopId=v),
              )),
            if(_selectedShopId!=null)
              Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: CreateLiveForm(shopId: _selectedShopId!))),
          ]);
        },
      ),
    );
  }
}
